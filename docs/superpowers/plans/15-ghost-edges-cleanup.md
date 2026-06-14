# Plan 15 — Naprawa pozostałych ghost edges Implementation Plan

> **For Claude:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dodać 3 prowincje do fixture'a mapy historycznej (jemen, italia_polnocna, tracja) zamykając wszystkie znane ghost edges. Mapa rośnie z 16 do 19 prowincji. Zero zmian w logice engine — wyłącznie JSON fixture + test allowlist + UI count patches.

**Architecture:** (a) `data/provinces_historical.json` — 3 nowe obiekty prowincji + 1 patch `abisynia.neighbors` (dodanie `jemen` jako mutual edge). (b) `tests/engine/test_province_graph.gd` — allowlist `[]` + 3 negative assertions analogiczne do `afryka_polnocna` z Plan 14. (c) Patche istniejących testów UI (`test_map_view.gd`, `test_main_shell.gd`) z `16` → `19`. (d) Cross-reference w `CLAUDE.md`.

**Tech Stack:** Godot 4.6.3, GDScript 2.0, GUT (Godot Unit Testing).

**Spec:** [`docs/superpowers/specs/15-ghost-edges-cleanup-design.md`](../specs/15-ghost-edges-cleanup-design.md)

---

## Convention reminders (z [CLAUDE.md](../../../CLAUDE.md))

- **Tab indent** w `.gd` i `.tscn`. JSON nie ma tabów w obecnym fixturze — używa spaces; trzymaj się tej konwencji.
- **Stałe engine tunable** — Plan 15 nie dodaje stałych ani logiki engine, więc ten punkt nie ma zastosowania.
- **Identyfikatory ANGIELSKIE** — `jemen`, `italia_polnocna`, `tracja` — wszystkie lowercase ASCII. Display names polskie: `"Jemen"`, `"Italia Północna"`, `"Tracja"`. Zgodne z memory `feedback_english_identifiers.md`.
- **Province ID format** — lowercase ASCII; polskie znaki odpada (np. `italia_polnocna`, nie `italia_północna`).
- **Brak nowych `class_name`** — Plan 15 nie dodaje skryptów, `.godot/global_script_class_cache.cfg` nie wymaga regeneracji.

---

## Test command reference

```bash
# Cała suite (po Plan 14: 709; po Plan 15 oczekiwane ~714-715)
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# Pojedynczy plik testu (zawsze res://-absolutna ścieżka)
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_province_loader.gd -gexit

# Subkatalog
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gexit
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gexit
```

---

## File Structure

**Modyfikowane (brak nowych plików):**

- `data/provinces_historical.json` — 3 nowe prowincje (jemen, italia_polnocna, tracja) + patch `abisynia.neighbors` (`["egipt"]` → `["egipt", "jemen"]`).
- `tests/engine/test_province_loader.gd` — 4 nowe testy (jemen, italia_polnocna, tracja, mutual edge abisynia↔jemen) + 1 modyfikacja istniejącego (`test_provinces_total_count` jeśli istnieje, lub nowy).
- `tests/engine/test_province_graph.gd` — modyfikacja `test_no_ghost_edges_in_full_graph` (allowlist `[]` + 3 negative assertions).
- `tests/ui/test_map_view.gd` — rename `test_view_renders_16_province_nodes` → `test_view_renders_19_province_nodes`, asercja `16` → `19`.
- `tests/ui/test_main_shell.gd` — asercja `16` → `19`.
- `CLAUDE.md` — 1-liner cross-reference w bullet "End-of-game flow".

**Mapa: spec § → plik kodu → plik testu → Task**

| Spec § | Plik kodu | Plik testu | Task |
|---|---|---|---|
| §4.2 jemen | `data/provinces_historical.json` | `tests/engine/test_province_loader.gd` | 1 |
| §4.3 italia_polnocna | `data/provinces_historical.json` | `tests/engine/test_province_loader.gd` | 2 |
| §4.4 tracja | `data/provinces_historical.json` | `tests/engine/test_province_loader.gd` | 3 |
| §4.5 mutual edge | `data/provinces_historical.json` | `tests/engine/test_province_loader.gd` | 4 |
| §3 allowlist | (test only) | `tests/engine/test_province_graph.gd` | 5 |
| §3 UI count | (test only) | `tests/ui/test_map_view.gd`, `tests/ui/test_main_shell.gd` | 6 |
| §3 docs | `CLAUDE.md` | — | 7 |

---

## Pre-flight: zweryfikuj baseline

- [ ] **Step 1: Cała suite musi pass przed Plan 15**

Run:
```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: wszystkie ~709 testów pass (baseline z Plan 14).

Jeśli baseline nie pass → STOP, napraw przed kontynuacją.

- [ ] **Step 2: Sprawdź obecny stan ghost edges allowlist**

Run: `grep -n "allowed_ghosts" tests/engine/test_province_graph.gd`

Expected: linia `var allowed_ghosts := ["jemen", "italia_polnocna", "tracja"]` przy `test_no_ghost_edges_in_full_graph`.

- [ ] **Step 3: Sprawdź obecny stan UI testów (count = 16)**

Run: `grep -n "16" tests/ui/test_map_view.gd tests/ui/test_main_shell.gd`

Expected: asercje `16` w obu plikach (precyzyjna lokalizacja może się różnić, np. `test_view_renders_16_province_nodes` w `test_map_view.gd:24` i `assert_eq(..., 16)` w `test_main_shell.gd:~73`).

---

## Task 1: Dodaj prowincję `jemen`

**Cel:** Zamknąć ghost edge `mekka↔jemen` przez dodanie prowincji `jemen` z polami zgodnymi ze spec §4.2.

**Files:**
- Modify: `data/provinces_historical.json` (dodać nowy obiekt do `provinces` array)
- Modify: `tests/engine/test_province_loader.gd` (dodać `test_loader_loads_jemen_arabian_owner_with_eastern_pressure_15`)

- [ ] **Step 1: Sprawdź konwencję `test_province_loader.gd`**

Read pierwsze ~70 linii `tests/engine/test_province_loader.gd` — potwierdź wzorce:
- `extends GutTest` (linia 1).
- Inline loading: `var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")` (linia 4 i kolejne).
- Inferred typing: `var foo := graph.get_province(...)` — bez explicit `: Province`.
- Wzorzec asercji dla prowincji Plan 14 (aleksandria, abisynia, libia, karthago) na końcu pliku — używaj jego stylu dla jemen.

- [ ] **Step 2: Napisz failing test `test_loader_loads_jemen_arabian_owner_with_eastern_pressure_15`**

W `tests/engine/test_province_loader.gd` dodaj test mirror dla wzorca Plan 14:

```gdscript
func test_loader_loads_jemen_arabian_owner_with_eastern_pressure_15() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	var jemen := graph.get_province("jemen")
	assert_not_null(jemen, "Plan 15: jemen powinien istnieć w fixturze")
	assert_eq(jemen.display_name, "Jemen")
	assert_eq(jemen.owner, "arabian_paganism")
	assert_eq(jemen.population, 250)
	assert_eq(jemen.terrain, "mountains")
	assert_false(jemen.is_holy_site)
	assert_eq(jemen.pressure.get("arabian_paganism", 0.0), 65.0)
	assert_eq(jemen.pressure.get("eastern_christianity", 0.0), 15.0)
	assert_eq(jemen.resources.get("food", 0), 1)
	assert_eq(jemen.resources.get("gold", 0), 3)
	assert_true("mekka" in jemen.neighbors, "jemen ma sąsiada mekka")
	assert_true("abisynia" in jemen.neighbors, "jemen ma sąsiada abisynia")
```

**Wzorzec ładowania:** `ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")` (zgodnie z linią 4 istniejącego `test_province_loader.gd`). Typowanie inline (`var graph := ...`) bez explicit `: ProvinceGraph` — zgodnie z konwencją pliku.

- [ ] **Step 3: Run test — expect FAIL**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_province_loader.gd -gexit
```

Expected: 1 test fail z `assert_not_null` (jemen nie istnieje w JSON).

- [ ] **Step 4: Dodaj prowincję `jemen` do `data/provinces_historical.json`**

W `data/provinces_historical.json` w array `provinces` (po prowincji `karthago`, przed zamykającym `]`):

```json
{"id": "jemen", "display_name": "Jemen", "owner": "arabian_paganism",
 "pressure": {"arabian_paganism": 65.0, "eastern_christianity": 15.0}, "population": 250,
 "resources": {"food": 1, "gold": 3}, "terrain": "mountains",
 "neighbors": ["mekka", "abisynia"], "is_holy_site": false,
 "position": {"x": 480, "y": 530}}
```

**Uwaga JSON:** dodaj przecinek po `karthago` (poprzedni obiekt) i NIE dodawaj przecinka po `jemen` jeśli to ostatni element (kolejne Task 2, 3 dodadzą więcej obiektów po jemen — wtedy przecinek po jemen pojawi się naturalnie).

- [ ] **Step 5: Run test — expect PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_province_loader.gd -gexit
```

Expected: nowy test pass; istniejące testy fixturee pass (warning: jeśli istnieje istniejący `test_provinces_total_count` asercjujący `16`, fail się ujawni — naprawimy w Task 4).

- [ ] **Step 6: Commit**

```bash
git add data/provinces_historical.json tests/engine/test_province_loader.gd
git commit -m "feat(fixture): Plan 15 — prowincja jemen (Arabian Paganism)"
```

---

## Task 2: Dodaj prowincję `italia_polnocna`

**Cel:** Zamknąć ghost edge `rzym↔italia_polnocna` przez dodanie prowincji `italia_polnocna` z polami zgodnymi ze spec §4.3.

**Files:**
- Modify: `data/provinces_historical.json` (dodać obiekt po jemen)
- Modify: `tests/engine/test_province_loader.gd` (dodać `test_loader_loads_italia_polnocna_western_owner_with_germanic_pressure_20`)

- [ ] **Step 1: Napisz failing test**

```gdscript
func test_loader_loads_italia_polnocna_western_owner_with_germanic_pressure_20() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	var italia := graph.get_province("italia_polnocna")
	assert_not_null(italia, "Plan 15: italia_polnocna powinna istnieć w fixturze")
	assert_eq(italia.display_name, "Italia Północna")
	assert_eq(italia.owner, "western_christianity")
	assert_eq(italia.population, 350)
	assert_eq(italia.terrain, "plains")
	assert_false(italia.is_holy_site)
	assert_eq(italia.pressure.get("western_christianity", 0.0), 60.0)
	assert_eq(italia.pressure.get("germanic_paganism", 0.0), 20.0)
	assert_eq(italia.resources.get("food", 0), 3)
	assert_eq(italia.resources.get("gold", 0), 2)
	assert_eq(italia.neighbors.size(), 1)
	assert_true("rzym" in italia.neighbors)
```

- [ ] **Step 2: Run test — expect FAIL**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_province_loader.gd -gexit
```

Expected: nowy test fail (italia_polnocna nie istnieje).

- [ ] **Step 3: Dodaj prowincję do JSON**

Po obiekcie `jemen` w `provinces_historical.json` dodaj przecinek i:

```json
{"id": "italia_polnocna", "display_name": "Italia Północna", "owner": "western_christianity",
 "pressure": {"western_christianity": 60.0, "germanic_paganism": 20.0}, "population": 350,
 "resources": {"food": 3, "gold": 2}, "terrain": "plains",
 "neighbors": ["rzym"], "is_holy_site": false,
 "position": {"x": 100, "y": 120}}
```

- [ ] **Step 4: Run test — expect PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_province_loader.gd -gexit
```

Expected: test pass.

- [ ] **Step 5: Commit**

```bash
git add data/provinces_historical.json tests/engine/test_province_loader.gd
git commit -m "feat(fixture): Plan 15 — prowincja italia_polnocna (Western Christianity)"
```

---

## Task 3: Dodaj prowincję `tracja`

**Cel:** Zamknąć ghost edge `konstantynopol↔tracja` przez dodanie prowincji `tracja` z polami zgodnymi ze spec §4.4.

**Files:**
- Modify: `data/provinces_historical.json` (dodać obiekt po italia_polnocna)
- Modify: `tests/engine/test_province_loader.gd` (dodać `test_loader_loads_tracja_eastern_owner_with_slavic_pressure_25`)

- [ ] **Step 1: Napisz failing test**

```gdscript
func test_loader_loads_tracja_eastern_owner_with_slavic_pressure_25() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	var tracja := graph.get_province("tracja")
	assert_not_null(tracja, "Plan 15: tracja powinna istnieć w fixturze")
	assert_eq(tracja.display_name, "Tracja")
	assert_eq(tracja.owner, "eastern_christianity")
	assert_eq(tracja.population, 300)
	assert_eq(tracja.terrain, "plains")
	assert_false(tracja.is_holy_site)
	assert_eq(tracja.pressure.get("eastern_christianity", 0.0), 60.0)
	assert_eq(tracja.pressure.get("slavic_paganism", 0.0), 25.0)
	assert_eq(tracja.resources.get("food", 0), 2)
	assert_eq(tracja.resources.get("gold", 0), 1)
	assert_eq(tracja.neighbors.size(), 1)
	assert_true("konstantynopol" in tracja.neighbors)
```

- [ ] **Step 2: Run — expect FAIL**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_province_loader.gd -gexit
```

- [ ] **Step 3: Dodaj prowincję do JSON**

Po obiekcie `italia_polnocna` dodaj przecinek i:

```json
{"id": "tracja", "display_name": "Tracja", "owner": "eastern_christianity",
 "pressure": {"eastern_christianity": 60.0, "slavic_paganism": 25.0}, "population": 300,
 "resources": {"food": 2, "gold": 1}, "terrain": "plains",
 "neighbors": ["konstantynopol"], "is_holy_site": false,
 "position": {"x": 200, "y": 60}}
```

To ostatni dodawany obiekt — **bez przecinka** na końcu (kolejny element to zamykający `]`).

- [ ] **Step 4: Run — expect PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_province_loader.gd -gexit
```

- [ ] **Step 5: Commit**

```bash
git add data/provinces_historical.json tests/engine/test_province_loader.gd
git commit -m "feat(fixture): Plan 15 — prowincja tracja (Eastern Christianity)"
```

---

## Task 4: Mutual edge `abisynia↔jemen` + regression guard count=19

**Cel:** Zamknąć asymetrię — `jemen.neighbors` zawiera `abisynia` (z Task 1), ale `abisynia.neighbors` nie zawiera `jemen`. Patch + 2 testy: TDD red-green dla mutual edge + regression guard liczby prowincji.

**Files:**
- Modify: `data/provinces_historical.json` — patch `abisynia.neighbors`: `["egipt"]` → `["egipt", "jemen"]`
- Modify: `tests/engine/test_province_loader.gd` — 2 nowe testy (1 red-green TDD + 1 regression guard)

- [ ] **Step 1: Napisz failing test `test_jemen_abisynia_mutual_edge`**

W `tests/engine/test_province_loader.gd`:

```gdscript
func test_jemen_abisynia_mutual_edge() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	var jemen := graph.get_province("jemen")
	var abisynia := graph.get_province("abisynia")
	assert_not_null(jemen)
	assert_not_null(abisynia)
	assert_true("abisynia" in jemen.neighbors, "jemen.neighbors zawiera abisynia (Task 1)")
	assert_true("jemen" in abisynia.neighbors, "abisynia.neighbors zawiera jemen (Task 4 patch)")
```

**Note:** `test_provinces_total_count_19` (regression guard) dodajemy DOPIERO po commit Task 4 mutual edge (Step 6). Powód: po Task 1-3 fixture ma już 19 prowincji, więc count test byłby od razu green — to nie jest TDD red-test, tylko guard przeciw przyszłym regresjom. Wzorzec brakuje w istniejących testach (grep nie znalazł `test_provinces_total_count_16`), więc dodajemy jako wyraźnie oznaczony nowy guard.

- [ ] **Step 2: Run test — expect FAIL**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_province_loader.gd -gexit
```

Expected: `test_jemen_abisynia_mutual_edge` fail (abisynia.neighbors == ["egipt"] only). Reszta testów loader pass.

- [ ] **Step 3: Patch `abisynia.neighbors` w JSON**

W `data/provinces_historical.json` znajdź obiekt abisynia (linia ok. 68 po Plan 14):

```json
{"id": "abisynia", ..., "neighbors": ["egipt"], ...}
```

Zmień na:

```json
{"id": "abisynia", ..., "neighbors": ["egipt", "jemen"], ...}
```

- [ ] **Step 4: Run test — expect PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_province_loader.gd -gexit
```

Expected: `test_jemen_abisynia_mutual_edge` pass.

- [ ] **Step 5: Dodaj regression guard `test_provinces_total_count_19`**

To NIE jest red-green TDD — to guard przeciw przyszłym przypadkowym usunięciom prowincji. W `tests/engine/test_province_loader.gd` dodaj:

```gdscript
# Regression guard: chroni przed przypadkowym usunięciem prowincji w przyszłych edycjach.
# Nie jest red-test — po Task 1-4 fixture ma już 19 prowincji.
func test_provinces_total_count_19() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	assert_eq(graph.province_count(), 19, "Plan 15: mapa ma 19 prowincji (16 z Plan 14 + 3 nowe z Plan 15)")
```

**Uwaga:** używamy `graph.province_count()` (zgodnie z wzorcem z linii 5 tego pliku) — NIE `graph.all_provinces().size()`.

- [ ] **Step 6: Run — expect PASS (immediate green)**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_province_loader.gd -gexit
```

Expected: `test_provinces_total_count_19` pass natychmiast (fixture już ma 19 prowincji po Task 1-3 + Task 4 patch).

- [ ] **Step 7: Commit**

```bash
git add data/provinces_historical.json tests/engine/test_province_loader.gd
git commit -m "feat(fixture): Plan 15 — mutual edge abisynia↔jemen + count guard"
```

---

## Task 5: Allowlist ghost edges → `[]` (refactor + mutation test)

**Cel:** Po Task 1-4 wszystkie 3 ghost edges są naprawione. Zaostrzyć istniejący `test_no_ghost_edges_in_full_graph` — allowlist pusty + 3 negative assertions per spec §3.

**Note (TDD framing):** To NIE jest typowy red-green test — istniejący test już passuje po Task 1-4 (allowlist zawiera nazwy, ale actual_ghosts jest empty, więc `ghost in allowed_ghosts` iteracja jest no-op). Plan 15 zaostrza test (pusty allowlist + explicit negative assertions). Czerwoną fazę udowadniamy przez **mandatory mutation test** (Step 5) — tymczasowo łamiemy fixture i obserwujemy że nowa, zaostrzona wersja test failuje. To jest refactor, nie nowa funkcjonalność, ale mutation test gwarantuje że pusty allowlist faktycznie waliduje.

**Files:**
- Modify: `tests/engine/test_province_graph.gd:55-73` — `test_no_ghost_edges_in_full_graph`

- [ ] **Step 1: Sprawdź obecny stan testu**

```bash
grep -A 25 "Plan 14: ghost edge integrity" tests/engine/test_province_graph.gd
```

Expected output (po Plan 14):
```gdscript
var allowed_ghosts := ["jemen", "italia_polnocna", "tracja"]
```
+ pętla budująca `actual_ghosts` + asercja `ghost in allowed_ghosts` + `assert_false("afryka_polnocna" ...)`.

Wzorzec ładowania: `var full_graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")` (sprawdzone w linii 58).

- [ ] **Step 2: Zastąp blok zaostrzoną wersją**

W `tests/engine/test_province_graph.gd` linie 55-73, zastąp istniejący blok komentarza + funkcji:

```gdscript
# === Plan 15: ghost edge integrity — wszystkie znane ghost edges naprawione ===

func test_no_ghost_edges_in_full_graph() -> void:
	var full_graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	# Po Plan 15 allowlist jest pusty — wszystkie znane ghost edges naprawione (jemen, italia_polnocna, tracja).
	var allowed_ghosts: Array[String] = []
	var actual_ghosts: Array[String] = []
	for p: Province in full_graph.all_provinces():
		for n: String in p.neighbors:
			if full_graph.get_province(n) == null and not (n in actual_ghosts):
				actual_ghosts.append(n)
	# Każdy znaleziony ghost MUSI być w allowlist (po Plan 15: zero ghost edges).
	for ghost: String in actual_ghosts:
		assert_true(ghost in allowed_ghosts,
			"Ghost edge '%s' nie jest w allowlist %s — usuń edge lub uzasadnij w spec 15" % [ghost, allowed_ghosts])
	# Sanity: 3 prowincje Plan 15 NIE są ghostami (dodane w Task 1-3).
	assert_false("jemen" in actual_ghosts,
		"jemen ghost edge powinien zostać naprawiony przez Task 1 w Plan 15")
	assert_false("italia_polnocna" in actual_ghosts,
		"italia_polnocna ghost edge powinien zostać naprawiony przez Task 2 w Plan 15")
	assert_false("tracja" in actual_ghosts,
		"tracja ghost edge powinien zostać naprawiony przez Task 3 w Plan 15")
	# Zachowane z Plan 14 — sanity check, że afryka_polnocna nadal naprawiona.
	assert_false("afryka_polnocna" in actual_ghosts,
		"afryka_polnocna ghost edge powinien zostać naprawiony przez karthago w Plan 14")
```

- [ ] **Step 3: Run — expect PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_province_graph.gd -gexit
```

Expected: pass — `actual_ghosts` jest puste (po Task 1-4), więc allowlist `[]` nie powoduje false negatywów.

- [ ] **Step 4: MANDATORY mutation test — udowodnij że zaostrzony test waliduje**

Pusty allowlist musi czemuś służyć. Bez mutation testu nie wiemy czy test naprawdę łapie ghost edges (mógłby być no-op).

Tymczasowo zmień `jemen.neighbors` w `data/provinces_historical.json` z `["mekka", "abisynia"]` na `["mekka", "abisynia", "atlantyda_nieistniejaca"]`. Run:

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_province_graph.gd -gexit
```

Expected: test FAIL z komunikatem `"Ghost edge 'atlantyda_nieistniejaca' nie jest w allowlist []"`. Jeśli pass — STOP, test jest no-op, znajdź problem w logice.

- [ ] **Step 5: Cofnij mutację (restore fixture)**

Przywróć `jemen.neighbors` do `["mekka", "abisynia"]`. Run:

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_province_graph.gd -gexit
```

Expected: pass. **NIE commituj** dopóki fixture nie jest przywrócony do oryginalnej formy.

Sanity diff check:
```bash
git diff data/provinces_historical.json
```

Expected: brak diff (mutacja cofnięta).

- [ ] **Step 6: Commit**

```bash
git add tests/engine/test_province_graph.gd
git commit -m "test(graph): Plan 15 — allowlist=[] + 3 negative assertions po naprawie ghost edges"
```

---

## Task 6: UI patches — `16` → `19`

**Cel:** Zaktualizować 2 istniejące testy UI assertujące liczbę prowincji.

**Files:**
- Modify: `tests/ui/test_map_view.gd` — rename testu + asercja
- Modify: `tests/ui/test_main_shell.gd` — asercja

- [ ] **Step 1: Sprawdź lokalizacje**

```bash
grep -n "16" tests/ui/test_map_view.gd tests/ui/test_main_shell.gd
```

Expected:
- `tests/ui/test_map_view.gd:24` (ok. linii 24 po Plan 14): `func test_view_renders_16_province_nodes` + asercja `16`.
- `tests/ui/test_main_shell.gd:~73`: asercja porównująca liczbę prowincji z `16`.

- [ ] **Step 2: Run istniejące UI testy — expect 2 FAILS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gexit
```

Expected: 2 testy fail (`test_view_renders_16_province_nodes`, oraz test w `test_main_shell.gd`) — bo mapa ma teraz 19 prowincji (z Task 1-4), nie 16.

Jeśli te 2 testy NIE failują → STOP, zweryfikuj że Task 1-4 zostały zacommitowane i fixture rzeczywiście ma 19 prowincji.

- [ ] **Step 3: Patch `test_map_view.gd`**

W `tests/ui/test_map_view.gd`:
- Rename funkcji: `test_view_renders_16_province_nodes` → `test_view_renders_19_province_nodes`.
- Update asercji: `assert_eq(mv.get_node_count(), 16)` → `assert_eq(mv.get_node_count(), 19)` (lub równoważna asercja — wzorzec z Plan 14).
- Update komentarza (jeśli istnieje wzmianka "16 prowincji").

- [ ] **Step 4: Patch `test_main_shell.gd`**

W `tests/ui/test_main_shell.gd` (linia ~73 lub gdziekolwiek po Plan 14):
- Zmień asercję `16` → `19`.
- Update komentarza jeśli istnieje.

- [ ] **Step 5: Run — expect PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gexit
```

Expected: oba testy pass; reszta UI suite bez regresji.

- [ ] **Step 6: Commit**

```bash
git add tests/ui/test_map_view.gd tests/ui/test_main_shell.gd
git commit -m "test(ui): Plan 15 — count prowincji 16 → 19"
```

---

## Task 7: CLAUDE.md cross-reference

**Cel:** Dopisać 1-liner o Plan 15 w sekcji "End-of-game flow" + uaktualnić wzmiankę o liczbie prowincji.

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Znajdź wzmiankę o Plan 14**

```bash
grep -n "Plan 14\|14-coptic\|16 prowincji" CLAUDE.md
```

Expected: linia w bullet "End-of-game flow" wymieniająca spec 14 + jakaś wzmianka "16 prowincji" w sekcji "Single source of truth" / "Architecture".

- [ ] **Step 2: Dopisz 1-liner po Plan 14**

Po linijce o Plan 14 dodaj:

```
Plan 15 (`docs/superpowers/specs/15-ghost-edges-cleanup-design.md`) zamyka 3 pozostałe ghost edges przez dodanie prowincji jemen, italia_polnocna, tracja — mapa ma teraz 19 prowincji.
```

- [ ] **Step 3: Update wzmianki "16 prowincji" → "19 prowincji"**

Jeśli grep w Step 1 zwrócił linię z "16 prowincji" (lub równoważne), zmień na "19 prowincji".

- [ ] **Step 4: Sanity grep**

```bash
grep -F "15-ghost-edges-cleanup-design.md" CLAUDE.md
grep -E "16 prowinc|17 prowinc|18 prowinc" CLAUDE.md
```

Expected:
- Pierwsza komenda: 1 linia (link do specu 15).
- Druga komenda: 0 linii (żadna wzmianka o liczbie < 19).

- [ ] **Step 5: Cała suite (sanity — docs only, nie powinno wpływać)**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: ~714-715 testów pass.

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: cross-reference do spec 15 + update count prowincji do 19"
```

---

## Po wszystkich taskach

- [ ] **Final review**: dispatch `superpowers:code-reviewer` na pełen branch (wszystkie 7 commitów Plan 15). Reviewer sprawdza:
  - Spec compliance z `15-ghost-edges-cleanup-design.md` (wszystkie 10 acceptance criteria z §7).
  - Code quality (JSON format spójny z Plan 14, brak hardcoded ID w testach gdzie da się skorzystać z helpera, brak magic numbers).
  - Test coverage (~5-6 nowych testów engine/fixture + 2 modyfikacje istniejących UI).
  - Brak regresji (~714-715 testów pass).
  - Konsystencja architektoniczna z Plan 14 (pattern fixture-only, allowlist update).
  - Pozycje (x,y) 3 nowych prowincji — czy nie kolidują wizualnie z istniejącymi (60×40 ClickArea margins).

- [ ] **Po approval**: push do origin/master (bez PR, zgodnie z workflow projektu).

---

## Acceptance Criteria (z spec §7)

Plan 15 jest gotowy do merge gdy:

1. ✅ `data/provinces_historical.json` zawiera 19 prowincji, w tym 3 nowe (jemen, italia_polnocna, tracja).
2. ✅ `abisynia.neighbors == ["egipt", "jemen"]` (mutual edge).
3. ✅ `mekka.neighbors`, `rzym.neighbors`, `konstantynopol.neighbors` — bez zmian względem stanu po Plan 14.
4. ✅ `test_no_ghost_edges_in_full_graph` — `allowed_ghosts = []`, 3 negative assertions (jemen, italia_polnocna, tracja) NIE w `actual_ghosts`.
5. ✅ `test_view_renders_19_province_nodes` (rename) — asercja `19` pass.
6. ✅ `test_main_shell.gd` — asercja prowincji `19` pass.
7. ✅ `CLAUDE.md` wzmiankuje Plan 15 + nie ma wzmianek o liczbie prowincji < 19.
8. ✅ Cała suite (~714-715) pass.
9. ✅ Brak regresji w Plan 12/13/14 — wszystkie istniejące testy unique victory, defeat, counter, factions pass.
10. ✅ Mapa wizualnie renderuje 19 nodes bez kolizji (manualny smoke test w editorze Godot opcjonalny).
