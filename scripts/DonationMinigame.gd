extends Control

signal finished(success: bool)

@export var duration_sec: float = 18.0
@export var min_pump_events: int = 2
@export var max_pump_events: int = 3
@export var pump_window_sec: float = 4.0

@export var base_fill_per_sec: float = 100.0 / 18.0

@export var min_flow_when_bad: float = 0.12
@export var flow_decay_per_sec: float = 0.72
@export var flow_recover_per_good_pump: float = 0.90
@export var flow_smooth: float = 10.0

@export var low_flow_threshold: float = 0.08
@export var low_flow_fail_after: float = 3.0
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
const TAP_HAND_PATH := "res://assets/ui/tap_hand.png"

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
var _tutorial_root: Node = null

var _tap_indicator: Node = null
var _tap_tween: Tween = null
var _click_handled_frame: int = -1


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

	_spawn_label_puzzle()

	if _show_tutorial:
		_open_tutorial()


# =============================
# MINIGIOCO ETICHETTE (accanto alla sacca)
# =============================
const LABEL_PUZZLE_SCRIPT := preload("res://scripts/LabelMatchPuzzle.gd")
var label_puzzle: Control = null
var puzzle_points: int = 50
var puzzle_grace: float = 9.0      # secondi extra a sacca piena per finire le etichette

## Puzzle da completare per questo donatore: lista di [lato, coppie].
## In Difficile sono due di fila.
var _puzzle_seq: Array = [[5, 4]]
var _puzzle_index: int = 0
var _puzzle_layer: CanvasLayer = null
var _puzzle_paused: bool = false
var _swapping: bool = false

var _grace_left: float = -1.0      # >= 0 mentre si aspetta il puzzle a sacca piena
var _puzzle_solved_at: float = -1.0
var _fail_reason: String = "flow"

## Un solo puzzle (usato dalla scena di debug). Chiamare prima di add_child.
func set_puzzle_difficulty(grid_size: int, pairs: int, points: int = 50, grace: float = 9.0) -> void:
	set_puzzle_sequence([[grid_size, pairs]], points, grace)


## Piu' puzzle di fila. Chiamare prima di add_child.
func set_puzzle_sequence(seq: Array, points: int = 50, grace: float = 9.0) -> void:
	_puzzle_seq = seq.duplicate(true) if not seq.is_empty() else [[5, 4]]
	puzzle_points = points
	puzzle_grace = grace


## Imposta i puzzle dalle regole della difficolta' scelta nel menu.
func set_puzzle_from_rules(first_donor: bool) -> void:
	var r: Dictionary = RunState.label_rules()
	set_puzzle_sequence(RunState.label_sequence(first_donor), r.points, r.grace)


func _all_puzzles_solved() -> bool:
	return (not _swapping) and _puzzle_index >= _puzzle_seq.size() - 1 \
		and is_instance_valid(label_puzzle) and label_puzzle.is_solved()


## Sacca piena: la donazione e' completa solo con tutte le etichette verificate.
func _process_bag_full(delta: float) -> void:
	if not is_instance_valid(label_puzzle) and not _swapping:
		_finish(true)
		return
	if _all_puzzles_solved():
		if _puzzle_solved_at < 0.0:
			_puzzle_solved_at = t_total
		t_total += delta
		# lascia vedere il timbro "VERIFICATE" un attimo prima di chiudere
		if t_total - _puzzle_solved_at >= 1.0:
			_finish(true)
		return

	if _grace_left < 0.0:
		_grace_left = puzzle_grace
		if pump_active:
			_end_pump()
		hand.visible = false
		# niente testo sotto la sacca: basta la barra rossa dentro il puzzle
		prompt.visible = false
		_set_puzzle_paused(false)

	_grace_left -= delta
	if is_instance_valid(label_puzzle):
		label_puzzle.set_countdown(_grace_left, puzzle_grace)
	if _grace_left <= 0.0:
		_fail_reason = "labels"
		_finish(false)


func _spawn_label_puzzle() -> void:
	# Layer proprio: la scena della donazione e' scalata (0.63) e il puzzle
	# deve restare a grandezza piena. Sta sotto il tocco della mano (120)
	# e sotto il tutorial (150), quindi non li blocca mai.
	_puzzle_layer = CanvasLayer.new()
	_puzzle_layer.name = "LabelPuzzleLayer"
	_puzzle_layer.layer = 100
	add_child(_puzzle_layer)
	_puzzle_index = 0
	_create_puzzle_for_index()
	get_viewport().size_changed.connect(_layout_label_puzzle)


func _create_puzzle_for_index() -> void:
	var spec: Array = _puzzle_seq[_puzzle_index]
	label_puzzle = LABEL_PUZZLE_SCRIPT.new()
	label_puzzle.name = "LabelMatchPuzzle"
	label_puzzle.setup(int(spec[0]), int(spec[1]))
	label_puzzle.points = puzzle_points
	label_puzzle.set_stage(_puzzle_index + 1, _puzzle_seq.size())
	_puzzle_layer.add_child(label_puzzle)
	label_puzzle.solved.connect(_on_label_puzzle_solved)
	label_puzzle.set_paused(_puzzle_paused)
	call_deferred("_layout_label_puzzle")


## Dopo il timbro "VERIFICATE" arriva il puzzle successivo, nello stesso posto.
func _swap_to_next_puzzle() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(label_puzzle):
		# toglierlo subito dall'albero: cosi' il nuovo puo' avere lo stesso nome
		if label_puzzle.get_parent() != null:
			label_puzzle.get_parent().remove_child(label_puzzle)
		label_puzzle.queue_free()
	_puzzle_index += 1
	_create_puzzle_for_index()
	_swapping = false


func _layout_label_puzzle() -> void:
	if not is_instance_valid(label_puzzle):
		return
	var vp := get_viewport_rect().size
	var ps: Vector2 = label_puzzle.size
	# la sacca sta circa al centro: il puzzle va nello spazio libero a destra
	var bag_right := vp.x * 0.5 + 90.0
	var free_w := vp.x - 16.0 - bag_right
	var x := bag_right + maxf(0.0, (free_w - ps.x) * 0.5)
	x = minf(x, vp.x - ps.x - 12.0)
	var y := maxf(8.0, (vp.y - ps.y) * 0.5)
	label_puzzle.position = Vector2(x, y).round()


func _set_puzzle_paused(p: bool) -> void:
	_puzzle_paused = p
	if is_instance_valid(label_puzzle):
		label_puzzle.set_paused(p)


func _on_label_puzzle_solved() -> void:
	RunState.labels_verified += 1
	RunState.score_labels += puzzle_points
	if _puzzle_index < _puzzle_seq.size() - 1:
		# ne manca ancora uno: piccola pausa per vedere il timbro, poi il prossimo
		_swapping = true
		get_tree().create_timer(0.9).timeout.connect(_swap_to_next_puzzle)
		return
	_puzzle_solved_at = t_total
	if is_instance_valid(label_puzzle):
		label_puzzle.set_countdown(-1.0, 1.0)


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
		_process_bag_full(delta)
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
	# Touch is handled by the layer-120 catcher in _spawn_tap_indicator() to avoid double-fire.
	# Here we only handle mouse clicks (PC).
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_pump_click()


func _start_pump() -> void:
	pump_active = true
	pump_time_left = pump_window_sec
	low_flow_time = 0.0

	prompt.visible = true
	hand.visible = true

	_spawn_tap_indicator()
	_set_puzzle_paused(true)

	want_closed = true
	if hand_open != null:
		hand.texture = hand_open

	pump_index += 1


func _end_pump() -> void:
	pump_active = false
	prompt.visible = false
	hand.visible = false
	low_flow_time = 0.0

	_kill_tap_indicator()
	_set_puzzle_paused(false)


func _handle_pump_click() -> void:
	# Guard against double-fire (touch + emulated mouse on Android both triggering same tap)
	var cur_frame := Engine.get_process_frames()
	if cur_frame == _click_handled_frame:
		return
	_click_handled_frame = cur_frame

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

	_kill_tap_indicator()
	_set_puzzle_paused(true)

	RunState.last_donation_fail_reason = "" if success else _fail_reason
	finished.emit(success)
	queue_free()


func set_show_tutorial(v: bool) -> void:
	_show_tutorial = v


func _open_tutorial() -> void:
	_tutorial_open = true
	_set_puzzle_paused(true)

	# Stesso stile di tutti gli altri pannelli (UiStyle)
	var UiStyle := preload("res://scripts/UiStyle.gd")

	var layer := CanvasLayer.new()
	layer.layer = 150
	get_tree().current_scene.add_child(layer)
	_tutorial_root = layer

	var root := Control.new()
	root.name = "TutorialOverlay"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)

	var dimm := ColorRect.new()
	dimm.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimm.color = Color(0.0, 0.0, 0.0, 0.6)
	dimm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dimm)

	var center_box := CenterContainer.new()
	center_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center_box)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(660, 0)
	UiStyle.style_panel(panel)
	center_box.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 24)
	for side in ["margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	margin.add_child(vb)

	var title := Label.new()
	title.text = "Come si dona"
	UiStyle.style_title(title)
	vb.add_child(title)

	var body := Label.new()
	body.text = \
		"• La sacca si riempie da sola nel tempo.\n" + \
		"• Intanto collega sacche e provette dello stesso colore: è il controllo etichette. Senza etichette verificate la donazione non vale.\n" + \
		"• Quando compare la mano, tocca velocemente lo schermo: se reagisci troppo tardi, la donazione fallisce."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(612, 0)
	UiStyle.style_body(body, 18)
	vb.add_child(body)

	var row := HBoxContainer.new()
	vb.add_child(row)
	var btn := Button.new()
	btn.text = "Inizia"
	UiStyle.style_button(btn, 18)
	btn.custom_minimum_size = Vector2(220, 52)
	row.add_child(btn)
	btn.pressed.connect(_close_tutorial)

	get_viewport().gui_release_focus()


func _make_tut_bullet(icon_text: String, body_text: String, icon_color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var icon_lbl := Label.new()
	icon_lbl.text = icon_text
	icon_lbl.add_theme_color_override("font_color", icon_color)
	icon_lbl.add_theme_font_size_override("font_size", tutorial_body_size + 2)
	icon_lbl.custom_minimum_size = Vector2(22, 0)
	row.add_child(icon_lbl)

	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(body)

	return row


func _make_sep(color: Color, height: float) -> CenterContainer:
	var wrap := CenterContainer.new()
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(600, height)
	line.color = color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(line)
	return wrap


func _close_tutorial() -> void:
	_tutorial_open = false
	_set_puzzle_paused(false)
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


func _spawn_tap_indicator() -> void:
	_kill_tap_indicator()

	var layer := CanvasLayer.new()
	layer.layer = 120
	get_tree().current_scene.add_child(layer)
	_tap_indicator = layer

	# Fullscreen invisible catcher at layer 120 — receives touch BEFORE VirtualDpad (layer 50).
	# Uses MOUSE_FILTER_PASS so it catches the event but still lets it through for other UI.
	var catcher := Control.new()
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(catcher)
	catcher.gui_input.connect(func(ev: InputEvent) -> void:
		if not pump_active:
			return
		var hit := false
		if ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
			hit = true
		elif ev is InputEventMouseButton \
				and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
				and (ev as InputEventMouseButton).pressed:
			hit = true
		if hit:
			_handle_pump_click()
	)

	# ── Badge "TOCCA!" pixel-art: icona mano + testo pixel, affiancati ──────────
	# HBox centrato; il pulse agisce sul gruppo intero (icona+testo insieme).
	var group := HBoxContainer.new()
	group.add_theme_constant_override("separation", 12)
	group.alignment = BoxContainer.ALIGNMENT_CENTER
	group.set_anchors_preset(Control.PRESET_CENTER)
	group.grow_horizontal = Control.GROW_DIRECTION_BOTH
	group.grow_vertical   = Control.GROW_DIRECTION_BOTH
	group.mouse_filter    = Control.MOUSE_FILTER_IGNORE
	layer.add_child(group)

	# Icona mano pixel-art (NEAREST per non sfocarla quando è scalata)
	if ResourceLoader.exists(TAP_HAND_PATH):
		var tex := load(TAP_HAND_PATH)
		if tex is Texture2D:
			var icon := TextureRect.new()
			icon.texture = tex
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(56, 64)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			group.add_child(icon)

	var lbl := Label.new()
	lbl.text = "TOCCA!"
	lbl.add_theme_color_override("font_color", Color(1.0, 0.86, 0.18))
	# Contorno scuro + ombra: si stacca da qualsiasi sfondo, look "da gioco".
	lbl.add_theme_color_override("font_outline_color", Color(0.12, 0.07, 0.05))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 3)
	lbl.add_theme_font_size_override("font_size", 40)
	if pixel_font != null:
		lbl.add_theme_font_override("font", pixel_font)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_child(lbl)

	# Pivot al centro del gruppo per uno scale pulito: la size del container è
	# nota solo dopo il layout, quindi lo impostiamo in deferred (metodo con
	# nome, niente lambda → sicuro su export Android).
	call_deferred("_center_tap_pivot", group)

	if _tap_tween != null and _tap_tween.is_valid():
		_tap_tween.kill()
	_tap_tween = create_tween().set_loops()
	_tap_tween.tween_property(group, "scale", Vector2(1.16, 1.16), 0.35)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tap_tween.tween_property(group, "scale", Vector2(1.0, 1.0), 0.35)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _center_tap_pivot(c: Control) -> void:
	# Imposta il pivot al centro reale del badge una volta calcolato il layout,
	# così il pulse scala dal centro senza derivare.
	if is_instance_valid(c):
		c.pivot_offset = c.size * 0.5


func _kill_tap_indicator() -> void:
	if _tap_tween != null and _tap_tween.is_valid():
		_tap_tween.kill()
	_tap_tween = null
	if is_instance_valid(_tap_indicator):
		_tap_indicator.queue_free()
	_tap_indicator = null
