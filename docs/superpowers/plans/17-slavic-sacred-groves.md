# Plan 17 — Ziemia Świętych Gajów (Religie Słowiańskie) Implementation Plan

> **For Claude:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 12. i ostatnia unique victory. Dodać 7 prowincji Slavic heartland (arkona, gnieszno, morawy, panonia, gardariki, nowogrod, kijow) i unique victory "Ziemia Świętych Gajów" — kontrola wszystkich 7 prowincji + A≤30, B≤30 przez 20 tur. Mapa rośnie 19→26.

**Architecture:** Hybryda Plan 14 (counter+predykat+label) + Plan 15 (fixture expansion). (a) 7 nowych obiektów JSON + 1 mutual edge patch tracja.neighbors. (b) 4 stałe + counter `slavic_sacred_groves_turns` + per-religion gałąź `update_counters` + predykat `_slavic_sacred_groves_satisfied` + klauzula `evaluate_unique_victory`. (c) `REASON_LABELS["slavic_sacred_groves"]`. (d) UI count patches 19→26 + CLAUDE.md.

**Tech Stack:** Godot 4.6.3, GDScript 2.0, GUT (Godot Unit Testing).

**Spec:** [`docs/superpowers/specs/17-slavic-sacred-groves-design.md`](../specs/17-slavic-sacred-groves-design.md)

---

## Convention reminders (z [CLAUDE.md](../../../CLAUDE.md))

- **Tab indent** w `.gd` i `.tscn`. JSON używa spaces (existing pattern).
- **Stałe engine tunable** — testy referencują `VictoryManager.SLAVIC_*`, nie hardcoduj.
- **Identyfikatory ANGIELSKIE** — `slavic_sacred_groves`, prowincje `arkona`, `gnieszno` etc. (wszystkie lowercase ASCII; "gniezno" w polskim z ż, ale ID `gnieszno` — uzgodnione z spec §4.3). Polish display_names OK.
- **Brak nowych `class_name`** — Plan 17 nie dodaje skryptów.
- **`const Array[String]`** — nowy idiom w VictoryManager.gd. Test waliduje exact contents listy.

---

## Test command reference

```bash
# Cała suite (po Plan 16: 721; po Plan 17 oczekiwane ~743)
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# Pojedynczy plik testu
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_province_loader.gd -gexit

# Subkatalog
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gexit
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gexit
```

---

## File Structure

**Modyfikowane (brak nowych plików):**

- `data/provinces_historical.json` — 7 nowych obiektów + patch `tracja.neighbors`.
- `scripts/engine/VictoryManager.gd` — 4 stałe + schema `+slavic_sacred_groves_turns` + gałąź `update_counters` + predykat + klauzula.
- `scripts/ui/dialogs/GameOverDialog.gd` — 1 wpis REASON_LABELS.
- `tests/engine/test_province_loader.gd` — 7 loader testów + 1 mutual edge + count guard 19→26.
- `tests/engine/test_victory_manager_constants.gd` — 1 nowy test.
- `tests/engine/test_victory_manager_flags.gd` — 6 nowych testów (counter).
- `tests/engine/test_victory_manager_unique.gd` — 3 nowe testy (predykat).
- `tests/engine/test_victory_manager_endgame.gd` — 1 nowy test (integracja).
- `tests/ui/test_map_view.gd` — rename + asercja 19→26.
- `tests/ui/test_main_shell.gd` — asercja 19→26.
- `tests/ui/test_game_over_dialog.gd` — dodać `"slavic_sacred_groves"` do reasons + label assertion test.
- `CLAUDE.md` — cross-reference + count update 19→26.

**Mapa: spec § → Task**

| Spec § | Task |
|---|---|
| §4.2 arkona | 1 |
| §4.3 gnieszno | 2 |
| §4.4 morawy | 3 |
| §4.5 panonia + mutual edge tracja | 4 |
| §4.6 gardariki | 5 |
| §4.7 nowogrod | 6 |
| §4.8 kijow + count guard 26 | 7 |
| §5.3 stałe | 8 |
| §5.5 counter + gałąź | 9 |
| §5.6/§5.7 predykat + klauzula | 10 |
| §3 endgame integracja | 11 |
| §5.8 UI label | 12 |
| §3 UI count patches 19→26 | 13 |
| §3 CLAUDE.md | 14 |

---

## Pre-flight: zweryfikuj baseline

- [ ] **Step 1: Cała suite musi pass przed Plan 17**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: ~721 testów pass (baseline z Plan 16).

- [ ] **Step 2: Sprawdź obecne pozycje istniejących prowincji** (Plan 15 cleanup state)

```bash
grep -n "tracja\|konstantynopol\|italia_polnocna" data/provinces_historical.json | head
```

Expected:
- tracja `{"x": 200, "y": 60}`
- konstantynopol `{"x": 280, "y": 100}`
- italia_polnocna `{"x": 100, "y": 120}`

To kluczowe dla Plan 17 §4.11 non-collision constraint.

- [ ] **Step 3: Sprawdź istniejący count test (jeśli istnieje)**

```bash
grep -n "test_provinces_total_count\|all_provinces().size()\|province_count() == 19" tests/engine/test_province_loader.gd
```

Expected: `test_provinces_total_count_19` (Plan 15 Task 4 guard).

---

## Task 1: Prowincja `arkona` (holy site)

**Cel:** Dodać arkona — holy site Slavic Paganism, far-NW (Rugia). Pierwsza z 7 nowych prowincji.

**Files:**
- Modify: `data/provinces_historical.json` (po prowincji `tracja`, przed zamykającym `]`)
- Modify: `tests/engine/test_province_loader.gd` (nowy loader test)

- [ ] **Step 1: Napisz failing test**

W `tests/engine/test_province_loader.gd` (na końcu pliku):

```gdscript
# === Plan 17: Slavic heartland ===

func test_loader_loads_arkona_with_holy_site_and_slavic_owner() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	var arkona := graph.get_province("arkona")
	assert_not_null(arkona, "Plan 17: arkona powinna istnieć")
	assert_eq(arkona.display_name, "Arkona")
	assert_eq(arkona.owner, "slavic_paganism")
	assert_eq(arkona.population, 200)
	assert_eq(arkona.terrain, "coast")
	assert_true(arkona.is_holy_site, "arkona jest holy site Slavic")
	assert_eq(arkona.pressure.get("slavic_paganism", 0.0), 80.0)
	assert_eq(arkona.resources.get("food", 0), 1)
	assert_eq(arkona.resources.get("gold", 0), 2)
	assert_eq(arkona.neighbors.size(), 1)
	assert_true("gnieszno" in arkona.neighbors)
```

- [ ] **Step 2: Run — expect FAIL**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_province_loader.gd -gexit
```

- [ ] **Step 3: Dodaj prowincję do JSON**

W `data/provinces_historical.json` po `tracja` (Plan 15) dodaj przecinek po tracja i:

```json
{"id": "arkona", "display_name": "Arkona", "owner": "slavic_paganism",
 "pressure": {"slavic_paganism": 80.0}, "population": 200,
 "resources": {"food": 1, "gold": 2}, "terrain": "coast",
 "neighbors": ["gnieszno"], "is_holy_site": true,
 "position": {"x": 40, "y": 0}}
```

**Uwaga:** brak przecinka po arkona (ostatni element przed `]`); Task 2 doda przecinek przy dodaniu gnieszno.

- [ ] **Step 4: Run — expect PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_province_loader.gd -gexit
```

- [ ] **Step 5: Commit**

```bash
git add data/provinces_historical.json tests/engine/test_province_loader.gd
git commit -m "feat(fixture): Plan 17 — prowincja arkona (Slavic Paganism, holy site)"
```

---

## Task 2: Prowincja `gnieszno`

**Cel:** Polanie / Wielkopolska. Centrum hub Slavic core, łączy arkona z resztą heartlandu.

**Files:**
- Modify: `data/provinces_historical.json`
- Modify: `tests/engine/test_province_loader.gd`

- [ ] **Step 1: Napisz failing test**

```gdscript
func test_loader_loads_gnieszno_slavic_owner_with_germanic_pressure_15() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	var gnieszno := graph.get_province("gnieszno")
	assert_not_null(gnieszno)
	assert_eq(gnieszno.display_name, "Gniezno")
	assert_eq(gnieszno.owner, "slavic_paganism")
	assert_eq(gnieszno.population, 280)
	assert_eq(gnieszno.terrain, "plains")
	assert_false(gnieszno.is_holy_site)
	assert_eq(gnieszno.pressure.get("slavic_paganism", 0.0), 70.0)
	assert_eq(gnieszno.pressure.get("germanic_paganism", 0.0), 15.0)
	assert_eq(gnieszno.resources.get("food", 0), 3)
	assert_eq(gnieszno.resources.get("gold", 0), 1)
	assert_true("arkona" in gnieszno.neighbors)
	assert_true("morawy" in gnieszno.neighbors)
	assert_true("gardariki" in gnieszno.neighbors)
```

- [ ] **Step 2: Run — expect FAIL**

- [ ] **Step 3: Dodaj prowincję**

Po `arkona` w JSON dodaj przecinek i:

```json
{"id": "gnieszno", "display_name": "Gniezno", "owner": "slavic_paganism",
 "pressure": {"slavic_paganism": 70.0, "germanic_paganism": 15.0}, "population": 280,
 "resources": {"food": 3, "gold": 1}, "terrain": "plains",
 "neighbors": ["arkona", "morawy", "gardariki"], "is_holy_site": false,
 "position": {"x": 140, "y": 10}}
```

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add data/provinces_historical.json tests/engine/test_province_loader.gd
git commit -m "feat(fixture): Plan 17 — prowincja gnieszno (Slavic Paganism)"
```

---

## Task 3: Prowincja `morawy`

**Cel:** Słowianie zachodni — przyszły Wielkomorawski region. Mountain terrain.

**Files:** identyczne pattern jak Task 2.

- [ ] **Step 1: Napisz failing test**

```gdscript
func test_loader_loads_morawy_slavic_owner_with_western_pressure_15() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	var morawy := graph.get_province("morawy")
	assert_not_null(morawy)
	assert_eq(morawy.display_name, "Morawy")
	assert_eq(morawy.owner, "slavic_paganism")
	assert_eq(morawy.population, 230)
	assert_eq(morawy.terrain, "mountains")
	assert_false(morawy.is_holy_site)
	assert_eq(morawy.pressure.get("slavic_paganism", 0.0), 65.0)
	assert_eq(morawy.pressure.get("western_christianity", 0.0), 15.0)
	assert_eq(morawy.resources.get("food", 0), 2)
	assert_eq(morawy.resources.get("gold", 0), 1)
	assert_true("gnieszno" in morawy.neighbors)
	assert_true("panonia" in morawy.neighbors)
```

- [ ] **Step 2: Run — expect FAIL**

- [ ] **Step 3: Dodaj prowincję**

```json
{"id": "morawy", "display_name": "Morawy", "owner": "slavic_paganism",
 "pressure": {"slavic_paganism": 65.0, "western_christianity": 15.0}, "population": 230,
 "resources": {"food": 2, "gold": 1}, "terrain": "mountains",
 "neighbors": ["gnieszno", "panonia"], "is_holy_site": false,
 "position": {"x": 140, "y": 70}}
```

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add data/provinces_historical.json tests/engine/test_province_loader.gd
git commit -m "feat(fixture): Plan 17 — prowincja morawy (Slavic Paganism)"
```

---

## Task 4: Prowincja `panonia` + mutual edge `panonia ↔ tracja`

**Cel:** Pannonia — kluczowa prowincja, jedyne połączenie Slavic heartland z istniejącą mapą (panonia↔tracja).

**Files:**
- Modify: `data/provinces_historical.json` — dodać panonia + patch tracja.neighbors
- Modify: `tests/engine/test_province_loader.gd` — loader test + mutual edge test

- [ ] **Step 1: Napisz failing testy**

```gdscript
func test_loader_loads_panonia_slavic_owner_with_eastern_pressure_20() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	var panonia := graph.get_province("panonia")
	assert_not_null(panonia)
	assert_eq(panonia.display_name, "Panonia")
	assert_eq(panonia.owner, "slavic_paganism")
	assert_eq(panonia.population, 320)
	assert_eq(panonia.terrain, "plains")
	assert_false(panonia.is_holy_site)
	assert_eq(panonia.pressure.get("slavic_paganism", 0.0), 55.0)
	assert_eq(panonia.pressure.get("eastern_christianity", 0.0), 20.0)
	assert_eq(panonia.resources.get("food", 0), 3)
	assert_eq(panonia.resources.get("gold", 0), 2)
	assert_true("morawy" in panonia.neighbors)
	assert_true("gardariki" in panonia.neighbors)
	assert_true("tracja" in panonia.neighbors)

func test_panonia_tracja_mutual_edge() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	var panonia := graph.get_province("panonia")
	var tracja := graph.get_province("tracja")
	assert_not_null(panonia)
	assert_not_null(tracja)
	assert_true("tracja" in panonia.neighbors, "panonia.neighbors zawiera tracja")
	assert_true("panonia" in tracja.neighbors, "tracja.neighbors zawiera panonia (Task 4 patch)")
```

- [ ] **Step 2: Run — expect FAILS**

Expected: `test_loader_loads_panonia_...` fail (panonia missing). `test_panonia_tracja_mutual_edge` fail (tracja.neighbors == ["konstantynopol"]).

- [ ] **Step 3: Dodaj panonia**

```json
{"id": "panonia", "display_name": "Panonia", "owner": "slavic_paganism",
 "pressure": {"slavic_paganism": 55.0, "eastern_christianity": 20.0}, "population": 320,
 "resources": {"food": 3, "gold": 2}, "terrain": "plains",
 "neighbors": ["morawy", "gardariki", "tracja"], "is_holy_site": false,
 "position": {"x": 260, "y": 10}}
```

- [ ] **Step 4: Patch `tracja.neighbors`**

W `data/provinces_historical.json` znajdź tracja (Plan 15):

```json
{"id": "tracja", ..., "neighbors": ["konstantynopol"], ...}
```

Zmień na:

```json
{"id": "tracja", ..., "neighbors": ["konstantynopol", "panonia"], ...}
```

- [ ] **Step 5: Run — expect PASS**

- [ ] **Step 6: Commit**

```bash
git add data/provinces_historical.json tests/engine/test_province_loader.gd
git commit -m "feat(fixture): Plan 17 — panonia + mutual edge panonia↔tracja"
```

---

## Task 5: Prowincja `gardariki`

**Cel:** Wschodni Słowianie. Central hub eastern Slavic.

- [ ] **Step 1: Napisz failing test**

```gdscript
func test_loader_loads_gardariki_slavic_owner_no_minor_pressure() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	var gardariki := graph.get_province("gardariki")
	assert_not_null(gardariki)
	assert_eq(gardariki.display_name, "Gardariki")
	assert_eq(gardariki.owner, "slavic_paganism")
	assert_eq(gardariki.population, 250)
	assert_eq(gardariki.terrain, "plains")
	assert_false(gardariki.is_holy_site)
	assert_eq(gardariki.pressure.get("slavic_paganism", 0.0), 70.0)
	assert_eq(gardariki.pressure.size(), 1, "tylko slavic_paganism w pressure dict")
	assert_eq(gardariki.resources.get("food", 0), 2)
	assert_eq(gardariki.resources.get("gold", 0), 1)
	assert_true("gnieszno" in gardariki.neighbors)
	assert_true("panonia" in gardariki.neighbors)
	assert_true("nowogrod" in gardariki.neighbors)
	assert_true("kijow" in gardariki.neighbors)
```

- [ ] **Step 2: Run — expect FAIL**

- [ ] **Step 3: Dodaj prowincję**

```json
{"id": "gardariki", "display_name": "Gardariki", "owner": "slavic_paganism",
 "pressure": {"slavic_paganism": 70.0}, "population": 250,
 "resources": {"food": 2, "gold": 1}, "terrain": "plains",
 "neighbors": ["gnieszno", "panonia", "nowogrod", "kijow"], "is_holy_site": false,
 "position": {"x": 360, "y": 10}}
```

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add data/provinces_historical.json tests/engine/test_province_loader.gd
git commit -m "feat(fixture): Plan 17 — prowincja gardariki (Slavic Paganism)"
```

---

## Task 6: Prowincja `nowogrod`

**Cel:** Słowianie ilmeńscy, far-N coast.

- [ ] **Step 1: Napisz failing test**

```gdscript
func test_loader_loads_nowogrod_slavic_owner_coast() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	var nowogrod := graph.get_province("nowogrod")
	assert_not_null(nowogrod)
	assert_eq(nowogrod.display_name, "Nowogród")
	assert_eq(nowogrod.owner, "slavic_paganism")
	assert_eq(nowogrod.population, 220)
	assert_eq(nowogrod.terrain, "coast")
	assert_false(nowogrod.is_holy_site)
	assert_eq(nowogrod.pressure.get("slavic_paganism", 0.0), 75.0)
	assert_eq(nowogrod.resources.get("food", 0), 1)
	assert_eq(nowogrod.resources.get("gold", 0), 3)
	assert_true("gardariki" in nowogrod.neighbors)
	assert_true("kijow" in nowogrod.neighbors)
```

- [ ] **Step 2: Run — expect FAIL**

- [ ] **Step 3: Dodaj prowincję**

```json
{"id": "nowogrod", "display_name": "Nowogród", "owner": "slavic_paganism",
 "pressure": {"slavic_paganism": 75.0}, "population": 220,
 "resources": {"food": 1, "gold": 3}, "terrain": "coast",
 "neighbors": ["gardariki", "kijow"], "is_holy_site": false,
 "position": {"x": 460, "y": -40}}
```

**Uwaga:** y = −40 (negatywne) — Godot Control coords nie mają hard bound; MapView obsługuje. To celowa pozycja "far north".

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add data/provinces_historical.json tests/engine/test_province_loader.gd
git commit -m "feat(fixture): Plan 17 — prowincja nowogrod (Slavic Paganism)"
```

---

## Task 7: Prowincja `kijow` + count guard 26

**Cel:** Kijów — ostatnia z 7 prowincji. Po dodaniu — mapa ma 26 prowincji. Update count guard.

- [ ] **Step 1: Napisz failing testy**

```gdscript
func test_loader_loads_kijow_slavic_owner() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	var kijow := graph.get_province("kijow")
	assert_not_null(kijow)
	assert_eq(kijow.display_name, "Kijów")
	assert_eq(kijow.owner, "slavic_paganism")
	assert_eq(kijow.population, 300)
	assert_eq(kijow.terrain, "plains")
	assert_false(kijow.is_holy_site)
	assert_eq(kijow.pressure.get("slavic_paganism", 0.0), 65.0)
	assert_eq(kijow.resources.get("food", 0), 3)
	assert_eq(kijow.resources.get("gold", 0), 2)
	assert_true("gardariki" in kijow.neighbors)
	assert_true("nowogrod" in kijow.neighbors)
```

I update istniejącego count guarda z Plan 15:

```bash
grep -n "test_provinces_total_count_19\|province_count() == 19\|province_count(), 19" tests/engine/test_province_loader.gd
```

Znajdź i rename `test_provinces_total_count_19` → `test_provinces_total_count_26`, zmień asercję `19` → `26`.

- [ ] **Step 2: Run — expect FAIL**

Expected: kijow loader fail + count test fail (mapa ma 25 po Tasks 1-6, oczekuje 26 po Task 7).

Wait — after Tasks 1-6 (6 provinces dodane + 19 baseline) = 25. After Task 7 (kijow) = 26. So:
- Before Task 7 fixture change: 25 provinces. `count == 26` test fails.
- After Task 7 fixture change: 26 provinces. Both tests pass.

Or actually count guard test was renamed (rename + assertion change). Po rename ale przed dodaniem kijow: count == 25 ≠ 26, fail. Po Task 7 step 3: count == 26, pass.

- [ ] **Step 3: Dodaj kijow**

```json
{"id": "kijow", "display_name": "Kijów", "owner": "slavic_paganism",
 "pressure": {"slavic_paganism": 65.0}, "population": 300,
 "resources": {"food": 3, "gold": 2}, "terrain": "plains",
 "neighbors": ["gardariki", "nowogrod"], "is_holy_site": false,
 "position": {"x": 520, "y": 30}}
```

To **ostatni** element JSON — bez przecinka.

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add data/provinces_historical.json tests/engine/test_province_loader.gd
git commit -m "feat(fixture): Plan 17 — prowincja kijow + count guard 26"
```

---

## Task 8: 4 stałe Plan 17

**Cel:** Dodać stałe `SLAVIC_*` do `VictoryManager.gd`.

**Files:**
- Modify: `scripts/engine/VictoryManager.gd` (po sekcji Plan 16 stałych)
- Modify: `tests/engine/test_victory_manager_constants.gd`

- [ ] **Step 1: Napisz failing test**

```gdscript
# === Plan 17: stałe Slavic Sacred Groves ===

func test_plan17_constants_exist() -> void:
	# 7 prowincji w stałej liście (Array[String])
	var ids := VictoryManager.SLAVIC_SACRED_GROVES_IDS
	assert_eq(ids.size(), 7)
	assert_true("arkona" in ids)
	assert_true("gnieszno" in ids)
	assert_true("morawy" in ids)
	assert_true("panonia" in ids)
	assert_true("gardariki" in ids)
	assert_true("nowogrod" in ids)
	assert_true("kijow" in ids)
	assert_eq(VictoryManager.SLAVIC_AXIS_A_MAX, 30.0)
	assert_eq(VictoryManager.SLAVIC_AXIS_B_MAX, 30.0)
	assert_eq(VictoryManager.SLAVIC_SACRED_GROVES_TURNS_REQUIRED, 20)
```

- [ ] **Step 2: Run — expect FAIL (parse error)**

- [ ] **Step 3: Dodaj 4 stałe**

W `scripts/engine/VictoryManager.gd` po sekcji Plan 16 stałych (linia ~68), przed `# === Public API ===`, wstaw:

```gdscript

# === Plan 17: unikalne warunki — Slavic Paganism (Ziemia Świętych Gajów) ===
const SLAVIC_SACRED_GROVES_IDS: Array[String] = ["arkona", "gnieszno", "morawy", "panonia", "gardariki", "nowogrod", "kijow"]
const SLAVIC_AXIS_A_MAX := 30.0							# anti-dogmatism preserved (start 20, próg 30)
const SLAVIC_AXIS_B_MAX := 30.0							# anti-hierarchy preserved (start 25, próg 30)
const SLAVIC_SACRED_GROVES_TURNS_REQUIRED := 20			# trwałość 9 warunków przez 20 tur
```

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/VictoryManager.gd tests/engine/test_victory_manager_constants.gd
git commit -m "feat(victory): Plan 17 stałe — Slavic Sacred Groves"
```

---

## Task 9: Counter `slavic_sacred_groves_turns` + gałąź `update_counters`

**Cel:** Schema + per-religion gałąź. Pattern z Plan 14/16 ale z `for ... break` dla listy 7 prowincji.

**Files:**
- Modify: `scripts/engine/VictoryManager.gd` (schema + gałąź po Arabian)
- Modify: `tests/engine/test_victory_manager_flags.gd` (6 nowych testów)

- [ ] **Step 1: Napisz 6 failing testów**

```gdscript
# === Plan 17: slavic_sacred_groves_turns counter ===

func test_update_counters_initializes_slavic_sacred_groves_turns_zero() -> void:
	var gs := _make_state("slavic_paganism")
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("slavic_paganism", {})
	assert_eq(prog.get("slavic_sacred_groves_turns", -1), 0,
		"counter inicjuje się na 0 dla Slavic")

func test_update_counters_increments_slavic_sacred_groves_when_all_conditions_met() -> void:
	var gs := _make_state("slavic_paganism")
	var rel: Religion = gs.get_religion("slavic_paganism")
	# 7 prowincji już Slavic z fixture (Plan 17 Tasks 1-7).
	# Osie startowe: A=20, B=25 — oba ≤ 30 (warunki spełnione).
	assert_eq(rel.get_axis("A"), 20.0, "Slavic start A=20")
	assert_eq(rel.get_axis("B"), 25.0, "Slavic start B=25")
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("slavic_paganism", {})
	assert_eq(prog.get("slavic_sacred_groves_turns", 0), 1)
	vm.update_counters(gs)
	assert_eq(prog.get("slavic_sacred_groves_turns", 0), 2)

func test_update_counters_resets_slavic_sacred_groves_when_arkona_lost() -> void:
	var gs := _make_state("slavic_paganism")
	gs.victory_progress["slavic_paganism"] = {"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 0, "arabian_submission_turns": 0,
		"slavic_sacred_groves_turns": 5}
	gs.province_graph.get_province("arkona").owner = "western_christianity"  # utrata arkony
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("slavic_paganism", {})
	assert_eq(prog.get("slavic_sacred_groves_turns", -1), 0,
		"utrata arkony → reset (province at start of list)")

func test_update_counters_resets_slavic_sacred_groves_when_kijow_lost() -> void:
	# Sprawdza że pętla iteruje przez całą listę (kijow at end).
	var gs := _make_state("slavic_paganism")
	gs.victory_progress["slavic_paganism"] = {"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 0, "arabian_submission_turns": 0,
		"slavic_sacred_groves_turns": 5}
	gs.province_graph.get_province("kijow").owner = "islam"  # utrata kijów (end of list)
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("slavic_paganism", {})
	assert_eq(prog.get("slavic_sacred_groves_turns", -1), 0,
		"utrata kijow → reset (province at end of list — waliduje że for nie ranny-exit)")

func test_update_counters_resets_slavic_sacred_groves_when_axis_A_rises_to_31() -> void:
	var gs := _make_state("slavic_paganism")
	var rel: Religion = gs.get_religion("slavic_paganism")
	rel.axes["A"] = 31.0  # powyżej SLAVIC_AXIS_A_MAX=30
	gs.victory_progress["slavic_paganism"] = {"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 0, "arabian_submission_turns": 0,
		"slavic_sacred_groves_turns": 5}
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("slavic_paganism", {})
	assert_eq(prog.get("slavic_sacred_groves_turns", -1), 0, "A=31 → reset (próg ostry ≤30)")

func test_update_counters_only_increments_slavic_sacred_groves_for_slavic_paganism() -> void:
	# Inne religie nie inkrementują counter, nawet jeśli "spełniają" warunki.
	var gs := _make_state("islam")
	# Daj Islam wszystkie 7 prowincji + niskie A/B (symuluje warunki).
	for pid: String in VictoryManager.SLAVIC_SACRED_GROVES_IDS:
		gs.province_graph.get_province(pid).owner = "islam"
	var rel: Religion = gs.get_religion("islam")
	rel.axes["A"] = 20.0
	rel.axes["B"] = 20.0
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("islam", {})
	assert_eq(prog.get("slavic_sacred_groves_turns", -1), 0,
		"Islam nie inkrementuje slavic_sacred_groves_turns (religion-scoped)")
```

- [ ] **Step 2: Run testy — expect FAILS**

Expected: 6 testów fail z `prog.get("slavic_sacred_groves_turns", -1)` zwracającym `-1` (klucz nie istnieje).

- [ ] **Step 3: Rozszerz schema w `_ensure_progress_entry`**

W `scripts/engine/VictoryManager.gd` (linia ~162 po Plan 16):

Zmień:
```gdscript
_ensure_progress_entry(state.victory_progress, religion.id, {"domination_turns": 0, "prestige_hegemony_turns": 0, "dharma_turns": 0, "coptic_citadel_turns": 0, "arabian_submission_turns": 0})
```

Na:
```gdscript
_ensure_progress_entry(state.victory_progress, religion.id, {"domination_turns": 0, "prestige_hegemony_turns": 0, "dharma_turns": 0, "coptic_citadel_turns": 0, "arabian_submission_turns": 0, "slavic_sacred_groves_turns": 0})
```

- [ ] **Step 4: Dodaj gałąź `update_counters` dla Slavic**

Po Arabian gałąź (Plan 16, ~linia 238), przed `# Defeat counters`, wstaw:

```gdscript

		# Plan 17 §5.5: slavic_sacred_groves_turns — kontrola 7 prowincji + osie preserved.
		if religion.id == "slavic_paganism":
			var groves_active: bool = true
			# Warunek 1: kontrola wszystkich 7 prowincji (null guard każda).
			for pid: String in SLAVIC_SACRED_GROVES_IDS:
				var p: Province = state.province_graph.get_province(pid)
				if p == null or p.owner != religion.id:
					groves_active = false
					break
			# Warunki 2-3: osie A i B preserved (tylko jeśli groves_active wciąż true).
			if groves_active and religion.get_axis("A") > SLAVIC_AXIS_A_MAX:
				groves_active = false
			if groves_active and religion.get_axis("B") > SLAVIC_AXIS_B_MAX:
				groves_active = false
			if groves_active:
				state.victory_progress[religion.id]["slavic_sacred_groves_turns"] += 1
			else:
				state.victory_progress[religion.id]["slavic_sacred_groves_turns"] = 0
```

**Wzór:** Coptic/Arabian używają `elif` chain (one big chain). Plan 17 deviates z `for ... break` (lista) + następnie 2 osobne `if groves_active and ...` (nie da się zrobić elif po `for`).

- [ ] **Step 5: Run — expect PASS**

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/VictoryManager.gd tests/engine/test_victory_manager_flags.gd
git commit -m "feat(victory): Plan 17 counter slavic_sacred_groves_turns w update_counters"
```

---

## Task 10: Predykat `_slavic_sacred_groves_satisfied` + klauzula `evaluate_unique_victory`

**Cel:** Helper + klauzula match. Pattern z Plan 14/16.

**Files:**
- Modify: `scripts/engine/VictoryManager.gd` (klauzula + helper)
- Modify: `tests/engine/test_victory_manager_unique.gd` (3 nowe testy)

- [ ] **Step 1: Napisz 3 failing testy**

```gdscript
# === Plan 17: Slavic Sacred Groves ===

func test_slavic_sacred_groves_requires_20_turns_counter() -> void:
	var gs := _make_state("slavic_paganism")
	var rel: Religion = gs.get_religion("slavic_paganism")
	gs.victory_progress["slavic_paganism"] = {"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 0, "arabian_submission_turns": 0,
		"slavic_sacred_groves_turns": 20}
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "slavic_sacred_groves")

func test_slavic_sacred_groves_blocked_with_19_turns() -> void:
	var gs := _make_state("slavic_paganism")
	var rel: Religion = gs.get_religion("slavic_paganism")
	gs.victory_progress["slavic_paganism"] = {"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 0, "arabian_submission_turns": 0,
		"slavic_sacred_groves_turns": 19}
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "", "19 tur < 20 → brak victory")

func test_slavic_sacred_groves_other_religion_never_returns_reason() -> void:
	var gs := _make_state("islam")
	var rel: Religion = gs.get_religion("islam")
	gs.victory_progress["islam"] = {"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 0, "arabian_submission_turns": 0,
		"slavic_sacred_groves_turns": 30}
	var vm := VictoryManager.new()
	var result: String = vm.evaluate_unique_victory(rel, gs)
	assert_ne(result, "slavic_sacred_groves",
		"Islam nie może zwrócić slavic_sacred_groves (klauzula tylko dla slavic_paganism)")
```

- [ ] **Step 2: Run — expect FAILS**

- [ ] **Step 3: Dodaj klauzulę w `evaluate_unique_victory`**

Po klauzuli Arabian (Plan 16):

```gdscript
		"arabian_paganism":
			if _arabian_submission_satisfied(religion, state):
				return "arabian_submission"
```

Dodaj:

```gdscript
		"slavic_paganism":
			if _slavic_sacred_groves_satisfied(religion, state):
				return "slavic_sacred_groves"
```

- [ ] **Step 4: Dodaj helper `_slavic_sacred_groves_satisfied`**

Po `_arabian_submission_satisfied` (na końcu pliku):

```gdscript

func _slavic_sacred_groves_satisfied(religion: Religion, state: Node) -> bool:
	# Plan 17 §5.6: counter slavic_sacred_groves_turns aktualizowany w update_counters.
	# Pattern z _arabian_submission_satisfied i _coptic_citadel_satisfied.
	var vp: Dictionary = state.victory_progress.get(religion.id, {})
	return vp.get("slavic_sacred_groves_turns", 0) >= SLAVIC_SACRED_GROVES_TURNS_REQUIRED
```

- [ ] **Step 5: Run — expect PASS**

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/VictoryManager.gd tests/engine/test_victory_manager_unique.gd
git commit -m "feat(victory): Plan 17 predykat _slavic_sacred_groves_satisfied + klauzula"
```

---

## Task 11: Endgame integration test

**Cel:** Test integracyjny — pełen pipeline. Brak nowego kodu (Tasks 9+10 wystarczają).

**Files:**
- Modify: `tests/engine/test_victory_manager_endgame.gd`

- [ ] **Step 1: Napisz test**

```gdscript
# === Plan 17: integracja slavic_sacred_groves z check ===

func test_check_marks_slavic_sacred_groves_with_game_outcome() -> void:
	var gs := _make_state("slavic_paganism")
	# 7 prowincji Slavic z fixture, osie startowe A=20 B=25 (oba ≤ 30) — warunki spełnione.
	var vm := VictoryManager.new()
	for _i in range(VictoryManager.SLAVIC_SACRED_GROVES_TURNS_REQUIRED):
		vm.update_counters(gs)
		vm.check(gs)
	assert_not_null(gs.game_outcome, "game_outcome ustawione po 20 turach")
	assert_eq(gs.game_outcome.winner_id, "slavic_paganism")
	assert_eq(gs.game_outcome.reason, "slavic_sacred_groves")
```

- [ ] **Step 2: Run — expect PASS natychmiast**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_endgame.gd -gexit
```

Expected: test pass natychmiast (kod z Tasks 9+10 wystarcza).

- [ ] **Step 3: Commit**

```bash
git add tests/engine/test_victory_manager_endgame.gd
git commit -m "test(victory): Plan 17 integracja slavic_sacred_groves z game_outcome"
```

---

## Task 12: REASON_LABELS + UI label test

**Cel:** Polish label + reasons array + label assertion test (parytet z Plan 14/16).

**Files:**
- Modify: `scripts/ui/dialogs/GameOverDialog.gd` (po `arabian_submission`)
- Modify: `tests/ui/test_game_over_dialog.gd` (reasons array + nowy test)

- [ ] **Step 1: Zaktualizuj `reasons` array w `test_dialog_maps_all_reasons_to_non_empty_polish_labels`**

W `tests/ui/test_game_over_dialog.gd` znajdź `reasons` array. Dodaj `"slavic_sacred_groves"` na końcu z komentarzem:

```gdscript
var reasons := [..., 
    # Plan 16:
    "arabian_submission",
    # Plan 17:
    "slavic_sacred_groves"]
```

- [ ] **Step 2: Dodaj label assertion test**

Na końcu `tests/ui/test_game_over_dialog.gd`:

```gdscript

func test_slavic_sacred_groves_label_contains_polish_religion_name() -> void:
	var label: String = GameOverDialog.REASON_LABELS.get("slavic_sacred_groves", "")
	assert_ne(label, "", "slavic_sacred_groves ma etykietę")
	assert_true(label.findn("słowiańskie") != -1 or label.findn("slavic") != -1,
		"etykieta zawiera 'Słowiańskie' lub 'Slavic'")
	assert_true(label.findn("gaj") != -1, "etykieta zawiera 'Gaj' (Ziemia Świętych Gajów)")
```

- [ ] **Step 3: Run — expect FAILS**

Expected:
- `test_dialog_maps_all_reasons_to_non_empty_polish_labels` zaktualizowany, ale `slavic_sacred_groves` nie ma label → fail.
- `test_slavic_sacred_groves_label_contains_polish_religion_name` fail.

- [ ] **Step 4: Dodaj etykietę w `REASON_LABELS`**

W `scripts/ui/dialogs/GameOverDialog.gd` po linii Plan 16 (`"arabian_submission": "Przyjęcie Islamu (Religie Arabskie)",`):

```gdscript
	# Plan 17:
	"slavic_sacred_groves": "Ziemia Świętych Gajów (Religie Słowiańskie)",
```

- [ ] **Step 5: Run — expect PASS**

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/dialogs/GameOverDialog.gd tests/ui/test_game_over_dialog.gd
git commit -m "feat(ui): Plan 17 REASON_LABELS slavic_sacred_groves"
```

---

## Task 13: UI count patches 19→26

**Cel:** Zaktualizować 2 testy UI assertujące liczbę prowincji (z Plan 15).

**Files:**
- Modify: `tests/ui/test_map_view.gd`
- Modify: `tests/ui/test_main_shell.gd`

- [ ] **Step 1: Sprawdź lokalizacje**

```bash
grep -n "19" tests/ui/test_map_view.gd tests/ui/test_main_shell.gd
```

Expected (po Plan 15):
- `test_map_view.gd:20` — `func test_view_renders_19_province_nodes()`.
- `test_map_view.gd:24` — `assert_eq(mv.get_node_count(), 19)`.
- `test_main_shell.gd:73` — `assert_eq(..., 19)`.

- [ ] **Step 2: Run UI suite — expect FAILS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gexit
```

Expected: 2 testy fail (count 19 vs faktyczne 26 po Tasks 1-7).

- [ ] **Step 3: Patch `test_map_view.gd`**

- Rename: `test_view_renders_19_province_nodes` → `test_view_renders_26_province_nodes`.
- Asercja: `assert_eq(mv.get_node_count(), 19)` → `assert_eq(mv.get_node_count(), 26)`.

- [ ] **Step 4: Patch `test_main_shell.gd`**

Asercja `19` → `26`.

- [ ] **Step 5: Run — expect PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gexit
```

- [ ] **Step 6: Commit**

```bash
git add tests/ui/test_map_view.gd tests/ui/test_main_shell.gd
git commit -m "test(ui): Plan 17 — count prowincji 19→26"
```

---

## Task 14: CLAUDE.md cross-reference + count update

**Cel:** 1-liner Plan 17 + update count 19→26.

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Znajdź wzmianki**

```bash
grep -n "Plan 15\|Plan 16\|19 prowinc" CLAUDE.md
```

Expected: bullet "End-of-game flow" z Plan 12, 13, 14, 15, 16 + sekcja "Single source of truth" z "19 prowincji".

- [ ] **Step 2: Dopisz 1-liner po Plan 16**

W sekcji "End-of-game flow", po wzmiance Plan 16:

```
Plan 17 (`docs/superpowers/specs/17-slavic-sacred-groves-design.md`) dodaje 7 prowincji Slavic heartland (arkona, gnieszno, morawy, panonia, gardariki, nowogrod, kijow) i unikalny warunek "Ziemia Świętych Gajów" dla Religii Słowiańskich (kontrola wszystkich 7 + A≤30, B≤30 przez 20 tur) — mapa ma teraz 26 prowincji.
```

- [ ] **Step 3: Update "19 prowincji" → "26 prowincji"**

Jeśli grep w Step 1 zwrócił linię z "19 prowincji", zmień na "26 prowincji".

- [ ] **Step 4: Sanity grep**

```bash
grep -F "17-slavic-sacred-groves-design.md" CLAUDE.md
grep -E "16 prowinc|17 prowinc|18 prowinc|19 prowinc|20 prowinc|21 prowinc|22 prowinc|23 prowinc|24 prowinc|25 prowinc" CLAUDE.md
```

Expected:
- Pierwsza: 1 linia.
- Druga: 0 linii (no stale counts).

- [ ] **Step 5: Cała suite (sanity)**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: ~743 testów pass.

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: cross-reference do spec 17 + update count prowincji 19→26"
```

---

## Po wszystkich taskach

- [ ] **Final review**: dispatch `superpowers:code-reviewer` na pełen branch (~14 commitów Plan 17 + spec/plan). Reviewer sprawdza:
  - Spec compliance z `17-slavic-sacred-groves-design.md` (wszystkie 14 acceptance criteria z §8).
  - Code quality (tab indent, naming, brak magic numbers, brak hardkoded id, idempotencja, position non-collision).
  - Test coverage (~22 nowych testów + UI patches).
  - Brak regresji (~743 testów pass).
  - Konsystencja z Plan 14/15/16 (counter+predykat+label, fixture expansion, mutual edge).
  - Position visual check — node'y rendują się bez kolizji w editorze (manualny smoke test opcjonalny).

- [ ] **Po approval**: push do origin/master (bez PR, zgodnie z workflow projektu).

---

## Acceptance Criteria (z spec §8)

Plan 17 jest gotowy do merge gdy:

1. ✅ `data/provinces_historical.json` zawiera 26 prowincji, w tym 7 nowych słowiańskich (arkona, gnieszno, morawy, panonia, gardariki, nowogrod, kijow).
2. ✅ `tracja.neighbors` zawiera `["konstantynopol", "panonia"]` (mutual edge).
3. ✅ Wszystkie 7 nowych prowincji ma `owner == "slavic_paganism"`.
4. ✅ `arkona.is_holy_site == true`; pozostałe 6 słowiańskich ma `is_holy_site == false`.
5. ✅ 4 stałe Plan 17 istnieją w `VictoryManager.gd`.
6. ✅ Counter `slavic_sacred_groves_turns` poprawnie inkrementuje/resetuje per spec §5.5.
7. ✅ `evaluate_unique_victory` dla Slavic z counter ≥ 20 zwraca `"slavic_sacred_groves"`.
8. ✅ `game_outcome.winner_id == "slavic_paganism"` AND `reason == "slavic_sacred_groves"` po `check()`.
9. ✅ `REASON_LABELS["slavic_sacred_groves"]` zawiera "Ziemia Świętych Gajów" i "Religie Słowiańskie".
10. ✅ Pre-existing testy Plan 12/13/14/15/16 — pass (poza UI count 19→26).
11. ✅ ~22 nowych testów + UI patches — pass.
12. ✅ Cała suite (~743) pass.
13. ✅ Brak ghost edges (allowlist `[]`).
14. ✅ `CLAUDE.md` wzmiankuje Plan 17 + count = 26.
