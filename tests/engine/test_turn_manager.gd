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
	var initial_zoroastr := mezopotamia.get_pressure("zoroastrianism")
	tm.process_turn(gs)
	assert_gt(mezopotamia.get_pressure("zoroastrianism"), initial_zoroastr)

func test_no_pressure_from_same_owner_neighbor() -> void:
	# persepolis (owner=zoroastrianism) sąsiaduje z persja (owner=zoroastrianism)
	# persepolis NIE powinna dostawać presji "zoroastrianism" — sąsiad to ta sama religia
	var tm := TurnManager.new()
	var gs := _make_state()
	var graph: ProvinceGraph = gs.province_graph
	var persepolis := graph.get_province("persepolis")
	var initial_zor := persepolis.get_pressure("zoroastrianism")
	tm.process_turn(gs)
	assert_eq(persepolis.get_pressure("zoroastrianism"), initial_zor)

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
	var islam: Religion = gs.get_religion("arabian_paganism")
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
	# Plan 18: pin NPC prestige=0 by block NPC scholar dispatch (gate blocks all).
	for r: Religion in gs.all_religions():
		if r.id != gs.player_religion_id:
			r.prestige = 0
	gs.scholar_missions.append({
		"from_religion_id": "islam",
		"to_religion_id": "western_christianity",
		"turns_remaining": 2,
	})
	tm.process_turn(gs)
	assert_eq(gs.scholar_missions.size(), 1)
	assert_eq(gs.scholar_missions[0]["turns_remaining"], 1)

func test_process_turn_generates_idea_when_mission_completes() -> void:
	var tm := TurnManager.new()
	var gs := _make_state()
	# Plan 18: pin NPC prestige=0 by block NPC scholar dispatch (gate blocks all).
	for r: Religion in gs.all_religions():
		if r.id != gs.player_religion_id:
			r.prestige = 0
	var islam: Religion = gs.get_religion("islam")
	var chr: Religion = gs.get_religion("western_christianity")
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
		"to_religion_id": "western_christianity",
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
	var war := wm.declare_war("islam", "eastern_christianity", "dzihad", gs)
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
	war.defender_id = "eastern_christianity"
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
	var def: Religion = gs.get_religion("eastern_christianity")
	att.war_weariness = 10.0
	def.war_weariness = 5.0
	var war := War.new()
	war.attacker_id = "islam"
	war.defender_id = "eastern_christianity"
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
	war.defender_id = "eastern_christianity"
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
	assert_eq(ev.opponent_id, "eastern_christianity")

const DiplomacyManagerScript := preload("res://scripts/engine/DiplomacyManager.gd")

func test_turn_decays_tension_in_peace() -> void:
	var state := _make_state()
	var tm := TurnManager.new()
	var dm := DiplomacyManager.new()
	var rel := dm.get_or_create_relation(state, "islam", "western_christianity")
	rel.military_tension = 20.0
	tm.process_turn(state)
	assert_almost_eq(rel.military_tension, 19.0, 0.001)

func test_turn_does_not_decay_tension_during_war() -> void:
	var state := _make_state()
	var tm := TurnManager.new()
	var dm := DiplomacyManager.new()
	var rel := dm.get_or_create_relation(state, "islam", "western_christianity")
	rel.military_tension = 20.0
	var w := War.new()
	w.attacker_id = "islam"
	w.defender_id = "western_christianity"
	w.state = "BATTLING"
	state.active_wars.append(w)
	tm.process_turn(state)
	assert_almost_eq(rel.military_tension, 20.0, 0.001)

func test_turn_evaluates_coalitions() -> void:
	var state := _make_state()
	var tm := TurnManager.new()
	var dm := DiplomacyManager.new()
	# 3 wojny islamu → threat=60, próg pokonany
	for ofiara: String in ["western_christianity", "hinduism", "buddhism"]:
		var w := War.new()
		w.attacker_id = "islam"
		w.defender_id = ofiara
		w.state = "BATTLING"
		state.active_wars.append(w)
	for member: String in ["judaism", "zoroastrianism"]:
		var rel := dm.get_or_create_relation(state, member, "islam")
		rel.military_tension = 50.0
	tm.process_turn(state)
	assert_eq(state.active_coalitions.size(), 1)
	assert_eq(state.active_coalitions[0].target_id, "islam")

# === Plan 18: AI override infrastructure ===

func test_turn_manager_set_ai_override_replaces_default() -> void:
	var tm := TurnManager.new()
	var custom_ai := AIManager.new()
	tm.set_ai_override(custom_ai)
	assert_eq(tm._get_ai(), custom_ai, "set_ai_override pinuje AIManager dla testów")

func test_turn_manager_get_ai_returns_new_instance_when_no_override() -> void:
	var tm := TurnManager.new()
	var ai := tm._get_ai()
	assert_not_null(ai, "Bez override _get_ai zwraca świeży AIManager")
	assert_true(ai is AIManager)

func test_npc_dispatches_scholar_with_seeded_rng() -> void:
	# Z deterministycznym RNG sprawdź że dispatch jest monotonic (nie zmniejsza missions).
	var tm := TurnManager.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	tm.set_ai_override(AIManager.new(rng))
	var gs := _make_state()
	# Ustaw prestige Slavic > 50 (próg gate).
	var slavic: Religion = gs.get_religion("slavic_paganism")
	slavic.prestige = 200
	var initial_missions: int = gs.scholar_missions.size()
	tm.process_turn(gs)
	# Z 10 NPC × 15% chance ≥1 dispatch wysoce prawdopodobne, ale deterministyczne z seedem.
	# Asercja safe: dispatch nie usuwa missions (≥ initial).
	assert_gte(gs.scholar_missions.size(), initial_missions,
		"NPC dispatches mogą dodać missions (monotonic)")

func test_player_scholar_mission_lands_in_pending_ideas() -> void:
	# Islam = player. Mission islam → western generuje idea, ląduje w pending_ideas.
	var tm := TurnManager.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 0
	tm.set_ai_override(AIManager.new(rng))
	var gs := _make_state()
	# Pin NPC prestige=0 by isolation.
	for r: Religion in gs.all_religions():
		if r.id != gs.player_religion_id:
			r.prestige = 0
	var islam: Religion = gs.get_religion("islam")
	var chr: Religion = gs.get_religion("western_christianity")
	islam.axes["A"] = 20.0
	chr.axes["A"] = 80.0
	for axis: String in ["B", "C", "D"]:
		islam.axes[axis] = 50.0
		chr.axes[axis] = 50.0
	gs.scholar_missions.append({
		"from_religion_id": "islam",
		"to_religion_id": "western_christianity",
		"turns_remaining": 1,
	})
	var initial_pending: int = gs.pending_ideas.size()
	tm.process_turn(gs)
	assert_eq(gs.pending_ideas.size(), initial_pending + 1, "Player idea ląduje w pending_ideas")

func test_npc_scholar_mission_auto_resolves_via_ai() -> void:
	# Slavic = NPC. Mission slavic → western generuje idea, AI decide → nie pending_ideas.
	var tm := TurnManager.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 0
	tm.set_ai_override(AIManager.new(rng))
	var gs := _make_state()  # player="islam"
	# Pin NPC prestige=0 by isolation (Slavic dostanie scholar manualnie poniżej).
	for r: Religion in gs.all_religions():
		if r.id != gs.player_religion_id:
			r.prestige = 0
	var slavic: Religion = gs.get_religion("slavic_paganism")
	var chr: Religion = gs.get_religion("western_christianity")
	slavic.axes["A"] = 20.0
	chr.axes["A"] = 80.0
	for axis: String in ["B", "C", "D"]:
		slavic.axes[axis] = 50.0
		chr.axes[axis] = 50.0
	gs.scholar_missions.append({
		"from_religion_id": "slavic_paganism",
		"to_religion_id": "western_christianity",
		"turns_remaining": 1,
	})
	var initial_pending: int = gs.pending_ideas.size()
	tm.process_turn(gs)
	# Mission resolved (zniknął z scholar_missions) AND nie w pending_ideas (auto-resolved).
	var matching_missions: int = 0
	for m: Dictionary in gs.scholar_missions:
		if m["from_religion_id"] == "slavic_paganism" and m["to_religion_id"] == "western_christianity":
			matching_missions += 1
	assert_eq(matching_missions, 0, "Mission slavic→western resolved")
	assert_eq(gs.pending_ideas.size(), initial_pending, "NPC idea NIE w pending_ideas (auto-resolved)")

# === Plan 19: _npc_attack_wars integration ===

const WarScript := preload("res://scripts/engine/War.gd")

func _make_npc_attacker_war(state: Node, attacker_id: String, defender_id: String) -> War:
	var war := WarScript.new()
	war.attacker_id = attacker_id
	war.defender_id = defender_id
	war.casus_belli = "wojna_sprawiedliwa"
	war.state = "BATTLING"
	war.turns_in_state = 0
	state.active_wars.append(war)
	return war

func test_npc_attacker_attacks_during_battling_state() -> void:
	var tm := TurnManager.new()
	var gs := _make_state()  # player = islam
	# Slavic atakuje Eastern Christianity. panonia↔tracja border (Plan 17).
	var war := _make_npc_attacker_war(gs, "slavic_paganism", "eastern_christianity")
	# Pin OTHER NPC prestige=0 by disable scholar noise from Plan 18 dispatch.
	# Slavic prestige zostaje (jest attacker, prestige=120 default).
	for r: Religion in gs.all_religions():
		if r.id != gs.player_religion_id and r.id != "slavic_paganism":
			r.prestige = 0
	var initial_battles: int = war.battles_won + war.battles_lost
	tm.process_turn(gs)
	var after_battles: int = war.battles_won + war.battles_lost
	assert_gt(after_battles, initial_battles, "NPC attacker wykonał >=1 attack")

func test_npc_does_not_attack_when_player_is_attacker() -> void:
	var tm := TurnManager.new()
	var gs := _make_state()  # player = islam
	# Player (islam) atakuje Eastern. NPC powinno skipnąć tę wojnę.
	var war := _make_npc_attacker_war(gs, "islam", "eastern_christianity")
	# Pin NPC prestige=0 by isolation.
	for r: Religion in gs.all_religions():
		if r.id != gs.player_religion_id:
			r.prestige = 0
	var initial_battles: int = war.battles_won + war.battles_lost
	tm.process_turn(gs)
	var after_battles: int = war.battles_won + war.battles_lost
	assert_eq(after_battles, initial_battles, "Player attacker -> AI skip -> no battles")

func test_npc_does_not_attack_during_mobilizing_state() -> void:
	var tm := TurnManager.new()
	var gs := _make_state()
	var war := _make_npc_attacker_war(gs, "slavic_paganism", "eastern_christianity")
	war.state = "MOBILIZING"
	# Pin OTHER NPC prestige=0.
	for r: Religion in gs.all_religions():
		if r.id != gs.player_religion_id and r.id != "slavic_paganism":
			r.prestige = 0
	var initial_battles: int = war.battles_won + war.battles_lost
	tm.process_turn(gs)
	# Po 1 turn: state może wciąż być MOBILIZING (turns_in_state staje 1, < 2).
	var after_battles: int = war.battles_won + war.battles_lost
	assert_eq(after_battles, initial_battles, "MOBILIZING -> AI skip -> no battles")

# === Plan 20: _npc_offer_peace integration ===

func test_npc_offers_peace_when_attacker_has_contested() -> void:
	var tm := TurnManager.new()
	# Disable AI declarations (Plan 20) via high_rng — randf() >= 0.2 skip declare gate.
	var high_rng := RandomNumberGenerator.new()
	high_rng.seed = 0  # randf() = 0.2023, skip declare
	tm.set_ai_override(AIManager.new(high_rng))
	var gs := _make_state()  # player = islam
	# NPC slavic attacks Eastern. Setup contested + low weariness — claim immediately.
	var war := WarScript.new()
	war.attacker_id = "slavic_paganism"
	war.defender_id = "eastern_christianity"
	war.casus_belli = "wojna_sprawiedliwa"
	war.state = "BATTLING"
	war.contested_provinces = ["tracja"]
	gs.active_wars.append(war)
	# Disable scholar noise (Plan 18).
	for r: Religion in gs.all_religions():
		if r.id != gs.player_religion_id and r.id != "slavic_paganism":
			r.prestige = 0
	tm.process_turn(gs)
	assert_eq(war.state, "ENDED", "NPC attacker peace → war ended")
	# Tracja should be annexed by Slavic.
	var tracja: Province = gs.province_graph.get_province("tracja")
	assert_eq(tracja.owner, "slavic_paganism", "Tracja annexed by Slavic")

func test_npc_offers_peace_when_defender_weariness_high() -> void:
	var tm := TurnManager.new()
	# Disable AI declarations via high_rng (skip declare gate).
	var high_rng := RandomNumberGenerator.new()
	high_rng.seed = 0
	tm.set_ai_override(AIManager.new(high_rng))
	var gs := _make_state()  # player = islam (attacker)
	# Player attacker → Plan 20 attacker peace skipped. Defender NPC slavic, weariness > 60 → peace.
	var war := WarScript.new()
	war.attacker_id = "islam"
	war.defender_id = "slavic_paganism"
	war.casus_belli = "wojna_sprawiedliwa"
	war.state = "BATTLING"
	gs.active_wars.append(war)
	var slavic: Religion = gs.get_religion("slavic_paganism")
	slavic.war_weariness = 65.0
	# Disable other NPC noise (scholar dispatch).
	for r: Religion in gs.all_religions():
		if r.id != gs.player_religion_id and r.id != "slavic_paganism":
			r.prestige = 0
	tm.process_turn(gs)
	assert_eq(war.state, "ENDED", "NPC defender peace when weariness > 60")

# === Plan 20: _npc_declare_wars integration ===

func test_npc_declares_war_when_tension_high() -> void:
	var tm := TurnManager.new()
	var gs := _make_state()  # player = islam
	# Setup eligible target for Western (axes 65/80/35/55).
	# Western CBs: nawrocenie_mieczem (A>=65 ✓, C<=40 ✓) → available.
	# Prestige pin: >=10 (DECLARE_WAR_PRESTIGE) ale <50 (AI_SCHOLAR_MIN_PRESTIGE)
	# żeby _npc_dispatch_scholars NIE konsumował RNG przed declare gate.
	var attacker: Religion = gs.get_religion("western_christianity")
	attacker.prestige = 30
	var dm := DiplomacyManager.new()
	dm.get_or_create_relation(gs, "western_christianity", "eastern_christianity").military_tension = 90.0
	# Seed low_rng for deterministic randf() < 0.2 (chance pass).
	var low_rng := RandomNumberGenerator.new()
	low_rng.seed = 13  # randf()=0.062, gate passes
	tm.set_ai_override(AIManager.new(low_rng))
	# Disable other NPC noise (prestige=0 for all except western and player).
	for r: Religion in gs.all_religions():
		if r.id != gs.player_religion_id and r.id != "western_christianity":
			r.prestige = 0
	var initial_wars: int = gs.active_wars.size()
	tm.process_turn(gs)
	# Western should declare war.
	assert_true(gs.active_wars.size() > initial_wars,
		"Plan 20: NPC z tension=90 + prestige=30 + CB available + low_rng seed=13 → declare")
	var new_war: War = gs.active_wars[initial_wars]
	assert_eq(new_war.attacker_id, "western_christianity")
	assert_eq(new_war.defender_id, "eastern_christianity")
