class_name TraitCard
extends PanelContainer

var state: Node = null

@onready var _name_label: Label = %NameLabel
@onready var _description_label: Label = %DescriptionLabel

func bind_state(s: Node) -> void:
	state = s
	if not is_inside_tree():
		return
	refresh()

func _ready() -> void:
	if state != null:
		refresh()

func refresh() -> void:
	if state == null:
		return
	var religion: Religion = state.get_player_religion()
	if religion == null:
		return
	var info: Dictionary = UIConstants.TRAIT_INFO.get(religion.trait_id, {})
	_name_label.text = info.get("name", "(nieznany trait)")
	_description_label.text = info.get("description", "")
