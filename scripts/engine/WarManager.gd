class_name WarManager
extends RefCounted

# --- Stałe wojny ---
const MOBILIZATION_TURNS := 2
const OCCUPATION_TURNS := 2
const WEARINESS_PER_TURN := 3.0
const WEARINESS_FORCED_PEACE := 90.0
const DECLARE_WAR_PRESTIGE := 10

# --- Stałe siły militarnej ---
const BASE_POPULATION_FACTOR := 0.1
const BASE_PRESTIGE_FACTOR := 2.0

const CB_BONUS: Dictionary = {
    "krucjata": 0.30,
    "dzihad": 0.40,
    "wojna_sprawiedliwa": 0.20,
    "nawrocenie_mieczem": 0.10,
    "stlumienie_herezji": 0.15,
}

# --- Stałe pokoju ---
const ASYMILACJA_AXIS_C_DELTA := 5.0   # Zasymiluj → atakujący przesuwa C w stronę synkretyzmu

# --- Modyfikatory osi (sumowane) ---
# Każda reguła: {"axis": X, "min": Y} = X >= Y → bonus; {"axis": X, "max": Y} = X <= Y → bonus
const AXIS_STRENGTH_MODIFIERS: Array = [
    {"axis": "A", "min": 60.0, "bonus": 0.15},    # Dogmatyzm >60
    {"axis": "B", "min": 60.0, "bonus": 0.20},    # Hierarchia >60
    {"axis": "D", "min": 65.0, "bonus": 0.25},    # Transcendencja >65
    {"axis": "D", "max": 35.0, "bonus": 0.15},    # Doczesność >65 → D <35
    {"axis": "C", "min": 60.0, "bonus": 0.10},    # Synkretyzm >60
]

# --- Modyfikatory terenu (broniący prowincji) ---
const TERRAIN_DEFENDER_MODIFIERS: Dictionary = {
    "mountains": 0.15,
    "desert": 0.10,
    "fertile": 0.05,
    "plains": 0.0,
    "coast": 0.0,
}

# --- Kara za zmęczenie wojenne ---
const WEARINESS_PENALTIES: Array = [
    {"min": 75.0, "penalty": 0.30},
    {"min": 55.0, "penalty": 0.20},
    {"min": 30.0, "penalty": 0.10},
]

# --- 3 opcje Teologii klęski ---
const DEFEAT_OPTIONS: Array = [
    {"label": "Kara za grzechy", "axis": "A", "delta": 5.0},      # Dogmatyzm
    {"label": "Wola niezbadana", "axis": "A", "delta": -8.0},     # Mistycyzm
    {"label": "Reformujemy się", "axis": "B", "delta": -6.0},     # Równouprawnienie
]

# --- CB z osi: każde CB wymaga zestawu reguł osi (wszystkie muszą być spełnione) ---
# Reguła: {"axis": X, "min": Y} = X >= Y; {"axis": X, "max": Y} = X <= Y
# UWAGA semantyka: min/max są INCLUSIVE na granicy (np. max=25 dopuszcza C=25).
# Spec używa strict ">" ("Ekskluzywizm >75"), ale konwencja repo (DoctrineManager.AXIS_THRESHOLDS)
# jest inclusive — celowo zachowujemy spójność.
const CB_AXIS_REQUIREMENTS: Dictionary = {
    "krucjata":           [{"axis": "C", "max": 25.0}, {"axis": "D", "max": 40.0}],   # Ekskl >75 + Doczesność >60
    "dzihad":             [{"axis": "C", "max": 25.0}, {"axis": "D", "min": 70.0}],   # Ekskl >75 + Transcendencja >70
    "wojna_sprawiedliwa": [{"axis": "B", "min": 60.0}, {"axis": "D", "max": 50.0}],   # Hierarchia >60 + Doczesność >50
    "nawrocenie_mieczem": [{"axis": "C", "max": 40.0}, {"axis": "A", "min": 65.0}],   # Ekskl >60 + Dogmatyzm >65
}

func available_casus_belli(attacker: Religion, defender: Religion) -> Array[String]:
    var result: Array[String] = []
    for cb_id: String in CB_AXIS_REQUIREMENTS.keys():
        var rules: Array = CB_AXIS_REQUIREMENTS[cb_id]
        if _religion_matches_axis_rules(attacker, rules):
            result.append(cb_id)
    if defender.parent_religion_id == attacker.id and attacker.id != "":
        result.append("stlumienie_herezji")
    return result

func _religion_matches_axis_rules(religion: Religion, rules: Array) -> bool:
    for rule: Dictionary in rules:
        var axis: String = rule.get("axis", "")
        var value := religion.get_axis(axis)
        if rule.has("min") and value < rule["min"]:
            return false
        if rule.has("max") and value > rule["max"]:
            return false
    return true

func declare_war(attacker_id: String, defender_id: String, cb: String, state: Node) -> War:
    var attacker: Religion = state.get_religion(attacker_id)
    var defender: Religion = state.get_religion(defender_id)
    if attacker == null or defender == null:
        return null
    if not available_casus_belli(attacker, defender).has(cb):
        return null
    if attacker.prestige < DECLARE_WAR_PRESTIGE:
        return null
    attacker.add_prestige(-DECLARE_WAR_PRESTIGE)
    var war := War.new()
    war.attacker_id = attacker_id
    war.defender_id = defender_id
    war.casus_belli = cb
    war.state = "MOBILIZING"
    war.turns_in_state = 0
    state.active_wars.append(war)
    return war

func compute_army_strength(religion: Religion, target_province: Province, war: War, state: Node) -> float:
    var owned: Array[Province] = state.province_graph.provinces_with_owner(religion.id)
    var pop_total := 0
    for p: Province in owned:
        pop_total += p.population
    var base := float(pop_total) * BASE_POPULATION_FACTOR + float(religion.prestige) * BASE_PRESTIGE_FACTOR
    var axis_modifier := 0.0
    for rule: Dictionary in AXIS_STRENGTH_MODIFIERS:
        var axis: String = rule["axis"]
        var value := religion.get_axis(axis)
        if rule.has("min") and value >= rule["min"]:
            axis_modifier += rule["bonus"]
        elif rule.has("max") and value <= rule["max"]:
            axis_modifier += rule["bonus"]
    var cb_modifier: float = CB_BONUS.get(war.casus_belli, 0.0)
    var weariness_penalty := 0.0
    for rule: Dictionary in WEARINESS_PENALTIES:
        if religion.war_weariness >= rule["min"]:
            weariness_penalty = rule["penalty"]
            break  # WEARINESS_PENALTIES posortowane od max do min
    var strength := base * (1.0 + axis_modifier) * (1.0 + cb_modifier) * (1.0 - weariness_penalty)
    # Modyfikator terenu tylko dla broniącego
    if religion.id == war.defender_id and target_province != null:
        var terrain_bonus: float = TERRAIN_DEFENDER_MODIFIERS.get(target_province.terrain, 0.0)
        strength *= (1.0 + terrain_bonus)
    return strength

func offer_peace(war: War, terms: Dictionary, state: Node) -> bool:
    if war.state == "ENDED":
        return false
    if terms.has("annexation"):
        var ann: Dictionary = terms["annexation"]
        var provinces: Array = ann.get("provinces", [])
        var policy: String = ann.get("policy", "nawracaj")
        _apply_annexation(war, provinces, policy, state)
    if terms.has("forced_council"):
        var fc: Dictionary = terms["forced_council"]
        var axis: String = fc.get("axis", "")
        var delta: float = fc.get("delta", 0.0)
        _apply_forced_council(war, axis, delta, state)
    # Eksterminacja kleru — Task 9
    war.state = "ENDED"
    war.outcome = "WIN" if war.contested_provinces.size() > 0 else "DRAW"
    state.active_wars.erase(war)
    return true

func _apply_annexation(war: War, province_ids: Array, policy: String, state: Node) -> void:
    var attacker: Religion = state.get_religion(war.attacker_id)
    for province_id in province_ids:
        if not war.contested_provinces.has(province_id):
            continue  # tylko prowincje faktycznie okupowane
        var province: Province = state.province_graph.get_province(province_id)
        if province == null:
            continue
        province.owner = war.attacker_id
        match policy:
            "wypedz":
                province.population = 0
            "nawracaj":
                pass  # zostaje populacja i pressure
            "zasymiluj":
                if attacker != null:
                    attacker.shift_axis("C", ASYMILACJA_AXIS_C_DELTA)

func _apply_forced_council(war: War, axis: String, delta: float, state: Node) -> void:
    var defender: Religion = state.get_religion(war.defender_id)
    if defender == null or axis == "":
        return
    defender.shift_axis(axis, delta)

func attack_province(war: War, province_id: String, state: Node) -> Dictionary:
    if war.state != "BATTLING":
        return {"victory": false, "atk_str": 0.0, "def_str": 0.0, "p_win": 0.0, "error": "not_battling"}
    var attacker: Religion = state.get_religion(war.attacker_id)
    var defender: Religion = state.get_religion(war.defender_id)
    var target: Province = state.province_graph.get_province(province_id)
    if attacker == null or defender == null or target == null:
        return {"victory": false, "atk_str": 0.0, "def_str": 0.0, "p_win": 0.0, "error": "invalid_target"}
    var atk_str := compute_army_strength(attacker, target, war, state)
    var def_str := compute_army_strength(defender, target, war, state)
    var total := atk_str + def_str
    var p_win := 0.5 if total <= 0.0 else atk_str / total
    var roll := randf()
    var victory := roll < p_win
    if victory:
        war.battles_won += 1
        if not war.contested_provinces.has(province_id):
            war.contested_provinces.append(province_id)
        war.state = "OCCUPYING"
        war.turns_in_state = 0
    else:
        war.battles_lost += 1
    return {"victory": victory, "atk_str": atk_str, "def_str": def_str, "p_win": p_win}
