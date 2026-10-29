extends RefCounted
## Stile unico dei pannelli del gioco (modello: pannello "Benvenuto al Centro
## Trasfusionale"). Usare queste funzioni per ogni nuovo pannello, cosi' tutte
## le stanze restano uguali.
##
## Uso:  const UiStyle := preload("res://scripts/UiStyle.gd")
##       UiStyle.style_panel(mio_pannello)

const FONT_PATH := "res://fonts/PixelOperator8.ttf"

const PANEL_BG     := Color(0.118, 0.118, 0.141)
const PANEL_BORDER := Color(0.227, 0.227, 0.275)
const TITLE        := Color(0.85, 0.0, 0.99)      # magenta
const TEXT         := Color(1, 1, 1)
const TEXT_MUTED   := Color(0.62, 0.62, 0.70)     # etichette ("Eta'", "Peso"...)
const BTN          := Color(0.184, 0.435, 0.929)  # blu
const BTN_HOVER    := Color(0.263, 0.500, 0.960)
const BTN_PRESSED  := Color(0.352, 0.566, 0.978)

const TITLE_SIZE := 26
const BODY_SIZE := 16


static func font() -> Font:
	if ResourceLoader.exists(FONT_PATH):
		return load(FONT_PATH)
	return null


static func _font_on(c: Control) -> void:
	var f := font()
	if f == null:
		return
	if c is RichTextLabel:
		c.add_theme_font_override("normal_font", f)
	else:
		c.add_theme_font_override("font", f)


static func panel_box(radius: int = 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = PANEL_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 8
	return sb


static func style_panel(p: Control, radius: int = 14) -> void:
	p.add_theme_stylebox_override("panel", panel_box(radius))


static func style_title(l: Label, size: int = TITLE_SIZE) -> void:
	_font_on(l)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", TITLE)


static func style_body(l: Control, size: int = BODY_SIZE, col: Color = TEXT) -> void:
	_font_on(l)
	if l is RichTextLabel:
		l.add_theme_font_size_override("normal_font_size", size)
		l.add_theme_color_override("default_color", col)
	else:
		l.add_theme_font_size_override("font_size", size)
		l.add_theme_color_override("font_color", col)
		l.add_theme_color_override("font_outline_color", Color.BLACK)


static func style_button(b: Button, size: int = BODY_SIZE) -> void:
	_font_on(b)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_pressed_color", TEXT)
	for pair in [["normal", BTN], ["hover", BTN_HOVER], ["pressed", BTN_PRESSED]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = pair[1]
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 18
		sb.content_margin_right = 18
		b.add_theme_stylebox_override(pair[0], sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE


## Pannello di riepilogo (es. "Stanza completata") gia' strutturato come
## Panel > MarginContainer > VBox: applica lo stile, poi adatta l'altezza
## al contenuto e lo centra, cosi' il pulsante non esce mai dal bordo.
static func fit_summary_panel(panel: Control, margin: Control, title: Label, body: Label, button: Button, width: float = 500.0) -> void:
	style_panel(panel)
	if title != null:
		style_title(title)
	if body != null:
		style_body(body)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(width - 40.0, 0)
	if button != null:
		style_button(button)
		button.custom_minimum_size = Vector2(220, 44)
	if margin is MarginContainer:
		for side in ["margin_left", "margin_right"]:
			margin.add_theme_constant_override(side, 20)
		for side in ["margin_top", "margin_bottom"]:
			margin.add_theme_constant_override(side, 18)

	# 1) pannello centrato con la larghezza giusta e il contenuto che lo riempie:
	#    cosi' Godot impagina il testo (a capo compreso) alla larghezza vera
	_place_centered(panel, width, panel.size.y if panel.size.y > 0 else 300.0)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.custom_minimum_size = Vector2.ZERO
	var was_alpha := panel.modulate.a
	panel.modulate.a = 0.0   # niente "salto" visibile mentre si misura

	# 2) dopo l'impaginazione misura l'altezza vera del contenuto
	var tree := panel.get_tree()
	if tree != null:
		await tree.process_frame
		await tree.process_frame
	if not is_instance_valid(panel):
		return
	var sz := margin.get_combined_minimum_size()
	var vp_h := panel.get_viewport_rect().size.y
	var w := maxf(width, sz.x)
	# mai piu' alto dello schermo: il pulsante deve restare sempre visibile
	var h := clampf(sz.y, 80.0, vp_h - 32.0)
	_place_centered(panel, w, h)
	panel.modulate.a = was_alpha if was_alpha > 0.0 else 1.0


static func _place_centered(panel: Control, w: float, h: float) -> void:
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -w * 0.5
	panel.offset_right = w * 0.5
	panel.offset_top = -h * 0.5
	panel.offset_bottom = h * 0.5


## Riordina un pannello gia' esistente (titolo opzionale, testo, pulsante)
## dentro margini e colonna verticale, con lo stile del gioco.
## I nodi vengono spostati, non ricreati: i segnali gia' collegati restano.
static func rebuild_panel(panel: Control, title_text: String, body: Label, button: Button, width: float) -> void:
	style_panel(panel)
	var margin := MarginContainer.new()
	margin.name = "UiMargin"
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	margin.add_child(vb)

	if title_text != "":
		var t := Label.new()
		t.text = title_text
		style_title(t, 22)
		vb.add_child(t)

	if body != null:
		body.reparent(vb, false)
		body.set_anchors_preset(Control.PRESET_TOP_LEFT)
		body.position = Vector2.ZERO
		body.custom_minimum_size = Vector2(width - 36, 0)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		style_body(body)

	if button != null:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
		vb.add_child(row)
		button.reparent(row, false)
		button.set_anchors_preset(Control.PRESET_TOP_LEFT)
		button.custom_minimum_size = Vector2(170, 44)
		style_button(button)

	# il pannello prende la dimensione del contenuto
	panel.custom_minimum_size = Vector2(width, 0)
	margin.reset_size()
	panel.size = Vector2(width, margin.get_combined_minimum_size().y)
