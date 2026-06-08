extends GutTest

# Klucze faz w UIConstants.FACTION_PHASE_* musza pokrywac wartosci zwracane
# przez SchismManager.get_phase() (0..3). Jesli ktos zmieni progi w engine
# albo doda fazę 4, test pada od razu.

func _make_faction_with_tension(tension: float) -> Faction:
	var f := Faction.new()
	f.id = "test"
	f.display_name = "Test"
	f.tension = tension
	return f

func test_phase_colors_has_entries_for_phases_zero_through_three():
	for phase in [0, 1, 2, 3]:
		assert_true(UIConstants.FACTION_PHASE_COLORS.has(phase),
			"FACTION_PHASE_COLORS missing entry for phase: " + str(phase))
		assert_typeof(UIConstants.FACTION_PHASE_COLORS[phase], TYPE_COLOR)

func test_phase_labels_has_entries_for_phases_zero_through_three():
	for phase in [0, 1, 2, 3]:
		assert_true(UIConstants.FACTION_PHASE_LABELS.has(phase),
			"FACTION_PHASE_LABELS missing entry for phase: " + str(phase))
		assert_ne(UIConstants.FACTION_PHASE_LABELS[phase], "",
			"FACTION_PHASE_LABELS[" + str(phase) + "] must be non-empty")

func test_phase_keys_are_complete_for_schism_manager():
	var sm := SchismManager.new()
	# Czteropunktowa walidacja: kazda faza wracana z engine ma wpis w UI dicts.
	var tensions := [0.0, SchismManager.PHASE1_THRESHOLD, SchismManager.PHASE2_THRESHOLD, SchismManager.PHASE3_THRESHOLD]
	for t: float in tensions:
		var phase: int = sm.get_phase(_make_faction_with_tension(t))
		assert_true(UIConstants.FACTION_PHASE_COLORS.has(phase),
			"FACTION_PHASE_COLORS missing entry for phase " + str(phase) + " (tension=" + str(t) + ")")
		assert_true(UIConstants.FACTION_PHASE_LABELS.has(phase),
			"FACTION_PHASE_LABELS missing entry for phase " + str(phase) + " (tension=" + str(t) + ")")

func test_axis_pole_names_covers_all_doctrine_axes():
	var expected_axes := ["A", "B", "C", "D"]
	for axis: String in expected_axes:
		assert_true(UIConstants.AXIS_POLE_NAMES.has(axis),
			"AXIS_POLE_NAMES missing entry for axis: " + axis)
		var poles: Dictionary = UIConstants.AXIS_POLE_NAMES[axis]
		assert_true(poles.has(1), "AXIS_POLE_NAMES[" + axis + "] missing key +1")
		assert_true(poles.has(-1), "AXIS_POLE_NAMES[" + axis + "] missing key -1")

# Spec 01 §1: tabela osi. Direction=+1 = biegun na wartosci 100, -1 = na wartosci 0.
func test_axis_pole_names_match_doctrine_spec():
	assert_eq(UIConstants.AXIS_POLE_NAMES["A"][1], "Dogmatyzm")
	assert_eq(UIConstants.AXIS_POLE_NAMES["A"][-1], "Mistycyzm")
	assert_eq(UIConstants.AXIS_POLE_NAMES["B"][1], "Hierarchia")
	assert_eq(UIConstants.AXIS_POLE_NAMES["B"][-1], "Równouprawnienie")
	assert_eq(UIConstants.AXIS_POLE_NAMES["C"][1], "Synkretyzm")
	assert_eq(UIConstants.AXIS_POLE_NAMES["C"][-1], "Ekskluzywizm")
	assert_eq(UIConstants.AXIS_POLE_NAMES["D"][1], "Transcendencja")
	assert_eq(UIConstants.AXIS_POLE_NAMES["D"][-1], "Doczesność")
