extends Area2D

@export var slot_index: int = 0            # 0 donor1, 1 donor2, ecc.
@export var game_ui_path: NodePath         # set da Inspector (es: ../../UI/TriageUI)

@onready var prompt: Control = get_parent().get_node("InteractPrompt")

var game_ui: Node = null


func _ready() -> void:
	if game_ui_path != NodePath(""):
		game_ui = get_node(game_ui_path)

	# prompt parte nascosto
	if prompt != null:
		prompt.visible = false

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	body.interact_target = self

	# mostra prompt solo se:
	# - UI esiste
	# - pannello NON è già aperto
	# - questo donatore NON è già stato valutato
	if prompt != null and game_ui != null:
		if not game_ui.is_panel_open() and not game_ui.donors_done[slot_index]:
			prompt.visible = true


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	if body.interact_target == self:
		body.interact_target = null

	if prompt != null:
		prompt.visible = false


# chiamata dal Player quando premi E
func interact(player: Node) -> void:
	if game_ui == null:
		return

	# se pannello è già aperto, non fare niente
	if game_ui.is_panel_open():
		return

	# se già valutato, non far aprire
	if game_ui.donors_done[slot_index]:
		if prompt != null:
			prompt.visible = false
		return

	# quando interagisci, nascondi prompt
	if prompt != null:
		prompt.visible = false

	# blocca player e apri triage
	player.set_can_move(false)

	if game_ui.has_method("start_triage_for_slot_from_player"):
		game_ui.start_triage_for_slot_from_player(slot_index, player)
	else:
		game_ui.start_triage_for_slot(slot_index)
