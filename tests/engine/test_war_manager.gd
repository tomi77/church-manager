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

const WarManagerScript := preload("res://scripts/engine/WarManager.gd")

func _pin_axes(rel: Religion, a: float, b: float, c: float, d: float) -> void:
    rel.axes["A"] = a
    rel.axes["B"] = b
    rel.axes["C"] = c
    rel.axes["D"] = d

func test_cb_krucjata_unlocked_when_exclusivism_high_and_doczesnosc_high() -> void:
    # Ekskluzywizm >75 → C <25; Doczesność >60 → D <40
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var att: Religion = gs.get_religion("islam")
    var def: Religion = gs.get_religion("chr_wschodnie")
    _pin_axes(att, 50.0, 50.0, 20.0, 30.0)
    _pin_axes(def, 50.0, 50.0, 50.0, 50.0)
    var cbs := wm.available_casus_belli(att, def)
    assert_true(cbs.has("krucjata"), "Ekskl. 80 + Doczesność 70 powinno odblokować Krucjatę")

func test_cb_dzihad_unlocked_when_exclusivism_high_and_transcendencja_high() -> void:
    # Ekskluzywizm >75 → C <25; Transcendencja >70 → D >70
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var att: Religion = gs.get_religion("islam")
    var def: Religion = gs.get_religion("chr_wschodnie")
    _pin_axes(att, 50.0, 50.0, 20.0, 75.0)
    _pin_axes(def, 50.0, 50.0, 50.0, 50.0)
    var cbs := wm.available_casus_belli(att, def)
    assert_true(cbs.has("dzihad"), "Ekskl. 80 + Transcendencja 75 powinno odblokować Dżihad")

func test_cb_wojna_sprawiedliwa_unlocked_when_hierarchia_high_and_doczesnosc_high() -> void:
    # Hierarchia >60 → B >60; Doczesność >50 → D <50
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var att: Religion = gs.get_religion("islam")
    var def: Religion = gs.get_religion("chr_wschodnie")
    _pin_axes(att, 50.0, 70.0, 50.0, 40.0)
    _pin_axes(def, 50.0, 50.0, 50.0, 50.0)
    var cbs := wm.available_casus_belli(att, def)
    assert_true(cbs.has("wojna_sprawiedliwa"))

func test_cb_nawrocenie_mieczem_unlocked_when_exclusivism_high_and_dogmatyzm_high() -> void:
    # Ekskluzywizm >60 → C <40; Dogmatyzm >65 → A >65
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var att: Religion = gs.get_religion("islam")
    var def: Religion = gs.get_religion("chr_wschodnie")
    _pin_axes(att, 70.0, 50.0, 30.0, 50.0)
    _pin_axes(def, 50.0, 50.0, 50.0, 50.0)
    var cbs := wm.available_casus_belli(att, def)
    assert_true(cbs.has("nawrocenie_mieczem"))

func test_cb_stlumienie_herezji_when_defender_is_schismatic_child() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var att: Religion = gs.get_religion("islam")
    var def: Religion = gs.get_religion("chr_wschodnie")
    _pin_axes(att, 50.0, 50.0, 50.0, 50.0)
    _pin_axes(def, 50.0, 50.0, 50.0, 50.0)
    def.parent_religion_id = "islam"  # symulujemy że defender to schizma islamu
    var cbs := wm.available_casus_belli(att, def)
    assert_true(cbs.has("stlumienie_herezji"))

func test_cb_stlumienie_herezji_NOT_when_defender_is_not_child() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var att: Religion = gs.get_religion("islam")
    var def: Religion = gs.get_religion("chr_wschodnie")
    _pin_axes(att, 50.0, 50.0, 50.0, 50.0)
    _pin_axes(def, 50.0, 50.0, 50.0, 50.0)
    # def.parent_religion_id == "" — nie jest schizmą islamu
    var cbs := wm.available_casus_belli(att, def)
    assert_false(cbs.has("stlumienie_herezji"))

func test_cb_empty_when_all_axes_neutral() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var att: Religion = gs.get_religion("islam")
    var def: Religion = gs.get_religion("chr_wschodnie")
    _pin_axes(att, 50.0, 50.0, 50.0, 50.0)
    _pin_axes(def, 50.0, 50.0, 50.0, 50.0)
    var cbs := wm.available_casus_belli(att, def)
    assert_eq(cbs.size(), 0, "Religia ze wszystkimi osiami w środku nie powinna mieć CB")

func test_declare_war_succeeds_when_cb_available_and_prestige_enough() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var att: Religion = gs.get_religion("islam")
    var def: Religion = gs.get_religion("chr_wschodnie")
    _pin_axes(att, 50.0, 50.0, 20.0, 75.0)  # Dżihad dostępny
    att.prestige = 100
    var war := wm.declare_war("islam", "chr_wschodnie", "dzihad", gs)
    assert_not_null(war)
    assert_eq(war.attacker_id, "islam")
    assert_eq(war.defender_id, "chr_wschodnie")
    assert_eq(war.casus_belli, "dzihad")
    assert_eq(war.state, "MOBILIZING")
    assert_eq(war.turns_in_state, 0)
    assert_eq(gs.active_wars.size(), 1)
    assert_eq(gs.active_wars[0], war)
    assert_eq(att.prestige, 100 - WarManagerScript.DECLARE_WAR_PRESTIGE)

func test_declare_war_fails_when_cb_not_available() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var att: Religion = gs.get_religion("islam")
    _pin_axes(att, 50.0, 50.0, 50.0, 50.0)  # żadne CB nie dostępne
    att.prestige = 100
    var war := wm.declare_war("islam", "chr_wschodnie", "dzihad", gs)
    assert_null(war)
    assert_eq(gs.active_wars.size(), 0)
    assert_eq(att.prestige, 100, "prestige nie powinien być wydany przy fail")

func test_declare_war_fails_when_not_enough_prestige() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var att: Religion = gs.get_religion("islam")
    _pin_axes(att, 50.0, 50.0, 20.0, 75.0)  # Dżihad dostępny
    att.prestige = 5  # <10
    var war := wm.declare_war("islam", "chr_wschodnie", "dzihad", gs)
    assert_null(war)
    assert_eq(gs.active_wars.size(), 0)
    assert_eq(att.prestige, 5)

func test_declare_war_fails_when_attacker_does_not_exist() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var war := wm.declare_war("nieistnieje", "chr_wschodnie", "dzihad", gs)
    assert_null(war)
    assert_eq(gs.active_wars.size(), 0)

func _make_war_for(att_id: String, def_id: String, cb: String, gs: Node) -> War:
    var war := War.new()
    war.attacker_id = att_id
    war.defender_id = def_id
    war.casus_belli = cb
    war.state = "BATTLING"
    return war

func test_compute_strength_base_no_modifiers() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    _pin_axes(rel, 50.0, 50.0, 50.0, 50.0)
    rel.prestige = 300
    rel.war_weariness = 0.0
    # islam vladnie mezopotamia (pop=400) wg JSON
    var target: Province = gs.province_graph.get_province("mezopotamia")
    var war := _make_war_for("islam", "chr_wschodnie", "wojna_sprawiedliwa", gs)
    war.casus_belli = ""  # neutralne CB żeby wyłączyć bonus
    # Baza: 400 * 0.1 + 300 * 2.0 = 40 + 600 = 640
    var strength := wm.compute_army_strength(rel, target, war, gs)
    assert_almost_eq(strength, 640.0, 0.5)

func test_compute_strength_with_dogmatyzm_modifier() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    _pin_axes(rel, 70.0, 50.0, 50.0, 50.0)  # Dogmatyzm >60 → +0.15
    rel.prestige = 300
    rel.war_weariness = 0.0
    var target: Province = gs.province_graph.get_province("mezopotamia")
    var war := _make_war_for("islam", "chr_wschodnie", "", gs)
    # 640 * 1.15 = 736
    var strength := wm.compute_army_strength(rel, target, war, gs)
    assert_almost_eq(strength, 736.0, 0.5)

func test_compute_strength_with_cb_bonus() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    _pin_axes(rel, 50.0, 50.0, 50.0, 50.0)
    rel.prestige = 300
    rel.war_weariness = 0.0
    var target: Province = gs.province_graph.get_province("mezopotamia")
    var war := _make_war_for("islam", "chr_wschodnie", "dzihad", gs)  # +0.40
    # 640 * 1.40 = 896
    var strength := wm.compute_army_strength(rel, target, war, gs)
    assert_almost_eq(strength, 896.0, 0.5)

func test_compute_strength_with_weariness_penalty() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    _pin_axes(rel, 50.0, 50.0, 50.0, 50.0)
    rel.prestige = 300
    rel.war_weariness = 60.0  # >55 → -0.20
    var target: Province = gs.province_graph.get_province("mezopotamia")
    var war := _make_war_for("islam", "chr_wschodnie", "", gs)
    # 640 * 0.80 = 512
    var strength := wm.compute_army_strength(rel, target, war, gs)
    assert_almost_eq(strength, 512.0, 0.5)

func test_compute_strength_terrain_modifier_only_for_defender() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("chr_wschodnie")
    _pin_axes(rel, 50.0, 50.0, 50.0, 50.0)
    rel.prestige = 100
    rel.war_weariness = 0.0
    # chr_wschodnie vladnie armenia (mountains, pop=200)
    var target: Province = gs.province_graph.get_province("armenia")
    var war := _make_war_for("islam", "chr_wschodnie", "", gs)
    # Suma populacji chr_wschodnie: lewant(300) + jerozolima(150) + anatolia(400) + konstantynopol(600) + armenia(200) = 1650
    # Baza: 1650 * 0.1 + 100 * 2.0 = 165 + 200 = 365
    # Modyfikator terenu (mountains): +0.15 dla broniącego
    # 365 * 1.15 = 419.75
    var strength := wm.compute_army_strength(rel, target, war, gs)
    assert_almost_eq(strength, 419.75, 0.5)

func test_compute_strength_terrain_modifier_skipped_for_attacker() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    _pin_axes(rel, 50.0, 50.0, 50.0, 50.0)
    rel.prestige = 300
    rel.war_weariness = 0.0
    var target: Province = gs.province_graph.get_province("armenia")  # mountains
    var war := _make_war_for("islam", "chr_wschodnie", "", gs)
    # islam jest atakującym — modyfikator terenu pomijany
    # Baza 640
    var strength := wm.compute_army_strength(rel, target, war, gs)
    assert_almost_eq(strength, 640.0, 0.5)

func test_attack_province_fails_when_not_in_battling_state() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var att: Religion = gs.get_religion("islam")
    _pin_axes(att, 50.0, 50.0, 20.0, 75.0)
    att.prestige = 100
    var war := wm.declare_war("islam", "chr_wschodnie", "dzihad", gs)
    # war.state == "MOBILIZING"
    var result := wm.attack_province(war, "anatolia", gs)
    assert_eq(result.get("victory", true), false, "atak w MOBILIZING powinien zwracać victory=false")
    assert_eq(war.battles_won, 0)
    assert_eq(war.battles_lost, 0)

func test_attack_province_victory_when_attacker_dominates() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var att: Religion = gs.get_religion("islam")
    var def: Religion = gs.get_religion("chr_wschodnie")
    _pin_axes(att, 50.0, 50.0, 50.0, 50.0)
    _pin_axes(def, 50.0, 50.0, 50.0, 50.0)
    att.prestige = 100000   # ogromna przewaga
    def.prestige = 0
    # przygotuj wojnę w stanie BATTLING (pomijamy declare_war + mobilizację)
    var war := War.new()
    war.attacker_id = "islam"
    war.defender_id = "chr_wschodnie"
    war.casus_belli = ""
    war.state = "BATTLING"
    gs.active_wars.append(war)
    # 100 prób — przewaga sił atakującego jest tak duża, że ≥95 powinno być victory
    var wins := 0
    for i in range(100):
        war.contested_provinces.clear()  # reset między próbami
        war.battles_won = 0
        war.battles_lost = 0
        war.state = "BATTLING"
        var result := wm.attack_province(war, "anatolia", gs)
        if result["victory"]:
            wins += 1
    assert_gte(wins, 95, "przy przewadze atakującego 100000:0 powinno być ≥95%% zwycięstw, było %d" % wins)

func test_attack_province_loss_when_defender_dominates() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var att: Religion = gs.get_religion("islam")
    var def: Religion = gs.get_religion("chr_wschodnie")
    _pin_axes(att, 50.0, 50.0, 50.0, 50.0)
    _pin_axes(def, 50.0, 50.0, 50.0, 50.0)
    att.prestige = 0
    def.prestige = 100000
    var war := War.new()
    war.attacker_id = "islam"
    war.defender_id = "chr_wschodnie"
    war.casus_belli = ""
    war.state = "BATTLING"
    gs.active_wars.append(war)
    var wins := 0
    for i in range(100):
        war.contested_provinces.clear()
        war.battles_won = 0
        war.battles_lost = 0
        war.state = "BATTLING"
        var result := wm.attack_province(war, "anatolia", gs)
        if result["victory"]:
            wins += 1
    assert_lte(wins, 5, "przy przewadze broniącego 100000:0 powinno być ≤5%% zwycięstw, było %d" % wins)

func test_attack_province_victory_changes_state_to_occupying_and_adds_contested() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var att: Religion = gs.get_religion("islam")
    var def: Religion = gs.get_religion("chr_wschodnie")
    _pin_axes(att, 50.0, 50.0, 50.0, 50.0)
    _pin_axes(def, 50.0, 50.0, 50.0, 50.0)
    att.prestige = 100000
    def.prestige = 0
    var war := War.new()
    war.attacker_id = "islam"
    war.defender_id = "chr_wschodnie"
    war.casus_belli = ""
    war.state = "BATTLING"
    gs.active_wars.append(war)
    var result := wm.attack_province(war, "anatolia", gs)
    assert_true(result["victory"])
    assert_eq(war.state, "OCCUPYING")
    assert_eq(war.turns_in_state, 0)
    assert_true(war.contested_provinces.has("anatolia"))
    assert_eq(war.battles_won, 1)

func test_attack_province_loss_keeps_state_battling_and_no_contested() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var att: Religion = gs.get_religion("islam")
    var def: Religion = gs.get_religion("chr_wschodnie")
    _pin_axes(att, 50.0, 50.0, 50.0, 50.0)
    _pin_axes(def, 50.0, 50.0, 50.0, 50.0)
    att.prestige = 0
    def.prestige = 100000
    var war := War.new()
    war.attacker_id = "islam"
    war.defender_id = "chr_wschodnie"
    war.casus_belli = ""
    war.state = "BATTLING"
    gs.active_wars.append(war)
    var result := wm.attack_province(war, "anatolia", gs)
    assert_false(result["victory"])
    assert_eq(war.state, "BATTLING")
    assert_eq(war.contested_provinces.size(), 0)
    assert_eq(war.battles_lost, 1)
