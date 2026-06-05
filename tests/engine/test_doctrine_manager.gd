extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")

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

const DoctrineManagerScript := preload("res://scripts/engine/DoctrineManager.gd")

func test_doctrine_manager_axis_A_high_unlocks_kanon_doktryny() -> void:
    var dm := DoctrineManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    rel.axes["A"] = 76.0
    var actions := dm.available_threshold_actions(rel)
    assert_true(actions.has("kanon_doktryny"), "A>=75 powinno odblokować kanon_doktryny")

func test_doctrine_manager_axis_A_low_unlocks_objawienie() -> void:
    var dm := DoctrineManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    rel.axes["A"] = 24.0
    var actions := dm.available_threshold_actions(rel)
    assert_true(actions.has("objawienie"), "A<=25 powinno odblokować objawienie")

func test_doctrine_manager_axis_middle_no_threshold_actions() -> void:
    var dm := DoctrineManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    rel.axes["A"] = 50.0
    rel.axes["B"] = 50.0
    rel.axes["C"] = 50.0
    rel.axes["D"] = 50.0
    var actions := dm.available_threshold_actions(rel)
    assert_eq(actions.size(), 0)

func test_doctrine_manager_axis_C_high_unlocks_ekumenizm_and_obrzad() -> void:
    var dm := DoctrineManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    rel.axes["C"] = 80.0
    var actions := dm.available_threshold_actions(rel)
    assert_true(actions.has("ekumenizm"))
    assert_true(actions.has("obrzad_fuzji"))

func test_doctrine_manager_axis_C_low_unlocks_inkwizycja_and_klatwa() -> void:
    var dm := DoctrineManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    rel.axes["C"] = 20.0
    var actions := dm.available_threshold_actions(rel)
    assert_true(actions.has("inkwizycja"))
    assert_true(actions.has("klatwa"))
