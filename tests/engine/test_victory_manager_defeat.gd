extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func _set_defeat_counter(state: Node, rid: String, key: String, value: int) -> void:
	if not state.defeat_progress.has(rid):
		state.defeat_progress[rid] = {"zero_provinces_turns": 0, "vassalage_turns": 0, "total_schism_turns": 0}
	state.defeat_progress[rid][key] = value

func test_elimination_returns_reason_when_5_turns_zero_provinces_and_ever_owned():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.ever_owned_province = true
	_set_defeat_counter(gs, "islam", "zero_provinces_turns", VictoryManager.ELIMINATION_TURNS_REQUIRED)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_defeat(rel, gs), "elimination")

func test_elimination_blocked_without_ever_owned_province():
	# Manicheizm nigdy nie miał prowincji → mimo licznika 100 nie jest eliminated
	var gs := _make_state()
	var rel: Religion = gs.get_religion("manichaeism")
	assert_false(rel.ever_owned_province)
	_set_defeat_counter(gs, "manichaeism", "zero_provinces_turns", 100)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_defeat(rel, gs), "")

func test_elimination_blocked_one_below_threshold():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.ever_owned_province = true
	_set_defeat_counter(gs, "islam", "zero_provinces_turns", VictoryManager.ELIMINATION_TURNS_REQUIRED - 1)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_defeat(rel, gs), "")

func test_long_vassalage_returns_reason_when_20_turns_with_suzerain_and_ever_owned():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.ever_owned_province = true
	_set_defeat_counter(gs, "islam", "vassalage_turns", VictoryManager.VASSAL_DEFEAT_TURNS_REQUIRED)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_defeat(rel, gs), "long_vassalage")

func test_long_vassalage_blocked_without_ever_owned():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("manichaeism")
	assert_false(rel.ever_owned_province)
	_set_defeat_counter(gs, "manichaeism", "vassalage_turns", 50)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_defeat(rel, gs), "")

func test_long_vassalage_blocked_one_below_threshold():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.ever_owned_province = true
	_set_defeat_counter(gs, "islam", "vassalage_turns", VictoryManager.VASSAL_DEFEAT_TURNS_REQUIRED - 1)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_defeat(rel, gs), "")

func test_no_defeat_when_neither_condition_met():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.ever_owned_province = true
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_defeat(rel, gs), "")

func test_elimination_takes_precedence_over_vassalage_when_both_met():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.ever_owned_province = true
	_set_defeat_counter(gs, "islam", "zero_provinces_turns", VictoryManager.ELIMINATION_TURNS_REQUIRED)
	_set_defeat_counter(gs, "islam", "vassalage_turns", VictoryManager.VASSAL_DEFEAT_TURNS_REQUIRED)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_defeat(rel, gs), "elimination", "elimination ma pierwszeństwo (tematycznie definitywne)")

# === Plan 13: D3 total_schism ===

func test_total_schism_returns_reason_at_threshold():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.ever_owned_province = true
	_set_defeat_counter(gs, "islam", "total_schism_turns", VictoryManager.SCHISM_TOTAL_TURNS_REQUIRED)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_defeat(rel, gs), "total_schism")

func test_total_schism_blocked_without_ever_owned_province():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("manichaeism")
	assert_false(rel.ever_owned_province)
	_set_defeat_counter(gs, "manichaeism", "total_schism_turns", 100)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_defeat(rel, gs), "")

func test_total_schism_blocked_one_below_threshold():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.ever_owned_province = true
	_set_defeat_counter(gs, "islam", "total_schism_turns", VictoryManager.SCHISM_TOTAL_TURNS_REQUIRED - 1)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_defeat(rel, gs), "")

func test_elimination_takes_precedence_over_total_schism():
	# D1 > D3 — eliminacja jest najdefinitywniejsza
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.ever_owned_province = true
	_set_defeat_counter(gs, "islam", "zero_provinces_turns", VictoryManager.ELIMINATION_TURNS_REQUIRED)
	_set_defeat_counter(gs, "islam", "total_schism_turns", VictoryManager.SCHISM_TOTAL_TURNS_REQUIRED)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_defeat(rel, gs), "elimination")

func test_total_schism_takes_precedence_over_long_vassalage():
	# D3 > D2 — schizma totalna jest bardziej dramatyczna od długiej wassalaży
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.ever_owned_province = true
	_set_defeat_counter(gs, "islam", "total_schism_turns", VictoryManager.SCHISM_TOTAL_TURNS_REQUIRED)
	_set_defeat_counter(gs, "islam", "vassalage_turns", VictoryManager.VASSAL_DEFEAT_TURNS_REQUIRED)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_defeat(rel, gs), "total_schism")
