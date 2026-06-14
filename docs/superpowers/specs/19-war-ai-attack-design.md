# Plan 19 — War AI: attack_province (MVP)

> **Spec dla:** Plan 19 — pierwsza implementacja war AI. MVP scope: NPC atakujący wykonują `attack_province` per turn (gdy `war.state == "BATTLING"`). Declarations + peace offers + defender counter-attacks pozostają out of scope.
>
> **W zakresie:**
> 1. Rozszerzenie istniejącej klasy `AIManager`: 2 nowe metody (`should_attack_in_war`, `choose_attack_target`).
> 2. Border-adjacent target selection z fallback do random (gdy brak adjacency).
> 3. Nowy etap `_npc_attack_wars(state)` w `TurnManager.process_turn` po `_process_active_wars`.
> 4. Per-war 1 attack per turn gdy NPC = attacker AND war.state == BATTLING.
>
> **Wyłączone z zakresu:**
> - **NPC war declarations** (`declare_war`) — Plan 20+.
> - **NPC peace offers** (`offer_peace`) — Plan 20+.
> - **NPC defender counter-attacks** — wymaga rozszerzenia WarManager API (obecnie `attack_province` używa tylko `war.attacker_id`).
> - **NPC resolve_defeat** (NPC wybiera opcję po przegranej) — Plan 20+.
> - **Smart targeting heuristics** (lowest population, highest pressure, weariness consideration) — future tuning.
> - **Holy war specific AI** (crusade/jihad targeting religious enemies) — Plan 21+.
> - **War declaration AI dla coalition members** — Plan 20+.

---

## Sekcja 1: Kontekst i motywacja

Plan 18 dał MVP NPC AI dla doktryny — NPC dispatchują scholarów i auto-resolve ideas. Stan po Plan 18:
- `AIManager` klasa istnieje (stateless, RefCounted, RNG injection).
- `TurnManager` ma `set_ai_override` setter + `_get_ai` helper + nowy etap `_npc_dispatch_scholars` + modyfikacja `_process_scholar_missions`.
- NPC religie aktywne **tylko doktrynalnie** — dispatch scholar, accept/reject ideas. **Nie atakują, nie deklarują wojen, nie oferują pokoju.**

`WarManager` API:
- `declare_war(attacker_id, defender_id, cb, state) -> War` — inicjuje wojnę.
- `attack_province(war, province_id, state) -> Dictionary` — atak (wymaga `war.state == "BATTLING"`, używa `randf()` globalny do roll'a).
- `offer_peace(war, terms, state) -> bool` — propozycja pokoju.
- `resolve_defeat(event, option_index, state) -> void` — NPC wybiera opcję po przegranej.

`TurnManager._process_active_wars`:
- Przejścia stanów (`MOBILIZING` → `BATTLING` po 2 turach; `OCCUPYING` → `BATTLING` po 2 turach).
- Naliczanie `war_weariness` (+3 per turn dla obu stron).
- Force_loss przy `weariness >= 90`.
- **NIE wykonuje aktywnych ataków** — `attack_province` musi być wywołane przez UI gracza (lub przez przyszłe AI).

Po Plan 19 (MVP attack-only):
- NPC atakujące religie wykonują `attack_province` per turn (1 atak per war, gdy BATTLING).
- Mapa staje się dynamiczna w wojnie — prowincje zmieniają właściciela bez akcji gracza.
- Gracz jako defender NPC attacker → musi defendować się czynnie (przez wojska, sojusze) zamiast po prostu czekać.
- Pozostawia future plans: declarations, peace, defender counterattacks.

**MVP rationale:** Pełne war AI (declare + attack + peace + defender counter) to wielokrotnie większy scope. Plan 19 dodaje TYLKO attack — najprostszy fragment z natychmiastowym wpływem na gameplay. Future plans budują na tym warstwami.

---

## Sekcja 2: Cele projektowe

1. **Rozszerzyć AIManager o war API** — 2 nowe metody (`should_attack_in_war`, `choose_attack_target`). Spójność z Plan 18 patternem (stateless, RNG injection, faction-data-driven decisions).
2. **MVP attack-only** — NPC atakujące religie aktywnie atakują podczas BATTLING. Bez declarations / peace / counter-attacks.
3. **Border-adjacent target selection** — NPC atakuje prowincje defendera sąsiadujące z własnymi prowincjami (geograficznie sensowne). Fallback do random gdy brak adjacency.
4. **Test isolation** — pre-existing tests używające `process_turn` z active_wars muszą być sprawdzone i ewentualnie isolatedowane (jak Plan 18 prestige=0 pin). Task 0 enumeration mandatory.
5. **Zero zmian w `WarManager` API** — Plan 19 używa istniejących `attack_province`, nie modyfikuje semantyki.
6. **Zero zmian w gracza flow** — UI gracza dla deklarowania wojen, atakowania prowincji, oferowania pokoju pozostaje niezmienione.

---

## Sekcja 3: Architektura — co zmienia Plan 19

### Modyfikacje istniejące

**`scripts/engine/AIManager.gd`:**
- Dodanie 2 metod public API:
  - `should_attack_in_war(attacker: Religion, war: War) -> bool` — gating.
  - `choose_attack_target(state: Node, attacker: Religion, defender_id: String) -> String` — target selection (border-adjacent + fallback).

**`scripts/engine/TurnManager.gd`:**
- Nowy etap `_npc_attack_wars(state)` w `process_turn` pipeline (po `_process_active_wars`, przed `_process_missionaries` lub gdziekolwiek logicznie).
- Iteruje `state.active_wars`, dla NPC atakujących wywołuje `ai.should_attack_in_war` + `ai.choose_attack_target` + `wm.attack_province`.

### Brak zmian

- `WarManager.gd` — bez zmian (używamy istniejącego `attack_province` API).
- `War.gd`, `Religion.gd`, `ProvinceGraph.gd`, `Province.gd`, `GameState.gd` — bez zmian.
- Inne managery (DiplomacyManager, DoctrineManager, SchismManager, VictoryManager) — bez zmian.
- UI — bez zmian.
- Fixture (`data/*.json`) — bez zmian.

### Pipeline order po Plan 19

```gdscript
func process_turn(state: Node) -> void:
	# ... existing early stages ...
	_update_faction_tensions(state)
	_npc_dispatch_scholars(state)        # Plan 18
	_process_scholar_missions(state)     # Plan 18 (modified)
	_apply_believer_exodus(state)
	_process_active_wars(state)          # existing (state transitions + weariness)
	_npc_attack_wars(state)              # NEW Plan 19
	_process_missionaries(state)
	_process_diplomacy(state)
	# ... existing late stages ...
```

---

## Sekcja 4: `should_attack_in_war` (gating)

### 4.1 Algorithm

```gdscript
func should_attack_in_war(attacker: Religion, war: War) -> bool:
	# Plan 19 MVP: zawsze true gdy attacker żyje i war.state == BATTLING.
	# Placeholder dla future heurystyk (weariness threshold, peace negotiation pending, etc.).
	if attacker == null or attacker.defeated_at_turn != -1:
		return false
	if war.state != "BATTLING":
		return false
	return true
```

### 4.2 Rationale dla MVP placeholder

W obecnym MVP `should_attack_in_war` nie dodaje żadnej heurystyki ponad to co TurnManager już sprawdza (`war.state == "BATTLING"`). Jest jednak **świadomym extension pointem** dla future plans:
- **Plan 20**: dodać `weariness < 70` (zbyt wyczerpani → szykować peace offer zamiast atakować).
- **Plan 21**: dodać `peace_negotiation_pending` flag check.
- **Plan 22**: dodać casus belli specific gating (np. krucjata atakuje tylko prowincje z holy_site).

### 4.3 Edge cases

- `attacker == null` — religia eliminated, return false. Sensowne (no agency).
- `attacker.defeated_at_turn != -1` — pokonany, return false. Sensowne (eliminated NPC nie powinien atakować).
- `war.state == "MOBILIZING"` / `"OCCUPYING"` / `"ENDED"` — return false. Spójne z `WarManager.attack_province` early-return.

---

## Sekcja 5: `choose_attack_target` (border-adjacent + fallback)

### 5.1 Algorithm

```gdscript
func choose_attack_target(state: Node, attacker: Religion, defender_id: String) -> String:
	# Plan 19 §5: border-adjacent target preferred, fallback random defender province.
	var defender_provs := state.province_graph.provinces_with_owner(defender_id)
	if defender_provs.is_empty():
		return ""
	var border_candidates: Array[String] = []
	for d_prov: Province in defender_provs:
		for neighbor_id: String in d_prov.neighbors:
			var neighbor: Province = state.province_graph.get_province(neighbor_id)
			if neighbor != null and neighbor.owner == attacker.id:
				border_candidates.append(d_prov.id)
				break  # 1 entry per defender province (no duplicates if multiple borders)
	if not border_candidates.is_empty():
		return border_candidates[rng.randi() % border_candidates.size()]
	# Fallback: random defender province (no border adjacency)
	return defender_provs[rng.randi() % defender_provs.size()].id
```

### 5.2 Rationale dla border-adjacent

Border-adjacent jest najbardziej intuicyjny dla strategy game — atakujesz to, do czego masz dostęp. Wzór z większości turn-based strategies (Civilization, Crusader Kings).

**Fallback do random:** gdy attacker i defender są geograficznie odseparowane (e.g. Slavic vs Eastern Christianity w odległych regionach), bez border adjacency border_candidates jest pusty. Random fallback zapewnia że NPC wciąż atakuje (mechanika nie blokuje się). Narratywnie: "ekspedycja morska" lub "marsz przez sojuszników" — uproszczenie.

### 5.3 Edge cases

- Defender ma 0 prowincji (eliminated) → return `""` → TurnManager skip attack.
- Wszystkie defender provinces są border-adjacent → border_candidates == defender_provs.size() → uniform random selection z całego setu.
- Brak adjacency wcale → fallback random z pełnego defender set.

### 5.4 Performance

Worst case: O(D × N) gdzie D = defender provinces, N = average neighbors per province. Dla 26 prowincji × ~3 neighbors = ~78 ops per war per turn. Negligible.

---

## Sekcja 6: Integration w TurnManager

### 6.1 `_npc_attack_wars` implementation

```gdscript
func _npc_attack_wars(state: Node) -> void:
	# Plan 19 §6.1: NPC attacker performs 1 attack per war per turn (gdy BATTLING).
	var ai := _get_ai()
	var wm := WarManager.new()
	# Iterujemy duplicate aby uniknąć side effects (attack_province nie modyfikuje active_wars,
	# ale safety + przejrzystość intencji).
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

### 6.2 Pipeline placement

Po `_process_active_wars(state)`, przed `_process_missionaries(state)`. Rationale:
- Po `_process_active_wars`: state transitions (MOBILIZING → BATTLING) już zakończone w tej turze, więc `war.state` reflektuje aktualny stan.
- Po `_process_active_wars`: jeśli weariness ≥ 90 → `force_loss` zostało wywołane → war usunięty z `active_wars` → NPC AI iteruje już bez "dead" wars.
- Przed `_process_missionaries`: kolejność akcji ofensywnych zachowuje war → missionary → diplomacy pattern.

### 6.3 Why `duplicate()`?

`attack_province` w obecnym kodzie nie usuwa wars z `active_wars` (state może zmienić się na OCCUPYING, ale war pozostaje). Więc iteracja po `state.active_wars` bezpośrednio jest bezpieczna. Plan 19 używa `.duplicate()` dla **future-proof safety** — jeśli future plan doda `attack_province` że mutuje array (np. auto-end war after N battles), iteracja działa.

---

## Sekcja 7: Test plan

### Engine — AIManager (~5 testów)

**`tests/engine/test_ai_manager.gd`** (rozszerzenie):

- `test_should_attack_in_war_returns_true_when_battling` — happy path.
- `test_should_attack_in_war_returns_false_when_not_battling` — MOBILIZING / OCCUPYING / ENDED → false.
- `test_should_attack_in_war_returns_false_when_attacker_defeated` — `defeated_at_turn != -1` → false.
- `test_choose_attack_target_picks_border_adjacent_when_available` — setup attacker + defender z adjacency, assert target ∈ border_candidates.
- `test_choose_attack_target_falls_back_to_random_when_no_border` — setup attacker + defender bez adjacency, assert target ∈ defender_provs.
- `test_choose_attack_target_returns_empty_when_defender_has_no_provinces` — defender 0 prov → "".
- `test_choose_attack_target_skips_non_defender_provinces` — sanity: jeśli istnieje prowincja z owner=neutral, ignorować.

### Engine — TurnManager integration (~3 testy)

**`tests/engine/test_turn_manager.gd`** (rozszerzenie):

- `test_npc_attacker_attacks_during_battling_state` — setup: NPC attacker war w BATTLING, player defender. 1 turn → assert war.battles_won OR war.battles_lost > 0 (atak się odbył).
- `test_npc_does_not_attack_when_player_is_attacker` — player attacker → 1 turn → NPC nic nie robi (no battles_won/lost increment).
- `test_npc_does_not_attack_during_mobilizing_state` — war.state = MOBILIZING → no attack.

### Test isolation (pre-existing)

Pre-existing testy używające `process_turn` z active wars — sprawdzić w Task 0:
- `test_turn_manager.gd:test_process_turn_mobilizing_war_transitions_to_battling_after_2_turns`
- `test_turn_manager.gd:test_process_turn_occupying_war_returns_to_battling_after_2_turns`
- `test_turn_manager.gd:test_process_turn_increments_war_weariness_for_both_sides`
- `test_turn_manager.gd:test_process_turn_force_peace_at_weariness_90_creates_defeat_event`

Każdy może mieć NPC attacker — wtedy nowy etap `_npc_attack_wars` doda attacks i może zaburzyć asercje (e.g. `assert war.state == BATTLING` może failować jeśli atak success → OCCUPYING).

**Task 0 scope rozszerzony:** Reviewer Plan 19 spec advisory note 1 — Task 0 MUST grep wszystkie test files (nie tylko test_turn_manager.gd) za pattern `process_turn` + `active_wars`. Komenda:
```bash
grep -l "process_turn" tests/**/*.gd | xargs grep -l "active_wars\|declare_war\|attack_province"
```
Enumerate konkretne testy, decide isolation per-test.

**Mitigacja:** dla każdego z 4 testów, ustawić `state.player_religion_id = war.attacker_id` (gracz to atakujący — Plan 19 skip). Lub: ustawić wszystkim attacker religiom `defeated_at_turn = X > 0` (skip via gate). Najprostsze: pin `player_religion_id`.

### Backward compatibility

- Plan 12-18 testy: bez zmian poza ewentualnym test isolation (jak Plan 18 dodał prestige=0 pin do test_diplomacy_manager).
- AIManager testy z Plan 18 (decide_accept_idea, should_dispatch_scholar, choose_scholar_target) — bez zmian.
- WarManager testy: bez zmian (`attack_province` semantyka niezmodyfikowana).

### Łącznie

~8 nowych testów (5 AIManager + 3 TurnManager integration). Po Plan 19 oczekiwane ~768 testów (760 z Plan 18 + 8 nowych).

---

## Sekcja 8: Otwarte pytania / Future work

### Decyzje implementacyjne (rozstrzygnięte przed planem)

1. **MVP attack-only** — declarations i peace odłożone do Plan 20+.
2. **Border-adjacent target selection** — wybrane nad random/lowest-pop/highest-pressure. Geographically sensible, narratywnie spójne.
3. **`should_attack_in_war` MVP placeholder** — zawsze true gdy BATTLING + alive. Extension point dla future heurystyk.
4. **Defender pozostaje pasywny** — `attack_province` API obsługuje tylko `war.attacker_id`. Future plan może rozszerzyć API o `recapture_province` lub `attack_province(side: String)`.
5. **Iteracja `state.active_wars.duplicate()`** — defensive copy dla future-proofness.

### Poza zakresem Plan 19

- **NPC declare_war**: wymaga heurystyk wyboru target + casus belli. Plan 20.
- **NPC offer_peace**: wymaga heurystyk gating (weariness > X, battles_lost > battles_won) + terms generation. Plan 20.
- **NPC resolve_defeat**: NPC wybiera opcję defeat (z DEFEAT_OPTIONS). Plan 20.
- **NPC counter-attacks jako defender**: rozszerzenie WarManager API. Plan 21+.
- **Smart targeting** (population, pressure, holy_site CB-aware): Plan 22+ tuning.
- **AI difficulty levels** — out of scope.

---

## Sekcja 9: Acceptance criteria

Plan 19 jest gotowy do merge gdy:

1. ✅ `AIManager.should_attack_in_war(attacker, war) -> bool` istnieje.
2. ✅ `AIManager.choose_attack_target(state, attacker, defender_id) -> String` istnieje.
3. ✅ `TurnManager._npc_attack_wars(state)` istnieje i jest wywoływane w `process_turn` po `_process_active_wars`.
4. ✅ NPC attacker performs attack per turn (1 per war) gdy `war.state == "BATTLING"`.
5. ✅ Player attacker is skipped (player UI handles).
6. ✅ Defeated NPC attacker is skipped.
7. ✅ Border-adjacent target preferred, fallback do random gdy brak adjacency.
8. ✅ Defender 0 provinces → no attack (silent skip).
9. ✅ Pre-existing Plan 12-18 testy (~760) pass — z minimalnym AI isolation w 4 pre-existing war tests.
10. ✅ ~8 nowych testów pass (5 AIManager + 3 TurnManager integration).
11. ✅ Cała suite (~768) pass.
12. ✅ `CLAUDE.md` wzmiankuje Plan 19.
13. ✅ Brak zmian w `WarManager.gd`, `War.gd`, fixture, UI, innych managerach.

---

## Sekcja 10: Zależności i ryzyka

**Zależności:**
- `AIManager` z Plan 18 (klasa + RNG injection) — w master.
- `TurnManager.set_ai_override` / `_get_ai` z Plan 18 — w master.
- `WarManager.attack_province` — istnieje w master, niezmieniany.
- `War.state`, `War.attacker_id`, `War.defender_id`, `War.battles_won`, `War.battles_lost` — istnieją, niezmieniane.
- `GameState.active_wars`, `player_religion_id` — istnieją.

**Ryzyka:**

- **R1: Pre-existing war tests collisions.** 4 testy w `test_turn_manager.gd` używają active_wars przez `process_turn`. NPC attacker w nich może triggerować unintended attacks. **Mandatory Task 0:** enumerate i decide isolation (per-test: pin player as attacker, lub set defeated_at_turn dla NPC attackerów).

- **R2: RNG niedeterminizm w `attack_province`** — używa `randf()` globalnego. Plan 19 NIE modyfikuje `attack_province`. Testy AIManager używają seeded `rng` na `choose_attack_target` poziomie. Testy integration akceptują dowolny battle outcome (asserting `battles_won + battles_lost >= 1`, nie specific value).

- **R3: NPC ataki mogą być over-aggressive.** 1 attack per war per turn × N wars. Jeśli 5 wars where NPC = attacker → 5 attacks per turn. Mitigacja: każda wojna ma OCCUPYING state cooldown (2 tury) po sukcesach, więc efektywnie 1 attack per 3 tury per war. Player również ma ten cooldown — symmetric.

- **R4: Player jako defender ma minimal counter-play.** Plan 19 nie dodaje gracza defender mechanics (counter-attack, defensive bonuses). Player polega na compute_army_strength terrain modifier + sojuszników. Future plan może rozszerzyć defender UI.

**Mitigacja R1-R4:** Wszystkie są MVP design intent. Future plans dodadzą peace AI (R3), defender counter (R2 partially), declaration AI (full reciprocal aggression).

**Brak ryzyk struktury:**
- AIManager rozszerzenie — addytywne (no field changes).
- TurnManager nowy etap — addytywny (no order changes w existing steps).
- Stałe Plan 19 — brak nowych (placeholder gating, no thresholds yet).
