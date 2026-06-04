class_name Province
extends Resource

@export var id: String = ""
@export var owner: String = ""
@export var pressure: Dictionary = {}
@export var population: int = 0
@export var resources: Dictionary = {"food": 0, "gold": 0}
@export var terrain: String = "plains"
@export var neighbors: Array[String] = []
@export var is_holy_site: bool = false

func get_pressure(religion_id: String) -> float:
    return pressure.get(religion_id, 0.0)

func add_pressure(religion_id: String, delta: float) -> void:
    var current := get_pressure(religion_id)
    pressure[religion_id] = clampf(current + delta, 0.0, 100.0)

func dominant_pressure_religion() -> String:
    var best_id := owner
    var best_val := get_pressure(owner)
    for rid: String in pressure:
        if pressure[rid] > best_val:
            best_val = pressure[rid]
            best_id = rid
    return best_id
