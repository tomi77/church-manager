extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func test_turn_manager_invokes_victory_check_after_advance_turn():
	var gs := _make_state()
	# Western_christianity — nie ma unique-victory, więc dominacja terytorialna zadziała.
	# Czyścimy holy_sites + flagujemy provinces jako !is_holy_site, żeby uniknąć
	# wcześniejszego triggeru "holy_land" (który zadziałałby już po 1 turze).
	for p in gs.province_graph.all_provinces():
		p.owner = "western_christianity"
		p.is_holy_site = false
	for r: Religion in gs.all_religions():
		r.holy_sites = []
	# Trzy tury z rzędu z dominacją — po trzeciej powinien wygrać
	var tm := TurnManager.new()
	tm.process_turn(gs)  # domination_turns = 1
	tm.process_turn(gs)  # domination_turns = 2
	tm.process_turn(gs)  # domination_turns = 3 → wygrywa
	assert_not_null(gs.game_outcome)
	assert_eq(gs.game_outcome.winner_id, "western_christianity")
	assert_eq(gs.game_outcome.reason, "domination")

func test_full_pipeline_does_not_crash_when_no_winner():
	var gs := _make_state()
	var tm := TurnManager.new()
	# Kilka tur startowych — żaden warunek nie powinien być spełniony
	for _i in range(5):
		tm.process_turn(gs)
	assert_null(gs.game_outcome)

func test_victory_check_not_invoked_when_game_already_over():
	var gs := _make_state()
	var prior := GameOutcome.new()
	prior.winner_id = "judaism"
	prior.end_turn = 5
	gs.game_outcome = prior
	var tm := TurnManager.new()
	tm.process_turn(gs)
	# Pipeline turn manager przeszedł, ale check nie powinien był nadpisać outcome
	assert_eq(gs.game_outcome.winner_id, "judaism")
	assert_eq(gs.game_outcome.end_turn, 5)
