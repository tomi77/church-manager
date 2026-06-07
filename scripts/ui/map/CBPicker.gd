class_name CBPicker
extends PanelContainer

signal cb_chosen(cb: String, defender_id: String)
signal cancelled

const CB_LABELS: Dictionary = {
    "krucjata": "⚔ Krucjata",
    "dzihad": "⚔ Dżihad",
    "stlumienie_herezji": "⚔ Stłumienie herezji",
    "rewanz": "⚔ Rewanż",
    "wojna_ekspansywna": "⚔ Wojna ekspansywna",
}

var _defender_id: String = ""

@onready var _list: VBoxContainer = %CBList
@onready var _cancel: Button = %CancelButton

func _ready() -> void:
    visible = false
    _cancel.pressed.connect(_on_cancel)

func open(cbs: Array[String], defender_id: String) -> void:
    _defender_id = defender_id
    for c in _list.get_children():
        c.queue_free()
    for cb: String in cbs:
        var btn := Button.new()
        btn.text = CB_LABELS.get(cb, cb)
        btn.pressed.connect(_on_cb_pressed.bind(cb))
        _list.add_child(btn)
    visible = true

func close() -> void:
    visible = false

func _on_cb_pressed(cb: String) -> void:
    close()
    emit_signal("cb_chosen", cb, _defender_id)

func _on_cancel() -> void:
    close()
    emit_signal("cancelled")
