extends Node2D

@onready var intro_layer = $IntroLayer               # CanvasLayer
@onready var dim = $IntroLayer/Dim                   # ColorRect (Control)
@onready var intro_panel = $IntroLayer/IntroPanel    # Panel (Control)
@onready var intro_button = $IntroLayer/IntroPanel/Margin/VBox/ButtonsRow/Intro

@onready var player = $Player
@onready var game_ui = $UI/TriageUI


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

	# Dim summary full-rect
	summary_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	summary_dim.offset_left = 0
	summary_dim.offset_top = 0
	summary_dim.offset_right = 0
	summary_dim.offset_bottom = 0

	# ---- BLOCCA IL GIOCO ALL’AVVIO ----
	player.set_physics_process(false)
	player.set_process_input(false)

	# ---- INTRO ----
	intro_layer.visible = true
	intro_button.disabled = false
	intro_button.pressed.connect(Callable(self, "_on_intro_finished"))

	# Dim intro full-rect
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.offset_left = 0
	dim.offset_top = 0
	dim.offset_right = 0
	dim.offset_bottom = 0

	# fade-in su Dim e Panel
	dim.modulate.a = 0.0
	intro_panel.modulate.a = 0.0

	var tw_in = create_tween()
	tw_in.tween_property(dim, "modulate:a", 1.0, 0.25)
	tw_in.parallel().tween_property(intro_panel, "modulate:a", 1.0, 0.25)


func _on_all_donors_completed() -> void:
	var total: int = game_ui.donors.size()
	var correct_first_try: int = total - game_ui.donors_missed_first_try.size()
	var mistakes: int = game_ui.mistakes_total

	# blocca player mentre mostri il riepilogo
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

	# sblocca il gioco
	player.set_physics_process(true)
	player.set_process_input(true)


func _on_continue_pressed() -> void:
	summary_layer.visible = false

	# sblocca player (oppure qui cambi scena)
	if player.has_method("set_can_move"):
		player.set_can_move(true)
	else:
		player.set_physics_process(true)
		player.set_process_input(true)

	# TODO più avanti:
	# get_tree().change_scene_to_file("res://scenes/EmocromoRoom.tscn").
