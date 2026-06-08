extends GutTest

const HeaderScene := preload("res://scenes/ui/Header.tscn")

func test_set_end_turn_enabled_disables_button():
	var header: Header = HeaderScene.instantiate()
	add_child_autofree(header)
	header.set_end_turn_enabled(false)
	assert_true(header.is_end_turn_disabled())

func test_set_end_turn_enabled_re_enables_button():
	var header: Header = HeaderScene.instantiate()
	add_child_autofree(header)
	header.set_end_turn_enabled(false)
	header.set_end_turn_enabled(true)
	assert_false(header.is_end_turn_disabled())
