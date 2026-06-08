extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func test_game_state_has_pending_ideas_array() -> void:
	var gs := _make_state()
	assert_not_null(gs.pending_ideas)
	assert_eq(gs.pending_ideas.size(), 0)

func test_game_state_has_scholar_missions_array() -> void:
	var gs := _make_state()
	assert_not_null(gs.scholar_missions)
	assert_eq(gs.scholar_missions.size(), 0)

func test_idea_has_correct_fields() -> void:
	var idea := Idea.new()
	idea.from_religion_id = "islam"
	idea.axis = "A"
	idea.delta = 5.0
	idea.description = "Nowa interpretacja"
	assert_eq(idea.from_religion_id, "islam")
	assert_eq(idea.axis, "A")
	assert_eq(idea.delta, 5.0)
	assert_eq(idea.description, "Nowa interpretacja")

const DoctrineManagerScript := preload("res://scripts/engine/DoctrineManager.gd")

func test_doctrine_manager_axis_A_high_unlocks_dogma_canon() -> void:
	var dm := DoctrineManagerScript.new()
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.axes["A"] = 76.0
	var actions := dm.available_threshold_actions(rel)
	assert_true(actions.has("dogma_canon"), "A>=75 powinno odblokować dogma_canon")

func test_doctrine_manager_axis_A_low_unlocks_mystical_revelation() -> void:
	var dm := DoctrineManagerScript.new()
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.axes["A"] = 24.0
	var actions := dm.available_threshold_actions(rel)
	assert_true(actions.has("mystical_revelation"), "A<=25 powinno odblokować mystical_revelation")

func test_doctrine_manager_axis_middle_no_threshold_actions() -> void:
	var dm := DoctrineManagerScript.new()
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.axes["A"] = 50.0
	rel.axes["B"] = 50.0
	rel.axes["C"] = 50.0
	rel.axes["D"] = 50.0
	var actions := dm.available_threshold_actions(rel)
	assert_eq(actions.size(), 0)

func test_doctrine_manager_axis_C_high_unlocks_ecumenism_and_obrzad() -> void:
	var dm := DoctrineManagerScript.new()
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.axes["C"] = 80.0
	var actions := dm.available_threshold_actions(rel)
	assert_true(actions.has("ecumenism"))
	assert_true(actions.has("fusion_rite"))

func test_doctrine_manager_axis_C_low_unlocks_inquisition_and_anathema() -> void:
	var dm := DoctrineManagerScript.new()
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.axes["C"] = 20.0
	var actions := dm.available_threshold_actions(rel)
	assert_true(actions.has("inquisition"))
	assert_true(actions.has("anathema"))

func test_call_sobor_shifts_axis_and_costs_prestige() -> void:
	var dm := DoctrineManagerScript.new()
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.prestige = 50
	var axis_before := rel.get_axis("A")
	var ok: bool = dm.call_sobor(rel, "A", 10.0)
	assert_true(ok)
	assert_eq(rel.prestige, 50 - DoctrineManagerScript.SOBOR_PRESTIGE_COST)
	assert_almost_eq(rel.get_axis("A"), axis_before + 10.0, 0.001)

func test_call_sobor_fails_if_not_enough_prestige() -> void:
	var dm := DoctrineManagerScript.new()
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.prestige = 10
	var axis_before := rel.get_axis("A")
	var ok: bool = dm.call_sobor(rel, "A", 10.0)
	assert_false(ok)
	assert_almost_eq(rel.get_axis("A"), axis_before, 0.001)
	assert_eq(rel.prestige, 10)

func test_sobor_increases_faction_tension() -> void:
	var dm := DoctrineManagerScript.new()
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.prestige = 100
	var tension_before := rel.factions[0].tension
	dm.call_sobor(rel, "A", 5.0)
	assert_almost_eq(rel.factions[0].tension, tension_before + DoctrineManagerScript.FACTION_TENSION_FROM_SOBOR, 0.001)

func test_issue_edict_shifts_axis_within_cap() -> void:
	var dm := DoctrineManagerScript.new()
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.prestige = 50
	var axis_before := rel.get_axis("B")
	var ok: bool = dm.issue_edict(rel, "B", 10.0)
	assert_true(ok)
	assert_eq(rel.prestige, 50 - DoctrineManagerScript.EDICT_PRESTIGE_COST)
	assert_almost_eq(rel.get_axis("B"), axis_before + DoctrineManagerScript.EDICT_MAX_DELTA, 0.001)

func test_issue_edict_fails_if_not_enough_prestige() -> void:
	var dm := DoctrineManagerScript.new()
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.prestige = 5
	var axis_before := rel.get_axis("B")
	var ok: bool = dm.issue_edict(rel, "B", 5.0)
	assert_false(ok)
	assert_almost_eq(rel.get_axis("B"), axis_before, 0.001)
	assert_eq(rel.prestige, 5)

func test_issue_edict_clamps_negative_delta() -> void:
	var dm := DoctrineManagerScript.new()
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.prestige = 50
	var axis_before := rel.get_axis("B")
	var ok: bool = dm.issue_edict(rel, "B", -10.0)
	assert_true(ok)
	assert_almost_eq(rel.get_axis("B"), axis_before - DoctrineManagerScript.EDICT_MAX_DELTA, 0.001)

func test_dispatch_scholar_adds_mission_to_state() -> void:
	var dm := DoctrineManagerScript.new()
	var gs := _make_state()
	dm.dispatch_scholar(gs, "islam", "western_christianity")
	assert_eq(gs.scholar_missions.size(), 1)
	assert_eq(gs.scholar_missions[0]["from_religion_id"], "islam")
	assert_eq(gs.scholar_missions[0]["to_religion_id"], "western_christianity")
	assert_eq(gs.scholar_missions[0]["turns_remaining"], DoctrineManagerScript.SCHOLAR_MISSION_TURNS)

func test_generate_idea_returns_idea_when_axes_differ() -> void:
	var dm := DoctrineManagerScript.new()
	var gs := _make_state()
	var islam: Religion = gs.get_religion("islam")
	var chr: Religion = gs.get_religion("western_christianity")
	# Pinuj wszystkie osie żeby A miała największą różnicę (uniknięcie zależności od JSON)
	islam.axes["A"] = 30.0
	islam.axes["B"] = 50.0
	islam.axes["C"] = 50.0
	islam.axes["D"] = 50.0
	chr.axes["A"] = 70.0
	chr.axes["B"] = 50.0
	chr.axes["C"] = 50.0
	chr.axes["D"] = 50.0
	var idea: Idea = dm.generate_idea("islam", "western_christianity", gs)
	assert_not_null(idea)
	assert_eq(idea.from_religion_id, "islam")
	assert_eq(idea.axis, "A")
	assert_gt(idea.delta, 0.0)
	assert_lte(idea.delta, DoctrineManagerScript.IDEA_MAX_DELTA)

func test_generate_idea_returns_null_when_axes_too_similar() -> void:
	var dm := DoctrineManagerScript.new()
	var gs := _make_state()
	var islam: Religion = gs.get_religion("islam")
	var chr: Religion = gs.get_religion("western_christianity")
	islam.axes["A"] = 50.0
	chr.axes["A"] = 55.0
	islam.axes["B"] = 50.0
	chr.axes["B"] = 55.0
	islam.axes["C"] = 50.0
	chr.axes["C"] = 55.0
	islam.axes["D"] = 50.0
	chr.axes["D"] = 55.0
	var idea: Idea = dm.generate_idea("islam", "western_christianity", gs)
	assert_null(idea)

func test_accept_idea_shifts_axis() -> void:
	var dm := DoctrineManagerScript.new()
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	var idea := Idea.new()
	idea.from_religion_id = "western_christianity"
	idea.axis = "A"
	idea.delta = 5.0
	gs.pending_ideas.append(idea)
	var axis_before := rel.get_axis("A")
	dm.accept_idea(idea, rel, gs)
	assert_almost_eq(rel.get_axis("A"), axis_before + 5.0, 0.001)
	assert_eq(gs.pending_ideas.size(), 0)

func test_reject_idea_removes_from_pending() -> void:
	var dm := DoctrineManagerScript.new()
	var gs := _make_state()
	var idea := Idea.new()
	idea.axis = "A"
	idea.delta = 5.0
	gs.pending_ideas.append(idea)
	dm.reject_idea(idea, gs)
	assert_eq(gs.pending_ideas.size(), 0)

func test_generate_idea_delta_negative_when_to_axis_lower() -> void:
	var dm := DoctrineManagerScript.new()
	var gs := _make_state()
	var islam: Religion = gs.get_religion("islam")
	var chr: Religion = gs.get_religion("western_christianity")
	islam.axes["A"] = 70.0
	islam.axes["B"] = 50.0
	islam.axes["C"] = 50.0
	islam.axes["D"] = 50.0
	chr.axes["A"] = 30.0
	chr.axes["B"] = 50.0
	chr.axes["C"] = 50.0
	chr.axes["D"] = 50.0
	var idea: Idea = dm.generate_idea("islam", "western_christianity", gs)
	assert_not_null(idea)
	assert_eq(idea.axis, "A")
	assert_lt(idea.delta, 0.0)
