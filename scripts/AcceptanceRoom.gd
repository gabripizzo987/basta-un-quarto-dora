extends Node2D

@onready var intro_layer = $IntroLayer
@onready var dim = $IntroLayer/Dim
@onready var intro_panel = $IntroLayer/IntroPanel
@onready var intro_button = $IntroLayer/IntroPanel/Margin/VBox/ButtonsRow/Intro

@onready var player = $Player
@onready var game_ui = $UI/TriageUI

@onready var triage_drag_ui: Control = $UI/TriageDragUI
@onready var drag_layer: CanvasLayer = $UI/DragLayer

@onready var summary_layer: CanvasLayer = $SummaryLayer
@onready var summary_dim: Control = $SummaryLayer/Dim
@onready var summary_panel: Control = $SummaryLayer/SummaryPanel
@onready var summary_title: Label = $SummaryLayer/SummaryPanel/Margin/VBox/Title
@onready var summary_body: Label = $SummaryLayer/SummaryPanel/Margin/VBox/Body
@onready var summary_button: Button = $SummaryLayer/SummaryPanel/Margin/VBox/ButtonsRow/Continue

@onready var tutorial_drag: Control = $UI/TutorialDrag
@onready var tutorial_ok: Button = $UI/TutorialDrag/Panel/ButtonOk
@onready var tutorial_dim: Control = $UI/TutorialDrag/Dim
@onready var tutorial_panel: Control = $UI/TutorialDrag/Panel

var pending_donor_node: Node2D = null

@onready var error_popup: Control = $UI/TriageUI/ErrorPopup

@onready var tutorial_manual: Control = $UI/TutorialManual
@onready var tutorial_manual_dim: Control = $UI/TutorialManual/Dim
@onready var tutorial_manual_panel: Control = $UI/TutorialManual/Panel
@onready var tutorial_manual_label: Label = $UI/TutorialManual/Panel/Label
@onready var tutorial_manual_ok: Button = $UI/TutorialManual/Panel/ButtonOk
@onready var tutorial_manual_arrow: Control = $UI/TutorialManual/Arrow

var arrow_tween: Tween = null


func _ready() -> void:
	game_ui.connect("all_donors_completed", Callable(self, "_on_all_donors_completed"))

	# summary
	summary_layer.visible = false
	summary_button.pressed.connect(_on_summary_continue_pressed)

	summary_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	summary_dim.offset_left = 0
	summary_dim.offset_top = 0
	summary_dim.offset_right = 0
	summary_dim.offset_bottom = 0

	player.set_physics_process(false)
	player.set_process_input(false)
	if player.has_method("face_up_idle"):
		player.face_up_idle()

	intro_layer.visible = true
	intro_button.disabled = false
	intro_button.pressed.connect(_on_intro_finished)

	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.offset_left = 0
	dim.offset_top = 0
	dim.offset_right = 0
	dim.offset_bottom = 0

	dim.modulate.a = 0.0
	intro_panel.modulate.a = 0.0

	var tw = create_tween()
	tw.tween_property(dim, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(intro_panel, "modulate:a", 1.0, 0.25)

	_setup_triage_drag_ui()
	_setup_tutorial_drag()
	_setup_error_popup_hook()
	_setup_tutorial_manual()


func _setup_triage_drag_ui() -> void:
	if triage_drag_ui == null:
		return

	triage_drag_ui.visible = false

	var drop_id := triage_drag_ui.get_node_or_null("Root/DropRow/DropIdoneo")
	var drop_non := triage_drag_ui.get_node_or_null("Root/DropRow/DropNonIdoneo")
	var drag_root := $UI/DragLayer/DragRoot

	if drop_id == null or drop_non == null or drag_root == null:
		push_error("Setup Drag UI: nodi mancanti")
		return

	triage_drag_ui.setup(game_ui, drop_id, drop_non, drag_root)


func _setup_tutorial_drag() -> void:
	if tutorial_drag == null:
		return

	tutorial_drag.set_anchors_preset(Control.PRESET_FULL_RECT)
	tutorial_drag.offset_left = 0
	tutorial_drag.offset_top = 0
	tutorial_drag.offset_right = 0
	tutorial_drag.offset_bottom = 0

	tutorial_drag.visible = false
	tutorial_drag.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if tutorial_dim:
		tutorial_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		tutorial_dim.offset_left = 0
		tutorial_dim.offset_top = 0
		tutorial_dim.offset_right = 0
		tutorial_dim.offset_bottom = 0
		tutorial_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if tutorial_panel:
		tutorial_panel.set_anchors_preset(Control.PRESET_CENTER)

	if tutorial_ok and not tutorial_ok.pressed.is_connected(Callable(self, "_on_tutorial_ok_pressed")):
		tutorial_ok.pressed.connect(Callable(self, "_on_tutorial_ok_pressed"))


func _setup_error_popup_hook() -> void:
	if error_popup and not error_popup.visibility_changed.is_connected(Callable(self, "_on_error_popup_visibility_changed")):
		error_popup.visibility_changed.connect(Callable(self, "_on_error_popup_visibility_changed"))
	_on_error_popup_visibility_changed()


func _setup_tutorial_manual() -> void:
	if tutorial_manual == null:
		return

	tutorial_manual.set_anchors_preset(Control.PRESET_FULL_RECT)
	tutorial_manual.offset_left = 0
	tutorial_manual.offset_top = 0
	tutorial_manual.offset_right = 0
	tutorial_manual.offset_bottom = 0

	tutorial_manual.visible = false
	tutorial_manual.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if tutorial_manual_dim:
		tutorial_manual_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		tutorial_manual_dim.offset_left = 0
		tutorial_manual_dim.offset_top = 0
		tutorial_manual_dim.offset_right = 0
		tutorial_manual_dim.offset_bottom = 0
		tutorial_manual_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if tutorial_manual_panel:
		tutorial_manual_panel.set_anchors_preset(Control.PRESET_CENTER)

	if tutorial_manual_label:
		tutorial_manual_label.text = "QUI trovi il MANUALE per ogni dubbio.\nUsalo quando vuoi! 📘"

	if tutorial_manual_ok and not tutorial_manual_ok.pressed.is_connected(Callable(self, "_on_tutorial_manual_ok_pressed")):
		tutorial_manual_ok.pressed.connect(Callable(self, "_on_tutorial_manual_ok_pressed"))

func _on_intro_finished() -> void:
	intro_button.disabled = true

	var tw = create_tween()
	tw.tween_property(dim, "modulate:a", 0.0, 0.25)
	tw.parallel().tween_property(intro_panel, "modulate:a", 0.0, 0.25)
	tw.finished.connect(_hide_intro_and_start)


func _hide_intro_and_start() -> void:
	intro_layer.visible = false
	player.set_physics_process(true)
	player.set_process_input(true)

	_show_tutorial_manual_once()


func _show_tutorial_manual_once() -> void:
	if player.has_method("set_can_move"):
		player.set_can_move(false)
	if tutorial_manual == null:
		return
	if RunState.tutorial_manual_seen:
		return

	RunState.tutorial_manual_seen = true

	tutorial_manual.visible = true
	tutorial_manual.mouse_filter = Control.MOUSE_FILTER_STOP	

	if tutorial_manual_arrow:
		if arrow_tween and arrow_tween.is_running():
			arrow_tween.kill()

		var base_y := tutorial_manual_arrow.position.y
		arrow_tween = create_tween()
		arrow_tween.set_loops() # infinito
		arrow_tween.tween_property(tutorial_manual_arrow, "position:y", base_y - 8, 0.35)
		arrow_tween.tween_property(tutorial_manual_arrow, "position:y", base_y + 24, 0.35)


func _on_tutorial_manual_ok_pressed() -> void:
	if player.has_method("set_can_move"):
		player.set_can_move(true)
	else:
		player.set_physics_process(true)
		player.set_process_input(true)
	if arrow_tween and arrow_tween.is_running():
		arrow_tween.kill()

	tutorial_manual.visible = false
	tutorial_manual.mouse_filter = Control.MOUSE_FILTER_IGNORE


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

	if error_popup and error_popup.visible:
		triage_drag_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return

	if not RunState.tutorial_drag_seen:
		RunState.tutorial_drag_seen = true
		pending_donor_node = donor_node

		tutorial_drag.visible = true
		tutorial_drag.mouse_filter = Control.MOUSE_FILTER_STOP
		triage_drag_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return

	triage_drag_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	triage_drag_ui.start_for_donor(donor_node)


func _on_tutorial_ok_pressed() -> void:
	tutorial_drag.visible = false
	tutorial_drag.mouse_filter = Control.MOUSE_FILTER_IGNORE

	triage_drag_ui.mouse_filter = Control.MOUSE_FILTER_STOP

	if pending_donor_node and is_instance_valid(pending_donor_node):
		triage_drag_ui.start_for_donor(pending_donor_node)
	pending_donor_node = null


func hide_drag_ui() -> void:
	if triage_drag_ui:
		triage_drag_ui.force_close_and_restore()


func _on_error_popup_visibility_changed() -> void:
	var open := (error_popup != null and error_popup.visible)

	if drag_layer:
		drag_layer.visible = not open

	if triage_drag_ui:
		triage_drag_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE if open else Control.MOUSE_FILTER_STOP


func _on_all_donors_completed() -> void:
	var total: int = int(game_ui.donors.size())
	var correct: int = int(total - game_ui.donors_missed_first_try.size())
	var mistakes: int = int(game_ui.mistakes_total)

	# ✅ SYNC anti-doppio (idempotente)
	RunState.mistakes_total -= RunState.mistakes_acceptance
	RunState.mistakes_acceptance = mistakes
	RunState.mistakes_total += RunState.mistakes_acceptance

	print("[ACCEPTANCE] mistakes_room=", mistakes,
		" acc_saved=", RunState.mistakes_acceptance,
		" total_now=", RunState.mistakes_total)

	player.set_physics_process(false)
	player.set_process_input(false)

	summary_title.text = "Stanza completata ✅"
	summary_body.text = "Donatori gestiti correttamente: %d / %d\nErrori totali: %d" % [
		correct, total, RunState.mistakes_total
	]

	summary_layer.visible = true
	summary_panel.visible = true
