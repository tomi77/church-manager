extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func _set_counter(state: Node, rid: String, key: String, value: int) -> void:
	if not state.victory_progress.has(rid):
		state.victory_progress[rid] = {"domination_turns": 0, "prestige_hegemony_turns": 0}
	state.victory_progress[rid][key] = value

func test_domination_returns_reason_when_counter_meets_threshold():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	_set_counter(gs, "islam", "domination_turns", VictoryManager.DOMINATION_TURNS_REQUIRED)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_universal_victory(rel, gs), "domination")

func test_domination_returns_empty_one_below_threshold():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	_set_counter(gs, "islam", "domination_turns", VictoryManager.DOMINATION_TURNS_REQUIRED - 1)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_universal_victory(rel, gs), "")

func test_prestige_hegemony_returns_reason_when_counter_meets_threshold():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	_set_counter(gs, "islam", "prestige_hegemony_turns", VictoryManager.PRESTIGE_HEGEMONY_TURNS_REQUIRED)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_universal_victory(rel, gs), "prestige_hegemony")

func test_holy_land_returns_reason_when_all_own_holy_sites_plus_one_foreign():
	# Western Christianity ma own holy_sites: ["rzym", "jerozolima"] (fixture).
	# Startowo zachód kontroluje rzym; jerozolima jest eastern's; konstantynopol jest is_holy_site eastern's.
	# Aby spełnić warunek: kontrola obu własnych (rzym + jerozolima) + 1 cudzy is_holy_site (konstantynopol).
	var gs := _make_state()
	var rel: Religion = gs.get_religion("western_christianity")
	gs.province_graph.get_province("jerozolima").owner = "western_christianity"		# własne (z eastern's posiadania)
	gs.province_graph.get_province("konstantynopol").owner = "western_christianity"	# cudze is_holy_site (NIE na liście zachodu)
	assert_eq(gs.province_graph.get_province("rzym").owner, "western_christianity",
		"sanity: rzym jest startowo zachodu")
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_universal_victory(rel, gs), "holy_land")

func test_holy_land_blocked_when_no_own_holy_sites():
	# Manicheizm ma puste holy_sites — warunek niedostępny mimo zdobycia cudzego
	var gs := _make_state()
	var rel: Religion = gs.get_religion("manichaeism")
	assert_eq(rel.holy_sites.size(), 0)
	gs.province_graph.get_province("jerozolima").owner = "manichaeism"
	var vm := VictoryManager.new()
	assert_ne(vm.evaluate_universal_victory(rel, gs), "holy_land")

func test_holy_land_blocked_when_own_holy_site_lost():
	# Zachód straci rzym (jego własne) — mimo posiadania cudzego (konstantynopol) i jerozolimy → nie wygrywa
	var gs := _make_state()
	var rel: Religion = gs.get_religion("western_christianity")
	gs.province_graph.get_province("rzym").owner = "islam"							# utrata własnego
	gs.province_graph.get_province("jerozolima").owner = "western_christianity"		# drugie własne kontrolowane
	gs.province_graph.get_province("konstantynopol").owner = "western_christianity"	# cudze is_holy_site
	var vm := VictoryManager.new()
	assert_ne(vm.evaluate_universal_victory(rel, gs), "holy_land")

func test_holy_land_blocked_without_foreign_holy_site():
	# Zachód kontroluje wszystkie własne (rzym + jerozolima), ale żadnego cudzego is_holy_site
	var gs := _make_state()
	var rel: Religion = gs.get_religion("western_christianity")
	gs.province_graph.get_province("jerozolima").owner = "western_christianity"
	# konstantynopol pozostaje eastern's; brak cudzego is_holy_site pod zachodu kontrolą
	var vm := VictoryManager.new()
	assert_ne(vm.evaluate_universal_victory(rel, gs), "holy_land")

func test_universal_victory_returns_empty_when_nothing_met():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_universal_victory(rel, gs), "")
