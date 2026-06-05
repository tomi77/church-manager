extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
    var gs: Node = GameStateScript.new()
    var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
    var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
    gs.initialize("islam", religions, graph)
    return gs

func test_religion_has_war_weariness_default_zero() -> void:
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    assert_almost_eq(rel.war_weariness, 0.0, 0.001)

func test_religion_has_parent_religion_id_default_empty() -> void:
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    assert_eq(rel.parent_religion_id, "")

func test_game_state_has_active_wars_empty() -> void:
    var gs := _make_state()
    assert_not_null(gs.active_wars)
    assert_eq(gs.active_wars.size(), 0)

func test_game_state_has_pending_defeat_events_empty() -> void:
    var gs := _make_state()
    assert_not_null(gs.pending_defeat_events)
    assert_eq(gs.pending_defeat_events.size(), 0)
