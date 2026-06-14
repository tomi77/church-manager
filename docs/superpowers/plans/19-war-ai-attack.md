# Plan 19 — War AI attack_province (MVP) Implementation Plan

> **For Claude:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Pierwsza war AI mechanika. NPC atakujący wykonują `attack_province` per turn gdy `war.state == "BATTLING"`. Border-adjacent target preferred, fallback random.

**Architecture:** Rozszerzenie istniejącej `AIManager` klasy (Plan 18) o 2 metody: `should_attack_in_war` (gating) + `choose_attack_target` (border-adjacent + fallback). Nowy etap `_npc_attack_wars(state)` w `TurnManager.process_turn` po `_process_active_wars`. Per-war 1 attack per turn, skip player attacker.

**Tech Stack:** Godot 4.6.3, GDScript 2.0, GUT.

**Spec:** [`docs/superpowers/specs/19-war-ai-attack-design.md`](../specs/19-war-ai-attack-design.md)

---

## Convention reminders (z [CLAUDE.md](../../../CLAUDE.md))

- **Tab indent** w `.gd`.
- **AIManager rng injection** — testy używają seeded RNG (Plan 18 pattern).
- **No randf() w testach** bez seed — wszystkie AI decisions używają `ai.rng`.
- **WarManager.attack_province używa randf() globalnego** — Plan 19 NIE modyfikuje, ale testy integracyjne akceptują dowolny battle outcome (assert ≥1 attempt, nie specific battles_won).
- **AIManager rozszerzenie addytywne** — nowe metody dodajemy po istniejących, bez modyfikacji prior API.

---

## Test command reference

```bash
# Cała suite (po Plan 18: 760; po Plan 19 oczekiwane ~770)
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# Pojedynczy
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_ai_manager.gd -gexit
```

---

## File Structure

**Modyfikowane:**
- `scripts/engine/AIManager.gd` — 2 nowe metody (`should_attack_in_war`, `choose_attack_target`).
- `scripts/engine/TurnManager.gd` — nowy etap `_npc_attack_wars` + wstawienie w pipeline.
- `tests/engine/test_ai_manager.gd` — ~5 nowych testów.
- `tests/engine/test_turn_manager.gd` — ~3 nowe testy + isolation w pre-existing tests (Task 0 zdecyduje konkretnie).
- `CLAUDE.md` — 1-liner cross-reference.

**Bez zmian:**
- `WarManager.gd`, `War.gd`, `Religion.gd`, `Province.gd`, `ProvinceGraph.gd`, `GameState.gd`.
- Fixture (`data/*.json`).
- UI.

**Mapa: spec § → Task**

| Spec § | Task |
|---|---|
| §10 R1 isolation enumeration | 0 (pre-flight) |
| §4 should_attack_in_war | 1 |
| §5 choose_attack_target | 2 |
| §6 _npc_attack_wars + pipeline | 3 |
| §10 R1 isolation fix (pre-existing tests) | 3 (folded) |
| §3 CLAUDE.md | 4 |

---

## Task 0: Pre-flight — baseline + wide collision enumerate

**Cel:** Cała suite baseline + wide grep wszystkich test files używających `process_turn` z active_wars.

- [ ] **Step 1: Baseline suite pass**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: ~760 testów pass (Plan 18 baseline).

- [ ] **Step 2: Wide collision grep (spec §10 R1 advisory)**

```bash
grep -l "process_turn" tests/**/*.gd | xargs grep -l "active_wars\|declare_war\|attack_province"
```

Lista plików — sprawdź każdy, identyfikuj testy które:
- Wywołują `process_turn`
- Mają NPC religię jako attacker w jakimś active_war
- Asercjują na stanie wojny (war.state, battles_won, battles_lost, weariness)

Spodziewane pliki do sprawdzenia:
- `tests/engine/test_turn_manager.gd` — 4 testy wojenne (spec §10 R1).
- `tests/engine/test_war_manager.gd` — większość używa wm bezpośrednio, nie process_turn.
- `tests/engine/test_diplomacy_manager.gd` — może mieć integration tests.
- UI tests (`test_world_tab_integration.gd` etc.) — mogą używać process_turn ale niekoniecznie z NPC attacker.

- [ ] **Step 3: Sprawdź konkretną listę z spec §10 R1**

Sprawdź:
- `test_turn_manager.gd:test_process_turn_mobilizing_war_transitions_to_battling_after_2_turns`
- `test_turn_manager.gd:test_process_turn_occupying_war_returns_to_battling_after_2_turns`
- `test_turn_manager.gd:test_process_turn_increments_war_weariness_for_both_sides`
- `test_turn_manager.gd:test_process_turn_force_peace_at_weariness_90_creates_defeat_event`

Dla każdego: KTO jest war.attacker_id i KTO jest gs.player_religion_id? Jeśli attacker != player (NPC attacker) → test wymaga isolation.

- [ ] **Step 4: Notatki dla Task 3**

Zapisz wyniki — które testy wymagają isolation i konkretną strategię (per-test fix).

Brak commitu — pre-flight inspection only.

---

## Task 1: `should_attack_in_war` (gating)

**Cel:** Implementacja gating function + 3 testy.

**Files:**
- Modify: `scripts/engine/AIManager.gd`
- Modify: `tests/engine/test_ai_manager.gd`

- [ ] **Step 1: Napisz 3 failing testy**

W `tests/engine/test_ai_manager.gd` na końcu pliku:

```gdscript

# === Plan 19: should_attack_in_war ===

const WarScript := preload("res://scripts/engine/War.gd")

func _make_war(attacker_id: String, defender_id: String, war_state: String = "BATTLING") -> War:
	var war := WarScript.new()
	war.attacker_id = attacker_id
	war.defender_id = defender_id
	war.casus_belli = "wojna_sprawiedliwa"
	war.state = war_state
	return war

func test_should_attack_in_war_returns_true_when_battling() -> void:
	var gs := _make_state()
	var rel: Religion = gs.get_religion("slavic_paganism")
	var war := _make_war("slavic_paganism", "eastern_christianity", "BATTLING")
	var ai := AIManagerScript.new()
	assert_true(ai.should_attack_in_war(rel, war), "BATTLING + alive → true")

func test_should_attack_in_war_returns_false_when_not_battling() -> void:
	var gs := _make_state()
	var rel: Religion = gs.get_religion("slavic_paganism")
	var ai := AIManagerScript.new()
	for non_battling: String in ["MOBILIZING", "OCCUPYING", "ENDED"]:
		var war := _make_war("slavic_paganism", "eastern_christianity", non_battling)
		assert_false(ai.should_attack_in_war(rel, war), "state %s → false" % non_battling)

func test_should_attack_in_war_returns_false_when_attacker_defeated() -> void:
	var gs := _make_state()
	var rel: Religion = gs.get_religion("slavic_paganism")
	rel.defeated_at_turn = 50
	var war := _make_war("slavic_paganism", "eastern_christianity", "BATTLING")
	var ai := AIManagerScript.new()
	assert_false(ai.should_attack_in_war(rel, war), "Defeated attacker → false")
```

- [ ] **Step 2: Run — expect FAILS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_ai_manager.gd -gexit
```

- [ ] **Step 3: Implementuj `should_attack_in_war`**

W `scripts/engine/AIManager.gd` po `choose_scholar_target` (na końcu klasy):

```gdscript

func should_attack_in_war(attacker: Religion, war: War) -> bool:
	# Plan 19 §4.1: gating attacker AI per war.
	# MVP: zawsze true gdy attacker żyje + war.state == BATTLING.
	# Placeholder dla future heurystyk (weariness, peace negotiation, CB-aware).
	if attacker == null or attacker.defeated_at_turn != -1:
		return false
	if war.state != "BATTLING":
		return false
	return true
```

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/AIManager.gd tests/engine/test_ai_manager.gd
git commit -m "feat(ai): Plan 19 should_attack_in_war — gating attacker"
```

---

## Task 2: `choose_attack_target` (border-adjacent + fallback)

**Cel:** Implementacja target selection + 4 testy.

**Files:**
- Modify: `scripts/engine/AIManager.gd`
- Modify: `tests/engine/test_ai_manager.gd`

- [ ] **Step 1: Napisz 4 failing testy**

W `tests/engine/test_ai_manager.gd` na końcu:

```gdscript

# === Plan 19: choose_attack_target ===

func test_choose_attack_target_picks_border_adjacent_when_available() -> void:
	# Slavic atakuje Eastern. Gardariki (Slavic) sąsiaduje z panonia (Slavic) — wewnątrz core.
	# Bardziej istotne: znajdź Slavic prowincję adjacent do Eastern province.
	# panonia (Slavic) ↔ tracja (Eastern) — wzajemna krawędź per Plan 17.
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("slavic_paganism")
	var ai := AIManagerScript.new(_seeded_rng(42))
	var target := ai.choose_attack_target(gs, attacker, "eastern_christianity")
	# Tracja jest jedyną Eastern province border-adjacent do panonia (Slavic).
	# Inne Eastern provinces (anatolia, konstantynopol, armenia, libia, karthago, jerozolima, lewant) — nie sąsiadują z Slavic.
	assert_eq(target, "tracja", "Tracja jako jedyna Eastern prov border-adjacent do panonia Slavic")

func test_choose_attack_target_falls_back_to_random_when_no_border() -> void:
	# Setup: attacker bez border-adjacency z defender. Slavic atakuje Islam (mezopotamia — non-adjacent do Slavic).
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("slavic_paganism")
	var ai := AIManagerScript.new(_seeded_rng(42))
	var target := ai.choose_attack_target(gs, attacker, "islam")
	# Islam ma tylko mezopotamia. Slavic prowincje nie sąsiadują → fallback random z defender_provs.
	assert_eq(target, "mezopotamia", "Fallback: jedyna Islam province mezopotamia (no border)")

func test_choose_attack_target_returns_empty_when_defender_has_no_provinces() -> void:
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("slavic_paganism")
	# Defender Islam — wyzeruj prowincje (Islam ma tylko mezopotamia).
	gs.province_graph.get_province("mezopotamia").owner = ""
	var ai := AIManagerScript.new(_seeded_rng(42))
	var target := ai.choose_attack_target(gs, attacker, "islam")
	assert_eq(target, "", "Defender 0 provinces → empty target")

func test_choose_attack_target_skips_non_defender_provinces() -> void:
	# Sanity: jeśli wszystkie defender provinces border-adjacent → wybierany jest tylko spośród defender.
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("slavic_paganism")
	var ai := AIManagerScript.new(_seeded_rng(42))
	var target := ai.choose_attack_target(gs, attacker, "eastern_christianity")
	# Target MUSI być Eastern province.
	var target_prov: Province = gs.province_graph.get_province(target)
	assert_not_null(target_prov)
	assert_eq(target_prov.owner, "eastern_christianity", "Target jest defender province (eastern_christianity)")
```

- [ ] **Step 2: Run — expect FAILS**

- [ ] **Step 3: Implementuj `choose_attack_target`**

W `AIManager.gd` po `should_attack_in_war`:

```gdscript

func choose_attack_target(state: Node, attacker: Religion, defender_id: String) -> String:
	# Plan 19 §5.1: border-adjacent preferred, fallback random defender province.
	var defender_provs := state.province_graph.provinces_with_owner(defender_id)
	if defender_provs.is_empty():
		return ""
	var border_candidates: Array[String] = []
	for d_prov: Province in defender_provs:
		for neighbor_id: String in d_prov.neighbors:
			var neighbor: Province = state.province_graph.get_province(neighbor_id)
			if neighbor != null and neighbor.owner == attacker.id:
				border_candidates.append(d_prov.id)
				break  # 1 entry per defender province
	if not border_candidates.is_empty():
		return border_candidates[rng.randi() % border_candidates.size()]
	# Fallback: random defender province (no border adjacency)
	return defender_provs[rng.randi() % defender_provs.size()].id
```

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/AIManager.gd tests/engine/test_ai_manager.gd
git commit -m "feat(ai): Plan 19 choose_attack_target — border-adjacent + fallback"
```

---

## Task 3: `_npc_attack_wars` TurnManager integration + test isolation

**Cel:** Nowy etap w pipeline + 3 integration testy + naprawa pre-existing tests (Task 0 enumerate).

**Files:**
- Modify: `scripts/engine/TurnManager.gd`
- Modify: `tests/engine/test_turn_manager.gd`

### Step 1: Napisz 3 failing integration testy

```gdscript

# === Plan 19: _npc_attack_wars integration ===

const WarScript := preload("res://scripts/engine/War.gd")

func _make_npc_attacker_war(state: Node, attacker_id: String, defender_id: String) -> War:
	# Pomocnik: stwórz wojnę w stanie BATTLING z attacker_id jako NPC (nie player).
	var war := WarScript.new()
	war.attacker_id = attacker_id
	war.defender_id = defender_id
	war.casus_belli = "wojna_sprawiedliwa"
	war.state = "BATTLING"
	war.turns_in_state = 0
	state.active_wars.append(war)
	return war

func test_npc_attacker_attacks_during_battling_state() -> void:
	var tm := TurnManager.new()
	# Disable NPC scholar dispatch (Plan 18 — pin prestige=0 for NPC scholars).
	# Tu Slavic ma być attacker — nie pinić Slavic prestige.
	var gs := _make_state()  # player = islam
	# Slavic atakuje Eastern Christianity. Pre-condition: panonia↔tracja border.
	var war := _make_npc_attacker_war(gs, "slavic_paganism", "eastern_christianity")
	# Reduce attacks_initially_done counter:
	var initial_battles: int = war.battles_won + war.battles_lost
	# Disable AI scholar noise: pin other NPC prestige=0.
	for r: Religion in gs.all_religions():
		if r.id != gs.player_religion_id and r.id != "slavic_paganism":
			r.prestige = 0
	tm.process_turn(gs)
	var after_battles: int = war.battles_won + war.battles_lost
	assert_gt(after_battles, initial_battles, "NPC attacker wykonał ≥1 attack")

func test_npc_does_not_attack_when_player_is_attacker() -> void:
	var tm := TurnManager.new()
	var gs := _make_state()  # player = islam
	# Player (islam) atakuje Eastern. NPC powinno skipnąć.
	var war := _make_npc_attacker_war(gs, "islam", "eastern_christianity")
	var initial_battles: int = war.battles_won + war.battles_lost
	# Pin NPC prestige=0 by isolation.
	for r: Religion in gs.all_religions():
		if r.id != gs.player_religion_id:
			r.prestige = 0
	tm.process_turn(gs)
	var after_battles: int = war.battles_won + war.battles_lost
	assert_eq(after_battles, initial_battles, "Player attacker → AI skip → no battles")

func test_npc_does_not_attack_during_mobilizing_state() -> void:
	var tm := TurnManager.new()
	var gs := _make_state()
	var war := _make_npc_attacker_war(gs, "slavic_paganism", "eastern_christianity")
	war.state = "MOBILIZING"
	# Disable other NPC noise.
	for r: Religion in gs.all_religions():
		if r.id != gs.player_religion_id and r.id != "slavic_paganism":
			r.prestige = 0
	var initial_battles: int = war.battles_won + war.battles_lost
	tm.process_turn(gs)
	# Po 1 turn: state może przejść z MOBILIZING do BATTLING (po 2 turach z MOBILIZATION_TURNS).
	# Jeden turn — state powinien zostać MOBILIZING (turns_in_state staje 1, < 2).
	# Więc _npc_attack_wars skip → battles unchanged.
	var after_battles: int = war.battles_won + war.battles_lost
	assert_eq(after_battles, initial_battles, "MOBILIZING → AI skip → no battles")
```

### Step 2: Run — expect FAILS (parse error: `_npc_attack_wars` brak)

### Step 3: Dodaj `_npc_attack_wars` w TurnManager

W `scripts/engine/TurnManager.gd` po `_process_active_wars` (lub gdziekolwiek z private functions, np. obok `_npc_dispatch_scholars`):

```gdscript

func _npc_attack_wars(state: Node) -> void:
	# Plan 19 §6.1: NPC attacker performs 1 attack per war per turn (gdy BATTLING).
	var ai := _get_ai()
	var wm := WarManager.new()
	for war: War in state.active_wars.duplicate():
		if war.state != "BATTLING":
			continue
		if war.attacker_id == state.player_religion_id:
			continue  # Player attacker → player UI decides
		var attacker: Religion = state.get_religion(war.attacker_id)
		if attacker == null:
			continue
		if not ai.should_attack_in_war(attacker, war):
			continue
		var target_id: String = ai.choose_attack_target(state, attacker, war.defender_id)
		if target_id != "":
			wm.attack_province(war, target_id, state)
```

### Step 4: Wstaw `_npc_attack_wars(state)` w pipeline `process_turn`

Znajdź:
```gdscript
	_process_active_wars(state)
	_process_missionaries(state)
```

Zmień na:
```gdscript
	_process_active_wars(state)
	_npc_attack_wars(state)
	_process_missionaries(state)
```

### Step 5: Run — expect PASS (nowe testy)

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_turn_manager.gd -gexit
```

Expected: nowe 3 testy pass. **Pre-existing 4 testy z Task 0 §10 R1 mogą failować** — to intended interim.

### Step 6: Napraw pre-existing tests (Task 0 enumeration)

**Reviewer Plan 19 plan note:** Wstępna analiza sugeruje że WSZYSTKIE 4 pre-existing testy używają `attacker_id = "islam"` AND `_make_state()` ma `player_religion_id = "islam"` jako default. Plan 19 player-skip guard (`war.attacker_id == state.player_religion_id` → continue) automatycznie chroni te testy — **isolation prawdopodobnie no-op**.

**Procedura:**
1. Po Step 5 (Run integration testów), uruchom pełną suite engine:
   ```bash
   godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gexit 2>&1 | grep -E "Failed|Failing"
   ```
2. **Jeśli ZERO failures** → no-op, skip do Step 7.
3. **Jeśli failures w 4 pre-existing tests** (z spec §10 R1) — Task 0 grep wykrył inne testy w innych plikach → zastosuj isolation per-test:
   - **Opcja A — pin `state.player_religion_id` na war.attacker_id:** dodaj `gs.player_religion_id = war.attacker_id` po `gs.active_wars.append(war)`.
   - **Opcja B — change attacker_id to player_religion_id:** zmień war.attacker_id w setup żeby był equal player_id.
   - Wybór per-test based on test intent.

### Step 7: Run całej suite — expect PASS

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: ~770 testów pass (760 baseline + 8 nowych).

### Step 8: Commit

```bash
git add scripts/engine/TurnManager.gd tests/engine/test_turn_manager.gd
git commit -m "feat(engine): Plan 19 _npc_attack_wars integration + test isolation"
```

---

## Task 4: CLAUDE.md cross-reference

**Cel:** 1-liner Plan 19 po Plan 18.

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Sprawdź stan**

```bash
grep -n "Plan 18\|18-npc-doctrine\|NPC AI" CLAUDE.md
```

- [ ] **Step 2: Dopisz 1-liner po Plan 18**

```
Plan 19 (`docs/superpowers/specs/19-war-ai-attack-design.md`) — pierwsza war AI: NPC atakujący wykonują `attack_province` per turn (border-adjacent target preferred). Brak NPC declarations/peace (Plan 20+).
```

- [ ] **Step 3: Sanity grep**

```bash
grep -F "19-war-ai-attack-design.md" CLAUDE.md
```

Expected: 1 linia.

- [ ] **Step 4: Cała suite (sanity — docs)**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: ~770 testów pass.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: cross-reference do spec 19 (War AI attack MVP)"
```

---

## Po wszystkich taskach

- [ ] **Final review**: dispatch `superpowers:code-reviewer` na pełen branch (~6 commitów Plan 19 + spec/plan). Reviewer sprawdza:
  - Spec compliance (13 acceptance criteria z §9).
  - Code quality (tab indent, RNG seeding, AIManager rozszerzenie addytywne).
  - Test coverage (~8 nowych + 4 pre-existing isolation).
  - Brak regresji (~770 pass).
  - Architektura — extension point pattern dla future war AI.

- [ ] **Po approval**: push do origin/master.

---

## Acceptance Criteria (z spec §9)

Plan 19 jest gotowy do merge gdy:

1. ✅ `AIManager.should_attack_in_war(attacker, war) -> bool` istnieje.
2. ✅ `AIManager.choose_attack_target(state, attacker, defender_id) -> String` istnieje.
3. ✅ `TurnManager._npc_attack_wars(state)` istnieje i wywoływany po `_process_active_wars`.
4. ✅ NPC attacker performs attack per turn (1 per war) gdy `war.state == "BATTLING"`.
5. ✅ Player attacker is skipped.
6. ✅ Defeated NPC attacker is skipped.
7. ✅ Border-adjacent target preferred, fallback random.
8. ✅ Defender 0 provinces → no attack.
9. ✅ Pre-existing Plan 12-18 testy pass — z minimal AI isolation w 4 tests.
10. ✅ ~8 nowych testów pass.
11. ✅ Cała suite (~770) pass.
12. ✅ CLAUDE.md wzmiankuje Plan 19.
13. ✅ Brak zmian w WarManager.gd, War.gd, fixture, UI, innych managerach.
