class_name TurnManager
extends RefCounted

const HOLY_SITE_PRESTIGE_PER_TURN := 3
const FACTION_TENSION_PER_DIVERGED_AXIS := 2.0
const AXIS_DIVERGENCE_THRESHOLD := 20.0
const BELIEVER_EXODUS_PER_TURN := 5

func process_turn(state: Node) -> void:
    _apply_passive_pressure(state.province_graph)
    _apply_holy_site_prestige(state)
    _update_faction_tensions(state)
    _process_scholar_missions(state)
    _apply_believer_exodus(state)
    state.advance_turn()

func _apply_passive_pressure(graph: ProvinceGraph) -> void:
    for province: Province in graph.all_provinces():
        for neighbor_id: String in graph.get_neighbors(province.id):
            var neighbor := graph.get_province(neighbor_id)
            if neighbor == null or neighbor.owner == province.owner:
                continue
            var delta := _pressure_delta(province.terrain)
            province.add_pressure(neighbor.owner, delta)

# Uproszczenie PoC: delta na podstawie terenu prowincji odbierającej presję.
# Plan mechaniki.md rozszerzy o populację sąsiada jako mnożnik.
func _pressure_delta(terrain: String) -> float:
    match terrain:
        "mountains": return 1.0
        "desert": return 1.0
        _: return 2.0

func _apply_holy_site_prestige(state: Node) -> void:
    for province: Province in state.province_graph.all_provinces():
        if not province.is_holy_site or province.owner == "":
            continue
        var owner: Religion = state.get_religion(province.owner)
        if owner != null:
            owner.add_prestige(HOLY_SITE_PRESTIGE_PER_TURN)

func _update_faction_tensions(state: Node) -> void:
    for religion: Religion in state.all_religions():
        for faction: Faction in religion.factions:
            var tension_delta := _compute_faction_tension_delta(religion, faction)
            faction.add_tension(tension_delta)

func _compute_faction_tension_delta(religion: Religion, faction: Faction) -> float:
    var delta := 0.0
    for pref: Dictionary in faction.axis_preferences:
        var axis: String = pref.get("axis", "")
        var direction: int = pref.get("direction", 0)
        var axis_val := religion.get_axis(axis)
        var preferred_high := direction > 0
        var diverged := (preferred_high and axis_val < 100.0 - AXIS_DIVERGENCE_THRESHOLD) or \
                        (not preferred_high and axis_val > AXIS_DIVERGENCE_THRESHOLD)
        if diverged:
            delta += FACTION_TENSION_PER_DIVERGED_AXIS
    return delta

func _process_scholar_missions(state: Node) -> void:
    var dm := DoctrineManager.new()
    var still_active: Array = []
    for mission: Dictionary in state.scholar_missions:
        mission["turns_remaining"] -= 1
        if mission["turns_remaining"] <= 0:
            var idea := dm.generate_idea(mission["from_religion_id"], mission["to_religion_id"], state)
            if idea != null:
                state.pending_ideas.append(idea)
        else:
            still_active.append(mission)
    state.scholar_missions = still_active

func _apply_believer_exodus(state: Node) -> void:
    var sm := SchismManager.new()
    for religion: Religion in state.all_religions():
        var has_phase2 := false
        for faction: Faction in religion.factions:
            if sm.get_phase(faction) >= 2:
                has_phase2 = true
                break
        if not has_phase2:
            continue
        for province: Province in state.province_graph.provinces_with_owner(religion.id):
            province.population = maxi(0, province.population - BELIEVER_EXODUS_PER_TURN)
