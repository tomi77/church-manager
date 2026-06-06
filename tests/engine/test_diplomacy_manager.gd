extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")
const RelationStateScript := preload("res://scripts/engine/RelationState.gd")
const CoalitionScript := preload("res://scripts/engine/Coalition.gd")
const DiplomacyManagerScript := preload("res://scripts/engine/DiplomacyManager.gd")
const MissionaryMissionScript := preload("res://scripts/engine/MissionaryMission.gd")
const TurnManagerScript := preload("res://scripts/engine/TurnManager.gd")

func _make_state() -> Node:
    var gs: Node = GameStateScript.new()
    var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
    var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
    gs.initialize("islam", religions, graph)
    return gs

func test_relation_state_defaults() -> void:
    var rs: RelationState = RelationStateScript.new()
    assert_eq(rs.religion_a_id, "")
    assert_eq(rs.religion_b_id, "")
    assert_almost_eq(rs.theological_trust, 0.0, 0.001)
    assert_almost_eq(rs.economic_cooperation, 0.0, 0.001)
    assert_almost_eq(rs.military_tension, 0.0, 0.001)
    assert_false(rs.alliance_active)

func test_coalition_defaults() -> void:
    var c: Coalition = CoalitionScript.new()
    assert_eq(c.target_id, "")
    assert_eq(c.members.size(), 0)
    assert_eq(c.turns_active, 0)

func test_game_state_has_relations_empty() -> void:
    var gs := _make_state()
    assert_not_null(gs.relations)
    assert_eq(gs.relations.size(), 0)

func test_game_state_has_active_coalitions_empty() -> void:
    var gs := _make_state()
    assert_not_null(gs.active_coalitions)
    assert_eq(gs.active_coalitions.size(), 0)

func test_pair_key_sorts_alphabetically() -> void:
    var dm: DiplomacyManager = DiplomacyManagerScript.new()
    var key1 := dm._pair_key("islam", "chr_zachodnie")
    var key2 := dm._pair_key("chr_zachodnie", "islam")
    assert_eq(key1, key2)
    assert_eq(key1[0], "chr_zachodnie")
    assert_eq(key1[1], "islam")

func test_get_or_create_relation_creates_new() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    assert_not_null(rel)
    assert_eq(rel.religion_a_id, "chr_zachodnie")  # sorted
    assert_eq(rel.religion_b_id, "islam")
    assert_eq(gs.relations.size(), 1)

func test_get_or_create_relation_returns_existing() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var rel1 := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel1.theological_trust = 42.0
    var rel2 := dm.get_or_create_relation(gs, "chr_zachodnie", "islam")
    assert_eq(rel2, rel1)
    assert_almost_eq(rel2.theological_trust, 42.0, 0.001)
    assert_eq(gs.relations.size(), 1)

func test_get_or_create_relation_symmetric_lookup() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    dm.get_or_create_relation(gs, "chr_zachodnie", "islam")
    dm.get_or_create_relation(gs, "islam", "hinduizm")
    assert_eq(gs.relations.size(), 2)

func test_threat_index_zero_without_wars() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var threat := dm.compute_threat_index(gs, "islam")
    assert_almost_eq(threat, 0.0, 0.001)

func test_threat_index_active_attacker_war() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var war := War.new()
    war.attacker_id = "islam"
    war.defender_id = "chr_zachodnie"
    war.state = "BATTLING"
    gs.active_wars.append(war)
    var threat := dm.compute_threat_index(gs, "islam")
    assert_almost_eq(threat, 20.0, 0.001)

func test_threat_index_active_defender_war() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var war := War.new()
    war.attacker_id = "chr_zachodnie"
    war.defender_id = "islam"
    war.state = "BATTLING"
    gs.active_wars.append(war)
    var threat := dm.compute_threat_index(gs, "islam")
    assert_almost_eq(threat, 5.0, 0.001)

func test_threat_index_multiple_wars_clamped() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    for target_id in ["chr_zachodnie", "hinduizm", "buddyzm", "judaizm", "zoroastryzm", "manicheizm"]:
        var war := War.new()
        war.attacker_id = "islam"
        war.defender_id = target_id
        war.state = "BATTLING"
        gs.active_wars.append(war)
    var threat := dm.compute_threat_index(gs, "islam")
    assert_almost_eq(threat, 100.0, 0.001)  # 6 wojen * 20 = 120, clamp do 100

func test_threat_index_ignores_ended_wars() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var war := War.new()
    war.attacker_id = "islam"
    war.defender_id = "chr_zachodnie"
    war.state = "ENDED"
    gs.active_wars.append(war)
    var threat := dm.compute_threat_index(gs, "islam")
    assert_almost_eq(threat, 0.0, 0.001)

func _pin_axes(rel: Religion, a: float, b: float, c: float, d: float) -> void:
    rel.axes["A"] = a
    rel.axes["B"] = b
    rel.axes["C"] = c
    rel.axes["D"] = d

func test_declare_alliance_success_high_trust() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    _pin_axes(src, 50.0, 50.0, 60.0, 50.0)  # C=60 → Ekskluzywizm 40 (brak blokady)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 55.0
    rel.military_tension = 20.0
    var ok := dm.declare_alliance(gs, "islam", "chr_zachodnie")
    assert_true(ok)
    assert_true(rel.alliance_active)
    assert_eq(src.prestige, 30)  # 50 - 20
    assert_almost_eq(rel.military_tension, 5.0, 0.001)  # 20 - 15

func test_declare_alliance_success_high_economic() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 30
    _pin_axes(src, 50.0, 50.0, 60.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.economic_cooperation = 65.0
    var ok := dm.declare_alliance(gs, "islam", "chr_zachodnie")
    assert_true(ok)
    assert_true(rel.alliance_active)

func test_declare_alliance_fails_no_thresholds() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    _pin_axes(src, 50.0, 50.0, 60.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 30.0
    rel.economic_cooperation = 30.0
    var ok := dm.declare_alliance(gs, "islam", "chr_zachodnie")
    assert_false(ok)
    assert_false(rel.alliance_active)
    assert_eq(src.prestige, 50)  # bez potrącenia

func test_declare_alliance_blocked_by_exclusivity_and_partner_synkretyzm() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    _pin_axes(src, 50.0, 50.0, 15.0, 50.0)  # C=15 → Ekskluzywizm 85
    var dst: Religion = gs.get_religion("chr_zachodnie")
    _pin_axes(dst, 50.0, 50.0, 70.0, 50.0)  # C=70 → Synkretyzm 70 (>60 partnera)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 70.0
    var ok := dm.declare_alliance(gs, "islam", "chr_zachodnie")
    assert_false(ok)
    assert_false(rel.alliance_active)
    assert_eq(src.prestige, 50)

func test_declare_alliance_passes_high_exclusivity_low_partner_synkretyzm() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    _pin_axes(src, 50.0, 50.0, 15.0, 50.0)  # C=15 → Ekskluzywizm 85
    var dst: Religion = gs.get_religion("chr_zachodnie")
    _pin_axes(dst, 50.0, 50.0, 40.0, 50.0)  # C=40 → Synkretyzm 40 (≤60, nie blokuje)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 70.0
    var ok := dm.declare_alliance(gs, "islam", "chr_zachodnie")
    assert_true(ok)
    assert_true(rel.alliance_active)

func test_declare_alliance_passes_high_exclusivity_partner_synkretyzm_at_threshold() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    _pin_axes(src, 50.0, 50.0, 15.0, 50.0)  # C=15 → Ekskluzywizm 85
    var dst: Religion = gs.get_religion("chr_zachodnie")
    _pin_axes(dst, 50.0, 50.0, 60.0, 50.0)  # C=60 exact threshold → NOT blocked (strict >)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 70.0
    var ok := dm.declare_alliance(gs, "islam", "chr_zachodnie")
    assert_true(ok)
    assert_true(rel.alliance_active)

func test_declare_alliance_fails_insufficient_prestige() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 10  # < 20
    _pin_axes(src, 50.0, 50.0, 60.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 70.0
    var ok := dm.declare_alliance(gs, "islam", "chr_zachodnie")
    assert_false(ok)
    assert_false(rel.alliance_active)
    assert_eq(src.prestige, 10)

func test_proclaim_interdict_success() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.military_tension = 10.0
    rel.theological_trust = 40.0
    var ok := dm.proclaim_interdict(gs, "islam", "chr_zachodnie")
    assert_true(ok)
    assert_eq(src.prestige, 35)  # 50 - 15
    assert_almost_eq(rel.military_tension, 30.0, 0.001)
    assert_almost_eq(rel.theological_trust, 15.0, 0.001)

func test_proclaim_interdict_clamps_trust_at_zero() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 10.0
    var ok := dm.proclaim_interdict(gs, "islam", "chr_zachodnie")
    assert_true(ok)
    assert_almost_eq(rel.theological_trust, 0.0, 0.001)

func test_proclaim_interdict_clamps_tension_at_100() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.military_tension = 90.0
    var ok := dm.proclaim_interdict(gs, "islam", "chr_zachodnie")
    assert_true(ok)
    assert_almost_eq(rel.military_tension, 100.0, 0.001)

func test_proclaim_interdict_fails_low_prestige() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 10
    var ok := dm.proclaim_interdict(gs, "islam", "chr_zachodnie")
    assert_false(ok)
    assert_eq(src.prestige, 10)

func _setup_agresor_scenario(gs: Node, agresor: String, ofiary: Array) -> void:
    for ofiara: String in ofiary:
        var w := War.new()
        w.attacker_id = agresor
        w.defender_id = ofiara
        w.state = "BATTLING"
        gs.active_wars.append(w)

func test_evaluate_coalitions_creates_coalition() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    _setup_agresor_scenario(gs, "islam", ["chr_zachodnie", "hinduizm", "buddyzm"])
    for member: String in ["judaizm", "zoroastryzm", "manicheizm"]:
        var rel := dm.get_or_create_relation(gs, member, "islam")
        rel.military_tension = 50.0
    dm.evaluate_coalitions(gs)
    assert_eq(gs.active_coalitions.size(), 1)
    var c: Coalition = gs.active_coalitions[0]
    assert_eq(c.target_id, "islam")
    assert_eq(c.members.size(), 3)
    assert_true("judaizm" in c.members)
    assert_true("zoroastryzm" in c.members)
    assert_true("manicheizm" in c.members)

func test_evaluate_coalitions_skips_low_threat() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    _setup_agresor_scenario(gs, "islam", ["chr_zachodnie"])
    var rel := dm.get_or_create_relation(gs, "judaizm", "islam")
    rel.military_tension = 60.0
    var rel2 := dm.get_or_create_relation(gs, "zoroastryzm", "islam")
    rel2.military_tension = 60.0
    dm.evaluate_coalitions(gs)
    assert_eq(gs.active_coalitions.size(), 0)

func test_evaluate_coalitions_skips_too_few_members() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    _setup_agresor_scenario(gs, "islam", ["chr_zachodnie", "hinduizm", "buddyzm"])
    var rel := dm.get_or_create_relation(gs, "judaizm", "islam")
    rel.military_tension = 60.0
    dm.evaluate_coalitions(gs)
    assert_eq(gs.active_coalitions.size(), 0)

func test_evaluate_coalitions_does_not_duplicate() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    _setup_agresor_scenario(gs, "islam", ["chr_zachodnie", "hinduizm", "buddyzm"])
    for member: String in ["judaizm", "zoroastryzm"]:
        var rel := dm.get_or_create_relation(gs, member, "islam")
        rel.military_tension = 50.0
    dm.evaluate_coalitions(gs)
    dm.evaluate_coalitions(gs)
    assert_eq(gs.active_coalitions.size(), 1)

func test_evaluate_coalitions_excludes_agresor_and_victims() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    _setup_agresor_scenario(gs, "islam", ["chr_zachodnie", "hinduizm", "buddyzm"])
    for victim: String in ["chr_zachodnie", "hinduizm", "buddyzm"]:
        var rel := dm.get_or_create_relation(gs, victim, "islam")
        rel.military_tension = 80.0
    for member: String in ["judaizm", "zoroastryzm"]:
        var rel := dm.get_or_create_relation(gs, member, "islam")
        rel.military_tension = 50.0
    dm.evaluate_coalitions(gs)
    var c: Coalition = gs.active_coalitions[0]
    assert_eq(c.members.size(), 2)
    assert_false("chr_zachodnie" in c.members)

func test_dissolve_coalition_when_threat_drops() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var c := Coalition.new()
    c.target_id = "islam"
    c.members = ["judaizm", "zoroastryzm"]
    gs.active_coalitions.append(c)
    # Brak wojen → threat=0
    dm.dissolve_coalitions(gs)
    assert_eq(gs.active_coalitions.size(), 0)

func test_coalition_persists_when_threat_high() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    _setup_agresor_scenario(gs, "islam", ["chr_zachodnie", "hinduizm", "buddyzm"])
    var c := Coalition.new()
    c.target_id = "islam"
    c.members = ["judaizm", "zoroastryzm"]
    gs.active_coalitions.append(c)
    dm.dissolve_coalitions(gs)
    assert_eq(gs.active_coalitions.size(), 1)
    assert_eq(c.turns_active, 1)

func test_coalition_dissolves_after_5_turns_without_conflict() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    # Konstrukcja stanu: islam ma 1 ofensywę (threat += 20) + 5 obrony (threat += 25) = 45
    var w1 := War.new(); w1.attacker_id = "islam"; w1.defender_id = "chr_zachodnie"; w1.state = "BATTLING"
    gs.active_wars.append(w1)
    for i in range(5):
        var wd := War.new(); wd.attacker_id = "buddyzm"; wd.defender_id = "islam"; wd.state = "BATTLING"
        gs.active_wars.append(wd)
    # threat(islam) = 20 + 5*5 = 45 ≥ 30
    var c := Coalition.new()
    c.target_id = "islam"
    c.members = ["judaizm", "zoroastryzm"]
    gs.active_coalitions.append(c)
    # Pierwsza iteracja: islam wciąż atakuje → reset turns_without_conflict
    dm.dissolve_coalitions(gs)
    assert_eq(gs.active_coalitions.size(), 1)
    # Usuwamy ofensywną wojnę islamu (został tylko jako defender)
    gs.active_wars.remove_at(0)
    # threat = 25, < 30 → natychmiastowy rozpad. Aby utrzymać >30:
    for i in range(2):
        var wd := War.new(); wd.attacker_id = "manicheizm"; wd.defender_id = "islam"; wd.state = "BATTLING"
        gs.active_wars.append(wd)
    # threat(islam) = 7*5 = 35 ≥ 30, ale islam nie atakuje → turns_without_conflict++
    for i in range(5):
        dm.dissolve_coalitions(gs)
    assert_eq(gs.active_coalitions.size(), 0)

func test_peace_council_reduces_weariness() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    src.war_weariness = 60.0
    var ok := dm.peace_council(gs, "islam")
    assert_true(ok)
    assert_eq(src.prestige, 25)  # 50 - 25
    assert_almost_eq(src.war_weariness, 30.0, 0.001)

func test_peace_council_clamps_weariness_at_zero() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    src.war_weariness = 10.0
    var ok := dm.peace_council(gs, "islam")
    assert_true(ok)
    assert_almost_eq(src.war_weariness, 0.0, 0.001)

func test_peace_council_fails_low_prestige() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 20
    src.war_weariness = 60.0
    var ok := dm.peace_council(gs, "islam")
    assert_false(ok)
    assert_eq(src.prestige, 20)
    assert_almost_eq(src.war_weariness, 60.0, 0.001)

func test_integration_coalition_lifecycle() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var tm := TurnManager.new()
    var wm := WarManager.new()
    var islam: Religion = gs.get_religion("islam")
    _pin_axes(islam, 50.0, 50.0, 20.0, 40.0)  # CB krucjata dostępny (C<25, D<40)
    islam.prestige = 100

    # 1. Islam wypowiada 3 wojny — agresja → threat=60
    for ofiara: String in ["chr_zachodnie", "hinduizm", "buddyzm"]:
        var war: War = wm.declare_war("islam", ofiara, "krucjata", gs)
        assert_not_null(war, "declare_war failed for %s" % ofiara)

    # 2. Sąsiedzi mają wysokie napięcie (z declare_war: +20, więc po jednym CB tension=20)
    # podkręcamy ręcznie żeby przekroczyć próg 40
    for member: String in ["judaizm", "zoroastryzm"]:
        var rel := dm.get_or_create_relation(gs, member, "islam")
        rel.military_tension = 50.0

    # 3. Turn 1: TurnManager wywołuje evaluate_coalitions
    tm.process_turn(gs)
    assert_eq(gs.active_coalitions.size(), 1, "koalicja powinna powstać")
    var c: Coalition = gs.active_coalitions[0]
    assert_eq(c.target_id, "islam")
    assert_eq(c.members.size(), 2)
    assert_true("judaizm" in c.members)
    assert_true("zoroastryzm" in c.members)

    # 4. Wszystkie wojny się kończą (czyścimy active_wars) → threat spada do 0
    gs.active_wars.clear()

    # 5. Turn 2: dissolve_coalitions widzi threat<30 → rozpad
    tm.process_turn(gs)
    assert_eq(gs.active_coalitions.size(), 0, "koalicja powinna się rozpaść")

func test_missionary_mission_defaults() -> void:
    var m: MissionaryMission = MissionaryMissionScript.new()
    assert_eq(m.source_id, "")
    assert_eq(m.target_id, "")
    assert_eq(m.turns_remaining, 0)

func test_game_state_has_missionary_missions_empty() -> void:
    var gs := _make_state()
    assert_not_null(gs.missionary_missions)
    assert_eq(gs.missionary_missions.size(), 0)

# --- Modyfikatory osi ---

func test_axis_cost_modifier_default() -> void:
    var dm := DiplomacyManager.new()
    var gs := _make_state()
    var src: Religion = gs.get_religion("islam")
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    assert_almost_eq(dm._axis_cost_modifier(src), 1.0, 0.001)

func test_axis_cost_modifier_hierarchia_high() -> void:
    var dm := DiplomacyManager.new()
    var gs := _make_state()
    var src: Religion = gs.get_religion("islam")
    _pin_axes(src, 50.0, 70.0, 50.0, 50.0)  # B=70 → Hierarchia (próg 60)
    assert_almost_eq(dm._axis_cost_modifier(src), 0.8, 0.001)

func test_axis_trust_gain_modifier_default() -> void:
    var dm := DiplomacyManager.new()
    var gs := _make_state()
    var src: Religion = gs.get_religion("islam")
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    assert_almost_eq(dm._axis_trust_gain_modifier(src), 1.0, 0.001)

func test_axis_trust_gain_modifier_synkretyzm_mid() -> void:
    var dm := DiplomacyManager.new()
    var gs := _make_state()
    var src: Religion = gs.get_religion("islam")
    _pin_axes(src, 50.0, 50.0, 65.0, 50.0)  # C=65 → Synkretyzm średni (>60)
    assert_almost_eq(dm._axis_trust_gain_modifier(src), 1.20, 0.001)

func test_axis_trust_gain_modifier_synkretyzm_high() -> void:
    var dm := DiplomacyManager.new()
    var gs := _make_state()
    var src: Religion = gs.get_religion("islam")
    _pin_axes(src, 50.0, 50.0, 80.0, 50.0)  # C=80 → Synkretyzm wysoki (>75)
    assert_almost_eq(dm._axis_trust_gain_modifier(src), 1.35, 0.001)

func test_axis_cost_modifier_hierarchia_at_threshold() -> void:
    var dm := DiplomacyManager.new()
    var gs := _make_state()
    var src: Religion = gs.get_religion("islam")
    _pin_axes(src, 50.0, 60.0, 50.0, 50.0)  # B=60 → exact threshold, no discount
    assert_almost_eq(dm._axis_cost_modifier(src), 1.0, 0.001)

func test_axis_trust_gain_modifier_synkretyzm_at_low_threshold() -> void:
    var dm := DiplomacyManager.new()
    var gs := _make_state()
    var src: Religion = gs.get_religion("islam")
    _pin_axes(src, 50.0, 50.0, 60.0, 50.0)  # C=60 → exact threshold, no bonus
    assert_almost_eq(dm._axis_trust_gain_modifier(src), 1.0, 0.001)

func test_axis_trust_gain_modifier_synkretyzm_at_high_threshold() -> void:
    var dm := DiplomacyManager.new()
    var gs := _make_state()
    var src: Religion = gs.get_religion("islam")
    _pin_axes(src, 50.0, 50.0, 75.0, 50.0)  # C=75 → exact threshold, only low bonus
    assert_almost_eq(dm._axis_trust_gain_modifier(src), 1.20, 0.001)

# --- Sobór Ekumeniczny ---

func test_ecumenical_council_success() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)  # C=50, Synkretyzm 50 (>40)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 65.0
    rel.military_tension = 20.0
    var initial_a := src.get_axis("A")
    var ok := dm.ecumenical_council(gs, "islam", "chr_zachodnie", "A", 5.0)
    assert_true(ok)
    assert_eq(src.prestige, 20)  # 50 - 30
    assert_almost_eq(src.get_axis("A"), initial_a + 5.0, 0.001)
    assert_almost_eq(rel.theological_trust, 80.0, 0.001)  # 65 + 15
    assert_almost_eq(rel.military_tension, 10.0, 0.001)  # 20 - 10

func test_ecumenical_council_clamps_delta_to_min() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 65.0
    var initial_a := src.get_axis("A")
    var ok := dm.ecumenical_council(gs, "islam", "chr_zachodnie", "A", 1.0)
    assert_true(ok)
    assert_almost_eq(src.get_axis("A"), initial_a + 3.0, 0.001)  # 1.0 → 3.0 (min)

func test_ecumenical_council_clamps_delta_to_max() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 65.0
    var initial_a := src.get_axis("A")
    var ok := dm.ecumenical_council(gs, "islam", "chr_zachodnie", "A", 20.0)
    assert_true(ok)
    assert_almost_eq(src.get_axis("A"), initial_a + 8.0, 0.001)  # 20 → 8 (max)

func test_ecumenical_council_negative_delta_preserves_sign() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 65.0
    var initial_a := src.get_axis("A")
    var ok := dm.ecumenical_council(gs, "islam", "chr_zachodnie", "A", -5.0)
    assert_true(ok)
    assert_almost_eq(src.get_axis("A"), initial_a - 5.0, 0.001)

func test_ecumenical_council_fails_low_trust() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 40.0  # <60
    var ok := dm.ecumenical_council(gs, "islam", "chr_zachodnie", "A", 5.0)
    assert_false(ok)
    assert_eq(src.prestige, 50)

func test_ecumenical_council_fails_low_synkretyzm() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    _pin_axes(src, 50.0, 50.0, 30.0, 50.0)  # C=30 → Synkretyzm <40
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 65.0
    var ok := dm.ecumenical_council(gs, "islam", "chr_zachodnie", "A", 5.0)
    assert_false(ok)

func test_ecumenical_council_fails_high_tension() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 65.0
    rel.military_tension = 90.0  # >85
    var ok := dm.ecumenical_council(gs, "islam", "chr_zachodnie", "A", 5.0)
    assert_false(ok)

func test_ecumenical_council_fails_active_war() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 65.0
    var war := War.new()
    war.attacker_id = "islam"
    war.defender_id = "chr_zachodnie"
    war.state = "BATTLING"
    gs.active_wars.append(war)
    var ok := dm.ecumenical_council(gs, "islam", "chr_zachodnie", "A", 5.0)
    assert_false(ok)

func test_ecumenical_council_fails_insufficient_prestige() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 20  # <30
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 65.0
    var ok := dm.ecumenical_council(gs, "islam", "chr_zachodnie", "A", 5.0)
    assert_false(ok)

func test_ecumenical_council_hierarchia_discount() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 30
    _pin_axes(src, 50.0, 70.0, 50.0, 50.0)  # B=70 → Hierarchia, koszt 30*0.8=24
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 65.0
    var ok := dm.ecumenical_council(gs, "islam", "chr_zachodnie", "A", 5.0)
    assert_true(ok)
    assert_eq(src.prestige, 6)  # 30 - 24

func test_ecumenical_council_synkretyzm_trust_bonus() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    _pin_axes(src, 50.0, 50.0, 80.0, 50.0)  # C=80 → Synkretyzm wysoki (1.35x)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 65.0
    var ok := dm.ecumenical_council(gs, "islam", "chr_zachodnie", "A", 5.0)
    assert_true(ok)
    # trust gain = 15 * 1.35 = 20.25
    assert_almost_eq(rel.theological_trust, 65.0 + 20.25, 0.001)

func test_ecumenical_council_fails_zero_delta() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 65.0
    var ok := dm.ecumenical_council(gs, "islam", "chr_zachodnie", "A", 0.0)
    assert_false(ok)
    assert_eq(src.prestige, 50)

# --- Misjonarze Wymienni (akcja) ---

func test_send_missionaries_success() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 30
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 40.0
    var ok := dm.send_missionaries(gs, "islam", "chr_zachodnie")
    assert_true(ok)
    assert_eq(src.prestige, 20)  # 30 - 10
    assert_eq(gs.missionary_missions.size(), 2)
    assert_almost_eq(rel.theological_trust, 50.0, 0.001)  # 40 + 10

func test_send_missionaries_creates_symmetric_pair() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 30
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 40.0
    dm.send_missionaries(gs, "islam", "chr_zachodnie")
    var sources: Array[String] = []
    var targets: Array[String] = []
    for m: MissionaryMission in gs.missionary_missions:
        sources.append(m.source_id)
        targets.append(m.target_id)
        assert_eq(m.turns_remaining, 3)
    assert_true("islam" in sources)
    assert_true("chr_zachodnie" in sources)
    assert_true("islam" in targets)
    assert_true("chr_zachodnie" in targets)

func test_send_missionaries_fails_low_trust() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 30
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 20.0  # <30
    var ok := dm.send_missionaries(gs, "islam", "chr_zachodnie")
    assert_false(ok)
    assert_eq(src.prestige, 30)
    assert_eq(gs.missionary_missions.size(), 0)

func test_send_missionaries_fails_high_exclusivity() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 30
    _pin_axes(src, 50.0, 50.0, 15.0, 50.0)  # C=15 → Ekskluzywizm 85 (>80)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 40.0
    var ok := dm.send_missionaries(gs, "islam", "chr_zachodnie")
    assert_false(ok)
    assert_eq(gs.missionary_missions.size(), 0)

func test_send_missionaries_fails_high_tension() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 30
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 40.0
    rel.military_tension = 90.0  # >85
    var ok := dm.send_missionaries(gs, "islam", "chr_zachodnie")
    assert_false(ok)

func test_send_missionaries_fails_insufficient_prestige() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 5  # <10
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 40.0
    var ok := dm.send_missionaries(gs, "islam", "chr_zachodnie")
    assert_false(ok)

func test_send_missionaries_hierarchia_discount() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 30
    _pin_axes(src, 50.0, 70.0, 50.0, 50.0)  # B=70 → koszt 10*0.8=8
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 40.0
    var ok := dm.send_missionaries(gs, "islam", "chr_zachodnie")
    assert_true(ok)
    assert_eq(src.prestige, 22)  # 30 - 8

func test_send_missionaries_synkretyzm_trust_bonus() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 30
    _pin_axes(src, 50.0, 50.0, 80.0, 50.0)  # C=80 → Synkretyzm wysoki (1.35x)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 40.0
    var ok := dm.send_missionaries(gs, "islam", "chr_zachodnie")
    assert_true(ok)
    # trust gain = 10 * 1.35 = 13.5
    assert_almost_eq(rel.theological_trust, 40.0 + 13.5, 0.001)

# --- Misjonarze Wymienni (powrót i efekty) ---

func test_missionary_decrement_per_turn() -> void:
    var gs := _make_state()
    var tm := TurnManagerScript.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 30
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    var dst: Religion = gs.get_religion("chr_zachodnie")
    _pin_axes(dst, 50.0, 50.0, 50.0, 50.0)
    var dm := DiplomacyManager.new()
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 40.0
    dm.send_missionaries(gs, "islam", "chr_zachodnie")
    # Po wysłaniu: turns_remaining=3 dla obu misji
    for m: MissionaryMission in gs.missionary_missions:
        assert_eq(m.turns_remaining, 3)
    tm.process_turn(gs)
    # Po 1 turze: turns_remaining=2
    for m: MissionaryMission in gs.missionary_missions:
        assert_eq(m.turns_remaining, 2)

func test_missionary_returns_after_three_turns_spawns_ideas() -> void:
    var gs := _make_state()
    var tm := TurnManagerScript.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 30
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    var dst: Religion = gs.get_religion("chr_zachodnie")
    # Wymuszamy różnicę osi > IDEA_MIN_AXIS_DIFF (=10), żeby Idea powstała
    _pin_axes(dst, 80.0, 50.0, 50.0, 50.0)  # A=80 vs source A=50 → diff 30
    var dm := DiplomacyManager.new()
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 40.0
    dm.send_missionaries(gs, "islam", "chr_zachodnie")
    tm.process_turn(gs)
    tm.process_turn(gs)
    tm.process_turn(gs)
    # Misje powinny już zniknąć
    assert_eq(gs.missionary_missions.size(), 0)
    # 2 idee powinny pojawić się w pending_ideas
    assert_eq(gs.pending_ideas.size(), 2)

func test_missionary_dogmatyzm_reduces_idea_delta() -> void:
    var gs := _make_state()
    var tm := TurnManagerScript.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 30
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)  # A=50
    var dst: Religion = gs.get_religion("chr_zachodnie")
    _pin_axes(dst, 80.0, 50.0, 50.0, 50.0)  # A=80 → Dogmatyzm 80 (>70), diff=30
    var dm := DiplomacyManager.new()
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 40.0
    dm.send_missionaries(gs, "islam", "chr_zachodnie")
    tm.process_turn(gs)
    tm.process_turn(gs)
    tm.process_turn(gs)
    # Idea wracająca DO chr_zachodnie (target=chr_zachodnie) ma 50% delta
    # Idea wracająca DO islam (target=islam, A=50, nie Dogmatyzm) ma 100% delta
    # Idea pochodząca od islam: best_axis=A (diff 30), delta = min(30*0.3, 8) = 8.0
    # Idea pochodząca od chr_zachodnie: też axis A, delta = 8.0
    var idea_to_islam: Idea = null
    var idea_to_chr: Idea = null
    for idea: Idea in gs.pending_ideas:
        if idea.from_religion_id == "chr_zachodnie":
            idea_to_islam = idea  # idea od chr_zachodnie wraca do islam
        else:
            idea_to_chr = idea
    assert_not_null(idea_to_islam)
    assert_not_null(idea_to_chr)
    # delta absolutna dla idei wracającej do islam = 8.0 (pełna), do chr = 4.0 (50%)
    assert_almost_eq(absf(idea_to_islam.delta), 8.0, 0.001)
    assert_almost_eq(absf(idea_to_chr.delta), 4.0, 0.001)

func test_missionary_exclusivity_bumps_faction_tension() -> void:
    var gs := _make_state()
    var tm := TurnManagerScript.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 30
    # Pin osie islam tak żeby JEGO dominująca frakcja nie dryfowała w _update_faction_tensions:
    # islam dominant faction = "ulema" (prefs A+1, B+1), nie diverged przy A=80,B=80.
    _pin_axes(src, 80.0, 80.0, 50.0, 50.0)  # Ekskluzywizm 50 (nie >70), brak dryfu napięcia
    var dst: Religion = gs.get_religion("chr_zachodnie")
    # Pin chr_zachodnie tak by: (a) C=20 → Ekskluzywizm 80 (>70) wywoła bump,
    # (b) papiestwo (dominant, prefs A+1, B+1) NIE diverged przy A=80,B=80 → brak dryfu.
    # Pozostałe frakcje (zakonnicy/reformatorzy) mogą dryfować, ale nie są dominujące.
    _pin_axes(dst, 80.0, 80.0, 20.0, 50.0)
    assert_true(dst.factions.size() > 0, "chr_zachodnie powinno mieć frakcje w danych historycznych")
    var dom_before := dst.dominant_faction()
    var initial_tension := dom_before.tension
    var dm := DiplomacyManager.new()
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 40.0
    dm.send_missionaries(gs, "islam", "chr_zachodnie")
    tm.process_turn(gs)
    tm.process_turn(gs)
    tm.process_turn(gs)
    var dom_after := dst.dominant_faction()
    # Misjonarz z islam→chr (m1) wraca: target=chr_zachodnie, C=20 (Eksklu>70) → bump +10.0
    # Misjonarz z chr→islam (m2) wraca: target=islam, C=50 (Eksklu 50, nie >70) → brak bumpa
    # → tylko chr_zachodnie's dominant faction (papiestwo) dostaje +10.0
    assert_almost_eq(dom_after.tension, initial_tension + 10.0, 0.001)

# --- Auto-join sojuszników do koalicji ---

func test_auto_join_adds_ally_of_member() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    # Koalicja przeciw "islam" z member "judaizm"
    var c := Coalition.new()
    c.target_id = "islam"
    c.members = ["judaizm"]
    gs.active_coalitions.append(c)
    # Sojusz między judaizm a zoroastryzm
    var rel := dm.get_or_create_relation(gs, "judaizm", "zoroastryzm")
    rel.alliance_active = true
    dm.auto_join_allies_to_coalitions(gs)
    assert_eq(c.members.size(), 2)
    assert_true("zoroastryzm" in c.members)

func test_auto_join_skips_target() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var c := Coalition.new()
    c.target_id = "islam"
    c.members = ["judaizm"]
    gs.active_coalitions.append(c)
    # Sojusz judaizm z islam (sam target koalicji) — nie powinien być dodany
    var rel := dm.get_or_create_relation(gs, "judaizm", "islam")
    rel.alliance_active = true
    dm.auto_join_allies_to_coalitions(gs)
    assert_eq(c.members.size(), 1)
    assert_false("islam" in c.members)

func test_auto_join_idempotent() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var c := Coalition.new()
    c.target_id = "islam"
    c.members = ["judaizm", "zoroastryzm"]
    gs.active_coalitions.append(c)
    var rel := dm.get_or_create_relation(gs, "judaizm", "zoroastryzm")
    rel.alliance_active = true
    dm.auto_join_allies_to_coalitions(gs)
    # zoroastryzm już jest członkiem — nie duplikujemy
    assert_eq(c.members.size(), 2)

func test_auto_join_skips_non_alliance() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var c := Coalition.new()
    c.target_id = "islam"
    c.members = ["judaizm"]
    gs.active_coalitions.append(c)
    # Relacja istnieje, ale alliance_active=false
    var rel := dm.get_or_create_relation(gs, "judaizm", "zoroastryzm")
    rel.alliance_active = false
    rel.theological_trust = 90.0  # mimo wysokiego trust — bez sojuszu nie dołącza
    dm.auto_join_allies_to_coalitions(gs)
    assert_eq(c.members.size(), 1)

func test_auto_join_runs_in_process_diplomacy() -> void:
    var gs := _make_state()
    var tm := TurnManagerScript.new()
    var dm := DiplomacyManager.new()
    # Setup koalicji z member judaizm, sojusz judaizm-zoroastryzm
    var c := Coalition.new()
    c.target_id = "islam"
    c.members = ["judaizm"]
    gs.active_coalitions.append(c)
    var rel := dm.get_or_create_relation(gs, "judaizm", "zoroastryzm")
    rel.alliance_active = true
    # Dwie aktywne wojny atakowane przez islam → threat = 2 × 20 = 40 (>30 dissolve, <50 dla nowej koalicji,
    # ale `_has_active_coalition` blokuje tworzenie kolejnej — istniejąca pre-built coalition zostaje
    # nietknięta przez evaluate_coalitions, a dissolve nie usuwa jej przy threat>30).
    var war1 := War.new()
    war1.attacker_id = "islam"
    war1.defender_id = "hinduizm"
    war1.state = "BATTLING"
    gs.active_wars.append(war1)
    var war2 := War.new()
    war2.attacker_id = "islam"
    war2.defender_id = "chr_zachodnie"
    war2.state = "BATTLING"
    gs.active_wars.append(war2)
    tm.process_turn(gs)
    # Po turze: koalicja nadal aktywna i zoroastryzm dołączył przez auto-join
    assert_eq(gs.active_coalitions.size(), 1)
    assert_true("zoroastryzm" in gs.active_coalitions[0].members)

# --- Integration test Plan 05: cykl doktrynalny + koalicja ---

func test_integration_council_missionaries_coalition_lifecycle() -> void:
    var gs := _make_state()
    var tm := TurnManagerScript.new()
    var dm := DiplomacyManager.new()

    var islam: Religion = gs.get_religion("islam")
    islam.prestige = 200
    _pin_axes(islam, 50.0, 50.0, 50.0, 50.0)
    var chr_zach: Religion = gs.get_religion("chr_zachodnie")
    # A=70 (NIE Dogmatyzm bo nie >70 strict), różnica A=20 zapewnia generację Idei nawet po Sobór
    _pin_axes(chr_zach, 70.0, 50.0, 50.0, 50.0)
    var rel_islam_chr := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel_islam_chr.theological_trust = 65.0
    rel_islam_chr.military_tension = 20.0

    # 1. Sobór Ekumeniczny: islam shift A +5 (po Sobór: A=55, diff od chr=15 — dalej ≥10 dla Idea)
    var sobor_ok := dm.ecumenical_council(gs, "islam", "chr_zachodnie", "A", 5.0)
    assert_true(sobor_ok, "Sobór powinien przejść (trust=65>60, Synkr=50>40, brak wojny)")
    assert_almost_eq(islam.get_axis("A"), 55.0, 0.001)
    assert_almost_eq(rel_islam_chr.theological_trust, 80.0, 0.001)  # 65 + 15

    # 2. Misjonarze Wymienni: islam ↔ chr_zachodnie (trust=80>30, nie Eksklu, napięcie 10 po Sobór)
    var send_ok := dm.send_missionaries(gs, "islam", "chr_zachodnie")
    assert_true(send_ok, "Misjonarze powinni zostać wysłani")
    assert_eq(gs.missionary_missions.size(), 2)
    assert_almost_eq(rel_islam_chr.theological_trust, 90.0, 0.001)  # 80 + 10

    # 3. Koalicja: 3 wars przez islam → threat = 3 × 20 = 60 (≥50)
    for defender: String in ["hinduizm", "buddyzm", "religie_arabskie"]:
        var war := War.new()
        war.attacker_id = "islam"
        war.defender_id = defender
        war.state = "BATTLING"
        gs.active_wars.append(war)

    # 4. Tensions kwalifikujące judaizm i manicheizm jako członków koalicji (≥40 vs islam)
    var rel_islam_jud := dm.get_or_create_relation(gs, "islam", "judaizm")
    rel_islam_jud.military_tension = 50.0
    var rel_islam_man := dm.get_or_create_relation(gs, "islam", "manicheizm")
    rel_islam_man.military_tension = 50.0

    # 5. Auto-join setup: judaizm ↔ zoroastryzm alliance, ALE zoroastryzm BEZ tension≥40 vs islam
    var rel_jud_zoro := dm.get_or_create_relation(gs, "judaizm", "zoroastryzm")
    rel_jud_zoro.alliance_active = true
    var rel_islam_zoro := dm.get_or_create_relation(gs, "islam", "zoroastryzm")
    rel_islam_zoro.military_tension = 10.0  # <40 → NIE kwalifikuje przez evaluate_coalitions

    # 6. process_turn × 3 — misjonarze wracają na turze 3, koalicja formuje się na każdej turze
    tm.process_turn(gs)
    tm.process_turn(gs)
    tm.process_turn(gs)

    # 7a. Misjonarze wrócili
    assert_eq(gs.missionary_missions.size(), 0, "misje powinny się zakończyć po 3 turach")
    # 7b. 2 Idee zwrotne w pending_ideas (diff A=15 ≥ IDEA_MIN_AXIS_DIFF=10)
    assert_eq(gs.pending_ideas.size(), 2, "2 idee powinny powstać z misjonarzy wymiennych")
    # 7c. Koalicja przeciw islam istnieje
    assert_eq(gs.active_coalitions.size(), 1, "koalicja powinna powstać przy threat=60")
    var coalition: Coalition = gs.active_coalitions[0]
    assert_eq(coalition.target_id, "islam")
    # 7d. judaizm i manicheizm dołączyli przez evaluate_coalitions (tension≥40)
    assert_true("judaizm" in coalition.members, "judaizm kwalifikuje się przez napięcie")
    assert_true("manicheizm" in coalition.members, "manicheizm kwalifikuje się przez napięcie")
    # 7e. zoroastryzm dołączył przez auto_join (tension <40, ale sojusz z judaizm)
    assert_true("zoroastryzm" in coalition.members, "zoroastryzm dołączył auto-join przez sojusz z judaizm")
