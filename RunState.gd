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

func recompute_mistakes_total() -> void:
	mistakes_total = mistakes_acceptance + mistakes_emocromo + mistakes_final
