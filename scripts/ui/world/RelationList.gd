class_name RelationList
extends ScrollContainer

signal religion_selected(id: String)

const RelationListItemScene := preload("res://scenes/ui/world/RelationListItem.tscn")

var state: Node = null
var _selected_id: String = ""
var _items: Dictionary = {}

@onready var _vbox: VBoxContainer = %ItemsVBox

func bind_state(s: Node) -> void:
	state = s
	refresh()

func set_selected(id: String) -> void:
	_selected_id = id
	for item_id: String in _items:
		_items[item_id].set_selected(item_id == id)

func refresh() -> void:
	if state == null:
		return
	for child in _vbox.get_children():
		child.queue_free()
	_items.clear()

	var player_id: String = state.player_religion_id
	var others: Array[Religion] = []
	for r: Religion in state.all_religions():
		if r.id != player_id:
			others.append(r)

	others.sort_custom(func(a: Religion, b: Religion) -> bool:
		return _sort_key(a) < _sort_key(b))

	for r: Religion in others:
		var rel := _get_relation(r.id)
		var marker := _compute_marker(r)
		var item: RelationListItem = RelationListItemScene.instantiate()
		_vbox.add_child(item)
		item.set_data(rel, r, marker)
		item.set_selected(r.id == _selected_id)
		item.pressed.connect(_on_item_pressed)
		_items[r.id] = item

func _get_relation(other_id: String) -> RelationState:
	var dm := DiplomacyManager.new()
	return dm.get_or_create_relation(state, state.player_religion_id, other_id)

func _sort_key(r: Religion) -> String:
	var player_id: String = state.player_religion_id
	# 0=war, 1=coalition_against, 2=ally, 3=our_vassal, 4=our_patron, 5=rest alpha
	for war: War in state.active_wars:
		if war.state == "ENDED":
			continue
		if (war.attacker_id == player_id and war.defender_id == r.id) or \
		   (war.attacker_id == r.id and war.defender_id == player_id):
			return "0_" + r.id
	for c: Coalition in state.active_coalitions:
		if c.target_id == player_id and r.id in c.members:
			return "1_" + r.id
	var rel := _get_relation(r.id)
	if rel != null and rel.alliance_active:
		return "2_" + r.id
	if r.suzerain_id == player_id:
		return "3_" + r.id
	var player: Religion = state.get_player_religion()
	if player != null and player.suzerain_id == r.id:
		return "4_" + r.id
	return "5_" + r.display_name

func _compute_marker(r: Religion) -> String:
	var player_id: String = state.player_religion_id
	var player: Religion = state.get_player_religion()
	for war: War in state.active_wars:
		if war.state == "ENDED":
			continue
		if (war.attacker_id == player_id and war.defender_id == r.id) or \
		   (war.attacker_id == r.id and war.defender_id == player_id):
			return "⚔"
	for c: Coalition in state.active_coalitions:
		if c.target_id == player_id and r.id in c.members:
			return "●"
	var rel := _get_relation(r.id)
	if rel != null and rel.alliance_active:
		return "🤝"
	if r.suzerain_id == player_id:
		return "↑👑"
	if player != null and player.suzerain_id == r.id:
		return "⛰"
	if player != null and player.interdict_grievance_from_id == r.id and player.interdict_grievance_until > state.current_turn:
		return "⚠"
	return ""

func _on_item_pressed(religion_id: String) -> void:
	set_selected(religion_id)
	emit_signal("religion_selected", religion_id)
