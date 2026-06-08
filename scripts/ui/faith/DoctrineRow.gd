class_name DoctrineRow
extends HBoxContainer

const ICON_AVAILABLE: String = "◐"
const ICON_LOCKED: String = "○"
const COLOR_AVAILABLE: Color = Color("dda820")
const COLOR_LOCKED: Color = Color(0.4, 0.4, 0.4)

var _action_id: String = ""
var _current_axis_value: float = 0.0

@onready var _state_icon: Label = %StateIcon
@onready var _name_label: Label = %NameLabel
@onready var _condition_label: Label = %ConditionLabel

func set_doctrine(action_id: String, axis_value: float) -> void:
	_action_id = action_id
	_current_axis_value = axis_value
	if not is_inside_tree():
		return
	refresh()

func _ready() -> void:
	if _action_id != "":
		refresh()

func refresh() -> void:
	var info: Dictionary = UIConstants.DOCTRINE_INFO.get(_action_id, {})
	if info.is_empty():
		_state_icon.text = ICON_LOCKED
		_name_label.text = "(nieznana doktryna)"
		_condition_label.text = ""
		tooltip_text = ""
		return
	var op: String = info.get("op", "min")
	var threshold: float = info.get("threshold", 0.0)
	var available := _is_available(op, threshold)
	_state_icon.text = ICON_AVAILABLE if available else ICON_LOCKED
	_state_icon.modulate = COLOR_AVAILABLE if available else COLOR_LOCKED
	_name_label.text = info.get("name", "")
	var op_glyph := "≥" if op == "min" else "≤"
	_condition_label.text = "wymaga " + info["axis"] + " " + op_glyph + " " + str(int(threshold))
	tooltip_text = info.get("description", "")

func _is_available(op: String, threshold: float) -> bool:
	if op == "min":
		return _current_axis_value >= threshold
	return _current_axis_value <= threshold
