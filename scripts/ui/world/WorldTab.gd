class_name WorldTab
extends Control

signal state_changed

var state: Node = null

@onready var _conflict: ConflictSection = %ConflictSection
@onready var _list: RelationList = %RelationList
@onready var _action_panel: ActionPanel = %ActionPanel

func _ready() -> void:
    _list.religion_selected.connect(_on_religion_selected)
    _action_panel.state_changed.connect(_on_state_changed)
    _conflict.state_changed.connect(_on_state_changed)

func bind_state(s: Node) -> void:
    state = s
    _conflict.bind_state(s)
    _list.bind_state(s)
    _action_panel.bind_state(s)
    _auto_select_first()

func refresh() -> void:
    if state == null:
        return
    _conflict.refresh()
    _list.refresh()
    if _action_panel.target_id == "" or state.get_religion(_action_panel.target_id) == null:
        _auto_select_first()
    else:
        _action_panel.refresh()

func _auto_select_first() -> void:
    var player_id: String = state.player_religion_id
    for r: Religion in state.all_religions():
        if r.id != player_id:
            _on_religion_selected(r.id)
            return

func _on_religion_selected(id: String) -> void:
    _list.set_selected(id)
    _action_panel.set_target(id)

func preselect_religion(religion_id: String) -> void:
    if state == null:
        return
    if state.get_religion(religion_id) == null:
        return
    _list.set_selected(religion_id)
    _action_panel.set_target(religion_id)

func _on_state_changed() -> void:
    refresh()
    emit_signal("state_changed")
