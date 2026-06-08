extends GutTest

const TabBarScene := preload("res://scenes/ui/TabBar.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")
const CoalitionScript := preload("res://scripts/engine/Coalition.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func _instance_tab_bar(state: Node) -> UITabBar:
	var tb: UITabBar = TabBarScene.instantiate()
	add_child_autofree(tb)
	await get_tree().process_frame
	tb.bind_state(state)
	return tb

func test_default_current_tab_is_swiat():
	var state := _make_state()
	add_child_autofree(state)
	var tb := await _instance_tab_bar(state)
	assert_eq(tb.current_tab, "world")

func test_clicking_mapa_changes_current_tab():
	var state := _make_state()
	add_child_autofree(state)
	var tb := await _instance_tab_bar(state)
	watch_signals(tb)
	tb.get_node("%MapButton").emit_signal("pressed")
	assert_eq(tb.current_tab, "map")
	assert_signal_emitted_with_parameters(tb, "tab_changed", ["map"])

func test_active_tab_has_full_modulate():
	var state := _make_state()
	add_child_autofree(state)
	var tb := await _instance_tab_bar(state)
	tb.set_current_tab("world")
	assert_almost_eq(tb.get_node("%WorldButton").modulate.r, 1.0, 0.01)
	assert_lt(tb.get_node("%MapButton").modulate.r, 1.0)

func test_swiat_alert_dot_when_coalition_against_player():
	var state := _make_state()
	add_child_autofree(state)
	var c: Coalition = CoalitionScript.new()
	c.target_id = state.player_religion_id
	c.members = ["western_christianity"]
	state.active_coalitions.append(c)
	var tb := await _instance_tab_bar(state)
	assert_true(tb.get_node("%WorldDot").visible)

func test_swiat_alert_dot_when_grievance_active():
	var state := _make_state()
	add_child_autofree(state)
	var player: Religion = state.get_player_religion()
	player.interdict_grievance_from_id = "western_christianity"
	player.interdict_grievance_until = state.current_turn + 5
	var tb := await _instance_tab_bar(state)
	assert_true(tb.get_node("%WorldDot").visible)

func test_frakcje_alert_dot_when_faction_tension_over_80():
	var state := _make_state()
	add_child_autofree(state)
	var player: Religion = state.get_player_religion()
	player.factions[0].tension = 85.0
	player.factions[0].influence = 50.0
	var tb := await _instance_tab_bar(state)
	assert_true(tb.get_node("%FactionsDot").visible)

func test_no_alert_dots_when_calm_state():
	var state := _make_state()
	add_child_autofree(state)
	var tb := await _instance_tab_bar(state)
	assert_false(tb.get_node("%WorldDot").visible)
	assert_false(tb.get_node("%FactionsDot").visible)
	assert_false(tb.get_node("%MapDot").visible)
	assert_false(tb.get_node("%FaithDot").visible)
