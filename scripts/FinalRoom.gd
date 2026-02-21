extends Node2D

@export var donor_scene: PackedScene
@export var minigame_scene: PackedScene

@onready var slots_parent: Node2D = $DonorSlots

# UI ROOT
@onready var ui: Node = $UI
@onready var hud_layer: CanvasLayer = $UI/HUD

# ---- INTRO/SUMMARY UI (path CORRETTI dai tuoi screen) ----
@onready var intro_layer: CanvasLayer = $UI/IntroLayer
@onready var overlay_root: Control   = $UI/IntroLayer/OverlayRoot
@onready var dim: ColorRect          = $UI/IntroLayer/OverlayRoot/Dim
@onready var intro_panel: Control    = $UI/IntroLayer/OverlayRoot/IntroPanel
@onready var intro_title: Label      = $UI/IntroLayer/OverlayRoot/IntroPanel/Margin/VBox/Title
@onready var intro_body: Label       = $UI/IntroLayer/OverlayRoot/IntroPanel/Margin/VBox/Body
@onready var intro_btn: Button       = $UI/IntroLayer/OverlayRoot/IntroPanel/Margin/VBox/ButtonsRow/Intro

@export var DEBUG_FINAL: bool = true

var spawned_final_donors: Array = []
var donation_running: bool = false
var intro_open: bool = false
var summary_open: bool = false

# lock robusto (senza gruppi)
var _locked_player: Node = null
var _locks: int = 0


func _ready() -> void:
	if DEBUG_FINAL:
		print("[FINALROOM] _ready()  scene=", get_tree().current_scene.name)

	# ATTENZIONE: lascia SOLO se non ti svuota donors_for_final
	RunState.reset_final_room_state()

	spawn_final_donors()
	_apply_panel_layout_for_text()

	if not RunState.tutorial_final_seen:
		RunState.tutorial_final_seen = true
		_show_intro()
	else:
		_hide_overlay()


# -------------------------------------------------
# SPAWN DONORS
# -------------------------------------------------
func spawn_final_donors() -> void:
	for d in spawned_final_donors:
		if is_instance_valid(d):
			d.queue_free()
	spawned_final_donors.clear()

	if donor_scene == null:
		push_error("FinalRoom: donor_scene NULL")
		return

	var slots: Array[Marker2D] = []
	for c in slots_parent.get_children():
		if c is Marker2D:
			slots.append(c as Marker2D)

	var ids: Array = RunState.donors_for_final
	if DEBUG_FINAL:
		print("[FINALROOM] donors_for_final=", ids)

	if ids.is_empty():
		print("[FINALROOM] nessun donatore idoneo.")
		return

	var n: int = mini(ids.size(), slots.size())
	for i in range(n):
		var donor_id: int = int(ids[i])
		if donor_id < 0 or donor_id >= RunState.donors.size():
			push_warning("[FINALROOM] donor_id fuori range: %s" % donor_id)
			continue

		var donor_data: Dictionary = RunState.donors[donor_id].duplicate(true)
		donor_data["id"] = donor_id

		var d := donor_scene.instantiate()
		add_child(d)
		(d as Node2D).global_position = slots[i].global_position

		if d.has_method("setup"):
			d.setup(donor_data)

		# IMPORTANT: rendilo interagibile
		if d.has_method("set_done"):
			d.set_done(false)
		if d.has_method("set_interaction_enabled"):
			d.set_interaction_enabled(true)

		spawned_final_donors.append(d)

	print("[FINALROOM] spawned=", spawned_final_donors.size())


# -------------------------------------------------
# DONATION (chiamata dal donor quando premi E)
# -------------------------------------------------
func start_donation_for(donor_id: int) -> void:
	if DEBUG_FINAL:
		print("[FINALROOM] start_donation_for donor_id=", donor_id,
			" intro_open=", intro_open,
			" summary_open=", summary_open,
			" donation_running=", donation_running)

	if intro_open or summary_open:
		return
	if donation_running:
		return

	if RunState.donation_completed_ids.has(donor_id) or RunState.donation_failed_ids.has(donor_id):
		return

	if minigame_scene == null:
		push_error("FinalRoom: minigame_scene NULL")
		return

	donation_running = true
	_lock_player()

	var mg := minigame_scene.instantiate()

	# ✅ Mettilo nell’HUD (CanvasLayer)
	hud_layer.add_child(mg)

	# full screen overlay
	if mg is Control:
		var c := mg as Control
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.offset_left = 0
		c.offset_top = 0
		c.offset_right = 0
		c.offset_bottom = 0
		c.z_index = 999

	# safety (se chiude senza finished)
	mg.tree_exited.connect(func():
		if DEBUG_FINAL: print("[FINALROOM] minigame tree_exited safety")
		donation_running = false
		_unlock_player()
	)

	# risultato
	mg.finished.connect(func(success: bool):
		if DEBUG_FINAL:
			print("[FINALROOM] <<< minigame finished donor_id=", donor_id, " success=", success)

		if success:
			if not RunState.donation_completed_ids.has(donor_id):
				RunState.donation_completed_ids.append(donor_id)
		else:
			if not RunState.donation_failed_ids.has(donor_id):
				RunState.donation_failed_ids.append(donor_id)
			RunState.mistakes_total += 1

		_mark_donor_done_in_scene(donor_id)
		donation_running = false
		_unlock_player()
		_try_finish_room()
	)


func _mark_donor_done_in_scene(donor_id: int) -> void:
	for d in spawned_final_donors:
		if not is_instance_valid(d):
			continue
		if d.has_method("get_donor_data"):
			var data: Dictionary = d.get_donor_data()
			if int(data.get("id", -1)) == donor_id:
				if d.has_method("set_done"):
					d.set_done(true)
				elif d.has_method("set_interaction_enabled"):
					d.set_interaction_enabled(false)
				return


func _try_finish_room() -> void:
	var total := RunState.donors_for_final.size()
	var done := RunState.donation_completed_ids.size() + RunState.donation_failed_ids.size()
	if total > 0 and done >= total:
		_show_summary()


# -------------------------------------------------
# OVERLAYS (INTRO/SUMMARY)
# -------------------------------------------------
func _apply_panel_layout_for_text() -> void:
	intro_panel.custom_minimum_size = Vector2(620, 280)
	intro_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	intro_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	intro_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_body.clip_text = false


func _show_intro() -> void:
	intro_open = true
	summary_open = false
	_lock_player()

	intro_layer.visible = true
	overlay_root.visible = true
	dim.visible = true
	intro_panel.visible = true

	intro_title.text = "Stanza finale — Donazione"
	intro_body.text = \
		"Ultimo step: completa la donazione per i donatori idonei.\n\n" + \
		"• Avvicinati e premi E.\n" + \
		"• La sacca si riempie nel tempo.\n" + \
		"• Se compare 'Flusso basso', premi/lascia (anche tenendo premuto).\n\n" + \
		"Ogni donazione fallita aumenta gli errori totali."

	intro_btn.text = "Inizia"

	if intro_btn.pressed.is_connected(_on_intro_pressed):
		intro_btn.pressed.disconnect(_on_intro_pressed)
	if intro_btn.pressed.is_connected(_on_summary_pressed):
		intro_btn.pressed.disconnect(_on_summary_pressed)

	intro_btn.pressed.connect(_on_intro_pressed)


func _on_intro_pressed() -> void:
	_hide_overlay()


func _show_summary() -> void:
	intro_open = false
	summary_open = true
	_lock_player()

	var ok := RunState.donation_completed_ids.size()
	var fail := RunState.donation_failed_ids.size()
	var total := RunState.donors_for_final.size()

	for d in spawned_final_donors:
		if is_instance_valid(d) and d.has_method("set_interaction_enabled"):
			d.set_interaction_enabled(false)

	intro_layer.visible = true
	overlay_root.visible = true
	dim.visible = true
	intro_panel.visible = true

	intro_title.text = "Stanza completata ✅"
	intro_body.text = \
		"Donazioni completate: %d / %d\n" % [ok, total] + \
		"Donazioni fallite: %d\n" % [fail] + \
		"Errori totali: %d" % [RunState.mistakes_total]

	intro_btn.text = "Fine"

	if intro_btn.pressed.is_connected(_on_intro_pressed):
		intro_btn.pressed.disconnect(_on_intro_pressed)
	if intro_btn.pressed.is_connected(_on_summary_pressed):
		intro_btn.pressed.disconnect(_on_summary_pressed)

	intro_btn.pressed.connect(_on_summary_pressed)


func _on_summary_pressed() -> void:
	print("END GAME / BACK TO MENU")
	# get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _hide_overlay() -> void:
	intro_open = false
	summary_open = false
	intro_layer.visible = false
	overlay_root.visible = false
	dim.visible = false
	intro_panel.visible = false
	_unlock_player()


# -------------------------------------------------
# PLAYER LOCK/UNLOCK (SENZA GRUPPI)
# Cerca il primo nodo che ha set_can_move()
# -------------------------------------------------
func _find_player_with_can_move() -> Node:
	var root := get_tree().current_scene
	if root == null:
		return null
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n != null and n.has_method("set_can_move"):
			return n
		for c in n.get_children():
			stack.append(c)
	return null


func _lock_player() -> void:
	_locks += 1
	if _locks > 1:
		return
	get_viewport().gui_release_focus()

	if _locked_player == null:
		_locked_player = _find_player_with_can_move()
	if _locked_player == null:
		if DEBUG_FINAL: print("[LOCK] player not found (no set_can_move). Skip lock.")
		return

	_locked_player.set_can_move(false)


func _unlock_player() -> void:
	_locks -= 1
	if _locks > 0:
		return
	_locks = 0
	get_viewport().gui_release_focus()

	if _locked_player != null:
		_locked_player.set_can_move(true)
		_locked_player = null
