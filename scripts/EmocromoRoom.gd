extends Node2D

@export var donor_scene: PackedScene
@onready var dim: ColorRect = $IntroLayer/Dim
@onready var intro_panel: Control = $IntroLayer/IntroPanel
@onready var player: Node = $Nurse
@onready var pressure_panel: Panel = $UI/PressurePanel
@onready var nurse_anim: AnimatedSprite2D = $Nurse/AnimatedSprite2D
@onready var overlay: Control = $UI/PressureOverlay
@onready var overlay_img: TextureRect = $UI/PressureOverlay/SfigmoBig
@onready var blood_minigame: Control = $UI/BloodDrawMiniGame
@onready var edta_icon: TextureRect = $UI/EDTATubeIcon
@onready var analyzer_machine: Area2D = $AnalyzerMachine/InteractArea
@onready var seat_markers: Array[Marker2D] = [
	$SeatMarker1,
	$SeatMarker2,
	$SeatMarker3,
	$SeatMarker4,
	$SeatMarker5
]

var emocromo_errors: Array[Dictionary] = []
var machine_busy: bool = false
var player_near_machine: bool = false
var donor := {"name": "Donatore Test", "sex": "M"}
var pressure_ok := true
var results := {}

enum FlowState { IDLE, IN_PRESSURE, WAIT_RETRY, IN_DRAW, IN_ANALYSIS, IN_RESULTS }
var state: FlowState = FlowState.IDLE
var pressure_attempts := 0
var pressure_last_sys := 0
var next_action: Callable = Callable()

var has_blood_sample: bool = false
var analysis_done: bool = false
var donor_busy: bool = false
var donor_done: bool = false
var decision_lock: bool = false
var completed_donor_ids: Array[int] = []
var current_donor_node: Node = null
var spawned_donors: Array[Node] = []

@export var MIN_ELIGIBLE_TO_FINAL: int = 3
@export var MAX_ELIGIBLE_TO_FINAL: int = 5

var forced_eligible_ids: Array[int] = []
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	$UI.hide()
	player.set_can_move(false)
	pressure_panel.continued.connect(_on_panel_continue)
	pressure_panel.accepted.connect(_on_decision_accept)
	pressure_panel.rejected.connect(_on_decision_reject)
	blood_minigame.done.connect(_on_blood_minigame_done)
	analyzer_machine.body_entered.connect(_on_machine_body_entered)
	analyzer_machine.body_exited.connect(_on_machine_body_exited)
	analyzer_machine.interacted.connect(_on_machine_interacted)

	analyzer_machine.set_enabled(false)
	
	if edta_icon:
		edta_icon.visible = false
	print("PLAYER layer/mask: ", $Nurse.collision_layer, " / ", $Nurse.collision_mask)
	spawn_donors_on_seats()
	_pick_forced_eligible_ids()
	rng.randomize()
	print("FORCED ELIGIBLE IDS:", forced_eligible_ids)
	
	print("SUMMARY TITLE:", $SummaryLayer/SummaryPanel/Margin/VBox/Title)
	print("SUMMARY BODY:", $SummaryLayer/SummaryPanel/Margin/VBox/Body)
	print("SUMMARY BTN:", $SummaryLayer/SummaryPanel/Margin/VBox/ButtonsRow/Continue)
	
func _on_intro_pressed() -> void:
	dim.hide()
	intro_panel.hide()
	$UI.show()
	player.set_can_move(true)
	state = FlowState.IDLE
	show_feedback("Avvicinati al donatore e premi E per iniziare.")

func start_emocromo_for(d: Dictionary) -> void:
	var id := int(d.get("id", -1))

	if id != -1 and completed_donor_ids.has(id):
		show_feedback("Hai già raccolto il campione da questo donatore.")
		return

	if donor_busy or state != FlowState.IDLE:
		show_feedback("Procedura già in corso...")
		return

	donor_busy = true
	donor = d.duplicate(true)
	_lock_other_donors(true)
	show_feedback("Donatore: %s (%s)" % [donor["name"], donor["sex"]])
	player.set_can_move(false)
	start_pressure_phase()

	has_blood_sample = false
	analysis_done = false
	if edta_icon:
		edta_icon.visible = false
		

func start_pressure_phase() -> void:
	state = FlowState.IN_PRESSURE
	pressure_attempts = 0
	pressure_last_sys = generate_pressure_base()
	player.set_can_move(false)

	pressure_panel.show_wait("Misurazione pressione", "Misurazione in corso...")

	if nurse_anim and nurse_anim.sprite_frames and nurse_anim.sprite_frames.has_animation("use"):
		nurse_anim.play("use")
	elif nurse_anim:
		nurse_anim.play("idle_up")

	show_sfigmo()

	await get_tree().create_timer(1.5).timeout

	hide_sfigmo()
	if nurse_anim:
		nurse_anim.play("idle_up")

	_handle_pressure_result()
	

func generate_pressure_ok() -> bool:
	return randi() % 5 != 0

func start_blood_draw_phase() -> void:
	state = FlowState.IN_DRAW
	pressure_panel.show_wait(
		"Prelievo campione",
		"Inserimento ago: premi E al momento giusto."
	)
	blood_minigame.start()

func start_analysis_phase() -> void:
	state = FlowState.IN_ANALYSIS
	pressure_panel.show_wait("Laboratorio analisi", "Analisi dell’emocromo in corso...")
	await get_tree().create_timer(6.5).timeout

	generate_results()
	open_results_ui()

func generate_results() -> void:
	var id := int(donor.get("id", -1))

	if id != -1 and forced_eligible_ids.has(id):
		results = _generate_eligible_results_for(str(donor.get("sex", "M")))
	else:
		results = {
			"hb": snappedf(randf_range(11.0, 16.0), 0.1),
			"wbc": snappedf(randf_range(3.0, 13.0), 0.1),
			"plt": randi_range(120, 450)
		}

	print("RISULTATI:", results, " | donor_id=", id, " forced=", (id != -1 and forced_eligible_ids.has(id)))

func evaluate_results() -> void:
	var eligible = is_eligible(donor["sex"], results)
	if $UI/TriageUI.has_method("show_results"):
		$UI/TriageUI.show_results(results, donor, eligible)
	else:
		show_feedback("Idoneo" if eligible else "Non idoneo")
	player.set_can_move(true)

func is_eligible(sex: String, r: Dictionary) -> bool:
	var hb_ok = (sex == "M" and r["hb"] >= 13.5) or (sex == "F" and r["hb"] >= 12.5)
	var wbc_ok = r["wbc"] >= 4.0 and r["wbc"] <= 11.0
	var plt_ok = r["plt"] >= 150 and r["plt"] <= 400
	return hb_ok and wbc_ok and plt_ok

func show_feedback(text: String) -> void:
	if $UI/TriageUI.has_method("show_feedback"):
		$UI/TriageUI.show_feedback(text)
	else:
		print(text)
		

func open_results_ui() -> void:
	state = FlowState.IN_RESULTS
	var txt := "Hb: %.1f g/dL\nWBC: %.1f x10^3/µL\nPLT: %d x10^3/µL\n\nScegli cosa fare:" % [
		results["hb"], results["wbc"], results["plt"]
	]
	pressure_panel.show_decision("Risultati emocromo", txt)
		
func compute_ineligibility_reasons(sex: String, r: Dictionary) -> Array[String]:
	var reasons: Array[String] = []

	if sex == "M" and r["hb"] < 13.5:
		reasons.append("Emoglobina bassa (Hb < 13.5)")
	if sex == "F" and r["hb"] < 12.5:
		reasons.append("Emoglobina bassa (Hb < 12.5)")

	if r["wbc"] < 4.0:
		reasons.append("Globuli bianchi bassi (WBC < 4.0)")
	elif r["wbc"] > 11.0:
		reasons.append("Globuli bianchi alti (WBC > 11.0)")

	if r["plt"] < 150:
		reasons.append("Piastrine basse (PLT < 150)")
	elif r["plt"] > 400:
		reasons.append("Piastrine alte (PLT > 400)")

	return reasons
	

func end_flow() -> void:
	state = FlowState.IDLE
	player.set_can_move(true)
	pressure_attempts = 0

	donor_busy = false

	var id := int(donor.get("id", -1))
	if id != -1 and not completed_donor_ids.has(id):
		completed_donor_ids.append(id)

	has_blood_sample = false
	analysis_done = true

	if current_donor_node and is_instance_valid(current_donor_node) and current_donor_node.has_method("set_done"):
		current_donor_node.set_done(true)

	if completed_donor_ids.size() >= spawned_donors.size():
		_show_room_summary()
		return  

	_lock_other_donors(false)
	current_donor_node = null

func _on_button_pressed() -> void:
	var eligible := is_eligible(donor["sex"], results)
	if eligible:
		show_feedback("✅ Scelta corretta: donatore idoneo.")
	else:
		var reasons = compute_ineligibility_reasons(donor["sex"], results)
		show_feedback("❌ Scelta errata: dovevi rimandare. Motivo: " + ", ".join(reasons))
		
	end_flow()


func _on_button_2_pressed() -> void:
	var eligible := is_eligible(donor["sex"], results)
	if not eligible:
		var reasons = compute_ineligibility_reasons(donor["sex"], results)
		show_feedback("✅ Scelta corretta: rimandato. Motivo: " + ", ".join(reasons))
	else:
		show_feedback("❌ Scelta errata: era idoneo, poteva donare.")

	end_flow()
	
func generate_pressure_base() -> int:
	# ✅ Donatore "forced" -> pressione sempre OK
	if _is_forced_donor():
		return rng.randi_range(118, 136)  # dentro 110–140, sicuro

	# --- tua logica random originale ---
	var roll = randi() % 100
	if roll < 70:
		return randi_range(110, 140)
	elif roll < 90:
		if randi() % 2 == 0:
			return randi_range(100, 109)
		return randi_range(141, 160)
	else:
		if randi() % 2 == 0:
			return randi_range(80, 99)
		return randi_range(161, 190)

func _classify_pressure(sys: int) -> String:
	if sys >= 110 and sys <= 140:
		return "ok"
	if (sys >= 100 and sys <= 109) or (sys >= 141 and sys <= 160):
		return "borderline"
	return "fail"

func _handle_pressure_result() -> void:
	var sys = pressure_last_sys
	var status = _classify_pressure(sys)

	if status == "ok":
		panel_continue(
			"Misurazione pressione",
			"Pressione: %d mmHg  (OK)\nProcedi con il prelievo." % sys,
			func(): start_blood_draw_phase()
		)
		return

	if status == "fail":
		panel_continue(
			"Misurazione pressione",
			"Pressione: %d mmHg  (NON IDONEA)\nDonatore rimandato per sicurezza." % sys,
			func(): end_flow()
		)
		return

	# borderline
	pressure_attempts += 1
	if pressure_attempts == 1:
		panel_continue(
			"Misurazione pressione",
			"Pressione: %d mmHg  (BORDERLINE)\nRiposo + acqua… ripeti tra 10 secondi." % sys,
			func(): _retry_pressure_after_rest()
		)
	else:
		panel_continue(
			"Misurazione pressione",
			"Pressione ancora borderline.\nDonatore rimandato (idoneità temporanea).",
			func(): end_flow()
		)


		
func ui_message(title: String, body: String, on_continue: Callable) -> void:
	next_action = on_continue
	pressure_panel.show_message(title, body)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return

	if player_near_machine and has_blood_sample and not analysis_done:
		if analyzer_machine:
			analyzer_machine.try_interact(player) 
		return

	pass
		
			
func _on_panel_continue() -> void:
	if next_action.is_valid():
		next_action.call()

func _retry_pressure_after_rest() -> void:
	state = FlowState.WAIT_RETRY
	pressure_panel.show_wait("Misurazione pressione", "Riposo in corso...")
	await get_tree().create_timer(10.0).timeout

	pressure_last_sys = clamp(pressure_last_sys + randi_range(-8, 8), 60, 200)

	pressure_panel.show_wait("Misurazione pressione", "Ripetizione misurazione in corso...")
	await get_tree().create_timer(1.5).timeout

	_handle_pressure_result()

func show_decision_buttons() -> void:
	var txt := "Hb: %.1f g/dL\nWBC: %.1f x10^3/µL\nPLT: %d x10^3/µL\n\nScegli cosa fare:" % [
		results["hb"], results["wbc"], results["plt"]
	]
	pressure_panel.show_decision("Risultati emocromo", txt)
	
func _on_decision_accept() -> void:
	var eligible := is_eligible(donor["sex"], results)

	if eligible:
		panel_continue(
			"Esito decisione",
			"✅ Scelta corretta: donatore idoneo.",
			func(): end_flow()
		)
		return

	var reasons := compute_ineligibility_reasons(donor["sex"], results)
	_record_emocromo_error("accept", reasons)

	var msg := "❌ Scelta errata: NON dovevi accettare.\n\nMotivo:\n- " + "\n- ".join(reasons) + "\n\nPremi OK e scegli di nuovo."
	_show_learning_error_and_retry("Errore decisione", msg)

	
func _on_decision_reject() -> void:
	var eligible := is_eligible(donor["sex"], results)

	if not eligible:
		var reasons := compute_ineligibility_reasons(donor["sex"], results)
		panel_continue(
			"Esito decisione",
			"✅ Scelta corretta: rimandato.\nMotivo: " + ", ".join(reasons),
			func(): end_flow()
		)
		return

	var reasons_ok: Array[String] = ["Valori nei range: Hb/WBC/PLT idonei."]
	_record_emocromo_error("reject", reasons_ok)

	var msg := "❌ Scelta errata: NON dovevi rimandare.\n\nMotivo:\n- Donatore idoneo (valori nei range).\n\nPremi OK e scegli di nuovo."
	_show_learning_error_and_retry("Errore decisione", msg)


func panel_continue(title: String, body: String, on_continue: Callable) -> void:
	next_action = on_continue
	pressure_panel.show_continue(title, body)
	
func show_sfigmo() -> void:
	if overlay == null or overlay_img == null:
		return

	overlay.visible = true
	overlay_img.visible = true
	overlay_img.modulate.a = 0.0

	await get_tree().process_frame
	_center_sfigmo_big()

	var tw := create_tween()
	tw.tween_property(overlay_img, "modulate:a", 1.0, 0.12)
	
func hide_sfigmo() -> void:
	if overlay == null or overlay_img == null:
		return

	var tw := create_tween()
	tw.tween_property(overlay_img, "modulate:a", 0.0, 0.10)
	tw.finished.connect(func():
		if is_instance_valid(overlay):
			overlay.visible = false
		if is_instance_valid(overlay_img):
			overlay_img.visible = false
			overlay_img.modulate.a = 1.0
	)
	
func show_pressure_overlay() -> void:
	if overlay == null:
		return

	overlay.visible = true
	overlay.modulate.a = 0.0

	await get_tree().process_frame
	_center_sfigmo_big()

	var tw = create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.12)



func hide_pressure_overlay() -> void:
	if overlay == null:
		return
	var tw = create_tween()
	tw.tween_property(overlay, "modulate:a", 0.0, 0.10)
	tw.finished.connect(func():
		if is_instance_valid(overlay):
			overlay.visible = false
	)

func _on_blood_minigame_done(result: String) -> void:
	if pressure_panel:
		pressure_panel.hide_panel()

	match result:
		"success":
			has_blood_sample = true
			analysis_done = false

			if analyzer_machine:
				analyzer_machine.set_enabled(false)

			player.set_can_move(false)
			state = FlowState.IN_DRAW

			pressure_panel.show_wait(
				"Prelievo campione",
				"Campione raccolto.\nPreparazione provetta in corso..."
			)

			if nurse_anim and nurse_anim.sprite_frames and nurse_anim.sprite_frames.has_animation("use"):
				nurse_anim.play("use")

			var tw := show_edta_tube(1.5)
			if tw:
				await tw.finished
			hide_edta_tube()

			if nurse_anim:
				nurse_anim.play("idle_up")

			if analyzer_machine:
				analyzer_machine.set_enabled(true)

			await get_tree().create_timer(4.0).timeout

			panel_continue(
				"Prelievo campione",
				"✅ Campione pronto.\nVai alla macchina e inserisci la provetta per avviare l’analisi.",
				func():
					state = FlowState.IDLE
					player.set_can_move(true)
			)

		"borderline", "fail":
			# ✅ ORA borderline è trattato come fallimento: deve riprovare
			has_blood_sample = false
			analysis_done = false

			if analyzer_machine:
				analyzer_machine.set_enabled(false)

			if edta_icon:
				edta_icon.visible = false

			panel_continue(
				"Prelievo campione",
				"❌ Prelievo non valido.\nRiprova con più calma.",
				func(): start_blood_draw_phase()
			)

		_:
			# safety: se arriva un valore strano, lo consideriamo fallito
			panel_continue(
				"Prelievo campione",
				"❌ Esito non valido.\nRiprova.",
				func(): start_blood_draw_phase()
			)

			
func show_edta_tube(hold_sec: float = 0.0) -> Tween:
	if edta_icon == null:
		return null

	edta_icon.visible = true
	edta_icon.modulate.a = 0.0

	edta_icon.pivot_offset = edta_icon.size * 0.5
	edta_icon.rotation_degrees = 0.0
	edta_icon.scale = Vector2(0.85, 0.85)

	var tw := create_tween()

	tw.tween_property(edta_icon, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(edta_icon, "scale", Vector2(1.0, 1.0), 0.12)

	tw.tween_property(edta_icon, "rotation_degrees", 360.0, 1.2)

	if hold_sec > 0.0:
		tw.tween_interval(hold_sec)

	return tw


func hide_edta_tube() -> void:
	if edta_icon == null:
		return

	var tw := create_tween()
	tw.tween_property(edta_icon, "modulate:a", 0.0, 0.10)
	tw.finished.connect(func():
		if is_instance_valid(edta_icon):
			edta_icon.visible = false
			edta_icon.modulate.a = 1.0
			edta_icon.scale = Vector2(1.0, 1.0)
	)
	
func _center_pivot(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	
func play_edta_pickup_anim() -> void:
	if edta_icon == null:
		return

	edta_icon.visible = true
	edta_icon.modulate.a = 1.0
	edta_icon.rotation = 0.0
	_center_pivot(edta_icon)

	var base_scale: Vector2 = edta_icon.scale
	edta_icon.scale = base_scale * 0.85

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE)
	tw.set_ease(Tween.EASE_OUT)

	tw.tween_property(edta_icon, "scale", base_scale, 0.12)

	tw.parallel().tween_property(edta_icon, "rotation", TAU, 0.45)

	tw.tween_property(edta_icon, "modulate:a", 0.0, 0.18)
	tw.parallel().tween_property(edta_icon, "scale", base_scale * 0.85, 0.18)

	tw.finished.connect(func():
		if is_instance_valid(edta_icon):
			edta_icon.visible = false
			edta_icon.modulate.a = 1.0
			edta_icon.rotation = 0.0
			edta_icon.scale = base_scale
	)


func _on_machine_body_entered(body: Node2D) -> void:
	if body == player:
		player_near_machine = true
		if has_blood_sample and not analysis_done:
			show_feedback("Premi E per inserire la provetta nella macchina.")


func _on_machine_body_exited(body: Node2D) -> void:
	if body == player:
		player_near_machine = false
		
func _on_machine_interacted(p: Node) -> void:
	if machine_busy:
		return
	if not has_blood_sample or analysis_done:
		return

	machine_busy = true
	await start_machine_insertion(p)
	machine_busy = false
	
func start_machine_insertion(p: Node) -> void:
	analysis_done = true
	has_blood_sample = false

	if analyzer_machine:
		analyzer_machine.set_enabled(false)

	if p and p.has_method("set_can_move"):
		p.set_can_move(false)

	state = FlowState.IN_ANALYSIS
	pressure_panel.show_wait("Laboratorio analisi", "Inserimento provetta...\nAnalisi in corso...")

	if nurse_anim and nurse_anim.sprite_frames and nurse_anim.sprite_frames.has_animation("use"):
		nurse_anim.play("use")

	var tw := show_edta_tube(0.6)
	if tw:
		await tw.finished
	hide_edta_tube()

	await get_tree().create_timer(1.0).timeout

	if nurse_anim:
		nurse_anim.play("idle_up")

	await start_analysis_phase()
	
func _record_emocromo_error(action: String, reasons: Array[String]) -> void:
	emocromo_errors.append({
		"donor_id": int(donor.get("id", -1)),
		"donor_name": donor.get("name", "Sconosciuto"),
		"donor_sex": donor.get("sex", "?"),
		"action": action,
		"reasons": reasons.duplicate(),
		"results": results.duplicate(true)
	})

func _show_learning_error_and_retry(title: String, body: String) -> void:
	panel_continue(
		title,
		body,
		func():
			open_results_ui()
	)

func spawn_donors_on_seats() -> void:
	spawned_donors.clear()
	var seat_markers := []
	for i in range(1, 6):
		var m := get_node_or_null("SeatMarker%d" % i)
		if m:
			seat_markers.append(m)

	var eligible_ids = RunState.donors_for_donation
	print("SPAWN DONORS, eligible:", eligible_ids)

	for i in range(min(eligible_ids.size(), seat_markers.size())):
		var donor_index: int = int(eligible_ids[i])

		var donor_data: Dictionary = RunState.donors[donor_index].duplicate(true)
		donor_data["id"] = donor_index

		var d := donor_scene.instantiate()
		add_child(d)
		d.global_position = seat_markers[i].global_position

		d.setup(donor_data)
		spawned_donors.append(d)
		print("SPAWN:", donor_index, donor_data.get("name"), "id_in_data=", donor_data.get("id"))


func _center_sfigmo_big() -> void:
	if overlay == null or overlay_img == null:
		return
	if overlay_img.texture == null:
		return

	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 0
	overlay.offset_top = 0
	overlay.offset_right = 0
	overlay.offset_bottom = 0

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var ts: Vector2 = overlay_img.texture.get_size()

	var s: float = min(vp.x / ts.x, vp.y / ts.y) * 0.92
	var scaled: Vector2 = ts * s

	overlay_img.set_anchors_preset(Control.PRESET_CENTER)
	overlay_img.offset_left   = -scaled.x * 0.5
	overlay_img.offset_top    = -scaled.y * 0.5
	overlay_img.offset_right  =  scaled.x * 0.5
	overlay_img.offset_bottom =  scaled.y * 0.5

	overlay_img.scale = Vector2.ONE
	overlay_img.pivot_offset = Vector2.ZERO

func set_current_donor_node(n: Node) -> void:
	current_donor_node = n

func _lock_other_donors(lock: bool) -> void:
	for d in spawned_donors:
		if not is_instance_valid(d):
			continue
		if d.has_method("set_interaction_enabled"):
			if lock:
				d.set_interaction_enabled(d == current_donor_node)
			else:
				d.set_interaction_enabled(true)
				
func can_start_interaction() -> bool:
	return (state == FlowState.IDLE) and (not donor_busy)

func _pick_forced_eligible_ids() -> void:
	forced_eligible_ids.clear()

	# Id dei donatori che arrivano da Acceptance (quelli che spawni in Emocromo)
	var eligible_ids: Array = RunState.donors_for_donation
	if eligible_ids.is_empty():
		return

	# Limiti reali
	var max_final: int = min(MAX_ELIGIBLE_TO_FINAL, eligible_ids.size())
	var min_final: int = min(MIN_ELIGIBLE_TO_FINAL, max_final)

	# target random tra 3 e 5 (o meno se non ci arrivi)
	var target: int = rng.randi_range(min_final, max_final)

	# Shuffle per non prendere sempre i primi (pull up la random vera)
	var pool: Array = eligible_ids.duplicate()
	pool.shuffle()

	for i in range(target):
		forced_eligible_ids.append(int(pool[i]))

func _generate_eligible_results_for(sex: String) -> Dictionary:
	var hb_min := 13.5 if sex == "M" else 12.5

	return {
		"hb": snappedf(randf_range(hb_min + 0.2, hb_min + 2.0), 0.1),
		"wbc": snappedf(randf_range(4.2, 10.8), 0.1),
		"plt": randi_range(160, 380)
	}

func _show_room_summary() -> void:
	if pressure_panel:
		pressure_panel.hide_panel()

	if blood_minigame and blood_minigame.visible:
		blood_minigame.hide()
	if edta_icon:
		edta_icon.visible = false

	# Blocca player
	if player and player.has_method("set_can_move"):
		player.set_can_move(false)

	var total: int = spawned_donors.size()
	var errors_total: int = emocromo_errors.size()
	var correct_first_try: int = total - _count_unique_donors_with_errors()

	var title_label: Label = $SummaryLayer/SummaryPanel/Margin/VBox/Title
	var body_label: Label  = $SummaryLayer/SummaryPanel/Margin/VBox/Body
	var btn: Button        = $SummaryLayer/SummaryPanel/Margin/VBox/ButtonsRow/Continue

	title_label.text = "Stanza completata ✅"
	body_label.text = "Donatori gestiti correttamente\nal primo tentativo: %d / %d\nErrori totali: %d" % [
		correct_first_try, total, errors_total
	]

	btn.text = "Prossima stanza"

	# Mostra layer sopra tutto
	$SummaryLayer.show()
	$SummaryLayer.layer = 50

func _count_unique_donors_with_errors() -> int:
	var seen := {}
	for e in emocromo_errors:
		var id := int(e.get("donor_id", -1))
		if id != -1:
			seen[id] = true
		else:
			# fallback se non hai donor_id negli errori
			seen[str(e.get("donor_name", ""))] = true
	return seen.size()

func _is_forced_donor() -> bool:
	var id := int(donor.get("id", -1))
	return id != -1 and forced_eligible_ids.has(id)
