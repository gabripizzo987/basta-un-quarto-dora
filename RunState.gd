extends Node

var donors: Array = []
var donors_for_donation: Array = []
var tutorial_drag_seen: bool = false
var tutorial_manual_seen: bool = false

var tutorial_final_seen: bool = false
var mistakes_final: int = 0

var mistakes_total: int = 0
var donors_missed_first_try: Array[int] = []
var donors_for_final: Array[int] = []
var donation_completed_ids: Array[int] = []
var donation_failed_ids: Array[int] = []

func reset_final_room_state() -> void:
	donation_completed_ids.clear()
	donation_failed_ids.clear()
	
	mistakes_final = 0
	
