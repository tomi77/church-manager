extends GutTest

const MainShellScene := preload("res://scenes/ui/MainShell.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func _instantiate_with_state(state: Node) -> MainShell:
	var shell: MainShell = MainShellScene.instantiate()
	add_child_autofree(shell)
	await get_tree().process_frame
	shell.bind_state(state)
	return shell

func test_main_shell_does_not_show_dialog_when_no_outcome():
	var gs := _make_state()
	add_child_autofree(gs)
	var shell := await _instantiate_with_state(gs)
	shell.refresh()
	assert_eq(shell.get_active_game_over_dialog_count(), 0)

func test_main_shell_shows_dialog_when_game_outcome_set():
	var gs := _make_state()
	add_child_autofree(gs)
	var outcome := GameOutcome.new()
	outcome.winner_id = "islam"
	outcome.reason = "domination"
	outcome.end_turn = 42
	gs.game_outcome = outcome
	var shell := await _instantiate_with_state(gs)
	shell.refresh()
	assert_eq(shell.get_active_game_over_dialog_count(), 1)

func test_main_shell_shows_dialog_only_once_on_repeated_refresh():
	var gs := _make_state()
	add_child_autofree(gs)
	var outcome := GameOutcome.new()
	outcome.winner_id = "islam"
	outcome.reason = "domination"
	gs.game_outcome = outcome
	var shell := await _instantiate_with_state(gs)
	shell.refresh()
	shell.refresh()
	shell.refresh()
	assert_eq(shell.get_active_game_over_dialog_count(), 1)

func test_main_shell_disables_end_turn_button_when_game_over():
	var gs := _make_state()
	add_child_autofree(gs)
	var outcome := GameOutcome.new()
	outcome.winner_id = "islam"
	outcome.reason = "domination"
	gs.game_outcome = outcome
	var shell := await _instantiate_with_state(gs)
	shell.refresh()
	# Header dostępne przez shell
	assert_true(shell.is_end_turn_disabled())

func test_main_shell_keeps_end_turn_enabled_after_player_defeat():
	# Gracz przegrał, ale nikt nie wygrał — gra trwa, gracz może obserwować swoją religię
	var gs := _make_state()
	add_child_autofree(gs)
	var rel: Religion = gs.get_religion("islam")
	rel.defeated_at_turn = 30
	var shell := await _instantiate_with_state(gs)
	shell.refresh()
	assert_false(shell.is_end_turn_disabled())

func test_main_shell_shows_defeat_dialog_when_player_defeated():
	var gs := _make_state()
	add_child_autofree(gs)
	var rel: Religion = gs.get_religion("islam")
	rel.defeated_at_turn = 30
	var shell := await _instantiate_with_state(gs)
	shell.refresh()
	assert_eq(shell.get_active_game_over_dialog_count(), 1)

func test_main_shell_shows_player_defeat_dialog_only_once():
	var gs := _make_state()
	add_child_autofree(gs)
	var rel: Religion = gs.get_religion("islam")
	rel.defeated_at_turn = 30
	var shell := await _instantiate_with_state(gs)
	shell.refresh()
	shell.refresh()
	assert_eq(shell.get_active_game_over_dialog_count(), 1)
