extends Control

const PIXEL_FONT_PATH := "res://fonts/PixelOperator8.ttf"

# Auto-fit del font del corpo: ogni pagina sceglie il font più grande che
# entra senza tagliare il testo. Alza il MAX per riempire ancora di più le
# pagine con poco testo; il MIN evita che le pagine piene diventino illeggibili.
const MANUAL_BODY_FONT_MAX := 24
const MANUAL_BODY_FONT_MIN := 11

# Dimensione del titolo del manuale (es. "Manuale idoneità donatore").
const MANUAL_TITLE_FONT_SIZE := 22

# Spazio (px) tra la colonna di sinistra e quella di destra nelle pagine.
# Più alto = le due pagine si allontanano dal dorso, la destra respira di più.
const PAGES_COLUMN_GAP := 96

# Geometria della PERGAMENA dentro il libro (frazioni del pannello), così il
# testo resta dentro l'area color pergamena e non finisce su telaio/bottoni.
# Misurate sul PNG (pergamena ~0.083..0.912 in verticale) con un po' di padding.
const PARCH_TOP    := 0.15   # bordo alto del testo (sotto il titolo)
const PARCH_BOTTOM := 0.88   # bordo basso del testo (sopra la cornice bassa)
const PARCH_SIDE   := 0.05   # margine laterale sinistro/destro

@onready var btn_prev: Button = $HBoxNav/ButtonPrev
@onready var btn_next: Button = $HBoxNav/ButtonNext
@onready var label_page: Label = $HBoxNav/LabelPage
@onready var btn_close: Button = $ButtonCloseManual
@onready var label_title: Label = get_node_or_null("LabelTitle")

var player: Node = null
var _player_was_movable: bool = true
var _is_open: bool = false   # guard: evita open/close ridondanti (anti-blocco da mash)

var pages: Array[Control] = []
var page_index: int = 0

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player")

	pages.clear()
	for c in get_children():
		if c is Control and String(c.name).begins_with("PagesRow"):
			pages.append(c)

	pages.sort_custom(func(a, b): return String(a.name) < String(b.name))

	if pages.is_empty():
		push_error("PanelManual: nessuna pagina trovata (PagesRow...)")
		return

	# Rifinisce il testo di tutte le pagine: centrato in verticale (niente buchi
	# in fondo quando il testo è poco) + interlinea ariosa + parole intere a capo.
	_polish_pages()

	# Titolo del manuale: più grande e ben leggibile (era troppo piccolo).
	_polish_title()

	# pannello leggermente più grande
	custom_minimum_size = Vector2(880, 560)

	# stile pixel per i 3 bottoni
	_pixel_btn(btn_prev,  "◀",        Vector2(80, 58))
	_pixel_btn(btn_next,  "▶",        Vector2(80, 58))
	_pixel_btn(btn_close, "✕  CHIUDI", Vector2(160, 58))

	label_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_page.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER

	btn_prev.pressed.connect(_on_prev_pressed)
	btn_next.pressed.connect(_on_next_pressed)
	btn_close.pressed.connect(_on_close_pressed)

	visible = false
	show_page(0)


func _pixel_btn(b: Button, label: String, min_size: Vector2) -> void:
	b.text = label
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE

	if ResourceLoader.exists(PIXEL_FONT_PATH):
		var fnt := load(PIXEL_FONT_PATH)
		if fnt is Font:
			b.add_theme_font_override("font", fnt)
	b.add_theme_font_size_override("font_size", 22)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.14, 0.92)
	sb.border_color = Color(0.75, 0.75, 1.00, 0.90)
	sb.border_width_left   = 3
	sb.border_width_right  = 3
	sb.border_width_top    = 3
	sb.border_width_bottom = 3
	sb.set_corner_radius_all(0)
	sb.shadow_color  = Color(0, 0, 0, 0.55)
	sb.shadow_size   = 3
	sb.shadow_offset = Vector2(3, 3)
	b.add_theme_stylebox_override("normal", sb)

	var sbp := sb.duplicate() as StyleBoxFlat
	sbp.bg_color     = Color(0.20, 0.20, 0.42, 1.0)
	sbp.shadow_size   = 1
	sbp.shadow_offset = Vector2(1, 1)
	b.add_theme_stylebox_override("hover",    sbp)
	b.add_theme_stylebox_override("pressed",  sbp)

	var sbd := sb.duplicate() as StyleBoxFlat
	sbd.bg_color = Color(0.04, 0.04, 0.09, 0.50)
	sbd.border_color = Color(0.4, 0.4, 0.5, 0.40)
	b.add_theme_stylebox_override("disabled", sbd)
	b.add_theme_stylebox_override("focus",    StyleBoxFlat.new())

	b.add_theme_color_override("font_color",          Color(0.95, 0.95, 1.0))
	b.add_theme_color_override("font_disabled_color", Color(0.4,  0.4,  0.5))

func open_manual() -> void:
	# Guard: se è GIÀ aperto e visibile, ignora. Evita di ri-salvare
	# can_move=false e restare bloccati alla chiusura quando si premono
	# tanti tasti. La condizione "and visible" permette comunque di
	# riaprire se un altro script ha nascosto il pannello direttamente.
	if _is_open and visible:
		return
	_is_open = true

	AudioManager.play_sfx("manual_open")
	visible = true
	show_page(0)

	# Togli il focus al ButtonManual: così spazio/invio non lo ri-premono
	# mentre il manuale è aperto (il pannello lo copre ma il focus resta).
	if get_viewport() != null:
		get_viewport().gui_release_focus()

	# blocca movimento
	if player != null and player.has_method("set_can_move"):
		_player_was_movable = player.can_move
		player.set_can_move(false)

func close_manual() -> void:
	# Guard: chiudere quando è già chiuso non deve toccare lo stato del player.
	if not _is_open:
		visible = false
		return
	_is_open = false

	AudioManager.play_sfx("manual_close")
	visible = false

	# Rilascia il focus per evitare che il ButtonManual resti grigio/ri-attivabile
	# da spazio/invio (causa del blocco input).
	if get_viewport() != null:
		get_viewport().gui_release_focus()

	# sblocca movimento solo se era mobile prima dell'apertura
	if player != null and player.has_method("set_can_move"):
		player.set_can_move(_player_was_movable)

func show_page(i: int) -> void:
	if pages.is_empty():
		return

	if i < 0:
		i = 0
	if i > pages.size() - 1:
		i = pages.size() - 1
	page_index = i

	for p in pages:
		p.visible = false
	pages[page_index].visible = true
	# Ri-applica la rifinitura alla pagina ora visibile: solo da visibile il
	# container le assegna l'altezza reale, necessaria alla centratura verticale.
	_polish_one(pages[page_index])


func _polish_title() -> void:
	# Ingrandisce il titolo del manuale e lo allarga su tutta la pagina, centrato.
	# Vale per entrambe le scene (triage / emocromo) senza toccare i .tscn.
	if not is_instance_valid(label_title):
		return
	label_title.add_theme_font_size_override("font_size", MANUAL_TITLE_FONT_SIZE)
	label_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Allarga il label così il testo non viene tagliato a destra
	label_title.offset_left  = 60.0
	label_title.offset_right = 820.0
	# leggera ombra per staccarlo dalla pergamena
	label_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	label_title.add_theme_constant_override("shadow_offset_x", 1)
	label_title.add_theme_constant_override("shadow_offset_y", 2)


func _confine_to_parchment(row: Control) -> void:
	# Posiziona il container delle due colonne DENTRO la pergamena del libro.
	# Il libro (BookBG) riempie il pannello; la pergamena occupa in verticale
	# la fascia PARCH_TOP..PARCH_BOTTOM e in orizzontale PARCH_SIDE dai lati.
	# Ancoriamo il row full-rect e usiamo offset in px sul rettangolo del pannello.
	var panel_h := size.y
	var panel_w := size.x
	if panel_h <= 1.0:
		panel_h = 600.0
	if panel_w <= 1.0:
		panel_w = 1000.0
	row.anchor_left = 0.0
	row.anchor_top = 0.0
	row.anchor_right = 1.0
	row.anchor_bottom = 1.0
	row.offset_left   = panel_w * PARCH_SIDE
	row.offset_right  = -panel_w * PARCH_SIDE
	row.offset_top    = panel_h * PARCH_TOP
	row.offset_bottom = -panel_h * (1.0 - PARCH_BOTTOM)


func _polish_pages() -> void:
	for p in pages:
		_polish_one(p)


func _polish_one(p: Node) -> void:
	# Resa più pulita e "piena" di ogni RichTextLabel della pagina:
	#  - centratura verticale → il testo corto sta a metà pagina, niente buco sotto
	#  - interlinea leggermente più ariosa → riempie meglio e si legge meglio
	#  - word-wrap autonomo → le parole non si spezzano a metà
	var col := p as Control
	if col == null:
		return
	# Spazio tra colonna sinistra e destra: più ampio → le due pagine si
	# staccano dal dorso centrale e la destra respira (più leggibile).
	if col is HBoxContainer:
		col.add_theme_constant_override("separation", PAGES_COLUMN_GAP)
		# Confina l'area del testo DENTRO la pergamena visibile del libro.
		# La pergamena occupa in verticale ~8%..91% del pannello: se il testo
		# esce da lì finisce sul telaio/sotto i bottoni e viene tagliato.
		_confine_to_parchment(col)
	for child in col.get_children():
		var rt := child as RichTextLabel
		if rt == null:
			continue
		rt.fit_content = false
		rt.scroll_active = false
		rt.clip_contents = true
		rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rt.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		rt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rt.add_theme_constant_override("line_separation", 2)
		# Auto-fit a misura REALE: parte da _ready ma viene rifinito anche in
		# show_page (quando la pagina è visibile e ha l'altezza vera).
		call_deferred("_autofit_font", rt)


func _autofit_font(rt: RichTextLabel) -> void:
	# Sceglie il font più grande il cui testo RENDERIZZATO entra nell'altezza
	# della pagina. Misura get_content_height() reale a ogni dimensione (con un
	# re-layout tra un tentativo e l'altro) → niente sbordamento, mai tagliato.
	if not is_instance_valid(rt):
		return
	var avail_h := rt.size.y
	if avail_h <= 1.0:
		# layout non pronto: riprova al prossimo frame
		await get_tree().process_frame
		if not is_instance_valid(rt):
			return
		avail_h = rt.size.y
		if avail_h <= 1.0:
			return
	# margine prudente: un filo d'aria sopra/sotto, niente testo a filo bordo
	var budget := avail_h - 10.0
	var chosen := MANUAL_BODY_FONT_MIN
	for fs in range(MANUAL_BODY_FONT_MAX, MANUAL_BODY_FONT_MIN - 1, -1):
		rt.add_theme_font_size_override("normal_font_size", fs)
		await get_tree().process_frame      # forza il re-layout del RichTextLabel
		if not is_instance_valid(rt):
			return
		if rt.get_content_height() <= budget:
			chosen = fs
			break
	rt.add_theme_font_size_override("normal_font_size", chosen)

	label_page.text = "Pagina %d/%d" % [page_index + 1, pages.size()]
	btn_prev.disabled = (page_index == 0)
	btn_next.disabled = (page_index == pages.size() - 1)

func _on_prev_pressed() -> void:
	AudioManager.play_sfx("manual_page")
	show_page(page_index - 1)

func _on_next_pressed() -> void:
	AudioManager.play_sfx("manual_page")
	show_page(page_index + 1)

func _on_close_pressed() -> void:
	close_manual()

# Se hai collegato il ButtonManual a questa funzione, perfetto:
func _on_button_manual_pressed() -> void:
	open_manual()
