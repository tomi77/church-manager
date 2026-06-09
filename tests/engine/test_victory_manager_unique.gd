extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state(player_id: String = "islam") -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize(player_id, religions, graph)
	return gs

func _grant(state: Node, religion_id: String, province_ids: Array) -> void:
	for pid: String in province_ids:
		state.province_graph.get_province(pid).owner = religion_id

# === Manicheizm ===

func test_manichaeism_illumination_requires_C_90_and_4_distinct_sources():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("manichaeism")
	rel.axes["C"] = 90.0
	rel.absorbed_idea_sources = ["islam", "judaism", "zoroastrianism", "buddhism"]
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "manichaeism_illumination")

func test_manichaeism_illumination_blocked_with_3_sources():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("manichaeism")
	rel.axes["C"] = 95.0
	rel.absorbed_idea_sources = ["islam", "judaism", "zoroastrianism"]
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

func test_manichaeism_illumination_blocked_with_C_89():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("manichaeism")
	rel.axes["C"] = 89.0
	rel.absorbed_idea_sources = ["islam", "judaism", "zoroastrianism", "buddhism", "hinduism"]
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

func test_manichaeism_can_win_with_zero_provinces():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("manichaeism")
	rel.axes["C"] = 90.0
	rel.absorbed_idea_sources = ["islam", "judaism", "zoroastrianism", "buddhism"]
	# Manicheizm w fixture nie ma prowincji (ever_owned_province == false)
	assert_false(rel.ever_owned_province)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "manichaeism_illumination")

# === Judaizm ===

func test_judaism_return_requires_jerusalem_4_provinces_and_unity():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("judaism")
	_grant(gs, "judaism", ["jerozolima", "lewant", "egipt", "anatolia"])
	# Wszystkie 3 frakcje tension < 30
	for f: Faction in rel.factions:
		f.tension = 10.0
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "judaism_return")

func test_judaism_return_blocked_when_one_faction_tension_above_30():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("judaism")
	_grant(gs, "judaism", ["jerozolima", "lewant", "egipt", "anatolia"])
	for f: Faction in rel.factions:
		f.tension = 10.0
	rel.factions[0].tension = 31.0
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

func test_judaism_return_blocked_without_jerusalem():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("judaism")
	# 4 prowincje, bez jerozolimy
	_grant(gs, "judaism", ["lewant", "egipt", "anatolia", "arabia_polnocna"])
	for f: Faction in rel.factions:
		f.tension = 10.0
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

func test_judaism_return_blocked_with_3_provinces():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("judaism")
	_grant(gs, "judaism", ["jerozolima", "lewant", "egipt"])
	for f: Faction in rel.factions:
		f.tension = 10.0
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

# === Zoroastryzm ===

func test_zoroastrianism_renaissance_requires_persepolis_and_3_provinces():
	# Zoroastryzm startowo ma persję + persepolis (2 prowincje) — dodajmy trzecią (mezopotamia)
	var gs := _make_state()
	var rel: Religion = gs.get_religion("zoroastrianism")
	gs.province_graph.get_province("mezopotamia").owner = "zoroastrianism"
	assert_eq(gs.province_graph.provinces_with_owner("zoroastrianism").size(), 3)
	assert_eq(gs.province_graph.get_province("persepolis").owner, "zoroastrianism")
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "zoroastrianism_renaissance")

func test_zoroastrianism_renaissance_blocked_without_persepolis():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("zoroastrianism")
	gs.province_graph.get_province("mezopotamia").owner = "zoroastrianism"
	gs.province_graph.get_province("persepolis").owner = "islam"  # utrata persepolis
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

func test_zoroastrianism_renaissance_blocked_with_only_2_provinces():
	# Startowo zoroastryzm ma 2 prowincje (persja + persepolis) — to dokładnie poniżej progu 3.
	# Test weryfikuje że stan startowy nie spełnia warunku.
	var gs := _make_state()
	var rel: Religion = gs.get_religion("zoroastrianism")
	assert_eq(gs.province_graph.provinces_with_owner("zoroastrianism").size(), 2,
		"sanity: zoroastryzm startuje z 2 prowincjami (mapa historyczna)")
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

# === Chrześcijaństwo Wschodnie ===

func test_east_christianity_pentarchy_requires_3_simultaneous_vassals():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("eastern_christianity")
	gs.get_religion("coptic_christianity").suzerain_id = "eastern_christianity"
	gs.get_religion("judaism").suzerain_id = "eastern_christianity"
	gs.get_religion("zoroastrianism").suzerain_id = "eastern_christianity"
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "east_christianity_pentarchy")

func test_east_christianity_pentarchy_blocked_with_2_vassals():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("eastern_christianity")
	gs.get_religion("coptic_christianity").suzerain_id = "eastern_christianity"
	gs.get_religion("judaism").suzerain_id = "eastern_christianity"
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

# === Islam ===

func test_islam_caliphate_requires_mekka_jerusalem_and_5_provinces():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	_grant(gs, "islam", ["mekka", "jerozolima", "lewant", "egipt", "anatolia"])
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "islam_caliphate")

func test_islam_caliphate_blocked_without_mekka():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	# Daj jerozolimę + 5 innych ale nie mekka
	_grant(gs, "islam", ["jerozolima", "lewant", "egipt", "anatolia", "armenia", "konstantynopol"])
	gs.province_graph.get_province("mekka").owner = "arabian_paganism"
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

func test_islam_caliphate_blocked_with_4_provinces():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	_grant(gs, "islam", ["mekka", "jerozolima", "lewant", "egipt"])
	# 4 prowincje (mekka + 3 inne), poniżej progu 5
	for p in gs.province_graph.all_provinces():
		if p.owner == "islam" and not ["mekka", "jerozolima", "lewant", "egipt"].has(p.id):
			p.owner = "other"
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

# === Germanic Ragnarök ===

func test_germanic_ragnarok_victory_requires_flag_and_100_percent_starting_recovered():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("germanic_paganism")
	rel.starting_provinces_snapshot = ["p1", "p2"]
	rel.ragnarok_triggered = true
	for pid: String in rel.starting_provinces_snapshot:
		var p := Province.new()
		p.id = pid
		p.owner = "germanic_paganism"
		gs.province_graph.add_province(p)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "germanic_ragnarok")

func test_germanic_ragnarok_blocked_if_flag_not_set():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("germanic_paganism")
	rel.starting_provinces_snapshot = ["p1", "p2"]
	rel.ragnarok_triggered = false
	for pid: String in rel.starting_provinces_snapshot:
		var p := Province.new()
		p.id = pid
		p.owner = "germanic_paganism"
		gs.province_graph.add_province(p)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

func test_germanic_ragnarok_blocked_if_not_all_starting_recovered():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("germanic_paganism")
	rel.starting_provinces_snapshot = ["p1", "p2"]
	rel.ragnarok_triggered = true
	for pid: String in rel.starting_provinces_snapshot:
		var p := Province.new()
		p.id = pid
		p.owner = "germanic_paganism"
		gs.province_graph.add_province(p)
	gs.province_graph.get_province("p2").owner = "other"  # tylko p1 odzyskane
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

func test_germanic_ragnarok_unreachable_with_empty_snapshot():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("germanic_paganism")
	assert_eq(rel.starting_provinces_snapshot.size(), 0)
	rel.ragnarok_triggered = true  # nawet z fałszywie ustawioną flagą
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

# === Plan 13: Western Christianity ===

func test_western_reformation_requires_rome_4_vassals_and_prestige_600():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("western_christianity")
	# Rzym jest startowo Western — sanity
	assert_eq(gs.province_graph.get_province("rzym").owner, "western_christianity")
	# 4 wasali
	gs.get_religion("coptic_christianity").suzerain_id = "western_christianity"
	gs.get_religion("judaism").suzerain_id = "western_christianity"
	gs.get_religion("zoroastrianism").suzerain_id = "western_christianity"
	gs.get_religion("islam").suzerain_id = "western_christianity"
	rel.prestige = 600
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "western_reformation")

func test_western_reformation_blocked_without_rome():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("western_christianity")
	gs.province_graph.get_province("rzym").owner = "islam"  # utrata Rzymu
	gs.get_religion("coptic_christianity").suzerain_id = "western_christianity"
	gs.get_religion("judaism").suzerain_id = "western_christianity"
	gs.get_religion("zoroastrianism").suzerain_id = "western_christianity"
	gs.get_religion("islam").suzerain_id = "western_christianity"
	rel.prestige = 600
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

func test_western_reformation_blocked_with_3_vassals():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("western_christianity")
	gs.get_religion("coptic_christianity").suzerain_id = "western_christianity"
	gs.get_religion("judaism").suzerain_id = "western_christianity"
	gs.get_religion("zoroastrianism").suzerain_id = "western_christianity"
	rel.prestige = 600
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

func test_western_reformation_blocked_with_prestige_599():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("western_christianity")
	gs.get_religion("coptic_christianity").suzerain_id = "western_christianity"
	gs.get_religion("judaism").suzerain_id = "western_christianity"
	gs.get_religion("zoroastrianism").suzerain_id = "western_christianity"
	gs.get_religion("islam").suzerain_id = "western_christianity"
	rel.prestige = VictoryManager.WESTERN_PRESTIGE_REQUIRED - 1
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

func test_western_reformation_safe_when_rome_missing_from_graph():
	# Null guard — custom map bez Rzymu nie crashuje
	var gs := _make_state()
	var rel: Religion = gs.get_religion("western_christianity")
	gs.province_graph._provinces.erase("rzym")
	rel.prestige = 600
	gs.get_religion("coptic_christianity").suzerain_id = "western_christianity"
	gs.get_religion("judaism").suzerain_id = "western_christianity"
	gs.get_religion("zoroastrianism").suzerain_id = "western_christianity"
	gs.get_religion("islam").suzerain_id = "western_christianity"
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

# === No unique victory dla innych religii ===

func test_no_unique_victory_for_western_christianity():
	# ChrZ bez wasali / wystarczającego prestiżu nie spełnia warunku Reformacji.
	var gs := _make_state()
	var rel: Religion = gs.get_religion("western_christianity")
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

# === Null-guard edge cases (custom mapy bez wymaganych ID) ===

func test_judaism_return_does_not_crash_when_jerusalem_missing_from_graph():
	# Custom-map scenario: graph bez jerozolimy. Helper musi zwrócić false, nie crashować.
	var gs := _make_state()
	var rel: Religion = gs.get_religion("judaism")
	# Manualnie usuwamy jerozolimę z grafu (provinces dict)
	gs.province_graph._provinces.erase("jerozolima")
	for f: Faction in rel.factions:
		f.tension = 10.0
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

func test_zoroastrianism_renaissance_does_not_crash_when_persepolis_missing():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("zoroastrianism")
	gs.province_graph._provinces.erase("persepolis")
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

func test_islam_caliphate_does_not_crash_when_mekka_missing():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	gs.province_graph._provinces.erase("mekka")
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

func test_islam_caliphate_does_not_crash_when_jerusalem_missing():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	gs.province_graph._provinces.erase("jerozolima")
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

# === Plan 13: Hinduism ===

func _set_victory_counter(state: Node, rid: String, key: String, value: int) -> void:
	if not state.victory_progress.has(rid):
		state.victory_progress[rid] = {"domination_turns": 0, "prestige_hegemony_turns": 0, "dharma_turns": 0}
	state.victory_progress[rid][key] = value

func test_hindu_dharma_requires_50_turns_counter():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("hinduism")
	_set_victory_counter(gs, "hinduism", "dharma_turns", VictoryManager.HINDU_DHARMA_TURNS_REQUIRED)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "hindu_dharma")

func test_hindu_dharma_blocked_with_49_turns():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("hinduism")
	_set_victory_counter(gs, "hinduism", "dharma_turns", VictoryManager.HINDU_DHARMA_TURNS_REQUIRED - 1)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

func test_hindu_dharma_blocked_when_counter_missing():
	# Nigdy nie był aktualizowany counter (np. religia nigdy nie miała ≥ 2 prowincji)
	var gs := _make_state()
	var rel: Religion = gs.get_religion("hinduism")
	# victory_progress["hinduism"] nie istnieje
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

# === Plan 13: Buddhism ===

func test_buddhism_middle_way_requires_D_90_and_4_sources():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("buddhism")
	rel.axes["D"] = 90.0
	rel.absorbed_idea_sources = ["islam", "judaism", "hinduism", "manichaeism"]
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "buddhism_middle_way")

func test_buddhism_middle_way_blocked_with_D_89():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("buddhism")
	rel.axes["D"] = 89.0
	rel.absorbed_idea_sources = ["islam", "judaism", "hinduism", "manichaeism", "zoroastrianism"]
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

func test_buddhism_middle_way_blocked_with_3_sources():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("buddhism")
	rel.axes["D"] = 95.0
	rel.absorbed_idea_sources = ["islam", "judaism", "hinduism"]
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

func test_buddhism_can_win_with_zero_provinces():
	# Analog test_manichaeism_can_win_with_zero_provinces — Buddhism startowo bez prowincji
	var gs := _make_state()
	var rel: Religion = gs.get_religion("buddhism")
	rel.axes["D"] = 90.0
	rel.absorbed_idea_sources = ["islam", "judaism", "hinduism", "manichaeism"]
	assert_false(rel.ever_owned_province, "buddhism startuje bez prowincji w fixture")
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "buddhism_middle_way")

# === Plan 14: coptic_citadel predykat ===

func test_coptic_citadel_requires_20_turns_counter() -> void:
	var gs := _make_state("coptic_christianity")
	var coptic: Religion = gs.get_religion("coptic_christianity")
	gs.victory_progress["coptic_christianity"] = {
		"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": VictoryManager.COPTIC_CITADEL_TURNS_REQUIRED}
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(coptic, gs), "coptic_citadel",
		"counter == 20 → coptic_citadel reason")

func test_coptic_citadel_blocked_with_19_turns() -> void:
	var gs := _make_state("coptic_christianity")
	var coptic: Religion = gs.get_religion("coptic_christianity")
	gs.victory_progress["coptic_christianity"] = {
		"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": VictoryManager.COPTIC_CITADEL_TURNS_REQUIRED - 1}
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(coptic, gs), "",
		"counter == 19 → brak unique victory (próg ostry >=)")

func test_coptic_citadel_other_religion_never_returns_reason() -> void:
	# Sanity: Islam z wstrzykniętym counterem nie zwraca coptic_citadel (brak case'a w match).
	var gs := _make_state("islam")
	var islam: Religion = gs.get_religion("islam")
	gs.victory_progress["islam"] = {
		"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 999}
	var vm := VictoryManager.new()
	assert_ne(vm.evaluate_unique_victory(islam, gs), "coptic_citadel",
		"Islam nigdy nie zwraca coptic_citadel — match case jest tylko dla coptic")
