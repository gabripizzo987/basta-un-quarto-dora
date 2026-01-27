extends Control

@export var offset_pixels: Vector2 = Vector2(0, -60) # quanto sopra la testa

var target_node: Node2D = null

func _ready() -> void:
	visible = false
	# IMPORTANTISSIMO: assicurati che il Control abbia anchor top-left
	set_anchors_preset(Control.PRESET_TOP_LEFT)

func show_for(node: Node2D) -> void:
	target_node = node
	visible = true
	call_deferred("_update_pos") # così size è già calcolata

func hide_prompt() -> void:
	visible = false
	target_node = null

func _process(_delta: float) -> void:
	if visible and target_node != null:
		_update_pos()

func _update_pos() -> void:
	if target_node == null:
		return

	# WORLD -> SCREEN (include Camera2D automaticamente)
	var world_pos: Vector2 = target_node.global_position
	var screen_pos: Vector2 = get_viewport().get_canvas_transform() * world_pos

	# centro sopra al donatore
	var p := screen_pos + offset_pixels
	p.x -= size.x * 0.5      # centra in X
	p.y -= size.y            # sopra (in Y)

	global_position = p
