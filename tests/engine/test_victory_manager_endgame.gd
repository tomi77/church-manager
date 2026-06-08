extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func test_check_sets_outcome_when_universal_victory_met():
	# Używamy western_christianity — nie ma unique-victory w Plan 12, więc domination zadziała.
	var gs := _make_state()
	for p in gs.province_graph.all_provinces():
		if p.owner != "western_christianity":
			p.owner = "western_christianity"
	gs.victory_progress["western_christianity"] = {"domination_turns": VictoryManager.DOMINATION_TURNS_REQUIRED - 1, "prestige_hegemony_turns": 0}
	var vm := VictoryManager.new()
	vm.check(gs)
	assert_not_null(gs.game_outcome)
	assert_eq(gs.game_outcome.winner_id, "western_christianity")
	assert_eq(gs.game_outcome.reason, "domination")

func test_check_does_nothing_when_game_already_over():
	var gs := _make_state()
	var prior := GameOutcome.new()
	prior.winner_id = "judaism"
	prior.reason = "test_prior"
	gs.game_outcome = prior
	var vm := VictoryManager.new()
	vm.check(gs)
	# Outcome nie zmienił się
	assert_eq(gs.game_outcome.winner_id, "judaism")
	assert_eq(gs.game_outcome.reason, "test_prior")

func test_check_unique_victory_takes_precedence_over_universal():
	# Islam ma jednocześnie spełniony unique (Pełen Kalifat) i universal (Hegemonia)
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	for p in gs.province_graph.all_provinces():
		p.owner = "islam"
	rel.prestige = 1000
	for r in gs.all_religions():
		if r.id != "islam":
			r.prestige = 100
	gs.victory_progress["islam"] = {"domination_turns": 99, "prestige_hegemony_turns": 99}
	var vm := VictoryManager.new()
	vm.check(gs)
	assert_eq(gs.game_outcome.reason, "islam_caliphate", "unique ma pierwszeństwo")

func test_check_schism_grace_blocks_victory_for_schism_religion():
	var gs := _make_state()
	# Stwórz schism religię ręcznie
	var schism := Religion.new()
	schism.id = "test_schism"
	schism.parent_religion_id = "islam"
	schism.birth_turn = gs.current_turn
	schism.prestige = 10000
	gs.add_religion(schism)
	gs.victory_progress["test_schism"] = {"domination_turns": 99, "prestige_hegemony_turns": 99}
	var vm := VictoryManager.new()
	vm.check(gs)
	# Schism nie wygrywa (grace), ale ktoś inny też nie — gra trwa
	assert_null(gs.game_outcome)

func test_check_starting_religion_not_affected_by_schism_grace():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	assert_eq(rel.parent_religion_id, "")
	assert_eq(rel.birth_turn, 0)
	# Mimo birth_turn=0, current_turn=1, parent_religion_id="" → grace nie blokuje
	for p in gs.province_graph.all_provinces():
		p.owner = "islam"
	gs.victory_progress["islam"] = {"domination_turns": VictoryManager.DOMINATION_TURNS_REQUIRED, "prestige_hegemony_turns": 0}
	var vm := VictoryManager.new()
	vm.check(gs)
	assert_not_null(gs.game_outcome, "starting religion ma wygrywać natychmiast (no grace)")

func test_check_schism_religion_can_win_after_grace_period():
	var gs := _make_state()
	var schism := Religion.new()
	schism.id = "test_schism"
	schism.parent_religion_id = "islam"
	schism.birth_turn = 0  # narodzona w turze 0
	schism.prestige = 10000
	schism.ever_owned_province = true
	gs.add_religion(schism)
	# Ustaw current_turn na 15 (>10 od narodzin)
	gs.current_turn = 15
	# Daj jej prowincje
	for p in gs.province_graph.all_provinces():
		p.owner = "test_schism"
	gs.victory_progress["test_schism"] = {"domination_turns": VictoryManager.DOMINATION_TURNS_REQUIRED, "prestige_hegemony_turns": 0}
	var vm := VictoryManager.new()
	vm.check(gs)
	assert_not_null(gs.game_outcome)
	assert_eq(gs.game_outcome.winner_id, "test_schism")

func test_check_sets_defeated_at_turn_when_defeat_met():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.ever_owned_province = true
	for p in gs.province_graph.provinces_with_owner("islam"):
		p.owner = ""
	gs.defeat_progress["islam"] = {"zero_provinces_turns": VictoryManager.ELIMINATION_TURNS_REQUIRED - 1, "vassalage_turns": 0}
	gs.current_turn = 50
	var vm := VictoryManager.new()
	vm.check(gs)
	assert_eq(rel.defeated_at_turn, 50)

func test_check_turn_limit_triggers_ranking_winner():
	var gs := _make_state()
	gs.current_turn = VictoryManager.TURN_LIMIT
	# Wyzeruj wszystkie liczniki, ale ustaw różne prestiże
	for r: Religion in gs.all_religions():
		r.prestige = 100
	gs.get_religion("western_christianity").prestige = 1000
	gs.get_religion("islam").prestige = 500
	var vm := VictoryManager.new()
	vm.check(gs)
	assert_not_null(gs.game_outcome)
	assert_eq(gs.game_outcome.winner_id, "western_christianity")
	assert_eq(gs.game_outcome.reason, "turn_limit")

func test_check_turn_limit_tiebreak_alphabetical_by_id():
	var gs := _make_state()
	gs.current_turn = VictoryManager.TURN_LIMIT
	# Wszyscy z tym samym prestiżem
	for r: Religion in gs.all_religions():
		r.prestige = 100
	var vm := VictoryManager.new()
	vm.check(gs)
	# Najmniejszy id alfabetycznie pierwszy. Sprawdź który religion_id jest pierwszy:
	# arabian_paganism < buddhism < coptic_christianity < ... alfabetycznie pierwszy.
	# Z fixture: arabian_paganism, buddhism, coptic_christianity, eastern_christianity,
	# germanic_paganism, hinduism, islam, judaism, manichaeism, slavic_paganism,
	# western_christianity, zoroastrianism
	assert_eq(gs.game_outcome.winner_id, "arabian_paganism")

func test_check_turn_limit_excludes_defeated_from_ranking():
	var gs := _make_state()
	gs.current_turn = VictoryManager.TURN_LIMIT
	for r: Religion in gs.all_religions():
		r.prestige = 100
	# Wyklucz "arabian_paganism" przez defeat
	gs.get_religion("arabian_paganism").defeated_at_turn = 50
	var vm := VictoryManager.new()
	vm.check(gs)
	# Buddhism powinien być teraz pierwszy
	assert_eq(gs.game_outcome.winner_id, "buddhism")

func test_check_sets_end_turn_in_outcome():
	var gs := _make_state()
	gs.current_turn = 42
	for p in gs.province_graph.all_provinces():
		p.owner = "islam"
	gs.victory_progress["islam"] = {"domination_turns": VictoryManager.DOMINATION_TURNS_REQUIRED, "prestige_hegemony_turns": 0}
	var vm := VictoryManager.new()
	vm.check(gs)
	assert_eq(gs.game_outcome.end_turn, 42)

func test_check_includes_ranking_in_outcome():
	var gs := _make_state()
	for p in gs.province_graph.all_provinces():
		p.owner = "islam"
	gs.victory_progress["islam"] = {"domination_turns": VictoryManager.DOMINATION_TURNS_REQUIRED, "prestige_hegemony_turns": 0}
	var vm := VictoryManager.new()
	vm.check(gs)
	assert_gt(gs.game_outcome.ranking.size(), 0)
	# Pierwszy w rankingu to islam (ma najwięcej prestiżu po wygranej + provinces)
	var first_entry: Dictionary = gs.game_outcome.ranking[0]
	assert_true(first_entry.has("religion_id"))
	assert_true(first_entry.has("prestige"))
	assert_true(first_entry.has("provinces"))

func test_compute_ranking_sorts_desc_by_prestige_then_id_asc():
	var gs := _make_state()
	for r: Religion in gs.all_religions():
		r.prestige = 100
	gs.get_religion("zoroastrianism").prestige = 500
	gs.get_religion("islam").prestige = 500
	# Tie-break: islam < zoroastrianism alphabetically, więc islam pierwszy
	var vm := VictoryManager.new()
	var ranking := vm.compute_ranking(gs)
	assert_eq(ranking[0]["religion_id"], "islam")
	assert_eq(ranking[1]["religion_id"], "zoroastrianism")

func test_check_sets_defeated_reason_on_elimination():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.ever_owned_province = true
	for p in gs.province_graph.provinces_with_owner("islam"):
		p.owner = ""
	gs.defeat_progress["islam"] = {"zero_provinces_turns": VictoryManager.ELIMINATION_TURNS_REQUIRED - 1, "vassalage_turns": 0}
	gs.current_turn = 50
	var vm := VictoryManager.new()
	vm.check(gs)
	assert_eq(rel.defeated_at_turn, 50)
	assert_eq(rel.defeated_reason, "elimination")

func test_check_sets_defeated_reason_on_long_vassalage():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.ever_owned_province = true
	rel.suzerain_id = "western_christianity"
	gs.defeat_progress["islam"] = {"zero_provinces_turns": 0, "vassalage_turns": VictoryManager.VASSAL_DEFEAT_TURNS_REQUIRED - 1}
	gs.current_turn = 50
	var vm := VictoryManager.new()
	vm.check(gs)
	assert_eq(rel.defeated_at_turn, 50)
	assert_eq(rel.defeated_reason, "long_vassalage")

func test_check_sets_defeated_reason_on_total_schism():
	# Plan 13: gdy D3 triggeruje, defeated_reason == "total_schism"
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.ever_owned_province = true
	# Ustaw licznik tuż przed threshold + symulacja ostatniej tury (3 frakcje w fazie 3)
	gs.defeat_progress["islam"] = {"zero_provinces_turns": 0, "vassalage_turns": 0, "total_schism_turns": VictoryManager.SCHISM_TOTAL_TURNS_REQUIRED - 1}
	for f: Faction in rel.factions:
		f.tension = 90.0
	gs.current_turn = 80
	var vm := VictoryManager.new()
	vm.check(gs)
	assert_eq(rel.defeated_at_turn, 80)
	assert_eq(rel.defeated_reason, "total_schism")

func test_check_turn_limit_sets_outcome_even_when_all_religions_defeated():
	# Edge case: cała mapa pokonana w tej samej turze. Bez tego guardu gra wisiała
	# po TURN_LIMIT (TurnManager wywoływany w nieskończoność).
	var gs := _make_state()
	gs.current_turn = VictoryManager.TURN_LIMIT
	for r: Religion in gs.all_religions():
		r.defeated_at_turn = gs.current_turn
	var vm := VictoryManager.new()
	vm.check(gs)
	assert_not_null(gs.game_outcome, "turn_limit musi ustawić outcome nawet gdy ranking pusty")
	assert_eq(gs.game_outcome.reason, "turn_limit")
	assert_eq(gs.game_outcome.winner_id, "", "brak kandydatów → pusty winner_id (legalny stan)")
	assert_eq(gs.game_outcome.end_turn, VictoryManager.TURN_LIMIT)
