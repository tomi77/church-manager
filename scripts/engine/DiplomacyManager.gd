class_name DiplomacyManager
extends RefCounted

# --- Stałe akcji dyplomatycznych ---
const ALLIANCE_PRESTIGE_COST := 20
const INTERDICT_PRESTIGE_COST := 15
const PEACE_COUNCIL_PRESTIGE_COST := 25

# --- Stałe wskaźników i progów ---
const ALLIANCE_TRUST_THRESHOLD := 50.0       # Zaufanie teologiczne >50 OR
const ALLIANCE_ECONOMIC_THRESHOLD := 60.0    # Współpraca ekonomiczna >60
const ALLIANCE_EXCLUSIVITY_BLOCK := 20.0     # C <20 (Ekskluzywizm >80) → blokada sojuszu
const COALITION_THREAT_THRESHOLD := 50.0
const COALITION_MEMBER_TENSION_THRESHOLD := 40.0   # NPC kwalifikuje się i akceptuje członkostwo deterministycznie powyżej tego progu
const COALITION_DISSOLUTION_THREAT := 30.0
const COALITION_DISSOLUTION_PEACE_TURNS := 5
const PEACE_TENSION_DECAY_PER_TURN := 1.0    # zanik military_tension przy pokoju

# --- Stałe efektów akcji ---
const ALLIANCE_TENSION_DROP := 15.0          # Napięcie militarne -15 obu stronom
const INTERDICT_TENSION_INCREASE := 20.0     # Napięcie militarne +20
const INTERDICT_TRUST_DECREASE := 25.0       # Zaufanie teologiczne -25
const PEACE_COUNCIL_WEARINESS_DROP := 30.0   # war_weariness -= 30
const DECLARE_WAR_TENSION_INCREASE := 20.0   # przy declare_war: military_tension +20

# --- Stałe threat index ---
const THREAT_PER_ACTIVE_WAR := 20.0          # każda wojna jako atakujący
const THREAT_PER_PASSIVE_WAR := 5.0          # każda wojna jako broniący (mniejszy wkład, bo defensywa)
const THREAT_MAX := 100.0

func _pair_key(a: String, b: String) -> Array:
    var pair: Array = [a, b]
    pair.sort()
    return pair

func get_or_create_relation(state: Node, a: String, b: String) -> RelationState:
    var key := _pair_key(a, b)
    for rel: RelationState in state.relations:
        if rel.religion_a_id == key[0] and rel.religion_b_id == key[1]:
            return rel
    var new_rel := RelationState.new()
    new_rel.religion_a_id = key[0]
    new_rel.religion_b_id = key[1]
    state.relations.append(new_rel)
    return new_rel

func compute_threat_index(state: Node, religion_id: String) -> float:
    var threat := 0.0
    for war: War in state.active_wars:
        if war.state == "ENDED":
            continue
        if war.attacker_id == religion_id:
            threat += THREAT_PER_ACTIVE_WAR
        elif war.defender_id == religion_id:
            threat += THREAT_PER_PASSIVE_WAR
    return clampf(threat, 0.0, THREAT_MAX)
