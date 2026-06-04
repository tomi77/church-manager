class_name Faction
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var axis_preferences: Array = []
@export var influence: float = 0.0
@export var tension: float = 0.0

func add_tension(delta: float) -> void:
    tension = clampf(tension + delta, 0.0, 100.0)

func get_preference_for_axis(axis: String) -> int:
    for pref: Dictionary in axis_preferences:
        if pref.get("axis", "") == axis:
            return pref.get("direction", 0)
    return 0
