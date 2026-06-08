# Plan 11 — UI Frakcje Implementation Plan

> **For Claude:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Zaimplementować zakładkę Frakcje — read-only widok 3 frakcji religii gracza (nazwa, faza schizmy, wpływ, napięcie, preferencje osi, podświetlenie dominującej).

**Architecture:** 2 komponenty UI w `scripts/ui/factions/` (FactionsTab, FactionCard) + dodatki do `UIConstants` (FACTION_PHASE_COLORS, FACTION_PHASE_LABELS, AXIS_POLE_NAMES) + integracja z `MainShell`. FactionsTab dynamicznie odbudowuje listę kart (`DoctrineList` pattern). FactionCard używa `SchismManager.get_phase()` (DRY z engine). Sortowanie stabilne po `influence` DESC zachowuje JSON order, marking dominującej via `Religion.dominant_faction()`. Brak własnych sygnałów — zakładka read-only.

**Tech Stack:** Godot 4.6.3, GDScript 2.0, GUT (Godot Unit Testing).

**Spec:** [`docs/superpowers/specs/11-ui-factions-design.md`](../specs/11-ui-factions-design.md)

---

## Convention reminders (z [CLAUDE.md](../../../CLAUDE.md))

- **Tab indent** w `.gd` i `.tscn`.
- **`class_name`** na każdym skrypcie UI (`FactionsTab`, `FactionCard`).
- **`unique_name_in_owner = true` + `%Name`** dla nazwanych dzieci w scenach.
- **Setters guard with `is_inside_tree()`** przed `@onready` (precedens: `RelationListItem.gd`, `PressureRow.gd`, `TraitCard.gd`).
- **`emit_signal("name", args)`** (forma stringowa) — w MVP nieużywane (zakładka read-only).
- **Identyfikatory ANGIELSKIE** — pliki, klasy, zmienne, ID. Polski tylko w `Label.text`, `display_name`, komentarzach, JSON. Zgodne z memory `feedback_english_identifiers.md`.
- **Class cache caveat:** po utworzeniu nowego `class_name` skryptu headless GUT może rzucać "Could not find type X" dopóki `.godot/global_script_class_cache.cfg` nie zostanie odświeżony. Po Task 2 (`FactionCard`) i Task 3 (`FactionsTab`) uruchom raz `godot --headless --path . --quit` aby zregenerować cache.

---

## Test command reference

```bash
# Cała suite (wzrost: 471 → 513)
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# Pojedynczy plik testu (zawsze res://-absolutna ścieżka)
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_faction_card.gd -gexit

# Subkatalog
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gexit
```

---

## Test helper pattern (kopiować do każdego nowego pliku testu)

Wszystkie testy używają tego samego pattern do utworzenia GameState:

```gdscript
extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state(player_id: String = "islam") -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize(player_id, religions, graph)
	return gs
```

(Precedens: `tests/ui/test_faith_tab.gd`, `tests/ui/test_trait_card.gd`.)

---

## File Structure

**Tworzone:**

```
scripts/ui/factions/
├── FactionsTab.gd
└── FactionCard.gd

scenes/ui/factions/
├── FactionsTab.tscn
└── FactionCard.tscn

tests/ui/
├── test_factions_tab.gd
├── test_faction_card.gd
└── test_faction_phase_parity.gd
```

**Modyfikowane:**
- `scripts/ui/UIConstants.gd` — `FACTION_PHASE_COLORS`, `FACTION_PHASE_LABELS`, `AXIS_POLE_NAMES`.
- `scripts/ui/MainShell.gd` — typ `_factions_tab`, `bind_state`, `refresh`, usunięcie `set_title`.
- `scenes/ui/MainShell.tscn` — `ExtResource` na `FactionsTab.tscn` zamiast `PlaceholderTab.tscn` dla węzła `FactionsTab`.
- `CLAUDE.md` — `FactionsTab` dodać do listy zaimplementowanych tabów (przestaje być placeholderem).

---

## Chunk 1: Foundation — UIConstants + parity tests

---

### Task 1: UIConstants — FACTION_PHASE_COLORS + FACTION_PHASE_LABELS + AXIS_POLE_NAMES + parity tests

**Cel:** Dodać dane referencyjne dla faz schizmy i biegunów osi. Test parytetu zapewnia że klucze fazy są spójne z `SchismManager.PHASE*_THRESHOLD`, a `AXIS_POLE_NAMES` zgadza się ze spec 01 §1 tabela osi.

**Files:**
- Modify: `scripts/ui/UIConstants.gd`
- Create: `tests/ui/test_faction_phase_parity.gd`

- [ ] **Step 1: Napisz failing test parytetu**

Stwórz `tests/ui/test_faction_phase_parity.gd`:

```gdscript
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
```

- [ ] **Step 2: Uruchom test — powinien failować**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_faction_phase_parity.gd -gexit
```

Expected: failure — testy raportują "missing key" / "missing entry" (stałe nie istnieją).

- [ ] **Step 3: Dodaj stałe do `scripts/ui/UIConstants.gd`**

Dopisz na końcu pliku (przed ewentualną pustą linią końcową):

```gdscript
# Faction phase colors — keys 0..3 muszą pokrywać wartości SchismManager.get_phase()
# Test parytetu: tests/ui/test_faction_phase_parity.gd
const FACTION_PHASE_COLORS: Dictionary = {
	0: Color(0.3, 0.7, 0.3),	# zielony — spokój (<40)
	1: Color(0.85, 0.7, 0.15),	# żółty — ruch heretycki (40..64)
	2: Color(0.95, 0.55, 0.1),	# pomarańczowy — odpływ wiernych (65..84)
	3: Color(0.85, 0.2, 0.2),	# czerwony — pełna schizma (>=85)
}

# Etykiety faz — kapitalizacja: wielka pierwsza litera, fraza po dwukropku z małej.
const FACTION_PHASE_LABELS: Dictionary = {
	0: "Spokój",
	1: "Faza 1: ruch heretycki",
	2: "Faza 2: odpływ wiernych",
	3: "Faza 3: pełna schizma",
}

# Bieguny osi (spec 01 §1): direction=+1 = wartość 100, direction=-1 = wartość 0.
# Spójne z Religion.shift_axis (mnoży delta * direction) i SchismManager.respond_dialoguj.
const AXIS_POLE_NAMES: Dictionary = {
	"A": {1: "Dogmatyzm",     -1: "Mistycyzm"},
	"B": {1: "Hierarchia",    -1: "Równouprawnienie"},
	"C": {1: "Synkretyzm",    -1: "Ekskluzywizm"},
	"D": {1: "Transcendencja", -1: "Doczesność"},
}
```

- [ ] **Step 4: Uruchom test — powinien passować**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_faction_phase_parity.gd -gexit
```

Expected: 5 passed tests.

- [ ] **Step 5: Uruchom całą suite — nic nie powinno się zepsuć**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 471 → 476 passing tests (5 nowych testów dodanych).

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/UIConstants.gd tests/ui/test_faction_phase_parity.gd
git commit -m "$(cat <<'EOF'
feat(ui): dodaj FACTION_PHASE_* i AXIS_POLE_NAMES do UIConstants

Stałe referencyjne dla FactionsTab (Plan 11):
- FACTION_PHASE_COLORS — kolory faz 0..3 (spokój/heretycki/odpływ/schizma)
- FACTION_PHASE_LABELS — polskie etykiety faz
- AXIS_POLE_NAMES — biegun osi per direction (spec 01 §1)

Test parytetu test_faction_phase_parity.gd:
- klucze 0..3 we wszystkich phase dicts
- każda wartość SchismManager.get_phase() ma wpis w obu dicts
- AXIS_POLE_NAMES literalnie zgodne ze spec 01 §1 tabelą

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Chunk 2: FactionCard

---

### Task 2: FactionCard — pojedyncza karta frakcji

**Cel:** `PanelContainer` z VBox prezentujący nazwę, fazę schizmy (z `SchismManager.get_phase`), wpływ %, pasek napięcia, preferencje osi. StyleBoxFlat różny dla dominującej (zielone obramowanie) vs zwykłej (subtelne ciemne tło bez obramowania).

**Files:**
- Create: `scripts/ui/factions/FactionCard.gd`
- Create: `scenes/ui/factions/FactionCard.tscn`
- Create: `tests/ui/test_faction_card.gd`

- [ ] **Step 1: Napisz failing test**

Stwórz `tests/ui/test_faction_card.gd`:

```gdscript
extends GutTest

const FactionCardScene := preload("res://scenes/ui/factions/FactionCard.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state(player_id: String = "islam") -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize(player_id, religions, graph)
	return gs

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
```

- [ ] **Step 2: Uruchom test — powinien failować**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_faction_card.gd -gexit
```

Expected: FAIL z "Could not preload FactionCard.tscn" (scena nie istnieje).

- [ ] **Step 3: Stwórz `scripts/ui/factions/FactionCard.gd`**

```gdscript
class_name FactionCard
extends PanelContainer

@onready var _name_label: Label = %NameLabel
@onready var _phase_label: Label = %PhaseLabel
@onready var _influence_value: Label = %InfluenceValue
@onready var _influence_label: Label = %InfluenceLabel
@onready var _tension_bar: ProgressBar = %TensionBar
@onready var _tension_value: Label = %TensionValue
@onready var _preferences_label: Label = %PreferencesLabel
@onready var _preferences_list: Label = %PreferencesList

var _faction: Faction = null
var _religion: Religion = null
var _is_dominant: bool = false

func bind_faction(faction: Faction, religion: Religion, is_dominant: bool) -> void:
	_faction = faction
	_religion = religion
	_is_dominant = is_dominant
	if is_inside_tree():
		refresh()

func _ready() -> void:
	if _faction != null:
		refresh()

func refresh() -> void:
	if _faction == null:
		return
	_name_label.text = _faction.display_name
	_influence_value.text = "%d%%" % clampi(int(round(_faction.influence * 100.0)), 0, 100)
	_tension_bar.value = _faction.tension
	_tension_value.text = "napięcie %d" % int(round(_faction.tension))
	_apply_phase()
	_apply_preferences()
	_apply_style()

func _apply_phase() -> void:
	var sm := SchismManager.new()
	var phase: int = sm.get_phase(_faction)
	_phase_label.text = UIConstants.FACTION_PHASE_LABELS.get(phase, "")
	var fill_color: Color = UIConstants.FACTION_PHASE_COLORS.get(phase, Color(0.5, 0.5, 0.5))
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = fill_color
	_tension_bar.add_theme_stylebox_override("fill", fill_sb)

func _apply_preferences() -> void:
	# Strzalka ↑ zawsze w gore — pokazujemy biegun ktory frakcja PROMUJE
	# (nie kierunek delta osi). direction=+1 → biegun "100", -1 → biegun "0".
	var parts: Array[String] = []
	for pref: Dictionary in _faction.axis_preferences:
		var axis: String = pref.get("axis", "")
		var direction: int = pref.get("direction", 0)
		if axis == "" or direction == 0 or not UIConstants.AXIS_POLE_NAMES.has(axis):
			continue
		var poles: Dictionary = UIConstants.AXIS_POLE_NAMES[axis]
		if not poles.has(direction):
			continue
		parts.append("↑ " + poles[direction])
	_preferences_list.text = " · ".join(parts)

func _apply_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	if _is_dominant:
		sb.bg_color = Color(0.12, 0.18, 0.12)
		sb.border_color = Color("3aa83a")
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_width_bottom = 2
	else:
		sb.bg_color = Color(0.1, 0.1, 0.1)
	add_theme_stylebox_override("panel", sb)
```

- [ ] **Step 4: Stwórz `scenes/ui/factions/FactionCard.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/factions/FactionCard.gd" id="1"]

[node name="FactionCard" type="PanelContainer"]
script = ExtResource("1")
size_flags_horizontal = 3

[node name="VBox" type="VBoxContainer" parent="."]

[node name="NameLabel" type="Label" parent="VBox"]
unique_name_in_owner = true
text = "(brak)"
theme_override_font_sizes/font_size = 16

[node name="PhaseLabel" type="Label" parent="VBox"]
unique_name_in_owner = true
text = ""
theme_override_font_sizes/font_size = 12

[node name="Separator1" type="HSeparator" parent="VBox"]

[node name="InfluenceValue" type="Label" parent="VBox"]
unique_name_in_owner = true
text = "0%"
theme_override_font_sizes/font_size = 24

[node name="InfluenceLabel" type="Label" parent="VBox"]
unique_name_in_owner = true
text = "wpływ"
theme_override_font_sizes/font_size = 10

[node name="TensionBar" type="ProgressBar" parent="VBox"]
unique_name_in_owner = true
max_value = 100.0
value = 0.0
show_percentage = false

[node name="TensionValue" type="Label" parent="VBox"]
unique_name_in_owner = true
text = "napięcie 0"
theme_override_font_sizes/font_size = 12

[node name="Separator2" type="HSeparator" parent="VBox"]

[node name="PreferencesLabel" type="Label" parent="VBox"]
unique_name_in_owner = true
text = "preferencje"
theme_override_font_sizes/font_size = 10

[node name="PreferencesList" type="Label" parent="VBox"]
unique_name_in_owner = true
text = ""
theme_override_font_sizes/font_size = 12
```

- [ ] **Step 5: Zregeneruj class cache (nowy `class_name FactionCard`)**

```bash
godot --headless --path . --quit
```

- [ ] **Step 6: Uruchom test — powinien passować**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_faction_card.gd -gexit
```

Expected: 25 passed tests.

- [ ] **Step 7: Uruchom całą suite — nic nie powinno się zepsuć**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 476 → 501 passing tests (25 nowych).

- [ ] **Step 8: Commit**

```bash
git add scripts/ui/factions/FactionCard.gd scenes/ui/factions/FactionCard.tscn tests/ui/test_faction_card.gd
git commit -m "$(cat <<'EOF'
feat(ui): dodaj FactionCard — karta pojedynczej frakcji

Komponent PanelContainer prezentujący nazwę, fazę schizmy (via
SchismManager.get_phase — DRY z engine), wpływ % (clamp 0..100),
pasek napięcia + wartość, preferencje osi (direction → biegun via
UIConstants.AXIS_POLE_NAMES).

StyleBoxFlat dynamiczny:
- dominująca: zielony półcień + border #3aa83a 2px
- zwykła: ciemne tło Color(0.1, 0.1, 0.1) bez border

bind_faction() z is_inside_tree guard (deferred do _ready)
— wzorzec TraitCard / RelationListItem.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Chunk 3: FactionsTab + MainShell integration

---

### Task 3: FactionsTab — kontener z dynamicznym rebuild

**Cel:** `Control` z `HBoxContainer` (`%CardsContainer`) który dynamicznie odbudowuje listę `FactionCard` na każdy `refresh()`. Sortowanie stabilne po `influence` DESC (zachowuje JSON order przy remisie). Marking dominującej via `Religion.dominant_faction()`.

**Files:**
- Create: `scripts/ui/factions/FactionsTab.gd`
- Create: `scenes/ui/factions/FactionsTab.tscn`
- Create: `tests/ui/test_factions_tab.gd`

- [ ] **Step 1: Napisz failing test**

Stwórz `tests/ui/test_factions_tab.gd`:

```gdscript
extends GutTest

const FactionsTabScene := preload("res://scenes/ui/factions/FactionsTab.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state(player_id: String = "islam") -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize(player_id, religions, graph)
	return gs

func _instance_tab(state: Node = null) -> FactionsTab:
	var t: FactionsTab = FactionsTabScene.instantiate()
	add_child_autofree(t)
	await get_tree().process_frame
	if state != null:
		t.bind_state(state)
	return t

func _cards(t: FactionsTab) -> Array:
	return t.get_node("%CardsContainer").get_children()

func test_tab_renders_without_state():
	var t: FactionsTab = FactionsTabScene.instantiate()
	add_child_autofree(t)
	await get_tree().process_frame
	assert_not_null(t)
	assert_eq(_cards(t).size(), 0)

func test_tab_renders_three_islam_factions():
	var state := _make_state("islam")
	add_child_autofree(state)
	var t := await _instance_tab(state)
	assert_eq(_cards(t).size(), 3)

func test_tab_card_names_match_islam_factions():
	# Islam JSON: ulama (0.40), sufis (0.30), warriors_of_faith (0.30)
	# Sortowanie DESC po influence → ulama pierwsza
	var state := _make_state("islam")
	add_child_autofree(state)
	var t := await _instance_tab(state)
	var cards := _cards(t)
	assert_eq(cards[0].get_node("%NameLabel").text, "Ulema")

func test_tab_handles_zero_factions():
	var state := _make_state("islam")
	add_child_autofree(state)
	state.get_player_religion().factions = []
	var t := await _instance_tab(state)
	assert_eq(_cards(t).size(), 0)

func test_tab_handles_two_factions():
	var state := _make_state("islam")
	add_child_autofree(state)
	var rel: Religion = state.get_player_religion()
	rel.factions.pop_back()  # 3 → 2
	var t := await _instance_tab(state)
	assert_eq(_cards(t).size(), 2)

func test_tab_handles_four_or_more_factions():
	# Uzasadnia dynamiczny rebuild zamiast 3 statycznych slotow
	var state := _make_state("islam")
	add_child_autofree(state)
	var rel: Religion = state.get_player_religion()
	var extra := Faction.new()
	extra.id = "synthetic"
	extra.display_name = "Synthetic"
	extra.influence = 0.1
	rel.factions.append(extra)
	var t := await _instance_tab(state)
	assert_eq(_cards(t).size(), 4)

func test_tab_sorts_by_influence_desc():
	var state := _make_state("islam")
	add_child_autofree(state)
	var rel: Religion = state.get_player_religion()
	# Force unique influences
	rel.factions[0].influence = 0.30  # ulama
	rel.factions[1].influence = 0.50  # sufis (sztucznie najwyzsze)
	rel.factions[2].influence = 0.20  # warriors_of_faith
	var t := await _instance_tab(state)
	var cards := _cards(t)
	assert_eq(cards[0].get_node("%NameLabel").text, "Sufici")
	assert_eq(cards[1].get_node("%NameLabel").text, "Ulema")
	assert_eq(cards[2].get_node("%NameLabel").text, "Wojownicy Wiary")

func test_tab_sort_is_stable_preserves_json_order_on_ties():
	# Sufici i warriors_of_faith oba na 0.30 w JSON. JSON order: sufis przed warriors.
	# Stable sort musi to zachowac.
	var state := _make_state("islam")
	add_child_autofree(state)
	var rel: Religion = state.get_player_religion()
	# rel.factions[1] = sufis, rel.factions[2] = warriors_of_faith
	# influence z JSON: 0.40, 0.30, 0.30
	var t := await _instance_tab(state)
	var cards := _cards(t)
	# Indeks 0 to ulama (najwyzszy 0.40), 1 i 2 = sufis i warriors w JSON order
	assert_eq(cards[1].get_node("%NameLabel").text, "Sufici")
	assert_eq(cards[2].get_node("%NameLabel").text, "Wojownicy Wiary")

func test_tab_marks_dominant_via_engine_helper():
	var state := _make_state("islam")
	add_child_autofree(state)
	var rel: Religion = state.get_player_religion()
	var dominant: Faction = rel.dominant_faction()
	var t := await _instance_tab(state)
	var cards := _cards(t)
	var dominant_found := false
	for card: FactionCard in cards:
		var is_dom: bool = card.get_node("%NameLabel").text == dominant.display_name
		if is_dom:
			dominant_found = true
			var sb: StyleBoxFlat = card.get_theme_stylebox("panel")
			assert_eq(sb.border_color, Color("3aa83a"), "Dominant card must have green border")
		else:
			var sb: StyleBoxFlat = card.get_theme_stylebox("panel")
			assert_eq(sb.border_width_left, 0, "Non-dominant card must have no border")
	assert_true(dominant_found, "Dominant card not rendered")

func test_tab_refresh_rebuilds_on_faction_removed():
	var state := _make_state("islam")
	add_child_autofree(state)
	var t := await _instance_tab(state)
	assert_eq(_cards(t).size(), 3)
	state.get_player_religion().factions.pop_back()
	t.refresh()
	await get_tree().process_frame
	assert_eq(_cards(t).size(), 2)

func test_tab_handles_null_player_religion():
	var gs: Node = GameStateScript.new()
	# Brak initialize() → player_religion_id == ""
	add_child_autofree(gs)
	var t: FactionsTab = FactionsTabScene.instantiate()
	add_child_autofree(t)
	await get_tree().process_frame
	t.bind_state(gs)
	# Brak crasha, brak kart
	assert_eq(_cards(t).size(), 0)
```

- [ ] **Step 2: Uruchom test — powinien failować**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_factions_tab.gd -gexit
```

Expected: FAIL z "Could not preload FactionsTab.tscn".

- [ ] **Step 3: Stwórz `scripts/ui/factions/FactionsTab.gd`**

```gdscript
class_name FactionsTab
extends Control

const FactionCardScene := preload("res://scenes/ui/factions/FactionCard.tscn")

@onready var _cards_container: HBoxContainer = %CardsContainer

var state: Node = null

func bind_state(s: Node) -> void:
	state = s
	if is_inside_tree():
		refresh()

func _ready() -> void:
	if state != null:
		refresh()

func refresh() -> void:
	if not is_inside_tree():
		return
	# Niszczymy stare karty i odbudowujemy. Wzorzec analogiczny do DoctrineList
	# (Plan 10) — obsluguje 0/1/2/3/4+ frakcji bez zalozen, schizmy usuwajace
	# frakcje, oraz przyszle trait'y mogace tworzyc nowe frakcje (tribal_pluralism).
	for child in _cards_container.get_children():
		child.queue_free()
	if state == null:
		return
	var religion: Religion = state.get_player_religion() if state.has_method("get_player_religion") else null
	if religion == null:
		return
	var dominant: Faction = religion.dominant_faction()
	var sorted_factions: Array = _sort_factions_stable(religion.factions)
	for f: Faction in sorted_factions:
		var card: FactionCard = FactionCardScene.instantiate()
		_cards_container.add_child(card)
		card.bind_faction(f, religion, f == dominant)

func _sort_factions_stable(factions: Array) -> Array:
	# Stable sort: influence DESC, tie-break = original index ASC (zachowuje JSON order).
	# Godot Array.sort_custom nie gwarantuje stabilnosci, wiec sortujemy po tuple.
	var indexed: Array = []
	for i in range(factions.size()):
		indexed.append({"faction": factions[i], "original_index": i})
	indexed.sort_custom(func(a, b):
		if a.faction.influence != b.faction.influence:
			return a.faction.influence > b.faction.influence
		return a.original_index < b.original_index
	)
	var result: Array = []
	for entry: Dictionary in indexed:
		result.append(entry.faction)
	return result
```

- [ ] **Step 4: Stwórz `scenes/ui/factions/FactionsTab.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/factions/FactionsTab.gd" id="1"]

[node name="FactionsTab" type="Control"]
script = ExtResource("1")
anchor_right = 1.0
anchor_bottom = 1.0

[node name="MarginContainer" type="MarginContainer" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0
theme_override_constants/margin_left = 20
theme_override_constants/margin_right = 20
theme_override_constants/margin_top = 20
theme_override_constants/margin_bottom = 20

[node name="CardsContainer" type="HBoxContainer" parent="MarginContainer"]
unique_name_in_owner = true
theme_override_constants/separation = 12
size_flags_horizontal = 3
size_flags_vertical = 3
```

- [ ] **Step 5: Zregeneruj class cache (nowy `class_name FactionsTab`)**

```bash
godot --headless --path . --quit
```

- [ ] **Step 6: Uruchom test — powinien passować**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_factions_tab.gd -gexit
```

Expected: 11 passed tests.

- [ ] **Step 7: Uruchom całą suite — nic nie powinno się zepsuć**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 501 → 512 passing tests (11 nowych).

- [ ] **Step 8: Commit**

```bash
git add scripts/ui/factions/FactionsTab.gd scenes/ui/factions/FactionsTab.tscn tests/ui/test_factions_tab.gd
git commit -m "$(cat <<'EOF'
feat(ui): dodaj FactionsTab — kontener z dynamicznym rebuild kart

Control z MarginContainer + HBoxContainer (CardsContainer) który
dynamicznie odbudowuje liste FactionCard na kazdy refresh().
Wzorzec analogiczny do DoctrineList (Plan 10).

Sortowanie stable po influence DESC z tie-break original_index ASC
(GDScript sort_custom nie gwarantuje stabilnosci). Zachowuje JSON
order przy remisie influence, spojny z Religion.dominant_faction()
strict > semantyka.

Marking dominującej via Religion.dominant_faction() — UI nie ma
wlasnej logiki, korzysta z engine helpera.

Obsluguje 0/1/2/3/4+ frakcji bez zalozen, brak crasha gdy
state == null lub player_religion_id == "".

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: MainShell integration — podmiana PlaceholderTab na FactionsTab

**Cel:** Cztery punktowe zmiany w `MainShell.gd` + jeden ExtResource swap w `MainShell.tscn`. Po tej zmianie zakładka Frakcje renderuje real komponent zamiast placeholdera.

**Files:**
- Modify: `scripts/ui/MainShell.gd`
- Modify: `scenes/ui/MainShell.tscn`
- Modify: `tests/ui/test_main_shell.gd` (potencjalnie — usunąć placeholder reference jeśli istnieje)

- [ ] **Step 1: Sprawdź stan `tests/ui/test_main_shell.gd`**

```bash
grep -n "factions\|Factions\|frakcje\|PlaceholderTab" tests/ui/test_main_shell.gd
```

Jeśli są asercje na `PlaceholderTab` jako typ `_factions_tab` lub `set_title("Frakcje ...")` — będą wymagać aktualizacji.

- [ ] **Step 2: Modify `scripts/ui/MainShell.gd:10`**

Zmień:
```gdscript
@onready var _factions_tab: PlaceholderTab = %FactionsTab
```

Na:
```gdscript
@onready var _factions_tab: FactionsTab = %FactionsTab
```

- [ ] **Step 3: Usuń linię z `MainShell.gd:15`**

Usuń:
```gdscript
	_factions_tab.set_title("Frakcje (Plan 11 — w trakcie)")
```

- [ ] **Step 4: Modify `MainShell.gd` `bind_state()` (linia 28-36)**

Po `_faith_tab.bind_state(s)` (linia 33) dodaj:
```gdscript
	_factions_tab.bind_state(s)
```

Tak by całość `bind_state()` wyglądała:
```gdscript
func bind_state(s: Node) -> void:
	state = s
	_header.bind_state(s)
	_tab_bar.bind_state(s)
	_map_tab.bind_state(s)
	_faith_tab.bind_state(s)
	_factions_tab.bind_state(s)
	if _world_tab.has_method("bind_state"):
		_world_tab.bind_state(s)
	refresh()
```

- [ ] **Step 5: Modify `MainShell.gd` `refresh()` (linia 38-45)**

Po `_faith_tab.refresh()` (linia 43) dodaj:
```gdscript
	_factions_tab.refresh()
```

Tak by całość `refresh()` wyglądała:
```gdscript
func refresh() -> void:
	_header.refresh()
	_tab_bar.refresh()
	if _map_tab.has_method("refresh"):
		_map_tab.refresh()
	_faith_tab.refresh()
	_factions_tab.refresh()
	if _world_tab.has_method("refresh"):
		_world_tab.refresh()
```

- [ ] **Step 6: Modify `scenes/ui/MainShell.tscn`**

Dodaj nowy `ExtResource` po linii 9:
```
[ext_resource type="PackedScene" path="res://scenes/ui/factions/FactionsTab.tscn" id="8"]
```

Zmień `FactionsTab` node z `instance=ExtResource("4")` (PlaceholderTab) na `instance=ExtResource("8")` (FactionsTab):

Z:
```
[node name="FactionsTab" parent="VBox/ContentArea" instance=ExtResource("4")]
unique_name_in_owner = true
visible = false
```

Na:
```
[node name="FactionsTab" parent="VBox/ContentArea" instance=ExtResource("8")]
unique_name_in_owner = true
visible = false
```

**Uwaga**: po podmianie linii 42 z `ExtResource("4")` na `ExtResource("8")`, `ExtResource(id="4")` (PlaceholderTab) jest osierocony — `FactionsTab` był jedynym konsumentem w MainShell.tscn po refaktorach fazy 5. **Usuń linię 6**:

```
[ext_resource type="PackedScene" path="res://scenes/ui/PlaceholderTab.tscn" id="4"]
```

Weryfikacja przed usunięciem (defensywna):
```bash
grep -n 'ExtResource("4")' scenes/ui/MainShell.tscn
```
Powinno zwrócić **tylko** linię 42 (którą właśnie zmieniliśmy na `ExtResource("8")`). Jeśli zwraca jakąkolwiek inną linię — nie usuwaj linii 6, zatrzymaj się i poproś o rewizję planu.

- [ ] **Step 7: Zaktualizuj `tests/ui/test_main_shell.gd` — literalne dyrektywy**

(a) **Usuń funkcję** `test_shell_frakcje_placeholder_has_correct_title` (linie 37-42):

```gdscript
func test_shell_frakcje_placeholder_has_correct_title():
	var state := _make_state()
	add_child_autofree(state)
	var shell := await _instance_shell(state)
	var frakcje: PlaceholderTab = shell.get_node("%FactionsTab")
	assert_string_contains(frakcje.title, "Plan 11")
```

(b) **Dodaj dwa nowe testy** analogiczne do `test_shell_instantiates_faith_tab_as_real_component` i `test_shell_binds_state_to_faith_tab` (linie 44-56). Wklej w miejsce usuniętego testu:

```gdscript
func test_shell_instantiates_factions_tab_as_real_component():
	var state := _make_state()
	add_child_autofree(state)
	var shell := await _instance_shell(state)
	var factions = shell.get_node("%FactionsTab")
	assert_true(factions is FactionsTab, "FactionsTab should be a FactionsTab instance, not PlaceholderTab")

func test_shell_binds_state_to_factions_tab():
	var state := _make_state()
	add_child_autofree(state)
	var shell := await _instance_shell(state)
	var factions: FactionsTab = shell.get_node("%FactionsTab")
	assert_eq(factions.state, state)
```

(c) Sprawdź `test_shell_default_shows_world_tab` (linie 20-27) — używa `shell.get_node("%FactionsTab")` z `.visible` (boolean check). To nadal działa dla `FactionsTab` (dziedziczy po Control). **Nie zmieniaj**.

- [ ] **Step 8: Uruchom test_main_shell.gd**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_main_shell.gd -gexit
```

Expected: All pass (jeśli były asercje placeholder — teraz zaktualizowane).

- [ ] **Step 9: Uruchom całą suite**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 512 → 513 passing tests (1 nowy `test_shell_instantiates_factions_tab_as_real_component` + 1 nowy `test_shell_binds_state_to_factions_tab` − 1 usunięty `test_shell_frakcje_placeholder_has_correct_title`). Brak nowych failów.

- [ ] **Step 10: Manualna weryfikacja w edytorze (opcjonalna ale rekomendowana)**

```bash
godot --path .
```

W edytorze: otwórz `scenes/ui/MainShell.tscn`, sprawdź że hierarchia wygląda OK (FactionsTab ma MarginContainer/CardsContainer zamiast Label). Jeśli edytor renderuje sensownie — OK. Uruchom F5 jeśli chcesz zobaczyć live mode.

- [ ] **Step 11: Commit**

```bash
git add scripts/ui/MainShell.gd scenes/ui/MainShell.tscn tests/ui/test_main_shell.gd
git commit -m "$(cat <<'EOF'
feat(ui): podmień PlaceholderTab na FactionsTab w MainShell

Cztery punktowe zmiany w MainShell.gd:
- typ _factions_tab: PlaceholderTab → FactionsTab (linia 10)
- usuniecie set_title("Frakcje (Plan 11 — w trakcie)") z _ready
- _factions_tab.bind_state(s) w bind_state()
- _factions_tab.refresh() w refresh()

MainShell.tscn: ExtResource dla FactionsTab.tscn zamiast
PlaceholderTab dla wezla FactionsTab.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: CLAUDE.md update

**Cel:** Zaktualizować dokumentację po wdrożeniu — FactionsTab przestaje być placeholderem.

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Znajdź sekcję "UI architecture" w `CLAUDE.md`**

```bash
grep -n "FactionsTab\|placeholder\|Plan 11" CLAUDE.md
```

- [ ] **Step 2: Zaktualizuj opis tabów**

Aktualnie w CLAUDE.md prawdopodobnie jest fraza w stylu "4 tabs in ContentArea: MapTab (Plan 09), FaithTab (Plan 10), WorldTab (diplomacy, Plan 08), FactionsTab (placeholder)". Zmień na:

> 4 tabs in ContentArea: MapTab (Plan 09), FaithTab (Plan 10), WorldTab (diplomacy, Plan 08), FactionsTab (Plan 11).

Jeśli istnieje konkretny opis FactionsTab — zaktualizuj go aby odzwierciedlał: "FactionsTab renders religion's factions as cards (name, schism phase via SchismManager.get_phase, influence %, tension bar, axis preferences, dominant faction highlighted)".

- [ ] **Step 3: Uruchom całą suite (sanity check)**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 513 passing tests.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
docs: zaktualizuj CLAUDE.md po wdrozeniu Plan 11 (FactionsTab)

FactionsTab przestaje byc placeholderem — opis tabu zaktualizowany
zgodnie z implementacja (karty z faza schizmy, wpływ, napiecie,
preferencje osi, dominujaca podswietlona).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

## Końcowa weryfikacja

Po Task 5:

- [ ] **Cała suite zielona**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Oczekiwane: 513 passing tests, 0 failing.

- [ ] **Live mode sprawdzenie (opcjonalne)**

```bash
godot --path .
```

W edytorze F5 → wybierz islam → kliknij tab "Frakcje" → powinieneś zobaczyć 3 karty: Ulema (dominująca, zielone obramowanie), Sufici, Wojownicy Wiary. Wartości wpływu (40%, 30%, 30%), napięcia (~20), faza "Spokój".

- [ ] **Commit push**

```bash
git log --oneline -6
git push origin master
```

Oczekiwana sekwencja:
```
<sha> docs: zaktualizuj CLAUDE.md po wdrozeniu Plan 11 (FactionsTab)
<sha> feat(ui): podmień PlaceholderTab na FactionsTab w MainShell
<sha> feat(ui): dodaj FactionsTab — kontener z dynamicznym rebuild kart
<sha> feat(ui): dodaj FactionCard — karta pojedynczej frakcji
<sha> feat(ui): dodaj FACTION_PHASE_* i AXIS_POLE_NAMES do UIConstants
<sha> docs: spec 11 FactionsTab — UI frakcji religii gracza
```

---

*Plan zatwierdzony — gotowy do wykonania.*
