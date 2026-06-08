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
