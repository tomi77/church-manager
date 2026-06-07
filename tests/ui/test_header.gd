extends GutTest

const HeaderScene := preload("res://scenes/ui/Header.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func _instance_header(state: Node) -> Header:
	var h: Header = HeaderScene.instantiate()
	add_child_autofree(h)
	await get_tree().process_frame
	h.bind_state(state)
	return h

func test_header_renders_player_name():
	var state := _make_state()
	add_child_autofree(state)
	var h := await _instance_header(state)
	var player: Religion = state.get_player_religion()
	assert_eq(h.get_node("%NameLabel").text, player.display_name)
	assert_eq(h.get_node("%IconLabel").text, player.icon)

func test_header_renders_turn():
	var state := _make_state()
	add_child_autofree(state)
	state.current_turn = 14
	var h := await _instance_header(state)
	assert_eq(h.get_node("%TurnLabel").text, "Tura 14")

func test_header_renders_prestige():
	var state := _make_state()
	add_child_autofree(state)
	state.get_player_religion().prestige = 285
	var h := await _instance_header(state)
	assert_eq(h.get_node("%PrestigeLabel").text, "⚑ 285")

func test_header_wars_label_red_when_active():
	var state := _make_state()
	add_child_autofree(state)
	var war := War.new()
	war.attacker_id = "islam"
	war.defender_id = "zoroastryzm"
	war.state = "BATTLING"
	state.active_wars.append(war)
	var h := await _instance_header(state)
	assert_eq(h.get_node("%WarsLabel").text, "⚔ 1 wojna")
	assert_almost_eq(h.get_node("%WarsLabel").modulate.r, 1.0, 0.01)

func test_header_wars_label_gray_when_no_active():
	var state := _make_state()
	add_child_autofree(state)
	var h := await _instance_header(state)
	assert_eq(h.get_node("%WarsLabel").text, "⚔ brak wojen")
	assert_lt(h.get_node("%WarsLabel").modulate.r, 1.0)

func test_header_faction_alert_visible_when_tension_over_80():
	var state := _make_state()
	add_child_autofree(state)
	var player: Religion = state.get_player_religion()
	player.factions[0].tension = 85.0
	player.factions[0].influence = 50.0	 # dominant
	var h := await _instance_header(state)
	assert_true(h.get_node("%FactionAlertLabel").visible)

func test_header_faction_alert_hidden_when_low_tension():
	var state := _make_state()
	add_child_autofree(state)
	var h := await _instance_header(state)
	assert_false(h.get_node("%FactionAlertLabel").visible)

func test_header_end_turn_button_emits_signal():
	var state := _make_state()
	add_child_autofree(state)
	var h := await _instance_header(state)
	watch_signals(h)
	h.get_node("%EndTurnButton").emit_signal("pressed")
	assert_signal_emitted(h, "turn_ended")

func test_header_end_turn_advances_turn():
	var state := _make_state()
	add_child_autofree(state)
	var initial_turn: int = state.current_turn
	var h := await _instance_header(state)
	h.get_node("%EndTurnButton").emit_signal("pressed")
	assert_eq(state.current_turn, initial_turn + 1)
