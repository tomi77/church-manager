extends Node

var current_turn: int = 1
var player_religion_id: String = ""
var province_graph: ProvinceGraph = null

var _religions: Dictionary = {}
var pending_ideas: Array[Idea] = []
var scholar_missions: Array = []  # Untyped: Array[Dictionary] not supported as typed array in GDScript 2.0

func initialize(player_id: String, religions: Array[Religion], graph: ProvinceGraph) -> void:
    player_religion_id = player_id
    province_graph = graph
    _religions.clear()
    for r: Religion in religions:
        _religions[r.id] = r

func get_player_religion() -> Religion:
    return get_religion(player_religion_id)

func get_religion(religion_id: String) -> Religion:
    return _religions.get(religion_id, null)

func all_religions() -> Array[Religion]:
    var result: Array[Religion] = []
    for r: Religion in _religions.values():
        result.append(r)
    return result

func advance_turn() -> void:
    current_turn += 1
