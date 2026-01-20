extends Node2D

@export var donor_name: String = "Daniele"
@export var donor_sex: String = "M"
@export var donor_id: int = 1

@onready var prompt = $InteractPrompt

func _ready() -> void:
	prompt.hide()

func get_donor_data() -> Dictionary:
	return {"id": donor_id, "name": donor_name, "sex": donor_sex}

func interact(player: Node) -> void:
	get_tree().current_scene.start_emocromo_for(get_donor_data())

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.has_method("set_can_move"):
		prompt.show()
		body.interact_target = self

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.has_method("set_can_move"):
		prompt.hide()
		if body.interact_target == self:
			body.interact_target = null
