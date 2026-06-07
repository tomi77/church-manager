class_name ConflictSection
extends VBoxContainer

signal state_changed

var state: Node = null

@onready var _header_label: Label = %HeaderLabel
@onready var _list_vbox: VBoxContainer = %ListVBox

func bind_state(s: Node) -> void:
	state = s
	refresh()

func refresh() -> void:
	if state == null:
		return
	for child in _list_vbox.get_children():
		child.queue_free()

	var player_id: String = state.player_religion_id
	var wars := _player_wars(player_id)

	visible = wars.size() > 0
	_header_label.text = "⚔ Aktywne konflikty (%d)" % wars.size()

	for war: War in wars:
		var row := _build_row(war, player_id)
		_list_vbox.add_child(row)

func _player_wars(player_id: String) -> Array[War]:
	var wars: Array[War] = []
	for war: War in state.active_wars:
		if war.state == "ENDED":
			continue
		if war.attacker_id == player_id or war.defender_id == player_id:
			wars.append(war)
	return wars

func _build_row(war: War, player_id: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var other_id: String = war.defender_id if war.attacker_id == player_id else war.attacker_id
	var other: Religion = state.get_religion(other_id)
	var attacker_text: String = "atak gracza" if war.attacker_id == player_id else "atak NPC"

	var label := Label.new()
	label.text = "🔥 %s · tura %d · %s · CB: %s" % [
		other.display_name if other != null else other_id,
		war.turns_in_state,
		attacker_text,
		war.casus_belli,
	]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var btn := Button.new()
	btn.text = "Sobór Pokojowy (25⚑)"
	var player: Religion = state.get_player_religion()
	btn.disabled = player == null or player.prestige < DiplomacyManager.PEACE_COUNCIL_PRESTIGE_COST
	btn.pressed.connect(_on_peace_council_pressed.bind(war))
	row.add_child(btn)

	return row

func _on_peace_council_pressed(_war: War) -> void:
	var dm := DiplomacyManager.new()
	var ok := dm.peace_council(state, state.player_religion_id)
	if ok:
		emit_signal("state_changed")
	refresh()
