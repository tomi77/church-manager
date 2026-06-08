extends GutTest

const ActionsScene := preload("res://scenes/ui/map/ProvinceActions.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func _instance(state: Node, province_id: String) -> ProvinceActions:
	var pa: ProvinceActions = ActionsScene.instantiate()
	add_child_autofree(pa)
	await get_tree().process_frame
	pa.bind(state, province_id)
	return pa

func test_actions_hidden_when_player_owns_province():
	var state := _make_state()
	add_child_autofree(state)
	# islam = player; mezopotamia owner=islam
	var pa := await _instance(state, "mezopotamia")
	assert_false(pa.get_node("%WarButton").visible)
	assert_false(pa.get_node("%MissionButton").visible)
	assert_false(pa.get_node("%DiplomacyButton").visible)

func test_diplomacy_button_always_visible_for_foreign_province():
	var state := _make_state()
	add_child_autofree(state)
	var pa := await _instance(state, "lewant")	# owner=eastern_christianity
	assert_true(pa.get_node("%DiplomacyButton").visible)

func test_diplomacy_button_emits_navigate_signal():
	var state := _make_state()
	add_child_autofree(state)
	var pa := await _instance(state, "lewant")
	watch_signals(pa)
	pa.get_node("%DiplomacyButton").emit_signal("pressed")
	assert_signal_emitted_with_parameters(pa, "navigate_to_diplomacy", ["eastern_christianity"])

func test_war_button_disabled_without_neighbor_province():
	var state := _make_state()
	add_child_autofree(state)
	# Persepolis sąsiaduje tylko z persja; islam nie ma żadnej prowincji sąsiadującej z persepolis
	var pa := await _instance(state, "persepolis")
	var btn: Button = pa.get_node("%WarButton")
	assert_true(btn.visible, "War button must be visible for foreign province")
	assert_true(btn.disabled, "War button must be disabled without neighbor")

func test_war_button_enabled_with_guaranteed_cb():
	var state := _make_state()
	add_child_autofree(state)
	var zoroastrianism: Religion = state.get_religion("zoroastrianism")
	zoroastrianism.parent_religion_id = "islam"
	# mezopotamia (islam) sąsiaduje z persja (zoroastrianism) — check first
	var pa := await _instance(state, "persja")
	var btn: Button = pa.get_node("%WarButton")
	assert_true(btn.visible)
	assert_false(btn.disabled, "War must be enabled given guaranteed CB + neighbor")

func test_cb_picker_cancel_refreshes_actions():
	var state := _make_state()
	add_child_autofree(state)
	var zoroastrianism: Religion = state.get_religion("zoroastrianism")
	zoroastrianism.parent_religion_id = "islam"
	var pa := await _instance(state, "persja")
	var picker := pa.get_node("%CBPicker")
	# War was enabled in setup — open picker (simulate multi-CB scenario)
	# Force visible state, then trigger cancel
	picker.visible = true
	picker.emit_signal("cancelled")
	# After cancel, picker hides itself in _on_cancel before emitting; verify war button still in coherent state
	var btn: Button = pa.get_node("%WarButton")
	assert_true(btn.visible)
	assert_false(btn.disabled, "War button must remain enabled after cancel (CBs still available)")
