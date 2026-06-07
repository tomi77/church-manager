class_name ProvinceNode
extends Control

signal pressed(province_id: String)

var province: Province = null
var is_selected: bool = false
var _alert_tween: Tween = null

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

func _max_foreign_pressure() -> Dictionary:
    if province == null:
        return {"id": "", "value": 0.0}
    var max_val := 0.0
    var max_id := ""
    for rid: String in province.pressure:
        if rid == province.owner:
            continue
        var v: float = float(province.pressure[rid])
        if v > max_val:
            max_val = v
            max_id = rid
    return {"id": max_id, "value": max_val}

func pressure_alert_state() -> String:
    var max_val: float = _max_foreign_pressure().value
    if max_val > PRESSURE_ALERT_MIN:
        return "alert"
    if max_val >= PRESSURE_SUBTLE_MIN:
        return "subtle"
    return "none"

func _apply_pressure_visual() -> void:
    if _alert_tween != null:
        _alert_tween.kill()
        _alert_tween = null
    var max_foreign := _max_foreign_pressure()
    var s := pressure_alert_state()
    if s == "none":
        modulate = Color.WHITE
        return
    var foreign_color: Color = UIConstants.religion_color(max_foreign.id)
    if s == "subtle":
        modulate = Color.WHITE.lerp(foreign_color.lightened(0.4), 0.3)
    elif s == "alert":
        if not OS.has_feature("headless"):
            _start_alert_tween(foreign_color)

func _start_alert_tween(target_color: Color) -> void:
    _alert_tween = create_tween().set_loops()
    _alert_tween.tween_property(self, "modulate", target_color.lightened(0.3), 0.5)
    _alert_tween.tween_property(self, "modulate", Color.WHITE, 0.5)
