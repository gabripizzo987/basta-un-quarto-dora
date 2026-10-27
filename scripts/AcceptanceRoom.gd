extends Node2D

const UiStyle := preload("res://scripts/UiStyle.gd")
const TAP_HAND := "res://assets/ui/tap_hand.png"

var _dpad: CanvasLayer = null
var _demo_layer: CanvasLayer = null
var _demo_tween: Tween = null

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
	_dpad = preload("res://scripts/VirtualDpad.gd").new()
	add_child(_dpad)
	game_ui.connect("all_donors_completed", Callable(self, "_on_all_donors_completed"))
	call_deferred("_resize_interact_prompt")

func _resize_interact_prompt() -> void:
	var prompt := get_node_or_null("UI/InteractPrompt")
	if prompt == null:
		return
	var key  := prompt.get_node_or_null("Pill/HBoxContainer/Key")  as Label
	var text := prompt.get_node_or_null("Pill/HBoxContainer/Text") as Label
	var pill := prompt.get_node_or_null("Pill") as PanelContainer
	if key  != null: key.add_theme_font_size_override("font_size", 28)
	if text != null: text.add_theme_font_size_override("font_size", 24)
	if pill != null:
		pill.custom_minimum_size = Vector2(160, 44)
		pill.set_offset(SIDE_LEFT,   -21.0)
		pill.set_offset(SIDE_TOP,      7.0)
		pill.set_offset(SIDE_RIGHT,  139.0)
		pill.set_offset(SIDE_BOTTOM,  51.0)
	prompt.set("offset_pixels", Vector2(0, -95))

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
	_setup_manual_overlay()


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
		var body := tutorial_panel.get_node_or_null("Label") as Label
		if body != null:
			body.text = "Tieni premuto sul donatore e trascinalo sulla sacca giusta: IDONEO oppure NON IDONEO."
		if tutorial_ok:
			tutorial_ok.text = "Ho capito"
		UiStyle.rebuild_panel(tutorial_panel, "Come si decide", body, tutorial_ok, 440)
		tutorial_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# sfondo piu' leggero: il donatore e le sacche devono restare visibili
	if tutorial_dim and tutorial_dim is ColorRect:
		(tutorial_dim as ColorRect).color = Color(0, 0, 0, 0.35)

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

	if tutorial_manual_label:
		tutorial_manual_label.text = "Qui trovi il Manuale con tutte le regole. Aprilo quando hai un dubbio."
	if tutorial_manual_ok:
		tutorial_manual_ok.text = "Ok"
	if tutorial_manual_panel:
		UiStyle.rebuild_panel(tutorial_manual_panel, "Il Manuale", tutorial_manual_label, tutorial_manual_ok, 340)
		tutorial_manual_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)

	if tutorial_manual_ok and not tutorial_manual_ok.pressed.is_connected(Callable(self, "_on_tutorial_manual_ok_pressed")):
		tutorial_manual_ok.pressed.connect(Callable(self, "_on_tutorial_manual_ok_pressed"))
		

func _setup_manual_overlay() -> void:
	var panel_manual := game_ui.get_node_or_null("PanelManual") as Control
	if panel_manual == null:
		return

	var manual_layer := CanvasLayer.new()
	manual_layer.name = "ManualOverlay"
	manual_layer.layer = 200
	add_child(manual_layer)

	panel_manual.reparent(manual_layer, false)

	# Ri-applica gli anchor centrati dopo il reparent
	panel_manual.set_anchors_preset(Control.PRESET_CENTER)
	panel_manual.offset_left = -500.0
	panel_manual.offset_top  = -300.0
	panel_manual.offset_right  = 500.0
	panel_manual.offset_bottom = 300.0
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
	AudioManager.play_music("acceptance")

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
		call_deferred("_align_arrow_to_manual_btn")


func _align_arrow_to_manual_btn() -> void:
	if tutorial_manual_arrow == null:
		return
	var btn := game_ui.get_node_or_null("ButtonManual") as Control
	if btn != null:
		var btn_rect := btn.get_global_rect()
		var cx := btn_rect.position.x + btn_rect.size.x * 0.5
		# Arrow rotated -90deg: visual footprint is 49px wide, 101px tall (extends upward from anchor).
		tutorial_manual_arrow.position = Vector2(cx - 24.5, btn_rect.end.y + 109.0)
		# nuvoletta subito sotto la freccia, allineata a destra col pulsante
		if tutorial_manual_panel:
			var ps: Vector2 = tutorial_manual_panel.size
			tutorial_manual_panel.position = Vector2(
				minf(btn_rect.end.x - ps.x, get_viewport().get_visible_rect().size.x - ps.x - 12.0),
				btn_rect.end.y + 128.0).round()

	if arrow_tween and arrow_tween.is_running():
		arrow_tween.kill()
	var base_y := tutorial_manual_arrow.position.y
	arrow_tween = create_tween()
	arrow_tween.set_loops()
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


## Scheda donatore: sotto il pulsante Manuale e a destra delle sacche,
## senza coprire niente. Si adatta alla larghezza dello schermo.
func _layout_donor_card() -> void:
	var card := game_ui.get_node_or_null("PanelAccept") as Control
	if card == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var top := 16.0
	var manual_btn := game_ui.get_node_or_null("ButtonManual") as Control
	if manual_btn != null and manual_btn.visible:
		top = manual_btn.get_global_rect().end.y + 12.0
	var left := vp.x - 460.0
	var bags_right := 0.0
	var bags_top := vp.y
	for path in ["Root/DropRow/DropIdoneo", "Root/DropRow/DropNonIdoneo"]:
		var z := triage_drag_ui.get_node_or_null(path) as Control
		if z != null:
			bags_right = maxf(bags_right, z.get_global_rect().end.x)
			bags_top = minf(bags_top, z.get_global_rect().position.y)
	left = maxf(left, bags_right + 24.0)
	left = minf(left, vp.x - 360.0)   # larghezza minima leggibile
	# schermo stretto (16:9): la scheda si ferma sopra le sacche e il testo si rimpicciolisce
	var narrow := left < bags_right + 24.0
	_card_max_bottom = (bags_top - 30.0) if narrow else (vp.y - 16.0)
	var info = game_ui.get("_rich_info")
	if info is RichTextLabel:
		(info as RichTextLabel).add_theme_font_size_override("normal_font_size", 15 if narrow else 18)
		(info as RichTextLabel).add_theme_constant_override("line_separation", 3 if narrow else 6)
	card.anchor_left = 1.0
	card.anchor_right = 1.0
	card.anchor_top = 0.0
	card.anchor_bottom = 1.0
	card.offset_left = left - vp.x
	card.offset_right = -16.0
	card.offset_top = top
	card.offset_bottom = -16.0


## La scheda e' alta quanto il suo contenuto (non arriva fino in fondo vuota).
func _fit_card_height(card: Control) -> void:
	var content := card.get_node_or_null("ContentVBox") as Control
	if content == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var h := content.get_combined_minimum_size().y + 36.0
	var bottom := minf(_card_max_bottom if _card_max_bottom > 0.0 else vp.y - 16.0, card.offset_top + h)
	card.offset_bottom = bottom - vp.y


## Joystick e tasto E spariscono mentre decidi o leggi un tutorial.
var _card_was_visible: bool = false
var _card_max_bottom: float = -1.0

func _process(_delta: float) -> void:
	# riposiziona la scheda ogni volta che compare (qualunque sia il percorso)
	var card := game_ui.get_node_or_null("PanelAccept") as Control
	if card != null:
		if card.visible and not _card_was_visible:
			_layout_donor_card()
		if card.visible:
			_fit_card_height(card)
		_card_was_visible = card.visible
	if _dpad == null:
		return
	var busy: bool = (game_ui.has_method("is_triage_active") and game_ui.is_triage_active()) \
		or tutorial_drag.visible or tutorial_manual.visible or intro_layer.visible \
		or summary_layer.visible
	if _dpad.visible == busy:
		_dpad.visible = not busy


func show_drag_ui_for_donor(donor_node: Node2D) -> void:
	AudioManager.play_sfx("drag_start")
	triage_drag_ui.visible = true
	call_deferred("_layout_donor_card")

	if error_popup and error_popup.visible:
		triage_drag_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return

	if not RunState.tutorial_drag_seen:
		RunState.tutorial_drag_seen = true
		pending_donor_node = donor_node

		tutorial_drag.visible = true
		tutorial_drag.mouse_filter = Control.MOUSE_FILTER_STOP
		triage_drag_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# pannello in alto al centro: sotto restano visibili donatore e sacche
		var vp := get_viewport().get_visible_rect().size
		tutorial_panel.position = Vector2((vp.x - tutorial_panel.size.x) * 0.5, 16.0).round()
		call_deferred("_start_drag_demo", donor_node)
		return

	triage_drag_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	triage_drag_ui.start_for_donor(donor_node)


## Manina che mostra il gesto: dal donatore alla sacca IDONEO, in loop.
func _start_drag_demo(donor_node: Node2D) -> void:
	_stop_drag_demo()
	if donor_node == null or not is_instance_valid(donor_node):
		return
	var drop := triage_drag_ui.get_node_or_null("Root/DropRow/DropIdoneo") as Control
	if drop == null or not ResourceLoader.exists(TAP_HAND):
		return

	_demo_layer = CanvasLayer.new()
	_demo_layer.layer = 90
	add_child(_demo_layer)
	var hand := TextureRect.new()
	hand.texture = load(TAP_HAND)
	hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hand.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hand.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hand.size = Vector2(72, 72)
	hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_demo_layer.add_child(hand)

	var anchor := donor_node.get_node_or_null("PromptAnchor") as Node2D
	var world_pos: Vector2 = anchor.global_position if anchor != null else donor_node.global_position
	var from: Vector2 = get_viewport().get_canvas_transform() * world_pos
	var to: Vector2 = drop.get_global_rect().get_center()
	var off := Vector2(-20, -8)   # la punta del dito sul punto giusto

	hand.position = from + off
	hand.modulate.a = 0.0
	_demo_tween = create_tween().set_loops()
	_demo_tween.tween_property(hand, "modulate:a", 1.0, 0.25)
	_demo_tween.tween_property(hand, "scale", Vector2(0.85, 0.85), 0.2)
	_demo_tween.tween_property(hand, "position", to + off, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_demo_tween.tween_property(hand, "scale", Vector2.ONE, 0.2)
	_demo_tween.tween_property(hand, "modulate:a", 0.0, 0.3)
	_demo_tween.tween_property(hand, "position", from + off, 0.01)
	_demo_tween.tween_interval(0.4)


func _stop_drag_demo() -> void:
	if _demo_tween != null and _demo_tween.is_valid():
		_demo_tween.kill()
	_demo_tween = null
	if is_instance_valid(_demo_layer):
		_demo_layer.queue_free()
	_demo_layer = null


func _on_tutorial_ok_pressed() -> void:
	_stop_drag_demo()
	tutorial_drag.visible = false
	tutorial_drag.mouse_filter = Control.MOUSE_FILTER_IGNORE

	triage_drag_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE

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
		triage_drag_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_all_donors_completed() -> void:
	var total: int = int(game_ui.donors.size())
	var correct: int = int(total - game_ui.donors_missed_first_try.size())
	var mistakes: int = int(game_ui.mistakes_total)

	RunState.mistakes_total -= RunState.mistakes_acceptance
	RunState.mistakes_acceptance = mistakes
	RunState.mistakes_total += RunState.mistakes_acceptance

	print("[ACCEPTANCE] mistakes_room=", mistakes,
		" acc_saved=", RunState.mistakes_acceptance,
		" total_now=", RunState.mistakes_total)

	player.set_physics_process(false)
	player.set_process_input(false)

	var room_score: int = RunState.compute_acceptance_score(correct, mistakes)

	summary_title.text = "Stanza completata"
	summary_body.text = "Donatori gestiti correttamente: %d / %d\nErrori totali: %d\n\nPunti stanza: %d\nPunteggio totale: %d" % [
		correct, total, RunState.mistakes_total, room_score, RunState.score_main()
	]

	AudioManager.play_sfx("room_complete")
	summary_layer.visible = true
	summary_panel.visible = true
	UiStyle.fit_summary_panel(summary_panel, summary_panel.get_node("Margin"),
		summary_title, summary_body, summary_button)
