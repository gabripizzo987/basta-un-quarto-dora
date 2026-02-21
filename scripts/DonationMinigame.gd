extends Control

signal finished(success: bool)

@export var duration_sec: float = 18.0
@export var min_pump_events: int = 1
@export var max_pump_events: int = 2
@export var pump_window_sec: float = 4.5

# --- FILL / FLOW (bilanciato) ---
@export var base_fill_per_sec: float = 100.0 / 18.0

@export var min_flow_when_bad: float = 0.12
@export var flow_decay_per_sec: float = 0.50
@export var flow_recover_per_good_pump: float = 0.50
@export var flow_smooth: float = 10.0

@export var low_flow_threshold: float = 0.12
@export var low_flow_fail_after: float = 2.4
@export var pump_recover_threshold: float = 0.28

# tagli (pixel su 1024)
@export var bag_top_px: int = 200
@export var bag_bottom_px: int = 650

# offset UI (per “centrale e leggermente in basso”)
@export var ui_offset_y: float = 80.0

@export var DEBUG_PRINT_EVERY_SEC: bool = false

# =============================
# NODI (path tuoi)
# =============================
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

# =============================
# STATO
# =============================
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

	_apply_hard_layout_fix()

	# ✅ FIX 1: applica offset DOPO che i container hanno calcolato il layout
	call_deferred("_apply_ui_offset")

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

	# cut params (TIPI ESPLICITI -> niente warning variant)
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


func _apply_hard_layout_fix() -> void:
	# root full rect
	set_anchors_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	# center full rect
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# vbox non deve espandere: resta “compatta”
	vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# sacca 1024x1024
	var target := Vector2(1024, 1024)
	bag_stack.custom_minimum_size = target
	clip.custom_minimum_size = target
	clip.clip_contents = true

	blood_fill.centered = false
	blood_fill.position = Vector2.ZERO
	blood_fill.scale = Vector2.ONE


func _apply_ui_offset() -> void:
	# ✅ FIX 2: con MarginContainer il modo giusto è modificare i margini, non la position del vbox
	# sposta in basso di ui_offset_y
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
		flow = maxf(min_flow_when_bad, flow - flow_decay_per_sec * delta)

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

	want_closed = true
	if hand_open != null:
		hand.texture = hand_open

	pump_index += 1


func _end_pump() -> void:
	pump_active = false
	prompt.visible = false
	hand.visible = false
	low_flow_time = 0.0


func _handle_pump_click() -> void:
	if hand_open == null or hand_closed == null:
		flow = clampf(flow + 0.12, 0.0, 1.35)
		return

	var is_open: bool = (hand.texture == hand_open)

	if want_closed and is_open:
		hand.texture = hand_closed
		want_closed = false
		flow = clampf(flow + flow_recover_per_good_pump, 0.0, 1.35)
		return

	if (not want_closed) and (not is_open):
		hand.texture = hand_open
		want_closed = true
		flow = clampf(flow + flow_recover_per_good_pump, 0.0, 1.35)
		return

	flow = maxf(min_flow_when_bad, flow - 0.01)


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
	finished.emit(success)
	queue_free()
