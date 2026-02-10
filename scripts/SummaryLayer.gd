extends CanvasLayer

signal continued

@onready var panel: Control = $SummaryPanel
@onready var title_label: Label = $SummaryPanel/Margin/VBox/Title
@onready var body_label: Label = $SummaryPanel/Margin/VBox/Body
@onready var continue_button: Button = $SummaryPanel/Margin/VBox/ButtonsRow/Continue

func _ready() -> void:
	hide()
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)

func show_summary(correct_first_try: int, total: int, errors_total: int) -> void:
	# ✅ testo identico allo screenshot
	title_label.text = "Stanza completata ✅"
	body_label.text = "Donatori gestiti correttamente\nal primo tentativo: %d / %d\nErrori totali: %d" % [
		correct_first_try, total, errors_total
	]
	show()
	layer = 50  # sopra tutto

func _on_continue_pressed() -> void:
	hide()
	emit_signal("continued")
