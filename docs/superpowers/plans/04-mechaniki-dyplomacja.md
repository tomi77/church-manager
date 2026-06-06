# Mechaniki: Dyplomacja — fundament (Plan 04) — Implementation Plan

> **For Claude:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Zaimplementować fundament systemu dyplomacji: 3 wskaźniki relacji per-para religii (zaufanie teologiczne, współpraca ekonomiczna, napięcie militarne), Sojusz Obronny, Interdykt Dyplomatyczny, wskaźnik zagrożenia globalnego, koalicje obronne (tworzenie i rozpad), Sobór Pokojowy oraz integrację z systemem wojny.

**Architecture:** `DiplomacyManager` to bezstanowa klasa `RefCounted` — analogicznie do `WarManager`/`DoctrineManager`/`SchismManager`. Przyjmuje `GameState` (Node) jako argument. `RelationState` i `Coalition` to data classes (Resource). `GameState` rozszerzamy o `relations` i `active_coalitions`. `WarManager.declare_war` podnosi `military_tension` w relacji atakujący↔broniący. `TurnManager.process_turn` wywołuje nowy krok `_process_diplomacy(state)` (tick zaniku napięcia w pokoju + `evaluate_coalitions`).

**Tech Stack:** Godot 4.6.3, GDScript 2.0, GUT (testy headless), JSON data files w `data/`.

**Uruchomienie testów:**
```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

**Spec referencyjny:** `docs/superpowers/specs/03-diplomacy-system-design.md`

## Uwagi kontekstowe

- 117 testów zdanych na starcie tego planu (Plan 01 + 02 + 03 wykonane)
- `GameState.gd` **nie ma** `class_name` (konflikt z Autoload) — testy używają `preload("res://scripts/engine/GameState.gd").new()`
- `DiplomacyManager.process_*(state: Node)` — duck typing, bo GameState nie ma class_name
- **`.uid` files są wymagane!** Po utworzeniu nowego pliku `.gd` uruchom `godot --headless --path . -e --quit` (lub `--import`) żeby wygenerować sidecar `.gd.uid` — bez tego klasy z `class_name` nie są rozwiązywalne w trybie headless. Dodaj `.uid` do tego samego commita.
- 4 osie teologiczne: A (Mistycyzm↔Dogmatyzm), B (Równouprawnienie↔Hierarchia), C (Ekskluzywizm↔Synkretyzm), D (Doczesność↔Transcendencja)

**Mapowanie pojęć ze speca → wartości osi:**
- Dogmatyzm = A, Mistycyzm = 100 - A
- Hierarchia = B, Równouprawnienie = 100 - B
- Synkretyzm = C, Ekskluzywizm = 100 - C
- Transcendencja = D, Doczesność = 100 - D

Przykład: "Ekskluzywizm >80" oznacza `100 - C > 80`, czyli `C < 20`.

**Konwencja indentacji:** Nowe pliki — 4 spacje (jak `test_war_manager.gd`). Modyfikacje istniejących plików — zachowaj indentację pliku (`TurnManager.gd`, `WarManager.gd` używają tabów w stylu Plan 03; sprawdź indent w pliku przed edycją).

**Konwencja klucza pary religii:** Relacja A↔B jest symetryczna. Klucz pary to alfabetycznie posortowana lista `[id_a, id_b]`. Helper `_pair_key(a, b)` zwraca posortowane id. `RelationState` ma pola `religion_a_id`, `religion_b_id` przechowywane już w posortowanej kolejności.

**Konwencja progów:** Spec używa strict `>` ("Zaufanie >50", "Ekskluzywizm >80"). Implementujemy strict (`value > threshold`), spójnie z testami. Testy używają wartości jednoznacznie po obu stronach progu (np. 55 i 30, nie 50). Identyczna konwencja jak w `WarManager.CB_AXIS_REQUIREMENTS` (Plan 03, z notą inclusive — w Plan 04 trzymamy strict żeby uniknąć ambiguity).

**Religion IDs (z `data/religions_historical.json`):** `islam`, `chr_zachodnie`, `chr_wschodnie`, `judaizm`, `zoroastryzm`, `koptyjski`, `manicheizm`, `religie_arabskie`, `hinduizm`, `buddyzm`, `religie_germanskie`, `religie_slowianski`. **UWAGA: "chrześcijaństwo" nie istnieje jako jedno id — są dwa odłamy `chr_zachodnie` i `chr_wschodnie`.** Testy używają `chr_zachodnie` jako głównego partnera dialogu z islamem.

**Sygnatura `WarManager.declare_war`** (z Plan 03 — ważne dla integracji w Task 9/11):
```gdscript
func declare_war(attacker_id: String, defender_id: String, cb: String, state: Node) -> War
```
Zwraca `War` (lub `null` na fail), nie `bool`. Testy w Plan 04 używają `assert_not_null` zamiast `assert_true`.

**Zakres odłożony (NIE w Plan 04):**
- Sobór Ekumeniczny, Misjonarze Wymienni, modyfikatory osi, twarde blokady doktrynalne (poza Ekskluzywizm dla Sojuszu) — Plan 05
- Uznanie Zwierzchnictwa, Trybut, Unia, Sobór Wasalny, `Religion.resources` — Plan 06
- NPC AI (NPC nie inicjuje akcji dyplomatycznych w PoC — tylko deterministycznie reaguje na koalicje)
- Bonus +5 prestige za długi pokój (>10 tur) — odłożone (wymaga tracking `last_conflict_turn`)
- `[Dołącz do koalicji]` jako propozycja dla NPC — deterministyczne reguły akceptacji
- Inicjatywa NPC w `[Dołącz do potępienia]` po Interdykcie — odłożone do Plan 05+
- **Zerwanie sojuszu i auto-dezaktywacja `alliance_active`** (po wojnie inicjatora, manualne, ekspiracja) — Plan 05
- **`threat_index` bonus -10 per aktywny Sojusz Obronny gracza** (spec Sekcja 2: "Wskaźnik zagrożenia gracza -10 globalnie") — Plan 05
- **`threat_index` bonus +15 per wystawiony Interdykt na potępioną religię** (spec Sekcja 2) — Plan 05 (wymaga flagi `interdict_active` na `RelationState`)
- **CB `[Obrona sojusznika]`** dla sojusznika po ataku na partnera — Plan 05 (integracja z `WarManager`)
- **CB `[Rewanż za zniewagę]`** automatycznie po Interdykcie wobec religii z Ekskluzywizmem >70 — Plan 05
- **Bonus +20% akceptacji koalicji przy Zaufaniu teologicznym >60** (spec Sekcja 4) — Plan 05
- **Sojusz Obronny auto-join do koalicji** (spec: sojusznik kwalifikującego się członka automatycznie dołącza) — Plan 05 (wymaga traversal po relacjach + test)
- **Pełna reguła blokady Sojuszu**: spec wymaga `source.Ekskl>80 AND target.Synk>60`. W Plan 04 upraszczamy do `source.Ekskl>80` (bardziej rygorystyczne) — pełna reguła w Plan 05

---

## Mapa plików

**Nowe pliki:**
- `scripts/engine/RelationState.gd` (Resource) — wskaźniki relacji per-para
- `scripts/engine/RelationState.gd.uid` — sidecar Godota (auto-gen)
- `scripts/engine/Coalition.gd` (Resource) — aktywna koalicja obronna
- `scripts/engine/Coalition.gd.uid` — sidecar Godota (auto-gen)
- `scripts/engine/DiplomacyManager.gd` (RefCounted) — bezstanowy menedżer dyplomacji
- `scripts/engine/DiplomacyManager.gd.uid` — sidecar Godota (auto-gen)
- `tests/engine/test_diplomacy_manager.gd` — pełna pokrywa testowa (~30+ testów)

**Modyfikowane pliki:**
- `scripts/engine/GameState.gd` — dodaj pola `relations: Array[RelationState]` i `active_coalitions: Array[Coalition]`
- `scripts/engine/WarManager.gd` — w `declare_war` podbij `military_tension` w relacji atakujący↔broniący (+20)
- `scripts/engine/TurnManager.gd` — `process_turn` woła `_process_diplomacy(state)` (przed `state.advance_turn()`)
- `tests/engine/test_war_manager.gd` — 1 nowy test: `declare_war` podbija military_tension
- `tests/engine/test_turn_manager.gd` — 2 nowe testy: tick zaniku napięcia, evaluate_coalitions wywoływane

---

## Chunk 1: Modele danych

### Task 1: RelationState + Coalition + GameState — nowe pola

**Files:**
- Create: `scripts/engine/RelationState.gd`
- Create: `scripts/engine/Coalition.gd`
- Modify: `scripts/engine/GameState.gd`
- Test: `tests/engine/test_diplomacy_manager.gd` (nowy plik, pierwsze testy)

- [ ] **Step 1: Utwórz `tests/engine/test_diplomacy_manager.gd` z pierwszymi testami (FAIL)**

```gdscript
extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")
const RelationStateScript := preload("res://scripts/engine/RelationState.gd")
const CoalitionScript := preload("res://scripts/engine/Coalition.gd")

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
```

- [ ] **Step 2: Uruchom testy — powinny FAIL (klasy nie istnieją)**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL: `Identifier "RelationState" not declared` (lub Coalition / fields nie istnieją)

- [ ] **Step 3: Utwórz `scripts/engine/RelationState.gd`**

```gdscript
class_name RelationState
extends Resource

@export var religion_a_id: String = ""
@export var religion_b_id: String = ""
@export var theological_trust: float = 0.0       # 0-100
@export var economic_cooperation: float = 0.0    # 0-100
@export var military_tension: float = 0.0        # 0-100
@export var alliance_active: bool = false        # Sojusz Obronny
```

- [ ] **Step 4: Utwórz `scripts/engine/Coalition.gd`**

```gdscript
class_name Coalition
extends Resource

@export var target_id: String = ""               # id religii-agresora, przeciwko któremu koalicja
@export var members: Array[String] = []          # id religii uczestniczących
@export var turns_active: int = 0                # liczba tur od powstania
@export var turns_without_conflict: int = 0      # licznik do rozpadu (5 tur bez wojny → koniec)
```

- [ ] **Step 5: Wygeneruj `.uid` sidecary**

Run: `godot --headless --path . -e --quit 2>&1 | tail -5`
Verify: `ls scripts/engine/RelationState.gd.uid scripts/engine/Coalition.gd.uid` — oba pliki istnieją.
Expected: brak błędów. Jeśli typed `Array[RelationState]` w `GameState.gd` powoduje parser error w Step 7, ponów `-e --quit` (czasem wymagane drugie przejście, gdy nowy `class_name` musi być rozwiązany).

- [ ] **Step 6: Dodaj pola do `GameState.gd`**

W `scripts/engine/GameState.gd`, po linii `var pending_defeat_events: Array[DefeatEvent] = []` dodaj:

```gdscript
var relations: Array[RelationState] = []
var active_coalitions: Array[Coalition] = []
```

- [ ] **Step 7: Uruchom testy — powinny PASS**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS dla 4 nowych testów; pozostałe 117 nadal passes.

- [ ] **Step 8: Commit**

```bash
git add scripts/engine/RelationState.gd scripts/engine/RelationState.gd.uid \
        scripts/engine/Coalition.gd scripts/engine/Coalition.gd.uid \
        scripts/engine/GameState.gd \
        tests/engine/test_diplomacy_manager.gd tests/engine/test_diplomacy_manager.gd.uid
git commit -m "feat: add RelationState and Coalition resources, GameState diplomacy fields"
```

---

## Chunk 2: DiplomacyManager — fundament

### Task 2: DiplomacyManager + get_or_create_relation

**Files:**
- Create: `scripts/engine/DiplomacyManager.gd`
- Test: `tests/engine/test_diplomacy_manager.gd` (rozbudowa)

- [ ] **Step 1: Dodaj testy do `test_diplomacy_manager.gd` (FAIL)**

Dopisz przed `func test_relation_state_defaults`:

```gdscript
const DiplomacyManagerScript := preload("res://scripts/engine/DiplomacyManager.gd")
```

Dopisz na końcu pliku:

```gdscript
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
```

- [ ] **Step 2: Uruchom testy — powinny FAIL**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: FAIL `Identifier "DiplomacyManager" not declared`.

- [ ] **Step 3: Utwórz `scripts/engine/DiplomacyManager.gd`**

```gdscript
class_name DiplomacyManager
extends RefCounted

# --- Stałe akcji dyplomatycznych ---
const ALLIANCE_PRESTIGE_COST := 20
const INTERDICT_PRESTIGE_COST := 15
const PEACE_COUNCIL_PRESTIGE_COST := 25

# --- Stałe wskaźników i progów ---
const ALLIANCE_TRUST_THRESHOLD := 50.0       # Zaufanie teologiczne >50 OR
const ALLIANCE_ECONOMIC_THRESHOLD := 60.0    # Współpraca ekonomiczna >60
const ALLIANCE_EXCLUSIVITY_BLOCK := 20.0     # C <20 (Ekskluzywizm >80) → blokada sojuszu
const COALITION_THREAT_THRESHOLD := 50.0
const COALITION_MEMBER_TENSION_THRESHOLD := 40.0   # NPC kwalifikuje się i akceptuje członkostwo deterministycznie powyżej tego progu
const COALITION_DISSOLUTION_THREAT := 30.0
const COALITION_DISSOLUTION_PEACE_TURNS := 5
const PEACE_TENSION_DECAY_PER_TURN := 1.0    # zanik military_tension przy pokoju

# --- Stałe efektów akcji ---
const ALLIANCE_TENSION_DROP := 15.0          # Napięcie militarne -15 obu stronom
const INTERDICT_TENSION_INCREASE := 20.0     # Napięcie militarne +20
const INTERDICT_TRUST_DECREASE := 25.0       # Zaufanie teologiczne -25
const PEACE_COUNCIL_WEARINESS_DROP := 30.0   # war_weariness -= 30
const DECLARE_WAR_TENSION_INCREASE := 20.0   # przy declare_war: military_tension +20

# --- Stałe threat index ---
const THREAT_PER_ACTIVE_WAR := 20.0          # każda wojna jako atakujący
const THREAT_PER_PASSIVE_WAR := 5.0          # każda wojna jako broniący (mniejszy wkład, bo defensywa)
const THREAT_MAX := 100.0

func _pair_key(a: String, b: String) -> Array:
    var pair: Array = [a, b]
    pair.sort()
    return pair

func get_or_create_relation(state: Node, a: String, b: String) -> RelationState:
    var key := _pair_key(a, b)
    for rel: RelationState in state.relations:
        if rel.religion_a_id == key[0] and rel.religion_b_id == key[1]:
            return rel
    var new_rel := RelationState.new()
    new_rel.religion_a_id = key[0]
    new_rel.religion_b_id = key[1]
    state.relations.append(new_rel)
    return new_rel
```

- [ ] **Step 4: Wygeneruj `.uid`**

Run: `godot --headless --path . -e --quit 2>&1 | tail -5`
Verify: `ls scripts/engine/DiplomacyManager.gd.uid` — istnieje.

- [ ] **Step 5: Uruchom testy — powinny PASS**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: PASS dla nowych 4 testów.

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/DiplomacyManager.gd scripts/engine/DiplomacyManager.gd.uid \
        tests/engine/test_diplomacy_manager.gd
git commit -m "feat: DiplomacyManager.get_or_create_relation with symmetric pair key"
```

---

### Task 3: compute_threat_index

**Files:**
- Modify: `scripts/engine/DiplomacyManager.gd`
- Test: `tests/engine/test_diplomacy_manager.gd`

**Wzór threat index (computed on-demand z aktywnych wojen i flag):**
- +20 za każdą aktywną wojnę jako atakujący (`attacker_id == religion_id`)
- +5 za każdą aktywną wojnę jako broniący (`defender_id == religion_id`)
- Clamp do [0, 100]

**Uwaga:** Spec mówi też o efekcie wystawionego Interdyktu na threat index potępionej religii (+15). To bonus do threat index **potępionej religii**, naliczany w Task 5 (`proclaim_interdict` ustawia tension≥50 — flagę sprawdzamy w threat). Trzymamy się prostej formuły z wojen w Task 3; bonus z interdyktu testujemy później.

- [ ] **Step 1: Dodaj testy (FAIL)**

```gdscript
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
```

- [ ] **Step 2: Uruchom testy — powinny FAIL**

Expected: FAIL `Invalid call to function 'compute_threat_index'`.

- [ ] **Step 3: Implementacja `compute_threat_index`**

Dopisz w `DiplomacyManager.gd` po `get_or_create_relation`:

```gdscript
func compute_threat_index(state: Node, religion_id: String) -> float:
    var threat := 0.0
    for war: War in state.active_wars:
        if war.state == "ENDED":
            continue
        if war.attacker_id == religion_id:
            threat += THREAT_PER_ACTIVE_WAR
        elif war.defender_id == religion_id:
            threat += THREAT_PER_PASSIVE_WAR
    return clampf(threat, 0.0, THREAT_MAX)
```

- [ ] **Step 4: Uruchom testy — powinny PASS**

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/DiplomacyManager.gd tests/engine/test_diplomacy_manager.gd
git commit -m "feat: DiplomacyManager.compute_threat_index from active wars"
```

---

## Chunk 3: Akcje dyplomatyczne

### Task 4: declare_alliance (Sojusz Obronny)

**Files:**
- Modify: `scripts/engine/DiplomacyManager.gd`
- Test: `tests/engine/test_diplomacy_manager.gd`

**Reguły (ze speca):**
- Wymagania: `theological_trust >50 OR economic_cooperation >60`
- Blokada: Ekskluzywizm >80 (`C <20`) inicjatora — doktryna wyklucza sojusz z heretykami
- Koszt: 20 prestiżu (potrącany z inicjatora — `source`)
- Efekt: `alliance_active = true`, `military_tension -= 15` obu stronom (clamp do [0,100])

- [ ] **Step 1: Dodaj testy (FAIL)**

```gdscript
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
```

- [ ] **Step 2: Uruchom testy — powinny FAIL**

- [ ] **Step 3: Implementacja `declare_alliance`**

Dopisz w `DiplomacyManager.gd`:

```gdscript
func declare_alliance(state: Node, source_id: String, target_id: String) -> bool:
    var source: Religion = state.get_religion(source_id)
    if source == null:
        return false
    if source.prestige < ALLIANCE_PRESTIGE_COST:
        return false
    # Blokada Ekskluzywizm >80 → C < (100 - 80) = 20
    if source.get_axis("C") < ALLIANCE_EXCLUSIVITY_BLOCK:
        return false
    var rel := get_or_create_relation(state, source_id, target_id)
    if rel.theological_trust < ALLIANCE_TRUST_THRESHOLD and rel.economic_cooperation < ALLIANCE_ECONOMIC_THRESHOLD:
        return false
    source.add_prestige(-ALLIANCE_PRESTIGE_COST)
    rel.alliance_active = true
    rel.military_tension = clampf(rel.military_tension - ALLIANCE_TENSION_DROP, 0.0, 100.0)
    return true
```

- [ ] **Step 4: Uruchom testy — powinny PASS**

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/DiplomacyManager.gd tests/engine/test_diplomacy_manager.gd
git commit -m "feat: DiplomacyManager.declare_alliance with thresholds and exclusivity block"
```

---

### Task 5: proclaim_interdict (Interdykt Dyplomatyczny)

**Files:**
- Modify: `scripts/engine/DiplomacyManager.gd`
- Test: `tests/engine/test_diplomacy_manager.gd`

**Reguły (ze speca):**
- Wymagania: brak — dostępny zawsze
- Koszt: 15 prestiżu
- Efekt na wskaźniki: `military_tension += 20`, `theological_trust -= 25` (clamp [0,100])
- Source musi mieć prestige ≥ 15

- [ ] **Step 1: Dodaj testy (FAIL)**

```gdscript
func test_proclaim_interdict_success() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.military_tension = 10.0
    rel.theological_trust = 40.0
    var ok := dm.proclaim_interdict(gs, "islam", "chr_zachodnie")
    assert_true(ok)
    assert_eq(src.prestige, 35)  # 50 - 15
    assert_almost_eq(rel.military_tension, 30.0, 0.001)
    assert_almost_eq(rel.theological_trust, 15.0, 0.001)

func test_proclaim_interdict_clamps_trust_at_zero() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 10.0
    var ok := dm.proclaim_interdict(gs, "islam", "chr_zachodnie")
    assert_true(ok)
    assert_almost_eq(rel.theological_trust, 0.0, 0.001)

func test_proclaim_interdict_clamps_tension_at_100() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.military_tension = 90.0
    var ok := dm.proclaim_interdict(gs, "islam", "chr_zachodnie")
    assert_true(ok)
    assert_almost_eq(rel.military_tension, 100.0, 0.001)

func test_proclaim_interdict_fails_low_prestige() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 10
    var ok := dm.proclaim_interdict(gs, "islam", "chr_zachodnie")
    assert_false(ok)
    assert_eq(src.prestige, 10)
```

- [ ] **Step 2: Uruchom testy — powinny FAIL**

- [ ] **Step 3: Implementacja `proclaim_interdict`**

```gdscript
func proclaim_interdict(state: Node, source_id: String, target_id: String) -> bool:
    var source: Religion = state.get_religion(source_id)
    if source == null:
        return false
    if source.prestige < INTERDICT_PRESTIGE_COST:
        return false
    var rel := get_or_create_relation(state, source_id, target_id)
    source.add_prestige(-INTERDICT_PRESTIGE_COST)
    rel.military_tension = clampf(rel.military_tension + INTERDICT_TENSION_INCREASE, 0.0, 100.0)
    rel.theological_trust = clampf(rel.theological_trust - INTERDICT_TRUST_DECREASE, 0.0, 100.0)
    return true
```

- [ ] **Step 4: Uruchom testy — powinny PASS**

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/DiplomacyManager.gd tests/engine/test_diplomacy_manager.gd
git commit -m "feat: DiplomacyManager.proclaim_interdict with tension/trust effects"
```

---

## Chunk 4: Koalicje obronne

### Task 6: evaluate_coalitions — tworzenie

**Files:**
- Modify: `scripts/engine/DiplomacyManager.gd`
- Test: `tests/engine/test_diplomacy_manager.gd`

**Reguły (ze speca):**
- Iterujemy po wszystkich religiach z aktywnymi wojnami jako atakujący
- Jeśli threat_index agresora >50, sprawdzamy potencjalnych członków:
  - Religia X kwalifikuje się jako członek, jeśli `military_tension(X, agresor) > 40`
  - Sojusznik kwalifikującego się członka (z `alliance_active=true`) automatycznie dołącza (bez sprawdzania własnego napięcia)
- Koalicja powstaje, jeśli liczba potencjalnych członków ≥ 2
- Jeśli koalicja już istnieje dla danego agresora — pomijamy (nie duplikujemy)
- NPC akceptuje automatycznie jeśli napięcie ≥ 40 (PoC bez AI)

**Uwaga implementacyjna:** Coalition.target_id = id agresora; members nie zawiera agresora ani jego ofiar. Algorytm:
1. Zbierz set agresorów (religie z aktywnymi wojnami jako atakujący) i ich ofiar.
2. Dla każdego agresora: jeśli threat>50 AND brak istniejącej koalicji dla niego AND ≥2 kandydatów → utwórz.

**Uwaga o auto-join sojuszników:** Spec Sekcja 4 mówi że Sojusz Obronny z potencjalnym członkiem → automatycznie dołącza bez propozycji. To wymaga traversal po `state.relations` z `alliance_active=true`. **W Plan 04 NIE implementujemy auto-join** — odłożone do Plan 05 (patrz "Zakres odłożony"). W tym Tasku członkowie kwalifikują się TYLKO przez `military_tension`.

- [ ] **Step 1: Dodaj testy (FAIL)**

```gdscript
func _setup_agresor_scenario(gs: Node, agresor: String, ofiary: Array) -> void:
    # 3 aktywne wojny czynią agresora threat_index = 60
    for ofiara: String in ofiary:
        var w := War.new()
        w.attacker_id = agresor
        w.defender_id = ofiara
        w.state = "BATTLING"
        gs.active_wars.append(w)

func test_evaluate_coalitions_creates_coalition() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    _setup_agresor_scenario(gs, "islam", ["chr_zachodnie", "hinduizm", "buddyzm"])
    # 3 potencjalni członkowie z napięciem >40 wobec islamu
    for member: String in ["judaizm", "zoroastryzm", "manicheizm"]:
        var rel := dm.get_or_create_relation(gs, member, "islam")
        rel.military_tension = 50.0
    dm.evaluate_coalitions(gs)
    assert_eq(gs.active_coalitions.size(), 1)
    var c: Coalition = gs.active_coalitions[0]
    assert_eq(c.target_id, "islam")
    assert_eq(c.members.size(), 3)
    assert_true("judaizm" in c.members)
    assert_true("zoroastryzm" in c.members)
    assert_true("manicheizm" in c.members)

func test_evaluate_coalitions_skips_low_threat() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    # tylko 1 wojna → threat=20 (<50)
    _setup_agresor_scenario(gs, "islam", ["chr_zachodnie"])
    var rel := dm.get_or_create_relation(gs, "judaizm", "islam")
    rel.military_tension = 60.0
    var rel2 := dm.get_or_create_relation(gs, "zoroastryzm", "islam")
    rel2.military_tension = 60.0
    dm.evaluate_coalitions(gs)
    assert_eq(gs.active_coalitions.size(), 0)

func test_evaluate_coalitions_skips_too_few_members() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    _setup_agresor_scenario(gs, "islam", ["chr_zachodnie", "hinduizm", "buddyzm"])
    var rel := dm.get_or_create_relation(gs, "judaizm", "islam")
    rel.military_tension = 60.0
    # tylko 1 kandydat
    dm.evaluate_coalitions(gs)
    assert_eq(gs.active_coalitions.size(), 0)

func test_evaluate_coalitions_does_not_duplicate() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    _setup_agresor_scenario(gs, "islam", ["chr_zachodnie", "hinduizm", "buddyzm"])
    for member: String in ["judaizm", "zoroastryzm"]:
        var rel := dm.get_or_create_relation(gs, member, "islam")
        rel.military_tension = 50.0
    dm.evaluate_coalitions(gs)
    dm.evaluate_coalitions(gs)
    assert_eq(gs.active_coalitions.size(), 1)

func test_evaluate_coalitions_excludes_agresor_and_victims() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    _setup_agresor_scenario(gs, "islam", ["chr_zachodnie", "hinduizm", "buddyzm"])
    # Ofiary mają wysokie napięcie z islamu, ale są w wojnie — nie liczymy ich do koalicji obronnej
    for victim: String in ["chr_zachodnie", "hinduizm", "buddyzm"]:
        var rel := dm.get_or_create_relation(gs, victim, "islam")
        rel.military_tension = 80.0
    for member: String in ["judaizm", "zoroastryzm"]:
        var rel := dm.get_or_create_relation(gs, member, "islam")
        rel.military_tension = 50.0
    dm.evaluate_coalitions(gs)
    var c: Coalition = gs.active_coalitions[0]
    assert_eq(c.members.size(), 2)  # tylko 2, ofiary wykluczone
    assert_false("chr_zachodnie" in c.members)
```

- [ ] **Step 2: Uruchom testy — powinny FAIL**

- [ ] **Step 3: Implementacja `evaluate_coalitions`**

```gdscript
func evaluate_coalitions(state: Node) -> void:
    # 1. Zbierz set agresorów i ich ofiar (z aktywnych wojen)
    var aggressors: Dictionary = {}  # agresor_id -> Array[String] (ofiary)
    for war: War in state.active_wars:
        if war.state == "ENDED":
            continue
        if not aggressors.has(war.attacker_id):
            aggressors[war.attacker_id] = []
        aggressors[war.attacker_id].append(war.defender_id)
    # 2. Dla każdego agresora sprawdź warunki koalicji
    for aggressor_id: String in aggressors.keys():
        if compute_threat_index(state, aggressor_id) < COALITION_THREAT_THRESHOLD:
            continue
        if _has_active_coalition(state, aggressor_id):
            continue
        var victims: Array = aggressors[aggressor_id]
        var members: Array[String] = []
        for religion: Religion in state.all_religions():
            if religion.id == aggressor_id or religion.id in victims:
                continue
            var rel := get_or_create_relation(state, religion.id, aggressor_id)
            if rel.military_tension >= COALITION_MEMBER_TENSION_THRESHOLD:
                members.append(religion.id)
        if members.size() >= 2:
            var c := Coalition.new()
            c.target_id = aggressor_id
            c.members = members
            state.active_coalitions.append(c)

func _has_active_coalition(state: Node, target_id: String) -> bool:
    for c: Coalition in state.active_coalitions:
        if c.target_id == target_id:
            return true
    return false
```

- [ ] **Step 4: Uruchom testy — powinny PASS**

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/DiplomacyManager.gd tests/engine/test_diplomacy_manager.gd
git commit -m "feat: DiplomacyManager.evaluate_coalitions creates defensive coalitions"
```

---

### Task 7: dissolve_coalitions — rozpad

**Files:**
- Modify: `scripts/engine/DiplomacyManager.gd`
- Test: `tests/engine/test_diplomacy_manager.gd`

**Reguły (ze speca):**
- Koalicja rozpada się, gdy:
  - `threat_index(target) < 30`, LUB
  - Agresor nie ma ŻADNEJ aktywnej wojny przez 5 tur (zawarł pokoje ze wszystkimi ofiarami)

**Uwaga implementacyjna:** Members koalicji są blokiem obronnym — nie są w wojnie z agresorem. Spec "Po 5 turach bez aktywnego konfliktu" oznacza: 5 tur od momentu gdy agresor przestał walczyć. Inkrementujemy `turns_without_conflict` gdy agresor nie ma żadnej aktywnej (non-ENDED) wojny; zerujemy gdy agresor walczy z kimkolwiek. Po 5 → rozpad. Spec "Agresor zawiera pokój z jednym z członków" jest interpretowany szerzej: pokój z OFIARAMI (które jako jedyne były w wojnie) prowadzi do dezeskalacji.

- [ ] **Step 1: Dodaj testy (FAIL)**

```gdscript
func test_dissolve_coalition_when_threat_drops() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var c := Coalition.new()
    c.target_id = "islam"
    c.members = ["judaizm", "zoroastryzm"]
    gs.active_coalitions.append(c)
    # Brak wojen → threat=0
    dm.dissolve_coalitions(gs)
    assert_eq(gs.active_coalitions.size(), 0)

func test_coalition_persists_when_threat_high() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    _setup_agresor_scenario(gs, "islam", ["chr_zachodnie", "hinduizm", "buddyzm"])
    var c := Coalition.new()
    c.target_id = "islam"
    c.members = ["judaizm", "zoroastryzm"]
    gs.active_coalitions.append(c)
    dm.dissolve_coalitions(gs)
    assert_eq(gs.active_coalitions.size(), 1)
    assert_eq(c.turns_active, 1)

func test_coalition_dissolves_after_5_turns_without_conflict() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    # Symulacja: koalicja istnieje, ale agresor nie ma już aktywnych wojen (zawarł pokoje)
    # Threat sztucznie podtrzymany przez ENDED+BATTLING? Threat=0 spowoduje rozpad od razu.
    # Aby przetestować ścieżkę "5 tur": dodajemy aktywne wojny innych religii (nie islam),
    # potem czyścimy. Najprościej: jedna aktywna wojna gdzie islam jest defender (threat=5),
    # ale threat=5 < 30 → rozpad od razu. Nie da się czysto przetestować "threat>30 AND
    # bez wojen agresora" — to wewnętrznie sprzeczne (threat>30 wymaga wojen agresora).
    # Test sprawdza fallback: gdy threat = ~50 sztucznie utrzymany przez wpisy do active_wars
    # gdzie islam jest defender (5 wojen * 5 = 25, plus 1 jako attacker = 45):
    var w1 := War.new(); w1.attacker_id = "islam"; w1.defender_id = "chr_zachodnie"; w1.state = "BATTLING"
    gs.active_wars.append(w1)
    for i in range(5):
        var wd := War.new(); wd.attacker_id = "buddyzm"; wd.defender_id = "islam"; wd.state = "BATTLING"
        gs.active_wars.append(wd)
    # threat(islam) = 20 (atak) + 5*5 (obrona) = 45 ≥ 30
    var c := Coalition.new()
    c.target_id = "islam"
    c.members = ["judaizm", "zoroastryzm"]
    gs.active_coalitions.append(c)
    # Pierwsza iteracja: islam wciąż atakuje → reset turns_without_conflict
    dm.dissolve_coalitions(gs)
    assert_eq(gs.active_coalitions.size(), 1)
    # Usuwamy ofensywną wojnę islamu (został tylko jako defender)
    gs.active_wars.remove_at(0)
    # threat = 25, > 30? Nie, 25 < 30 → natychmiastowy rozpad. Aby utrzymać >30:
    for i in range(2):
        var wd := War.new(); wd.attacker_id = "manicheizm"; wd.defender_id = "islam"; wd.state = "BATTLING"
        gs.active_wars.append(wd)
    # threat(islam) = 7*5 = 35 ≥ 30, ale islam nie atakuje → turns_without_conflict++
    for i in range(5):
        dm.dissolve_coalitions(gs)
    assert_eq(gs.active_coalitions.size(), 0)
```

**Uwaga o teście:** Test jest celowo "edge case" — w realnej grze threat<30 zazwyczaj przychodzi RAZEM z brakiem wojen ofensywnych. Test izoluje ścieżkę "5 tur bez ofensyw, ale threat utrzymany przez bycie celem". Logic implementacji liczy "wojny gdzie agresor=target_id koalicji", nie wojny w ogóle.

- [ ] **Step 2: Uruchom testy — powinny FAIL**

- [ ] **Step 3: Implementacja `dissolve_coalitions`**

Dopisz w `DiplomacyManager.gd`:

```gdscript
func dissolve_coalitions(state: Node) -> void:
    var still_active: Array[Coalition] = []
    for c: Coalition in state.active_coalitions:
        c.turns_active += 1
        if compute_threat_index(state, c.target_id) < COALITION_DISSOLUTION_THREAT:
            continue
        if _aggressor_has_offensive_war(state, c.target_id):
            c.turns_without_conflict = 0
        else:
            c.turns_without_conflict += 1
        if c.turns_without_conflict >= COALITION_DISSOLUTION_PEACE_TURNS:
            continue
        still_active.append(c)
    state.active_coalitions = still_active

func _aggressor_has_offensive_war(state: Node, aggressor_id: String) -> bool:
    for war: War in state.active_wars:
        if war.state == "ENDED":
            continue
        if war.attacker_id == aggressor_id:
            return true
    return false
```

- [ ] **Step 4: Uruchom testy — powinny PASS**

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/DiplomacyManager.gd tests/engine/test_diplomacy_manager.gd
git commit -m "feat: DiplomacyManager.dissolve_coalitions on low threat or peace"
```

---

## Chunk 5: Sobór Pokojowy + integracja

### Task 8: peace_council (redukcja war_weariness)

**Files:**
- Modify: `scripts/engine/DiplomacyManager.gd`
- Test: `tests/engine/test_diplomacy_manager.gd`

**Reguły:**
- Koszt: 25 prestiżu (potrącany z `religion_id`) — ze speca Sekcja 4
- Efekt: `war_weariness -= 30` (clamp do [0,100]) — **decyzja projektowa Plan 04** (spec nie precyzuje wartości). Wybór 30: ~1/3 progu `WEARINESS_FORCED_PEACE=90` (Plan 03) — Sobór Pokojowy zauważalnie ratuje przed force-peace, ale nie wymazuje weariness. Mniej niż 30 → Sobór nieopłacalny (25 prestige za <30% wpływu); więcej niż 50 → trywialnie unieważnia mechanikę zmęczenia.

- [ ] **Step 1: Dodaj testy (FAIL)**

```gdscript
func test_peace_council_reduces_weariness() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    src.war_weariness = 60.0
    var ok := dm.peace_council(gs, "islam")
    assert_true(ok)
    assert_eq(src.prestige, 25)  # 50 - 25
    assert_almost_eq(src.war_weariness, 30.0, 0.001)

func test_peace_council_clamps_weariness_at_zero() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    src.war_weariness = 10.0
    var ok := dm.peace_council(gs, "islam")
    assert_true(ok)
    assert_almost_eq(src.war_weariness, 0.0, 0.001)

func test_peace_council_fails_low_prestige() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 20
    src.war_weariness = 60.0
    var ok := dm.peace_council(gs, "islam")
    assert_false(ok)
    assert_eq(src.prestige, 20)
    assert_almost_eq(src.war_weariness, 60.0, 0.001)
```

- [ ] **Step 2: Uruchom testy — powinny FAIL**

- [ ] **Step 3: Implementacja `peace_council`**

```gdscript
func peace_council(state: Node, religion_id: String) -> bool:
    var rel: Religion = state.get_religion(religion_id)
    if rel == null:
        return false
    if rel.prestige < PEACE_COUNCIL_PRESTIGE_COST:
        return false
    rel.add_prestige(-PEACE_COUNCIL_PRESTIGE_COST)
    rel.war_weariness = clampf(rel.war_weariness - PEACE_COUNCIL_WEARINESS_DROP, 0.0, 100.0)
    return true
```

- [ ] **Step 4: Uruchom testy — powinny PASS**

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/DiplomacyManager.gd tests/engine/test_diplomacy_manager.gd
git commit -m "feat: DiplomacyManager.peace_council reduces war_weariness for prestige"
```

---

### Task 9: WarManager.declare_war — podbij military_tension

**Files:**
- Modify: `scripts/engine/WarManager.gd`
- Test: `tests/engine/test_war_manager.gd`

**Reguły:** Po pomyślnym `declare_war` (po pobraniu kosztu prestiżu i utworzeniu War) — utwórz/pobierz relację atakujący↔broniący i podbij `military_tension += 20` (clamp).

**Sygnatura `WarManager.declare_war` (z Plan 03):**
```gdscript
func declare_war(attacker_id: String, defender_id: String, cb: String, state: Node) -> War
```
Zwraca `War` (lub `null` na fail).

**Uwaga implementacyjna:** `WarManager` instancjonuje `DiplomacyManager` lokalnie — stateless, bez side-effects. Identyczny pattern jak `TurnManager._process_active_wars → WarManager.new()`.

- [ ] **Step 1: Dodaj test do `test_war_manager.gd` (FAIL)**

Dopisz na końcu pliku:

```gdscript
const DiplomacyManagerScript := preload("res://scripts/engine/DiplomacyManager.gd")

func test_declare_war_increases_military_tension() -> void:
    var gs := _make_state()
    _pin_axes(gs.get_religion("islam"), 50.0, 50.0, 20.0, 50.0)  # C=20 → Eksk 80, Doczesność 50
    gs.get_religion("islam").prestige = 50
    var wm := WarManager.new()
    var war: War = wm.declare_war("islam", "chr_zachodnie", "krucjata", gs)
    assert_not_null(war)
    var dm := DiplomacyManager.new()
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    assert_almost_eq(rel.military_tension, 20.0, 0.001)
```

**Uwaga:** Funkcja `_pin_axes` już istnieje w `test_war_manager.gd` (Plan 03). Argument order `declare_war`: **attacker, defender, cb, state** (NIE state pierwszy).

- [ ] **Step 2: Uruchom test — powinien FAIL**

Expected: tension = 0 (brak integracji).

- [ ] **Step 3: Modyfikuj `WarManager.declare_war`**

Znajdź funkcję `declare_war` w `WarManager.gd`. Po linii dodającej War do `state.active_wars`, ale przed `return war` (NIE `return true` — funkcja zwraca War) dodaj:

```gdscript
    var dm := DiplomacyManager.new()
    var rel := dm.get_or_create_relation(state, attacker_id, defender_id)
    rel.military_tension = clampf(rel.military_tension + DiplomacyManager.DECLARE_WAR_TENSION_INCREASE, 0.0, 100.0)
```

**Uwaga:** Tension bump dzieje się TYLKO przy pomyślnym declare_war (po `state.active_wars.append(war)`, przed `return war`). Wszystkie early `return null` (niespełnienie warunków CB, brak prestiżu) NIE podbijają tension.

- [ ] **Step 4: Uruchom testy — powinny PASS (cały test_war_manager + nowy test)**

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/WarManager.gd tests/engine/test_war_manager.gd
git commit -m "feat: WarManager.declare_war bumps military_tension via DiplomacyManager"
```

---

### Task 10: TurnManager._process_diplomacy

**Files:**
- Modify: `scripts/engine/TurnManager.gd`
- Test: `tests/engine/test_turn_manager.gd`

**Reguły:**
1. Per turn dla każdej relacji: jeśli para nie jest w aktywnej wojnie → `military_tension -= 1` (decay; clamp do 0).
2. Wywołaj `dm.evaluate_coalitions(state)` (tworzenie).
3. Wywołaj `dm.dissolve_coalitions(state)` (rozpad i licznik turns_active).

**Kolejność wywołań w `process_turn`:** `_process_diplomacy(state)` PO `_process_active_wars(state)` (bo evaluate_coalitions używa aktywnych wojen, a wojny mogą zostać force-zakończone w `_process_active_wars`).

- [ ] **Step 1: Dodaj testy do `test_turn_manager.gd` (FAIL)**

Dopisz na końcu pliku:

```gdscript
const DiplomacyManagerScript := preload("res://scripts/engine/DiplomacyManager.gd")

func test_turn_decays_tension_in_peace() -> void:
    var state := _make_state()
    var tm := TurnManager.new()
    var dm := DiplomacyManager.new()
    var rel := dm.get_or_create_relation(state, "islam", "chr_zachodnie")
    rel.military_tension = 20.0
    tm.process_turn(state)
    assert_almost_eq(rel.military_tension, 19.0, 0.001)

func test_turn_does_not_decay_tension_during_war() -> void:
    var state := _make_state()
    var tm := TurnManager.new()
    var dm := DiplomacyManager.new()
    var rel := dm.get_or_create_relation(state, "islam", "chr_zachodnie")
    rel.military_tension = 20.0
    var w := War.new()
    w.attacker_id = "islam"
    w.defender_id = "chr_zachodnie"
    w.state = "BATTLING"
    state.active_wars.append(w)
    tm.process_turn(state)
    assert_almost_eq(rel.military_tension, 20.0, 0.001)

func test_turn_evaluates_coalitions() -> void:
    var state := _make_state()
    var tm := TurnManager.new()
    var dm := DiplomacyManager.new()
    # 3 wojny islamu → threat=60, próg pokonany
    for ofiara: String in ["chr_zachodnie", "hinduizm", "buddyzm"]:
        var w := War.new()
        w.attacker_id = "islam"
        w.defender_id = ofiara
        w.state = "BATTLING"
        state.active_wars.append(w)
    for member: String in ["judaizm", "zoroastryzm"]:
        var rel := dm.get_or_create_relation(state, member, "islam")
        rel.military_tension = 50.0
    tm.process_turn(state)
    assert_eq(state.active_coalitions.size(), 1)
    assert_eq(state.active_coalitions[0].target_id, "islam")
```

**Helper `_make_state`:** Już istnieje w `test_turn_manager.gd` (po follow-up consolidation).

- [ ] **Step 2: Uruchom testy — powinny FAIL**

- [ ] **Step 3: Implementacja `_process_diplomacy` w `TurnManager.gd`**

W `process_turn`, po `_process_active_wars(state)` a przed `state.advance_turn()` dodaj:

```gdscript
    _process_diplomacy(state)
```

Po `_process_active_wars` w pliku, dodaj funkcję:

```gdscript
func _process_diplomacy(state: Node) -> void:
    var dm := DiplomacyManager.new()
    # 1. Tick zaniku napięcia w pokoju
    for rel: RelationState in state.relations:
        if not _pair_in_active_war(state, rel.religion_a_id, rel.religion_b_id):
            rel.military_tension = clampf(rel.military_tension - DiplomacyManager.PEACE_TENSION_DECAY_PER_TURN, 0.0, 100.0)
    # 2. Tworzenie i rozpad koalicji
    dm.evaluate_coalitions(state)
    dm.dissolve_coalitions(state)

func _pair_in_active_war(state: Node, a: String, b: String) -> bool:
    for war: War in state.active_wars:
        if war.state == "ENDED":
            continue
        if (war.attacker_id == a and war.defender_id == b) or (war.attacker_id == b and war.defender_id == a):
            return true
    return false
```

**Indent:** `TurnManager.gd` używa tabów — zachowaj konwencję pliku.

- [ ] **Step 4: Uruchom testy — powinny PASS**

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/TurnManager.gd tests/engine/test_turn_manager.gd
git commit -m "feat: TurnManager._process_diplomacy ticks tension and evaluates coalitions"
```

---

### Task 11: Test integracyjny — pełen scenariusz koalicji

**Files:**
- Modify: `tests/engine/test_diplomacy_manager.gd`

**Cel:** Jeden test integracyjny pokrywający pełen cykl: agresor wypowiada 3 wojny → koalicja zawiązuje się → pokoje → koalicja rozpada.

- [ ] **Step 1: Dodaj test (FAIL możliwy jeśli formuły nie są spójne)**

```gdscript
func test_integration_coalition_lifecycle() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var tm := TurnManager.new()
    var wm := WarManager.new()
    var islam: Religion = gs.get_religion("islam")
    _pin_axes(islam, 50.0, 50.0, 20.0, 40.0)  # CB krucjata dostępny (C<25, D<40)
    islam.prestige = 100

    # 1. Islam wypowiada 3 wojny — agresja → threat=60
    for ofiara: String in ["chr_zachodnie", "hinduizm", "buddyzm"]:
        var war: War = wm.declare_war("islam", ofiara, "krucjata", gs)
        assert_not_null(war, "declare_war failed for %s" % ofiara)

    # 2. Sąsiedzi mają wysokie napięcie (z declare_war: +20, więc po jednym CB tension=20)
    # podkręcamy ręcznie żeby przekroczyć próg 40
    for member: String in ["judaizm", "zoroastryzm"]:
        var rel := dm.get_or_create_relation(gs, member, "islam")
        rel.military_tension = 50.0

    # 3. Turn 1: TurnManager wywołuje evaluate_coalitions
    tm.process_turn(gs)
    assert_eq(gs.active_coalitions.size(), 1, "koalicja powinna powstać")
    var c: Coalition = gs.active_coalitions[0]
    assert_eq(c.target_id, "islam")
    assert_eq(c.members.size(), 2)

    # 4. Wszystkie wojny się kończą (czyścimy active_wars) → threat spada do 0
    gs.active_wars.clear()

    # 5. Turn 2: dissolve_coalitions widzi threat<30 → rozpad
    tm.process_turn(gs)
    assert_eq(gs.active_coalitions.size(), 0, "koalicja powinna się rozpaść")
```

- [ ] **Step 2: Uruchom test — sprawdź czy passes**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`

Jeśli FAIL — sprawdź:
- Czy `_pin_axes` jest dostępny w `test_diplomacy_manager.gd` (helper z Task 4)
- Czy `declare_war` faktycznie podbija tension (Task 9)
- Czy `_process_diplomacy` jest wywoływany (Task 10)

- [ ] **Step 3: Final test suite**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`
Expected: **wszystkie testy passes** (117 baseline + nowe testy z Plan 04 = ~150+).

- [ ] **Step 4: Commit**

```bash
git add tests/engine/test_diplomacy_manager.gd
git commit -m "test: integration test for coalition lifecycle (declare→form→dissolve)"
```

---

## Definition of Done — Plan 04

- [ ] `RelationState.gd` i `Coalition.gd` istnieją jako Resource z polami zdefiniowanymi w Task 1
- [ ] `GameState.relations` i `GameState.active_coalitions` zainicjalizowane jako puste tablice
- [ ] `DiplomacyManager` ma:
  - `_pair_key(a, b)` (sortowany)
  - `get_or_create_relation(state, a, b)` — symetryczny lookup
  - `compute_threat_index(state, religion_id)` — z aktywnych wojen
  - `declare_alliance(state, source, target)` — z progami trust/economic i blokadą Ekskluzywizmu
  - `proclaim_interdict(state, source, target)` — z efektami na tension/trust
  - `evaluate_coalitions(state)` — tworzenie ≥2 członków przy threat>50
  - `dissolve_coalitions(state)` — rozpad przy threat<30 lub 5 tur peace
  - `peace_council(state, religion_id)` — redukcja war_weariness za prestige
- [ ] `WarManager.declare_war` podbija `military_tension` w relacji
- [ ] `TurnManager.process_turn` wywołuje `_process_diplomacy(state)` (po `_process_active_wars`)
- [ ] Wszystkie testy passes (~150+)
- [ ] Brak regresji w istniejących 117 testach
- [ ] Test integracyjny `test_integration_coalition_lifecycle` pokrywa cykl declare→form→dissolve
- [ ] Wszystkie `.uid` sidecary zacommitowane

## Co NIE wchodzi do Plan 04 (odłożone)

- **Sobór Ekumeniczny / Misjonarze Wymienni** — wymagają systemu idei i osi, Plan 05
- **Modyfikatory osi na dyplomację** (Synkretyzm bonus, Hierarchia koszt, Transcendencja siła) — Plan 05
- **Twarde blokady doktrynalne** (poza Ekskluzywizm dla Sojuszu) — Plan 05
- **Uznanie Zwierzchnictwa, Trybut, Unia, Sobór Wasalny** — Plan 06 (wymaga `Religion.resources`)
- **Bonus +5 prestiżu/turę za >10 tur pokoju** — odłożone (wymaga tracking last_conflict_turn)
- **`[Dołącz do potępienia]` po Interdykcie dla innych religii** — Plan 05 (wymaga NPC decision system)
- **AI NPC inicjujący akcje dyplomatyczne** — przyszłość
- **Sprzężenia z Krucjatą/Dżihadem** — Plan 07 (Krucjata/Dżihad meta-mechanika)
- **UI dyplomacji** — Plan dedykowany UI (spec 06)

---

**Następny plan:** `05-mechaniki-dyplomacja-doktryna.md` — Sobór Ekumeniczny, Misjonarze Wymienni, modyfikatory osi i twarde blokady doktrynalne.
