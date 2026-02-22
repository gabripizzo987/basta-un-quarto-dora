extends Control

signal finished(success: bool)

@export var duration_sec: float = 18.0
@export var min_pump_events: int = 1
@export var max_pump_events: int = 2
@export var pump_window_sec: float = 6.0

@export var base_fill_per_sec: float = 100.0 / 18.0

@export var min_flow_when_bad: float = 0.12
@export var flow_decay_per_sec: float = 0.50
@export var flow_recover_per_good_pump: float = 0.95
@export var flow_smooth: float = 10.0

@export var low_flow_threshold: float = 0.08
@export var low_flow_fail_after: float = 4.2
@export var pump_recover_threshold: float = 0.16

@export var bag_top_px: int = 200
@export var bag_bottom_px: int = 650

@export var ui_offset_y: float = 80.0

@export var DEBUG_PRINT_EVERY_SEC: bool = false
@export var hold_recover_per_sec: float = 0.55

# =============================
# PIXEL STYLE
# =============================
@export var pixel_font: FontFile
@export var pixel_font_size: int = 22            # ⬅️ più grande di default
@export var tutorial_title_size: int = 28        # ⬅️ più grande
@export var tutorial_body_size: int = 22         # ⬅️ più grande

# cursor/icon
@export var custom_cursor: Texture2D
@export var cursor_hotspot: Vector2 = Vector2(0, 0)
@export var cursor_scale: float = 0.25           # ⬅️ riduce il mouse gigante (0.20–0.35 ok)

const DEFAULT_PIXEL_FONT_PATH := "res://fonts/PixelOperator8.ttf"
const DEFAULT_CURSOR_PATH := "res://assets/backgrounds/Spritesheets/Mouse.png"

@onready var center: CenterContainer = $CenterContainer
@onready var offset: MarginContainer = $CenterContainer/Offset
@onready var vbox: VBoxContainer = $CenterContainer/Offset/VBoxContainer

@onready var bag_stack: Control = $CenterContainer/Offset/VBoxContainer/BagStack
@onready var clip: Control = $CenterContainer/Offset/VBoxContainer/BagStack/Clip
@onready var blood_fill: Sprite2D = $CenterContainer/Offset/VBoxContainer/BagStack/Clip/BloodFill

@onready var hand: TextureRect = $CenterContainer/Offset/VBoxContainer/Hand
@onready var prompt: Label = $CenterContainer/Offset/VBoxContainer/Prompt

@export var hand_open: Texture2D
@export var hand_closed: Texture2D

var t_total: float = 0.0
var t_fill: float = 0.0
var fill_percent: float = 0.0

var flow: float = 1.0
var flow_target: float = 1.0

var pump_active: bool = false
var pump_time_left: float = 0.0
var pump_schedule: Array[float] = []
var pump_index: int = 0

var want_closed: bool = true
var low_flow_time: float = 0.0

var blood_mat: ShaderMaterial = null

var _show_tutorial: bool = false
var _tutorial_open: bool = false
var _tutorial_root: Control = null

# cache cursor scalato
var _scaled_cursor: Texture2D = null


func _ready() -> void:
	if bag_stack == null or clip == null or blood_fill == null:
		push_error("Nodi BagStack/Clip/BloodFill non trovati. Controlla i path!")
		return
	if hand == null or prompt == null:
		push_error("Nodi Hand/Prompt non trovati. Controlla i path!")
		return
	if blood_fill.texture == null:
		push_error("BloodFill.texture è NULL. Assegna la texture rossa (piena).")
		return

	# fallback risorse
	_ensure_pixel_assets_loaded()

	_apply_hard_layout_fix()
	call_deferred("_apply_ui_offset")

	# pixel font su tutta la scena (incl. prompt)
	_apply_pixel_font_recursive(self)

	# IMPORTANT: NON settiamo il cursor qui (lo facciamo solo quando c’è flusso basso)

	# input: non far mangiare click
	mouse_filter = Control.MOUSE_FILTER_STOP
	bag_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bag_frame := bag_stack.get_node_or_null("BagFrame")
	if bag_frame != null and bag_frame is Control:
		(bag_frame as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	# shader material
	var m: Material = blood_fill.material
	if m is ShaderMaterial:
		blood_mat = m as ShaderMaterial
	else:
		push_error("BloodFill.material non è ShaderMaterial: %s" % [m])
		return

	var tex_h: float = float(blood_fill.texture.get_size().y)
	var cut_top: float = clamp(float(bag_top_px) / tex_h, 0.0, 1.0)
	var cut_bottom: float = clamp(float(tex_h - bag_bottom_px) / tex_h, 0.0, 1.0)

	blood_mat.set_shader_parameter("cut_top", cut_top)
	blood_mat.set_shader_parameter("cut_bottom", cut_bottom)

	# init
	t_total = 0.0
	t_fill = 0.0
	fill_percent = 0.0
	flow = 1.0
	flow_target = 1.0
	low_flow_time = 0.0
	pump_active = false
	pump_time_left = 0.0
	pump_index = 0

	prompt.visible = false
	hand.visible = false
	if hand_open != null:
		hand.texture = hand_open

	randomize()
	_build_schedule()

	_set_fill_shader(0.0)

	if _show_tutorial:
		_open_tutorial()


func _apply_hard_layout_fix() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL

	vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var target := Vector2(1024, 1024)
	bag_stack.custom_minimum_size = target
	clip.custom_minimum_size = target
	clip.clip_contents = true

	blood_fill.centered = false
	blood_fill.position = Vector2.ZERO
	blood_fill.scale = Vector2.ONE


func _apply_ui_offset() -> void:
	offset.add_theme_constant_override("margin_top", int(ui_offset_y))


func _build_schedule() -> void:
	pump_schedule.clear()

	var mn: int = maxi(0, int(min_pump_events))
	var mx: int = maxi(mn, int(max_pump_events))
	var events: int = randi_range(mn, mx)

	for i in range(events):
		var when: float = randf_range(3.0, maxf(3.1, duration_sec - 3.0))
		pump_schedule.append(when)

	pump_schedule.sort()
	pump_index = 0


func _process(delta: float) -> void:
	if _tutorial_open:
		return

	if DEBUG_PRINT_EVERY_SEC and int(t_total) != int(t_total - delta):
		print("t_fill=", snappedf(t_fill, 0.1),
			" t_total=", snappedf(t_total, 0.1),
			" fill=", snappedf(fill_percent, 1),
			" flow=", snappedf(flow, 2),
			" pump=", pump_active,
			" lowT=", snappedf(low_flow_time, 2))

	if fill_percent >= 100.0:
		_finish(true)
		return

	t_total += delta
	if not pump_active:
		t_fill += delta

	if (not pump_active) and (pump_index < pump_schedule.size()) and (t_fill >= pump_schedule[pump_index]):
		_start_pump()

	flow_target = (min_flow_when_bad if pump_active else 1.0)
	flow = lerpf(flow, flow_target, 1.0 - exp(-flow_smooth * delta))

	if pump_active:
		pump_time_left -= delta

		# decay naturale del flusso quando è "basso"
		flow = maxf(min_flow_when_bad, flow - flow_decay_per_sec * delta)

		# ✅ NEW: se tieni premuto il sinistro, recuperi un po' ogni frame (più easy)
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			flow = clampf(flow + hold_recover_per_sec * delta, 0.0, 1.35)

		prompt.text = ("Flusso basso — stringi e rilascia!" if flow < 0.30 else "Flusso OK")

		if flow < low_flow_threshold:
			low_flow_time += delta
		else:
			low_flow_time = maxf(0.0, low_flow_time - delta * 0.6)

		if low_flow_time >= low_flow_fail_after:
			_finish(false)
			return

		if pump_time_left <= 0.0:
			if flow < pump_recover_threshold:
				_finish(false)
				return
			_end_pump()

	fill_percent = clampf(fill_percent + (base_fill_per_sec * flow * delta), 0.0, 100.0)
	_set_fill_shader(fill_percent / 100.0)

	if t_fill >= duration_sec and fill_percent < 100.0:
		_finish(false)


func _input(event: InputEvent) -> void:
	if _tutorial_open:
		return
	if not pump_active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_pump_click()


func _start_pump() -> void:
	pump_active = true
	pump_time_left = pump_window_sec
	low_flow_time = 0.0

	prompt.visible = true
	hand.visible = true

	# ✅ mostra cursor SOLO quando c’è flusso basso (mano visibile)
	_apply_custom_cursor(true)

	want_closed = true
	if hand_open != null:
		hand.texture = hand_open

	pump_index += 1


func _end_pump() -> void:
	pump_active = false
	prompt.visible = false
	hand.visible = false
	low_flow_time = 0.0

	# ✅ torna al mouse normale
	_apply_custom_cursor(false)


func _handle_pump_click() -> void:
	# ogni click aiuta SEMPRE tanto
	flow = clampf(flow + (flow_recover_per_good_pump * 0.70), 0.0, 1.35)

	# feedback visivo (toggle)
	if hand_open != null and hand_closed != null:
		hand.texture = hand_closed if (hand.texture == hand_open) else hand_open

func _set_fill_shader(a: float) -> void:
	if blood_mat == null:
		return
	blood_mat.set_shader_parameter("fill_amount", clampf(a, 0.0, 1.0))


func _finish(success: bool) -> void:
	print(">>> FINISH success=", success,
		" t_fill=", snappedf(t_fill, 0.2),
		" t_total=", snappedf(t_total, 0.2),
		" fill=", snappedf(fill_percent, 1))
	set_process(false)

	# safety: sempre ripristina cursor normale
	_apply_custom_cursor(false)

	finished.emit(success)
	queue_free()


func set_show_tutorial(v: bool) -> void:
	_show_tutorial = v


func _open_tutorial() -> void:
	_tutorial_open = true

	var root := Control.new()
	root.name = "TutorialOverlay"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	_tutorial_root = root

	var dimm := ColorRect.new()
	dimm.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimm.color = Color(0, 0, 0, 0.72)
	root.add_child(dimm)

	var center_box := CenterContainer.new()
	center_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center_box)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 300) # ⬅️ un pelo più grande
	center_box.add_child(panel)

	# ✅ PANEL COLOR #D56FFF
	# ✅ PANEL STYLE come gli altri (dark + bordo + rounded)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.html("#1E1E26")     # scuro
	sb.bg_color.a = 0.96
	sb.border_color = Color.html("#5E5E73") # bordo soft
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 18
	sb.corner_radius_bottom_right = 18
	panel.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	margin.add_child(vb)

	var title := Label.new()
	title.text = "Tutorial — Donazione"
	title.add_theme_font_size_override("font_size", tutorial_title_size)
	vb.add_child(title)

	# bullets
	var b1 := Label.new()
	b1.text = "• La sacca si riempie nel tempo."
	b1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b1.add_theme_font_size_override("font_size", tutorial_body_size)
	vb.add_child(b1)

	# ✅ riga con icona mouse INLINE vicino a “(ripetutamente)”
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)

	var lpre := Label.new()
	lpre.text = "• Quando compare la mano: CLIC sinistro"
	lpre.add_theme_font_size_override("font_size", tutorial_body_size)
	row.add_child(lpre)

	var icon := TextureRect.new()
	icon.texture = _get_scaled_cursor_for_icon()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(24, 24)  # ⬅️ iconcina piccola
	row.add_child(icon)

	var lpost := Label.new()
	lpost.text = "(ripetutamente)"
	lpost.add_theme_font_size_override("font_size", tutorial_body_size)
	row.add_child(lpost)

	var b3 := Label.new()
	b3.text = "• Se reagisci troppo tardi, la donazione fallisce."
	b3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b3.add_theme_font_size_override("font_size", tutorial_body_size)
	vb.add_child(b3)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	vb.add_child(spacer)

	var hint := Label.new()
	hint.text = "Premi \"Inizia\" per partire."
	hint.add_theme_font_size_override("font_size", tutorial_body_size)
	vb.add_child(hint)

	var btn := Button.new()
	btn.text = "Inizia"
	btn.custom_minimum_size = Vector2(180, 46)
	vb.add_child(btn)

	btn.pressed.connect(_close_tutorial)

	# pixel font anche ai nodi runtime
	_apply_pixel_font_recursive(root)

	get_viewport().gui_release_focus()
	btn.grab_focus()


func _close_tutorial() -> void:
	_tutorial_open = false
	if is_instance_valid(_tutorial_root):
		_tutorial_root.queue_free()
	_tutorial_root = null
	get_viewport().gui_release_focus()


# =============================
# PIXEL HELPERS
# =============================
func _ensure_pixel_assets_loaded() -> void:
	if pixel_font == null and ResourceLoader.exists(DEFAULT_PIXEL_FONT_PATH):
		var f := load(DEFAULT_PIXEL_FONT_PATH)
		if f is FontFile:
			pixel_font = f as FontFile

	if custom_cursor == null and ResourceLoader.exists(DEFAULT_CURSOR_PATH):
		var t := load(DEFAULT_CURSOR_PATH)
		if t is Texture2D:
			custom_cursor = t as Texture2D


func _apply_pixel_font_recursive(n: Node) -> void:
	if pixel_font == null:
		return

	if n is Control:
		var c := n as Control
		c.add_theme_font_override("font", pixel_font)
		c.add_theme_font_size_override("font_size", pixel_font_size)

	for ch in n.get_children():
		_apply_pixel_font_recursive(ch)


func _apply_custom_cursor(enable: bool) -> void:
	if custom_cursor == null:
		return

	if enable:
		var tex := _get_scaled_cursor()
		Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, cursor_hotspot)
		Input.set_custom_mouse_cursor(tex, Input.CURSOR_POINTING_HAND, cursor_hotspot)
		Input.set_custom_mouse_cursor(tex, Input.CURSOR_IBEAM, cursor_hotspot)
	else:
		Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
		Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
		Input.set_custom_mouse_cursor(null, Input.CURSOR_IBEAM)


func _get_scaled_cursor() -> Texture2D:
	if _scaled_cursor != null:
		return _scaled_cursor
	_scaled_cursor = _make_scaled_texture(custom_cursor, cursor_scale)
	return _scaled_cursor


func _get_scaled_cursor_for_icon() -> Texture2D:
	# per la iconcina nel tutorial va bene anche lo stesso cursor scalato
	return _get_scaled_cursor()


func _make_scaled_texture(src: Texture2D, scale_f: float) -> Texture2D:
	if src == null:
		return null
	scale_f = clampf(scale_f, 0.05, 1.0)

	var img := src.get_image()
	if img == null:
		return src

	var w := maxi(1, int(img.get_width() * scale_f))
	var h := maxi(1, int(img.get_height() * scale_f))

	# resize con nearest per pixel art
	img.resize(w, h, Image.INTERPOLATE_NEAREST)

	var tex := ImageTexture.create_from_image(img)
	return tex
