extends GutTest

const FactionCardScene := preload("res://scenes/ui/factions/FactionCard.tscn")

func _instance_card() -> FactionCard:
	var c: FactionCard = FactionCardScene.instantiate()
	add_child_autofree(c)
	await get_tree().process_frame
	return c

func _make_faction(id: String, dn: String, influence: float, tension: float, prefs: Array = []) -> Faction:
	var f := Faction.new()
	f.id = id
	f.display_name = dn
	f.influence = influence
	f.tension = tension
	f.axis_preferences = prefs
	return f

func _make_religion_with_faction(f: Faction) -> Religion:
	var r := Religion.new()
	r.id = "test"
	r.display_name = "Test"
	r.factions = [f]
	return r

func test_card_renders_without_state():
	var c: FactionCard = FactionCardScene.instantiate()
	add_child_autofree(c)
	await get_tree().process_frame
	assert_not_null(c)

func test_card_shows_faction_name():
	var f := _make_faction("ulama", "Ulema", 0.40, 20.0,
		[{"axis": "A", "direction": 1}, {"axis": "B", "direction": 1}])
	var r := _make_religion_with_faction(f)
	var c := await _instance_card()
	c.bind_faction(f, r, true)
	assert_eq(c.get_node("%NameLabel").text, "Ulema")

func test_card_shows_influence_as_rounded_percent():
	var f := _make_faction("x", "X", 0.40, 0.0)
	var c := await _instance_card()
	c.bind_faction(f, _make_religion_with_faction(f), false)
	assert_eq(c.get_node("%InfluenceValue").text, "40%")

func test_card_influence_rounding():
	# 0.406 → 41 (round to nearest, bezpieczne wzgledem IEEE-754 precyzji)
	var f := _make_faction("x", "X", 0.406, 0.0)
	var c := await _instance_card()
	c.bind_faction(f, _make_religion_with_faction(f), false)
	assert_eq(c.get_node("%InfluenceValue").text, "41%")

func test_card_influence_rounds_down_when_under_half():
	# 0.404 → 40 (defensive — round nie zaokragla w gore)
	var f := _make_faction("x", "X", 0.404, 0.0)
	var c := await _instance_card()
	c.bind_faction(f, _make_religion_with_faction(f), false)
	assert_eq(c.get_node("%InfluenceValue").text, "40%")

func test_card_influence_clamped_to_100():
	# Defensive: jesli engine kiedys wyjedzie poza 0..1, UI nie pokaze "123%"
	var f := _make_faction("x", "X", 1.23, 0.0)
	var c := await _instance_card()
	c.bind_faction(f, _make_religion_with_faction(f), false)
	assert_eq(c.get_node("%InfluenceValue").text, "100%")

func test_card_tension_value_shows_rounded_int():
	var f := _make_faction("x", "X", 0.3, 35.7)
	var c := await _instance_card()
	c.bind_faction(f, _make_religion_with_faction(f), false)
	assert_eq(c.get_node("%TensionValue").text, "napięcie 36")
	assert_almost_eq(c.get_node("%TensionBar").value, 35.7, 0.01)

func test_card_phase_label_uses_schism_manager_phase_zero():
	var f := _make_faction("x", "X", 0.3, 0.0)
	var c := await _instance_card()
	c.bind_faction(f, _make_religion_with_faction(f), false)
	assert_eq(c.get_node("%PhaseLabel").text, UIConstants.FACTION_PHASE_LABELS[0])

func test_card_phase_label_at_phase1_threshold():
	# Wymusza DRY z SchismManager — UI nie literuje progow
	var f := _make_faction("x", "X", 0.3, SchismManager.PHASE1_THRESHOLD)
	var c := await _instance_card()
	c.bind_faction(f, _make_religion_with_faction(f), false)
	assert_eq(c.get_node("%PhaseLabel").text, UIConstants.FACTION_PHASE_LABELS[1])

func test_card_phase_label_at_phase2_threshold():
	var f := _make_faction("x", "X", 0.3, SchismManager.PHASE2_THRESHOLD)
	var c := await _instance_card()
	c.bind_faction(f, _make_religion_with_faction(f), false)
	assert_eq(c.get_node("%PhaseLabel").text, UIConstants.FACTION_PHASE_LABELS[2])

func test_card_phase_label_at_phase3_threshold():
	var f := _make_faction("x", "X", 0.3, SchismManager.PHASE3_THRESHOLD)
	var c := await _instance_card()
	c.bind_faction(f, _make_religion_with_faction(f), false)
	assert_eq(c.get_node("%PhaseLabel").text, UIConstants.FACTION_PHASE_LABELS[3])

func test_card_phase_boundary_just_below_phase1():
	# 39.9 < 40 → faza 0
	var f := _make_faction("x", "X", 0.3, SchismManager.PHASE1_THRESHOLD - 0.1)
	var c := await _instance_card()
	c.bind_faction(f, _make_religion_with_faction(f), false)
	assert_eq(c.get_node("%PhaseLabel").text, UIConstants.FACTION_PHASE_LABELS[0])

func test_card_tension_bar_color_matches_phase():
	for phase in [0, 1, 2, 3]:
		var threshold: float = [0.0,
			SchismManager.PHASE1_THRESHOLD,
			SchismManager.PHASE2_THRESHOLD,
			SchismManager.PHASE3_THRESHOLD][phase]
		var f := _make_faction("x", "X", 0.3, threshold)
		var c := await _instance_card()
		c.bind_faction(f, _make_religion_with_faction(f), false)
		var bar: ProgressBar = c.get_node("%TensionBar")
		var sb: StyleBoxFlat = bar.get_theme_stylebox("fill")
		assert_eq(sb.bg_color, UIConstants.FACTION_PHASE_COLORS[phase],
			"Phase " + str(phase) + " fill color mismatch")

func test_card_preferences_maps_direction_to_pole():
	# Ulema: A=+1, B=+1 → "↑ Dogmatyzm · ↑ Hierarchia"
	var f := _make_faction("ulama", "Ulema", 0.4, 20.0,
		[{"axis": "A", "direction": 1}, {"axis": "B", "direction": 1}])
	var c := await _instance_card()
	c.bind_faction(f, _make_religion_with_faction(f), false)
	assert_eq(c.get_node("%PreferencesList").text, "↑ Dogmatyzm · ↑ Hierarchia")

func test_card_preferences_maps_negative_direction():
	# Sufici: A=-1, D=+1 → "↑ Mistycyzm · ↑ Transcendencja"
	var f := _make_faction("sufis", "Sufici", 0.3, 20.0,
		[{"axis": "A", "direction": -1}, {"axis": "D", "direction": 1}])
	var c := await _instance_card()
	c.bind_faction(f, _make_religion_with_faction(f), false)
	assert_eq(c.get_node("%PreferencesList").text, "↑ Mistycyzm · ↑ Transcendencja")

func test_card_preferences_warriors_both_negative():
	# Wojownicy Wiary: C=-1, D=-1 → "↑ Ekskluzywizm · ↑ Doczesność" (spec sekcja 4)
	var f := _make_faction("warriors", "Wojownicy Wiary", 0.3, 20.0,
		[{"axis": "C", "direction": -1}, {"axis": "D", "direction": -1}])
	var c := await _instance_card()
	c.bind_faction(f, _make_religion_with_faction(f), false)
	assert_eq(c.get_node("%PreferencesList").text, "↑ Ekskluzywizm · ↑ Doczesność")

func test_card_preferences_skips_direction_zero():
	# Defensive: pref z direction=0 jest pomijany (brak bieguna do pokazania)
	var f := _make_faction("x", "X", 0.3, 0.0,
		[{"axis": "A", "direction": 0}, {"axis": "B", "direction": 1}])
	var c := await _instance_card()
	c.bind_faction(f, _make_religion_with_faction(f), false)
	assert_eq(c.get_node("%PreferencesList").text, "↑ Hierarchia")

func test_card_preferences_handles_empty_array():
	var f := _make_faction("x", "X", 0.3, 0.0, [])
	var c := await _instance_card()
	c.bind_faction(f, _make_religion_with_faction(f), false)
	assert_eq(c.get_node("%PreferencesList").text, "")

func test_card_preferences_skips_unknown_axis():
	var f := _make_faction("x", "X", 0.3, 0.0,
		[{"axis": "Z", "direction": 1}, {"axis": "A", "direction": 1}])
	var c := await _instance_card()
	c.bind_faction(f, _make_religion_with_faction(f), false)
	# Z pomijane, A pokazane
	assert_eq(c.get_node("%PreferencesList").text, "↑ Dogmatyzm")

func test_card_dominant_has_green_border():
	var f := _make_faction("x", "X", 0.5, 0.0)
	var c := await _instance_card()
	c.bind_faction(f, _make_religion_with_faction(f), true)
	var sb: StyleBoxFlat = c.get_theme_stylebox("panel")
	assert_eq(sb.border_color, Color("3aa83a"))
	assert_eq(sb.border_width_left, 2)
	assert_eq(sb.border_width_top, 2)

func test_card_non_dominant_has_dark_bg_no_border():
	var f := _make_faction("x", "X", 0.3, 0.0)
	var c := await _instance_card()
	c.bind_faction(f, _make_religion_with_faction(f), false)
	var sb: StyleBoxFlat = c.get_theme_stylebox("panel")
	assert_eq(sb.bg_color, Color(0.1, 0.1, 0.1))
	assert_eq(sb.border_width_left, 0)

func test_card_handles_influence_zero():
	var f := _make_faction("x", "X", 0.0, 0.0)
	var c := await _instance_card()
	c.bind_faction(f, _make_religion_with_faction(f), false)
	assert_eq(c.get_node("%InfluenceValue").text, "0%")

func test_card_handles_tension_zero():
	var f := _make_faction("x", "X", 0.3, 0.0)
	var c := await _instance_card()
	c.bind_faction(f, _make_religion_with_faction(f), false)
	assert_eq(c.get_node("%TensionValue").text, "napięcie 0")
	assert_eq(c.get_node("%PhaseLabel").text, UIConstants.FACTION_PHASE_LABELS[0])

func test_card_handles_tension_max():
	var f := _make_faction("x", "X", 0.3, 100.0)
	var c := await _instance_card()
	c.bind_faction(f, _make_religion_with_faction(f), false)
	assert_eq(c.get_node("%TensionValue").text, "napięcie 100")
	assert_eq(c.get_node("%PhaseLabel").text, UIConstants.FACTION_PHASE_LABELS[3])

func test_card_bind_before_inside_tree_deferred_to_ready():
	# Wzorzec is_inside_tree() guard — TraitCard pattern
	var f := _make_faction("ulama", "Ulema", 0.4, 20.0,
		[{"axis": "A", "direction": 1}])
	var c: FactionCard = FactionCardScene.instantiate()
	# bind PRZED add_child — nie powinno crashowac
	c.bind_faction(f, _make_religion_with_faction(f), false)
	add_child_autofree(c)
	await get_tree().process_frame
	assert_eq(c.get_node("%NameLabel").text, "Ulema")
