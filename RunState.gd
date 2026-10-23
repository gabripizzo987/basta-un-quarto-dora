extends Node

var donors: Array = []
var donors_for_donation: Array = []
var tutorial_drag_seen: bool = false
var tutorial_manual_seen: bool = false

var badge_precisione_ago: bool = false
var donors_needle_missed_first_try: Array[int] = []

var donation_tutorial_seen: bool = false

var tutorial_final_seen: bool = false
var mistakes_final: int = 0

var mistakes_acceptance: int = 0
var mistakes_emocromo: int = 0
var mistakes_total: int = 0

var donors_missed_first_try: Array[int] = []
var donors_for_final: Array[int] = []
var donation_completed_ids: Array[int] = []
var donation_failed_ids: Array[int] = []
var donors_needle_first_try_ok: Array[int] = []

# ── PUNTEGGIO ────────────────────────────────────────────────────────────────
# Valori dei punti: cambiali qui per ribilanciare il gioco.
const PTS_ACC_CORRECT := 100      # accettazione: donatore valutato giusto al primo tentativo
const PTS_ACC_MISTAKE := 25       # accettazione: penalita' per ogni errore
const PTS_EMO_CORRECT := 100      # emocromo: donatore gestito senza errori
const PTS_EMO_MISTAKE := 25       # emocromo: penalita' per ogni errore
const PTS_EMO_NEEDLE_FIRST := 50  # emocromo: prelievo riuscito al primo colpo
const PTS_EMO_NEEDLE_BADGE := 100 # emocromo: badge Precisione Ago
const PTS_FINAL_DONATION := 150   # sala finale: donazione completata
const PTS_MEDAL_GOLD := 300       # bonus medaglia oro (0 errori totali)
const PTS_MEDAL_SILVER := 100     # bonus medaglia argento (1-3 errori)

var score_acceptance: int = 0
var score_emocromo: int = 0
var score_final: int = 0
var score_medal_bonus: int = 0
var score_breakfast: int = 0

# Punteggio senza la sala colazione (che e' facoltativa)
func score_main() -> int:
	return score_acceptance + score_emocromo + score_final + score_medal_bonus

func score_total() -> int:
	return score_main() + score_breakfast

func compute_acceptance_score(correct_first_try: int, mistakes: int) -> int:
	score_acceptance = maxi(0, correct_first_try * PTS_ACC_CORRECT - mistakes * PTS_ACC_MISTAKE)
	return score_acceptance

func compute_emocromo_score(correct_first_try: int, mistakes: int) -> int:
	var pts := correct_first_try * PTS_EMO_CORRECT - mistakes * PTS_EMO_MISTAKE
	pts += donors_needle_first_try_ok.size() * PTS_EMO_NEEDLE_FIRST
	if badge_precisione_ago:
		pts += PTS_EMO_NEEDLE_BADGE
	score_emocromo = maxi(0, pts)
	return score_emocromo

func compute_final_score() -> int:
	score_final = donation_completed_ids.size() * PTS_FINAL_DONATION
	if mistakes_total == 0:
		score_medal_bonus = PTS_MEDAL_GOLD
	elif mistakes_total <= 3:
		score_medal_bonus = PTS_MEDAL_SILVER
	else:
		score_medal_bonus = 0
	return score_final + score_medal_bonus

# ✅ NUOVO: reset “di run” (da chiamare all’inizio partita)
func reset_run_state() -> void:
	# tutorial / flags
	tutorial_drag_seen = false
	tutorial_manual_seen = false
	donation_tutorial_seen = false
	tutorial_final_seen = false

	# badge ago
	badge_precisione_ago = false
	donors_needle_missed_first_try.clear()
	donors_needle_first_try_ok.clear()

	# punteggio
	score_acceptance = 0
	score_emocromo = 0
	score_final = 0
	score_medal_bonus = 0
	score_breakfast = 0

	# errori
	mistakes_acceptance = 0
	mistakes_emocromo = 0
	mistakes_final = 0
	recompute_mistakes_total()

	# liste run
	donors_for_final.clear()
	donation_completed_ids.clear()
	donation_failed_ids.clear()
	donors_missed_first_try.clear()

func reset_final_room_state() -> void:
	donation_completed_ids.clear()
	donation_failed_ids.clear()
	mistakes_final = 0
	score_final = 0
	score_medal_bonus = 0
	score_breakfast = 0

func recompute_mistakes_total() -> void:
	mistakes_total = mistakes_acceptance + mistakes_emocromo + mistakes_final
