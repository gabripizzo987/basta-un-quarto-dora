extends Control
## Tessera sanitaria del donatore (prima stanza), disegnata in pixel art.
## Il giocatore la confronta con il modulo: nome, sesso, eta' (dalla data di
## nascita) e scadenza devono combaciare.
## Grafica generica: nessun logo o stemma reale.

const PIXEL_FONT_PATH := "res://fonts/PixelOperator8.ttf"

const C_OUT    := Color("14201d")
const C_SHADOW := Color(0, 0, 0, 0.45)
const C_CARD   := Color("d4e8dc")
const C_CARD_HI := Color("e9f4ed")
const C_CARD_LO := Color("a9c7b7")
const C_HEAD   := Color("2c7361")
const C_HEAD_HI := Color("3f8f7b")
const C_INK    := Color("1d2826")
const C_MUTED  := Color("5b766d")
const C_CHIP   := Color("d9b04a")
const C_CHIP_LO := Color("a37e26")
const C_TODAY_BG := Color(0.118, 0.118, 0.141)

const W := 420.0
const H := 300.0
const TODAY_H := 34.0
const P := 4.0   # "pixel" della grafica

var _doc: Dictionary = {}
var _today := ""
var _font: Font = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(W, H + TODAY_H + 8.0)
	size = custom_minimum_size
	if ResourceLoader.exists(PIXEL_FONT_PATH):
		_font = load(PIXEL_FONT_PATH)


func set_donor(donor: Dictionary) -> void:
	_doc = donor.get("doc", {})
	var t := Time.get_date_dict_from_system()
	_today = "%02d/%02d/%04d" % [t.day, t.month, t.year]
	queue_redraw()


func _notched(r: Rect2, col: Color, n: float) -> void:
	draw_rect(Rect2(r.position + Vector2(n, 0), Vector2(r.size.x - n * 2, r.size.y)), col)
	draw_rect(Rect2(r.position + Vector2(0, n), Vector2(r.size.x, r.size.y - n * 2)), col)


func _text(pos: Vector2, s: String, size_px: int, col: Color) -> void:
	if _font != null:
		draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)


func _field(x: float, y: float, label: String, value: String) -> void:
	_text(Vector2(x, y), label, 16, C_MUTED)
	_text(Vector2(x, y + 20), value, 16, C_INK)


func _draw() -> void:
	if _doc.is_empty():
		return
	var card := Rect2(Vector2.ZERO, Vector2(W, H))

	# ombra, contorno, corpo con luce in alto e ombra in basso
	_notched(Rect2(card.position + Vector2(P * 2, P * 2), card.size), C_SHADOW, P * 2)
	_notched(card, C_OUT, P * 2)
	var body := card.grow(-P)
	_notched(body, C_CARD, P)
	draw_rect(Rect2(body.position + Vector2(P, 0), Vector2(body.size.x - P * 2, P)), C_CARD_HI)
	draw_rect(Rect2(Vector2(body.position.x + P, body.end.y - P), Vector2(body.size.x - P * 2, P)), C_CARD_LO)

	# fascia in alto
	var head := Rect2(body.position + Vector2(0, P), Vector2(body.size.x, 40))
	draw_rect(head, C_HEAD)
	draw_rect(Rect2(head.position, Vector2(head.size.x, P)), C_HEAD_HI)
	_text(head.position + Vector2(16, 28), "TESSERA SANITARIA", 16, Color.WHITE)
	# piccolo motivo a righe a destra della fascia
	for i in 5:
		draw_rect(Rect2(Vector2(head.end.x - 24 - i * 10, head.position.y + 10), Vector2(P, 20)), C_HEAD_HI)

	# chip dorato
	var chip := Rect2(Vector2(20, 66), Vector2(48, 38))
	draw_rect(chip.grow(P), C_OUT)
	draw_rect(chip, C_CHIP)
	draw_rect(Rect2(chip.position + Vector2(0, 12), Vector2(chip.size.x, P)), C_CHIP_LO)
	draw_rect(Rect2(chip.position + Vector2(0, 24), Vector2(chip.size.x, P)), C_CHIP_LO)
	draw_rect(Rect2(chip.position + Vector2(22, 0), Vector2(P, chip.size.y)), C_CHIP_LO)

	# campi
	var x0 := 88.0
	_field(x0, 70, "COGNOME", String(_doc.get("surname", "")))
	_field(x0, 112, "NOME", String(_doc.get("name", "")))
	_field(x0, 154, "SESSO", String(_doc.get("sex", "")))
	_field(x0 + 96, 154, "DATA DI NASCITA", "%02d/%02d/%04d" % [
		int(_doc.get("birth_d", 1)), int(_doc.get("birth_m", 1)), int(_doc.get("birth_y", 2000))])
	_field(20, 198, "CODICE FISCALE", String(_doc.get("cf", "")))
	_field(20, 242, "SCADENZA", "%02d/%02d/%04d" % [
		int(_doc.get("exp_d", 1)), int(_doc.get("exp_m", 1)), int(_doc.get("exp_y", 2030))])
	# data di oggi sotto la tessera (serve per eta' e scadenza)
	var today_txt := "Data di oggi: " + _today
	var tw := 300.0
	if _font != null:
		tw = _font.get_string_size(today_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 28.0
	var tag := Rect2(Vector2(0, H + 8), Vector2(tw, TODAY_H))
	var sb := preload("res://scripts/UiStyle.gd").panel_box(10)
	sb.shadow_size = 0
	draw_style_box(sb, tag)
	_text(tag.position + Vector2(14, 23), today_txt, 16, Color.WHITE)
