extends Control

@export var click_radius: float = 48.0
@export var debug_logs: bool = true

var triage_logic: Node = null
var drop_idoneo: Control = null
var drop_non: Control = null
var drag_root: Node2D = null

var donor: Node2D = null
var hit_anchor: Node2D = null

var donor_attached: bool = false
var dragging: bool = false
var drag_offset_screen: Vector2 = Vector2.ZERO

# Stato originale (per restore)
var donor_original_parent: Node = null
var donor_original_z: int = 0
var donor_original_z_as_relative: bool = true
var donor_original_process: bool = true
var donor_original_physics: bool = true
var donor_original_global_transform: Transform2D

# mentre aspettiamo l’esito (popup o no)
var resolving_choice: bool = false
var last_drop_valid: bool = false

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	set_process_input(true)

func setup(_triage_logic: Node, _drop_idoneo: Control, _drop_non: Control, _drag_root: Node2D) -> void:
	triage_logic = _triage_logic
	drop_idoneo = _drop_idoneo
	drop_non = _drop_non
	drag_root = _drag_root
	_dbg("setup OK triage_logic=%s drop_id=%s drop_non=%s drag_root=%s" % [triage_logic, drop_idoneo, drop_non, drag_root])

func start_for_donor(donor_node: Node2D) -> void:
	donor = donor_node
	dragging = false
	donor_attached = false
	drag_offset_screen = Vector2.ZERO
	resolving_choice = false
	last_drop_valid = false

	if donor != null:
		hit_anchor = donor.get_node_or_null("PromptAnchor") as Node2D
		if hit_anchor == null:
			hit_anchor = donor
	else:
		hit_anchor = null

	_dbg("start_for_donor donor=%s hit_anchor=%s" % [donor, hit_anchor])

func force_close_and_restore() -> void:
	visible = false
	resolving_choice = false
	if donor_attached:
		_restore_donor()
	donor = null
	hit_anchor = null
	dragging = false
	donor_attached = false

func _process(_delta: float) -> void:
	if triage_logic == null:
		visible = false
		return

	var should_show := false
	if triage_logic.has_method("is_triage_active"):
		should_show = bool(triage_logic.is_triage_active())

	if visible != should_show:
		visible = should_show
		_dbg("visible -> %s" % visible)

		if (not visible) and donor_attached:
			_restore_donor()
			donor = null
			hit_anchor = null
			donor_attached = false
			dragging = false
			resolving_choice = false

	# follow mouse while dragging (SCREEN coords)
	if visible and dragging and donor != null and donor_attached and not resolving_choice:
		var mouse_s := _mouse_screen()
		donor.global_position = mouse_s - drag_offset_screen

	# ✅ se stiamo aspettando la risoluzione e il popup è stato chiuso,
	# allora possiamo tornare a permettere il drag (ramo sbagliato)
	if resolving_choice and triage_logic != null and triage_logic.has_method("is_error_popup_open"):
		if not bool(triage_logic.call("is_error_popup_open")):
			# popup chiuso => era errore, ora deve poter riprovare
			resolving_choice = false
			_dbg("popup closed -> retry enabled")

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if donor == null:
		return

	# ✅ se popup aperto -> NON gestire input (così il click va al bottone OK)
	if triage_logic != null and triage_logic.has_method("is_error_popup_open"):
		if bool(triage_logic.call("is_error_popup_open")):
			return

	# ✅ se stiamo aspettando risoluzione (dopo drop) -> non iniziare nuovi drag
	if resolving_choice:
		return

	if drop_idoneo == null or drop_non == null or drag_root == null:
		_dbg("MISSING refs drop/drag_root -> drop_id=%s drop_non=%s drag_root=%s" % [drop_idoneo, drop_non, drag_root])
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return

		var mouse_s := _mouse_screen()

		if debug_logs:
			_dbg("LMB pressed=%s mouse_s=%s donor=%s dragging=%s attached=%s resolving=%s" %
				[mb.pressed, mouse_s, donor, dragging, donor_attached, resolving_choice])

		# START DRAG
		if mb.pressed:
			if not donor_attached:
				# click test in WORLD usando anchor
				var mouse_w: Vector2 = donor.get_global_mouse_position()
				var anchor_w: Vector2 = (hit_anchor.global_position if hit_anchor != null else donor.global_position)
				var dist_w := anchor_w.distance_to(mouse_w)

				_dbg("WORLD click dist=%s (radius=%s)" % [dist_w, click_radius])

				if dist_w <= click_radius:
					_attach_donor_keep_visual()
					dragging = true
					drag_offset_screen = mouse_s - donor.global_position
					get_viewport().set_input_as_handled()
				return
			else:
				# già attaccato: click test in SCREEN
				var dist_s := donor.global_position.distance_to(mouse_s)
				if dist_s <= click_radius:
					dragging = true
					drag_offset_screen = mouse_s - donor.global_position
					get_viewport().set_input_as_handled()
				return

		# DROP
		if (not mb.pressed) and dragging:
			dragging = false
			get_viewport().set_input_as_handled()
			_try_drop(mouse_s)
			return

func _mouse_screen() -> Vector2:
	return get_viewport().get_mouse_position()

func _attach_donor_keep_visual() -> void:
	if donor == null or drag_root == null:
		return
	if donor_attached:
		return

	donor_original_parent = donor.get_parent()
	donor_original_z = donor.z_index
	donor_original_z_as_relative = donor.z_as_relative
	donor_original_process = donor.is_processing()
	donor_original_physics = donor.is_physics_processing()
	donor_original_global_transform = donor.global_transform

	donor.set_process(false)
	donor.set_physics_process(false)

	var canvas_xform: Transform2D = get_viewport().get_canvas_transform()
	var screen_xform: Transform2D = canvas_xform * donor_original_global_transform

	if donor_original_parent != null:
		donor_original_parent.remove_child(donor)
	drag_root.add_child(donor)

	donor.global_transform = screen_xform

	# NON tocchiamo lo z
	donor.z_index = donor_original_z
	donor.z_as_relative = donor_original_z_as_relative

	donor_attached = true
	_dbg("ATTACH OK donor=%s" % donor.name)

func _restore_donor() -> void:
	if donor == null:
		return
	if donor_original_parent == null:
		donor_attached = false
		return

	var p := donor.get_parent()
	if p != null:
		p.remove_child(donor)
	donor_original_parent.add_child(donor)

	donor.global_transform = donor_original_global_transform
	donor.z_index = donor_original_z
	donor.z_as_relative = donor_original_z_as_relative
	donor.set_process(donor_original_process)
	donor.set_physics_process(donor_original_physics)

	donor_attached = false
	dragging = false
	_dbg("RESTORE OK donor=%s" % donor.name)

func _try_drop(mouse_s: Vector2) -> void:
	if donor == null:
		return

	var in_idoneo := drop_idoneo.get_global_rect().has_point(mouse_s)
	var in_non := drop_non.get_global_rect().has_point(mouse_s)

	_dbg("drop check: in_idoneo=%s in_non=%s" % [in_idoneo, in_non])

	if in_idoneo or in_non:
		var accepted := in_idoneo

		# chiudiamo il drag e rimettiamo il donor al parent originale (così non resta “incollato”)
		_restore_donor()

		# ✅ avviamo gestione scelta senza “async without await”
		if triage_logic != null and triage_logic.has_method("handle_choice"):
			resolving_choice = true
			last_drop_valid = true
			_dbg("CALL handle_choice(%s) (deferred)" % accepted)
			triage_logic.call_deferred("handle_choice", accepted)

			# ✅ dopo 1 frame controlliamo se è comparso il popup:
			# - se popup compare => era sbagliato => NON sparire, e dopo OK può riprovare
			# - se popup NON compare => consideriamo corretto => sparisci subito
			call_deferred("_post_choice_check")
		return

	# drop fuori: torna alla sedia
	_restore_donor()

func _post_choice_check() -> void:
	# questa funzione usa await, quindi dev’essere async (in Godot va bene così)
	await get_tree().process_frame

	if not resolving_choice:
		return
	if triage_logic == null or not triage_logic.has_method("is_error_popup_open"):
		# se non possiamo sapere, non facciamo sparire (safe)
		resolving_choice = false
		return

	var popup_open := bool(triage_logic.call("is_error_popup_open"))

	if popup_open:
		# ❌ sbagliato: lasciamo tutto com’è, l’utente clicca OK e poi riprova
		_dbg("choice WRONG (popup open) -> keep donor, retry after OK")
		# resolving_choice resta true finché il popup non si chiude (lo gestiamo in _process)
		return

	# ✅ corretto: sparisce SUBITO
	_dbg("choice CORRECT (no popup) -> hide donor now")
	_mark_donor_done()
	resolving_choice = false

	# chiudi riferimento: questo donor è finito
	donor = null
	hit_anchor = null

func _mark_donor_done() -> void:
	if donor == null:
		return

	donor.visible = false

	if donor is CollisionObject2D:
		(donor as CollisionObject2D).set_deferred("collision_layer", 0)
		(donor as CollisionObject2D).set_deferred("collision_mask", 0)

	var area := donor.get_node_or_null("DonorArea")
	if area != null:
		area.set_deferred("monitoring", false)
		area.set_deferred("monitorable", false)
		area.set_process(false)

func _dbg(msg: String) -> void:
	if debug_logs:
		print("[TriageDragUI] ", msg)
