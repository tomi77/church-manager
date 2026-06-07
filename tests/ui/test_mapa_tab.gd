extends GutTest

const MapaTabScene := preload("res://scenes/ui/map/MapaTab.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func _instance(state: Node) -> MapaTab:
	var t: MapaTab = MapaTabScene.instantiate()
	add_child_autofree(t)
	await get_tree().process_frame
	t.bind_state(state)
	return t

func test_tab_starts_with_no_selection():
	var state := _make_state()
	add_child_autofree(state)
	var t := await _instance(state)
	var panel := t.get_node("%DetailPanel")
	assert_false(panel.visible)

func test_clicking_node_shows_panel():
	var state := _make_state()
	add_child_autofree(state)
	var t := await _instance(state)
	var map_view: MapView = t.get_node("%MapView")
	var node: ProvinceNode = map_view.get_node_for_id("lewant")
	node.get_node("%ClickArea").emit_signal("pressed")
	var panel: ProvinceDetailPanel = t.get_node("%DetailPanel")
	assert_true(panel.visible)
	assert_eq(panel.current_province_id, "lewant")

func test_navigate_signal_propagates():
	var state := _make_state()
	add_child_autofree(state)
	var t := await _instance(state)
	var map_view: MapView = t.get_node("%MapView")
	var node: ProvinceNode = map_view.get_node_for_id("lewant")
	node.get_node("%ClickArea").emit_signal("pressed")
	watch_signals(t)
	var panel: ProvinceDetailPanel = t.get_node("%DetailPanel")
	var actions := panel.get_node("%Actions")
	actions.emit_signal("navigate_to_diplomacy", "chr_wschodnie")
	assert_signal_emitted_with_parameters(t, "navigate_to_diplomacy", ["chr_wschodnie"])
