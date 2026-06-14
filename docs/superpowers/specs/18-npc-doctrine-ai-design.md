# Plan 18 — NPC AI: doktryna (MVP)

> **Spec dla:** Plan 18 — pierwsza implementacja AI dla niegracznych religii. MVP scope: TYLKO doctrine loop (dispatch scholar + accept/reject ideas).
>
> **W zakresie:**
> 1. Nowa klasa `AIManager` w `scripts/engine/AIManager.gd` (stateless, `extends RefCounted`, pattern jak inni managerowie).
> 2. `AIManager.decide_accept_idea(religion, idea)` — faction-weighted heuristic.
> 3. `AIManager.should_dispatch_scholar(religion)` + `AIManager.choose_scholar_target(state, religion)` — proactive dispatch z RNG seeding.
> 4. Integracja w `TurnManager.process_turn`:
>    - Nowy etap `_npc_dispatch_scholars(state)` przed `_process_scholar_missions`.
>    - Modyfikacja `_process_scholar_missions`: dla NPC, idea auto-resolve via AIManager zamiast `pending_ideas.append`.
> 5. RNG seeding: `AIManager.new(rng)` przyjmuje opcjonalny `RandomNumberGenerator` (deterministic testy).
>
> **Wyłączone z zakresu:**
> - **War AI** (declare_war, attack_province, offer_peace) — Plan 19+.
> - **Diplomacy AI** (alliances, interdicts, councils, missionaries, suzerainty) — Plan 19+.
> - **Sobor / edict** (proactive doctrine actions) — Plan 20+.
> - **Player UI dla accept/reject pending_ideas** — `pending_ideas` queue dla gracza pozostaje orphaned (osobny plan UI).
> - **Smart utility-based decision** — Plan 18 używa prostego faction-weighted scoring. Tuning odłożony.
> - **NPC counter-actions** (counter-missionary, schism risk avoidance, faction tension management) — Plan 21+.
> - **Adaptive AI difficulty** — out of scope.

---

## Sekcja 1: Kontekst i motywacja

Obecny stan po Plan 17:
- 12 religii w grze, gracz kontroluje 1 (`state.player_religion_id`).
- Pozostałe 11 religii **istnieją jako pasywne data containers** — nie podejmują żadnych aktywnych akcji.
- `TurnManager.process_turn` iteruje wszystkie religie wykonując pasywne efekty (passive_pressure, holy_site_prestige, faction_tensions, scholar_mission resolution, war resolution, missionary resolution, diplomacy, resources, vassal revolts), **ale żadna z akcji aktywnych** (declare_war, send_missionaries, accept_idea, call_sobor, etc.) nie jest wywoływana dla NPC.
- `state.pending_ideas` queue **istnieje, ale nikt go nie konsumuje**: brak UI gracza dla accept/reject, brak AI dla NPC. Idee się akumulują (orphan queue).
- `dispatch_scholar` API istnieje, ale tylko testy go wywołują. W produkcji `state.scholar_missions` jest pusty.

To znaczy: **gra jest jednokierunkowa** — gracz może wpływać na NPC (przez missionaries, scholar, war), ale NPC nigdy nie odpowiada poza pasywnymi reakcjami.

Plan 18 to **MVP AI**: implementuje minimalny doctrine loop dla NPC — proactive scholar dispatch + automatic idea resolution. Po Plan 18:
- NPC religie aktywnie wysyłają scholars do innych religii.
- NPC akceptują lub odrzucają idee na podstawie faction preferences.
- Mapa doktrynalna staje się dynamiczna — NPC axes dryfują czas.

**MVP rationale:** Pełne AI (war + diplomacy + doctrine) to wielokrotnie większy scope (15+ akcji × 11 NPC × heurystyki targeting). Plan 18 ustanawia AIManager architekturę i pierwszą działającą warstwę, na której kolejne plany budują.

---

## Sekcja 2: Cele projektowe

1. **Ustanowić AIManager architekturę** — klasa stateless analogiczna do innych managerów (`extends RefCounted`, public API methods, no per-instance state).
2. **MVP doctrine loop** — NPC dispatchują scholars proaktywnie i resolve ideas automatycznie.
3. **Faction-weighted heuristic** — decyzja accept/reject oparta na sumie `faction.influence × axis_preference_match`. Deterministyczna, używa istniejących danych.
4. **RNG seeding dla testów** — `AIManager.new(rng)` przyjmuje `RandomNumberGenerator`, testy iniciują seed dla reproducibility (zgodnie z CLAUDE.md).
5. **Zero zmian w istniejącej logice gracza** — player UI / player flow / `pending_ideas` dla gracza pozostają niezmienione. Plan 18 to czysty add dla NPC.
6. **Test isolation** — istniejące endgame testy (Plan 14/16/17) używają bezpośredniego `vm.update_counters` + `vm.check`, nie `tm.process_turn`. AIManager NIE wpływa na te testy. Plan 18 dodaje nowe testy w nowym pliku `test_ai_manager.gd` + rozszerzenie `test_turn_manager.gd`.

---

## Sekcja 3: Architektura — co zmienia Plan 18

### Nowa klasa

**`scripts/engine/AIManager.gd`** (~40-50 linii):
- `extends RefCounted` (pattern jak DiplomacyManager, WarManager, etc.).
- 2 stałe: `AI_SCHOLAR_MIN_PRESTIGE`, `AI_SCHOLAR_DISPATCH_CHANCE`.
- Field: `var rng: RandomNumberGenerator` (zainicjowany w `_init`).
- Constructor: `func _init(injected_rng: RandomNumberGenerator = null)` — jeśli `injected_rng != null` przypisz, inaczej stwórz nowy z `randomize()`.
- 3 metody public API:
  - `decide_accept_idea(religion: Religion, idea: Idea) -> bool`
  - `should_dispatch_scholar(religion: Religion) -> bool`
  - `choose_scholar_target(state: Node, religion: Religion) -> String`

### Modyfikacje

**`scripts/engine/TurnManager.gd`:**
- `process_turn` pipeline: nowy etap `_npc_dispatch_scholars(state)` przed `_process_scholar_missions`.
- `_process_scholar_missions` modyfikowane: gdy mission produkuje idea, sprawdź czy dispatcher to NPC; jeśli tak — auto-resolve via AIManager (`decide_accept_idea` → `accept_idea` lub `reject_idea`); jeśli gracz — `pending_ideas.append(idea)` (bez zmian).
- Nowa funkcja `_npc_dispatch_scholars(state)`: iteruje wszystkie religie, dla NPC wywołuje `ai.should_dispatch_scholar` + `ai.choose_scholar_target` + `dm.dispatch_scholar`.
- TurnManager musi gdzieś trzymać/inicjować AIManager. Opcje:
  - (a) Nowy field `var ai: AIManager` w TurnManager — wymaga init w `_init`.
  - (b) Lokalne `var ai := AIManager.new()` per turn — analog `var wm := WarManager.new()` w existing pipeline.
  - **Wybór: (b)** — spójne z istniejącym pattern (per-turn instancjowanie wszystkich managerów).

### Brak zmian

- `DoctrineManager.gd` — bez zmian (API `dispatch_scholar`, `accept_idea`, `reject_idea`, `generate_idea` nietknięte).
- `Religion.gd`, `Faction.gd`, `Idea.gd`, `GameState.gd` — bez zmian.
- Inne managery (DiplomacyManager, WarManager, SchismManager, VictoryManager) — bez zmian.
- UI — bez zmian.
- Fixture (`data/*.json`) — bez zmian.

### `is_defeated()` — sanity check istnienia

Spec zakłada że `Religion.is_defeated()` istnieje (sprawdza `defeated_at_turn != -1`). Sprawdzić w implementacji jeśli nie istnieje — dodać helper lub używać `religion.defeated_at_turn != -1` inline.

---

## Sekcja 4: Faction-weighted decision (`decide_accept_idea`)

### 4.1 Algorytm

```gdscript
func decide_accept_idea(religion: Religion, idea: Idea) -> bool:
	# Suma: faction.influence × pref.direction × shift_direction
	# Pozytywna suma = frakcje wspierają shift → accept
	var net_support: float = 0.0
	var shift_direction: int = 1 if idea.delta > 0.0 else -1
	for faction: Faction in religion.factions:
		for pref: Dictionary in faction.axis_preferences:
			if pref.get("axis", "") == idea.axis:
				var pref_dir: int = pref.get("direction", 0)
				net_support += faction.influence * pref_dir * shift_direction
				break  # tylko 1 preference per axis per faction
	return net_support > 0.0
```

### 4.2 Tie-break

Jeśli `net_support == 0.0` (brak frakcji z preferencją na osi `idea.axis`, lub idealny remis przeciwstawnych frakcji) → **reject** (conservative — nie wprowadzaj zmiany bez wsparcia).

### 4.3 Edge cases

- **Religia bez frakcji** (`religion.factions.is_empty()`) — `net_support = 0` → reject. Sensowne (no agency to approve).
- **Idea z delta=0** — `shift_direction` undefined (1 if 0.0 > 0 else -1 → -1). Reject (no movement). Sensowne.
- **Wszystkie frakcje neutralne na osi `idea.axis`** — `net_support = 0` → reject.

### 4.4 Przykład: Slavic + idea axis A delta +5

Slavic factions:
- Wolchwi (influence 0.45): `axis_preferences: [{A:-1}, {D:+1}]`. Match on A: pref_dir=-1, shift=+1 → contribution: 0.45 × -1 × 1 = **-0.45**.
- Plemienna Starszyzna (0.35): `[{B:-1}]`. No match on A → contribution 0.
- Herosi Ziemi (0.20): `[{D:-1}, {C:+1}]`. No match on A → contribution 0.

`net_support = -0.45 + 0 + 0 = -0.45 < 0` → **reject**.

Slavic rejects idea pushing A up — narratywnie spójne (Wolchwi przeciw dogmatyzmowi).

### 4.5 Przykład: Slavic + idea axis A delta -3 (lower A)

- Wolchwi: shift=-1, pref_dir=-1 → 0.45 × -1 × -1 = **+0.45**. (Wolchwi support).
- Inne: 0.

`net_support = +0.45 > 0` → **accept**.

Slavic akceptuje idee obniżające dogmatyzm — spójne z Wolchwi.

---

## Sekcja 5: Scholar dispatch (`should_dispatch_scholar`, `choose_scholar_target`)

### 5.1 Gating: `should_dispatch_scholar`

```gdscript
const AI_SCHOLAR_MIN_PRESTIGE := 50
const AI_SCHOLAR_DISPATCH_CHANCE := 0.15

func should_dispatch_scholar(religion: Religion) -> bool:
	if religion.defeated_at_turn != -1:
		return false
	if religion.prestige < AI_SCHOLAR_MIN_PRESTIGE:
		return false
	return rng.randf() < AI_SCHOLAR_DISPATCH_CHANCE
```

**Rationale:**
- `defeated_at_turn != -1`: pokonane religie nie działają.
- `prestige < 50`: `dispatch_scholar` w obecnym DoctrineManager.gd **nie kosztuje prestige** (tylko dodaje do `state.scholar_missions`). Próg 50 w AI to **AI-only gate** — chroni przed dispatch'em religii w opłakanym stanie. Najuboższy startowy prestige to Manichaeism=100, Slavic=120, więc próg 50 jest niski (wszyscy startowo pass).
- 15% chance per turn → ~30 dispatch eventów per NPC na 200 turach.

### 5.2 Target selection: `choose_scholar_target`

```gdscript
func choose_scholar_target(state: Node, religion: Religion) -> String:
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

**Rationale:**
- Random non-self, non-defeated target.
- MVP nie używa axis-diff filtering (chociaż `generate_idea` zwraca null jeśli `best_diff < IDEA_MIN_AXIS_DIFF`, więc niektóre dispatcha "trafia w pustkę" — to acceptable noise).
- Future plan: smart targeting (theological_trust, axis_diff, faction alignment).

### 5.3 Constants overview

```gdscript
const AI_SCHOLAR_MIN_PRESTIGE := 50
const AI_SCHOLAR_DISPATCH_CHANCE := 0.15
```

Tylko 2 stałe — najmniejszy MVP scope.

---

## Sekcja 6: Integracja w TurnManager

### 6.1 New step `_npc_dispatch_scholars`

```gdscript
func _npc_dispatch_scholars(state: Node) -> void:
	var ai := AIManager.new()
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

**Pipeline placement:** w `process_turn`, PRZED `_process_scholar_missions`. Rationale: nowe missions dispatchowane w tym samym tick'u liczą `turns_remaining` jak normal.

### 6.2 Modified `_process_scholar_missions`

Current:
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

After Plan 18:
```gdscript
func _process_scholar_missions(state: Node) -> void:
	var dm := DoctrineManager.new()
	var ai := AIManager.new()
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
	# Player ideas → pending_ideas (player UI accept/reject — out of scope).
	# NPC ideas → AI auto-resolve.
	if dispatcher_id == state.player_religion_id:
		state.pending_ideas.append(idea)
		return
	var dispatcher: Religion = state.get_religion(dispatcher_id)
	if dispatcher == null or dispatcher.defeated_at_turn != -1:
		return  # NPC defeated mid-mission — drop idea
	if ai.decide_accept_idea(dispatcher, idea):
		dm.accept_idea(idea, dispatcher, state)
	else:
		dm.reject_idea(idea, state)
```

**Note:** `idea.from_religion_id == mission["from_religion_id"] == dispatcher_id` — generate_idea ustawia `idea.from_religion_id = from_religion_id` (czyli dispatcher). Plan 18 używa `mission["from_religion_id"]` jako kanonicznego dispatcher dla czytelności. (Niestandardowa subtelność: `accept_idea` self-guard `idea.from_religion_id != religion.id` skips `absorbed_idea_sources` append gdy dispatcher absorbs own idea — to **intentional**, nie bug.)

### 6.3 Pipeline order po Plan 18

```gdscript
func process_turn(state: Node) -> void:
	# ... istniejące pierwsze etapy ...
	_update_faction_tensions(state)
	_npc_dispatch_scholars(state)        # NEW Plan 18
	_process_scholar_missions(state)     # MODIFIED Plan 18
	_apply_believer_exodus(state)
	# ... reszta bez zmian ...
```

---

## Sekcja 7: Test plan

### Engine — AIManager (~12 nowych testów)

**`tests/engine/test_ai_manager.gd`** (nowy plik):

Helper:
```gdscript
const AIManagerScript := preload("res://scripts/engine/AIManager.gd")

func _make_state(player_id: String = "islam") -> Node:
	# Identyczny pattern do test_victory_manager_*
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize(player_id, religions, graph)
	return gs

func _seeded_rng(seed_val: int = 42) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	return rng

func _make_idea(from_id: String, axis: String, delta: float) -> Idea:
	var idea := Idea.new()
	idea.from_religion_id = from_id
	idea.axis = axis
	idea.delta = delta
	return idea
```

**decide_accept_idea tests:**

- `test_accept_idea_accepts_when_dominant_faction_supports_shift` — Slavic + axis A delta -3 → accept (Wolchwi support).
- `test_accept_idea_rejects_when_dominant_faction_opposes_shift` — Slavic + axis A delta +5 → reject (Wolchwi oppose).
- `test_accept_idea_rejects_on_zero_net_support` — Religion z brakiem axis_preferences na danej osi → reject (conservative).
- `test_accept_idea_uses_faction_influence_weighting` — 2 fake factions: small-influence supporter + large-influence opposer → reject; reverse weights → accept.
- `test_accept_idea_rejects_religion_with_no_factions` — `religion.factions = []` → reject.

**should_dispatch_scholar tests:**

- `test_should_not_dispatch_when_defeated` — `defeated_at_turn = 50` → false.
- `test_should_not_dispatch_when_prestige_below_min` — prestige = 49 (próg ostry 50) → false.
- `test_should_dispatch_deterministic_with_seeded_rng` — seed=42, prestige=100 → deterministic boolean (sprawdź obserwowaną wartość po seed).

**choose_scholar_target tests:**

- `test_choose_scholar_target_returns_non_self` — seeded rng, target ≠ religion.id.
- `test_choose_scholar_target_skips_defeated_religions` — wszystkie inne defeated → "" (lub samo-wybrane jako jedyne kandydaty? — sprawdzić logic).
- `test_choose_scholar_target_returns_empty_when_no_candidates` — wszyscy poza self defeated → "".

### Engine — TurnManager integration (~3 nowe testy)

**`tests/engine/test_turn_manager.gd`** (rozszerzenie):

- `test_npc_scholar_mission_auto_resolves_via_ai_instead_of_pending` — setup: NPC dispatch, advance turns until mission completes; assert `state.pending_ideas` jest puste (NPC idea consumed) i NPC.axes shifted (lub nie, w zależności od decision).
- `test_player_scholar_mission_still_lands_in_pending_ideas` — setup: player dispatch, advance; assert `state.pending_ideas.size() == 1`.
- `test_npc_dispatches_scholar_per_turn_with_seeded_rng` — setup: seed deterministic chance to hit dispatch; advance 1 turn; assert `state.scholar_missions.size() >= 1`.

### Backward compatibility

- Plan 12-17 endgame tests (Plan 14 coptic_citadel, Plan 16 arabian_submission, Plan 17 slavic_sacred_groves) — używają `vm.update_counters` + `vm.check` bezpośrednio, nie `tm.process_turn`. **Bez zmian.**
- Plan 12-17 unit tests (counter increment, faction unity, etc.) — bezpośrednie API calls. **Bez zmian.**
- Istniejące `test_doctrine_manager.gd` i `test_doctrine_manager_idea_sources.gd` używają manualnych Idea + `dm.accept_idea`. **Bez zmian.**
- Istniejące `test_turn_manager.gd` tests — sprawdzić jeśli używają `process_turn` i przyjmują pewną liczbę `pending_ideas` lub `scholar_missions`. **Potencjalna kolizja** — Plan 18 wprowadza NPC behaviors. Mitigacja: w tych testach inject seeded rng do AIManager **lub** mock/disable AI (np. ustawić AI_SCHOLAR_DISPATCH_CHANCE = 0 dla testu).

**Konkretna potencjalna kolizja:** Jeśli `test_turn_manager.gd` ma test wywołujący `tm.process_turn(state)` N razy i asercjujący że `state.scholar_missions.size() == 0`, ten test pęknie po Plan 18 (NPC dispatchują).

**Mitigacja — MANDATORY Task 0 pre-flight:** Enumerate wszystkie `process_turn` call sites w `test_turn_manager.gd` (przewidywane linie 15, 24, 35, 44, 52, 62, 73, 96, 110, 127, 139, 159, 162, 176, 179, 195, 210, 227, 241, 258 — sprawdzić aktualne). Dla każdego: zdecydować czy NPC behavior wpływa na asercje. Opcje izolacji:
1. **Option A (Rekomendowane):** TurnManager przyjmuje opcjonalny `ai: AIManager` w konstruktorze lub jako field z setter. Testy injectują "disabled" AI z `rng.seed = 0` + `randf()` zwraca > 0.15 (efektywnie nigdy dispatch). Production: domyślny `var ai := AIManager.new()`.
2. **Option B:** Test injektuje seeded RNG i pinuje prestige=0 dla NPC religii — gate prestige zablokuje wszystkie dispatch'e.

Wybór architektoniczny: **Option A** (injectable) — wymaga zmiany w pipeline (zamiast `var ai := AIManager.new()` per `_npc_dispatch_scholars` i `_process_scholar_missions`, TurnManager utrzymuje `ai` jako field z lazy-init lub setter). To deviacja od existing pattern (per-step instancjowanie managerów), ale czystość testowania uzasadnia.

**Compromise (Option C):** Zachowaj per-step `AIManager.new()` w produkcji, ale dodaj `_test_ai_override: AIManager` field z setter `set_ai_override(ai)` — production ignoruje (null override → new instance), testy ustawiają via setter. Najmniej inwazyjne.

### Łącznie

~15 nowych testów (12 AIManager + 3 TurnManager integration). Po Plan 18 oczekiwane ~756 testów (741 z Plan 17 + 15 nowych).

---

## Sekcja 8: Otwarte pytania / Future work

### Decyzje implementacyjne (rozstrzygnięte przed planem)

1. **Faction-weighted heuristic** — wybrany nad random i utility-based. Deterministic (po seed), używa istniejących danych, narratywnie sensowne.
2. **Random target dla scholar dispatch** — MVP. Future plan: smart targeting przez theological_trust, axis_diff, faction alignment.
3. **15% dispatch chance, 50 min prestige** — początkowe wartości do playtestingu.
4. **Per-turn AI instancjowanie** — spójne z innymi managerami (`var ai := AIManager.new()` per pipeline step), nie persistent field w TurnManager.
5. **`pending_ideas` queue dla gracza pozostaje orphan** — Plan 18 nie dodaje UI accept/reject. Future plan UI.
6. **Idea semantics** — `idea.from_religion_id` to dispatcher (ustawiony przez `generate_idea(from_religion_id, ...)`). Identyczne z `mission["from_religion_id"]`. Plan 18 używa `mission` jako kanonicznego źródła dla czytelności. Self-guard w `accept_idea` jest intentional (skip self-source absorption).

### Poza zakresem Plan 18

- **War AI** (declare_war, attack_province, offer_peace) — Plan 19+.
- **Diplomacy AI** (alliance, interdict, council, missionary, suzerainty) — Plan 19+.
- **Sobor / edict AI** — Plan 20+.
- **Player UI accept/reject ideas** — UI plan.
- **AI tuning** — playtesting.
- **NPC counter-actions na presję gracza** — Plan 21+.
- **Difficulty levels** — out of scope.
- **AI logging / observability** — Plan 22+.

---

## Sekcja 9: Acceptance criteria

Plan 18 jest gotowy do merge gdy:

1. ✅ Klasa `AIManager` istnieje w `scripts/engine/AIManager.gd` (`extends RefCounted`, stateless).
2. ✅ 2 stałe Plan 18 w `AIManager.gd` (`AI_SCHOLAR_MIN_PRESTIGE`, `AI_SCHOLAR_DISPATCH_CHANCE`).
3. ✅ `AIManager._init(rng: RandomNumberGenerator = null)` przyjmuje opcjonalny seeded RNG.
4. ✅ `AIManager.decide_accept_idea(religion, idea) -> bool` implementuje faction-weighted sum > 0 heurystykę.
5. ✅ `AIManager.should_dispatch_scholar(religion) -> bool` filtruje defeated/poor + RNG gating.
6. ✅ `AIManager.choose_scholar_target(state, religion) -> String` zwraca random non-self non-defeated lub "".
7. ✅ `TurnManager._npc_dispatch_scholars(state)` istnieje i jest wywoływany w `process_turn` przed `_process_scholar_missions`.
8. ✅ `TurnManager._process_scholar_missions` rozróżnia player vs NPC dispatcher i wywołuje `accept_idea`/`reject_idea` dla NPC.
9. ✅ Player ideas wciąż landują w `state.pending_ideas` (no regression).
10. ✅ Istniejące testy Plan 12-17 (~741) pass bez modyfikacji LUB z minimalnym AI isolation mitigation (przesunięte do Task X spec).
11. ✅ ~15 nowych testów (12 AIManager + 3 TurnManager) pass.
12. ✅ Cała suite (~756) pass.
13. ✅ `CLAUDE.md` wzmiankuje Plan 18 (1-liner cross-reference).
14. ✅ Brak zmian w `data/*.json`, `Religion.gd`, `Faction.gd`, `Idea.gd`, `DoctrineManager.gd`, `GameState.gd`, UI.

---

## Sekcja 10: Zależności i ryzyka

**Zależności:**
- DoctrineManager (`dispatch_scholar`, `accept_idea`, `reject_idea`, `generate_idea`) — istnieje w master, niezmieniany.
- TurnManager pipeline (`process_turn`, `_process_scholar_missions`) — istnieje w master, modyfikowany.
- GameState (`scholar_missions`, `pending_ideas`, `player_religion_id`, `all_religions()`) — istnieje, niezmieniany.
- Religion (`factions`, `prestige`, `defeated_at_turn`) — istnieje, niezmieniany.
- Faction (`axis_preferences`, `influence`) — istnieje, niezmieniany.
- Idea (`axis`, `delta`, `from_religion_id`) — istnieje, niezmieniany.

**Ryzyka:**

- **R1: Istniejące `test_turn_manager.gd` testy mogą pęknąć przez wprowadzenie NPC behavior.** Plan 18 zmienia behaviour `process_turn` (dodaje scholar dispatch + idea auto-resolve dla NPC). Testy które wcześniej dawały `state.scholar_missions = []` po N turach mogą teraz dać niepuste.
  - **Mitigacja (Task 0 pre-flight):** Sprawdzić wszystkie testy używające `tm.process_turn`. Dla tych testów: (a) inject seeded RNG z wysokim threshold (efektywnie dispatch=false), lub (b) ustawić `religion.prestige = 0` żeby gate blokował dispatch.
  - **Alternatywnie:** TurnManager przyjmuje opcjonalny `ai: AIManager` parameter — test może pass null/disabled AI.

- **R2: NPC ideas zmienią NPC axes — może wpłynąć na victory conditions innych religii.** Np. test sprawdzający że Manichaeism osiąga `C >= 90`: jeśli NPC AI dispatchuje scholarów do Manichaeism i ideas są akceptowane, C może drift od 90.
  - **Mitigacja:** Endgame tests używają `vm.update_counters + vm.check` bezpośrednio (nie `process_turn`) — nie dotyczy ich (zweryfikowane w §7 backward compat).
  - **Inne testy:** sprawdzić w pre-flight.

- **R3: RNG niedeterminizm w produkcji.** `AIManager.new()` z `randomize()` znaczy że każda gra ma inny seed. To **intended behavior** (replayability), ale wymaga że spec dokumentuje to wprost.
  - **Mitigacja:** Constructor signature `_init(rng = null)` pozwala testom inject seeded RNG. Produkcja używa `AIManager.new()` (default randomized).

- **R4: Performance regression.** Plan 18 dodaje per-turn NPC iteration + `randf()` calls. 11 NPC × 200 tur = 2200 `randf()` calls + dispatch logic. Negligible (Godot easily handles 10⁵ ops/turn).

- **R5: Faction-weighted decision może być too predictable.** Po kilku turach NPC.axes zmierza monotonicznie ku axes preferowanym przez dominującą frakcję. Może być nudne.
  - **Mitigacja (design intent):** Plan 18 MVP. Future plans wprowadzą smart utility + faction tension dynamics (NPC nie zawsze może slate idea — tension cap, prestige cost, etc.).

**Brak ryzyk struktury:**
- AIManager to nowa klasa — nie koliduje z istniejącymi.
- 2 nowe stałe (AI_*) nie kolidują z istniejącymi.
- Zmiany w TurnManager są addytywne (nowy etap + modyfikacja existing function — nie wpływa na inne managery).
