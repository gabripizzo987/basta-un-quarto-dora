extends Control

signal finished(success: bool)

@export var duration_sec: float = 18.0
@export var max_pump_events: int = 2
@export var pump_window_sec: float = 3.2

@export var base_fill_per_sec: float = 100.0 / 18.0
@export var min_flow_when_bad: float = 0.08
@export var flow_decay_per_sec: float = 0.45
@export var flow_recover_per_good_pump: float = 0.16
@export var flow_smooth: float = 8.0

@export var low_flow_threshold: float = 0.18
@export var low_flow_fail_after: float = 1.2

@onready var bag: TextureProgressBar = $CenterContainer/VBoxContainer/BagStack/BagFill
@onready var hand: TextureRect = $CenterContainer/VBoxContainer/Hand
@onready var prompt: Label = $CenterContainer/VBoxContainer/Prompt

@export var hand_open: Texture2D
@export var hand_closed: Texture2D

var t: float = 0.0
var flow: float = 1.0
var flow_target: float = 1.0

var pump_active: bool = false
var pump_time_left: float = 0.0
var pump_schedule: Array[float] = []
var pump_index: int = 0

var want_closed: bool = true
var low_flow_time: float = 0.0


func _ready() -> void:
	if bag == null:
		push_error("BagFill non trovato: controlla il path!")
		return
	if hand == null:
		push_error("Hand non trovato: controlla il path!")
		return
	if prompt == null:
		push_error("Prompt non trovato: controlla il path!")
		return
		
	bag.min_value = 0
	bag.max_value = 100
	bag.value = 0

	prompt.visible = false
	hand.visible = false

	# safety: mano
	if hand_open != null:
		hand.texture = hand_open

	randomize()
	_build_schedule()


func _build_schedule() -> void:
	pump_schedule.clear()

	var events := randi_range(0, max_pump_events)
	for i in range(events):
		var when := randf_range(3.0, duration_sec - 3.0)
		pump_schedule.append(when)

	pump_schedule.sort()
	pump_index = 0


func _process(delta: float) -> void:
	if bag.value >= 100.0:
		_finish(true)
		return

	t += delta

	if (not pump_active) and (pump_index < pump_schedule.size()) and (t >= pump_schedule[pump_index]):
		_start_pump()

	flow_target = min_flow_when_bad if pump_active else 1.0
	flow = lerpf(flow, flow_target, 1.0 - exp(-flow_smooth * delta))

	if pump_active:
		pump_time_left -= delta
		flow = max(min_flow_when_bad, flow - flow_decay_per_sec * delta)

		prompt.text = "Flusso basso — stringi e rilascia" if flow < 0.25 else "Flusso OK"

		if flow < low_flow_threshold:
			low_flow_time += delta
		else:
			low_flow_time = max(0.0, low_flow_time - delta * 0.5)

		if low_flow_time >= low_flow_fail_after:
			_finish(false)
			return

		if pump_time_left <= 0.0:
			_end_pump()

	bag.value = minf(100.0, maxf(0.0, bag.value + base_fill_per_sec * flow * delta))

	if t >= duration_sec and bag.value < 100.0:
		_finish(false)


func _unhandled_input(event: InputEvent) -> void:
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
	# se non hai textures, fallback: non crasha
	if hand_open == null or hand_closed == null:
		flow = clamp(flow + 0.05, 0.0, 1.0)
		return

	var is_open := (hand.texture == hand_open)

	if want_closed and is_open:
		hand.texture = hand_closed
		want_closed = false
		flow = clamp(flow + flow_recover_per_good_pump, 0.0, 1.2)
		return

	if (not want_closed) and (not is_open):
		hand.texture = hand_open
		want_closed = true
		flow = clamp(flow + flow_recover_per_good_pump, 0.0, 1.2)
		return

	flow = max(min_flow_when_bad, flow - 0.03)


func _finish(success: bool) -> void:
	set_process(false)
	set_process_unhandled_input(false)
	finished.emit(success)
	queue_free()
