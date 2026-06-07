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

func test_shell_placeholders_have_correct_titles():
    var state := _make_state()
    add_child_autofree(state)
    var shell := await _instance_shell(state)
    var mapa: PlaceholderTab = shell.get_node("%MapaTab")
    var wiara: PlaceholderTab = shell.get_node("%WiaraTab")
    var frakcje: PlaceholderTab = shell.get_node("%FrakcjeTab")
    assert_string_contains(mapa.title, "Plan 09")
    assert_string_contains(wiara.title, "Plan 10")
    assert_string_contains(frakcje.title, "Plan 11")

func test_shell_end_turn_refreshes():
    var state := _make_state()
    add_child_autofree(state)
    state.get_player_religion().prestige = 100
    var shell := await _instance_shell(state)
    var initial_turn: int = state.current_turn
    shell.get_node("%Header").get_node("%EndTurnButton").emit_signal("pressed")
    assert_eq(state.current_turn, initial_turn + 1)
    assert_eq(shell.get_node("%Header").get_node("%TurnLabel").text, "Tura %d" % state.current_turn)
