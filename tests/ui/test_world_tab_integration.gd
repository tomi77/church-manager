extends GutTest

const MainShellScene := preload("res://scenes/ui/MainShell.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")
const WarScript := preload("res://scripts/engine/War.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func _shell(state: Node) -> MainShell:
	var s: MainShell = MainShellScene.instantiate()
	add_child_autofree(s)
	await get_tree().process_frame
	s.bind_state(state)
	return s

func test_full_loop_alliance():
	var state := _make_state()
	add_child_autofree(state)
	state.get_player_religion().prestige = 100
	var dm := DiplomacyManager.new()
	var rel := dm.get_or_create_relation(state, "islam", "western_christianity")
	rel.theological_trust = 70.0

	var shell := await _shell(state)
	var world: WorldTab = shell.get_node("%SwiatTab")
	world._on_religion_selected("western_christianity")

	var panel: ActionPanel = world.get_node("%ActionPanel")
	panel.get_node("%AllianceButton").emit_signal("pressed")

	# Sojusz aktywny
	var rel_after := dm.get_or_create_relation(state, "islam", "western_christianity")
	assert_true(rel_after.alliance_active)
	# Prestiż spadł
	assert_eq(state.get_player_religion().prestige, 80)
	# Header zaktualizowany
	assert_eq(shell.get_node("%Header").get_node("%PrestigeLabel").text, "⚑ 80")
	# Marker w liście (po refreshu)
	var list: RelationList = world.get_node("%RelationList")
	assert_eq(list._items["western_christianity"].marker, "🤝")

func test_full_loop_rewanz():
	var state := _make_state()
	add_child_autofree(state)
	var player: Religion = state.get_player_religion()
	player.interdict_grievance_from_id = "western_christianity"
	player.interdict_grievance_until = state.current_turn + 5
	player.axes["C"] = 20.0

	var shell := await _shell(state)
	var world: WorldTab = shell.get_node("%SwiatTab")
	world._on_religion_selected("western_christianity")

	var panel: ActionPanel = world.get_node("%ActionPanel")
	var rewanz_btn: Button = panel.get_node("%RewanzButton")
	assert_true(rewanz_btn.visible)

	rewanz_btn.emit_signal("pressed")
	panel.get_node("%ConfirmDialog").emit_signal("confirmed")

	# Wojna utworzona
	var has_war: bool = false
	for war: War in state.active_wars:
		if war.attacker_id == "islam" and war.defender_id == "western_christianity" and war.casus_belli == "rewanz":
			has_war = true
	assert_true(has_war)
	# Grievance wyzerowany
	assert_eq(player.interdict_grievance_from_id, "")
	# Marker w liście zmienił się na ⚔
	var list: RelationList = world.get_node("%RelationList")
	assert_eq(list._items["western_christianity"].marker, "⚔")

func test_full_loop_peace_council_ends_war():
	var state := _make_state()
	add_child_autofree(state)
	var player: Religion = state.get_player_religion()
	player.prestige = 100
	player.war_weariness = 60.0
	var war: War = WarScript.new()
	war.attacker_id = "islam"
	war.defender_id = "zoroastrianism"
	war.state = "BATTLING"
	war.casus_belli = "stlumienie_herezji"
	state.active_wars.append(war)

	var shell := await _shell(state)
	var world: WorldTab = shell.get_node("%SwiatTab")
	var conflict: ConflictSection = world.get_node("%ConflictSection")
	assert_true(conflict.visible)

	var row: HBoxContainer = conflict.get_node("%ListVBox").get_child(0)
	var peace_btn: Button = row.get_child(1)
	peace_btn.emit_signal("pressed")

	# Weariness zmalał per spec 04 sek.4
	assert_lt(state.get_player_religion().war_weariness, 60.0)

func test_full_loop_end_turn_advances():
	var state := _make_state()
	add_child_autofree(state)
	var initial_turn: int = state.current_turn

	var shell := await _shell(state)
	shell.get_node("%Header").get_node("%EndTurnButton").emit_signal("pressed")

	assert_eq(state.current_turn, initial_turn + 1)
	assert_string_contains(shell.get_node("%Header").get_node("%TurnLabel").text, str(state.current_turn))
