extends GutTest

const StartMenuScene := preload("res://scenes/ui/StartMenu.tscn")

func _instance_menu() -> StartMenu:
    var m: StartMenu = StartMenuScene.instantiate()
    add_child_autofree(m)
    await get_tree().process_frame
    return m

func test_grid_populated_with_12_religions():
    var m := await _instance_menu()
    var grid: GridContainer = m.get_node("%ReligionGrid")
    assert_eq(grid.get_child_count(), 12)

func test_start_button_disabled_initially():
    var m := await _instance_menu()
    assert_true(m.get_node("%StartButton").disabled)

func test_card_click_enables_start_button():
    var m := await _instance_menu()
    watch_signals(m)
    var first_card: Button = m.get_node("%ReligionGrid").get_child(0)
    first_card.emit_signal("pressed")
    assert_false(m.get_node("%StartButton").disabled)
    assert_signal_emitted(m, "religion_selected")

func test_selected_info_updates_on_card_click():
    var m := await _instance_menu()
    var first_card: Button = m.get_node("%ReligionGrid").get_child(0)
    first_card.emit_signal("pressed")
    var info_text: String = m.get_node("%SelectedInfoLabel").text
    assert_string_contains(info_text, "Wybrana:")

func test_religion_selected_signal_carries_id():
    var m := await _instance_menu()
    watch_signals(m)
    var first_card: Button = m.get_node("%ReligionGrid").get_child(0)
    first_card.emit_signal("pressed")
    var params = get_signal_parameters(m, "religion_selected", 0)
    assert_typeof(params[0], TYPE_STRING)
    assert_true(params[0].length() > 0)
