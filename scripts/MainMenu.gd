extends Control

func _on_Inizia_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game/Game.tscn")

func _on_button_pressed() -> void:
	print("Start premuto")
	get_tree().change_scene_to_file("res://scenes/rooms/AcceptanceRoom.tscn")
	
func _ready():
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
