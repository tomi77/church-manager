extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")
const RelationStateScript := preload("res://scripts/engine/RelationState.gd")
const CoalitionScript := preload("res://scripts/engine/Coalition.gd")
const DiplomacyManagerScript := preload("res://scripts/engine/DiplomacyManager.gd")

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

func test_declare_alliance_blocked_by_exclusivity() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    _pin_axes(src, 50.0, 50.0, 15.0, 50.0)  # C=15 → Ekskluzywizm 85
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 70.0
    var ok := dm.declare_alliance(gs, "islam", "chr_zachodnie")
    assert_false(ok)
    assert_false(rel.alliance_active)
    assert_eq(src.prestige, 50)

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
