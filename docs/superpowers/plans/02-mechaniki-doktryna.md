# Mechaniki: Doktryna i Schizmy — Implementation Plan

> **For Claude:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Zaimplementować system doktryn (przesunięcia osi teologicznych, sobory, edykty, misje uczone) oraz system schizm (fazy napięcia frakcyjnego, reakcje gracza, pełna schizma).

**Architecture:** `DoctrineManager` i `SchismManager` to bezstanowe klasy RefCounted — przyjmują `GameState` (Node) jako argument. `Idea` to data class (Resource). `GameState` rozszerzamy o `pending_ideas` i `scholar_missions`. `TurnManager` woła oba managerów w `process_turn`.

**Tech Stack:** Godot 4.6.3, GDScript 2.0, GUT (testy headless: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`), JSON data files w `data/`.

**Uruchomienie testów:**
```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

**Uwagi kontekstowe:**
- `GameState.gd` **nie ma** `class_name` (konflikt z Autoload) — testy używają `preload("res://scripts/engine/GameState.gd").new()`
- `TurnManager.process_turn(state: Node)` — duck typing, bo GameState nie ma class_name
- `Array.assign()` do ładowania typed arrays z JSON
- Dla typed loop: `for pd: Dictionary in list` zamiast `for pd in list: ... pd as Dictionary`
- 4 osie teologiczne: A (Mistycyzm↔Dogmatyzm), B (Równouprawnienie↔Hierarchia), C (Ekskluzywizm↔Synkretyzm), D (Doczesność↔Transcendencja)
- 46 testów zdanych na gałęzi master przed startem tego planu

---

## Chunk 1: DoctrineManager — dane i progi osi

### Task 1: Idea.gd + rozszerzenie GameState

**Files:**
- Create: `scripts/engine/Idea.gd`
- Modify: `scripts/engine/GameState.gd`
- Test: `tests/engine/test_doctrine_manager.gd` (nowy plik, pierwsze testy)

- [ ] **Step 1: Napisz plik testowy z pierwszym testem (FAIL)**

```gdscript
# tests/engine/test_doctrine_manager.gd
extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
    var gs: Node = GameStateScript.new()
    var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
    var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
    gs.initialize("islam", religions, graph)
    return gs

func test_game_state_has_pending_ideas_array() -> void:
    var gs := _make_state()
    assert_not_null(gs.pending_ideas)
    assert_eq(gs.pending_ideas.size(), 0)

func test_game_state_has_scholar_missions_array() -> void:
    var gs := _make_state()
    assert_not_null(gs.scholar_missions)
    assert_eq(gs.scholar_missions.size(), 0)

func test_idea_has_correct_fields() -> void:
    var idea := Idea.new()
    idea.from_religion_id = "islam"
    idea.axis = "A"
    idea.delta = 5.0
    idea.description = "Nowa interpretacja"
    assert_eq(idea.from_religion_id, "islam")
    assert_eq(idea.axis, "A")
    assert_eq(idea.delta, 5.0)
    assert_eq(idea.description, "Nowa interpretacja")
```

- [ ] **Step 2: Uruchom testy — potwierdź FAIL**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20
```

Oczekiwane: błędy o brakującym `pending_ideas`, `scholar_missions`, `Idea`.

- [ ] **Step 3: Utwórz `Idea.gd`**

```gdscript
# scripts/engine/Idea.gd
class_name Idea
extends Resource

@export var from_religion_id: String = ""
@export var axis: String = ""
@export var delta: float = 0.0
@export var description: String = ""
```

- [ ] **Step 4: Rozszerz `GameState.gd` — dodaj pola**

W `scripts/engine/GameState.gd` dodaj po `var _religions: Dictionary = {}`:

```gdscript
var pending_ideas: Array[Idea] = []
var scholar_missions: Array = []
```

- [ ] **Step 5: Uruchom testy — potwierdź PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20
```

Oczekiwane: wszystkie testy zielone (poprzednie 46 + 3 nowe = 49).

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/Idea.gd scripts/engine/GameState.gd tests/engine/test_doctrine_manager.gd scripts/engine/Idea.gd.uid
git commit -m "feat: add Idea data class and extend GameState with pending_ideas/scholar_missions"
```

---

### Task 2: DoctrineManager — system progów osi

**Files:**
- Create: `scripts/engine/DoctrineManager.gd`
- Test: `tests/engine/test_doctrine_manager.gd` (rozbudowa)

- [ ] **Step 1: Dodaj testy progów do pliku testowego (FAIL)**

Dopisz do `tests/engine/test_doctrine_manager.gd`:

```gdscript
const DoctrineManagerScript := preload("res://scripts/engine/DoctrineManager.gd")

func test_doctrine_manager_axis_A_high_unlocks_kanon_doktryny() -> void:
    var dm := DoctrineManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    rel.axes["A"] = 76.0
    var actions := dm.available_threshold_actions(rel)
    assert_true(actions.has("kanon_doktryny"), "A>=75 powinno odblokować kanon_doktryny")

func test_doctrine_manager_axis_A_low_unlocks_objawienie() -> void:
    var dm := DoctrineManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    rel.axes["A"] = 24.0
    var actions := dm.available_threshold_actions(rel)
    assert_true(actions.has("objawienie"), "A<=25 powinno odblokować objawienie")

func test_doctrine_manager_axis_middle_no_threshold_actions() -> void:
    var dm := DoctrineManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    rel.axes["A"] = 50.0
    rel.axes["B"] = 50.0
    rel.axes["C"] = 50.0
    var actions := dm.available_threshold_actions(rel)
    assert_eq(actions.size(), 0)

func test_doctrine_manager_axis_C_high_unlocks_ekumenizm_and_obrzad() -> void:
    var dm := DoctrineManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    rel.axes["C"] = 80.0
    var actions := dm.available_threshold_actions(rel)
    assert_true(actions.has("ekumenizm"))
    assert_true(actions.has("obrzad_fuzji"))

func test_doctrine_manager_axis_C_low_unlocks_inkwizycja_and_klatwa() -> void:
    var dm := DoctrineManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    rel.axes["C"] = 20.0
    var actions := dm.available_threshold_actions(rel)
    assert_true(actions.has("inkwizycja"))
    assert_true(actions.has("klatwa"))
```

- [ ] **Step 2: Uruchom testy — potwierdź FAIL**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20
```

- [ ] **Step 3: Utwórz `DoctrineManager.gd` z systemem progów**

```gdscript
# scripts/engine/DoctrineManager.gd
class_name DoctrineManager
extends RefCounted

const SOBOR_PRESTIGE_COST := 30
const EDICT_PRESTIGE_COST := 15
const EDICT_MAX_DELTA := 5.0
const FACTION_TENSION_FROM_SOBOR := 8.0
const SCHOLAR_MISSION_TURNS := 3
const IDEA_MIN_AXIS_DIFF := 10.0
const IDEA_DELTA_FACTOR := 0.3
const IDEA_MAX_DELTA := 8.0

const AXIS_THRESHOLDS: Dictionary = {
    "A": [
        {"min": 75.0, "actions": ["kanon_doktryny"]},
        {"max": 25.0, "actions": ["objawienie"]},
    ],
    "B": [
        {"min": 75.0, "actions": ["papieskie_interdykty"]},
        {"max": 25.0, "actions": ["sobor_ludowy"]},
    ],
    "C": [
        {"min": 75.0, "actions": ["ekumenizm", "obrzad_fuzji"]},
        {"max": 25.0, "actions": ["inkwizycja", "klatwa"]},
    ],
    # Oś D (Doczesność↔Transcendencja) nie ma akcji progowych w tym PoC — celowe pominięcie.
}

func available_threshold_actions(religion: Religion) -> Array[String]:
    var result: Array[String] = []
    for axis: String in AXIS_THRESHOLDS.keys():
        var value := religion.get_axis(axis)
        for rule: Dictionary in AXIS_THRESHOLDS[axis]:
            if rule.has("min") and value >= rule["min"]:
                for action: String in rule["actions"]:
                    result.append(action)
            elif rule.has("max") and value <= rule["max"]:
                for action: String in rule["actions"]:
                    result.append(action)
    return result
```

- [ ] **Step 4: Uruchom testy — potwierdź PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20
```

Oczekiwane: 54 testy zielone.

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/DoctrineManager.gd tests/engine/test_doctrine_manager.gd scripts/engine/DoctrineManager.gd.uid
git commit -m "feat: add DoctrineManager with axis threshold action system"
```

---

### Task 3: DoctrineManager — sobory, edykty i reakcje frakcji

**Files:**
- Modify: `scripts/engine/DoctrineManager.gd`
- Test: `tests/engine/test_doctrine_manager.gd` (rozbudowa)

- [ ] **Step 1: Dodaj testy soboru i edyktu (FAIL)**

Dopisz do `tests/engine/test_doctrine_manager.gd`:

```gdscript
func test_call_sobor_shifts_axis_and_costs_prestige() -> void:
    var dm := DoctrineManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    rel.prestige = 50
    var axis_before := rel.get_axis("A")
    var ok := dm.call_sobor(rel, "A", 10.0)
    assert_true(ok)
    assert_eq(rel.prestige, 50 - DoctrineManagerScript.SOBOR_PRESTIGE_COST)
    assert_almost_eq(rel.get_axis("A"), axis_before + 10.0, 0.001)

func test_call_sobor_fails_if_not_enough_prestige() -> void:
    var dm := DoctrineManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    rel.prestige = 10
    var axis_before := rel.get_axis("A")
    var ok := dm.call_sobor(rel, "A", 10.0)
    assert_false(ok)
    assert_almost_eq(rel.get_axis("A"), axis_before, 0.001)
    assert_eq(rel.prestige, 10)

func test_sobor_increases_faction_tension() -> void:
    var dm := DoctrineManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    rel.prestige = 100
    var tension_before := rel.factions[0].tension
    dm.call_sobor(rel, "A", 5.0)
    assert_almost_eq(rel.factions[0].tension, tension_before + DoctrineManagerScript.FACTION_TENSION_FROM_SOBOR, 0.001)

func test_issue_edict_shifts_axis_within_cap() -> void:
    var dm := DoctrineManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    rel.prestige = 50
    var axis_before := rel.get_axis("B")
    var ok := dm.issue_edict(rel, "B", 10.0)
    assert_true(ok)
    assert_eq(rel.prestige, 50 - DoctrineManagerScript.EDICT_PRESTIGE_COST)
    assert_almost_eq(rel.get_axis("B"), axis_before + DoctrineManagerScript.EDICT_MAX_DELTA, 0.001)

func test_issue_edict_fails_if_not_enough_prestige() -> void:
    var dm := DoctrineManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    rel.prestige = 5
    var ok := dm.issue_edict(rel, "B", 5.0)
    assert_false(ok)
```

- [ ] **Step 2: Uruchom testy — potwierdź FAIL**

- [ ] **Step 3: Zaimplementuj `call_sobor` i `issue_edict` w `DoctrineManager.gd`**

Dopisz do klasy `DoctrineManager`:

```gdscript
func call_sobor(religion: Religion, axis: String, delta: float) -> bool:
    if religion.prestige < SOBOR_PRESTIGE_COST:
        return false
    religion.add_prestige(-SOBOR_PRESTIGE_COST)
    religion.shift_axis(axis, delta)
    for faction: Faction in religion.factions:
        faction.add_tension(FACTION_TENSION_FROM_SOBOR)
    return true

func issue_edict(religion: Religion, axis: String, delta: float) -> bool:
    if religion.prestige < EDICT_PRESTIGE_COST:
        return false
    religion.add_prestige(-EDICT_PRESTIGE_COST)
    var clamped_delta := clampf(delta, -EDICT_MAX_DELTA, EDICT_MAX_DELTA)
    religion.shift_axis(axis, clamped_delta)
    return true
```

- [ ] **Step 4: Uruchom testy — potwierdź PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20
```

Oczekiwane: 59 testów zielonych.

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/DoctrineManager.gd tests/engine/test_doctrine_manager.gd
git commit -m "feat: add call_sobor and issue_edict to DoctrineManager"
```

---

### Task 4: DoctrineManager — misje uczonych i idee

**Files:**
- Modify: `scripts/engine/DoctrineManager.gd`
- Test: `tests/engine/test_doctrine_manager.gd` (rozbudowa)

- [ ] **Step 1: Dodaj testy misji uczonego i idei (FAIL)**

Dopisz do `tests/engine/test_doctrine_manager.gd`:

```gdscript
func test_dispatch_scholar_adds_mission_to_state() -> void:
    var dm := DoctrineManagerScript.new()
    var gs := _make_state()
    dm.dispatch_scholar(gs, "islam", "chr_zachodnie")
    assert_eq(gs.scholar_missions.size(), 1)
    assert_eq(gs.scholar_missions[0]["from_religion_id"], "islam")
    assert_eq(gs.scholar_missions[0]["to_religion_id"], "chr_zachodnie")
    assert_eq(gs.scholar_missions[0]["turns_remaining"], DoctrineManagerScript.SCHOLAR_MISSION_TURNS)

func test_generate_idea_returns_idea_when_axes_differ() -> void:
    var dm := DoctrineManagerScript.new()
    var gs := _make_state()
    var islam: Religion = gs.get_religion("islam")
    var chr: Religion = gs.get_religion("chr_zachodnie")
    # Pinuj wszystkie osie żeby A miała największą różnicę (uniknięcie zależności od JSON)
    for rel in [islam, chr]:
        rel.axes["A"] = 50.0
        rel.axes["B"] = 50.0
        rel.axes["C"] = 50.0
        rel.axes["D"] = 50.0
    islam.axes["A"] = 30.0
    chr.axes["A"] = 70.0
    var idea := dm.generate_idea("islam", "chr_zachodnie", gs)
    assert_not_null(idea)
    assert_eq(idea.from_religion_id, "islam")
    assert_eq(idea.axis, "A")
    assert_gt(idea.delta, 0.0)
    assert_le(idea.delta, DoctrineManagerScript.IDEA_MAX_DELTA)

func test_generate_idea_returns_null_when_axes_too_similar() -> void:
    var dm := DoctrineManagerScript.new()
    var gs := _make_state()
    var islam: Religion = gs.get_religion("islam")
    var chr: Religion = gs.get_religion("chr_zachodnie")
    islam.axes["A"] = 50.0
    chr.axes["A"] = 55.0
    islam.axes["B"] = 50.0
    chr.axes["B"] = 55.0
    islam.axes["C"] = 50.0
    chr.axes["C"] = 55.0
    islam.axes["D"] = 50.0
    chr.axes["D"] = 55.0
    var idea := dm.generate_idea("islam", "chr_zachodnie", gs)
    assert_null(idea)

func test_accept_idea_shifts_axis() -> void:
    var dm := DoctrineManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    var idea := Idea.new()
    idea.from_religion_id = "chr_zachodnie"
    idea.axis = "A"
    idea.delta = 5.0
    gs.pending_ideas.append(idea)
    var axis_before := rel.get_axis("A")
    dm.accept_idea(idea, rel, gs)
    assert_almost_eq(rel.get_axis("A"), axis_before + 5.0, 0.001)
    assert_eq(gs.pending_ideas.size(), 0)

func test_reject_idea_removes_from_pending() -> void:
    var dm := DoctrineManagerScript.new()
    var gs := _make_state()
    var idea := Idea.new()
    idea.axis = "A"
    idea.delta = 5.0
    gs.pending_ideas.append(idea)
    dm.reject_idea(idea, gs)
    assert_eq(gs.pending_ideas.size(), 0)
```

- [ ] **Step 2: Uruchom testy — potwierdź FAIL**

- [ ] **Step 3: Zaimplementuj `dispatch_scholar`, `generate_idea`, `accept_idea`, `reject_idea`**

Dopisz do klasy `DoctrineManager`:

```gdscript
func dispatch_scholar(state: Node, from_religion_id: String, to_religion_id: String) -> void:
    state.scholar_missions.append({
        "from_religion_id": from_religion_id,
        "to_religion_id": to_religion_id,
        "turns_remaining": SCHOLAR_MISSION_TURNS,
    })

func generate_idea(from_religion_id: String, to_religion_id: String, state: Node) -> Idea:
    var from_rel: Religion = state.get_religion(from_religion_id)
    var to_rel: Religion = state.get_religion(to_religion_id)
    if from_rel == null or to_rel == null:
        return null
    var best_axis := ""
    var best_diff := 0.0
    for axis: String in ["A", "B", "C", "D"]:
        var diff := absf(to_rel.get_axis(axis) - from_rel.get_axis(axis))
        if diff > best_diff:
            best_diff = diff
            best_axis = axis
    if best_diff < IDEA_MIN_AXIS_DIFF:
        return null
    var idea := Idea.new()
    idea.from_religion_id = from_religion_id
    idea.axis = best_axis
    idea.delta = minf(best_diff * IDEA_DELTA_FACTOR, IDEA_MAX_DELTA)
    var sign_val := 1.0 if to_rel.get_axis(best_axis) > from_rel.get_axis(best_axis) else -1.0
    idea.delta *= sign_val
    idea.description = "Idea z " + from_religion_id + " (oś " + best_axis + ")"
    return idea

func accept_idea(idea: Idea, religion: Religion, state: Node) -> void:
    religion.shift_axis(idea.axis, idea.delta)
    state.pending_ideas.erase(idea)

func reject_idea(idea: Idea, state: Node) -> void:
    state.pending_ideas.erase(idea)
```

- [ ] **Step 4: Uruchom testy — potwierdź PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20
```

Oczekiwane: 64 testy zielone.

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/DoctrineManager.gd tests/engine/test_doctrine_manager.gd
git commit -m "feat: add scholar missions and idea generation to DoctrineManager"
```

---

## Chunk 2: SchismManager — fazy i pełna schizma

### Task 5: SchismManager — detekcja faz i reakcje gracza

**Files:**
- Create: `scripts/engine/SchismManager.gd`
- Create: `tests/engine/test_schism_manager.gd`

- [ ] **Step 1: Napisz plik testowy (FAIL)**

```gdscript
# tests/engine/test_schism_manager.gd
extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")
const SchismManagerScript := preload("res://scripts/engine/SchismManager.gd")

func _make_state() -> Node:
    var gs: Node = GameStateScript.new()
    var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
    var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
    gs.initialize("islam", religions, graph)
    return gs

func _get_faction(gs: Node) -> Faction:
    return gs.get_religion("islam").factions[0]

func test_schism_phase_0_when_tension_low() -> void:
    var sm := SchismManagerScript.new()
    var faction := _get_faction(_make_state())
    faction.tension = 20.0
    assert_eq(sm.get_phase(faction), 0)

func test_schism_phase_1_when_tension_above_40() -> void:
    var sm := SchismManagerScript.new()
    var faction := _get_faction(_make_state())
    faction.tension = 45.0
    assert_eq(sm.get_phase(faction), 1)

func test_schism_phase_2_when_tension_above_65() -> void:
    var sm := SchismManagerScript.new()
    var faction := _get_faction(_make_state())
    faction.tension = 70.0
    assert_eq(sm.get_phase(faction), 2)

func test_schism_phase_3_when_tension_above_85() -> void:
    var sm := SchismManagerScript.new()
    var faction := _get_faction(_make_state())
    faction.tension = 90.0
    assert_eq(sm.get_phase(faction), 3)

func test_stlumienie_reduces_tension_and_influence() -> void:
    var sm := SchismManagerScript.new()
    var faction := _get_faction(_make_state())
    faction.tension = 60.0
    faction.influence = 0.5
    sm.respond_stlumienie(faction)
    assert_almost_eq(faction.tension, 60.0 - SchismManagerScript.TENSION_REDUCE_STLUM, 0.001)
    assert_almost_eq(faction.influence, 0.5 - SchismManagerScript.INFLUENCE_REDUCE_STLUM, 0.001)

func test_dialog_reduces_tension_less() -> void:
    var sm := SchismManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    var faction := rel.factions[0]
    faction.tension = 60.0
    var axis_before := rel.get_axis("A")
    sm.respond_dialoguj(faction, rel)
    assert_almost_eq(faction.tension, 60.0 - SchismManagerScript.TENSION_REDUCE_DIALOGUJ, 0.001)

func test_dialog_shifts_axis_toward_faction_preference() -> void:
    var sm := SchismManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    var faction := rel.factions[0]  # ulema: axis_preferences = [{axis: A, direction: 1}, {axis: B, direction: 1}]
    faction.tension = 60.0
    assert_true(faction.axis_preferences.size() > 0, "Test wymaga frakcji z axis_preferences — ulema powinno je mieć")
    var pref: Dictionary = faction.axis_preferences[0]
    var axis: String = pref.get("axis", "A")
    var axis_before := rel.get_axis(axis)
    sm.respond_dialoguj(faction, rel)
    assert_ne(rel.get_axis(axis), axis_before)

func test_koncesja_reduces_tension_most() -> void:
    var sm := SchismManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    rel.prestige = 50
    var faction := rel.factions[0]
    faction.tension = 70.0
    var ok := sm.respond_koncesja(faction, rel)
    assert_true(ok)
    assert_almost_eq(faction.tension, 70.0 - SchismManagerScript.TENSION_REDUCE_KONCESJA, 0.001)
    assert_eq(rel.prestige, 50 - SchismManagerScript.KONCESJA_PRESTIGE_COST)

func test_koncesja_fails_without_prestige() -> void:
    var sm := SchismManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    rel.prestige = 5
    var faction := rel.factions[0]
    faction.tension = 70.0
    var ok := sm.respond_koncesja(faction, rel)
    assert_false(ok)
```

- [ ] **Step 2: Uruchom testy — potwierdź FAIL**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20
```

- [ ] **Step 3: Utwórz `SchismManager.gd`**

```gdscript
# scripts/engine/SchismManager.gd
class_name SchismManager
extends RefCounted

const PHASE1_THRESHOLD := 40.0
const PHASE2_THRESHOLD := 65.0
const PHASE3_THRESHOLD := 85.0
const SCHISM_MIN_INFLUENCE := 0.30

const TENSION_REDUCE_STLUM := 15.0
const INFLUENCE_REDUCE_STLUM := 0.10
const TENSION_REDUCE_DIALOGUJ := 8.0
const AXIS_CONCESSION_DIALOGUJ := 3.0
const TENSION_REDUCE_KONCESJA := 20.0
const KONCESJA_PRESTIGE_COST := 15

const SCHISM_AXIS_OFFSET := 15.0
const SCHISM_INITIAL_PRESTIGE := 50

func get_phase(faction: Faction) -> int:
    if faction.tension >= PHASE3_THRESHOLD:
        return 3
    if faction.tension >= PHASE2_THRESHOLD:
        return 2
    if faction.tension >= PHASE1_THRESHOLD:
        return 1
    return 0

func respond_stlumienie(faction: Faction) -> void:
    faction.tension = maxf(0.0, faction.tension - TENSION_REDUCE_STLUM)
    faction.influence = maxf(0.0, faction.influence - INFLUENCE_REDUCE_STLUM)

func respond_dialoguj(faction: Faction, religion: Religion) -> void:
    faction.tension = maxf(0.0, faction.tension - TENSION_REDUCE_DIALOGUJ)
    for pref: Dictionary in faction.axis_preferences:
        var axis: String = pref.get("axis", "")
        var direction: int = pref.get("direction", 1)
        if axis != "" and religion.axes.has(axis):
            religion.shift_axis(axis, AXIS_CONCESSION_DIALOGUJ * direction)
            break  # Reaguj tylko na pierwszą preferencję z ważną osią

func respond_koncesja(faction: Faction, religion: Religion) -> bool:
    if religion.prestige < KONCESJA_PRESTIGE_COST:
        return false
    religion.add_prestige(-KONCESJA_PRESTIGE_COST)
    faction.tension = maxf(0.0, faction.tension - TENSION_REDUCE_KONCESJA)
    return true
```

- [ ] **Step 4: Uruchom testy — potwierdź PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20
```

Oczekiwane: 73 testy zielone.

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/SchismManager.gd tests/engine/test_schism_manager.gd scripts/engine/SchismManager.gd.uid
git commit -m "feat: add SchismManager with phase detection and player responses"
```

---

### Task 6: SchismManager — pełna schizma (trigger_schism)

**Files:**
- Modify: `scripts/engine/SchismManager.gd`
- Test: `tests/engine/test_schism_manager.gd` (rozbudowa)

- [ ] **Step 1: Dodaj testy pełnej schizmy (FAIL)**

Dopisz do `tests/engine/test_schism_manager.gd`:

```gdscript
func test_trigger_schism_creates_new_religion() -> void:
    var sm := SchismManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    var faction := rel.factions[0]
    faction.tension = 90.0
    faction.influence = 0.5
    var count_before := gs.all_religions().size()
    var new_rel := sm.trigger_schism(faction, rel, gs)
    assert_not_null(new_rel)
    assert_ne(new_rel.id, rel.id)
    assert_eq(gs.all_religions().size(), count_before + 1)

func test_trigger_schism_requires_min_influence() -> void:
    var sm := SchismManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    var faction := rel.factions[0]
    faction.tension = 90.0
    faction.influence = 0.10
    var new_rel := sm.trigger_schism(faction, rel, gs)
    assert_null(new_rel)

func test_trigger_schism_new_religion_has_offset_axes() -> void:
    var sm := SchismManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    var faction := rel.factions[0]  # ulema: axis_preferences = [{axis: A, direction: 1}, {axis: B, direction: 1}]
    assert_true(faction.axis_preferences.size() > 0, "Test wymaga frakcji z axis_preferences")
    faction.tension = 90.0
    faction.influence = 0.5
    var parent_axis_A := rel.get_axis("A")
    var new_rel := sm.trigger_schism(faction, rel, gs)
    assert_not_null(new_rel)
    # Oś A powinna być przesunięta (ulema: direction=1, więc +SCHISM_AXIS_OFFSET)
    assert_ne(new_rel.get_axis("A"), parent_axis_A)

func test_trigger_schism_new_religion_has_initial_prestige() -> void:
    var sm := SchismManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    var faction := rel.factions[0]
    faction.tension = 90.0
    faction.influence = 0.5
    var new_rel := sm.trigger_schism(faction, rel, gs)
    assert_not_null(new_rel)
    assert_eq(new_rel.prestige, SchismManagerScript.SCHISM_INITIAL_PRESTIGE)

func test_trigger_schism_removes_faction_from_parent() -> void:
    var sm := SchismManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    var faction := rel.factions[0]
    var faction_id := faction.id
    faction.tension = 90.0
    faction.influence = 0.5
    sm.trigger_schism(faction, rel, gs)
    assert_null(rel.get_faction(faction_id))
```

- [ ] **Step 2: Uruchom testy — potwierdź FAIL**

- [ ] **Step 3: Zaimplementuj `trigger_schism` w `SchismManager.gd`**

Dopisz do klasy `SchismManager`:

```gdscript
func trigger_schism(faction: Faction, religion: Religion, state: Node) -> Religion:
    if faction.influence < SCHISM_MIN_INFLUENCE:
        return null
    var new_rel := Religion.new()
    new_rel.id = religion.id + "_" + faction.id + "_schizma"
    new_rel.display_name = faction.display_name + " (Schizma)"
    new_rel.prestige = SCHISM_INITIAL_PRESTIGE
    new_rel.color = religion.color
    new_rel.accent_color = religion.accent_color
    for axis: String in religion.axes.keys():
        new_rel.axes[axis] = religion.get_axis(axis)
    for pref: Dictionary in faction.axis_preferences:
        var axis: String = pref.get("axis", "")
        var direction: int = pref.get("direction", 1)
        if axis != "" and new_rel.axes.has(axis):
            new_rel.axes[axis] = clampf(new_rel.get_axis(axis) + SCHISM_AXIS_OFFSET * direction, 0.0, 100.0)
    religion.factions.erase(faction)
    state._religions[new_rel.id] = new_rel
    return new_rel
```

**Uwaga:** `state._religions` jest dostępne przez duck typing — GameState nie ma class_name, ale pole `_religions` jest publiczne w kontekście GDScript.

- [ ] **Step 4: Uruchom testy — potwierdź PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20
```

Oczekiwane: 78 testów zielonych.

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/SchismManager.gd tests/engine/test_schism_manager.gd
git commit -m "feat: add trigger_schism to SchismManager — creates new religion from faction"
```

---

## Chunk 3: TurnManager — integracja misji i exodusu

### Task 7: TurnManager — misje uczonych i exodus wiernych

**Files:**
- Modify: `scripts/engine/TurnManager.gd`
- Modify: `tests/engine/test_turn_manager.gd`

- [ ] **Step 1: Dodaj testy integracji do pliku testowego (FAIL)**

Dopisz do `tests/engine/test_turn_manager.gd`:

```gdscript
func test_process_turn_decrements_scholar_mission_turns() -> void:
    var tm := TurnManager.new()
    var gs := _make_state()
    gs.scholar_missions.append({
        "from_religion_id": "islam",
        "to_religion_id": "chr_zachodnie",
        "turns_remaining": 2,
    })
    tm.process_turn(gs)
    assert_eq(gs.scholar_missions.size(), 1)
    assert_eq(gs.scholar_missions[0]["turns_remaining"], 1)

func test_process_turn_generates_idea_when_mission_completes() -> void:
    var tm := TurnManager.new()
    var gs := _make_state()
    var islam: Religion = gs.get_religion("islam")
    var chr: Religion = gs.get_religion("chr_zachodnie")
    # Pinuj wszystkie osie żeby A miała największą różnicę
    for rel in [islam, chr]:
        rel.axes["A"] = 50.0
        rel.axes["B"] = 50.0
        rel.axes["C"] = 50.0
        rel.axes["D"] = 50.0
    islam.axes["A"] = 20.0
    chr.axes["A"] = 80.0
    gs.scholar_missions.append({
        "from_religion_id": "islam",
        "to_religion_id": "chr_zachodnie",
        "turns_remaining": 1,
    })
    tm.process_turn(gs)
    assert_eq(gs.scholar_missions.size(), 0)
    assert_eq(gs.pending_ideas.size(), 1)
    assert_eq(gs.pending_ideas[0].axis, "A")

func test_process_turn_applies_believer_exodus_in_phase2() -> void:
    var tm := TurnManager.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    rel.factions[0].tension = 70.0
    var province := gs.province_graph.get_province("mekka")
    assert_not_null(province)
    var pop_before := province.population
    gs.province_graph.get_province("mekka").owner = "islam"
    tm.process_turn(gs)
    assert_lt(gs.province_graph.get_province("mekka").population, pop_before)

func test_process_turn_no_exodus_in_phase1() -> void:
    var tm := TurnManager.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    rel.factions[0].tension = 50.0
    var province := gs.province_graph.get_province("mekka")
    gs.province_graph.get_province("mekka").owner = "islam"
    var pop_before := province.population
    tm.process_turn(gs)
    assert_eq(gs.province_graph.get_province("mekka").population, pop_before)
```

- [ ] **Step 2: Uruchom testy — potwierdź FAIL**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20
```

- [ ] **Step 3: Zmodyfikuj `TurnManager.gd` — dodaj stałą i 2 nowe metody, zaktualizuj `process_turn`**

**WAŻNE:** NIE zastępuj całego pliku. Istniejące metody `_apply_passive_pressure`, `_apply_holy_site_prestige`, `_update_faction_tensions`, `_compute_faction_tension_delta`, `_pressure_delta` pozostają bez zmian.

**3a.** Dodaj stałą na końcu bloku stałych (po `AXIS_DIVERGENCE_THRESHOLD`):

```gdscript
const BELIEVER_EXODUS_PER_TURN := 5
```

**3b.** Zastąp tylko metodę `process_turn` (dodaj 2 nowe wywołania przed `state.advance_turn()`):

```gdscript
func process_turn(state: Node) -> void:
    _apply_passive_pressure(state.province_graph)
    _apply_holy_site_prestige(state)
    _update_faction_tensions(state)
    _process_scholar_missions(state)
    _apply_believer_exodus(state)
    state.advance_turn()
```

**3c.** Dodaj 2 nowe metody na końcu pliku (przed EOF):

```gdscript
func _process_scholar_missions(state: Node) -> void:
    var dm := DoctrineManager.new()
    var still_active: Array = []
    for mission: Dictionary in state.scholar_missions:
        mission["turns_remaining"] -= 1
        if mission["turns_remaining"] <= 0:
            var idea := dm.generate_idea(mission["from_religion_id"], mission["to_religion_id"], state)
            if idea != null:
                state.pending_ideas.append(idea)
        else:
            still_active.append(mission)
    state.scholar_missions = still_active

func _apply_believer_exodus(state: Node) -> void:
    var sm := SchismManager.new()
    for religion: Religion in state.all_religions():
        var has_phase2 := false
        for faction: Faction in religion.factions:
            if sm.get_phase(faction) >= 2:
                has_phase2 = true
                break
        if not has_phase2:
            continue
        for province: Province in state.province_graph.provinces_with_owner(religion.id):
            province.population = maxi(0, province.population - BELIEVER_EXODUS_PER_TURN)
```

- [ ] **Step 4: Uruchom testy — potwierdź PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20
```

Oczekiwane: ~82 testy zielone (poprzednie 78 + 4 nowe).

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/TurnManager.gd tests/engine/test_turn_manager.gd
git commit -m "feat: integrate DoctrineManager and SchismManager into TurnManager process_turn"
```

---

## Podsumowanie

Po wykonaniu tego planu:

| Plik | Status |
|------|--------|
| `scripts/engine/Idea.gd` | Nowy |
| `scripts/engine/DoctrineManager.gd` | Nowy |
| `scripts/engine/SchismManager.gd` | Nowy |
| `scripts/engine/GameState.gd` | Rozszerzony o `pending_ideas`, `scholar_missions` |
| `scripts/engine/TurnManager.gd` | Rozszerzony o `_process_scholar_missions`, `_apply_believer_exodus` |
| `tests/engine/test_doctrine_manager.gd` | Nowy |
| `tests/engine/test_schism_manager.gd` | Nowy |
| `tests/engine/test_turn_manager.gd` | Rozszerzony |

**Łącznie:** ~82 testy (46 z planu 1 + ~36 nowych).
