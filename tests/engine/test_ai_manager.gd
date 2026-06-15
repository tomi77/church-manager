extends GutTest

const AIManagerScript := preload("res://scripts/engine/AIManager.gd")

# === Plan 18: AIManager skeleton ===

func test_ai_manager_has_plan18_constants() -> void:
	assert_eq(AIManager.AI_SCHOLAR_MIN_PRESTIGE, 50)
	assert_almost_eq(AIManager.AI_SCHOLAR_DISPATCH_CHANCE, 0.15, 0.001)

func test_ai_manager_init_creates_rng_when_no_injection() -> void:
	var ai := AIManagerScript.new()
	assert_not_null(ai.rng, "AIManager bez injection tworzy własny rng")

func test_ai_manager_init_uses_injected_rng() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var ai := AIManagerScript.new(rng)
	assert_eq(ai.rng, rng, "AIManager używa injected rng")

# === Plan 18: decide_accept_idea ===

const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state(player_id: String = "islam") -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize(player_id, religions, graph)
	return gs

func _make_idea(from_id: String, axis: String, delta: float) -> Idea:
	var idea := Idea.new()
	idea.from_religion_id = from_id
	idea.axis = axis
	idea.delta = delta
	return idea

func test_decide_accepts_when_dominant_faction_supports_shift() -> void:
	# Slavic + axis A delta -3: Wolchwi (0.45, A-1) supports → net +0.45 → accept.
	var gs := _make_state()
	var rel: Religion = gs.get_religion("slavic_paganism")
	var idea := _make_idea("islam", "A", -3.0)
	var ai := AIManagerScript.new()
	assert_true(ai.decide_accept_idea(rel, idea), "Wolchwi support A↓ → accept")

func test_decide_rejects_when_dominant_faction_opposes_shift() -> void:
	# Slavic + axis A delta +5: Wolchwi opposes → reject.
	var gs := _make_state()
	var rel: Religion = gs.get_religion("slavic_paganism")
	var idea := _make_idea("islam", "A", 5.0)
	var ai := AIManagerScript.new()
	assert_false(ai.decide_accept_idea(rel, idea), "Wolchwi oppose A↑ → reject")

func test_decide_rejects_on_zero_net_support() -> void:
	# Slavic z wyzerowanymi axis_preferences — net_support == 0 → reject (conservative).
	var gs := _make_state()
	var rel: Religion = gs.get_religion("slavic_paganism")
	for f: Faction in rel.factions:
		f.axis_preferences = []
	var idea := _make_idea("islam", "A", 5.0)
	var ai := AIManagerScript.new()
	assert_false(ai.decide_accept_idea(rel, idea), "Zero net_support → reject")

func test_decide_uses_faction_influence_weighting() -> void:
	# 1 supporter (0.20, A+1) + 1 opposer (0.40, A-1) + Idea A delta +5.
	# shift=+1. Supporter: 0.20×1×1=+0.20. Opposer: 0.40×-1×1=-0.40. Net=-0.20 → reject.
	var gs := _make_state()
	var rel: Religion = gs.get_religion("slavic_paganism")
	rel.factions = []
	var f1 := Faction.new()
	f1.id = "supporter"
	f1.influence = 0.20
	f1.axis_preferences = [{"axis": "A", "direction": 1}]
	var f2 := Faction.new()
	f2.id = "opposer"
	f2.influence = 0.40
	f2.axis_preferences = [{"axis": "A", "direction": -1}]
	rel.factions = [f1, f2]
	var idea := _make_idea("islam", "A", 5.0)
	var ai := AIManagerScript.new()
	assert_false(ai.decide_accept_idea(rel, idea), "Większa influence opposera → reject")

func test_decide_rejects_religion_with_no_factions() -> void:
	var gs := _make_state()
	var rel: Religion = gs.get_religion("slavic_paganism")
	rel.factions = []
	var idea := _make_idea("islam", "A", 5.0)
	var ai := AIManagerScript.new()
	assert_false(ai.decide_accept_idea(rel, idea), "Brak frakcji → reject")

# === Plan 18: should_dispatch_scholar ===

func _seeded_rng(seed_val: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	return rng

func test_should_not_dispatch_when_defeated() -> void:
	var gs := _make_state()
	var rel: Religion = gs.get_religion("slavic_paganism")
	rel.defeated_at_turn = 50
	rel.prestige = 200
	var ai := AIManagerScript.new(_seeded_rng(0))
	assert_false(ai.should_dispatch_scholar(rel))

func test_should_not_dispatch_when_prestige_below_min() -> void:
	var gs := _make_state()
	var rel: Religion = gs.get_religion("slavic_paganism")
	rel.prestige = 49  # próg ostry: AI_SCHOLAR_MIN_PRESTIGE=50.
	var ai := AIManagerScript.new(_seeded_rng(0))
	assert_false(ai.should_dispatch_scholar(rel))

func test_should_dispatch_deterministic_with_seeded_rng() -> void:
	var gs := _make_state()
	var rel: Religion = gs.get_religion("slavic_paganism")
	rel.prestige = 100
	var ai_a := AIManagerScript.new(_seeded_rng(1))
	var ai_b := AIManagerScript.new(_seeded_rng(1))
	assert_eq(ai_a.should_dispatch_scholar(rel), ai_b.should_dispatch_scholar(rel),
		"Identyczne seedy → identyczne decyzje (deterministic)")

# === Plan 18: choose_scholar_target ===

func test_choose_scholar_target_returns_non_self() -> void:
	var gs := _make_state()
	var rel: Religion = gs.get_religion("slavic_paganism")
	var ai := AIManagerScript.new(_seeded_rng(42))
	var target := ai.choose_scholar_target(gs, rel)
	assert_ne(target, "")
	assert_ne(target, "slavic_paganism", "Target nie może być self")

func test_choose_scholar_target_skips_defeated_religions() -> void:
	var gs := _make_state()
	for r: Religion in gs.all_religions():
		if r.id != "slavic_paganism" and r.id != "islam":
			r.defeated_at_turn = 1
	var rel: Religion = gs.get_religion("slavic_paganism")
	var ai := AIManagerScript.new(_seeded_rng(42))
	var target := ai.choose_scholar_target(gs, rel)
	assert_eq(target, "islam", "Jedyny żywy non-self target to islam")

func test_choose_scholar_target_returns_empty_when_no_candidates() -> void:
	var gs := _make_state()
	for r: Religion in gs.all_religions():
		if r.id != "slavic_paganism":
			r.defeated_at_turn = 1
	var rel: Religion = gs.get_religion("slavic_paganism")
	var ai := AIManagerScript.new(_seeded_rng(42))
	var target := ai.choose_scholar_target(gs, rel)
	assert_eq(target, "", "Brak żywych kandydatów → empty string")

# === Plan 19: should_attack_in_war ===

const WarScript := preload("res://scripts/engine/War.gd")

func _make_war(attacker_id: String, defender_id: String, war_state: String = "BATTLING") -> War:
	var war := WarScript.new()
	war.attacker_id = attacker_id
	war.defender_id = defender_id
	war.casus_belli = "wojna_sprawiedliwa"
	war.state = war_state
	return war

func test_should_attack_in_war_returns_true_when_battling() -> void:
	var gs := _make_state()
	var rel: Religion = gs.get_religion("slavic_paganism")
	var war := _make_war("slavic_paganism", "eastern_christianity", "BATTLING")
	var ai := AIManagerScript.new()
	assert_true(ai.should_attack_in_war(rel, war), "BATTLING + alive → true")

func test_should_attack_in_war_returns_false_when_not_battling() -> void:
	var gs := _make_state()
	var rel: Religion = gs.get_religion("slavic_paganism")
	var ai := AIManagerScript.new()
	for non_battling: String in ["MOBILIZING", "OCCUPYING", "ENDED"]:
		var war := _make_war("slavic_paganism", "eastern_christianity", non_battling)
		assert_false(ai.should_attack_in_war(rel, war), "state %s → false" % non_battling)

func test_should_attack_in_war_returns_false_when_attacker_defeated() -> void:
	var gs := _make_state()
	var rel: Religion = gs.get_religion("slavic_paganism")
	rel.defeated_at_turn = 50
	var war := _make_war("slavic_paganism", "eastern_christianity", "BATTLING")
	var ai := AIManagerScript.new()
	assert_false(ai.should_attack_in_war(rel, war), "Defeated attacker → false")

# === Plan 19: choose_attack_target ===

func test_choose_attack_target_picks_border_adjacent_when_available() -> void:
	# Slavic atakuje Eastern. Tracja jest jedyną Eastern border-adjacent do panonia (Slavic).
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("slavic_paganism")
	var ai := AIManagerScript.new(_seeded_rng(42))
	var target := ai.choose_attack_target(gs, attacker, "eastern_christianity")
	assert_eq(target, "tracja", "Tracja border-adjacent do panonia (Slavic)")

func test_choose_attack_target_falls_back_to_random_when_no_border() -> void:
	# Slavic atakuje Islam (mezopotamia — non-adjacent do Slavic).
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("slavic_paganism")
	var ai := AIManagerScript.new(_seeded_rng(42))
	var target := ai.choose_attack_target(gs, attacker, "islam")
	assert_eq(target, "mezopotamia", "Fallback: jedyna Islam province")

func test_choose_attack_target_returns_empty_when_defender_has_no_provinces() -> void:
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("slavic_paganism")
	# Wyzeruj Islam — ma tylko mezopotamia.
	gs.province_graph.get_province("mezopotamia").owner = ""
	var ai := AIManagerScript.new(_seeded_rng(42))
	var target := ai.choose_attack_target(gs, attacker, "islam")
	assert_eq(target, "", "Defender 0 provinces → empty target")

func test_choose_attack_target_skips_non_defender_provinces() -> void:
	# Target MUSI być defender province (eastern_christianity).
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("slavic_paganism")
	var ai := AIManagerScript.new(_seeded_rng(42))
	var target := ai.choose_attack_target(gs, attacker, "eastern_christianity")
	var target_prov: Province = gs.province_graph.get_province(target)
	assert_not_null(target_prov)
	assert_eq(target_prov.owner, "eastern_christianity", "Target = defender province")

# === Plan 20: stałe + should_declare_war ===

func test_plan20_constants_exist() -> void:
	assert_almost_eq(AIManager.AI_WAR_TENSION_THRESHOLD, 70.0, 0.001)
	assert_almost_eq(AIManager.AI_WAR_DECLARE_CHANCE, 0.2, 0.001)
	assert_almost_eq(AIManager.AI_PEACE_ATTACKER_WEARINESS_GIVE_UP, 70.0, 0.001)
	assert_almost_eq(AIManager.AI_PEACE_DEFENDER_WEARINESS, 60.0, 0.001)

func test_should_declare_war_true_when_all_conditions_met() -> void:
	# Islam axes (A=70, B=65, C=30, D=75) — TYLKO nawrocenie_mieczem available (C<=40 ✓, A>=65 ✓).
	# Krucjata fails (C>25), dzihad fails (C>25), wojna_sprawiedliwa fails (D>50).
	# 1 CB wystarcza dla declare → happy path.
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("islam")
	attacker.prestige = 50
	var defender: Religion = gs.get_religion("eastern_christianity")
	var dm := DiplomacyManager.new()
	var rel := dm.get_or_create_relation(gs, "islam", "eastern_christianity")
	rel.military_tension = 80.0
	var ai := AIManagerScript.new()
	assert_true(ai.should_declare_war(attacker, defender, gs), "Islam→Eastern: tension 80 + prestige 50 + nawrocenie_mieczem → true")

func test_should_declare_war_false_when_self() -> void:
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("islam")
	var ai := AIManagerScript.new()
	assert_false(ai.should_declare_war(attacker, attacker, gs))

func test_should_declare_war_false_when_prestige_below_required() -> void:
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("islam")
	attacker.prestige = 5  # < DECLARE_WAR_PRESTIGE=10
	var defender: Religion = gs.get_religion("eastern_christianity")
	var dm := DiplomacyManager.new()
	dm.get_or_create_relation(gs, "islam", "eastern_christianity").military_tension = 80.0
	var ai := AIManagerScript.new()
	assert_false(ai.should_declare_war(attacker, defender, gs))

func test_should_declare_war_false_when_already_at_war() -> void:
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("islam")
	attacker.prestige = 50
	var defender: Religion = gs.get_religion("eastern_christianity")
	# Setup existing war.
	var existing := WarScript.new()
	existing.attacker_id = "islam"
	existing.defender_id = "eastern_christianity"
	existing.state = "BATTLING"
	gs.active_wars.append(existing)
	var dm := DiplomacyManager.new()
	dm.get_or_create_relation(gs, "islam", "eastern_christianity").military_tension = 80.0
	var ai := AIManagerScript.new()
	assert_false(ai.should_declare_war(attacker, defender, gs))

func test_should_declare_war_false_when_allied() -> void:
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("islam")
	attacker.prestige = 50
	var defender: Religion = gs.get_religion("eastern_christianity")
	var dm := DiplomacyManager.new()
	var rel := dm.get_or_create_relation(gs, "islam", "eastern_christianity")
	rel.military_tension = 80.0
	rel.alliance_active = true
	var ai := AIManagerScript.new()
	assert_false(ai.should_declare_war(attacker, defender, gs))

func test_should_declare_war_false_when_vassal_relation() -> void:
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("islam")
	attacker.prestige = 50
	var defender: Religion = gs.get_religion("eastern_christianity")
	defender.suzerain_id = "islam"  # defender is vassal of attacker
	var dm := DiplomacyManager.new()
	dm.get_or_create_relation(gs, "islam", "eastern_christianity").military_tension = 80.0
	var ai := AIManagerScript.new()
	assert_false(ai.should_declare_war(attacker, defender, gs))

func test_should_declare_war_false_when_same_coalition() -> void:
	# AC #8: coalition guard. Setup: Islam + Eastern w tej samej coalition.
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("islam")
	attacker.prestige = 50
	var defender: Religion = gs.get_religion("eastern_christianity")
	var dm := DiplomacyManager.new()
	dm.get_or_create_relation(gs, "islam", "eastern_christianity").military_tension = 80.0
	var coalition := Coalition.new()
	coalition.members = ["islam", "eastern_christianity"]
	gs.active_coalitions.append(coalition)
	var ai := AIManagerScript.new()
	assert_false(ai.should_declare_war(attacker, defender, gs))

func test_should_declare_war_false_when_tension_below_threshold() -> void:
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("islam")
	attacker.prestige = 50
	var defender: Religion = gs.get_religion("eastern_christianity")
	var dm := DiplomacyManager.new()
	dm.get_or_create_relation(gs, "islam", "eastern_christianity").military_tension = 69.0  # próg ostry 70
	var ai := AIManagerScript.new()
	assert_false(ai.should_declare_war(attacker, defender, gs))

func test_choose_war_target_returns_empty_when_rng_above_threshold() -> void:
	# Seeded RNG seed=0 → first randf()=0.2023 (>= AI_WAR_DECLARE_CHANCE=0.2) → {} regardless of eligible targets.
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("islam")
	attacker.prestige = 50
	# Setup eligible target (tension 80) — to prove RNG gate blocks even with available target.
	var dm := DiplomacyManager.new()
	dm.get_or_create_relation(gs, "islam", "eastern_christianity").military_tension = 80.0
	var high_rng := RandomNumberGenerator.new()
	high_rng.seed = 0
	var ai := AIManagerScript.new(high_rng)
	var target := ai.choose_war_target(gs, attacker)
	assert_eq(target.size(), 0, "RNG >= 0.2 → choose_war_target returns {}")

func test_choose_war_target_picks_highest_tension() -> void:
	# Setup: Islam with 2 eligible targets — Eastern (tension 80) and Western (tension 90).
	# Seeded RNG seed=13 → first randf()=0.0621 (< 0.2) — gate passes.
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("islam")
	attacker.prestige = 50
	var dm := DiplomacyManager.new()
	dm.get_or_create_relation(gs, "islam", "eastern_christianity").military_tension = 80.0
	dm.get_or_create_relation(gs, "islam", "western_christianity").military_tension = 90.0
	var low_rng := RandomNumberGenerator.new()
	low_rng.seed = 13
	var ai := AIManagerScript.new(low_rng)
	var target := ai.choose_war_target(gs, attacker)
	assert_false(target.is_empty(), "RNG seed=13 (randf=0.062) → gate passes, target chosen")
	assert_eq(target["defender_id"], "western_christianity", "Higher tension wins (90 vs 80)")
	# CB for Islam is nawrocenie_mieczem (A=70>=65, C=30<=40). Other 3 CBs fail.
	assert_eq(target["cb"], "nawrocenie_mieczem", "Only available CB for Islam axes is nawrocenie_mieczem")

func test_should_declare_war_false_when_no_cb_available() -> void:
	# Slavic ma profile A=20, B=25 — żaden z 4 standardowych CBs nie pasuje. Defender bez heresy + bez rewanz → no CB.
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("slavic_paganism")
	attacker.prestige = 50
	var defender: Religion = gs.get_religion("eastern_christianity")
	var dm := DiplomacyManager.new()
	dm.get_or_create_relation(gs, "slavic_paganism", "eastern_christianity").military_tension = 80.0
	var ai := AIManagerScript.new()
	assert_false(ai.should_declare_war(attacker, defender, gs))
