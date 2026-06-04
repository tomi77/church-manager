extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")

var _tm: TurnManager
var _state: Node

func before_each() -> void:
    _state = GameStateScript.new()
    var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
    var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
    _state.initialize("islam", religions, graph)
    _tm = TurnManager.new()

func test_process_turn_advances_turn_counter() -> void:
    _tm.process_turn(_state)
    assert_eq(_state.current_turn, 2)

func test_passive_pressure_increases_on_adjacent_foreign_province() -> void:
    var graph: ProvinceGraph = _state.province_graph
    var mezopotamia := graph.get_province("mezopotamia")
    var initial_zoroastr := mezopotamia.get_pressure("zoroastryzm")
    _tm.process_turn(_state)
    assert_gt(mezopotamia.get_pressure("zoroastryzm"), initial_zoroastr)

func test_no_pressure_from_same_owner_neighbor() -> void:
    # persepolis (owner=zoroastryzm) sąsiaduje z persja (owner=zoroastryzm)
    # persepolis NIE powinna dostawać presji "zoroastryzm" — sąsiad to ta sama religia
    var graph: ProvinceGraph = _state.province_graph
    var persepolis := graph.get_province("persepolis")
    var initial_zor := persepolis.get_pressure("zoroastryzm")
    _tm.process_turn(_state)
    assert_eq(persepolis.get_pressure("zoroastryzm"), initial_zor)

func test_passive_pressure_foreign_religion_increases_on_border_province() -> void:
    var graph: ProvinceGraph = _state.province_graph
    var persja := graph.get_province("persja")
    var initial_islam := persja.get_pressure("islam")
    _tm.process_turn(_state)
    assert_gt(persja.get_pressure("islam"), initial_islam)

func test_holy_site_owner_gains_prestige() -> void:
    var islam: Religion = _state.get_religion("religie_arabskie")
    var initial_prestige := islam.prestige
    _tm.process_turn(_state)
    assert_gt(islam.prestige, initial_prestige)

func test_faction_tension_increases_when_axis_diverges() -> void:
    var islam: Religion = _state.get_religion("islam")
    var sufici := islam.get_faction("sufici")
    islam.axes["A"] = 90.0
    var initial_tension := sufici.tension
    _tm.process_turn(_state)
    assert_gt(sufici.tension, initial_tension)
