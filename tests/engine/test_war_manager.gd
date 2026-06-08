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
	war.defender_id = "eastern_christianity"
	war.casus_belli = "krucjata"
	war.state = "BATTLING"
	war.turns_in_state = 3
	war.contested_provinces = ["anatolia"]
	war.battles_won = 2
	war.battles_lost = 1
	war.outcome = "WIN"
	assert_eq(war.attacker_id, "islam")
	assert_eq(war.defender_id, "eastern_christianity")
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
	ev.opponent_id = "eastern_christianity"
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
	var def: Religion = gs.get_religion("eastern_christianity")
	_pin_axes(att, 50.0, 50.0, 20.0, 30.0)
	_pin_axes(def, 50.0, 50.0, 50.0, 50.0)
	var cbs := wm.available_casus_belli(att, def, gs)
	assert_true(cbs.has("krucjata"), "Ekskl. 80 + Doczesność 70 powinno odblokować Krucjatę")

func test_cb_dzihad_unlocked_when_exclusivism_high_and_transcendencja_high() -> void:
	# Ekskluzywizm >75 → C <25; Transcendencja >70 → D >70
	var wm := WarManagerScript.new()
	var gs := _make_state()
	var att: Religion = gs.get_religion("islam")
	var def: Religion = gs.get_religion("eastern_christianity")
	_pin_axes(att, 50.0, 50.0, 20.0, 75.0)
	_pin_axes(def, 50.0, 50.0, 50.0, 50.0)
	var cbs := wm.available_casus_belli(att, def, gs)
	assert_true(cbs.has("dzihad"), "Ekskl. 80 + Transcendencja 75 powinno odblokować Dżihad")

func test_cb_wojna_sprawiedliwa_unlocked_when_hierarchia_high_and_doczesnosc_high() -> void:
	# Hierarchia >60 → B >60; Doczesność >50 → D <50
	var wm := WarManagerScript.new()
	var gs := _make_state()
	var att: Religion = gs.get_religion("islam")
	var def: Religion = gs.get_religion("eastern_christianity")
	_pin_axes(att, 50.0, 70.0, 50.0, 40.0)
	_pin_axes(def, 50.0, 50.0, 50.0, 50.0)
	var cbs := wm.available_casus_belli(att, def, gs)
	assert_true(cbs.has("wojna_sprawiedliwa"))

func test_cb_nawrocenie_mieczem_unlocked_when_exclusivism_high_and_dogmatyzm_high() -> void:
	# Ekskluzywizm >60 → C <40; Dogmatyzm >65 → A >65
	var wm := WarManagerScript.new()
	var gs := _make_state()
	var att: Religion = gs.get_religion("islam")
	var def: Religion = gs.get_religion("eastern_christianity")
	_pin_axes(att, 70.0, 50.0, 30.0, 50.0)
	_pin_axes(def, 50.0, 50.0, 50.0, 50.0)
	var cbs := wm.available_casus_belli(att, def, gs)
	assert_true(cbs.has("nawrocenie_mieczem"))

func test_cb_stlumienie_herezji_when_defender_is_schismatic_child() -> void:
	var wm := WarManagerScript.new()
	var gs := _make_state()
	var att: Religion = gs.get_religion("islam")
	var def: Religion = gs.get_religion("eastern_christianity")
	_pin_axes(att, 50.0, 50.0, 50.0, 50.0)
	_pin_axes(def, 50.0, 50.0, 50.0, 50.0)
	def.parent_religion_id = "islam"  # symulujemy że defender to schizma islamu
	var cbs := wm.available_casus_belli(att, def, gs)
	assert_true(cbs.has("stlumienie_herezji"))

func test_cb_stlumienie_herezji_NOT_when_defender_is_not_child() -> void:
	var wm := WarManagerScript.new()
	var gs := _make_state()
	var att: Religion = gs.get_religion("islam")
	var def: Religion = gs.get_religion("eastern_christianity")
	_pin_axes(att, 50.0, 50.0, 50.0, 50.0)
	_pin_axes(def, 50.0, 50.0, 50.0, 50.0)
	# def.parent_religion_id == "" — nie jest schizmą islamu
	var cbs := wm.available_casus_belli(att, def, gs)
	assert_false(cbs.has("stlumienie_herezji"))

func test_cb_empty_when_all_axes_neutral() -> void:
	var wm := WarManagerScript.new()
	var gs := _make_state()
	var att: Religion = gs.get_religion("islam")
	var def: Religion = gs.get_religion("eastern_christianity")
	_pin_axes(att, 50.0, 50.0, 50.0, 50.0)
	_pin_axes(def, 50.0, 50.0, 50.0, 50.0)
	var cbs := wm.available_casus_belli(att, def, gs)
	assert_eq(cbs.size(), 0, "Religia ze wszystkimi osiami w środku nie powinna mieć CB")

func test_declare_war_succeeds_when_cb_available_and_prestige_enough() -> void:
	var wm := WarManagerScript.new()
	var gs := _make_state()
	var att: Religion = gs.get_religion("islam")
	var def: Religion = gs.get_religion("eastern_christianity")
	_pin_axes(att, 50.0, 50.0, 20.0, 75.0)	# Dżihad dostępny
	att.prestige = 100
	var war := wm.declare_war("islam", "eastern_christianity", "dzihad", gs)
	assert_not_null(war)
	assert_eq(war.attacker_id, "islam")
	assert_eq(war.defender_id, "eastern_christianity")
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
	_pin_axes(att, 50.0, 50.0, 50.0, 50.0)	# żadne CB nie dostępne
	att.prestige = 100
	var war := wm.declare_war("islam", "eastern_christianity", "dzihad", gs)
	assert_null(war)
	assert_eq(gs.active_wars.size(), 0)
	assert_eq(att.prestige, 100, "prestige nie powinien być wydany przy fail")

func test_declare_war_fails_when_not_enough_prestige() -> void:
	var wm := WarManagerScript.new()
	var gs := _make_state()
	var att: Religion = gs.get_religion("islam")
	_pin_axes(att, 50.0, 50.0, 20.0, 75.0)	# Dżihad dostępny
	att.prestige = 5  # <10
	var war := wm.declare_war("islam", "eastern_christianity", "dzihad", gs)
	assert_null(war)
	assert_eq(gs.active_wars.size(), 0)
	assert_eq(att.prestige, 5)

func test_declare_war_fails_when_attacker_does_not_exist() -> void:
	var wm := WarManagerScript.new()
	var gs := _make_state()
	var war := wm.declare_war("nieistnieje", "eastern_christianity", "dzihad", gs)
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
	var war := _make_war_for("islam", "eastern_christianity", "wojna_sprawiedliwa", gs)
	war.casus_belli = ""  # neutralne CB żeby wyłączyć bonus
	# Baza: 400 * 0.1 + 300 * 2.0 = 40 + 600 = 640
	var strength := wm.compute_army_strength(rel, target, war, gs)
	assert_almost_eq(strength, 640.0, 0.5)

func test_compute_strength_with_dogmatyzm_modifier() -> void:
	var wm := WarManagerScript.new()
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	_pin_axes(rel, 70.0, 50.0, 50.0, 50.0)	# Dogmatyzm >60 → +0.15
	rel.prestige = 300
	rel.war_weariness = 0.0
	var target: Province = gs.province_graph.get_province("mezopotamia")
	var war := _make_war_for("islam", "eastern_christianity", "", gs)
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
	var war := _make_war_for("islam", "eastern_christianity", "dzihad", gs)  # +0.40
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
	var war := _make_war_for("islam", "eastern_christianity", "", gs)
	# 640 * 0.80 = 512
	var strength := wm.compute_army_strength(rel, target, war, gs)
	assert_almost_eq(strength, 512.0, 0.5)

func test_compute_strength_terrain_modifier_only_for_defender() -> void:
	var wm := WarManagerScript.new()
	var gs := _make_state()
	var rel: Religion = gs.get_religion("eastern_christianity")
	_pin_axes(rel, 50.0, 50.0, 50.0, 50.0)
	rel.prestige = 100
	rel.war_weariness = 0.0
	# eastern_christianity vladnie armenia (mountains, pop=200)
	var target: Province = gs.province_graph.get_province("armenia")
	var war := _make_war_for("islam", "eastern_christianity", "", gs)
	# Suma populacji eastern_christianity: lewant(300) + jerozolima(150) + anatolia(400) + konstantynopol(600) + armenia(200) = 1650
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
	var war := _make_war_for("islam", "eastern_christianity", "", gs)
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
	var war := wm.declare_war("islam", "eastern_christianity", "dzihad", gs)
	# war.state == "MOBILIZING"
	var result := wm.attack_province(war, "anatolia", gs)
	assert_eq(result.get("victory", true), false, "atak w MOBILIZING powinien zwracać victory=false")
	assert_eq(war.battles_won, 0)
	assert_eq(war.battles_lost, 0)

func test_attack_province_victory_when_attacker_dominates() -> void:
	var wm := WarManagerScript.new()
	var gs := _make_state()
	var att: Religion = gs.get_religion("islam")
	var def: Religion = gs.get_religion("eastern_christianity")
	_pin_axes(att, 50.0, 50.0, 50.0, 50.0)
	_pin_axes(def, 50.0, 50.0, 50.0, 50.0)
	att.prestige = 100000	# ogromna przewaga
	def.prestige = 0
	# przygotuj wojnę w stanie BATTLING (pomijamy declare_war + mobilizację)
	var war := War.new()
	war.attacker_id = "islam"
	war.defender_id = "eastern_christianity"
	war.casus_belli = ""
	war.state = "BATTLING"
	gs.active_wars.append(war)
	# 100 prób — przewaga sił atakującego jest tak duża, że ≥95 powinno być victory
	var wins := 0
	for i in range(100):
		war.contested_provinces.clear()	 # reset między próbami
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
	var def: Religion = gs.get_religion("eastern_christianity")
	_pin_axes(att, 50.0, 50.0, 50.0, 50.0)
	_pin_axes(def, 50.0, 50.0, 50.0, 50.0)
	att.prestige = 0
	def.prestige = 100000
	var war := War.new()
	war.attacker_id = "islam"
	war.defender_id = "eastern_christianity"
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
	var def: Religion = gs.get_religion("eastern_christianity")
	_pin_axes(att, 50.0, 50.0, 50.0, 50.0)
	_pin_axes(def, 50.0, 50.0, 50.0, 50.0)
	att.prestige = 100000
	def.prestige = 0
	var war := War.new()
	war.attacker_id = "islam"
	war.defender_id = "eastern_christianity"
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
	var def: Religion = gs.get_religion("eastern_christianity")
	_pin_axes(att, 50.0, 50.0, 50.0, 50.0)
	_pin_axes(def, 50.0, 50.0, 50.0, 50.0)
	att.prestige = 0
	def.prestige = 100000
	var war := War.new()
	war.attacker_id = "islam"
	war.defender_id = "eastern_christianity"
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
	var war := _make_battling_war(gs, "islam", "eastern_christianity", ["anatolia"])
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
	var war := _make_battling_war(gs, "islam", "eastern_christianity", ["anatolia"])
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
	_pin_axes(att, 50.0, 50.0, 30.0, 50.0)	# C=30
	var anatolia: Province = gs.province_graph.get_province("anatolia")
	var pop_before := anatolia.population
	var war := _make_battling_war(gs, "islam", "eastern_christianity", ["anatolia"])
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
	var war := _make_battling_war(gs, "islam", "eastern_christianity", ["anatolia"])
	var ok := wm.offer_peace(war, {
		"annexation": {"provinces": ["anatolia", "lewant"], "policy": "wypedz"}
	}, gs)
	assert_true(ok)
	assert_eq(anatolia.owner, "islam")
	assert_eq(lewant.owner, owner_lewant_before, "lewant nie był w contested → nie powinien zmienić właściciela")

func test_offer_peace_empty_terms_ends_war_as_draw() -> void:
	var wm := WarManagerScript.new()
	var gs := _make_state()
	var war := _make_battling_war(gs, "islam", "eastern_christianity", [])
	var ok := wm.offer_peace(war, {}, gs)
	assert_true(ok)
	assert_eq(war.state, "ENDED")
	assert_eq(war.outcome, "DRAW")

func test_offer_peace_removes_war_from_active_wars() -> void:
	var wm := WarManagerScript.new()
	var gs := _make_state()
	var war := _make_battling_war(gs, "islam", "eastern_christianity", ["anatolia"])
	assert_eq(gs.active_wars.size(), 1)
	wm.offer_peace(war, {"annexation": {"provinces": ["anatolia"], "policy": "nawracaj"}}, gs)
	assert_eq(gs.active_wars.size(), 0, "wojna ENDED powinna być usunięta z active_wars")

func test_offer_peace_forced_council_shifts_defender_axis() -> void:
	var wm := WarManagerScript.new()
	var gs := _make_state()
	var def: Religion = gs.get_religion("eastern_christianity")
	_pin_axes(def, 50.0, 50.0, 50.0, 50.0)
	var war := _make_battling_war(gs, "islam", "eastern_christianity", ["anatolia"])
	var ok := wm.offer_peace(war, {
		"annexation": {"provinces": ["anatolia"], "policy": "nawracaj"},
		"forced_council": {"axis": "A", "delta": 8.0}
	}, gs)
	assert_true(ok)
	assert_almost_eq(def.get_axis("A"), 58.0, 0.001)

func test_offer_peace_forced_council_negative_delta() -> void:
	var wm := WarManagerScript.new()
	var gs := _make_state()
	var def: Religion = gs.get_religion("eastern_christianity")
	_pin_axes(def, 50.0, 50.0, 50.0, 50.0)
	var war := _make_battling_war(gs, "islam", "eastern_christianity", [])
	wm.offer_peace(war, {
		"forced_council": {"axis": "B", "delta": -10.0}
	}, gs)
	assert_almost_eq(def.get_axis("B"), 40.0, 0.001)

func test_offer_peace_forced_council_without_annexation_still_works() -> void:
	var wm := WarManagerScript.new()
	var gs := _make_state()
	var def: Religion = gs.get_religion("eastern_christianity")
	_pin_axes(def, 60.0, 60.0, 60.0, 60.0)
	var war := _make_battling_war(gs, "islam", "eastern_christianity", [])
	wm.offer_peace(war, {
		"forced_council": {"axis": "D", "delta": 5.0}
	}, gs)
	assert_almost_eq(def.get_axis("D"), 65.0, 0.001)
	assert_eq(war.state, "ENDED")

func test_offer_peace_clergy_extermination_removes_faction() -> void:
	var wm := WarManagerScript.new()
	var gs := _make_state()
	var def: Religion = gs.get_religion("eastern_christianity")
	# eastern_christianity ma 3 frakcje: patriarchowie, hezychazm, cesarze_teologowie
	assert_eq(def.factions.size(), 3)
	var war := _make_battling_war(gs, "islam", "eastern_christianity", [])
	wm.offer_peace(war, {
		"clergy_extermination": {"faction_id": "hezychazm"}
	}, gs)
	assert_eq(def.factions.size(), 2)
	assert_null(def.get_faction("hezychazm"))

func test_offer_peace_clergy_extermination_redistributes_influence() -> void:
	var wm := WarManagerScript.new()
	var gs := _make_state()
	var def: Religion = gs.get_religion("eastern_christianity")
	# influence_start: patriarchowie=0.45, hezychazm=0.30, cesarze_teologowie=0.25
	var patr := def.get_faction("patriarchowie")
	var ces := def.get_faction("cesarze_teologowie")
	var patr_before := patr.influence
	var ces_before := ces.influence
	var hez_influence := def.get_faction("hezychazm").influence
	var war := _make_battling_war(gs, "islam", "eastern_christianity", [])
	wm.offer_peace(war, {
		"clergy_extermination": {"faction_id": "hezychazm"}
	}, gs)
	# 0.30 podzielone przez 2 pozostałe frakcje = 0.15 każda
	assert_almost_eq(patr.influence, patr_before + hez_influence / 2.0, 0.001)
	assert_almost_eq(ces.influence, ces_before + hez_influence / 2.0, 0.001)

func test_offer_peace_clergy_extermination_invalid_faction_noop() -> void:
	var wm := WarManagerScript.new()
	var gs := _make_state()
	var def: Religion = gs.get_religion("eastern_christianity")
	var size_before := def.factions.size()
	var war := _make_battling_war(gs, "islam", "eastern_christianity", [])
	wm.offer_peace(war, {
		"clergy_extermination": {"faction_id": "nieistnieje"}
	}, gs)
	assert_eq(def.factions.size(), size_before, "nieistniejąca frakcja → no-op")

func test_offer_peace_clergy_extermination_last_faction_just_removes() -> void:
	var wm := WarManagerScript.new()
	var gs := _make_state()
	var def: Religion = gs.get_religion("eastern_christianity")
	# Sztucznie zostaw tylko 1 frakcję
	while def.factions.size() > 1:
		def.factions.pop_back()
	var only_id: String = def.factions[0].id
	var war := _make_battling_war(gs, "islam", "eastern_christianity", [])
	wm.offer_peace(war, {
		"clergy_extermination": {"faction_id": only_id}
	}, gs)
	assert_eq(def.factions.size(), 0, "ostatnia frakcja usunięta — brak komu rozdzielić wpływ")

func test_force_loss_ends_war_and_creates_defeat_event() -> void:
	var wm := WarManagerScript.new()
	var gs := _make_state()
	var war := _make_battling_war(gs, "islam", "eastern_christianity", [])
	war.casus_belli = "dzihad"
	assert_eq(gs.pending_defeat_events.size(), 0)
	wm.force_loss(war, "islam", gs)
	assert_eq(war.state, "ENDED")
	assert_eq(war.outcome, "LOSS")
	assert_eq(gs.active_wars.size(), 0)
	assert_eq(gs.pending_defeat_events.size(), 1)
	var ev: DefeatEvent = gs.pending_defeat_events[0]
	assert_eq(ev.religion_id, "islam")
	assert_eq(ev.opponent_id, "eastern_christianity")
	assert_eq(ev.cb, "dzihad")
	assert_eq(ev.options.size(), 3)

func test_force_loss_for_defender_creates_defeat_event_for_defender() -> void:
	var wm := WarManagerScript.new()
	var gs := _make_state()
	var war := _make_battling_war(gs, "islam", "eastern_christianity", [])
	war.casus_belli = "wojna_sprawiedliwa"
	wm.force_loss(war, "eastern_christianity", gs)
	assert_eq(war.outcome, "LOSS")
	var ev: DefeatEvent = gs.pending_defeat_events[0]
	assert_eq(ev.religion_id, "eastern_christianity")
	assert_eq(ev.opponent_id, "islam")

func test_resolve_defeat_shifts_chosen_axis_and_removes_event() -> void:
	var wm := WarManagerScript.new()
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	_pin_axes(rel, 50.0, 50.0, 50.0, 50.0)
	var ev := DefeatEvent.new()
	ev.religion_id = "islam"
	ev.opponent_id = "eastern_christianity"
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

const DiplomacyManagerScript := preload("res://scripts/engine/DiplomacyManager.gd")

func test_declare_war_increases_military_tension() -> void:
	var gs := _make_state()
	_pin_axes(gs.get_religion("islam"), 50.0, 50.0, 20.0, 30.0)	 # C=20 → Eksk 80; D=30 → Doczesność 70 (Krucjata wymaga >60)
	gs.get_religion("islam").prestige = 50
	var wm := WarManager.new()
	var war: War = wm.declare_war("islam", "western_christianity", "krucjata", gs)
	assert_not_null(war)
	var dm := DiplomacyManager.new()
	var rel := dm.get_or_create_relation(gs, "islam", "western_christianity")
	assert_almost_eq(rel.military_tension, 20.0, 0.001)

# --- CB Rewanż za zniewagę (Plan 07) ---

func test_cb_rewanz_unlocked_when_grievance_active_and_exclusivism_high() -> void:
	var gs := _make_state()
	var wm := WarManager.new()
	var att: Religion = gs.get_religion("islam")
	var def: Religion = gs.get_religion("western_christianity")
	_pin_axes(att, 50.0, 50.0, 20.0, 50.0)	# C=20 → Ekskluzywizm 80
	att.interdict_grievance_from_id = "western_christianity"
	att.interdict_grievance_until = gs.current_turn + 5
	var cbs := wm.available_casus_belli(att, def, gs)
	assert_true("rewanz" in cbs, "Rewanż dostępny przy C<30 + grievance aktywne")

func test_cb_rewanz_blocked_when_exclusivism_too_low() -> void:
	var gs := _make_state()
	var wm := WarManager.new()
	var att: Religion = gs.get_religion("islam")
	var def: Religion = gs.get_religion("western_christianity")
	_pin_axes(att, 50.0, 50.0, 50.0, 50.0)	# C=50 → tolerancyjny
	att.interdict_grievance_from_id = "western_christianity"
	att.interdict_grievance_until = gs.current_turn + 5
	var cbs := wm.available_casus_belli(att, def, gs)
	assert_false("rewanz" in cbs, "Rewanż NIE dostępny przy C>=30")

func test_cb_rewanz_blocked_when_grievance_expired() -> void:
	var gs := _make_state()
	var wm := WarManager.new()
	var att: Religion = gs.get_religion("islam")
	var def: Religion = gs.get_religion("western_christianity")
	_pin_axes(att, 50.0, 50.0, 20.0, 50.0)
	att.interdict_grievance_from_id = "western_christianity"
	att.interdict_grievance_until = gs.current_turn	 # > operator strict → equal nie wystarcza
	var cbs := wm.available_casus_belli(att, def, gs)
	assert_false("rewanz" in cbs, "Rewanż NIE dostępny gdy grievance_until == current_turn (operator > strict)")

func test_cb_rewanz_blocked_when_defender_is_not_grievance_source() -> void:
	var gs := _make_state()
	var wm := WarManager.new()
	var att: Religion = gs.get_religion("islam")
	var other: Religion = gs.get_religion("hinduism")
	_pin_axes(att, 50.0, 50.0, 20.0, 50.0)
	att.interdict_grievance_from_id = "western_christianity"
	att.interdict_grievance_until = gs.current_turn + 5
	var cbs := wm.available_casus_belli(att, other, gs)
	assert_false("rewanz" in cbs, "Rewanż musi być przeciw konkretnemu sprawcy")

func test_cb_rewanz_handles_null_state() -> void:
	var gs := _make_state()
	var wm := WarManager.new()
	var att: Religion = gs.get_religion("islam")
	var def: Religion = gs.get_religion("western_christianity")
	_pin_axes(att, 50.0, 50.0, 20.0, 50.0)
	att.interdict_grievance_from_id = "western_christianity"
	att.interdict_grievance_until = 9999
	var cbs := wm.available_casus_belli(att, def, null)
	assert_false("rewanz" in cbs, "bez state nie ma reaktywnych CB")

func test_cb_rewanz_blocked_when_attacker_equals_defender() -> void:
	var gs := _make_state()
	var wm := WarManager.new()
	var rel: Religion = gs.get_religion("islam")
	_pin_axes(rel, 50.0, 50.0, 20.0, 50.0)
	rel.interdict_grievance_from_id = "islam"
	rel.interdict_grievance_until = gs.current_turn + 5
	var cbs := wm.available_casus_belli(rel, rel, gs)
	assert_false("rewanz" in cbs, "self-Rewanż zablokowany przez guard attacker.id != defender.id")

func test_cb_rewanz_bonus_value() -> void:
	assert_almost_eq(WarManager.CB_BONUS.get("rewanz", -1.0), 0.15, 0.001)

func test_cb_rewanz_blocked_when_grievance_id_empty() -> void:
	# Guard symmetryczny do stlumienie_herezji (attacker.id != ""): puste grievance_from_id
	# NIE może trywialnie sparować z pustym defender.id (np. Religion.new() bez ustawionego id).
	var gs := _make_state()
	var wm := WarManager.new()
	var att: Religion = gs.get_religion("islam")
	_pin_axes(att, 50.0, 50.0, 20.0, 50.0)
	att.interdict_grievance_from_id = ""			 # puste (default)
	att.interdict_grievance_until = gs.current_turn + 5
	var empty_def := Religion.new()					 # nowa religia bez id (id == "")
	var cbs := wm.available_casus_belli(att, empty_def, gs)
	assert_false("rewanz" in cbs, "puste grievance_from_id nie aktywuje Rewanżu nawet gdy defender.id też pusty")

# --- declare_war zużywa grievance (Plan 07) ---

func test_declare_war_rewanz_consumes_grievance() -> void:
	var gs := _make_state()
	var wm := WarManager.new()
	var att: Religion = gs.get_religion("islam")
	var def: Religion = gs.get_religion("western_christianity")
	_pin_axes(att, 50.0, 50.0, 20.0, 50.0)	# Ekskluzywizm
	att.prestige = 50
	att.interdict_grievance_from_id = "western_christianity"
	att.interdict_grievance_until = gs.current_turn + 5
	var war := wm.declare_war("islam", "western_christianity", "rewanz", gs)
	assert_not_null(war, "wojna Rewanż utworzona")
	assert_eq(att.interdict_grievance_from_id, "", "grievance from_id wyzerowane po deklaracji")
	assert_eq(att.interdict_grievance_until, 0, "grievance until wyzerowane po deklaracji")

func test_declare_war_non_rewanz_does_not_consume_grievance() -> void:
	var gs := _make_state()
	var wm := WarManager.new()
	var att: Religion = gs.get_religion("islam")
	var def: Religion = gs.get_religion("western_christianity")
	_pin_axes(att, 50.0, 50.0, 20.0, 30.0)	# Ekskluzywizm + Doczesność → krucjata
	att.prestige = 50
	att.interdict_grievance_from_id = "western_christianity"
	var grievance_turn: int = gs.current_turn + 5
	att.interdict_grievance_until = grievance_turn
	var war := wm.declare_war("islam", "western_christianity", "krucjata", gs)
	assert_not_null(war, "wojna krucjata utworzona")
	assert_eq(att.interdict_grievance_from_id, "western_christianity", "grievance NIE wyzerowane przy CB != rewanz")
	assert_eq(att.interdict_grievance_until, grievance_turn, "okno grievance nietknięte")

func test_declare_war_rewanz_jednorazowy_second_attempt_fails() -> void:
	# Po pierwszej wojnie Rewanż, kolejna nie powinna być możliwa (grievance zużyte).
	var gs := _make_state()
	var wm := WarManager.new()
	var att: Religion = gs.get_religion("islam")
	var def: Religion = gs.get_religion("western_christianity")
	_pin_axes(att, 50.0, 50.0, 20.0, 50.0)
	att.prestige = 100
	att.interdict_grievance_from_id = "western_christianity"
	att.interdict_grievance_until = gs.current_turn + 5
	# Pierwsza wojna — sukces
	assert_not_null(wm.declare_war("islam", "western_christianity", "rewanz", gs))
	# Sanity: grievance zostało zerowane przez declare_war (Task 4),
	# więc kolejny Rewanż wpada na guard CB, NIE na guard prestiżu/wojny.
	assert_eq(att.interdict_grievance_from_id, "", "grievance from_id zerowane po 1. wojnie")
	assert_eq(att.interdict_grievance_until, 0, "grievance until zerowane po 1. wojnie")
	# Druga próba — fail (grievance puste, więc Rewanż nie dostępny)
	var war2 := wm.declare_war("islam", "western_christianity", "rewanz", gs)
	assert_null(war2, "kolejna wojna Rewanż blokowana — grievance jednorazowe")

# --- Bonus HolyWar w święta wojna sojusznicza (Plan 07) ---
#
# UWAGA: testy używają CB "dzihad" (D>=70), bo bonus HolyWar wymaga D>65 —
# CB "krucjata" wymaga D<=40, więc gameplay-owo nigdy nie aktywuje bonusu HolyWar.
# Defenderzy: "eastern_christianity" (5 prowincji m.in. armenia/lewant) i "zoroastrianism" (persja/persepolis)
# — religie WŁAŚCICIELE prowincji w danych historycznych. judaism/hinduism/buddhism NIE mają prowincji,
# więc `provinces_with_owner("judaism")` zwraca []. Target province wybieramy przez get_province("armenia")
# (mountains, owned by eastern_christianity) — wzorzec z istniejących testów compute_strength_terrain_*.

func _setup_holy_war_alliance(gs: Node, att_id: String, ally_id: String, target_id: String, ally_target_id: String) -> Dictionary:
	# Tworzy sojusz + 2 wojny dzihad APPENDOWANE do gs.active_wars (wymóg `_has_holy_war_ally`).
	var dm := DiplomacyManager.new()
	var rel := dm.get_or_create_relation(gs, att_id, ally_id)
	rel.alliance_active = true
	var att_war := _make_war_for(att_id, target_id, "dzihad", gs)
	var ally_war := _make_war_for(ally_id, ally_target_id, "dzihad", gs)
	gs.active_wars.append(att_war)
	gs.active_wars.append(ally_war)
	return {"att_war": att_war, "ally_war": ally_war}

func test_holy_war_bonus_applies_when_attacker_has_d_high_and_ally_in_dzihad() -> void:
	var gs := _make_state()
	var wm := WarManager.new()
	var att: Religion = gs.get_religion("islam")
	_pin_axes(att, 50.0, 50.0, 20.0, 70.0)	 # D=70 > 65 → bonus
	var wars := _setup_holy_war_alliance(gs, "islam", "western_christianity", "eastern_christianity", "zoroastrianism")
	var att_war: War = wars["att_war"]
	var target_prov: Province = gs.province_graph.get_province("armenia")  # owned by eastern_christianity
	var strength_with := wm.compute_army_strength(att, target_prov, att_war, gs)
	# Sanity baseline: usuń bonus przez zerwanie sojuszu, ponownie zmierz.
	for rel: RelationState in gs.relations:
		rel.alliance_active = false
	var strength_without := wm.compute_army_strength(att, target_prov, att_war, gs)
	assert_gt(strength_with, strength_without, "bonus HolyWar zwiększa siłę armii")

func test_holy_war_bonus_blocked_when_d_below_threshold() -> void:
	var gs := _make_state()
	var wm := WarManager.new()
	var att: Religion = gs.get_religion("islam")
	_pin_axes(att, 50.0, 50.0, 20.0, 65.0)	# D=65 → operator > strict, NIE aktywuje +15% (równe progowi)
	var wars := _setup_holy_war_alliance(gs, "islam", "western_christianity", "eastern_christianity", "zoroastrianism")
	var target_prov: Province = gs.province_graph.get_province("armenia")
	var strength_with_d65 := wm.compute_army_strength(att, target_prov, wars["att_war"], gs)
	_pin_axes(att, 50.0, 50.0, 20.0, 66.0)	# D=66 → bonus aktywny
	var strength_with_d66 := wm.compute_army_strength(att, target_prov, wars["att_war"], gs)
	assert_gt(strength_with_d66, strength_with_d65, "bonus tylko przy D>65 (strict, nie >=)")

func test_holy_war_bonus_blocked_without_alliance() -> void:
	var gs := _make_state()
	var wm := WarManager.new()
	var att: Religion = gs.get_religion("islam")
	_pin_axes(att, 50.0, 50.0, 20.0, 70.0)
	# Brak alliance_active — wojny istnieją, ale sojusz NIE
	var att_war := _make_war_for("islam", "eastern_christianity", "dzihad", gs)
	var ally_war := _make_war_for("western_christianity", "zoroastrianism", "dzihad", gs)
	gs.active_wars.append(att_war)
	gs.active_wars.append(ally_war)
	var target_prov: Province = gs.province_graph.get_province("armenia")
	var strength_no_alliance := wm.compute_army_strength(att, target_prov, att_war, gs)
	# Włącz sojusz — siła powinna wzrosnąć
	var dm := DiplomacyManager.new()
	var rel := dm.get_or_create_relation(gs, "islam", "western_christianity")
	rel.alliance_active = true
	var strength_with_alliance := wm.compute_army_strength(att, target_prov, att_war, gs)
	assert_gt(strength_with_alliance, strength_no_alliance, "bonus wymaga aktywnego sojuszu")

func test_holy_war_bonus_blocked_when_ally_not_in_holy_war() -> void:
	var gs := _make_state()
	var wm := WarManager.new()
	var att: Religion = gs.get_religion("islam")
	_pin_axes(att, 50.0, 50.0, 20.0, 70.0)
	var dm := DiplomacyManager.new()
	var rel := dm.get_or_create_relation(gs, "islam", "western_christianity")
	rel.alliance_active = true
	var att_war := _make_war_for("islam", "eastern_christianity", "dzihad", gs)
	var ally_war := _make_war_for("western_christianity", "zoroastrianism", "wojna_sprawiedliwa", gs)	 # NIE krucjata/dzihad
	gs.active_wars.append(att_war)
	gs.active_wars.append(ally_war)
	var target_prov: Province = gs.province_graph.get_province("armenia")
	var strength_ally_not_holy := wm.compute_army_strength(att, target_prov, att_war, gs)
	# Zmień wojnę sojusznika na święta wojnę (przez bezpośrednią referencję, nie indeks)
	ally_war.casus_belli = "dzihad"
	var strength_ally_holy := wm.compute_army_strength(att, target_prov, att_war, gs)
	assert_gt(strength_ally_holy, strength_ally_not_holy, "sojusznik MUSI prowadzić krucjatę/dzihad")

func test_holy_war_bonus_blocked_for_defender_in_holy_war() -> void:
	# Spec sek.4: bonus tylko dla atakującego. Defender w krucjacie/dzihadzie z D>65 NIE dostaje bonusu.
	var gs := _make_state()
	var wm := WarManager.new()
	var att: Religion = gs.get_religion("islam")
	var def_with_d_high: Religion = gs.get_religion("eastern_christianity")  # owns provinces — potrzebne dla base
	_pin_axes(att, 50.0, 50.0, 50.0, 50.0)
	_pin_axes(def_with_d_high, 50.0, 50.0, 20.0, 70.0)
	var dm := DiplomacyManager.new()
	# Sojusz defendera z trzecią religią prowadzącą dzihad
	var rel := dm.get_or_create_relation(gs, "eastern_christianity", "western_christianity")
	rel.alliance_active = true
	var att_war := _make_war_for("islam", "eastern_christianity", "dzihad", gs)
	var ally_war := _make_war_for("western_christianity", "zoroastrianism", "dzihad", gs)
	gs.active_wars.append(att_war)
	gs.active_wars.append(ally_war)
	var target_prov: Province = gs.province_graph.get_province("armenia")
	# Mierzymy siłę DEFENDERA (eastern_christianity). Bonus nie powinien aktywować się mimo D=70 i sojusznika w dzihadzie.
	var def_strength_with_ally := wm.compute_army_strength(def_with_d_high, target_prov, att_war, gs)
	# Zerwij sojusz i ponownie zmierz — powinno być identyczne (bonus nigdy nie aplikowany)
	rel.alliance_active = false
	var def_strength_no_ally := wm.compute_army_strength(def_with_d_high, target_prov, att_war, gs)
	assert_almost_eq(def_strength_with_ally, def_strength_no_ally, 0.001, "defender nie dostaje bonusu HolyWar")

func test_holy_war_constants() -> void:
	assert_almost_eq(WarManager.HOLY_WAR_ALLIANCE_AXIS_D_THRESHOLD, 65.0, 0.001)
	assert_almost_eq(WarManager.HOLY_WAR_ALLIANCE_BONUS, 0.15, 0.001)
	assert_true("krucjata" in WarManager.HOLY_WAR_CBS)
	assert_true("dzihad" in WarManager.HOLY_WAR_CBS)
	assert_eq(WarManager.HOLY_WAR_CBS.size(), 2, "tylko krucjata i dzihad")

# --- INTEGRATION TESTS (Plan 07) ---

const TurnManagerScript := preload("res://scripts/engine/TurnManager.gd")

func test_integration_interdict_to_rewanz_cycle() -> void:
	# Spec sek.6 (Cykl Interdykt → Rewanż):
	# 1. islam rzuca Interdykt na judaism (judaism ma C<30 → kwalifikuje się do Rewanżu)
	# 2. Grievance ustawione na judaism
	# 3. Przewijamy 5 tur — grievance nadal aktywne
	# 4. judaism deklaruje wojnę Rewanż przeciw islam — sukces
	# 5. Grievance zerowane
	# 6. Kolejna próba Rewanżu blokowana (jednorazowy)
	var gs := _make_state()
	var dm := DiplomacyManager.new()
	var wm := WarManager.new()
	var tm := TurnManagerScript.new()

	var attacker: Religion = gs.get_religion("islam")
	var victim: Religion = gs.get_religion("judaism")
	_pin_axes(victim, 50.0, 50.0, 20.0, 50.0)  # C=20 → Ekskluzywizm 80
	attacker.prestige = 100
	victim.prestige = 100

	# 1. Interdykt
	assert_true(dm.proclaim_interdict(gs, "islam", "judaism"))
	var grievance_turn: int = victim.interdict_grievance_until
	assert_eq(victim.interdict_grievance_from_id, "islam")
	assert_eq(grievance_turn, gs.current_turn + DiplomacyManager.GRIEVANCE_WINDOW_TURNS)

	# 2. Po 5 turach grievance nadal aktywne (10 - 5 = 5 tur do końca)
	for _t in range(5):
		tm.process_turn(gs)
	assert_true(victim.interdict_grievance_until > gs.current_turn, "grievance nadal aktywne po 5 turach")

	# 3. Rewanż dostępny
	var cbs := wm.available_casus_belli(victim, attacker, gs)
	assert_true("rewanz" in cbs, "Rewanż dostępny jako CB")

	# 4. Deklaracja wojny Rewanż
	var war := wm.declare_war("judaism", "islam", "rewanz", gs)
	assert_not_null(war, "wojna Rewanż utworzona")
	assert_eq(war.casus_belli, "rewanz")

	# 5. Grievance zerowane
	assert_eq(victim.interdict_grievance_from_id, "", "grievance from zużyte")
	assert_eq(victim.interdict_grievance_until, 0, "grievance until zużyte")

	# 6. Kolejny Rewanż blokowany
	var cbs2 := wm.available_casus_belli(victim, attacker, gs)
	assert_false("rewanz" in cbs2, "jednorazowy — drugiej próby nie ma")

func test_integration_two_allies_in_parallel_holy_wars_both_get_bonus() -> void:
	# Spec sek.6 (Cykl święta wojna sojusznicza):
	# Dwie religie X i Y, obie D=70 (HolyWar D>65 + dzihad D>=70 OK), alliance_active,
	# deklarują dżihady przeciw różnym defenderom. Obie powinny dostać bonus +15% w swoich battles.
	# Defenderzy: eastern_christianity (owns 5 prowincji) i coptic_christianity (owns egipt).
	var gs := _make_state()
	var wm := WarManager.new()
	var dm := DiplomacyManager.new()

	var x: Religion = gs.get_religion("islam")
	var y: Religion = gs.get_religion("zoroastrianism")
	_pin_axes(x, 50.0, 50.0, 20.0, 70.0)   # D=70, C=20 (Ekskluzywizm 80) → dzihad OK + HolyWar OK
	_pin_axes(y, 50.0, 50.0, 20.0, 70.0)   # D=70 → dzihad OK + HolyWar OK

	x.prestige = 100
	y.prestige = 100
	var rel := dm.get_or_create_relation(gs, "islam", "zoroastrianism")
	rel.alliance_active = true

	var warX := wm.declare_war("islam", "eastern_christianity", "dzihad", gs)
	var warY := wm.declare_war("zoroastrianism", "coptic_christianity", "dzihad", gs)
	assert_not_null(warX)
	assert_not_null(warY)

	# Bonus dla X — atakuje province eastern_christianity (armenia, mountains)
	var provX: Province = gs.province_graph.get_province("armenia")
	var strX_with := wm.compute_army_strength(x, provX, warX, gs)

	# Bonus dla Y — atakuje province coptic_christianity (egipt)
	var provY: Province = gs.province_graph.get_province("egipt")
	var strY_with := wm.compute_army_strength(y, provY, warY, gs)

	# Zerwij sojusz — siła powinna spaść dla obu
	rel.alliance_active = false
	var strX_without := wm.compute_army_strength(x, provX, warX, gs)
	var strY_without := wm.compute_army_strength(y, provY, warY, gs)

	assert_gt(strX_with, strX_without, "X dostaje bonus przy sojuszu w dzihad")
	assert_gt(strY_with, strY_without, "Y dostaje bonus przy sojuszu w dzihad")
