extends GutTest

const PanelScene := preload("res://scenes/ui/map/ProvinceDetailPanel.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func _instance(state: Node) -> ProvinceDetailPanel:
	var p: ProvinceDetailPanel = PanelScene.instantiate()
	add_child_autofree(p)
	await get_tree().process_frame
	p.bind_state(state)
	return p

func test_panel_hidden_with_no_selection():
	var state := _make_state()
	add_child_autofree(state)
	var p := await _instance(state)
	assert_false(p.visible)

func test_panel_shows_when_province_selected():
	var state := _make_state()
	add_child_autofree(state)
	var p := await _instance(state)
	p.set_province("mekka")
	assert_true(p.visible)
	assert_eq(p.current_province_id, "mekka")

func test_panel_clear_hides():
	var state := _make_state()
	add_child_autofree(state)
	var p := await _instance(state)
	p.set_province("mekka")
	p.clear()
	assert_false(p.visible)
	assert_eq(p.current_province_id, "")

func test_panel_relays_navigate_signal():
	var state := _make_state()
	add_child_autofree(state)
	var p := await _instance(state)
	p.set_province("lewant")
	watch_signals(p)
	var actions := p.get_node("%Actions")
	actions.emit_signal("navigate_to_diplomacy", "chr_wschodnie")
	assert_signal_emitted_with_parameters(p, "navigate_to_diplomacy", ["chr_wschodnie"])

func test_panel_relays_war_declared_signal():
	var state := _make_state()
	add_child_autofree(state)
	var p := await _instance(state)
	p.set_province("lewant")
	watch_signals(p)
	var actions := p.get_node("%Actions")
	actions.emit_signal("war_declared", "chr_wschodnie", "krucjata")
	assert_signal_emitted_with_parameters(p, "war_declared", ["chr_wschodnie", "krucjata"])

func test_panel_relays_missionaries_sent_signal():
	var state := _make_state()
	add_child_autofree(state)
	var p := await _instance(state)
	p.set_province("lewant")
	watch_signals(p)
	var actions := p.get_node("%Actions")
	actions.emit_signal("missionaries_sent", "chr_wschodnie")
	assert_signal_emitted_with_parameters(p, "missionaries_sent", ["chr_wschodnie"])

func test_panel_refresh_noop_when_no_province():
	var state := _make_state()
	add_child_autofree(state)
	var p := await _instance(state)
	# Should not crash, simply return early
	p.refresh()
	assert_eq(p.current_province_id, "")
