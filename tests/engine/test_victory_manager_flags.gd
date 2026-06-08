extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func _grant_province_to(state: Node, religion_id: String, province_id: String) -> void:
	state.province_graph.get_province(province_id).owner = religion_id

func test_update_flags_sets_ever_owned_for_religion_acquiring_first_province():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("manichaeism")
	assert_false(rel.ever_owned_province, "manicheizm startuje bez prowincji")
	_grant_province_to(gs, "manichaeism", "mezopotamia")
	var vm := VictoryManager.new()
	vm.update_flags(gs)
	assert_true(rel.ever_owned_province, "po zdobyciu prowincji flaga ustawiona")

func test_update_flags_keeps_ever_owned_true_after_losing_provinces():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	assert_true(rel.ever_owned_province, "islam startuje z prowincjami")
	# Utrata wszystkich prowincji
	for p in gs.province_graph.provinces_with_owner("islam"):
		p.owner = ""
	var vm := VictoryManager.new()
	vm.update_flags(gs)
	assert_true(rel.ever_owned_province, "flaga jest trwała — nie resetuje się")

func test_update_flags_does_not_touch_defeated_religion():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("manichaeism")
	rel.defeated_at_turn = 50  # już pokonana
	_grant_province_to(gs, "manichaeism", "mezopotamia")
	var vm := VictoryManager.new()
	vm.update_flags(gs)
	# Defeated religion nie podlega update — flaga pozostaje false
	assert_false(rel.ever_owned_province)

func test_update_flags_sets_ragnarok_for_germanic_after_losing_more_than_half_snapshot():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("germanic_paganism")
	# Symulujemy posiadanie 4 prowincji startowych
	rel.starting_provinces_snapshot = ["p1", "p2", "p3", "p4"]
	rel.ever_owned_province = true
	# Dodajemy te prowincje do grafu, owner = germanic_paganism
	for pid in rel.starting_provinces_snapshot:
		var p := Province.new()
		p.id = pid
		p.owner = "germanic_paganism"
		gs.province_graph.add_province(p)
	# Religia utraciła 3 z 4 (75%) — owner zmieniony
	gs.province_graph.get_province("p1").owner = "other"
	gs.province_graph.get_province("p2").owner = "other"
	gs.province_graph.get_province("p3").owner = "other"
	assert_false(rel.ragnarok_triggered)
	var vm := VictoryManager.new()
	vm.update_flags(gs)
	assert_true(rel.ragnarok_triggered, "germanic_paganism utracił >50% snapshot → flag set")

func test_update_flags_does_not_set_ragnarok_when_snapshot_empty():
	# Na mapie historycznej germanic_paganism nie ma startowych prowincji
	var gs := _make_state()
	var rel: Religion = gs.get_religion("germanic_paganism")
	assert_eq(rel.starting_provinces_snapshot.size(), 0)
	var vm := VictoryManager.new()
	vm.update_flags(gs)
	assert_false(rel.ragnarok_triggered, "pusty snapshot → nigdy nie trigger")

func test_update_flags_ragnarok_only_applies_to_germanic_paganism():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	# Symulacja utraty wszystkich startowych prowincji
	for pid in rel.starting_provinces_snapshot:
		gs.province_graph.get_province(pid).owner = "other"
	var vm := VictoryManager.new()
	vm.update_flags(gs)
	assert_false(rel.ragnarok_triggered, "ragnarok_triggered nie dotyczy religii innych niż germanic_paganism")

func test_update_flags_ragnarok_persists_after_recovery():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("germanic_paganism")
	rel.starting_provinces_snapshot = ["p1", "p2"]
	rel.ever_owned_province = true
	for pid in rel.starting_provinces_snapshot:
		var p := Province.new()
		p.id = pid
		p.owner = "germanic_paganism"
		gs.province_graph.add_province(p)
	gs.province_graph.get_province("p1").owner = "other"  # 1/2 lost = 50%
	var vm := VictoryManager.new()
	vm.update_flags(gs)
	assert_true(rel.ragnarok_triggered)
	# Religia odzyskuje prowincję
	gs.province_graph.get_province("p1").owner = "germanic_paganism"
	vm.update_flags(gs)
	assert_true(rel.ragnarok_triggered, "raz ustawiona flaga nie resetuje się")

func test_update_counters_increments_domination_when_above_threshold():
	var gs := _make_state()
	# Daj islamowi >=50% prowincji (6/12). Sprawdź ile islam już ma.
	var current: int = gs.province_graph.provinces_with_owner("islam").size()
	var needed: int = int(ceil(VictoryManager.DOMINATION_PROVINCE_SHARE * gs.province_graph.all_provinces().size())) - current
	var available: Array = []
	for p in gs.province_graph.all_provinces():
		if p.owner != "islam":
			available.append(p)
	for i in range(needed):
		available[i].owner = "islam"
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("islam", {})
	assert_eq(prog.get("domination_turns", 0), 1)
	vm.update_counters(gs)
	prog = gs.victory_progress.get("islam", {})
	assert_eq(prog.get("domination_turns", 0), 2)

func test_update_counters_resets_domination_on_drop_below_threshold():
	var gs := _make_state()
	# Symulacja: licznik już > 0
	gs.victory_progress["islam"] = {"domination_turns": 5, "prestige_hegemony_turns": 0}
	# Islam startowo nie ma 50% prowincji → po update licznik dominacji powinien wrócić do 0
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("islam", {})
	assert_eq(prog.get("domination_turns", 0), 0, "spadek poniżej progu → reset")

func test_update_counters_increments_prestige_hegemony_when_2x_second():
	var gs := _make_state()
	# Ustaw islam prestige = 1000, wszyscy inni < 500
	for r in gs.all_religions():
		r.prestige = 100 if r.id != "islam" else 1000
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("islam", {})
	assert_eq(prog.get("prestige_hegemony_turns", 0), 1)

func test_update_counters_resets_prestige_hegemony_when_below_ratio():
	var gs := _make_state()
	# Wszyscy mają taki sam prestiż — żadna religia nie ma 2× drugiej
	for r in gs.all_religions():
		r.prestige = 100
	gs.victory_progress["islam"] = {"domination_turns": 0, "prestige_hegemony_turns": 5}
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("islam", {})
	assert_eq(prog.get("prestige_hegemony_turns", 0), 0)

func test_update_counters_increments_zero_provinces_when_religion_has_no_provinces():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.ever_owned_province = true
	for p in gs.province_graph.provinces_with_owner("islam"):
		p.owner = ""
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.defeat_progress.get("islam", {})
	assert_eq(prog.get("zero_provinces_turns", 0), 1)

func test_update_counters_resets_zero_provinces_on_reconquest():
	var gs := _make_state()
	gs.defeat_progress["islam"] = {"zero_provinces_turns": 4, "vassalage_turns": 0}
	# Islam wciąż ma prowincje
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.defeat_progress.get("islam", {})
	assert_eq(prog.get("zero_provinces_turns", 0), 0, "ma prowincje → reset")

func test_update_counters_increments_vassalage_when_suzerain_set():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.suzerain_id = "western_christianity"
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.defeat_progress.get("islam", {})
	assert_eq(prog.get("vassalage_turns", 0), 1)

func test_update_counters_resets_vassalage_on_independence():
	var gs := _make_state()
	gs.defeat_progress["islam"] = {"zero_provinces_turns": 0, "vassalage_turns": 15}
	var rel: Religion = gs.get_religion("islam")
	rel.suzerain_id = ""  # niezależna
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.defeat_progress.get("islam", {})
	assert_eq(prog.get("vassalage_turns", 0), 0)

func test_update_counters_does_not_touch_defeated_religion():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("manichaeism")
	rel.defeated_at_turn = 50
	rel.suzerain_id = "islam"
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	# Pokonana religia nie podlega aktualizacji liczników
	assert_false(gs.defeat_progress.has("manichaeism"))

# === Plan 13: total_schism_turns counter ===

func test_update_counters_initializes_total_schism_turns_zero():
	var gs := _make_state()
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.defeat_progress.get("islam", {})
	assert_eq(prog.get("total_schism_turns", -1), 0,
		"po pierwszym update licznik istnieje i jest 0")

func test_update_counters_increments_total_schism_when_all_three_factions_phase_3():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	# Wszystkie 3 frakcje w fazie 3 (tension >= 85)
	for f: Faction in rel.factions:
		f.tension = 90.0
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.defeat_progress.get("islam", {})
	assert_eq(prog.get("total_schism_turns", 0), 1)
	vm.update_counters(gs)
	prog = gs.defeat_progress.get("islam", {})
	assert_eq(prog.get("total_schism_turns", 0), 2)

func test_update_counters_resets_total_schism_when_one_faction_drops_below_phase_3():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	# Symulacja: licznik już > 0
	gs.defeat_progress["islam"] = {"zero_provinces_turns": 0, "vassalage_turns": 0, "total_schism_turns": 1}
	# Tylko 2 z 3 w fazie 3
	rel.factions[0].tension = 90.0
	rel.factions[1].tension = 90.0
	rel.factions[2].tension = 80.0  # poniżej PHASE3_THRESHOLD
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.defeat_progress.get("islam", {})
	assert_eq(prog.get("total_schism_turns", 0), 0, "jedna frakcja poniżej → reset")

func test_update_counters_total_schism_requires_exactly_3_factions():
	# Edge case: religia z != 3 frakcjami (np. po schizmie utraciła frakcję)
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	# Usuwamy jedną frakcję (zostały 2)
	rel.factions.pop_back()
	assert_eq(rel.factions.size(), 2)
	# Obie pozostałe w fazie 3
	for f: Faction in rel.factions:
		f.tension = 90.0
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.defeat_progress.get("islam", {})
	assert_eq(prog.get("total_schism_turns", 0), 0,
		"religia z mniej niż 3 frakcjami nie inkrementuje (faktyczna schizma już zaszła)")

func test_update_counters_total_schism_does_not_touch_defeated_religion():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("manichaeism")
	rel.defeated_at_turn = 50  # pokonana
	for f: Faction in rel.factions:
		f.tension = 90.0
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	assert_false(gs.defeat_progress.has("manichaeism"),
		"pokonana religia nie podlega update_counters")

# === Plan 13: dharma_turns counter (Hindu) ===

func test_update_counters_initializes_dharma_turns_zero():
	var gs := _make_state()
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("hinduism", {})
	assert_eq(prog.get("dharma_turns", -1), 0,
		"po pierwszym update licznik istnieje i jest 0")

func test_update_counters_increments_dharma_when_hindu_owns_2_provinces():
	var gs := _make_state()
	# Hindu startowo nie ma prowincji — daj 2
	gs.province_graph.get_province("mekka").owner = "hinduism"
	gs.province_graph.get_province("lewant").owner = "hinduism"
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("hinduism", {})
	assert_eq(prog.get("dharma_turns", 0), 1)
	vm.update_counters(gs)
	prog = gs.victory_progress.get("hinduism", {})
	assert_eq(prog.get("dharma_turns", 0), 2)

func test_update_counters_resets_dharma_when_hindu_owns_only_1_province():
	var gs := _make_state()
	gs.victory_progress["hinduism"] = {"domination_turns": 0, "prestige_hegemony_turns": 0, "dharma_turns": 30}
	# Hindu ma 1 prowincję
	gs.province_graph.get_province("mekka").owner = "hinduism"
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("hinduism", {})
	assert_eq(prog.get("dharma_turns", 0), 0, "spadek poniżej progu → reset")

func test_update_counters_only_increments_dharma_for_hinduism():
	# Inne religie (np. islam) nie mają licznika dharma_turns inkrementowanego nawet z ≥ 2 prowincji
	var gs := _make_state()
	# Islam startowo ma 1 prowincję (mezopotamia), dodajmy drugą
	gs.province_graph.get_province("lewant").owner = "islam"
	assert_gt(gs.province_graph.provinces_with_owner("islam").size(), 1)
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("islam", {})
	# Klucz dharma_turns istnieje (default 0) ale nie inkrementuje dla islamu
	assert_eq(prog.get("dharma_turns", -1), 0)
