# Plan 20 — War AI declare_war + offer_peace Implementation Plan

> **For Claude:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Drugi war AI scope. NPC proaktywnie deklarują wojny (tension >= 70 + pełne guards) i oferują pokój kontekstowo per role (attacker: contested OR weariness > 70; defender: weariness > 60).

**Architecture:** Rozszerzenie istniejącej `AIManager` (Plan 18/19) o 4 metody (2 declare + 2 peace) + 4 stałe. 2 nowe etapy w `TurnManager.process_turn`: `_npc_offer_peace` (kończy istniejące wojny) + `_npc_declare_wars` (otwiera nowe). Pipeline po Plan 19 `_npc_attack_wars`. Pełne guards na declarations (ally/vassal/coalition/existing war).

**Tech Stack:** Godot 4.6.3, GDScript 2.0, GUT.

**Spec:** [`docs/superpowers/specs/20-war-ai-declare-peace-design.md`](../specs/20-war-ai-declare-peace-design.md)

---

## Convention reminders (z [CLAUDE.md](../../../CLAUDE.md))

- **Tab indent** w `.gd`.
- **AIManager rng injection** — testy używają seeded RNG (Plan 18/19 pattern).
- **No randf() w testach** bez seed — choose_war_target gated przez `rng.randf() < AI_WAR_DECLARE_CHANCE`.
- **Pełne guards** — declaration gating uses `_pair_in_active_war` semantyka inline, RelationState.alliance_active, Religion.suzerain_id, Coalition.members.
- **`active_wars.duplicate()` jest WYMAGANE** dla `_npc_offer_peace` (offer_peace mutuje `state.active_wars` przez `erase`).

---

## Test command reference

```bash
# Cała suite (po Plan 19: 770; po Plan 20 oczekiwane ~783)
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# Pojedynczy plik
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_ai_manager.gd -gexit
```

---

## File Structure

**Modyfikowane:**
- `scripts/engine/AIManager.gd` — 4 stałe + 4 metody (`should_declare_war`, `choose_war_target`, `should_offer_peace`, `compose_peace_terms`).
- `scripts/engine/TurnManager.gd` — 2 nowe etapy (`_npc_offer_peace`, `_npc_declare_wars`) + wstawienie w pipeline.
- `tests/engine/test_ai_manager.gd` — ~10 nowych testów.
- `tests/engine/test_turn_manager.gd` — ~3 integration testy + warunkowa isolation.
- `CLAUDE.md` — 1-liner.

**Bez zmian:**
- `WarManager.gd`, `War.gd`, `Religion.gd`, `RelationState.gd`, `Coalition.gd`, `DiplomacyManager.gd`, `GameState.gd`.
- Fixture (`data/*.json`).
- UI.

**Mapa: spec § → Task**

| Spec § | Task |
|---|---|
| §9 R1 isolation enumerate | 0 (pre-flight) |
| §4.1 stałe + §4.2 should_declare_war | 1 |
| §4.3 choose_war_target | 2 |
| §4.4/§4.5 peace (should + compose) | 3 |
| §5.1 _npc_offer_peace pipeline | 4 |
| §5.2 _npc_declare_wars pipeline + isolation | 5 |
| §3 CLAUDE.md | 6 |

---

## Task 0: Pre-flight — baseline + isolation enumerate

**Cel:** Baseline pass + wide enumerate testów które `process_turn` może zaburzyć przez declarations (nowe wojny) lub peace (kończenie wojen).

- [ ] **Step 1: Cała suite pass**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: ~770 testów pass (Plan 19 baseline).

- [ ] **Step 2: Wide grep — process_turn + war state**

```bash
grep -l "process_turn" tests/**/*.gd | xargs grep -l "active_wars\|declare_war\|offer_peace\|war.state"
```

Spodziewane pliki:
- `tests/engine/test_turn_manager.gd` — 4 testy wojenne + Plan 19 Tasks (5+).
- `tests/engine/test_diplomacy_manager.gd` — może mieć integration tests.
- `tests/engine/test_war_manager.gd` — line 964 (jedno użycie).

- [ ] **Step 3: Identyfikuj testy zagrożone declarations**

Plan 20 declare może DODAĆ wojny do `active_wars`. Testy asercjujące `active_wars.size() == N` mogą failować jeśli:
- Para NPC ma `military_tension >= 70` w fixturze (RelationState default).
- NPC ma prestige >= 10.
- NPC ma CB available.
- RNG seed dostarcza `randf() < 0.2`.

Sprawdź startowe military_tension dla par w fixturze (`data/religions_historical.json` lub gdzie ustawiane defaultowo).

```bash
grep -A 2 "military_tension" data/religions_historical.json scripts/engine/*.gd | head -30
```

- [ ] **Step 4: Identyfikuj testy zagrożone peace**

Plan 20 peace może USUNĄĆ wojny z `active_wars`. Testy asercjujące war.state, war.battles_won, weariness mogą failować jeśli NPC strona spełnia condition:
- Attacker NPC + contested > 0 → peace.
- Attacker NPC + weariness > 70 → peace.
- Defender NPC + weariness > 60 → peace.

Większość testów Plan 19 z war.weariness manipulacją może być zagrożona.

- [ ] **Step 5: Notatki dla Task 5**

Zapisz listę testów wymagających izolacji per kategoria (declare-vulnerable, peace-vulnerable). Najprostsze mitigation:
- **Disabled RNG**: `disabled_rng = RandomNumberGenerator.new(); disabled_rng.seed = X` gdzie randf() pierwsze N > 0.2 (skip declare).
- **Pin tension < 70** dla all NPC pairs w teście.
- **Pin attacker_id = player** (już chroni przez Plan 19 player-skip).

Brak commitu — pre-flight inspection only.

---

## Task 1: Stałe + `should_declare_war` (pełne guards)

**Cel:** 4 stałe Plan 20 + main declaration gating.

**Files:**
- Modify: `scripts/engine/AIManager.gd`
- Modify: `tests/engine/test_ai_manager.gd`

- [ ] **Step 1: Napisz failing testy (constants + 7 should_declare_war tests)**

W `tests/engine/test_ai_manager.gd` na końcu:

```gdscript

# === Plan 20: stałe + should_declare_war ===

func test_plan20_constants_exist() -> void:
	assert_almost_eq(AIManager.AI_WAR_TENSION_THRESHOLD, 70.0, 0.001)
	assert_almost_eq(AIManager.AI_WAR_DECLARE_CHANCE, 0.2, 0.001)
	assert_almost_eq(AIManager.AI_PEACE_ATTACKER_WEARINESS_GIVE_UP, 70.0, 0.001)
	assert_almost_eq(AIManager.AI_PEACE_DEFENDER_WEARINESS, 60.0, 0.001)

func test_should_declare_war_true_when_all_conditions_met() -> void:
	# Islam axes (A=70, B=65, C=30, D=75) — TYLKO nawrocenie_mieczem available (C<=40 ✓, A>=65 ✓).
	# Krucjata fails (C>25), dzihad fails (C>25), wojna_sprawiedliwa fails (D>50).
	# 1 CB wystarcza dla declare → happy path.
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("islam")
	attacker.prestige = 50
	var defender: Religion = gs.get_religion("eastern_christianity")
	var dm := DiplomacyManager.new()
	var rel := dm.get_or_create_relation(gs, "islam", "eastern_christianity")
	rel.military_tension = 80.0
	var ai := AIManagerScript.new()
	assert_true(ai.should_declare_war(attacker, defender, gs), "Islam→Eastern: tension 80 + prestige 50 + nawrocenie_mieczem → true")

func test_should_declare_war_false_when_self() -> void:
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("islam")
	var ai := AIManagerScript.new()
	assert_false(ai.should_declare_war(attacker, attacker, gs))

func test_should_declare_war_false_when_prestige_below_required() -> void:
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("islam")
	attacker.prestige = 5  # < DECLARE_WAR_PRESTIGE=10
	var defender: Religion = gs.get_religion("eastern_christianity")
	var dm := DiplomacyManager.new()
	dm.get_or_create_relation(gs, "islam", "eastern_christianity").military_tension = 80.0
	var ai := AIManagerScript.new()
	assert_false(ai.should_declare_war(attacker, defender, gs))

func test_should_declare_war_false_when_already_at_war() -> void:
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("islam")
	attacker.prestige = 50
	var defender: Religion = gs.get_religion("eastern_christianity")
	# Setup existing war.
	var existing := WarScript.new()
	existing.attacker_id = "islam"
	existing.defender_id = "eastern_christianity"
	existing.state = "BATTLING"
	gs.active_wars.append(existing)
	var dm := DiplomacyManager.new()
	dm.get_or_create_relation(gs, "islam", "eastern_christianity").military_tension = 80.0
	var ai := AIManagerScript.new()
	assert_false(ai.should_declare_war(attacker, defender, gs))

func test_should_declare_war_false_when_allied() -> void:
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("islam")
	attacker.prestige = 50
	var defender: Religion = gs.get_religion("eastern_christianity")
	var dm := DiplomacyManager.new()
	var rel := dm.get_or_create_relation(gs, "islam", "eastern_christianity")
	rel.military_tension = 80.0
	rel.alliance_active = true
	var ai := AIManagerScript.new()
	assert_false(ai.should_declare_war(attacker, defender, gs))

func test_should_declare_war_false_when_vassal_relation() -> void:
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("islam")
	attacker.prestige = 50
	var defender: Religion = gs.get_religion("eastern_christianity")
	defender.suzerain_id = "islam"  # defender is vassal of attacker
	var dm := DiplomacyManager.new()
	dm.get_or_create_relation(gs, "islam", "eastern_christianity").military_tension = 80.0
	var ai := AIManagerScript.new()
	assert_false(ai.should_declare_war(attacker, defender, gs))

func test_should_declare_war_false_when_same_coalition() -> void:
	# AC #8: coalition guard. Setup: Islam + Eastern w tej samej coalition.
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("islam")
	attacker.prestige = 50
	var defender: Religion = gs.get_religion("eastern_christianity")
	var dm := DiplomacyManager.new()
	dm.get_or_create_relation(gs, "islam", "eastern_christianity").military_tension = 80.0
	var coalition := Coalition.new()
	coalition.members = ["islam", "eastern_christianity"]
	gs.active_coalitions.append(coalition)
	var ai := AIManagerScript.new()
	assert_false(ai.should_declare_war(attacker, defender, gs))

func test_should_declare_war_false_when_tension_below_threshold() -> void:
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("islam")
	attacker.prestige = 50
	var defender: Religion = gs.get_religion("eastern_christianity")
	var dm := DiplomacyManager.new()
	dm.get_or_create_relation(gs, "islam", "eastern_christianity").military_tension = 69.0  # próg ostry 70
	var ai := AIManagerScript.new()
	assert_false(ai.should_declare_war(attacker, defender, gs))

func test_should_declare_war_false_when_no_cb_available() -> void:
	# Slavic ma profile A=20, B=25 — żaden z 4 standardowych CBs nie pasuje. Defender bez heresy + bez rewanz → no CB.
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("slavic_paganism")
	attacker.prestige = 50
	var defender: Religion = gs.get_religion("eastern_christianity")
	var dm := DiplomacyManager.new()
	dm.get_or_create_relation(gs, "slavic_paganism", "eastern_christianity").military_tension = 80.0
	var ai := AIManagerScript.new()
	assert_false(ai.should_declare_war(attacker, defender, gs))
```

- [ ] **Step 2: Run — expect FAILS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_ai_manager.gd -gexit
```

- [ ] **Step 3: Dodaj stałe w `scripts/engine/AIManager.gd`**

Po stałych Plan 18/19 (przed metodami):

```gdscript

# === Plan 20: war declarations + peace ===
const AI_WAR_TENSION_THRESHOLD := 70.0
const AI_WAR_DECLARE_CHANCE := 0.2
const AI_PEACE_ATTACKER_WEARINESS_GIVE_UP := 70.0
const AI_PEACE_DEFENDER_WEARINESS := 60.0
```

- [ ] **Step 4: Dodaj `should_declare_war` po `choose_attack_target` (Plan 19)**

```gdscript

func should_declare_war(attacker: Religion, defender: Religion, state: Node) -> bool:
	# Plan 20 §4.2: pełne guards przed declaration.
	if attacker == null or defender == null:
		return false
	if attacker.id == defender.id:
		return false
	if attacker.defeated_at_turn != -1 or defender.defeated_at_turn != -1:
		return false
	if attacker.prestige < WarManager.DECLARE_WAR_PRESTIGE:
		return false
	# Already at war?
	for war: War in state.active_wars:
		if war.state == "ENDED":
			continue
		if (war.attacker_id == attacker.id and war.defender_id == defender.id) \
				or (war.attacker_id == defender.id and war.defender_id == attacker.id):
			return false
	# Alliance check.
	var dm := DiplomacyManager.new()
	var rel := dm.get_or_create_relation(state, attacker.id, defender.id)
	if rel.alliance_active:
		return false
	# Suzerain/vassal chain.
	if attacker.suzerain_id == defender.id or defender.suzerain_id == attacker.id:
		return false
	# Same coalition.
	for coalition: Coalition in state.active_coalitions:
		if attacker.id in coalition.members and defender.id in coalition.members:
			return false
	# Tension threshold (próg ostry >=).
	if rel.military_tension < AI_WAR_TENSION_THRESHOLD:
		return false
	# CB available.
	var wm := WarManager.new()
	if wm.available_casus_belli(attacker, defender, state).is_empty():
		return false
	return true
```

- [ ] **Step 5: Run — expect PASS**

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/AIManager.gd tests/engine/test_ai_manager.gd
git commit -m "feat(ai): Plan 20 stałe + should_declare_war (pełne guards)"
```

---

## Task 2: `choose_war_target` (RNG gate + highest tension)

**Cel:** Target selection per declaration.

**Files:**
- Modify: `scripts/engine/AIManager.gd`
- Modify: `tests/engine/test_ai_manager.gd`

- [ ] **Step 1: Napisz 2 failing testy**

```gdscript

# === Plan 20: choose_war_target ===

func test_choose_war_target_returns_empty_when_rng_above_threshold() -> void:
	# Seeded RNG z randf() pierwsze wywołanie > 0.2 → {} regardless of eligible targets.
	# Use seed gdzie randf() pierwsze = wysoka wartość (np. seed 99, sprawdź eksperymentalnie).
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("islam")
	attacker.prestige = 50
	# Setup eligible target (tension 80) — żeby udowodnić że RNG gate blokuje.
	var dm := DiplomacyManager.new()
	dm.get_or_create_relation(gs, "islam", "eastern_christianity").military_tension = 80.0
	# Inject RNG ze stałym seed dający randf() > 0.2.
	var high_rng := RandomNumberGenerator.new()
	high_rng.seed = 99  # adjust if needed empirically
	var ai := AIManagerScript.new(high_rng)
	# Spróbuj kilku seedów — celem jest udowodnić deterministic skip.
	# Pragmatyczny test: zamiast szukać seed, override randf() przez injection custom rng class.
	# MVP: użyj seed 99 i sprawdź jeśli się nie udaje, dostosuj.
	var target := ai.choose_war_target(gs, attacker)
	# Jeśli seed daje randf() < 0.2, test failuje — wybierz inny seed.
	# Alternative: zostaw asercję jako "ZAWARTOŚĆ" zamiast "EMPTY", patrz Step note.
	if high_rng.randf() < 0.2:
		# Skip test if seed nie pasuje (use assert_eq with skip marker).
		assert_true(true, "Seed nie spełnia >0.2, test pomijany")
	else:
		assert_eq(target.size(), 0, "RNG > 0.2 → choose_war_target returns {}")

# UWAGA: powyższy test ma wbudowaną kontrole seedu. Lepsza alternatywa to:
# stworzyć custom RNG mock który returns deterministic value. Jeśli mock niepraktyczny,
# znajdź seed empirycznie podczas testowania.

func test_choose_war_target_picks_highest_tension() -> void:
	# Setup: Islam z 2 eligible targets — Eastern (tension 80) i Western (tension 90).
	# Seeded RNG z randf() < 0.2 (pass gate).
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("islam")
	attacker.prestige = 50
	var dm := DiplomacyManager.new()
	dm.get_or_create_relation(gs, "islam", "eastern_christianity").military_tension = 80.0
	dm.get_or_create_relation(gs, "islam", "western_christianity").military_tension = 90.0
	# Pass gate: seed gdzie randf() pierwsze wywołanie < 0.2.
	var low_rng := RandomNumberGenerator.new()
	low_rng.seed = 1  # adjust if needed
	var ai := AIManagerScript.new(low_rng)
	# Pre-check seed (sanity).
	# Note: AIManager._init może wywołać randf() w randomize() — sprawdź czy seed jest "nietknięte" przy injection.
	# Z Plan 18: if injected_rng != null, nie wywołuje randomize() — seed preserved.
	var target := ai.choose_war_target(gs, attacker)
	if target.is_empty():
		# Jeśli seed dał randf() > 0.2, użyj innego seedu.
		assert_true(true, "Seed dał gate skip, test pomijany — wybierz inny seed empirycznie")
	else:
		assert_eq(target["defender_id"], "western_christianity", "Higher tension wins (90 vs 80)")
		assert_true(target["cb"] in ["krucjata", "dzihad", "wojna_sprawiedliwa", "nawrocenie_mieczem"],
			"CB z available list dla Islam")
```

**Uwaga implementer — RNG seed discovery (Reviewer concern):**

Empirical seed discovery jest fragile (silent test skipping ryzyko). **Preferowana procedura**:

1. **Pre-compute seedy** PRZED napisaniem testów:
```bash
godot --headless --path . --eval "var rng = RandomNumberGenerator.new(); for s in range(100): rng.seed = s; print(s, ': ', rng.randf())"
```
Znajdź seed gdzie `rng.randf() < 0.2` (low_rng) i osobny gdzie `rng.randf() >= 0.2` (high_rng). Hardcode te konkretne seedy w testach z assertion (NO silent skip).

2. **Alternative — MockRNG class** (cleaner long-term):
Stwórz `tests/engine/MockRNG.gd extends RandomNumberGenerator` z overridable `randf() -> float` returning deterministyczne queued values. Cały test_ai_manager.gd byłby deterministic.

3. **Minimum dla MVP**: hardcoded seed po empirycznej weryfikacji. **NIE używaj** `assert_true(true, "skipped")` fallback — to silent failure mode. Test musi albo PASS deterministycznie albo FAIL z konkretnym error.

- [ ] **Step 2: Run — expect FAILS (parse error: choose_war_target brak)**

- [ ] **Step 3: Implementuj w AIManager.gd po `should_declare_war`**

```gdscript

func choose_war_target(state: Node, attacker: Religion) -> Dictionary:
	# Plan 20 §4.3: RNG gate first (anti-spam), then highest-tension eligible target.
	if rng.randf() >= AI_WAR_DECLARE_CHANCE:
		return {}
	var best_target_id: String = ""
	var best_tension: float = -1.0
	var dm := DiplomacyManager.new()
	for defender: Religion in state.all_religions():
		if not should_declare_war(attacker, defender, state):
			continue
		var rel := dm.get_or_create_relation(state, attacker.id, defender.id)
		if rel.military_tension > best_tension:
			best_tension = rel.military_tension
			best_target_id = defender.id
	if best_target_id == "":
		return {}
	var defender_rel: Religion = state.get_religion(best_target_id)
	var wm := WarManager.new()
	var cbs := wm.available_casus_belli(attacker, defender_rel, state)
	if cbs.is_empty():
		return {}
	return {"defender_id": best_target_id, "cb": cbs[0]}
```

- [ ] **Step 4: Run — expect PASS**

(Jeśli test pominięty przez seed mismatch — dostosuj seed empirycznie.)

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/AIManager.gd tests/engine/test_ai_manager.gd
git commit -m "feat(ai): Plan 20 choose_war_target — RNG gate + highest tension"
```

---

## Task 3: Peace methods (`should_offer_peace` + `compose_peace_terms`)

**Cel:** Decision + terms generation. Razem bo tightly coupled.

**Files:**
- Modify: `scripts/engine/AIManager.gd`
- Modify: `tests/engine/test_ai_manager.gd`

- [ ] **Step 1: Napisz 5 failing testy**

```gdscript

# === Plan 20: should_offer_peace ===

func test_should_offer_peace_attacker_contested_provinces() -> void:
	# Attacker z contested > 0 → true (claim winnings).
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("islam")
	attacker.war_weariness = 10.0  # niska weariness — claim mimo to
	var war := _make_war("islam", "eastern_christianity", "BATTLING")
	war.contested_provinces = ["lewant"]
	var ai := AIManagerScript.new()
	assert_true(ai.should_offer_peace(war, "islam", gs), "Attacker contested > 0 → peace (claim)")

func test_should_offer_peace_attacker_give_up_high_weariness() -> void:
	# Attacker bez contested, weariness > 70 → true (give up).
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("islam")
	attacker.war_weariness = 75.0  # > 70
	var war := _make_war("islam", "eastern_christianity", "BATTLING")
	war.contested_provinces = []
	var ai := AIManagerScript.new()
	assert_true(ai.should_offer_peace(war, "islam", gs), "Attacker weariness > 70 → give up peace")

func test_should_offer_peace_defender_high_weariness() -> void:
	# Defender, weariness > 60 → true.
	var gs := _make_state()
	var defender: Religion = gs.get_religion("eastern_christianity")
	defender.war_weariness = 65.0
	var war := _make_war("islam", "eastern_christianity", "BATTLING")
	var ai := AIManagerScript.new()
	assert_true(ai.should_offer_peace(war, "eastern_christianity", gs), "Defender weariness > 60 → peace")

func test_should_offer_peace_false_when_low_weariness_no_contested() -> void:
	# Attacker, no contested, weariness 30 → false.
	var gs := _make_state()
	var attacker: Religion = gs.get_religion("islam")
	attacker.war_weariness = 30.0
	var war := _make_war("islam", "eastern_christianity", "BATTLING")
	war.contested_provinces = []
	var ai := AIManagerScript.new()
	assert_false(ai.should_offer_peace(war, "islam", gs), "Attacker no contested + low weariness → no peace")

# === Plan 20: compose_peace_terms ===

func test_compose_peace_terms_attacker_annexation_when_contested() -> void:
	var gs := _make_state()
	var war := _make_war("islam", "eastern_christianity", "BATTLING")
	war.contested_provinces = ["lewant", "jerozolima"]
	var ai := AIManagerScript.new()
	var terms := ai.compose_peace_terms(war, "islam", gs)
	assert_true(terms.has("annexation"))
	var ann: Dictionary = terms["annexation"]
	assert_true("lewant" in ann.get("provinces", []))
	assert_true("jerozolima" in ann.get("provinces", []))
	assert_eq(ann.get("policy", ""), "nawracaj")

func test_compose_peace_terms_empty_when_no_contested() -> void:
	# Attacker bez contested (give-up) OR defender → empty terms.
	var gs := _make_state()
	var war := _make_war("islam", "eastern_christianity", "BATTLING")
	war.contested_provinces = []
	var ai := AIManagerScript.new()
	assert_eq(ai.compose_peace_terms(war, "islam", gs), {}, "Attacker no contested → empty")
	assert_eq(ai.compose_peace_terms(war, "eastern_christianity", gs), {}, "Defender → empty")
```

- [ ] **Step 2: Run — expect FAILS**

- [ ] **Step 3: Implementuj obie metody**

W AIManager.gd po `choose_war_target`:

```gdscript

func should_offer_peace(war: War, npc_id: String, state: Node) -> bool:
	# Plan 20 §4.4: per-role peace decision.
	if war.state == "ENDED":
		return false
	var npc: Religion = state.get_religion(npc_id)
	if npc == null:
		return false
	if war.attacker_id == npc_id:
		if war.contested_provinces.size() > 0:
			return true
		if npc.war_weariness > AI_PEACE_ATTACKER_WEARINESS_GIVE_UP:
			return true
		return false
	elif war.defender_id == npc_id:
		return npc.war_weariness > AI_PEACE_DEFENDER_WEARINESS
	return false

func compose_peace_terms(war: War, npc_id: String, state: Node) -> Dictionary:
	# Plan 20 §4.5: terms zależą od role + contested status.
	if war.attacker_id == npc_id and war.contested_provinces.size() > 0:
		return {"annexation": {"provinces": war.contested_provinces.duplicate(), "policy": "nawracaj"}}
	return {}
```

- [ ] **Step 4: Run — expect PASS**

- [ ] **Step 5: Commit**

```bash
git add scripts/engine/AIManager.gd tests/engine/test_ai_manager.gd
git commit -m "feat(ai): Plan 20 should_offer_peace + compose_peace_terms"
```

---

## Task 4: `_npc_offer_peace` TurnManager integration

**Cel:** Pipeline integration dla peace.

**Files:**
- Modify: `scripts/engine/TurnManager.gd`
- Modify: `tests/engine/test_turn_manager.gd`

- [ ] **Step 1: Napisz 2 failing integration testy**

```gdscript

# === Plan 20: _npc_offer_peace integration ===

func test_npc_offers_peace_when_attacker_has_contested() -> void:
	var tm := TurnManager.new()
	# Disable AI declarations (Plan 20) by seeded high_rng — randf() > 0.2 skip declare gate.
	# Hardcode seed po pre-computation (Task 2 procedura).
	var high_rng := RandomNumberGenerator.new()
	high_rng.seed = 99  # adjust po pre-computation if needed
	tm.set_ai_override(AIManager.new(high_rng))
	var gs := _make_state()  # player = islam
	# NPC slavic atakuje Eastern. Setup contested + low weariness — claim immediately.
	var war := WarScript.new()
	war.attacker_id = "slavic_paganism"
	war.defender_id = "eastern_christianity"
	war.casus_belli = "wojna_sprawiedliwa"
	war.state = "BATTLING"
	war.contested_provinces = ["tracja"]
	gs.active_wars.append(war)
	# Disable scholar noise (Plan 18).
	for r: Religion in gs.all_religions():
		if r.id != gs.player_religion_id and r.id != "slavic_paganism":
			r.prestige = 0
	tm.process_turn(gs)
	assert_eq(war.state, "ENDED", "NPC attacker peace → war ended")
	# Tracja powinna być zaanektowana przez Slavic.
	var tracja: Province = gs.province_graph.get_province("tracja")
	assert_eq(tracja.owner, "slavic_paganism", "Tracja annexed by Slavic")

func test_npc_offers_peace_when_defender_weariness_high() -> void:
	var tm := TurnManager.new()
	# Disable AI declarations via high_rng (skip declare gate).
	var high_rng := RandomNumberGenerator.new()
	high_rng.seed = 99  # adjust po pre-computation if needed
	tm.set_ai_override(AIManager.new(high_rng))
	var gs := _make_state()  # player = islam (attacker)
	# Player attacker → Plan 20 attacker peace skipped. Defender NPC slavic, weariness > 60 → peace.
	var war := WarScript.new()
	war.attacker_id = "islam"
	war.defender_id = "slavic_paganism"
	war.casus_belli = "wojna_sprawiedliwa"
	war.state = "BATTLING"
	gs.active_wars.append(war)
	var slavic: Religion = gs.get_religion("slavic_paganism")
	slavic.war_weariness = 65.0
	# Disable other NPC noise (scholar dispatch).
	for r: Religion in gs.all_religions():
		if r.id != gs.player_religion_id and r.id != "slavic_paganism":
			r.prestige = 0
	tm.process_turn(gs)
	assert_eq(war.state, "ENDED", "NPC defender peace gdy weariness > 60")
```

- [ ] **Step 2: Run — expect FAILS (parse error)**

- [ ] **Step 3: Dodaj `_npc_offer_peace` w TurnManager**

Po `_npc_attack_wars` (Plan 19) w `scripts/engine/TurnManager.gd`:

```gdscript

func _npc_offer_peace(state: Node) -> void:
	# Plan 20 §5.1: NPC kontekstowo kończy wojny.
	# Iteracja: attacker first, then defender (deterministic).
	var ai := _get_ai()
	var wm := WarManager.new()
	for war: War in state.active_wars.duplicate():
		if war.state == "ENDED":
			continue
		# Attacker NPC
		if war.attacker_id != state.player_religion_id:
			if ai.should_offer_peace(war, war.attacker_id, state):
				var terms := ai.compose_peace_terms(war, war.attacker_id, state)
				wm.offer_peace(war, terms, state)
				continue
		if war.state == "ENDED":
			continue
		# Defender NPC
		if war.defender_id != state.player_religion_id:
			if ai.should_offer_peace(war, war.defender_id, state):
				var terms := ai.compose_peace_terms(war, war.defender_id, state)
				wm.offer_peace(war, terms, state)
```

- [ ] **Step 4: Wstaw `_npc_offer_peace(state)` w pipeline**

Znajdź:
```gdscript
	_process_active_wars(state)
	_npc_attack_wars(state)
	_process_missionaries(state)
```

Zmień na:
```gdscript
	_process_active_wars(state)
	_npc_attack_wars(state)
	_npc_offer_peace(state)
	_process_missionaries(state)
```

- [ ] **Step 5: Run — expect PASS**

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/TurnManager.gd tests/engine/test_turn_manager.gd
git commit -m "feat(engine): Plan 20 _npc_offer_peace pipeline integration"
```

---

## Task 5: `_npc_declare_wars` TurnManager integration + isolation

**Cel:** Pipeline integration dla declarations + naprawa pre-existing tests (Task 0 enumerate).

**Files:**
- Modify: `scripts/engine/TurnManager.gd`
- Modify: `tests/engine/test_turn_manager.gd`
- Optional: `tests/engine/test_diplomacy_manager.gd`, `tests/engine/test_war_manager.gd`

- [ ] **Step 1: Napisz failing integration test**

```gdscript

# === Plan 20: _npc_declare_wars integration ===

func test_npc_declares_war_when_tension_high() -> void:
	var tm := TurnManager.new()
	var gs := _make_state()  # player = islam
	# Setup eligible target dla Slavic — wymyślony niski profile, ale Slavic NIE ma CB.
	# Użyjmy Islam jako attacker (axes 70/65/30/75 — wszystkie 4 CBs available).
	# Ale Islam jest player → skip w pipeline. Użyjmy western_christianity (axes 65/80/35/55).
	# Western CBs: wojna_sprawiedliwa (B>=60 ✓, D<=50 ✗ since D=55). nawrocenie_mieczem (C<=40 ✓, A>=65 ✓). OK!
	var attacker: Religion = gs.get_religion("western_christianity")
	attacker.prestige = 50
	var defender: Religion = gs.get_religion("eastern_christianity")
	var dm := DiplomacyManager.new()
	dm.get_or_create_relation(gs, "western_christianity", "eastern_christianity").military_tension = 90.0
	# Seed RNG dla deterministic randf() < 0.2 (chance pass).
	var low_rng := RandomNumberGenerator.new()
	low_rng.seed = 1  # adjust empirically
	tm.set_ai_override(AIManager.new(low_rng))
	# Disable other NPC noise (prestige=0 dla wszystkich oprócz western i player).
	for r: Religion in gs.all_religions():
		if r.id != gs.player_religion_id and r.id != "western_christianity":
			r.prestige = 0
	var initial_wars: int = gs.active_wars.size()
	tm.process_turn(gs)
	# Western powinien zadeklarować wojnę.
	# Note: jeśli seed nie pasuje, dopasuj.
	if gs.active_wars.size() == initial_wars:
		assert_true(false, "Seed nie wywołał deklaracji — dopasuj seed")
	else:
		var new_war: War = gs.active_wars[initial_wars]
		assert_eq(new_war.attacker_id, "western_christianity")
		assert_eq(new_war.defender_id, "eastern_christianity")
```

**Uwaga implementer:** seed wymaga dostosowania empirycznego. Alternatywnie użyj mocka RNG, lub setup tension tak wysoko że dispatch zawsze trafia.

- [ ] **Step 2: Run — expect FAIL (parse error `_npc_declare_wars` brak)**

- [ ] **Step 3: Dodaj `_npc_declare_wars` w TurnManager**

Po `_npc_offer_peace`:

```gdscript

func _npc_declare_wars(state: Node) -> void:
	# Plan 20 §5.2: NPC declarations per turn.
	var ai := _get_ai()
	var wm := WarManager.new()
	for religion: Religion in state.all_religions():
		if religion.id == state.player_religion_id:
			continue
		if religion.defeated_at_turn != -1:
			continue
		var target := ai.choose_war_target(state, religion)
		if target.is_empty():
			continue
		wm.declare_war(religion.id, target["defender_id"], target["cb"], state)
```

- [ ] **Step 4: Wstaw `_npc_declare_wars(state)` w pipeline po peace**

```gdscript
	_process_active_wars(state)
	_npc_attack_wars(state)
	_npc_offer_peace(state)
	_npc_declare_wars(state)
	_process_missionaries(state)
```

- [ ] **Step 5: Run nowego testu — expect PASS**

- [ ] **Step 6: WARUNKOWA naprawa pre-existing tests**

Uruchom CAŁĄ suite:

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | grep -E "Failed|Failing"
```

Jeśli failures w pre-existing tests używających `process_turn`:
- **Najczęstsze:** NPC z high tension/prestige zaczyna nowe wojny → tests asercjujące `active_wars.size()` failują.
- **Najczęstsze:** NPC defender z weariness > 60 (test setup) → war auto-peace → tests asercjujące war.state == BATTLING failują.

**Mitigation per failing test:**
1. **Disabled RNG override**: `tm.set_ai_override(AIManager.new(_disabled_rng()))` gdzie `_disabled_rng()` returns seeded RNG z randf() pierwsze N > 0.2 (skip declarations).
2. **Pin tension < 70** dla all NPC pairs:
```gdscript
for rel: RelationState in gs.relations:
    rel.military_tension = minf(rel.military_tension, 50.0)
```
3. **Lower weariness threshold** sentinel: ustaw weariness < 60 dla NPC w teście.

- [ ] **Step 7: Run całej suite — expect PASS**

Expected: ~783 testów pass.

- [ ] **Step 8: Commit**

```bash
git add scripts/engine/TurnManager.gd tests/engine/test_turn_manager.gd
# Dodaj inne pliki jeśli izolacja:
# git add tests/engine/test_diplomacy_manager.gd tests/engine/test_war_manager.gd
git commit -m "feat(engine): Plan 20 _npc_declare_wars + test isolation"
```

---

## Task 6: CLAUDE.md cross-reference

**Cel:** 1-liner Plan 20 po Plan 19.

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Sprawdź stan**

```bash
grep -n "Plan 19\|Plan 20" CLAUDE.md
```

- [ ] **Step 2: Dopisz 1-liner po Plan 19**

```
Plan 20 (`docs/superpowers/specs/20-war-ai-declare-peace-design.md`) — NPC proaktywnie deklarują wojny (tension >= 70 + pełne guards) i oferują pokój kontekstowo (attacker: contested OR weariness > 70; defender: weariness > 60). NPC resolve_defeat + smart CB + forced_council — Plan 21+.
```

- [ ] **Step 3: Sanity grep**

```bash
grep -F "20-war-ai-declare-peace-design.md" CLAUDE.md
```

Expected: 1 linia.

- [ ] **Step 4: Cała suite (sanity)**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: ~783 testów pass.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: cross-reference do spec 20 (War AI declare + peace)"
```

---

## Po wszystkich taskach

- [ ] **Final review**: dispatch `superpowers:code-reviewer` na pełen branch (~8 commitów Plan 20 + spec/plan). Reviewer sprawdza:
  - Spec compliance (14 acceptance criteria z §8).
  - Code quality (tab indent, RNG seeding, AIManager rozszerzenie addytywne, pełne guards correct order).
  - Test coverage (~13 nowych + warunkowe izolacje).
  - Brak regresji (~783 pass).
  - Architektura — extension point pattern dla future war AI (Plan 21+).

- [ ] **Po approval**: push do origin/master.

---

## Acceptance Criteria (z spec §8)

Plan 20 jest gotowy do merge gdy:

1. ✅ 4 stałe Plan 20 w AIManager.
2. ✅ `should_declare_war` z pełnymi guards (8 checks).
3. ✅ `choose_war_target` z RNG gate + highest tension.
4. ✅ `should_offer_peace` z per-role logic.
5. ✅ `compose_peace_terms` z annexation/empty.
6. ✅ `TurnManager._npc_offer_peace` w pipeline po `_npc_attack_wars`.
7. ✅ `TurnManager._npc_declare_wars` w pipeline po peace.
8. ✅ NPC declarations: skip player, defeated, ally, vassal/suzerain, coalition, existing war.
9. ✅ NPC peace: per-role correct.
10. ✅ Pre-existing testy Plan 12-19 pass — z warunkową izolacją.
11. ✅ ~13 nowych testów pass.
12. ✅ Cała suite (~783) pass.
13. ✅ CLAUDE.md wzmiankuje Plan 20.
14. ✅ Brak zmian w WarManager.gd, War.gd, RelationState.gd, Coalition.gd, fixture, UI.
