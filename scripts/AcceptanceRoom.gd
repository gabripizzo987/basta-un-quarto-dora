extends Node2D

@onready var intro_layer = $IntroLayer
@onready var dim = $IntroLayer/Dim
@onready var intro_panel = $IntroLayer/IntroPanel
@onready var intro_button = $IntroLayer/IntroPanel/Margin/VBox/ButtonsRow/Intro

@onready var player = $Player
@onready var game_ui = $UI/TriageUI

# ---- DRAG UI (SCENA FIGLIA) ----
@onready var triage_drag_ui: Control = $UI/TriageDragUI

# ---- SUMMARY ----
@onready var summary_layer: CanvasLayer = $SummaryLayer
@onready var summary_dim: Control = $SummaryLayer/Dim
@onready var summary_panel: Control = $SummaryLayer/SummaryPanel
@onready var summary_title: Label = $SummaryLayer/SummaryPanel/Margin/VBox/Title
@onready var summary_body: Label = $SummaryLayer/SummaryPanel/Margin/VBox/Body
@onready var summary_button: Button = $SummaryLayer/SummaryPanel/Margin/VBox/ButtonsRow/Continue


func _ready() -> void:
	game_ui.connect("all_donors_completed", Callable(self, "_on_all_donors_completed"))

	# ---- SUMMARY ----
	summary_layer.visible = false
	summary_button.pressed.connect(Callable(self, "_on_summary_continue_pressed"))

	summary_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	summary_dim.offset_left = 0
	summary_dim.offset_top = 0
	summary_dim.offset_right = 0
	summary_dim.offset_bottom = 0

	# ---- BLOCCA IL GIOCO ALL’AVVIO ----
	player.set_physics_process(false)
	player.set_process_input(false)

	if player.has_method("face_up_idle"):
		player.face_up_idle()

	# ---- INTRO ----
	intro_layer.visible = true
	intro_button.disabled = false
	intro_button.pressed.connect(Callable(self, "_on_intro_finished"))

	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.offset_left = 0
	dim.offset_top = 0
	dim.offset_right = 0
	dim.offset_bottom = 0

	dim.modulate.a = 0.0
	intro_panel.modulate.a = 0.0

	var tw_in = create_tween()
	tw_in.tween_property(dim, "modulate:a", 1.0, 0.25)
	tw_in.parallel().tween_property(intro_panel, "modulate:a", 1.0, 0.25)

	_setup_triage_drag_ui()

func _setup_triage_drag_ui() -> void:
	if triage_drag_ui == null:
		return

	triage_drag_ui.visible = false

	var drop_id := triage_drag_ui.get_node_or_null("Root/DropRow/DropIdoneo") as Control
	var drop_non := triage_drag_ui.get_node_or_null("Root/DropRow/DropNonIdoneo") as Control
	var drag_root := $UI/DragLayer/DragRoot as Node2D

	print("drop_id=", drop_id, " drop_non=", drop_non, " drag_root=", drag_root)

	if drop_id == null or drop_non == null or drag_root == null:
		push_error("Setup Drag UI: nodi mancanti (controlla Root/DropRow/...)")
		return

	triage_drag_ui.setup(game_ui, drop_id, drop_non, drag_root)

# --------------------------------------------------
# SUMMARY
# --------------------------------------------------
func _on_all_donors_completed() -> void:
	var total: int = game_ui.donors.size()
	var correct_first_try: int = total - game_ui.donors_missed_first_try.size()
	var mistakes: int = game_ui.mistakes_total

	player.set_physics_process(false)
	player.set_process_input(false)

	summary_title.text = "Stanza completata ✅"
	summary_body.text = """
Donatori gestiti correttamente al primo tentativo: %d / %d
Errori totali: %d
""" % [correct_first_try, total, mistakes]

	summary_layer.visible = true
	summary_panel.visible = true


func _on_intro_finished() -> void:
	intro_button.disabled = true

	var tw_out = create_tween()
	tw_out.tween_property(dim, "modulate:a", 0.0, 0.25)
	tw_out.parallel().tween_property(intro_panel, "modulate:a", 0.0, 0.25)
	tw_out.finished.connect(Callable(self, "_hide_intro_and_start"))


func _hide_intro_and_start() -> void:
	intro_layer.visible = false
	player.set_physics_process(true)
	player.set_process_input(true)


func _on_summary_continue_pressed() -> void:
	summary_layer.visible = false

	if player.has_method("set_can_move"):
		player.set_can_move(true)
	else:
		player.set_physics_process(true)
		player.set_process_input(true)

	get_tree().change_scene_to_file("res://scenes/EmocromoRoom.tscn")

func show_drag_ui_for_donor(donor_node: Node2D) -> void:
	triage_drag_ui.visible = true
	print("[AcceptanceRoom] show_drag_ui_for_donor donor=", donor_node)

	# importantissimo: passa il donor al TriageDragUI
	if triage_drag_ui.has_method("start_for_donor"):
		triage_drag_ui.start_for_donor(donor_node)

func hide_drag_ui() -> void:
	if triage_drag_ui != null:
		triage_drag_ui.force_close_and_restore()
