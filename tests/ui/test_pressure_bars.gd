extends GutTest

const BarsScene := preload("res://scenes/ui/map/PressureBars.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
    var gs: Node = GameStateScript.new()
    var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
    var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
    gs.initialize("islam", religions, graph)
    return gs

func _instance(state: Node, province_id: String) -> PressureBars:
    var pb: PressureBars = BarsScene.instantiate()
    add_child_autofree(pb)
    await get_tree().process_frame
    pb.bind(state, province_id)
    return pb

func test_bars_render_one_row_per_pressure_entry():
    var state := _make_state()
    add_child_autofree(state)
    # lewant: chr_wschodnie=60, islam=15 → 2 rows
    var pb := await _instance(state, "lewant")
    assert_eq(pb.row_count(), 2)

func test_bars_skip_zero_pressure():
    var state := _make_state()
    add_child_autofree(state)
    # mekka: religie_arabskie=80 → 1 row (no other pressures)
    var pb := await _instance(state, "mekka")
    assert_eq(pb.row_count(), 1)

func test_bars_sort_descending_by_pressure():
    var state := _make_state()
    add_child_autofree(state)
    # lewant: chr_wschodnie=60 > islam=15 → row[0]=chr_wschodnie
    var pb := await _instance(state, "lewant")
    var first := pb.get_row(0)
    assert_eq(first.religion_id, "chr_wschodnie")
    var second := pb.get_row(1)
    assert_eq(second.religion_id, "islam")

func test_bars_render_pressure_value():
    var state := _make_state()
    add_child_autofree(state)
    var pb := await _instance(state, "lewant")
    var first := pb.get_row(0)
    assert_eq(first.get_node("%ValueLabel").text, "60")

func test_bars_zero_rows_for_unknown_province():
    var state := _make_state()
    add_child_autofree(state)
    var pb := await _instance(state, "nonexistent_province_id")
    assert_eq(pb.row_count(), 0)
