extends Control
## Minigioco "Controllo etichette" (sala donazione).
##
## Mentre la sacca si riempie, il giocatore collega ogni sacca alla provetta
## con l'etichetta dello stesso colore, tracciando un tubicino col dito.
## Nella realta' sacca, provette e modulo di un donatore hanno lo stesso
## codice etichetta: e' cio' che rende il sangue rintracciabile.
##
## Tutto e' disegnato da codice in pixel art (nessun asset da importare).
## Niente lambda nelle .connect() (crash su export Android).

signal solved
signal pair_connected(index: int)

const PIXEL_FONT_PATH := "res://fonts/PixelOperator8.ttf"
const POINTS_PER_PUZZLE := 50

# ── Palette (toni caldi del gioco) ──────────────────────────────────────────
const C_OUT      := Color("1a080c")
const C_SHADOW   := Color(0.0, 0.0, 0.0, 0.45)
const C_PANEL    := Color("2b0f15")
const C_PANEL_LO := Color("1c090d")
const C_FRAME    := Color("8c2f2a")
const C_FRAME_HI := Color("c9523f")
const C_FRAME_LO := Color("5a1a19")
const C_SLOT     := Color("241015")
const C_SLOT_HI  := Color("3a1a22")
const C_SLOT_LO  := Color("12060a")
const C_GOLD     := Color("ffce38")
const C_TEXT     := Color("efe7e2")
const C_MUTED    := Color("b79a95")
const C_WHITE    := Color("f4efe9")
const C_GLASS    := Color("a9d3e0")
const C_BLOOD    := Color("c0242c")
const C_OK       := Color("62d36b")
const C_PAPER    := Color("eadcbc")
const C_PAPER_LO := Color("b9a47e")
const C_INK      := Color("2a1416")

## Colori delle etichette (uno per coppia sacca/provetta).
## Niente rosso: si confonderebbe con il sangue della sacca.
const PAIR_COLORS: Array[Color] = [
	Color("3f8fe6"),   # blu
	Color("4fc25a"),   # verde
	Color("f2c12b"),   # giallo
	Color("e45aae"),   # magenta
	Color("ff8a2e"),   # arancio
]

# ── Sprite pixel art ────────────────────────────────────────────────────────
# o = contorno  f/h/e = etichetta (colore, chiaro, scuro)
# r/l/d = sangue (base, chiaro, scuro)  w = bianco  g = vetro  k = codice a barre
const BAG_SPRITE: Array[String] = [
	"....oooo....",
	"....oggo....",
	".oooooooooo.",
	"olrrrrrrrrdo",
	"olrhfffferdo",
	"olrkwkwkwrdo",
	"olrkwkwkwrdo",
	"olrkwkwkwrdo",
	"orrefffferdo",
	"orrrrrrrrddo",
	".orrrrrrrdo.",
	"..oooooooo..",
	".....oo.....",
	".....oo.....",
]

const TUBE_SPRITE: Array[String] = [
	"..oooooo..",
	".ohhfffeo.",
	".offffeeo.",
	".oooooooo.",
	"..oggggo..",
	"..ohfffo..",
	"..ofkfko..",
	"..oeffeo..",
	"..olrrdo..",
	"..olrrdo..",
	"..orrrdo..",
	"..orrrdo..",
	"...ordo...",
	"....oo....",
]

const CHECK_SPRITE: Array[String] = [
	".......oo",
	"......ovo",
	"oo...ovo.",
	"ovo.ovo..",
	".ovovo...",
	"..ovo....",
	"...o.....",
]

# ── Stato ───────────────────────────────────────────────────────────────────
var grid_n: int = 5
var pair_count: int = 4

var _cell: float = 54.0
var _px: float = 4.0            # "pixel" della cornice
var _sprite_px: float = 3.0     # "pixel" delle sprite
var _pad: float = 22.0
var _header_h: float = 78.0
var _footer_h: float = 52.0
var _grid_origin := Vector2.ZERO

var _endpoints: Dictionary = {}       # Vector2i -> indice coppia
var _endpoint_is_bag: Dictionary = {} # Vector2i -> bool
var _paths: Array = []                # Array di Array[Vector2i]
var _owner: Dictionary = {}           # Vector2i -> indice coppia (celle dei tubi)
var _connected: Array[bool] = []
var _solution: Dictionary = {}        # indice coppia -> celle della soluzione

var _drawing: int = -1
var _last_pointer := Vector2.ZERO
var _lot_code: String = "0427"         # numero di lotto sull'etichetta in alto
var _paused: bool = false
var _done: bool = false

var _time: float = 0.0
var _flash: float = 0.0
var _done_t: float = 0.0
var _particles: Array = []            # [pos, vel, color, life]

var _font: Font = null


# ════════════════════════════════════════════════════════════════════════════
#  API
# ════════════════════════════════════════════════════════════════════════════

## Punti mostrati nel timbro di vittoria (dipendono dalla difficolta').
var points: int = POINTS_PER_PUZZLE

## Conto alla rovescia (sacca piena): -1 = spento.
var _countdown_left: float = -1.0
var _countdown_total: float = 1.0


## n = lato della griglia (4, 5 o 6), k = numero di coppie.
func setup(n: int, k: int) -> void:
	grid_n = clampi(n, 4, 6)
	pair_count = clampi(k, 2, PAIR_COLORS.size())
	match grid_n:
		4: _cell = 90.0
		5: _cell = 76.0
		_: _cell = 66.0
	_sprite_px = floorf(_cell * 0.80 / 14.0)
	var grid_px := _cell * grid_n
	var w := grid_px + _pad * 2.0
	var h := _header_h + grid_px + _footer_h + _pad
	custom_minimum_size = Vector2(w, h)
	size = custom_minimum_size
	_grid_origin = Vector2(_pad, _header_h)
	_lot_code = "%04d" % randi_range(1000, 9999)
	_generate_level()
	queue_redraw()


## Puzzle n-esimo di una serie (Difficile: due per donatore). Mostra "1/2".
var _stage: int = 1
var _stage_total: int = 1

func set_stage(i: int, total: int) -> void:
	_stage = i
	_stage_total = total
	queue_redraw()


## Mostra il conto alla rovescia rosso (left < 0 lo spegne).
func set_countdown(left: float, total: float) -> void:
	_countdown_left = left
	_countdown_total = maxf(total, 0.01)


func set_paused(p: bool) -> void:
	if _paused == p:
		return
	_paused = p
	if p:
		_drawing = -1
	queue_redraw()


func is_solved() -> bool:
	return _done


# ════════════════════════════════════════════════════════════════════════════
#  Ciclo
# ════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if ResourceLoader.exists(PIXEL_FONT_PATH):
		_font = load(PIXEL_FONT_PATH)
	if _font == null:
		_font = ThemeDB.fallback_font
	if _paths.is_empty():
		setup(grid_n, pair_count)


func _process(delta: float) -> void:
	_time += delta
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 2.5)
	if _done:
		_done_t += delta
	for p in _particles:
		p[0] += p[1] * delta
		p[1].y += 260.0 * delta
		p[3] -= delta
	var alive: Array = []
	for p in _particles:
		if p[3] > 0.0:
			alive.append(p)
	_particles = alive
	queue_redraw()


# ════════════════════════════════════════════════════════════════════════════
#  Generazione livello
# ════════════════════════════════════════════════════════════════════════════
# Un percorso che passa per tutte le celle (rimescolato con mosse "backbite")
# viene tagliato in k pezzi: ogni pezzo e' la soluzione di una coppia.
# Cosi' ogni puzzle ha sempre almeno una soluzione che riempie la griglia.

func _generate_level() -> void:
	var best: Array = []
	for attempt in 60:
		var path := _random_hamiltonian_path(grid_n)
		var segs := _cut_path(path, pair_count)
		if not segs.is_empty():
			best = segs
			break
	if best.is_empty():
		best = _cut_path(_snake_path(grid_n), pair_count)

	_endpoints.clear()
	_endpoint_is_bag.clear()
	_paths.clear()
	_owner.clear()
	_connected.clear()

	var order := range(pair_count)
	order.shuffle()
	for i in pair_count:
		var seg: Array = best[i]
		var color_idx: int = order[i]
		var a: Vector2i = seg[0]
		var b: Vector2i = seg[seg.size() - 1]
		_endpoints[a] = color_idx
		_endpoints[b] = color_idx
		var a_is_bag := randf() < 0.5
		_endpoint_is_bag[a] = a_is_bag
		_endpoint_is_bag[b] = not a_is_bag

	for i in pair_count:
		_paths.append([])
		_connected.append(false)
	_solution.clear()
	for i in pair_count:
		_solution[order[i]] = best[i]
	_done = false
	_done_t = 0.0


## Solo per test/screenshot: collega le prime `count` coppie con la soluzione.
func debug_fill(count: int) -> void:
	var keys := _solution.keys()
	keys.sort()
	for i in mini(count, keys.size()):
		var k: int = keys[i]
		_clear_path(k)
		var seg: Array = _solution[k]
		_paths[k] = [seg[0]]
		_owner[seg[0]] = k
		for j in range(1, seg.size()):
			_extend(k, seg[j])


func _snake_path(n: int) -> Array:
	var path: Array = []
	for y in n:
		if y % 2 == 0:
			for x in n:
				path.append(Vector2i(x, y))
		else:
			for x in range(n - 1, -1, -1):
				path.append(Vector2i(x, y))
	return path


func _random_hamiltonian_path(n: int) -> Array:
	var path := _snake_path(n)
	for i in n * n * 40:
		_backbite(path, n)
	return path


func _backbite(path: Array, n: int) -> void:
	var flip := randf() < 0.5
	if flip:
		path.reverse()
	var tail: Vector2i = path[path.size() - 1]
	var prev: Vector2i = path[path.size() - 2]
	var nbs: Array = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c: Vector2i = tail + d
		if c.x >= 0 and c.y >= 0 and c.x < n and c.y < n and c != prev:
			nbs.append(c)
	if not nbs.is_empty():
		var nb: Vector2i = nbs[randi() % nbs.size()]
		var i := path.find(nb)
		var rest := path.slice(i + 1)
		rest.reverse()
		path.resize(i + 1)
		path.append_array(rest)
	if flip:
		path.reverse()


func _cut_path(path: Array, k: int) -> Array:
	var total := path.size()
	var min_len := 3
	if total < k * min_len:
		return []
	for attempt in 40:
		# lunghezze casuali ma non troppo sbilanciate
		var lens: Array = []
		for i in k:
			lens.append(min_len)
		var left := total - k * min_len
		while left > 0:
			lens[randi() % k] += 1
			left -= 1
		var segs: Array = []
		var idx := 0
		var ok := true
		for L in lens:
			var seg := path.slice(idx, idx + L)
			idx += L
			var a: Vector2i = seg[0]
			var b: Vector2i = seg[seg.size() - 1]
			# niente coppie con gli estremi gia' vicini: troppo facili
			if absi(a.x - b.x) + absi(a.y - b.y) <= 1:
				ok = false
				break
			segs.append(seg)
		if ok:
			return segs
	return []


# ════════════════════════════════════════════════════════════════════════════
#  Input (mouse; su Android il tocco arriva come mouse emulato)
# ════════════════════════════════════════════════════════════════════════════

func _gui_input(event: InputEvent) -> void:
	if _paused or _done:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_last_pointer = event.position
			_on_press(_cell_at(event.position))
		else:
			_drawing = -1
			_check_win()
		accept_event()
	elif event is InputEventMouseMotion and _drawing >= 0:
		# segue la traiettoria reale del dito tra un evento e l'altro,
		# cosi' anche i trascinamenti veloci passano dalle celle giuste
		var to: Vector2 = event.position
		var dist := _last_pointer.distance_to(to)
		var steps := maxi(1, ceili(dist / (_cell * 0.25)))
		for i in range(1, steps + 1):
			_drag_to(_cell_at(_last_pointer.lerp(to, float(i) / steps)))
		_last_pointer = to
		accept_event()


func _cell_at(p: Vector2) -> Vector2i:
	var local := (p - _grid_origin) / _cell
	var c := Vector2i(floori(local.x), floori(local.y))
	if c.x < 0 or c.y < 0 or c.x >= grid_n or c.y >= grid_n:
		return Vector2i(-1, -1)
	return c


func _on_press(c: Vector2i) -> void:
	if c.x < 0:
		return
	if _endpoints.has(c):
		var k: int = _endpoints[c]
		_clear_path(k)
		_paths[k] = [c]
		_owner[c] = k
		_drawing = k
		AudioManager.play_sfx("drag_start")
	elif _owner.has(c):
		var k2: int = _owner[c]
		_truncate(k2, _paths[k2].find(c))
		_drawing = k2


func _drag_to(target: Vector2i) -> void:
	if target.x < 0 or _drawing < 0:
		return
	var path: Array = _paths[_drawing]
	if path.is_empty():
		return
	var cur: Vector2i = path[path.size() - 1]
	var guard := 0
	# trascinamenti veloci: avanza una cella alla volta verso il dito
	while cur != target and guard < 12:
		guard += 1
		var diff := target - cur
		var step_x := Vector2i(signi(diff.x), 0)
		var step_y := Vector2i(0, signi(diff.y))
		var first := step_x if absi(diff.x) >= absi(diff.y) else step_y
		var second := step_y if first == step_x else step_x
		# prima la direzione principale; se e' bloccata prova l'altra
		var moved := false
		for st in [first, second]:
			if st == Vector2i.ZERO:
				continue
			if _is_free_for(_drawing, cur + st) and _extend(_drawing, cur + st):
				moved = true
				break
		if not moved and not _extend(_drawing, cur + first):
			break
		path = _paths[_drawing]
		cur = path[path.size() - 1]


## Cella libera per il colore k: vuota, gia' sua o la sua estremita'.
func _is_free_for(k: int, c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= grid_n or c.y >= grid_n:
		return false
	if _endpoints.has(c):
		return _endpoints[c] == k
	return _owner.get(c, k) == k


func _extend(k: int, c: Vector2i) -> bool:
	var path: Array = _paths[k]
	var i := path.find(c)
	if i >= 0:
		# tornare indietro accorcia il tubo
		_truncate(k, i)
		return true
	if _connected[k]:
		return false
	if _endpoints.has(c) and _endpoints[c] != k:
		return false
	if _owner.has(c) and _owner[c] != k:
		# taglia il tubo di un altro colore
		var other: int = _owner[c]
		_truncate(other, _paths[other].find(c) - 1)
	path.append(c)
	_owner[c] = k
	if _endpoints.has(c) and _endpoints[c] == k and c != path[0]:
		_connected[k] = true
		_flash = 1.0
		_burst(_cell_center(c), PAIR_COLORS[k], 10)
		AudioManager.play_sfx("btn_click")
		pair_connected.emit(k)
		_check_win()
	return true


func _truncate(k: int, keep_index: int) -> void:
	var path: Array = _paths[k]
	while path.size() > maxi(keep_index + 1, 0):
		var c: Vector2i = path.pop_back()
		if _owner.get(c, -1) == k:
			_owner.erase(c)
	_connected[k] = false
	if path.size() >= 2:
		var last: Vector2i = path[path.size() - 1]
		if _endpoints.get(last, -1) == k and last != path[0]:
			_connected[k] = true


func _clear_path(k: int) -> void:
	_truncate(k, -1)


func _all_connected() -> bool:
	for ok in _connected:
		if not ok:
			return false
	return true


## Vinci solo se tutte le caselle sono coperte da un tubo.
func _grid_full() -> bool:
	return _owner.size() >= grid_n * grid_n


func _check_win() -> void:
	if _done:
		return
	if not _all_connected() or not _grid_full():
		return
	_done = true
	_done_t = 0.0
	AudioManager.play_sfx("correct")
	var center := _grid_origin + Vector2(_cell * grid_n, _cell * grid_n) * 0.5
	_burst(center, C_GOLD, 26)
	_burst(center, C_OK, 16)
	solved.emit()


func _burst(at: Vector2, col: Color, count: int) -> void:
	for i in count:
		var ang := randf() * TAU
		var spd := randf_range(90.0, 230.0)
		_particles.append([at, Vector2(cos(ang), sin(ang) - 0.6) * spd, col, randf_range(0.5, 0.9)])


# ════════════════════════════════════════════════════════════════════════════
#  Disegno
# ════════════════════════════════════════════════════════════════════════════

func _cell_center(c: Vector2i) -> Vector2:
	return _grid_origin + Vector2(c.x + 0.5, c.y + 0.5) * _cell


func _snap(v: float, unit: float) -> float:
	return roundf(v / unit) * unit


func _draw() -> void:
	_draw_panel()
	_draw_header()
	_draw_grid()
	_draw_tubes()
	_draw_endpoints()
	_draw_footer()
	if _countdown_left >= 0.0 and not _done:
		_draw_countdown()
	if _paused and not _done:
		_draw_paused_overlay()
	if _done:
		_draw_done_overlay()
	for p in _particles:
		var a: float = clampf(p[3] / 0.6, 0.0, 1.0)
		var s := _px * (1.0 + float(int(p[3] * 10.0) % 2))
		var col: Color = p[2]
		col.a = a
		var pos: Vector2 = p[0]
		draw_rect(Rect2(Vector2(_snap(pos.x, _px), _snap(pos.y, _px)), Vector2(s, s)), col)


## Rettangolo "pixel" con gli angoli smussati di un pixel.
func _notched_rect(r: Rect2, col: Color, notch: float) -> void:
	draw_rect(Rect2(r.position + Vector2(notch, 0), Vector2(r.size.x - notch * 2.0, r.size.y)), col)
	draw_rect(Rect2(r.position + Vector2(0, notch), Vector2(r.size.x, r.size.y - notch * 2.0)), col)


func _draw_panel() -> void:
	var p := _px
	var r := Rect2(Vector2.ZERO, size)
	# ombra
	_notched_rect(Rect2(r.position + Vector2(p * 2, p * 2), r.size), C_SHADOW, p * 2)
	# contorno + cornice a rilievo
	_notched_rect(r, C_OUT, p * 2)
	var fr := r.grow(-p)
	_notched_rect(fr, C_FRAME, p)
	draw_rect(Rect2(fr.position + Vector2(p, 0), Vector2(fr.size.x - p * 2, p)), C_FRAME_HI)
	draw_rect(Rect2(fr.position + Vector2(0, p), Vector2(p, fr.size.y - p * 2)), C_FRAME_HI)
	draw_rect(Rect2(Vector2(fr.position.x + p, fr.end.y - p), Vector2(fr.size.x - p * 2, p)), C_FRAME_LO)
	draw_rect(Rect2(Vector2(fr.end.x - p, fr.position.y + p), Vector2(p, fr.size.y - p * 2)), C_FRAME_LO)
	# interno
	var inner := r.grow(-p * 3)
	_notched_rect(inner, C_OUT, p)
	_notched_rect(inner.grow(-p), C_PANEL, p)
	# rivetti negli angoli
	for c in [inner.position + Vector2(p * 2, p * 2),
			Vector2(inner.end.x - p * 4, inner.position.y + p * 2),
			Vector2(inner.position.x + p * 2, inner.end.y - p * 4),
			inner.end - Vector2(p * 4, p * 4)]:
		draw_rect(Rect2(c, Vector2(p * 2, p * 2)), C_FRAME_LO)
		draw_rect(Rect2(c, Vector2(p, p)), C_FRAME_HI)


func _draw_text(text: String, y: float, font_size: int, col: Color, shadow := true) -> void:
	if _font == null:
		return
	var x := 0.0
	var w := size.x
	if shadow:
		draw_string(_font, Vector2(x + _px, y + _px), text, HORIZONTAL_ALIGNMENT_CENTER, w, font_size, C_OUT)
	draw_string(_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_CENTER, w, font_size, col)


## In alto un adesivo da laboratorio: codice a barre + numero di lotto.
func _draw_header() -> void:
	var p := _px
	var label := Rect2(Vector2(_pad + p * 2, p * 6), Vector2(size.x - (_pad + p * 2) * 2, _header_h - p * 11))
	label.position = Vector2(_snap(label.position.x, p), _snap(label.position.y, p))
	label.size = Vector2(_snap(label.size.x, p), _snap(label.size.y, p))
	# ombra + contorno + carta
	draw_rect(Rect2(label.position + Vector2(p, p), label.size), C_SHADOW)
	_notched_rect(label.grow(p), C_OUT, p)
	draw_rect(label, C_PAPER)
	draw_rect(Rect2(label.position, Vector2(label.size.x, p)), C_PAPER.lightened(0.35))
	draw_rect(Rect2(Vector2(label.position.x, label.end.y - p), Vector2(label.size.x, p)), C_PAPER_LO)
	# angolo piegato in alto a destra
	var f := p * 3
	var corner := Vector2(label.end.x - f, label.position.y)
	draw_rect(Rect2(corner, Vector2(f, f)), C_PANEL)
	draw_rect(Rect2(corner, Vector2(p, f)), C_PAPER_LO)
	draw_rect(Rect2(corner + Vector2(0, f - p), Vector2(f, p)), C_PAPER_LO)
	draw_rect(Rect2(corner + Vector2(p, p), Vector2(p, p)), C_PAPER_LO)

	# codice a barre a sinistra (barre di larghezza diversa, ricavate dal lotto)
	var bx := label.position.x + p * 3
	var by := label.position.y + p * 2
	var bh := label.size.y - p * 4
	var seq := _lot_code + _lot_code.reverse() + _lot_code
	var x := bx
	for i in seq.length():
		var d := int(seq[i])
		var w := p * (1 + d % 2)
		draw_rect(Rect2(Vector2(x, by), Vector2(w, bh)), C_INK)
		x += w + p * (1 + (d / 3) % 2)
	# numero di lotto a destra, inchiostro scuro
	if _font != null:
		var tx := x + p * 3
		var tw := label.end.x - f - tx
		var ty := label.position.y + label.size.y * 0.5 + 8.0
		var txt := "LOTTO " + _lot_code
		if _stage_total > 1:
			txt += "  %d/%d" % [_stage, _stage_total]
		draw_string(_font, Vector2(tx, ty), txt, HORIZONTAL_ALIGNMENT_CENTER, tw, 16, C_INK)


func _draw_grid() -> void:
	var p := _px
	var gsz := Vector2(_cell * grid_n, _cell * grid_n)
	var well := Rect2(_grid_origin, gsz).grow(p * 2)
	_notched_rect(well, C_OUT, p)
	draw_rect(well.grow(-p), C_SLOT_LO)
	var hint_empty := _all_connected() and not _done and not _paused
	var pulse := 0.45 + 0.40 * sin(_time * 5.0)

	for y in grid_n:
		for x in grid_n:
			var c := Vector2i(x, y)
			var r := Rect2(_grid_origin + Vector2(x, y) * _cell, Vector2(_cell, _cell)).grow(-p)
			draw_rect(r, C_SLOT)
			draw_rect(Rect2(r.position, Vector2(r.size.x, p)), C_SLOT_HI)
			draw_rect(Rect2(r.position, Vector2(p, r.size.y)), C_SLOT_HI)
			draw_rect(Rect2(Vector2(r.position.x, r.end.y - p), Vector2(r.size.x, p)), C_SLOT_LO)
			var k: int = _owner.get(c, -1)
			if k >= 0:
				var tint: Color = PAIR_COLORS[k]
				tint.a = 0.30 if _connected[k] else 0.16
				draw_rect(r.grow(-p), tint)
			elif hint_empty:
				# tutto collegato ma restano caselle vuote: pulsano piano
				var glow := C_GOLD
				glow.a = pulse
				draw_rect(Rect2(r.position, Vector2(r.size.x, p)), glow)
				draw_rect(Rect2(Vector2(r.position.x, r.end.y - p), Vector2(r.size.x, p)), glow)
				draw_rect(Rect2(r.position, Vector2(p, r.size.y)), glow)
				draw_rect(Rect2(Vector2(r.end.x - p, r.position.y), Vector2(p, r.size.y)), glow)


func _draw_tubes() -> void:
	var p := _px
	var t := _snap(_cell * 0.30, p)
	# tre passate: contorno, colore, riflesso -> i tubi si fondono bene agli incroci
	for pass_i in 3:
		for k in _paths.size():
			var path: Array = _paths[k]
			if path.is_empty():
				continue
			var base: Color = PAIR_COLORS[k]
			var col: Color
			var grow := 0.0
			match pass_i:
				0:
					col = C_OUT
					grow = p
				1:
					col = base.darkened(0.12) if not _connected[k] else base
				2:
					col = base.lightened(0.45)
			for i in path.size():
				var c: Vector2i = path[i]
				var ctr := _cell_center(c)
				if pass_i < 2:
					draw_rect(Rect2(ctr - Vector2(t, t) * 0.5 - Vector2(grow, grow), Vector2(t, t) + Vector2(grow, grow) * 2.0), col)
				if i == 0:
					continue
				var prev: Vector2i = path[i - 1]
				var a := _cell_center(prev)
				var tl := Vector2(minf(a.x, ctr.x), minf(a.y, ctr.y)) - Vector2(t, t) * 0.5
				var br := Vector2(maxf(a.x, ctr.x), maxf(a.y, ctr.y)) + Vector2(t, t) * 0.5
				if pass_i < 2:
					draw_rect(Rect2(tl - Vector2(grow, grow), br - tl + Vector2(grow, grow) * 2.0), col)
				else:
					# riflesso: una striscia di un pixel sul lato alto/sinistro
					if prev.y == c.y:
						draw_rect(Rect2(Vector2(tl.x, tl.y + p), Vector2(br.x - tl.x, p)), col)
					else:
						draw_rect(Rect2(Vector2(tl.x + p, tl.y), Vector2(p, br.y - tl.y)), col)


func _draw_sprite(rows: Array[String], center: Vector2, unit: float, pair_col: Color) -> void:
	var h := rows.size()
	var w := rows[0].length()
	var origin := center - Vector2(w, h) * unit * 0.5
	origin = Vector2(_snap(origin.x, 1.0), _snap(origin.y, 1.0))
	for y in h:
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch == ".":
				continue
			var col: Color
			match ch:
				"o", "k": col = C_OUT
				"f": col = pair_col
				"h": col = pair_col.lightened(0.40)
				"e": col = pair_col.darkened(0.30)
				"r": col = C_BLOOD
				"l": col = C_BLOOD.lightened(0.35)
				"d": col = C_BLOOD.darkened(0.35)
				"c": col = C_BLOOD.darkened(0.15)
				"w": col = C_WHITE
				"g": col = C_GLASS
				"v": col = C_OK
				_: col = Color.MAGENTA
			draw_rect(Rect2(origin + Vector2(x, y) * unit, Vector2(unit, unit)), col)


func _draw_endpoints() -> void:
	var p := _px
	for c in _endpoints.keys():
		var k: int = _endpoints[c]
		var col: Color = PAIR_COLORS[k]
		var r := Rect2(_grid_origin + Vector2(c.x, c.y) * _cell, Vector2(_cell, _cell)).grow(-p * 2)
		# piastrina colorata sotto l'oggetto
		var pad_col := col
		pad_col.a = 0.42 if _connected[k] else 0.26
		draw_rect(r, pad_col)
		# angoli della piastrina (dorati quando la coppia e' collegata)
		var corner := C_GOLD if _connected[k] else col
		var s := p * 3
		for v in [r.position, Vector2(r.end.x - s, r.position.y), Vector2(r.position.x, r.end.y - s), r.end - Vector2(s, s)]:
			draw_rect(Rect2(v, Vector2(s, p)), corner)
		draw_rect(Rect2(r.position, Vector2(p, s)), corner)
		draw_rect(Rect2(Vector2(r.end.x - p, r.position.y), Vector2(p, s)), corner)
		draw_rect(Rect2(Vector2(r.position.x, r.end.y - s), Vector2(p, s)), corner)
		draw_rect(Rect2(Vector2(r.end.x - p, r.end.y - s), Vector2(p, s)), corner)

		var ctr := _cell_center(c)
		# piccolo "respiro" sulle estremita' non ancora collegate
		var bob := 0.0
		if not _connected[k] and not _paused and not _done:
			bob = -_sprite_px if int(_time * 2.0 + k) % 2 == 0 else 0.0
		var sprite: Array[String] = BAG_SPRITE if _endpoint_is_bag.get(c, true) else TUBE_SPRITE
		_draw_sprite(sprite, ctr + Vector2(0, bob), _sprite_px, col)

		if _connected[k]:
			_draw_sprite(CHECK_SPRITE, r.end - Vector2(p * 5, p * 4), p, col)


func _draw_footer() -> void:
	var p := _px
	var y := _snap(_header_h + _cell * grid_n + p * 5, p)
	# pallini delle coppie (uno per colore) a sinistra
	var dot := p * 4
	var gap := p * 2
	var x := _snap(_pad + p * 2, p)
	for i in pair_count:
		var k := _pair_color_for_slot(i)
		var r := Rect2(Vector2(x, y), Vector2(dot, dot))
		draw_rect(r.grow(p), C_OUT)
		var col: Color = PAIR_COLORS[k] if _connected[k] else C_SLOT_HI
		draw_rect(r, col)
		if _connected[k]:
			draw_rect(Rect2(r.position, Vector2(dot, p)), col.lightened(0.4))
		x += dot + gap
	# barra delle caselle riempite a destra (una tacca per casella)
	var total := grid_n * grid_n
	var filled := mini(_owner.size(), total)
	var bar_x := x + p * 3
	var bar_w := _snap(size.x - _pad - p * 2 - bar_x, p)
	var bar := Rect2(Vector2(bar_x, y), Vector2(bar_w, dot))
	draw_rect(bar.grow(p), C_OUT)
	draw_rect(bar, C_SLOT_LO)
	var fill_col := C_OK if filled >= total else C_GOLD
	var fw := _snap(bar_w * float(filled) / total, p)
	if fw > 0.0:
		draw_rect(Rect2(bar.position, Vector2(fw, dot)), fill_col.darkened(0.15))
		draw_rect(Rect2(bar.position, Vector2(fw, p)), fill_col.lightened(0.35))
	# tacche: una ogni casella
	for i in range(1, total):
		var tx := _snap(bar_x + bar_w * float(i) / total, p)
		draw_rect(Rect2(Vector2(tx, y + dot - p), Vector2(p, p)), C_OUT)


## I pallini seguono l'ordine dei colori usati (sempre gli stessi colori).
func _pair_color_for_slot(i: int) -> int:
	var used: Array = []
	for k in _endpoints.values():
		if not used.has(k):
			used.append(k)
	used.sort()
	return used[i] if i < used.size() else 0


## Sacca piena: cornice rossa che pulsa + barra del tempo che si consuma.
func _draw_countdown() -> void:
	var p := _px
	var red := Color("ff3b3b")
	var pulse := 0.55 + 0.45 * sin(_time * 10.0)
	var gsz := Vector2(_cell * grid_n, _cell * grid_n)
	var well := Rect2(_grid_origin, gsz).grow(p * 2)
	var glow := red
	glow.a = pulse
	draw_rect(Rect2(well.position - Vector2(p, p), Vector2(well.size.x + p * 2, p)), glow)
	draw_rect(Rect2(Vector2(well.position.x - p, well.end.y), Vector2(well.size.x + p * 2, p)), glow)
	draw_rect(Rect2(well.position - Vector2(p, p), Vector2(p, well.size.y + p * 2)), glow)
	draw_rect(Rect2(Vector2(well.end.x, well.position.y - p), Vector2(p, well.size.y + p * 2)), glow)
	# barra del tempo tra l'etichetta e la griglia
	var bar := Rect2(Vector2(well.position.x, _header_h - p * 4), Vector2(well.size.x, p * 2))
	draw_rect(bar.grow(p), C_OUT)
	var frac := clampf(_countdown_left / _countdown_total, 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(_snap(bar.size.x * frac, p), bar.size.y)), red)


func _draw_paused_overlay() -> void:
	var p := _px
	var gsz := Vector2(_cell * grid_n, _cell * grid_n)
	var r := Rect2(_grid_origin, gsz).grow(p * 2)
	draw_rect(r, Color(C_OUT.r, C_OUT.g, C_OUT.b, 0.78))
	# righe da "monitor"
	var y := r.position.y
	while y < r.end.y:
		draw_rect(Rect2(Vector2(r.position.x, y), Vector2(r.size.x, p)), Color(0, 0, 0, 0.25))
		y += p * 3
	var blink := int(_time * 3.0) % 2 == 0
	var cy := r.position.y + r.size.y * 0.5
	_draw_text("PAUSA", cy - 18.0, 16, C_MUTED, false)
	if blink:
		_draw_text("STRINGI", cy + 14.0, 24, C_GOLD)
		_draw_text("LA MANO!", cy + 42.0, 24, C_GOLD)


func _draw_done_overlay() -> void:
	var p := _px
	var gsz := Vector2(_cell * grid_n, _cell * grid_n)
	var r := Rect2(_grid_origin, gsz).grow(p * 2)
	var a := clampf(_done_t * 3.0, 0.0, 1.0)
	draw_rect(r, Color(C_OUT.r, C_OUT.g, C_OUT.b, 0.55 * a))
	# timbro "verificato" che entra con un piccolo rimbalzo
	var pop := 1.0 + 0.25 * maxf(0.0, 1.0 - _done_t * 4.0)
	var bw := _snap(r.size.x * 0.86 * pop, p)
	var bh := _snap(96.0 * pop, p)
	var box := Rect2(r.get_center() - Vector2(bw, bh) * 0.5, Vector2(bw, bh))
	box.position = Vector2(_snap(box.position.x, p), _snap(box.position.y, p))
	_notched_rect(box.grow(p), C_OUT, p * 2)
	_notched_rect(box, C_OK.darkened(0.25), p)
	_notched_rect(box.grow(-p * 2), C_OUT, p)
	_notched_rect(box.grow(-p * 3), Color("17331b"), p)
	if _font != null:
		var w := box.size.x
		draw_string(_font, Vector2(box.position.x + p, box.position.y + 42 + p), "VERIFICATE", HORIZONTAL_ALIGNMENT_CENTER, w, 24, C_OUT)
		draw_string(_font, Vector2(box.position.x, box.position.y + 42), "VERIFICATE", HORIZONTAL_ALIGNMENT_CENTER, w, 24, C_OK)
		draw_string(_font, Vector2(box.position.x, box.position.y + 74), "+%d PUNTI" % points, HORIZONTAL_ALIGNMENT_CENTER, w, 16, C_GOLD)
