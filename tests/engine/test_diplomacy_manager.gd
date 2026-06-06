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
