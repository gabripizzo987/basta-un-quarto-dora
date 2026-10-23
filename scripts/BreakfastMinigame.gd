extends Control

signal finished()

# ══════════════════════════════════════════════════════════════════════════════
#  CONSTANTS
# ══════════════════════════════════════════════════════════════════════════════

const PIXEL_FONT      := "res://fonts/PixelOperator8.ttf"
const GAME_DURATION   := 38.0
const DECAY_PER_SEC   := 0.07
const DECAY_WRONG     := 0.18
const COOLDOWN_AFTER  := 1.2
const TYPEWRITER_SPD  := 0.025

const ITEMS: Array = [
	{"name": "ACQUA",    "color": Color(0.18, 0.50, 0.95)},
	{"name": "SUCCO",    "color": Color(0.92, 0.52, 0.08)},
	{"name": "BISCOTTO", "color": Color(0.70, 0.42, 0.12)},
	{"name": "CAFFÈ",    "color": Color(0.33, 0.17, 0.05)},
]

const PHRASES: Array = [
	["Ho sete!\nAcqua per favore.", "Vorrei\ndell'acqua.", "Acqua, grazie!"],
	["Un succo\ndi frutta?", "Vorrei un succo!", "Succo, per favore!"],
	["Un biscotto?", "Ho un po' di fame.", "Biscottino, please!"],
	["Caffè leggero?", "Posso avere\nil caffè?", "Un caffè, grazie!"],
]

const INTRO_MSGS: Array = [
	"Ottimo lavoro!\nLa donazione e' completata.",
	"IMPORTANTE: dopo ogni donazione\ne' fondamentale bere subito!\nAcqua o succo di frutta.",
	"Mangia qualcosa di leggero:\nbiscotti, crackers o frutta.\nIl corpo deve recuperare!",
	"Resta seduto qualche minuto.\nEvita sforzi fisici per 24 ore.\nRimani idratato!",
	"Adesso aiuta i donatori!\nTrascinagli il rinfresco giusto\nprima che la barra si svuoti!",
]

const DONOR_SHEETS: Array = [
	"res://assets/characters/character-spritesheet.png",
	"res://assets/characters/character-spritesheet (3).png",
	"res://assets/characters/character-spritesheet (5).png",
	"res://assets/characters/character-spritesheet (6).png",
	"res://assets/characters/character-spritesheet (7).png",
]
const SPRITE_REGION := Rect2(128, 2048, 64, 64)

const DONOR_COLORS: Array = [
	Color(0.85, 0.28, 0.28),
	Color(0.28, 0.72, 0.42),
	Color(0.28, 0.52, 0.92),
	Color(0.90, 0.72, 0.18),
	Color(0.72, 0.35, 0.88),
]

const C_BG     := Color(0.04, 0.03, 0.08)
const C_ARENA  := Color(0.07, 0.05, 0.12)
const C_PANEL  := Color(0.06, 0.05, 0.02)
const C_BORDER := Color(0.85, 0.72, 0.20)
const C_GOLD   := Color(1.00, 0.85, 0.22)
const C_WHITE  := Color(1.00, 1.00, 1.00)
const C_GRAY   := Color(0.60, 0.58, 0.54)
const C_GREEN  := Color(0.22, 0.82, 0.28)
const C_RED_C  := Color(0.88, 0.20, 0.14)
const C_HP_OK  := Color(0.20, 0.78, 0.25)
const C_HP_WRN := Color(0.90, 0.74, 0.12)
const C_HP_BAD := Color(0.88, 0.20, 0.14)


# ══════════════════════════════════════════════════════════════════════════════
#  DONOR STATE
# ══════════════════════════════════════════════════════════════════════════════

class DonorState:
	var name:       String
	var color:      Color
	var sprite_idx: int   = 0
	var hp:         float = 0.70
	var request:    int   = -1
	var cooldown:   float = 0.0
	var card:       Control
	var hp_fill:    ColorRect
	var hp_max_w:   float = 100.0
	var bubble:     Control
	var bubble_lbl: Label
	var anim_tw:    Tween


# ══════════════════════════════════════════════════════════════════════════════
#  RUNTIME STATE
# ══════════════════════════════════════════════════════════════════════════════

var _donors:       Array = []
var _states:       Array = []
var _score:        int   = 0
var _served_total: int   = 0

enum Phase { INTRO, GAME, RESULT }
var _phase := Phase.INTRO

var _intro_idx:  int    = 0
var _text_done:  bool   = false
var _dial_lbl:   Label  = null
var _full_text:  String = ""

var _game_time:  float  = GAME_DURATION
var _game_active:bool   = false

var _drag_item:  int     = -1
var _drag_ghost: Control = null
var _item_cards: Array   = []

var _score_lbl:   Label     = null
var _timer_lbl:   Label     = null
var _timer_fill:  ColorRect = null
var _timer_max_w: float     = 0.0
var _req_lbl:     Label     = null

var _vp: Vector2 = Vector2.ZERO
var _pf: Font    = null
var _item_textures: Array = []

# Accumulatore per l'effetto typewriter — gestito in _process().
# NIENTE tween/lambda perché su Android export i lambda crashano spesso.
var _type_chars: float = 0.0


# ══════════════════════════════════════════════════════════════════════════════
#  SETUP / READY
# ══════════════════════════════════════════════════════════════════════════════

func setup(donors: Array) -> void:
	# Accetta sia Array[String] sia Array[Dictionary{name,sprite_idx}]
	_donors = donors.duplicate()
	if _donors.is_empty():
		_donors = [{"name": "Donatore", "sprite_idx": 0}]


func _ready() -> void:
	# Pixel font
	if ResourceLoader.exists(PIXEL_FONT):
		var f := load(PIXEL_FONT)
		if f is Font:
			_pf = f

	# ── DIMENSIONE: su CanvasLayer gli anchors non funzionano, impostiamo la size manualmente
	_vp = get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	size = _vp
	mouse_filter = Control.MOUSE_FILTER_STOP

	if _donors.is_empty():
		_donors = [{"name": "Donatore", "sprite_idx": 0}]

	# Genera le texture pixel-art PRIMA dell'intro (sicuro su Android export)
	_make_item_textures()

	_build_intro()


# ══════════════════════════════════════════════════════════════════════════════
#  INTRO
# ══════════════════════════════════════════════════════════════════════════════

func _build_intro() -> void:
	_phase = Phase.INTRO

	# Sfondo nero pieno
	var bg := ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size = _vp
	bg.color = C_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Titolo centrato in alto
	var title := _lbl("SALA COLAZIONE", 28, C_GOLD, true)
	title.position = Vector2(0, _vp.y * 0.12)
	title.size = Vector2(_vp.x, 40)
	add_child(title)

	# Separatore
	var sep := ColorRect.new()
	sep.color = C_BORDER
	sep.size = Vector2(_vp.x * 0.6, 2)
	sep.position = Vector2(_vp.x * 0.2, _vp.y * 0.12 + 48)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sep)

	# Box dialogo: larghezza generosa, centrato, nella metà bassa
	var box_w := minf(_vp.x - 60, 700.0)
	var box_h := _vp.y * 0.38
	var box_x := (_vp.x - box_w) * 0.5
	var box_y := _vp.y * 0.45

	var dbox := _make_panel(Vector2(box_x, box_y), Vector2(box_w, box_h), C_PANEL, C_BORDER, 3)
	add_child(dbox)

	var dm := MarginContainer.new()
	dm.position = Vector2(18, 14)
	dm.size = Vector2(box_w - 36, box_h - 60)
	dbox.add_child(dm)

	_dial_lbl = _lbl("", 22, C_WHITE, false)
	_dial_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dial_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dial_lbl.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	dm.add_child(_dial_lbl)

	# "▼ tocca per continuare" lampeggiante in basso a destra del box
	var tap := _lbl("▼  tocca per continuare", 14, C_GOLD, false)
	tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tap.position = Vector2(12, box_h - 36)
	tap.size = Vector2(box_w - 24, 26)
	dbox.add_child(tap)
	var blink := tap.create_tween().set_loops()
	blink.tween_property(tap, "modulate:a", 0.15, 0.55)
	blink.tween_property(tap, "modulate:a", 1.00, 0.55)

	# Bottone invisibile a tutto schermo — dimensioni ESPLICITE (no anchors preset).
	# Button.pressed gestisce nativamente touch+mouse, si attiva UNA volta per tap
	# (niente frame-guard) ed è il metodo di input più affidabile su Android.
	# Colleghiamo un METODO CON NOME, non un lambda (i lambda crashano su export).
	var adv := Button.new()
	adv.position = Vector2.ZERO
	adv.size = _vp
	adv.focus_mode = Control.FOCUS_NONE
	adv.mouse_filter = Control.MOUSE_FILTER_STOP
	var empty := StyleBoxEmpty.new()
	adv.add_theme_stylebox_override("normal", empty)
	adv.add_theme_stylebox_override("hover", empty)
	adv.add_theme_stylebox_override("pressed", empty)
	adv.add_theme_stylebox_override("focus", empty)
	adv.add_theme_stylebox_override("disabled", empty)
	add_child(adv)
	adv.pressed.connect(_on_intro_advance)

	_show_intro_msg()


func _show_intro_msg() -> void:
	if _intro_idx >= INTRO_MSGS.size():
		_phase = Phase.GAME   # blocca subito altri tap prima che _start_game giri
		_clear_children()
		call_deferred("_start_game")
		return

	_full_text = INTRO_MSGS[_intro_idx]
	_text_done = false
	_type_chars = 0.0
	if is_instance_valid(_dial_lbl):
		_dial_lbl.text = ""
	# Il typewriter viene animato in _process() (niente tween/lambda → no crash)


func _on_intro_advance() -> void:
	if _phase != Phase.INTRO:
		return
	# 1° tap: completa subito il testo. 2° tap: passa al messaggio successivo.
	if not _text_done:
		_text_done = true
		_type_chars = float(_full_text.length())
		if is_instance_valid(_dial_lbl):
			_dial_lbl.text = _full_text
		return
	_intro_idx += 1
	_show_intro_msg()


func _clear_children() -> void:
	for c in get_children():
		c.queue_free()


# ══════════════════════════════════════════════════════════════════════════════
#  GAME BUILD
# ══════════════════════════════════════════════════════════════════════════════

func _start_game() -> void:
	_phase = Phase.GAME
	_game_time  = GAME_DURATION
	_game_active = true
	# Le texture sono già pronte (generate in _ready)

	_states.clear()
	randomize()
	for i in _donors.size():
		var ds := DonorState.new()
		var entry = _donors[i]
		if entry is Dictionary:
			ds.name       = (entry.get("name", "Donatore") as String).to_upper()
			ds.sprite_idx = int(entry.get("sprite_idx", i % DONOR_SHEETS.size()))
		else:
			ds.name       = (str(entry)).to_upper()
			ds.sprite_idx = i % DONOR_SHEETS.size()
		ds.color    = DONOR_COLORS[i % DONOR_COLORS.size()]
		ds.hp       = randf_range(0.55, 0.80)
		ds.cooldown = randf_range(0.3, 1.2)
		_states.append(ds)

	_build_game_ui()


func _build_game_ui() -> void:
	var W := _vp.x
	var H := _vp.y

	# ── Sfondi ────────────────────────────────────────────────────────────────
	var arena_h := H * 0.61

	var bg_full := ColorRect.new()
	bg_full.position = Vector2.ZERO
	bg_full.size = Vector2(W, H)
	bg_full.color = C_BG
	bg_full.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_full)

	var bg_arena := ColorRect.new()
	bg_arena.position = Vector2.ZERO
	bg_arena.size = Vector2(W, arena_h)
	bg_arena.color = C_ARENA
	bg_arena.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_arena)

	# Separatore oro
	var sep := ColorRect.new()
	sep.position = Vector2(0, arena_h)
	sep.size = Vector2(W, 4)
	sep.color = C_BORDER
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sep)

	# ── Top bar timer + punti ──────────────────────────────────────────────────
	var top_h := 44.0
	var top_bg := ColorRect.new()
	top_bg.position = Vector2.ZERO
	top_bg.size = Vector2(W, top_h)
	top_bg.color = Color(0.02, 0.01, 0.06)
	top_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_bg)

	_timer_max_w = W * 0.46
	var tbg := ColorRect.new()
	tbg.position = Vector2(10, 9)
	tbg.size = Vector2(_timer_max_w, 26)
	tbg.color = Color(0.12, 0.09, 0.05)
	tbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tbg)

	_timer_fill = ColorRect.new()
	_timer_fill.position = Vector2(10, 9)
	_timer_fill.size = Vector2(_timer_max_w, 26)
	_timer_fill.color = C_HP_OK
	_timer_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_timer_fill)

	_timer_lbl = _lbl("70s", 16, C_WHITE, false)
	_timer_lbl.position = Vector2(16, 11)
	add_child(_timer_lbl)

	_score_lbl = _lbl("PUNTI: 0", 18, C_GOLD, false)
	_score_lbl.position = Vector2(W * 0.55, 11)
	add_child(_score_lbl)

	# ── Donor cards in arena ──────────────────────────────────────────────────
	var n := _states.size()
	var margin_sides := 24.0
	var gap := 12.0
	var card_w := (W - margin_sides * 2.0 - gap * (n - 1)) / float(n)
	card_w = minf(card_w, 160.0)
	var total_w := card_w * n + gap * (n - 1)
	var start_x := (W - total_w) * 0.5
	var card_y := top_h + 112.0         # riserva spazio per le bubble (più grandi) sopra
	var card_h := arena_h - card_y - 8.0

	for i in n:
		var ds: DonorState = _states[i]
		var cx := start_x + i * (card_w + gap)
		ds.card = _build_donor_card(ds, Vector2(cx, card_y), Vector2(card_w, card_h))
		add_child(ds.card)

	# ── Bottom: dialogo sx + item tray dx ─────────────────────────────────────
	var bot_y  := arena_h + 4.0
	var bot_h  := H - bot_y
	var dial_w := W * 0.46
	var tray_x := dial_w + 12.0
	var tray_w := W - tray_x - 8.0

	# Box dialogo
	var dbox := _make_panel(
		Vector2(8, bot_y + 6),
		Vector2(dial_w - 4, bot_h - 14),
		C_PANEL, C_BORDER, 3)
	add_child(dbox)

	var dm := MarginContainer.new()
	dm.position = Vector2(14, 10)
	dm.size = Vector2(dial_w - 32, bot_h - 34)
	dbox.add_child(dm)

	_req_lbl = _lbl("Aspetta la\nrichiesta...", 21, C_WHITE, false)
	_req_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_req_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_req_lbl.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	dm.add_child(_req_lbl)

	# Item tray 2×2
	_item_cards.clear()
	var cell_w := (tray_w - 8.0) * 0.5
	var cell_h := (bot_h - 16.0) * 0.5

	for i in ITEMS.size():
		var item: Dictionary = ITEMS[i]
		var col := i % 2
		var row := i / 2
		var ix := tray_x + col * (cell_w + 8)
		var iy := bot_y + 6 + row * (cell_h + 8)

		var card := _build_item_card(item, i, Vector2(ix, iy), Vector2(cell_w, cell_h))
		add_child(card)
		_item_cards.append(card)

		card.gui_input.connect(_on_item_gui.bind(i))


func _build_donor_card(ds: DonorState, pos: Vector2, sz: Vector2) -> Control:
	var card := Control.new()
	card.position = pos
	card.size = sz
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	# Pannello sfondo
	var panel := Panel.new()
	panel.position = Vector2.ZERO
	panel.size = sz
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.08, 0.06, 0.14)
	psb.border_color = ds.color.darkened(0.25)
	psb.border_width_left = 2; psb.border_width_right  = 2
	psb.border_width_top  = 2; psb.border_width_bottom = 2
	psb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", psb)
	card.add_child(panel)

	# Sprite del donatore (stesso spritesheet usato in gioco)
	var av_sz := minf(sz.x * 0.62, 72.0)
	var av_x  := (sz.x - av_sz) * 0.5
	var av_y  := 6.0

	var sheet_path: String = DONOR_SHEETS[ds.sprite_idx % DONOR_SHEETS.size()]
	var tex_rect := TextureRect.new()
	tex_rect.position = Vector2(av_x, av_y)
	tex_rect.size = Vector2(av_sz, av_sz)
	tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(sheet_path):
		var atlas := AtlasTexture.new()
		atlas.atlas = load(sheet_path)
		atlas.region = SPRITE_REGION
		tex_rect.texture = atlas
	card.add_child(tex_rect)

	# Nome
	var name_lbl := _lbl(ds.name, 15, C_WHITE, true)
	name_lbl.position = Vector2(0, av_y + av_sz + 2)
	name_lbl.size = Vector2(sz.x, 20)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_lbl)

	# HP bar
	var hp_y := av_y + av_sz + 22.0
	var hp_w := sz.x - 16.0
	var hp_bg := ColorRect.new()
	hp_bg.position = Vector2(8, hp_y)
	hp_bg.size = Vector2(hp_w, 12)
	hp_bg.color = Color(0.14, 0.10, 0.06)
	hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hp_bg)

	ds.hp_max_w = hp_w
	ds.hp_fill = ColorRect.new()
	ds.hp_fill.position = Vector2(8, hp_y)
	ds.hp_fill.size = Vector2(hp_w * ds.hp, 12)
	ds.hp_fill.color = _hp_col(ds.hp)
	ds.hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(ds.hp_fill)

	# Speech bubble (sopra la card, nascosta)
	var bub_w := sz.x + 16.0
	ds.bubble = Control.new()
	ds.bubble.position = Vector2(-8, -104)
	ds.bubble.size = Vector2(bub_w, 94)
	ds.bubble.visible = false
	ds.bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(ds.bubble)

	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.95, 0.93, 0.86)
	bsb.set_corner_radius_all(8)
	bsb.border_color = Color(0.28, 0.22, 0.08)
	bsb.border_width_left = 2; bsb.border_width_right  = 2
	bsb.border_width_top  = 2; bsb.border_width_bottom = 2
	var bpanel := Panel.new()
	bpanel.position = Vector2.ZERO
	bpanel.size = Vector2(bub_w, 94)
	bpanel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bpanel.add_theme_stylebox_override("panel", bsb)
	ds.bubble.add_child(bpanel)

	ds.bubble_lbl = _lbl("", 19, Color(0.12, 0.10, 0.04), true)
	ds.bubble_lbl.position = Vector2(6, 6)
	ds.bubble_lbl.size = Vector2(bub_w - 12, 82)
	ds.bubble_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.bubble_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ds.bubble_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ds.bubble.add_child(ds.bubble_lbl)

	# Drop zone
	var di := _states.find(ds)
	card.gui_input.connect(_on_donor_gui.bind(di))

	return card


func _build_item_card(item: Dictionary, item_idx: int, pos: Vector2, sz: Vector2) -> Panel:
	var card := Panel.new()
	card.position = pos
	card.size = sz
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var sb := StyleBoxFlat.new()
	sb.bg_color = (item["color"] as Color).darkened(0.15)
	sb.border_color = (item["color"] as Color).lightened(0.3)
	sb.border_width_left = 3; sb.border_width_right  = 3
	sb.border_width_top  = 3; sb.border_width_bottom = 3
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 4; sb.shadow_offset = Vector2(2, 3)
	card.add_theme_stylebox_override("panel", sb)

	# Pixel-art image (NEAREST filter → look pixel-art)
	if item_idx < _item_textures.size():
		var img_sz := minf(sz.x * 0.68, sz.y * 0.62)
		var tr := TextureRect.new()
		tr.texture = _item_textures[item_idx]
		tr.size = Vector2(img_sz, img_sz)
		tr.position = Vector2((sz.x - img_sz) * 0.5, sz.y * 0.06)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(tr)

	# Label at bottom
	var lbl := _lbl(item["name"] as String, 14, C_WHITE, true)
	lbl.position = Vector2(0, sz.y * 0.70)
	lbl.size = Vector2(sz.x, sz.y * 0.28)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(lbl)

	return card


# ══════════════════════════════════════════════════════════════════════════════
#  DRAG & DROP
# ══════════════════════════════════════════════════════════════════════════════

func _on_item_gui(ev: InputEvent, idx: int) -> void:
	if not _game_active:
		return
	var pressed := false
	var gpos    := Vector2.ZERO
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and (ev as InputEventMouseButton).pressed:
		pressed = true; gpos = (ev as InputEventMouseButton).global_position
	elif ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
		pressed = true; gpos = (ev as InputEventScreenTouch).position
	if pressed:
		_start_drag(idx, gpos)


func _start_drag(idx: int, gpos: Vector2) -> void:
	_drag_item = idx
	_kill_ghost()

	var item: Dictionary = ITEMS[idx]
	_drag_ghost = Panel.new()
	_drag_ghost.size = Vector2(78, 88)
	_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = (item["color"] as Color).darkened(0.10)
	gsb.set_corner_radius_all(8)
	gsb.border_color = C_WHITE
	gsb.border_width_left = 2; gsb.border_width_right  = 2
	gsb.border_width_top  = 2; gsb.border_width_bottom = 2
	_drag_ghost.add_theme_stylebox_override("panel", gsb)
	_drag_ghost.modulate.a = 0.92

	# Pixel-art image in ghost
	if idx < _item_textures.size():
		var tr := TextureRect.new()
		tr.texture = _item_textures[idx]
		tr.size = Vector2(58, 58)
		tr.position = Vector2(10, 4)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_drag_ghost.add_child(tr)

	var gl := _lbl(item["name"] as String, 11, C_WHITE, true)
	gl.position = Vector2(0, 62)
	gl.size = Vector2(78, 22)
	gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_ghost.add_child(gl)

	add_child(_drag_ghost)
	_drag_ghost.position = gpos - Vector2(39, 44)
	_set_item_highlight(idx, true)


func _input(event: InputEvent) -> void:
	# Solo fase GAME: gestione drag & drop
	# (l'avanzamento intro è gestito da gui_input sul ColorRect overlay)
	if _phase != Phase.GAME or _drag_item == -1:
		return

	var pos := Vector2.ZERO
	var released := false

	if event is InputEventMouseMotion:
		pos = (event as InputEventMouseMotion).global_position
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not (event as InputEventMouseButton).pressed:
		pos = (event as InputEventMouseButton).global_position; released = true
	elif event is InputEventScreenDrag:
		pos = (event as InputEventScreenDrag).position
	elif event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed:
		pos = (event as InputEventScreenTouch).position; released = true

	if pos != Vector2.ZERO and is_instance_valid(_drag_ghost):
		_drag_ghost.position = pos - Vector2(50, 30)

	if released:
		_set_item_highlight(_drag_item, false)
		# Cerca quale donatore è sotto il punto di rilascio
		var hit := -1
		for i in _states.size():
			var ds: DonorState = _states[i]
			if is_instance_valid(ds.card) and ds.card.get_global_rect().has_point(pos):
				hit = i; break
		if hit != -1:
			_serve(hit, _drag_item)
		_drag_item = -1
		_kill_ghost()


func _on_donor_gui(_ev: InputEvent, _idx: int) -> void:
	pass  # gestito da _input release


func _kill_ghost() -> void:
	if is_instance_valid(_drag_ghost):
		_drag_ghost.queue_free()
	_drag_ghost = null


func _set_item_highlight(idx: int, on: bool) -> void:
	if idx < 0 or idx >= _item_cards.size():
		return
	var card := _item_cards[idx] as Panel
	if not is_instance_valid(card):
		return
	var item: Dictionary = ITEMS[idx]
	var sb := StyleBoxFlat.new()
	sb.bg_color = (item["color"] as Color).darkened(0.15)
	sb.set_corner_radius_all(10)
	if on:
		sb.border_color = C_GOLD
		sb.border_width_left = 4; sb.border_width_right  = 4
		sb.border_width_top  = 4; sb.border_width_bottom = 4
	else:
		sb.border_color = (item["color"] as Color).lightened(0.3)
		sb.border_width_left = 3; sb.border_width_right  = 3
		sb.border_width_top  = 3; sb.border_width_bottom = 3
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 4; sb.shadow_offset = Vector2(2, 3)
	card.add_theme_stylebox_override("panel", sb)
	card.pivot_offset = card.size * 0.5
	var tw := create_tween()
	tw.tween_property(card, "scale", Vector2(1.1, 1.1) if on else Vector2(1.0, 1.0), 0.10)


# ══════════════════════════════════════════════════════════════════════════════
#  GAME LOGIC
# ══════════════════════════════════════════════════════════════════════════════

func _serve(donor_idx: int, item_idx: int) -> void:
	var ds: DonorState = _states[donor_idx]
	if ds.request == -1:
		return
	var correct := item_idx == ds.request
	if correct:
		_score += 12
		_served_total += 1
		ds.hp = minf(1.0, ds.hp + 0.35)
		ds.request  = -1
		ds.cooldown = COOLDOWN_AFTER
		if is_instance_valid(ds.bubble): ds.bubble.visible = false
		_flash(ds, C_GREEN)
		_update_req_lbl()
	else:
		_score = maxi(0, _score - 7)
		ds.hp = maxf(0.0, ds.hp - DECAY_WRONG)
		_flash(ds, C_RED_C)
		_set_req_lbl("%s voleva\n%s, non %s!" % [ds.name, ITEMS[ds.request]["name"], ITEMS[item_idx]["name"]])
	_update_score()
	_update_hp(ds)


func _process(delta: float) -> void:
	# ── INTRO: typewriter senza tween (no lambda → sicuro su Android export) ────
	if _phase == Phase.INTRO:
		if not _text_done and is_instance_valid(_dial_lbl):
			_type_chars += delta / TYPEWRITER_SPD
			var total := _full_text.length()
			if _type_chars >= float(total):
				_type_chars = float(total)
				_text_done = true
			_dial_lbl.text = _full_text.substr(0, int(_type_chars))
		return

	if _phase != Phase.GAME or not _game_active:
		return
	_game_time -= delta
	_update_timer()
	if _game_time <= 0.0:
		_game_time = 0.0; _end_game(); return

	for i in _states.size():
		var ds: DonorState = _states[i]
		if ds.cooldown > 0.0:
			ds.cooldown -= delta
			continue
		if ds.request == -1:
			ds.request = randi() % ITEMS.size()
			var ph: Array = PHRASES[ds.request]
			# Guard nullo: su Android il node potrebbe non essere ancora pronto
			if is_instance_valid(ds.bubble_lbl):
				ds.bubble_lbl.text = str(ph[randi() % ph.size()])
			if is_instance_valid(ds.bubble):
				ds.bubble.visible = true
				_pop_bubble(ds)
			_update_req_lbl()
		ds.hp = maxf(0.0, ds.hp - DECAY_PER_SEC * delta)
		_update_hp(ds)
		if ds.hp <= 0.0:
			_score = maxi(0, _score - 6)
			ds.hp = 0.60; ds.request = -1; ds.cooldown = 3.0
			if is_instance_valid(ds.bubble): ds.bubble.visible = false
			_update_score(); _flash(ds, C_RED_C); _update_req_lbl()


func _update_hp(ds: DonorState) -> void:
	if not is_instance_valid(ds.hp_fill): return
	ds.hp_fill.size.x  = ds.hp_max_w * ds.hp
	ds.hp_fill.color   = _hp_col(ds.hp)


func _update_timer() -> void:
	var r := _game_time / GAME_DURATION
	if is_instance_valid(_timer_fill):
		_timer_fill.size.x = _timer_max_w * r
		_timer_fill.color  = _hp_col(r)
	if is_instance_valid(_timer_lbl):
		_timer_lbl.text = "%ds" % int(_game_time)


func _update_score() -> void:
	if is_instance_valid(_score_lbl):
		_score_lbl.text = "PUNTI: %d" % _score


func _update_req_lbl() -> void:
	for ds in _states:
		var d := ds as DonorState
		if d.request != -1:
			var lbl_text := ""
			if is_instance_valid(d.bubble_lbl):
				lbl_text = d.bubble_lbl.text.replace("\n", " ")
			_set_req_lbl("%s:\n\"%s\"" % [d.name, lbl_text])
			return
	_set_req_lbl("I donatori\naspettano...")


func _set_req_lbl(text: String) -> void:
	if is_instance_valid(_req_lbl): _req_lbl.text = text


func _flash(ds: DonorState, col: Color) -> void:
	if not is_instance_valid(ds.card): return
	if ds.anim_tw != null and ds.anim_tw.is_valid(): ds.anim_tw.kill()
	ds.anim_tw = create_tween()
	ds.anim_tw.tween_property(ds.card, "modulate", col,        0.07)
	ds.anim_tw.tween_property(ds.card, "modulate", Color.WHITE, 0.32)


func _pop_bubble(ds: DonorState) -> void:
	if not is_instance_valid(ds.bubble): return
	ds.bubble.scale = Vector2(0.6, 0.6)
	ds.bubble.pivot_offset = ds.bubble.size * 0.5
	var tw := create_tween()
	tw.tween_property(ds.bubble, "scale", Vector2(1.0, 1.0), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ══════════════════════════════════════════════════════════════════════════════
#  RESULT
# ══════════════════════════════════════════════════════════════════════════════

func _end_game() -> void:
	_game_active = false
	_kill_ghost()
	_phase = Phase.RESULT

	var W := _vp.x
	var H := _vp.y

	var dim := ColorRect.new()
	dim.position = Vector2.ZERO
	dim.size = Vector2(W, H)
	dim.color = Color(0, 0, 0, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var pw := minf(W - 48, 560.0)
	var ph := minf(H - 80, 460.0)
	var panel := _make_panel(
		Vector2((W - pw) * 0.5, (H - ph) * 0.5),
		Vector2(pw, ph), C_PANEL, C_BORDER, 3)
	add_child(panel)

	var vb := VBoxContainer.new()
	vb.position = Vector2(24, 20)
	vb.size = Vector2(pw - 48, ph - 40)
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)

	vb.add_child(_lbl("COLAZIONE COMPLETATA!", 22, C_GOLD, true))
	vb.add_child(_hsep(C_BORDER))
	RunState.score_breakfast = _score
	vb.add_child(_lbl("Rinfreschi serviti: %d\nPunti colazione: %d\nPUNTEGGIO TOTALE: %d" % [_served_total, _score, RunState.score_total()], 18, C_WHITE, true))
	PlayGames.submit_score(RunState.score_total())
	vb.add_child(_hsep(Color(C_BORDER.r, C_BORDER.g, C_BORDER.b, 0.35)))

	var edu := _lbl(
		"Ricorda sempre:\n" +
		"  Bevi acqua o succo subito dopo.\n" +
		"  Mangia qualcosa di leggero.\n" +
		"  Riposa qualche minuto.\n" +
		"  Evita sforzi per 24 ore.\n\nGrazie per aver donato!",
		16, C_GRAY, false)
	edu.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(edu)

	vb.add_child(_hsep(Color(C_BORDER.r, C_BORDER.g, C_BORDER.b, 0.35)))

	var wrap := CenterContainer.new()
	vb.add_child(wrap)
	var btn := _make_btn("TORNA AL MENU", C_RED_C)
	btn.custom_minimum_size = Vector2(240, 54)
	wrap.add_child(btn)
	btn.pressed.connect(_on_result_menu_pressed)


func _on_result_menu_pressed() -> void:
	finished.emit()
	queue_free()


# ══════════════════════════════════════════════════════════════════════════════
#  HELPERS
# ══════════════════════════════════════════════════════════════════════════════

func _hp_col(r: float) -> Color:
	if r > 0.50: return C_HP_OK
	elif r > 0.25: return C_HP_WRN
	return C_HP_BAD


func _lbl(text: String, size: int, color: Color, centered: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	if centered: l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _pf != null: l.add_theme_font_override("font", _pf)
	return l


func _make_panel(pos: Vector2, sz: Vector2, bg: Color, border: Color, bw: int) -> Panel:
	var p := Panel.new()
	p.position = pos; p.size = sz
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg; sb.border_color = border
	sb.border_width_left = bw; sb.border_width_right  = bw
	sb.border_width_top  = bw; sb.border_width_bottom = bw
	sb.set_corner_radius_all(10)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _make_btn(text: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 18)
	if _pf != null: btn.add_theme_font_override("font", _pf)
	for pair: Array in [[&"normal", color], [&"hover", color.lightened(0.18)], [&"pressed", color.darkened(0.2)]]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = pair[1] as Color
		sb.set_corner_radius_all(12)
		sb.border_width_left = 1; sb.border_width_right  = 1
		sb.border_width_top  = 1; sb.border_width_bottom = 1
		sb.border_color = (pair[1] as Color).lightened(0.3)
		btn.add_theme_stylebox_override(pair[0], sb)
	btn.add_theme_stylebox_override("focus", StyleBoxFlat.new())
	btn.add_theme_color_override("font_color", C_WHITE)
	return btn


func _hsep(color: Color) -> CenterContainer:
	var wrap := CenterContainer.new()
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(460, 2)
	line.color = color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(line)
	return wrap


# ══════════════════════════════════════════════════════════════════════════════
#  PIXEL ART ITEM TEXTURES  (16×16, rendered with TEXTURE_FILTER_NEAREST)
# ══════════════════════════════════════════════════════════════════════════════

func _make_item_textures() -> void:
	_item_textures.clear()
	for i in ITEMS.size():
		_item_textures.append(_make_item_texture(i))


func _make_item_texture(idx: int) -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match idx:
		0: _draw_acqua(img)
		1: _draw_succo(img)
		2: _draw_biscotto(img)
		3: _draw_caffe(img)
	return ImageTexture.create_from_image(img)


# ── pixel helpers ─────────────────────────────────────────────────────────────

func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < 16 and y >= 0 and y < 16:
		img.set_pixel(x, y, c)

func _px_row(img: Image, y: int, x1: int, x2: int, c: Color) -> void:
	for x in range(x1, x2 + 1): _px(img, x, y, c)

func _px_col(img: Image, x: int, y1: int, y2: int, c: Color) -> void:
	for y in range(y1, y2 + 1): _px(img, x, y, c)

func _px_fill(img: Image, x1: int, y1: int, x2: int, y2: int, c: Color) -> void:
	for y in range(y1, y2 + 1):
		for x in range(x1, x2 + 1):
			_px(img, x, y, c)


# ── ACQUA – bicchiere d'acqua blu ─────────────────────────────────────────────

func _draw_acqua(img: Image) -> void:
	var K := Color(0.05, 0.05, 0.12)   # contorno scuro
	var G := Color(0.72, 0.90, 0.98)   # vetro trasparente
	var H := Color(0.96, 0.98, 1.00)   # riflesso bianco
	var B := Color(0.18, 0.52, 0.90)   # acqua blu
	var D := Color(0.08, 0.30, 0.68)   # acqua scura

	# bordo superiore
	_px_row(img, 1, 3, 12, K)
	# pareti laterali
	_px_col(img, 3, 1, 12, K)
	_px_col(img, 12, 1, 12, K)
	# parte trasparente del vetro (top 2 righe)
	_px_fill(img, 4, 2, 11, 3, G)
	_px(img, 4, 2, H)   # riflesso
	_px(img, 5, 2, H)
	# superficie acqua (riga più chiara)
	_px_row(img, 4, 4, 11, Color(0.42, 0.72, 0.98))
	# corpo acqua
	_px_fill(img, 4, 5, 11, 11, B)
	# accenti scuri nell'acqua
	_px(img, 6,  7, D); _px(img, 9, 9, D); _px(img, 7, 11, D)
	# fondo bicchiere
	_px_row(img, 12, 4, 11, K)
	# base
	_px_row(img, 13, 3, 12, K)


# ── SUCCO – succo d'arancia con cannuccia ─────────────────────────────────────

func _draw_succo(img: Image) -> void:
	var K := Color(0.14, 0.06, 0.02)
	var G := Color(0.96, 0.88, 0.68)   # vetro caldo
	var H := Color(1.00, 0.95, 0.80)
	var O := Color(0.95, 0.58, 0.08)   # succo arancione
	var D := Color(0.70, 0.34, 0.04)   # arancia scura
	var S := Color(0.95, 0.24, 0.22)   # cannuccia rossa

	# cannuccia (prima del vetro, così il bordo passa sopra)
	_px_col(img, 10, 0, 5, S)
	_px(img, 11, 0, S); _px(img, 11, 1, S)

	# bordo superiore e pareti
	_px_row(img, 1, 3, 12, K)
	_px_col(img, 3, 1, 12, K)
	_px_col(img, 12, 1, 12, K)
	# vetro trasparente top
	_px_fill(img, 4, 2, 11, 3, G)
	_px(img, 4, 2, H); _px(img, 5, 2, H)
	# superficie succo
	_px_row(img, 4, 4, 11, Color(1.00, 0.78, 0.34))
	# corpo succo
	_px_fill(img, 4, 5, 11, 11, O)
	# accenti
	_px(img, 6, 8, D); _px(img, 9, 10, D); _px(img, 7, 11, D)
	# fondo e base
	_px_row(img, 12, 4, 11, K)
	_px_row(img, 13, 3, 12, K)


# ── BISCOTTO – biscotto rotondo con gocce di cioccolato ───────────────────────

func _draw_biscotto(img: Image) -> void:
	var K := Color(0.20, 0.09, 0.02)   # contorno / chip
	var C := Color(0.84, 0.64, 0.30)   # biscotto chiaro
	var D := Color(0.64, 0.44, 0.16)   # biscotto scuro
	var H := Color(0.96, 0.82, 0.52)   # riflesso

	# corpo circolare
	var cx := 7.5; var cy := 7.5
	for y in range(16):
		for x in range(16):
			var dx := x + 0.5 - cx
			var dy := y + 0.5 - cy
			var r := sqrt(dx * dx + dy * dy)
			if r < 5.5:
				_px(img, x, y, C)
			elif r < 6.8:
				_px(img, x, y, K)

	# texture / crepe
	_px(img, 7, 5, D); _px(img, 8, 6, D)
	_px(img, 5, 7, D); _px(img, 9, 8, D)
	_px(img, 6, 9, D); _px(img, 10, 7, D)

	# gocce di cioccolato
	_px(img, 5,  5, K); _px(img,  4,  6, K)
	_px(img, 10, 5, K); _px(img, 11,  6, K)
	_px(img, 5, 10, K); _px(img,  4,  9, K)
	_px(img, 10,10, K); _px(img, 11,  9, K)
	_px(img, 7, 12, K)

	# riflesso in alto a sinistra
	_px(img, 5, 4, H); _px(img, 6, 3, H); _px(img, 4, 7, H)


# ── CAFFÈ – tazza di caffè con vapore ─────────────────────────────────────────

func _draw_caffe(img: Image) -> void:
	var K  := Color(0.06, 0.04, 0.02)   # contorno
	var M  := Color(0.55, 0.34, 0.15)   # tazza corpo
	var MD := Color(0.33, 0.18, 0.06)   # lato ombra
	var CF := Color(0.14, 0.07, 0.02)   # caffè liquido
	var R  := Color(0.72, 0.52, 0.26)   # bordo tazza
	var S  := Color(0.82, 0.80, 0.78)   # vapore

	# vapore
	_px(img, 4, 0, S); _px(img, 4, 1, S); _px(img, 3, 2, S)
	_px(img, 8, 0, S); _px(img, 7, 1, S); _px(img, 8, 2, S)

	# contorno tazza
	_px_col(img, 2, 4, 12, K)
	_px_col(img, 11, 4, 12, K)
	_px_row(img, 4, 2, 11, K)
	_px_row(img, 12, 2, 11, K)
	# base
	_px_row(img, 13, 1, 12, K)

	# bordo superiore (chiaro)
	_px_row(img, 5, 3, 10, R)

	# superficie caffè (top 2 righe interne)
	_px_fill(img, 3, 5, 10, 6, CF)
	_px(img, 4, 5, Color(0.28, 0.14, 0.05))  # piccolo riflesso

	# corpo tazza
	_px_fill(img, 3, 7, 10, 11, M)
	# ombra lato destro
	_px_col(img, 10, 5, 11, MD)

	# manico (destra)
	_px(img, 12, 6, K); _px(img, 13, 6, K)
	_px(img, 13, 7, K); _px(img, 13, 8, K); _px(img, 13, 9, K)
	_px(img, 12, 10, K); _px(img, 13, 10, K)
	_px(img, 12, 7, M); _px(img, 12, 8, M); _px(img, 12, 9, M)
