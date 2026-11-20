class_name PerkSelect
extends CanvasLayer
## "CHOOSE A PERK" screen. Shows a hand of cards and reports the choice upward. Works with mouse, keyboard,
## gamepad and touch. Runs while the tree is paused.

signal perk_chosen(index: int)
signal redraw_requested
signal skipped

## One entry per card: {category, title, rare, lines, flavour}.
const CARD_KEYS: Array[String] = ["category", "title", "rare", "lines", "flavour"]

@export var card_scene: PackedScene

@onready var _cards_box: HBoxContainer = %Cards
@onready var _redraw_button: Button = %RedrawButton
@onready var _skip_button: Button = %SkipButton
@onready var _header: Label = %Header

var _cards: Array[PerkCard] = []
var _selected: int = 0
var _redraws_left: int = 0
## Ignore input briefly after opening so a held fire button does not pick a card.
var _input_lock: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_redraw_button.pressed.connect(_request_redraw)
	_skip_button.pressed.connect(_skip)


func is_open() -> bool:
	return visible


func open(cards: Array[Dictionary], redraws_left: int, pending: int) -> void:
	for c: PerkCard in _cards:
		c.queue_free()
	_cards.clear()
	for i: int in cards.size():
		var data: Dictionary = cards[i]
		var card: PerkCard = card_scene.instantiate() as PerkCard
		_cards_box.add_child(card)
		card.show_perk(data["category"], data["title"], data["rare"], data["lines"], data["flavour"])
		card.hovered.connect(_select.bind(i))
		card.clicked.connect(_on_card_clicked.bind(i))
		_cards.append(card)
	_redraws_left = redraws_left
	_redraw_button.text = "REDRAW (%d)  [R / Y]" % redraws_left
	_redraw_button.disabled = redraws_left <= 0
	_header.text = "CHOOSE A PERK" if pending <= 1 else "CHOOSE A PERK  (+%d more)" % (pending - 1)
	visible = true
	_input_lock = 0.2
	_select(clampi(_selected, 0, maxi(0, _cards.size() - 1)))


func close() -> void:
	visible = false


func selected_index() -> int:
	return _selected


func card_count() -> int:
	return _cards.size()


func _process(delta: float) -> void:
	_input_lock = maxf(0.0, _input_lock - delta)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _input_lock > 0.0:
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		_select(wrapi(_selected - 1, 0, _cards.size()))
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		_select(wrapi(_selected + 1, 0, _cards.size()))
	elif event.is_action_pressed("ui_accept"):
		_confirm()
	elif event.is_action_pressed("perk_redraw"):
		_request_redraw()
	elif event.is_action_pressed("perk_skip") or event.is_action_pressed("ui_cancel"):
		_skip()
	else:
		return
	get_viewport().set_input_as_handled()


func _select(index: int) -> void:
	if _cards.is_empty():
		return
	_selected = index
	for i: int in _cards.size():
		_cards[i].selected = i == index


func _on_card_clicked(index: int) -> void:
	if _input_lock > 0.0:
		return
	_select(index)
	_confirm()


func _confirm() -> void:
	if _cards.is_empty():
		_skip()
		return
	perk_chosen.emit(_selected)


func _request_redraw() -> void:
	if _redraws_left > 0:
		redraw_requested.emit()


func _skip() -> void:
	skipped.emit()
