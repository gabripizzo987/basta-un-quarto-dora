extends Control
## Scena di DEBUG per provare la seconda stanza (emocromo) da PC.
## Apri debug/DebugEmocromo.tscn in Godot e premi F6 (Esegui scena corrente).
## Non viene inclusa nelle esportazioni (filtro "debug/*").
##
## Tasti: 1 / 2 / 3 = entra nella stanza in FACILE / MEDIO / DIFFICILE
## Nella stanza: frecce/WASD per muoverti, E per interagire.

const PIXEL_FONT := "res://fonts/PixelOperator8.ttf"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("140507")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var l := Label.new()
	l.text = "DEBUG STANZA EMOCROMO\n\n" + \
		"1  FACILE     ago normale\n" + \
		"2  MEDIO      ago +20%\n" + \
		"3  DIFFICILE  ago +45%\n\n" + \
		"Nella stanza: frecce/WASD per muoverti, E per interagire."
	l.position = Vector2(40, 40)
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color("efe7e2"))
	if ResourceLoader.exists(PIXEL_FONT):
		l.add_theme_font_override("font", load(PIXEL_FONT))
	add_child(l)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode in [KEY_1, KEY_2, KEY_3]:
		_start_room(event.keycode - KEY_1)


func _start_room(diff: int) -> void:
	RunState.reset_run_state()
	RunState.difficulty = diff
	# 5 donatori finti arrivati dalla prima stanza (gli id scelgono gli sprite)
	RunState.donors = [
		{"name": "Gabriele", "sex": "M"},
		{"name": "Claudio", "sex": "M"},
		{"name": "Daniele", "sex": "M"},
		{"name": "Anna", "sex": "F"},
		{"name": "Elisa", "sex": "F"},
	]
	RunState.donors_for_donation = [0, 1, 2, 3, 4]
	get_tree().change_scene_to_file("res://scenes/EmocromoRoom.tscn")
