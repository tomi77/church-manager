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
	var r: Religion = gs.get_religion("western_christianity")
	assert_not_null(r)
	assert_eq(r.id, "western_christianity")

func test_game_state_provinces_graph_accessible() -> void:
	var gs := _make_state()
	var graph: ProvinceGraph = gs.province_graph
	assert_not_null(graph)
	assert_gt(graph.province_count(), 0)

func test_game_state_all_religions_loaded() -> void:
	var gs := _make_state()
	var religions: Array = gs.all_religions()
	assert_eq(religions.size(), 12)

func _fresh_state() -> Node:
	# Helper: GameState bez initialize, gołe pola domyślne.
	return GameStateScript.new()

func test_game_outcome_defaults_to_null():
	var gs := _fresh_state()
	assert_null(gs.game_outcome)

func test_victory_progress_defaults_to_empty_dict():
	var gs := _fresh_state()
	assert_eq(gs.victory_progress.size(), 0)

func test_defeat_progress_defaults_to_empty_dict():
	var gs := _fresh_state()
	assert_eq(gs.defeat_progress.size(), 0)

func test_is_game_over_false_when_outcome_null():
	var gs := _fresh_state()
	assert_false(gs.is_game_over())

func test_is_game_over_true_when_outcome_set():
	var gs := _fresh_state()
	gs.game_outcome = GameOutcome.new()
	assert_true(gs.is_game_over())

func test_reset_clears_current_turn_to_one():
	var gs := _fresh_state()
	gs.current_turn = 87
	gs.reset()
	assert_eq(gs.current_turn, 1)

func test_reset_clears_player_religion_id():
	var gs := _fresh_state()
	gs.player_religion_id = "islam"
	gs.reset()
	assert_eq(gs.player_religion_id, "")

func test_reset_clears_province_graph():
	var gs := _fresh_state()
	gs.province_graph = ProvinceGraph.new()
	gs.reset()
	assert_null(gs.province_graph)

func test_reset_clears_religions():
	var gs := _fresh_state()
	var r := Religion.new()
	r.id = "islam"
	gs.add_religion(r)
	gs.reset()
	assert_eq(gs.all_religions().size(), 0)

func test_reset_clears_pending_ideas():
	var gs := _fresh_state()
	gs.pending_ideas.append(Idea.new())
	gs.reset()
	assert_eq(gs.pending_ideas.size(), 0)

func test_reset_clears_scholar_missions():
	var gs := _fresh_state()
	gs.scholar_missions.append({"x": 1})
	gs.reset()
	assert_eq(gs.scholar_missions.size(), 0)

func test_reset_clears_active_wars():
	var gs := _fresh_state()
	gs.active_wars.append(War.new())
	gs.reset()
	assert_eq(gs.active_wars.size(), 0)

func test_reset_clears_pending_defeat_events():
	var gs := _fresh_state()
	gs.pending_defeat_events.append(DefeatEvent.new())
	gs.reset()
	assert_eq(gs.pending_defeat_events.size(), 0)

func test_reset_clears_relations():
	var gs := _fresh_state()
	gs.relations.append(RelationState.new())
	gs.reset()
	assert_eq(gs.relations.size(), 0)

func test_reset_clears_active_coalitions():
	var gs := _fresh_state()
	gs.active_coalitions.append(Coalition.new())
	gs.reset()
	assert_eq(gs.active_coalitions.size(), 0)

func test_reset_clears_missionary_missions():
	var gs := _fresh_state()
	gs.missionary_missions.append(MissionaryMission.new())
	gs.reset()
	assert_eq(gs.missionary_missions.size(), 0)

func test_reset_clears_game_outcome():
	var gs := _fresh_state()
	gs.game_outcome = GameOutcome.new()
	gs.reset()
	assert_null(gs.game_outcome)

func test_reset_clears_victory_progress():
	var gs := _fresh_state()
	gs.victory_progress["islam"] = {"domination_turns": 5}
	gs.reset()
	assert_eq(gs.victory_progress.size(), 0)

func test_reset_clears_defeat_progress():
	var gs := _fresh_state()
	gs.defeat_progress["manichaeism"] = {"zero_provinces_turns": 3}
	gs.reset()
	assert_eq(gs.defeat_progress.size(), 0)

func test_initialize_snapshots_starting_provinces_for_arabian_paganism():
	# arabian_paganism kontroluje mekka na mapie historycznej (provinces_historical.json)
	var gs := _make_state()
	var r: Religion = gs.get_religion("arabian_paganism")
	assert_true(r.starting_provinces_snapshot.has("mekka"),
		"arabian_paganism powinno mieć mekka w snapshot, miało: " + str(r.starting_provinces_snapshot))

func test_initialize_snapshots_starting_provinces_for_eastern_christianity():
	# eastern_christianity kontroluje jerozolima i konstantynopol
	var gs := _make_state()
	var r: Religion = gs.get_religion("eastern_christianity")
	assert_true(r.starting_provinces_snapshot.has("jerozolima"))
	assert_true(r.starting_provinces_snapshot.has("konstantynopol"))

func test_initialize_sets_ever_owned_true_for_religion_with_starting_provinces():
	var gs := _make_state()
	var r: Religion = gs.get_religion("islam")
	# Islam ma prowincje startowe w historycznym fixture
	assert_true(r.ever_owned_province, "islam ma startowe prowincje → ever_owned_province == true")

func test_initialize_leaves_ever_owned_false_for_religion_without_starting_provinces():
	# Manicheizm jest w JSON ale nie ma żadnej prowincji w provinces_historical.json
	var gs := _make_state()
	var r: Religion = gs.get_religion("manichaeism")
	assert_false(r.ever_owned_province, "manichaeism bez prowincji startowych → ever_owned_province == false")
	assert_eq(r.starting_provinces_snapshot.size(), 0)

func test_initialize_leaves_ever_owned_false_for_germanic_paganism():
	var gs := _make_state()
	var r: Religion = gs.get_religion("germanic_paganism")
	assert_false(r.ever_owned_province)
	assert_eq(r.starting_provinces_snapshot.size(), 0)
