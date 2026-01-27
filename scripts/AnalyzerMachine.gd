extends Area2D

signal interacted(player: Node)

@onready var prompt: Control = get_parent().get_node("InteractPrompt")

var enabled: bool = false
var _player_inside: Node = null

func _ready() -> void:
	if prompt:
		prompt.visible = false

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func set_enabled(v: bool) -> void:
	enabled = v
	_update_prompt(false)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player") and not body.has_method("set_can_move"):
		return

	_player_inside = body
	body.interact_target = self

	_update_prompt(false)

func _on_body_exited(body: Node) -> void:
	if _player_inside == body:
		_player_inside = null

	if body.get("interact_target") == self:
		body.interact_target = null

	_update_prompt(true)

func _update_prompt(force_hide: bool) -> void:
	if not prompt:
		return

	if force_hide:
		prompt.visible = false
		return

	prompt.visible = enabled and _player_inside != null

func interact(player: Node) -> void:
	if not enabled:
		return

	_update_prompt(true)
	emit_signal("interacted", player)

func try_interact(player: Node) -> bool:
	if not enabled:
		return false
	interact(player)
	return true
