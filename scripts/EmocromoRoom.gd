extends Node2D

@onready var dim: ColorRect = $IntroLayer/Dim
@onready var intro_panel: Control = $IntroLayer/IntroPanel
@onready var player: Node = $Nurse
@onready var pressure_panel: Panel = $UI/PressurePanel
@onready var sfigmo: Sprite2D = $Daniele/Props/Sfigmo
@onready var nurse_anim: AnimatedSprite2D = $Nurse/AnimatedSprite2D
@onready var overlay: Control = $UI/PressureOverlay
@onready var overlay_img: TextureRect = $UI/PressureOverlay/SfigmoBig
@onready var blood_minigame: Control = $UI/BloodDrawMiniGame

var donor := {"name": "Donatore Test", "sex": "M"}
var pressure_ok := true
var results := {}

enum FlowState { IDLE, IN_PRESSURE, WAIT_RETRY, IN_DRAW, IN_ANALYSIS, IN_RESULTS }
var state: FlowState = FlowState.IDLE
var pressure_attempts := 0
var pressure_last_sys := 0
var next_action: Callable = Callable()


func _ready() -> void:
	$UI.hide()
	player.set_can_move(false)
	pressure_panel.continued.connect(_on_panel_continue)
	pressure_panel.accepted.connect(_on_decision_accept)
	pressure_panel.rejected.connect(_on_decision_reject)
	blood_minigame.done.connect(_on_blood_minigame_done)
	

func _on_intro_pressed() -> void:
	dim.hide()
	intro_panel.hide()
	$UI.show()
	player.set_can_move(true)
	state = FlowState.IDLE
	show_feedback("Avvicinati al donatore e premi E per iniziare.")

func start_emocromo_for(d: Dictionary) -> void:
	if state != FlowState.IDLE:
		show_feedback("Procedura già in corso...")
		return

	donor = d.duplicate(true)
	show_feedback("Donatore: %s (%s)" % [donor["name"], donor["sex"]])
	player.set_can_move(false)
	start_pressure_phase()


func start_pressure_phase() -> void:
	state = FlowState.IN_PRESSURE
	pressure_attempts = 0
	pressure_last_sys = generate_pressure_base()
	player.set_can_move(false)

	pressure_panel.show_wait("Misurazione pressione", "Misurazione in corso...")

	# --- anim infermiere + prop sfigmo + overlay grande ---
	if nurse_anim and nurse_anim.sprite_frames and nurse_anim.sprite_frames.has_animation("use"):
		nurse_anim.play("use")
	elif nurse_anim:
		nurse_anim.play("idle_up")

	show_sfigmo()
	show_pressure_overlay()
	# -----------------------------------------------------

	await get_tree().create_timer(1.5).timeout

	# nascondi prop + overlay e torna idle
	hide_sfigmo()
	hide_pressure_overlay()
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
	await get_tree().create_timer(10.0).timeout

	generate_results()
	open_results_ui()

func generate_results() -> void:
	results = {
		"hb": snappedf(randf_range(11.0, 16.0), 0.1),
		"wbc": snappedf(randf_range(3.0, 13.0), 0.1),
		"plt": randi_range(120, 450)
	}
	print("RISULTATI:", results)

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
	# genera UNA sola sistolica per il donatore
	# distribuzione semplice: spesso normale, a volte borderline, raramente fail
	var roll = randi() % 100
	if roll < 70:
		return randi_range(110, 140)      # ok
	elif roll < 90:
		# borderline
		if randi() % 2 == 0:
			return randi_range(100, 109)
		return randi_range(141, 160)
	else:
		# fail
		if randi() % 2 == 0:
			return randi_range(80, 99)
		return randi_range(161, 190)

func _classify_pressure(sys: int) -> String:
	# ok: 110–140
	if sys >= 110 and sys <= 140:
		return "ok"
	# borderline: 100–109 o 141–160
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
	if event.is_action_pressed("interact"):
		# qui resta la tua interazione col donatore (se serve)
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
		show_feedback("✅ Scelta corretta: donatore idoneo.")
	else:
		show_feedback("❌ Scelta errata: dovevi rimandare.")
	end_flow()
	
func _on_decision_reject() -> void:
	var eligible := is_eligible(donor["sex"], results)
	if not eligible:
		show_feedback("✅ Scelta corretta: donatore rimandato.")
	else:
		show_feedback("❌ Scelta errata: il donatore era idoneo.")
	end_flow()

func panel_continue(title: String, body: String, on_continue: Callable) -> void:
	next_action = on_continue
	pressure_panel.show_continue(title, body)
	
func show_sfigmo() -> void:
	if sfigmo == null:
		return

	var base := Vector2(0.28, 0.28) 
	sfigmo.visible = true
	sfigmo.modulate.a = 0.0
	sfigmo.scale = base * 0.85

	var tw = create_tween()
	tw.tween_property(sfigmo, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(sfigmo, "scale", base, 0.12)

func hide_sfigmo() -> void:
	var tw = create_tween()
	tw.tween_property(sfigmo, "modulate:a", 0.0, 0.10)
	tw.finished.connect(func():
		sfigmo.visible = false
		sfigmo.modulate.a = 1.0
	)
	
func show_pressure_overlay() -> void:
	if overlay == null:
		return
	overlay.visible = true
	overlay.modulate.a = 0.0
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
	match result:
		"success":
			panel_continue(
				"Prelievo campione",
				"Campione prelevato correttamente.\nProcedi con l’analisi.",
				func(): start_analysis_phase()
			)
		"borderline":
			panel_continue(
				"Prelievo campione",
				"Prelievo riuscito, ma con difficoltà.\nProcedi con l’analisi.",
				func(): start_analysis_phase()
			)
		"fail":
			panel_continue(
				"Prelievo campione",
				"Prelievo non valido.\nRiprova con più calma.",
				func(): start_blood_draw_phase()
			)
