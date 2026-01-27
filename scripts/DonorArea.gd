extends Area2D

@export var slot_index: int = 0
@export var game_ui_path: NodePath
@export var prompt_path: NodePath  # trascina: UI/InteractPrompt

var game_ui: Node = null
var prompt: Node = null

var player_inside := false
var current_player: Node2D = null

func _ready() -> void:
	if game_ui_path != NodePath(""):
		game_ui = get_node(game_ui_path)

	if prompt_path != NodePath(""):
		prompt = get_node(prompt_path)

	if prompt != null and prompt.has_method("hide_prompt"):
		prompt.hide_prompt()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if prompt == null or game_ui == null:
		return

	# Se non sono dentro, non devo fare niente
	if not player_inside or current_player == null:
		return

	# Se UI aperta o donatore già fatto => nascondi (solo se era questo)
	if game_ui.is_panel_open() or game_ui.donors_done[slot_index]:
		_hide_if_this_donor_is_target()
		return

	# MOSTRA SOLO SE SONO IL DONATORE PIÙ VICINO (anti-overlap)
	if _am_i_the_closest_area():
		_show_for_this_donor()
	else:
		_hide_if_this_donor_is_target()

func _on_body_entered(body: Node) -> void:
	if body.name != "Player" and not body.is_in_group("player"):
		return

	player_inside = true
	current_player = body as Node2D
	body.interact_target = self

func _on_body_exited(body: Node) -> void:
	if body.name != "Player" and not body.is_in_group("player"):
		return

	player_inside = false
	current_player = null

	if body.interact_target == self:
		body.interact_target = null

	_hide_if_this_donor_is_target()

func interact(player: Node) -> void:
	if game_ui == null:
		return
	if game_ui.is_panel_open():
		return
	if game_ui.donors_done[slot_index]:
		return

	_hide_if_this_donor_is_target()

	player.set_can_move(false)

	if game_ui.has_method("start_triage_for_slot_from_player"):
		var donor_node := get_parent() as Node2D
		game_ui.start_triage_for_slot_from_player(slot_index, player, donor_node)
	else:
		game_ui.start_triage_for_slot(slot_index)

# -------------------------
# Helpers
# -------------------------

func _get_anchor_node() -> Node2D:
	var donor := get_parent() as Node2D
	if donor == null:
		return self as Node2D

	var anchor := donor.get_node_or_null("PromptAnchor") as Node2D
	return anchor if anchor != null else donor

func _show_for_this_donor() -> void:
	if prompt != null and prompt.has_method("show_for"):
		prompt.show_for(_get_anchor_node())

func _hide_if_this_donor_is_target() -> void:
	if prompt == null:
		return

	# se InteractPrompt.gd ha target_node, nascondi solo se è questo
	if "target_node" in prompt:
		if prompt.target_node == _get_anchor_node():
			if prompt.has_method("hide_prompt"):
				prompt.hide_prompt()
	else:
		# fallback
		if prompt.has_method("hide_prompt"):
			prompt.hide_prompt()

func _am_i_the_closest_area() -> bool:
	# Se non ho player, non posso decidere
	if current_player == null:
		return false

	var my_anchor: Node2D = _get_anchor_node()
	if my_anchor == null:
		return false

	var my_dist: float = my_anchor.global_position.distance_to(current_player.global_position)

	for a in get_tree().get_nodes_in_group("donor_area"):
		if a == self:
			continue

		# Considera solo le aree dove il player è dentro
		if not a.player_inside or a.current_player == null:
			continue

		var other_anchor: Node2D = a._get_anchor_node()
		if other_anchor == null:
			continue

		var other_dist: float = other_anchor.global_position.distance_to(current_player.global_position)

		if other_dist < my_dist:
			return false

	return true
