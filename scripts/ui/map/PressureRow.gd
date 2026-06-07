class_name PressureRow
extends HBoxContainer

var religion_id: String = ""

var _pending_religion: Religion = null
var _pending_pressure: float = 0.0

@onready var _icon: Label = %IconLabel
@onready var _name: Label = %NameLabel
@onready var _bar: ProgressBar = %Bar
@onready var _value: Label = %ValueLabel

func _ready() -> void:
    if _pending_religion != null:
        _refresh()

func set_data(religion: Religion, pressure_value: float) -> void:
    religion_id = religion.id
    _pending_religion = religion
    _pending_pressure = pressure_value
    if is_inside_tree():
        _refresh()

func _refresh() -> void:
    if _pending_religion == null:
        return
    _icon.text = _pending_religion.icon
    _name.text = _pending_religion.display_name
    _bar.value = _pending_pressure
    _value.text = "%d" % int(_pending_pressure)
