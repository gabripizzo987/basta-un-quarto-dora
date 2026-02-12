extends CharacterBody2D

const SPEED = 150.0
@onready var anim = $AnimatedSprite2D

var last_direction = "down"
var can_move := true

var interact_target: Node = null 

func set_can_move(value: bool) -> void:
	can_move = value
	if not can_move:
		velocity = Vector2.ZERO
		update_animation(Vector2.ZERO)

func _physics_process(delta: float) -> void:
	if not can_move:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var input_vector = Vector2.ZERO
	if Input.is_action_pressed("move_right"):
		input_vector.x += 1
	if Input.is_action_pressed("move_left"):
		input_vector.x -= 1
	if Input.is_action_pressed("move_down"):
		input_vector.y += 1
	if Input.is_action_pressed("move_up"):
		input_vector.y -= 1

	input_vector = input_vector.normalized()
	velocity = input_vector * SPEED
	move_and_slide()
	update_animation(input_vector)

func _unhandled_input(event: InputEvent) -> void:
	# Interazione SOLO con E
	if not can_move:
		return

	if event.is_action_pressed("interact"):
		if interact_target != null:
			# chiama una funzione sul donatore
			if interact_target.has_method("interact"):
				interact_target.interact(self)

func update_animation(input_vector: Vector2) -> void:
	if input_vector == Vector2.ZERO:
		match last_direction:
			"down": anim.play("idle_down")
			"up": anim.play("idle_up")
			"left": anim.play("idle_left")
			"right": anim.play("idle_right")
	else:
		if abs(input_vector.x) > abs(input_vector.y):
			if input_vector.x > 0:
				last_direction = "right"
				anim.play("walk_right")
			else:
				last_direction = "left"
				anim.play("walk_left")
		else:
			if input_vector.y > 0:
				last_direction = "down"
				anim.play("walk_down")
			else:
				last_direction = "up"
				anim.play("walk_up")
				
func face_up_idle() -> void:
	last_direction = "up"
	update_animation(Vector2.ZERO)
