class_name MapView
extends Control

signal province_selected(province_id: String)

const ProvinceNodeScene := preload("res://scenes/ui/map/ProvinceNode.tscn")

var state: Node = null
var _nodes: Dictionary = {}       # id -> ProvinceNode
var _edges: Dictionary = {}       # "a|b" -> Line2D (a<b lexicographically)
var _selected_id: String = ""

@onready var _edges_layer: Control = %EdgesLayer
@onready var _nodes_layer: Control = %NodesLayer

func bind_state(s: Node) -> void:
    state = s
    refresh()

func refresh() -> void:
    _clear_all()
    if state == null:
        return
    var graph: ProvinceGraph = state.province_graph
    if graph == null:
        return
    for p: Province in graph.all_provinces():
        _spawn_node(p)
    for p: Province in graph.all_provinces():
        for n_id: String in graph.get_neighbors(p.id):
            _ensure_edge(p.id, n_id)

func set_selected_id(id: String) -> void:
    if _selected_id != "" and _nodes.has(_selected_id):
        _nodes[_selected_id].set_selected(false)
    _selected_id = id
    if id != "" and _nodes.has(id):
        _nodes[id].set_selected(true)

func get_node_for_id(id: String) -> ProvinceNode:
    return _nodes.get(id, null)

func get_node_count() -> int:
    return _nodes.size()

func has_edge(a: String, b: String) -> bool:
    return _edges.has(_edge_key(a, b))

func _spawn_node(p: Province) -> void:
    var pn: ProvinceNode = ProvinceNodeScene.instantiate()
    _nodes_layer.add_child(pn)
    pn.set_province(p)
    pn.pressed.connect(_on_node_pressed)
    _nodes[p.id] = pn

func _ensure_edge(a: String, b: String) -> void:
    var key := _edge_key(a, b)
    if _edges.has(key):
        return
    if not _nodes.has(a) or not _nodes.has(b):
        return
    var line := Line2D.new()
    line.width = UIConstants.MAP_EDGE_WIDTH
    line.default_color = UIConstants.MAP_EDGE_COLOR
    var ca: Vector2 = _nodes[a].position + UIConstants.MAP_NODE_SIZE * 0.5
    var cb: Vector2 = _nodes[b].position + UIConstants.MAP_NODE_SIZE * 0.5
    line.points = PackedVector2Array([ca, cb])
    _edges_layer.add_child(line)
    _edges[key] = line

func _edge_key(a: String, b: String) -> String:
    return (a + "|" + b) if a < b else (b + "|" + a)

func _clear_all() -> void:
    for c in _nodes_layer.get_children():
        c.queue_free()
    for c in _edges_layer.get_children():
        c.queue_free()
    _nodes.clear()
    _edges.clear()

func _on_node_pressed(province_id: String) -> void:
    set_selected_id(province_id)
    emit_signal("province_selected", province_id)
