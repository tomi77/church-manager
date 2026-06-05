extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
    var gs: Node = GameStateScript.new()
    var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
    var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
    gs.initialize("islam", religions, graph)
    return gs

func test_religion_has_war_weariness_default_zero() -> void:
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    assert_almost_eq(rel.war_weariness, 0.0, 0.001)

func test_religion_has_parent_religion_id_default_empty() -> void:
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    assert_eq(rel.parent_religion_id, "")

func test_game_state_has_active_wars_empty() -> void:
    var gs := _make_state()
    assert_not_null(gs.active_wars)
    assert_eq(gs.active_wars.size(), 0)

func test_game_state_has_pending_defeat_events_empty() -> void:
    var gs := _make_state()
    assert_not_null(gs.pending_defeat_events)
    assert_eq(gs.pending_defeat_events.size(), 0)

func test_war_has_default_fields() -> void:
    var war := War.new()
    assert_eq(war.attacker_id, "")
    assert_eq(war.defender_id, "")
    assert_eq(war.casus_belli, "")
    assert_eq(war.state, "MOBILIZING")
    assert_eq(war.turns_in_state, 0)
    assert_eq(war.contested_provinces.size(), 0)
    assert_eq(war.battles_won, 0)
    assert_eq(war.battles_lost, 0)
    assert_eq(war.outcome, "")

func test_war_fields_are_settable() -> void:
    var war := War.new()
    war.attacker_id = "islam"
    war.defender_id = "chr_wschodnie"
    war.casus_belli = "krucjata"
    war.state = "BATTLING"
    war.turns_in_state = 3
    war.contested_provinces = ["anatolia"]
    war.battles_won = 2
    war.battles_lost = 1
    war.outcome = "WIN"
    assert_eq(war.attacker_id, "islam")
    assert_eq(war.defender_id, "chr_wschodnie")
    assert_eq(war.casus_belli, "krucjata")
    assert_eq(war.state, "BATTLING")
    assert_eq(war.turns_in_state, 3)
    assert_eq(war.contested_provinces[0], "anatolia")
    assert_eq(war.battles_won, 2)
    assert_eq(war.battles_lost, 1)
    assert_eq(war.outcome, "WIN")

func test_defeat_event_has_default_fields() -> void:
    var ev := DefeatEvent.new()
    assert_eq(ev.religion_id, "")
    assert_eq(ev.opponent_id, "")
    assert_eq(ev.cb, "")
    assert_eq(ev.options.size(), 0)

func test_defeat_event_fields_are_settable() -> void:
    var ev := DefeatEvent.new()
    ev.religion_id = "islam"
    ev.opponent_id = "chr_wschodnie"
    ev.cb = "wojna_sprawiedliwa"
    ev.options = [
        {"label": "Kara za grzechy", "axis": "A", "delta": 5.0},
        {"label": "Wola niezbadana", "axis": "A", "delta": -8.0},
    ]
    assert_eq(ev.religion_id, "islam")
    assert_eq(ev.options.size(), 2)
    assert_eq(ev.options[0]["axis"], "A")
