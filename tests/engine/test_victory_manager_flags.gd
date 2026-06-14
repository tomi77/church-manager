extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state(player_id: String = "islam") -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize(player_id, religions, graph)
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
	# Daj islamowi >=50% prowincji (8/16). Sprawdź ile islam już ma.
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

# === Plan 14: coptic_citadel_turns counter ===

func test_update_counters_initializes_coptic_citadel_turns_zero() -> void:
	var gs := _make_state("coptic_christianity")
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("coptic_christianity", {})
	assert_eq(prog.get("coptic_citadel_turns", -1), 0,
		"po pierwszym update licznik istnieje i jest 0")

func test_update_counters_increments_coptic_citadel_when_all_conditions_met() -> void:
	var gs := _make_state("coptic_christianity")
	var coptic: Religion = gs.get_religion("coptic_christianity")
	# Wszystkie 3 prowincje Coptic (już z fixture: egipt + aleksandria + abisynia są coptic)
	# Axis D ≥ 85
	coptic.axes["D"] = 90.0
	# Wszystkie frakcje tension < 50 (już z fixture: tension_start = 20.0)
	for f: Faction in coptic.factions:
		f.tension = 20.0
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("coptic_christianity", {})
	assert_eq(prog.get("coptic_citadel_turns", 0), 1)
	vm.update_counters(gs)
	prog = gs.victory_progress.get("coptic_christianity", {})
	assert_eq(prog.get("coptic_citadel_turns", 0), 2)

func test_update_counters_resets_coptic_citadel_when_aleksandria_lost() -> void:
	var gs := _make_state("coptic_christianity")
	var coptic: Religion = gs.get_religion("coptic_christianity")
	coptic.axes["D"] = 90.0
	for f: Faction in coptic.factions:
		f.tension = 20.0
	gs.victory_progress["coptic_christianity"] = {
		"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 5}
	# Utrata aleksandrii
	gs.province_graph.get_province("aleksandria").owner = "eastern_christianity"
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("coptic_christianity", {})
	assert_eq(prog.get("coptic_citadel_turns", -1), 0, "utrata aleksandrii → reset")

func test_update_counters_resets_coptic_citadel_when_axis_d_below_threshold() -> void:
	var gs := _make_state("coptic_christianity")
	var coptic: Religion = gs.get_religion("coptic_christianity")
	coptic.axes["D"] = 84.99  # tuż poniżej progu
	for f: Faction in coptic.factions:
		f.tension = 20.0
	gs.victory_progress["coptic_christianity"] = {
		"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 5}
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("coptic_christianity", {})
	assert_eq(prog.get("coptic_citadel_turns", -1), 0, "axis D < 85 → reset")

func test_update_counters_resets_coptic_citadel_when_faction_tension_at_threshold() -> void:
	# Próg ostry: < 50 (nie <=). Tension = 50.0 powinien blokować.
	var gs := _make_state("coptic_christianity")
	var coptic: Religion = gs.get_religion("coptic_christianity")
	coptic.axes["D"] = 90.0
	coptic.factions[0].tension = 50.0
	coptic.factions[1].tension = 20.0
	coptic.factions[2].tension = 20.0
	gs.victory_progress["coptic_christianity"] = {
		"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 5}
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("coptic_christianity", {})
	assert_eq(prog.get("coptic_citadel_turns", -1), 0, "tension == 50 → reset (próg ostry)")

func test_update_counters_resets_coptic_citadel_when_faction_lost_via_schism() -> void:
	# Edge case: factions.size() < 3 (np. po schizmie) — vacuous truth blocked przez guard.
	var gs := _make_state("coptic_christianity")
	var coptic: Religion = gs.get_religion("coptic_christianity")
	coptic.axes["D"] = 90.0
	coptic.factions.pop_back()  # zostały 2 frakcje
	for f: Faction in coptic.factions:
		f.tension = 20.0
	gs.victory_progress["coptic_christianity"] = {
		"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 5}
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("coptic_christianity", {})
	assert_eq(prog.get("coptic_citadel_turns", -1), 0,
		"factions.size() < 3 → reset (schizma już zaszła, jedność zburzona)")

func test_update_counters_only_increments_coptic_citadel_for_coptic_christianity() -> void:
	# Inne religie nie inkrementują coptic_citadel_turns nawet jeśli "spełniają" warunki Coptic.
	var gs := _make_state("islam")
	var islam: Religion = gs.get_religion("islam")
	islam.axes["D"] = 100.0  # axis D bardzo wysoki
	for f: Faction in islam.factions:
		f.tension = 10.0
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("islam", {})
	assert_eq(prog.get("coptic_citadel_turns", -1), 0,
		"Islam nie inkrementuje coptic_citadel_turns (counter jest religion-scoped do Coptic)")

# === Plan 16: arabian_submission_turns counter ===

func test_update_counters_initializes_arabian_submission_turns_zero() -> void:
	var gs := _make_state("arabian_paganism")
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("arabian_paganism", {})
	assert_eq(prog.get("arabian_submission_turns", -1), 0,
		"counter inicjuje się na 0 dla Arabian")

func test_update_counters_increments_arabian_submission_when_all_6_conditions_met() -> void:
	var gs := _make_state("arabian_paganism")
	var rel: Religion = gs.get_religion("arabian_paganism")
	# Mekka już jest Arabian z fixture. Pozostaje ustawić osie i upewnić się że 3 frakcje żyją.
	rel.axes["A"] = 70.0
	rel.axes["B"] = 65.0
	rel.axes["C"] = 30.0
	rel.axes["D"] = 75.0
	assert_eq(rel.factions.size(), 3, "Arabian startuje z 3 frakcjami")
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("arabian_paganism", {})
	assert_eq(prog.get("arabian_submission_turns", 0), 1)
	vm.update_counters(gs)
	assert_eq(prog.get("arabian_submission_turns", 0), 2, "counter inkrementuje per turn")

func test_update_counters_resets_arabian_submission_when_mekka_lost() -> void:
	var gs := _make_state("arabian_paganism")
	var rel: Religion = gs.get_religion("arabian_paganism")
	rel.axes["A"] = 70.0
	rel.axes["B"] = 65.0
	rel.axes["C"] = 30.0
	rel.axes["D"] = 75.0
	# Pre-set counter = 5, by check reset
	gs.victory_progress["arabian_paganism"] = {"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 0, "arabian_submission_turns": 5}
	gs.province_graph.get_province("mekka").owner = "islam"  # utrata mekki
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("arabian_paganism", {})
	assert_eq(prog.get("arabian_submission_turns", -1), 0, "utrata mekki → reset")

func test_update_counters_resets_arabian_submission_when_axis_A_drops_to_64() -> void:
	var gs := _make_state("arabian_paganism")
	var rel: Religion = gs.get_religion("arabian_paganism")
	rel.axes["A"] = 64.0  # poniżej ARABIAN_AXIS_A_REQUIRED=65
	rel.axes["B"] = 65.0
	rel.axes["C"] = 30.0
	rel.axes["D"] = 75.0
	gs.victory_progress["arabian_paganism"] = {"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 0, "arabian_submission_turns": 5}
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("arabian_paganism", {})
	assert_eq(prog.get("arabian_submission_turns", -1), 0, "A=64 → reset (próg ostry ≥65)")

func test_update_counters_resets_arabian_submission_when_axis_C_rises_to_36() -> void:
	var gs := _make_state("arabian_paganism")
	var rel: Religion = gs.get_religion("arabian_paganism")
	rel.axes["A"] = 70.0
	rel.axes["B"] = 65.0
	rel.axes["C"] = 36.0  # powyżej ARABIAN_AXIS_C_MAX=35
	rel.axes["D"] = 75.0
	gs.victory_progress["arabian_paganism"] = {"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 0, "arabian_submission_turns": 5}
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("arabian_paganism", {})
	assert_eq(prog.get("arabian_submission_turns", -1), 0, "C=36 → reset (próg ostry ≤35)")

func test_update_counters_resets_arabian_submission_when_faction_count_drops_to_2() -> void:
	var gs := _make_state("arabian_paganism")
	var rel: Religion = gs.get_religion("arabian_paganism")
	rel.axes["A"] = 70.0
	rel.axes["B"] = 65.0
	rel.axes["C"] = 30.0
	rel.axes["D"] = 75.0
	# Symuluj utratę 1 frakcji przez schizmę.
	rel.factions.pop_back()
	assert_eq(rel.factions.size(), 2)
	gs.victory_progress["arabian_paganism"] = {"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 0, "arabian_submission_turns": 5}
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("arabian_paganism", {})
	assert_eq(prog.get("arabian_submission_turns", -1), 0,
		"factions.size()<3 → reset (utrata frakcji przez schizmę)")

func test_update_counters_only_increments_arabian_submission_for_arabian_paganism() -> void:
	# Inne religie nie inkrementują arabian_submission_turns nawet jeśli "spełniają" warunki.
	var gs := _make_state("islam")
	var rel: Religion = gs.get_religion("islam")
	# Islam już ma osie islamskie (70/65/30/75) — gdyby gałąź nie filtrowała, counter rósłby.
	# Islam też ma mekka (startowo nie, ale ustawmy).
	gs.province_graph.get_province("mekka").owner = "islam"
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("islam", {})
	assert_eq(prog.get("arabian_submission_turns", -1), 0,
		"Islam nie inkrementuje arabian_submission_turns (counter jest religion-scoped do Arabian)")

# === Plan 17: slavic_sacred_groves_turns counter ===

func test_update_counters_initializes_slavic_sacred_groves_turns_zero() -> void:
	var gs := _make_state("slavic_paganism")
	# Łamiemy warunek (axis A powyżej progu) by counter trzymał się na 0,
	# żeby przetestować że klucz w schema istnieje (default -1 = missing key).
	var rel: Religion = gs.get_religion("slavic_paganism")
	rel.axes["A"] = 50.0
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("slavic_paganism", {})
	assert_eq(prog.get("slavic_sacred_groves_turns", -1), 0,
		"counter inicjuje się na 0 dla Slavic")

func test_update_counters_increments_slavic_sacred_groves_when_all_conditions_met() -> void:
	var gs := _make_state("slavic_paganism")
	var rel: Religion = gs.get_religion("slavic_paganism")
	# 7 prowincji już Slavic z fixture (Plan 17 Tasks 1-7). Osie startowe: A=20, B=25.
	assert_eq(rel.get_axis("A"), 20.0, "Slavic start A=20")
	assert_eq(rel.get_axis("B"), 25.0, "Slavic start B=25")
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("slavic_paganism", {})
	assert_eq(prog.get("slavic_sacred_groves_turns", 0), 1)
	vm.update_counters(gs)
	assert_eq(prog.get("slavic_sacred_groves_turns", 0), 2)

func test_update_counters_resets_slavic_sacred_groves_when_arkona_lost() -> void:
	var gs := _make_state("slavic_paganism")
	gs.victory_progress["slavic_paganism"] = {"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 0, "arabian_submission_turns": 0,
		"slavic_sacred_groves_turns": 5}
	gs.province_graph.get_province("arkona").owner = "western_christianity"
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("slavic_paganism", {})
	assert_eq(prog.get("slavic_sacred_groves_turns", -1), 0,
		"utrata arkony → reset (province at start of list)")

func test_update_counters_resets_slavic_sacred_groves_when_kijow_lost() -> void:
	var gs := _make_state("slavic_paganism")
	gs.victory_progress["slavic_paganism"] = {"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 0, "arabian_submission_turns": 0,
		"slavic_sacred_groves_turns": 5}
	gs.province_graph.get_province("kijow").owner = "islam"
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("slavic_paganism", {})
	assert_eq(prog.get("slavic_sacred_groves_turns", -1), 0,
		"utrata kijow → reset (province at end of list — for...break iterates fully)")

func test_update_counters_resets_slavic_sacred_groves_when_axis_A_rises_to_31() -> void:
	var gs := _make_state("slavic_paganism")
	var rel: Religion = gs.get_religion("slavic_paganism")
	rel.axes["A"] = 31.0
	gs.victory_progress["slavic_paganism"] = {"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 0, "arabian_submission_turns": 0,
		"slavic_sacred_groves_turns": 5}
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("slavic_paganism", {})
	assert_eq(prog.get("slavic_sacred_groves_turns", -1), 0, "A=31 → reset (próg ostry ≤30)")

func test_update_counters_only_increments_slavic_sacred_groves_for_slavic_paganism() -> void:
	var gs := _make_state("islam")
	for pid: String in VictoryManager.SLAVIC_SACRED_GROVES_IDS:
		gs.province_graph.get_province(pid).owner = "islam"
	var rel: Religion = gs.get_religion("islam")
	rel.axes["A"] = 20.0
	rel.axes["B"] = 20.0
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("islam", {})
	assert_eq(prog.get("slavic_sacred_groves_turns", -1), 0,
		"Islam nie inkrementuje slavic_sacred_groves_turns (religion-scoped)")
