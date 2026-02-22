extends Node2D

@export var donor_scene: PackedScene
@export var minigame_scene: PackedScene

@onready var slots_parent: Node2D = $DonorSlots

@onready var ui: Node = $UI
@onready var hud_layer: CanvasLayer = $UI/HUD

@onready var intro_layer: CanvasLayer = $UI/IntroLayer
@onready var overlay_root: Control   = $UI/IntroLayer/OverlayRoot
@onready var dim: ColorRect          = $UI/IntroLayer/OverlayRoot/Dim
@onready var intro_panel: Control    = $UI/IntroLayer/OverlayRoot/IntroPanel
@onready var intro_title: Label      = $UI/IntroLayer/OverlayRoot/IntroPanel/Margin/VBox/Title
@onready var intro_body: Label       = $UI/IntroLayer/OverlayRoot/IntroPanel/Margin/VBox/Body
@onready var intro_btn: Button       = $UI/IntroLayer/OverlayRoot/IntroPanel/Margin/VBox/ButtonsRow/Intro


@export var DEBUG_FINAL: bool = true

var spawned_final_donors: Array = []
var donation_running: bool = false
var intro_open: bool = false
var summary_open: bool = false

var _locked_player: Node = null
var _locks: int = 0
var _medal_icon: TextureRect = null
var fail_popup: Control = null

const TEX_GOLD   := preload("res://assets/ui/medals/bag_gold.png")
const TEX_SILVER := preload("res://assets/ui/medals/bag_silver.png")
const TEX_BRONZE := preload("res://assets/ui/medals/bag_bronze.png")


func _ready() -> void:
	if DEBUG_FINAL:
		print("[FINALROOM] _ready()  scene=", get_tree().current_scene.name)

	RunState.reset_final_room_state()

	spawn_final_donors()
	_apply_panel_layout_for_text()

	if not RunState.tutorial_final_seen:
		RunState.tutorial_final_seen = true
		_show_intro()
	else:
		_hide_overlay()


func spawn_final_donors() -> void:
	for d in spawned_final_donors:
		if is_instance_valid(d):
			d.queue_free()
	spawned_final_donors.clear()

	if donor_scene == null:
		push_error("FinalRoom: donor_scene NULL")
		return

	var slots: Array[Marker2D] = []
	for c in slots_parent.get_children():
		if c is Marker2D:
			slots.append(c as Marker2D)

	var ids: Array = RunState.donors_for_final
	if DEBUG_FINAL:
		print("[FINALROOM] donors_for_final=", ids)

	if ids.is_empty():
		print("[FINALROOM] nessun donatore idoneo.")
		return

	var n: int = mini(ids.size(), slots.size())
	for i in range(n):
		var donor_id: int = int(ids[i])
		if donor_id < 0 or donor_id >= RunState.donors.size():
			push_warning("[FINALROOM] donor_id fuori range: %s" % donor_id)
			continue

		var donor_data: Dictionary = RunState.donors[donor_id].duplicate(true)
		donor_data["id"] = donor_id

		var d := donor_scene.instantiate()
		add_child(d)
		(d as Node2D).global_position = slots[i].global_position

		if d.has_method("setup"):
			d.setup(donor_data)

		if d.has_method("set_done"):
			d.set_done(false)
		if d.has_method("set_interaction_enabled"):
			d.set_interaction_enabled(true)

		spawned_final_donors.append(d)

	print("[FINALROOM] spawned=", spawned_final_donors.size())


func start_donation_for(donor_id: int) -> void:
	if DEBUG_FINAL:
		print("[FINALROOM] start_donation_for donor_id=", donor_id,
			" intro_open=", intro_open,
			" summary_open=", summary_open,
			" donation_running=", donation_running)

	if intro_open or summary_open:
		return
	if donation_running:
		return

	if RunState.donation_completed_ids.has(donor_id) or RunState.donation_failed_ids.has(donor_id):
		return

	if minigame_scene == null:
		push_error("FinalRoom: minigame_scene NULL")
		return

	donation_running = true
	_lock_player()

	var mg := minigame_scene.instantiate()
	var seen: bool = bool(RunState.donation_tutorial_seen)
	var show_tut: bool = not seen
	RunState.donation_tutorial_seen = true

	if mg.has_method("set_show_tutorial"):
		mg.set_show_tutorial(show_tut)

	hud_layer.add_child(mg)

	if mg is Control:
		var c := mg as Control
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.offset_left = 0
		c.offset_top = 0
		c.offset_right = 0
		c.offset_bottom = 0
		c.z_index = 999

	mg.tree_exited.connect(func():
		if DEBUG_FINAL: print("[FINALROOM] minigame tree_exited safety")
		donation_running = false
		_unlock_player()
	)

	mg.finished.connect(func(success: bool):
		if DEBUG_FINAL:
			print("[FINALROOM] <<< minigame finished donor_id=", donor_id, " success=", success)

		if success:
			if not RunState.donation_completed_ids.has(donor_id):
				RunState.donation_completed_ids.append(donor_id)
		else:
			if not RunState.donation_failed_ids.has(donor_id):
				RunState.donation_failed_ids.append(donor_id)
				
			RunState.mistakes_final = RunState.donation_failed_ids.size()
			RunState.recompute_mistakes_total()

		_mark_donor_done_in_scene(donor_id)
		donation_running = false
		
		if not success:
			_show_fail_popup_like_summary("Dovevi premere il tasto sinistro più velocemente.\nLa prossima volta cerca di essere più veloce 💉")
			return
	# ✅ se successo: sblocca e continua flow normale
		_unlock_player()
		_try_finish_room()
	)


func _mark_donor_done_in_scene(donor_id: int) -> void:
	for d in spawned_final_donors:
		if not is_instance_valid(d):
			continue
		if d.has_method("get_donor_data"):
			var data: Dictionary = d.get_donor_data()
			if int(data.get("id", -1)) == donor_id:
				if d.has_method("set_done"):
					d.set_done(true)
				elif d.has_method("set_interaction_enabled"):
					d.set_interaction_enabled(false)
				return


func _try_finish_room() -> void:
	var total := RunState.donors_for_final.size()
	var done := RunState.donation_completed_ids.size() + RunState.donation_failed_ids.size()
	if total > 0 and done >= total:
		_show_summary()


func _apply_panel_layout_for_text() -> void:
	intro_panel.custom_minimum_size = Vector2(620, 280)
	intro_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	intro_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	intro_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_body.clip_text = false


func _show_intro() -> void:
	intro_open = true
	summary_open = false
	_lock_player()

	intro_layer.visible = true
	overlay_root.visible = true
	dim.visible = true
	intro_panel.visible = true

	intro_title.text = "Stanza finale — Donazione"
	intro_body.text = \
		"Ultimo step: completa la donazione per i donatori idonei.\n\n" + \
		"• Avvicinati e premi E.\n" + \
		"• La sacca si riempie nel tempo.\n" + \
		"• Se compare la mano premi/lascia velocemente click sinistro mouse.\n\n" + \
		"Ogni donazione fallita aumenta gli errori totali."

	intro_btn.text = "Inizia"

	if intro_btn.pressed.is_connected(_on_intro_pressed):
		intro_btn.pressed.disconnect(_on_intro_pressed)
	if intro_btn.pressed.is_connected(_on_summary_pressed):
		intro_btn.pressed.disconnect(_on_summary_pressed)

	intro_btn.pressed.connect(_on_intro_pressed)


func _on_intro_pressed() -> void:
	_hide_overlay()


func _show_summary() -> void:
	intro_open = false
	summary_open = true
	_lock_player()
	
	RunState.mistakes_final = RunState.donation_failed_ids.size()
	RunState.recompute_mistakes_total()
	
	var ok := RunState.donation_completed_ids.size()
	var fail := RunState.donation_failed_ids.size()
	var total := RunState.donors_for_final.size()
	var errors := int(RunState.mistakes_total)

	# blocca interazioni
	for d in spawned_final_donors:
		if is_instance_valid(d) and d.has_method("set_interaction_enabled"):
			d.set_interaction_enabled(false)

	intro_layer.visible = true
	overlay_root.visible = true
	dim.visible = true
	intro_panel.visible = true

	# --- MEDAGLIA ---
	_ensure_medal_icon()

	var medal_name := "BRONZO"
	var medal_tex: Texture2D = TEX_BRONZE

	if errors == 0:
		medal_name = "ORO"
		medal_tex = TEX_GOLD
	elif errors <= 3:
		medal_name = "ARGENTO"
		medal_tex = TEX_SILVER
	else:
		medal_name = "BRONZO"
		medal_tex = TEX_BRONZE

	if is_instance_valid(_medal_icon):
		_medal_icon.texture = medal_tex
		_medal_icon.custom_minimum_size = Vector2(140, 140) # ✅ ancora più grande se vuoi
		_medal_icon.modulate = Color(1,1,1,1)

	# --- TESTI ---
	intro_title.text = "Stanza completata ✅"
	intro_body.text = \
		"Medaglia: %s 🏅\n\n" % medal_name + \
		"Donazioni completate: %d / %d\n" % [ok, total] + \
		"Donazioni fallite: %d\n" % fail + \
		"Errori totali: %d\n\n" % errors + \
		_get_motivational_line(errors)

	intro_btn.text = "Fine"

	# 🔥 Pulisce TUTTE le connessioni precedenti
	for c in intro_btn.pressed.get_connections():
		intro_btn.pressed.disconnect(c.callable)

	intro_btn.pressed.connect(_on_summary_pressed)

	# ✅ FIX layout (wrap + pannello)
	call_deferred("_fit_panel_to_text")

func _on_summary_pressed() -> void:
	print("END GAME / BACK TO MENU")
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")


func _hide_overlay() -> void:
	intro_open = false
	summary_open = false
	intro_layer.visible = false
	overlay_root.visible = false
	dim.visible = false
	intro_panel.visible = false
	_unlock_player()


func _find_player_with_can_move() -> Node:
	var root := get_tree().current_scene
	if root == null:
		return null
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n != null and n.has_method("set_can_move"):
			return n
		for c in n.get_children():
			stack.append(c)
	return null


func _lock_player() -> void:
	_locks += 1
	if _locks > 1:
		return
	get_viewport().gui_release_focus()

	if _locked_player == null:
		_locked_player = _find_player_with_can_move()
	if _locked_player == null:
		if DEBUG_FINAL: print("[LOCK] player not found (no set_can_move). Skip lock.")
		return

	_locked_player.set_can_move(false)


func _unlock_player() -> void:
	_locks -= 1
	if _locks > 0:
		return
	_locks = 0
	get_viewport().gui_release_focus()

	if _locked_player != null:
		_locked_player.set_can_move(true)
		_locked_player = null

func _medal_data_for_errors(err: int) -> Dictionary:

	if err <= 0:
		return {
			"label": "Medaglia d’ORO 🏅",
			"tex": "res://assets/ui/medals/bag_gold.png",
			"msg": "Perfetto! Hai gestito tutto al meglio: ogni donazione conta davvero. Continua così 💛"
		}
	elif err <= 3:
		return {
			"label": "Medaglia d’ARGENTO 🥈",
			"tex": "res://assets/ui/medals/bag_silver.png",
			"msg": "Ottimo lavoro! Qualche imprevisto capita: l’importante è esserci e migliorare. Grazie per il tuo impegno 🤍"
		}
	else:
		return {
			"label": "Medaglia di BRONZO 🥉",
			"tex": "res://assets/ui/medals/bag_bronze.png",
			"msg": "Non mollare! Anche i piccoli passi salvano vite: riprova con calma e diventerai super bravo 🤎"
		}


func _ensure_medal_icon() -> void:
	if is_instance_valid(_medal_icon):
		return

	# VBox dove stanno Title/Body/ButtonsRow
	var vbox := $UI/IntroLayer/OverlayRoot/IntroPanel/Margin/VBox as VBoxContainer
	if vbox == null:
		push_warning("[FINALROOM] VBox non trovato per MedalIcon")
		return

	var icon := TextureRect.new()
	icon.name = "MedalIcon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(120, 120) # ✅ grande
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# mettila in cima (indice 0)
	vbox.add_child(icon)
	vbox.move_child(icon, 0)

	_medal_icon = icon


func _fit_panel_to_text() -> void:
	intro_panel.custom_minimum_size = Vector2(940, 520)

	intro_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	intro_title.clip_text = false
	intro_body.clip_text = false

	var usable_w := intro_panel.custom_minimum_size.x - 60.0
	intro_title.custom_minimum_size = Vector2(usable_w, 0)
	intro_body.custom_minimum_size = Vector2(usable_w, 0)

	intro_panel.queue_redraw()
	
func _get_motivational_line(errors: int) -> String:
	if errors == 0:
		return "Perfetto! Hai gestito tutto al meglio: ogni donazione conta davvero. Continua così 💛"
	elif errors < 3:
		return "Ottimo lavoro! Qualche imprevisto può capitare: l’importante è la sicurezza. Ci sei quasi 🤍"
	else:
		return "Non mollare! La donazione richiede attenzione e calma: riprova e migliora, un passo alla volta 🧡"
		
func _show_fail_popup() -> void:
	if fail_popup != null:
		return

	fail_popup = Control.new()
	fail_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	fail_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	hud_layer.add_child(fail_popup)

	# sfondo scuro
	var dim_bg := ColorRect.new()
	dim_bg.color = Color(0, 0, 0, 0.6)
	dim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	fail_popup.add_child(dim_bg)

	# pannello centrale
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(520, 180)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position -= panel.custom_minimum_size * 0.5
	fail_popup.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20
	vbox.offset_top = 20
	vbox.offset_right = -20
	vbox.offset_bottom = -20
	panel.add_child(vbox)

	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = "❌ Donazione fallita.\n\nDovevi premere il tasto sinistro più velocemente."
	vbox.add_child(label)

	var btn := Button.new()
	btn.text = "OK"
	vbox.add_child(btn)

	btn.pressed.connect(func():
		fail_popup.queue_free()
		fail_popup = null
		_unlock_player()
		_try_finish_room()
	)
func _show_fail_popup_like_summary(msg: String) -> void:
	# usa lo stesso overlay della stanza (pixel font + stile già ok)
	intro_open = true
	summary_open = false
	_lock_player()

	intro_layer.visible = true
	overlay_root.visible = true
	dim.visible = true
	intro_panel.visible = true

	# se hai l'icona medaglia in summary, qui la nascondiamo (opzionale)
	if is_instance_valid(_medal_icon):
		_medal_icon.visible = false

	intro_title.text = "Donazione fallita ❌"
	intro_body.text = msg
	intro_btn.text = "OK"

	# evita doppi connect
	if intro_btn.pressed.is_connected(_on_intro_pressed):
		intro_btn.pressed.disconnect(_on_intro_pressed)
	if intro_btn.pressed.is_connected(_on_summary_pressed):
		intro_btn.pressed.disconnect(_on_summary_pressed)

	# OK: chiudi overlay e continua
	intro_btn.pressed.connect(func():
		_hide_overlay()
		_unlock_player()
		_try_finish_room()
	)
