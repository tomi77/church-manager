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

func test_shell_default_shows_swiat_tab():
	var state := _make_state()
	add_child_autofree(state)
	var shell := await _instance_shell(state)
	assert_true(shell.get_node("%SwiatTab").visible)
	assert_false(shell.get_node("%MapaTab").visible)
	assert_false(shell.get_node("%WiaraTab").visible)
	assert_false(shell.get_node("%FrakcjeTab").visible)

func test_shell_tab_change_switches_visible_content():
	var state := _make_state()
	add_child_autofree(state)
	var shell := await _instance_shell(state)
	shell.get_node("%TabBar").set_current_tab("wiara")
	assert_true(shell.get_node("%WiaraTab").visible)
	assert_false(shell.get_node("%SwiatTab").visible)

func test_shell_frakcje_placeholder_has_correct_title():
	var state := _make_state()
	add_child_autofree(state)
	var shell := await _instance_shell(state)
	var frakcje: PlaceholderTab = shell.get_node("%FrakcjeTab")
	assert_string_contains(frakcje.title, "Plan 11")

func test_shell_instantiates_wiara_tab_as_real_component():
	var state := _make_state()
	add_child_autofree(state)
	var shell := await _instance_shell(state)
	var wiara = shell.get_node("%WiaraTab")
	assert_true(wiara is WiaraTab, "WiaraTab should be a WiaraTab instance, not PlaceholderTab")

func test_shell_binds_state_to_wiara_tab():
	var state := _make_state()
	add_child_autofree(state)
	var shell := await _instance_shell(state)
	var wiara: WiaraTab = shell.get_node("%WiaraTab")
	assert_eq(wiara.state, state)

func test_main_shell_renders_map_view_in_mapa_tab():
	var state := _make_state()
	add_child_autofree(state)
	var shell := await _instance_shell(state)
	shell.get_node("%TabBar").set_current_tab("mapa")
	var mapa_tab: MapaTab = shell.get_node("%MapaTab")
	assert_not_null(mapa_tab)
	assert_true(mapa_tab.visible)
	assert_eq(mapa_tab.get_node("%MapView").get_node_count(), 12)

func test_main_shell_hides_map_view_in_other_tabs():
	var state := _make_state()
	add_child_autofree(state)
	var shell := await _instance_shell(state)
	shell.get_node("%TabBar").set_current_tab("swiat")
	var map_view = shell.get_node("%MapaTab")
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
	var wiara: WiaraTab = s.get_node("%WiaraTab")
	assert_eq(wiara.state, GameState)
	# Etykiety osi pokazują wartości Islamu (A=70), nie zera.
	assert_eq(wiara.get_node("%AxisRadar").get_node("%ValueLabelA").text, "A: 70")
