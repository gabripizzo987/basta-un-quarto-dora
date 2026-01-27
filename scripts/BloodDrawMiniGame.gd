extends Control

signal done(result: String) # "success" | "borderline" | "fail"

@onready var frame: Panel = $Frame
@onready var title: Label = $Frame/Margin/VBox/Title
@onready var hint: Label = $Frame/Margin/VBox/Hint
@onready var playfield: Control = $Frame/Margin/VBox/PlayField

@onready var arm: TextureRect = $Frame/Margin/VBox/PlayField/Arm
@onready var zone: ColorRect = $Frame/Margin/VBox/PlayField/VeinZone
@onready var needle: TextureRect = $Frame/Margin/VBox/PlayField/Needle
@onready var elbow: Marker2D = $Frame/Margin/VBox/PlayField/Arm/ElbowMarker
@onready var margin: MarginContainer = $Frame/Margin

var active: bool = false
var speed: float = 280.0
var dir: int = 1
var needle_y: float = 0.0
var fixed_x: float = 0.0

const TOP_PADDING: float = -200.0
const BOTTOM_PADDING: float = -175.0
const BORDERLINE_MARGIN: float = 18.0
const TIP_MARGIN_BOTTOM: float = 6.0
const ELBOW_JITTER_Y: float = 6.0
const ELBOW_JITTER_X: float = 0.0

const TEXT_PAD_X := 4
const TEXT_PAD_Y := 4
const TITLE_COLOR := Color("#7EC8E3")  

const OSC_UP: float = 150.0
const OSC_DOWN: float = 600.0

const ZONE_X_OFFSET: float = 35.0
const NEEDLE_X_OFFSET: float = 10.0

const NEEDLE_TIP_OFFSET_Y: float = 61.0

func _ready() -> void:
	hide()
	set_process(false)

func start() -> void:
	await get_tree().process_frame

	show()
	active = true
	set_process(true)

	title.text = "Prelievo - Inserimento ago"
	hint.text = "Premi E quando la punta dell'ago e' nella VENA"
	
	margin.add_theme_constant_override("margin_left",  TEXT_PAD_X)
	margin.add_theme_constant_override("margin_top",   TEXT_PAD_Y)

	title.add_theme_color_override("font_color", TITLE_COLOR)


	playfield.clip_contents = false
	frame.clip_contents = false

	_force_top_left(playfield)
	_force_top_left(arm)
	_force_top_left(zone)
	_force_top_left(needle)

	needle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	needle.stretch_mode = TextureRect.STRETCH_SCALE
	arm.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arm.stretch_mode = TextureRect.STRETCH_SCALE

	arm.z_as_relative = false
	zone.z_as_relative = false
	needle.z_as_relative = false
	arm.z_index = -100
	zone.z_index = 10
	needle.z_index = 999
	needle.move_to_front()

	if needle.texture == null:
		push_error("Needle.texture è NULL")
		return

	var tex_size: Vector2 = needle.texture.get_size()
	var desired_h: float = playfield.size.y * 0.80
	var aspect: float = tex_size.x / maxf(1.0, tex_size.y)
	var desired_w: float = desired_h * aspect
	needle.size = Vector2(desired_w, desired_h)

	_place_zone_on_elbow()

	var zone_center: Vector2 = zone.position + zone.size * 0.5
	var tip_local: Vector2 = _tip_local_for_alignment()
	var base_pos: Vector2 = zone_center - tip_local
	base_pos.x += NEEDLE_X_OFFSET

	fixed_x = _clamp_needle_x(base_pos.x)
	needle.position.x = fixed_x

	var r: Vector2 = _range_y_around_zone()
	needle_y = r.x
	needle.position.y = needle_y
	dir = 1

func _process(delta: float) -> void:
	if not active:
		return

	var r: Vector2 = _range_y_around_zone()
	var min_y: float = r.x
	var max_y: float = r.y

	needle_y += float(dir) * speed * delta

	if needle_y <= min_y:
		needle_y = min_y
		dir = 1
	elif needle_y >= max_y:
		needle_y = max_y
		dir = -1

	needle.position.x = fixed_x
	needle.position.y = needle_y

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("interact"):
		_check_result()

func _place_zone_on_elbow() -> void:
	var elbow_local_in_arm: Vector2 = elbow.position
	elbow_local_in_arm.x += randf_range(-ELBOW_JITTER_X, ELBOW_JITTER_X)
	elbow_local_in_arm.y += randf_range(-ELBOW_JITTER_Y, ELBOW_JITTER_Y)

	var elbow_pf: Vector2 = arm.position + elbow_local_in_arm
	elbow_pf.x += ZONE_X_OFFSET

	zone.position = elbow_pf - zone.size * 0.5


func _tip_local_for_alignment() -> Vector2:
	return Vector2(
		needle.size.x * 0.5,
		needle.size.y - NEEDLE_TIP_OFFSET_Y
	)

func _range_y_around_zone() -> Vector2:
	var zone_center_y: float = zone.position.y + zone.size.y * 0.5
	var tip_local: Vector2 = _tip_local_for_alignment()

	var min_y: float = (zone_center_y - OSC_UP) - tip_local.y
	var max_y: float = (zone_center_y + OSC_DOWN) - tip_local.y

	var min_clamp: float = TOP_PADDING
	var max_clamp: float = playfield.size.y - needle.size.y - BOTTOM_PADDING
	if max_clamp < min_clamp:
		max_clamp = min_clamp

	min_y = clamp(min_y, min_clamp, max_clamp)
	max_y = clamp(max_y, min_clamp, max_clamp)
	if max_y < min_y:
		max_y = min_y

	return Vector2(min_y, max_y)

func _needle_tip_global() -> Vector2:
	var tip_local := Vector2(
		needle.size.x * 0.5,
		needle.size.y - NEEDLE_TIP_OFFSET_Y
	)
	var t := needle.get_global_transform_with_canvas()
	return t * tip_local

func _check_result() -> void:
	active = false
	set_process(false)

	var tip: Vector2 = _needle_tip_global()
	var zrect: Rect2 = zone.get_global_rect()

	var result: String = "fail"
	if zrect.has_point(tip):
		result = "success"
	else:
		var top: float = zrect.position.y
		var bottom: float = zrect.position.y + zrect.size.y
		var dy: float = minf(absf(tip.y - top), absf(tip.y - bottom))
		if dy <= BORDERLINE_MARGIN:
			result = "borderline"

	match result:
		"success":
			hint.text = "✅ Perfetto. Ago in vena."
		"borderline":
			hint.text = "⚠️ Quasi. Riprova con piu' precisione."
		"fail":
			hint.text = "❌ Fuori punto. Ripeti con calma."

	await get_tree().create_timer(0.9).timeout
	hide()
	emit_signal("done", result)

func _clamp_needle_x(x: float) -> float:
	var max_x: float = playfield.size.x - needle.size.x
	if max_x < 0.0:
		max_x = 0.0
	return clamp(x, 0.0, max_x)

func _force_top_left(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	c.pivot_offset = Vector2.ZERO
	c.rotation = 0.0
