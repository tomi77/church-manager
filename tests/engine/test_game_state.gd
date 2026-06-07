extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func test_game_state_turn_starts_at_one() -> void:
	var gs := _make_state()
	assert_eq(gs.current_turn, 1)

func test_game_state_player_religion_set_correctly() -> void:
	var gs := _make_state()
	assert_eq(gs.player_religion_id, "islam")

func test_game_state_get_player_religion_returns_correct() -> void:
	var gs := _make_state()
	var r: Religion = gs.get_player_religion()
	assert_eq(r.id, "islam")

func test_game_state_get_religion_by_id() -> void:
	var gs := _make_state()
	var r: Religion = gs.get_religion("chr_zachodnie")
	assert_not_null(r)
	assert_eq(r.id, "chr_zachodnie")

func test_game_state_provinces_graph_accessible() -> void:
	var gs := _make_state()
	var graph: ProvinceGraph = gs.province_graph
	assert_not_null(graph)
	assert_gt(graph.province_count(), 0)

func test_game_state_all_religions_loaded() -> void:
	var gs := _make_state()
	var religions: Array = gs.all_religions()
	assert_eq(religions.size(), 12)
