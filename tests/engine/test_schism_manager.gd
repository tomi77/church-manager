extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")
const SchismManagerScript := preload("res://scripts/engine/SchismManager.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func _get_faction(gs: Node) -> Faction:
	return gs.get_religion("islam").factions[0]

func test_schism_phase_0_when_tension_low() -> void:
	var sm := SchismManagerScript.new()
	var faction := _get_faction(_make_state())
	faction.tension = 20.0
	assert_eq(sm.get_phase(faction), 0)

func test_schism_phase_1_when_tension_above_40() -> void:
	var sm := SchismManagerScript.new()
	var faction := _get_faction(_make_state())
	faction.tension = 45.0
	assert_eq(sm.get_phase(faction), 1)

func test_schism_phase_2_when_tension_above_65() -> void:
	var sm := SchismManagerScript.new()
	var faction := _get_faction(_make_state())
	faction.tension = 70.0
	assert_eq(sm.get_phase(faction), 2)

func test_schism_phase_3_when_tension_above_85() -> void:
	var sm := SchismManagerScript.new()
	var faction := _get_faction(_make_state())
	faction.tension = 90.0
	assert_eq(sm.get_phase(faction), 3)

func test_stlumienie_reduces_tension_and_influence() -> void:
	var sm := SchismManagerScript.new()
	var faction := _get_faction(_make_state())
	faction.tension = 60.0
	faction.influence = 0.5
	sm.respond_stlumienie(faction)
	assert_almost_eq(faction.tension, 60.0 - SchismManagerScript.TENSION_REDUCE_STLUM, 0.001)
	assert_almost_eq(faction.influence, 0.5 - SchismManagerScript.INFLUENCE_REDUCE_STLUM, 0.001)

func test_dialog_reduces_tension_less() -> void:
	var sm := SchismManagerScript.new()
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	var faction := rel.factions[0]
	faction.tension = 60.0
	sm.respond_dialoguj(faction, rel)
	assert_almost_eq(faction.tension, 60.0 - SchismManagerScript.TENSION_REDUCE_DIALOGUJ, 0.001)

func test_dialog_shifts_axis_toward_faction_preference() -> void:
	var sm := SchismManagerScript.new()
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	var faction := rel.factions[0]  # ulema: axis_preferences = [{axis: A, direction: 1}, {axis: B, direction: 1}]
	faction.tension = 60.0
	assert_true(faction.axis_preferences.size() > 0, "Test wymaga frakcji z axis_preferences — ulema powinno je mieć")
	var pref: Dictionary = faction.axis_preferences[0]
	var axis: String = pref.get("axis", "A")
	var axis_before := rel.get_axis(axis)
	sm.respond_dialoguj(faction, rel)
	assert_ne(rel.get_axis(axis), axis_before)

func test_koncesja_reduces_tension_most() -> void:
	var sm := SchismManagerScript.new()
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.prestige = 50
	var faction := rel.factions[0]
	faction.tension = 70.0
	var ok := sm.respond_koncesja(faction, rel)
	assert_true(ok)
	assert_almost_eq(faction.tension, 70.0 - SchismManagerScript.TENSION_REDUCE_KONCESJA, 0.001)
	assert_eq(rel.prestige, 50 - SchismManagerScript.KONCESJA_PRESTIGE_COST)

func test_koncesja_fails_without_prestige() -> void:
	var sm := SchismManagerScript.new()
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.prestige = 5
	var faction := rel.factions[0]
	faction.tension = 70.0
	var ok := sm.respond_koncesja(faction, rel)
	assert_false(ok)
	assert_almost_eq(faction.tension, 70.0, 0.001)
	assert_eq(rel.prestige, 5)

func test_stlumienie_clamps_at_zero() -> void:
	var sm := SchismManagerScript.new()
	var faction := _get_faction(_make_state())
	faction.tension = 0.0
	faction.influence = 0.0
	sm.respond_stlumienie(faction)
	assert_almost_eq(faction.tension, 0.0, 0.001)
	assert_almost_eq(faction.influence, 0.0, 0.001)

func test_dialog_handles_empty_axis_preferences() -> void:
	var sm := SchismManagerScript.new()
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	var faction := rel.factions[0]
	faction.axis_preferences.clear()
	faction.tension = 60.0
	sm.respond_dialoguj(faction, rel)
	assert_almost_eq(faction.tension, 60.0 - SchismManagerScript.TENSION_REDUCE_DIALOGUJ, 0.001)

func test_trigger_schism_creates_new_religion() -> void:
	var sm := SchismManagerScript.new()
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	var faction := rel.factions[0]
	faction.tension = 90.0
	faction.influence = 0.5
	var count_before: int = gs.all_religions().size()
	var new_rel := sm.trigger_schism(faction, rel, gs)
	assert_not_null(new_rel)
	assert_ne(new_rel.id, rel.id)
	assert_eq(gs.all_religions().size(), count_before + 1)

func test_trigger_schism_requires_min_influence() -> void:
	var sm := SchismManagerScript.new()
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	var faction := rel.factions[0]
	faction.tension = 90.0
	faction.influence = 0.10
	var new_rel := sm.trigger_schism(faction, rel, gs)
	assert_null(new_rel)

func test_trigger_schism_new_religion_has_offset_axes() -> void:
	var sm := SchismManagerScript.new()
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	var faction := rel.factions[0]  # ulema: axis_preferences = [{axis: A, direction: 1}, {axis: B, direction: 1}]
	assert_true(faction.axis_preferences.size() > 0, "Test wymaga frakcji z axis_preferences")
	faction.tension = 90.0
	faction.influence = 0.5
	var parent_axis_A := rel.get_axis("A")
	var new_rel := sm.trigger_schism(faction, rel, gs)
	assert_not_null(new_rel)
	# Oś A powinna być przesunięta (ulema: direction=1, więc +SCHISM_AXIS_OFFSET)
	assert_ne(new_rel.get_axis("A"), parent_axis_A)

func test_trigger_schism_new_religion_has_initial_prestige() -> void:
	var sm := SchismManagerScript.new()
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	var faction := rel.factions[0]
	faction.tension = 90.0
	faction.influence = 0.5
	var new_rel := sm.trigger_schism(faction, rel, gs)
	assert_not_null(new_rel)
	assert_eq(new_rel.prestige, SchismManagerScript.SCHISM_INITIAL_PRESTIGE)

func test_trigger_schism_removes_faction_from_parent() -> void:
	var sm := SchismManagerScript.new()
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	var faction := rel.factions[0]
	var faction_id := faction.id
	faction.tension = 90.0
	faction.influence = 0.5
	sm.trigger_schism(faction, rel, gs)
	assert_null(rel.get_faction(faction_id))
