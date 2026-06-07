extends GutTest

const ConflictSectionScene := preload("res://scenes/ui/world/ConflictSection.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")
const WarScript := preload("res://scripts/engine/War.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func _instance(state: Node) -> ConflictSection:
	var s: ConflictSection = ConflictSectionScene.instantiate()
	add_child_autofree(s)
	await get_tree().process_frame
	s.bind_state(state)
	return s

func test_invisible_when_no_wars():
	var state := _make_state()
	add_child_autofree(state)
	var s := await _instance(state)
	assert_false(s.visible)

func test_visible_when_player_has_war():
	var state := _make_state()
	add_child_autofree(state)
	var war: War = WarScript.new()
	war.attacker_id = "islam"
	war.defender_id = "zoroastryzm"
	war.state = "BATTLING"
	state.active_wars.append(war)
	var s := await _instance(state)
	assert_true(s.visible)

func test_lists_only_player_wars():
	var state := _make_state()
	add_child_autofree(state)
	var w1: War = WarScript.new()
	w1.attacker_id = "islam"
	w1.defender_id = "zoroastryzm"
	w1.state = "BATTLING"
	var w2: War = WarScript.new()
	w2.attacker_id = "chr_zachodnie"
	w2.defender_id = "chr_wschodnie"
	w2.state = "BATTLING"
	state.active_wars.append(w1)
	state.active_wars.append(w2)
	var s := await _instance(state)
	assert_eq(s.get_node("%ListVBox").get_child_count(), 1)

func test_ended_wars_excluded():
	var state := _make_state()
	add_child_autofree(state)
	var war: War = WarScript.new()
	war.attacker_id = "islam"
	war.defender_id = "zoroastryzm"
	war.state = "ENDED"
	state.active_wars.append(war)
	var s := await _instance(state)
	assert_false(s.visible)

func test_peace_council_button_disabled_when_low_prestige():
	var state := _make_state()
	add_child_autofree(state)
	state.get_player_religion().prestige = 10
	var war: War = WarScript.new()
	war.attacker_id = "islam"
	war.defender_id = "zoroastryzm"
	war.state = "BATTLING"
	state.active_wars.append(war)
	var s := await _instance(state)
	var row: HBoxContainer = s.get_node("%ListVBox").get_child(0)
	var btn: Button = row.get_child(1)
	assert_true(btn.disabled)

func test_peace_council_button_enabled_when_prestige_sufficient():
	var state := _make_state()
	add_child_autofree(state)
	state.get_player_religion().prestige = 100
	var war: War = WarScript.new()
	war.attacker_id = "islam"
	war.defender_id = "zoroastryzm"
	war.state = "BATTLING"
	state.active_wars.append(war)
	var s := await _instance(state)
	var row: HBoxContainer = s.get_node("%ListVBox").get_child(0)
	var btn: Button = row.get_child(1)
	assert_false(btn.disabled)

func test_peace_council_emits_state_changed():
	var state := _make_state()
	add_child_autofree(state)
	state.get_player_religion().prestige = 100
	state.get_player_religion().war_weariness = 60.0
	var war: War = WarScript.new()
	war.attacker_id = "islam"
	war.defender_id = "zoroastryzm"
	war.state = "BATTLING"
	state.active_wars.append(war)
	var s := await _instance(state)
	watch_signals(s)
	var row: HBoxContainer = s.get_node("%ListVBox").get_child(0)
	var btn: Button = row.get_child(1)
	btn.emit_signal("pressed")
	assert_signal_emitted(s, "state_changed")
