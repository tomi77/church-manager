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
