# Plan 13 — Rozszerzenie warunków wygranej/przegranej Implementation Plan

> **For Claude:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Zaimplementować D3 schizma totalna (defeat) + 3 unikalne warunki wygranej (Western Reformacja Apostolska, Hindu Dharmiczna Trwałość, Buddhism Środkowa Droga Globalna) przez czyste rozszerzenie istniejącego `VictoryManager` (Plan 12).

**Architecture:** Czyste rozszerzenia w `VictoryManager.gd` — nowe stałe, rozszerzona logika `update_counters` (2 nowe liczniki), nowe klauzule w `evaluate_unique_victory` i `evaluate_defeat`, 3 nowe prywatne helpery. Schema dict-ów `victory_progress`/`defeat_progress` extensible o 2 nowe klucze. UI: rozszerzenie `REASON_LABELS` o 4 etykiety polskie. **Zero zmian w fixture'ach JSON, Religion, GameState, MainShell** — Plan 12 fix I3 (`defeated_reason` field) już obsługuje nowy reason `total_schism` automatycznie.

**Tech Stack:** Godot 4.6.3, GDScript 2.0, GUT (Godot Unit Testing).

**Spec:** [`docs/superpowers/specs/13-victory-extensions-design.md`](../specs/13-victory-extensions-design.md)

---

## Convention reminders (z [CLAUDE.md](../../../CLAUDE.md))

- **Tab indent** w `.gd` i `.tscn`.
- **Stałe engine tunable** — testy referencują `VictoryManager.SCHISM_TOTAL_TURNS_REQUIRED` etc., **nie hardcoduj wartości**.
- **Identyfikatory ANGIELSKIE** — pliki, klasy, zmienne, ID. Polski tylko w `Label.text`, `display_name`, komentarzach, JSON. Zgodne z memory `feedback_english_identifiers.md`.
- **Managery extend `RefCounted`**, hold no state, biorą `state: Node` jako pierwszy parametr — `VictoryManager` już jest taki.
- **Brak zmian w `class_name`** — Plan 13 nie dodaje nowych skryptów, więc `.godot/global_script_class_cache.cfg` nie wymaga regeneracji.

---

## Test command reference

```bash
# Cała suite
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# Pojedynczy plik testu (zawsze res://-absolutna ścieżka)
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_constants.gd -gexit

# Subkatalog
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gexit
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gexit
```

---

## File Structure

**Modyfikowane (brak nowych plików):**

- `scripts/engine/VictoryManager.gd` — 8 stałych, update_counters, evaluate_defeat, evaluate_unique_victory, 3 helpery.
- `scripts/ui/dialogs/GameOverDialog.gd` — 4 wpisy w `REASON_LABELS`.
- `tests/engine/test_victory_manager_constants.gd` — 1 nowy test.
- `tests/engine/test_victory_manager_flags.gd` — 8 nowych testów (counter dharma + total_schism).
- `tests/engine/test_victory_manager_unique.gd` — 10 nowych testów (Western + Hindu + Buddhism).
- `tests/engine/test_victory_manager_defeat.gd` — 5 nowych testów (D3 + precedencja).
- `tests/engine/test_victory_manager_endgame.gd` — 1 nowy test (defeated_reason).
- `tests/ui/test_game_over_dialog.gd` — 1 rozszerzenie listy reasonów.

**Mapa: spec § → plik kodu → plik testu**

| Spec §  | Plik kodu                              | Plik testu                                       | Task |
|---------|----------------------------------------|--------------------------------------------------|------|
| §6 stałe | `scripts/engine/VictoryManager.gd`    | `tests/engine/test_victory_manager_constants.gd` | 1    |
| §4 D3   | `scripts/engine/VictoryManager.gd`     | `tests/engine/test_victory_manager_flags.gd`     | 2    |
| §5.2 Hindu | `scripts/engine/VictoryManager.gd`  | `tests/engine/test_victory_manager_flags.gd`     | 3    |
| §5.1 Western | `scripts/engine/VictoryManager.gd` | `tests/engine/test_victory_manager_unique.gd`   | 4    |
| §5.2 Hindu | `scripts/engine/VictoryManager.gd`  | `tests/engine/test_victory_manager_unique.gd`    | 5    |
| §5.3 Buddhism | `scripts/engine/VictoryManager.gd` | `tests/engine/test_victory_manager_unique.gd`  | 6    |
| §4 D3 evaluate | `scripts/engine/VictoryManager.gd` | `tests/engine/test_victory_manager_defeat.gd`  | 7    |
| §4 integration | `scripts/engine/VictoryManager.gd` | `tests/engine/test_victory_manager_endgame.gd` | 8    |
| §6 UI   | `scripts/ui/dialogs/GameOverDialog.gd` | `tests/ui/test_game_over_dialog.gd`              | 9    |
| §9 docs | `CLAUDE.md`                            | — (docs only)                                    | 10   |

---

## Test helper pattern (precedens z Plan 12)

Wszystkie testy engine używają tego samego helpera (kopiowany do każdego pliku testów, lub reused gdy istnieje w plikach modyfikowanych):

```gdscript
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state(player_id: String = "islam") -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize(player_id, religions, graph)
	return gs
```

(W plikach `test_victory_manager_*.gd` ten helper już istnieje — nie duplikuj.)

---

## Chunk 1: Foundation — stałe i liczniki

---

### Task 1: VictoryManager — 8 nowych stałych Plan 13

**Cel:** Dodać stałe dla D3 schizmy totalnej i 3 unikalnych warunków wygranej. Plan 13 nie używa magic numbers — wszystkie progi tunable.

**Files:**
- Modify: `scripts/engine/VictoryManager.gd`
- Modify: `tests/engine/test_victory_manager_constants.gd`

- [ ] **Step 1: Napisz failing test stałych Plan 13**

Dopisz do `tests/engine/test_victory_manager_constants.gd`:

```gdscript
func test_plan13_constants_exist():
	# D3 schizma totalna
	assert_eq(VictoryManager.SCHISM_TOTAL_TURNS_REQUIRED, 2)
	# Western Reformacja Apostolska
	assert_eq(VictoryManager.WESTERN_ROME_ID, "rzym")
	assert_eq(VictoryManager.WESTERN_VASSALS_REQUIRED, 4)
	assert_eq(VictoryManager.WESTERN_PRESTIGE_REQUIRED, 600)
	# Hindu Dharmiczna Trwałość
	assert_eq(VictoryManager.HINDU_PROVINCES_REQUIRED, 2)
	assert_eq(VictoryManager.HINDU_DHARMA_TURNS_REQUIRED, 50)
	# Buddhism Środkowa Droga
	assert_almost_eq(VictoryManager.BUDDHISM_AXIS_D_REQUIRED, 90.0, 0.001)
	assert_eq(VictoryManager.BUDDHISM_DISTINCT_SOURCES_REQUIRED, 4)
```

- [ ] **Step 2: Uruchom — powinien failować**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_constants.gd -gexit
```

Expected: failure — `Invalid get index 'SCHISM_TOTAL_TURNS_REQUIRED'`.

- [ ] **Step 3: Dodaj stałe do `scripts/engine/VictoryManager.gd`**

Po istniejących stałych Plan 12 (po `MANICHAEISM_DISTINCT_SOURCES_REQUIRED`), **przed** komentarzem `# === Public API`:

```gdscript

# === Plan 13: schizma totalna (D3 defeat) ===
const SCHISM_TOTAL_TURNS_REQUIRED := 2				# trzy frakcje w fazie 3 przez N tur → defeat

# === Plan 13: unikalne warunki — Western Christianity ===
const WESTERN_ROME_ID := "rzym"
const WESTERN_VASSALS_REQUIRED := 4
const WESTERN_PRESTIGE_REQUIRED := 600

# === Plan 13: unikalne warunki — Hinduism ===
const HINDU_PROVINCES_REQUIRED := 2
const HINDU_DHARMA_TURNS_REQUIRED := 50

# === Plan 13: unikalne warunki — Buddhism ===
const BUDDHISM_AXIS_D_REQUIRED := 90.0
const BUDDHISM_DISTINCT_SOURCES_REQUIRED := 4
```

- [ ] **Step 4: Uruchom — pass**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_constants.gd -gexit
```

Expected: wszystkie testy pass (Plan 12 + nowy Plan 13).

- [ ] **Step 5: Cała suite — brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: 654/654 + 1 nowy = 655 testów, wszystkie passing.

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/VictoryManager.gd tests/engine/test_victory_manager_constants.gd
git commit -m "feat(victory): Plan 13 stale — D3 schizma + Western/Hindu/Buddhism unique"
```

---

### Task 2: VictoryManager.update_counters — total_schism_turns

**Cel:** Dodać licznik `total_schism_turns` w `state.defeat_progress[id]` inkrementowany gdy wszystkie 3 frakcje religii mają `tension >= PHASE3_THRESHOLD`, resetowany w przeciwnym razie. Pomija religie z `defeated_at_turn != -1`.

**Files:**
- Modify: `scripts/engine/VictoryManager.gd`
- Modify: `tests/engine/test_victory_manager_flags.gd`

- [ ] **Step 1: Napisz failing testy**

Dopisz do `tests/engine/test_victory_manager_flags.gd` (na końcu pliku):

```gdscript
# === Plan 13: total_schism_turns counter ===

func test_update_counters_initializes_total_schism_turns_zero():
	var gs := _make_state()
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.defeat_progress.get("islam", {})
	assert_eq(prog.get("total_schism_turns", -1), 0,
		"po pierwszym update licznik istnieje i jest 0")

func test_update_counters_increments_total_schism_when_all_three_factions_phase_3():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	# Wszystkie 3 frakcje w fazie 3 (tension >= 85)
	for f: Faction in rel.factions:
		f.tension = 90.0
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.defeat_progress.get("islam", {})
	assert_eq(prog.get("total_schism_turns", 0), 1)
	vm.update_counters(gs)
	prog = gs.defeat_progress.get("islam", {})
	assert_eq(prog.get("total_schism_turns", 0), 2)

func test_update_counters_resets_total_schism_when_one_faction_drops_below_phase_3():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	# Symulacja: licznik już > 0
	gs.defeat_progress["islam"] = {"zero_provinces_turns": 0, "vassalage_turns": 0, "total_schism_turns": 1}
	# Tylko 2 z 3 w fazie 3
	rel.factions[0].tension = 90.0
	rel.factions[1].tension = 90.0
	rel.factions[2].tension = 80.0  # poniżej PHASE3_THRESHOLD
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.defeat_progress.get("islam", {})
	assert_eq(prog.get("total_schism_turns", 0), 0, "jedna frakcja poniżej → reset")

func test_update_counters_total_schism_requires_exactly_3_factions():
	# Edge case: religia z != 3 frakcjami (np. po schizmie utraciła frakcję)
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	# Usuwamy jedną frakcję (zostały 2)
	rel.factions.pop_back()
	assert_eq(rel.factions.size(), 2)
	# Obie pozostałe w fazie 3
	for f: Faction in rel.factions:
		f.tension = 90.0
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.defeat_progress.get("islam", {})
	assert_eq(prog.get("total_schism_turns", 0), 0,
		"religia z mniej niż 3 frakcjami nie inkrementuje (faktyczna schizma już zaszła)")

func test_update_counters_total_schism_does_not_touch_defeated_religion():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("manichaeism")
	rel.defeated_at_turn = 50  # pokonana
	for f: Faction in rel.factions:
		f.tension = 90.0
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	assert_false(gs.defeat_progress.has("manichaeism"),
		"pokonana religia nie podlega update_counters")
```

- [ ] **Step 2: Uruchom — powinno failować**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_flags.gd -gexit
```

Expected: 4 z 5 nowych testów failuje (default w `defeat_progress` nie zawiera klucza `total_schism_turns`; counter nie istnieje).

- [ ] **Step 3: Zmodyfikuj `scripts/engine/VictoryManager.gd`**

**Krok A:** Zmodyfikuj wywołanie `_ensure_progress_entry` dla `defeat_progress` w `update_counters` (Plan 12). Wewnątrz pętli per-religia, znajdź linię:

```gdscript
_ensure_progress_entry(state.defeat_progress, religion.id, {"zero_provinces_turns": 0, "vassalage_turns": 0})
```

Zmień na:

```gdscript
_ensure_progress_entry(state.defeat_progress, religion.id, {"zero_provinces_turns": 0, "vassalage_turns": 0, "total_schism_turns": 0})
```

**Krok B:** Po istniejących increment'ach `zero_provinces_turns` / `vassalage_turns` w `update_counters`, **wewnątrz tej samej pętli per-religia**, dodaj logikę total_schism:

```gdscript
		# Plan 13 §4: total_schism — wszystkie 3 frakcje w fazie 3 (tension >= PHASE3_THRESHOLD).
		# Religie ze schism mają < 3 frakcji (utracona została do nowej religii) — wtedy guard fail.
		var all_phase_3: bool = religion.factions.size() == 3
		if all_phase_3:
			for f: Faction in religion.factions:
				if f.tension < SchismManager.PHASE3_THRESHOLD:
					all_phase_3 = false
					break
		if all_phase_3:
			state.defeat_progress[religion.id]["total_schism_turns"] += 1
		else:
			state.defeat_progress[religion.id]["total_schism_turns"] = 0
```

- [ ] **Step 4: Uruchom — pass**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_flags.gd -gexit
```

Expected: wszystkie testy pass (stare + 5 nowych).

- [ ] **Step 5: Cała suite — brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: All tests passed.

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/VictoryManager.gd tests/engine/test_victory_manager_flags.gd
git commit -m "feat(victory): update_counters — total_schism_turns (Plan 13 D3 prereq)"
```

---

### Task 3: VictoryManager.update_counters — dharma_turns (Hindu)

**Cel:** Dodać licznik `dharma_turns` w `state.victory_progress[id]` inkrementowany TYLKO dla religii `hinduism` gdy ma ≥ `HINDU_PROVINCES_REQUIRED` (2) prowincji. Pomija inne religie i pokonane.

**Files:**
- Modify: `scripts/engine/VictoryManager.gd`
- Modify: `tests/engine/test_victory_manager_flags.gd`

- [ ] **Step 1: Napisz failing testy**

Dopisz do `tests/engine/test_victory_manager_flags.gd`:

```gdscript
# === Plan 13: dharma_turns counter (Hindu) ===

func test_update_counters_initializes_dharma_turns_zero():
	var gs := _make_state()
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("hinduism", {})
	assert_eq(prog.get("dharma_turns", -1), 0,
		"po pierwszym update licznik istnieje i jest 0")

func test_update_counters_increments_dharma_when_hindu_owns_2_provinces():
	var gs := _make_state()
	# Hindu startowo nie ma prowincji — daj 2
	gs.province_graph.get_province("mekka").owner = "hinduism"
	gs.province_graph.get_province("lewant").owner = "hinduism"
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("hinduism", {})
	assert_eq(prog.get("dharma_turns", 0), 1)
	vm.update_counters(gs)
	prog = gs.victory_progress.get("hinduism", {})
	assert_eq(prog.get("dharma_turns", 0), 2)

func test_update_counters_resets_dharma_when_hindu_owns_only_1_province():
	var gs := _make_state()
	gs.victory_progress["hinduism"] = {"domination_turns": 0, "prestige_hegemony_turns": 0, "dharma_turns": 30}
	# Hindu ma 1 prowincję
	gs.province_graph.get_province("mekka").owner = "hinduism"
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("hinduism", {})
	assert_eq(prog.get("dharma_turns", 0), 0, "spadek poniżej progu → reset")

func test_update_counters_only_increments_dharma_for_hinduism():
	# Inne religie (np. islam) nie mają licznika dharma_turns inkrementowanego nawet z ≥ 2 prowincji
	var gs := _make_state()
	# Islam startowo ma 1 prowincję (mezopotamia), dodajmy drugą
	gs.province_graph.get_province("lewant").owner = "islam"
	assert_gt(gs.province_graph.provinces_with_owner("islam").size(), 1)
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("islam", {})
	# Klucz dharma_turns istnieje (default 0) ale nie inkrementuje dla islamu
	assert_eq(prog.get("dharma_turns", -1), 0)
```

- [ ] **Step 2: Uruchom — powinno failować**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_flags.gd -gexit
```

Expected: 3 z 4 nowych testów failuje (klucz `dharma_turns` nie w default schema).

- [ ] **Step 3: Zmodyfikuj `scripts/engine/VictoryManager.gd`**

**Krok A:** Zmodyfikuj wywołanie `_ensure_progress_entry` dla `victory_progress` w `update_counters` (Plan 12):

```gdscript
_ensure_progress_entry(state.victory_progress, religion.id, {"domination_turns": 0, "prestige_hegemony_turns": 0})
```

Zmień na:

```gdscript
_ensure_progress_entry(state.victory_progress, religion.id, {"domination_turns": 0, "prestige_hegemony_turns": 0, "dharma_turns": 0})
```

**Krok B:** Po istniejących increment'ach `domination_turns` / `prestige_hegemony_turns` w `update_counters`, **wewnątrz tej samej pętli per-religia**, dodaj logikę dharma:

```gdscript
		# Plan 13 §5.2: hindu dharma — kontrola ≥ HINDU_PROVINCES_REQUIRED prowincji.
		# Tylko Hinduizm — inne religie mają default 0 i nie podlegają.
		if religion.id == "hinduism":
			if owned >= HINDU_PROVINCES_REQUIRED:
				state.victory_progress[religion.id]["dharma_turns"] += 1
			else:
				state.victory_progress[religion.id]["dharma_turns"] = 0
```

(`owned` jest local variable z Plan 12 update_counters, computed wcześniej w pętli.)

- [ ] **Step 4: Uruchom — pass**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_flags.gd -gexit
```

Expected: wszystkie testy pass.

- [ ] **Step 5: Cała suite — brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/VictoryManager.gd tests/engine/test_victory_manager_flags.gd
git commit -m "feat(victory): update_counters — dharma_turns dla Hinduizmu (Plan 13)"
```

---

## Chunk 2: Unique victories — 3 religie

---

### Task 4: Western Christianity — "Reformacja Apostolska"

**Cel:** Dodać `_western_reformation_satisfied` helper + klauzulę w `evaluate_unique_victory`. Religia spełnia warunek gdy kontroluje Rzym + ma ≥4 wasali + prestiż ≥600.

**Files:**
- Modify: `scripts/engine/VictoryManager.gd`
- Modify: `tests/engine/test_victory_manager_unique.gd`

- [ ] **Step 1: Napisz failing testy**

Dopisz do `tests/engine/test_victory_manager_unique.gd` (na końcu pliku, przed `# === No unique victory dla innych religii ===` jeśli istnieje):

```gdscript
# === Plan 13: Western Christianity ===

func test_western_reformation_requires_rome_4_vassals_and_prestige_600():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("western_christianity")
	# Rzym jest startowo Western — sanity
	assert_eq(gs.province_graph.get_province("rzym").owner, "western_christianity")
	# 4 wasali
	gs.get_religion("coptic_christianity").suzerain_id = "western_christianity"
	gs.get_religion("judaism").suzerain_id = "western_christianity"
	gs.get_religion("zoroastrianism").suzerain_id = "western_christianity"
	gs.get_religion("islam").suzerain_id = "western_christianity"
	rel.prestige = 600
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "western_reformation")

func test_western_reformation_blocked_without_rome():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("western_christianity")
	gs.province_graph.get_province("rzym").owner = "islam"  # utrata Rzymu
	gs.get_religion("coptic_christianity").suzerain_id = "western_christianity"
	gs.get_religion("judaism").suzerain_id = "western_christianity"
	gs.get_religion("zoroastrianism").suzerain_id = "western_christianity"
	gs.get_religion("islam").suzerain_id = "western_christianity"
	rel.prestige = 600
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

func test_western_reformation_blocked_with_3_vassals():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("western_christianity")
	gs.get_religion("coptic_christianity").suzerain_id = "western_christianity"
	gs.get_religion("judaism").suzerain_id = "western_christianity"
	gs.get_religion("zoroastrianism").suzerain_id = "western_christianity"
	rel.prestige = 600
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

func test_western_reformation_blocked_with_prestige_599():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("western_christianity")
	gs.get_religion("coptic_christianity").suzerain_id = "western_christianity"
	gs.get_religion("judaism").suzerain_id = "western_christianity"
	gs.get_religion("zoroastrianism").suzerain_id = "western_christianity"
	gs.get_religion("islam").suzerain_id = "western_christianity"
	rel.prestige = VictoryManager.WESTERN_PRESTIGE_REQUIRED - 1
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

func test_western_reformation_safe_when_rome_missing_from_graph():
	# Null guard — custom map bez Rzymu nie crashuje
	var gs := _make_state()
	var rel: Religion = gs.get_religion("western_christianity")
	gs.province_graph._provinces.erase("rzym")
	rel.prestige = 600
	gs.get_religion("coptic_christianity").suzerain_id = "western_christianity"
	gs.get_religion("judaism").suzerain_id = "western_christianity"
	gs.get_religion("zoroastrianism").suzerain_id = "western_christianity"
	gs.get_religion("islam").suzerain_id = "western_christianity"
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")
```

- [ ] **Step 2: Uruchom — powinno failować**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_unique.gd -gexit
```

Expected: `test_western_reformation_requires_rome_4_vassals_and_prestige_600` failuje (zwraca `""` zamiast `"western_reformation"`).

- [ ] **Step 3: Dodaj klauzulę + helper do `scripts/engine/VictoryManager.gd`**

**Krok A:** W `evaluate_unique_victory`, w match-statement, dodaj klauzulę po istniejących klauzulach Plan 12, **przed** `_:` (default) jeśli istnieje, albo na końcu match:

```gdscript
		"western_christianity":
			if _western_reformation_satisfied(religion, state):
				return "western_reformation"
```

**Krok B:** Dodaj helper na końcu pliku (po istniejących Plan 12 helperach `_germanic_ragnarok_satisfied`):

```gdscript
func _western_reformation_satisfied(religion: Religion, state: Node) -> bool:
	# Spec 13 §5.1: kontrola Rzymu + ≥ WESTERN_VASSALS_REQUIRED wasali + prestiż ≥ WESTERN_PRESTIGE_REQUIRED.
	var rome: Province = state.province_graph.get_province(WESTERN_ROME_ID)
	if rome == null or rome.owner != religion.id:
		return false
	if religion.prestige < WESTERN_PRESTIGE_REQUIRED:
		return false
	var vassal_count: int = 0
	for r: Religion in state.all_religions():
		if r.suzerain_id == religion.id:
			vassal_count += 1
	return vassal_count >= WESTERN_VASSALS_REQUIRED
```

- [ ] **Step 4: Uruchom — pass**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_unique.gd -gexit
```

Expected: 5 nowych testów pass.

- [ ] **Step 5: Cała suite — brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/VictoryManager.gd tests/engine/test_victory_manager_unique.gd
git commit -m "feat(victory): Western Christianity unique — Reformacja Apostolska (Plan 13)"
```

---

### Task 5: Hinduism — "Dharmiczna Trwałość"

**Cel:** Dodać `_hindu_dharma_satisfied` helper + klauzulę w `evaluate_unique_victory`. Religia spełnia warunek gdy licznik `dharma_turns` (z Task 3) osiągnie próg 50.

**Files:**
- Modify: `scripts/engine/VictoryManager.gd`
- Modify: `tests/engine/test_victory_manager_unique.gd`

- [ ] **Step 1: Napisz failing testy**

Dopisz do `tests/engine/test_victory_manager_unique.gd`:

```gdscript
# === Plan 13: Hinduism ===

func _set_victory_counter(state: Node, rid: String, key: String, value: int) -> void:
	if not state.victory_progress.has(rid):
		state.victory_progress[rid] = {"domination_turns": 0, "prestige_hegemony_turns": 0, "dharma_turns": 0}
	state.victory_progress[rid][key] = value

func test_hindu_dharma_requires_50_turns_counter():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("hinduism")
	_set_victory_counter(gs, "hinduism", "dharma_turns", VictoryManager.HINDU_DHARMA_TURNS_REQUIRED)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "hindu_dharma")

func test_hindu_dharma_blocked_with_49_turns():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("hinduism")
	_set_victory_counter(gs, "hinduism", "dharma_turns", VictoryManager.HINDU_DHARMA_TURNS_REQUIRED - 1)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

func test_hindu_dharma_blocked_when_counter_missing():
	# Nigdy nie był aktualizowany counter (np. religia nigdy nie miała ≥ 2 prowincji)
	var gs := _make_state()
	var rel: Religion = gs.get_religion("hinduism")
	# victory_progress["hinduism"] nie istnieje
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")
```

- [ ] **Step 2: Uruchom — powinno failować**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_unique.gd -gexit
```

Expected: `test_hindu_dharma_requires_50_turns_counter` failuje (zwraca `""`).

- [ ] **Step 3: Dodaj klauzulę + helper do `scripts/engine/VictoryManager.gd`**

**Krok A:** W `evaluate_unique_victory`, w match-statement, dodaj:

```gdscript
		"hinduism":
			if _hindu_dharma_satisfied(religion, state):
				return "hindu_dharma"
```

**Krok B:** Dodaj helper:

```gdscript
func _hindu_dharma_satisfied(religion: Religion, state: Node) -> bool:
	# Spec 13 §5.2: kontrola ≥ HINDU_PROVINCES_REQUIRED prowincji przez ≥ HINDU_DHARMA_TURNS_REQUIRED kolejnych tur.
	# Counter dharma_turns aktualizowany w update_counters (Plan 13 Task 3).
	var vp: Dictionary = state.victory_progress.get(religion.id, {})
	return vp.get("dharma_turns", 0) >= HINDU_DHARMA_TURNS_REQUIRED
```

- [ ] **Step 4: Uruchom — pass**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_unique.gd -gexit
```

- [ ] **Step 5: Cała suite — brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/VictoryManager.gd tests/engine/test_victory_manager_unique.gd
git commit -m "feat(victory): Hinduism unique — Dharmiczna Trwalosc (Plan 13)"
```

---

### Task 6: Buddhism — "Środkowa Droga Globalna"

**Cel:** Dodać `_buddhism_middle_way_satisfied` helper + klauzulę w `evaluate_unique_victory`. Analog Manicheism (Plan 12) ale na osi D zamiast C. Brak prereq prowincjowych — Buddhism może wygrać z 0 prowincji.

**Files:**
- Modify: `scripts/engine/VictoryManager.gd`
- Modify: `tests/engine/test_victory_manager_unique.gd`

- [ ] **Step 1: Napisz failing testy**

Dopisz do `tests/engine/test_victory_manager_unique.gd`:

```gdscript
# === Plan 13: Buddhism ===

func test_buddhism_middle_way_requires_D_90_and_4_sources():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("buddhism")
	rel.axes["D"] = 90.0
	rel.absorbed_idea_sources = ["islam", "judaism", "hinduism", "manichaeism"]
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "buddhism_middle_way")

func test_buddhism_middle_way_blocked_with_D_89():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("buddhism")
	rel.axes["D"] = 89.0
	rel.absorbed_idea_sources = ["islam", "judaism", "hinduism", "manichaeism", "zoroastrianism"]
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

func test_buddhism_middle_way_blocked_with_3_sources():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("buddhism")
	rel.axes["D"] = 95.0
	rel.absorbed_idea_sources = ["islam", "judaism", "hinduism"]
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

func test_buddhism_can_win_with_zero_provinces():
	# Analog test_manichaeism_can_win_with_zero_provinces — Buddhism startowo bez prowincji
	var gs := _make_state()
	var rel: Religion = gs.get_religion("buddhism")
	rel.axes["D"] = 90.0
	rel.absorbed_idea_sources = ["islam", "judaism", "hinduism", "manichaeism"]
	assert_false(rel.ever_owned_province, "buddhism startuje bez prowincji w fixture")
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "buddhism_middle_way")
```

- [ ] **Step 2: Uruchom — powinno failować**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_unique.gd -gexit
```

Expected: pozytywne testy failują (return `""`).

- [ ] **Step 3: Dodaj klauzulę + helper do `scripts/engine/VictoryManager.gd`**

**Krok A:** W `evaluate_unique_victory`, w match-statement, dodaj:

```gdscript
		"buddhism":
			if _buddhism_middle_way_satisfied(religion, state):
				return "buddhism_middle_way"
```

**Krok B:** Dodaj helper:

```gdscript
func _buddhism_middle_way_satisfied(religion: Religion, state: Node) -> bool:
	# Spec 13 §5.3: oś D (Transcendencja) >= BUDDHISM_AXIS_D_REQUIRED + ≥ BUDDHISM_DISTINCT_SOURCES_REQUIRED źródeł.
	# Analog Manicheism (oś C), Buddhism focused na D.
	if religion.get_axis("D") < BUDDHISM_AXIS_D_REQUIRED:
		return false
	return religion.absorbed_idea_sources.size() >= BUDDHISM_DISTINCT_SOURCES_REQUIRED
```

- [ ] **Step 4: Uruchom — pass**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_unique.gd -gexit
```

- [ ] **Step 5: Cała suite — brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/VictoryManager.gd tests/engine/test_victory_manager_unique.gd
git commit -m "feat(victory): Buddhism unique — Srodkowa Droga Globalna (Plan 13)"
```

---

## Chunk 3: D3 defeat + UI

---

### Task 7: VictoryManager.evaluate_defeat — D3 total_schism z precedencją

**Cel:** Rozszerzyć `evaluate_defeat` o sprawdzenie D3 `total_schism` po D1 elimination i **przed** D2 long_vassalage. Precedencja: D1 > D3 > D2.

**Files:**
- Modify: `scripts/engine/VictoryManager.gd`
- Modify: `tests/engine/test_victory_manager_defeat.gd`

- [ ] **Step 1: Napisz failing testy**

Dopisz do `tests/engine/test_victory_manager_defeat.gd`:

```gdscript
# === Plan 13: D3 total_schism ===

func test_total_schism_returns_reason_at_threshold():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.ever_owned_province = true
	_set_defeat_counter(gs, "islam", "total_schism_turns", VictoryManager.SCHISM_TOTAL_TURNS_REQUIRED)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_defeat(rel, gs), "total_schism")

func test_total_schism_blocked_without_ever_owned_province():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("manichaeism")
	assert_false(rel.ever_owned_province)
	_set_defeat_counter(gs, "manichaeism", "total_schism_turns", 100)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_defeat(rel, gs), "")

func test_total_schism_blocked_one_below_threshold():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.ever_owned_province = true
	_set_defeat_counter(gs, "islam", "total_schism_turns", VictoryManager.SCHISM_TOTAL_TURNS_REQUIRED - 1)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_defeat(rel, gs), "")

func test_elimination_takes_precedence_over_total_schism():
	# D1 > D3 — eliminacja jest najdefinitywniejsza
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.ever_owned_province = true
	_set_defeat_counter(gs, "islam", "zero_provinces_turns", VictoryManager.ELIMINATION_TURNS_REQUIRED)
	_set_defeat_counter(gs, "islam", "total_schism_turns", VictoryManager.SCHISM_TOTAL_TURNS_REQUIRED)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_defeat(rel, gs), "elimination")

func test_total_schism_takes_precedence_over_long_vassalage():
	# D3 > D2 — schizma totalna jest bardziej dramatyczna od długiej wassalaży
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.ever_owned_province = true
	_set_defeat_counter(gs, "islam", "total_schism_turns", VictoryManager.SCHISM_TOTAL_TURNS_REQUIRED)
	_set_defeat_counter(gs, "islam", "vassalage_turns", VictoryManager.VASSAL_DEFEAT_TURNS_REQUIRED)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_defeat(rel, gs), "total_schism")
```

NOTE: Funkcja `_set_defeat_counter` istnieje w `test_victory_manager_defeat.gd` z Plan 12. **Sprawdź** czy default dict zawiera `total_schism_turns`. Jeśli nie, zaktualizuj helper:

```gdscript
func _set_defeat_counter(state: Node, rid: String, key: String, value: int) -> void:
	if not state.defeat_progress.has(rid):
		state.defeat_progress[rid] = {"zero_provinces_turns": 0, "vassalage_turns": 0, "total_schism_turns": 0}
	state.defeat_progress[rid][key] = value
```

Modify helper if needed in a separate small edit before adding the tests.

- [ ] **Step 2: Uruchom — powinno failować**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_defeat.gd -gexit
```

Expected: nowe testy failują (return values niezgodne).

- [ ] **Step 3: Zmodyfikuj `evaluate_defeat` w `scripts/engine/VictoryManager.gd`**

Aktualnie po Plan 12:

```gdscript
func evaluate_defeat(religion: Religion, state: Node) -> String:
	if not religion.ever_owned_province:
		return ""
	var dp: Dictionary = state.defeat_progress.get(religion.id, {})
	if dp.get("zero_provinces_turns", 0) >= ELIMINATION_TURNS_REQUIRED:
		return "elimination"
	if dp.get("vassalage_turns", 0) >= VASSAL_DEFEAT_TURNS_REQUIRED:
		return "long_vassalage"
	return ""
```

Zmień na:

```gdscript
func evaluate_defeat(religion: Religion, state: Node) -> String:
	# Spec §5 (Plan 12) + Plan 13 §4: D1 → D3 → D2 (precedencja).
	if not religion.ever_owned_province:
		return ""
	var dp: Dictionary = state.defeat_progress.get(religion.id, {})
	if dp.get("zero_provinces_turns", 0) >= ELIMINATION_TURNS_REQUIRED:
		return "elimination"
	if dp.get("total_schism_turns", 0) >= SCHISM_TOTAL_TURNS_REQUIRED:
		return "total_schism"
	if dp.get("vassalage_turns", 0) >= VASSAL_DEFEAT_TURNS_REQUIRED:
		return "long_vassalage"
	return ""
```

- [ ] **Step 4: Uruchom — pass**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_defeat.gd -gexit
```

Expected: wszystkie testy pass (Plan 12 + 5 nowych Plan 13).

- [ ] **Step 5: Cała suite — brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/VictoryManager.gd tests/engine/test_victory_manager_defeat.gd
git commit -m "feat(victory): evaluate_defeat — D3 total_schism (Plan 13) z precedencja D1 > D3 > D2"
```

---

### Task 8: Endgame integration — defeated_reason dla total_schism

**Cel:** Test integracyjny `check()` ustawia `religion.defeated_reason = "total_schism"` gdy D3 trigger. Confirm Plan 12 fix I3 (defeated_reason persistence) działa dla nowego reasonu.

**Files:**
- Modify: `tests/engine/test_victory_manager_endgame.gd`

- [ ] **Step 1: Napisz failing test**

Dopisz do `tests/engine/test_victory_manager_endgame.gd`:

```gdscript
func test_check_sets_defeated_reason_on_total_schism():
	# Plan 13: gdy D3 triggeruje, defeated_reason == "total_schism"
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.ever_owned_province = true
	# Ustaw licznik tuż przed threshold + symulacja ostatniej tury (3 frakcje w fazie 3)
	gs.defeat_progress["islam"] = {"zero_provinces_turns": 0, "vassalage_turns": 0, "total_schism_turns": VictoryManager.SCHISM_TOTAL_TURNS_REQUIRED - 1}
	for f: Faction in rel.factions:
		f.tension = 90.0
	gs.current_turn = 80
	var vm := VictoryManager.new()
	vm.check(gs)
	assert_eq(rel.defeated_at_turn, 80)
	assert_eq(rel.defeated_reason, "total_schism")
```

- [ ] **Step 2: Uruchom — powinno failować**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_endgame.gd -gexit
```

Expected: failure (defeated_reason `""` lub `"long_vassalage"` zamiast `"total_schism"`).

**UWAGA:** jeśli test PASS (nie failuje), pomiń step 3 i przejdź do step 4. To znak że Plan 12 fix I3 + Task 7 już zapewniły poprawne podłączenie i nowy test po prostu weryfikuje rezultat. Jeśli FAIL — diagnoza w Step 3.

- [ ] **Step 3: Diagnoza brakującego elementu (TYLKO gdy Step 2 FAILED)**

Test wymaga **tylko** kombinacji Task 2 (update_counters increment) + Task 7 (evaluate_defeat returns "total_schism") + Plan 12 fix I3 (defeated_reason persistence in check). Jeśli failuje, sprawdź:
- Task 2 commit'owany.
- Task 7 commit'owany.
- W `VictoryManager.check` (Plan 12) `religion.defeated_reason = defeat_reason` istnieje po `religion.defeated_at_turn = state.current_turn`.

Jeśli któraś z tych warunków nie jest spełniona, naprawić w odpowiednim task'u, nie tutaj.

- [ ] **Step 4: Uruchom — pass**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_endgame.gd -gexit
```

- [ ] **Step 5: Cała suite — brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- [ ] **Step 6: Commit**

```bash
git add tests/engine/test_victory_manager_endgame.gd
git commit -m "test(victory): defeated_reason == 'total_schism' po D3 check (Plan 13)"
```

---

### Task 9: GameOverDialog — 4 nowe etykiety polskie

**Cel:** Dodać polskie etykiety dla 4 nowych reasonów (`total_schism`, `western_reformation`, `hindu_dharma`, `buddhism_middle_way`) w `REASON_LABELS`.

**Files:**
- Modify: `scripts/ui/dialogs/GameOverDialog.gd`
- Modify: `tests/ui/test_game_over_dialog.gd`

- [ ] **Step 1: Napisz failing test (rozszerz istniejący Plan 12 test)**

W `tests/ui/test_game_over_dialog.gd` istnieje test:

```gdscript
func test_dialog_maps_all_reasons_to_non_empty_polish_labels():
	var dialog := _instantiate()
	var reasons := ["domination", "prestige_hegemony", "holy_land",
		"manichaeism_illumination", "judaism_return", "zoroastrianism_renaissance",
		"east_christianity_pentarchy", "islam_caliphate", "germanic_ragnarok",
		"turn_limit", "elimination", "long_vassalage"]
	for r: String in reasons:
		var outcome := _make_outcome("islam", r)
		dialog.show_outcome(outcome)
		var text: String = dialog.get_reason_text()
		assert_ne(text, "", "Reason " + r + " powinien mieć etykietę")
```

Rozszerz listę `reasons` o 4 nowe wpisy Plan 13:

```gdscript
func test_dialog_maps_all_reasons_to_non_empty_polish_labels():
	var dialog := _instantiate()
	var reasons := ["domination", "prestige_hegemony", "holy_land",
		"manichaeism_illumination", "judaism_return", "zoroastrianism_renaissance",
		"east_christianity_pentarchy", "islam_caliphate", "germanic_ragnarok",
		"turn_limit", "elimination", "long_vassalage",
		# Plan 13:
		"total_schism", "western_reformation", "hindu_dharma", "buddhism_middle_way"]
	for r: String in reasons:
		var outcome := _make_outcome("islam", r)
		dialog.show_outcome(outcome)
		var text: String = dialog.get_reason_text()
		assert_ne(text, "", "Reason " + r + " powinien mieć etykietę")
```

(Dodaj też nowy stand-alone test dla pewności:)

```gdscript
func test_dialog_maps_plan13_reasons_to_polish_labels():
	# Plan 13: weryfikacja polskich etykiet dla 4 nowych reasonów
	var dialog := _instantiate()
	var expected_labels := {
		"total_schism": "Totalna Schizma",
		"western_reformation": "Reformacja Apostolska",
		"hindu_dharma": "Dharmiczna Trwałość",
		"buddhism_middle_way": "Środkowa Droga Globalna",
	}
	for reason: String in expected_labels:
		var outcome := _make_outcome("islam", reason)
		dialog.show_outcome(outcome)
		var text: String = dialog.get_reason_text()
		assert_true(text.contains(expected_labels[reason]),
			"Reason " + reason + " powinien zawierać '" + expected_labels[reason] + "', miał: " + text)
```

- [ ] **Step 2: Uruchom — powinno failować**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_game_over_dialog.gd -gexit
```

Expected: nowy test + rozszerzony test failują (brak etykiet w REASON_LABELS — fallback wyświetla samo reason ID).

- [ ] **Step 3: Dodaj etykiety do `scripts/ui/dialogs/GameOverDialog.gd`**

Rozszerz `REASON_LABELS` dict — dodaj 4 wpisy **przed** zamykającym `}`:

```gdscript
const REASON_LABELS: Dictionary = {
	"domination": "Dominacja terytorialna",
	"prestige_hegemony": "Hegemonia prestiżu",
	"holy_land": "Święta Ziemia",
	"manichaeism_illumination": "Synkretyczna Iluminacja (Manicheizm)",
	"judaism_return": "Powrót do Syjonu (Judaizm)",
	"zoroastrianism_renaissance": "Renesans Saszański (Zoroastryzm)",
	"east_christianity_pentarchy": "Pentarchia (Chrześcijaństwo Wschodnie)",
	"islam_caliphate": "Pełen Kalifat (Islam)",
	"germanic_ragnarok": "Ragnarök Triumfalny (Religie Germańskie)",
	"turn_limit": "Koniec ery (limit 200 tur)",
	"elimination": "Eliminacja",
	"long_vassalage": "Długi wasal",
	# Plan 13:
	"total_schism": "Totalna Schizma",
	"western_reformation": "Reformacja Apostolska (Chrześcijaństwo Zachodnie)",
	"hindu_dharma": "Dharmiczna Trwałość (Hinduizm)",
	"buddhism_middle_way": "Środkowa Droga Globalna (Buddyzm)",
}
```

- [ ] **Step 4: Uruchom — pass**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_game_over_dialog.gd -gexit
```

Expected: wszystkie testy UI pass.

- [ ] **Step 5: Cała suite — brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/dialogs/GameOverDialog.gd tests/ui/test_game_over_dialog.gd
git commit -m "feat(ui): GameOverDialog REASON_LABELS — 4 nowe etykiety polskie (Plan 13)"
```

---

## Chunk 4: Cleanup

---

### Task 10: CLAUDE.md update

**Cel:** Krótka wzmianka w CLAUDE.md że Plan 13 dodał D3 + 3 unique victories. Opcjonalny (acceptance criterion §9 spec 13).

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Zaktualizuj `CLAUDE.md`**

Przeczytaj `CLAUDE.md`. W sekcji "Spec-driven workflow" lub na końcu wzmianki o Plan 12, dodaj:

```
- Plan 13 (`docs/superpowers/specs/13-victory-extensions-design.md`) rozszerza Plan 12 o D3 schizma totalna (3 frakcje w fazie 3 przez 2 tury) i 3 unikalne warunki wygranej: Reformacja Apostolska (Chrześcijaństwo Zachodnie), Dharmiczna Trwałość (Hinduizm), Środkowa Droga Globalna (Buddyzm).
```

Wybierz miejsce w `CLAUDE.md` które ma sens — np. tuż po istniejącej wzmiance o Plan 12 (linia "**End-of-game flow:** `MainShell` instancjonuje `GameOverDialog`..." z Plan 12 Task 18).

- [ ] **Step 2: Cała suite — sanity**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: All tests passed.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: wzmianka o Plan 13 w CLAUDE.md (D3 schizma + 3 unique victories)"
```

---

## Podsumowanie zakresu i kolejności

| Chunk | Tasks | Pliki kodu | Pliki testów |
|-------|-------|-----------|--------------|
| 1: Foundation | 1–3 | VictoryManager (stałe + 2 liczniki) | test_victory_manager_constants + _flags |
| 2: Unique victories | 4–6 | VictoryManager (3 helpery + match clauses) | test_victory_manager_unique |
| 3: D3 + UI | 7–9 | VictoryManager (evaluate_defeat) + GameOverDialog | test_victory_manager_defeat + _endgame + test_game_over_dialog |
| 4: Cleanup | 10 | CLAUDE.md | — |

**Łącznie: 10 tasków, ~25 nowych testów, brak zmian w fixture'ach JSON, brak zmian w Religion/GameState/MainShell.**

**Edge cases świadomie obsłużone:**

- Religia ze schism (utrata frakcji do nowej religii) — `factions.size() == 3` guard chroni `total_schism_turns` przed inkrementem (Task 2 test_update_counters_total_schism_requires_exactly_3_factions).
- Hindu null guard — `dharma_turns` resetuje do 0 gdy spadek poniżej 2 prowincji (Task 3 test_update_counters_resets_dharma_when_hindu_owns_only_1_province).
- Western null guard — null province (custom map bez Rzymu) zwraca false, nie crashuje (Task 4 test_western_reformation_safe_when_rome_missing_from_graph).
- Buddhism bez prowincji — wygrywa nawet z `ever_owned_province == false`, bez prereq prowincjowych (Task 6 test_buddhism_can_win_with_zero_provinces).
- Defeated religion skip — `update_counters` pomija religie z `defeated_at_turn != -1` (Plan 12 zachowane).
- Precedencja D1 > D3 > D2 — testy explicite weryfikują kolejność (Task 7).

**Brak modyfikacji w istniejących Plan 12 testach** poza rozszerzeniem 1 testu UI o nowe reasony (Task 9, additive only).

---

## Otwarte dla wykonawcy

- **Lokalizacja klauzul w `evaluate_unique_victory`**: Plan 12 ma 6 klauzul w match. Plan 13 dodaje 3 — kolejność nie ma znaczenia funkcjonalnie (każda religia ma najwyżej jeden match). Sugerowana kolejność (alfabetyczna lub flavor-spójna): manichaeism → judaism → zoroastrianism → eastern_christianity → islam → germanic_paganism (Plan 12) → western_christianity → hinduism → buddhism (Plan 13). Albo grupowanie chrześcijańskie (eastern + western razem).

- **`SchismManager.PHASE3_THRESHOLD` reference**: w Task 2 używamy `SchismManager.PHASE3_THRESHOLD` — sprawdź czy importować/referencować static const z innej klasy działa. Alternatywa: zduplikować stałą w `VictoryManager` jako `VICTORY_SCHISM_PHASE3 = 85.0`, ale wtedy dryf wartości. Preferowane: bezpośredni reference `SchismManager.PHASE3_THRESHOLD`.

- **Test isolation**: testy używają `_make_state()` które tworzy `Node` — pamiętać o `add_child_autofree` jeśli przyszłe testy będą wymagały. Plan 13 nie powinien tego potrzebować bo nie testuje UI life-cycle.

- **`.uid` sidecar files**: Plan 13 nie dodaje nowych skryptów (brak nowych `.uid` sidecar'ów). Brak class cache regen needed.
