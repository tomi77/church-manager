# Plan 16 — Przyjęcie Islamu (Religie Arabskie)

> **Spec dla:** Plan 16 — domknięcie deferred item z spec 13 §10 (Arabian Paganism). Implementuje 11. unique victory: doktrynalna mimikra profilu islamskiego.
>
> **W zakresie:**
> 1. 7 stałych Plan 16 w `VictoryManager.gd`.
> 2. Counter `arabian_submission_turns` w `state.victory_progress` schema.
> 3. Klauzula `evaluate_unique_victory` dla `arabian_paganism`.
> 4. Predykat helper `_arabian_submission_satisfied`.
> 5. REASON_LABELS["arabian_submission"] w `GameOverDialog.gd`.
>
> **Wyłączone z zakresu:**
> - Mechanika "transformacji" Arabian → Islam (zmiana religion.id, trait, factions, color) — odrzucone na rzecz doktrynalnej mimikry.
> - Religie Słowiańskie — "Ziemia Świętych Gajów" (osobna spec, wymaga ekspansji mapy eurazjatyckiej).
> - Nowe narzędzia doktrynalne dla shiftu osi — gracz używa istniejących mechanik (idea acceptance, faction support, doctrine pressure).
> - Holy site rebalancing — mekka pozostaje Arabian holy site; Islam nadal `holy_sites = ["mekka", "jerozolima"]`.
> - Tuning thresholdów po playtestingu (próg 15 tur, axes 65/60/35/70) — odłożone do balance review.

---

## Sekcja 1: Kontekst i motywacja

Plan 13 (Sekcja 10) wymienił Religie Arabskie jako deferred — unique victory "Przyjęcie Islamu" wymagało **decyzji designu o mechanice konwersji**. Stan po Plan 14/15:

- 10 z 12 religii ma unique victory (Plan 12: 6, Plan 13: +3, Plan 14: +1 Coptic).
- Religie Arabskie i Słowiańskie pozostają bez unique victory.
- Arabian Paganism ma 3 prowincje (mekka, arabia_polnocna, jemen po Plan 15), 3 frakcje, holy_site mekka, axes startowe A=25 B=30 C=55 D=45.
- Islam istnieje jako osobna religia (axes 70/65/30/75, holy_sites mekka+jerozolima, profile niemal "lustrzane" do Arabian).

Plan 16 wybiera **doktrynalną mimikrę** jako interpretację "przyjęcia Islamu":
- Arabian zachowuje swój `religion_id`, prowincje, frakcje, trait, color.
- Warunek wygranej = osie Arabian zbliżyły się do profilu islamskiego (A↑, B↑, C↓, D↑) na trwałe.
- Mekka pozostaje pod kontrolą Arabian jako narratywny anchor (historyczna kolebka Islamu).

Po Plan 16:
- 11 z 12 religii ma unique victory.
- Religie Słowiańskie pozostają jako jedyna bez unique victory (czekają na ekspansję mapy).
- Zero zmian w fixturze, engine logic, UI poza dodaniem 1 etykiety reason.

---

## Sekcja 2: Cele projektowe

1. **Domknięcie deferred item** — Arabian dostaje unique victory dopasowane do profilu doktrynalnego (low A, B, D start z trait `tribal_pluralism`, faction preferences PRZECIWSTAWNE islamskiej osi).
2. **Minimalna zmiana mechaniki** — Plan 16 to wyłącznie counter + predykat + label. Zero nowych klas, fixture'ów, manager methods.
3. **Spójność z istniejącym pattern Plan 13/14** — counter w `update_counters`, predykat reads counter, klauzula `evaluate_unique_victory`, label w REASON_LABELS.
4. **Wbudowana design tension** — wszystkie 3 startowe frakcje Arabian opozycjonują islamską oś (axis_preferences). Gracz musi shiftować axes wbrew faction preferences → faction tension rośnie → ryzyko schizmy → D3 defeat threat. Krótszy counter (15 tur vs Coptic 20) kompensuje wyższą trudność utrzymania warunków.
5. **Zero collateral damage** — Plan 16 nie zmienia zachowania żadnego innego unique victory, defeat, ani uniwersalnego warunku.

---

## Sekcja 3: Architektura — co zmienia Plan 16

### Modyfikacje istniejące

**`scripts/engine/VictoryManager.gd`:**
- Dodanie 7 stałych dla Arabian (§5.3).
- Rozszerzenie schema w `_ensure_progress_entry(state.victory_progress, ...)` o `"arabian_submission_turns": 0`.
- Rozszerzenie `update_counters` o gałąź `if religion.id == "arabian_paganism"` z inkrementem/resetem `arabian_submission_turns`.
- Rozszerzenie `evaluate_unique_victory` o klauzulę `"arabian_paganism":`.
- Nowy helper `_arabian_submission_satisfied(religion, state) -> bool`.

**`scripts/ui/dialogs/GameOverDialog.gd`:**
- Rozszerzenie `REASON_LABELS` o 1 etykietę: `"arabian_submission": "Przyjęcie Islamu (Religie Arabskie)"`.

### Brak nowych klas, brak zmian fixture, brak zmian innych managerów

- `Religion.gd`, `Faction.gd`, `Province.gd` — bez zmian.
- `data/religions_historical.json`, `data/provinces_historical.json` — bez zmian.
- `DoctrineManager`, `SchismManager`, `TurnManager`, `DiplomacyManager`, `WarManager` — bez zmian.
- UI poza GameOverDialog — bez zmian.

---

## Sekcja 4: Warunek "Przyjęcie Islamu"

### 4.1 Reason ID

`arabian_submission`

Etymologia: Islam (arab. اسلام) = "poddanie się" (woli Boga). "Przyjęcie Islamu" przez Arabian = akt poddania doktrynalnego.

Pattern naming spójny z istniejącymi reason IDs (manichaeism_illumination, hindu_dharma, coptic_citadel).

### 4.2 Trigger condition

Religia `arabian_paganism` spełnia warunek gdy **wszystkie z poniższych** są true:

1. `mekka` istnieje w ProvinceGraph i `mekka.owner == "arabian_paganism"`.
2. `religion.get_axis("A") >= 65.0` (Islam reference: 70.0).
3. `religion.get_axis("B") >= 60.0` (Islam reference: 65.0).
4. `religion.get_axis("C") <= 35.0` (Islam reference: 30.0).
5. `religion.get_axis("D") >= 70.0` (Islam reference: 75.0).
6. `religion.factions.size() >= 3` (żadna z 3 startowych frakcji nie odpadła przez schizmę).
7. **Trwałość:** powyższe 6 warunków utrzymane przez ≥ 15 tur (counter `arabian_submission_turns`).

### 4.3 Stałe

```gdscript
const ARABIAN_MEKKA_ID := "mekka"
const ARABIAN_AXIS_A_REQUIRED := 65.0
const ARABIAN_AXIS_B_REQUIRED := 60.0
const ARABIAN_AXIS_C_MAX := 35.0
const ARABIAN_AXIS_D_REQUIRED := 70.0
const ARABIAN_ACTIVE_FACTIONS_REQUIRED := 3
const ARABIAN_SUBMISSION_TURNS_REQUIRED := 15
```

### 4.4 Flavor i design intent

**Doktrynalna mimikra:** Arabian musi osiągnąć profile axes zbliżone do Islamu. Startując z A=25 B=30 C=55 D=45, gracz musi:
- A: +40 do ≥65 (Dogmatism)
- B: +30 do ≥60 (Hierarchy)
- C: −20 do ≤35 (Syncretism — KIERUNEK PRZECIWNY do C=55 start)
- D: +25 do ≥70 (Transcendence)

**Mechanika opozycji frakcji** — kluczowa design tension:
- Strażnicy Kaaby (40% influence): `axis_preferences C+1, B−1` — PRZECIWNE do C≤35 oraz B≥60.
- Kapłani Plemienni (35%): `B−1` — PRZECIWNE do B≥60.
- Kupcy i Wędrowcy (25%): `C+1` — PRZECIWNE do C≤35.

Każda akcja shifting axis "w stronę islamską" konfliktuje z preferencjami któreś z frakcji → tension rośnie → ryzyko phase escalation (Plan 13 §5: phase 1 ≥60, phase 2 ≥80, phase 3 ≥95 + 2-turn trigger).

**Próg 15 tur** (vs Coptic 20, Hindu 50) — kompensuje wyższą trudność. Zestaw 6 warunków jednocześnie + dynamika opposition + zagrożenie D3 defeat = bardzo wymagający warunek.

**Mekka jako anchor** — Arabian zaczyna z mekka. Utrzymanie mekki przez 15 tur w grze z Islamem (mezopotamia jako sąsiad arabia_polnocna) + presją Eastern (lewant) = realne ryzyko utraty. Mekka.is_holy_site = true daje passive prestige → korzyść strategiczna, ale i target dla wrogów.

### 4.5 Counter — `arabian_submission_turns`

Dodawany do istniejącego schema `state.victory_progress[religion.id]`:

```gdscript
{"domination_turns": int, "prestige_hegemony_turns": int, "dharma_turns": int, "coptic_citadel_turns": int, "arabian_submission_turns": int}
```

`update_counters` (wzorzec analogiczny do `coptic_citadel_turns` w Plan 14 §5.5):

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

Dla religii innych niż arabian_paganism: brak inkrementu → counter zostaje 0 przez całą grę (analog `coptic_citadel_turns` dla nie-Coptic).

### 4.6 Helper `_arabian_submission_satisfied(religion, state) -> bool`

```gdscript
func _arabian_submission_satisfied(religion: Religion, state: Node) -> bool:
	# Counter arabian_submission_turns aktualizowany w update_counters.
	var vp: Dictionary = state.victory_progress.get(religion.id, {})
	return vp.get("arabian_submission_turns", 0) >= ARABIAN_SUBMISSION_TURNS_REQUIRED
```

Wzór z `_hindu_dharma_satisfied` (Plan 13) i `_coptic_citadel_satisfied` (Plan 14) — predykat reads counter, faktyczne warunki ewaluuje `update_counters`. Gwarantuje spójność: nie da się "udać" 15 tur w jednej turze.

### 4.7 Prereq i integracja z `evaluate_unique_victory`

`evaluate_unique_victory` (Plan 12 §4.2) ma już prereq `not religion.is_defeated() and religion.player_controlled`. Plan 16 dodaje klauzulę:

```gdscript
"arabian_paganism":
	if _arabian_submission_satisfied(religion, state):
		return "arabian_submission"
```

Klauzula umieszczona w `match religion.id` po istniejących klauzulach (kolejność: manichaeism, judaism, zoroastrianism, eastern_christianity, islam, germanic_paganism, western_christianity, hinduism, buddhism, coptic_christianity, arabian_paganism).

### 4.8 Reason mapping (UI)

`GameOverDialog.REASON_LABELS["arabian_submission"] = "Przyjęcie Islamu (Religie Arabskie)"`.

Format spójny z Plan 13/14 (`"Reformacja Apostolska (Chrześcijaństwo Zachodnie)"`, `"Cytadela Pustelnicza (Koptyjski Kościół)"`).

---

## Sekcja 5: Test plan

### Engine — stałe (~1 test)

**`tests/engine/test_victory_manager_constants.gd`** — rozszerzenie:
- `test_plan16_constants_exist` — 7 nowych stałych z asercjami wartości (MEKKA_ID="mekka", A_REQ=65.0, B_REQ=60.0, C_MAX=35.0, D_REQ=70.0, FACTIONS_REQ=3, TURNS_REQ=15).

### Engine — counter (~7 testów)

**`tests/engine/test_victory_manager_flags.gd`** — rozszerzenie:
- `test_update_counters_initializes_arabian_submission_turns_zero` — domyślnie 0 w victory_progress.
- `test_update_counters_increments_arabian_submission_when_all_6_conditions_met` — happy path: ustaw mekka.owner + 4 axes + 3 factions → counter rośnie.
- `test_update_counters_resets_arabian_submission_when_mekka_lost` — utrata mekki (owner=islam) → counter=0.
- `test_update_counters_resets_arabian_submission_when_axis_A_drops_to_64` — próg ostry (≥65, nie >64).
- `test_update_counters_resets_arabian_submission_when_axis_C_rises_to_36` — próg ostry (≤35, nie <36).
- `test_update_counters_resets_arabian_submission_when_faction_count_drops_to_2` — utrata frakcji przez schizmę.
- `test_update_counters_only_increments_arabian_submission_for_arabian_paganism` — inne religie nie dotyczą (counter zostaje 0).

### Engine — predykat (~3 testy)

**`tests/engine/test_victory_manager_unique.gd`** — rozszerzenie:
- `test_arabian_submission_requires_15_turns_counter` — happy path (counter == 15, predykat zwraca `"arabian_submission"`).
- `test_arabian_submission_blocked_with_14_turns` — próg ostry (≥15, nie >14).
- `test_arabian_submission_other_religion_never_returns_reason` — sanity: Islam z spreparowanym `victory_progress["islam"]["arabian_submission_turns"] = 30` nie zwraca `"arabian_submission"` (brak case'a w match).

### Engine — endgame integracja (~1 test)

**`tests/engine/test_victory_manager_endgame.gd`** — rozszerzenie:
- `test_check_marks_arabian_submission_with_game_outcome` — pełna integracja: ustaw warunki, advance turn 15x, sprawdź `state.game_outcome.winner_id == "arabian_paganism"` i `game_outcome.reason == "arabian_submission"`.

### UI — REASON_LABELS (rozszerzenie istniejącego ~1 test)

**`tests/ui/test_game_over_dialog.gd`** — rozszerzenie:
- Aktualizacja `test_dialog_maps_all_reasons_to_non_empty_polish_labels` — dodać `"arabian_submission"` do listy weryfikowanych reasonów. Asercja: label zawiera `"Przyjęcie Islamu"` lub `"Religie Arabskie"`.

### Backward compatibility

- Plan 12/13/14/15 testy: bez zmian. Plan 16 tylko dodaje counter + predykat + label.
- Wszystkie wcześniejsze warunki (3 universal, 10 unique z Plan 12+13+14, D1/D2/D3 defeats) — bez zmian zachowania.
- Religie inne niż Arabian: counter `arabian_submission_turns` istnieje w schema ale pozostaje 0 — gałąź `update_counters` filtruje po religion.id.
- Brak zmian fixture'a → wszystkie testy fixture/loader bez wpływu.

### Łącznie

~13 nowych testów engine + 1 modyfikacja UI testu. Po Plan 16 oczekiwane ~721 testów (708 z Plan 15 + 13 nowych engine, UI patch w istniejącym teście).

---

## Sekcja 6: Otwarte pytania / Future work

### Decyzje implementacyjne (rozstrzygnięte przed planem)

1. **Reason ID `arabian_submission`** — etymologicznie poprawny (Islam = "submission"), pattern spójny z istniejącymi. Alternatywa `arabian_islamic_adoption` odrzucona jako dłuższa/mniej kanoniczna.

2. **Mekka jako wymagany owner** — Arabian startuje z mekka. Utrata mekki podczas 15-turowego okna = counter reset. Mekka jest też holy site Islam → naturalna wrogość Islam wobec Arabian utrzymującego mekka jako Pagan. Acceptable design tension.

3. **`factions.size() >= 3` jako proxy "faction survival"** — Faction.gd nie ma `defeated` flagi; schizma usuwa frakcję z `religion.factions` array (`SchismManager.gd:68: religion.factions.erase(faction)`). Sprawdzanie size() jest robust i tanie.

4. **Counter 15 tur (vs Hindu 50, Coptic 20)** — wybór designerski oparty na wyższej trudności (6 warunków jednocześnie + opposition frakcji). Tuning odłożony do playtestingu.

5. **Axis thresholds 65/60/35/70 (Islam: 70/65/30/75)** — margines 5 punktów daje "comfort zone" dla minor fluctuations. Stricter (70/65/30/75) byłby zbyt podatny na chwilowe wahnięcia; bardziej liberalny (60/55/40/65) trywializowałby warunek.

### Poza zakresem Plan 16

- **Religie Słowiańskie — "Ziemia Świętych Gajów"** — wymaga ekspansji mapy eurazjatyckiej (kijów, nowogród, morawy). Osobna spec.
- **UI wskaźnik postępu `arabian_submission_turns`** — analog `dharma_turns`/`coptic_citadel_turns`. Future UI feature.
- **Faction "conversion" mechanic** — pomysł: gdy Arabian osiąga axes islamskie, frakcje też transformują się (np. Strażnicy → Ulema). Out of scope; obecnie frakcje zachowują startowe ID/preferences.
- **Re-balance progu 15 tur i thresholdów axes** — początkowe wartości, do tuningu po playtestach.
- **Visual indication w MapTab** — np. prowincje Arabian "lśnią" gdy spełnione wszystkie 6 warunków. Future feature.

---

## Sekcja 7: Acceptance criteria

Plan 16 jest gotowy do merge gdy:

1. ✅ 7 stałych Plan 16 istnieje w `VictoryManager.gd`.
2. ✅ Counter `arabian_submission_turns` w `victory_progress` poprawnie inkrementuje gdy spełnione 6 warunków z §4.2 (1-6) i religia to Arabian; resetuje gdy choć jeden niespełniony; pozostaje 0 dla innych religii.
3. ✅ `evaluate_unique_victory` dla Arabian z `arabian_submission_turns >= 15` zwraca `"arabian_submission"`.
4. ✅ `state.game_outcome.winner_id == "arabian_paganism"` AND `game_outcome.reason == "arabian_submission"` po `check()` gdy gracz Arabian wygra.
5. ✅ `GameOverDialog.REASON_LABELS["arabian_submission"]` zwraca polską etykietę zawierającą `"Przyjęcie Islamu"` i `"Religie Arabskie"`.
6. ✅ Pre-existing testy Plan 12/13/14/15 (~708 po Plan 15) — wszystkie pass bez modyfikacji.
7. ✅ ~13 nowych testów engine (constants/flags/unique/endgame) + 1 modyfikacja UI testu — wszystkie pass.
8. ✅ Cała suite (~721 testów) pass.
9. ✅ Brak zmian w fixturze (`data/*.json`), engine managerach (poza VictoryManager), UI poza GameOverDialog.
10. ✅ `CLAUDE.md` wzmiankuje Plan 16 (1-liner cross-reference w bullet "End-of-game flow").

---

## Sekcja 8: Zależności i ryzyka

**Zależności:**
- Plan 12 (VictoryManager pipeline, GameOutcome, GameOverDialog, `_ensure_progress_entry`) — w master.
- Plan 13 (`victory_progress[id]` dictionary schema, pattern counter+predykat dla Hindu/Buddhism/Western) — w master.
- Plan 14 (pattern dla Coptic citadel: counter w update_counters per-religion gałąź + predykat reads counter + REASON_LABELS) — w master.
- Plan 15 (jemen jako 2. prowincja Arabian — kontekst, nie blocker; Arabian wciąż ma mekka jako holy site) — w master.
- `data/religions_historical.json` — Arabian Paganism profile istnieje, niezmieniany.

**Ryzyka:**

- **R1: Axes shift przeciwny preferencjom wszystkich 3 frakcji.** Każda akcja podnosząca A, B, D lub obniżająca C generuje tension u co najmniej jednej frakcji. Faction tension rośnie → ryzyko phase escalation → ryzyko schizmy → reset counter (faction count < 3) lub D3 defeat (3 frakcje w phase 3 przez 2 tury).
  - **Mitigacja (design intent):** Plan 16 nie dodaje narzędzi przeciwdziałania — gracz używa idea filtering, faction support actions (z DoctrineManager Plan 02), strategic pacing. To CECHA tego unique victory, nie bug.

- **R2: Utrata mekki podczas 15-turowego okna.** Mekka sąsiaduje z lewant (Eastern), arabia_polnocna (Arabian sąsiad), jemen (Arabian — Plan 15). Bezpośredni sąsiedzi nie są Islam. Ale: Islam (mezopotamia) sąsiaduje z arabia_polnocna → indirect threat path. War, missionary pressure z Islam mogą podgryzać Arabian core.
  - **Mitigacja:** Arabian uses war system, alliances, vassalage do obrony. Out of Plan 16 scope.

- **R3: Counter race z D1 defeat (zero provinces, 3 tury).** Jeśli Arabian straci 3 prowincje, D1 defeat triggers przed unique victory. Kolejność check w `VictoryManager.check()`:
  1. `evaluate_defeat` (D1/D2/D3)
  2. `evaluate_unique_victory` (per religia)
  3. `evaluate_universal_victory` (domination/hegemony/holy_land)

  Defeat wygrywa kolejnościowo. To intended — gracz "przegrał" zanim mógłby "wygrać".

- **R4: Player może triwializować przez idea spamming.** Jeśli player ma dostęp do idei z impactem A+1 B+1 C-1 D+1, może pumpować osie szybko ignorując frakcje (do pewnego stopnia).
  - **Mitigacja:** Idea acceptance mechanic z Plan 02/13 — idee wymagają faction approval lub dają faction tension. System samoreguluje (do tuningu).

**Mitigacja ryzyk:**
- R1, R2, R3, R4 to **design intent** — Plan 16 unique victory ma być wymagający. Tuning progów odłożony do playtestingu (§6 future work).

**Brak ryzyk struktury:**
- Schema `victory_progress` jest extensible Dictionary — dodanie `arabian_submission_turns` nie psuje istniejących kluczy.
- Match w `evaluate_unique_victory` ma default branch (zwraca `""`) — nowy case nie wpływa na istniejące religie.
- Stałe Plan 16 nie kolidują z istniejącymi (prefix ARABIAN_, brak overlapu z ISLAM_*, COPTIC_*, etc.).
