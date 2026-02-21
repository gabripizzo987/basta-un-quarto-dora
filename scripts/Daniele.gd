extends Node2D

@export var donor_id: int = -1
@export var donor_name: String = "Donatore"
@export var donor_sex: String = "M"

# ⬇️ SpriteFrames SEDUTI (già assegnati nello Inspector)
@export var frames_0: SpriteFrames
@export var frames_1: SpriteFrames
@export var frames_2: SpriteFrames
@export var frames_3: SpriteFrames
@export var frames_4: SpriteFrames

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var prompt = $InteractPrompt

var donor_done := false
var donor_busy := false
var interaction_enabled := true


func _ready() -> void:
	prompt.hide()
	_apply_sprite()


# 🔑 chiamata da EmocromoRoom quando il donatore viene spawnato
func setup(donor_data: Dictionary) -> void:
	donor_id = donor_data.get("id", -1)
	donor_name = donor_data.get("name", "Sconosciuto")
	donor_sex = donor_data.get("sex", "M")

	donor_done = false
	donor_busy = false

	_apply_sprite()


func _apply_sprite() -> void:
	if not sprite:
		return

	var chosen_frames: SpriteFrames = null

	match donor_id:
		0: chosen_frames = frames_0
		1: chosen_frames = frames_1
		2: chosen_frames = frames_2
		3: chosen_frames = frames_3
		4: chosen_frames = frames_4

	if chosen_frames == null:
		push_warning("SpriteFrames mancanti per donor_id=%d" % donor_id)
		return

	sprite.frames = chosen_frames
	sprite.play("default")  


func get_donor_data() -> Dictionary:
	return {
		"id": donor_id,
		"name": donor_name,
		"sex": donor_sex
	}


func interact(player: Node) -> void:
	print("DONOR INTERACT:", donor_id, donor_name, "scene=", get_tree().current_scene.name)
	if donor_done:
		if get_tree().current_scene.has_method("show_feedback"):
			get_tree().current_scene.show_feedback(
				"Hai già gestito %s." % donor_name
			)
		return

	var room := get_tree().current_scene
	if room and room.has_method("set_current_donor_node"):
		room.set_current_donor_node(self)

	# Se siamo in EmocromoRoom
	if room and room.has_method("start_emocromo_for"):
		room.start_emocromo_for(get_donor_data())
		return

	# Se siamo in FinalRoom (minigioco donazione)
	if room and room.has_method("start_donation_for"):
		room.start_donation_for(donor_id)
		return

	# fallback
	push_warning("Questa scena non gestisce l'interazione del donatore.")

func _on_area_2d_body_entered(body: Node2D) -> void:
	if donor_done or not interaction_enabled:
		return

	var room := get_tree().current_scene
	if room and room.has_method("can_start_interaction") and not room.can_start_interaction():
		return

	if body.has_method("set_can_move"):
		prompt.show()
		body.interact_target = self



func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.has_method("set_can_move"):
		prompt.hide()
		if body.interact_target == self:
			body.interact_target = null
			
func set_interaction_enabled(v: bool) -> void:
	interaction_enabled = v
	if $Area2D:
		$Area2D.monitoring = v
		$Area2D.monitorable = v
	if prompt:
		prompt.visible = false

func set_done(v: bool) -> void:
	donor_done = v
	if donor_done:
		set_interaction_enabled(false)
		# se vuoi “spento” come acceptance:
		if sprite:
			sprite.modulate = Color(0.6, 0.6, 0.6, 1.0)
