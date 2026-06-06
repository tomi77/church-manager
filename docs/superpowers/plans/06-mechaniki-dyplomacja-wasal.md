# Plan 06 — Dyplomacja: Wasalstwo

> **For Claude:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wprowadzić asymetryczną relację patron↔klient (`[Uznanie Zwierzchnictwa]`), przepływ zasobów (Trybut), dwa nowe sobory (`[Sobór Wasalny]` dla patrona z Hierarchią >75, `[Sobór Ludowy]` jako defensywa religii o Równouprawnieniu >70) oraz auto-bunt klienta przy napięciu dominującej frakcji >80.

**Architecture:** Wasalstwo to dwustronna relacja, ale przechowywana asymetrycznie na `Religion.suzerain_id` (klient zna patrona; relacja 1:N wyliczana ad-hoc). Nowy zasób `Religion.resources` (int) wprowadza pierwszy w silniku przepływ niezwiązany z prestiżem — Trybut to przepływ klient → patron w `TurnManager._process_resources`. Wszystkie akcje (`recognize_suzerainty`, `vassal_council`, `people_council`) idą jako publiczne metody do `DiplomacyManager`. Auto-bunt odpala się w `TurnManager._process_vassal_revolts` po przepływie zasobów. Spec źródłowy: `docs/superpowers/specs/07-vassalage-system-design.md`.

**Tech Stack:** Godot 4.6.3, GDScript 2.0, GUT (Godot Unit Testing), headless test runner.

---

## Powiązania ze spec-em

Mapowanie zakresu Plan 06 do sekcji `docs/superpowers/specs/07-vassalage-system-design.md`:

| Element planu | Sekcja spec | Notatka |
|---|---|---|
| `Religion.resources`, `suzerain_id`, `interdict_immunity_until` + `RelationState.vassal_council_cooldown_until` | Sekcja 1 — Model Danych | nowe pola z defaultami `0` / `""` |
| `recognize_suzerainty` | Sekcja 2 — `[Uznanie Zwierzchnictwa]` | klient inicjuje; A<80, trust>40, brak wojny; one-time bonusy patrona |
| `_process_resources` | Sekcja 3 — Mechaniki Per-Turn | passive income +5 wszystkim, trybut +/-3 patron/klient z floor 0 |
| `_process_vassal_revolts` | Sekcja 3 — Auto-bunt | tension dominującej frakcji >80 → zerwij, +30 military_tension, -40 tension |
| `vassal_council` | Sekcja 2 — `[Sobór Wasalny]` | patron B>75, koszt 30, shift osi 3–8 u klienta, +15 tension frakcji, cooldown 5 |
| `people_council` + guard w `proclaim_interdict` | Sekcja 2 — `[Sobór Ludowy]` | aktor B<30, koszt 15, immunity 5 tur; proclaim_interdict guard na target |

---

## Konwencje (uwaga implementatora)

**Wcięcia:** w tym projekcie pliki używają RÓŻNYCH konwencji:
- `Religion.gd`, `RelationState.gd`, `DiplomacyManager.gd`, `TurnManager.gd`, `GameState.gd`, `tests/engine/*.gd` — **4 spacje**
- `DoctrineManager.gd` — **TAB-y** (nieruszany w Plan 06)

Przed każdą edycją WERYFIKUJ wcięcie pliku poleceniem:
```bash
grep -E "^[\t ]+" <plik> | head -1 | od -c | head -1
```
Jeśli widzisz `\t` — używaj tabów. Jeśli widzisz `\sp \sp \sp \sp` — używaj 4 spacji. Nie mieszaj.

**Klasy bez `class_name`:** `GameState.gd` NIE ma `class_name` (kolizja z Autoload). Testy korzystają z `preload("res://scripts/engine/GameState.gd").new()`.

**Brak nowych plików `.gd` w Plan 06:** wszystkie zmiany dotyczą istniejących plików. Nie ma nowych `.uid` sidecarów do wygenerowania.

**Cross-class constants:** `TurnManager` odwołuje się do stałych `DiplomacyManager` przez `DiplomacyManager.CONST_NAME` (jak w Plan 05 dla `DOGMATYZM_*`, `EKSKLUZYWIZM_*`).

**Wzorzec testowy:** Test pliki używają `extends GutTest` i helpera `_make_state()` ładującego dane historyczne (`res://data/religions_historical.json`, `res://data/provinces_historical.json`). Religie dostępne (id z pliku): `islam`, `chr_zachodnie`, `chr_wschodnie`, `judaizm`, `zoroastryzm`, `koptyjski`, `manicheizm`, `religie_arabskie`, `hinduizm`, `buddyzm`, `religie_germanskie`, `religie_slowianski`. Helper `_pin_axes(rel, a, b, c, d)` jest w `test_diplomacy_manager.gd:128`.

**Konwencja umieszczania testów:** wszystkie testy dyplomacji (w tym te dotyczące `TurnManager._process_*` powiązanych z dyplomacją) trafiają do `tests/engine/test_diplomacy_manager.gd` — analogicznie do Plan 05, w którym `_process_missionaries` testowany jest tam, nie w `test_turn_manager.gd`.

**Komenda testowa:**
```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

**Baseline:** Plan 05 zostawia ~221 passing tests. Po Plan 06 oczekuj ~250+ (zależnie od liczby nowych asercji).

---

## Mapa zmian w plikach

**Nowe pliki:** brak.

**Modyfikacje:**
- `scripts/engine/Religion.gd` — 3 nowe `@export`: `resources: int`, `suzerain_id: String`, `interdict_immunity_until: int`
- `scripts/engine/RelationState.gd` — 1 nowe `@export`: `vassal_council_cooldown_until: int`
- `scripts/engine/DiplomacyManager.gd` — ~18 nowych stałych, 3 metody publiczne (`recognize_suzerainty`, `vassal_council`, `people_council`), modyfikacja `proclaim_interdict` (guard immunity)
- `scripts/engine/TurnManager.gd` — `_process_resources(state)` i `_process_vassal_revolts(state)` w `process_turn` po `_process_diplomacy(state)`
- `tests/engine/test_diplomacy_manager.gd` — ~30 nowych testów + integration test
- `tests/engine/test_religion.gd` — 1 test defaultów nowych pól

---

## Chunk 1: Fundamenty danych (Task 1)

### Task 1: Pola wasalstwa (Religion + RelationState)

**Files:**
- Modify: `scripts/engine/Religion.gd:4-15`
- Modify: `scripts/engine/RelationState.gd:4-9`
- Test: `tests/engine/test_religion.gd` (dodaj na koniec)
- Test: `tests/engine/test_diplomacy_manager.gd:17-24` (rozszerz test `test_relation_state_defaults`)

- [ ] **Step 1: Napisz failing testy**

W `tests/engine/test_religion.gd`, dodaj na koniec pliku:

```gdscript
func test_religion_vassal_fields_defaults() -> void:
    var r := Religion.new()
    assert_eq(r.resources, 0)
    assert_eq(r.suzerain_id, "")
    assert_eq(r.interdict_immunity_until, 0)
```

W `tests/engine/test_diplomacy_manager.gd`, znajdź `test_relation_state_defaults` (linia ~17) i dodaj na końcu funkcji:

```gdscript
    assert_eq(rs.vassal_council_cooldown_until, 0)
```

- [ ] **Step 2: Uruchom testy — sprawdź FAIL**

Run:
```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
Expected: oba nowe asserty FAIL (pola jeszcze nie istnieją).

- [ ] **Step 3: Dodaj pola do `Religion.gd`**

W `scripts/engine/Religion.gd`, po linii `@export var parent_religion_id: String = ""` (linia 15) dodaj:

```gdscript
@export var resources: int = 0
@export var suzerain_id: String = ""
@export var interdict_immunity_until: int = 0
```

- [ ] **Step 4: Dodaj pole do `RelationState.gd`**

W `scripts/engine/RelationState.gd`, po linii `@export var alliance_active: bool = false        # Sojusz Obronny` (linia 9) dodaj:

```gdscript
@export var vassal_council_cooldown_until: int = 0    # anty-spam Soboru Wasalnego (per para)
```

- [ ] **Step 5: Uruchom testy — sprawdź PASS**

Expected: nowe testy PASS, brak regresji w ~221 istniejących testach.

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/Religion.gd scripts/engine/RelationState.gd tests/engine/test_religion.gd tests/engine/test_diplomacy_manager.gd
git commit -m "feat: add vassalage fields to Religion and RelationState"
```

---

## Chunk 2: Uznanie Zwierzchnictwa i Trybut (Task 2–3)

### Task 2: Stałe wasalstwa + `recognize_suzerainty`

**Files:**
- Modify: `scripts/engine/DiplomacyManager.gd:60` (dodaj stałe na końcu sekcji stałych Plan 05)
- Modify: `scripts/engine/DiplomacyManager.gd` (dodaj funkcję na końcu pliku po `_axis_trust_gain_modifier`)
- Test: `tests/engine/test_diplomacy_manager.gd` (dodaj na końcu)

- [ ] **Step 1: Napisz failing testy**

Dodaj na końcu `tests/engine/test_diplomacy_manager.gd`:

```gdscript
# --- recognize_suzerainty (Plan 06) ---

func test_recognize_suzerainty_success() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var client: Religion = gs.get_religion("judaizm")
    var patron: Religion = gs.get_religion("chr_zachodnie")
    _pin_axes(client, 50.0, 50.0, 50.0, 50.0)  # A=50 (<80) OK
    patron.prestige = 0
    var rel := dm.get_or_create_relation(gs, "judaizm", "chr_zachodnie")
    rel.theological_trust = 45.0  # >40 OK
    var ok := dm.recognize_suzerainty(gs, "judaizm", "chr_zachodnie")
    assert_true(ok, "akceptacja przy A<80, trust>40, brak wojny")
    assert_eq(client.suzerain_id, "chr_zachodnie")
    assert_eq(patron.prestige, DiplomacyManager.SUZERAINTY_PATRON_PRESTIGE_GAIN)
    assert_almost_eq(rel.economic_cooperation, DiplomacyManager.SUZERAINTY_ECON_GAIN, 0.001)

func test_recognize_suzerainty_blocked_dogmatyzm() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var client: Religion = gs.get_religion("judaizm")
    _pin_axes(client, 85.0, 50.0, 50.0, 50.0)  # A=85 → Dogmatyzm >80 blokuje
    var rel := dm.get_or_create_relation(gs, "judaizm", "chr_zachodnie")
    rel.theological_trust = 60.0
    var ok := dm.recognize_suzerainty(gs, "judaizm", "chr_zachodnie")
    assert_false(ok, "A>=80 blokuje uznanie")
    assert_eq(client.suzerain_id, "")

func test_recognize_suzerainty_blocked_dogmatyzm_threshold() -> void:
    # Próg jest <80 (ostry); A=80 dokładnie nadal blokuje (warunek: A >= 80)
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var client: Religion = gs.get_religion("judaizm")
    _pin_axes(client, 80.0, 50.0, 50.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "judaizm", "chr_zachodnie")
    rel.theological_trust = 60.0
    assert_false(dm.recognize_suzerainty(gs, "judaizm", "chr_zachodnie"), "A==80 blokuje")

func test_recognize_suzerainty_blocked_low_trust() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var client: Religion = gs.get_religion("judaizm")
    _pin_axes(client, 50.0, 50.0, 50.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "judaizm", "chr_zachodnie")
    rel.theological_trust = 40.0  # próg ostry: trust > 40
    var ok := dm.recognize_suzerainty(gs, "judaizm", "chr_zachodnie")
    assert_false(ok, "trust<=40 blokuje")

func test_recognize_suzerainty_blocked_active_war() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var client: Religion = gs.get_religion("judaizm")
    _pin_axes(client, 50.0, 50.0, 50.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "judaizm", "chr_zachodnie")
    rel.theological_trust = 70.0
    var war := War.new()
    war.attacker_id = "chr_zachodnie"
    war.defender_id = "judaizm"
    war.state = "BATTLING"
    gs.active_wars.append(war)
    assert_false(dm.recognize_suzerainty(gs, "judaizm", "chr_zachodnie"))

func test_recognize_suzerainty_blocked_existing_patron() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var client: Religion = gs.get_religion("judaizm")
    client.suzerain_id = "islam"  # już ma patrona
    _pin_axes(client, 50.0, 50.0, 50.0, 50.0)
    var rel := dm.get_or_create_relation(gs, "judaizm", "chr_zachodnie")
    rel.theological_trust = 70.0
    assert_false(dm.recognize_suzerainty(gs, "judaizm", "chr_zachodnie"), "klient z istniejącym patronem nie może uznać kolejnego")

func test_recognize_suzerainty_returns_false_on_null_religions() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    assert_false(dm.recognize_suzerainty(gs, "nonexistent", "chr_zachodnie"))
    assert_false(dm.recognize_suzerainty(gs, "judaizm", "nonexistent"))
```

- [ ] **Step 2: Uruchom testy — sprawdź FAIL**

Expected: błędy odwołań do `DiplomacyManager.SUZERAINTY_*` i `dm.recognize_suzerainty`.

- [ ] **Step 3: Dodaj stałe w `DiplomacyManager.gd`**

W `scripts/engine/DiplomacyManager.gd`, po linii z `EKSKLUZYWIZM_FACTION_TENSION_BUMP` (linia 61) dodaj:

```gdscript

# --- Stałe Wasalstwa (Plan 06) ---
const SUZERAINTY_DOGMATYZM_BLOCK := 80.0       # A>=80 blokuje uznanie zwierzchnictwa (spec 03 sek.3)
const SUZERAINTY_TRUST_THRESHOLD := 40.0       # trust>40 wymagane
const SUZERAINTY_PATRON_PRESTIGE_GAIN := 20    # one-time bonus prestiżu patrona
const SUZERAINTY_ECON_GAIN := 20.0             # one-time bonus economic_cooperation

# --- Stałe ekonomii (Plan 06) ---
const PASSIVE_INCOME_PER_TURN := 5             # bazowy dochód zasobów wszystkich religii
const TRIBUTE_PER_TURN := 3                    # przepływ klient → patron

# --- Stałe Buntu (Plan 06) ---
const REVOLT_FACTION_TENSION_THRESHOLD := 80.0 # tension dominującej frakcji klienta > 80 → bunt
const REVOLT_TENSION_INCREASE := 30.0          # military_tension klient↔patron po buncie
const REVOLT_TENSION_RELIEF := 40.0            # spadek tension dominującej frakcji klienta po buncie

# --- Stałe Soboru Wasalnego (Plan 06) ---
const VASSAL_COUNCIL_HIERARCHIA_THRESHOLD := 75.0  # B>75 patrona
const VASSAL_COUNCIL_PRESTIGE_COST := 30
const VASSAL_COUNCIL_MIN_AXIS_DELTA := 3.0
const VASSAL_COUNCIL_MAX_AXIS_DELTA := 8.0
const VASSAL_COUNCIL_CLIENT_TENSION_BUMP := 15.0   # bump tension dominującej frakcji klienta
const VASSAL_COUNCIL_COOLDOWN_TURNS := 5

# --- Stałe Soboru Ludowego (Plan 06) ---
const PEOPLE_COUNCIL_ROWNOUPRAWNIENIE_THRESHOLD := 30.0  # B<30 (Równouprawnienie >70)
const PEOPLE_COUNCIL_PRESTIGE_COST := 15
const PEOPLE_COUNCIL_IMMUNITY_TURNS := 5
```

- [ ] **Step 4: Dodaj funkcję `recognize_suzerainty`**

Na końcu pliku `scripts/engine/DiplomacyManager.gd` (po `_axis_trust_gain_modifier`, ostatnia linia ~297) dodaj:

```gdscript

# --- Akcje wasalstwa (Plan 06) ---

func recognize_suzerainty(state: Node, client_id: String, patron_id: String) -> bool:
    var client: Religion = state.get_religion(client_id)
    var patron: Religion = state.get_religion(patron_id)
    if client == null or patron == null:
        return false
    # Klient nie może mieć już patrona (spec 07 sek.2)
    if client.suzerain_id != "":
        return false
    # Blokada: Dogmatyzm >=80 (spec 03 sek.3 + spec 07 sek.2)
    if client.get_axis("A") >= SUZERAINTY_DOGMATYZM_BLOCK:
        return false
    var rel := get_or_create_relation(state, client_id, patron_id)
    # Blokada: trust <=40 (spec 07 sek.2; próg ostry)
    if rel.theological_trust <= SUZERAINTY_TRUST_THRESHOLD:
        return false
    # Blokada: aktywna wojna między stronami
    for war: War in state.active_wars:
        if war.state == "ENDED":
            continue
        if (war.attacker_id == client_id and war.defender_id == patron_id) or \
           (war.attacker_id == patron_id and war.defender_id == client_id):
            return false
    client.suzerain_id = patron_id
    patron.add_prestige(SUZERAINTY_PATRON_PRESTIGE_GAIN)
    rel.economic_cooperation = clampf(rel.economic_cooperation + SUZERAINTY_ECON_GAIN, 0.0, 100.0)
    return true
```

- [ ] **Step 5: Uruchom testy — sprawdź PASS**

Expected: 7 nowych testów PASS, brak regresji.

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/DiplomacyManager.gd tests/engine/test_diplomacy_manager.gd
git commit -m "feat: add recognize_suzerainty action and vassalage constants"
```

---

### Task 3: `_process_resources` (passive income + trybut)

**Files:**
- Modify: `scripts/engine/TurnManager.gd:17` (dodaj wywołanie w `process_turn`)
- Modify: `scripts/engine/TurnManager.gd` (dodaj funkcję na końcu pliku)
- Test: `tests/engine/test_diplomacy_manager.gd` (dodaj na końcu)

- [ ] **Step 1: Napisz failing testy**

Dodaj na końcu `tests/engine/test_diplomacy_manager.gd`:

```gdscript
# --- _process_resources (Plan 06) ---

func test_process_resources_passive_income_only() -> void:
    var gs := _make_state()
    var tm := TurnManagerScript.new()
    var islam: Religion = gs.get_religion("islam")
    var chr_z: Religion = gs.get_religion("chr_zachodnie")
    islam.resources = 0
    chr_z.resources = 0
    tm._process_resources(gs)
    assert_eq(islam.resources, DiplomacyManager.PASSIVE_INCOME_PER_TURN, "islam: passive income +5")
    assert_eq(chr_z.resources, DiplomacyManager.PASSIVE_INCOME_PER_TURN, "chr_zachodnie: passive income +5")

func test_process_resources_tribute_flows_client_to_patron() -> void:
    var gs := _make_state()
    var tm := TurnManagerScript.new()
    var client: Religion = gs.get_religion("judaizm")
    var patron: Religion = gs.get_religion("chr_zachodnie")
    client.suzerain_id = "chr_zachodnie"
    client.resources = 10
    patron.resources = 0
    tm._process_resources(gs)
    # klient: +5 passive, -3 trybut = +2 netto → 12
    assert_eq(client.resources, 12, "klient: passive +5 minus trybut 3 = +2 netto")
    # patron: +5 passive, +3 trybut = 8
    assert_eq(patron.resources, 8, "patron: passive +5 plus trybut 3")

func test_process_resources_tribute_floor_zero() -> void:
    var gs := _make_state()
    var tm := TurnManagerScript.new()
    var client: Religion = gs.get_religion("judaizm")
    var patron: Religion = gs.get_religion("chr_zachodnie")
    client.suzerain_id = "chr_zachodnie"
    # Klient ma 1 resource ZA passive income — po +5 ma 6, trybut nie zubaża <0
    # Sprawdźmy też najgorszy przypadek: klient z 0 zasobami przed turą
    client.resources = 0
    patron.resources = 0
    tm._process_resources(gs)
    # klient: 0 + 5 passive = 5, potem -min(3,5) = 2 → patron dostaje 3
    assert_eq(client.resources, 2)
    assert_eq(patron.resources, 8)  # 0 + 5 passive + 3 trybut

func test_process_resources_no_patron_no_tribute() -> void:
    var gs := _make_state()
    var tm := TurnManagerScript.new()
    var orphan: Religion = gs.get_religion("judaizm")
    orphan.suzerain_id = ""  # bez patrona
    orphan.resources = 0
    tm._process_resources(gs)
    assert_eq(orphan.resources, DiplomacyManager.PASSIVE_INCOME_PER_TURN, "religia bez patrona: tylko passive income")

func test_process_resources_dangling_patron_skipped() -> void:
    var gs := _make_state()
    var tm := TurnManagerScript.new()
    var client: Religion = gs.get_religion("judaizm")
    client.suzerain_id = "nonexistent_religion"
    client.resources = 10
    tm._process_resources(gs)
    # patron==null → trybut się nie wykonuje, tylko passive
    assert_eq(client.resources, 15, "dangling patron: klient dostaje tylko passive, brak utraty trybutu")

func test_process_resources_does_not_leak_into_unrelated_state() -> void:
    # Sanity regression: passive income nie wpływa na prestiż, war_weariness, axes innych religii.
    # Strzeże przed pułapką polegającą na przypadkowej modyfikacji pól używanych w innych testach.
    var gs := _make_state()
    var tm := TurnManagerScript.new()
    var probe: Religion = gs.get_religion("buddyzm")  # religia nieuczestnicząca w żadnym scenariuszu
    probe.prestige = 50
    probe.war_weariness = 12.5
    var a_before := probe.get_axis("A")
    for _i in range(5):
        tm._process_resources(gs)
    assert_eq(probe.prestige, 50, "prestiż nietknięty przez _process_resources")
    assert_almost_eq(probe.war_weariness, 12.5, 0.001)
    assert_almost_eq(probe.get_axis("A"), a_before, 0.001)
    assert_eq(probe.resources, 5 * DiplomacyManager.PASSIVE_INCOME_PER_TURN, "tylko resources naliczane")
```

- [ ] **Step 2: Uruchom testy — sprawdź FAIL**

Expected: błąd `Invalid call. Nonexistent function '_process_resources'`.

- [ ] **Step 3: Wpięcie do `process_turn`**

W `scripts/engine/TurnManager.gd` zmień blok `process_turn` (linie 9–18) dodając wywołanie po `_process_diplomacy`:

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
    _process_resources(state)
    state.advance_turn()
```

- [ ] **Step 4: Dodaj funkcję `_process_resources` na końcu pliku**

W `scripts/engine/TurnManager.gd`, na końcu pliku (po `_process_missionaries`) dodaj:

```gdscript

func _process_resources(state: Node) -> void:
    # Najpierw passive income wszystkim, potem trybut klient → patron.
    # Spec 07 sek.3: ta kolejność gwarantuje że klient zaczyna turę z +PASSIVE-TRIBUTE netto,
    # nie wpada w nędzę nawet jeśli zaczyna z 0 zasobami.
    for religion: Religion in state.all_religions():
        religion.resources += DiplomacyManager.PASSIVE_INCOME_PER_TURN
    for client: Religion in state.all_religions():
        if client.suzerain_id == "":
            continue
        var patron: Religion = state.get_religion(client.suzerain_id)
        if patron == null:
            continue
        var amount: int = mini(DiplomacyManager.TRIBUTE_PER_TURN, client.resources)
        client.resources -= amount
        patron.resources += amount
```

- [ ] **Step 5: Uruchom testy — sprawdź PASS**

Expected: 5 nowych testów PASS, brak regresji w istniejących testach (passive income +5 do religii w innych testach nie powinien ich łamać — istniejące testy nie używają `resources`).

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/TurnManager.gd tests/engine/test_diplomacy_manager.gd
git commit -m "feat: passive income and tribute flow in TurnManager._process_resources"
```

---

## Chunk 3: Auto-bunt klienta (Task 4)

### Task 4: `_process_vassal_revolts`

**Files:**
- Modify: `scripts/engine/TurnManager.gd` (dodaj wywołanie w `process_turn` po `_process_resources`)
- Modify: `scripts/engine/TurnManager.gd` (dodaj funkcję na końcu pliku)
- Test: `tests/engine/test_diplomacy_manager.gd` (dodaj na końcu)

- [ ] **Step 1: Napisz failing testy**

Dodaj na końcu `tests/engine/test_diplomacy_manager.gd`:

```gdscript
# --- _process_vassal_revolts (Plan 06) ---

func _make_client_with_faction_tension(gs: Node, client_id: String, patron_id: String, tension: float) -> void:
    var client: Religion = gs.get_religion(client_id)
    client.suzerain_id = patron_id
    # Zapewnij dominującą frakcję z określonym tension
    if client.factions.is_empty():
        var f := Faction.new()
        f.id = "test_dom"
        f.influence = 100.0
        f.tension = tension
        client.factions.append(f)
    else:
        var dom := client.dominant_faction()
        dom.tension = tension

func test_vassal_revolt_triggers_above_threshold() -> void:
    var gs := _make_state()
    var tm := TurnManagerScript.new()
    var dm := DiplomacyManager.new()
    _make_client_with_faction_tension(gs, "judaizm", "chr_zachodnie", 85.0)  # >80
    var rel := dm.get_or_create_relation(gs, "judaizm", "chr_zachodnie")
    rel.military_tension = 10.0
    tm._process_vassal_revolts(gs)
    var client: Religion = gs.get_religion("judaizm")
    assert_eq(client.suzerain_id, "", "klient się wyzwala")
    assert_almost_eq(rel.military_tension, 10.0 + DiplomacyManager.REVOLT_TENSION_INCREASE, 0.001, "military_tension += 30")
    assert_almost_eq(client.dominant_faction().tension, 85.0 - DiplomacyManager.REVOLT_TENSION_RELIEF, 0.001, "ulga po buncie -40")

func test_vassal_revolt_threshold_boundary() -> void:
    # Próg ostry: tension > 80; dokładnie 80.0 NIE triggeruje
    var gs := _make_state()
    var tm := TurnManagerScript.new()
    _make_client_with_faction_tension(gs, "judaizm", "chr_zachodnie", 80.0)
    tm._process_vassal_revolts(gs)
    var client: Religion = gs.get_religion("judaizm")
    assert_eq(client.suzerain_id, "chr_zachodnie", "tension==80 nie triggeruje buntu")

func test_vassal_revolt_no_op_below_threshold() -> void:
    var gs := _make_state()
    var tm := TurnManagerScript.new()
    _make_client_with_faction_tension(gs, "judaizm", "chr_zachodnie", 50.0)
    tm._process_vassal_revolts(gs)
    var client: Religion = gs.get_religion("judaizm")
    assert_eq(client.suzerain_id, "chr_zachodnie", "klient bez buntu pod progiem")

func test_vassal_revolt_skips_religions_without_patron() -> void:
    var gs := _make_state()
    var tm := TurnManagerScript.new()
    # Religia bez patrona, ale z wysokim tension dominującej frakcji — NIE powinno wywoływać akcji
    var orphan: Religion = gs.get_religion("judaizm")
    if orphan.factions.is_empty():
        var f := Faction.new()
        f.id = "test_dom"
        f.influence = 100.0
        f.tension = 95.0
        orphan.factions.append(f)
    tm._process_vassal_revolts(gs)
    assert_eq(orphan.suzerain_id, "")  # bez zmian

func test_vassal_revolt_skips_client_without_factions() -> void:
    var gs := _make_state()
    var tm := TurnManagerScript.new()
    var client: Religion = gs.get_religion("judaizm")
    client.factions.clear()  # brak frakcji
    client.suzerain_id = "chr_zachodnie"
    tm._process_vassal_revolts(gs)
    # klient bez frakcji → dominant_faction() == null → no-op
    assert_eq(client.suzerain_id, "chr_zachodnie", "klient bez frakcji nie buntuje się")
```

- [ ] **Step 2: Uruchom testy — sprawdź FAIL**

Expected: błąd `Invalid call. Nonexistent function '_process_vassal_revolts'`.

- [ ] **Step 3: Wpięcie do `process_turn`**

W `scripts/engine/TurnManager.gd` zmień blok `process_turn` dodając wywołanie po `_process_resources`:

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
    _process_resources(state)
    _process_vassal_revolts(state)
    state.advance_turn()
```

- [ ] **Step 4: Dodaj funkcję `_process_vassal_revolts`**

Na końcu pliku `scripts/engine/TurnManager.gd` (po `_process_resources`) dodaj:

```gdscript

func _process_vassal_revolts(state: Node) -> void:
    # Spec 07 sek.3: gdy dominująca frakcja klienta ma tension > 80, klient zrywa.
    # Bunt skutkuje: utratą patrona, wzrostem napięcia militarnego klient↔patron,
    # ulgą frakcji (rozładowanie energii społecznej po wyzwoleniu).
    var dm := DiplomacyManager.new()
    for client: Religion in state.all_religions():
        if client.suzerain_id == "":
            continue
        var dom: Faction = client.dominant_faction()
        if dom == null:
            continue
        if dom.tension <= DiplomacyManager.REVOLT_FACTION_TENSION_THRESHOLD:
            continue
        var patron_id := client.suzerain_id
        client.suzerain_id = ""
        var rel := dm.get_or_create_relation(state, client.id, patron_id)
        rel.military_tension = clampf(rel.military_tension + DiplomacyManager.REVOLT_TENSION_INCREASE, 0.0, 100.0)
        dom.tension = maxf(0.0, dom.tension - DiplomacyManager.REVOLT_TENSION_RELIEF)
```

- [ ] **Step 5: Uruchom testy — sprawdź PASS**

Expected: 5 nowych testów PASS, brak regresji.

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/TurnManager.gd tests/engine/test_diplomacy_manager.gd
git commit -m "feat: auto-revolt of vassal client when dominant faction tension > 80"
```

---

## Chunk 4: Sobory wasalskie i ludowe (Task 5–6)

### Task 5: `vassal_council` (z cooldownem)

**Files:**
- Modify: `scripts/engine/DiplomacyManager.gd` (dodaj funkcję po `recognize_suzerainty`)
- Test: `tests/engine/test_diplomacy_manager.gd` (dodaj na końcu)

- [ ] **Step 1: Napisz failing testy**

Dodaj na końcu `tests/engine/test_diplomacy_manager.gd`:

```gdscript
# --- vassal_council (Plan 06) ---

func _setup_vassal_council(gs: Node, patron_id: String, client_id: String) -> RelationState:
    var patron: Religion = gs.get_religion(patron_id)
    var client: Religion = gs.get_religion(client_id)
    _pin_axes(patron, 50.0, 80.0, 50.0, 50.0)  # B=80 → Hierarchia >75
    patron.prestige = 100
    client.suzerain_id = patron_id
    # Zapewnij dominującą frakcję z czystym tension=0
    if client.factions.is_empty():
        var f := Faction.new()
        f.id = "test_dom"
        f.influence = 100.0
        f.tension = 0.0
        client.factions.append(f)
    else:
        client.dominant_faction().tension = 0.0
    var dm := DiplomacyManager.new()
    return dm.get_or_create_relation(gs, patron_id, client_id)

func test_vassal_council_success() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    _setup_vassal_council(gs, "chr_zachodnie", "judaizm")
    var client: Religion = gs.get_religion("judaizm")
    var patron: Religion = gs.get_religion("chr_zachodnie")
    var client_d_before := client.get_axis("D")
    var ok := dm.vassal_council(gs, "chr_zachodnie", "judaizm", "D", 5.0)
    assert_true(ok)
    assert_almost_eq(client.get_axis("D"), client_d_before + 5.0, 0.001, "klient shift +5 na osi D")
    assert_eq(patron.prestige, 100 - DiplomacyManager.VASSAL_COUNCIL_PRESTIGE_COST)
    assert_almost_eq(client.dominant_faction().tension, DiplomacyManager.VASSAL_COUNCIL_CLIENT_TENSION_BUMP, 0.001)

func test_vassal_council_blocked_low_hierarchia() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    _setup_vassal_council(gs, "chr_zachodnie", "judaizm")
    var patron: Religion = gs.get_religion("chr_zachodnie")
    _pin_axes(patron, 50.0, 75.0, 50.0, 50.0)  # B=75 dokładnie — próg ostry: B>75
    assert_false(dm.vassal_council(gs, "chr_zachodnie", "judaizm", "D", 5.0), "B==75 nie wystarczy")

func test_vassal_council_blocked_low_prestige() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    _setup_vassal_council(gs, "chr_zachodnie", "judaizm")
    var patron: Religion = gs.get_religion("chr_zachodnie")
    patron.prestige = DiplomacyManager.VASSAL_COUNCIL_PRESTIGE_COST - 1
    assert_false(dm.vassal_council(gs, "chr_zachodnie", "judaizm", "D", 5.0))

func test_vassal_council_blocked_not_suzerain() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    _setup_vassal_council(gs, "chr_zachodnie", "judaizm")
    var client: Religion = gs.get_religion("judaizm")
    client.suzerain_id = "islam"  # patron to ktoś inny
    assert_false(dm.vassal_council(gs, "chr_zachodnie", "judaizm", "D", 5.0))

func test_vassal_council_blocked_no_relation_no_suzerain() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    _setup_vassal_council(gs, "chr_zachodnie", "judaizm")
    var client: Religion = gs.get_religion("judaizm")
    client.suzerain_id = ""  # klient bez patrona
    assert_false(dm.vassal_council(gs, "chr_zachodnie", "judaizm", "D", 5.0))

func test_vassal_council_cooldown_blocks_second_call() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    _setup_vassal_council(gs, "chr_zachodnie", "judaizm")
    assert_true(dm.vassal_council(gs, "chr_zachodnie", "judaizm", "D", 5.0))
    assert_false(dm.vassal_council(gs, "chr_zachodnie", "judaizm", "D", 5.0), "cooldown blokuje drugi raz")

func test_vassal_council_cooldown_expires() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    _setup_vassal_council(gs, "chr_zachodnie", "judaizm")
    var patron: Religion = gs.get_religion("chr_zachodnie")
    patron.prestige = 200  # dość na 2 użycia
    assert_true(dm.vassal_council(gs, "chr_zachodnie", "judaizm", "D", 5.0))
    # Przewińmy turę poza cooldown (5 tur)
    for i in range(DiplomacyManager.VASSAL_COUNCIL_COOLDOWN_TURNS + 1):
        gs.advance_turn()
    assert_true(dm.vassal_council(gs, "chr_zachodnie", "judaizm", "D", 5.0), "cooldown wygasł, akcja dostępna")

func test_vassal_council_cooldown_boundary_exact_turn() -> void:
    # Guard: current_turn <= cooldown_until → blokada. Sprawdza zachowanie DOKŁADNIE na granicy.
    # Po pierwszym wywołaniu na turze T: cooldown_until = T + 5.
    # Turn T+5: guard T+5 <= T+5 → true → blokada (oczekiwane).
    # Turn T+6: guard T+6 <= T+5 → false → przejdzie (oczekiwane).
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    _setup_vassal_council(gs, "chr_zachodnie", "judaizm")
    var patron: Religion = gs.get_religion("chr_zachodnie")
    patron.prestige = 200
    var t_start := gs.current_turn
    assert_true(dm.vassal_council(gs, "chr_zachodnie", "judaizm", "D", 5.0))
    # przewinięcie do T+5 (cooldown_until)
    while gs.current_turn < t_start + DiplomacyManager.VASSAL_COUNCIL_COOLDOWN_TURNS:
        gs.advance_turn()
    assert_eq(gs.current_turn, t_start + DiplomacyManager.VASSAL_COUNCIL_COOLDOWN_TURNS)
    assert_false(dm.vassal_council(gs, "chr_zachodnie", "judaizm", "D", 5.0), "dokładnie na cooldown_until: nadal zablokowane")
    # przewinięcie do T+6 — pierwszy dostępny tick
    gs.advance_turn()
    assert_true(dm.vassal_council(gs, "chr_zachodnie", "judaizm", "D", 5.0), "T+6 (cooldown+1): odblokowane")

func test_vassal_council_delta_clamped() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    _setup_vassal_council(gs, "chr_zachodnie", "judaizm")
    var client: Religion = gs.get_religion("judaizm")
    _pin_axes(client, 50.0, 50.0, 50.0, 50.0)
    var ok := dm.vassal_council(gs, "chr_zachodnie", "judaizm", "D", 20.0)  # przekracza MAX=8
    assert_true(ok)
    assert_almost_eq(client.get_axis("D"), 50.0 + DiplomacyManager.VASSAL_COUNCIL_MAX_AXIS_DELTA, 0.001, "delta clampnięta do MAX=8")

func test_vassal_council_negative_delta_clamped() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    _setup_vassal_council(gs, "chr_zachodnie", "judaizm")
    var client: Religion = gs.get_religion("judaizm")
    _pin_axes(client, 50.0, 50.0, 50.0, 50.0)
    var ok := dm.vassal_council(gs, "chr_zachodnie", "judaizm", "D", -20.0)
    assert_true(ok)
    assert_almost_eq(client.get_axis("D"), 50.0 - DiplomacyManager.VASSAL_COUNCIL_MAX_AXIS_DELTA, 0.001, "delta -20 clampnięta do -8")

func test_vassal_council_delta_zero_returns_false() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    _setup_vassal_council(gs, "chr_zachodnie", "judaizm")
    assert_false(dm.vassal_council(gs, "chr_zachodnie", "judaizm", "D", 0.0), "delta=0 → no-op false")

func test_vassal_council_below_min_delta_clamped_up() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    _setup_vassal_council(gs, "chr_zachodnie", "judaizm")
    var client: Religion = gs.get_religion("judaizm")
    _pin_axes(client, 50.0, 50.0, 50.0, 50.0)
    var ok := dm.vassal_council(gs, "chr_zachodnie", "judaizm", "D", 1.0)  # poniżej MIN=3
    assert_true(ok)
    assert_almost_eq(client.get_axis("D"), 50.0 + DiplomacyManager.VASSAL_COUNCIL_MIN_AXIS_DELTA, 0.001, "delta 1 clampnięta do MIN=3 z zachowanym znakiem")
```

- [ ] **Step 2: Uruchom testy — sprawdź FAIL**

Expected: błąd `Invalid call. Nonexistent function 'vassal_council'`.

- [ ] **Step 3: Dodaj funkcję `vassal_council` w `DiplomacyManager.gd`**

W `scripts/engine/DiplomacyManager.gd`, po `recognize_suzerainty` dodaj:

```gdscript

func vassal_council(state: Node, patron_id: String, client_id: String, axis: String, delta: float) -> bool:
    var patron: Religion = state.get_religion(patron_id)
    var client: Religion = state.get_religion(client_id)
    if patron == null or client == null:
        return false
    # Spec 07 sek.2: bez kierunku ustępstwa akcja nic nie robi
    if is_zero_approx(delta):
        return false
    # Klient musi być wasalem TEGO patrona
    if client.suzerain_id != patron_id:
        return false
    # Blokada: Hierarchia patrona <=75 (spec 03 sek.3: B>75)
    if patron.get_axis("B") <= VASSAL_COUNCIL_HIERARCHIA_THRESHOLD:
        return false
    var rel := get_or_create_relation(state, patron_id, client_id)
    # Blokada: cooldown
    if state.current_turn <= rel.vassal_council_cooldown_until:
        return false
    # Blokada: koszt prestiżu
    if patron.prestige < VASSAL_COUNCIL_PRESTIGE_COST:
        return false
    # Delta clampowana z zachowaniem znaku (jak w ecumenical_council)
    var sign_val := signf(delta)
    var clamped_abs := clampf(absf(delta), VASSAL_COUNCIL_MIN_AXIS_DELTA, VASSAL_COUNCIL_MAX_AXIS_DELTA)
    var final_delta := clamped_abs * sign_val
    patron.add_prestige(-VASSAL_COUNCIL_PRESTIGE_COST)
    client.shift_axis(axis, final_delta)
    var dom := client.dominant_faction()
    if dom != null:
        dom.add_tension(VASSAL_COUNCIL_CLIENT_TENSION_BUMP)
    rel.vassal_council_cooldown_until = state.current_turn + VASSAL_COUNCIL_COOLDOWN_TURNS
    return true
```

- [ ] **Step 4: Uruchom testy — sprawdź PASS**

Expected: 11 nowych testów PASS, brak regresji.

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/DiplomacyManager.gd tests/engine/test_diplomacy_manager.gd
git commit -m "feat: vassal_council with cooldown, prestige cost, and faction tension bump"
```

---

### Task 6: `people_council` + guard w `proclaim_interdict`

**Files:**
- Modify: `scripts/engine/DiplomacyManager.gd` (dodaj funkcję po `vassal_council`; rozszerz `proclaim_interdict` o guard immunity)
- Test: `tests/engine/test_diplomacy_manager.gd` (dodaj na końcu)

- [ ] **Step 1: Napisz failing testy**

Dodaj na końcu `tests/engine/test_diplomacy_manager.gd`:

```gdscript
# --- people_council (Plan 06) ---

func test_people_council_success() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("judaizm")
    _pin_axes(src, 50.0, 20.0, 50.0, 50.0)  # B=20 → Równouprawnienie >70
    src.prestige = 50
    var ok := dm.people_council(gs, "judaizm")
    assert_true(ok)
    assert_eq(src.prestige, 50 - DiplomacyManager.PEOPLE_COUNCIL_PRESTIGE_COST)
    assert_eq(src.interdict_immunity_until, gs.current_turn + DiplomacyManager.PEOPLE_COUNCIL_IMMUNITY_TURNS)

func test_people_council_blocked_high_hierarchia() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("judaizm")
    _pin_axes(src, 50.0, 30.0, 50.0, 50.0)  # B=30 dokładnie — próg ostry: B<30
    src.prestige = 50
    assert_false(dm.people_council(gs, "judaizm"), "B==30 nie kwalifikuje")

func test_people_council_blocked_low_prestige() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("judaizm")
    _pin_axes(src, 50.0, 20.0, 50.0, 50.0)
    src.prestige = DiplomacyManager.PEOPLE_COUNCIL_PRESTIGE_COST - 1
    assert_false(dm.people_council(gs, "judaizm"))

func test_people_council_null_religion() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    assert_false(dm.people_council(gs, "nonexistent"))

# --- proclaim_interdict guard (Plan 06) ---

func test_proclaim_interdict_blocked_by_immunity() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 100
    var target: Religion = gs.get_religion("judaizm")
    target.interdict_immunity_until = gs.current_turn + 3  # 3 tury immunity w przyszłość
    assert_false(dm.proclaim_interdict(gs, "islam", "judaizm"), "immunity blokuje Interdykt")
    assert_eq(src.prestige, 100, "prestiż nietknięty przy zablokowanej akcji")

func test_proclaim_interdict_passes_when_immunity_expired() -> void:
    # Granica wygaśnięcia: guard używa `>` (immunity_until > current_turn).
    # Gdy current_turn DOGONI immunity_until (jest mu równy), guard zwraca false → akcja przechodzi.
    # To zdefiniowana semantyka "ostatniej tury immunity" — immunity działa do tury T-1 włącznie,
    # przestaje działać dokładnie w turze T (== immunity_until).
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 100
    var target: Religion = gs.get_religion("judaizm")
    target.interdict_immunity_until = gs.current_turn  # immunity równe current_turn → już nie blokuje
    assert_true(dm.proclaim_interdict(gs, "islam", "judaizm"), "immunity == current_turn już nie blokuje")
    assert_eq(src.prestige, 100 - DiplomacyManager.INTERDICT_PRESTIGE_COST)

func test_proclaim_interdict_baseline_no_immunity() -> void:
    # Sanity: bez immunity Interdykt powinien przechodzić jak wcześniej
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 100
    assert_true(dm.proclaim_interdict(gs, "islam", "judaizm"))
```

- [ ] **Step 2: Uruchom testy — sprawdź FAIL**

Expected: błąd `Invalid call. Nonexistent function 'people_council'`, oraz failing `test_proclaim_interdict_blocked_by_immunity` (guard jeszcze nie wstawiony).

- [ ] **Step 3: Dodaj funkcję `people_council` w `DiplomacyManager.gd`**

W `scripts/engine/DiplomacyManager.gd`, po `vassal_council` dodaj:

```gdscript

func people_council(state: Node, source_id: String) -> bool:
    var source: Religion = state.get_religion(source_id)
    if source == null:
        return false
    # Spec 07 sek.2: B<30 (Równouprawnienie >70); próg ostry
    if source.get_axis("B") >= PEOPLE_COUNCIL_ROWNOUPRAWNIENIE_THRESHOLD:
        return false
    if source.prestige < PEOPLE_COUNCIL_PRESTIGE_COST:
        return false
    source.add_prestige(-PEOPLE_COUNCIL_PRESTIGE_COST)
    source.interdict_immunity_until = state.current_turn + PEOPLE_COUNCIL_IMMUNITY_TURNS
    return true
```

- [ ] **Step 4: Dodaj guard do `proclaim_interdict`**

W `scripts/engine/DiplomacyManager.gd`, w funkcji `proclaim_interdict` (zaczyna się ~linia 110), zaraz po sprawdzeniu `source.prestige < INTERDICT_PRESTIGE_COST` dodaj guard:

```gdscript
func proclaim_interdict(state: Node, source_id: String, target_id: String) -> bool:
    var source: Religion = state.get_religion(source_id)
    if source == null:
        return false
    if source.prestige < INTERDICT_PRESTIGE_COST:
        return false
    # Guard immunity (Plan 06): target ze świeżym Soborem Ludowym jest niewzruszalny
    var target: Religion = state.get_religion(target_id)
    if target != null and target.interdict_immunity_until > state.current_turn:
        return false
    var rel := get_or_create_relation(state, source_id, target_id)
    source.add_prestige(-INTERDICT_PRESTIGE_COST)
    rel.military_tension = clampf(rel.military_tension + INTERDICT_TENSION_INCREASE, 0.0, 100.0)
    rel.theological_trust = clampf(rel.theological_trust - INTERDICT_TRUST_DECREASE, 0.0, 100.0)
    return true
```

Uwaga: zachowaj istniejący kod (przepływ prestiżu, mutacje rel). Tylko dodaj `target` lookup i guard po sprawdzeniu prestiżu. Nie nadpisuj całej funkcji bez weryfikacji.

- [ ] **Step 5: Uruchom testy — sprawdź PASS**

Expected: 7 nowych testów PASS, brak regresji (sanity test `test_proclaim_interdict_baseline_no_immunity` weryfikuje że baseline nie został złamany).

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/DiplomacyManager.gd tests/engine/test_diplomacy_manager.gd
git commit -m "feat: people_council and interdict immunity guard"
```

---

## Chunk 5: Integration test (Task 7)

### Task 7: End-to-end test cyklu wasalskiego

**Files:**
- Test: `tests/engine/test_diplomacy_manager.gd` (dodaj na końcu)

- [ ] **Step 1: Napisz integration test**

Dodaj na końcu `tests/engine/test_diplomacy_manager.gd`:

```gdscript
# --- Integration test (Plan 06) ---

func test_integration_vassalage_lifecycle() -> void:
    # Cykl: uznanie zwierzchnictwa → trybut (5 tur) → vassal_council × 4 z cooldownem → auto-bunt.
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var tm := TurnManagerScript.new()

    var client: Religion = gs.get_religion("judaizm")
    var patron: Religion = gs.get_religion("chr_zachodnie")
    _pin_axes(client, 50.0, 50.0, 50.0, 50.0)
    _pin_axes(patron, 50.0, 80.0, 50.0, 50.0)  # B=80 → uprawniony do Soboru Wasalnego
    patron.prestige = 200
    client.resources = 0

    # Zapewnij dominującą frakcję u klienta (tension=0).
    # Wyzeruj axis_preferences — w przeciwnym razie _update_faction_tensions w process_turn
    # dodaje +2 tension per diverged axis per turę i scenariusz przestaje być deterministyczny
    # (5 tur cooldownu × 4 sobory = 20+ tur naliczania, zaszumiałoby próg buntu).
    # Workaround sprzęga test z mechaniką, ale to świadoma decyzja: testujemy cykl wasalstwa,
    # nie napięcie frakcji z dryfu doktrynalnego (to pokrywa test_faction.gd).
    if client.factions.is_empty():
        var f := Faction.new()
        f.id = "test_dom"
        f.influence = 100.0
        f.tension = 0.0
        f.axis_preferences = []
        client.factions.append(f)
    else:
        var dom_init := client.dominant_faction()
        dom_init.tension = 0.0
        dom_init.axis_preferences = []

    # 1. Trust > 40 wymagany dla uznania
    var rel := dm.get_or_create_relation(gs, "judaizm", "chr_zachodnie")
    rel.theological_trust = 60.0

    # 2. Uznanie Zwierzchnictwa
    assert_true(dm.recognize_suzerainty(gs, "judaizm", "chr_zachodnie"), "krok 1: uznanie")
    assert_eq(client.suzerain_id, "chr_zachodnie")
    assert_eq(patron.prestige, 200 + DiplomacyManager.SUZERAINTY_PATRON_PRESTIGE_GAIN, "patron +20 prestiżu")

    # 3. Sobór Wasalny × 4 (każdy +15 tension dominującej frakcji = 60 łącznie; nadal < 80, brak buntu na tym etapie)
    #    Cooldown 5 tur — między każdym wywołaniem przewijamy 6 tur procesem TurnManager.
    var dom: Faction = client.dominant_faction()
    var tension_before := dom.tension
    for i in range(4):
        assert_true(dm.vassal_council(gs, "chr_zachodnie", "judaizm", "D", 4.0), "sobór wasalny iteracja %d" % i)
        # 6 tur, żeby cooldown wygasł przed następnym wywołaniem
        for _t in range(DiplomacyManager.VASSAL_COUNCIL_COOLDOWN_TURNS + 1):
            tm.process_turn(gs)
    # Tension dominującej frakcji: 0 + 4*15 = 60 (poniżej progu 80)
    assert_almost_eq(dom.tension, tension_before + 4.0 * DiplomacyManager.VASSAL_COUNCIL_CLIENT_TENSION_BUMP, 0.001, "tension dominującej frakcji = 60 po 4 soborach")
    assert_eq(client.suzerain_id, "chr_zachodnie", "klient nadal wasalem po 4 soborach")

    # 4. Pchnięcie tension na próg buntu (uproszczenie testowe).
    #    Naturalna saturacja wymaga 6 sobórów (6×15=90), co przy cooldownie 5 daje 30+ tur.
    #    Test integracyjny pomija to ręcznym ustawieniem tension=90 — sprawdzamy ścieżkę buntu,
    #    nie wytrzymałość mechaniki cooldown (pokryta w unit teście test_vassal_council_cooldown_*).
    dom.tension = 90.0
    tm._process_vassal_revolts(gs)
    assert_eq(client.suzerain_id, "", "krok 4: klient się buntuje przy tension>80")
    # rel jest tym samym RelationState (klucz pary jest symetryczny)
    assert_true(rel.military_tension >= DiplomacyManager.REVOLT_TENSION_INCREASE - 0.001, "military_tension >= 30 po buncie")
    assert_almost_eq(dom.tension, 90.0 - DiplomacyManager.REVOLT_TENSION_RELIEF, 0.001, "ulga -40")

    # 5. Sanity: trybut przestał płynąć po buncie
    patron.resources = 0
    client.resources = 100
    tm._process_resources(gs)
    # Klient: 100 + 5 passive (suzerain_id == "", brak trybutu) = 105
    assert_eq(client.resources, 105, "po buncie brak trybutu — klient zachowuje passive income")
    assert_eq(patron.resources, DiplomacyManager.PASSIVE_INCOME_PER_TURN, "patron: tylko passive income, brak trybutu")


func test_integration_people_council_protects_against_interdict() -> void:
    # Sobór Ludowy → immunity → próba Interdyktu z różnych stron, każda blokowana → wygasa po 5 turach
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var tm := TurnManagerScript.new()

    var defender: Religion = gs.get_religion("judaizm")
    _pin_axes(defender, 50.0, 20.0, 50.0, 50.0)  # B=20 → Równouprawnienie >70
    defender.prestige = 50

    var attacker_a: Religion = gs.get_religion("islam")
    attacker_a.prestige = 100
    var attacker_b: Religion = gs.get_religion("hinduizm")
    attacker_b.prestige = 100

    # 1. Defender wystawia Sobór Ludowy
    assert_true(dm.people_council(gs, "judaizm"))
    var immunity_turn := defender.interdict_immunity_until
    assert_eq(immunity_turn, gs.current_turn + DiplomacyManager.PEOPLE_COUNCIL_IMMUNITY_TURNS)

    # 2. Dwa różne aktorzy próbują Interdyktu — oba blokowane
    assert_false(dm.proclaim_interdict(gs, "islam", "judaizm"), "atakujący A blokowany")
    assert_false(dm.proclaim_interdict(gs, "hinduizm", "judaizm"), "atakujący B blokowany")
    assert_eq(attacker_a.prestige, 100, "prestiż A nietknięty")
    assert_eq(attacker_b.prestige, 100, "prestiż B nietknięty")

    # 3. Przewińmy turę aż immunity wygaśnie (proclaim_interdict używa `>` więc immunity == current_turn już nie blokuje)
    for _t in range(DiplomacyManager.PEOPLE_COUNCIL_IMMUNITY_TURNS):
        tm.process_turn(gs)
    assert_true(gs.current_turn >= immunity_turn, "current_turn dogonił immunity_until")

    # 4. Po wygaśnięciu — Interdykt przechodzi
    assert_true(dm.proclaim_interdict(gs, "islam", "judaizm"), "po wygaśnięciu immunity Interdykt działa")
```

- [ ] **Step 2: Uruchom test — sprawdź czy passes**

Run pełny test suite:
```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Częste pułapki:
- `_update_faction_tensions` w TurnManager.process_turn dodaje +2.0 tension per diverged axis per tura. W integration test pinujemy klienta na (50,50,50,50) — domyślne `axis_preferences` historycznych frakcji NIE wszystkie są diverged w tym ustawieniu, ale dla pewności wyzerowujemy `axis_preferences` dominującej frakcji.
- Cooldown Soboru Wasalnego liczony per relacja (RelationState.vassal_council_cooldown_until). `state.current_turn` rośnie w `tm.process_turn` przez `state.advance_turn()`.
- Trybut przepływ wymaga `suzerain_id != ""` ORAZ `state.get_religion(suzerain_id) != null`. Po buncie `suzerain_id == ""` więc trybut się zatrzymuje.

- [ ] **Step 3: Final test suite — sprawdź wszystko**

Expected: WSZYSTKIE testy PASS (~255+). Brak regresji w 221 testach z Plan 05 ani wcześniejszych.

- [ ] **Step 4: Commit**

```bash
git add tests/engine/test_diplomacy_manager.gd
git commit -m "test: integration tests for Plan 06 (vassalage lifecycle, people council vs interdict)"
```

---

## Definition of Done — Plan 06

- [ ] `Religion` ma 3 nowe pola: `resources: int = 0`, `suzerain_id: String = ""`, `interdict_immunity_until: int = 0`
- [ ] `RelationState` ma nowe pole `vassal_council_cooldown_until: int = 0`
- [ ] `DiplomacyManager` ma 3 nowe metody publiczne:
  - `recognize_suzerainty(state, client_id, patron_id) -> bool` z blokadami null/istniejący patron/Dogmatyzm>=80/trust<=40/wojna
  - `vassal_council(state, patron_id, client_id, axis, delta) -> bool` z blokadami null/wczesny guard delta=0/wrong suzerain/B<=75/cooldown/prestiż; delta clampowana z zachowaniem znaku
  - `people_council(state, source_id) -> bool` z blokadami null/B>=30/prestiż; ustawia `interdict_immunity_until`
- [ ] `DiplomacyManager.proclaim_interdict` ma dodatkowy guard sprawdzający `target.interdict_immunity_until > state.current_turn` (przed pobraniem prestiżu)
- [ ] `DiplomacyManager` ma stałe Plan 06:
  - Wasalstwo: `SUZERAINTY_DOGMATYZM_BLOCK`, `SUZERAINTY_TRUST_THRESHOLD`, `SUZERAINTY_PATRON_PRESTIGE_GAIN`, `SUZERAINTY_ECON_GAIN`
  - Ekonomia: `PASSIVE_INCOME_PER_TURN`, `TRIBUTE_PER_TURN`
  - Bunt: `REVOLT_FACTION_TENSION_THRESHOLD`, `REVOLT_TENSION_INCREASE`, `REVOLT_TENSION_RELIEF`
  - Sobór Wasalny: `VASSAL_COUNCIL_HIERARCHIA_THRESHOLD`, `VASSAL_COUNCIL_PRESTIGE_COST`, `VASSAL_COUNCIL_MIN_AXIS_DELTA`, `VASSAL_COUNCIL_MAX_AXIS_DELTA`, `VASSAL_COUNCIL_CLIENT_TENSION_BUMP`, `VASSAL_COUNCIL_COOLDOWN_TURNS`
  - Sobór Ludowy: `PEOPLE_COUNCIL_ROWNOUPRAWNIENIE_THRESHOLD`, `PEOPLE_COUNCIL_PRESTIGE_COST`, `PEOPLE_COUNCIL_IMMUNITY_TURNS`
- [ ] `TurnManager.process_turn` wywołuje (w tej kolejności po `_process_diplomacy`):
  1. `_process_resources(state)` — passive income +5 wszystkim, potem trybut klient→patron z floor 0
  2. `_process_vassal_revolts(state)` — auto-bunt klienta przy tension dominującej frakcji >80
- [ ] Integration testy weryfikują:
  - `test_integration_vassalage_lifecycle`: uznanie → 4× Sobór Wasalny z cooldownem → manualny push tension → bunt → brak trybutu po buncie
  - `test_integration_people_council_protects_against_interdict`: Sobór Ludowy → dwóch różnych atakujących nie może użyć Interdyktu → po 5 turach immunity wygasa → Interdykt przechodzi
- [ ] Wszystkie nowe testy passes (~32 unit + 2 integration ≈ 34 nowych)
- [ ] Brak regresji w 221 istniejących testach
- [ ] Brak magic numbers w nowych metodach — wszystkie wartości jako nazwane stałe

## Co NIE wchodzi do Plan 06 (odłożone)

- **Unia personalna** — nie zdefiniowana w spec 03, brak modelu → **przyszłość**
- **`[Dołącz do potępienia]`** po Interdykcie — wymaga NPC decision system → **przyszłość**
- **Reaktywny CB `[Rewanż za zniewagę]`** po Interdykcie przy Ekskluzywizm>70 — wymaga integracji z `WarManager.CB_AXIS_REQUIREMENTS` → **Plan 07+**
- **Auto-join klienta do koalicji/sojuszu patrona** — **Plan 07**
- **Bunt klienta tworzący schizmę przez `SchismManager`** — Plan 06 robi tylko "odłączenie", schizma jako pochodna buntu → **przyszłość**
- **+5 prestiżu/turę za >10 tur pokoju** — wymaga trackingu `last_conflict_turn` → **odłożone**
- **AI NPC inicjujący Uznanie/Sobór Wasalny** — **przyszłość**
- **UI dyplomacji (akcje gracza)** — **dedykowany plan UI**
- **Trybut jako zasób inny niż int** (populacja, wojsko, etc.) — Plan 06 wprowadza tylko jedno generic `resources`; rozszerzony katalog → **przyszłość**
- **Transcendencja >65 → +15% siła sojuszu militarnego** — brak konsumenta w obecnym kodzie → **Plan 07** (Krucjata/Dżihad)
- **Sobór Ludowy z mechaniką frakcji / głosowania** — Plan 06 implementuje wersję defensywną bez frakcji
- **Sobór Ekumeniczny z konkretnym trwałym bonusem** — Plan 05 zaimplementował tylko ustępstwo, trwały bonus → **przyszłość**

---

**Następny plan:** `07-mechaniki-dyplomacja-vs-wojna.md` (proponowany) — auto-join klienta do koalicji patrona, reaktywny CB Rewanż za zniewagę po Interdykcie (Ekskluzywizm>70), Transcendencja >65 → +15% siła sojuszu w Krucjacie/Dżihadzie. Lub osobny plan UI dyplomacji.
