extends Control

signal all_donors_completed

var triage_active := false
var mistakes_total: int = 0
var donors_missed_first_try: Array[int] = []  # slot_index dei donatori sbagliati almeno una volta

var rng = RandomNumberGenerator.new()

var current_player: Node = null
# Donatori della partita (dati generati)
var donors = []
var current_donor_index = -1
var decision_locked: bool = false
var current_donor_node: Node2D = null
signal error_popup_opened
signal error_popup_closed

@onready var button_accept: Button = $PanelAccept/ContentVBox/ButtonsHBox/ButtonAccept
@onready var button_reject: Button = $PanelAccept/ContentVBox/ButtonsHBox/ButtonReject

@onready var panel_accept = $PanelAccept
@onready var label_name = $PanelAccept/ContentVBox/LabelName
@onready var label_info = $PanelAccept/ContentVBox/LabelInfo
@onready var label_feedback = $PanelAccept/ContentVBox/LabelFeedback

@onready var error_popup = $ErrorPopup
@onready var error_text = $ErrorPopup/Margin/VBox/ErrorText
@onready var error_ok = $ErrorPopup/Margin/VBox/ButtonsRow/ButtonOk

@onready var panel_manual = $PanelManual
@onready var button_manual = $ButtonManual
@onready var button_close_manual = $PanelManual/ButtonCloseManual

@onready var panel_emocromo = $PanelEmocromo
@onready var label_bp = $PanelEmocromo/LabelBP
@onready var label_bp_info = $PanelEmocromo/LabelBPInfo
@onready var label_feedback_emo = $PanelEmocromo/LabelFeedbackEmo
@onready var button_coffee = $PanelEmocromo/ButtonCoffee
@onready var button_wait = $PanelEmocromo/ButtonWait
@onready var button_proceed = $PanelEmocromo/ButtonProceedDonation

var SLOT_CONFIG = [
	{"name": "Gabriele", "sex": "M"},   # Donor1
	{"name": "Claudio",     "sex": "M"},   # Donor2
	{"name": "Daniele",     "sex": "M"},   # Donor3
	{"name": "Anna",   "sex": "F"},   # Donor4
	{"name": "Elisa",   "sex": "F"}    # Donor5
]

# quali donatori sono già stati gestiti (accettati+emocromo o rifiutati)
var donors_done = []

var phase = "accept"  

var current_bp_sys = 0
var current_bp_dia = 0

# indici dei donatori che arrivano effettivamente alla donazione
var donors_for_donation = []

var DISEASES = [
	{"id": "none",          "label": "Nessuna patologia rilevante",                          "deferral": "none"},
	{"id": "flu_recent",    "label": "Influenza con febbre 3 giorni fa",                     "deferral": "temp"},
	{"id": "flu_old",       "label": "Influenza 1 mese fa, ora guarito",                     "deferral": "none"},
	{"id": "covid_recent",  "label": "COVID-19 2 settimane fa, ancora astenia",              "deferral": "temp"},
	{"id": "covid_old",     "label": "COVID-19 3 mesi fa, completamente guarito",            "deferral": "none"},
	{"id": "hiv",           "label": "Infezione da HIV nota",                                "deferral": "perm"},
	{"id": "hepatitis_b",   "label": "Epatite B cronica",                                    "deferral": "perm"},
	{"id": "hepatitis_c",   "label": "Epatite C cronica",                                    "deferral": "perm"},
	{"id": "cardiac_disease","label": "Cardiopatia con limitazione allo sforzo",            "deferral": "perm"},
	{"id": "pregnancy",     "label": "Gravidanza in corso",                                  "deferral": "temp"}
]

var DRUGS = [
	{"id": "none",              "label": "Nessun farmaco recente",                           "deferral": "none"},
	{"id": "paracetamol_recent","label": "Paracetamolo per febbre negli ultimi 2 giorni",    "deferral": "temp"},
	{"id": "ibuprofen_recent",  "label": "Ibuprofene negli ultimi 2 giorni",                 "deferral": "temp"},
	{"id": "antibiotic_recent", "label": "Antibiotico per infezione negli ultimi 5 giorni",  "deferral": "temp"},
	{"id": "anticoagulant",     "label": "Terapia cronica con anticoagulanti orali",         "deferral": "perm"}
]


func _ready() -> void:
	rng.randomize()
	generate_donors(5, 3) # 5 donatori, almeno 3 idonei

	# inizializza array dei donatori gestiti
	donors_done.clear()
	for i in range(donors.size()):
		donors_done.append(false)

	# all'inizio nessun pannello visibile
	panel_manual.visible = false
	panel_emocromo.visible = false
	panel_accept.visible = false

	error_popup.visible = false
	error_ok.pressed.connect(Callable(self, "_on_error_ok_pressed"))

# chiamata dall'esterno quando parli col donatore i
func start_triage_for_slot(slot_index: int) -> void:
	get_parent().get_node("TriageDragUI").visible = true
	if slot_index < 0 or slot_index >= donors.size():
		return

	# se è già stato valutato, non riapri il triage
	if donors_done[slot_index]:
		return

	current_donor_index = slot_index
	phase = "accept"

	panel_emocromo.visible = false
	panel_manual.visible = false
	panel_accept.visible = true
	triage_active = true
	_set_triage_active(true)
	show_current_donor()

func start_triage_for_slot_from_player(slot_index: int, player: Node, donor_node: Node2D = null) -> void:
	current_player = player
	current_donor_node = donor_node
	triage_active = true

	var scene := get_tree().current_scene
	if donor_node != null and scene != null and scene.has_method("show_drag_ui_for_donor"):
		scene.show_drag_ui_for_donor(donor_node)

	start_triage_for_slot(slot_index)

	
func _unlock_player() -> void:
	if current_player == null:
		return

	# evita riapertura immediata con E
	current_player.interact_target = null

	if current_player.has_method("set_can_move"):
		current_player.set_can_move(true)

	current_player = null
	

func is_panel_open() -> bool:
	return panel_accept.visible or panel_emocromo.visible or panel_manual.visible


func close_panel_without_finishing() -> void:
	# Chiude solo graficamente, non segna il donatore come fatto
	panel_accept.visible = false
	triage_active = false
	panel_emocromo.visible = false
	panel_manual.visible = false
	_unlock_player()
	_set_triage_active(false)


# EMOCROMO (inutilizzato)

func start_emocromo_for_current_donor() -> void:
	phase = "emocromo"
	panel_accept.visible = false
	panel_manual.visible = false
	panel_emocromo.visible = true

	# Stato iniziale della pressione: 0 = bassa, 1 = normale, 2 = alta
	var state = rng.randi_range(0, 2)
	if state == 0:
		current_bp_sys = rng.randi_range(90, 100)
		current_bp_dia = rng.randi_range(55, 65)
	elif state == 1:
		current_bp_sys = rng.randi_range(110, 125)
		current_bp_dia = rng.randi_range(70, 80)
	else:
		current_bp_sys = rng.randi_range(140, 160)
		current_bp_dia = rng.randi_range(90, 100)

	label_feedback_emo.text = ""
	update_emocromo_ui()


func is_bp_ok() -> bool:
	# Range semplificato accettabile
	return current_bp_sys >= 110 and current_bp_sys <= 140 \
		and current_bp_dia >= 70 and current_bp_dia <= 90


func update_emocromo_ui() -> void:
	label_bp.text = "Pressione: %d / %d mmHg" % [current_bp_sys, current_bp_dia]

	if is_bp_ok():
		label_bp_info.text = "Valori nella norma: puoi procedere alla donazione."
		button_proceed.disabled = false
	else:
		button_proceed.disabled = true
		if current_bp_sys < 110 or current_bp_dia < 70:
			label_bp_info.text = "Pressione bassa: somministra caffè zuccherato o attendi e rivaluta."
		else:
			label_bp_info.text = "Pressione alta: meglio attendere e rivalutare prima di donare."

# GENERAZIONE DONATORI
func generate_donors(count: int, min_eligible: int) -> void:
	donors.clear()

	var real_count = count
	if real_count > SLOT_CONFIG.size():
		real_count = SLOT_CONFIG.size()

	# scegli quanti saranno idonei (tra min_eligible e real_count)
	var target_eligible = rng.randi_range(min_eligible, real_count)

	var flags = []
	for i in range(real_count):
		flags.append(i < target_eligible)
	flags.shuffle()

	for i in range(real_count):
		var must_be_eligible = flags[i]
		var slot_cfg = SLOT_CONFIG[i]   # nome/sesso fissi per quello slot

		var donor = generate_random_donor(must_be_eligible, slot_cfg)

		if must_be_eligible:
			while not is_donor_eligible(donor):
				donor = generate_random_donor(true, slot_cfg)

		donors.append(donor)


func generate_random_donor(must_be_eligible: bool, slot_cfg: Dictionary) -> Dictionary:
	var name = slot_cfg["name"]
	var sex = slot_cfg["sex"]

	var age
	if must_be_eligible:
		age = rng.randi_range(18, 60) # età donabile
	else:
		age = rng.randi_range(17, 70)

	var weight
	if must_be_eligible:
		weight = rng.randi_range(55, 100) # sopra soglia
	else:
		weight = rng.randi_range(45, 100)

	# tatuaggi
	var has_tattoo = rng.randi_range(0, 1) == 1
	var tattoo_months_ago = -1
	if has_tattoo:
		if must_be_eligible:
			tattoo_months_ago = rng.randi_range(6, 24) # oltre 6 mesi
		else:
			tattoo_months_ago = rng.randi_range(0, 24)

	# malattie
	var disease
	var filtered_diseases = []
	for d in DISEASES:
		if sex == "M" and d["id"] == "pregnancy":
			continue
		filtered_diseases.append(d)

	if must_be_eligible:
		var allowed_diseases = []
		for d in filtered_diseases:
			if d["deferral"] == "none":
				allowed_diseases.append(d)
		disease = allowed_diseases[rng.randi() % allowed_diseases.size()]
	else:
		disease = filtered_diseases[rng.randi() % filtered_diseases.size()]

	# farmaci
	var drug
	if must_be_eligible:
		var allowed_drugs = []
		for d2 in DRUGS:
			if d2["deferral"] == "none":
				allowed_drugs.append(d2)
		drug = allowed_drugs[rng.randi() % allowed_drugs.size()]
	else:
		drug = DRUGS[rng.randi() % DRUGS.size()]

	# viaggi a rischio
	var recent_travel_risk
	var travel_label
	if must_be_eligible:
		recent_travel_risk = false
		travel_label = "Nessun viaggio recente in zone a rischio."
	else:
		recent_travel_risk = rng.randi_range(0, 1) == 1
		if recent_travel_risk:
			travel_label = "Viaggio in zona a rischio malaria/dengue negli ultimi 3 mesi."
		else:
			travel_label = "Nessun viaggio recente in zone a rischio."

	# ultima donazione
	var first_time = false
	var last_donation_months_ago = -1
	if rng.randi_range(0, 1) == 0:
		first_time = true
	else:
		if must_be_eligible:
			last_donation_months_ago = rng.randi_range(3, 24)
		else:
			last_donation_months_ago = rng.randi_range(0, 24)

	return {
		"name": name,
		"sex": sex,
		"age": age,
		"weight": weight,
		"has_tattoo": has_tattoo,
		"tattoo_months_ago": tattoo_months_ago,
		"disease": disease,
		"drug": drug,
		"recent_travel_risk": recent_travel_risk,
		"travel_label": travel_label,
		"first_time": first_time,
		"last_donation_months_ago": last_donation_months_ago
	}

# MOSTRARE I DATI A SCHERMO
func show_current_donor() -> void:
	if current_donor_index < 0 or current_donor_index >= donors.size():
		return

	var donor = donors[current_donor_index]
	label_name.text = "Donatore: %s" % donor["name"]

	var sex_txt = "Maschio"
	if donor["sex"] != "M":
		sex_txt = "Femmina"

	var tattoo_txt = "Nessun tatuaggio"
	if donor["has_tattoo"]:
		tattoo_txt = "%d mesi fa" % donor["tattoo_months_ago"]

	var disease_label = donor["disease"]["label"]
	var drug_label = donor["drug"]["label"]

	var donation_txt
	if donor["first_time"]:
		donation_txt = "Prima donazione"
	else:
		donation_txt = "Ultima donazione: %d mesi fa" % donor["last_donation_months_ago"]

	label_info.text = "Sesso: %s\nEtà: %d anni\nPeso: %d kg\nTatuaggio: %s\nMalattie: %s\nFarmaci: %s\nViaggi: %s\n%s" % [
		sex_txt,
		donor["age"],
		donor["weight"],
		tattoo_txt,
		disease_label,
		drug_label,
		donor["travel_label"],
		donation_txt
	]

	label_feedback.text = ""
	
# LOGICA DI IDONEITÀ
func is_donor_eligible(donor: Dictionary) -> bool:
	if donor["age"] < 18:
		return false

	if donor["weight"] < 50:
		return false

	if donor["has_tattoo"] and donor["tattoo_months_ago"] < 6:
		return false

	var disease_deferral = donor["disease"]["deferral"]
	if disease_deferral == "perm" or disease_deferral == "temp":
		return false

	var drug_deferral = donor["drug"]["deferral"]
	if drug_deferral == "perm" or drug_deferral == "temp":
		return false

	if donor["recent_travel_risk"]:
		return false

	if not donor["first_time"] and donor["last_donation_months_ago"] < 3:
		return false

	return true


func get_ineligibility_reason(donor: Dictionary) -> String:
	if donor["age"] < 18:
		return "Età inferiore a 18 anni."

	if donor["weight"] < 50:
		return "Peso inferiore a 50 kg."

	if donor["has_tattoo"] and donor["tattoo_months_ago"] < 6:
		return "Tatuaggio eseguito da meno di 6 mesi."

	var disease_deferral = donor["disease"]["deferral"]
	if disease_deferral == "perm":
		return "Patologia che controindica in modo permanente la donazione (%s)." % donor["disease"]["label"]
	if disease_deferral == "temp":
		return "Condizione temporanea: oggi il donatore va rimandato (%s)." % donor["disease"]["label"]

	var drug_deferral = donor["drug"]["deferral"]
	if drug_deferral == "perm":
		return "Terapia farmacologica che controindica la donazione (%s)." % donor["drug"]["label"]
	if drug_deferral == "temp":
		return "Farmaco assunto di recente: il donatore va rimandato oggi (%s)." % donor["drug"]["label"]

	if donor["recent_travel_risk"]:
		return "Viaggio recente in zona a rischio malaria/dengue: il donatore va temporaneamente sospeso."

	if not donor["first_time"] and donor["last_donation_months_ago"] < 3:
		return "Ultima donazione troppo recente: devono passare almeno 3 mesi."

	return "Non idoneo per motivi clinici (semplificati)."

# FINE TRIAGE DI UN DONATORE
func _finish_current_donor() -> void:
	if current_donor_index < 0 or current_donor_index >= donors_done.size():
		return

	# segna fatto
	donors_done[current_donor_index] = true

	decision_locked = false
	_set_choice_buttons_enabled(true)
	label_feedback.text = ""
	_set_triage_active(false)
	triage_active = false
	current_donor_node = null
	# chiudi pannelli
	panel_accept.visible = false
	panel_emocromo.visible = false
	panel_manual.visible = false

	# sblocca player e "chiudi" interazione corrente
	_unlock_player()
	current_donor_index = -1

	if _all_donors_done():
		RunState.donors = donors.duplicate(true)
		RunState.donors_for_donation = donors_for_donation.duplicate()
		RunState.mistakes_total = mistakes_total
		RunState.donors_missed_first_try = donors_missed_first_try.duplicate()
		
		print("RUNSTATE SAVED:")
		print("donors:", RunState.donors.size())
		print("eligible:", RunState.donors_for_donation)
		emit_signal("all_donors_completed")
	get_parent().get_node("TriageDragUI").visible = false
	
func _all_donors_done() -> bool:
	for done in donors_done:
		if not done:
			return false
	return true


func handle_choice(accepted: bool) -> bool:
	print("CHOICE:", accepted, " donor=", current_donor_index)

	# Se popup errore aperto, ignora input
	if error_popup.visible:
		return false

	if decision_locked:
		return false

	if current_donor_index < 0 or current_donor_index >= donors.size():
		return false

	# BLOCCA subito
	decision_locked = true
	_set_choice_buttons_enabled(false)

	var donor = donors[current_donor_index]
	var eligible = is_donor_eligible(donor)

	if accepted == eligible:
		# CORRETTO
		if eligible:
			label_feedback.text = "Corretto: %s è idoneo alla donazione.\nPasserà alla fase successiva." % donor["name"]

			if not donors_for_donation.has(current_donor_index):
				donors_for_donation.append(current_donor_index)

			await get_tree().create_timer(1.5).timeout
			_finish_current_donor()
			return true
		else:
			label_feedback.text = "Corretto: %s non è idoneo." % donor["name"]

			await get_tree().create_timer(1.5).timeout
			_finish_current_donor()
			return true

	# SBAGLIATO
	mistakes_total += 1

	if not donors_missed_first_try.has(current_donor_index):
		donors_missed_first_try.append(current_donor_index)

	if eligible and not accepted:
		label_feedback.text = "Errore: %s era idoneo." % donor["name"]
		show_error_popup("Il donatore rispettava i criteri minimi di idoneità: dovevi ACCETTARE.")
	elif not eligible and accepted:
		label_feedback.text = "Errore: %s non è idoneo." % donor["name"]
		show_error_popup(get_ineligibility_reason(donor))

	# SBLOCCA: può riprovare
	decision_locked = false
	_set_choice_buttons_enabled(true)
	return false


func _on_ButtonManual_pressed() -> void:
	panel_manual.visible = true


func _on_ButtonCloseManual_pressed() -> void:
	panel_manual.visible = false


func _on_ButtonCoffee_pressed() -> void:
	if phase != "emocromo":
		return

	current_bp_sys += 5
	current_bp_dia += 3
	label_feedback_emo.text = "Hai somministrato caffè zuccherato."
	update_emocromo_ui()


func _on_ButtonWait_pressed() -> void:
	if phase != "emocromo":
		return
	# Attendere tende a riportare verso un range normale
	if current_bp_sys < 110 or current_bp_dia < 70:
		current_bp_sys += 3
		current_bp_dia += 2
	elif current_bp_sys > 140 or current_bp_dia > 90:
		current_bp_sys -= 5
		current_bp_dia -= 3
	else:
		current_bp_sys += rng.randi_range(-2, 2)
		current_bp_dia += rng.randi_range(-2, 2)

	label_feedback_emo.text = "Hai atteso qualche minuto e rivalutato la pressione."
	update_emocromo_ui()


func _on_ButtonProceedDonation_pressed() -> void:
	if phase != "emocromo":
		return

	if not is_bp_ok():
		label_feedback_emo.text = "Non puoi procedere: la pressione non è ancora in range."
		return

	# Arrivato alla donazione in condizioni corrette
	if not donors_for_donation.has(current_donor_index):
		donors_for_donation.append(current_donor_index)

	_finish_current_donor()


func _on_button_accept_pressed() -> void:
	if decision_locked:
		return
	handle_choice(true)


func _on_button_reject_pressed() -> void:
	if decision_locked:
		return
	handle_choice(false)


func _on_button_manual_pressed() -> void:
	panel_manual.visible = true


func _on_button_close_manual_pressed() -> void:
	panel_manual.visible = false


func _on_button_ok_pressed() -> void:
	error_popup.visible = false
	emit_signal("error_popup_closed")

func show_error_popup(reason: String) -> void:
	error_popup.visible = true
	error_text.text = "Motivo:\n%s" % reason

	if error_popup is Control:
		(error_popup as Control).move_to_front()

	emit_signal("error_popup_opened")

	var ok_btn := error_popup.get_node("Margin/VBox/ButtonsRow/ButtonOk") as Button
	if ok_btn:
		ok_btn.disabled = false
		ok_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		ok_btn.focus_mode = Control.FOCUS_ALL
		ok_btn.grab_focus()


func open_for_donor_index(index: int, player: Node) -> void:
	current_player = player
	current_donor_index = index
	panel_accept.visible = true
	show_current_donor()

func close_panel() -> void:
	panel_accept.visible = false
	if current_player != null:
		current_player.set_can_move(true)
		current_player = null

func _set_choice_buttons_enabled(enabled: bool) -> void:
	button_accept.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	button_reject.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	
func is_decision_locked() -> bool:
	return decision_locked
	
func on_drag_drop_choice(accepted: bool) -> void:
	# chiamata da DonorDragCard → TriageDragUI → qui
	handle_choice(accepted)


func is_triage_active() -> bool:
	return triage_active

func _set_triage_active(v: bool) -> void:
	triage_active = v

func get_current_donor_node() -> Node2D:
	return current_donor_node
	
func is_error_popup_open() -> bool:
	return error_popup.visible
