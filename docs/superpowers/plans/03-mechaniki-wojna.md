# Mechaniki: Wojna — fundament (Plan 3a) — Implementation Plan

> **For Claude:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Zaimplementować fundament mechaniki wojny: casus belli z doktryny + ze schizmy, deklarację wojny, formułę siły militarnej z modyfikatorami, probabilistyczne rozstrzyganie bitew, 3 warunki pokoju (Aneksja+asymilacja, Wymuszony sobór, Eksterminacja kleru), zmęczenie wojenne, Teologię klęski.

**Architecture:** `WarManager` to bezstanowa klasa `RefCounted` — analogicznie do `DoctrineManager`/`SchismManager`. Przyjmuje `GameState` (Node) jako argument. `War` i `DefeatEvent` to data classes (Resource). `GameState` rozszerzamy o `active_wars` i `pending_defeat_events`. `Religion` rozszerzamy o `war_weariness` i `parent_religion_id`. `SchismManager.trigger_schism` wypełnia `parent_religion_id` dla CB Stłumienie Herezji. `TurnManager.process_turn` wywołuje nowy krok `_process_active_wars`.

**Tech Stack:** Godot 4.6.3, GDScript 2.0, GUT (testy headless), JSON data files w `data/`.

**Uruchomienie testów:**
```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

**Spec referencyjny:** `docs/superpowers/specs/02-war-system-design.md` (Sekcje 1-4 + Apendyks A z decyzjami implementacyjnymi)

## Uwagi kontekstowe

- `GameState.gd` **nie ma** `class_name` (konflikt z Autoload) — testy używają `preload("res://scripts/engine/GameState.gd").new()`
- `WarManager.process_*(state: Node)` — duck typing, bo GameState nie ma class_name
- 88 testów zdanych na starcie tego planu (Plan 1 + Plan 2 wykonane)
- **`.uid` files są wymagane!** Po utworzeniu nowego pliku `.gd` uruchom `godot --headless --path . -e --quit` żeby wygenerować sidecar `.gd.uid` — bez tego klasy z `class_name` nie są rozwiązywalne w trybie headless. Dodaj `.uid` do tego samego commita.
- 4 osie teologiczne: A (Mistycyzm↔Dogmatyzm), B (Równouprawnienie↔Hierarchia), C (Ekskluzywizm↔Synkretyzm), D (Doczesność↔Transcendencja)

**Mapowanie pojęć ze speca → wartości osi:**
- Dogmatyzm = A, Mistycyzm = 100 - A
- Hierarchia = B, Równouprawnienie = 100 - B
- Synkretyzm = C, Ekskluzywizm = 100 - C
- Transcendencja = D, Doczesność = 100 - D

Przykład: "Ekskluzywizm >75" oznacza `100 - C > 75`, czyli `C < 25`. "Dogmatyzm >60" oznacza `A > 60`.

**Konwencja indentacji:** Nowe pliki — 4 spacje (jak `test_doctrine_manager.gd`). Modyfikacje istniejących plików — zachowaj indentację pliku (`SchismManager.gd`, `TurnManager.gd` używają tabów).

---

## Mapa plików

**Nowe pliki:**
- `scripts/engine/War.gd` (Resource) — dane aktywnej wojny (atakujący, broniący, CB, stan, contested)
- `scripts/engine/War.gd.uid` — sidecar Godota (auto-gen)
- `scripts/engine/DefeatEvent.gd` (Resource) — pending zdarzenie Teologii klęski z 3 opcjami osi
- `scripts/engine/DefeatEvent.gd.uid` — sidecar Godota (auto-gen)
- `scripts/engine/WarManager.gd` (RefCounted) — bezstanowy menedżer wojny: available_casus_belli, declare_war, compute_army_strength, attack_province, offer_peace, resolve_defeat
- `scripts/engine/WarManager.gd.uid` — sidecar Godota (auto-gen)
- `tests/engine/test_war_manager.gd` — pełna pokrywa testowa (~32 testy)

**Modyfikowane pliki:**
- `scripts/engine/Religion.gd` — dodaj pola `war_weariness: float = 0.0` i `parent_religion_id: String = ""`
- `scripts/engine/GameState.gd` — dodaj pola `active_wars: Array[War]` i `pending_defeat_events: Array[DefeatEvent]`
- `scripts/engine/SchismManager.gd` — w `trigger_schism` ustaw `new_rel.parent_religion_id = religion.id`
- `scripts/engine/TurnManager.gd` — `process_turn` woła `_process_active_wars(state)` (przed `state.advance_turn()`)
- `tests/engine/test_schism_manager.gd` — 1 nowy test: parent_religion_id po trigger_schism
- `tests/engine/test_turn_manager.gd` — 4 nowe testy: MOBILIZING→BATTLING, OCCUPYING→BATTLING, naliczanie weariness, force peace

---

## Chunk 1: Rozszerzenia modeli

### Task 1: Religion + GameState + SchismManager — nowe pola

**Files:**
- Modify: `scripts/engine/Religion.gd`
- Modify: `scripts/engine/GameState.gd`
- Modify: `scripts/engine/SchismManager.gd`
- Test: `tests/engine/test_schism_manager.gd` (rozbudowa)
- Test: `tests/engine/test_war_manager.gd` (nowy plik, pierwsze testy)

- [ ] **Step 1: Utwórz `tests/engine/test_war_manager.gd` z pierwszymi testami (FAIL)**

```gdscript
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
```

- [ ] **Step 2: Dopisz test parent_religion_id do `tests/engine/test_schism_manager.gd`**

Dopisz na końcu pliku:

```gdscript
func test_trigger_schism_sets_parent_religion_id() -> void:
    var sm := SchismManagerScript.new()
    var gs := _make_state()
    var rel: Religion = gs.get_religion("islam")
    var faction := rel.factions[0]
    faction.tension = 90.0
    faction.influence = 0.5
    var new_rel := sm.trigger_schism(faction, rel, gs)
    assert_not_null(new_rel)
    assert_eq(new_rel.parent_religion_id, rel.id)
```

- [ ] **Step 3: Uruchom testy — potwierdź FAIL**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -30
```

Oczekiwane: błędy `Invalid access to property 'war_weariness'`, `'parent_religion_id'`, `'active_wars'`, `'pending_defeat_events'`.

- [ ] **Step 4: Rozszerz `scripts/engine/Religion.gd`**

Dodaj dwa nowe pola po `@export var accent_color: String = "#ffffff"`:

```gdscript
@export var war_weariness: float = 0.0
@export var parent_religion_id: String = ""
```

- [ ] **Step 5: Rozszerz `scripts/engine/GameState.gd`**

Dodaj dwa nowe pola po `var scholar_missions: Array = []`:

```gdscript
var active_wars: Array = []            # promote do Array[War] w Task 2 Step 6
var pending_defeat_events: Array = []  # promote do Array[DefeatEvent] w Task 2 Step 6
```

> Uwaga: `War` i `DefeatEvent` nie istnieją jeszcze — utworzymy je w Task 2. Używamy **untyped** `Array` jako primary path, żeby parser GDScript nie miał chicken-and-egg z brakującymi `class_name`. Po utworzeniu data classes + `.uid` w Task 2 promotujemy do typed (Task 2 Step 6).

- [ ] **Step 6: Zmodyfikuj `scripts/engine/SchismManager.gd` — funkcja `trigger_schism`**

W funkcji `trigger_schism`, zaraz po linii `new_rel.id = religion.id + "_" + faction.id + "_schizma"`, dodaj:

```gdscript
	new_rel.parent_religion_id = religion.id
```

(zachowaj tabulację — `SchismManager.gd` używa tabów)

- [ ] **Step 7: Uruchom testy — potwierdź PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20
```

Oczekiwane: wszystkie testy zielone (88 poprzednie + 4 nowe w test_war_manager + 1 nowy w test_schism_manager = 93).

- [ ] **Step 8: Commit**

```bash
git add scripts/engine/Religion.gd scripts/engine/GameState.gd scripts/engine/SchismManager.gd tests/engine/test_war_manager.gd tests/engine/test_schism_manager.gd
git commit -m "feat: extend Religion with war_weariness/parent_religion_id, GameState with active_wars/pending_defeat_events; SchismManager sets parent on schism"
```

---

### Task 2: War.gd + DefeatEvent.gd (data classes)

**Files:**
- Create: `scripts/engine/War.gd`
- Create: `scripts/engine/War.gd.uid` (auto-gen)
- Create: `scripts/engine/DefeatEvent.gd`
- Create: `scripts/engine/DefeatEvent.gd.uid` (auto-gen)
- Test: `tests/engine/test_war_manager.gd` (rozbudowa)

- [ ] **Step 1: Dopisz testy pól War i DefeatEvent (FAIL)**

Dopisz do `tests/engine/test_war_manager.gd`:

```gdscript
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
```

- [ ] **Step 2: Uruchom testy — potwierdź FAIL**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20
```

Oczekiwane: błędy o nieistniejącej klasie `War` i `DefeatEvent`.

- [ ] **Step 3: Utwórz `scripts/engine/War.gd`**

```gdscript
class_name War
extends Resource

@export var attacker_id: String = ""
@export var defender_id: String = ""
@export var casus_belli: String = ""        # krucjata | dzihad | wojna_sprawiedliwa | nawrocenie_mieczem | stlumienie_herezji
@export var state: String = "MOBILIZING"    # MOBILIZING | BATTLING | OCCUPYING | ENDED
@export var turns_in_state: int = 0
@export var contested_provinces: Array[String] = []
@export var battles_won: int = 0
@export var battles_lost: int = 0
@export var outcome: String = ""            # "" | WIN | LOSS | DRAW (po ENDED)
```

- [ ] **Step 4: Utwórz `scripts/engine/DefeatEvent.gd`**

```gdscript
class_name DefeatEvent
extends Resource

@export var religion_id: String = ""
@export var opponent_id: String = ""
@export var cb: String = ""
@export var options: Array = []  # Array[Dictionary]: {label: String, axis: String, delta: float}
```

- [ ] **Step 5: Wygeneruj `.uid` sidecar dla obu plików**

```bash
godot --headless --path . -e --quit 2>&1 | tail -10
ls scripts/engine/War.gd.uid scripts/engine/DefeatEvent.gd.uid
```

Oczekiwane: oba pliki `.uid` istnieją.

- [ ] **Step 6: Promote untyped `Array` do typed w `GameState.gd`**

`War.gd` i `DefeatEvent.gd` istnieją z `.uid` → parser potrafi rozwiązać `class_name`. Zmień:

```gdscript
var active_wars: Array[War] = []
var pending_defeat_events: Array[DefeatEvent] = []
```

- [ ] **Step 7: Uruchom testy — potwierdź PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20
```

Oczekiwane: 97 testów zielonych (93 + 4 nowe).

- [ ] **Step 8: Commit**

```bash
git add scripts/engine/War.gd scripts/engine/War.gd.uid scripts/engine/DefeatEvent.gd scripts/engine/DefeatEvent.gd.uid scripts/engine/GameState.gd tests/engine/test_war_manager.gd
git commit -m "feat: add War and DefeatEvent data classes"
```

---

## Chunk 2: WarManager — CB i deklaracja wojny

### Task 3: WarManager + available_casus_belli (5 CB)

**Files:**
- Create: `scripts/engine/WarManager.gd`
- Create: `scripts/engine/WarManager.gd.uid` (auto-gen)
- Test: `tests/engine/test_war_manager.gd` (rozbudowa)

- [ ] **Step 1: Dopisz testy CB do `tests/engine/test_war_manager.gd` (FAIL)**

```gdscript
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
```

- [ ] **Step 2: Uruchom testy — potwierdź FAIL**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20
```

- [ ] **Step 3: Utwórz `scripts/engine/WarManager.gd` z `available_casus_belli`**

```gdscript
class_name WarManager
extends RefCounted

# --- Stałe wojny ---
const MOBILIZATION_TURNS := 2
const OCCUPATION_TURNS := 2
const WEARINESS_PER_TURN := 3.0
const WEARINESS_FORCED_PEACE := 90.0
const DECLARE_WAR_PRESTIGE := 10

# --- Stałe siły militarnej ---
const BASE_POPULATION_FACTOR := 0.1
const BASE_PRESTIGE_FACTOR := 2.0

const CB_BONUS: Dictionary = {
    "krucjata": 0.30,
    "dzihad": 0.40,
    "wojna_sprawiedliwa": 0.20,
    "nawrocenie_mieczem": 0.10,
    "stlumienie_herezji": 0.15,
}

# --- Stałe pokoju ---
const ASYMILACJA_AXIS_C_DELTA := 5.0   # Zasymiluj → atakujący przesuwa C w stronę synkretyzmu

# --- Modyfikatory osi (sumowane) ---
# Każda reguła: {"axis": X, "min": Y} = X >= Y → bonus; {"axis": X, "max": Y} = X <= Y → bonus
const AXIS_STRENGTH_MODIFIERS: Array = [
    {"axis": "A", "min": 60.0, "bonus": 0.15},    # Dogmatyzm >60
    {"axis": "B", "min": 60.0, "bonus": 0.20},    # Hierarchia >60
    {"axis": "D", "min": 65.0, "bonus": 0.25},    # Transcendencja >65
    {"axis": "D", "max": 35.0, "bonus": 0.15},    # Doczesność >65 → D <35
    {"axis": "C", "min": 60.0, "bonus": 0.10},    # Synkretyzm >60
]

# --- Modyfikatory terenu (broniący prowincji) ---
const TERRAIN_DEFENDER_MODIFIERS: Dictionary = {
    "mountains": 0.15,
    "desert": 0.10,
    "fertile": 0.05,
    "plains": 0.0,
    "coast": 0.0,
}

# --- Kara za zmęczenie wojenne ---
const WEARINESS_PENALTIES: Array = [
    {"min": 75.0, "penalty": 0.30},
    {"min": 55.0, "penalty": 0.20},
    {"min": 30.0, "penalty": 0.10},
]

# --- 3 opcje Teologii klęski ---
const DEFEAT_OPTIONS: Array = [
    {"label": "Kara za grzechy", "axis": "A", "delta": 5.0},      # Dogmatyzm
    {"label": "Wola niezbadana", "axis": "A", "delta": -8.0},     # Mistycyzm
    {"label": "Reformujemy się", "axis": "B", "delta": -6.0},     # Równouprawnienie
]

# --- CB z osi: każde CB wymaga zestawu reguł osi (wszystkie muszą być spełnione) ---
# Reguła: {"axis": X, "min": Y} = X >= Y; {"axis": X, "max": Y} = X <= Y
# UWAGA semantyka: min/max są INCLUSIVE na granicy (np. max=25 dopuszcza C=25).
# Spec używa strict ">" ("Ekskluzywizm >75"), ale konwencja repo (DoctrineManager.AXIS_THRESHOLDS)
# jest inclusive — celowo zachowujemy spójność.
const CB_AXIS_REQUIREMENTS: Dictionary = {
    "krucjata":           [{"axis": "C", "max": 25.0}, {"axis": "D", "max": 40.0}],   # Ekskl >75 + Doczesność >60
    "dzihad":             [{"axis": "C", "max": 25.0}, {"axis": "D", "min": 70.0}],   # Ekskl >75 + Transcendencja >70
    "wojna_sprawiedliwa": [{"axis": "B", "min": 60.0}, {"axis": "D", "max": 50.0}],   # Hierarchia >60 + Doczesność >50
    "nawrocenie_mieczem": [{"axis": "C", "max": 40.0}, {"axis": "A", "min": 65.0}],   # Ekskl >60 + Dogmatyzm >65
}

func available_casus_belli(attacker: Religion, defender: Religion) -> Array[String]:
    var result: Array[String] = []
    for cb_id: String in CB_AXIS_REQUIREMENTS.keys():
        var rules: Array = CB_AXIS_REQUIREMENTS[cb_id]
        if _religion_matches_axis_rules(attacker, rules):
            result.append(cb_id)
    if defender.parent_religion_id == attacker.id and attacker.id != "":
        result.append("stlumienie_herezji")
    return result

func _religion_matches_axis_rules(religion: Religion, rules: Array) -> bool:
    for rule: Dictionary in rules:
        var axis: String = rule.get("axis", "")
        var value := religion.get_axis(axis)
        if rule.has("min") and value < rule["min"]:
            return false
        if rule.has("max") and value > rule["max"]:
            return false
    return true
```

- [ ] **Step 4: Wygeneruj `.uid` sidecar**

```bash
godot --headless --path . -e --quit 2>&1 | tail -5
ls scripts/engine/WarManager.gd.uid
```

- [ ] **Step 5: Uruchom testy — potwierdź PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20
```

Oczekiwane: 104 testy zielone (97 + 7 nowych).

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/WarManager.gd scripts/engine/WarManager.gd.uid tests/engine/test_war_manager.gd
git commit -m "feat: add WarManager with available_casus_belli (4 axis-based CB + stlumienie_herezji)"
```

---

### Task 4: WarManager.declare_war

**Files:**
- Modify: `scripts/engine/WarManager.gd`
- Test: `tests/engine/test_war_manager.gd` (rozbudowa)

- [ ] **Step 1: Dopisz testy declare_war (FAIL)**

```gdscript
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
```

- [ ] **Step 2: Uruchom testy — potwierdź FAIL**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20
```

- [ ] **Step 3: Dodaj funkcję `declare_war` do `WarManager.gd`**

Dopisz pod `available_casus_belli`/`_religion_matches_axis_rules`:

```gdscript
func declare_war(attacker_id: String, defender_id: String, cb: String, state: Node) -> War:
    var attacker: Religion = state.get_religion(attacker_id)
    var defender: Religion = state.get_religion(defender_id)
    if attacker == null or defender == null:
        return null
    if not available_casus_belli(attacker, defender).has(cb):
        return null
    if attacker.prestige < DECLARE_WAR_PRESTIGE:
        return null
    attacker.add_prestige(-DECLARE_WAR_PRESTIGE)
    var war := War.new()
    war.attacker_id = attacker_id
    war.defender_id = defender_id
    war.casus_belli = cb
    war.state = "MOBILIZING"
    war.turns_in_state = 0
    state.active_wars.append(war)
    return war
```

- [ ] **Step 4: Uruchom testy — potwierdź PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20
```

Oczekiwane: 108 testów zielonych (104 + 4 nowe).

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/WarManager.gd tests/engine/test_war_manager.gd
git commit -m "feat: WarManager.declare_war — costs 10 prestige, validates CB, adds to active_wars"
```

---

## Chunk 3: WarManager — siła i bitwa

### Task 5: compute_army_strength (baza + modyfikatory)

**Files:**
- Modify: `scripts/engine/WarManager.gd`
- Test: `tests/engine/test_war_manager.gd` (rozbudowa)

- [ ] **Step 1: Dopisz testy siły do `tests/engine/test_war_manager.gd` (FAIL)**

```gdscript
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
```

- [ ] **Step 2: Uruchom testy — potwierdź FAIL**

- [ ] **Step 3: Dodaj `compute_army_strength` do `WarManager.gd`**

Dopisz na końcu pliku:

```gdscript
func compute_army_strength(religion: Religion, target_province: Province, war: War, state: Node) -> float:
    var owned: Array[Province] = state.province_graph.provinces_with_owner(religion.id)
    var pop_total := 0
    for p: Province in owned:
        pop_total += p.population
    var base := float(pop_total) * BASE_POPULATION_FACTOR + float(religion.prestige) * BASE_PRESTIGE_FACTOR
    var axis_modifier := 0.0
    for rule: Dictionary in AXIS_STRENGTH_MODIFIERS:
        var axis: String = rule["axis"]
        var value := religion.get_axis(axis)
        if rule.has("min") and value >= rule["min"]:
            axis_modifier += rule["bonus"]
        elif rule.has("max") and value <= rule["max"]:
            axis_modifier += rule["bonus"]
    var cb_modifier: float = CB_BONUS.get(war.casus_belli, 0.0)
    var weariness_penalty := 0.0
    for rule: Dictionary in WEARINESS_PENALTIES:
        if religion.war_weariness >= rule["min"]:
            weariness_penalty = rule["penalty"]
            break  # WEARINESS_PENALTIES posortowane od max do min
    var strength := base * (1.0 + axis_modifier) * (1.0 + cb_modifier) * (1.0 - weariness_penalty)
    # Modyfikator terenu tylko dla broniącego
    if religion.id == war.defender_id and target_province != null:
        var terrain_bonus: float = TERRAIN_DEFENDER_MODIFIERS.get(target_province.terrain, 0.0)
        strength *= (1.0 + terrain_bonus)
    return strength
```

- [ ] **Step 4: Uruchom testy — potwierdź PASS**

Oczekiwane: 114 testów zielonych (108 + 6 nowych).

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/WarManager.gd tests/engine/test_war_manager.gd
git commit -m "feat: WarManager.compute_army_strength — base + axis/CB/weariness/terrain modifiers"
```

---

### Task 6: attack_province — probabilistyczna bitwa

**Files:**
- Modify: `scripts/engine/WarManager.gd`
- Test: `tests/engine/test_war_manager.gd` (rozbudowa)

- [ ] **Step 1: Dopisz testy bitwy (FAIL)**

```gdscript
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
    assert_gte(wins, 95, "przy przewadze atakującego 100000:0 powinno być ≥95% zwycięstw, było %d" % wins)

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
```

- [ ] **Step 2: Uruchom testy — potwierdź FAIL**

- [ ] **Step 3: Dodaj `attack_province` do `WarManager.gd`**

```gdscript
func attack_province(war: War, province_id: String, state: Node) -> Dictionary:
    if war.state != "BATTLING":
        return {"victory": false, "atk_str": 0.0, "def_str": 0.0, "p_win": 0.0, "error": "not_battling"}
    var attacker: Religion = state.get_religion(war.attacker_id)
    var defender: Religion = state.get_religion(war.defender_id)
    var target: Province = state.province_graph.get_province(province_id)
    if attacker == null or defender == null or target == null:
        return {"victory": false, "atk_str": 0.0, "def_str": 0.0, "p_win": 0.0, "error": "invalid_target"}
    var atk_str := compute_army_strength(attacker, target, war, state)
    var def_str := compute_army_strength(defender, target, war, state)
    var total := atk_str + def_str
    var p_win := 0.5 if total <= 0.0 else atk_str / total
    var roll := randf()
    var victory := roll < p_win
    if victory:
        war.battles_won += 1
        if not war.contested_provinces.has(province_id):
            war.contested_provinces.append(province_id)
        war.state = "OCCUPYING"
        war.turns_in_state = 0
    else:
        war.battles_lost += 1
    return {"victory": victory, "atk_str": atk_str, "def_str": def_str, "p_win": p_win}
```

- [ ] **Step 4: Uruchom testy — potwierdź PASS**

Oczekiwane: 119 testów zielonych (114 + 5 nowych).

> Uwaga: probabilistyczne testy używają `randf()` — w skrajnie rzadkim przypadku mogą zafailować przez statystyczną fluktuację. Progi ≥95/≤5 są na tyle szerokie że prawdopodobieństwo flaky < 0.0001. Jeśli test się zafailuje, **uruchom go drugi raz** zanim uznasz że coś jest źle.

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/WarManager.gd tests/engine/test_war_manager.gd
git commit -m "feat: WarManager.attack_province — share-based probability, state transitions, contested accumulation"
```

---

## Chunk 4: Warunki pokoju

### Task 7: offer_peace + Aneksja z polityką asymilacji

**Files:**
- Modify: `scripts/engine/WarManager.gd`
- Test: `tests/engine/test_war_manager.gd` (rozbudowa)

W tym task wprowadzamy `offer_peace(war, terms, state)` z obsługą **tylko jednego** warunku — aneksji. Pozostałe warunki dochodzą w Task 8, 9.

`terms` to `Dictionary` ze strukturą:
```
{
    "annexation": {"provinces": ["anatolia"], "policy": "zasymiluj"},   # opcjonalne
    "forced_council": {"axis": "C", "delta": 5.0},                       # opcjonalne, Task 8
    "clergy_extermination": {"faction_id": "patriarchowie"},             # opcjonalne, Task 9
}
```

`policy` ∈ {`"wypedz"`, `"nawracaj"`, `"zasymiluj"`}.

- [ ] **Step 1: Dopisz testy aneksji (FAIL)**

```gdscript
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
```

- [ ] **Step 2: Uruchom testy — potwierdź FAIL**

- [ ] **Step 3: Dodaj `offer_peace` z aneksją do `WarManager.gd`**

```gdscript
func offer_peace(war: War, terms: Dictionary, state: Node) -> bool:
    if war.state == "ENDED":
        return false
    if terms.has("annexation"):
        var ann: Dictionary = terms["annexation"]
        var provinces: Array = ann.get("provinces", [])
        var policy: String = ann.get("policy", "nawracaj")
        _apply_annexation(war, provinces, policy, state)
    # Wymuszony sobór i Eksterminacja kleru — Task 8, 9
    war.state = "ENDED"
    war.outcome = "WIN" if war.contested_provinces.size() > 0 else "DRAW"
    state.active_wars.erase(war)
    return true

func _apply_annexation(war: War, province_ids: Array, policy: String, state: Node) -> void:
    var attacker: Religion = state.get_religion(war.attacker_id)
    for province_id in province_ids:
        if not war.contested_provinces.has(province_id):
            continue  # tylko prowincje faktycznie okupowane
        var province: Province = state.province_graph.get_province(province_id)
        if province == null:
            continue
        province.owner = war.attacker_id
        match policy:
            "wypedz":
                province.population = 0
            "nawracaj":
                pass  # zostaje populacja i pressure
            "zasymiluj":
                if attacker != null:
                    attacker.shift_axis("C", ASYMILACJA_AXIS_C_DELTA)
```

- [ ] **Step 4: Uruchom testy — potwierdź PASS**

Oczekiwane: 125 testów zielonych (119 + 6 nowych).

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/WarManager.gd tests/engine/test_war_manager.gd
git commit -m "feat: WarManager.offer_peace + annexation with 3 assimilation policies"
```

---

### Task 8: offer_peace + Wymuszony sobór

**Files:**
- Modify: `scripts/engine/WarManager.gd`
- Test: `tests/engine/test_war_manager.gd` (rozbudowa)

- [ ] **Step 1: Dopisz testy wymuszonego soboru (FAIL)**

```gdscript
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
```

- [ ] **Step 2: Uruchom testy — potwierdź FAIL**

- [ ] **Step 3: Dodaj wymuszony sobór do `offer_peace`**

W `offer_peace`, **przed** linią `war.state = "ENDED"`, dodaj:

```gdscript
    if terms.has("forced_council"):
        var fc: Dictionary = terms["forced_council"]
        var axis: String = fc.get("axis", "")
        var delta: float = fc.get("delta", 0.0)
        _apply_forced_council(war, axis, delta, state)
```

I dopisz pomocniczą funkcję pod `_apply_annexation`:

```gdscript
func _apply_forced_council(war: War, axis: String, delta: float, state: Node) -> void:
    var defender: Religion = state.get_religion(war.defender_id)
    if defender == null or axis == "":
        return
    defender.shift_axis(axis, delta)
```

- [ ] **Step 4: Uruchom testy — potwierdź PASS**

Oczekiwane: 128 testów zielonych (125 + 3 nowe).

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/WarManager.gd tests/engine/test_war_manager.gd
git commit -m "feat: WarManager.offer_peace + forced council (defender axis shift)"
```

---

### Task 9: offer_peace + Eksterminacja kleru

**Files:**
- Modify: `scripts/engine/WarManager.gd`
- Test: `tests/engine/test_war_manager.gd` (rozbudowa)

Eksterminacja kleru usuwa wskazaną frakcję broniącego i **rozdziela jej wpływ równo** między pozostałe frakcje.

- [ ] **Step 1: Dopisz testy eksterminacji (FAIL)**

```gdscript
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
```

- [ ] **Step 2: Uruchom testy — potwierdź FAIL**

- [ ] **Step 3: Dodaj eksterminację kleru do `offer_peace`**

W `offer_peace`, **przed** `war.state = "ENDED"`:

```gdscript
    if terms.has("clergy_extermination"):
        var ce: Dictionary = terms["clergy_extermination"]
        var faction_id: String = ce.get("faction_id", "")
        _apply_clergy_extermination(war, faction_id, state)
```

I dopisz pomocniczą funkcję:

```gdscript
func _apply_clergy_extermination(war: War, faction_id: String, state: Node) -> void:
    var defender: Religion = state.get_religion(war.defender_id)
    if defender == null or faction_id == "":
        return
    var target: Faction = defender.get_faction(faction_id)
    if target == null:
        return
    var redistributed := target.influence
    defender.factions.erase(target)
    if defender.factions.size() > 0:
        var share := redistributed / float(defender.factions.size())
        for f: Faction in defender.factions:
            f.influence += share
```

- [ ] **Step 4: Uruchom testy — potwierdź PASS**

Oczekiwane: 132 testy zielone (128 + 4 nowe).

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/WarManager.gd tests/engine/test_war_manager.gd
git commit -m "feat: WarManager.offer_peace + clergy extermination (removes faction, redistributes influence)"
```

---

## Chunk 5: DefeatEvent + TurnManager integracja

### Task 10: DefeatEvent created on LOSS + resolve_defeat

**Files:**
- Modify: `scripts/engine/WarManager.gd`
- Test: `tests/engine/test_war_manager.gd` (rozbudowa)

W tym task dodajemy 2 publiczne funkcje:
- `force_loss(war, loser_id, state)` — wymusza koniec wojny ze stanem LOSS dla `loser_id`, tworzy DefeatEvent
- `resolve_defeat(event, option_index, state)` — gracz wybiera opcję teologiczną

Dlaczego `force_loss` osobno od `offer_peace`? Bo offer_peace = sukces atakującego (WIN/DRAW), force_loss = klęska (atakujący lub broniący). TurnManager będzie wywoływał force_loss przy weariness ≥ 90 (Task 11).

- [ ] **Step 1: Dopisz testy klęski (FAIL)**

```gdscript
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
```

- [ ] **Step 2: Uruchom testy — potwierdź FAIL**

- [ ] **Step 3: Dodaj `force_loss` i `resolve_defeat` do `WarManager.gd`**

```gdscript
func force_loss(war: War, loser_id: String, state: Node) -> void:
    if war.state == "ENDED":
        return
    war.state = "ENDED"
    war.outcome = "LOSS"
    state.active_wars.erase(war)
    var winner_id: String = war.defender_id if loser_id == war.attacker_id else war.attacker_id
    var ev := DefeatEvent.new()
    ev.religion_id = loser_id
    ev.opponent_id = winner_id
    ev.cb = war.casus_belli
    ev.options = DEFEAT_OPTIONS.duplicate(true)
    state.pending_defeat_events.append(ev)

func resolve_defeat(event: DefeatEvent, option_index: int, state: Node) -> void:
    if option_index < 0 or option_index >= event.options.size():
        return
    var option: Dictionary = event.options[option_index]
    var religion: Religion = state.get_religion(event.religion_id)
    if religion == null:
        return
    religion.shift_axis(option.get("axis", ""), option.get("delta", 0.0))
    state.pending_defeat_events.erase(event)
```

- [ ] **Step 4: Uruchom testy — potwierdź PASS**

Oczekiwane: 137 testów zielonych (132 + 5 nowych).

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/WarManager.gd tests/engine/test_war_manager.gd
git commit -m "feat: WarManager.force_loss + resolve_defeat — DefeatEvent with 3 axis options (Teologia klęski)"
```

---

### Task 11: TurnManager._process_active_wars — integracja

**Files:**
- Modify: `scripts/engine/TurnManager.gd`
- Test: `tests/engine/test_turn_manager.gd` (rozbudowa)

`process_turn` zyskuje krok `_process_active_wars(state)` przed `state.advance_turn()`. Ten krok:
1. Inkrementuje `turns_in_state` każdej aktywnej wojny.
2. `MOBILIZING` → `BATTLING` po `MOBILIZATION_TURNS`.
3. `OCCUPYING` → `BATTLING` po `OCCUPATION_TURNS` (broniący ma okno na kontratak; AI w PoC tego nie wykorzystuje).
4. Dla obu stron każdej aktywnej wojny: `war_weariness += WEARINESS_PER_TURN`.
5. Po naliczeniu zmęczenia: jeśli ktoraś strona ma `war_weariness >= WEARINESS_FORCED_PEACE` → `force_loss(war, ta_strona, state)`.

Uwaga: iteracja po `active_wars` może się zmieniać przez `force_loss` (`erase`). Zbieramy `still_active` jak w `_process_scholar_missions`.

- [ ] **Step 1: Dopisz testy integracji do `tests/engine/test_turn_manager.gd` (FAIL)**

```gdscript
const WarManagerScript := preload("res://scripts/engine/WarManager.gd")

func _pin_axes_tm(rel: Religion, a: float, b: float, c: float, d: float) -> void:
    rel.axes["A"] = a
    rel.axes["B"] = b
    rel.axes["C"] = c
    rel.axes["D"] = d

func test_process_turn_mobilizing_war_transitions_to_battling_after_2_turns() -> void:
    var tm := TurnManager.new()
    var wm := WarManagerScript.new()
    var gs := _make_state()
    var att: Religion = gs.get_religion("islam")
    _pin_axes_tm(att, 50.0, 50.0, 20.0, 75.0)
    att.prestige = 100
    var war := wm.declare_war("islam", "chr_wschodnie", "dzihad", gs)
    assert_eq(war.state, "MOBILIZING")
    tm.process_turn(gs)
    assert_eq(war.state, "MOBILIZING")
    assert_eq(war.turns_in_state, 1)
    tm.process_turn(gs)
    assert_eq(war.state, "BATTLING")
    assert_eq(war.turns_in_state, 0)

func test_process_turn_occupying_war_returns_to_battling_after_2_turns() -> void:
    var tm := TurnManager.new()
    var gs := _make_state()
    var war := War.new()
    war.attacker_id = "islam"
    war.defender_id = "chr_wschodnie"
    war.casus_belli = "dzihad"
    war.state = "OCCUPYING"
    war.turns_in_state = 0
    gs.active_wars.append(war)
    tm.process_turn(gs)
    assert_eq(war.state, "OCCUPYING")
    assert_eq(war.turns_in_state, 1)
    tm.process_turn(gs)
    assert_eq(war.state, "BATTLING")
    assert_eq(war.turns_in_state, 0)

func test_process_turn_increments_war_weariness_for_both_sides() -> void:
    var tm := TurnManager.new()
    var gs := _make_state()
    var att: Religion = gs.get_religion("islam")
    var def: Religion = gs.get_religion("chr_wschodnie")
    att.war_weariness = 10.0
    def.war_weariness = 5.0
    var war := War.new()
    war.attacker_id = "islam"
    war.defender_id = "chr_wschodnie"
    war.state = "BATTLING"
    gs.active_wars.append(war)
    tm.process_turn(gs)
    assert_almost_eq(att.war_weariness, 10.0 + WarManagerScript.WEARINESS_PER_TURN, 0.001)
    assert_almost_eq(def.war_weariness, 5.0 + WarManagerScript.WEARINESS_PER_TURN, 0.001)

func test_process_turn_force_peace_at_weariness_90_creates_defeat_event() -> void:
    var tm := TurnManager.new()
    var gs := _make_state()
    var att: Religion = gs.get_religion("islam")
    att.war_weariness = 88.0  # po +3 → 91, próg 90 przekroczony
    var war := War.new()
    war.attacker_id = "islam"
    war.defender_id = "chr_wschodnie"
    war.casus_belli = "dzihad"
    war.state = "BATTLING"
    gs.active_wars.append(war)
    tm.process_turn(gs)
    assert_eq(war.state, "ENDED")
    assert_eq(war.outcome, "LOSS")
    assert_eq(gs.active_wars.size(), 0)
    assert_eq(gs.pending_defeat_events.size(), 1)
    var ev: DefeatEvent = gs.pending_defeat_events[0]
    assert_eq(ev.religion_id, "islam")
    assert_eq(ev.opponent_id, "chr_wschodnie")
```

- [ ] **Step 2: Uruchom testy — potwierdź FAIL**

- [ ] **Step 3: Zmodyfikuj `scripts/engine/TurnManager.gd`**

Dodaj w `process_turn` linię `_process_active_wars(state)` zaraz po `_apply_believer_exodus(state)` (przed `state.advance_turn()`):

```gdscript
func process_turn(state: Node) -> void:
    _apply_passive_pressure(state.province_graph)
    _apply_holy_site_prestige(state)
    _update_faction_tensions(state)
    _process_scholar_missions(state)
    _apply_believer_exodus(state)
    _process_active_wars(state)
    state.advance_turn()
```

Dodaj na końcu pliku nową funkcję (zachowaj tabulację — `TurnManager.gd` używa 4 spacji wg podglądu):

```gdscript
func _process_active_wars(state: Node) -> void:
    var wm := WarManager.new()
    # Najpierw przejścia stanów i naliczanie weariness
    var still_active: Array[War] = []
    for war: War in state.active_wars:
        war.turns_in_state += 1
        if war.state == "MOBILIZING" and war.turns_in_state >= WarManager.MOBILIZATION_TURNS:
            war.state = "BATTLING"
            war.turns_in_state = 0
        elif war.state == "OCCUPYING" and war.turns_in_state >= WarManager.OCCUPATION_TURNS:
            war.state = "BATTLING"
            war.turns_in_state = 0
        var attacker: Religion = state.get_religion(war.attacker_id)
        var defender: Religion = state.get_religion(war.defender_id)
        if attacker != null:
            attacker.war_weariness = clampf(attacker.war_weariness + WarManager.WEARINESS_PER_TURN, 0.0, 100.0)
        if defender != null:
            defender.war_weariness = clampf(defender.war_weariness + WarManager.WEARINESS_PER_TURN, 0.0, 100.0)
        still_active.append(war)
    state.active_wars = still_active
    # Drugi przebieg: force_loss dla stron z weariness >= próg
    var to_force: Array = []
    for war: War in state.active_wars:
        var attacker: Religion = state.get_religion(war.attacker_id)
        var defender: Religion = state.get_religion(war.defender_id)
        if attacker != null and attacker.war_weariness >= WarManager.WEARINESS_FORCED_PEACE:
            to_force.append({"war": war, "loser_id": war.attacker_id})
        elif defender != null and defender.war_weariness >= WarManager.WEARINESS_FORCED_PEACE:
            to_force.append({"war": war, "loser_id": war.defender_id})
    for entry: Dictionary in to_force:
        wm.force_loss(entry["war"], entry["loser_id"], state)
```

- [ ] **Step 4: Uruchom testy — potwierdź PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -30
```

Oczekiwane: 141 testów zielonych (137 + 4 nowe). Wszystkie istniejące testy (88 + Plan 3a) nadal zielone.

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/TurnManager.gd tests/engine/test_turn_manager.gd
git commit -m "feat: TurnManager._process_active_wars — state transitions, weariness, force peace at >=90"
```

---

## Po wykonaniu wszystkich tasków

Spodziewany stan:
- **141 testów zdanych** (88 wcześniej + 53 nowe — szczegółowy bilans w komentarzach przy każdym tasku)
- **12 commitów** (po 1 na task + 1 dodatkowy jeśli implementer rozdzieli niektóre kroki)
- Nowe pliki: `War.gd`, `War.gd.uid`, `DefeatEvent.gd`, `DefeatEvent.gd.uid`, `WarManager.gd`, `WarManager.gd.uid`, `test_war_manager.gd`
- Modyfikowane: `Religion.gd`, `GameState.gd`, `SchismManager.gd`, `TurnManager.gd`, `test_schism_manager.gd`, `test_turn_manager.gd`

**Wywołanie `superpowers:finishing-a-development-branch` po wszystkich taskach** — zgodnie z konwencją Plan 2.

## Co NIE wchodzi do Plan 3a (odłożone do 3b/3c)

- **Krucjata/Dżihad jako meta-mechanika** (jednoczenie schizmatyków, zawieszenie napięć frakcyjnych, cooldown 1 epoka, prestige >500) — Plan 3c
- **Wskaźnik zagrożenia globalnego + koalicje obronne** — Plan 3b (dyplomacja)
- **Frakcje pacyfistyczne jako blokada wypowiedzenia wojny** — Plan 3c
- **Obowiązkowe wojny `[Fatwa]`/`[Sobór Wojenny]` z Ekskl. >80** — Plan 3c
- **Warunki pokoju: Trybut i Unia pod zwierzchnictwem** — Plan 3b (wymaga `Religion.resources` i vassalage)
- **Sobór Pokojowy (redukcja zmęczenia za prestiż)** — Plan 3b
- **AI broniącego: kontratak w stanie BATTLING** — przyszłość, PoC bez AI
- **Limity liczby aktywnych wojen** — celowo brak w 3a
