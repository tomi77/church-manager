extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func test_process_turn_advances_turn_counter() -> void:
	var tm := TurnManager.new()
	var gs := _make_state()
	tm.process_turn(gs)
	assert_eq(gs.current_turn, 2)

func test_passive_pressure_increases_on_adjacent_foreign_province() -> void:
	var tm := TurnManager.new()
	var gs := _make_state()
	var graph: ProvinceGraph = gs.province_graph
	var mezopotamia := graph.get_province("mezopotamia")
	var initial_zoroastr := mezopotamia.get_pressure("zoroastryzm")
	tm.process_turn(gs)
	assert_gt(mezopotamia.get_pressure("zoroastryzm"), initial_zoroastr)

func test_no_pressure_from_same_owner_neighbor() -> void:
	# persepolis (owner=zoroastryzm) sąsiaduje z persja (owner=zoroastryzm)
	# persepolis NIE powinna dostawać presji "zoroastryzm" — sąsiad to ta sama religia
	var tm := TurnManager.new()
	var gs := _make_state()
	var graph: ProvinceGraph = gs.province_graph
	var persepolis := graph.get_province("persepolis")
	var initial_zor := persepolis.get_pressure("zoroastryzm")
	tm.process_turn(gs)
	assert_eq(persepolis.get_pressure("zoroastryzm"), initial_zor)

func test_passive_pressure_foreign_religion_increases_on_border_province() -> void:
	var tm := TurnManager.new()
	var gs := _make_state()
	var graph: ProvinceGraph = gs.province_graph
	var persja := graph.get_province("persja")
	var initial_islam := persja.get_pressure("islam")
	tm.process_turn(gs)
	assert_gt(persja.get_pressure("islam"), initial_islam)

func test_holy_site_owner_gains_prestige() -> void:
	var tm := TurnManager.new()
	var gs := _make_state()
	var islam: Religion = gs.get_religion("religie_arabskie")
	var initial_prestige := islam.prestige
	tm.process_turn(gs)
	assert_gt(islam.prestige, initial_prestige)

func test_faction_tension_increases_when_axis_diverges() -> void:
	var tm := TurnManager.new()
	var gs := _make_state()
	var islam: Religion = gs.get_religion("islam")
	var sufis := islam.get_faction("sufis")
	islam.axes["A"] = 90.0
	var initial_tension := sufis.tension
	tm.process_turn(gs)
	assert_gt(sufis.tension, initial_tension)

func test_process_turn_decrements_scholar_mission_turns() -> void:
	var tm := TurnManager.new()
	var gs := _make_state()
	gs.scholar_missions.append({
		"from_religion_id": "islam",
		"to_religion_id": "chr_zachodnie",
		"turns_remaining": 2,
	})
	tm.process_turn(gs)
	assert_eq(gs.scholar_missions.size(), 1)
	assert_eq(gs.scholar_missions[0]["turns_remaining"], 1)

func test_process_turn_generates_idea_when_mission_completes() -> void:
	var tm := TurnManager.new()
	var gs := _make_state()
	var islam: Religion = gs.get_religion("islam")
	var chr: Religion = gs.get_religion("chr_zachodnie")
	# Pinuj wszystkie osie żeby A miała największą różnicę
	islam.axes["A"] = 20.0
	islam.axes["B"] = 50.0
	islam.axes["C"] = 50.0
	islam.axes["D"] = 50.0
	chr.axes["A"] = 80.0
	chr.axes["B"] = 50.0
	chr.axes["C"] = 50.0
	chr.axes["D"] = 50.0
	gs.scholar_missions.append({
		"from_religion_id": "islam",
		"to_religion_id": "chr_zachodnie",
		"turns_remaining": 1,
	})
	tm.process_turn(gs)
	assert_eq(gs.scholar_missions.size(), 0)
	assert_eq(gs.pending_ideas.size(), 1)
	assert_eq(gs.pending_ideas[0].axis, "A")

func test_process_turn_applies_believer_exodus_in_phase2() -> void:
	var tm := TurnManager.new()
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.factions[0].tension = 70.0
	var province: Province = gs.province_graph.get_province("mekka")
	assert_not_null(province)
	var pop_before: int = province.population
	gs.province_graph.get_province("mekka").owner = "islam"
	tm.process_turn(gs)
	assert_lt(gs.province_graph.get_province("mekka").population, pop_before)

func test_process_turn_no_exodus_in_phase1() -> void:
	var tm := TurnManager.new()
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	# Pinuj osie żeby _update_faction_tensions nie pchnęło frakcji do fazy 2
	rel.axes["A"] = 50.0
	rel.axes["B"] = 50.0
	rel.axes["C"] = 50.0
	rel.axes["D"] = 50.0
	rel.factions[0].tension = 50.0
	var province: Province = gs.province_graph.get_province("mekka")
	assert_not_null(province)
	gs.province_graph.get_province("mekka").owner = "islam"
	var pop_before: int = province.population
	tm.process_turn(gs)
	assert_eq(gs.province_graph.get_province("mekka").population, pop_before)

func test_process_turn_exodus_clamps_population_at_zero() -> void:
	var tm := TurnManager.new()
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.factions[0].tension = 70.0
	var province: Province = gs.province_graph.get_province("mekka")
	assert_not_null(province)
	province.population = 3
	province.owner = "islam"
	tm.process_turn(gs)
	assert_eq(province.population, 0)

const WarManagerScript := preload("res://scripts/engine/WarManager.gd")

func _pin_axes_tm(rel: Religion, a: float, b: float, c: float, d: float) -> void:
	rel.axes["A"] = a
	rel.axes["B"] = b
	rel.axes["C"] = c
	rel.axes["D"] = d

func test_process_turn_mobilizing_war_transitions_to_battling_after_2_turns() -> void:
	var tm := TurnManager.new()
	var wm := WarManagerScript.new()
	var gs := _make_state()
	var att: Religion = gs.get_religion("islam")
	_pin_axes_tm(att, 50.0, 50.0, 20.0, 75.0)
	att.prestige = 100
	var war := wm.declare_war("islam", "chr_wschodnie", "dzihad", gs)
	assert_eq(war.state, "MOBILIZING")
	tm.process_turn(gs)
	assert_eq(war.state, "MOBILIZING")
	assert_eq(war.turns_in_state, 1)
	tm.process_turn(gs)
	assert_eq(war.state, "BATTLING")
	assert_eq(war.turns_in_state, 0)

func test_process_turn_occupying_war_returns_to_battling_after_2_turns() -> void:
	var tm := TurnManager.new()
	var gs := _make_state()
	var war := War.new()
	war.attacker_id = "islam"
	war.defender_id = "chr_wschodnie"
	war.casus_belli = "dzihad"
	war.state = "OCCUPYING"
	war.turns_in_state = 0
	gs.active_wars.append(war)
	tm.process_turn(gs)
	assert_eq(war.state, "OCCUPYING")
	assert_eq(war.turns_in_state, 1)
	tm.process_turn(gs)
	assert_eq(war.state, "BATTLING")
	assert_eq(war.turns_in_state, 0)

func test_process_turn_increments_war_weariness_for_both_sides() -> void:
	var tm := TurnManager.new()
	var gs := _make_state()
	var att: Religion = gs.get_religion("islam")
	var def: Religion = gs.get_religion("chr_wschodnie")
	att.war_weariness = 10.0
	def.war_weariness = 5.0
	var war := War.new()
	war.attacker_id = "islam"
	war.defender_id = "chr_wschodnie"
	war.state = "BATTLING"
	gs.active_wars.append(war)
	tm.process_turn(gs)
	assert_almost_eq(att.war_weariness, 10.0 + WarManagerScript.WEARINESS_PER_TURN, 0.001)
	assert_almost_eq(def.war_weariness, 5.0 + WarManagerScript.WEARINESS_PER_TURN, 0.001)

func test_process_turn_force_peace_at_weariness_90_creates_defeat_event() -> void:
	var tm := TurnManager.new()
	var gs := _make_state()
	var att: Religion = gs.get_religion("islam")
	att.war_weariness = 88.0  # po +3 → 91, próg 90 przekroczony
	var war := War.new()
	war.attacker_id = "islam"
	war.defender_id = "chr_wschodnie"
	war.casus_belli = "dzihad"
	war.state = "BATTLING"
	gs.active_wars.append(war)
	tm.process_turn(gs)
	assert_eq(war.state, "ENDED")
	assert_eq(war.outcome, "LOSS")
	assert_eq(gs.active_wars.size(), 0)
	assert_eq(gs.pending_defeat_events.size(), 1)
	var ev: DefeatEvent = gs.pending_defeat_events[0]
	assert_eq(ev.religion_id, "islam")
	assert_eq(ev.opponent_id, "chr_wschodnie")

const DiplomacyManagerScript := preload("res://scripts/engine/DiplomacyManager.gd")

func test_turn_decays_tension_in_peace() -> void:
	var state := _make_state()
	var tm := TurnManager.new()
	var dm := DiplomacyManager.new()
	var rel := dm.get_or_create_relation(state, "islam", "chr_zachodnie")
	rel.military_tension = 20.0
	tm.process_turn(state)
	assert_almost_eq(rel.military_tension, 19.0, 0.001)

func test_turn_does_not_decay_tension_during_war() -> void:
	var state := _make_state()
	var tm := TurnManager.new()
	var dm := DiplomacyManager.new()
	var rel := dm.get_or_create_relation(state, "islam", "chr_zachodnie")
	rel.military_tension = 20.0
	var w := War.new()
	w.attacker_id = "islam"
	w.defender_id = "chr_zachodnie"
	w.state = "BATTLING"
	state.active_wars.append(w)
	tm.process_turn(state)
	assert_almost_eq(rel.military_tension, 20.0, 0.001)

func test_turn_evaluates_coalitions() -> void:
	var state := _make_state()
	var tm := TurnManager.new()
	var dm := DiplomacyManager.new()
	# 3 wojny islamu → threat=60, próg pokonany
	for ofiara: String in ["chr_zachodnie", "hinduizm", "buddyzm"]:
		var w := War.new()
		w.attacker_id = "islam"
		w.defender_id = ofiara
		w.state = "BATTLING"
		state.active_wars.append(w)
	for member: String in ["judaizm", "zoroastryzm"]:
		var rel := dm.get_or_create_relation(state, member, "islam")
		rel.military_tension = 50.0
	tm.process_turn(state)
	assert_eq(state.active_coalitions.size(), 1)
	assert_eq(state.active_coalitions[0].target_id, "islam")
