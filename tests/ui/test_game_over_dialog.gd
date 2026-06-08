extends GutTest

const GameOverDialogScene := preload("res://scenes/ui/dialogs/GameOverDialog.tscn")

func _make_outcome(winner_id: String = "islam", reason: String = "domination") -> GameOutcome:
	var o := GameOutcome.new()
	o.winner_id = winner_id
	o.reason = reason
	o.end_turn = 87
	o.ranking = [
		{"religion_id": "islam", "prestige": 540, "provinces": 6},
		{"religion_id": "western_christianity", "prestige": 510, "provinces": 3},
		{"religion_id": "eastern_christianity", "prestige": 480, "provinces": 2},
	]
	return o

func _instantiate() -> Control:
	var dialog: Control = GameOverDialogScene.instantiate()
	add_child_autofree(dialog)
	return dialog

func test_dialog_shows_winner_display_name_in_outcome_mode():
	var dialog := _instantiate()
	var outcome := _make_outcome("islam", "domination")
	dialog.show_outcome(outcome)
	# Powinien zawierać nazwę religii (display_name z fixture: "☪ Islam") gdzieś w tekście
	var title_text: String = dialog.get_title_text()
	assert_true(title_text.contains("Islam") or title_text.contains("☪"),
		"Tytuł powinien zawierać nazwę zwycięzcy, miał: " + title_text)

func test_dialog_shows_reason_label_in_polish():
	var dialog := _instantiate()
	var outcome := _make_outcome("islam", "domination")
	dialog.show_outcome(outcome)
	assert_true(dialog.get_reason_text().contains("Dominacja"),
		"Powinno być polskie etykieta dla 'domination', miał: " + dialog.get_reason_text())

func test_dialog_maps_all_reasons_to_non_empty_polish_labels():
	var dialog := _instantiate()
	var reasons := ["domination", "prestige_hegemony", "holy_land",
		"manichaeism_illumination", "judaism_return", "zoroastrianism_renaissance",
		"east_christianity_pentarchy", "islam_caliphate", "germanic_ragnarok",
		"turn_limit", "elimination", "long_vassalage"]
	for r: String in reasons:
		var outcome := _make_outcome("islam", r)
		dialog.show_outcome(outcome)
		var text: String = dialog.get_reason_text()
		assert_ne(text, "", "Reason " + r + " powinien mieć etykietę")

func test_dialog_shows_end_turn():
	var dialog := _instantiate()
	var outcome := _make_outcome()
	outcome.end_turn = 87
	dialog.show_outcome(outcome)
	assert_true(dialog.get_turn_text().contains("87"))

func test_dialog_shows_ranking_with_3_entries():
	var dialog := _instantiate()
	var outcome := _make_outcome()
	dialog.show_outcome(outcome)
	assert_eq(dialog.get_ranking_row_count(), 3)

func test_dialog_emits_new_game_pressed():
	var dialog := _instantiate()
	dialog.show_outcome(_make_outcome())
	watch_signals(dialog)
	dialog.press_new_game()  # helper do testowego pressed
	assert_signal_emitted(dialog, "new_game_pressed")

func test_dialog_emits_closed_when_close_pressed():
	var dialog := _instantiate()
	dialog.show_outcome(_make_outcome())
	watch_signals(dialog)
	dialog.press_close()
	assert_signal_emitted(dialog, "closed")

func test_dialog_player_defeat_mode_shows_defeat_message():
	var dialog := _instantiate()
	dialog.show_player_defeat("islam", "elimination")
	var text: String = dialog.get_title_text()
	assert_true(text.contains("Przegrałeś") or text.contains("Pokonany"))

func test_dialog_player_defeat_mode_emits_close_signal():
	var dialog := _instantiate()
	dialog.show_player_defeat("islam", "elimination")
	watch_signals(dialog)
	dialog.press_close()
	assert_signal_emitted(dialog, "closed")
