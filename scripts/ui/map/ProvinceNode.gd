class_name ProvinceNode
extends Control

signal pressed(province_id: String)

var province: Province = null
var is_selected: bool = false

@onready var _polygon: Polygon2D = %Polygon
@onready var _outline: Line2D = %Outline
@onready var _name_label: Label = %NameLabel
@onready var _click_area: Button = %ClickArea

func _ready() -> void:
    _click_area.pressed.connect(_on_click_pressed)
    if province != null:
        _refresh()

func set_province(p: Province) -> void:
    province = p
    if is_inside_tree():
        _refresh()

func set_selected(sel: bool) -> void:
    is_selected = sel
    if is_inside_tree():
        _refresh_outline()

func _refresh() -> void:
    if province == null:
        return
    position = province.position
    _name_label.text = province.display_name
    _polygon.color = UIConstants.religion_color(province.owner)
    _refresh_outline()

func _refresh_outline() -> void:
    _outline.default_color = UIConstants.MAP_NODE_OUTLINE_SELECTED if is_selected else UIConstants.MAP_NODE_OUTLINE_DEFAULT
    _outline.width = UIConstants.MAP_NODE_OUTLINE_WIDTH_SELECTED if is_selected else UIConstants.MAP_NODE_OUTLINE_WIDTH_DEFAULT

func _on_click_pressed() -> void:
    if province != null:
        emit_signal("pressed", province.id)
