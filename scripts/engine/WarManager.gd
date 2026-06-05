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
