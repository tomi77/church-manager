extends GutTest

const FaithTabScene := preload("res://scenes/ui/faith/FaithTab.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func _instance_tab(state: Node) -> FaithTab:
	var t: FaithTab = FaithTabScene.instantiate()
	add_child_autofree(t)
	await get_tree().process_frame
	t.bind_state(state)
	return t

func test_tab_renders_without_state():
	var t: FaithTab = FaithTabScene.instantiate()
	add_child_autofree(t)
	await get_tree().process_frame
	assert_not_null(t)

func test_tab_renders_three_child_components():
	var state := _make_state()
	add_child_autofree(state)
	var t := await _instance_tab(state)
	assert_not_null(t.get_node("%AxisRadar"))
	assert_not_null(t.get_node("%TraitCard"))
	assert_not_null(t.get_node("%DoctrineList"))

func test_tab_propagates_state_to_children():
	var state := _make_state()
	add_child_autofree(state)
	var t := await _instance_tab(state)
	var radar: AxisRadar = t.get_node("%AxisRadar")
	var card: TraitCard = t.get_node("%TraitCard")
	var list: DoctrineList = t.get_node("%DoctrineList")
	assert_eq(radar.state, state)
	assert_eq(card.state, state)
	assert_eq(list.state, state)

func test_tab_refresh_propagates_to_children():
	var state := _make_state()
	add_child_autofree(state)
	var t := await _instance_tab(state)
	# Mutuj os i sprawdz, ze refresh dociera
	state.get_player_religion().axes["A"] = 100.0
	t.refresh()
	var radar: AxisRadar = t.get_node("%AxisRadar")
	assert_eq(radar.get_node("%ValueLabelA").text, "A: 100")

func test_tab_refresh_no_op_when_state_null():
	var t: FaithTab = FaithTabScene.instantiate()
	add_child_autofree(t)
	await get_tree().process_frame
	t.refresh()  # Bez crasha
	assert_null(t.state)
