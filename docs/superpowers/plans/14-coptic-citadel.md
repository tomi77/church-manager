# Plan 14 — Cytadela Pustelnicza (Koptyjski Kościół) Implementation Plan

> **For Claude:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Dodać 4 prowincje do fixture'a mapy historycznej (aleksandria, abisynia, libia, karthago) i zaimplementować unikalny warunek wygranej "Cytadela Pustelnicza" dla `coptic_christianity` (kontrola 3 prowincji + axis D ≥ 85 + faction unity przez 20 tur).

**Architecture:** Czyste rozszerzenia: (a) `data/provinces_historical.json` — 4 nowe prowincje + 2 patche neighbors (egipt, rzym); (b) `scripts/engine/VictoryManager.gd` — 6 stałych + schema migration (`coptic_citadel_turns`) + nowa gałąź w `update_counters` (per-religion check) + nowa klauzula w `evaluate_unique_victory` + helper `_coptic_citadel_satisfied`; (c) `scripts/ui/dialogs/GameOverDialog.gd` — 1 nowa etykieta `REASON_LABELS`. UI testy assertujące "12 prowincji" zaktualizowane do "16".

**Tech Stack:** Godot 4.6.3, GDScript 2.0, GUT (Godot Unit Testing).

**Spec:** [`docs/superpowers/specs/14-coptic-citadel-design.md`](../specs/14-coptic-citadel-design.md)

---

## Convention reminders (z [CLAUDE.md](../../../CLAUDE.md))

- **Tab indent** w `.gd` i `.tscn`.
- **Stałe engine tunable** — testy referencują `VictoryManager.COPTIC_AXIS_D_REQUIRED` etc., **nie hardcoduj wartości**.
- **Identyfikatory ANGIELSKIE** — pliki, klasy, zmienne, ID. Polski tylko w `Label.text`, `display_name`, komentarzach, JSON. Zgodne z memory `feedback_english_identifiers.md`.
- **Province ID format** — same lowercase ASCII, słowiańskie/polskie znaki odpada (np. `aleksandria`, nie `aleksandría`). Display_name może być po polsku (`"Aleksandria"`, `"Kartagina"`).
- **Brak nowych `class_name`** — Plan 14 nie dodaje nowych skryptów, więc `.godot/global_script_class_cache.cfg` nie wymaga regeneracji.

---

## Test command reference

```bash
# Cała suite (po Plan 14 oczekiwane ~683 + ~14 ≈ 697)
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

- `data/provinces_historical.json` — 4 nowe prowincje, patch `egipt.neighbors`, patch `rzym.neighbors`.
- `scripts/engine/VictoryManager.gd` — 6 nowych stałych, schema `victory_progress` + `coptic_citadel_turns`, gałąź `update_counters`, klauzula `evaluate_unique_victory`, helper `_coptic_citadel_satisfied`, update komentarza nagłówka stałych (linia 8).
- `scripts/ui/dialogs/GameOverDialog.gd` — 1 wpis w `REASON_LABELS`.
- `tests/engine/test_province_loader.gd` — 6 nowych testów (4 prowincje + 2 patche).
- `tests/engine/test_province_graph.gd` — 1 nowy test (`test_no_ghost_edges_in_full_graph`).
- `tests/engine/test_victory_manager_constants.gd` — 1 nowy test.
- `tests/engine/test_victory_manager_flags.gd` — 6 nowych testów (counter coptic_citadel_turns).
- `tests/engine/test_victory_manager_unique.gd` — 3 nowe testy (coptic_citadel predykat).
- `tests/engine/test_victory_manager_endgame.gd` — 1 nowy test (integracja).
- `tests/ui/test_game_over_dialog.gd` — rozszerzenie listy reasonów.
- `tests/ui/test_map_view.gd` — aktualizacja `test_view_renders_12_province_nodes` (12 → 16, rename).
- `tests/ui/test_main_shell.gd` — aktualizacja asercji `12` → `16` (linia ~73).
- `CLAUDE.md` — 1-liner cross-reference w bullet "End-of-game flow".

**Mapa: spec § → plik kodu → plik testu**

| Spec §  | Plik kodu                              | Plik testu                                       | Task |
|---------|----------------------------------------|--------------------------------------------------|------|
| §4 fixture | `data/provinces_historical.json`     | `tests/engine/test_province_loader.gd`           | 1    |
| §4 fixture | `tests/ui/test_map_view.gd`, `tests/ui/test_main_shell.gd` | (in-place fix) | 1 |
| §4.7 ghost | (none — same file)                    | `tests/engine/test_province_graph.gd`            | 2    |
| §5.3 stałe | `scripts/engine/VictoryManager.gd`   | `tests/engine/test_victory_manager_constants.gd` | 3    |
| §5.5 counter | `scripts/engine/VictoryManager.gd` | `tests/engine/test_victory_manager_flags.gd`     | 4    |
| §5.6 predykat | `scripts/engine/VictoryManager.gd` | `tests/engine/test_victory_manager_unique.gd`   | 5    |
| §5.7 integracja | `scripts/engine/VictoryManager.gd` | `tests/engine/test_victory_manager_endgame.gd` | 6    |
| §5.8 UI | `scripts/ui/dialogs/GameOverDialog.gd` | `tests/ui/test_game_over_dialog.gd`              | 7    |
| §3 docs | `CLAUDE.md`                            | — (docs only)                                    | 8    |

---

## Test helper pattern (precedens z Plan 12)

Plik `test_victory_manager_*.gd` używa helpera `_make_state(player_id)`. **Status helpera per plik (stan przed Plan 14):**

| Plik | Sygnatura | Akcja w Plan 14 |
|------|-----------|------------------|
| `test_victory_manager_unique.gd` | `_make_state(player_id: String = "islam")` | OK, bez zmian |
| `test_victory_manager_flags.gd` | `_make_state()` (parameterless, hardcoded `"islam"`) | **Task 4 Step 3 Krok 0: zunifikować sygnaturę** |
| `test_victory_manager_endgame.gd` | `_make_state()` (parameterless, hardcoded `"islam"`) | **Task 6 Step 3 Krok 0: zunifikować sygnaturę** |
| `test_victory_manager_defeat.gd` | `_make_state(player_id)` | OK |

Wzorzec docelowy (kopiowany z `test_victory_manager_unique.gd`):

```gdscript
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state(player_id: String = "islam") -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize(player_id, religions, graph)
	return gs
```

Dla testów koptyjskich preferuj `_make_state("coptic_christianity")` jako player.

## Religion API reference (precedens z Plan 13)

`Religion.gd` ma tylko `get_axis(axis: String) -> float` i `shift_axis(axis: String, delta: float) -> void`. **Brak `set_axis()`.** Bezpośrednie ustawienie wartości (jak w Plan 13 testach):

```gdscript
religion.axes["D"] = 90.0			# OK — bezpośredni dostęp do pola Dictionary
# NIE: religion.set_axis("D", 90.0)	— metoda nie istnieje
```

## GameOutcome field reference

`GameOutcome.gd` definiuje pole **`winner_id`** (nie `winner_religion_id`). Wszystkie asercje muszą używać `outcome.winner_id`.

---

## Chunk 1: Fixture — 4 nowe prowincje + ghost edges

---

### Task 1: Fixture — dodanie aleksandria, abisynia, libia, karthago + patche neighbors

**Cel:** Rozszerzyć `data/provinces_historical.json` o 4 prowincje (spec §4.2-4.5) i naprawić 2 ghost edges (egipt↔libia, rzym↔afryka_polnocna → karthago). Zaktualizować 2 istniejące UI testy assertujące "12 prowincji" → "16".

**Files:**
- Modify: `data/provinces_historical.json`
- Modify: `tests/engine/test_province_loader.gd`
- Modify: `tests/ui/test_map_view.gd`
- Modify: `tests/ui/test_main_shell.gd`

- [ ] **Step 1: Dopisz failing testy do `tests/engine/test_province_loader.gd`**

```gdscript

# === Plan 14: nowe prowincje koptyjskie ===

func test_loader_loads_aleksandria_with_holy_site_and_coptic_owner() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	var aleksandria := graph.get_province("aleksandria")
	assert_not_null(aleksandria, "aleksandria istnieje")
	assert_eq(aleksandria.owner, "coptic_christianity")
	assert_true(aleksandria.is_holy_site, "aleksandria jest holy site")

func test_loader_loads_abisynia_coptic_owner_no_holy_site() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	var abisynia := graph.get_province("abisynia")
	assert_not_null(abisynia)
	assert_eq(abisynia.owner, "coptic_christianity")
	assert_false(abisynia.is_holy_site)

func test_loader_loads_libia_eastern_owner_with_coptic_pressure() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	var libia := graph.get_province("libia")
	assert_not_null(libia)
	assert_eq(libia.owner, "eastern_christianity")
	assert_almost_eq(libia.pressure.get("coptic_christianity", 0.0), 25.0, 0.001,
		"libia ma 25 pressure dla Coptic (missionary potential)")

func test_loader_loads_karthago_eastern_owner_with_western_pressure() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	var karthago := graph.get_province("karthago")
	assert_not_null(karthago)
	assert_eq(karthago.owner, "eastern_christianity")
	assert_almost_eq(karthago.pressure.get("western_christianity", 0.0), 20.0, 0.001,
		"karthago ma 20 pressure dla Western (Augustyn / dziedzictwo łacińskie)")

func test_egipt_neighbors_include_aleksandria_and_abisynia() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	assert_true(graph.are_neighbors("egipt", "aleksandria"), "egipt ↔ aleksandria")
	assert_true(graph.are_neighbors("egipt", "abisynia"), "egipt ↔ abisynia")
	assert_true(graph.are_neighbors("egipt", "libia"), "egipt ↔ libia (poprzedni ghost teraz waluuje)")

func test_rzym_neighbors_karthago_not_afryka_polnocna() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	assert_true(graph.are_neighbors("rzym", "karthago"), "rzym ↔ karthago")
	assert_null(graph.get_province("afryka_polnocna"),
		"afryka_polnocna nie powinna istnieć — została zastąpiona przez karthago")
```

- [ ] **Step 2: Uruchom — powinno failować**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_province_loader.gd -gexit
```

Expected: 6 nowych testów failuje — `get_province("aleksandria")` zwraca null itd.

- [ ] **Step 3: Dodaj 4 prowincje + patche w `data/provinces_historical.json`**

**Krok A:** Dodaj 4 nowe obiekty prowincji do tablicy `"provinces"` (kolejność: po `armenia`, na końcu tablicy, przed zamknięciem `]`):

```json
,
    {"id": "aleksandria", "display_name": "Aleksandria", "owner": "coptic_christianity",
     "pressure": {"coptic_christianity": 75.0, "eastern_christianity": 15.0}, "population": 400,
     "resources": {"food": 2, "gold": 4}, "terrain": "coast",
     "neighbors": ["egipt", "libia"], "is_holy_site": true,
     "position": {"x": 200, "y": 350}},
    {"id": "abisynia", "display_name": "Abisynia", "owner": "coptic_christianity",
     "pressure": {"coptic_christianity": 70.0}, "population": 250,
     "resources": {"food": 2, "gold": 1}, "terrain": "mountains",
     "neighbors": ["egipt"], "is_holy_site": false,
     "position": {"x": 320, "y": 520}},
    {"id": "libia", "display_name": "Libia", "owner": "eastern_christianity",
     "pressure": {"eastern_christianity": 50.0, "coptic_christianity": 25.0}, "population": 200,
     "resources": {"food": 1, "gold": 1}, "terrain": "desert",
     "neighbors": ["aleksandria", "egipt", "karthago"], "is_holy_site": false,
     "position": {"x": 140, "y": 420}},
    {"id": "karthago", "display_name": "Kartagina", "owner": "eastern_christianity",
     "pressure": {"eastern_christianity": 55.0, "western_christianity": 20.0}, "population": 300,
     "resources": {"food": 2, "gold": 3}, "terrain": "coast",
     "neighbors": ["libia", "rzym"], "is_holy_site": false,
     "position": {"x": 60, "y": 320}}
```

**Krok B:** Patch `egipt.neighbors` — znajdź linię:
```json
"neighbors": ["lewant", "jerozolima", "libia"]
```
i zmień na:
```json
"neighbors": ["lewant", "jerozolima", "libia", "aleksandria", "abisynia"]
```

**Krok C:** Patch `rzym.neighbors` — znajdź linię:
```json
"neighbors": ["italia_polnocna", "afryka_polnocna"]
```
i zmień na:
```json
"neighbors": ["italia_polnocna", "karthago"]
```

- [ ] **Step 4: Zaktualizuj `tests/ui/test_map_view.gd`**

Znajdź `test_view_renders_12_province_nodes` (linia ~20):

```gdscript
func test_view_renders_12_province_nodes():
	var state := _make_state()
	add_child_autofree(state)
	var mv := await _instance_view(state)
	assert_eq(mv.get_node_count(), 12)
```

Zmień nazwę i wartość:

```gdscript
func test_view_renders_16_province_nodes():
	var state := _make_state()
	add_child_autofree(state)
	var mv := await _instance_view(state)
	assert_eq(mv.get_node_count(), 16)
```

- [ ] **Step 5: Zaktualizuj `tests/ui/test_main_shell.gd`**

Znajdź asercję `assert_eq(mapa_tab.get_node("%MapView").get_node_count(), 12)` (linia ~73) i zmień `12` → `16`.

- [ ] **Step 6: Uruchom test_province_loader.gd — pass**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_province_loader.gd -gexit
```

Expected: wszystkie nowe i istniejące testy pass.

- [ ] **Step 7: Uruchom cała suite — brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 683 + 6 = 689 testów, wszystkie pass. Jeśli inne testy fail z powodu zmienionej liczby prowincji (np. `province_count() == 12` gdzieś dalej) — zaktualizuj je w tym kroku (uzupełnij listę modyfikacji w PR opisie).

- [ ] **Step 8: Commit**

```bash
git add data/provinces_historical.json tests/engine/test_province_loader.gd tests/ui/test_map_view.gd tests/ui/test_main_shell.gd
git commit -m "feat(fixture): Plan 14 — 4 nowe prowincje (aleksandria, abisynia, libia, karthago) + naprawa ghost edges"
```

---

### Task 2: Test ghost edges — pełny graf, allowlist

**Cel:** Dodać test waliduący że WSZYSTKIE neighbory w grafie wskazują na istniejące prowincje, z explicit allowlist znanych out-of-scope ghosts (`jemen`, `italia_polnocna`). Po Plan 14 `afryka_polnocna` MUSI zniknąć z allowlisty.

**Files:**
- Modify: `tests/engine/test_province_graph.gd`

- [ ] **Step 1: Dopisz failing test do `tests/engine/test_province_graph.gd`**

```gdscript

# === Plan 14: ghost edge integrity ===

func test_no_ghost_edges_in_full_graph() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	# Allowlist: znane out-of-scope ghost edges (mapa nie obejmuje italia północna, jemen).
	# Po Plan 14 'afryka_polnocna' nie powinna być w allowlist — została zastąpiona przez karthago.
	var allowed_ghosts := ["jemen", "italia_polnocna"]
	var actual_ghosts: Array[String] = []
	for p: Province in graph.all_provinces():
		for n: String in p.neighbors:
			if graph.get_province(n) == null and not (n in actual_ghosts):
				actual_ghosts.append(n)
	# Każdy znaleziony ghost MUSI być w allowlist.
	for ghost: String in actual_ghosts:
		assert_true(ghost in allowed_ghosts,
			"Ghost edge '%s' nie jest w allowlist %s — usuń edge lub uzasadnij w spec 14 §4.7" % [ghost, allowed_ghosts])
	# Walidacja że afryka_polnocna NIE jest już ghostem (sanity check Plan 14 fix).
	assert_false("afryka_polnocna" in actual_ghosts,
		"afryka_polnocna ghost edge powinien zostać naprawiony przez karthago w Plan 14")
```

- [ ] **Step 2: Uruchom — powinien pass od razu**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_province_graph.gd -gexit
```

Expected: pass (Task 1 już naprawił `afryka_polnocna`; pozostałe ghosts `jemen`, `italia_polnocna` są w allowlist).

Jeśli test failuje (np. inny nieoczekiwany ghost) — debuguj, popraw fixture lub dodaj do allowlist po dyskusji.

- [ ] **Step 3: Cała suite — brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 689 + 1 = 690 testów, wszystkie pass.

- [ ] **Step 4: Commit**

```bash
git add tests/engine/test_province_graph.gd
git commit -m "test(graph): full-graph ghost edge integrity z allowlist (Plan 14)"
```

---

## Chunk 2: VictoryManager — stałe, counter, predykat

---

### Task 3: VictoryManager — 6 nowych stałych Plan 14 + komentarz nagłówka

**Cel:** Dodać 6 stałych dla warunku Cytadela Pustelnicza i zaktualizować nagłówkowy komentarz "12 prowincji" → "16 prowincji" (linia 8).

**Files:**
- Modify: `scripts/engine/VictoryManager.gd`
- Modify: `tests/engine/test_victory_manager_constants.gd`

- [ ] **Step 1: Napisz failing test stałych Plan 14**

Dopisz do `tests/engine/test_victory_manager_constants.gd`:

```gdscript

func test_plan14_constants_exist() -> void:
	assert_eq(VictoryManager.COPTIC_ALEKSANDRIA_ID, "aleksandria")
	assert_eq(VictoryManager.COPTIC_EGIPT_ID, "egipt")
	assert_eq(VictoryManager.COPTIC_ABISYNIA_ID, "abisynia")
	assert_almost_eq(VictoryManager.COPTIC_AXIS_D_REQUIRED, 85.0, 0.001)
	assert_almost_eq(VictoryManager.COPTIC_FACTION_TENSION_MAX, 50.0, 0.001)
	assert_eq(VictoryManager.COPTIC_CITADEL_TURNS_REQUIRED, 20)
```

- [ ] **Step 2: Uruchom — failure**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_constants.gd -gexit
```

Expected: failure — `Invalid get index 'COPTIC_ALEKSANDRIA_ID'`.

- [ ] **Step 3: Dodaj stałe i zaktualizuj komentarz w `scripts/engine/VictoryManager.gd`**

**Krok A:** Zmień linię 8:
```gdscript
# === Stałe uniwersalne — kalibracja do mapy historycznej (12 prowincji) ===
```
na:
```gdscript
# === Stałe uniwersalne — kalibracja do mapy historycznej (16 prowincji po Plan 14) ===
```

**Krok B:** Po istniejących stałych Plan 13 (po `BUDDHISM_DISTINCT_SOURCES_REQUIRED`), **przed** komentarzem `# === Public API`, dodaj:

```gdscript

# === Plan 14: unikalne warunki — Coptic Christianity (Cytadela Pustelnicza) ===
const COPTIC_ALEKSANDRIA_ID := "aleksandria"
const COPTIC_EGIPT_ID := "egipt"
const COPTIC_ABISYNIA_ID := "abisynia"
const COPTIC_AXIS_D_REQUIRED := 85.0					# axis D (Transcendencja) — Coptic startuje 70, lift +15
const COPTIC_FACTION_TENSION_MAX := 50.0				# wszystkie 3 frakcje < 50 (poniżej phase 1)
const COPTIC_CITADEL_TURNS_REQUIRED := 20				# trwałość 5 warunków przez 20 tur
```

- [ ] **Step 4: Uruchom — pass**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_constants.gd -gexit
```

Expected: wszystkie testy pass (Plan 12+13 + nowy Plan 14).

- [ ] **Step 5: Cała suite — brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 690 + 1 = 691 testów pass.

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/VictoryManager.gd tests/engine/test_victory_manager_constants.gd
git commit -m "feat(victory): Plan 14 stale — Coptic Cytadela Pustelnicza"
```

---

### Task 4: VictoryManager.update_counters — coptic_citadel_turns

**Cel:** Dodać licznik `coptic_citadel_turns` w `state.victory_progress[id]`. Inkrementuje gdy religia jest Coptic AND wszystkie 5 warunków z spec §5.2 (kontrola 3 prowincji + axis D ≥ 85 + factions.size() >= 3 + wszystkie tension < 50) spełnione; resetuje w przeciwnym wypadku. Pomija religie z `defeated_at_turn != -1` (idem co Plan 12/13).

**Files:**
- Modify: `scripts/engine/VictoryManager.gd`
- Modify: `tests/engine/test_victory_manager_flags.gd`

- [ ] **Step 1: Dopisz failing testy do `tests/engine/test_victory_manager_flags.gd`**

```gdscript

# === Plan 14: coptic_citadel_turns counter ===

func test_update_counters_initializes_coptic_citadel_turns_zero() -> void:
	var gs := _make_state("coptic_christianity")
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("coptic_christianity", {})
	assert_eq(prog.get("coptic_citadel_turns", -1), 0,
		"po pierwszym update licznik istnieje i jest 0")

func test_update_counters_increments_coptic_citadel_when_all_conditions_met() -> void:
	var gs := _make_state("coptic_christianity")
	var coptic: Religion = gs.get_religion("coptic_christianity")
	# Wszystkie 3 prowincje Coptic (już z fixture: egipt + aleksandria + abisynia są coptic)
	# Axis D ≥ 85
	coptic.axes["D"] = 90.0
	# Wszystkie frakcje tension < 50 (już z fixture: tension_start = 20.0)
	for f: Faction in coptic.factions:
		f.tension = 20.0
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("coptic_christianity", {})
	assert_eq(prog.get("coptic_citadel_turns", 0), 1)
	vm.update_counters(gs)
	prog = gs.victory_progress.get("coptic_christianity", {})
	assert_eq(prog.get("coptic_citadel_turns", 0), 2)

func test_update_counters_resets_coptic_citadel_when_aleksandria_lost() -> void:
	var gs := _make_state("coptic_christianity")
	var coptic: Religion = gs.get_religion("coptic_christianity")
	coptic.axes["D"] = 90.0
	for f: Faction in coptic.factions:
		f.tension = 20.0
	gs.victory_progress["coptic_christianity"] = {
		"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 5}
	# Utrata aleksandrii
	gs.province_graph.get_province("aleksandria").owner = "eastern_christianity"
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("coptic_christianity", {})
	assert_eq(prog.get("coptic_citadel_turns", -1), 0, "utrata aleksandrii → reset")

func test_update_counters_resets_coptic_citadel_when_axis_d_below_threshold() -> void:
	var gs := _make_state("coptic_christianity")
	var coptic: Religion = gs.get_religion("coptic_christianity")
	coptic.axes["D"] = 84.99  # tuż poniżej progu
	for f: Faction in coptic.factions:
		f.tension = 20.0
	gs.victory_progress["coptic_christianity"] = {
		"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 5}
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("coptic_christianity", {})
	assert_eq(prog.get("coptic_citadel_turns", -1), 0, "axis D < 85 → reset")

func test_update_counters_resets_coptic_citadel_when_faction_tension_at_threshold() -> void:
	# Próg ostry: < 50 (nie <=). Tension = 50.0 powinien blokować.
	var gs := _make_state("coptic_christianity")
	var coptic: Religion = gs.get_religion("coptic_christianity")
	coptic.axes["D"] = 90.0
	coptic.factions[0].tension = 50.0
	coptic.factions[1].tension = 20.0
	coptic.factions[2].tension = 20.0
	gs.victory_progress["coptic_christianity"] = {
		"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 5}
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("coptic_christianity", {})
	assert_eq(prog.get("coptic_citadel_turns", -1), 0, "tension == 50 → reset (próg ostry)")

func test_update_counters_resets_coptic_citadel_when_faction_lost_via_schism() -> void:
	# Edge case: factions.size() < 3 (np. po schizmie) — vacuous truth blocked przez guard.
	var gs := _make_state("coptic_christianity")
	var coptic: Religion = gs.get_religion("coptic_christianity")
	coptic.axes["D"] = 90.0
	coptic.factions.pop_back()  # zostały 2 frakcje
	for f: Faction in coptic.factions:
		f.tension = 20.0
	gs.victory_progress["coptic_christianity"] = {
		"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 5}
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("coptic_christianity", {})
	assert_eq(prog.get("coptic_citadel_turns", -1), 0,
		"factions.size() < 3 → reset (schizma już zaszła, jedność zburzona)")

func test_update_counters_only_increments_coptic_citadel_for_coptic_christianity() -> void:
	# Inne religie nie inkrementują coptic_citadel_turns nawet jeśli "spełniają" warunki Coptic.
	var gs := _make_state("islam")
	var islam: Religion = gs.get_religion("islam")
	islam.axes["D"] = 100.0  # axis D bardzo wysoki
	for f: Faction in islam.factions:
		f.tension = 10.0
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("islam", {})
	assert_eq(prog.get("coptic_citadel_turns", -1), 0,
		"Islam nie inkrementuje coptic_citadel_turns (counter jest religion-scoped do Coptic)")
```

- [ ] **Step 2: Uruchom — failure**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_flags.gd -gexit
```

Expected: większość nowych testów failuje — `coptic_citadel_turns` nie istnieje w schema; counter nie inkrementuje.

- [ ] **Step 3: Zmodyfikuj `scripts/engine/VictoryManager.gd` (schema + logic)**

**Krok 0 (preliminary, test helper):** W `tests/engine/test_victory_manager_flags.gd:5`, zmień parameterless helper na parametryzowany (analog `test_victory_manager_unique.gd:5`):

```gdscript
# Przed:
func _make_state() -> Node:
	# ... hardcoded "islam"

# Po:
func _make_state(player_id: String = "islam") -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize(player_id, religions, graph)
	return gs
```

Default `"islam"` zachowuje wszystkie istniejące wywołania `_make_state()` w tym pliku bez modyfikacji. Po tej zmianie wywołania `_make_state("coptic_christianity")` z Step 1 będą resolwowały.

**Krok A:** Znajdź wywołanie `_ensure_progress_entry` dla `victory_progress` w `update_counters` (powstało w Plan 13):
```gdscript
_ensure_progress_entry(state.victory_progress, religion.id, {"domination_turns": 0, "prestige_hegemony_turns": 0, "dharma_turns": 0})
```
Zmień na:
```gdscript
_ensure_progress_entry(state.victory_progress, religion.id, {"domination_turns": 0, "prestige_hegemony_turns": 0, "dharma_turns": 0, "coptic_citadel_turns": 0})
```

**Krok B:** Po istniejącej logice `dharma_turns` (Plan 13) w `update_counters`, **wewnątrz tej samej pętli per-religia**, dodaj:

```gdscript
		# Plan 14 §5.5: coptic_citadel_turns — kontrola 3 prowincji + axis D + faction unity.
		if religion.id == "coptic_christianity":
			var citadel_active: bool = true
			var aleksandria: Province = state.province_graph.get_province(COPTIC_ALEKSANDRIA_ID)
			var egipt: Province = state.province_graph.get_province(COPTIC_EGIPT_ID)
			var abisynia: Province = state.province_graph.get_province(COPTIC_ABISYNIA_ID)
			if aleksandria == null or aleksandria.owner != religion.id:
				citadel_active = false
			elif egipt == null or egipt.owner != religion.id:
				citadel_active = false
			elif abisynia == null or abisynia.owner != religion.id:
				citadel_active = false
			elif religion.get_axis("D") < COPTIC_AXIS_D_REQUIRED:
				citadel_active = false
			elif religion.factions.size() < 3:
				citadel_active = false
			else:
				for f: Faction in religion.factions:
					if f.tension >= COPTIC_FACTION_TENSION_MAX:
						citadel_active = false
						break
			if citadel_active:
				state.victory_progress[religion.id]["coptic_citadel_turns"] += 1
			else:
				state.victory_progress[religion.id]["coptic_citadel_turns"] = 0
```

- [ ] **Step 4: Uruchom — pass**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_flags.gd -gexit
```

Expected: wszystkie testy pass.

- [ ] **Step 5: Cała suite — brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 691 + 7 = 698 testów pass.

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/VictoryManager.gd tests/engine/test_victory_manager_flags.gd
git commit -m "feat(victory): Plan 14 — counter coptic_citadel_turns w update_counters"
```

---

### Task 5: VictoryManager.evaluate_unique_victory — coptic_citadel + helper

**Cel:** Dodać klauzulę `"coptic_christianity":` w `evaluate_unique_victory` zwracającą `"coptic_citadel"` gdy `coptic_citadel_turns >= 20`. Dodać helper `_coptic_citadel_satisfied`.

**Files:**
- Modify: `scripts/engine/VictoryManager.gd`
- Modify: `tests/engine/test_victory_manager_unique.gd`

- [ ] **Step 1: Dopisz failing testy do `tests/engine/test_victory_manager_unique.gd`**

```gdscript

# === Plan 14: coptic_citadel predykat ===

func test_coptic_citadel_requires_20_turns_counter() -> void:
	var gs := _make_state("coptic_christianity")
	var coptic: Religion = gs.get_religion("coptic_christianity")
	gs.victory_progress["coptic_christianity"] = {
		"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 20}
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(coptic, gs), "coptic_citadel",
		"counter == 20 → coptic_citadel reason")

func test_coptic_citadel_blocked_with_19_turns() -> void:
	var gs := _make_state("coptic_christianity")
	var coptic: Religion = gs.get_religion("coptic_christianity")
	gs.victory_progress["coptic_christianity"] = {
		"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 19}
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(coptic, gs), "",
		"counter == 19 → brak unique victory (próg ostry >=)")

func test_coptic_citadel_other_religion_never_returns_reason() -> void:
	# Sanity: Islam z wstrzykniętym counterem nie zwraca coptic_citadel (brak case'a w match).
	var gs := _make_state("islam")
	var islam: Religion = gs.get_religion("islam")
	gs.victory_progress["islam"] = {
		"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 999}
	var vm := VictoryManager.new()
	assert_ne(vm.evaluate_unique_victory(islam, gs), "coptic_citadel",
		"Islam nigdy nie zwraca coptic_citadel — match case jest tylko dla coptic")
```

- [ ] **Step 2: Uruchom — failure**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_unique.gd -gexit
```

Expected: failure — `evaluate_unique_victory(coptic, ...)` zwraca `""` (brak case'a w match).

- [ ] **Step 3: Dodaj klauzulę i helper w `scripts/engine/VictoryManager.gd`**

**Krok A:** W `evaluate_unique_victory`, w `match religion.id`, po istniejącej klauzuli `"buddhism":` (Plan 13), dodaj:

```gdscript
		"coptic_christianity":
			if _coptic_citadel_satisfied(religion, state):
				return "coptic_citadel"
```

**Krok B:** Po istniejących helperach (np. po `_buddhism_middle_way_satisfied`), dodaj:

```gdscript
func _coptic_citadel_satisfied(religion: Religion, state: Node) -> bool:
	# Counter coptic_citadel_turns aktualizowany w update_counters (Plan 14 Task 4).
	# Helper reads tylko counter — faktyczne 5 warunków waliduje update_counters,
	# co gwarantuje że "20 tur" nie da się "udać" w jednej turze.
	var vp: Dictionary = state.victory_progress.get(religion.id, {})
	return vp.get("coptic_citadel_turns", 0) >= COPTIC_CITADEL_TURNS_REQUIRED
```

- [ ] **Step 4: Uruchom — pass**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_unique.gd -gexit
```

Expected: wszystkie testy pass.

- [ ] **Step 5: Cała suite**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 698 + 3 = 701 testów pass.

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/VictoryManager.gd tests/engine/test_victory_manager_unique.gd
git commit -m "feat(victory): Plan 14 — evaluate_unique_victory coptic_citadel + helper"
```

---

## Chunk 3: Integracja, UI, docs

---

### Task 6: VictoryManager endgame — coptic_citadel zapisuje game_outcome (regression check)

**Cel:** Test integracyjny / regresji — pełna gra Coptic (od `_make_state("coptic_christianity")`), spełnij warunki, advance 20 turn, sprawdź że `state.game_outcome.winner_id == "coptic_christianity"` i `game_outcome.reason == "coptic_citadel"`. **Note:** to nie jest klasyczny TDD cycle (implementacja powstała w Tasks 4-5) — to regression check że counter + predykat + match clause spinają się prawidłowo z `check()` pipeline z Plan 12. Test pisany po implementacji świadomie.

**Files:**
- Modify: `tests/engine/test_victory_manager_endgame.gd`

- [ ] **Step 0: Zunifikuj `_make_state` w `tests/engine/test_victory_manager_endgame.gd`**

Linia 5 (`func _make_state() -> Node:`) — zmień na parametryzowaną wersję analogicznie do Task 4 Krok 0:

```gdscript
func _make_state(player_id: String = "islam") -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize(player_id, religions, graph)
	return gs
```

Default `"islam"` zachowuje istniejące wywołania bez modyfikacji.

- [ ] **Step 1: Dopisz failing test do `tests/engine/test_victory_manager_endgame.gd`**

```gdscript

# === Plan 14: integracja coptic_citadel z check ===

func test_check_marks_coptic_citadel_with_game_outcome() -> void:
	var gs := _make_state("coptic_christianity")
	var coptic: Religion = gs.get_religion("coptic_christianity")
	# Spełnij wszystkie 5 warunków (po Task 4 counter będzie inkrementował).
	coptic.axes["D"] = 90.0
	for f: Faction in coptic.factions:
		f.tension = 20.0
	# Aleksandria, egipt, abisynia już są coptic z fixture.
	var vm := VictoryManager.new()
	# 20 tur update_counters + check (po Plan 12 check ustawia game_outcome).
	for i in range(20):
		vm.update_counters(gs)
		vm.check(gs)
	assert_not_null(gs.game_outcome, "game_outcome ustawione po 20 turach")
	assert_eq(gs.game_outcome.winner_id, "coptic_christianity")
	assert_eq(gs.game_outcome.reason, "coptic_citadel")
```

- [ ] **Step 2: Uruchom — powinno failować lub pass**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_endgame.gd -gexit
```

Expected: po Tasks 3-5 powinno pass od razu — wszystkie elementy (counter, predykat, match) są na miejscu. Jeśli fail — debuguj który komponent zwraca błąd (najczęściej brak `coptic_citadel_turns` w schema albo niepoprawne wywołanie `check`).

- [ ] **Step 3: Jeśli failure — fix (analiza nie predict)**

Jeśli test failuje, sprawdź:
- `gs.game_outcome` jest null → `check()` nie zapisuje outcome → debuguj `check()` w Plan 12.
- `game_outcome.reason` jest np. `"domination"` zamiast `"coptic_citadel"` → kolejność warunków w `check()` — uniwersalne warunki check się przed unique? Sprawdź spec 12 §6 (kolejność powinna być: defeat → unique → universal).

Jeśli kolejność jest poprawna, ten test powinien pass — jeśli nie, jest to bug w innym warunku (zgłaszać i ewentualnie rozbić na osobny task).

- [ ] **Step 4: Cała suite**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 701 + 1 = 702 testów pass.

- [ ] **Step 5: Commit**

```bash
git add tests/engine/test_victory_manager_endgame.gd
git commit -m "test(victory): Plan 14 — integracja coptic_citadel z game_outcome"
```

---

### Task 7: GameOverDialog — REASON_LABELS["coptic_citadel"]

**Cel:** Dodać polską etykietę dla `"coptic_citadel"` w `GameOverDialog.REASON_LABELS`.

**Files:**
- Modify: `scripts/ui/dialogs/GameOverDialog.gd`
- Modify: `tests/ui/test_game_over_dialog.gd`

- [ ] **Step 1: Rozszerz `test_dialog_maps_all_reasons_to_non_empty_polish_labels`**

W `tests/ui/test_game_over_dialog.gd` znajdź test sprawdzający że wszystkie reasony mapują się do polskich etykiet (powinien być parametryczny/listowy, dodany w Plan 12+13). Dodaj `"coptic_citadel"` do listy weryfikowanych reasonów.

Jeśli wzorzec jest:
```gdscript
var reasons := ["domination", "prestige_hegemony", "holy_land", ...]
```
dodaj `"coptic_citadel"`. Test powinien też wymagać że etykieta zawiera "Coptic" albo "Koptyjski":

```gdscript
func test_coptic_citadel_label_contains_polish_religion_name() -> void:
	var label: String = GameOverDialog.REASON_LABELS.get("coptic_citadel", "")
	assert_ne(label, "", "coptic_citadel ma etykietę")
	assert_true(label.findn("koptyjski") != -1 or label.findn("coptic") != -1,
		"etykieta zawiera 'Koptyjski' lub 'Coptic'")
```

- [ ] **Step 2: Uruchom — failure**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_game_over_dialog.gd -gexit
```

Expected: failure — `REASON_LABELS["coptic_citadel"]` zwraca `""`.

- [ ] **Step 3: Dodaj wpis w `scripts/ui/dialogs/GameOverDialog.gd`**

W stałej `REASON_LABELS`, po wpisach Plan 13 (`"buddhism_middle_way"`), dodaj przed zamknięciem `}`:

```gdscript
	"coptic_citadel": "Cytadela Pustelnicza (Koptyjski Kościół)",
```

- [ ] **Step 4: Uruchom — pass**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_game_over_dialog.gd -gexit
```

- [ ] **Step 5: Cała suite**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 702 + 1-2 = ~703-704 testów pass.

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/dialogs/GameOverDialog.gd tests/ui/test_game_over_dialog.gd
git commit -m "feat(ui): Plan 14 — REASON_LABELS coptic_citadel"
```

---

### Task 8: CLAUDE.md — cross-reference do spec 14

**Cel:** Dodać 1-liner cross-reference do spec 14 w bullet "End-of-game flow" (analog Plan 13 wzmianki).

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Zlokalizuj bullet "End-of-game flow"**

Otwórz `CLAUDE.md`, znajdź sekcję wzmiankującą Plan 13 (`13-victory-extensions-design.md`).

- [ ] **Step 2: Dodaj 1-liner**

Po wzmiance Plan 13, dodaj:

```
Plan 14 (`docs/superpowers/specs/14-coptic-citadel-design.md`) dodaje unikalny warunek "Cytadela Pustelnicza" dla Koptyjskiego Kościoła + 4 nowe prowincje (aleksandria, abisynia, libia, karthago).
```

- [ ] **Step 3: Sanity grep test**

```bash
grep -F "14-coptic-citadel-design.md" CLAUDE.md
```

Expected: znaleziona linia.

- [ ] **Step 4: Cała suite (sanity — docs only, nie powinno wpływać)**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: ~703 testów pass.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: cross-reference do spec 14 (Coptic Cytadela Pustelnicza)"
```

---

## Po wszystkich taskach

- [ ] **Final review**: dispatch `superpowers:code-reviewer` na pełen branch (wszystkie 8 commitów Plan 14). Reviewer sprawdza:
  - Spec compliance z `14-coptic-citadel-design.md` (wszystkie 10 acceptance criteria z §8).
  - Code quality (tab indent, naming, brak magic numbers, brak hardkoded id, idempotencja).
  - Test coverage (~14 nowych engine/fixture testów + 1-2 UI + 2 modyfikacje istniejących).
  - Brak regresji (~703 testów pass).
  - Konsystencja architektoniczna z Plan 13 (counter + predykat pattern).

- [ ] **Po approval**: push do origin/master (bez PR, zgodnie z workflow projektu).

---

## Acceptance Criteria (z spec §8)

Plan 14 jest gotowy do merge gdy:

1. ✅ `data/provinces_historical.json` zawiera 16 prowincji, w tym 4 nowe.
2. ✅ `egipt.neighbors` zawiera `aleksandria` i `abisynia`.
3. ✅ `rzym.neighbors` zawiera `karthago` i NIE zawiera `afryka_polnocna`.
4. ✅ 6 stałych Plan 14 istnieje w `VictoryManager.gd`.
5. ✅ Counter `coptic_citadel_turns` w `victory_progress` poprawnie inkrementuje/resetuje per spec §5.2 (kontrola 3 prowincji + axis D + factions ≥ 3 + tension < 50).
6. ✅ `evaluate_unique_victory` dla Coptic z `coptic_citadel_turns >= 20` zwraca `"coptic_citadel"`.
7. ✅ `state.game_outcome.winner_id == "coptic_christianity"` AND `state.game_outcome.reason == "coptic_citadel"` po `check()` gdy gracz Coptic wygra.
8. ✅ `GameOverDialog.REASON_LABELS["coptic_citadel"]` zwraca polską etykietę.
9. ✅ `CLAUDE.md` wzmiankuje Plan 14.
10. ✅ Cała suite (~703 testów) pass; ghost edges allowlist tylko `[jemen, italia_polnocna]` (afryka_polnocna naprawiona).
