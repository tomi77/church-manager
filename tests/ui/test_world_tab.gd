extends GutTest

const WorldTabScene := preload("res://scenes/ui/world/WorldTab.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func _instance(state: Node) -> WorldTab:
	var t: WorldTab = WorldTabScene.instantiate()
	add_child_autofree(t)
	await get_tree().process_frame
	t.bind_state(state)
	return t

func test_auto_selects_first_npc_religion():
	var state := _make_state()
	add_child_autofree(state)
	var t := await _instance(state)
	assert_ne(t.get_node("%ActionPanel").target_id, "")
	assert_ne(t.get_node("%ActionPanel").target_id, "islam")

func test_list_selection_updates_action_panel():
	var state := _make_state()
	add_child_autofree(state)
	var t := await _instance(state)
	t._on_religion_selected("western_christianity")
	assert_eq(t.get_node("%ActionPanel").target_id, "western_christianity")

func test_action_state_change_emits_state_changed_up():
	var state := _make_state()
	add_child_autofree(state)
	state.get_player_religion().prestige = 100
	var dm := DiplomacyManager.new()
	var rel := dm.get_or_create_relation(state, "islam", "western_christianity")
	rel.theological_trust = 70.0
	var t := await _instance(state)
	t._on_religion_selected("western_christianity")
	watch_signals(t)
	t.get_node("%ActionPanel").get_node("%AllianceButton").emit_signal("pressed")
	assert_signal_emitted(t, "state_changed")
