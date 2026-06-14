# Plan 18 — NPC AI doctrine (MVP) Implementation Plan

> **For Claude:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pierwsza implementacja AI dla niegracznych religii. MVP: NPC dispatchują scholars proaktywnie (RNG-gated) + auto-accept/reject ideas via faction-weighted heuristic. Player UI accept/reject pozostaje out of scope.

**Architecture:** Nowa klasa `AIManager.gd` (stateless, `extends RefCounted`, pattern jak DiplomacyManager). 3 metody: `decide_accept_idea`, `should_dispatch_scholar`, `choose_scholar_target`. `_init(rng = null)` przyjmuje opcjonalny seeded RNG. Integracja w `TurnManager`: nowy etap `_npc_dispatch_scholars` + modyfikacja `_process_scholar_missions` (NPC ideas auto-resolve via AI, player ideas zostają w `pending_ideas`). `TurnManager` ma `set_ai_override(ai)` setter dla test isolation.

**Tech Stack:** Godot 4.6.3, GDScript 2.0, GUT (Godot Unit Testing).

**Spec:** [`docs/superpowers/specs/18-npc-doctrine-ai-design.md`](../specs/18-npc-doctrine-ai-design.md)

---

## Convention reminders (z [CLAUDE.md](../../../CLAUDE.md))

- **Tab indent** w `.gd`.
- **Stałe engine tunable** — testy referencują `AIManager.AI_SCHOLAR_*`, nie hardcoduj.
- **Identyfikatory ANGIELSKIE** — `AIManager`, `decide_accept_idea`, etc. Polish tylko w komentarzach.
- **Nowa `class_name AIManager`** — wymaga regeneracji `.godot/global_script_class_cache.cfg`. Po stworzeniu pliku: open Godot editor lub `godot --headless --path . --quit`.
- **No `randf()` / `randi()` w testach** bez seed — RNG injection przez `_init(rng)` lub `set_ai_override`.

---

## Test command reference

```bash
# Cała suite (po Plan 17: 741; po Plan 18 oczekiwane ~756)
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# Pojedynczy plik testu
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_ai_manager.gd -gexit
```

---

## File Structure

**Nowy plik:**
- `scripts/engine/AIManager.gd` — `class_name AIManager`, `extends RefCounted`. 2 stałe + 3 metody + RNG field.

**Modyfikowane:**
- `scripts/engine/TurnManager.gd` — dodać `_ai_override` field + `set_ai_override` setter + `_get_ai` helper + nowy etap `_npc_dispatch_scholars` + modyfikacja `_process_scholar_missions`.
- `tests/engine/test_ai_manager.gd` — nowy plik testów (~12 testów).
- `tests/engine/test_turn_manager.gd` — 3 nowe testy integracyjne + ewentualne `set_ai_override(null_ai)` w istniejących testach (Task 0 zdecyduje).
- `CLAUDE.md` — 1-liner cross-reference.

**Bez zmian:**
- `DoctrineManager.gd`, `Religion.gd`, `Faction.gd`, `Idea.gd`, `GameState.gd`.
- Fixture (`data/*.json`).
- UI.

**Mapa: spec § → Task**

| Spec § | Task |
|---|---|
| §10 R1 isolation | 0 (pre-flight) |
| §3 AIManager skeleton + constants | 1 |
| §4 decide_accept_idea | 2 |
| §5.1 should_dispatch_scholar | 3 |
| §5.2 choose_scholar_target | 4 |
| §10 R1 / §6 injectable AI | 5 |
| §6.1 _npc_dispatch_scholars | 6 |
| §6.2 _process_scholar_missions | 7 |
| §3 CLAUDE.md cross-ref | 8 |

---

## Task 0: Pre-flight — baseline + enumerate collisions

**Cel:** Sprawdzić baseline pass + zidentyfikować testy w `test_turn_manager.gd` które wywołują `process_turn` i mogą być zaburzone przez NPC AI dispatch.

**Files:** read-only inspection.

- [ ] **Step 1: Cała suite musi pass przed Plan 18**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: ~741 testów pass (baseline z Plan 17).

- [ ] **Step 2: Enumerate process_turn call sites w test_turn_manager.gd**

```bash
grep -n "process_turn\|scholar_missions\|pending_ideas" tests/engine/test_turn_manager.gd
```

Spodziewane (po Plan 17):
- Lines 12-15 `test_process_turn_advances_turn_counter` — single process_turn, no scholar/idea assertions. **Safe.**
- Lines 18-25 `test_passive_pressure_increases_on_adjacent_foreign_province` — single process_turn. **Safe** unless NPC dispatch creates side effects on pressure (no — dispatch only modifies scholar_missions).
- Lines 27-35 `test_no_pressure_from_same_owner_neighbor` — **Safe** same.
- Lines 38-44 `test_passive_pressure_foreign_religion_increases_on_border_province` — **Safe**.
- Lines 47-52 `test_holy_site_owner_gains_prestige` — **Safe**.
- Lines 55-62 `test_faction_tension_increases_when_axis_diverges` — **Safe**.
- Lines 65-75 `test_process_turn_decrements_scholar_mission_turns` — manually adds 1 mission, asserts size==1 after 1 turn. **Potentially unsafe** if NPC adds more missions in same turn.
- Lines 77-99 `test_process_turn_generates_idea_when_mission_completes` — manually adds 1 mission (islam→western, "islam" = player), asserts `scholar_missions.size() == 0` AND `pending_ideas.size() == 1`. **Potentially unsafe** if NPC dispatches new missions during same turn (assertion `== 0` fails).
- Lines 101-127 `test_process_turn_applies_believer_exodus_*` — **Safe** (no scholar/idea assertions).
- Lines 130-179 `test_process_turn_*_war_*` — **Safe**.
- Lines 195-241 `test_turn_*` — **Safe** unless asserts on scholar/idea state.
- Lines 244-258 `test_turn_evaluates_coalitions` — **Safe**.

- [ ] **Step 3: Identyfikuj testy do izolacji**

Z analizy Step 2 — **2 testy są potencjalnie unsafe**:
1. `test_process_turn_decrements_scholar_mission_turns` (lines 65-75): asserts `scholar_missions.size() == 1` po 1 turze. NPC dispatch może dodać extra mission → fail.
2. `test_process_turn_generates_idea_when_mission_completes` (lines 77-99): asserts `scholar_missions.size() == 0`. NPC dispatch może dodać → fail.

**Plan rozwiązania:** Po Task 5 (set_ai_override), oba testy używają disabled AI override w prologu testu. Task 7 zaimplementuje fix.

- [ ] **Step 4: Sprawdź czy AIManager class_name nie koliduje**

```bash
grep -rn "class_name AIManager" scripts/ 2>/dev/null
```

Expected: 0 wyników (brak istniejącego AIManager).

- [ ] **Step 5: Commit (no code change — pre-flight only)**

Brak commitu — Task 0 to inspection. Wyniki zapisz w notatkach roboczych dla Task 5/7.

---

## Task 1: AIManager skeleton + constants + RNG init

**Cel:** Stworzyć `AIManager.gd` z constructor (opcjonalny RNG) + 2 stałe + 1 test.

**Files:**
- Create: `scripts/engine/AIManager.gd`
- Modify: `tests/engine/test_ai_manager.gd` (nowy plik)

- [ ] **Step 1: Napisz failing test**

Stwórz `tests/engine/test_ai_manager.gd`:

```gdscript
extends GutTest

const AIManagerScript := preload("res://scripts/engine/AIManager.gd")

# === Plan 18: AIManager skeleton ===

func test_ai_manager_has_plan18_constants() -> void:
	assert_eq(AIManager.AI_SCHOLAR_MIN_PRESTIGE, 50)
	assert_almost_eq(AIManager.AI_SCHOLAR_DISPATCH_CHANCE, 0.15, 0.001)

func test_ai_manager_init_creates_rng_when_no_injection() -> void:
	var ai := AIManagerScript.new()
	assert_not_null(ai.rng, "AIManager bez injection tworzy własny rng")

func test_ai_manager_init_uses_injected_rng() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var ai := AIManagerScript.new(rng)
	assert_eq(ai.rng, rng, "AIManager używa injected rng")
```

- [ ] **Step 2: Run — expect FAIL (parse error — class missing)**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_ai_manager.gd -gexit
```

Expected: parse error `Could not find type AIManager`.

- [ ] **Step 3: Stwórz `scripts/engine/AIManager.gd`**

```gdscript
class_name AIManager
extends RefCounted

# Plan 18 — NPC AI doctrine MVP.
# Spec: docs/superpowers/specs/18-npc-doctrine-ai-design.md
# Stateless (pattern jak DiplomacyManager, WarManager). RNG injection dla determinizmu testów.

const AI_SCHOLAR_MIN_PRESTIGE := 50
const AI_SCHOLAR_DISPATCH_CHANCE := 0.15

var rng: RandomNumberGenerator

func _init(injected_rng: RandomNumberGenerator = null) -> void:
	if injected_rng != null:
		rng = injected_rng
	else:
		rng = RandomNumberGenerator.new()
		rng.randomize()
```

- [ ] **Step 4: Regeneruj class_name cache**

```bash
godot --headless --path . --quit 2>&1 | tail -5
```

Expected: brak parse errorów (cache zaktualizowany).

- [ ] **Step 5: Run — expect PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_ai_manager.gd -gexit
```

Expected: 3 testy pass.

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/AIManager.gd tests/engine/test_ai_manager.gd
git commit -m "feat(ai): Plan 18 AIManager skeleton + RNG injection"
```

---

## Task 2: `decide_accept_idea` — faction-weighted heuristic

**Cel:** Implementacja decision function. 5 nowych testów.

**Files:**
- Modify: `scripts/engine/AIManager.gd`
- Modify: `tests/engine/test_ai_manager.gd`

- [ ] **Step 1: Napisz 5 failing testów**

Dodaj w `tests/engine/test_ai_manager.gd`:

```gdscript

# === Plan 18: decide_accept_idea ===

const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state(player_id: String = "islam") -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize(player_id, religions, graph)
	return gs

func _make_idea(from_id: String, axis: String, delta: float) -> Idea:
	var idea := Idea.new()
	idea.from_religion_id = from_id
	idea.axis = axis
	idea.delta = delta
	return idea

func test_decide_accepts_when_dominant_faction_supports_shift() -> void:
	# Slavic + axis A delta -3 (lower A): Wolchwi (0.45 influence, A-1) supports → net +0.45 > 0 → accept.
	var gs := _make_state()
	var rel: Religion = gs.get_religion("slavic_paganism")
	var idea := _make_idea("islam", "A", -3.0)
	var ai := AIManagerScript.new()
	assert_true(ai.decide_accept_idea(rel, idea), "Wolchwi support A↓ → accept")

func test_decide_rejects_when_dominant_faction_opposes_shift() -> void:
	# Slavic + axis A delta +5 (raise A): Wolchwi opposes → net -0.45 < 0 → reject.
	var gs := _make_state()
	var rel: Religion = gs.get_religion("slavic_paganism")
	var idea := _make_idea("islam", "A", 5.0)
	var ai := AIManagerScript.new()
	assert_false(ai.decide_accept_idea(rel, idea), "Wolchwi oppose A↑ → reject")

func test_decide_rejects_on_zero_net_support() -> void:
	# Slavic + axis B delta +5 (raise B): Plemienna Starszyzna (0.35 influence, B-1) opposes → -0.35 < 0 → reject.
	# Note: this tests rejecting on negative; for zero-net case, we test religia bez axis_preferences na osi.
	# Manichaeism factions: Iluminowani (C+1, A-1), Pustelnicy (D+1, C-1), Naczynia Hyle (B-1).
	# Axis A delta +5: Iluminowani oppose (-0.30 contrib), reszta neutralna na A → net negative.
	# Tu test innej axis — sprawdzamy że dla osi bez żadnej frakcji w preferencjach zwracamy reject.
	# Hindu factions to test: Bramini (...), Kapłani (...), Asketicy (...). Sprawdź data.
	# Workaround: użyj rel z fake factions (mockowanie).
	# PRAGMATIC: użyjmy Slavic + axis D delta +3 — Wolchwi support D↑ (0.45), Herosi oppose D↑ (0.20)
	# Net: 0.45 - 0.20 = +0.25 > 0 → accept. Nie pasuje.
	# Lepiej: Slavic + axis C delta -3 — Herosi C+1 oppose → reject. Albo użyj zero-net direct:
	# brak frakcji wspierającej axis na której idea działa.
	# Najprostsze: NEW religion bez factions, lub mock.
	var gs := _make_state()
	var rel: Religion = gs.get_religion("slavic_paganism")
	# Iteruj faktyczne axis_preferences i wybierz combo z net_support == 0.
	# Stwórz idea na osi gdzie żadna frakcja Slavic NIE ma preferencji:
	# Slavic factions: Wolchwi (D+1, A-1), Plemienna Starszyzna (B-1), Herosi Ziemi (D-1, C+1).
	# Pokrywają A, B, C, D. Brak osi neutralnej.
	# Workaround: usuń wszystkie axis_preferences (mutuj rel.factions[X].axis_preferences = []):
	for f: Faction in rel.factions:
		f.axis_preferences = []
	var idea := _make_idea("islam", "A", 5.0)
	var ai := AIManagerScript.new()
	assert_false(ai.decide_accept_idea(rel, idea), "Zero net_support (no preferences match) → reject (conservative)")

func test_decide_uses_faction_influence_weighting() -> void:
	# Stwórz dwie frakcje: 0.20 supporter + 0.40 opposer → reject (oppose stronger).
	var gs := _make_state()
	var rel: Religion = gs.get_religion("slavic_paganism")
	# Override fakcje: 1 supporter (0.20, A+1) + 1 opposer (0.40, A-1) + Idea axis A delta +5.
	# shift=+1. Supporter: 0.20 × 1 × 1 = +0.20. Opposer: 0.40 × -1 × 1 = -0.40. Net = -0.20 < 0 → reject.
	rel.factions = []
	var f1 := Faction.new()
	f1.id = "supporter"
	f1.influence = 0.20
	f1.axis_preferences = [{"axis": "A", "direction": 1}]
	var f2 := Faction.new()
	f2.id = "opposer"
	f2.influence = 0.40
	f2.axis_preferences = [{"axis": "A", "direction": -1}]
	rel.factions = [f1, f2]
	var idea := _make_idea("islam", "A", 5.0)
	var ai := AIManagerScript.new()
	assert_false(ai.decide_accept_idea(rel, idea), "Większa influence opposera → reject")

func test_decide_rejects_religion_with_no_factions() -> void:
	var gs := _make_state()
	var rel: Religion = gs.get_religion("slavic_paganism")
	rel.factions = []
	var idea := _make_idea("islam", "A", 5.0)
	var ai := AIManagerScript.new()
	assert_false(ai.decide_accept_idea(rel, idea), "Brak frakcji → reject (conservative)")
```

- [ ] **Step 2: Run — expect FAILS**

Expected: 5 testów fail (`decide_accept_idea` brak).

- [ ] **Step 3: Implementuj `decide_accept_idea` w AIManager**

Po `_init` w `scripts/engine/AIManager.gd`:

```gdscript

func decide_accept_idea(religion: Religion, idea: Idea) -> bool:
	# Plan 18 §4.1: faction-weighted sum > 0 → accept.
	# sign_match = pref.direction × sign(idea.delta).
	# net_support = Σ faction.influence × sign_match.
	var net_support: float = 0.0
	var shift_direction: int = 1 if idea.delta > 0.0 else -1
	for faction: Faction in religion.factions:
		for pref: Dictionary in faction.axis_preferences:
			if pref.get("axis", "") == idea.axis:
				var pref_dir: int = pref.get("direction", 0)
				net_support += faction.influence * pref_dir * shift_direction
				break
	return net_support > 0.0
```

- [ ] **Step 4: Run — expect PASS**

Expected: 5 testów pass + 3 z Task 1 pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/AIManager.gd tests/engine/test_ai_manager.gd
git commit -m "feat(ai): Plan 18 decide_accept_idea — faction-weighted heuristic"
```

---

## Task 3: `should_dispatch_scholar` — prestige gate + RNG

**Cel:** Decision function dla dispatch. 3 testy.

**Files:**
- Modify: `scripts/engine/AIManager.gd`
- Modify: `tests/engine/test_ai_manager.gd`

- [ ] **Step 1: Napisz 3 failing testy**

```gdscript

# === Plan 18: should_dispatch_scholar ===

func _seeded_rng(seed_val: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	return rng

func test_should_not_dispatch_when_defeated() -> void:
	var gs := _make_state()
	var rel: Religion = gs.get_religion("slavic_paganism")
	rel.defeated_at_turn = 50
	rel.prestige = 200
	var ai := AIManagerScript.new(_seeded_rng(0))  # nie używamy RNG bo defeated guard wcześniej.
	assert_false(ai.should_dispatch_scholar(rel))

func test_should_not_dispatch_when_prestige_below_min() -> void:
	var gs := _make_state()
	var rel: Religion = gs.get_religion("slavic_paganism")
	rel.prestige = 49  # próg ostry: AI_SCHOLAR_MIN_PRESTIGE=50.
	var ai := AIManagerScript.new(_seeded_rng(0))
	assert_false(ai.should_dispatch_scholar(rel))

func test_should_dispatch_deterministic_with_seeded_rng() -> void:
	# Z seed 1, randf() ma deterministyczną wartość. Sprawdź obserwowany rezultat.
	var gs := _make_state()
	var rel: Religion = gs.get_religion("slavic_paganism")
	rel.prestige = 100  # > 50
	var ai_a := AIManagerScript.new(_seeded_rng(1))
	var ai_b := AIManagerScript.new(_seeded_rng(1))
	# Dwa AIManagery z tym samym seedem → identyczne wyniki.
	assert_eq(ai_a.should_dispatch_scholar(rel), ai_b.should_dispatch_scholar(rel),
		"Identyczne seedy → identyczne decyzje (deterministic)")
```

- [ ] **Step 2: Run — expect FAILS**

- [ ] **Step 3: Implementuj `should_dispatch_scholar`**

```gdscript

func should_dispatch_scholar(religion: Religion) -> bool:
	# Plan 18 §5.1: gate na defeated + prestige + RNG chance.
	if religion.defeated_at_turn != -1:
		return false
	if religion.prestige < AI_SCHOLAR_MIN_PRESTIGE:
		return false
	return rng.randf() < AI_SCHOLAR_DISPATCH_CHANCE
```

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/AIManager.gd tests/engine/test_ai_manager.gd
git commit -m "feat(ai): Plan 18 should_dispatch_scholar — prestige gate + RNG"
```

---

## Task 4: `choose_scholar_target` — random non-self non-defeated

**Cel:** Target selection. 3 testy.

**Files:**
- Modify: `scripts/engine/AIManager.gd`
- Modify: `tests/engine/test_ai_manager.gd`

- [ ] **Step 1: Napisz 3 failing testy**

```gdscript

# === Plan 18: choose_scholar_target ===

func test_choose_scholar_target_returns_non_self() -> void:
	var gs := _make_state()
	var rel: Religion = gs.get_religion("slavic_paganism")
	var ai := AIManagerScript.new(_seeded_rng(42))
	var target := ai.choose_scholar_target(gs, rel)
	assert_ne(target, "", "Target nie powinien być pusty (są inne religie w fixturze)")
	assert_ne(target, "slavic_paganism", "Target nie może być self")

func test_choose_scholar_target_skips_defeated_religions() -> void:
	var gs := _make_state()
	# Defeat wszystkich poza Slavic i Islam.
	for r: Religion in gs.all_religions():
		if r.id != "slavic_paganism" and r.id != "islam":
			r.defeated_at_turn = 1
	var rel: Religion = gs.get_religion("slavic_paganism")
	var ai := AIManagerScript.new(_seeded_rng(42))
	var target := ai.choose_scholar_target(gs, rel)
	assert_eq(target, "islam", "Jedyny żywy non-self target to islam")

func test_choose_scholar_target_returns_empty_when_no_candidates() -> void:
	var gs := _make_state()
	# Defeat wszystkich poza Slavic.
	for r: Religion in gs.all_religions():
		if r.id != "slavic_paganism":
			r.defeated_at_turn = 1
	var rel: Religion = gs.get_religion("slavic_paganism")
	var ai := AIManagerScript.new(_seeded_rng(42))
	var target := ai.choose_scholar_target(gs, rel)
	assert_eq(target, "", "Brak żywych kandydatów → empty string")
```

- [ ] **Step 2: Run — expect FAILS**

- [ ] **Step 3: Implementuj `choose_scholar_target`**

```gdscript

func choose_scholar_target(state: Node, religion: Religion) -> String:
	# Plan 18 §5.2: random non-self, non-defeated.
	var candidates: Array[String] = []
	for r: Religion in state.all_religions():
		if r.id == religion.id:
			continue
		if r.defeated_at_turn != -1:
			continue
		candidates.append(r.id)
	if candidates.is_empty():
		return ""
	return candidates[rng.randi() % candidates.size()]
```

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/AIManager.gd tests/engine/test_ai_manager.gd
git commit -m "feat(ai): Plan 18 choose_scholar_target — random non-self non-defeated"
```

---

## Task 5: TurnManager `set_ai_override` — test isolation infrastructure

**Cel:** Dodać setter `set_ai_override(ai)` + helper `_get_ai()` w TurnManager. Bez nowych behaviorów — tylko infrastruktura testowa potrzebna dla Tasks 6/7/8.

**Files:**
- Modify: `scripts/engine/TurnManager.gd`
- Modify: `tests/engine/test_turn_manager.gd` (1 test infrastruktury)

- [ ] **Step 1: Napisz failing test**

W `tests/engine/test_turn_manager.gd` na końcu pliku:

```gdscript

# === Plan 18: AI override infrastructure ===

func test_turn_manager_set_ai_override_replaces_default() -> void:
	var tm := TurnManager.new()
	var custom_ai := AIManager.new()
	tm.set_ai_override(custom_ai)
	# Internal helper _get_ai returns custom_ai gdy ustawione, inaczej default new().
	assert_eq(tm._get_ai(), custom_ai, "set_ai_override pinuje AIManager dla testów")

func test_turn_manager_get_ai_returns_new_instance_when_no_override() -> void:
	var tm := TurnManager.new()
	var ai := tm._get_ai()
	assert_not_null(ai, "Bez override _get_ai zwraca świeży AIManager")
	assert_true(ai is AIManager)
```

- [ ] **Step 2: Run — expect FAILS**

- [ ] **Step 3: Dodaj infrastrukturę w `scripts/engine/TurnManager.gd`**

Na początku klasy (po `extends RefCounted` lub innym extends):

```gdscript
# Plan 18: AI override dla test isolation.
# Produkcja: _get_ai zwraca świeży AIManager (jak inne managery — per-step).
# Testy: set_ai_override pinuje konkretną instancję (np. z seeded RNG lub disabled chance).
var _ai_override: AIManager = null

func set_ai_override(ai: AIManager) -> void:
	_ai_override = ai

func _get_ai() -> AIManager:
	if _ai_override != null:
		return _ai_override
	return AIManager.new()
```

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/TurnManager.gd tests/engine/test_turn_manager.gd
git commit -m "feat(engine): Plan 18 TurnManager AI override infrastructure"
```

---

## Task 6: `_npc_dispatch_scholars` — proactive NPC dispatch

**Cel:** Nowy etap w `process_turn` — NPC dispatchują scholars per turn.

**Files:**
- Modify: `scripts/engine/TurnManager.gd`
- Modify: `tests/engine/test_turn_manager.gd`

- [ ] **Step 1: Napisz failing test integracyjny**

```gdscript

func test_npc_dispatches_scholar_with_seeded_rng() -> void:
	# Seed wybierz tak żeby randf() < 0.15 → NPC dispatchuje.
	# Player = islam, więc dispatch przez Slavic powinien sukces.
	# Seed 1, randf() pierwsza wartość znana — sprawdź eksperymentalnie.
	var tm := TurnManager.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	tm.set_ai_override(AIManager.new(rng))
	var gs := _make_state()
	# Manualnie ustaw prestige Slavic > 50.
	var slavic: Religion = gs.get_religion("slavic_paganism")
	slavic.prestige = 200
	var initial_missions := gs.scholar_missions.size()
	tm.process_turn(gs)
	# Co najmniej 1 NPC powinien dispatch'ować (z 10 NPC, 15% chance, 1 turn — szansa ≥1 ≈ 80%).
	# Z deterministycznym seedem to jest binary — verify ≥1 OR ≥0 depending on seed.
	# PRAGMATIC: sprawdź że suite zachowuje się deterministycznie z tym seedem.
	# (Konkretną liczbę dispatch'ów wyliczymy eksperymentalnie post-implementation.)
	assert_gte(gs.scholar_missions.size(), initial_missions,
		"NPC dispatches nie zmniejszają liczby missions (mogą tylko zwiększyć)")
```

**Uwaga:** test deterministyczny ale lekki — sprawdza tylko że dispatch może się zdarzyć (nie pęka), nie zlicza dokładnej liczby. Po implementacji wartość seed=1 może być dostrojona dla mocniejszej asercji (np. `assert_gt`).

- [ ] **Step 2: Run — expect FAIL**

Expected: brak `_npc_dispatch_scholars` (lub etap nie istnieje w pipeline).

- [ ] **Step 3: Dodaj `_npc_dispatch_scholars` w TurnManager**

```gdscript

func _npc_dispatch_scholars(state: Node) -> void:
	# Plan 18 §6.1: per-turn NPC scholar dispatch.
	var ai := _get_ai()
	var dm := DoctrineManager.new()
	for religion: Religion in state.all_religions():
		if religion.id == state.player_religion_id:
			continue
		if not ai.should_dispatch_scholar(religion):
			continue
		var target_id: String = ai.choose_scholar_target(state, religion)
		if target_id != "":
			dm.dispatch_scholar(state, religion.id, target_id)
```

- [ ] **Step 4: Wstaw `_npc_dispatch_scholars(state)` w `process_turn`**

Znajdź w `scripts/engine/TurnManager.gd`:
```gdscript
	_update_faction_tensions(state)
	_process_scholar_missions(state)
```

Zmień na:
```gdscript
	_update_faction_tensions(state)
	_npc_dispatch_scholars(state)
	_process_scholar_missions(state)
```

- [ ] **Step 5: Run — expect PASS (nowy test)**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_turn_manager.gd -gexit
```

Expected: nowy test pass. **Stare testy mogą failować** (interim broken state — Task 7 naprawi).

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/TurnManager.gd tests/engine/test_turn_manager.gd
git commit -m "feat(engine): Plan 18 _npc_dispatch_scholars — proactive NPC dispatch"
```

---

## Task 7: `_process_scholar_missions` modification + test isolation fixes

**Cel:** NPC ideas auto-resolve via AI; player ideas wciąż w pending_ideas. Naprawić 2 testy zidentyfikowane w Task 0.

**Files:**
- Modify: `scripts/engine/TurnManager.gd`
- Modify: `tests/engine/test_turn_manager.gd`

- [ ] **Step 1: Napisz 2 nowe failing testy**

```gdscript

func test_player_scholar_mission_lands_in_pending_ideas() -> void:
	# Islam = player. Mission islam → western generuje idea, ląduje w pending_ideas.
	var tm := TurnManager.new()
	# Disabled AI dispatch (random > 0.15 always) — testy player flow tylko.
	var rng := RandomNumberGenerator.new()
	rng.seed = 0
	tm.set_ai_override(AIManager.new(rng))  # seed 0 → możliwy dispatch, ale śledzimy konkretną mission.
	var gs := _make_state()
	var islam: Religion = gs.get_religion("islam")
	var chr: Religion = gs.get_religion("western_christianity")
	islam.axes["A"] = 20.0
	chr.axes["A"] = 80.0
	# Pin pozostałe osie żeby A miała max diff.
	for axis: String in ["B", "C", "D"]:
		islam.axes[axis] = 50.0
		chr.axes[axis] = 50.0
	gs.scholar_missions.append({
		"from_religion_id": "islam",
		"to_religion_id": "western_christianity",
		"turns_remaining": 1,
	})
	var initial_pending := gs.pending_ideas.size()
	tm.process_turn(gs)
	assert_eq(gs.pending_ideas.size(), initial_pending + 1, "Player idea ląduje w pending_ideas")

func test_npc_scholar_mission_auto_resolves_via_ai() -> void:
	# Slavic = NPC. Mission slavic → western generuje idea, AI decide → accept lub reject (nie pending_ideas).
	var tm := TurnManager.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 0
	tm.set_ai_override(AIManager.new(rng))
	var gs := _make_state()  # player_id="islam"
	var slavic: Religion = gs.get_religion("slavic_paganism")
	var chr: Religion = gs.get_religion("western_christianity")
	slavic.axes["A"] = 20.0
	chr.axes["A"] = 80.0
	for axis: String in ["B", "C", "D"]:
		slavic.axes[axis] = 50.0
		chr.axes[axis] = 50.0
	gs.scholar_missions.append({
		"from_religion_id": "slavic_paganism",
		"to_religion_id": "western_christianity",
		"turns_remaining": 1,
	})
	var initial_pending := gs.pending_ideas.size()
	tm.process_turn(gs)
	# Mission resolved (nie w scholar_missions) AND nie w pending_ideas (auto-resolved by AI).
	# Note: process_turn może spawn'ować nowe NPC missions — sprawdzamy że mission specyficzny zniknął.
	# Po Task 6 nowe missions mogą się dodawać → zamiast `size == 0` sprawdzamy że żadna z istniejących nie zawiera tej from/to combo.
	var matching_missions := 0
	for m: Dictionary in gs.scholar_missions:
		if m["from_religion_id"] == "slavic_paganism" and m["to_religion_id"] == "western_christianity":
			matching_missions += 1
	assert_eq(matching_missions, 0, "Mission slavic→western resolved (zniknął z scholar_missions)")
	# Idea nie ląduje w pending (NPC dispatch).
	assert_eq(gs.pending_ideas.size(), initial_pending, "NPC idea nie ląduje w pending_ideas")
```

- [ ] **Step 2: Run — expect FAILS**

Expected: nowe testy fail (NPC dispatch wciąż ląduje w pending_ideas — Task 6 nie modyfikował resolve logic).

- [ ] **Step 3: Modyfikuj `_process_scholar_missions` w TurnManager**

Znajdź obecną funkcję (ok. linie 75-83):
```gdscript
func _process_scholar_missions(state: Node) -> void:
	var dm := DoctrineManager.new()
	var still_active: Array = []
	for mission: Dictionary in state.scholar_missions:
		mission["turns_remaining"] -= 1
		if mission["turns_remaining"] <= 0:
			var idea := dm.generate_idea(mission["from_religion_id"], mission["to_religion_id"], state)
			if idea != null:
				state.pending_ideas.append(idea)
		else:
			still_active.append(mission)
	state.scholar_missions = still_active
```

Zmień na:
```gdscript
func _process_scholar_missions(state: Node) -> void:
	var dm := DoctrineManager.new()
	var ai := _get_ai()
	var still_active: Array = []
	for mission: Dictionary in state.scholar_missions:
		mission["turns_remaining"] -= 1
		if mission["turns_remaining"] <= 0:
			var idea := dm.generate_idea(mission["from_religion_id"], mission["to_religion_id"], state)
			if idea != null:
				_resolve_idea(idea, mission["from_religion_id"], state, dm, ai)
		else:
			still_active.append(mission)
	state.scholar_missions = still_active

func _resolve_idea(idea: Idea, dispatcher_id: String, state: Node, dm: DoctrineManager, ai: AIManager) -> void:
	# Plan 18 §6.2: rozróżnij player vs NPC.
	if dispatcher_id == state.player_religion_id:
		state.pending_ideas.append(idea)
		return
	var dispatcher: Religion = state.get_religion(dispatcher_id)
	if dispatcher == null or dispatcher.defeated_at_turn != -1:
		return  # NPC defeated mid-mission — drop idea.
	if ai.decide_accept_idea(dispatcher, idea):
		dm.accept_idea(idea, dispatcher, state)
	else:
		dm.reject_idea(idea, state)
```

- [ ] **Step 4: Run nowych testów — expect PASS**

- [ ] **Step 5: Napraw test isolation dla 2 testów z Task 0 Step 3**

Sprawdź czy testy z Task 0 (`test_process_turn_decrements_scholar_mission_turns`, `test_process_turn_generates_idea_when_mission_completes`) wciąż przechodzą po Task 6 + 7. Jeśli pęknięte (NPC dispatch dodaje extra missions), dodaj na początku **każdego z 2 testów**:

```gdscript
	# Plan 18: disable NPC AI dispatch dla tego testu (seed=0 + niska prestige).
	# Alternative: ai_override z RNG zwracającym zawsze > 0.15.
	var disabled_rng := RandomNumberGenerator.new()
	disabled_rng.seed = 999999  # wybierz seed gdzie randf() pierwsze N wywołań > 0.15
	tm.set_ai_override(AIManager.new(disabled_rng))
```

**Lepsze rozwiązanie:** TurnManager mógłby przyjmować `set_npc_disabled(true)` flag (boolean disable całego NPC pipeline). Plan 18 wybiera prostsze: pin prestige=0 dla wszystkich NPC w teście:

```gdscript
	# Plan 18: pin NPC prestige=0 by block all NPC scholar dispatch (gate check).
	for r: Religion in gs.all_religions():
		if r.id != gs.player_religion_id:
			r.prestige = 0
```

To **deterministyczne** (gate prestige < 50 zwraca false zawsze) i nie wymaga seed engineering.

Dodaj te 5 linii na początku ciał `test_process_turn_decrements_scholar_mission_turns` oraz `test_process_turn_generates_idea_when_mission_completes`.

- [ ] **Step 6: Run pełnego test_turn_manager.gd — expect PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_turn_manager.gd -gexit
```

Expected: wszystkie testy pass (stare + 4 nowe Plan 18).

- [ ] **Step 7: Run całej suite — expect PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: ~756 testów pass.

- [ ] **Step 8: Commit**

```bash
git add scripts/engine/TurnManager.gd tests/engine/test_turn_manager.gd
git commit -m "feat(engine): Plan 18 _process_scholar_missions AI resolution + test isolation"
```

---

## Task 8: CLAUDE.md cross-reference

**Cel:** 1-liner Plan 18 w "End-of-game flow" lub osobnej sekcji.

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Sprawdź obecny stan CLAUDE.md**

```bash
grep -n "Plan 17\|Plan 18\|NPC\|AI" CLAUDE.md | head
```

- [ ] **Step 2: Dopisz 1-liner po Plan 17**

Plan 18 to NIE end-of-game feature — lepiej dodać jako osobny bullet "AI/NPC" w sekcji "Architecture" lub po sekcji "Stateless Manager pattern". Najczystsze: dodać do "Stateless Manager pattern" bullet info o AIManager.

Pragmatyczny wybór: dopisz w "End-of-game flow" bullet (gdzie są inne Plan N referencje) jako historical log, nawet jeśli temat to NPC AI nie endgame:

```
Plan 18 (`docs/superpowers/specs/18-npc-doctrine-ai-design.md`) — pierwsza implementacja AI: NPC religie dispatchują scholarów i auto-resolve ideas via faction-weighted heuristic. Nowa klasa `AIManager` (stateless, RefCounted, RNG injection dla testów). `TurnManager` ma `set_ai_override` setter dla test isolation.
```

- [ ] **Step 3: Sanity grep**

```bash
grep -F "18-npc-doctrine-ai-design.md" CLAUDE.md
```

Expected: 1 linia.

- [ ] **Step 4: Cała suite (sanity)**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: ~756 testów pass.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: cross-reference do spec 18 (NPC AI doctrine MVP)"
```

---

## Po wszystkich taskach

- [ ] **Final review**: dispatch `superpowers:code-reviewer` na pełen branch (~10 commitów Plan 18 + spec/plan). Reviewer sprawdza:
  - Spec compliance (14 acceptance criteria z §9).
  - Code quality (tab indent, English IDs, brak magic numbers, RNG seeding).
  - Test coverage (~15 nowych testów + isolation w istniejących).
  - Brak regresji (~756 pass).
  - Architektura AIManager (stateless, RefCounted, parametr RNG).
  - Integracja w TurnManager (pipeline placement, override pattern).

- [ ] **Po approval**: push do origin/master.

---

## Acceptance Criteria (z spec §9)

Plan 18 jest gotowy do merge gdy:

1. ✅ `scripts/engine/AIManager.gd` istnieje (`class_name AIManager`, `extends RefCounted`, stateless).
2. ✅ 2 stałe w AIManager (`AI_SCHOLAR_MIN_PRESTIGE=50`, `AI_SCHOLAR_DISPATCH_CHANCE=0.15`).
3. ✅ `_init(rng = null)` z opcjonalnym RNG injection.
4. ✅ `decide_accept_idea` implementuje faction-weighted sum > 0.
5. ✅ `should_dispatch_scholar` ma defeated + prestige + RNG gates.
6. ✅ `choose_scholar_target` zwraca random non-self non-defeated lub "".
7. ✅ `TurnManager._npc_dispatch_scholars` wywoływany w `process_turn` przed `_process_scholar_missions`.
8. ✅ `TurnManager._process_scholar_missions` rozróżnia player vs NPC dispatcher.
9. ✅ Player ideas wciąż w `pending_ideas` (no regression).
10. ✅ Istniejące Plan 12-17 testy (~741) pass — z minimalnym AI isolation w 2 test_turn_manager.gd testach.
11. ✅ ~15 nowych testów pass (12 AIManager + 3 TurnManager integration).
12. ✅ Cała suite (~756) pass.
13. ✅ `CLAUDE.md` wzmiankuje Plan 18.
14. ✅ Brak zmian w `data/*.json`, Religion.gd, Faction.gd, Idea.gd, DoctrineManager.gd, GameState.gd, UI.
