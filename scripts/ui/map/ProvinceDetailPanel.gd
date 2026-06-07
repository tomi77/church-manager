class_name ProvinceDetailPanel
extends PanelContainer

signal navigate_to_diplomacy(religion_id: String)
signal war_declared(defender_id: String, cb: String)
signal missionaries_sent(target_id: String)

var state: Node = null
var current_province_id: String = ""

@onready var _header: ProvinceDetailHeader = %Header
@onready var _pressure: PressureBars = %Pressure
@onready var _actions: ProvinceActions = %Actions

func _ready() -> void:
	visible = false
	_actions.navigate_to_diplomacy.connect(_on_navigate)
	_actions.war_declared.connect(_on_war)
	_actions.missionaries_sent.connect(_on_missionaries)

func bind_state(s: Node) -> void:
	state = s

func set_province(province_id: String) -> void:
	current_province_id = province_id
	if state == null:
		return
	_header.bind(state, province_id)
	_pressure.bind(state, province_id)
	_actions.bind(state, province_id)
	visible = true

func clear() -> void:
	current_province_id = ""
	visible = false

func refresh() -> void:
	if current_province_id != "" and state != null:
		_header.refresh()
		_pressure.refresh()
		_actions.refresh()

func _on_navigate(religion_id: String) -> void:
	emit_signal("navigate_to_diplomacy", religion_id)

func _on_war(defender_id: String, cb: String) -> void:
	emit_signal("war_declared", defender_id, cb)
	refresh()

func _on_missionaries(target_id: String) -> void:
	emit_signal("missionaries_sent", target_id)
	refresh()
