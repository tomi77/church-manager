class_name AxisDeltaPicker
extends HBoxContainer

signal executed(axis: String, delta: float)

const AXES := ["A", "B", "C", "D"]
const DELTAS := [-8.0, -5.0, 5.0, 8.0]

var _selected_axis: String = ""
var _selected_delta: float = 0.0

@onready var _execute_btn: Button = %ExecuteButton

func _ready() -> void:
	for axis: String in AXES:
		var btn: Button = get_node("%%%sButton" % axis)
		btn.pressed.connect(_on_axis_pressed.bind(axis))
	for delta: float in DELTAS:
		var key: String = _delta_key(delta)
		var btn: Button = get_node("%%%sButton" % key)
		btn.pressed.connect(_on_delta_pressed.bind(delta))
	_execute_btn.pressed.connect(_on_execute_pressed)
	_refresh_execute_state()

func reset() -> void:
	_selected_axis = ""
	_selected_delta = 0.0
	_refresh_axis_buttons()
	_refresh_delta_buttons()
	_refresh_execute_state()

func _delta_key(d: float) -> String:
	if d == -8.0: return "DeltaMinus8"
	if d == -5.0: return "DeltaMinus5"
	if d == 5.0: return "DeltaPlus5"
	if d == 8.0: return "DeltaPlus8"
	return "?"

func _on_axis_pressed(axis: String) -> void:
	_selected_axis = axis
	_refresh_axis_buttons()
	_refresh_execute_state()

func _on_delta_pressed(delta: float) -> void:
	_selected_delta = delta
	_refresh_delta_buttons()
	_refresh_execute_state()

func _refresh_axis_buttons() -> void:
	for axis: String in AXES:
		var btn: Button = get_node("%%%sButton" % axis)
		btn.modulate = UIConstants.COLOR_PICKER_SELECTED if axis == _selected_axis else UIConstants.COLOR_PICKER_UNSELECTED

func _refresh_delta_buttons() -> void:
	for delta: float in DELTAS:
		var key: String = _delta_key(delta)
		var btn: Button = get_node("%%%sButton" % key)
		btn.modulate = UIConstants.COLOR_PICKER_SELECTED if delta == _selected_delta else UIConstants.COLOR_PICKER_UNSELECTED

func _refresh_execute_state() -> void:
	_execute_btn.disabled = _selected_axis == "" or _selected_delta == 0.0

func _on_execute_pressed() -> void:
	if _selected_axis == "" or _selected_delta == 0.0:
		return
	emit_signal("executed", _selected_axis, _selected_delta)
	reset()
