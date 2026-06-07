extends GutTest

const PickerScene := preload("res://scenes/ui/world/AxisDeltaPicker.tscn")

func _instance() -> AxisDeltaPicker:
	var p: AxisDeltaPicker = PickerScene.instantiate()
	add_child_autofree(p)
	await get_tree().process_frame
	return p

func test_execute_disabled_initially():
	var p := await _instance()
	assert_true(p.get_node("%ExecuteButton").disabled)

func test_select_axis_only_keeps_execute_disabled():
	var p := await _instance()
	p.get_node("%CButton").emit_signal("pressed")
	assert_true(p.get_node("%ExecuteButton").disabled)

func test_select_axis_and_delta_enables_execute():
	var p := await _instance()
	p.get_node("%CButton").emit_signal("pressed")
	p.get_node("%DeltaPlus5Button").emit_signal("pressed")
	assert_false(p.get_node("%ExecuteButton").disabled)

func test_execute_emits_signal_with_params():
	var p := await _instance()
	p.get_node("%AButton").emit_signal("pressed")
	p.get_node("%DeltaMinus5Button").emit_signal("pressed")
	watch_signals(p)
	p.get_node("%ExecuteButton").emit_signal("pressed")
	assert_signal_emitted_with_parameters(p, "executed", ["A", -5.0])

func test_execute_resets_picker():
	var p := await _instance()
	p.get_node("%CButton").emit_signal("pressed")
	p.get_node("%DeltaPlus5Button").emit_signal("pressed")
	p.get_node("%ExecuteButton").emit_signal("pressed")
	assert_true(p.get_node("%ExecuteButton").disabled)

func test_reset_clears_selection():
	var p := await _instance()
	p.get_node("%CButton").emit_signal("pressed")
	p.get_node("%DeltaPlus5Button").emit_signal("pressed")
	p.reset()
	assert_true(p.get_node("%ExecuteButton").disabled)
