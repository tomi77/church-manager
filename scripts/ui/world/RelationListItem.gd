class_name RelationListItem
extends PanelContainer

signal pressed(religion_id: String)

var religion: Religion = null
var relation: RelationState = null
var marker: String = ""
var is_selected: bool = false

@onready var _btn: Button = %RowButton
@onready var _name_label: Label = %NameLabel
@onready var _z_label: Label = %ZLabel
@onready var _e_label: Label = %ELabel
@onready var _n_label: Label = %NLabel
@onready var _marker_label: Label = %MarkerLabel

func _ready() -> void:
    _btn.pressed.connect(_on_pressed)

func set_data(rel: RelationState, r: Religion, marker_text: String) -> void:
    religion = r
    relation = rel
    marker = marker_text
    if is_inside_tree():
        _refresh()

func set_selected(sel: bool) -> void:
    is_selected = sel
    if is_inside_tree():
        _refresh_selection()

func _refresh() -> void:
    if religion == null:
        return
    _name_label.text = "%s %s" % [religion.icon, religion.display_name]
    if relation != null:
        _z_label.text = "Z %d" % int(relation.theological_trust)
        _e_label.text = "E %d" % int(relation.economic_cooperation)
        _n_label.text = "N %d" % int(relation.military_tension)
    else:
        _z_label.text = "Z 0"
        _e_label.text = "E 0"
        _n_label.text = "N 0"
    _marker_label.text = marker
    _refresh_selection()

func _refresh_selection() -> void:
    modulate = Color(1.1, 1.1, 1.1) if is_selected else Color(1, 1, 1)

func _on_pressed() -> void:
    emit_signal("pressed", religion.id if religion != null else "")
