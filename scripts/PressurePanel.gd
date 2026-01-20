extends Panel

signal continued
signal accepted
signal rejected

@onready var title_label: Label = $Margin/Root/Header/Title
@onready var body_label: Label = $Margin/Root/Body

@onready var continue_button: Button = $Margin/Root/Header/ContinueButton

@onready var buttons_row: HBoxContainer = $Margin/Root/ButtonsRow
@onready var accept_button: Button = $Margin/Root/ButtonsRow/AcceptButton
@onready var reject_button: Button = $Margin/Root/ButtonsRow/RejectButton

func _ready() -> void:
	hide()
	continue_button.pressed.connect(_on_continue_pressed)
	accept_button.pressed.connect(_on_accept_pressed)
	reject_button.pressed.connect(_on_reject_pressed)

func show_wait(title: String, body: String) -> void:
	title_label.text = title
	body_label.text = body
	continue_button.hide()
	buttons_row.hide()
	show()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.12)

func show_continue(title: String, body: String) -> void:
	title_label.text = title
	body_label.text = body
	buttons_row.hide()
	continue_button.show()
	show()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.12)

func show_decision(title: String, body: String) -> void:
	title_label.text = title
	body_label.text = body
	continue_button.hide()
	buttons_row.show()
	show()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.12)

func hide_panel() -> void:
	hide()

func _on_continue_pressed() -> void:
	hide()
	emit_signal("continued")

func _on_accept_pressed() -> void:
	hide()
	emit_signal("accepted")

func _on_reject_pressed() -> void:
	hide()
	emit_signal("rejected")
