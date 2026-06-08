extends GutTest

const RelationListScene := preload("res://scenes/ui/world/RelationList.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")
const CoalitionScript := preload("res://scripts/engine/Coalition.gd")
const WarScript := preload("res://scripts/engine/War.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func _instance_list(state: Node) -> RelationList:
	var l: RelationList = RelationListScene.instantiate()
	add_child_autofree(l)
	await get_tree().process_frame
	l.bind_state(state)
	return l

func test_list_excludes_player():
	var state := _make_state()
	add_child_autofree(state)
	var l := await _instance_list(state)
	var ids: Array = []
	for item in l._items.values():
		ids.append(item.religion.id)
	assert_does_not_have(ids, "islam")

func test_list_includes_all_other_religions():
	var state := _make_state()
	add_child_autofree(state)
	var l := await _instance_list(state)
	var expected_count: int = state.all_religions().size() - 1
	assert_eq(l._items.size(), expected_count)

func test_click_item_emits_religion_selected():
	var state := _make_state()
	add_child_autofree(state)
	var l := await _instance_list(state)
	watch_signals(l)
	var first_id: String = l._items.keys()[0]
	l._items[first_id]._on_pressed()
	assert_signal_emitted_with_parameters(l, "religion_selected", [first_id])

func test_set_selected_updates_only_one_item():
	var state := _make_state()
	add_child_autofree(state)
	var l := await _instance_list(state)
	var target_id: String = l._items.keys()[2]
	l.set_selected(target_id)
	for id: String in l._items:
		assert_eq(l._items[id].is_selected, id == target_id)

func test_war_marker():
	var state := _make_state()
	add_child_autofree(state)
	var war: War = WarScript.new()
	war.attacker_id = "islam"
	war.defender_id = "zoroastrianism"
	war.state = "BATTLING"
	state.active_wars.append(war)
	var l := await _instance_list(state)
	assert_eq(l._items["zoroastrianism"].marker, "⚔")

func test_coalition_marker():
	var state := _make_state()
	add_child_autofree(state)
	var c: Coalition = CoalitionScript.new()
	c.target_id = "islam"
	c.members = ["western_christianity"]
	state.active_coalitions.append(c)
	var l := await _instance_list(state)
	assert_eq(l._items["western_christianity"].marker, "●")

func test_vassal_marker():
	var state := _make_state()
	add_child_autofree(state)
	state.get_religion("coptic_christianity").suzerain_id = "islam"
	var l := await _instance_list(state)
	assert_eq(l._items["coptic_christianity"].marker, "↑👑")

func test_grievance_marker():
	var state := _make_state()
	add_child_autofree(state)
	var player: Religion = state.get_player_religion()
	player.interdict_grievance_from_id = "western_christianity"
	player.interdict_grievance_until = state.current_turn + 5
	var l := await _instance_list(state)
	assert_eq(l._items["western_christianity"].marker, "⚠")

func test_war_sorted_first():
	var state := _make_state()
	add_child_autofree(state)
	var war: War = WarScript.new()
	war.attacker_id = "islam"
	war.defender_id = "zoroastrianism"
	war.state = "BATTLING"
	state.active_wars.append(war)
	var l := await _instance_list(state)
	var first_child: RelationListItem = l.get_node("%ItemsVBox").get_child(0)
	assert_eq(first_child.religion.id, "zoroastrianism")
