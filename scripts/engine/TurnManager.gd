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
    _process_active_wars(state)
    _process_missionaries(state)
    _process_diplomacy(state)
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

func _process_active_wars(state: Node) -> void:
    var wm := WarManager.new()
    # Najpierw przejścia stanów i naliczanie weariness
    var still_active: Array[War] = []
    for war: War in state.active_wars:
        war.turns_in_state += 1
        if war.state == "MOBILIZING" and war.turns_in_state >= WarManager.MOBILIZATION_TURNS:
            war.state = "BATTLING"
            war.turns_in_state = 0
        elif war.state == "OCCUPYING" and war.turns_in_state >= WarManager.OCCUPATION_TURNS:
            war.state = "BATTLING"
            war.turns_in_state = 0
        var attacker: Religion = state.get_religion(war.attacker_id)
        var defender: Religion = state.get_religion(war.defender_id)
        if attacker != null:
            attacker.war_weariness = clampf(attacker.war_weariness + WarManager.WEARINESS_PER_TURN, 0.0, 100.0)
        if defender != null:
            defender.war_weariness = clampf(defender.war_weariness + WarManager.WEARINESS_PER_TURN, 0.0, 100.0)
        still_active.append(war)
    state.active_wars = still_active
    # Drugi przebieg: force_loss dla stron z weariness >= próg.
    # Tie-break: atakujący sprawdzany pierwszy (elif), więc przy jednoczesnym przekroczeniu
    # progu obie strony — atakujący przegrywa. Defender'a excess weariness pozostaje
    # i wyzwoli force_loss w kolejnej turze, jeśli wojna by trwała (a nie trwa, bo wojna
    # właśnie się skończyła force_loss atakującego).
    var to_force: Array = []
    for war: War in state.active_wars:
        var attacker: Religion = state.get_religion(war.attacker_id)
        var defender: Religion = state.get_religion(war.defender_id)
        if attacker != null and attacker.war_weariness >= WarManager.WEARINESS_FORCED_PEACE:
            to_force.append({"war": war, "loser_id": war.attacker_id})
        elif defender != null and defender.war_weariness >= WarManager.WEARINESS_FORCED_PEACE:
            to_force.append({"war": war, "loser_id": war.defender_id})
    for entry: Dictionary in to_force:
        wm.force_loss(entry["war"], entry["loser_id"], state)

func _process_diplomacy(state: Node) -> void:
    var dm := DiplomacyManager.new()
    for rel: RelationState in state.relations:
        if not _pair_in_active_war(state, rel.religion_a_id, rel.religion_b_id):
            rel.military_tension = clampf(rel.military_tension - DiplomacyManager.PEACE_TENSION_DECAY_PER_TURN, 0.0, 100.0)
    dm.evaluate_coalitions(state)
    dm.dissolve_coalitions(state)

func _pair_in_active_war(state: Node, a: String, b: String) -> bool:
    for war: War in state.active_wars:
        if war.state == "ENDED":
            continue
        if (war.attacker_id == a and war.defender_id == b) or (war.attacker_id == b and war.defender_id == a):
            return true
    return false

func _process_missionaries(state: Node) -> void:
    var doctm := DoctrineManager.new()
    var still_active: Array[MissionaryMission] = []
    for mission: MissionaryMission in state.missionary_missions:
        mission.turns_remaining -= 1
        if mission.turns_remaining > 0:
            still_active.append(mission)
            continue
        # Spec sec.2 "Misjonarze Wymienni" — przy powrocie misjonarza, target to religia
        # przyjmująca obcą ideę; jej Dogmatyzm zmniejsza skuteczność, jej Ekskluzywizm
        # generuje napięcie u własnej dominującej frakcji ("własna frakcja konserwatywna").
        # send_missionaries tworzy symetryczną parę misji, więc każda religia jest sprawdzana
        # jako target dokładnie raz.
        var target: Religion = state.get_religion(mission.target_id)
        var idea := doctm.generate_idea(mission.source_id, mission.target_id, state)
        if idea != null:
            if target != null and target.get_axis("A") > DiplomacyManager.DOGMATYZM_RESISTANCE_THRESHOLD:
                idea.delta *= DiplomacyManager.DOGMATYZM_IDEA_DELTA_MULTIPLIER
            state.pending_ideas.append(idea)
        if target != null and target.get_axis("C") < DiplomacyManager.EKSKLUZYWIZM_FACTION_THRESHOLD:
            var dom := target.dominant_faction()
            if dom != null:
                dom.add_tension(DiplomacyManager.EKSKLUZYWIZM_FACTION_TENSION_BUMP)
    state.missionary_missions = still_active
