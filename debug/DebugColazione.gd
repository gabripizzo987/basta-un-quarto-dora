extends Control
## Scena di DEBUG per provare la sala colazione da PC.
## Apri debug/DebugColazione.tscn in Godot e premi F6 (Esegui scena corrente).
## Non viene inclusa nelle esportazioni (filtro "debug/*").
##
## Tasti: INVIO = avvia la sala colazione (sempre 5 donatori)
##        R     = ricomincia

const PIXEL_FONT := "res://fonts/PixelOperator8.ttf"

var _layer: CanvasLayer = null
var _info: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("140507")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_info = Label.new()
	_info.position = Vector2(40, 40)
	_info.add_theme_font_size_override("font_size", 20)
	_info.add_theme_color_override("font_color", Color("efe7e2"))
	if ResourceLoader.exists(PIXEL_FONT):
		_info.add_theme_font_override("font", load(PIXEL_FONT))
	add_child(_info)
	_show_menu()


func _show_menu(extra: String = "") -> void:
	_info.text = "DEBUG SALA COLAZIONE\n\n" + \
		"INVIO  avvia la sala colazione (sempre 5 donatori)\n" + \
		"R      ricomincia\n\n" + \
		"Trascina acqua, succo, biscotto o caffè sul donatore che lo chiede." + extra


func _start() -> void:
	if is_instance_valid(_layer):
		_layer.queue_free()
	RunState.reset_run_state()
	# come nel gioco vero: la sala finale passa i 5 donatori della giornata
	RunState.donors = [
		{"name": "Gabriele", "sex": "M"}, {"name": "Claudio", "sex": "M"},
		{"name": "Daniele", "sex": "M"}, {"name": "Anna", "sex": "F"},
		{"name": "Elisa", "sex": "F"}]
	var donor_data: Array = []
	for i in RunState.donors.size():
		donor_data.append({"name": RunState.donors[i].name, "sprite_idx": i})

	_layer = CanvasLayer.new()
	_layer.layer = 250
	add_child(_layer)
	var mg := preload("res://scripts/BreakfastMinigame.gd").new()
	mg.setup(donor_data)
	_layer.add_child(mg)
	mg.finished.connect(_on_finished)


func _on_finished() -> void:
	if is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
	_show_menu("\n\nUltima partita: %d punti colazione." % RunState.score_breakfast)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_R:
			_start()
