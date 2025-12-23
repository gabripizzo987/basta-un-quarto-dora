extends Control

@onready var btn_prev: Button = $HBoxNav/ButtonPrev
@onready var btn_next: Button = $HBoxNav/ButtonNext
@onready var label_page: Label = $HBoxNav/LabelPage
@onready var btn_close: Button = $ButtonCloseManual

var player: Node = null

var pages: Array[Control] = []
var page_index: int = 0

func _ready() -> void:
	# trova il player (deve essere nel gruppo "player")
	player = get_tree().get_first_node_in_group("player")

	# raccoglie PagesRow, PagesRow2, ... PagesRow6
	pages.clear()
	for c in get_children():
		if c is Control and String(c.name).begins_with("PagesRow"):
			pages.append(c)

	pages.sort_custom(func(a, b): return String(a.name) < String(b.name))

	if pages.is_empty():
		push_error("PanelManual: nessuna pagina trovata (PagesRow...)")
		return

	btn_prev.pressed.connect(_on_prev_pressed)
	btn_next.pressed.connect(_on_next_pressed)
	btn_close.pressed.connect(_on_close_pressed)

	visible = false
	show_page(0)

func open_manual() -> void:
	visible = true
	show_page(0)

	# blocca movimento
	if player != null and player.has_method("set_can_move"):
		player.set_can_move(false)

func close_manual() -> void:
	visible = false

	# sblocca movimento
	if player != null and player.has_method("set_can_move"):
		player.set_can_move(true)

func show_page(i: int) -> void:
	if pages.is_empty():
		return

	if i < 0:
		i = 0
	if i > pages.size() - 1:
		i = pages.size() - 1
	page_index = i

	for p in pages:
		p.visible = false
	pages[page_index].visible = true

	label_page.text = "Pagina %d/%d" % [page_index + 1, pages.size()]
	btn_prev.disabled = (page_index == 0)
	btn_next.disabled = (page_index == pages.size() - 1)

func _on_prev_pressed() -> void:
	show_page(page_index - 1)

func _on_next_pressed() -> void:
	show_page(page_index + 1)

func _on_close_pressed() -> void:
	close_manual()

# Se hai collegato il ButtonManual a questa funzione, perfetto:
func _on_button_manual_pressed() -> void:
	open_manual()
