extends GutTest

const DoctrineRowScene := preload("res://scenes/ui/faith/DoctrineRow.tscn")

func _instance_row() -> DoctrineRow:
	var r: DoctrineRow = DoctrineRowScene.instantiate()
	add_child_autofree(r)
	await get_tree().process_frame
	return r

func test_row_shows_available_state_when_min_threshold_met():
	var r := await _instance_row()
	r.set_doctrine("dogma_canon", 80.0)  # A=80 vs min 75 → dostępna
	assert_eq(r.get_node("%StateIcon").text, "◐")
	assert_eq(r.get_node("%NameLabel").text, "Kanon Doktrynalny")
	assert_string_contains(r.get_node("%ConditionLabel").text, "A")
	assert_string_contains(r.get_node("%ConditionLabel").text, "75")

func test_row_shows_locked_state_when_min_threshold_unmet():
	var r := await _instance_row()
	r.set_doctrine("dogma_canon", 50.0)  # A=50 vs min 75 → zablokowana
	assert_eq(r.get_node("%StateIcon").text, "○")

func test_row_shows_available_at_min_threshold_boundary():
	var r := await _instance_row()
	r.set_doctrine("dogma_canon", 75.0)  # boundary >= 75 → dostępna
	assert_eq(r.get_node("%StateIcon").text, "◐")

func test_row_shows_available_at_max_threshold_boundary():
	var r := await _instance_row()
	r.set_doctrine("mystical_revelation", 25.0)  # boundary <= 25 → dostępna
	assert_eq(r.get_node("%StateIcon").text, "◐")

func test_row_locked_when_max_threshold_exceeded():
	var r := await _instance_row()
	r.set_doctrine("mystical_revelation", 26.0)  # A=26 vs max 25 → zablokowana
	assert_eq(r.get_node("%StateIcon").text, "○")

func test_row_tooltip_contains_description():
	var r := await _instance_row()
	r.set_doctrine("dogma_canon", 80.0)
	assert_string_contains(r.tooltip_text, "Ortodoksja")

func test_row_handles_unknown_doctrine_id():
	var r := await _instance_row()
	r.set_doctrine("nieznany", 50.0)
	# Brak crasha; placeholder
	assert_not_null(r)
