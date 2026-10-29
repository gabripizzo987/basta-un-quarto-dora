extends Control

@export var popup_max_size := Vector2(720, 260)  # adatta a gusto
@export var popup_min_font_size := 10
@export var popup_max_font_size := 18

signal all_donors_completed

var triage_active := false
var mistakes_total: int = 0
var donors_missed_first_try: Array[int] = []  # slot_index dei donatori sbagliati almeno una volta

var _popup_top_layer: CanvasLayer = null
var _popup_original_parent: Node = null
var _popup_original_index: int = -1

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

var _rich_info: RichTextLabel = null

const _C_KEY  := "[color=#9E9EB3]"   # grigio per le etichette (stile UiStyle)
const _C_VAL  := "[color=#FFFFFF]"   # bianco per i valori
const _C_END  := "[/color]"
const _PIXEL_FONT := "res://fonts/PixelOperator8.ttf"

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

	donors_done.clear()
	for i in range(donors.size()):
		donors_done.append(false)

	panel_manual.visible = false
	panel_emocromo.visible = false
	panel_accept.visible = false

	error_popup.visible = false
	error_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	error_text.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if error_ok and not error_ok.pressed.is_connected(Callable(self, "_on_button_ok_pressed")):
		error_ok.pressed.connect(Callable(self, "_on_button_ok_pressed"))

	_style_accept_panel()

func _style_accept_panel() -> void:
	# ── Ridimensiona e sposta il pannello ────────────────────────────────────
	panel_accept.custom_minimum_size = Vector2(500, 0)
	panel_accept.set_offset(SIDE_LEFT,   -500.0)
	panel_accept.set_offset(SIDE_TOP,      38.0)
	panel_accept.set_offset(SIDE_BOTTOM, -180.0)

	# ── Sfondo: stile unico del gioco (UiStyle) ─────────────────────────────
	var sb := preload("res://scripts/UiStyle.gd").panel_box()
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	panel_accept.add_theme_stylebox_override("panel", sb)
	# margini interni: prima il testo toccava il bordo
	var content := panel_accept.get_node_or_null("ContentVBox") as Control
	if content != null:
		content.set_anchors_preset(Control.PRESET_FULL_RECT)
		content.offset_left = 20
		content.offset_right = -20
		content.offset_top = 16
		content.offset_bottom = -16
		content.add_theme_constant_override("separation", 10)

	# ── Pixel font ───────────────────────────────────────────────────────────
	var fnt: Font = null
	if ResourceLoader.exists(_PIXEL_FONT):
		var f := load(_PIXEL_FONT)
		if f is Font:
			fnt = f

	# ── Nome donatore: titolo magenta come gli altri pannelli ───────────────
	if fnt: label_name.add_theme_font_override("font", fnt)
	label_name.add_theme_font_size_override("font_size", 24)
	label_name.add_theme_color_override("font_color", preload("res://scripts/UiStyle.gd").TITLE)

	# ── RichTextLabel per i dati (sostituisce label_info) ────────────────────
	label_info.visible = false
	_rich_info = RichTextLabel.new()
	_rich_info.bbcode_enabled        = true
	_rich_info.fit_content           = true
	_rich_info.scroll_active         = false
	_rich_info.autowrap_mode         = TextServer.AUTOWRAP_WORD_SMART
	_rich_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rich_info.size_flags_vertical   = Control.SIZE_SHRINK_BEGIN
	_rich_info.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	if fnt: _rich_info.add_theme_font_override("normal_font", fnt)
	_rich_info.add_theme_font_size_override("normal_font_size", 18)
	_rich_info.add_theme_constant_override("line_separation", 6)
	label_info.get_parent().add_child(_rich_info)
	label_info.get_parent().move_child(_rich_info, label_info.get_index() + 1)

	# ── Feedback: font pixel ─────────────────────────────────────────────────
	if fnt: label_feedback.add_theme_font_override("font", fnt)
	label_feedback.add_theme_font_size_override("font_size", 17)
	label_feedback.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))


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

	# quante tessere sanitarie "sbagliate" (dipende dalla difficolta')
	var n_doc_issues := 0
	match RunState.difficulty:
		1: n_doc_issues = 1
		2: n_doc_issues = rng.randi_range(1, 2)
	n_doc_issues = mini(n_doc_issues, real_count - min_eligible)

	# scegli quanti saranno idonei (tra min_eligible e real_count)
	var target_eligible = rng.randi_range(min_eligible, real_count - n_doc_issues)

	var flags = []
	for i in range(real_count):
		flags.append(i < target_eligible)
	flags.shuffle()

	# tra i NON idonei, alcuni lo sono solo per la tessera (clinicamente ok)
	var doc_issue_slots: Array = []
	for i in range(real_count):
		if not flags[i] and doc_issue_slots.size() < n_doc_issues:
			doc_issue_slots.append(i)

	var used_surnames: Array = []
	for i in range(real_count):
		var must_be_eligible = flags[i]
		var slot_cfg = SLOT_CONFIG[i]   # nome/sesso fissi per quello slot
		var doc_issue: bool = doc_issue_slots.has(i)

		var donor = generate_random_donor(must_be_eligible or doc_issue, slot_cfg)

		if must_be_eligible or doc_issue:
			while not is_donor_eligible(donor):
				donor = generate_random_donor(true, slot_cfg)

		# cognome + tessera sanitaria che combacia col modulo
		var surname: String = SURNAMES[rng.randi() % SURNAMES.size()]
		while used_surnames.has(surname):
			surname = SURNAMES[rng.randi() % SURNAMES.size()]
		used_surnames.append(surname)
		donor["surname"] = surname
		donor["doc"] = _make_document(donor)
		donor["doc_issue"] = ""
		if doc_issue:
			_apply_doc_issue(donor, RunState.difficulty >= 2)

		donors.append(donor)


# ── TESSERA SANITARIA ────────────────────────────────────────────────────────
# Il modulo e' quello che il donatore compila; la tessera e' il documento.
# Il giocatore controlla che nome, sesso, eta' (dalla data di nascita) e
# scadenza combacino. Se no il donatore va rimandato.

const SURNAMES := ["Rossi", "Russo", "Ferrari", "Esposito", "Bianchi", "Romano",
	"Colombo", "Ricci", "Marino", "Greco", "Bruno", "Gallo", "Conti", "Costa",
	"Giordano", "Mancini", "Rizzo", "Lombardi", "Moretti", "Barbieri"]
const OTHER_NAMES_M := ["Marco", "Luca", "Paolo", "Matteo", "Davide", "Simone"]
const OTHER_NAMES_F := ["Giulia", "Sara", "Chiara", "Francesca", "Laura", "Marta"]
const CF_MONTHS := "ABCDEHLMPRST"


func today_dict() -> Dictionary:
	return Time.get_date_dict_from_system()


func format_date(d: int, m: int, y: int) -> String:
	return "%02d/%02d/%04d" % [d, m, y]


## Documento coerente con il modulo.
func _make_document(donor: Dictionary) -> Dictionary:
	var t := today_dict()
	var bm := rng.randi_range(1, 12)
	var bd := rng.randi_range(1, 28)
	var by: int = int(t.year) - int(donor["age"])
	# compleanno non ancora passato quest'anno -> nato un anno prima
	if bm > int(t.month) or (bm == int(t.month) and bd > int(t.day)):
		by -= 1
	var exp_y: int = int(t.year) + rng.randi_range(1, 5)
	var doc := {
		"surname": String(donor["surname"]).to_upper(),
		"name": String(donor["name"]).to_upper(),
		"sex": donor["sex"],
		"birth_d": bd, "birth_m": bm, "birth_y": by,
		"exp_d": rng.randi_range(1, 28), "exp_m": rng.randi_range(1, 12), "exp_y": exp_y,
	}
	doc["cf"] = _codice_fiscale(doc)
	return doc


## Rende la tessera NON coerente. subtle = Difficile (errori piccoli).
func _apply_doc_issue(donor: Dictionary, subtle: bool) -> void:
	var doc: Dictionary = donor["doc"]
	var t := today_dict()
	var kinds := ["nome", "sesso", "eta", "scaduta"]
	var kind: String = kinds[rng.randi() % kinds.size()]
	match kind:
		"nome":
			if subtle:
				# una lettera diversa nel cognome (es. ROSSI -> ROSI)
				var s: String = doc.surname
				var i := rng.randi_range(1, s.length() - 2)
				doc.surname = s.substr(0, i) + s.substr(i + 1)
			else:
				var pool: Array = OTHER_NAMES_M if donor["sex"] == "M" else OTHER_NAMES_F
				doc.name = String(pool[rng.randi() % pool.size()]).to_upper()
		"sesso":
			doc.sex = "F" if donor["sex"] == "M" else "M"
		"eta":
			# data di nascita che non torna con l'eta' scritta sul modulo
			var shift := (1 if rng.randf() < 0.5 else -1) * (1 if subtle else rng.randi_range(5, 12))
			doc.birth_y = int(doc.birth_y) + shift
		"scaduta":
			if subtle:
				# scaduta da poco (il mese scorso)
				var m := int(t.month) - 1
				var y := int(t.year)
				if m < 1:
					m = 12
					y -= 1
				doc.exp_m = m
				doc.exp_y = y
			else:
				doc.exp_y = int(t.year) - rng.randi_range(1, 3)
	doc["cf"] = _codice_fiscale(doc)
	donor["doc_issue"] = kind


## Codice fiscale semplificato ma verosimile (lettere, anno, mese, giorno).
func _codice_fiscale(doc: Dictionary) -> String:
	var day: int = int(doc.birth_d) + (40 if doc.sex == "F" else 0)
	var letters := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	return _cf_part(doc.surname) + _cf_part(doc.name) \
		+ "%02d" % (int(doc.birth_y) % 100) + CF_MONTHS[int(doc.birth_m) - 1] \
		+ "%02d" % day + "H501" + letters[(int(doc.birth_y) + int(doc.birth_d)) % 26]


## 3 lettere del codice fiscale: prima le consonanti, poi le vocali.
func _cf_part(s: String) -> String:
	var cons := ""
	var vow := ""
	for ch in s:
		if "AEIOU".contains(ch):
			vow += ch
		elif ch >= "A" and ch <= "Z":
			cons += ch
	return (cons + vow + "XXX").substr(0, 3)


func doc_issue_reason(donor: Dictionary) -> String:
	match String(donor.get("doc_issue", "")):
		"nome": return "Tessera sanitaria: il nome non corrisponde al modulo."
		"sesso": return "Tessera sanitaria: il sesso non corrisponde al modulo."
		"eta": return "Tessera sanitaria: la data di nascita non corrisponde all'età dichiarata."
		"scaduta": return "Tessera sanitaria scaduta: serve un documento valido."
	return ""


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
		weight = rng.randi_range(55, 100)
	else:
		weight = rng.randi_range(45, 100)

	# tatuaggi
	var has_tattoo = rng.randi_range(0, 1) == 1
	var tattoo_months_ago = -1
	if has_tattoo:
		if must_be_eligible:
			tattoo_months_ago = rng.randi_range(4, 24) 
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
	label_name.text = "%s %s" % [donor["name"], donor.get("surname", "")]

	var sex_txt  := "Maschio" if donor["sex"] == "M" else "Femmina"
	var tattoo_txt := ("Nessun tatuaggio" if not donor["has_tattoo"]
		else "%d mesi fa" % donor["tattoo_months_ago"])
	var donation_txt := ("Prima donazione" if donor["first_time"]
		else "Ultima donazione: %d mesi fa" % donor["last_donation_months_ago"])

	if _rich_info != null:
		var k := _C_KEY; var v := _C_VAL; var e := _C_END
		_rich_info.text = (
			k + "Sesso: "     + e + v + sex_txt + e + "\n" +
			k + "Età: "       + e + v + "%d anni" % donor["age"] + e + "\n" +
			k + "Peso: "      + e + v + "%d kg" % donor["weight"] + e + "\n" +
			k + "Tatuaggio: " + e + v + tattoo_txt + e + "\n" +
			k + "Malattie: "  + e + v + donor["disease"]["label"] + e + "\n" +
			k + "Farmaci: "   + e + v + donor["drug"]["label"] + e + "\n" +
			k + "Viaggi: "    + e + v + donor["travel_label"] + e + "\n" +
			k + "Donazione: " + e + v + donation_txt + e
		)
	else:
		label_info.text = "%s | %d anni | %d kg\n%s\n%s\n%s\n%s\n%s" % [
			sex_txt, donor["age"], donor["weight"],
			tattoo_txt, donor["disease"]["label"],
			donor["drug"]["label"], donor["travel_label"], donation_txt]

	label_feedback.text = ""
	
# LOGICA DI IDONEITÀ
func is_donor_eligible(donor: Dictionary) -> bool:
	if String(donor.get("doc_issue", "")) != "":
		return false

	if donor["age"] < 18:
		return false

	if donor["weight"] < 50:
		return false

	if donor["has_tattoo"] and donor["tattoo_months_ago"] < 4:
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
	if doc_issue_reason(donor) != "":
		return doc_issue_reason(donor)

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
		RunState.mistakes_acceptance = mistakes_total
		RunState.donors_missed_first_try = donors_missed_first_try.duplicate()
		RunState.recompute_mistakes_total()
		
		print("[ACCEPTANCE SAVE] acc=", RunState.mistakes_acceptance, " total=", RunState.mistakes_total)
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
		AudioManager.play_sfx("correct")
		if eligible:
			label_feedback.text = "✓ Corretto: %s è idoneo.\nPasserà alla fase successiva." % donor["name"]
			label_feedback.add_theme_color_override("font_color", Color(0.35, 0.90, 0.45))

			if not donors_for_donation.has(current_donor_index):
				donors_for_donation.append(current_donor_index)

			await get_tree().create_timer(1.5).timeout
			_finish_current_donor()
			return true
		else:
			label_feedback.text = "✓ Corretto: %s non è idoneo." % donor["name"]
			label_feedback.add_theme_color_override("font_color", Color(0.35, 0.90, 0.45))

			await get_tree().create_timer(1.5).timeout
			_finish_current_donor()
			return true

	# SBAGLIATO
	AudioManager.play_sfx("wrong")
	mistakes_total += 1

	if not donors_missed_first_try.has(current_donor_index):
		donors_missed_first_try.append(current_donor_index)

	if eligible and not accepted:
		label_feedback.text = "✗ Errore: %s era idoneo." % donor["name"]
		label_feedback.add_theme_color_override("font_color", Color(0.95, 0.35, 0.30))
		show_error_popup("Il donatore rispettava i criteri minimi di idoneità: dovevi ACCETTARE.")
	elif not eligible and accepted:
		label_feedback.text = "✗ Errore: %s non è idoneo." % donor["name"]
		label_feedback.add_theme_color_override("font_color", Color(0.95, 0.35, 0.30))
		var reasons := get_ineligibility_reasons(donor)
		show_error_popup_many(reasons)

	# SBLOCCA: può riprovare
	decision_locked = false
	_set_choice_buttons_enabled(true)
	return false


func _on_ButtonManual_pressed() -> void:
	# Passa dai metodi guardati del pannello (blocco player + anti-blocco mash)
	if panel_manual.has_method("open_manual"):
		panel_manual.open_manual()
	else:
		panel_manual.visible = true


func _on_ButtonCloseManual_pressed() -> void:
	if panel_manual.has_method("close_manual"):
		panel_manual.close_manual()
	else:
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
	# Passa dai metodi guardati del pannello (blocco player + anti-blocco mash)
	if panel_manual.has_method("open_manual"):
		panel_manual.open_manual()
	else:
		panel_manual.visible = true


func _on_button_close_manual_pressed() -> void:
	if panel_manual.has_method("close_manual"):
		panel_manual.close_manual()
	else:
		panel_manual.visible = false


func _on_button_ok_pressed() -> void:
	error_popup.visible = false
	_restore_popup_parent()
	emit_signal("error_popup_closed")

func show_error_popup(reason: String) -> void:
	_ensure_popup_on_top() 
	error_popup.visible = true

	# ✅ sempre sopra tutto
	error_popup.z_as_relative = false
	error_popup.z_index = 99999
	error_popup.mouse_filter = Control.MOUSE_FILTER_STOP

	error_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	error_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_text.text = "Motivo:\n%s" % reason
	_fit_error_popup_text_label()

	# ⚠️ importantissimo: se il popup sta su una CanvasLayer più bassa, portalo davanti
	if error_popup is Control:
		(error_popup as Control).move_to_front()

	emit_signal("error_popup_opened")

	# ok sempre cliccabile e focus
	if error_ok:
		error_ok.disabled = false
		error_ok.mouse_filter = Control.MOUSE_FILTER_STOP
		error_ok.focus_mode = Control.FOCUS_ALL
		error_ok.grab_focus()


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
	
func show_error_popup_many(reasons: Array[String]) -> void:
	_ensure_popup_on_top()
	error_popup.visible = true

	# ✅ sempre sopra tutto
	error_popup.z_as_relative = false
	error_popup.z_index = 99999
	error_popup.mouse_filter = Control.MOUSE_FILTER_STOP

	error_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	error_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_text.text = "Motivi:\n• " + "\n• ".join(reasons)
	_fit_error_popup_text_label()

	if error_popup is Control:
		(error_popup as Control).move_to_front()

	emit_signal("error_popup_opened")

	if error_ok:
		error_ok.disabled = false
		error_ok.mouse_filter = Control.MOUSE_FILTER_STOP
		error_ok.focus_mode = Control.FOCUS_ALL
		error_ok.grab_focus()

func get_ineligibility_reasons(donor: Dictionary) -> Array[String]:
	var reasons: Array[String] = []

	var doc_reason := doc_issue_reason(donor)
	if doc_reason != "":
		reasons.append(doc_reason)

	if donor["age"] < 18:
		reasons.append("Età inferiore a 18 anni.")

	if donor["weight"] < 50:
		reasons.append("Peso inferiore a 50 kg.")

	# ✅ tattoo/piercing: 4 mesi
	if donor["has_tattoo"] and donor["tattoo_months_ago"] < 4:
		reasons.append("Tatuaggio/Piercing eseguito da meno di 4 mesi.")

	var disease_deferral = donor["disease"]["deferral"]
	if disease_deferral == "perm":
		reasons.append("Patologia che controindica in modo permanente la donazione (%s)." % donor["disease"]["label"])
	elif disease_deferral == "temp":
		reasons.append("Condizione temporanea: oggi il donatore va rimandato (%s)." % donor["disease"]["label"])

	var drug_deferral = donor["drug"]["deferral"]
	if drug_deferral == "perm":
		reasons.append("Terapia farmacologica che controindica la donazione (%s)." % donor["drug"]["label"])
	elif drug_deferral == "temp":
		reasons.append("Farmaco assunto di recente: il donatore va rimandato oggi (%s)." % donor["drug"]["label"])

	if donor["recent_travel_risk"]:
		reasons.append("Viaggio recente in zona a rischio malaria/dengue: il donatore va temporaneamente sospeso.")

	if not donor["first_time"] and donor["last_donation_months_ago"] < 3:
		reasons.append("Ultima donazione troppo recente: devono passare almeno 3 mesi.")

	# fallback (ma solo se davvero non hai trovato niente)
	if reasons.is_empty():
		reasons.append("Non idoneo per motivi clinici (semplificati).")

	return reasons

func _ensure_popup_on_top() -> void:
	if error_popup == null:
		return

	# crea una volta un CanvasLayer sopra a TUTTO
	if _popup_top_layer == null:
		_popup_top_layer = CanvasLayer.new()
		_popup_top_layer.name = "PopupTopLayer"
		_popup_top_layer.layer = 999  # sopra quasi tutto
		get_tree().current_scene.add_child(_popup_top_layer)

	# se non è già nel top layer, spostalo
	if error_popup.get_parent() != _popup_top_layer:
		_popup_original_parent = error_popup.get_parent()
		_popup_original_index = error_popup.get_index()

		_popup_original_parent.remove_child(error_popup)
		_popup_top_layer.add_child(error_popup)

	# input settings per sicurezza
	error_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	error_text.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _restore_popup_parent() -> void:
	if error_popup == null:
		return
	if _popup_original_parent == null:
		return
	if error_popup.get_parent() == _popup_original_parent:
		return

	error_popup.get_parent().remove_child(error_popup)
	_popup_original_parent.add_child(error_popup)

	# rimetti la posizione nell’albero (così non cambia layout)
	if _popup_original_index >= 0 and _popup_original_index < _popup_original_parent.get_child_count():
		_popup_original_parent.move_child(error_popup, _popup_original_index)

func _fit_error_popup_text_label() -> void:
	if error_popup == null or error_text == null:
		return

	# inchioda dimensione popup
	var c := error_popup as Control
	c.custom_minimum_size = popup_max_size
	c.size = popup_max_size

	error_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# area disponibile per la label (se è in VBox, usa la sua size attuale)
	await get_tree().process_frame

	var font: Font = error_text.get_theme_font("font")
	var box_w = error_text.size.x
	var box_h = error_text.size.y

	# prova a scendere di font finché ci sta
	for fs in range(popup_max_font_size, popup_min_font_size - 1, -1):
		error_text.add_theme_font_size_override("font_size", fs)
		await get_tree().process_frame

		var line_h := font.get_height(fs) + 2
		var max_lines := int(floor(box_h / line_h))

		# stima righe con word-wrap “approx”: conta quante righe servono spezzando per parole
		var needed := _estimate_wrapped_lines(error_text.text, font, fs, box_w)

		if needed <= max_lines:
			return
			
func _estimate_wrapped_lines(txt: String, font: Font, fs: int, max_w: float) -> int:
	var lines := txt.split("\n")
	var total := 0

	for raw in lines:
		var words := raw.split(" ", false)
		if words.is_empty():
			total += 1
			continue

		var cur := ""
		for w in words:
			var test := (cur if cur != "" else "") + ("" if cur == "" else " ") + w
			if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= max_w:
				cur = test
			else:
				total += 1
				cur = w
		total += 1

	return total
