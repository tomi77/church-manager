class_name WiaraTab
extends Control

var state: Node = null

@onready var _axis_radar: AxisRadar = %AxisRadar
@onready var _trait_card: TraitCard = %TraitCard
@onready var _doctrine_list: DoctrineList = %DoctrineList

func bind_state(s: Node) -> void:
	state = s
	if not is_inside_tree():
		return
	_axis_radar.bind_state(s)
	_trait_card.bind_state(s)
	_doctrine_list.bind_state(s)

func _ready() -> void:
	if state != null:
		_axis_radar.bind_state(state)
		_trait_card.bind_state(state)
		_doctrine_list.bind_state(state)

func refresh() -> void:
	if state == null:
		return
	_axis_radar.refresh()
	_trait_card.refresh()
	_doctrine_list.refresh()
