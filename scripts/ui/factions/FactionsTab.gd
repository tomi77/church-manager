class_name FactionsTab
extends Control

const FactionCardScene := preload("res://scenes/ui/factions/FactionCard.tscn")

@onready var _cards_container: HBoxContainer = %CardsContainer

var state: Node = null

func bind_state(s: Node) -> void:
	state = s
	if is_inside_tree():
		refresh()

func _ready() -> void:
	if state != null:
		refresh()

func refresh() -> void:
	if not is_inside_tree():
		return
	# Niszczymy stare karty i odbudowujemy. Wzorzec analogiczny do DoctrineList
	# (Plan 10) — obsluguje 0/1/2/3/4+ frakcji bez zalozen, schizmy usuwajace
	# frakcje, oraz przyszle trait'y mogace tworzyc nowe frakcje (tribal_pluralism).
	for child in _cards_container.get_children():
		child.queue_free()
	if state == null:
		return
	var religion: Religion = state.get_player_religion() if state.has_method("get_player_religion") else null
	if religion == null:
		return
	var dominant: Faction = religion.dominant_faction()
	var sorted_factions: Array = _sort_factions_stable(religion.factions)
	for f: Faction in sorted_factions:
		var card: FactionCard = FactionCardScene.instantiate()
		_cards_container.add_child(card)
		card.bind_faction(f, religion, f == dominant)

func _sort_factions_stable(factions: Array) -> Array:
	# Stable sort: influence DESC, tie-break = original index ASC (zachowuje JSON order).
	# Godot Array.sort_custom nie gwarantuje stabilnosci, wiec sortujemy po tuple.
	var indexed: Array = []
	for i in range(factions.size()):
		indexed.append({"faction": factions[i], "original_index": i})
	indexed.sort_custom(func(a, b):
		if a.faction.influence != b.faction.influence:
			return a.faction.influence > b.faction.influence
		return a.original_index < b.original_index
	)
	var result: Array = []
	for entry: Dictionary in indexed:
		result.append(entry.faction)
	return result
