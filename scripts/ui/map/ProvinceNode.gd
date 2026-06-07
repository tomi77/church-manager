class_name ProvinceNode
extends Control

signal pressed(province_id: String)

var province: Province = null
var is_selected: bool = false
var _tween_active: bool = false

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
    _apply_pressure_visual()

func _refresh_outline() -> void:
    _outline.default_color = UIConstants.MAP_NODE_OUTLINE_SELECTED if is_selected else UIConstants.MAP_NODE_OUTLINE_DEFAULT
    _outline.width = UIConstants.MAP_NODE_OUTLINE_WIDTH_SELECTED if is_selected else UIConstants.MAP_NODE_OUTLINE_WIDTH_DEFAULT

func _on_click_pressed() -> void:
    if province != null:
        emit_signal("pressed", province.id)

const PRESSURE_SUBTLE_MIN: float = 61.0
const PRESSURE_ALERT_MIN: float = 85.0

func pressure_alert_state() -> String:
    if province == null:
        return "none"
    var max_foreign := 0.0
    for rid: String in province.pressure:
        if rid == province.owner:
            continue
        var v: float = float(province.pressure[rid])
        if v > max_foreign:
            max_foreign = v
    if max_foreign > PRESSURE_ALERT_MIN:
        return "alert"
    if max_foreign >= PRESSURE_SUBTLE_MIN:
        return "subtle"
    return "none"

func _max_foreign_religion() -> String:
    if province == null:
        return ""
    var max_foreign := 0.0
    var max_id := ""
    for rid: String in province.pressure:
        if rid == province.owner:
            continue
        var v: float = float(province.pressure[rid])
        if v > max_foreign:
            max_foreign = v
            max_id = rid
    return max_id

func _apply_pressure_visual() -> void:
    var s := pressure_alert_state()
    if s == "none":
        modulate = Color.WHITE
        return
    var foreign_id := _max_foreign_religion()
    var foreign_color: Color = UIConstants.religion_color(foreign_id)
    if s == "subtle":
        modulate = Color.WHITE.lerp(foreign_color.lightened(0.4), 0.3)
    elif s == "alert":
        if not _tween_active and not OS.has_feature("headless"):
            _start_alert_tween(foreign_color)

func _start_alert_tween(target_color: Color) -> void:
    _tween_active = true
    var t := create_tween().set_loops()
    t.tween_property(self, "modulate", target_color.lightened(0.3), 0.5)
    t.tween_property(self, "modulate", Color.WHITE, 0.5)
