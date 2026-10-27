extends Control
## Scena di DEBUG per provare il minigioco "Etichette" da PC.
## Apri debug/DebugLabelPuzzle.tscn in Godot e premi F6 (Esegui scena corrente).
## Non viene inclusa nelle esportazioni (filtro "debug/*").
##
## Tasti:
##   1 / 2 / 3  difficolta' FACILE / MEDIO / DIFFICILE
##   Q  puzzle del primo donatore     W  puzzle dei donatori successivi
##   R  nuovo puzzle                  P  pausa on/off (simula la mano)
##   S  risolvi da solo               D  donazione completa (sacca + mano + puzzle)
##   ESC  torna al puzzle da solo

const PUZZLE_SCRIPT := preload("res://scripts/LabelMatchPuzzle.gd")
const DONATION_SCENE := preload("res://scenes/DonationMinigame.tscn")
const PIXEL_FONT := "res://fonts/PixelOperator8.ttf"

var _puzzle: Control = null
var _donation: Node = null
var _first_donor: bool = true
var _info: Label = null
var _status: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("140507")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_info = _make_label(16, Color("b79a95"))
	_info.position = Vector2(24, 20)
	_info.text = "DEBUG ETICHETTE\n\n1 2 3  facile medio difficile\nQ  primo donatore\nW  donatori successivi\nR  nuovo puzzle\nP  pausa (mano)\nS  risolvi da solo\nD  donazione completa\nESC  torna qui"
	add_child(_info)

	_status = _make_label(16, Color("ffce38"))
	_status.position = Vector2(24, 330)
	add_child(_status)

	get_viewport().size_changed.connect(_center_puzzle)
	_new_puzzle()


func _make_label(font_size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	if ResourceLoader.exists(PIXEL_FONT):
		l.add_theme_font_override("font", load(PIXEL_FONT))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _rules() -> Array:
	var r: Dictionary = RunState.label_rules()
	if _first_donor:
		return [r.size_first, r.pairs_first, r.points, r.grace]
	return [r.size, r.pairs, r.points, r.grace]


func _describe() -> String:
	var r := _rules()
	return "%s - %s\ngriglia %dx%d, %d colori\n+%d punti, %ds extra" % [
		RunState.DIFFICULTY_NAMES[RunState.difficulty],
		"primo donatore" if _first_donor else "donatori successivi",
		r[0], r[0], r[1], r[2], int(r[3])]


func _new_puzzle() -> void:
	_clear_donation()
	if is_instance_valid(_puzzle):
		_puzzle.queue_free()
	var r := _rules()
	_puzzle = PUZZLE_SCRIPT.new()
	_puzzle.setup(r[0], r[1])
	_puzzle.points = r[2]
	add_child(_puzzle)
	_puzzle.solved.connect(_on_solved)
	_center_puzzle()
	_status.text = _describe() + "\n\nPunti etichette: %d" % RunState.score_labels


func _center_puzzle() -> void:
	if is_instance_valid(_puzzle):
		var vp := get_viewport_rect().size
		_puzzle.position = ((vp - _puzzle.size) * 0.5).round()


func _on_solved() -> void:
	RunState.score_labels += _puzzle.points
	RunState.labels_verified += 1
	_status.text = _describe() + "\n\nRISOLTO!\nPunti etichette: %d" % RunState.score_labels


func _start_donation() -> void:
	if is_instance_valid(_puzzle):
		_puzzle.queue_free()
		_puzzle = null
	_clear_donation()
	var mg := DONATION_SCENE.instantiate()
	mg.set_show_tutorial(true)
	mg.set_puzzle_from_rules(_first_donor)
	add_child(mg)
	mg.finished.connect(_on_donation_finished)
	_donation = mg
	_status.text = _describe() + "\n\nDonazione in corso...\n(ESC per uscire)"


func _on_donation_finished(success: bool) -> void:
	_donation = null
	var why := ""
	if not success:
		why = " (etichette)" if RunState.last_donation_fail_reason == "labels" else " (flusso)"
	_status.text = _describe() + "\n\nDonazione %s%s\nPunti etichette: %d\nD per rifarla, R per il puzzle" % [
		"RIUSCITA" if success else "FALLITA", why, RunState.score_labels]


func _clear_donation() -> void:
	if is_instance_valid(_donation):
		_donation.queue_free()
	_donation = null


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_1, KEY_2, KEY_3:
			RunState.difficulty = event.keycode - KEY_1
			_new_puzzle()
		KEY_Q:
			_first_donor = true
			_new_puzzle()
		KEY_W:
			_first_donor = false
			_new_puzzle()
		KEY_R, KEY_ESCAPE:
			_new_puzzle()
		KEY_P:
			if is_instance_valid(_puzzle):
				_puzzle.set_paused(not _puzzle._paused)
		KEY_S:
			if is_instance_valid(_puzzle):
				_puzzle.debug_fill(99)
		KEY_D:
			_start_donation()
