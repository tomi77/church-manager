# Plan 13 — Rozszerzenie warunków zwycięstwa i przegranej

> **Spec dla:** Plan 13 — implementacja deferred items z spec 12 §5/§10:
> 1. **D3 Schizma Totalna** — trzeci warunek przegranej.
> 2. **3 unikalne warunki zwycięstwa** dla religii pominiętych w Plan 12: Chrześcijaństwo Zachodnie, Hinduizm, Buddyzm.
>
> **Wyłączone z zakresu:**
> - **Religie Arabskie** — "Przyjęcie Islamu" wymaga osobnej mechaniki konwersji religii (osobna spec).
> - **Koptyjski Kościół** — wymaga zaprojektowania prowincji `aleksandria` lub przepisania prereq (osobna spec, gdy zostanie podjęta decyzja co do rozszerzenia mapy).
> - **Religie Słowiańskie** — brak słowiańskich prowincji na mapie historycznej (12 middle-east provinces). Wymaga eurazjatyckiego rozszerzenia mapy (spec 12 §10 hint).

---

## Sekcja 1: Kontekst i motywacja

Plan 12 wdrożył 3 uniwersalne warunki zwycięstwa, 6 unikalnych (dla 6 z 12 religii) i 2 warunki przegranej. **Sekcja 5 spec 12** zaznaczyła schizmę totalną jako D3 deferred. **Sekcja 10 spec 12** wymieniła 6 unique victories jako future work — 3 z nich (Western, Hindu, Buddhism) działają na obecnej mapie historycznej (12 prowincji middle-east) i mogą być zaimplementowane w ramach istniejących mechanik (factions, prestige, axes, vassalage, provinces, absorbed_idea_sources). Pozostałe 3 (Arabian, Coptic, Slavic) wymagają osobnych decyzji designu (mechanika konwersji, zmiana fixture'a mapy, rozszerzenie geograficzne).

Cel Plan 13: domknąć możliwe deferred items bez touching mapy lub wprowadzania konwersji religii. Po Plan 13:
- 9 z 12 religii ma unique victory (z Manichaeism, Judaism, Zoroastrianism, East Christianity, Islam, Germanic z Plan 12 + Western, Hindu, Buddhism z Plan 13).
- 3 warunki przegranej (D1 elimination, D2 long_vassalage, D3 total_schism).
- 3 religie pozostają bez unique victory (Arabian, Coptic, Slavic) — osobne plany lub poczekają na expanded map.

---

## Sekcja 2: Cele projektowe

1. **Symetria mechaniki dla feasible religii** — dla religii bez geograficznych blockerów na mapie historycznej dodać unique victory.
2. **Reużycie infrastruktury Plan 12** — nowe warunki używają istniejących pól (`victory_progress`, `defeat_progress`, `ever_owned_province`, `defeated_at_turn`, `defeated_reason`) i pattern (counter z resetem, prereq, evaluate_* + check pipeline).
3. **Flavor-appropriate** — każdy warunek odzwierciedla flavor religii (Reformacja → Western, Dharma → Hindu, Środkowa Droga → Buddhism).
4. **Zero zmian w istniejących Plan 12 testach** — Plan 13 rozszerza, nie modyfikuje istniejących warunków.
5. **Zero zmian w fixture'ach JSON** — Plan 13 nie wymaga nowych prowincji ani modyfikacji religii.

---

## Sekcja 3: Architektura — co zmienia Plan 13

### Modyfikacje istniejące

**`scripts/engine/VictoryManager.gd`:**
- Dodanie 1 stałej dla D3: `SCHISM_TOTAL_TURNS_REQUIRED = 2`.
- Dodanie 7 stałych dla 3 unique victories.
- Rozszerzenie `update_counters` o aktualizację 2 nowych liczników (`total_schism_turns` w defeat_progress, `dharma_turns` w victory_progress).
- Rozszerzenie `evaluate_unique_victory` o 3 nowe klauzule `match religion.id`.
- Rozszerzenie `evaluate_defeat` o D3 `total_schism` przed D2 (precedencja: elimination → total_schism → long_vassalage).
- Nowe helpery: `_western_reformation_satisfied`, `_hindu_dharma_satisfied`, `_buddhism_middle_way_satisfied`.

**`scripts/ui/dialogs/GameOverDialog.gd`:**
- Rozszerzenie `REASON_LABELS` o 4 nowe etykiety (1 defeat + 3 victories).

### Brak nowych klas, brak zmian pól

Wszystkie nowe warunki to czyste rozszerzenia VictoryManager — brak nowych skryptów, brak nowych Resource'ów, brak zmian w Religion/GameState/fixture'ach.

Schema `victory_progress`/`defeat_progress` dict-ów rozszerza się o 2 nowe klucze (extensible Dictionary z Plan 12).

---

## Sekcja 4: D3 — Schizma Totalna (defeat)

### Trigger condition

Religia (z `defeated_at_turn == -1` i `ever_owned_province == true`) spełnia warunek schizma totalna gdy **wszystkie 3 frakcje** mają `tension >= PHASE3_THRESHOLD (85.0)` jednocześnie.

### Counter — `total_schism_turns`

Dodawany do istniejącego `state.defeat_progress[id]` schema:

```gdscript
{"zero_provinces_turns": int, "vassalage_turns": int, "total_schism_turns": int}
```

`update_counters` (Plan 12 §7):
- Inkrementuj `total_schism_turns += 1` gdy wszystkie 3 frakcje >= PHASE3_THRESHOLD.
- Reset `total_schism_turns = 0` gdy choć jedna frakcja spadnie poniżej PHASE3_THRESHOLD.

### Próg defeat

`SCHISM_TOTAL_TURNS_REQUIRED = 2`. Gdy `total_schism_turns >= 2`, `evaluate_defeat` zwraca `"total_schism"`.

**Uzasadnienie 2 tur:** warunek (3 frakcje na 85+ jednocześnie) jest sam w sobie skrajny. 2 tury dają graczowi 1 turę reakcji (stłumienie/dialog/koncesja) zanim defeat. Spójne z duchem D1/D2 (kumulatywne tury), bez nadmiernego rozciągania.

### Precedencja D1 > D3 > D2

`evaluate_defeat` zmienia kolejność checków:
1. `elimination` (D1) — najdefinitywniejsze, 0 prowincji = brak ciała kulturowego
2. `total_schism` (D3) — rozpad doktrynalny, ciało społeczne istnieje ale rozpada się od środka
3. `long_vassalage` (D2) — najmniej dramatyczne, religia istnieje ale podporządkowana

### Prereq

`ever_owned_province == true` (analogicznie do D1/D2). Religia bez własnych prowincji nie podlega — schizma jest fenomenem zinternalizowanej religii kulturowej.

### Reason mapping (UI)

`GameOverDialog.REASON_LABELS["total_schism"] = "Totalna Schizma"`.

---

## Sekcja 5: Unikalne warunki zwycięstwa

Każdy warunek dodany do `evaluate_unique_victory` match-statement (Plan 12 §4.2) w postaci klauzuli `"<religion_id>": if _<religion_specific>_satisfied(religion, state): return "<reason_id>"`.

### 5.1 Chrześcijaństwo Zachodnie — "Reformacja Apostolska"

**Reason ID:** `western_reformation`

**Trigger:**
- Religia kontroluje prowincję `rzym` (Wieczne Miasto, holy_site).
- Co najmniej **4 inne religie** mają `suzerain_id == "western_christianity"` (wasale).
- Prestiż `religion.prestige >= 600`.

**Konstanty:**
- `WESTERN_ROME_ID = "rzym"`
- `WESTERN_VASSALS_REQUIRED = 4`
- `WESTERN_PRESTIGE_REQUIRED = 600`

**Flavor:** Sukcesja Apostolska + dominacja teologiczna nad innymi tradycjami chrześcijańskimi i pogańskimi przez vassal sieć + wyższy prestiż niż starting 500 → "Reformacja Apostolska" jako triumfalne zjednoczenie zachodniego świata.

**Helper:** `_western_reformation_satisfied(religion, state) -> bool`

```gdscript
func _western_reformation_satisfied(religion: Religion, state: Node) -> bool:
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

### 5.2 Hinduizm — "Dharmiczna Trwałość"

**Reason ID:** `hindu_dharma`

**Trigger:**
- Religia kontroluje **≥ 2 prowincje** przez **50 kolejnych tur**.

**Konstanty:**
- `HINDU_PROVINCES_REQUIRED = 2`
- `HINDU_DHARMA_TURNS_REQUIRED = 50`

**Counter:** `dharma_turns` w `state.victory_progress[id]`:

```gdscript
{"domination_turns": int, "prestige_hegemony_turns": int, "dharma_turns": int}
```

**Update logic (`update_counters`):**
- Inkrementuj `dharma_turns += 1` gdy `provinces_with_owner(religion.id).size() >= HINDU_PROVINCES_REQUIRED`.
- Reset `dharma_turns = 0` gdy `< HINDU_PROVINCES_REQUIRED`.

**Flavor:** Hinduizm nie szuka dominacji geograficznej ani prestiżowej hegemonii — szuka długoterminowej trwałości. 50 tur = ¼ TURN_LIMIT, długo ale realnie osiągalne.

**Helper:** `_hindu_dharma_satisfied(religion, state) -> bool`

```gdscript
func _hindu_dharma_satisfied(religion: Religion, state: Node) -> bool:
	var vp: Dictionary = state.victory_progress.get(religion.id, {})
	return vp.get("dharma_turns", 0) >= HINDU_DHARMA_TURNS_REQUIRED
```

**Why 2 prowincje, nie 1:** mapa historyczna ma Hindu z 0 prowincjami startowymi. Próg 2 wymaga ekspansji o conquest — niespecyficzny geograficznie (dowolne 2 z 12 prowincji), realny przez wojnę/wassalage/missionaries. Próg 1 byłby spełniany od momentu pierwszej zdobyczy bez znaczącego wysiłku.

### 5.3 Buddyzm — "Środkowa Droga Globalna"

**Reason ID:** `buddhism_middle_way`

**Trigger:**
- `religion.get_axis("D") >= 90.0` (oś Transcendencja, start 85).
- `religion.absorbed_idea_sources.size() >= 4` (jak Manicheizm).

**Konstanty:**
- `BUDDHISM_AXIS_D_REQUIRED = 90.0`
- `BUDDHISM_DISTINCT_SOURCES_REQUIRED = 4`

**Flavor:** Manicheizm i Buddyzm mają najbardziej synkretyczne profile. Manicheizm idzie w oś C (Syncretism, start 85, prog 90); Buddyzm idzie w oś D (Transcendencja, start 85, prog 90). Symetryczne mechanicznie, różne flavor-thematycznie. Spec 05: trait `middle_way`, akcja `[Dharma-Yatra]` generuje presję — niski koszt absorpcji idei z innych religii.

**Helper:** `_buddhism_middle_way_satisfied(religion, state) -> bool`

```gdscript
func _buddhism_middle_way_satisfied(religion: Religion, state: Node) -> bool:
	if religion.get_axis("D") < BUDDHISM_AXIS_D_REQUIRED:
		return false
	return religion.absorbed_idea_sources.size() >= BUDDHISM_DISTINCT_SOURCES_REQUIRED
```

**Brak prowincjowych prereq** (jak Manicheism) — Buddhism może wygrać z 0 prowincji jeśli osiągnie syncretic transcendencję. Buddhism startuje z 0 prowincjami i `ever_owned_province == false` po `initialize`, więc D1/D2/D3 nie zagrażają mimo brak prowincji. Tylko zdobycie 1 prowincji + późniejsza utrata aktywuje D1 prereq.

---

## Sekcja 6: Modyfikacje danych i kodu

### `scripts/engine/VictoryManager.gd`

**Nowe stałe (dodać po istniejących Plan 12 stałych):**

```gdscript
# === Plan 13: schizma totalna (D3 defeat) ===
const SCHISM_TOTAL_TURNS_REQUIRED := 2

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

**Modyfikacja `update_counters`** — wewnątrz pętli per-religia, po istniejących licznikach Plan 12, dodać 2 nowe:

```gdscript
# Plan 13: total_schism — wszystkie 3 frakcje w fazie 3 (tension >= PHASE3_THRESHOLD)
var all_phase_3: bool = religion.factions.size() == 3
for f: Faction in religion.factions:
	if f.tension < SchismManager.PHASE3_THRESHOLD:
		all_phase_3 = false
		break
if all_phase_3:
	state.defeat_progress[religion.id]["total_schism_turns"] += 1
else:
	state.defeat_progress[religion.id]["total_schism_turns"] = 0

# Plan 13: hindu dharma — kontrola ≥ HINDU_PROVINCES_REQUIRED prowincji
if religion.id == "hinduism":
	if owned >= HINDU_PROVINCES_REQUIRED:
		state.victory_progress[religion.id]["dharma_turns"] += 1
	else:
		state.victory_progress[religion.id]["dharma_turns"] = 0
```

**Modyfikacja default schema** dla `_ensure_progress_entry`:

```gdscript
# victory_progress default (Plan 12 + dharma_turns):
{"domination_turns": 0, "prestige_hegemony_turns": 0, "dharma_turns": 0}

# defeat_progress default (Plan 12 + total_schism_turns):
{"zero_provinces_turns": 0, "vassalage_turns": 0, "total_schism_turns": 0}
```

**Modyfikacja `evaluate_defeat`** — dodać D3 przed D2:

```gdscript
func evaluate_defeat(religion: Religion, state: Node) -> String:
	# Spec §5 + Plan 13 §4: D1, D3, D2 (precedencja).
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

**Modyfikacja `evaluate_unique_victory`** — dodać 3 klauzule:

```gdscript
"western_christianity":
	if _western_reformation_satisfied(religion, state):
		return "western_reformation"
"hinduism":
	if _hindu_dharma_satisfied(religion, state):
		return "hindu_dharma"
"buddhism":
	if _buddhism_middle_way_satisfied(religion, state):
		return "buddhism_middle_way"
```

### `scripts/ui/dialogs/GameOverDialog.gd`

**Rozszerzenie REASON_LABELS:**

```gdscript
"total_schism": "Totalna Schizma",
"western_reformation": "Reformacja Apostolska (Chrześcijaństwo Zachodnie)",
"hindu_dharma": "Dharmiczna Trwałość (Hinduizm)",
"buddhism_middle_way": "Środkowa Droga Globalna (Buddyzm)",
```

### `scripts/ui/MainShell.gd`

**Bez zmian.** `_show_player_defeat_dialog` używa `player.defeated_reason` (Plan 12 fix I3) — pobierze nowy reason `"total_schism"` automatycznie.

### `scripts/engine/Religion.gd`

**Bez zmian w polach.** Plan 12 pole `defeated_reason: String` obsłuży nowy "total_schism".

### `scripts/engine/GameState.gd`

**Bez zmian w polach.** `reset()` nie wymaga aktualizacji — dict-y `victory_progress`/`defeat_progress` są clearowane całe.

### `data/`

**Bez zmian w fixture'ach JSON.** Plan 13 używa istniejących prowincji (`rzym`) i istniejących pól religii (axes, factions, suzerain_id, absorbed_idea_sources).

---

## Sekcja 7: Test plan

### Engine (~20 nowych testów)

**`tests/engine/test_victory_manager_constants.gd`** — rozszerzenie:
- `test_plan13_constants_exist` — 8 nowych stałych z asercjami wartości.

**`tests/engine/test_victory_manager_flags.gd`** — rozszerzenie (update_counters):
- `test_update_counters_initializes_dharma_turns_zero` — domyślnie 0 w victory_progress.
- `test_update_counters_initializes_total_schism_turns_zero`.
- `test_update_counters_increments_total_schism_when_all_three_factions_phase_3`.
- `test_update_counters_resets_total_schism_when_one_faction_drops_below_phase_3`.
- `test_update_counters_total_schism_requires_3_factions` — religia z != 3 frakcjami (edge case) nie inkrementuje.
- `test_update_counters_increments_dharma_when_hindu_owns_2_provinces` — Hindu z 2 prowincji.
- `test_update_counters_resets_dharma_when_hindu_owns_only_1_province`.
- `test_update_counters_only_increments_dharma_for_hinduism` — inne religie nie dotyczą.

**`tests/engine/test_victory_manager_unique.gd`** — rozszerzenie:
- `test_western_reformation_requires_rome_4_vassals_and_prestige_600` — happy path.
- `test_western_reformation_blocked_without_rome`.
- `test_western_reformation_blocked_with_3_vassals` — próg ostry.
- `test_western_reformation_blocked_with_prestige_599`.
- `test_hindu_dharma_requires_50_turns_counter` — sprawdza tylko evaluator.
- `test_hindu_dharma_blocked_with_49_turns`.
- `test_buddhism_middle_way_requires_D_90_and_4_sources`.
- `test_buddhism_middle_way_blocked_with_D_89`.
- `test_buddhism_middle_way_blocked_with_3_sources`.
- `test_buddhism_can_win_with_zero_provinces` — analog Manichaeism.

**`tests/engine/test_victory_manager_defeat.gd`** — rozszerzenie:
- `test_total_schism_returns_reason_at_threshold`.
- `test_total_schism_blocked_without_ever_owned_province`.
- `test_total_schism_blocked_one_below_threshold`.
- `test_elimination_takes_precedence_over_total_schism` — D1 > D3.
- `test_total_schism_takes_precedence_over_long_vassalage` — D3 > D2.

**`tests/engine/test_victory_manager_endgame.gd`** — rozszerzenie:
- `test_check_marks_total_schism_with_defeated_reason` — `defeated_reason == "total_schism"` po `check`.

### UI (~1 nowy test)

**`tests/ui/test_game_over_dialog.gd`** — rozszerzenie:
- Update `test_dialog_maps_all_reasons_to_non_empty_polish_labels` (Plan 12) — dodać 4 nowe reasony do listy: `"total_schism"`, `"western_reformation"`, `"hindu_dharma"`, `"buddhism_middle_way"`.

### Backward compatibility

- Plan 12 testy: bez zmian (Plan 13 tylko dodaje, nie modyfikuje).
- Religie inne niż 3 wymienionych w Plan 13: `evaluate_unique_victory` zwraca `""` (default branch w match).
- Defeated religions: skip identyczny jak Plan 12.
- Religie pominięte w Plan 13 (Arabian, Coptic, Slavic): mogą wygrać uniwersalnie (domination/hegemony/holy_land) — Plan 13 nic nie blokuje.

---

## Sekcja 8: Otwarte pytania / Future work

### W zakresie Plan 13 — do rozstrzygnięcia podczas implementacji

1. **Liczniki dla wszystkich religii vs tylko relevant?** `dharma_turns` jest sensowne tylko dla Hindu.
   - **A: licznik dla wszystkich** (jak `domination_turns`) — leniwy default w `_ensure_progress_entry`, każdy update_counter inkrementuje swój. Spójne z Plan 12 dictionary schema.
   - **B: tylko relevant** (`if religion.id == "hinduism": ...`) — oszczędza pamięć, kod bardziej "switchowy".
   - **Recommended: A** — spójność z Plan 12, koszt pamięci pomijalny (1 int per religia), `_ensure_progress_entry` już ma ten pattern.

2. **`total_schism_turns` dla wszystkich religii?** Liczy się dla każdej religii bo każda może mieć 3 frakcje. Default schema includes it.

3. **Schizma w trakcie liczenia total_schism_turns** — gdy player/AI triggeruje schism na frakcji w fazie 3, frakcja znika z parent religion. Następna `update_counters` zobaczy 2 frakcje, `factions.size() == 3` false → counter reset. To zamierzone — schizma JEST sposobem na uniknięcie total_schism defeat.

### Poza zakresem Plan 13

- **Religie Arabskie — "Przyjęcie Islamu"** — wymaga mechaniki konwersji religii (kto wygrywa? player przejmuje Islam? co z prowincjami?). Osobna spec (kandydat Plan 14+).
- **Koptyjski Kościół — "Pustelnictwo Powszechne"** — wymaga decyzji co do prowincji aleksandria (dodać do fixture'a lub zmienić prereq). Osobna spec.
- **Religie Słowiańskie — "Ziemia Świętych Gajów"** — brak słowiańskich prowincji na mapie historycznej. Czeka na eurazjatyckie rozszerzenie mapy (spec 12 §10 hint).
- **Zjednoczenie ChrZ + ChrW przez sobór** — spec 12 §10 punkt 4.
- **Mapa eurazjatycka** — rekalibracja progów (gdy >20 prowincji).
- **Wskaźnik postępu warunków w UI** — spec 12 §10 punkt 7.
- **Coalition victory** — spec 12 §10 punkt 6.

---

## Sekcja 9: Acceptance criteria

Plan 13 jest gotowy do merge gdy:

1. Wszystkie 3 unique victories triggerują się gdy spełnione warunki (jeden test happy-path per religia).
2. Każdy unique victory blokowany na każdym z osobnych warunków (per-condition negative tests).
3. D3 schizma totalna triggeruje po 2 turach z 3 frakcjami w fazie 3.
4. D3 reset gdy choć jedna frakcja spadnie z fazy 3.
5. Precedencja D1 > D3 > D2 zachowana (test elimination wins vs total_schism).
6. `defeated_reason == "total_schism"` ustawione gdy D3.
7. GameOverDialog wyświetla polskie etykiety dla wszystkich 4 nowych reasonów.
8. Existing 654 tests + ~20 nowych = ~674 testów wszystkie passing.
9. CLAUDE.md / spec 12 wzmiankuje Plan 13 (cross-reference do tej spec, opcjonalnie).

---

## Sekcja 10: Zależności i ryzyka

**Zależności:**
- Plan 12 (VictoryManager, GameOutcome, GameOverDialog, defeated_reason) — wymagane, w master.
- SchismManager.PHASE3_THRESHOLD — istniejące (= 85.0).
- `data/provinces_historical.json` musi mieć: `rzym`. Zweryfikowane — istnieje.

**Ryzyka:**
- **R1: Buddhism axis D start = 85, prog = 90 — różnica 5 punktów**. Wymaga shift_axis(D, +5) np. przez akceptację 1-2 idei boostujących D. Realistyczne — Buddhism start już blisko progu, mechanika doctrine system ułatwia.
- **R2: Hindu 0 prowincji startowo** — musi zdobyć minimum 2. 50 tur to dłuższy horyzont; w typowej rozgrywce do tury 50 conquest by missionaries/war jest realny.
- **R3: Western Christianity 4 wasali** — istniejący system vassalage (Plan 06/07) musi pozwalać na 4 równoczesnych. Sprawdzić że żaden cap nie blokuje.

**Mitigacja R3:** Pierwszy task planu = sanity check że DiplomacyManager/RelationState nie ma `MAX_VASSALS_PER_SUZERAIN` constraint. Jeśli ma, podnieść lub dokumentować jako known limit.
