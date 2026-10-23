extends CanvasLayer

const PIXEL_FONT_PATH := "res://fonts/PixelOperator8.ttf"

# Joystick geometry
const BASE_R   := 90.0    # raggio anello esterno
const KNOB_R   := 40.0    # raggio della pallina
const DEAD     := 0.18    # dead-zone (frazione di BASE_R)
const STICK_X  := 175.0   # distanza dal bordo sinistro al centro dello stick
const STICK_Y  := 130.0   # distanza dal bordo inferiore al centro dello stick

# Interact button
const BTN_SZ   := Vector2(105, 105)
const BTN_MX   := 36.0
const BTN_MY   := 90.0

var _base_center := Vector2.ZERO
var _knob        : Control = null
var _touch_idx   := -1
var _active      := false


func _ready() -> void:
	layer = 50

	var vp := get_viewport().get_visible_rect().size

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_base_center = Vector2(STICK_X, vp.y - STICK_Y)

	# anello esterno (fisso)
	var base := _circle_panel(BASE_R * 2,
		Color(0.07, 0.07, 0.18, 0.55),
		Color(0.70, 0.70, 1.00, 0.80), 4)
	base.position = _base_center - Vector2(BASE_R, BASE_R)
	root.add_child(base)

	# pallina mobile
	_knob = _circle_panel(KNOB_R * 2,
		Color(0.28, 0.28, 0.60, 0.90),
		Color(0.90, 0.90, 1.00, 1.00), 3)
	_knob.position = _base_center - Vector2(KNOB_R, KNOB_R)
	root.add_child(_knob)

	# bottone Interagisci (E) — in basso a destra
	var ibtn := _pixel_btn("E", BTN_SZ)
	ibtn.position = Vector2(vp.x - BTN_SZ.x - BTN_MX, vp.y - BTN_SZ.y - BTN_MY)
	root.add_child(ibtn)
	ibtn.pressed.connect(func():
		var ev := InputEventAction.new()
		ev.action = "interact"
		ev.pressed = true
		Input.parse_input_event(ev)
	)

	# restyle ButtonManual (se presente nella scena)
	call_deferred("_restyle_manual_btn")


# ── Input ────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	# mouse (PC)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _in_base(event.position):
			_active = true
			_update_stick(event.position)
		elif not event.pressed:
			_stop_stick()
	elif event is InputEventMouseMotion and _active:
		_update_stick(event.position)
	# touch (Android)
	elif event is InputEventScreenTouch:
		if event.pressed and _touch_idx == -1 and _in_base(event.position):
			_touch_idx = event.index
			_active    = true
			_update_stick(event.position)
		elif not event.pressed and event.index == _touch_idx:
			_touch_idx = -1
			_stop_stick()
	elif event is InputEventScreenDrag and event.index == _touch_idx:
		_update_stick(event.position)


func _in_base(pos: Vector2) -> bool:
	return pos.distance_to(_base_center) <= BASE_R * 1.6


func _update_stick(pos: Vector2) -> void:
	var offset := pos - _base_center
	if offset.length() > BASE_R:
		offset = offset.normalized() * BASE_R

	if is_instance_valid(_knob):
		_knob.position = _base_center + offset - Vector2(KNOB_R, KNOB_R)

	var norm := offset / BASE_R

	for a in ["move_up", "move_down", "move_left", "move_right"]:
		Input.action_release(a)

	if norm.length() < DEAD:
		return

	if norm.x >  DEAD: Input.action_press("move_right")
	elif norm.x < -DEAD: Input.action_press("move_left")
	if norm.y >  DEAD: Input.action_press("move_down")
	elif norm.y < -DEAD: Input.action_press("move_up")


func _stop_stick() -> void:
	_active = false
	if is_instance_valid(_knob):
		_knob.position = _base_center - Vector2(KNOB_R, KNOB_R)
	for a in ["move_up", "move_down", "move_left", "move_right"]:
		Input.action_release(a)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _restyle_manual_btn() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var btn := scene.find_child("ButtonManual", true, false)
	if not (btn is Button):
		return
	var b := btn as Button
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(140, 56)
	b.offset_left   = -165.0
	b.offset_right  = -20.0
	b.offset_top    = 5.0
	b.offset_bottom = 61.0
	if ResourceLoader.exists(PIXEL_FONT_PATH):
		var fnt := load(PIXEL_FONT_PATH)
		if fnt is Font:
			b.add_theme_font_override("font", fnt)
	b.add_theme_font_size_override("font_size", 22)
	var sb := StyleBoxFlat.new()
	sb.bg_color      = Color(0.06, 0.06, 0.14, 0.92)
	sb.border_color  = Color(0.75, 0.75, 1.00, 0.90)
	sb.border_width_left = 3; sb.border_width_right  = 3
	sb.border_width_top  = 3; sb.border_width_bottom = 3
	sb.set_corner_radius_all(0)
	sb.shadow_color  = Color(0, 0, 0, 0.55)
	sb.shadow_size   = 3
	sb.shadow_offset = Vector2(3, 3)
	b.add_theme_stylebox_override("normal", sb)
	var sbp := sb.duplicate() as StyleBoxFlat
	sbp.bg_color     = Color(0.20, 0.20, 0.42, 1.0)
	sbp.shadow_size  = 1; sbp.shadow_offset = Vector2(1, 1)
	b.add_theme_stylebox_override("hover",   sbp)
	b.add_theme_stylebox_override("pressed", sbp)
	b.add_theme_stylebox_override("focus",   StyleBoxFlat.new())
	b.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))


func _circle_panel(diameter: float, bg: Color, border: Color, bw: int) -> Panel:
	var p  := Panel.new()
	var sz := Vector2(diameter, diameter)
	p.custom_minimum_size = sz
	p.size         = sz
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color          = bg
	sb.border_color      = border
	sb.border_width_left = bw; sb.border_width_right  = bw
	sb.border_width_top  = bw; sb.border_width_bottom = bw
	var r := int(diameter / 2)
	sb.corner_radius_top_left    = r
	sb.corner_radius_top_right   = r
	sb.corner_radius_bottom_left = r
	sb.corner_radius_bottom_right = r
	p.add_theme_stylebox_override("panel", sb)
	return p


func _pixel_btn(label: String, sz: Vector2) -> Button:
	var b := Button.new()
	b.text                = label
	b.custom_minimum_size = sz
	b.size                = sz
	b.focus_mode          = Control.FOCUS_NONE
	b.mouse_filter        = Control.MOUSE_FILTER_STOP
	if ResourceLoader.exists(PIXEL_FONT_PATH):
		var fnt := load(PIXEL_FONT_PATH)
		if fnt is Font:
			b.add_theme_font_override("font", fnt)
	b.add_theme_font_size_override("font_size", 34)
	var sb := StyleBoxFlat.new()
	sb.bg_color      = Color(0.06, 0.06, 0.14, 0.85)
	sb.border_color  = Color(0.80, 0.80, 1.00, 0.85)
	sb.border_width_left = 3; sb.border_width_right  = 3
	sb.border_width_top  = 3; sb.border_width_bottom = 3
	sb.set_corner_radius_all(0)
	sb.shadow_color  = Color(0, 0, 0, 0.60)
	sb.shadow_size   = 4
	sb.shadow_offset = Vector2(4, 4)
	b.add_theme_stylebox_override("normal", sb)
	var sbp := sb.duplicate() as StyleBoxFlat
	sbp.bg_color    = Color(0.22, 0.22, 0.42, 1.0)
	sbp.shadow_size = 1; sbp.shadow_offset = Vector2(1, 1)
	b.add_theme_stylebox_override("hover",   sbp)
	b.add_theme_stylebox_override("pressed", sbp)
	b.add_theme_stylebox_override("focus",   StyleBoxFlat.new())
	b.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	return b
