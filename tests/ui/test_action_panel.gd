extends GutTest

const ActionPanelScene := preload("res://scenes/ui/world/ActionPanel.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")
const CoalitionScript := preload("res://scripts/engine/Coalition.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func _instance(state: Node, target_id: String) -> ActionPanel:
	var p: ActionPanel = ActionPanelScene.instantiate()
	add_child_autofree(p)
	await get_tree().process_frame
	p.bind_state(state)
	p.set_target(target_id)
	return p

func test_renders_target_name():
	var state := _make_state()
	add_child_autofree(state)
	var p := await _instance(state, "western_christianity")
	var text: String = p.get_node("%TargetNameLabel").text
	assert_string_contains(text, "Chrześcijaństwo Zachodnie")

func test_alliance_disabled_when_low_prestige():
	var state := _make_state()
	add_child_autofree(state)
	state.get_player_religion().prestige = 0
	var p := await _instance(state, "western_christianity")
	assert_true(p.get_node("%AllianceButton").disabled)
	assert_string_contains(p.get_node("%AllianceButton").tooltip_text, "Brak prestiżu")

func test_alliance_enabled_when_conditions_met():
	var state := _make_state()
	add_child_autofree(state)
	state.get_player_religion().prestige = 100
	var dm := DiplomacyManager.new()
	var rel := dm.get_or_create_relation(state, "islam", "western_christianity")
	rel.theological_trust = 70.0
	var p := await _instance(state, "western_christianity")
	assert_false(p.get_node("%AllianceButton").disabled)

func test_alliance_click_invokes_manager():
	var state := _make_state()
	add_child_autofree(state)
	state.get_player_religion().prestige = 100
	var dm := DiplomacyManager.new()
	var rel := dm.get_or_create_relation(state, "islam", "western_christianity")
	rel.theological_trust = 70.0
	var p := await _instance(state, "western_christianity")
	watch_signals(p)
	p.get_node("%AllianceButton").emit_signal("pressed")
	assert_signal_emitted(p, "state_changed")
	var rel_after := dm.get_or_create_relation(state, "islam", "western_christianity")
	assert_true(rel_after.alliance_active)

func test_interdict_disabled_when_low_prestige():
	var state := _make_state()
	add_child_autofree(state)
	state.get_player_religion().prestige = 0
	var p := await _instance(state, "western_christianity")
	assert_true(p.get_node("%InterdictButton").disabled)

func test_interdict_opens_confirm_dialog():
	var state := _make_state()
	add_child_autofree(state)
	state.get_player_religion().prestige = 100
	var p := await _instance(state, "western_christianity")
	p.get_node("%InterdictButton").emit_signal("pressed")
	assert_true(p.get_node("%ConfirmDialog").visible)

func test_interdict_confirmed_invokes_manager():
	var state := _make_state()
	add_child_autofree(state)
	state.get_player_religion().prestige = 100
	var p := await _instance(state, "western_christianity")
	p.get_node("%InterdictButton").emit_signal("pressed")
	p.get_node("%ConfirmDialog").emit_signal("confirmed")
	var target: Religion = state.get_religion("western_christianity")
	assert_eq(target.interdict_grievance_from_id, "islam")
	assert_true(target.interdict_grievance_until > state.current_turn)

func test_missionaries_disabled_when_low_trust():
	var state := _make_state()
	add_child_autofree(state)
	state.get_player_religion().prestige = 100
	var p := await _instance(state, "western_christianity")
	assert_true(p.get_node("%MissionariesButton").disabled)

func test_ecu_council_shows_picker_on_click():
	var state := _make_state()
	add_child_autofree(state)
	state.get_player_religion().prestige = 100
	state.get_player_religion().axes["C"] = 60.0
	var dm := DiplomacyManager.new()
	var rel := dm.get_or_create_relation(state, "islam", "western_christianity")
	rel.theological_trust = 70.0
	var p := await _instance(state, "western_christianity")
	p.get_node("%EcuCouncilButton").emit_signal("pressed")
	assert_true(p.get_node("%PickerContainer").visible)

func test_vassal_patron_visible_when_player_unsuzerained():
	var state := _make_state()
	add_child_autofree(state)
	var p := await _instance(state, "western_christianity")
	assert_true(p.get_node("%VassalPatronButton").visible)

func test_vassal_patron_hidden_when_player_is_client():
	var state := _make_state()
	add_child_autofree(state)
	state.get_player_religion().suzerain_id = "eastern_christianity"
	var p := await _instance(state, "western_christianity")
	assert_false(p.get_node("%VassalPatronButton").visible)

func test_vassal_council_visible_only_for_clients():
	var state := _make_state()
	add_child_autofree(state)
	state.get_religion("coptic_christianity").suzerain_id = "islam"
	var p := await _instance(state, "coptic_christianity")
	assert_true(p.get_node("%VassalCouncilButton").visible)
	p.set_target("western_christianity")
	assert_false(p.get_node("%VassalCouncilButton").visible)

func test_rewanz_hidden_when_no_cb():
	var state := _make_state()
	add_child_autofree(state)
	var p := await _instance(state, "western_christianity")
	assert_false(p.get_node("%RewanzButton").visible)

func test_rewanz_visible_when_grievance_active():
	var state := _make_state()
	add_child_autofree(state)
	var player: Religion = state.get_player_religion()
	player.interdict_grievance_from_id = "western_christianity"
	player.interdict_grievance_until = state.current_turn + 5
	player.axes["C"] = 20.0
	var p := await _instance(state, "western_christianity")
	assert_true(p.get_node("%RewanzButton").visible)

func test_grievance_box_visible_when_active():
	var state := _make_state()
	add_child_autofree(state)
	var player: Religion = state.get_player_religion()
	player.interdict_grievance_from_id = "western_christianity"
	player.interdict_grievance_until = state.current_turn + 5
	var p := await _instance(state, "western_christianity")
	assert_true(p.get_node("%GrievanceBox").visible)

func test_coalition_box_visible_when_targeted():
	var state := _make_state()
	add_child_autofree(state)
	var c: Coalition = CoalitionScript.new()
	c.target_id = "islam"
	c.members = ["western_christianity", "eastern_christianity"]
	state.active_coalitions.append(c)
	var p := await _instance(state, "western_christianity")
	assert_true(p.get_node("%CoalitionBox").visible)

func test_picker_execute_invokes_ecu_council():
	var state := _make_state()
	add_child_autofree(state)
	var player: Religion = state.get_player_religion()
	player.prestige = 100
	player.axes["C"] = 60.0
	player.axes["B"] = 50.0	 # B≤60 → _axis_cost_modifier=1.0, cost == COUNCIL_PRESTIGE_COST nominalnie
	var dm := DiplomacyManager.new()
	var rel := dm.get_or_create_relation(state, "islam", "western_christianity")
	rel.theological_trust = 70.0
	var p := await _instance(state, "western_christianity")
	p.get_node("%EcuCouncilButton").emit_signal("pressed")
	p._picker.get_node("%CButton").emit_signal("pressed")
	p._picker.get_node("%DeltaPlus5Button").emit_signal("pressed")
	p._picker.get_node("%ExecuteButton").emit_signal("pressed")
	assert_eq(player.prestige, 70)	# 100 - 30 (cost nominalny przy B≤60)
