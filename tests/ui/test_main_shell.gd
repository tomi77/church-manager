extends GutTest

const MainShellScene := preload("res://scenes/ui/MainShell.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func _instance_shell(state: Node) -> MainShell:
	var s: MainShell = MainShellScene.instantiate()
	add_child_autofree(s)
	await get_tree().process_frame
	s.bind_state(state)
	return s

func test_shell_default_shows_world_tab():
	var state := _make_state()
	add_child_autofree(state)
	var shell := await _instance_shell(state)
	assert_true(shell.get_node("%WorldTab").visible)
	assert_false(shell.get_node("%MapTab").visible)
	assert_false(shell.get_node("%FaithTab").visible)
	assert_false(shell.get_node("%FactionsTab").visible)

func test_shell_tab_change_switches_visible_content():
	var state := _make_state()
	add_child_autofree(state)
	var shell := await _instance_shell(state)
	shell.get_node("%TabBar").set_current_tab("faith")
	assert_true(shell.get_node("%FaithTab").visible)
	assert_false(shell.get_node("%WorldTab").visible)

func test_shell_instantiates_factions_tab_as_real_component():
	var state := _make_state()
	add_child_autofree(state)
	var shell := await _instance_shell(state)
	var factions = shell.get_node("%FactionsTab")
	assert_true(factions is FactionsTab, "FactionsTab should be a FactionsTab instance")

func test_shell_binds_state_to_factions_tab():
	var state := _make_state()
	add_child_autofree(state)
	var shell := await _instance_shell(state)
	var factions: FactionsTab = shell.get_node("%FactionsTab")
	assert_eq(factions.state, state)

func test_shell_instantiates_faith_tab_as_real_component():
	var state := _make_state()
	add_child_autofree(state)
	var shell := await _instance_shell(state)
	var wiara = shell.get_node("%FaithTab")
	assert_true(wiara is FaithTab, "FaithTab should be a FaithTab instance")

func test_shell_binds_state_to_faith_tab():
	var state := _make_state()
	add_child_autofree(state)
	var shell := await _instance_shell(state)
	var wiara: FaithTab = shell.get_node("%FaithTab")
	assert_eq(wiara.state, state)

func test_main_shell_renders_map_view_in_map_tab():
	var state := _make_state()
	add_child_autofree(state)
	var shell := await _instance_shell(state)
	shell.get_node("%TabBar").set_current_tab("map")
	var mapa_tab: MapTab = shell.get_node("%MapTab")
	assert_not_null(mapa_tab)
	assert_true(mapa_tab.visible)
	assert_eq(mapa_tab.get_node("%MapView").get_node_count(), 19)

func test_main_shell_hides_map_view_in_other_tabs():
	var state := _make_state()
	add_child_autofree(state)
	var shell := await _instance_shell(state)
	shell.get_node("%TabBar").set_current_tab("world")
	var map_view = shell.get_node("%MapTab")
	assert_false(map_view.visible)

func test_shell_end_turn_refreshes():
	var state := _make_state()
	add_child_autofree(state)
	state.get_player_religion().prestige = 100
	var shell := await _instance_shell(state)
	var initial_turn: int = state.current_turn
	shell.get_node("%Header").get_node("%EndTurnButton").emit_signal("pressed")
	assert_eq(state.current_turn, initial_turn + 1)
	assert_eq(shell.get_node("%Header").get_node("%TurnLabel").text, "Tura %d" % state.current_turn)

# Bootstrap z autoload GameState: StartMenu woła GameState.initialize(...) + change_scene_to_file(MainShell.tscn).
# MainShell._ready() musi sam podpiąć autoload do dzieci — w przeciwnym razie Header/Mapa/Wiara/Świat
# pokazują domyślne placeholdery ("?", A:0, Tura 0).
func test_shell_auto_binds_to_initialized_gamestate_autoload():
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	GameState.initialize("islam", religions, graph)
	var s: MainShell = MainShellScene.instantiate()
	add_child_autofree(s)
	await get_tree().process_frame
	# Bez wywoływania bind_state ręcznie — sprawdzamy że _ready() spiął autoload.
	assert_eq(s.state, GameState)
	var wiara: FaithTab = s.get_node("%FaithTab")
	assert_eq(wiara.state, GameState)
	# Etykiety osi pokazują wartości Islamu (A=70), nie zera.
	assert_eq(wiara.get_node("%AxisRadar").get_node("%ValueLabelA").text, "A: 70")
