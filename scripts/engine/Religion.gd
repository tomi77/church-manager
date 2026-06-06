class_name Religion
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var icon: String = ""
@export var axes: Dictionary = {"A": 50.0, "B": 50.0, "C": 50.0, "D": 50.0}
@export var prestige: int = 0
@export var holy_sites: Array[String] = []
@export var factions: Array[Faction] = []
@export var trait_id: String = ""
@export var color: String = "#ffffff"
@export var accent_color: String = "#ffffff"
@export var war_weariness: float = 0.0
@export var parent_religion_id: String = ""
@export var resources: int = 0                   # waluta trybutu i soborów
@export var suzerain_id: String = ""             # "" = wolna; nie-"" = id patrona
@export var interdict_immunity_until: int = 0    # turn numer do którego Interdykt jest blokowany

func get_axis(axis: String) -> float:
    return axes.get(axis, 50.0)

func shift_axis(axis: String, delta: float) -> void:
    if not axes.has(axis):
        return
    axes[axis] = clampf(get_axis(axis) + delta, 0.0, 100.0)

func get_faction(faction_id: String) -> Faction:
    for f: Faction in factions:
        if f.id == faction_id:
            return f
    return null

func dominant_faction() -> Faction:
    var best: Faction = null
    for f: Faction in factions:
        if best == null or f.influence > best.influence:
            best = f
    return best

func add_prestige(delta: int) -> void:
    prestige = maxi(0, prestige + delta)
