extends Node2D

@export var donor_scene: PackedScene
@export var minigame_scene: PackedScene

@onready var slots_parent: Node2D = $DonorSlots
@onready var ui: Node = $UI

var spawned_final_donors: Array = []
var final_ids: Array[int] = []
var current_index: int = 0
var donation_running := false


func _ready() -> void:
	# reset run della stanza finale (consigliato)
	RunState.reset_final_room_state()

	# 1) spawna idonei nei marker
	spawn_final_donors()

	# 2) prepara coda id
	final_ids = []
	for x in RunState.donors_for_final:
		final_ids.append(int(x))

	current_index = 0
	_start_next_donation()


func spawn_final_donors() -> void:
	for d in spawned_final_donors:
		if is_instance_valid(d):
			d.queue_free()
	spawned_final_donors.clear()

	if donor_scene == null:
		push_error("FinalRoom: donor_scene è NULL")
		return

	var slots: Array[Marker2D] = []
	for c in slots_parent.get_children():
		if c is Marker2D:
			slots.append(c as Marker2D)

	var ids: Array = RunState.donors_for_final
	if ids.is_empty():
		print("FINAL ROOM: nessun donatore idoneo da spawnare.")
		return

	var n: int = mini(ids.size(), slots.size())

	for i in range(n):
		var donor_id: int = int(ids[i])

		if donor_id < 0 or donor_id >= RunState.donors.size():
			push_warning("FINAL ROOM: donor_id fuori range: %s" % donor_id)
			continue

		var donor_data: Dictionary = RunState.donors[donor_id].duplicate(true)
		donor_data["id"] = donor_id

		var d := donor_scene.instantiate()
		add_child(d)

		(d as Node2D).global_position = slots[i].global_position

		if d.has_method("setup"):
			d.setup(donor_data)

		spawned_final_donors.append(d)

	print("FINAL ROOM - donors_for_final:", ids)


func _start_next_donation() -> void:
	# salta donor già processati (se per qualche motivo rientri)
	while current_index < final_ids.size():
		var donor_id := final_ids[current_index]
		if RunState.donation_completed_ids.has(donor_id) or RunState.donation_failed_ids.has(donor_id):
			current_index += 1
		else:
			break

	if current_index >= final_ids.size():
		_all_done()
		return

	var donor_id: int = final_ids[current_index]

	if minigame_scene == null:
		push_error("FinalRoom: minigame_scene è NULL")
		return

	var mg = minigame_scene.instantiate()
	ui.add_child(mg)

	mg.finished.connect(func(success: bool):
		if success:
			if not RunState.donation_completed_ids.has(donor_id):
				RunState.donation_completed_ids.append(donor_id)
			print("✅ DONAZIONE OK donor_id=", donor_id)
		else:
			if not RunState.donation_failed_ids.has(donor_id):
				RunState.donation_failed_ids.append(donor_id)
			print("❌ DONAZIONE SCARTATA donor_id=", donor_id)

		current_index += 1
		_start_next_donation()
	)


func _all_done() -> void:
	var ok := RunState.donation_completed_ids.size()
	var fail := RunState.donation_failed_ids.size()
	print("FINAL DONE - ok:", ok, " fail:", fail)

func start_donation_for(donor_id: int) -> void:
	if donation_running:
		return

	# se già completato/scartato, non riparte
	if RunState.donation_completed_ids.has(donor_id) or RunState.donation_failed_ids.has(donor_id):
		print("Donazione già registrata per questo donatore.")
		return

	donation_running = true

	var mg = minigame_scene.instantiate()
	$UI.add_child(mg)

	mg.finished.connect(func(success: bool):
		if success:
			if not RunState.donation_completed_ids.has(donor_id):
				RunState.donation_completed_ids.append(donor_id)
		else:
			if not RunState.donation_failed_ids.has(donor_id):
				RunState.donation_failed_ids.append(donor_id)

		_mark_donor_done_in_scene(donor_id)
		donation_running = false
	)

func _mark_donor_done_in_scene(donor_id: int) -> void:
	for d in spawned_final_donors:
		if not is_instance_valid(d):
			continue
		if d.has_method("get_donor_data"):
			var data = d.get_donor_data()
			if int(data.get("id", -1)) == donor_id:
				if d.has_method("set_done"):
					d.set_done(true)
				elif d.has_method("set_interaction_enabled"):
					d.set_interaction_enabled(false)
				return
