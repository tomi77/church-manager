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

# --- Stałe modyfikatorów osi (Plan 05) ---
const HIERARCHIA_COST_THRESHOLD := 60.0      # B>60 → tańsze akcje
const HIERARCHIA_COST_MULTIPLIER := 0.8      # -20% kosztu prestiżu
const SYNKRETYZM_TRUST_LOW_THRESHOLD := 60.0     # C>60 → +20% trust gain
const SYNKRETYZM_TRUST_HIGH_THRESHOLD := 75.0    # C>75 → +35% trust gain
const SYNKRETYZM_TRUST_LOW_MULTIPLIER := 1.20
const SYNKRETYZM_TRUST_HIGH_MULTIPLIER := 1.35

# --- Stałe Soboru Ekumenicznego (Plan 05) ---
const COUNCIL_PRESTIGE_COST := 30
const COUNCIL_TRUST_THRESHOLD := 60.0          # trust >60 (próg progowy)
const COUNCIL_SYNKRETYZM_THRESHOLD := 40.0     # C>40 → Synkretyzm >40
const COUNCIL_MIN_AXIS_DELTA := 3.0            # min |delta| ustępstwa
const COUNCIL_MAX_AXIS_DELTA := 8.0            # max |delta| ustępstwa
const COUNCIL_TRUST_GAIN := 15.0
const COUNCIL_TENSION_DROP := 10.0
const BLOCK_TENSION_FOR_DIALOGUE := 85.0       # napięcie >85 blokuje dialog

# --- Stałe Misjonarzy Wymiennych (Plan 05) ---
const MISSIONARIES_PRESTIGE_COST := 10
const MISSIONARIES_TRUST_THRESHOLD := 30.0
const MISSIONARIES_TURNS := 3
const MISSIONARIES_TRUST_GAIN := 10.0
const MISSIONARIES_EXCLUSIVITY_BLOCK := 20.0   # C<20 → Ekskluzywizm>80 source blokuje wysyłkę misjonarzy

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

func declare_alliance(state: Node, source_id: String, target_id: String) -> bool:
    var source: Religion = state.get_religion(source_id)
    if source == null:
        return false
    if source.prestige < ALLIANCE_PRESTIGE_COST:
        return false
    # Blokada Ekskluzywizm >80 → C < (100 - 80) = 20
    if source.get_axis("C") < ALLIANCE_EXCLUSIVITY_BLOCK:
        return false
    var rel := get_or_create_relation(state, source_id, target_id)
    if rel.theological_trust < ALLIANCE_TRUST_THRESHOLD and rel.economic_cooperation < ALLIANCE_ECONOMIC_THRESHOLD:
        return false
    source.add_prestige(-ALLIANCE_PRESTIGE_COST)
    rel.alliance_active = true
    rel.military_tension = clampf(rel.military_tension - ALLIANCE_TENSION_DROP, 0.0, 100.0)
    return true

func proclaim_interdict(state: Node, source_id: String, target_id: String) -> bool:
    var source: Religion = state.get_religion(source_id)
    if source == null:
        return false
    if source.prestige < INTERDICT_PRESTIGE_COST:
        return false
    var rel := get_or_create_relation(state, source_id, target_id)
    source.add_prestige(-INTERDICT_PRESTIGE_COST)
    rel.military_tension = clampf(rel.military_tension + INTERDICT_TENSION_INCREASE, 0.0, 100.0)
    rel.theological_trust = clampf(rel.theological_trust - INTERDICT_TRUST_DECREASE, 0.0, 100.0)
    return true

func evaluate_coalitions(state: Node) -> void:
    var aggressors: Dictionary = {}  # agresor_id -> Array[String] (ofiary)
    for war: War in state.active_wars:
        if war.state == "ENDED":
            continue
        if not aggressors.has(war.attacker_id):
            aggressors[war.attacker_id] = []
        aggressors[war.attacker_id].append(war.defender_id)
    for aggressor_id: String in aggressors.keys():
        if compute_threat_index(state, aggressor_id) < COALITION_THREAT_THRESHOLD:
            continue
        if _has_active_coalition(state, aggressor_id):
            continue
        var victims: Array = aggressors[aggressor_id]
        var members: Array[String] = []
        for religion: Religion in state.all_religions():
            if religion.id == aggressor_id or religion.id in victims:
                continue
            var rel := get_or_create_relation(state, religion.id, aggressor_id)
            if rel.military_tension >= COALITION_MEMBER_TENSION_THRESHOLD:
                members.append(religion.id)
        if members.size() >= 2:
            var c := Coalition.new()
            c.target_id = aggressor_id
            c.members = members
            state.active_coalitions.append(c)

func _has_active_coalition(state: Node, target_id: String) -> bool:
    for c: Coalition in state.active_coalitions:
        if c.target_id == target_id:
            return true
    return false

func dissolve_coalitions(state: Node) -> void:
    var still_active: Array[Coalition] = []
    for c: Coalition in state.active_coalitions:
        c.turns_active += 1
        if compute_threat_index(state, c.target_id) < COALITION_DISSOLUTION_THREAT:
            continue
        if _aggressor_has_offensive_war(state, c.target_id):
            c.turns_without_conflict = 0
        else:
            c.turns_without_conflict += 1
        if c.turns_without_conflict >= COALITION_DISSOLUTION_PEACE_TURNS:
            continue
        still_active.append(c)
    state.active_coalitions = still_active

func _aggressor_has_offensive_war(state: Node, aggressor_id: String) -> bool:
    for war: War in state.active_wars:
        if war.state == "ENDED":
            continue
        if war.attacker_id == aggressor_id:
            return true
    return false

func peace_council(state: Node, religion_id: String) -> bool:
    var religion: Religion = state.get_religion(religion_id)
    if religion == null:
        return false
    if religion.prestige < PEACE_COUNCIL_PRESTIGE_COST:
        return false
    religion.add_prestige(-PEACE_COUNCIL_PRESTIGE_COST)
    religion.war_weariness = clampf(religion.war_weariness - PEACE_COUNCIL_WEARINESS_DROP, 0.0, 100.0)
    return true

func ecumenical_council(state: Node, source_id: String, target_id: String, axis: String, delta: float) -> bool:
    var source: Religion = state.get_religion(source_id)
    var target: Religion = state.get_religion(target_id)
    if source == null or target == null:
        return false
    # Spec sec.2: brak działania bez wybranego kierunku ustępstwa
    if is_zero_approx(delta):
        return false
    # Blokada: Synkretyzm source ≤40 (spec sec.2 wymaga >40)
    if source.get_axis("C") <= COUNCIL_SYNKRETYZM_THRESHOLD:
        return false
    var rel := get_or_create_relation(state, source_id, target_id)
    # Blokada: trust ≤60 (spec sec.2 wymaga >60)
    if rel.theological_trust <= COUNCIL_TRUST_THRESHOLD:
        return false
    # Blokada: napięcie >85 (spec sec.1)
    if rel.military_tension > BLOCK_TENSION_FOR_DIALOGUE:
        return false
    # Blokada: aktywna wojna między parą
    for war: War in state.active_wars:
        if war.state == "ENDED":
            continue
        if (war.attacker_id == source_id and war.defender_id == target_id) or \
           (war.attacker_id == target_id and war.defender_id == source_id):
            return false
    # Koszt z modyfikatorem Hierarchii
    var cost := int(round(COUNCIL_PRESTIGE_COST * _axis_cost_modifier(source)))
    if source.prestige < cost:
        return false
    # Delta clampowana do [MIN, MAX], znak zachowany
    var sign_val := signf(delta)
    var clamped_abs := clampf(absf(delta), COUNCIL_MIN_AXIS_DELTA, COUNCIL_MAX_AXIS_DELTA)
    var final_delta := clamped_abs * sign_val
    var gain_modifier := _axis_trust_gain_modifier(source)
    source.add_prestige(-cost)
    source.shift_axis(axis, final_delta)
    var gain := COUNCIL_TRUST_GAIN * gain_modifier
    rel.theological_trust = clampf(rel.theological_trust + gain, 0.0, 100.0)
    rel.military_tension = clampf(rel.military_tension - COUNCIL_TENSION_DROP, 0.0, 100.0)
    return true

func send_missionaries(state: Node, source_id: String, target_id: String) -> bool:
    var source: Religion = state.get_religion(source_id)
    var target: Religion = state.get_religion(target_id)
    if source == null or target == null:
        return false
    # Blokada Ekskluzywizm >80 source (C<20, spec sec.3)
    if source.get_axis("C") < MISSIONARIES_EXCLUSIVITY_BLOCK:
        return false
    var rel := get_or_create_relation(state, source_id, target_id)
    # Blokada napięcia >85 (spec sec.1)
    if rel.military_tension > BLOCK_TENSION_FOR_DIALOGUE:
        return false
    # Blokada trust ≤30 (spec sec.2 wymaga >30)
    if rel.theological_trust <= MISSIONARIES_TRUST_THRESHOLD:
        return false
    var cost := int(round(MISSIONARIES_PRESTIGE_COST * _axis_cost_modifier(source)))
    if source.prestige < cost:
        return false
    var gain_modifier := _axis_trust_gain_modifier(source)
    source.add_prestige(-cost)
    var m1 := MissionaryMission.new()
    m1.source_id = source_id
    m1.target_id = target_id
    m1.turns_remaining = MISSIONARIES_TURNS
    state.missionary_missions.append(m1)
    var m2 := MissionaryMission.new()
    m2.source_id = target_id
    m2.target_id = source_id
    m2.turns_remaining = MISSIONARIES_TURNS
    state.missionary_missions.append(m2)
    var gain := MISSIONARIES_TRUST_GAIN * gain_modifier
    rel.theological_trust = clampf(rel.theological_trust + gain, 0.0, 100.0)
    return true

# --- Helpery modyfikatorów osi (Plan 05) ---

func _axis_cost_modifier(religion: Religion) -> float:
    # Hierarchia (oś B) >60 → -20% koszt prestiżu wszystkich akcji
    if religion.get_axis("B") > HIERARCHIA_COST_THRESHOLD:
        return HIERARCHIA_COST_MULTIPLIER
    return 1.0

func _axis_trust_gain_modifier(religion: Religion) -> float:
    # Synkretyzm (oś C) >75 → +35%, >60 → +20% trust gain z akcji teologicznych
    var c := religion.get_axis("C")
    if c > SYNKRETYZM_TRUST_HIGH_THRESHOLD:
        return SYNKRETYZM_TRUST_HIGH_MULTIPLIER
    if c > SYNKRETYZM_TRUST_LOW_THRESHOLD:
        return SYNKRETYZM_TRUST_LOW_MULTIPLIER
    return 1.0
