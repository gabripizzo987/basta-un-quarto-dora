extends Panel

signal continued
signal accepted
signal rejected

@onready var title_label: Label = $Margin/Root/Header/Title
@onready var body_label: RichTextLabel = $Margin/Root/Body

@onready var continue_button: Button = $Margin/Root/Header/ContinueButton

@onready var buttons_row: HBoxContainer = $Margin/Root/ButtonsRow
@onready var accept_button: Button = $Margin/Root/ButtonsRow/AcceptButton
@onready var reject_button: Button = $Margin/Root/ButtonsRow/RejectButton

@onready var root: Control = $Margin/Root
@onready var header: Control = $Margin/Root/Header

const EXTRA_PADDING_Y := 26.0      
const MIN_PANEL_H := 150.0         
const MAX_PANEL_H := 420.0    

func _ready() -> void:
	hide()

	continue_button.pressed.connect(_on_continue_pressed)
	accept_button.pressed.connect(_on_accept_pressed)
	reject_button.pressed.connect(_on_reject_pressed)

	# --- FIX LAYOUT: testo wrappa + pannello cresce ---
	body_label.bbcode_enabled = false
	body_label.fit_content = true
	body_label.scroll_active = false
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	buttons_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons_row.size_flags_vertical = Control.SIZE_SHRINK_END
	buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_row.add_theme_constant_override("separation", 12)

	# margini extra sotto (così i bottoni non toccano il bordo)
	var margin := $Margin
	if margin and margin is MarginContainer:
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_right", 16)
		margin.add_theme_constant_override("margin_top", 12)
		margin.add_theme_constant_override("margin_bottom", 24)

	_style_decision_buttons()

func _style_decision_buttons() -> void:
	_style_pill_button(accept_button, Color("#2ECC71"))
	_style_pill_button(reject_button, Color("#E74C3C"))

	for b in [accept_button, reject_button]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_stretch_ratio = 1.0
		b.custom_minimum_size = Vector2(0, 34)

func _style_pill_button(b: Button, base_color: Color) -> void:
	if b == null:
		return

	b.custom_minimum_size = Vector2(140, 34)
	b.focus_mode = Control.FOCUS_NONE

	var pad_x := 20
	var pad_y := 6

	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = base_color
	sb_normal.corner_radius_top_left = 16
	sb_normal.corner_radius_top_right = 16
	sb_normal.corner_radius_bottom_left = 16
	sb_normal.corner_radius_bottom_right = 16
	sb_normal.content_margin_left = pad_x
	sb_normal.content_margin_right = pad_x
	sb_normal.content_margin_top = pad_y
	sb_normal.content_margin_bottom = pad_y

	var sb_hover: StyleBoxFlat = sb_normal.duplicate()
	sb_hover.bg_color = base_color.lightened(0.10)

	var sb_pressed: StyleBoxFlat = sb_normal.duplicate()
	sb_pressed.bg_color = base_color.darkened(0.10)

	var sb_disabled: StyleBoxFlat = sb_normal.duplicate()
	sb_disabled.bg_color = base_color.darkened(0.45)

	b.add_theme_stylebox_override("normal", sb_normal)
	b.add_theme_stylebox_override("hover", sb_hover)
	b.add_theme_stylebox_override("pressed", sb_pressed)
	b.add_theme_stylebox_override("disabled", sb_disabled)

	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("#BBBBBB"))

func show_wait(title: String, body: String) -> void:
	title_label.text = title
	body_label.text = body
	continue_button.hide()
	buttons_row.hide()
	show()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.12)
	_auto_resize_to_body()

func show_continue(title: String, body: String) -> void:
	title_label.text = title
	body_label.text = body
	buttons_row.hide()
	continue_button.show()
	show()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.12)
	_auto_resize_to_body()

func show_decision(title: String, body: String) -> void:
	title_label.text = title
	body_label.text = body
	continue_button.hide()
	buttons_row.show()
	show()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.12)
	_auto_resize_to_body()

func hide_panel() -> void:
	hide()

func _on_continue_pressed() -> void:
	hide()
	emit_signal("continued")

func _on_accept_pressed() -> void:
	hide()
	emit_signal("accepted")

func _on_reject_pressed() -> void:
	hide()
	emit_signal("rejected")

func _auto_resize_to_body() -> void:
	# aspetta 1 frame: così Godot calcola wrap + layout
	await get_tree().process_frame

	# forza layout del body (non cambia nulla se già settato)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	# altezza reale del testo wrappato (RichTextLabel)
	var body_h: float = body_label.get_content_height()

	var header_h: float = header.size.y
	var buttons_h: float = buttons_row.size.y if buttons_row.visible else 0.0

	var wanted: float = header_h + body_h + buttons_h + EXTRA_PADDING_Y
	wanted = clamp(wanted, MIN_PANEL_H, MAX_PANEL_H)

	custom_minimum_size.y = wanted
