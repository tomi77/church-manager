class_name AxisRadar
extends Control

const CENTER: Vector2 = Vector2(200, 200)
const MAX_RADIUS: float = 160.0

var state: Node = null

@onready var _value_polygon: Polygon2D = %ValuePolygon
@onready var _value_outline: Line2D = %ValueOutline
@onready var _label_a: Label = %ValueLabelA
@onready var _label_b: Label = %ValueLabelB
@onready var _label_c: Label = %ValueLabelC
@onready var _label_d: Label = %ValueLabelD

func bind_state(s: Node) -> void:
	state = s
	if not is_inside_tree():
		return
	refresh()

func _ready() -> void:
	if state != null:
		refresh()

func refresh() -> void:
	if state == null:
		return
	var religion: Religion = state.get_player_religion()
	if religion == null:
		return
	var vertices := _compute_vertices(religion.axes)
	_value_polygon.polygon = PackedVector2Array(vertices)
	_value_polygon.color = _with_alpha(UIConstants.religion_color(religion.id), 0.4)
	_value_outline.points = PackedVector2Array(vertices + [vertices[0]])
	_value_outline.default_color = UIConstants.religion_accent_color(religion.id)
	_label_a.text = "A: " + str(int(round(religion.get_axis("A"))))
	_label_b.text = "B: " + str(int(round(religion.get_axis("B"))))
	_label_c.text = "C: " + str(int(round(religion.get_axis("C"))))
	_label_d.text = "D: " + str(int(round(religion.get_axis("D"))))

func _compute_vertices(axes: Dictionary) -> Array[Vector2]:
	var ra: float = axes.get("A", 0.0) / 100.0 * MAX_RADIUS
	var rb: float = axes.get("B", 0.0) / 100.0 * MAX_RADIUS
	var rc: float = axes.get("C", 0.0) / 100.0 * MAX_RADIUS
	var rd: float = axes.get("D", 0.0) / 100.0 * MAX_RADIUS
	return [
		CENTER + Vector2(0, -ra),	# A — góra
		CENTER + Vector2(rb, 0),	# B — prawo
		CENTER + Vector2(0, rc),	# C — dół
		CENTER + Vector2(-rd, 0),	# D — lewo
	]

func _with_alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)
