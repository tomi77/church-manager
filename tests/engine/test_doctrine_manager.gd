extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")
const Idea := preload("res://scripts/engine/Idea.gd")

func _make_state() -> Node:
    var gs: Node = GameStateScript.new()
    var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
    var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
    gs.initialize("islam", religions, graph)
    return gs

func test_game_state_has_pending_ideas_array() -> void:
    var gs := _make_state()
    assert_not_null(gs.pending_ideas)
    assert_eq(gs.pending_ideas.size(), 0)

func test_game_state_has_scholar_missions_array() -> void:
    var gs := _make_state()
    assert_not_null(gs.scholar_missions)
    assert_eq(gs.scholar_missions.size(), 0)

func test_idea_has_correct_fields() -> void:
    var idea := Idea.new()
    idea.from_religion_id = "islam"
    idea.axis = "A"
    idea.delta = 5.0
    idea.description = "Nowa interpretacja"
    assert_eq(idea.from_religion_id, "islam")
    assert_eq(idea.axis, "A")
    assert_eq(idea.delta, 5.0)
    assert_eq(idea.description, "Nowa interpretacja")
