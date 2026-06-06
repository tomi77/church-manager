# Plan 07 — Dyplomacja vs Wojna

> **For Claude:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Zintegrować dyplomację z mechaniką wojny przez trzy luźne sprzężenia: wasalskie auto-join koalicji (klient podąża za patronem), reaktywny CB `[Rewanż za zniewagę]` po Interdykcie przy Ekskluzywizm>70, oraz bonus +15% siły armii w Krucjacie/Dżihadzie dla religii z D>65 mającej sojusznika w świętej wojnie.

**Architecture:** Trzy komponenty rozszerzające istniejące menedżery (`DiplomacyManager`, `WarManager`) bez nowych klas danych. Dwa nowe `@export` pola na `Religion` (`interdict_grievance_from_id`, `interdict_grievance_until`) trackują zniewagę. Sygnatura `WarManager.available_casus_belli` rozszerzona o `state` (breaking change, ale wszystkie call-sites aktualizujemy w tym samym taskcie). `DiplomacyManager.auto_join_vassals_to_coalitions` to nowa metoda wstrzykiwana w `TurnManager._process_diplomacy` po istniejącym `auto_join_allies_to_coalitions`. Bonus HolyWar to dodatkowy człon `axis_modifier` w `compute_army_strength`, gated guardem `religion.id == war.attacker_id` (tylko atakujący). Spec źródłowy: `docs/superpowers/specs/08-diplomacy-war-bridge-design.md`.

**Tech Stack:** Godot 4.6.3, GDScript 2.0, GUT (Godot Unit Testing), headless test runner.

---

## Powiązania ze spec-em

Mapowanie zakresu Plan 07 do sekcji `docs/superpowers/specs/08-diplomacy-war-bridge-design.md`:

| Element planu | Sekcja spec | Notatka |
|---|---|---|
| `Religion.interdict_grievance_from_id`, `interdict_grievance_until` | Sekcja 1 — Model Danych | defaults `""` / `0` |
| `proclaim_interdict` self-guard + zapis grievance | Sekcja 3 — Komponent B, Krok 1 | guard `source_id == target_id` na początku; zapis na końcu przed `return true` |
| `available_casus_belli(att, def, state)` + reactive Rewanż + `CB_BONUS["rewanz"] = 0.15` | Sekcja 3 — Komponent B, Krok 2 | breaking sig change; defensywne guardy `state != null`, `attacker.id != defender.id` |
| `declare_war` — zużycie grievance po `cb=="rewanz"` | Sekcja 3 — Komponent B, Krok 3 | wyzerowanie obu pól jednorazowo |
| Bonus HolyWar w `compute_army_strength` + helper `_has_holy_war_ally` | Sekcja 4 — Komponent C | guard `religion.id == war.attacker_id`, `D > 65` strict, kontekstowe (per-call) |
| `auto_join_vassals_to_coalitions` + integracja w `TurnManager._process_diplomacy` | Sekcja 2 — Komponent A | snapshot members, 1 poziom propagacji; guardy null patron, suzerain == target_id |
| Integration tests | Sekcja 6 — Pętle sprzężeń zwrotnych | I1: Interdykt→Rewanż cycle; I2: patron→klient w koalicji; I3: dwóch sojuszników D>65 w równoległych krucjatach |
| Stała `GRIEVANCE_WINDOW_TURNS = 10` (DiplomacyManager) | Sekcja 5 | okno 10 tur, operator `>` strict (efektywnie 9 tur) |
| Stała `GRIEVANCE_EKSKLUZYWIZM_THRESHOLD = 30.0` (DiplomacyManager) | Sekcja 5 | cross-class: konsumowana w WarManager |
| Stałe `HOLY_WAR_ALLIANCE_AXIS_D_THRESHOLD = 65.0`, `HOLY_WAR_ALLIANCE_BONUS = 0.15`, `HOLY_WAR_CBS = ["krucjata", "dzihad"]` (WarManager) | Sekcja 5 | bonus tylko dla ataku w święta wojna |

---

## Konwencje (uwaga implementatora)

**Wcięcia:** w tym projekcie pliki używają RÓŻNYCH konwencji:
- `Religion.gd`, `DiplomacyManager.gd`, `WarManager.gd`, `TurnManager.gd`, `GameState.gd`, `tests/engine/*.gd` — **4 spacje**
- `DoctrineManager.gd` — **TAB-y** (nieruszany w Plan 07)

Przed edycją zweryfikuj:
```bash
grep -E "^[\t ]+" <plik> | head -1 | od -c | head -1
```
Jeśli widzisz `\t` — taby. Jeśli `\sp \sp \sp \sp` — 4 spacje. Nie mieszaj.

**Klasy bez `class_name`:** `GameState.gd` NIE ma `class_name` (kolizja z Autoload). Testy korzystają z `preload("res://scripts/engine/GameState.gd").new()`.

**Brak nowych plików `.gd` w Plan 07:** wszystkie zmiany dotyczą istniejących plików. Nie ma nowych `.uid` sidecarów.

**Cross-class constants:** `WarManager.available_casus_belli` odwołuje się do `DiplomacyManager.GRIEVANCE_EKSKLUZYWIZM_THRESHOLD`. Wzorzec ten jest precedensowany w `TurnManager` → `DiplomacyManager.PASSIVE_INCOME_PER_TURN` (Plan 06). NIE duplikuj stałej; importuj przez nazwę klasy.

**Wzorzec testowy:** Test pliki używają `extends GutTest` i helpera `_make_state()` ładującego dane historyczne. Religie dostępne (id z `data/religions_historical.json`): `islam`, `chr_zachodnie`, `chr_wschodnie`, `judaizm`, `zoroastryzm`, `koptyjski`, `manicheizm`, `religie_arabskie`, `hinduizm`, `buddyzm`, `religie_germanskie`, `religie_slowianski`. Helper `_pin_axes(rel, a, b, c, d)` jest w obu test plikach. Helper `_make_war_for(att_id, def_id, cb, gs)` znajduje się w `test_war_manager.gd:216`.

**Konwencja umieszczania testów (Plan 06 follow-up):**
- Wszystkie testy `WarManager` (`available_casus_belli`, `declare_war`, `compute_army_strength`) → `tests/engine/test_war_manager.gd`
- Wszystkie testy `DiplomacyManager` (`proclaim_interdict`, `auto_join_vassals_to_coalitions`) → `tests/engine/test_diplomacy_manager.gd`
- Testy nowych pól `Religion` → `tests/engine/test_religion.gd`
- Integration testy obejmujące oba systemy → tam, gdzie jest *więcej* metod menedżera. CB Rewanż integration → `test_war_manager.gd`. Vassal auto-join integration → `test_diplomacy_manager.gd`. HolyWar integration → `test_war_manager.gd`.

**Komenda testowa:**
```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

**Baseline:** Plan 06 zostawia ~262 passing tests. Po Plan 07 oczekuj ~294 (29 unit + 3 integration = 32 nowych).

**Breaking change:** `WarManager.available_casus_belli` zmienia sygnaturę z `(att, def)` na `(att, def, state)`. Task 3 aktualizuje WSZYSTKIE call-sites:
- `WarManager.gd:96` (w `declare_war`)
- `tests/engine/test_war_manager.gd` — 7 wywołań (linie ~101, 112, 123, 134, 145, 156, 166)

Brak innych konsumentów (sprawdzone `grep`).

**Asymetria operatorów (uwaga z Plan 06):**
- `interdict_grievance_until > state.current_turn` (strict `>`) — okno wygasa DOKŁADNIE w turze T+10. Analogicznie do `interdict_immunity_until`.
- `vassal_council_cooldown_until` (Plan 06) używa `<=` — celowo inny operator. Plan 07 nie ruszają cooldown vassal.
- `D > HOLY_WAR_ALLIANCE_AXIS_D_THRESHOLD` (strict `>`) — bonus aktywuje się dopiero przy D=66, nie na granicy D=65. Świadoma decyzja, by uniknąć kumulacji bonusów na progu z `AXIS_STRENGTH_MODIFIERS["D"].min=65` (operator `>=`).

---

## Mapa zmian w plikach

**Nowe pliki:** brak.

**Modyfikacje:**
- `scripts/engine/Religion.gd` — 2 nowe `@export` (`interdict_grievance_from_id`, `interdict_grievance_until`)
- `scripts/engine/DiplomacyManager.gd` — 2 nowe stałe (`GRIEVANCE_WINDOW_TURNS`, `GRIEVANCE_EKSKLUZYWIZM_THRESHOLD`), modyfikacja `proclaim_interdict` (guard + zapis grievance), nowa metoda `auto_join_vassals_to_coalitions`
- `scripts/engine/WarManager.gd` — 3 nowe stałe HolyWar + wpis `CB_BONUS["rewanz"]`, zmiana sygnatury `available_casus_belli` + dodanie reactive Rewanż, modyfikacja `declare_war` (zużycie grievance), modyfikacja `compute_army_strength` + helper `_has_holy_war_ally`
- `scripts/engine/TurnManager.gd` — wstrzyknięcie `dm.auto_join_vassals_to_coalitions(state)` w `_process_diplomacy` po `auto_join_allies_to_coalitions`
- `tests/engine/test_religion.gd` — 1 test defaultów nowych pól
- `tests/engine/test_diplomacy_manager.gd` — 12 nowych unit testów + 1 integration (4 proclaim_interdict, 8 auto_join_vassals)
- `tests/engine/test_war_manager.gd` — 16 nowych unit testów + 2 integration + aktualizacja 7 wywołań (7 Rewanż + 3 declare_war + 6 HolyWar)

---

## Chunk 1: Fundamenty danych (Task 1)

### Task 1: Pola grievance na `Religion`

**Files:**
- Modify: `scripts/engine/Religion.gd:15-18` (po polach Plan 06)
- Test: `tests/engine/test_religion.gd` (dodaj na koniec)

- [ ] **Step 1: Napisz failing test**

W `tests/engine/test_religion.gd`, dodaj na koniec pliku:

```gdscript
func test_religion_grievance_fields_defaults() -> void:
    var r := Religion.new()
    assert_eq(r.interdict_grievance_from_id, "")
    assert_eq(r.interdict_grievance_until, 0)
```

- [ ] **Step 2: Uruchom testy — sprawdź FAIL**

Run:
```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
Expected: nowy test FAIL ("Invalid get index 'interdict_grievance_from_id'" lub podobny — pola jeszcze nie istnieją).

- [ ] **Step 3: Dodaj pola do `Religion.gd`**

W `scripts/engine/Religion.gd`, po linii `@export var interdict_immunity_until: int = 0` (linia 18) dodaj:

```gdscript
@export var interdict_grievance_from_id: String = ""    # ostatnia religia która rzuciła na nas Interdykt (Plan 07)
@export var interdict_grievance_until: int = 0          # tura do której (wyłącznie) CB Rewanż jest dostępny
```

- [ ] **Step 4: Uruchom testy — sprawdź PASS**

Run pełny suite:
```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
Expected: nowy test PASS, brak regresji w ~262 istniejących testach.

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/Religion.gd tests/engine/test_religion.gd
git commit -m "feat: add grievance fields to Religion (Plan 07 model)"
```

---

## Chunk 2: Grievance po Interdykcie (Tasks 2–3)

### Task 2: `proclaim_interdict` — self-guard + zapis grievance

**Files:**
- Modify: `scripts/engine/DiplomacyManager.gd:63-65` (dodaj stałe Plan 07 na końcu sekcji stałych Plan 06)
- Modify: `scripts/engine/DiplomacyManager.gd:141-155` (rozszerz `proclaim_interdict`)
- Test: `tests/engine/test_diplomacy_manager.gd` (dodaj na końcu)

- [ ] **Step 1: Napisz failing testy**

Dodaj na końcu `tests/engine/test_diplomacy_manager.gd`:

```gdscript
# --- proclaim_interdict + grievance (Plan 07) ---

func test_proclaim_interdict_blocked_when_source_equals_target() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 100
    var ok := dm.proclaim_interdict(gs, "islam", "islam")
    assert_false(ok, "self-Interdykt zabroniony")
    assert_eq(src.prestige, 100, "prestiż nie pobrany")
    assert_eq(src.interdict_grievance_from_id, "", "własna grievance nie ustawiona")

func test_proclaim_interdict_records_grievance_on_target() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 100
    var target: Religion = gs.get_religion("judaizm")
    var t_before: int = gs.current_turn
    var ok := dm.proclaim_interdict(gs, "islam", "judaizm")
    assert_true(ok, "Interdykt przeszedł")
    assert_eq(target.interdict_grievance_from_id, "islam", "grievance ustawione na sprawcę")
    assert_eq(target.interdict_grievance_until, t_before + DiplomacyManager.GRIEVANCE_WINDOW_TURNS)

func test_proclaim_interdict_overwrites_previous_grievance() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var target: Religion = gs.get_religion("judaizm")
    # Symulacja: poprzednia zniewaga od hinduizmu, zapisana 5 tur wcześniej (już ustabilizowana)
    target.interdict_grievance_from_id = "hinduizm"
    target.interdict_grievance_until = gs.current_turn + 2
    var src: Religion = gs.get_religion("islam")
    src.prestige = 100
    assert_true(dm.proclaim_interdict(gs, "islam", "judaizm"), "nowy Interdykt przechodzi")
    assert_eq(target.interdict_grievance_from_id, "islam", "nowy źródło nadpisuje stary")
    assert_eq(target.interdict_grievance_until, gs.current_turn + DiplomacyManager.GRIEVANCE_WINDOW_TURNS, "okno zresetowane")

func test_proclaim_interdict_does_not_set_grievance_on_immunity_block() -> void:
    # Spec sek.3: grievance jest zapisywane PRZED 'return true' — czyli tylko gdy akcja przeszła.
    # Immunity z Plan 06 blokuje akcję wcześniej, więc grievance NIE jest zapisywane.
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var src: Religion = gs.get_religion("islam")
    src.prestige = 100
    var target: Religion = gs.get_religion("judaizm")
    target.interdict_immunity_until = gs.current_turn + 3
    assert_false(dm.proclaim_interdict(gs, "islam", "judaizm"))
    assert_eq(target.interdict_grievance_from_id, "", "grievance NIE ustawione gdy Interdykt zablokowany przez immunity")
    assert_eq(target.interdict_grievance_until, 0)
```

- [ ] **Step 2: Uruchom testy — sprawdź FAIL**

Run:
```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
Expected: 4 testy FAIL — `GRIEVANCE_WINDOW_TURNS` nie istnieje (compile error w `test_proclaim_interdict_records_grievance_on_target`), guard self-Interdykt nie działa, grievance pola pozostają domyślne.

- [ ] **Step 3: Dodaj stałe Plan 07 w `DiplomacyManager.gd`**

W `scripts/engine/DiplomacyManager.gd`, znajdź koniec sekcji stałych Plan 06 (po linii `const PEOPLE_COUNCIL_IMMUNITY_TURNS := 5   # uwaga: proclaim_interdict używa...` — linia ~92). Dodaj:

```gdscript

# --- Stałe Grievance po Interdykcie (Plan 07) ---
# Operator `>` (strict) — analogicznie do interdict_immunity_until z Plan 06.
# Skutek: jeśli grievance_until = T+10, CB Rewanż dostępne w turach T+1..T+9 (efektywnie 9 tur okna).
const GRIEVANCE_WINDOW_TURNS := 10
const GRIEVANCE_EKSKLUZYWIZM_THRESHOLD := 30.0   # C<30 (Ekskluzywizm>70) — konsumowane przez WarManager.available_casus_belli
```

- [ ] **Step 4: Rozszerz `proclaim_interdict` o self-guard + zapis grievance**

W `scripts/engine/DiplomacyManager.gd`, znajdź `func proclaim_interdict` (linia ~141). Aktualnie:

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

Zmień na:

```gdscript
func proclaim_interdict(state: Node, source_id: String, target_id: String) -> bool:
    # Guard self-Interdykt (Plan 07): religia nie może rzucić Interdyktu na samą siebie.
    # Eliminuje degenerowany przypadek attacker.interdict_grievance_from_id == attacker.id.
    if source_id == target_id:
        return false
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
    # Zapis grievance (Plan 07): target zapamiętuje sprawcę i okno czasu na CB Rewanż.
    # Wykonywane przed `return true`, więc tylko gdy wszystkie wcześniejsze guardy przeszły.
    if target != null:
        target.interdict_grievance_from_id = source_id
        target.interdict_grievance_until = state.current_turn + GRIEVANCE_WINDOW_TURNS
    return true
```

Uwaga: guard `target != null` przed zapisem grievance — `target` mógłby być `null` jeśli `target_id` wskazuje na nieistniejącą religię. W obecnym kodzie ta gałąź jest nieosiągalna (immunity guard wcześniej sprawdza `target != null`, ale używa short-circuit `and`), więc dodajemy explicit guard dla pewności.

- [ ] **Step 5: Uruchom testy — sprawdź PASS**

Expected: 4 nowe testy PASS, brak regresji.

Częste pułapki:
- Jeśli zapomnisz `target != null` przed zapisem grievance — krash przy `null.interdict_grievance_from_id`.
- Jeśli przeniesiesz zapis grievance PRZED `source.add_prestige(-INTERDICT_PRESTIGE_COST)` — nieszkodliwe, ale niespójne ze spec (spec mówi "przed `return true`", czyli po koszcie).
- Jeśli postawisz guard self na końcu (po `if source == null`) — wszystko zadziała, ale to dodatkowy `state.get_religion()` call. Spec preferuje na początku, before any state lookup.

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/DiplomacyManager.gd tests/engine/test_diplomacy_manager.gd
git commit -m "feat: proclaim_interdict records grievance + self-guard (Plan 07)"
```

---

### Task 3: `WarManager.available_casus_belli` — rozszerzenie sygnatury + reactive Rewanż

**Files:**
- Modify: `scripts/engine/WarManager.gd:15-21` (dodaj `CB_BONUS["rewanz"]`)
- Modify: `scripts/engine/WarManager.gd:71-89` (zmień sygnaturę + dodaj reactive blok)
- Modify: `scripts/engine/WarManager.gd:96` (jedno wywołanie `available_casus_belli` w `declare_war`)
- Modify: `tests/engine/test_war_manager.gd` — zaktualizuj 7 istniejących wywołań do nowej sygnatury
- Test: `tests/engine/test_war_manager.gd` (dodaj na końcu pliku)

- [ ] **Step 1: Napisz failing testy**

Dodaj na końcu `tests/engine/test_war_manager.gd`:

```gdscript
# --- CB Rewanż za zniewagę (Plan 07) ---

func test_cb_rewanz_unlocked_when_grievance_active_and_exclusivism_high() -> void:
    var gs := _make_state()
    var wm := WarManager.new()
    var att: Religion = gs.get_religion("islam")
    var def: Religion = gs.get_religion("chr_zachodnie")
    _pin_axes(att, 50.0, 50.0, 20.0, 50.0)  # C=20 → Ekskluzywizm 80
    att.interdict_grievance_from_id = "chr_zachodnie"
    att.interdict_grievance_until = gs.current_turn + 5
    var cbs := wm.available_casus_belli(att, def, gs)
    assert_true("rewanz" in cbs, "Rewanż dostępny przy C<30 + grievance aktywne")

func test_cb_rewanz_blocked_when_exclusivism_too_low() -> void:
    var gs := _make_state()
    var wm := WarManager.new()
    var att: Religion = gs.get_religion("islam")
    var def: Religion = gs.get_religion("chr_zachodnie")
    _pin_axes(att, 50.0, 50.0, 50.0, 50.0)  # C=50 → tolerancyjny
    att.interdict_grievance_from_id = "chr_zachodnie"
    att.interdict_grievance_until = gs.current_turn + 5
    var cbs := wm.available_casus_belli(att, def, gs)
    assert_false("rewanz" in cbs, "Rewanż NIE dostępny przy C>=30")

func test_cb_rewanz_blocked_when_grievance_expired() -> void:
    var gs := _make_state()
    var wm := WarManager.new()
    var att: Religion = gs.get_religion("islam")
    var def: Religion = gs.get_religion("chr_zachodnie")
    _pin_axes(att, 50.0, 50.0, 20.0, 50.0)
    att.interdict_grievance_from_id = "chr_zachodnie"
    att.interdict_grievance_until = gs.current_turn  # > operator strict → equal nie wystarcza
    var cbs := wm.available_casus_belli(att, def, gs)
    assert_false("rewanz" in cbs, "Rewanż NIE dostępny gdy grievance_until == current_turn (operator > strict)")

func test_cb_rewanz_blocked_when_defender_is_not_grievance_source() -> void:
    var gs := _make_state()
    var wm := WarManager.new()
    var att: Religion = gs.get_religion("islam")
    var other: Religion = gs.get_religion("hinduizm")  # nie ten, który rzucił Interdykt
    _pin_axes(att, 50.0, 50.0, 20.0, 50.0)
    att.interdict_grievance_from_id = "chr_zachodnie"
    att.interdict_grievance_until = gs.current_turn + 5
    var cbs := wm.available_casus_belli(att, other, gs)
    assert_false("rewanz" in cbs, "Rewanż musi być przeciw konkretnemu sprawcy")

func test_cb_rewanz_handles_null_state() -> void:
    # Defensywne: testy jednostkowe mogą wołać bez state (np. dla statycznych CB)
    var gs := _make_state()
    var wm := WarManager.new()
    var att: Religion = gs.get_religion("islam")
    var def: Religion = gs.get_religion("chr_zachodnie")
    _pin_axes(att, 50.0, 50.0, 20.0, 50.0)
    att.interdict_grievance_from_id = "chr_zachodnie"
    att.interdict_grievance_until = 9999
    var cbs := wm.available_casus_belli(att, def, null)
    assert_false("rewanz" in cbs, "bez state nie ma reaktywnych CB")

func test_cb_rewanz_blocked_when_attacker_equals_defender() -> void:
    # Defensywny guard: gdyby ktoś ręcznie ustawił grievance na własne id, available_casus_belli
    # nie powinien zwrócić Rewanżu na siebie.
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
```

- [ ] **Step 2: Uruchom testy — sprawdź FAIL**

Run:
```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
Expected: 7 nowych testów FAIL (sygnatura `available_casus_belli` zwraca błąd "expected 2 arguments, got 3"; `CB_BONUS["rewanz"]` nie istnieje).

Dodatkowo: wszystkie istniejące testy używające 2-argumentowej sygnatury (`test_cb_*` linie 93-167 w `test_war_manager.gd`) — staną się compile-errors po zmianie sygnatury. Trzeba je zaktualizować w step 4.

- [ ] **Step 3: Zmień sygnaturę `available_casus_belli` + dodaj reactive Rewanż + `CB_BONUS["rewanz"]`**

W `scripts/engine/WarManager.gd`, znajdź `CB_BONUS` (linia 15-21). Dodaj wpis "rewanz":

```gdscript
const CB_BONUS: Dictionary = {
    "krucjata": 0.30,
    "dzihad": 0.40,
    "wojna_sprawiedliwa": 0.20,
    "nawrocenie_mieczem": 0.10,
    "stlumienie_herezji": 0.15,
    "rewanz": 0.15,
}
```

Następnie znajdź `func available_casus_belli` (linia ~71). Aktualnie:

```gdscript
func available_casus_belli(attacker: Religion, defender: Religion) -> Array[String]:
    var result: Array[String] = []
    for cb_id: String in CB_AXIS_REQUIREMENTS.keys():
        var rules: Array = CB_AXIS_REQUIREMENTS[cb_id]
        if _religion_matches_axis_rules(attacker, rules):
            result.append(cb_id)
    if defender.parent_religion_id == attacker.id and attacker.id != "":
        result.append("stlumienie_herezji")
    return result
```

Zmień na:

```gdscript
func available_casus_belli(attacker: Religion, defender: Religion, state: Node) -> Array[String]:
    var result: Array[String] = []
    for cb_id: String in CB_AXIS_REQUIREMENTS.keys():
        var rules: Array = CB_AXIS_REQUIREMENTS[cb_id]
        if _religion_matches_axis_rules(attacker, rules):
            result.append(cb_id)
    if defender.parent_religion_id == attacker.id and attacker.id != "":
        result.append("stlumienie_herezji")
    # Reaktywne CB Rewanż za zniewagę (Plan 07).
    # Defensywne guardy: state==null (testy bez state), attacker==defender (zdegenerowane grievance).
    if state != null \
       and attacker.id != defender.id \
       and attacker.interdict_grievance_from_id == defender.id \
       and attacker.interdict_grievance_until > state.current_turn \
       and attacker.get_axis("C") < DiplomacyManager.GRIEVANCE_EKSKLUZYWIZM_THRESHOLD:
        result.append("rewanz")
    return result
```

- [ ] **Step 4: Zaktualizuj `declare_war` + istniejące testy do nowej sygnatury**

W `scripts/engine/WarManager.gd:96`, zmień:

```gdscript
    if not available_casus_belli(attacker, defender).has(cb):
```

na:

```gdscript
    if not available_casus_belli(attacker, defender, state).has(cb):
```

W `tests/engine/test_war_manager.gd`, zaktualizuj 7 wywołań — każdy `wm.available_casus_belli(att, def)` zmień na `wm.available_casus_belli(att, def, gs)`:

```bash
# Sanity grep: powinno znaleźć 7 wystąpień (przed zmianą).
grep -n "available_casus_belli(att, def)" tests/engine/test_war_manager.gd
```

Linie do edycji (zgodnie z aktualnym stanem pliku): 101, 112, 123, 134, 145, 156, 166.

Po edycji:
```bash
grep -n "available_casus_belli(att, def)" tests/engine/test_war_manager.gd
# Expected: 0 wystąpień. Wszystkie powinny mieć trzeci argument.
```

- [ ] **Step 5: Uruchom testy — sprawdź PASS**

Run pełny suite:
```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
Expected: 7 nowych testów Rewanż PASS, 7 zaktualizowanych testów statycznych CB nadal PASS, brak regresji.

Częste pułapki:
- Jeśli zapomnisz `DiplomacyManager.GRIEVANCE_EKSKLUZYWIZM_THRESHOLD` (cross-class) → "Invalid get index" — sprawdź że nie próbujesz duplikować stałej lokalnie w `WarManager`.
- Jeśli pominiesz guard `state != null` → krash w testach jednostkowych wołających `available_casus_belli(att, def, null)`.
- Jeśli zapomnisz guard `attacker.id != defender.id` → test `test_cb_rewanz_blocked_when_attacker_equals_defender` FAIL.
- Jeśli `_pin_axes(att, 50.0, 50.0, 20.0, 50.0)` rzuca błąd "nie ma metody _pin_axes" — sprawdź czy nazwa testu zaczyna się od `test_` i czy plik ma `_pin_axes` (jest na linii 87).
- Operator `>` strict — w teście `test_cb_rewanz_blocked_when_grievance_expired` używamy `grievance_until == current_turn` jako case wygaszenia. Jeśli kod używa `>=`, ten test FAIL.

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/WarManager.gd tests/engine/test_war_manager.gd
git commit -m "feat: reactive CB rewanz + available_casus_belli takes state (Plan 07)"
```

---

## Chunk 3: Wojenne integracje (Tasks 4–5)

### Task 4: `declare_war` — zużycie grievance po `cb=="rewanz"`

**Files:**
- Modify: `scripts/engine/WarManager.gd:91-111` (`declare_war`, dodanie zerowania grievance)
- Test: `tests/engine/test_war_manager.gd` (dodaj na końcu)

- [ ] **Step 1: Napisz failing testy**

Dodaj na końcu `tests/engine/test_war_manager.gd`:

```gdscript
# --- declare_war zużywa grievance (Plan 07) ---

func test_declare_war_rewanz_consumes_grievance() -> void:
    var gs := _make_state()
    var wm := WarManager.new()
    var att: Religion = gs.get_religion("islam")
    var def: Religion = gs.get_religion("chr_zachodnie")
    _pin_axes(att, 50.0, 50.0, 20.0, 50.0)  # Ekskluzywizm
    att.prestige = 50
    att.interdict_grievance_from_id = "chr_zachodnie"
    att.interdict_grievance_until = gs.current_turn + 5
    var war := wm.declare_war("islam", "chr_zachodnie", "rewanz", gs)
    assert_not_null(war, "wojna Rewanż utworzona")
    assert_eq(att.interdict_grievance_from_id, "", "grievance from_id wyzerowane po deklaracji")
    assert_eq(att.interdict_grievance_until, 0, "grievance until wyzerowane po deklaracji")

func test_declare_war_non_rewanz_does_not_consume_grievance() -> void:
    var gs := _make_state()
    var wm := WarManager.new()
    var att: Religion = gs.get_religion("islam")
    var def: Religion = gs.get_religion("chr_zachodnie")
    _pin_axes(att, 50.0, 50.0, 20.0, 30.0)  # Ekskluzywizm + Doczesność → krucjata
    att.prestige = 50
    att.interdict_grievance_from_id = "chr_zachodnie"
    var grievance_turn := gs.current_turn + 5
    att.interdict_grievance_until = grievance_turn
    var war := wm.declare_war("islam", "chr_zachodnie", "krucjata", gs)
    assert_not_null(war, "wojna krucjata utworzona")
    assert_eq(att.interdict_grievance_from_id, "chr_zachodnie", "grievance NIE wyzerowane przy CB != rewanz")
    assert_eq(att.interdict_grievance_until, grievance_turn, "okno grievance nietknięte")

func test_declare_war_rewanz_jednorazowy_second_attempt_fails() -> void:
    # Po pierwszej wojnie Rewanż, kolejna nie powinna być możliwa (grievance zużyte).
    var gs := _make_state()
    var wm := WarManager.new()
    var att: Religion = gs.get_religion("islam")
    var def: Religion = gs.get_religion("chr_zachodnie")
    _pin_axes(att, 50.0, 50.0, 20.0, 50.0)
    att.prestige = 100
    att.interdict_grievance_from_id = "chr_zachodnie"
    att.interdict_grievance_until = gs.current_turn + 5
    # Pierwsza wojna — sukces
    assert_not_null(wm.declare_war("islam", "chr_zachodnie", "rewanz", gs))
    # Druga próba — fail (grievance puste, więc Rewanż nie dostępny)
    var war2 := wm.declare_war("islam", "chr_zachodnie", "rewanz", gs)
    assert_null(war2, "kolejna wojna Rewanż blokowana — grievance jednorazowe")
```

- [ ] **Step 2: Uruchom testy — sprawdź FAIL**

Run:
```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
Expected: testy `test_declare_war_rewanz_consumes_grievance` i `test_declare_war_rewanz_jednorazowy_second_attempt_fails` FAIL — grievance pozostaje po deklaracji.

- [ ] **Step 3: Dodaj zużycie grievance w `declare_war`**

W `scripts/engine/WarManager.gd`, znajdź `func declare_war` (linia ~91). Aktualnie pod koniec:

```gdscript
    attacker.add_prestige(-DECLARE_WAR_PRESTIGE)
    var war := War.new()
    war.attacker_id = attacker_id
    war.defender_id = defender_id
    war.casus_belli = cb
    war.state = "MOBILIZING"
    war.turns_in_state = 0
    state.active_wars.append(war)
    var dm := DiplomacyManager.new()
    var rel := dm.get_or_create_relation(state, attacker_id, defender_id)
    rel.military_tension = clampf(rel.military_tension + DiplomacyManager.DECLARE_WAR_TENSION_INCREASE, 0.0, 100.0)
    return war
```

Po `state.active_wars.append(war)` dodaj zużycie grievance (przed lub po `dm` blok — kolejność bez znaczenia funkcjonalnego):

```gdscript
    attacker.add_prestige(-DECLARE_WAR_PRESTIGE)
    var war := War.new()
    war.attacker_id = attacker_id
    war.defender_id = defender_id
    war.casus_belli = cb
    war.state = "MOBILIZING"
    war.turns_in_state = 0
    state.active_wars.append(war)
    # Plan 07: Rewanż jest jednorazowy — wyzeruj grievance po deklaracji.
    if cb == "rewanz":
        attacker.interdict_grievance_from_id = ""
        attacker.interdict_grievance_until = 0
    var dm := DiplomacyManager.new()
    var rel := dm.get_or_create_relation(state, attacker_id, defender_id)
    rel.military_tension = clampf(rel.military_tension + DiplomacyManager.DECLARE_WAR_TENSION_INCREASE, 0.0, 100.0)
    return war
```

- [ ] **Step 4: Uruchom testy — sprawdź PASS**

Expected: 3 nowe testy PASS, brak regresji w istniejących wojennych.

Częste pułapki:
- Jeśli umieścisz `if cb == "rewanz"` PRZED `state.active_wars.append(war)` — i tak działa, ale spec preferuje po (bo zerowanie grievance jest postconditionem deklaracji wojny, nie warunkiem jej zaistnienia).
- Jeśli zerujesz grievance ZAWSZE (bez `if cb == "rewanz"`) — testy `test_declare_war_non_rewanz_does_not_consume_grievance` FAIL.

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/WarManager.gd tests/engine/test_war_manager.gd
git commit -m "feat: declare_war consumes interdict grievance on CB rewanz (Plan 07)"
```

---

### Task 5: Bonus HolyWar w `compute_army_strength` + helper `_has_holy_war_ally`

**Files:**
- Modify: `scripts/engine/WarManager.gd:50` (dodaj stałe HolyWar po `WEARINESS_PENALTIES`)
- Modify: `scripts/engine/WarManager.gd:113-138` (`compute_army_strength` — wstrzykuj bonus)
- Modify: `scripts/engine/WarManager.gd` — dodaj na końcu helper `_has_holy_war_ally`
- Test: `tests/engine/test_war_manager.gd` (dodaj na końcu)

- [ ] **Step 1: Napisz failing testy**

Dodaj na końcu `tests/engine/test_war_manager.gd`:

```gdscript
# --- Bonus HolyWar w święta wojna sojusznicza (Plan 07) ---
#
# UWAGA: testy używają CB "dzihad" (D>=70), bo bonus HolyWar wymaga D>65 —
# CB "krucjata" wymaga D<=40, więc gameplay-owo nigdy nie aktywuje bonusu HolyWar.
# Defenderzy: "chr_wschodnie" (5 prowincji m.in. armenia/lewant) i "zoroastryzm" (persja/persepolis)
# — religie WŁAŚCICIELE prowincji w danych historycznych. judaizm/hinduizm/buddyzm NIE mają prowincji,
# więc `provinces_with_owner("judaizm")` zwraca []. Target province wybieramy przez get_province("armenia")
# (mountains, owned by chr_wschodnie) — wzorzec z istniejących testów compute_strength_terrain_*.

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
    _pin_axes(att, 50.0, 50.0, 20.0, 70.0)   # D=70 > 65 → bonus
    var wars := _setup_holy_war_alliance(gs, "islam", "chr_zachodnie", "chr_wschodnie", "zoroastryzm")
    var att_war: War = wars["att_war"]
    var target_prov: Province = gs.province_graph.get_province("armenia")  # owned by chr_wschodnie
    var strength_with := wm.compute_army_strength(att, target_prov, att_war, gs)
    # Sanity baseline: usuń bonus przez zerwanie sojuszu, ponownie zmierz.
    for rel: RelationState in gs.relations:
        rel.alliance_active = false
    var strength_without := wm.compute_army_strength(att, target_prov, att_war, gs)
    assert_gt(strength_with, strength_without, "bonus HolyWar zwiększa siłę armii")
    # Sanity ratio: różnica multiplikatywna powinna mieć tendencję ~+15% / (1 + axis_modifier_base).
    # Nie liczymy dokładnej wartości — `test_holy_war_constants` sprawdza stałą; tutaj wystarczy że bonus przyłożył się i siła wzrosła.

func test_holy_war_bonus_blocked_when_d_below_threshold() -> void:
    var gs := _make_state()
    var wm := WarManager.new()
    var att: Religion = gs.get_religion("islam")
    _pin_axes(att, 50.0, 50.0, 20.0, 65.0)  # D=65 → operator > strict, NIE aktywuje +15% (równe progowi)
    var wars := _setup_holy_war_alliance(gs, "islam", "chr_zachodnie", "chr_wschodnie", "zoroastryzm")
    var target_prov: Province = gs.province_graph.get_province("armenia")
    var strength_with_d65 := wm.compute_army_strength(att, target_prov, wars["att_war"], gs)
    _pin_axes(att, 50.0, 50.0, 20.0, 66.0)  # D=66 → bonus aktywny
    var strength_with_d66 := wm.compute_army_strength(att, target_prov, wars["att_war"], gs)
    assert_gt(strength_with_d66, strength_with_d65, "bonus tylko przy D>65 (strict, nie >=)")

func test_holy_war_bonus_blocked_without_alliance() -> void:
    var gs := _make_state()
    var wm := WarManager.new()
    var att: Religion = gs.get_religion("islam")
    _pin_axes(att, 50.0, 50.0, 20.0, 70.0)
    # Brak alliance_active — wojny istnieją, ale sojusz NIE
    var att_war := _make_war_for("islam", "chr_wschodnie", "dzihad", gs)
    var ally_war := _make_war_for("chr_zachodnie", "zoroastryzm", "dzihad", gs)
    gs.active_wars.append(att_war)
    gs.active_wars.append(ally_war)
    var target_prov: Province = gs.province_graph.get_province("armenia")
    var strength_no_alliance := wm.compute_army_strength(att, target_prov, att_war, gs)
    # Włącz sojusz — siła powinna wzrosnąć
    var dm := DiplomacyManager.new()
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.alliance_active = true
    var strength_with_alliance := wm.compute_army_strength(att, target_prov, att_war, gs)
    assert_gt(strength_with_alliance, strength_no_alliance, "bonus wymaga aktywnego sojuszu")

func test_holy_war_bonus_blocked_when_ally_not_in_holy_war() -> void:
    var gs := _make_state()
    var wm := WarManager.new()
    var att: Religion = gs.get_religion("islam")
    _pin_axes(att, 50.0, 50.0, 20.0, 70.0)
    var dm := DiplomacyManager.new()
    var rel := dm.get_or_create_relation(gs, "islam", "chr_zachodnie")
    rel.alliance_active = true
    var att_war := _make_war_for("islam", "chr_wschodnie", "dzihad", gs)
    var ally_war := _make_war_for("chr_zachodnie", "zoroastryzm", "wojna_sprawiedliwa", gs)  # NIE krucjata/dzihad
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
    # Mierzymy siłę religii "chr_wschodnie" (broniący w dzihad islam→chr_wschodnie), z D=70 i sojusznikiem
    # w równoległym dzihad. Bez guard `religion.id == war.attacker_id`, defender dostałby błędnie +15%.
    var gs := _make_state()
    var wm := WarManager.new()
    var att: Religion = gs.get_religion("islam")
    var def_with_d_high: Religion = gs.get_religion("chr_wschodnie")  # owns provinces — potrzebne dla base
    _pin_axes(att, 50.0, 50.0, 50.0, 50.0)
    _pin_axes(def_with_d_high, 50.0, 50.0, 20.0, 70.0)
    var dm := DiplomacyManager.new()
    # Sojusz defendera z trzecią religią prowadzącą dzihad
    var rel := dm.get_or_create_relation(gs, "chr_wschodnie", "chr_zachodnie")
    rel.alliance_active = true
    var att_war := _make_war_for("islam", "chr_wschodnie", "dzihad", gs)
    var ally_war := _make_war_for("chr_zachodnie", "zoroastryzm", "dzihad", gs)
    gs.active_wars.append(att_war)
    gs.active_wars.append(ally_war)
    var target_prov: Province = gs.province_graph.get_province("armenia")
    # Mierzymy siłę DEFENDERA (chr_wschodnie). Bonus nie powinien aktywować się mimo D=70 i sojusznika w dzihadzie.
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
```

Uwagi do testów:
- Wszystkie HolyWar testy używają `gs.active_wars.append(...)` jawnie (bo `_make_war_for` w `test_war_manager.gd:216` *tylko tworzy* `War`, nie wpisuje do `state.active_wars`). Bez tego `_has_holy_war_ally` zwróci false i bonus nigdy się nie pojawi.
- `chr_wschodnie` jako defender — to religia z 5 prowincjami; służy jako target zarówno do `get_province("armenia")` (target_province), jak i obliczenia `base = sum(populations) * 0.1` w `compute_army_strength` gdy defender jest mierzony.
- CB `dzihad` (nie krucjata) — krucjata wymaga `D<=40` (Doczesność>60), dzihad wymaga `D>=70` (Transcendencja>=70). Plan 07 bonus jest `D>65`. Tylko dzihad jest zgodny z gameplay'em (declare_war by się powiódł). W testach `_make_war_for` ominęłby walidację, ale spójność stylistyczna z gameplay'em ma priorytet.
- W teście `test_holy_war_bonus_blocked_when_ally_not_in_holy_war` używamy bezpośredniej referencji `ally_war.casus_belli = "dzihad"` zamiast `gs.active_wars[1].casus_belli` — bezpieczne na wypadek zmiany kolejności append.

- [ ] **Step 2: Uruchom testy — sprawdź FAIL**

Run:
```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
Expected: testy FAIL — `HOLY_WAR_*` stałe nie istnieją (compile error w `test_holy_war_constants`), bonus nie aplikuje (`assert_gt(strength_with, strength_without)` FAIL).

- [ ] **Step 3: Dodaj stałe HolyWar w `WarManager.gd`**

W `scripts/engine/WarManager.gd`, znajdź koniec `WEARINESS_PENALTIES` (linia ~50). Dodaj:

```gdscript

# --- Bonus świętej wojny sojuszniczej (Plan 07) ---
# Operator `>` strict, świadomie inny niż AXIS_STRENGTH_MODIFIERS["D"].min=65 z `>=` —
# bonus aktywny dopiero przy D=66, by nie kumulował się z bazowym +25% na samej granicy.
const HOLY_WAR_ALLIANCE_AXIS_D_THRESHOLD := 65.0
const HOLY_WAR_ALLIANCE_BONUS := 0.15
const HOLY_WAR_CBS: Array = ["krucjata", "dzihad"]
```

- [ ] **Step 4: Wstrzyknij bonus w `compute_army_strength` + dodaj helper `_has_holy_war_ally`**

W `scripts/engine/WarManager.gd`, znajdź `func compute_army_strength` (linia ~113). Aktualnie po pętli `AXIS_STRENGTH_MODIFIERS` (linia ~126):

```gdscript
    for rule: Dictionary in AXIS_STRENGTH_MODIFIERS:
        var axis: String = rule["axis"]
        var value := religion.get_axis(axis)
        if rule.has("min") and value >= rule["min"]:
            axis_modifier += rule["bonus"]
        elif rule.has("max") and value <= rule["max"]:
            axis_modifier += rule["bonus"]
    var cb_modifier: float = CB_BONUS.get(war.casus_belli, 0.0)
```

Zmień na (wstaw blok bonusu HolyWar między AXIS_STRENGTH_MODIFIERS a cb_modifier):

```gdscript
    for rule: Dictionary in AXIS_STRENGTH_MODIFIERS:
        var axis: String = rule["axis"]
        var value := religion.get_axis(axis)
        if rule.has("min") and value >= rule["min"]:
            axis_modifier += rule["bonus"]
        elif rule.has("max") and value <= rule["max"]:
            axis_modifier += rule["bonus"]
    # Bonus świętej wojny sojuszniczej (Plan 07).
    # Tylko atakujący w krucjacie/dzihadzie, z D>65 (strict), mający sojusznika również w świętej wojnie.
    if religion.id == war.attacker_id \
       and war.casus_belli in HOLY_WAR_CBS \
       and religion.get_axis("D") > HOLY_WAR_ALLIANCE_AXIS_D_THRESHOLD \
       and _has_holy_war_ally(religion, state):
        axis_modifier += HOLY_WAR_ALLIANCE_BONUS
    var cb_modifier: float = CB_BONUS.get(war.casus_belli, 0.0)
```

Następnie na końcu `WarManager.gd` (po `attack_province`) dodaj helper:

```gdscript

func _has_holy_war_ally(religion: Religion, state: Node) -> bool:
    # Plan 07: sprawdza czy religia ma aktywny sojusz z inną religią prowadzącą krucjatę/dżihad jako atakujący.
    # Sojusznik broniący w krucjacie NIE liczy się — wymagany jest atak.
    for rel: RelationState in state.relations:
        if not rel.alliance_active:
            continue
        var ally_id := ""
        if rel.religion_a_id == religion.id:
            ally_id = rel.religion_b_id
        elif rel.religion_b_id == religion.id:
            ally_id = rel.religion_a_id
        else:
            continue
        for war: War in state.active_wars:
            if war.state == "ENDED":
                continue
            if war.attacker_id == ally_id and war.casus_belli in HOLY_WAR_CBS:
                return true
    return false
```

- [ ] **Step 5: Uruchom testy — sprawdź PASS**

Expected: 6 nowych testów HolyWar PASS, brak regresji w istniejących testach `compute_army_strength`.

Częste pułapki:
- Jeśli zapomnisz `religion.id == war.attacker_id` → test `test_holy_war_bonus_blocked_for_defender_in_holy_war` FAIL.
- Jeśli użyjesz `>=` zamiast `>` → test `test_holy_war_bonus_blocked_when_d_below_threshold` FAIL (D=65 dostanie bonus).
- Helper `_has_holy_war_ally` przegląda WSZYSTKIE wojny — jeśli sojusznik ma wojnę ENDED z krucjatą jest pomijana przez guard `war.state == "ENDED"`.
- `_setup_holy_war_alliance` używa `_make_war_for` i ręcznie appenduje wojny do `gs.active_wars` — bez tego `_has_holy_war_ally` zwróci false (iteruje `state.active_wars`). Wzorzec: `var w := _make_war_for(...); gs.active_wars.append(w)`.
- Religie używane w testach HolyWar: `islam` (mezopotamia), `chr_zachodnie` (rzym), `chr_wschodnie` (5 prowincji), `zoroastryzm` (2 prowincje), `koptyjski` (egipt) — wszystkie są właścicielami prowincji w `religions_historical.json`. **NIE używaj** `judaizm`, `hinduizm`, `buddyzm`, `manicheizm` jako defenderów — nie mają prowincji i `provinces_with_owner(...)` zwróci pustą tablicę.

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/WarManager.gd tests/engine/test_war_manager.gd
git commit -m "feat: holy war alliance +15% bonus in compute_army_strength (Plan 07)"
```

---

## Chunk 4: Wasalskie auto-join koalicji i integracja TurnManager (Task 6)

### Task 6: `auto_join_vassals_to_coalitions` + `TurnManager._process_diplomacy`

**Files:**
- Modify: `scripts/engine/DiplomacyManager.gd` — dodaj funkcję `auto_join_vassals_to_coalitions` (po `auto_join_allies_to_coalitions`, linia ~222)
- Modify: `scripts/engine/TurnManager.gd:128-135` (`_process_diplomacy` — wstrzyknij wywołanie)
- Test: `tests/engine/test_diplomacy_manager.gd` (dodaj na końcu)

- [ ] **Step 1: Napisz failing testy**

Dodaj na końcu `tests/engine/test_diplomacy_manager.gd`:

```gdscript
# --- auto_join_vassals_to_coalitions (Plan 07) ---

func _make_coalition_against(gs: Node, target_id: String, members: Array[String]) -> Coalition:
    var c := Coalition.new()
    c.target_id = target_id
    c.members = members.duplicate()
    gs.active_coalitions.append(c)
    return c

func test_vassal_auto_join_client_follows_patron_in_members() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var client: Religion = gs.get_religion("judaizm")
    client.suzerain_id = "chr_zachodnie"  # patron = chr_zachodnie
    var c := _make_coalition_against(gs, "islam", ["chr_zachodnie", "hinduizm"] as Array[String])
    dm.auto_join_vassals_to_coalitions(gs)
    assert_true("judaizm" in c.members, "klient dołączył bo patron jest w members")
    assert_eq(c.members.size(), 3, "dokładnie 3 członków (poprzedni + klient)")

func test_vassal_auto_join_skips_when_patron_not_in_members() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var client: Religion = gs.get_religion("judaizm")
    client.suzerain_id = "chr_zachodnie"
    var c := _make_coalition_against(gs, "islam", ["hinduizm", "buddyzm"] as Array[String])
    dm.auto_join_vassals_to_coalitions(gs)
    assert_false("judaizm" in c.members, "patron nie jest w koalicji → klient nie dołącza")

func test_vassal_auto_join_skips_when_client_already_member() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var client: Religion = gs.get_religion("judaizm")
    client.suzerain_id = "chr_zachodnie"
    var c := _make_coalition_against(gs, "islam", ["chr_zachodnie", "judaizm"] as Array[String])  # klient już jest
    var members_before: int = c.members.size()
    dm.auto_join_vassals_to_coalitions(gs)
    assert_eq(c.members.size(), members_before, "idempotentne — bez duplikatów")

func test_vassal_auto_join_skips_when_client_is_coalition_target() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var client: Religion = gs.get_religion("judaizm")
    client.suzerain_id = "chr_zachodnie"
    var c := _make_coalition_against(gs, "judaizm", ["chr_zachodnie", "hinduizm"] as Array[String])  # klient JEST target
    dm.auto_join_vassals_to_coalitions(gs)
    assert_false("judaizm" in c.members, "klient nie może być w members swojej własnej koalicji-target")

func test_vassal_auto_join_skips_when_patron_is_coalition_target() -> void:
    # Brzegowy przypadek z spec sek.2: jeśli patron jest target_id (poza members),
    # klient nie zostaje wciągany do members. W praktyce patron nie pojawi się w `snapshot`,
    # więc warunek `client.suzerain_id == member_id` nie sparuje. Test weryfikuje że nawet
    # gdyby się to zdarzyło, dodatkowy guard `client.suzerain_id == c.target_id` blokuje.
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var client: Religion = gs.get_religion("judaizm")
    client.suzerain_id = "chr_zachodnie"
    # Patologiczna konfiguracja (normalnie evaluate_coalitions tego nie tworzy):
    # patron jest target_id, ale przypadkiem ktoś dał go też w members.
    var c := _make_coalition_against(gs, "chr_zachodnie", ["chr_zachodnie", "hinduizm"] as Array[String])
    dm.auto_join_vassals_to_coalitions(gs)
    assert_false("judaizm" in c.members, "klient nie atakuje swojego patrona")

func test_vassal_auto_join_skips_when_patron_null() -> void:
    # Jeśli suzerain_id wskazuje na nieistniejącą religię, klient nie podąża.
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var client: Religion = gs.get_religion("judaizm")
    client.suzerain_id = "nieistniejacy_patron"
    var c := _make_coalition_against(gs, "islam", ["nieistniejacy_patron", "hinduizm"] as Array[String])
    dm.auto_join_vassals_to_coalitions(gs)
    assert_false("judaizm" in c.members, "klient z null patron nie dołącza")

func test_vassal_auto_join_one_level_propagation_only() -> void:
    # Klient klienta NIE jest dodawany w tej samej turze.
    # Setup: patron P, klient A (suzerain = P), klient B (suzerain = A).
    # Po dodaniu A przez snapshot, B nie powinien być wciągnięty (iteruje się tylko po SNAPSHOT).
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var a: Religion = gs.get_religion("judaizm")
    a.suzerain_id = "chr_zachodnie"
    var b: Religion = gs.get_religion("zoroastryzm")
    b.suzerain_id = "judaizm"
    var c := _make_coalition_against(gs, "islam", ["chr_zachodnie", "hinduizm"] as Array[String])
    dm.auto_join_vassals_to_coalitions(gs)
    assert_true("judaizm" in c.members, "klient pierwszego poziomu (A) dołącza")
    assert_false("zoroastryzm" in c.members, "klient drugiego poziomu (B) NIE dołącza w tej samej turze")

func test_vassal_auto_join_no_active_coalitions_noop() -> void:
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var client: Religion = gs.get_religion("judaizm")
    client.suzerain_id = "chr_zachodnie"
    # Brak koalicji w state.active_coalitions
    dm.auto_join_vassals_to_coalitions(gs)
    assert_eq(gs.active_coalitions.size(), 0, "no-op gdy brak koalicji")
```

- [ ] **Step 2: Uruchom testy — sprawdź FAIL**

Run:
```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
Expected: 8 nowych testów FAIL — metoda `auto_join_vassals_to_coalitions` nie istnieje ("Invalid call. Nonexistent function").

- [ ] **Step 3: Dodaj funkcję `auto_join_vassals_to_coalitions` w `DiplomacyManager.gd`**

W `scripts/engine/DiplomacyManager.gd`, po funkcji `auto_join_allies_to_coalitions` (linia ~222), dodaj:

```gdscript

func auto_join_vassals_to_coalitions(state: Node) -> void:
    # Plan 07 sek.2: klient z `suzerain_id` automatycznie dołącza do koalicji, w której jest jego patron.
    # Snapshot zapobiega kaskadzie: tylko obecni członkowie z momentu wywołania mogą wciągać wasali
    # (1 poziom propagacji per tura).
    for c: Coalition in state.active_coalitions:
        var snapshot: Array[String] = []
        for m: String in c.members:
            snapshot.append(m)
        for member_id: String in snapshot:
            if member_id == c.target_id:
                continue
            for client: Religion in state.all_religions():
                if client.suzerain_id != member_id:
                    continue
                if state.get_religion(client.suzerain_id) == null:
                    continue  # patron usunięty z gry — klient osierocony nie podąża
                if client.suzerain_id == c.target_id:
                    continue  # vetto: klient nie atakuje swojego patrona
                if client.id == c.target_id:
                    continue  # klient nie jest członkiem swojej własnej koalicji
                if client.id in c.members:
                    continue  # idempotentność — brak duplikatów
                c.members.append(client.id)
```

- [ ] **Step 4: Uruchom testy unit — sprawdź PASS**

Expected: 8 nowych testów PASS (na razie bez wywołania w TurnManager).

- [ ] **Step 5: Wstrzyknij wywołanie w `TurnManager._process_diplomacy`**

W `scripts/engine/TurnManager.gd`, znajdź `func _process_diplomacy` (linia ~128). Aktualnie:

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

Zmień na (wstaw nowe wywołanie między allies i dissolve):

```gdscript
func _process_diplomacy(state: Node) -> void:
    var dm := DiplomacyManager.new()
    for rel: RelationState in state.relations:
        if not _pair_in_active_war(state, rel.religion_a_id, rel.religion_b_id):
            rel.military_tension = clampf(rel.military_tension - DiplomacyManager.PEACE_TENSION_DECAY_PER_TURN, 0.0, 100.0)
    dm.evaluate_coalitions(state)
    dm.auto_join_allies_to_coalitions(state)
    dm.auto_join_vassals_to_coalitions(state)
    dm.dissolve_coalitions(state)
```

Kolejność: najpierw sojusznicy przez `alliance_active` (Plan 04), potem wasale przez `suzerain_id` (Plan 07). Wasale wciągnięci w tej turze NIE wciągają swoich sojuszników (snapshot pochodzi z `members` PRZED dodaniem wasali w bieżącej iteracji).

- [ ] **Step 6: Uruchom testy — sprawdź PASS**

Run pełny suite:
```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
Expected: brak regresji w `_process_diplomacy` testach (Plan 04-06 testy nadal PASS).

Częste pułapki:
- Kolejność wywołań ma znaczenie: jeśli `auto_join_vassals_to_coalitions` zostanie PRZED `auto_join_allies_to_coalitions`, sojusznicy klientów (dodanych przez vassal) NIE zostaną wciągnięci — to też jest jednopoziomowo, więc OK ale spójność z spec wymaga `allies → vassals → dissolve`.
- Jeśli postawisz `dm.auto_join_vassals_to_coalitions(state)` PO `dm.dissolve_coalitions(state)` — wasale dodadzą się do koalicji już oznaczonych do rozwiązania w tej turze. Funkcjonalnie szkody nie ma (koalicja w następnej turze przejdzie przez dissolve znowu), ale jest niespójne ze spec.

- [ ] **Step 7: Commit**

```bash
git add scripts/engine/DiplomacyManager.gd scripts/engine/TurnManager.gd tests/engine/test_diplomacy_manager.gd
git commit -m "feat: auto_join_vassals_to_coalitions + TurnManager integration (Plan 07)"
```

---

## Chunk 5: Integration tests (Task 7)

### Task 7: Trzy integration testy — pełne cykle Plan 07

**Files:**
- Test: `tests/engine/test_war_manager.gd` (dodaj 2 integration testy na końcu)
- Test: `tests/engine/test_diplomacy_manager.gd` (dodaj 1 integration test na końcu)

- [ ] **Step 1: Napisz integration testy (failing only if poprzednie tasks nie kompletne)**

W `tests/engine/test_war_manager.gd`, dodaj na końcu:

```gdscript
# --- INTEGRATION TESTS (Plan 07) ---

const TurnManagerScript := preload("res://scripts/engine/TurnManager.gd")

func test_integration_interdict_to_rewanz_cycle() -> void:
    # Spec sek.6 (Cykl Interdykt → Rewanż):
    # 1. islam rzuca Interdykt na judaizm (judaizm ma C<30 → kwalifikuje się do Rewanżu)
    # 2. Grievance ustawione na judaizm
    # 3. Przewijamy 5 tur — grievance nadal aktywne
    # 4. judaizm deklaruje wojnę Rewanż przeciw islam — sukces
    # 5. Grievance zerowane
    # 6. Kolejna próba Rewanżu blokowana (jednorazowy)
    var gs := _make_state()
    var dm := DiplomacyManager.new()
    var wm := WarManager.new()
    var tm := TurnManagerScript.new()

    var attacker: Religion = gs.get_religion("islam")
    var victim: Religion = gs.get_religion("judaizm")
    _pin_axes(victim, 50.0, 50.0, 20.0, 50.0)  # C=20 → Ekskluzywizm 80
    attacker.prestige = 100
    victim.prestige = 100

    # 1. Interdykt
    assert_true(dm.proclaim_interdict(gs, "islam", "judaizm"))
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
    var war := wm.declare_war("judaizm", "islam", "rewanz", gs)
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
    # Defenderzy: chr_wschodnie (owns 5 prowincji) i koptyjski (owns egipt) — religie WŁAŚCICIELE
    # prowincji w danych historycznych. Target_province pobierany przez get_province(id).
    var gs := _make_state()
    var wm := WarManager.new()
    var dm := DiplomacyManager.new()

    var x: Religion = gs.get_religion("islam")
    var y: Religion = gs.get_religion("zoroastryzm")
    _pin_axes(x, 50.0, 50.0, 20.0, 70.0)   # D=70, C=20 (Ekskluzywizm 80) → dzihad OK + HolyWar OK
    _pin_axes(y, 50.0, 50.0, 20.0, 70.0)   # D=70 → dzihad OK + HolyWar OK

    x.prestige = 100
    y.prestige = 100
    var rel := dm.get_or_create_relation(gs, "islam", "zoroastryzm")
    rel.alliance_active = true

    var warX := wm.declare_war("islam", "chr_wschodnie", "dzihad", gs)
    var warY := wm.declare_war("zoroastryzm", "koptyjski", "dzihad", gs)
    assert_not_null(warX)
    assert_not_null(warY)

    # Bonus dla X — atakuje province chr_wschodnie (armenia, mountains)
    var provX: Province = gs.province_graph.get_province("armenia")
    var strX_with := wm.compute_army_strength(x, provX, warX, gs)

    # Bonus dla Y — atakuje province koptyjski (egipt)
    var provY: Province = gs.province_graph.get_province("egipt")
    var strY_with := wm.compute_army_strength(y, provY, warY, gs)

    # Zerwij sojusz — siła powinna spaść dla obu
    rel.alliance_active = false
    var strX_without := wm.compute_army_strength(x, provX, warX, gs)
    var strY_without := wm.compute_army_strength(y, provY, warY, gs)

    assert_gt(strX_with, strX_without, "X dostaje bonus przy sojuszu w dzihad")
    assert_gt(strY_with, strY_without, "Y dostaje bonus przy sojuszu w dzihad")
```

W `tests/engine/test_diplomacy_manager.gd`, dodaj na końcu:

```gdscript
# --- INTEGRATION TEST: Vassal auto-join przez TurnManager (Plan 07) ---

func test_integration_vassal_auto_join_in_turn_manager_pipeline() -> void:
    # Spec sek.6 (Cykl wasalskie auto-join):
    # 1. Agresor G atakuje victim V — tworzy się tension, ale koalicja jeszcze nie powstaje (potrzebne threat>=50).
    # 2. G atakuje też drugą religię — threat=40 (atak)+? Plus military_tension ofiar.
    # Setup: aggressor "islam" prowadzi 3 ofensywne wojny → threat_index >= 50 (3*20 = 60).
    # Patron "chr_zachodnie" ma tension >= 40 (ręcznie ustawione) → kwalifikuje się jako member.
    # Klient "judaizm" ma suzerain_id="chr_zachodnie".
    # Po process_turn, auto_join_vassals_to_coalitions powinno dodać judaizm do koalicji wraz z patronem.
    var gs := _make_state()
    var tm := TurnManagerScript.new()
    var dm := DiplomacyManager.new()
    var wm := WarManager.new()

    var aggressor: Religion = gs.get_religion("islam")
    var victim1: Religion = gs.get_religion("hinduizm")
    var victim2: Religion = gs.get_religion("buddyzm")
    var victim3: Religion = gs.get_religion("religie_arabskie")
    var patron: Religion = gs.get_religion("chr_zachodnie")
    var client: Religion = gs.get_religion("judaizm")

    aggressor.prestige = 1000
    _pin_axes(aggressor, 50.0, 50.0, 20.0, 30.0)  # Ekskluzywizm + Doczesność → krucjata

    # 3 ofensywne wojny — threat_index = 60 >= COALITION_THREAT_THRESHOLD (50)
    var w1 := wm.declare_war("islam", "hinduizm", "krucjata", gs)
    var w2 := wm.declare_war("islam", "buddyzm", "krucjata", gs)
    var w3 := wm.declare_war("islam", "religie_arabskie", "krucjata", gs)
    assert_not_null(w1)
    assert_not_null(w2)
    assert_not_null(w3)

    # Patron ma tension >= 40 (kwalifikuje się jako member)
    var rel_patron_aggressor := dm.get_or_create_relation(gs, "chr_zachodnie", "islam")
    rel_patron_aggressor.military_tension = 45.0

    # Druga religia spoza wasalstwa ma tension >= 40 (żeby members.size() >= 2 wymagane w evaluate_coalitions)
    var rel_other_aggressor := dm.get_or_create_relation(gs, "zoroastryzm", "islam")
    rel_other_aggressor.military_tension = 45.0

    # Klient ma patrona, ale sam ma niskie tension (więc nie kwalifikuje się jako "naturalny" member)
    var rel_client_aggressor := dm.get_or_create_relation(gs, "judaizm", "islam")
    rel_client_aggressor.military_tension = 10.0  # poniżej progu 40
    client.suzerain_id = "chr_zachodnie"

    # Process turn — evaluate_coalitions tworzy koalicję, auto_join_vassals dołącza klienta
    tm.process_turn(gs)

    assert_eq(gs.active_coalitions.size(), 1, "powstała 1 koalicja przeciw islam")
    var c: Coalition = gs.active_coalitions[0]
    assert_eq(c.target_id, "islam")
    assert_true("chr_zachodnie" in c.members, "patron w members (przez tension)")
    assert_true("judaizm" in c.members, "klient w members (przez auto-join wasala)")
    # Sanity: klient nadal ma niskie własne tension (auto-join działa niezależnie od tego).
    # Po process_turn military_tension JEST modyfikowany (PEACE_TENSION_DECAY_PER_TURN -1 gdy nie ma wojny pary).
    # Klient w teście nie ma wojny z aggressorem, więc tension spadnie z 10 do 9 (>= 0, < COALITION_MEMBER_TENSION_THRESHOLD=40).
    assert_lt(rel_client_aggressor.military_tension, DiplomacyManager.COALITION_MEMBER_TENSION_THRESHOLD,
              "klient ma niskie tension — nie wszedłby do koalicji przez własne napięcie")
```

Klucz testu: klient dołączył do koalicji **mimo niskiego własnego tension** (10), bo jego patron jest w members. Asercja `assert_lt(...)` to twardy dowód że nie wszedł przez own-tension path.

- [ ] **Step 2: Uruchom testy — sprawdź PASS lub debugify**

Run:
```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Częste pułapki:
- `_update_faction_tensions` w `TurnManager.process_turn` modyfikuje **`faction.tension`** (oś dominującej frakcji), NIE `RelationState.military_tension`. To dwa różne pola. Klient zachowa swoje ustawione `military_tension = 10`.
- W `_process_diplomacy` jest natomiast `rel.military_tension -= PEACE_TENSION_DECAY_PER_TURN (1.0)` dla par bez aktywnej wojny — czyli klient↔aggressor straci 1 punkt tension po turze. Bezpiecznie ustawić start na 10 (po turze będzie 9, dalej < 40).
- Krucjata wymaga `C<=25` i `D<=40`. W setupie aggressora `_pin_axes(50, 50, 20, 30)` daje C=20 i D=30 — oba spełnione.
- Dżihad wymaga `C<=25` i `D>=70`. Bonus HolyWar wymaga `D>65`. Krucjata wymaga `D<=40` — wzajemnie wyklucza się z `D>65`, więc **w krucjacie bonus HolyWar nigdy się nie aktywuje gameplay'owo**. Testy używają wyłącznie `dzihad`. Stała `HOLY_WAR_CBS = ["krucjata", "dzihad"]` zostaje (zgodnie ze spec) — krucjata jest tam dla forward-compatibility (gdyby w przyszłości złagodzono warunek D).
- `provinces_with_owner` zwraca pustą tablicę jeśli `owner == ""`. Religie domyślne z `religions_historical.json` mają przypisane prowincje, więc to działa.
- Test `test_integration_interdict_to_rewanz_cycle` — wywołuje `tm.process_turn(gs)` 5 razy. `process_turn` może modyfikować inne stany (frakcje, prowincje, war_weariness). Jeśli któryś side-effect uniemożliwia kolejne fazy, isolate przez `gs.active_wars.clear()` przed `declare_war` w step 4.

- [ ] **Step 3: Final test suite — sprawdź wszystko**

Run pełny suite:
```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: WSZYSTKIE testy PASS (~294). Brak regresji w 262 testach z Plan 06 ani wcześniejszych.

- [ ] **Step 4: Commit**

```bash
git add tests/engine/test_war_manager.gd tests/engine/test_diplomacy_manager.gd
git commit -m "test: integration tests for Plan 07 (Interdykt→Rewanż, HolyWar allies, vassal auto-join)"
```

---

## Definition of Done — Plan 07

- [ ] `Religion` ma 2 nowe pola: `interdict_grievance_from_id: String = ""`, `interdict_grievance_until: int = 0`
- [ ] `DiplomacyManager.proclaim_interdict` ma:
  - Guard na początku: `if source_id == target_id: return false`
  - Zapis grievance przed `return true`: `target.interdict_grievance_from_id = source_id; target.interdict_grievance_until = state.current_turn + GRIEVANCE_WINDOW_TURNS` (gated `target != null`)
- [ ] `DiplomacyManager` ma 2 nowe stałe:
  - `GRIEVANCE_WINDOW_TURNS = 10`
  - `GRIEVANCE_EKSKLUZYWIZM_THRESHOLD = 30.0` (konsumowana cross-class w WarManager)
- [ ] `DiplomacyManager` ma nową metodę `auto_join_vassals_to_coalitions(state)` z guardami:
  - skip jeśli `member_id == c.target_id`
  - skip jeśli `client.suzerain_id != member_id`
  - skip jeśli `state.get_religion(client.suzerain_id) == null`
  - skip jeśli `client.suzerain_id == c.target_id`
  - skip jeśli `client.id == c.target_id`
  - skip jeśli `client.id in c.members` (idempotentność)
  - snapshot members przed iteracją (1 poziom propagacji)
- [ ] `WarManager.available_casus_belli` ma:
  - Nową sygnaturę `(attacker, defender, state)` (breaking change)
  - Reactive Rewanż gated przez: `state != null`, `attacker.id != defender.id`, `attacker.interdict_grievance_from_id == defender.id`, `attacker.interdict_grievance_until > state.current_turn`, `attacker.get_axis("C") < DiplomacyManager.GRIEVANCE_EKSKLUZYWIZM_THRESHOLD`
  - Wszystkie call-sites zaktualizowane (1 w `declare_war`, 7 w `tests/engine/test_war_manager.gd`)
- [ ] `WarManager.CB_BONUS["rewanz"] = 0.15`
- [ ] `WarManager.declare_war` ma blok zerowania grievance po `state.active_wars.append(war)`:
  - `if cb == "rewanz": attacker.interdict_grievance_from_id = ""; attacker.interdict_grievance_until = 0`
- [ ] `WarManager` ma 3 nowe stałe HolyWar:
  - `HOLY_WAR_ALLIANCE_AXIS_D_THRESHOLD = 65.0`
  - `HOLY_WAR_ALLIANCE_BONUS = 0.15`
  - `HOLY_WAR_CBS = ["krucjata", "dzihad"]`
- [ ] `WarManager.compute_army_strength` ma blok bonusu HolyWar między `AXIS_STRENGTH_MODIFIERS` a `cb_modifier`, z guardami `religion.id == war.attacker_id`, `war.casus_belli in HOLY_WAR_CBS`, `religion.get_axis("D") > HOLY_WAR_ALLIANCE_AXIS_D_THRESHOLD`, `_has_holy_war_ally(religion, state)`
- [ ] `WarManager` ma nowy helper `_has_holy_war_ally(religion, state) -> bool` przeglądający aktywne sojusze (rel.alliance_active) i wojny sojusznika w krucjacie/dżihadzie jako atakujący
- [ ] `TurnManager._process_diplomacy` wywołuje `dm.auto_join_vassals_to_coalitions(state)` między `auto_join_allies_to_coalitions` a `dissolve_coalitions`
- [ ] Integration testy weryfikują:
  - `test_integration_interdict_to_rewanz_cycle`: Interdykt → 5 tur → Rewanż declare → grievance zużyte → kolejny Rewanż blokowany
  - `test_integration_two_allies_in_parallel_holy_wars_both_get_bonus`: dwie religie D>65 (islam, zoroastryzm), alliance_active, deklarują dżihad przeciw province-owning defenderom → obie dostają +15%
  - `test_integration_vassal_auto_join_in_turn_manager_pipeline`: aggressor + 3 wojny → koalicja → patron w members → klient (suzerain_id) dołącza w tej samej turze przez auto-join
- [ ] Brak regresji w 262 istniejących testach
- [ ] Wszystkie nowe testy PASS (29 unit + 3 integration = 32 nowych)
- [ ] Brak magic numbers w nowych metodach — wszystkie wartości jako nazwane stałe

## Co NIE wchodzi do Plan 07 (odłożone)

- **`[Dołącz do potępienia]`** po Interdykcie — wymaga NPC decision system, AI gracze automatycznie wystawiający Interdykt po pierwszym → przyszłość
- **Wielokrotne grievance / historia zniewag** — Plan 07 trzyma tylko *ostatnią* zniewagę
- **Rewanż jako CB dla sojusznika victima** — tylko bezpośrednia ofiara Interdyktu może użyć Rewanżu
- **Bonus Transcendencji dla broniącego w krucjacie** — wyłącznie ofensywny
- **Multi-party wars / koalicja jako jeden warfront** — War pozostaje 1v1
- **Kumulacja kilku sojuszników D>65** — stały +15% niezależnie od liczby sojuszników
- **Auto-join klienta do sojuszu obronnego patrona** (poza koalicjami) — tylko koalicje
- **Rewanż dla Ekskluzywizm <=70** — sztywny próg C<30
- **+5 prestiżu/turę za >10 tur pokoju** — wymaga osobnego trackingu
- **UI Plan 07** — przyciski "[Rewanż za zniewagę]", "Sojusznicy w krucjacie" → dedykowany plan UI
- **Defensywne sprzątanie martwego grievance** (gdy `interdict_grievance_from_id` wskazuje na usuniętą religię) — YAGNI (nigdy nie zwróci CB)

---

**Następny plan:** `08-mechaniki-ui-dyplomacja.md` (proponowany) — dedykowany plan UI dyplomacji integrujący wszystkie akcje Plan 04-07: deklaracja Sojuszu/Soboru, [Rewanż za zniewagę] jako przycisk po Interdykcie, podgląd grievance w panelu relacji, lista wasali, koalicji i ich członków. Albo Plan 08 z konsumentami `Religion.resources` (zwerbowanie armii, sponsorowanie misjonarzy) — Plan 06 wprowadził strumień, nie ma jeszcze konsumenta.
