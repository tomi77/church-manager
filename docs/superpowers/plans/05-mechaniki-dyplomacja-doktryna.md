# Plan 05 — Dyplomacja: doktryna i modyfikatory

> **For Claude:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rozszerzyć fundament dyplomacji (Plan 04) o doktrynalne akcje (Sobór Ekumeniczny, Misjonarze Wymienni), modyfikatory osi (Synkretyzm, Hierarchia, Dogmatyzm), twarde blokady doktrynalne oraz automatyczne dołączanie sojuszników do koalicji.

**Architecture:** Wszystkie nowe metody dyplomatyczne dokładają się jako publiczne funkcje do istniejącego `DiplomacyManager` (stateless RefCounted). Nowy Resource `MissionaryMission` modeluje 3-turową misję wymienną, przetwarzaną przez `TurnManager._process_missionaries` (analogicznie do istniejącego `_process_scholar_missions`). Modyfikatory osi to prywatne helpery (`_axis_cost_modifier`, `_axis_trust_gain_modifier`) wywoływane na początku każdej akcji. Spec źródłowy: `docs/superpowers/specs/03-diplomacy-system-design.md` (sekcje 2–4).

**Tech Stack:** Godot 4.6.3, GDScript 2.0, GUT (Godot Unit Testing), headless test runner.

---

## Powiązania ze spec-em

Mapowanie zakresu Plan 05 do sekcji `docs/superpowers/specs/03-diplomacy-system-design.md`:

| Element planu | Sekcja spec | Notatka |
|---|---|---|
| `ecumenical_council` | Sekcja 2 — `[Sobór Ekumeniczny]` | trust>60, Synkretyzm>40, brak wojny, koszt 30, ustępstwo na osi 3–8 pkt, +15 trust, −10 tension |
| `send_missionaries` + `_process_missionaries` | Sekcja 2 — `[Misjonarze Wymienni]` | trust>30, koszt 10, 3 tury, Idea zwrotna, +10 trust, ryzyko Ekskluzywizm>70 |
| Modyfikatory osi (Synkretyzm, Hierarchia, Dogmatyzm) | Sekcja 3 — Modyfikatory | Synkretyzm>60/>75 → trust gain; Hierarchia>60 → koszt; Dogmatyzm>70 → odporność na obce idee |
| Twarde blokady (Ekskluzywizm + Synkretyzm partnera, Napięcie>85) | Sekcja 3 — Twarde blokady | Refactor istniejącej blokady Sojuszu wg spec |
| `auto_join_allies_to_coalitions` | Sekcja 4 — Dyplomacja a skład koalicji | Sojusz Obronny → automatyczne członkostwo bez progu napięcia |

---

## Konwencje (uwaga implementatora)

**Wcięcia:** w tym projekcie pliki używają RÓŻNYCH konwencji:
- `DiplomacyManager.gd`, `TurnManager.gd`, `GameState.gd`, `tests/engine/*.gd` — **4 spacje**
- `DoctrineManager.gd` — **TAB-y**

Przed każdą edycją WERYFIKUJ wcięcie pliku poleceniem:
```bash
grep -E "^[\t ]+" <plik> | head -1 | od -c | head -1
```
Jeśli widzisz `\t` — używaj tabów. Jeśli widzisz `\sp \sp \sp \sp` — używaj 4 spacji. Nie mieszaj.

**Klasy bez `class_name`:** `GameState.gd` NIE ma `class_name` (kolizja z Autoload). Testy korzystają z `preload("res://scripts/engine/GameState.gd").new()`. Nowe pliki Resource (jak `MissionaryMission.gd`) wymagają `class_name`.

**`.uid` sidecary:** Po stworzeniu nowego pliku `.gd` wygeneruj sidecar:
```bash
godot --headless --path . -e --quit 2>&1 | tail -5
```
Plik `<name>.gd.uid` musi być w commicie razem ze skryptem.

**Wzorzec testowy:** Test pliki używają `extends GutTest` i helpera `_make_state()` ładującego dane historyczne (`res://data/religions_historical.json`, `res://data/provinces_historical.json`). Religie dostępne (id z pliku): `islam`, `chr_zachodnie`, `chr_wschodnie`, `judaizm`, `zoroastryzm`, `koptyjski`, `manicheizm`, `religie_arabskie`, `hinduizm`, `buddyzm`, `religie_germanskie`, `religie_slowianski`. Helper `_pin_axes(rel, a, b, c, d)` jest w `test_diplomacy_manager.gd:126`.

**Komenda testowa:**
```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

**Baseline:** Plan 04 zostawia ~179 passing tests. Po Plan 05 oczekuj ~210+ (zależnie od ilości nowych asercji).

---

## Mapa zmian w plikach

**Nowe pliki:**
- `scripts/engine/MissionaryMission.gd` — Resource z `source_id`, `target_id`, `turns_remaining`
- `scripts/engine/MissionaryMission.gd.uid` — sidecar (wygenerowany automatycznie)

**Modyfikacje:**
- `scripts/engine/GameState.gd` — pole `missionary_missions: Array[MissionaryMission]`
- `scripts/engine/DiplomacyManager.gd` — ~20 nowych stałych, 2 metody publiczne (`ecumenical_council`, `send_missionaries`), 3 helpery prywatne (`_axis_cost_modifier`, `_axis_trust_gain_modifier`, `auto_join_allies_to_coalitions`), 1 refactor (`declare_alliance` blokada)
- `scripts/engine/TurnManager.gd` — `_process_missionaries(state)` przed `_process_diplomacy(state)`, plus wywołanie `auto_join_allies_to_coalitions` w `_process_diplomacy`
- `tests/engine/test_diplomacy_manager.gd` — ~25 nowych testów + aktualizacja `test_declare_alliance_blocked_by_exclusivity`

---

## Chunk 1: Fundamenty (Task 1–2)

### Task 1: `MissionaryMission` Resource + `GameState.missionary_missions`

**Files:**
- Create: `scripts/engine/MissionaryMission.gd`
- Modify: `scripts/engine/GameState.gd:12-14`
- Test: `tests/engine/test_diplomacy_manager.gd` (dodaj na koniec)

- [ ] **Step 1: Napisz failing test** (na koniec `tests/engine/test_diplomacy_manager.gd`)

```gdscript
const MissionaryMissionScript := preload("res://scripts/engine/MissionaryMission.gd")

func test_missionary_mission_defaults() -> void:
    var m: MissionaryMission = MissionaryMissionScript.new()
    assert_eq(m.source_id, "")
    assert_eq(m.target_id, "")
    assert_eq(m.turns_remaining, 0)

func test_game_state_has_missionary_missions_empty() -> void:
    var gs := _make_state()
    assert_not_null(gs.missionary_missions)
    assert_eq(gs.missionary_missions.size(), 0)
```

Constant `MissionaryMissionScript` dodaj OBOK pozostałych preloadów na górze pliku (linia ~6).

- [ ] **Step 2: Uruchom test — sprawdź FAIL**

Run:
```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
Expected: błąd `Could not preload resource file "res://scripts/engine/MissionaryMission.gd"` lub podobny.

- [ ] **Step 3: Stwórz `scripts/engine/MissionaryMission.gd`**

```gdscript
class_name MissionaryMission
extends Resource

@export var source_id: String = ""              # religia wysyłająca misjonarza
@export var target_id: String = ""              # religia przyjmująca misjonarza
@export var turns_remaining: int = 0            # tury do powrotu (start: 3)
```

- [ ] **Step 4: Dodaj pole do `GameState.gd`**

W `scripts/engine/GameState.gd` po linii 13 (`var active_coalitions: Array[Coalition] = []`) dodaj:

```gdscript
var missionary_missions: Array[MissionaryMission] = []
```

- [ ] **Step 5: Wygeneruj `.uid` sidecar**

Run:
```bash
godot --headless --path . -e --quit 2>&1 | tail -5
```

Sprawdź, że powstał `scripts/engine/MissionaryMission.gd.uid`:
```bash
ls scripts/engine/MissionaryMission.gd.uid
```

- [ ] **Step 6: Uruchom testy — sprawdź PASS**

Run testów (komenda wyżej). Oczekuj: oba nowe testy passą, brak regresji.

- [ ] **Step 7: Commit**

```bash
git add scripts/engine/MissionaryMission.gd scripts/engine/MissionaryMission.gd.uid scripts/engine/GameState.gd tests/engine/test_diplomacy_manager.gd
git commit -m "feat: add MissionaryMission resource and GameState.missionary_missions field"
```

---

### Task 2: Modyfikatory osi (`_axis_cost_modifier`, `_axis_trust_gain_modifier`) + stałe

**Files:**
- Modify: `scripts/engine/DiplomacyManager.gd:4-29` (dodaj stałe po istniejących)
- Modify: `scripts/engine/DiplomacyManager.gd:152` (dodaj helpery na końcu pliku)
- Test: `tests/engine/test_diplomacy_manager.gd` (dodaj na końcu)

- [ ] **Step 1: Napisz failing testy**

Dodaj na końcu `tests/engine/test_diplomacy_manager.gd`:

```gdscript
# --- Modyfikatory osi ---

func test_axis_cost_modifier_default() -> void:
    var dm := DiplomacyManager.new()
    var gs := _make_state()
    var src: Religion = gs.get_religion("islam")
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    assert_almost_eq(dm._axis_cost_modifier(src), 1.0, 0.001)

func test_axis_cost_modifier_hierarchia_high() -> void:
    var dm := DiplomacyManager.new()
    var gs := _make_state()
    var src: Religion = gs.get_religion("islam")
    _pin_axes(src, 50.0, 70.0, 50.0, 50.0)  # B=70 → Hierarchia (próg 60)
    assert_almost_eq(dm._axis_cost_modifier(src), 0.8, 0.001)

func test_axis_trust_gain_modifier_default() -> void:
    var dm := DiplomacyManager.new()
    var gs := _make_state()
    var src: Religion = gs.get_religion("islam")
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    assert_almost_eq(dm._axis_trust_gain_modifier(src), 1.0, 0.001)

func test_axis_trust_gain_modifier_synkretyzm_mid() -> void:
    var dm := DiplomacyManager.new()
    var gs := _make_state()
    var src: Religion = gs.get_religion("islam")
    _pin_axes(src, 50.0, 50.0, 65.0, 50.0)  # C=65 → Synkretyzm średni (>60)
    assert_almost_eq(dm._axis_trust_gain_modifier(src), 1.20, 0.001)

func test_axis_trust_gain_modifier_synkretyzm_high() -> void:
    var dm := DiplomacyManager.new()
    var gs := _make_state()
    var src: Religion = gs.get_religion("islam")
    _pin_axes(src, 50.0, 50.0, 80.0, 50.0)  # C=80 → Synkretyzm wysoki (>75)
    assert_almost_eq(dm._axis_trust_gain_modifier(src), 1.35, 0.001)
```

- [ ] **Step 2: Uruchom testy — sprawdź FAIL**

Expected: 5 testów FAIL z błędem "method '_axis_cost_modifier' not found" (lub podobnym).

- [ ] **Step 3: Dodaj stałe w `DiplomacyManager.gd`** (po linii 29, przed `_pair_key`)

```gdscript
# --- Stałe modyfikatorów osi (Plan 05) ---
const HIERARCHIA_COST_THRESHOLD := 60.0      # B>60 → tańsze akcje
const HIERARCHIA_COST_MULTIPLIER := 0.8      # -20% kosztu prestiżu
const SYNKRETYZM_TRUST_LOW_THRESHOLD := 60.0     # C>60 → +20% trust gain
const SYNKRETYZM_TRUST_HIGH_THRESHOLD := 75.0    # C>75 → +35% trust gain
const SYNKRETYZM_TRUST_LOW_MULTIPLIER := 1.20
const SYNKRETYZM_TRUST_HIGH_MULTIPLIER := 1.35
```

- [ ] **Step 4: Dodaj helpery na końcu `DiplomacyManager.gd`** (po `peace_council`)

```gdscript
# --- Helpery modyfikatorów osi (Plan 05) ---

func _axis_cost_modifier(religion: Religion) -> float:
    # Hierarchia (oś B) >60 → -20% koszt prestiżu wszystkich akcji
    if religion.get_axis("B") > HIERARCHIA_COST_THRESHOLD:
        return HIERARCHIA_COST_MULTIPLIER
    return 1.0

func _axis_trust_gain_modifier(religion: Religion) -> float:
    # Synkretyzm (oś C) >75 → +35%, >60 → +20% trust gain z akcji teologicznych
    var c := religion.get_axis("C")
    if c > SYNKRETYZM_TRUST_HIGH_THRESHOLD:
        return SYNKRETYZM_TRUST_HIGH_MULTIPLIER
    if c > SYNKRETYZM_TRUST_LOW_THRESHOLD:
        return SYNKRETYZM_TRUST_LOW_MULTIPLIER
    return 1.0
```

- [ ] **Step 5: Uruchom testy — sprawdź PASS**

Expected: 5 nowych testów pass, brak regresji.

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/DiplomacyManager.gd tests/engine/test_diplomacy_manager.gd
git commit -m "feat: DiplomacyManager axis modifiers (Hierarchia cost, Synkretyzm trust gain)"
```

---

## Chunk 2: Akcje doktrynalne (Task 3–4)

### Task 3: `ecumenical_council`

**Files:**
- Modify: `scripts/engine/DiplomacyManager.gd` (dodaj stałe i metodę)
- Test: `tests/engine/test_diplomacy_manager.gd`

**Specyfikacja metody (spec sekcja 2):**
- Wymagania: trust>60, Synkretyzm>40 (C>40), brak aktywnej wojny między parą, napięcie ≤85
- Koszt: 30 prestiżu (modyfikowany przez Hierarchię)
- Mechanika: shift osi `source` o `delta` (clamped do [3,8] dla |delta|, znak zachowany)
- Efekt: trust +15 (z modyfikatorem Synkretyzmu), tension −10

- [ ] **Step 1: Napisz failing testy**

Dodaj na końcu `test_diplomacy_manager.gd`:

```gdscript
# --- Sobór Ekumeniczny ---

func test_ecumenical_council_success() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)  # C=50, Synkretyzm 50 (>40)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 65.0
    rel.military_tension = 20.0
    var initial_a := src.get_axis("A")
    var ok := dm.ecumenical_council(gs, "islam", "chr_zachodnie", "A", 5.0)
    assert_true(ok)
    assert_eq(src.prestige, 20)  # 50 - 30
    assert_almost_eq(src.get_axis("A"), initial_a + 5.0, 0.001)
    assert_almost_eq(rel.theological_trust, 80.0, 0.001)  # 65 + 15
    assert_almost_eq(rel.military_tension, 10.0, 0.001)  # 20 - 10

func test_ecumenical_council_clamps_delta_to_min() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 65.0
    var initial_a := src.get_axis("A")
    var ok := dm.ecumenical_council(gs, "islam", "chr_zachodnie", "A", 1.0)
    assert_true(ok)
    assert_almost_eq(src.get_axis("A"), initial_a + 3.0, 0.001)  # 1.0 → 3.0 (min)

func test_ecumenical_council_clamps_delta_to_max() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 65.0
    var initial_a := src.get_axis("A")
    var ok := dm.ecumenical_council(gs, "islam", "chr_zachodnie", "A", 20.0)
    assert_true(ok)
    assert_almost_eq(src.get_axis("A"), initial_a + 8.0, 0.001)  # 20 → 8 (max)

func test_ecumenical_council_negative_delta_preserves_sign() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 65.0
    var initial_a := src.get_axis("A")
    var ok := dm.ecumenical_council(gs, "islam", "chr_zachodnie", "A", -5.0)
    assert_true(ok)
    assert_almost_eq(src.get_axis("A"), initial_a - 5.0, 0.001)

func test_ecumenical_council_fails_low_trust() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 40.0  # <60
    var ok := dm.ecumenical_council(gs, "islam", "chr_zachodnie", "A", 5.0)
    assert_false(ok)
    assert_eq(src.prestige, 50)

func test_ecumenical_council_fails_low_synkretyzm() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    _pin_axes(src, 50.0, 50.0, 30.0, 50.0)  # C=30 → Synkretyzm <40
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 65.0
    var ok := dm.ecumenical_council(gs, "islam", "chr_zachodnie", "A", 5.0)
    assert_false(ok)

func test_ecumenical_council_fails_high_tension() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 65.0
    rel.military_tension = 90.0  # >85
    var ok := dm.ecumenical_council(gs, "islam", "chr_zachodnie", "A", 5.0)
    assert_false(ok)

func test_ecumenical_council_fails_active_war() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 65.0
    var war := War.new()
    war.attacker_id = "islam"
    war.defender_id = "chr_zachodnie"
    war.state = "BATTLING"
    gs.active_wars.append(war)
    var ok := dm.ecumenical_council(gs, "islam", "chr_zachodnie", "A", 5.0)
    assert_false(ok)

func test_ecumenical_council_fails_insufficient_prestige() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 20  # <30
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 65.0
    var ok := dm.ecumenical_council(gs, "islam", "chr_zachodnie", "A", 5.0)
    assert_false(ok)

func test_ecumenical_council_hierarchia_discount() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 30
    _pin_axes(src, 50.0, 70.0, 50.0, 50.0)  # B=70 → Hierarchia, koszt 30*0.8=24
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 65.0
    var ok := dm.ecumenical_council(gs, "islam", "chr_zachodnie", "A", 5.0)
    assert_true(ok)
    assert_eq(src.prestige, 6)  # 30 - 24

func test_ecumenical_council_synkretyzm_trust_bonus() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    _pin_axes(src, 50.0, 50.0, 80.0, 50.0)  # C=80 → Synkretyzm wysoki (1.35x)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 65.0
    var ok := dm.ecumenical_council(gs, "islam", "chr_zachodnie", "A", 5.0)
    assert_true(ok)
    # trust gain = 15 * 1.35 = 20.25
    assert_almost_eq(rel.theological_trust, 65.0 + 20.25, 0.001)
```

- [ ] **Step 2: Uruchom testy — sprawdź FAIL**

Expected: 11 nowych testów FAIL z błędem "method 'ecumenical_council' not found".

- [ ] **Step 3: Dodaj stałe Soboru w `DiplomacyManager.gd`** (po stałych modyfikatorów z Task 2)

```gdscript
# --- Stałe Soboru Ekumenicznego (Plan 05) ---
const COUNCIL_PRESTIGE_COST := 30
const COUNCIL_TRUST_THRESHOLD := 60.0          # trust >60 (próg progowy)
const COUNCIL_SYNKRETYZM_THRESHOLD := 40.0     # C>40 → Synkretyzm >40
const COUNCIL_MIN_AXIS_DELTA := 3.0            # min |delta| ustępstwa
const COUNCIL_MAX_AXIS_DELTA := 8.0            # max |delta| ustępstwa
const COUNCIL_TRUST_GAIN := 15.0
const COUNCIL_TENSION_DROP := 10.0
const BLOCK_TENSION_FOR_DIALOGUE := 85.0       # napięcie >85 blokuje dialog
```

- [ ] **Step 4: Dodaj metodę `ecumenical_council`** (przed helperami modyfikatorów)

```gdscript
func ecumenical_council(state: Node, source_id: String, target_id: String, axis: String, delta: float) -> bool:
    var source: Religion = state.get_religion(source_id)
    var target: Religion = state.get_religion(target_id)
    if source == null or target == null:
        return false
    # Spec sec.2: brak działania bez wybranego kierunku ustępstwa
    if delta == 0.0:
        return false
    # Blokada: Synkretyzm source ≤40 (spec sec.2 wymaga >40)
    if source.get_axis("C") <= COUNCIL_SYNKRETYZM_THRESHOLD:
        return false
    var rel := get_or_create_relation(state, source_id, target_id)
    # Blokada: trust ≤60 (spec sec.2 wymaga >60)
    if rel.theological_trust <= COUNCIL_TRUST_THRESHOLD:
        return false
    # Blokada: napięcie >85 (spec sec.1)
    if rel.military_tension > BLOCK_TENSION_FOR_DIALOGUE:
        return false
    # Blokada: aktywna wojna między parą
    for war: War in state.active_wars:
        if war.state == "ENDED":
            continue
        if (war.attacker_id == source_id and war.defender_id == target_id) or \
           (war.attacker_id == target_id and war.defender_id == source_id):
            return false
    # Koszt z modyfikatorem Hierarchii
    var cost := int(round(COUNCIL_PRESTIGE_COST * _axis_cost_modifier(source)))
    if source.prestige < cost:
        return false
    # Delta clampowana do [MIN, MAX], znak zachowany
    var sign_val := signf(delta)
    var clamped_abs := clampf(absf(delta), COUNCIL_MIN_AXIS_DELTA, COUNCIL_MAX_AXIS_DELTA)
    var final_delta := clamped_abs * sign_val
    source.add_prestige(-cost)
    source.shift_axis(axis, final_delta)
    var gain := COUNCIL_TRUST_GAIN * _axis_trust_gain_modifier(source)
    rel.theological_trust = clampf(rel.theological_trust + gain, 0.0, 100.0)
    rel.military_tension = clampf(rel.military_tension - COUNCIL_TENSION_DROP, 0.0, 100.0)
    return true
```

- [ ] **Step 5: Uruchom testy — sprawdź PASS**

Expected: 11 nowych testów pass, brak regresji.

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/DiplomacyManager.gd tests/engine/test_diplomacy_manager.gd
git commit -m "feat: DiplomacyManager.ecumenical_council with axis shift, trust and tension effects"
```

---

### Task 4: `send_missionaries`

**Files:**
- Modify: `scripts/engine/DiplomacyManager.gd`
- Test: `tests/engine/test_diplomacy_manager.gd`

**Specyfikacja metody (spec sekcja 2):**
- Wymagania: trust>30, Ekskluzywizm ≤80 source (C≥20), napięcie ≤85
- Koszt: 10 prestiżu (modyfikowany przez Hierarchię)
- Mechanika: tworzy 2 misje (`source→target` i `target→source`) z `turns_remaining=3`
- Efekt natychmiastowy: trust +10 (z modyfikatorem Synkretyzmu)
- Powrót i ryzyko frakcji obsługiwane w Task 5

- [ ] **Step 1: Napisz failing testy**

Dodaj na końcu `test_diplomacy_manager.gd`:

```gdscript
# --- Misjonarze Wymienni (akcja) ---

func test_send_missionaries_success() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 30
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 40.0
    var ok := dm.send_missionaries(gs, "islam", "chr_zachodnie")
    assert_true(ok)
    assert_eq(src.prestige, 20)  # 30 - 10
    assert_eq(gs.missionary_missions.size(), 2)
    assert_almost_eq(rel.theological_trust, 50.0, 0.001)  # 40 + 10

func test_send_missionaries_creates_symmetric_pair() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 30
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 40.0
    dm.send_missionaries(gs, "islam", "chr_zachodnie")
    var sources: Array[String] = []
    var targets: Array[String] = []
    for m: MissionaryMission in gs.missionary_missions:
        sources.append(m.source_id)
        targets.append(m.target_id)
        assert_eq(m.turns_remaining, 3)
    assert_true("islam" in sources)
    assert_true("chr_zachodnie" in sources)
    assert_true("islam" in targets)
    assert_true("chr_zachodnie" in targets)

func test_send_missionaries_fails_low_trust() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 30
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 20.0  # <30
    var ok := dm.send_missionaries(gs, "islam", "chr_zachodnie")
    assert_false(ok)
    assert_eq(src.prestige, 30)
    assert_eq(gs.missionary_missions.size(), 0)

func test_send_missionaries_fails_high_exclusivity() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 30
    _pin_axes(src, 50.0, 50.0, 15.0, 50.0)  # C=15 → Ekskluzywizm 85 (>80)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 40.0
    var ok := dm.send_missionaries(gs, "islam", "chr_zachodnie")
    assert_false(ok)
    assert_eq(gs.missionary_missions.size(), 0)

func test_send_missionaries_fails_high_tension() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 30
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 40.0
    rel.military_tension = 90.0  # >85
    var ok := dm.send_missionaries(gs, "islam", "chr_zachodnie")
    assert_false(ok)

func test_send_missionaries_fails_insufficient_prestige() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 5  # <10
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 40.0
    var ok := dm.send_missionaries(gs, "islam", "chr_zachodnie")
    assert_false(ok)

func test_send_missionaries_hierarchia_discount() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 30
    _pin_axes(src, 50.0, 70.0, 50.0, 50.0)  # B=70 → koszt 10*0.8=8
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 40.0
    var ok := dm.send_missionaries(gs, "islam", "chr_zachodnie")
    assert_true(ok)
    assert_eq(src.prestige, 22)  # 30 - 8
```

- [ ] **Step 2: Uruchom testy — sprawdź FAIL**

Expected: 7 nowych testów FAIL ("method 'send_missionaries' not found").

- [ ] **Step 3: Dodaj stałe Misjonarzy w `DiplomacyManager.gd`**

```gdscript
# --- Stałe Misjonarzy Wymiennych (Plan 05) ---
const MISSIONARIES_PRESTIGE_COST := 10
const MISSIONARIES_TRUST_THRESHOLD := 30.0
const MISSIONARIES_TURNS := 3
const MISSIONARIES_TRUST_GAIN := 10.0
```

(`ALLIANCE_EXCLUSIVITY_BLOCK := 20.0` i `BLOCK_TENSION_FOR_DIALOGUE := 85.0` są już zdefiniowane z poprzednich tasków.)

- [ ] **Step 4: Dodaj metodę `send_missionaries`** (po `ecumenical_council`)

```gdscript
func send_missionaries(state: Node, source_id: String, target_id: String) -> bool:
    var source: Religion = state.get_religion(source_id)
    var target: Religion = state.get_religion(target_id)
    if source == null or target == null:
        return false
    # Blokada Ekskluzywizm >80 source (C<20, spec sec.3)
    if source.get_axis("C") < ALLIANCE_EXCLUSIVITY_BLOCK:
        return false
    var rel := get_or_create_relation(state, source_id, target_id)
    # Blokada napięcia >85 (spec sec.1)
    if rel.military_tension > BLOCK_TENSION_FOR_DIALOGUE:
        return false
    # Blokada trust ≤30 (spec sec.2 wymaga >30)
    if rel.theological_trust <= MISSIONARIES_TRUST_THRESHOLD:
        return false
    var cost := int(round(MISSIONARIES_PRESTIGE_COST * _axis_cost_modifier(source)))
    if source.prestige < cost:
        return false
    source.add_prestige(-cost)
    var m1 := MissionaryMission.new()
    m1.source_id = source_id
    m1.target_id = target_id
    m1.turns_remaining = MISSIONARIES_TURNS
    state.missionary_missions.append(m1)
    var m2 := MissionaryMission.new()
    m2.source_id = target_id
    m2.target_id = source_id
    m2.turns_remaining = MISSIONARIES_TURNS
    state.missionary_missions.append(m2)
    var gain := MISSIONARIES_TRUST_GAIN * _axis_trust_gain_modifier(source)
    rel.theological_trust = clampf(rel.theological_trust + gain, 0.0, 100.0)
    return true
```

- [ ] **Step 5: Uruchom testy — sprawdź PASS**

Expected: 7 nowych testów pass, brak regresji.

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/DiplomacyManager.gd tests/engine/test_diplomacy_manager.gd
git commit -m "feat: DiplomacyManager.send_missionaries creates 3-turn mutual missions"
```

---

## Chunk 3: TurnManager — przetwarzanie misjonarzy (Task 5)

### Task 5: `_process_missionaries` w TurnManager + ryzyko Ekskluzywizmu + Dogmatyzm filter

**Files:**
- Modify: `scripts/engine/TurnManager.gd:9-17` (dodaj wywołanie), `scripts/engine/TurnManager.gd:140` (dodaj funkcję)
- Modify: `scripts/engine/DiplomacyManager.gd` (dodaj stałe Dogmatyzm + Ekskluzywizm faction)
- Test: `tests/engine/test_diplomacy_manager.gd` i/lub `tests/engine/test_turn_manager.gd`

**Specyfikacja (spec sekcja 2 + 3):**
- Dekrementuje `turns_remaining` każdej misji o 1
- Gdy `turns_remaining <= 0`:
  1. Generuj Idea (przez `DoctrineManager.generate_idea(source_id, target_id, state)`)
  2. Jeśli target ma Dogmatyzm >70 (A>70) → `idea.delta *= 0.5` (skuteczność obcych misjonarzy −50%)
  3. Dodaj ideę do `state.pending_ideas` (jeśli nie null)
  4. Jeśli target ma Ekskluzywizm >70 (C<30) → bump tension dominującej frakcji target o 10.0
- Wywołanie z `process_turn` PRZED `_process_diplomacy(state)`

- [ ] **Step 1: Napisz failing testy w `test_diplomacy_manager.gd`**

```gdscript
# --- Misjonarze Wymienni (powrót i efekty) ---

const TurnManagerScript := preload("res://scripts/engine/TurnManager.gd")

func test_missionary_decrement_per_turn() -> void:
    var gs := _make_state()
    var tm := TurnManagerScript.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 30
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    var dst: Religion = gs.get_religion("chr_zachodnie")
    _pin_axes(dst, 50.0, 50.0, 50.0, 50.0)
    var dm := DiplomacyManager.new()
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 40.0
    dm.send_missionaries(gs, "islam", "chr_zachodnie")
    # Po wysłaniu: turns_remaining=3 dla obu misji
    for m: MissionaryMission in gs.missionary_missions:
        assert_eq(m.turns_remaining, 3)
    tm.process_turn(gs)
    # Po 1 turze: turns_remaining=2
    for m: MissionaryMission in gs.missionary_missions:
        assert_eq(m.turns_remaining, 2)

func test_missionary_returns_after_three_turns_spawns_ideas() -> void:
    var gs := _make_state()
    var tm := TurnManagerScript.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 30
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)
    var dst: Religion = gs.get_religion("chr_zachodnie")
    # Wymuszamy różnicę osi > IDEA_MIN_AXIS_DIFF (=10), żeby Idea powstała
    _pin_axes(dst, 80.0, 50.0, 50.0, 50.0)  # A=80 vs source A=50 → diff 30
    var dm := DiplomacyManager.new()
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 40.0
    dm.send_missionaries(gs, "islam", "chr_zachodnie")
    tm.process_turn(gs)
    tm.process_turn(gs)
    tm.process_turn(gs)
    # Misje powinny już zniknąć
    assert_eq(gs.missionary_missions.size(), 0)
    # 2 idee powinny pojawić się w pending_ideas
    assert_eq(gs.pending_ideas.size(), 2)

func test_missionary_dogmatyzm_reduces_idea_delta() -> void:
    var gs := _make_state()
    var tm := TurnManagerScript.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 30
    _pin_axes(src, 50.0, 50.0, 50.0, 50.0)  # A=50
    var dst: Religion = gs.get_religion("chr_zachodnie")
    _pin_axes(dst, 80.0, 50.0, 50.0, 50.0)  # A=80 → Dogmatyzm 80 (>70), diff=30
    var dm := DiplomacyManager.new()
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 40.0
    dm.send_missionaries(gs, "islam", "chr_zachodnie")
    tm.process_turn(gs)
    tm.process_turn(gs)
    tm.process_turn(gs)
    # Idea wracająca DO chr_zachodnie (target=chr_zachodnie) ma 50% delta
    # Idea wracająca DO islam (target=islam, A=50, nie Dogmatyzm) ma 100% delta
    # Idea pochodząca od islam: best_axis=A (diff 30), delta = min(30*0.3, 8) = 8.0
    # Idea pochodząca od chr_zachodnie: też axis A, delta = 8.0
    var idea_to_islam: Idea = null
    var idea_to_chr: Idea = null
    for idea: Idea in gs.pending_ideas:
        if idea.from_religion_id == "chr_zachodnie":
            idea_to_islam = idea  # idea od chr_zachodnie wraca do islam
        else:
            idea_to_chr = idea
    assert_not_null(idea_to_islam)
    assert_not_null(idea_to_chr)
    # delta absolutna dla idei wracającej do islam = 8.0 (pełna), do chr = 4.0 (50%)
    assert_almost_eq(absf(idea_to_islam.delta), 8.0, 0.001)
    assert_almost_eq(absf(idea_to_chr.delta), 4.0, 0.001)

func test_missionary_exclusivity_bumps_faction_tension() -> void:
    var gs := _make_state()
    var tm := TurnManagerScript.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 30
    # Pin osie islam tak żeby JEGO dominująca frakcja nie dryfowała w _update_faction_tensions:
    # islam dominant faction = "ulema" (prefs A+1, B+1), nie diverged przy A=80,B=80.
    _pin_axes(src, 80.0, 80.0, 50.0, 50.0)  # Ekskluzywizm 50 (nie >70), brak dryfu napięcia
    var dst: Religion = gs.get_religion("chr_zachodnie")
    # Pin chr_zachodnie tak by: (a) C=20 → Ekskluzywizm 80 (>70) wywoła bump,
    # (b) papiestwo (dominant, prefs A+1, B+1) NIE diverged przy A=80,B=80 → brak dryfu.
    # Pozostałe frakcje (zakonnicy/reformatorzy) mogą dryfować, ale nie są dominujące.
    _pin_axes(dst, 80.0, 80.0, 20.0, 50.0)
    assert_true(dst.factions.size() > 0, "chr_zachodnie powinno mieć frakcje w danych historycznych")
    var dom_before := dst.dominant_faction()
    var initial_tension := dom_before.tension
    var dm := DiplomacyManager.new()
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 40.0
    dm.send_missionaries(gs, "islam", "chr_zachodnie")
    tm.process_turn(gs)
    tm.process_turn(gs)
    tm.process_turn(gs)
    var dom_after := dst.dominant_faction()
    # Misjonarz z islam→chr (m1) wraca: target=chr_zachodnie, C=20 (Eksklu>70) → bump +10.0
    # Misjonarz z chr→islam (m2) wraca: target=islam, C=50 (Eksklu 50, nie >70) → brak bumpa
    # → tylko chr_zachodnie's dominant faction (papiestwo) dostaje +10.0
    assert_almost_eq(dom_after.tension, initial_tension + 10.0, 0.001)
```

- [ ] **Step 2: Uruchom testy — sprawdź FAIL**

Expected: 4 testy FAIL (assertion fail lub function-not-defined dla `_process_missionaries`).

- [ ] **Step 3: Dodaj stałe Dogmatyzm + Ekskluzywizm faction w `DiplomacyManager.gd`** (po stałych Misjonarzy)

```gdscript
# --- Stałe efektów zwrotnych Misjonarzy (Plan 05) ---
const DOGMATYZM_RESISTANCE_THRESHOLD := 70.0   # A>70 → -50% siła obcej idei
const DOGMATYZM_IDEA_DELTA_MULTIPLIER := 0.5
const EKSKLUZYWIZM_FACTION_THRESHOLD := 30.0   # C<30 → Ekskluzywizm >70 → bump frakcji
const EKSKLUZYWIZM_FACTION_TENSION_BUMP := 10.0
```

- [ ] **Step 4: Dodaj `_process_missionaries` w `TurnManager.gd`**

Najpierw modyfikuj `process_turn` (linia 9–17) — dodaj wywołanie `_process_missionaries(state)` PRZED `_process_diplomacy(state)`:

```gdscript
func process_turn(state: Node) -> void:
    _apply_passive_pressure(state.province_graph)
    _apply_holy_site_prestige(state)
    _update_faction_tensions(state)
    _process_scholar_missions(state)
    _apply_believer_exodus(state)
    _process_active_wars(state)
    _process_missionaries(state)
    _process_diplomacy(state)
    state.advance_turn()
```

Następnie dodaj funkcję na końcu pliku (po `_pair_in_active_war`):

```gdscript
func _process_missionaries(state: Node) -> void:
    var doctm := DoctrineManager.new()
    var still_active: Array[MissionaryMission] = []
    for mission: MissionaryMission in state.missionary_missions:
        mission.turns_remaining -= 1
        if mission.turns_remaining > 0:
            still_active.append(mission)
            continue
        # Spec sec.2 "Misjonarze Wymienni" — przy powrocie misjonarza, target to religia
        # przyjmująca obcą ideę; jej Dogmatyzm zmniejsza skuteczność, jej Ekskluzywizm
        # generuje napięcie u własnej dominującej frakcji ("własna frakcja konserwatywna").
        # send_missionaries tworzy symetryczną parę misji, więc każda religia jest sprawdzana
        # jako target dokładnie raz.
        var target: Religion = state.get_religion(mission.target_id)
        var idea := doctm.generate_idea(mission.source_id, mission.target_id, state)
        if idea != null:
            if target != null and target.get_axis("A") > DiplomacyManager.DOGMATYZM_RESISTANCE_THRESHOLD:
                idea.delta *= DiplomacyManager.DOGMATYZM_IDEA_DELTA_MULTIPLIER
            state.pending_ideas.append(idea)
        if target != null and target.get_axis("C") < DiplomacyManager.EKSKLUZYWIZM_FACTION_THRESHOLD:
            var dom := target.dominant_faction()
            if dom != null:
                dom.add_tension(DiplomacyManager.EKSKLUZYWIZM_FACTION_TENSION_BUMP)
    state.missionary_missions = still_active
```

- [ ] **Step 5: Uruchom testy — sprawdź PASS**

Expected: 4 nowe testy pass, brak regresji w istniejących testach (~210+ total).

UWAGA: test `test_missionary_exclusivity_bumps_faction_tension` zależy od tego, czy religia "chr_zachodnie" w `religions_historical.json` ma frakcje. Jeśli FAIL na `dst.factions.size() > 0` — rozważ użycie innej religii (np. `judaizm`) lub stwórz frakcję syntetycznie w teście:

```gdscript
# Fallback gdyby chr_zachodnie nie miało frakcji w danych historycznych:
if dst.factions.size() == 0:
    var f := Faction.new()
    f.id = "test_faction"
    f.influence = 50.0
    dst.factions.append(f)
```

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/TurnManager.gd scripts/engine/DiplomacyManager.gd tests/engine/test_diplomacy_manager.gd
git commit -m "feat: TurnManager._process_missionaries spawns Ideas, applies Dogmatyzm/Ekskluzywizm effects"
```

---

## Chunk 4: Blokady i auto-join (Task 6–7)

### Task 6: Refactor blokady Sojuszu wg spec (Ekskluzywizm + Synkretyzm partnera)

**Files:**
- Modify: `scripts/engine/DiplomacyManager.gd:58-73` (`declare_alliance`)
- Modify: `tests/engine/test_diplomacy_manager.gd:173-184` (zaktualizować `test_declare_alliance_blocked_by_exclusivity`)
- Test: `tests/engine/test_diplomacy_manager.gd` (dodać nowe testy)

**Spec (sekcja 3, twarde blokady):** Ekskluzywizm >80 blokuje Sojusz **z religią o Synkretyzmie >60** — to węższa blokada niż obecnie (Plan 04 blokuje sojusz w ogóle przy Ekskl>80).

- [ ] **Step 1: Napisz/zaktualizuj testy**

W `tests/engine/test_diplomacy_manager.gd`, ZASTĄP istniejący `test_declare_alliance_blocked_by_exclusivity` (linie 173–184):

```gdscript
func test_declare_alliance_blocked_by_exclusivity_and_partner_synkretyzm() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    _pin_axes(src, 50.0, 50.0, 15.0, 50.0)  # C=15 → Ekskluzywizm 85
    var dst: Religion = gs.get_religion("chr_zachodnie")
    _pin_axes(dst, 50.0, 50.0, 70.0, 50.0)  # C=70 → Synkretyzm 70 (>60 partnera)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 70.0
    var ok := dm.declare_alliance(gs, "islam", "chr_zachodnie")
    assert_false(ok)
    assert_false(rel.alliance_active)
    assert_eq(src.prestige, 50)

func test_declare_alliance_passes_high_exclusivity_low_partner_synkretyzm() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 50
    _pin_axes(src, 50.0, 50.0, 15.0, 50.0)  # C=15 → Ekskluzywizm 85
    var dst: Religion = gs.get_religion("chr_zachodnie")
    _pin_axes(dst, 50.0, 50.0, 40.0, 50.0)  # C=40 → Synkretyzm 40 (≤60, nie blokuje)
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.theological_trust = 70.0
    var ok := dm.declare_alliance(gs, "islam", "chr_zachodnie")
    assert_true(ok)
    assert_true(rel.alliance_active)
```

- [ ] **Step 2: Uruchom testy — sprawdź FAIL**

Expected: nowy test `test_declare_alliance_passes_high_exclusivity_low_partner_synkretyzm` FAIL (obecny kod blokuje Sojusz wyłącznie po Ekskl>80 niezależnie od partnera).

- [ ] **Step 3: Dodaj stałą w `DiplomacyManager.gd`** (obok `ALLIANCE_EXCLUSIVITY_BLOCK`)

```gdscript
const ALLIANCE_PARTNER_SYNKRETYZM_BLOCK := 60.0  # partner Synkretyzm >60 → wzmacnia blokadę Ekskluzywizmu
```

- [ ] **Step 4: Zmień warunek w `declare_alliance`** (linie 64–66)

ZASTĄP:
```gdscript
    # Blokada Ekskluzywizm >80 → C < (100 - 80) = 20
    if source.get_axis("C") < ALLIANCE_EXCLUSIVITY_BLOCK:
        return false
```

NA:
```gdscript
    # Blokada Sojuszu (spec sekcja 3): source Ekskluzywizm >80 (C<20) AND target Synkretyzm >60 (C>60)
    var target: Religion = state.get_religion(target_id)
    if target == null:
        return false
    if source.get_axis("C") < ALLIANCE_EXCLUSIVITY_BLOCK and target.get_axis("C") > ALLIANCE_PARTNER_SYNKRETYZM_BLOCK:
        return false
```

- [ ] **Step 5: Uruchom testy — sprawdź PASS**

Expected: oba nowe testy pass, brak regresji.

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/DiplomacyManager.gd tests/engine/test_diplomacy_manager.gd
git commit -m "refactor: alliance block requires both Eksklu source>80 and Synkre target>60 (spec sec 3)"
```

---

### Task 7: `auto_join_allies_to_coalitions` + integracja w `_process_diplomacy`

**Files:**
- Modify: `scripts/engine/DiplomacyManager.gd` (dodaj metodę po `dissolve_coalitions`)
- Modify: `scripts/engine/TurnManager.gd:125-131` (`_process_diplomacy`)
- Test: `tests/engine/test_diplomacy_manager.gd`

**Specyfikacja (spec sekcja 4):** Po `evaluate_coalitions`: dla każdej koalicji, sojusznicy istniejących członków (alliance_active=true w relacji) są automatycznie dodawani do `c.members`, jeśli sojusznik:
- nie jest sam target koalicji
- nie jest już członkiem
- nie jest ofiarą wojny prowadzonej przez target (defender pozostaje "ofiarą", nie wrogiem agresora — to dla niego koalicja, więc i tak nie ma sensu go dołączać)

Implementacja iteracyjna: dodajemy sojuszników, ale NIE rekursywnie (sojusznicy sojuszników). Plan 05 robi 1 poziom — gdyby było trzeba więcej, zostawić do późniejszej iteracji.

- [ ] **Step 1: Napisz failing testy**

```gdscript
# --- Auto-join sojuszników do koalicji ---

func test_auto_join_adds_ally_of_member() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    # Koalicja przeciw "islam" z member "judaizm"
    var c := Coalition.new()
    c.target_id = "islam"
    c.members = ["judaizm"]
    gs.active_coalitions.append(c)
    # Sojusz między judaizm a zoroastryzm
    var rel := dm.get_or_create_relation(gs, "judaizm", "zoroastryzm")
    rel.alliance_active = true
    dm.auto_join_allies_to_coalitions(gs)
    assert_eq(c.members.size(), 2)
    assert_true("zoroastryzm" in c.members)

func test_auto_join_skips_target() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var c := Coalition.new()
    c.target_id = "islam"
    c.members = ["judaizm"]
    gs.active_coalitions.append(c)
    # Sojusz judaizm z islam (sam target koalicji) — nie powinien być dodany
    var rel := dm.get_or_create_relation(gs, "judaizm", "islam")
    rel.alliance_active = true
    dm.auto_join_allies_to_coalitions(gs)
    assert_eq(c.members.size(), 1)
    assert_false("islam" in c.members)

func test_auto_join_idempotent() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var c := Coalition.new()
    c.target_id = "islam"
    c.members = ["judaizm", "zoroastryzm"]
    gs.active_coalitions.append(c)
    var rel := dm.get_or_create_relation(gs, "judaizm", "zoroastryzm")
    rel.alliance_active = true
    dm.auto_join_allies_to_coalitions(gs)
    # zoroastryzm już jest członkiem — nie duplikujemy
    assert_eq(c.members.size(), 2)

func test_auto_join_skips_non_alliance() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var c := Coalition.new()
    c.target_id = "islam"
    c.members = ["judaizm"]
    gs.active_coalitions.append(c)
    # Relacja istnieje, ale alliance_active=false
    var rel := dm.get_or_create_relation(gs, "judaizm", "zoroastryzm")
    rel.alliance_active = false
    rel.theological_trust = 90.0  # mimo wysokiego trust — bez sojuszu nie dołącza
    dm.auto_join_allies_to_coalitions(gs)
    assert_eq(c.members.size(), 1)

func test_auto_join_runs_in_process_diplomacy() -> void:
    var gs := _make_state()
    var tm := TurnManagerScript.new()
    var dm := DiplomacyManager.new()
    # Setup koalicji z member judaizm, sojusz judaizm-zoroastryzm
    var c := Coalition.new()
    c.target_id = "islam"
    c.members = ["judaizm"]
    gs.active_coalitions.append(c)
    var rel := dm.get_or_create_relation(gs, "judaizm", "zoroastryzm")
    rel.alliance_active = true
    # Dwie aktywne wojny atakowane przez islam → threat = 2 × 20 = 40 (>30 dissolve, <50 dla nowej koalicji,
    # ale `_has_active_coalition` blokuje tworzenie kolejnej — istniejąca pre-built coalition zostaje
    # nietknięta przez evaluate_coalitions, a dissolve nie usuwa jej przy threat>30).
    var war1 := War.new()
    war1.attacker_id = "islam"
    war1.defender_id = "hinduizm"
    war1.state = "BATTLING"
    gs.active_wars.append(war1)
    var war2 := War.new()
    war2.attacker_id = "islam"
    war2.defender_id = "chr_zachodnie"
    war2.state = "BATTLING"
    gs.active_wars.append(war2)
    tm.process_turn(gs)
    # Po turze: koalicja nadal aktywna i zoroastryzm dołączył przez auto-join
    assert_eq(gs.active_coalitions.size(), 1)
    assert_true("zoroastryzm" in gs.active_coalitions[0].members)
```

- [ ] **Step 2: Uruchom testy — sprawdź FAIL**

Expected: 5 testów FAIL ("method 'auto_join_allies_to_coalitions' not found").

- [ ] **Step 3: Dodaj metodę w `DiplomacyManager.gd`** (po `dissolve_coalitions`, przed `_aggressor_has_offensive_war` lub na końcu — wybierz miejsce konwencjonalnie)

```gdscript
func auto_join_allies_to_coalitions(state: Node) -> void:
    for c: Coalition in state.active_coalitions:
        var snapshot: Array[String] = []
        for m: String in c.members:
            snapshot.append(m)
        for member_id: String in snapshot:
            for rel: RelationState in state.relations:
                if not rel.alliance_active:
                    continue
                var ally_id := ""
                if rel.religion_a_id == member_id:
                    ally_id = rel.religion_b_id
                elif rel.religion_b_id == member_id:
                    ally_id = rel.religion_a_id
                if ally_id == "" or ally_id == c.target_id or ally_id in c.members:
                    continue
                c.members.append(ally_id)
```

- [ ] **Step 4: Dodaj wywołanie w `TurnManager._process_diplomacy`** (linie 125–131)

ZASTĄP:
```gdscript
func _process_diplomacy(state: Node) -> void:
    var dm := DiplomacyManager.new()
    for rel: RelationState in state.relations:
        if not _pair_in_active_war(state, rel.religion_a_id, rel.religion_b_id):
            rel.military_tension = clampf(rel.military_tension - DiplomacyManager.PEACE_TENSION_DECAY_PER_TURN, 0.0, 100.0)
    dm.evaluate_coalitions(state)
    dm.dissolve_coalitions(state)
```

NA:
```gdscript
func _process_diplomacy(state: Node) -> void:
    var dm := DiplomacyManager.new()
    for rel: RelationState in state.relations:
        if not _pair_in_active_war(state, rel.religion_a_id, rel.religion_b_id):
            rel.military_tension = clampf(rel.military_tension - DiplomacyManager.PEACE_TENSION_DECAY_PER_TURN, 0.0, 100.0)
    dm.evaluate_coalitions(state)
    dm.auto_join_allies_to_coalitions(state)
    dm.dissolve_coalitions(state)
```

- [ ] **Step 5: Uruchom testy — sprawdź PASS**

Expected: 5 nowych testów pass, brak regresji.

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/DiplomacyManager.gd scripts/engine/TurnManager.gd tests/engine/test_diplomacy_manager.gd
git commit -m "feat: auto-join allies to coalitions in _process_diplomacy"
```

---

## Chunk 5: Integracja i DoD (Task 8)

### Task 8: Integration test — Sobór + Misjonarze + auto-join koalicji

**Files:**
- Test: `tests/engine/test_diplomacy_manager.gd` (na końcu)

- [ ] **Step 1: Napisz integration test**

```gdscript
# --- Integration test Plan 05: cykl doktrynalny + koalicja ---

func test_integration_council_missionaries_coalition_lifecycle() -> void:
    var gs := _make_state()
    var tm := TurnManagerScript.new()
    var dm := DiplomacyManager.new()

    var islam: Religion = gs.get_religion("islam")
    islam.prestige = 200
    _pin_axes(islam, 50.0, 50.0, 50.0, 50.0)
    var chr_zach: Religion = gs.get_religion("chr_zachodnie")
    # A=70 (NIE Dogmatyzm bo nie >70 strict), różnica A=20 zapewnia generację Idei nawet po Sobór
    _pin_axes(chr_zach, 70.0, 50.0, 50.0, 50.0)
    var rel_islam_chr := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel_islam_chr.theological_trust = 65.0
    rel_islam_chr.military_tension = 20.0

    # 1. Sobór Ekumeniczny: islam shift A +5 (po Sobór: A=55, diff od chr=15 — dalej ≥10 dla Idea)
    var sobor_ok := dm.ecumenical_council(gs, "islam", "chr_zachodnie", "A", 5.0)
    assert_true(sobor_ok, "Sobór powinien przejść (trust=65>60, Synkr=50>40, brak wojny)")
    assert_almost_eq(islam.get_axis("A"), 55.0, 0.001)
    assert_almost_eq(rel_islam_chr.theological_trust, 80.0, 0.001)  # 65 + 15

    # 2. Misjonarze Wymienni: islam ↔ chr_zachodnie (trust=80>30, nie Eksklu, napięcie 10 po Sobór)
    var send_ok := dm.send_missionaries(gs, "islam", "chr_zachodnie")
    assert_true(send_ok, "Misjonarze powinni zostać wysłani")
    assert_eq(gs.missionary_missions.size(), 2)
    assert_almost_eq(rel_islam_chr.theological_trust, 90.0, 0.001)  # 80 + 10

    # 3. Koalicja: 3 wars przez islam → threat = 3 × 20 = 60 (≥50)
    for defender: String in ["hinduizm", "buddyzm", "religie_arabskie"]:
        var war := War.new()
        war.attacker_id = "islam"
        war.defender_id = defender
        war.state = "BATTLING"
        gs.active_wars.append(war)

    # 4. Tensions kwalifikujące judaizm i manicheizm jako członków koalicji (≥40 vs islam)
    var rel_islam_jud := dm.get_or_create_relation(gs, "islam", "judaizm")
    rel_islam_jud.military_tension = 50.0
    var rel_islam_man := dm.get_or_create_relation(gs, "islam", "manicheizm")
    rel_islam_man.military_tension = 50.0

    # 5. Auto-join setup: judaizm ↔ zoroastryzm alliance, ALE zoroastryzm BEZ tension≥40 vs islam
    var rel_jud_zoro := dm.get_or_create_relation(gs, "judaizm", "zoroastryzm")
    rel_jud_zoro.alliance_active = true
    var rel_islam_zoro := dm.get_or_create_relation(gs, "islam", "zoroastryzm")
    rel_islam_zoro.military_tension = 10.0  # <40 → NIE kwalifikuje przez evaluate_coalitions

    # 6. process_turn × 3 — misjonarze wracają na turze 3, koalicja formuje się na każdej turze
    tm.process_turn(gs)
    tm.process_turn(gs)
    tm.process_turn(gs)

    # 7a. Misjonarze wrócili
    assert_eq(gs.missionary_missions.size(), 0, "misje powinny się zakończyć po 3 turach")
    # 7b. 2 Idee zwrotne w pending_ideas (diff A=15 ≥ IDEA_MIN_AXIS_DIFF=10)
    assert_eq(gs.pending_ideas.size(), 2, "2 idee powinny powstać z misjonarzy wymiennych")
    # 7c. Koalicja przeciw islam istnieje
    assert_eq(gs.active_coalitions.size(), 1, "koalicja powinna powstać przy threat=60")
    var coalition: Coalition = gs.active_coalitions[0]
    assert_eq(coalition.target_id, "islam")
    # 7d. judaizm i manicheizm dołączyli przez evaluate_coalitions (tension≥40)
    assert_true("judaizm" in coalition.members, "judaizm kwalifikuje się przez napięcie")
    assert_true("manicheizm" in coalition.members, "manicheizm kwalifikuje się przez napięcie")
    # 7e. zoroastryzm dołączył przez auto_join (tension <40, ale sojusz z judaizm)
    assert_true("zoroastryzm" in coalition.members, "zoroastryzm dołączył auto-join przez sojusz z judaizm")
```

- [ ] **Step 2: Uruchom test — sprawdź czy passes**

Run pełny test suite. Jeśli FAIL — przeczytaj komunikat dokładnie i napraw zgodnie z założeniami z poprzednich tasków.

Częste pułapki:
- `chr_zachodnie` ma A=65, B=80 w danych historycznych — `_pin_axes` w teście ustawia na (70,50,50,50), więc to nie problem.
- War_weariness narasta o `WEARINESS_PER_TURN=3.0` per wojna per turę dla obu stron. Po 3 turach w 3 wojnach: islam ma ~27 — poniżej progu `WEARINESS_FORCED_PEACE=90.0`, więc żadna wojna się nie kończy w trakcie testu.
- Próg `COALITION_MEMBER_TENSION_THRESHOLD = 40` — używaj 50.0 dla judaizm/manicheizm, ale zoroastryzm musi mieć <40 (test ustawia 10), żeby auto-join był weryfikowalny.

- [ ] **Step 3: Final test suite — sprawdź wszystko**

Run:
```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: WSZYSTKIE testy passes (~215+). Brak regresji w 179 testach z Plan 04 ani wcześniejszych.

- [ ] **Step 4: Commit**

```bash
git add tests/engine/test_diplomacy_manager.gd
git commit -m "test: integration test for Plan 05 (council, missionaries, coalition auto-join)"
```

---

## Definition of Done — Plan 05

- [ ] `MissionaryMission.gd` istnieje jako Resource z polami `source_id`, `target_id`, `turns_remaining`
- [ ] `GameState.missionary_missions` zainicjalizowane jako pusta `Array[MissionaryMission]`
- [ ] `DiplomacyManager` ma nowe metody:
  - `ecumenical_council(state, source, target, axis, delta) -> bool` z blokadami trust/Synkretyzm/napięcie/wojna oraz wczesnym guardem `delta == 0.0`
  - `send_missionaries(state, source, target) -> bool` z blokadami Ekskluzywizm/trust/napięcie i symetrycznym tworzeniem 2 misji
  - `auto_join_allies_to_coalitions(state) -> void`
  - prywatne helpery `_axis_cost_modifier(religion)`, `_axis_trust_gain_modifier(religion)`
- [ ] `DiplomacyManager` ma stałe Plan 05:
  - Sobór: `COUNCIL_PRESTIGE_COST`, `COUNCIL_TRUST_THRESHOLD`, `COUNCIL_SYNKRETYZM_THRESHOLD`, `COUNCIL_MIN_AXIS_DELTA`, `COUNCIL_MAX_AXIS_DELTA`, `COUNCIL_TRUST_GAIN`, `COUNCIL_TENSION_DROP`
  - Misjonarze: `MISSIONARIES_PRESTIGE_COST`, `MISSIONARIES_TRUST_THRESHOLD`, `MISSIONARIES_TURNS`, `MISSIONARIES_TRUST_GAIN`
  - Modyfikatory: `HIERARCHIA_COST_THRESHOLD`/`_MULTIPLIER`, `SYNKRETYZM_TRUST_LOW_THRESHOLD`/`_HIGH_THRESHOLD`/`_LOW_MULTIPLIER`/`_HIGH_MULTIPLIER`
  - Misje zwrotne: `DOGMATYZM_RESISTANCE_THRESHOLD`, `DOGMATYZM_IDEA_DELTA_MULTIPLIER`, `EKSKLUZYWIZM_FACTION_THRESHOLD`, `EKSKLUZYWIZM_FACTION_TENSION_BUMP`
  - Blokada sojuszu: `ALLIANCE_PARTNER_SYNKRETYZM_BLOCK`
  - Wspólne: `BLOCK_TENSION_FOR_DIALOGUE`
- [ ] `DiplomacyManager.declare_alliance` blokuje Sojusz tylko gdy source Ekskluzywizm>80 ORAZ target Synkretyzm>60 (zgodnie ze spec, węższe niż w Plan 04)
- [ ] `TurnManager.process_turn` wywołuje `_process_missionaries(state)` PRZED `_process_diplomacy(state)`
- [ ] `TurnManager._process_diplomacy` wywołuje `auto_join_allies_to_coalitions` między `evaluate_coalitions` a `dissolve_coalitions`
- [ ] `TurnManager._process_missionaries` dekrementuje misje, spawn Idea z modyfikatorem Dogmatyzmu, bump tension dominującej frakcji przy Ekskluzywizmie target>70
- [ ] Integration test `test_integration_council_missionaries_coalition_lifecycle` w `tests/engine/test_diplomacy_manager.gd` weryfikuje: Sobór (axis shift + trust +15), Misjonarze (3 tury, 2 Idee w `pending_ideas`), koalicja przez evaluate_coalitions (judaizm+manicheizm), auto-join (zoroastryzm przez sojusz)
- [ ] Wszystkie nowe testy passes (~40 nowych testów + integration)
- [ ] Brak regresji w 179 istniejących testach
- [ ] Wszystkie `.uid` sidecary zacommitowane
- [ ] Brak magic numbers w metodach — wszystko jako nazwane stałe (komenty grupujące zachowane)

## Co NIE wchodzi do Plan 05 (odłożone)

- **Uznanie Zwierzchnictwa / Trybut / Unia / Sobór Wasalny** — wymagają `Religion.resources` → **Plan 06**
- **Transcendencja >65 → +15% siła sojuszu militarnego** — brak konsumenta w obecnym kodzie → **Plan 07** (Krucjata/Dżihad)
- **`[Sobór Ludowy]` blokujący Interdykt przy Równouprawnieniu** — wymaga rozbudowanego systemu frakcji → **Plan 06+**
- **`[Dołącz do potępienia]` po Interdykcie** — wymaga NPC decision system → **przyszłość**
- **`[Interdykt Dyplomatyczny]` → automatyczny CB `[Rewanż za zniewagę]` przy Ekskluzywizm>70 potępionej religii** (spec sekcja 3) — wymaga integracji z `WarManager.CB_AXIS_REQUIREMENTS` i logiki spawnowania CB po interdykcie → **Plan 06+** (kiedy będziemy rozbudowywać reaktywne CB)
- **AI NPC inicjujący Sobór/Misjonarzy** — przyszłość
- **`Idea` jako konkretny element doktrynalny** (poza shift osi) — istniejący system idei wystarcza dla Plan 05; rozszerzony catalog ideowy → **przyszłość**
- **`[Sobór Ekumeniczny]` z konkretnym bonusem dla obu stron** (spec mówi "ustępstwo doktrynalne lub trwały bonus") — Plan 05 implementuje tylko ustępstwo (shift osi); bonus typu "trwały efekt" → **Plan 06+**
- **Bonus +5 prestiżu/turę za >10 tur pokoju** — wymaga `last_conflict_turn` → **odłożone**
- **Rekursywne auto-join** (sojusznicy sojuszników) — 1 poziom wystarczy w Plan 05
- **UI dyplomacji (akcje gracza)** — **dedykowany plan UI**

---

**Następny plan:** `06-mechaniki-dyplomacja-wasal.md` — Uznanie Zwierzchnictwa, Trybut, Unia, Sobór Wasalny (wymaga `Religion.resources`), Sobór Ludowy, modyfikatory frakcji.
