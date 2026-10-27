extends Control

@onready var manual: Control = $PanelManual

const PIXEL_FONT_PATH := "res://fonts/PixelOperator8.ttf"

const C_BG         := Color(0.050, 0.018, 0.025)
const C_RED        := Color(0.750, 0.135, 0.110)
const C_RED_HOVER  := Color(0.900, 0.230, 0.175)
const C_RED_PRESS  := Color(0.560, 0.095, 0.075)
const C_DARK_BTN   := Color(0.120, 0.055, 0.055)
const C_DARK_HOVER := Color(0.200, 0.090, 0.085)
const C_WHITE      := Color(1, 1, 1)
const C_GRAY       := Color(0.65, 0.65, 0.65)

var _logo: Control
var _settings_panel: Control

const LOGO_PATH := "res://assets/ui/logo.png"

# Sito del gioco (privacy + supporto). Aperto nel BROWSER esterno tramite
# un intent di sistema.
const SITE_URL := "https://gabripizzo987.github.io/basta-un-quarto-dora/"

func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	manual.visible = false

	# Nascondi tutti i nodi preesistenti della vecchia scena (Label, Button ecc.)
	for child in get_children():
		if child != manual:
			child.visible = false

	_build_ui()
	_animate_intro()
	AudioManager.play_music("menu")

# ── Build ─────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var vp := get_viewport().get_visible_rect().size

	# Sfondo scuro
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = C_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Particelle fluttuanti
	_spawn_particles(vp)

	# Barre decorative
	_add_bar(Vector2(0, 0),          Vector2(vp.x, 5), C_RED)
	_add_bar(Vector2(0, vp.y - 5),   Vector2(vp.x, 5), C_RED)
	_add_bar(Vector2(0, 0),          Vector2(5, vp.y),  Color(C_RED.r, C_RED.g, C_RED.b, 0.4))

	# Container centrale
	var center := VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 18)
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.offset_left   = -220
	center.offset_top    = -210
	center.offset_right  =  220
	center.offset_bottom =  210
	add_child(center)

	# Logo goccia + croce (immagine). Fallback alla croce testo se manca il file.
	_logo = _make_logo(128)
	var logo_wrap := CenterContainer.new()
	logo_wrap.add_child(_logo)
	center.add_child(logo_wrap)

	# Titolo
	center.add_child(_label("BASTA UN QUARTO D'ORA", 30, C_WHITE, true))

	# Sottotitolo
	center.add_child(_label("Un gioco educativo sulla donazione del sangue", 14, C_GRAY, true))

	# Separatore rosso
	var sep_wrap := CenterContainer.new()
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(260, 2)
	sep.color = C_RED
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sep_wrap.add_child(sep)
	center.add_child(sep_wrap)

	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 10)
	center.add_child(sp)

	# Bottone INIZIA
	var btn_start := _button("▶   INIZIA", C_RED, C_RED_HOVER, C_RED_PRESS, 280, 62, 21)
	center.add_child(btn_start)
	btn_start.pressed.connect(_on_button_pressed)
	btn_start.mouse_entered.connect(func(): AudioManager.play_sfx("btn_hover"))

	# Bottone Gruppi sanguigni
	var btn_gruppi := _button("Gruppi sanguigni", C_DARK_BTN, C_DARK_HOVER, C_DARK_BTN.darkened(0.15), 280, 62, 21)
	center.add_child(btn_gruppi)
	btn_gruppi.pressed.connect(_on_btn_gruppi_pressed)
	btn_gruppi.mouse_entered.connect(func(): AudioManager.play_sfx("btn_hover"))

	# Bottone Sito web (apre il browser: privacy + supporto). Stesso stile degli altri.
	# Metodo con nome (niente lambda → sicuro su export Android).
	# Sito web + Classifica affiancati, per non allungare la colonna.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	center.add_child(row)

	var btn_sito := _button("Sito web", C_DARK_BTN, C_DARK_HOVER, C_DARK_BTN.darkened(0.15), 200, 62, 19)
	row.add_child(btn_sito)
	btn_sito.pressed.connect(_on_btn_sito_pressed)
	btn_sito.mouse_entered.connect(_play_btn_hover)

	# Bottone Classifica mondiale (Google Play Games). Se non hai fatto
	# l'accesso, premendolo te lo chiede.
	var btn_classifica := _button("Classifica", C_DARK_BTN, C_DARK_HOVER, C_DARK_BTN.darkened(0.15), 200, 62, 19)
	row.add_child(btn_classifica)
	btn_classifica.pressed.connect(_on_btn_classifica_pressed)
	btn_classifica.mouse_entered.connect(_play_btn_hover)
	btn_classifica.visible = PlayGames.is_available()

	# Record personale (salvato sul telefono), in basso al centro
	# Record personali per difficolta' (solo quelli gia' fatti)
	var rec_parts: Array[String] = []
	for d in RunState.DIFFICULTY_NAMES.size():
		if PlayGames.best_for(d) > 0:
			rec_parts.append("%s %d" % [RunState.DIFFICULTY_NAMES[d].capitalize(), PlayGames.best_for(d)])
	if not rec_parts.is_empty():
		var rec := _label("Record:  " + "   ".join(rec_parts), 14, C_GRAY, true)
		rec.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		rec.offset_left = -300
		rec.offset_right = 300
		rec.offset_top = -44
		rec.offset_bottom = -16
		rec.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rec)

	# Bottone Impostazioni (ingranaggio, in alto a destra)
	var btn_settings := _button("⚙", Color(0.10, 0.05, 0.05), Color(0.20, 0.08, 0.08), Color(0.07, 0.03, 0.03), 64, 64, 30)
	btn_settings.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn_settings.offset_left   = -92
	btn_settings.offset_top    = 10
	btn_settings.offset_right  = -24
	btn_settings.offset_bottom = 76
	add_child(btn_settings)
	btn_settings.pressed.connect(_on_settings_pressed)

	# Pannello impostazioni (inizialmente nascosto)
	_settings_panel = _build_settings_panel(vp)
	_settings_panel.visible = false
	add_child(_settings_panel)

	# Il manuale e gli eventuali nodi vecchi rimangono in fondo ma nascosti
	manual.move_to_front()
	_settings_panel.move_to_front()

func _add_bar(pos: Vector2, size: Vector2, color: Color) -> void:
	var r := ColorRect.new()
	r.position = pos
	r.size = size
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)

func _label(text: String, size: int, color: Color, centered: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pf := load(PIXEL_FONT_PATH)
	if pf:
		l.add_theme_font_override("font", pf)
	return l

func _make_logo(sz: float) -> Control:
	# Usa l'immagine logo se esiste, altrimenti croce testo (fallback sicuro).
	if ResourceLoader.exists(LOGO_PATH):
		var tex := load(LOGO_PATH)
		if tex is Texture2D:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.custom_minimum_size = Vector2(sz, sz)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			return tr
	return _label("✚", 64, C_RED, true)

func _button(text: String, nc: Color, hc: Color, pc: Color, w: float, h: float, fs: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(w, h)
	btn.focus_mode = Control.FOCUS_NONE
	for pair in [[&"normal", nc], [&"hover", hc], [&"pressed", pc]]:
		var sbox := StyleBoxFlat.new()
		sbox.bg_color = pair[1] as Color
		sbox.set_corner_radius_all(12)
		if pair[0] == &"normal":
			sbox.border_width_left = 1; sbox.border_width_top = 1
			sbox.border_width_right = 1; sbox.border_width_bottom = 1
			sbox.border_color = nc.lightened(0.25)
		btn.add_theme_stylebox_override(pair[0], sbox)
	btn.add_theme_stylebox_override("focus", StyleBoxFlat.new())
	btn.add_theme_color_override("font_color", C_WHITE)
	btn.add_theme_font_size_override("font_size", fs)
	var pf := load(PIXEL_FONT_PATH)
	if pf:
		btn.add_theme_font_override("font", pf)
	return btn

# ── Pannello Impostazioni ─────────────────────────────────────────────────────

func _build_settings_panel(vp: Vector2) -> Control:
	# Overlay scuro semitrasparente
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.75)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	# Box centrale
	var box := PanelContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left   = -200
	box.offset_top    = -160
	box.offset_right  =  200
	box.offset_bottom =  160
	var box_style := StyleBoxFlat.new()
	box_style.bg_color = Color(0.09, 0.04, 0.04)
	box_style.set_corner_radius_all(14)
	box_style.border_width_left = 2; box_style.border_width_top = 2
	box_style.border_width_right = 2; box_style.border_width_bottom = 2
	box_style.border_color = C_RED
	box.add_theme_stylebox_override("panel", box_style)
	overlay.add_child(box)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 22)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.add_child(vbox)
	box.add_child(margin)

	# Titolo
	var title := _label("⚙  Impostazioni", 20, C_WHITE, false)
	vbox.add_child(title)

	# Separatore
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 2)
	sep.color = C_RED
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	# Slider Musica
	vbox.add_child(_label("🎵  Musica", 15, C_GRAY, false))
	var slider_music := _slider(AudioManager._music_vol)
	slider_music.value_changed.connect(func(v): AudioManager.set_music_volume(v))
	vbox.add_child(slider_music)

	# Slider Effetti
	vbox.add_child(_label("🔊  Effetti sonori", 15, C_GRAY, false))
	var slider_sfx := _slider(AudioManager._sfx_vol)
	slider_sfx.value_changed.connect(func(v): AudioManager.set_sfx_volume(v))
	vbox.add_child(slider_sfx)

	# Bottone Chiudi
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(sp)
	var btn_close := _button("Chiudi", C_RED, C_RED_HOVER, C_RED_PRESS, 160, 44, 16)
	var center_wrap := CenterContainer.new()
	center_wrap.add_child(btn_close)
	vbox.add_child(center_wrap)
	btn_close.pressed.connect(func(): _settings_panel.visible = false)

	return overlay

func _slider(initial: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = initial
	s.custom_minimum_size = Vector2(0, 28)
	return s

# ── Particelle ────────────────────────────────────────────────────────────────

func _spawn_particles(vp: Vector2) -> void:
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(host)
	for i in 28:
		var dot := ColorRect.new()
		var sz := randf_range(3.0, 9.0)
		dot.size = Vector2(sz, sz)
		dot.color = Color(C_RED.r, C_RED.g, C_RED.b, randf_range(0.12, 0.45))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.position = Vector2(randf() * vp.x, randf() * vp.y)
		host.add_child(dot)
		var dur := randf_range(12.0, 26.0)
		var tw  := create_tween().set_loops()
		tw.set_parallel(true)
		tw.tween_property(dot, "position:x", dot.position.x + randf_range(-90.0, 90.0), dur)
		tw.tween_property(dot, "position:y", dot.position.y - randf_range(160.0, 520.0), dur)
		tw.tween_property(dot, "modulate:a", 0.0, dur * 0.75)

# ── Animazioni ────────────────────────────────────────────────────────────────

func _animate_intro() -> void:
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.85)
	tw.finished.connect(func():
		if is_instance_valid(_logo):
			var tw2 := create_tween().set_loops()
			tw2.tween_property(_logo, "modulate:a", 0.45, 1.3)
			tw2.tween_property(_logo, "modulate:a", 1.0,  1.3)
	)

# ── Handlers ──────────────────────────────────────────────────────────────────

func _on_button_pressed() -> void:
	AudioManager.play_sfx("btn_click")
	_show_difficulty_panel()


# ── Scelta difficolta' ───────────────────────────────────────────────────────

var _difficulty_panel: Control = null

const DIFFICULTY_INFO := [
	["FACILE", "Puzzle piccoli e più tempo"],
	["MEDIO", "L'esperienza classica"],
	["DIFFICILE", "Puzzle grandi, poco tempo"],
]

func _show_difficulty_panel() -> void:
	if is_instance_valid(_difficulty_panel):
		_difficulty_panel.queue_free()
	_difficulty_panel = _build_difficulty_panel()
	add_child(_difficulty_panel)
	_difficulty_panel.move_to_front()


func _build_difficulty_panel() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	var box := PanelContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -230
	box.offset_right = 230
	box.offset_top = -230
	box.offset_bottom = 230
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.09, 0.04, 0.04)
	st.set_corner_radius_all(14)
	st.border_width_left = 2; st.border_width_top = 2
	st.border_width_right = 2; st.border_width_bottom = 2
	st.border_color = C_RED
	box.add_theme_stylebox_override("panel", st)
	overlay.add_child(box)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 30)
	for side in ["margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 22)
	box.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	vbox.add_child(_label("SCEGLI LA DIFFICOLTÀ", 20, C_WHITE, true))
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 2)
	sep.color = C_RED
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	for i in DIFFICULTY_INFO.size():
		var selected: bool = i == RunState.difficulty
		var nc: Color = C_RED if selected else C_DARK_BTN
		var hc: Color = C_RED_HOVER if selected else C_DARK_HOVER
		var btn := _button(DIFFICULTY_INFO[i][0], nc, hc, nc.darkened(0.15), 360, 56, 20)
		btn.pressed.connect(_on_difficulty_chosen.bind(i))
		btn.mouse_entered.connect(_play_btn_hover)
		var wrap := CenterContainer.new()
		wrap.add_child(btn)
		vbox.add_child(wrap)
		vbox.add_child(_label(DIFFICULTY_INFO[i][1], 13, C_GRAY, true))

	var back := _button("Indietro", C_DARK_BTN, C_DARK_HOVER, C_DARK_BTN.darkened(0.15), 160, 40, 15)
	back.pressed.connect(_on_difficulty_back)
	var back_wrap := CenterContainer.new()
	back_wrap.add_child(back)
	vbox.add_child(back_wrap)
	return overlay


func _on_difficulty_back() -> void:
	AudioManager.play_sfx("btn_click")
	if is_instance_valid(_difficulty_panel):
		_difficulty_panel.queue_free()
	_difficulty_panel = null


func _on_difficulty_chosen(d: int) -> void:
	AudioManager.play_sfx("btn_click")
	RunState.set_difficulty(d)
	if is_instance_valid(_difficulty_panel):
		_difficulty_panel.queue_free()
	_difficulty_panel = null
	_start_game()


func _start_game() -> void:
	RunState.reset_run_state()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	await tw.finished
	get_tree().change_scene_to_file("res://scenes/rooms/AcceptanceRoom.tscn")

func _on_btn_gruppi_pressed() -> void:
	AudioManager.play_sfx("page_turn")
	manual.visible = true

func _on_btn_sito_pressed() -> void:
	# Apre il sito nel browser esterno (privacy + supporto). Su Android usa un
	# intent di sistema: non richiede il permesso internet dell'app.
	AudioManager.play_sfx("btn_click")
	OS.shell_open(SITE_URL)

func _on_btn_classifica_pressed() -> void:
	AudioManager.play_sfx("btn_click")
	PlayGames.show_leaderboard()

func _play_btn_hover() -> void:
	AudioManager.play_sfx("btn_hover")

func _on_settings_pressed() -> void:
	AudioManager.play_sfx("btn_click")
	_settings_panel.visible = true

func _on_ManualClose_pressed() -> void:
	AudioManager.play_sfx("page_turn")
	manual.visible = false
