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

var _continue_row: HBoxContainer = null

const EXTRA_PADDING_Y := 34.0
const MIN_PANEL_H := 170.0
const MAX_PANEL_H := 460.0

# Dimensioni "da dito": su telefono i pulsanti piccoli erano difficili da premere.
const TITLE_SIZE := 24
const BODY_SIZE := 20
const BUTTON_FONT_SIZE := 22
const BUTTON_H := 58.0
const CONTINUE_W := 220.0

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
	buttons_row.add_theme_constant_override("separation", 20)

	# margini extra sotto (così i bottoni non toccano il bordo)
	var margin := $Margin
	if margin and margin is MarginContainer:
		margin.add_theme_constant_override("margin_left", 22)
		margin.add_theme_constant_override("margin_right", 22)
		margin.add_theme_constant_override("margin_top", 16)
		margin.add_theme_constant_override("margin_bottom", 24)

	# testi piu' grandi
	title_label.add_theme_font_size_override("font_size", TITLE_SIZE)
	body_label.add_theme_font_size_override("normal_font_size", BODY_SIZE)
	root.add_theme_constant_override("separation", 12)

	# l'area interna riempie tutto il pannello (prima era 40x40: il testo
	# andava a capo a meta' e i pulsanti venivano tagliati)
	if margin is Control:
		(margin as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# "Continua" grande, in basso a destra (accanto al titolo non ci stava)
	_continue_row = HBoxContainer.new()
	_continue_row.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(_continue_row)
	continue_button.reparent(_continue_row, false)
	continue_button.custom_minimum_size = Vector2(CONTINUE_W, BUTTON_H)
	continue_button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	continue_button.focus_mode = Control.FOCUS_NONE
	_style_pill_button(continue_button, Color("#2F6FED"))
	continue_button.custom_minimum_size = Vector2(CONTINUE_W, BUTTON_H)
	_continue_row.visible = false

	_style_decision_buttons()

func _style_decision_buttons() -> void:
	_style_pill_button(accept_button, Color("#2ECC71"))
	_style_pill_button(reject_button, Color("#E74C3C"))

	for b in [accept_button, reject_button]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_stretch_ratio = 1.0
		b.custom_minimum_size = Vector2(0, BUTTON_H)
		b.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)

func _style_pill_button(b: Button, base_color: Color) -> void:
	if b == null:
		return

	b.custom_minimum_size = Vector2(200, BUTTON_H)
	b.focus_mode = Control.FOCUS_NONE

	var pad_x := 24
	var pad_y := 10

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

func _set_continue_visible(v: bool) -> void:
	continue_button.visible = v
	if _continue_row != null:
		_continue_row.visible = v


func show_wait(title: String, body: String) -> void:
	title_label.text = title
	body_label.text = body
	_set_continue_visible(false)
	buttons_row.hide()
	show()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.12)
	_auto_resize_to_body()

func show_continue(title: String, body: String) -> void:
	title_label.text = title
	body_label.text = body
	buttons_row.hide()
	_set_continue_visible(true)
	show()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.12)
	_auto_resize_to_body()

func show_decision(title: String, body: String) -> void:
	title_label.text = title
	body_label.text = body
	_set_continue_visible(false)
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

	# altezza reale: tutto il contenuto (titolo, testo a capo, pulsanti) + margini
	var wanted: float = root.get_combined_minimum_size().y + 16.0 + 24.0 + 6.0
	wanted = clamp(wanted, MIN_PANEL_H, MAX_PANEL_H)

	custom_minimum_size.y = wanted
	# il pannello e' ancorato in basso e cresce verso l'alto
	offset_top = offset_bottom - wanted
