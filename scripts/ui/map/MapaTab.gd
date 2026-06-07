class_name MapaTab
extends HBoxContainer

signal navigate_to_diplomacy(religion_id: String)
signal state_changed

var state: Node = null

@onready var _map_view: MapView = %MapView
@onready var _detail_panel: ProvinceDetailPanel = %DetailPanel

func _ready() -> void:
    _map_view.province_selected.connect(_on_province_selected)
    _detail_panel.navigate_to_diplomacy.connect(_on_navigate)
    _detail_panel.war_declared.connect(func(_defender_id: String, _cb: String): emit_signal("state_changed"))
    _detail_panel.missionaries_sent.connect(func(_target_id: String): emit_signal("state_changed"))

func bind_state(s: Node) -> void:
    state = s
    _map_view.bind_state(s)
    _detail_panel.bind_state(s)

func refresh() -> void:
    if state == null:
        return
    _map_view.refresh()
    if _detail_panel.current_province_id != "":
        _detail_panel.refresh()

func _on_province_selected(province_id: String) -> void:
    _detail_panel.set_province(province_id)

func _on_navigate(religion_id: String) -> void:
    emit_signal("navigate_to_diplomacy", religion_id)

