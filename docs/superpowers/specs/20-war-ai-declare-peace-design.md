# Plan 20 — War AI: declare_war + offer_peace

> **Spec dla:** Plan 20 — drugi krok war AI. NPC proaktywnie deklarują wojny (gdy `military_tension >= 70`) i oferują pokój kontekstowo (attacker claim winnings / give up; defender weariness >= 60).
>
> **W zakresie:**
> 1. Rozszerzenie `AIManager` o 4 metody:
>    - `should_declare_war(attacker, defender, state) -> bool` — pełne guards (tension + prestige + CB + nie ally/vassal/coalition/existing war).
>    - `choose_war_target(state, attacker) -> Dictionary` — wybiera best target (highest tension) + CB.
>    - `should_offer_peace(war, npc_id, state) -> bool` — per-role gating.
>    - `compose_peace_terms(war, npc_id, state) -> Dictionary` — terms based on role.
> 2. 4 nowe stałe Plan 20.
> 3. 2 nowe etapy w `TurnManager.process_turn`:
>    - `_npc_offer_peace(state)` — kończenie istniejących wojen.
>    - `_npc_declare_wars(state)` — deklarowanie nowych wojen.
> 4. Test isolation (warunkowa, Task 0 enumerate).
>
> **Wyłączone z zakresu:**
> - **NPC resolve_defeat** — wybór DEFEAT_OPTIONS po przegranej. Plan 21+.
> - **Smart CB selection** — Plan 20 picks first available CB (deterministic). Future: pick strongest CB_BONUS.
> - **Smart peace terms** — Plan 20 używa wyłącznie annexation lub empty. Forced_council, clergy_extermination — Plan 21+.
> - **War declaration AI dla coalition members** (offensive war by coalition) — Plan 22+.
> - **Defender counterattack** — wymaga rozszerzenia WarManager API. Plan 21+.
> - **Holy war (krucjata/dzihad) specific targeting** — Plan 22+ (e.g. target religia z innym holy_site).
> - **AI tuning** — thresholds (70 tension, 60/70 weariness, 20% chance) do playtestingu.

---

## Sekcja 1: Kontekst i motywacja

Stan po Plan 19:
- `AIManager` (Plan 18) z 5 metodami: 3 doctrine (Plan 18) + 2 war attack (Plan 19).
- `TurnManager._npc_dispatch_scholars` (Plan 18) + `_npc_attack_wars` (Plan 19) w pipeline.
- NPC religie:
  - ✅ Dispatchują scholary, auto-resolve ideas (Plan 18 doctrine).
  - ✅ Atakują prowincje gdy `war.state == "BATTLING"` (Plan 19 war attack).
  - ❌ **Nie deklarują wojen** — wojny są inicjowane TYLKO przez gracza.
  - ❌ **Nie oferują pokoju** — wojny kończy tylko gracz przez UI (lub `force_loss` na `weariness >= 90`).

Plan 20 zamyka tę lukę:
- NPC inicjują wojny gdy `military_tension >= 70` z eligible target.
- NPC kończą wojny kontekstowo:
  - **Attacker**: claim winnings (contested_provinces > 0) lub give up (weariness > 70).
  - **Defender**: peace gdy weariness > 60.

Po Plan 20:
- War flow staje się dwukierunkowy — NPC może zaatakować gracza (poprzez declare_war).
- Wojny kończą się "naturalnie" przez NPC peace offers zamiast tylko force_loss.
- Gracz musi rozważać sojusze, dyplomację, nie tylko military strength.

**MVP rationale:** Plan 19 dodał reactive war AI (NPC walczy w wojnie). Plan 20 dodaje proactive war AI (NPC zaczyna i kończy wojny). To naturalne rozszerzenie tego samego komponentu.

---

## Sekcja 2: Cele projektowe

1. **Rozszerzyć AIManager o war proactive API** — 4 metody dla declare + peace decision making.
2. **Pełne guards na declarations** — NPC nie deklaruje wojny z sojusznikiem/vassalem/suzerain/coalition member.
3. **Kontekstowe peace heuristics** — attacker różni się od defendera w decision logic.
4. **Pipeline integration** — attack → peace → declare order (kończenie spraw przed otwieraniem nowych).
5. **Test isolation strategy** — Task 0 mandatory enumerate; mitigation per-test (tension/prestige pinning lub disabled-RNG seed).
6. **Zero zmian w `WarManager.gd` API** — używamy istniejących `declare_war`, `offer_peace`, `available_casus_belli`.

---

## Sekcja 3: Architektura — co zmienia Plan 20

### Modyfikacje istniejące

**`scripts/engine/AIManager.gd`:**
- 4 nowe stałe (§4.1).
- 4 nowe metody public API (§4.2-§4.5).

**`scripts/engine/TurnManager.gd`:**
- 2 nowe etapy w pipeline (§5).
- Pipeline placement: po `_npc_attack_wars` (Plan 19), przed `_process_missionaries`.

### Brak zmian

- `WarManager.gd`, `War.gd`, `Religion.gd`, `RelationState.gd`, `Coalition.gd`, `GameState.gd` — bez zmian.
- `DiplomacyManager.gd` — bez zmian (tylko queries: `get_or_create_relation`).
- Inne managery (DoctrineManager, SchismManager, VictoryManager) — bez zmian.
- UI — bez zmian.
- Fixture (`data/*.json`) — bez zmian.

---

## Sekcja 4: AIManager — nowe stałe i metody

### 4.1 Stałe Plan 20

```gdscript
const AI_WAR_TENSION_THRESHOLD := 70.0          # mil_tension >= 70 → eligible target dla declare
const AI_WAR_DECLARE_CHANCE := 0.2              # 20% per turn chance to declare when eligible
const AI_PEACE_ATTACKER_WEARINESS_GIVE_UP := 70.0  # attacker peace jeśli weariness > 70 (give up empty terms)
const AI_PEACE_DEFENDER_WEARINESS := 60.0       # defender peace jeśli weariness > 60
```

### 4.2 `should_declare_war` (pełne guards)

```gdscript
func should_declare_war(attacker: Religion, defender: Religion, state: Node) -> bool:
	# Plan 20 §4.2: full guards before declaring war.
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
	# Tension threshold.
	if rel.military_tension < AI_WAR_TENSION_THRESHOLD:
		return false
	# CB available.
	var wm := WarManager.new()
	if wm.available_casus_belli(attacker, defender, state).is_empty():
		return false
	return true
```

**Guards order (cheapest first):**
1. Null guards, self-target, defeated states.
2. Prestige (field access, O(1)).
3. Already in war (loops state.active_wars).
4. Alliance (single relation lookup).
5. Suzerain/vassal (2 field comparisons).
6. Coalition (loops state.active_coalitions).
7. Tension threshold.
8. CB available (loops CB_AXIS_REQUIREMENTS + axis match).

### 4.3 `choose_war_target` (RNG gate + highest tension)

```gdscript
func choose_war_target(state: Node, attacker: Religion) -> Dictionary:
	# Plan 20 §4.3: RNG gate first (avoid declaration spam), then pick highest-tension eligible target.
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
	if cbs.is_empty():  # defensive — should be filtered by should_declare_war
		return {}
	return {"defender_id": best_target_id, "cb": cbs[0]}
```

**Note:** RNG gate FIRST oszczędza CPU — jeśli random > 0.2, nie iterujemy religii. Determinism w testach: seeded RNG.

**Tie-breaking dla equal tension:** pierwsza znaleziona w iteration order (deterministic dla `all_religions()`).

### 4.4 `should_offer_peace` (kontekstowy per role)

```gdscript
func should_offer_peace(war: War, npc_id: String, state: Node) -> bool:
	# Plan 20 §4.4: per-role peace decision.
	if war.state == "ENDED":
		return false
	var npc: Religion = state.get_religion(npc_id)
	if npc == null:
		return false
	if war.attacker_id == npc_id:
		# Attacker: claim winnings OR give up
		if war.contested_provinces.size() > 0:
			return true  # claim now (even if low weariness)
		if npc.war_weariness > AI_PEACE_ATTACKER_WEARINESS_GIVE_UP:
			return true  # exhausted, give up
		return false
	elif war.defender_id == npc_id:
		# Defender: peace gdy weariness > 60
		return npc.war_weariness > AI_PEACE_DEFENDER_WEARINESS
	return false  # NPC nie jest stroną w wojnie
```

**Rationale per role:**
- **Attacker** ma 2 ścieżki:
  - `contested_provinces > 0`: NPC wygrywa, claim natychmiast (lock-in gains).
  - `weariness > 70`: NPC trwa za długo bez sukcesu, give up.
  - Edge case: contested > 0 AND weariness > 70 → claim (więcej zysku niż empty peace).
- **Defender** ma jedną ścieżkę:
  - `weariness > 60`: NPC odmawia kontynuacji. Empty terms = DRAW outcome.

**Asymmetria progu** (attacker 70 vs defender 60):
- Defender bardziej skłonny do peace (60) — chce zakończyć obronę.
- Attacker bardziej upiera się (70) — zainwestował w deklarację.

**Boundary semantyka (próg ostry `>`):** Operatory `>` w obu warunkach są strict. Weariness = 60.0 (exact) → defender NIE oferuje peace. Weariness = 70.0 (exact) → attacker give-up NIE jest triggerowane. Testy boundary cases używają wartości +1 (61, 71) lub -1 (59, 69) dla deterministyczności.

### 4.5 `compose_peace_terms`

```gdscript
func compose_peace_terms(war: War, npc_id: String, state: Node) -> Dictionary:
	# Plan 20 §4.5: terms zależą od role + contested status.
	if war.attacker_id == npc_id and war.contested_provinces.size() > 0:
		return {"annexation": {"provinces": war.contested_provinces.duplicate(), "policy": "nawracaj"}}
	return {}  # Empty terms: defender peace OR attacker give-up
```

**Why `policy: "nawracaj"`:**
- 3 dostępne policies (per WarManager.gd): `"wypedz"` (extermination), `"nawracaj"` (preserve population), `"zasymiluj"` (preserve + axis C shift).
- MVP wybiera `"nawracaj"` — narratywnie najlżejsze, minimal side effects.
- Future plan może dodawać policy heuristics (e.g. zasymiluj jeśli attacker axis C low).

**Why `contested_provinces.duplicate()`:**
- `_apply_annexation` iteruje `province_ids` i może mutować state. Defensive copy.

---

## Sekcja 5: TurnManager integration

### 5.1 Dwa nowe etapy

```gdscript
func _npc_offer_peace(state: Node) -> void:
	# Plan 20 §5.1: NPC kontekstowo kończy wojny.
	# Iteracja kolejnościowa: attacker first, then defender (deterministic).
	# Po peace, war.state == "ENDED" — drugi check (defender) skip.
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
		# Defender NPC (only if war not already ended)
		if war.state == "ENDED":
			continue
		if war.defender_id != state.player_religion_id:
			if ai.should_offer_peace(war, war.defender_id, state):
				var terms := ai.compose_peace_terms(war, war.defender_id, state)
				wm.offer_peace(war, terms, state)

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

### 5.2 Pipeline placement

```gdscript
func process_turn(state: Node) -> void:
	# ... existing early stages ...
	_process_active_wars(state)
	_npc_attack_wars(state)         # Plan 19
	_npc_offer_peace(state)         # NEW Plan 20 — close existing wars
	_npc_declare_wars(state)        # NEW Plan 20 — open new wars
	_process_missionaries(state)
	# ... existing late stages ...
```

**Order rationale:**
- `_npc_attack_wars` (Plan 19) before peace: NPC ma ostatnią szansę na contested_provinces przed offer_peace.
- `_npc_offer_peace` before declare: kończ stare → otwieraj nowe (natural AI flow).
- Both after `_process_active_wars` (state transitions + weariness already applied).

### 5.3 Why `active_wars.duplicate()`?

`offer_peace` MOŻE mutować `state.active_wars` (linia `state.active_wars.erase(war)`). Iteracja po raw array byłaby unsafe (modify during iteration). Duplicate jest **wymagane** (nie defensive jak w Plan 19), nie tylko ostrożnościowe.

**Defeated mid-turn:** Plan 19's `_npc_attack_wars` (run wcześniej w tej samej turze) może triggerować `force_loss` przez weariness lub eliminację. To usuwa wojnę z `active_wars` (WarManager.gd:233) PRZED `_npc_offer_peace` start iteracji. Defensive guard `if war.state == "ENDED": continue` chroni przed edge case gdy wojna ENDED ale jeszcze nie erased.

### 5.4 Same-turn declare → attack flow

Gdy `_npc_declare_wars` doda nową wojnę w turnie T:
- Wojna startuje w MOBILIZING (state.turns_in_state = 0).
- W tym samym turnie pipeline kontynuuje: `_process_missionaries`, etc. — nie wraca do attacks.
- Następny turn: `_process_active_wars` += turns_in_state → MOBILIZING (turns 1, < 2).
- Turn T+2: BATTLING.
- Turn T+2+: `_npc_attack_wars` may attack.

Tj. 2 tury opóźnienia między declaration i pierwszy atak — spójne z player declarations.

---

## Sekcja 6: Test plan

### Engine — AIManager (~10 testów)

**`tests/engine/test_ai_manager.gd`** (rozszerzenie):

`should_declare_war` (~6 testów):
- `test_should_declare_war_true_when_all_conditions_met` — happy path (tension 80, prestige 50, CB available, no allies/wars).
- `test_should_declare_war_false_when_self` — defender == attacker → false.
- `test_should_declare_war_false_when_prestige_below_required` — prestige=5 < 10 → false.
- `test_should_declare_war_false_when_already_at_war` — existing war attacker→defender → false.
- `test_should_declare_war_false_when_allied` — rel.alliance_active=true → false.
- `test_should_declare_war_false_when_vassal_relation` — defender.suzerain_id == attacker.id → false.
- `test_should_declare_war_false_when_same_coalition` — both in coalition → false.
- `test_should_declare_war_false_when_tension_below_threshold` — tension=69 → false (próg ostry >=70).
- `test_should_declare_war_false_when_no_cb_available` — attacker axes nie pasują do żadnego CB → false.

`choose_war_target` (~2 testy):
- `test_choose_war_target_returns_empty_when_rng_above_threshold` — seeded RNG > 0.2 → {}.
- `test_choose_war_target_picks_highest_tension` — multiple eligible → highest tension wins.

`should_offer_peace` (~3 testy):
- `test_should_offer_peace_attacker_contested_provinces` — attacker, contested>0 → true.
- `test_should_offer_peace_attacker_give_up_high_weariness` — attacker, contested=0, weariness=75 → true.
- `test_should_offer_peace_defender_high_weariness` — defender, weariness=65 → true.
- `test_should_offer_peace_false_when_low_weariness_no_contested` — attacker, no contested, weariness=30 → false.

`compose_peace_terms` (~2 testy):
- `test_compose_peace_terms_attacker_annexation_when_contested` — attacker + contested → annexation dict.
- `test_compose_peace_terms_empty_when_no_contested` — attacker no contested OR defender → {}.

### Engine — TurnManager integration (~3 testy)

**`tests/engine/test_turn_manager.gd`** (rozszerzenie):

- `test_npc_declares_war_when_tension_high` — setup: NPC z tension=80 z player, prestige=50. Seeded RNG dispatch. Process turn → assert `state.active_wars.size()` += 1, war.attacker_id == NPC.
- `test_npc_offers_peace_when_attacker_has_contested` — setup: NPC attacker, contested=[X], weariness low. Process turn → war.state == ENDED, X owned by NPC.
- `test_npc_offers_peace_when_defender_weariness_high` — setup: NPC defender, weariness=65. Process turn → war.state == ENDED, no annexation.

### Test isolation (warunkowa)

Pre-existing tests używające `process_turn` mogą być zakłócone przez Plan 20:
- `_npc_declare_wars` dodaje nowe wojny gdy NPC tension >= 70 (niektóre fixture pary mają startowe tension 70+).
- `_npc_offer_peace` kończy wojny gdy NPC weariness > 60 lub contested > 0.

**Task 0 mandatory:** enumerate `process_turn` call sites + identify konkretne kolizje. Najczęstsze mitigation:
1. Pin NPC tension < 70 dla wszystkich par (modify state.relations).
2. Disable NPC AI via `set_ai_override(AIManager.new(disabled_rng))` gdzie `disabled_rng.randf()` zawsze > 0.2.

Najczystsze: opcja 2 (jeden line per test).

### Backward compatibility

- Plan 12-19 testy: bez zmian poza warunkową izolacją.
- Plan 18 testy AIManager (decide_accept_idea, etc.) — bez zmian.
- Plan 19 testy AIManager (should_attack_in_war, choose_attack_target) — bez zmian.

### Łącznie

~13 nowych testów (10 AIManager + 3 TurnManager). Po Plan 20 oczekiwane ~783 testów (770 z Plan 19 + 13 nowych).

---

## Sekcja 7: Otwarte pytania / Future work

### Decyzje implementacyjne (rozstrzygnięte przed planem)

1. **Tension threshold 70** — wybrane jako "wysokie napięcie" zgodne z DiplomacyManager.PEACE_TENSION_DECAY (tension naturalnie maleje). 70 = "actively hostile". Future tuning.
2. **20% RNG declare chance** — anti-spam: gdy NPC ma 3 eligible targets z tension >= 70, ~60% chance to declare wojnę z ANY of them per turn. Bez gate, NPC by deklarował każdą turę.
3. **Peace attacker asymetric** — `contested > 0` (claim) jest pierwszy sprawdzany; weariness > 70 jest fallback. Jeśli NPC wygrywa, ends szybko z annexation.
4. **`policy: "nawracaj"`** — minimal side effects (Population preserved, axis nie zmienia się). Future plan może dodać heuristic policy choice.
5. **CB selection: first available** — deterministic, MVP. Future: pick max CB_BONUS.
6. **Pipeline order: attack → peace → declare** — naturalne AI flow.

### Poza zakresem Plan 20

- **NPC resolve_defeat** — wybór DEFEAT_OPTIONS po przegranej (Plan 21+).
- **Smart CB targeting** — krucjata vs heretyk, dzihad vs religijny wróg (Plan 22).
- **Smart peace terms** — forced_council + clergy_extermination (Plan 21).
- **Coalition declarations** — NPC declared war + auto-join via existing DiplomacyManager (out of scope, ale DiplomacyManager.auto_join_*_to_coalitions już to obsługuje passively).
- **Defender counter-attacks** — wymaga WarManager extension (Plan 21+).
- **Holy war specific AI** — Plan 22+.
- **NPC tuning** — playtesting.

---

## Sekcja 8: Acceptance criteria

Plan 20 jest gotowy do merge gdy:

1. ✅ 4 stałe Plan 20 w AIManager (`AI_WAR_TENSION_THRESHOLD`, `AI_WAR_DECLARE_CHANCE`, `AI_PEACE_ATTACKER_WEARINESS_GIVE_UP`, `AI_PEACE_DEFENDER_WEARINESS`).
2. ✅ `should_declare_war(attacker, defender, state) -> bool` z pełnymi guards.
3. ✅ `choose_war_target(state, attacker) -> Dictionary` z RNG gate + highest tension selection.
4. ✅ `should_offer_peace(war, npc_id, state) -> bool` z per-role logic.
5. ✅ `compose_peace_terms(war, npc_id, state) -> Dictionary` z annexation/empty.
6. ✅ `TurnManager._npc_offer_peace(state)` istnieje + w pipeline po Plan 19 attack.
7. ✅ `TurnManager._npc_declare_wars(state)` istnieje + w pipeline po peace.
8. ✅ NPC declarations: skip player, defeated, ally, vassal/suzerain, coalition member, existing war.
9. ✅ NPC peace: per-role correct (attacker contested → annex; attacker give-up → empty; defender weariness → empty).
10. ✅ Pre-existing testy Plan 12-19 pass — z warunkową AI isolation.
11. ✅ ~13 nowych testów pass.
12. ✅ Cała suite (~783) pass.
13. ✅ CLAUDE.md wzmiankuje Plan 20.
14. ✅ Brak zmian w WarManager.gd, War.gd, RelationState.gd, Coalition.gd, fixture, UI.

---

## Sekcja 9: Zależności i ryzyka

**Zależności:**
- Plan 18 AIManager (klasa + RNG injection + `_get_ai` w TurnManager).
- Plan 19 attack AI (precedens war API extension).
- `WarManager.declare_war`, `offer_peace`, `available_casus_belli` — istnieją, niezmieniane.
- `DiplomacyManager.get_or_create_relation` — istnieje, niezmieniany.
- `RelationState.alliance_active`, `military_tension` — istnieją.
- `Coalition.members` — istnieje.
- `Religion.suzerain_id` — istnieje.

**Ryzyka:**

- **R1: Test isolation invasive niż Plan 19.** Plan 20 może ADD nowe wojny do `state.active_wars` mid-test (declarations) AND END istniejące wojny (peace). Pre-existing tests asercjujące war count / war state mogą pęknąć w wielu miejscach. **Mandatory Task 0** wide enumerate + per-test mitigation (preferred: `set_ai_override(AIManager.new(disabled_rng))`).

- **R2: NPC over-aggressive declarations.** 11 NPC × 20% chance × per-turn × eligible targets może stworzyć "world war" scenario. Tuning: 20% jest punktem startowym, do playtestingu redukcji do 5-10%.

- **R3: NPC over-eager peace.** Defender z weariness 60 (po ~20 turach) → peace empty terms. Attacker contested=1 (1 won battle) → peace annex 1. Wojny mogą kończyć się szybko, bez głębokich kampanii. Tuning thresholds. MVP: design intent.

- **R4: Same-turn declare → no attack.** Plan 20 declare adds new war in MOBILIZING. `_npc_attack_wars` (już za nami w tej turze) nie atakuje (war.state != BATTLING). Pierwsza walka w turze T+2. Spójne z player declarations — acceptable.

- **R5: Concurrent NPC peace both sides.** Jeśli oba sides w wojnie to NPC AND oba meet peace condition same turn — `_npc_offer_peace` iteruje attacker first, then defender. War zostanie ENDED przez attacker → defender check skipped. Determinism preserved. Acceptable.

**Mitigation R1-R5:** R1 wymaga Task 0 enumerate (Plan 20 plan). R2-R4 to design intent / tuning future. R5 jest acceptable deterministic ordering.

**Brak ryzyk struktury:**
- AIManager rozszerzenie — addytywne.
- TurnManager 2 nowe etapy — addytywne.
- 4 nowe stałe — brak konfliktu z istniejącymi.
