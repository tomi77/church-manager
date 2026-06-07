extends GutTest

const MapViewScene := preload("res://scenes/ui/map/MapView.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
    var gs: Node = GameStateScript.new()
    var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
    var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
    gs.initialize("islam", religions, graph)
    return gs

func _instance_view(state: Node) -> MapView:
    var mv: MapView = MapViewScene.instantiate()
    add_child_autofree(mv)
    await get_tree().process_frame
    mv.bind_state(state)
    return mv

func test_view_renders_12_province_nodes():
    var state := _make_state()
    add_child_autofree(state)
    var mv := await _instance_view(state)
    assert_eq(mv.get_node_count(), 12)

func test_view_renders_edges_between_valid_neighbors():
    var state := _make_state()
    add_child_autofree(state)
    var mv := await _instance_view(state)
    assert_true(mv.has_edge("mekka", "lewant"))
    assert_true(mv.has_edge("mekka", "arabia_polnocna"))
    assert_false(mv.has_edge("mekka", "jemen"), "Dangling neighbor must be skipped")

func test_view_emits_province_selected_on_node_click():
    var state := _make_state()
    add_child_autofree(state)
    var mv := await _instance_view(state)
    watch_signals(mv)
    var mekka_node: ProvinceNode = mv.get_node_for_id("mekka")
    mekka_node.get_node("%ClickArea").emit_signal("pressed")
    assert_signal_emitted_with_parameters(mv, "province_selected", ["mekka"])

func test_view_selection_clears_previous():
    var state := _make_state()
    add_child_autofree(state)
    var mv := await _instance_view(state)
    mv.set_selected_id("mekka")
    assert_true(mv.get_node_for_id("mekka").is_selected)
    mv.set_selected_id("lewant")
    assert_false(mv.get_node_for_id("mekka").is_selected)
    assert_true(mv.get_node_for_id("lewant").is_selected)
