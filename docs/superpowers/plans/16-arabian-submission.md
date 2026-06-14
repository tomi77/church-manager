# Plan 16 — Przyjęcie Islamu (Religie Arabskie) Implementation Plan

> **For Claude:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 11. unique victory dla Religie Arabskie — doktrynalna mimikra profilu islamskiego (osie A≥65, B≥60, C≤35, D≥70) + kontrola mekki + ≥3 frakcje, utrzymywane przez 15 tur. Zero zmian w fixturze.

**Architecture:** Pattern z Plan 14 (Coptic Cytadela): (a) 7 stałych w `VictoryManager.gd`; (b) Counter `arabian_submission_turns` w schema `state.victory_progress` + per-religion gałąź w `update_counters`; (c) Predykat helper `_arabian_submission_satisfied` + klauzula w `evaluate_unique_victory`; (d) Etykieta `REASON_LABELS["arabian_submission"]` w `GameOverDialog.gd`.

**Tech Stack:** Godot 4.6.3, GDScript 2.0, GUT (Godot Unit Testing).

**Spec:** [`docs/superpowers/specs/16-arabian-submission-design.md`](../specs/16-arabian-submission-design.md)

---

## Convention reminders (z [CLAUDE.md](../../../CLAUDE.md))

- **Tab indent** w `.gd`.
- **Stałe engine tunable** — testy referencują `VictoryManager.ARABIAN_AXIS_A_REQUIRED` etc., **nie hardcoduj wartości**.
- **Identyfikatory ANGIELSKIE** — pliki, klasy, zmienne, ID. Polski tylko w `Label.text`, `display_name`, komentarzach. Zgodne z memory `feedback_english_identifiers.md`.
- **Brak nowych `class_name`** — Plan 16 nie dodaje skryptów, `.godot/global_script_class_cache.cfg` nie wymaga regeneracji.
- **Faction count = "faction survival" proxy** — schizma usuwa frakcję z `religion.factions` (SchismManager.gd:68 `religion.factions.erase(faction)`). Test `factions.size() >= 3` jest robust.

---

## Test command reference

```bash
# Cała suite (po Plan 15: 708; po Plan 16 oczekiwane ~721)
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# Pojedynczy plik testu
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_constants.gd -gexit

# Subkatalog
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gexit
```

---

## File Structure

**Modyfikowane (brak nowych plików):**

- `scripts/engine/VictoryManager.gd` — 7 nowych stałych, schema `+arabian_submission_turns`, gałąź `update_counters`, klauzula `evaluate_unique_victory`, helper `_arabian_submission_satisfied`.
- `scripts/ui/dialogs/GameOverDialog.gd` — 1 wpis w `REASON_LABELS`.
- `tests/engine/test_victory_manager_constants.gd` — 1 nowy test.
- `tests/engine/test_victory_manager_flags.gd` — 7 nowych testów (counter arabian_submission_turns).
- `tests/engine/test_victory_manager_unique.gd` — 3 nowe testy (predykat arabian_submission).
- `tests/engine/test_victory_manager_endgame.gd` — 1 nowy test (integracja).
- `tests/ui/test_game_over_dialog.gd` — modyfikacja istniejącego testu (dodać "arabian_submission" do listy reasonów).
- `CLAUDE.md` — 1-liner cross-reference.

**Mapa: spec § → plik kodu → plik testu → Task**

| Spec § | Plik kodu | Plik testu | Task |
|---|---|---|---|
| §4.3 stałe | `scripts/engine/VictoryManager.gd` | `tests/engine/test_victory_manager_constants.gd` | 1 |
| §4.5 counter | `scripts/engine/VictoryManager.gd` | `tests/engine/test_victory_manager_flags.gd` | 2 |
| §4.6/§4.7 predykat | `scripts/engine/VictoryManager.gd` | `tests/engine/test_victory_manager_unique.gd` | 3 |
| §3 integracja | (no new code) | `tests/engine/test_victory_manager_endgame.gd` | 4 |
| §4.8 UI label | `scripts/ui/dialogs/GameOverDialog.gd` | `tests/ui/test_game_over_dialog.gd` | 5 |
| §3 docs | `CLAUDE.md` | — | 6 |

---

## Pre-flight: zweryfikuj baseline

- [ ] **Step 1: Cała suite musi pass przed Plan 16**

Run:
```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: wszystkie ~708 testów pass (baseline z Plan 15).

Jeśli baseline nie pass → STOP, napraw przed kontynuacją.

- [ ] **Step 2: Sprawdź istniejący schema w `_ensure_progress_entry`**

```bash
grep -n "_ensure_progress_entry(state.victory_progress" scripts/engine/VictoryManager.gd
```

Expected: linia ok. 153:
```gdscript
_ensure_progress_entry(state.victory_progress, religion.id, {"domination_turns": 0, "prestige_hegemony_turns": 0, "dharma_turns": 0, "coptic_citadel_turns": 0})
```

To kluczowa linia — Task 2 doda do tego słownika `"arabian_submission_turns": 0`.

- [ ] **Step 3: Sprawdź gdzie wstawić nowe stałe**

```bash
grep -n "Plan 14: unikalne warunki — Coptic" scripts/engine/VictoryManager.gd
```

Expected: linia 53 (komentarz nagłówka stałych Coptic, kończą się na linii 59). Task 1 wstawia stałe Arabian po linii 59 (przed `# === Public API ===`).

---

## Task 1: 7 stałych Plan 16

**Cel:** Dodać 7 stałych konfiguracyjnych dla Arabian Submission do `VictoryManager.gd`.

**Files:**
- Modify: `scripts/engine/VictoryManager.gd` (po linii 59, przed `# === Public API ===`)
- Modify: `tests/engine/test_victory_manager_constants.gd` (dodać `test_plan16_constants_exist`)

- [ ] **Step 1: Napisz failing test `test_plan16_constants_exist`**

W `tests/engine/test_victory_manager_constants.gd` dodaj:

```gdscript
# === Plan 16: stałe Arabian Submission ===

func test_plan16_constants_exist() -> void:
	assert_eq(VictoryManager.ARABIAN_MEKKA_ID, "mekka")
	assert_eq(VictoryManager.ARABIAN_AXIS_A_REQUIRED, 65.0)
	assert_eq(VictoryManager.ARABIAN_AXIS_B_REQUIRED, 60.0)
	assert_eq(VictoryManager.ARABIAN_AXIS_C_MAX, 35.0)
	assert_eq(VictoryManager.ARABIAN_AXIS_D_REQUIRED, 70.0)
	assert_eq(VictoryManager.ARABIAN_ACTIVE_FACTIONS_REQUIRED, 3)
	assert_eq(VictoryManager.ARABIAN_SUBMISSION_TURNS_REQUIRED, 15)
```

- [ ] **Step 2: Run — expect FAIL**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_constants.gd -gexit
```

Expected: parse/runtime error — `ARABIAN_*` constants nie istnieją.

- [ ] **Step 3: Dodaj 7 stałych do `VictoryManager.gd`**

Po linii 59 (`const COPTIC_CITADEL_TURNS_REQUIRED := 20`), przed pustą linią i `# === Public API ===`, wstaw:

```gdscript

# === Plan 16: unikalne warunki — Arabian Paganism (Przyjęcie Islamu) ===
const ARABIAN_MEKKA_ID := "mekka"
const ARABIAN_AXIS_A_REQUIRED := 65.0					# Islam reference 70 — margin 5
const ARABIAN_AXIS_B_REQUIRED := 60.0					# Islam reference 65 — margin 5
const ARABIAN_AXIS_C_MAX := 35.0						# Islam reference 30 — margin 5 (próg górny)
const ARABIAN_AXIS_D_REQUIRED := 70.0					# Islam reference 75 — margin 5
const ARABIAN_ACTIVE_FACTIONS_REQUIRED := 3				# wszystkie 3 startowe frakcje muszą żyć (brak schizmy)
const ARABIAN_SUBMISSION_TURNS_REQUIRED := 15			# trwałość 6 warunków przez 15 tur
```

- [ ] **Step 4: Run — expect PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_constants.gd -gexit
```

Expected: `test_plan16_constants_exist` + wszystkie istniejące testy constants pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/VictoryManager.gd tests/engine/test_victory_manager_constants.gd
git commit -m "feat(victory): Plan 16 stałe — Arabian Submission"
```

---

## Task 2: Counter `arabian_submission_turns` + gałąź `update_counters`

**Cel:** Dodać klucz `arabian_submission_turns` do schema `victory_progress` i gałąź per-religion w `update_counters` która inkrementuje/resetuje counter zgodnie ze spec §4.5.

**Files:**
- Modify: `scripts/engine/VictoryManager.gd` (linia 153 schema + nowa gałąź po linii 205)
- Modify: `tests/engine/test_victory_manager_flags.gd` (7 nowych testów)

- [ ] **Step 1: Napisz 7 failing testów**

W `tests/engine/test_victory_manager_flags.gd` (na końcu pliku) dodaj sekcję:

```gdscript
# === Plan 16: arabian_submission_turns counter ===

func test_update_counters_initializes_arabian_submission_turns_zero() -> void:
	var gs := _make_state("arabian_paganism")
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("arabian_paganism", {})
	assert_eq(prog.get("arabian_submission_turns", -1), 0,
		"counter inicjuje się na 0 dla Arabian")

func test_update_counters_increments_arabian_submission_when_all_6_conditions_met() -> void:
	var gs := _make_state("arabian_paganism")
	var rel: Religion = gs.get_religion("arabian_paganism")
	# Mekka już jest Arabian z fixture. Pozostaje ustawić osie i upewnić się że 3 frakcje żyją.
	rel.axes["A"] = 70.0
	rel.axes["B"] = 65.0
	rel.axes["C"] = 30.0
	rel.axes["D"] = 75.0
	assert_eq(rel.factions.size(), 3, "Arabian startuje z 3 frakcjami")
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("arabian_paganism", {})
	assert_eq(prog.get("arabian_submission_turns", 0), 1)
	vm.update_counters(gs)
	assert_eq(prog.get("arabian_submission_turns", 0), 2, "counter inkrementuje per turn")

func test_update_counters_resets_arabian_submission_when_mekka_lost() -> void:
	var gs := _make_state("arabian_paganism")
	var rel: Religion = gs.get_religion("arabian_paganism")
	rel.axes["A"] = 70.0
	rel.axes["B"] = 65.0
	rel.axes["C"] = 30.0
	rel.axes["D"] = 75.0
	# Pre-set counter = 5, by check reset
	gs.victory_progress["arabian_paganism"] = {"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 0, "arabian_submission_turns": 5}
	gs.province_graph.get_province("mekka").owner = "islam"  # utrata mekki
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("arabian_paganism", {})
	assert_eq(prog.get("arabian_submission_turns", -1), 0, "utrata mekki → reset")

func test_update_counters_resets_arabian_submission_when_axis_A_drops_to_64() -> void:
	var gs := _make_state("arabian_paganism")
	var rel: Religion = gs.get_religion("arabian_paganism")
	rel.axes["A"] = 64.0  # poniżej ARABIAN_AXIS_A_REQUIRED=65
	rel.axes["B"] = 65.0
	rel.axes["C"] = 30.0
	rel.axes["D"] = 75.0
	gs.victory_progress["arabian_paganism"] = {"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 0, "arabian_submission_turns": 5}
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("arabian_paganism", {})
	assert_eq(prog.get("arabian_submission_turns", -1), 0, "A=64 → reset (próg ostry ≥65)")

func test_update_counters_resets_arabian_submission_when_axis_C_rises_to_36() -> void:
	var gs := _make_state("arabian_paganism")
	var rel: Religion = gs.get_religion("arabian_paganism")
	rel.axes["A"] = 70.0
	rel.axes["B"] = 65.0
	rel.axes["C"] = 36.0  # powyżej ARABIAN_AXIS_C_MAX=35
	rel.axes["D"] = 75.0
	gs.victory_progress["arabian_paganism"] = {"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 0, "arabian_submission_turns": 5}
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("arabian_paganism", {})
	assert_eq(prog.get("arabian_submission_turns", -1), 0, "C=36 → reset (próg ostry ≤35)")

func test_update_counters_resets_arabian_submission_when_faction_count_drops_to_2() -> void:
	var gs := _make_state("arabian_paganism")
	var rel: Religion = gs.get_religion("arabian_paganism")
	rel.axes["A"] = 70.0
	rel.axes["B"] = 65.0
	rel.axes["C"] = 30.0
	rel.axes["D"] = 75.0
	# Symuluj utratę 1 frakcji przez schizmę.
	rel.factions.pop_back()
	assert_eq(rel.factions.size(), 2)
	gs.victory_progress["arabian_paganism"] = {"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 0, "arabian_submission_turns": 5}
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("arabian_paganism", {})
	assert_eq(prog.get("arabian_submission_turns", -1), 0,
		"factions.size()<3 → reset (utrata frakcji przez schizmę)")

func test_update_counters_only_increments_arabian_submission_for_arabian_paganism() -> void:
	# Inne religie nie inkrementują arabian_submission_turns nawet jeśli "spełniają" warunki.
	var gs := _make_state("islam")
	var rel: Religion = gs.get_religion("islam")
	# Islam już ma osie islamskie (70/65/30/75) — gdyby gałąź nie filtrowała, counter rósłby.
	# Islam też ma mekka (startowo nie, ale ustawmy).
	gs.province_graph.get_province("mekka").owner = "islam"
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("islam", {})
	assert_eq(prog.get("arabian_submission_turns", -1), 0,
		"Islam nie inkrementuje arabian_submission_turns (counter jest religion-scoped do Arabian)")
```

- [ ] **Step 2: Run testy — expect FAILS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_flags.gd -gexit
```

Expected: 7 nowych testów fail z `prog.get("arabian_submission_turns", -1)` zwracającym `-1` (klucz nie istnieje w schema).

- [ ] **Step 3: Rozszerz schema w `_ensure_progress_entry`**

W `scripts/engine/VictoryManager.gd` linia 153:

Zmień:
```gdscript
_ensure_progress_entry(state.victory_progress, religion.id, {"domination_turns": 0, "prestige_hegemony_turns": 0, "dharma_turns": 0, "coptic_citadel_turns": 0})
```

Na:
```gdscript
_ensure_progress_entry(state.victory_progress, religion.id, {"domination_turns": 0, "prestige_hegemony_turns": 0, "dharma_turns": 0, "coptic_citadel_turns": 0, "arabian_submission_turns": 0})
```

- [ ] **Step 4: Dodaj gałąź `update_counters` dla Arabian**

Po linii 205 (`state.victory_progress[religion.id]["coptic_citadel_turns"] = 0`), przed `# Defeat counters` (linia 207), wstaw:

```gdscript

		# Plan 16 §4.5: arabian_submission_turns — kontrola mekki + axes islamskie + faction survival.
		if religion.id == "arabian_paganism":
			var submission_active: bool = true
			# Warunek 1: kontrola mekki (null guard).
			var mekka: Province = state.province_graph.get_province(ARABIAN_MEKKA_ID)
			if mekka == null or mekka.owner != religion.id:
				submission_active = false
			# Warunki 2-5: osie islamskie.
			elif religion.get_axis("A") < ARABIAN_AXIS_A_REQUIRED:
				submission_active = false
			elif religion.get_axis("B") < ARABIAN_AXIS_B_REQUIRED:
				submission_active = false
			elif religion.get_axis("C") > ARABIAN_AXIS_C_MAX:
				submission_active = false
			elif religion.get_axis("D") < ARABIAN_AXIS_D_REQUIRED:
				submission_active = false
			# Warunek 6: faction survival.
			elif religion.factions.size() < ARABIAN_ACTIVE_FACTIONS_REQUIRED:
				submission_active = false
			if submission_active:
				state.victory_progress[religion.id]["arabian_submission_turns"] += 1
			else:
				state.victory_progress[religion.id]["arabian_submission_turns"] = 0
```

- [ ] **Step 5: Run — expect PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_flags.gd -gexit
```

Expected: 7 nowych testów pass + wszystkie istniejące flags testy pass (regresja zero).

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/VictoryManager.gd tests/engine/test_victory_manager_flags.gd
git commit -m "feat(victory): Plan 16 counter arabian_submission_turns w update_counters"
```

---

## Task 3: Predykat `_arabian_submission_satisfied` + klauzula `evaluate_unique_victory`

**Cel:** Dodać helper czytający counter + klauzulę match w `evaluate_unique_victory` dla `arabian_paganism`.

**Files:**
- Modify: `scripts/engine/VictoryManager.gd` (klauzula w `evaluate_unique_victory` + helper na końcu pliku po `_coptic_citadel_satisfied`)
- Modify: `tests/engine/test_victory_manager_unique.gd` (3 nowe testy)

- [ ] **Step 1: Napisz 3 failing testy**

W `tests/engine/test_victory_manager_unique.gd` (na końcu pliku) dodaj:

```gdscript
# === Plan 16: Arabian Submission ===

func test_arabian_submission_requires_15_turns_counter() -> void:
	var gs := _make_state("arabian_paganism")
	var rel: Religion = gs.get_religion("arabian_paganism")
	gs.victory_progress["arabian_paganism"] = {"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 0, "arabian_submission_turns": 15}
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "arabian_submission")

func test_arabian_submission_blocked_with_14_turns() -> void:
	var gs := _make_state("arabian_paganism")
	var rel: Religion = gs.get_religion("arabian_paganism")
	gs.victory_progress["arabian_paganism"] = {"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 0, "arabian_submission_turns": 14}
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "", "14 tur < próg 15 → brak victory")

func test_arabian_submission_other_religion_never_returns_reason() -> void:
	# Sanity: spreparowany counter dla Islam nie zwraca arabian_submission (brak case'a w match).
	var gs := _make_state("islam")
	var rel: Religion = gs.get_religion("islam")
	gs.victory_progress["islam"] = {"domination_turns": 0, "prestige_hegemony_turns": 0,
		"dharma_turns": 0, "coptic_citadel_turns": 0, "arabian_submission_turns": 30}
	var vm := VictoryManager.new()
	# Islam może zwrócić islam_caliphate jeśli warunki spełnione, ale NIGDY arabian_submission.
	var result: String = vm.evaluate_unique_victory(rel, gs)
	assert_ne(result, "arabian_submission",
		"Islam nie może zwrócić arabian_submission (klauzula tylko dla arabian_paganism)")
```

- [ ] **Step 2: Run testy — expect FAILS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_unique.gd -gexit
```

Expected:
- `test_arabian_submission_requires_15_turns_counter` fail — funkcja zwraca `""` zamiast `"arabian_submission"`.
- `test_arabian_submission_blocked_with_14_turns` pass (już zwraca `""`).
- `test_arabian_submission_other_religion_never_returns_reason` — pass jeśli Islam już nie ma case'a, fail jeśli przez przypadek mieszają się match'e.

- [ ] **Step 3: Dodaj klauzulę w `evaluate_unique_victory`**

W `scripts/engine/VictoryManager.gd` znajdź klauzulę Coptic (ok. linii 299-301):

```gdscript
		"coptic_christianity":
			if _coptic_citadel_satisfied(religion, state):
				return "coptic_citadel"
```

Po niej dodaj:

```gdscript
		"arabian_paganism":
			if _arabian_submission_satisfied(religion, state):
				return "arabian_submission"
```

- [ ] **Step 4: Dodaj helper `_arabian_submission_satisfied` na końcu pliku**

Po `_coptic_citadel_satisfied` (ostatni helper w pliku), dodaj:

```gdscript

func _arabian_submission_satisfied(religion: Religion, state: Node) -> bool:
	# Plan 16 §4.6: counter arabian_submission_turns aktualizowany w update_counters.
	# Pattern z _hindu_dharma_satisfied i _coptic_citadel_satisfied.
	var vp: Dictionary = state.victory_progress.get(religion.id, {})
	return vp.get("arabian_submission_turns", 0) >= ARABIAN_SUBMISSION_TURNS_REQUIRED
```

- [ ] **Step 5: Run — expect PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_unique.gd -gexit
```

Expected: 3 nowe testy pass + wszystkie istniejące unique testy pass.

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/VictoryManager.gd tests/engine/test_victory_manager_unique.gd
git commit -m "feat(victory): Plan 16 predykat _arabian_submission_satisfied + klauzula evaluate_unique_victory"
```

---

## Task 4: Integracja endgame (`check()` ustawia `game_outcome`)

**Cel:** Test integracyjny — pełen pipeline: ustaw warunki → 15× `update_counters` + `check()` → `state.game_outcome.reason == "arabian_submission"`.

**Files:**
- Modify: `tests/engine/test_victory_manager_endgame.gd` (1 nowy test)

**Note:** Brak nowego kodu — Task 2 + Task 3 razem implementują pełną integrację. Task 4 to wyłącznie test integracyjny.

- [ ] **Step 1: Napisz failing test**

W `tests/engine/test_victory_manager_endgame.gd` (na końcu pliku) dodaj:

```gdscript
# === Plan 16: integracja arabian_submission z check ===

func test_check_marks_arabian_submission_with_game_outcome() -> void:
	var gs := _make_state("arabian_paganism")
	var arabian: Religion = gs.get_religion("arabian_paganism")
	# Spełnij wszystkie 6 warunków (po Task 2 counter będzie inkrementował).
	arabian.axes["A"] = 70.0
	arabian.axes["B"] = 65.0
	arabian.axes["C"] = 30.0
	arabian.axes["D"] = 75.0
	# Mekka już Arabian, 3 frakcje istnieją z fixture.
	var vm := VictoryManager.new()
	# 15 tur update_counters + check (po Plan 12 check ustawia game_outcome).
	for _i in range(VictoryManager.ARABIAN_SUBMISSION_TURNS_REQUIRED):
		vm.update_counters(gs)
		vm.check(gs)
	assert_not_null(gs.game_outcome, "game_outcome ustawione po 15 turach")
	assert_eq(gs.game_outcome.winner_id, "arabian_paganism")
	assert_eq(gs.game_outcome.reason, "arabian_submission")
```

- [ ] **Step 2: Run — expect PASS (kod już istnieje z Tasks 2+3)**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_endgame.gd -gexit
```

Expected: nowy test pass natychmiast.

Jeśli FAIL — coś poszło nie tak z Task 2 lub Task 3, debug. NIE ma być potrzeby nowego kodu w Task 4.

- [ ] **Step 3: Commit**

```bash
git add tests/engine/test_victory_manager_endgame.gd
git commit -m "test(victory): Plan 16 integracja arabian_submission z game_outcome"
```

---

## Task 5: REASON_LABELS + UI test patch

**Cel:** Dodać polską etykietę reason w `GameOverDialog.gd` + zaktualizować test UI sprawdzający wszystkie reasons.

**Files:**
- Modify: `scripts/ui/dialogs/GameOverDialog.gd` (linia ok. 39 — po `"coptic_citadel"`)
- Modify: `tests/ui/test_game_over_dialog.gd` (rozszerzenie istniejącego testu listy reasons)

- [ ] **Step 1: Sprawdź obecny stan**

```bash
grep -n "REASON_LABELS\|coptic_citadel\|test_dialog_maps_all_reasons" scripts/ui/dialogs/GameOverDialog.gd tests/ui/test_game_over_dialog.gd | head -10
```

Expected:
- `scripts/ui/dialogs/GameOverDialog.gd:20` — `const REASON_LABELS: Dictionary = {`.
- `scripts/ui/dialogs/GameOverDialog.gd:39` — `"coptic_citadel": "Cytadela Pustelnicza (Koptyjski Kościół)",`.
- `tests/ui/test_game_over_dialog.gd` — test sprawdzający że wszystkie reasons mapują się na polskie label.

- [ ] **Step 2: Zaktualizuj `test_dialog_maps_all_reasons_to_non_empty_polish_labels`**

W `tests/ui/test_game_over_dialog.gd:40-47` znajdź hardcoded array `reasons`:

```gdscript
var reasons := ["domination", "prestige_hegemony", "holy_land",
    "manichaeism_illumination", "judaism_return", "zoroastrianism_renaissance",
    "east_christianity_pentarchy", "islam_caliphate", "germanic_ragnarok",
    "turn_limit", "elimination", "long_vassalage",
    # Plan 13:
    "total_schism", "western_reformation", "hindu_dharma", "buddhism_middle_way",
    # Plan 14:
    "coptic_citadel"]
```

Dodaj `"arabian_submission"` jako kolejny element z komentarzem Plan 16:

```gdscript
var reasons := ["domination", "prestige_hegemony", "holy_land",
    "manichaeism_illumination", "judaism_return", "zoroastrianism_renaissance",
    "east_christianity_pentarchy", "islam_caliphate", "germanic_ragnarok",
    "turn_limit", "elimination", "long_vassalage",
    # Plan 13:
    "total_schism", "western_reformation", "hindu_dharma", "buddhism_middle_way",
    # Plan 14:
    "coptic_citadel",
    # Plan 16:
    "arabian_submission"]
```

- [ ] **Step 3: Dodaj label assertion test (parytet z Plan 14)**

Plan 14 ma `test_coptic_citadel_label_contains_polish_religion_name` (linia 110-114). Dla parytetu dodaj analogiczny test na końcu `tests/ui/test_game_over_dialog.gd`:

```gdscript

func test_arabian_submission_label_contains_polish_religion_name() -> void:
	var label: String = GameOverDialog.REASON_LABELS.get("arabian_submission", "")
	assert_ne(label, "", "arabian_submission ma etykietę")
	assert_true(label.findn("arabskie") != -1 or label.findn("arabian") != -1,
		"etykieta zawiera 'Arabskie' lub 'Arabian'")
	assert_true(label.findn("islam") != -1, "etykieta zawiera 'Islam' (Przyjęcie Islamu)")
```

- [ ] **Step 4: Run — expect FAILS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_game_over_dialog.gd -gexit
```

Expected:
- `test_dialog_maps_all_reasons_to_non_empty_polish_labels` fail — `arabian_submission` w `reasons` array ale `REASON_LABELS["arabian_submission"]` nie istnieje, `dialog.get_reason_text()` zwraca `""` lub fallback.
- `test_arabian_submission_label_contains_polish_religion_name` fail — `REASON_LABELS.get(...)` zwraca `""`.

- [ ] **Step 5: Dodaj etykietę w `REASON_LABELS`**

W `scripts/ui/dialogs/GameOverDialog.gd` po linii 39 (po `"coptic_citadel": "Cytadela Pustelnicza (Koptyjski Kościół)",`), dodaj:

```gdscript
	"arabian_submission": "Przyjęcie Islamu (Religie Arabskie)",
```

Spójność formatu z Plan 13/14: `"<Polish concept> (<religion display_name>)"`.

- [ ] **Step 6: Run — expect PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_game_over_dialog.gd -gexit
```

Expected: oba testy pass.

- [ ] **Step 7: Commit**

```bash
git add scripts/ui/dialogs/GameOverDialog.gd tests/ui/test_game_over_dialog.gd
git commit -m "feat(ui): Plan 16 REASON_LABELS arabian_submission"
```

---

## Task 6: CLAUDE.md cross-reference

**Cel:** Dopisać 1-liner o Plan 16 w sekcji "End-of-game flow".

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Znajdź wzmianki**

```bash
grep -n "Plan 14\|Plan 15\|14-coptic\|15-ghost" CLAUDE.md
```

Expected: bullet "End-of-game flow" z wzmiankami Plan 12, 13, 14, 15.

- [ ] **Step 2: Dopisz 1-liner po Plan 15**

W sekcji "End-of-game flow", po wzmiance Plan 15, dodaj:

```
Plan 16 (`docs/superpowers/specs/16-arabian-submission-design.md`) dodaje unikalny warunek "Przyjęcie Islamu" dla Religie Arabskie (doktrynalna mimikra profilu islamskiego: A≥65, B≥60, C≤35, D≥70 + mekka + 3 frakcje, przez 15 tur).
```

- [ ] **Step 3: Sanity grep**

```bash
grep -F "16-arabian-submission-design.md" CLAUDE.md
```

Expected: 1 linia (link do specu 16).

- [ ] **Step 4: Cała suite (sanity — docs only, nie powinno wpływać)**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: ~721 testów pass (708 baseline + 13 nowych).

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: cross-reference do spec 16 (Arabian Submission)"
```

---

## Po wszystkich taskach

- [ ] **Final review**: dispatch `superpowers:code-reviewer` na pełen branch (wszystkie 6 commitów Plan 16 + commity spec/plan). Reviewer sprawdza:
  - Spec compliance z `16-arabian-submission-design.md` (wszystkie 10 acceptance criteria z §7).
  - Code quality (tab indent, naming, brak magic numbers, brak hardkoded id, idempotencja counter).
  - Test coverage (~13 nowych engine + 1 UI patch = ~14 dodatkowych testów łącznie).
  - Brak regresji (~721 testów pass).
  - Konsystencja architektoniczna z Plan 14 (Coptic pattern: counter + predykat + label, jednakowy schemat tests).

- [ ] **Po approval**: push do origin/master (bez PR, zgodnie z workflow projektu).

---

## Acceptance Criteria (z spec §7)

Plan 16 jest gotowy do merge gdy:

1. ✅ 7 stałych Plan 16 istnieje w `VictoryManager.gd`.
2. ✅ Counter `arabian_submission_turns` w `victory_progress` poprawnie inkrementuje gdy spełnione 6 warunków (mekka + 4 axes + 3 factions) i religia to Arabian; resetuje gdy choć jeden niespełniony; pozostaje 0 dla innych religii.
3. ✅ `evaluate_unique_victory` dla Arabian z `arabian_submission_turns >= 15` zwraca `"arabian_submission"`.
4. ✅ `state.game_outcome.winner_id == "arabian_paganism"` AND `game_outcome.reason == "arabian_submission"` po `check()` gdy gracz Arabian wygra (test integracyjny).
5. ✅ `GameOverDialog.REASON_LABELS["arabian_submission"]` zwraca polską etykietę zawierającą `"Przyjęcie Islamu"` i `"Religie Arabskie"`.
6. ✅ Pre-existing testy Plan 12/13/14/15 (~708) — wszystkie pass bez modyfikacji.
7. ✅ 12 nowych testów engine + 1 nowy UI test (`test_arabian_submission_label_contains_polish_religion_name`) + 1 modyfikacja UI testu (`test_dialog_maps_all_reasons_*`) — wszystkie pass.
8. ✅ Cała suite (~721) pass.
9. ✅ Brak zmian w fixturze (`data/*.json`), engine managerach (poza VictoryManager), UI poza GameOverDialog.
10. ✅ `CLAUDE.md` wzmiankuje Plan 16 (1-liner cross-reference).
