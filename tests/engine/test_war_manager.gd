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

func _make_battling_war(gs: Node, att_id: String, def_id: String, contested: Array[String]) -> War:
    var war := War.new()
    war.attacker_id = att_id
    war.defender_id = def_id
    war.casus_belli = ""
    war.state = "BATTLING"
    war.contested_provinces = contested
    gs.active_wars.append(war)
    return war

func test_offer_peace_annexation_wypedz_zeros_population_and_changes_owner() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var anatolia: Province = gs.province_graph.get_province("anatolia")
    var pop_before := anatolia.population
    assert_gt(pop_before, 0)
    var war := _make_battling_war(gs, "islam", "chr_wschodnie", ["anatolia"])
    var ok := wm.offer_peace(war, {
        "annexation": {"provinces": ["anatolia"], "policy": "wypedz"}
    }, gs)
    assert_true(ok)
    assert_eq(anatolia.owner, "islam")
    assert_eq(anatolia.population, 0)
    assert_eq(war.state, "ENDED")
    assert_eq(war.outcome, "WIN")

func test_offer_peace_annexation_nawracaj_keeps_population_and_changes_owner() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var anatolia: Province = gs.province_graph.get_province("anatolia")
    var pop_before := anatolia.population
    var war := _make_battling_war(gs, "islam", "chr_wschodnie", ["anatolia"])
    var ok := wm.offer_peace(war, {
        "annexation": {"provinces": ["anatolia"], "policy": "nawracaj"}
    }, gs)
    assert_true(ok)
    assert_eq(anatolia.owner, "islam")
    assert_eq(anatolia.population, pop_before)
    assert_eq(war.state, "ENDED")

func test_offer_peace_annexation_zasymiluj_shifts_attacker_axis_C() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var att: Religion = gs.get_religion("islam")
    _pin_axes(att, 50.0, 50.0, 30.0, 50.0)  # C=30
    var anatolia: Province = gs.province_graph.get_province("anatolia")
    var pop_before := anatolia.population
    var war := _make_battling_war(gs, "islam", "chr_wschodnie", ["anatolia"])
    var ok := wm.offer_peace(war, {
        "annexation": {"provinces": ["anatolia"], "policy": "zasymiluj"}
    }, gs)
    assert_true(ok)
    assert_eq(anatolia.owner, "islam")
    assert_eq(anatolia.population, pop_before)
    assert_almost_eq(att.get_axis("C"), 30.0 + WarManagerScript.ASYMILACJA_AXIS_C_DELTA, 0.001)

func test_offer_peace_annexation_only_contested_provinces() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var anatolia: Province = gs.province_graph.get_province("anatolia")
    var lewant: Province = gs.province_graph.get_province("lewant")
    var owner_lewant_before := lewant.owner
    # war.contested = ["anatolia"]; terms próbuje aneksować ["anatolia", "lewant"]
    var war := _make_battling_war(gs, "islam", "chr_wschodnie", ["anatolia"])
    var ok := wm.offer_peace(war, {
        "annexation": {"provinces": ["anatolia", "lewant"], "policy": "wypedz"}
    }, gs)
    assert_true(ok)
    assert_eq(anatolia.owner, "islam")
    assert_eq(lewant.owner, owner_lewant_before, "lewant nie był w contested → nie powinien zmienić właściciela")

func test_offer_peace_empty_terms_ends_war_as_draw() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var war := _make_battling_war(gs, "islam", "chr_wschodnie", [])
    var ok := wm.offer_peace(war, {}, gs)
    assert_true(ok)
    assert_eq(war.state, "ENDED")
    assert_eq(war.outcome, "DRAW")

func test_offer_peace_removes_war_from_active_wars() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var war := _make_battling_war(gs, "islam", "chr_wschodnie", ["anatolia"])
    assert_eq(gs.active_wars.size(), 1)
    wm.offer_peace(war, {"annexation": {"provinces": ["anatolia"], "policy": "nawracaj"}}, gs)
    assert_eq(gs.active_wars.size(), 0, "wojna ENDED powinna być usunięta z active_wars")

func test_offer_peace_forced_council_shifts_defender_axis() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var def: Religion = gs.get_religion("chr_wschodnie")
    _pin_axes(def, 50.0, 50.0, 50.0, 50.0)
    var war := _make_battling_war(gs, "islam", "chr_wschodnie", ["anatolia"])
    var ok := wm.offer_peace(war, {
        "annexation": {"provinces": ["anatolia"], "policy": "nawracaj"},
        "forced_council": {"axis": "A", "delta": 8.0}
    }, gs)
    assert_true(ok)
    assert_almost_eq(def.get_axis("A"), 58.0, 0.001)

func test_offer_peace_forced_council_negative_delta() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var def: Religion = gs.get_religion("chr_wschodnie")
    _pin_axes(def, 50.0, 50.0, 50.0, 50.0)
    var war := _make_battling_war(gs, "islam", "chr_wschodnie", [])
    wm.offer_peace(war, {
        "forced_council": {"axis": "B", "delta": -10.0}
    }, gs)
    assert_almost_eq(def.get_axis("B"), 40.0, 0.001)

func test_offer_peace_forced_council_without_annexation_still_works() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var def: Religion = gs.get_religion("chr_wschodnie")
    _pin_axes(def, 60.0, 60.0, 60.0, 60.0)
    var war := _make_battling_war(gs, "islam", "chr_wschodnie", [])
    wm.offer_peace(war, {
        "forced_council": {"axis": "D", "delta": 5.0}
    }, gs)
    assert_almost_eq(def.get_axis("D"), 65.0, 0.001)
    assert_eq(war.state, "ENDED")

func test_offer_peace_clergy_extermination_removes_faction() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var def: Religion = gs.get_religion("chr_wschodnie")
    # chr_wschodnie ma 3 frakcje: patriarchowie, hezychazm, cesarze_teologowie
    assert_eq(def.factions.size(), 3)
    var war := _make_battling_war(gs, "islam", "chr_wschodnie", [])
    wm.offer_peace(war, {
        "clergy_extermination": {"faction_id": "hezychazm"}
    }, gs)
    assert_eq(def.factions.size(), 2)
    assert_null(def.get_faction("hezychazm"))

func test_offer_peace_clergy_extermination_redistributes_influence() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var def: Religion = gs.get_religion("chr_wschodnie")
    # influence_start: patriarchowie=0.45, hezychazm=0.30, cesarze_teologowie=0.25
    var patr := def.get_faction("patriarchowie")
    var ces := def.get_faction("cesarze_teologowie")
    var patr_before := patr.influence
    var ces_before := ces.influence
    var hez_influence := def.get_faction("hezychazm").influence
    var war := _make_battling_war(gs, "islam", "chr_wschodnie", [])
    wm.offer_peace(war, {
        "clergy_extermination": {"faction_id": "hezychazm"}
    }, gs)
    # 0.30 podzielone przez 2 pozostałe frakcje = 0.15 każda
    assert_almost_eq(patr.influence, patr_before + hez_influence / 2.0, 0.001)
    assert_almost_eq(ces.influence, ces_before + hez_influence / 2.0, 0.001)

func test_offer_peace_clergy_extermination_invalid_faction_noop() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var def: Religion = gs.get_religion("chr_wschodnie")
    var size_before := def.factions.size()
    var war := _make_battling_war(gs, "islam", "chr_wschodnie", [])
    wm.offer_peace(war, {
        "clergy_extermination": {"faction_id": "nieistnieje"}
    }, gs)
    assert_eq(def.factions.size(), size_before, "nieistniejąca frakcja → no-op")

func test_offer_peace_clergy_extermination_last_faction_just_removes() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var def: Religion = gs.get_religion("chr_wschodnie")
    # Sztucznie zostaw tylko 1 frakcję
    while def.factions.size() > 1:
        def.factions.pop_back()
    var only_id: String = def.factions[0].id
    var war := _make_battling_war(gs, "islam", "chr_wschodnie", [])
    wm.offer_peace(war, {
        "clergy_extermination": {"faction_id": only_id}
    }, gs)
    assert_eq(def.factions.size(), 0, "ostatnia frakcja usunięta — brak komu rozdzielić wpływ")

func test_force_loss_ends_war_and_creates_defeat_event() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var war := _make_battling_war(gs, "islam", "chr_wschodnie", [])
    war.casus_belli = "dzihad"
    assert_eq(gs.pending_defeat_events.size(), 0)
    wm.force_loss(war, "islam", gs)
    assert_eq(war.state, "ENDED")
    assert_eq(war.outcome, "LOSS")
    assert_eq(gs.active_wars.size(), 0)
    assert_eq(gs.pending_defeat_events.size(), 1)
    var ev: DefeatEvent = gs.pending_defeat_events[0]
    assert_eq(ev.religion_id, "islam")
    assert_eq(ev.opponent_id, "chr_wschodnie")
    assert_eq(ev.cb, "dzihad")
    assert_eq(ev.options.size(), 3)

func test_force_loss_for_defender_creates_defeat_event_for_defender() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var war := _make_battling_war(gs, "islam", "chr_wschodnie", [])
    war.casus_belli = "wojna_sprawiedliwa"
    wm.force_loss(war, "chr_wschodnie", gs)
    assert_eq(war.outcome, "LOSS")
    var ev: DefeatEvent = gs.pending_defeat_events[0]
    assert_eq(ev.religion_id, "chr_wschodnie")
    assert_eq(ev.opponent_id, "islam")

func test_resolve_defeat_shifts_chosen_axis_and_removes_event() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    _pin_axes(rel, 50.0, 50.0, 50.0, 50.0)
    var ev := DefeatEvent.new()
    ev.religion_id = "islam"
    ev.opponent_id = "chr_wschodnie"
    ev.cb = "dzihad"
    ev.options = WarManagerScript.DEFEAT_OPTIONS.duplicate(true)
    gs.pending_defeat_events.append(ev)
    # Opcja 0: "Kara za grzechy", A, +5.0
    wm.resolve_defeat(ev, 0, gs)
    assert_almost_eq(rel.get_axis("A"), 55.0, 0.001)
    assert_eq(gs.pending_defeat_events.size(), 0)

func test_resolve_defeat_negative_delta_option() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    _pin_axes(rel, 50.0, 50.0, 50.0, 50.0)
    var ev := DefeatEvent.new()
    ev.religion_id = "islam"
    ev.options = WarManagerScript.DEFEAT_OPTIONS.duplicate(true)
    gs.pending_defeat_events.append(ev)
    # Opcja 1: "Wola niezbadana", A, -8.0
    wm.resolve_defeat(ev, 1, gs)
    assert_almost_eq(rel.get_axis("A"), 42.0, 0.001)

func test_resolve_defeat_invalid_index_noop() -> void:
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    _pin_axes(rel, 50.0, 50.0, 50.0, 50.0)
    var ev := DefeatEvent.new()
    ev.religion_id = "islam"
    ev.options = WarManagerScript.DEFEAT_OPTIONS.duplicate(true)
    gs.pending_defeat_events.append(ev)
    wm.resolve_defeat(ev, 99, gs)  # invalid
    assert_almost_eq(rel.get_axis("A"), 50.0, 0.001)
    assert_eq(gs.pending_defeat_events.size(), 1, "invalid index — event NIE usunięty")
