# Plan 17 — Ziemia Świętych Gajów (Religie Słowiańskie)

> **Spec dla:** Plan 17 — domknięcie deferred item z spec 13 §10 (Slavic Paganism). Hybryda Plan 14 (unique victory) + Plan 15 (map expansion). 12. i ostatnia unique victory.
>
> **W zakresie:**
> 1. Dodanie 7 prowincji do `data/provinces_historical.json` (arkona, gnieszno, morawy, panonia, gardariki, nowogrod, kijow) — pełny Slavic heartland.
> 2. Mutual edge `panonia ↔ tracja` (jedyne połączenie nowej mapy z istniejącą).
> 3. Stałe Plan 17 w `VictoryManager.gd`.
> 4. Counter `slavic_sacred_groves_turns` w `state.victory_progress` schema.
> 5. Klauzula `evaluate_unique_victory` dla `slavic_paganism`.
> 6. Predykat helper `_slavic_sacred_groves_satisfied`.
> 7. `REASON_LABELS["slavic_sacred_groves"]` w `GameOverDialog.gd`.
>
> **Wyłączone z zakresu:**
> - Re-balance progu `DOMINATION_PROVINCE_SHARE` (po 19→26 prowincji threshold rośnie 10→13). Świadome — recalibration odłożona do playtestingu.
> - Nowe traity / faction profiles Slavic (Wolchwi/Plemienna/Herosi z istniejącego JSON pozostają niezmienione).
> - Morskie / dalekosiężne edges (nowogrod ↔ konstantynopol Varangian route, kijow ↔ persja Khazaria) — geograficzne uproszczenie.
> - Karolingowie / Lombardowie / Awarowie jako osobne religie — pressure values w nowych prowincjach to "design hooks" bez nowej mechaniki.
> - Tuning progów (axes ≤30, 20 tur) — do playtestingu.

---

## Sekcja 1: Kontekst i motywacja

Plan 13 (Sekcja 10) wymienił Religie Słowiańskie jako deferred — unique victory wymagała **ekspansji mapy** (kijów, nowogród, morawy). Stan po Plan 14/15/16:

- 11 z 12 religii ma unique victory (Plan 12: 6, Plan 13: +3, Plan 14: +1 Coptic, Plan 16: +1 Arabian).
- Religie Słowiańskie pozostają jako **jedyna** bez unique victory.
- Slavic ma w fixturze: profile (axes A=20 B=25 C=65 D=55, trait `blood_and_soil`, 3 frakcje), holy_site `arkona` zadeklarowane w `religions_historical.json` ale **prowincja arkona nie istnieje** w `provinces_historical.json` (silent — analog aleksandria przed Plan 14).
- Slavic ma 0 prowincji w obecnym fixturze. Wystarcza jedna tura by `defeated_at_turn` było ustawione (D1: zero provinces × 5 tur). Slavic jest de facto eliminated od początku gry.
- Plan 15 dodał tracja z `pressure["slavic_paganism"] = 25.0` jako "design hook" dla przyszłego Slavic expansion — Plan 17 ten hook realizuje.

Po Plan 17:
- 12/12 religii ma unique victory — kompletne pokrycie.
- Slavic startuje z 7 prowincjami (heartland eurazjatycki).
- Mapa rośnie 19 → 26 prowincji.
- `arkona` istnieje jako holy site (waluuje `religions_historical.json:holy_sites`).
- Nowa krawędź `panonia ↔ tracja` łączy Slavic heartland z istniejącą mapą.

---

## Sekcja 2: Cele projektowe

1. **Domknięcie deferred item** — Slavic dostaje viable startową pozycję (7 prowincji) + unique victory dopasowane do profilu (low A/B = anti-Christianization, trait `blood_and_soil` = territorialność).
2. **Pełny Slavic heartland** — 7 prowincji obejmuje archeologicznie / historycznie spójny region: zachód (arkona Wendowie, gnieszno Polacy, morawy Czesi/Słowacy), środek (panonia Awarowie/Słowianie), wschód (gardariki/kijow/nowogrod precursor Rusi).
3. **Pojedynczy entry point z istniejącej mapy** — tylko `panonia ↔ tracja` łączy Slavic heartland z resztą mapy. Inne religie muszą przejść przez tracja by zaatakować Slavic.
4. **Spójność z Plan 14 unique victory pattern** — counter + predykat + label. Spójność z Plan 15 fixture expansion (JSON spaces, neighbors mutual).
5. **Zero zmian innych managerów / fixture'ów** — Slavic profile w `religions_historical.json` nietknięty (jak Plan 16 dla Arabian).

---

## Sekcja 3: Architektura — co zmienia Plan 17

### Modyfikacje fixture

**`data/provinces_historical.json`:**
- Dodanie 7 nowych obiektów prowincji (§4.2-4.8).
- Patch `tracja.neighbors`: `["konstantynopol"]` → `["konstantynopol", "panonia"]` (mutual edge z panonia).

### Modyfikacje engine

**`scripts/engine/VictoryManager.gd`:**
- 4 nowe stałe (§5.3).
- Schema `_ensure_progress_entry` (linia ~162) rozszerzony o `"slavic_sacred_groves_turns": 0`.
- Gałąź per-religion w `update_counters` (po Arabian gałąź).
- Klauzula `"slavic_paganism"` w `evaluate_unique_victory`.
- Helper `_slavic_sacred_groves_satisfied` (po `_arabian_submission_satisfied`).

### Modyfikacje UI

**`scripts/ui/dialogs/GameOverDialog.gd`:**
- `REASON_LABELS["slavic_sacred_groves"] = "Ziemia Świętych Gajów (Religie Słowiańskie)"`.

### Testy

- `tests/engine/test_province_loader.gd`: 7 loader testów + 1 mutual edge + 1 count=26.
- `tests/engine/test_province_graph.gd`: allowlist pozostaje `[]` (Plan 15 stan, brak nowych ghost edges).
- `tests/engine/test_victory_manager_*.gd`: ~12 testów (1 constants + 6 flags + 3 unique + 1 endgame + 1 inny).
- `tests/ui/test_map_view.gd`, `test_main_shell.gd`: count 19→26.
- `tests/ui/test_game_over_dialog.gd`: dodać `"slavic_sacred_groves"` do reasons array + label assertion test.
- `tests/engine/test_war_manager.gd`: brak modyfikacji (Plan 17 nie zmienia populacji żadnej istniejącej religii — wszystkie 7 nowych prowincji to Slavic).

### Brak zmian

- `Religion.gd`, `Faction.gd`, `Province.gd`, `ProvinceGraph.gd`, `ProvinceLoader.gd`, `Coalition.gd`, etc. — bez zmian.
- `data/religions_historical.json` — bez zmian (Slavic profile + holy_sites=["arkona"] istnieje).
- Inne managery (DiplomacyManager, WarManager, etc.) — bez zmian.

---

## Sekcja 4: Fixture — 7 nowych prowincji

### 4.1 Schemat

Każda prowincja zgodna z `Province.from_dict` — pola: `id`, `display_name`, `owner`, `pressure`, `population`, `resources`, `terrain`, `neighbors`, `is_holy_site`, `position`.

### 4.2 Arkona

```json
{"id": "arkona", "display_name": "Arkona", "owner": "slavic_paganism",
 "pressure": {"slavic_paganism": 80.0}, "population": 200,
 "resources": {"food": 1, "gold": 2}, "terrain": "coast",
 "neighbors": ["gnieszno"], "is_holy_site": true,
 "position": {"x": 40, "y": 20}}
```

**Uzasadnienie:**
- **Owner Slavic + holy site:** Świątynia Świętowita na Rugii — kluczowe miejsce kultu połabskich Słowian (uchwytne archeologicznie do XII w., w VII w. postulowany ośrodek kultu pomorskiego). `religions_historical.json:slavic_paganism.holy_sites` już wymienia.
- **Pressure 80 slavic:** najbardziej "czysta" lokalizacja — Rugia była daleko od chrześcijańskich misji w VII w.
- **Terrain coast:** wyspa nad Bałtykiem.
- **Neighbors `[gnieszno]`:** tylko jeden sąsiad — wyspa (geograficznie izolowana, ale fixture trzyma ją lądem przez gnieszno dla connectivity).

### 4.3 Gnieszno

```json
{"id": "gnieszno", "display_name": "Gniezno", "owner": "slavic_paganism",
 "pressure": {"slavic_paganism": 70.0, "germanic_paganism": 15.0}, "population": 280,
 "resources": {"food": 3, "gold": 1}, "terrain": "plains",
 "neighbors": ["arkona", "morawy", "gardariki"], "is_holy_site": false,
 "position": {"x": 140, "y": 30}}
```

**Uzasadnienie:**
- **Owner Slavic:** Wielkopolska — historyczne jądro plemienia Polan (formalnie X w., ale archeologicznie pre-Polanie obecność od V-VI w.).
- **Pressure 70 slavic, 15 germanic:** Słowianie zachodni granicz z Sasami / Wikingami → minor Germanic pressure jako "design hook" przyszłej dynamiki Western↔Germanic↔Slavic.
- **Resources `{food: 3, gold: 1}` + plains:** żyzna równina (food 3), ubogi w gold (interior, brak portu).
- **Neighbors:** arkona (północ), morawy (południe), gardariki (wschód) — central hub Slavic core.

### 4.4 Morawy

```json
{"id": "morawy", "display_name": "Morawy", "owner": "slavic_paganism",
 "pressure": {"slavic_paganism": 65.0, "western_christianity": 15.0}, "population": 230,
 "resources": {"food": 2, "gold": 1}, "terrain": "mountains",
 "neighbors": ["gnieszno", "panonia"], "is_holy_site": false,
 "position": {"x": 180, "y": 80}}
```

**Uzasadnienie:**
- **Owner Slavic:** Słowianie zachodni (precursor Wielkiej Morawy IX w.). W VII w. archeologicznie obecność Słowian na obszarze Moraw/Słowacji.
- **Pressure 65 slavic, 15 western:** południowa flanka — przyszły kontakt z misjami chrześcijaństwa łacińskiego (Cyryl/Metody IX w., wcześniej Aquileia/Salzburg).
- **Resources mountains:** Karpaty, food 2, gold 1.
- **Neighbors:** gnieszno (północ), panonia (południe). Brak edge do italia_polnocna (Alpy = bariera, geograficznie uproszczenie).

### 4.5 Panonia

```json
{"id": "panonia", "display_name": "Panonia", "owner": "slavic_paganism",
 "pressure": {"slavic_paganism": 55.0, "eastern_christianity": 20.0}, "population": 320,
 "resources": {"food": 3, "gold": 2}, "terrain": "plains",
 "neighbors": ["morawy", "gardariki", "tracja"], "is_holy_site": false,
 "position": {"x": 260, "y": 80}}
```

**Uzasadnienie:**
- **Owner Slavic:** Pannonia po upadku Awar Khaganatu (po 626 r. — porażka Awar pod Konstantynopolem) zmieszana Awarsko-Słowiańsko. W VII w. archeologicznie dominacja Słowian rośnie.
- **Pressure 55 slavic, 20 eastern:** najbardziej "kontestowana" prowincja Slavic core — frontier z Bizancjum (Tracja).
- **Resources `{food: 3, gold: 2}` + plains:** Niż Panoński — żyzny.
- **Neighbors:** morawy (zachód), gardariki (północny-wschód), tracja (południe — **mutual edge** z istniejącą mapą).

### 4.6 Gardariki

```json
{"id": "gardariki", "display_name": "Gardariki", "owner": "slavic_paganism",
 "pressure": {"slavic_paganism": 70.0}, "population": 250,
 "resources": {"food": 2, "gold": 1}, "terrain": "plains",
 "neighbors": ["gnieszno", "panonia", "nowogrod", "kijow"], "is_holy_site": false,
 "position": {"x": 340, "y": 30}}
```

**Uzasadnienie:**
- **Owner Slavic:** Wschodni Słowianie (precursor Rusi). Nazwa "Gardariki" (Skandynawska "ziemia grodów") to skandynawski egzonim dla obszaru późniejszej Rusi.
- **Pressure 70 slavic, brak presji:** w VII w. brak chrześcijańskich misji w głębi puszczy wschodniej; Khazaria z południa nie ma agresywnych prozelitów.
- **Resources plains:** food 2, gold 1.
- **Neighbors:** gnieszno (zachód), panonia (południowy zachód), nowogrod (północ), kijow (południe) — central hub wschodniego Slavic.

### 4.7 Nowogrod

```json
{"id": "nowogrod", "display_name": "Nowogród", "owner": "slavic_paganism",
 "pressure": {"slavic_paganism": 75.0}, "population": 220,
 "resources": {"food": 1, "gold": 3}, "terrain": "coast",
 "neighbors": ["gardariki", "kijow"], "is_holy_site": false,
 "position": {"x": 420, "y": 0}}
```

**Uzasadnienie:**
- **Owner Slavic:** Nowogrodzkie ziemie (Słowianie ilmeńscy) — północna baza późniejszego szlaku Waregów. W VII w. archeologicznie wczesnoSłowiańska obecność.
- **Pressure 75 slavic:** głęboka północ, brak konkurencji.
- **Resources coast (Bałtyk + jeziora) + food 1, gold 3:** uboga ziemia uprawna, ale handel rzeczny (Wołchow → Bałtyk).
- **Neighbors:** gardariki (południe), kijow (południe via szlaku Wareskiego) — sieć rzeczna.

### 4.8 Kijow

```json
{"id": "kijow", "display_name": "Kijów", "owner": "slavic_paganism",
 "pressure": {"slavic_paganism": 65.0}, "population": 300,
 "resources": {"food": 3, "gold": 2}, "terrain": "plains",
 "neighbors": ["gardariki", "nowogrod"], "is_holy_site": false,
 "position": {"x": 480, "y": 60}}
```

**Uzasadnienie:**
- **Owner Slavic:** Polanie Naddnieprzańscy — przyszły rdzeń Rusi Kijowskiej (formalnie IX w., archeologicznie pre-osadnictwo Słowian od VI w.).
- **Pressure 65 slavic:** lekko niższe niż gardariki / nowogrod (Khazaria z południa wywiera słabą presję — symbolizowane niższym pressure).
- **Resources `{food: 3, gold: 2}` + plains:** żyzny Dniepr.
- **Neighbors:** gardariki (północ), nowogrod (północ via Dniepr) — brak edge do persji/mezopotamia (geograficzne uproszczenie — Khazaria nie modelowana).

### 4.9 Patch istniejącej prowincji

**`tracja.neighbors`:**
- Przed: `["konstantynopol"]`
- Po: `["konstantynopol", "panonia"]`

Mutual edge — `panonia.neighbors` zawiera `tracja`. To **jedyna nowa krawędź** łącząca Slavic heartland z istniejącą mapą (19 prowincji).

### 4.10 Topologia po Plan 17

```
                                                    nowogrod
                                                       |
                              arkona                   |
                                |                      |
                             gnieszno ── gardariki ── kijow
                                |          |
                              morawy ── panonia
                                            |
                                         tracja  ← MUTUAL EDGE (nowa)
                                            |
                                      konstantynopol
                                            |
                                      (reszta mapy)
```

26 prowincji total. 0 ghost edges (allowlist nadal pusty z Plan 15).

Krawędzie nowo wprowadzone przez Plan 17:
- arkona ↔ gnieszno
- gnieszno ↔ morawy, gnieszno ↔ gardariki
- morawy ↔ panonia
- panonia ↔ gardariki, **panonia ↔ tracja** (mutual edge — patch tracja)
- gardariki ↔ kijow, gardariki ↔ nowogrod
- nowogrod ↔ kijow

11 nowych krawędzi (10 internal + 1 cross-region).

### 4.11 Pressure values jako "design hooks"

Plan 17 wprowadza 3 minor pressures sygnalizujące przyszłe specs **bez** implementacji mechaniki:

- **`gnieszno.pressure["germanic_paganism"] = 15.0`** — Slavic↔Germanic kontakt (Sasi/Wikingowie).
- **`morawy.pressure["western_christianity"] = 15.0`** — przyszłe misje Aquileia/Salzburg.
- **`panonia.pressure["eastern_christianity"] = 20.0`** — bizantyjska presja z Tracji.

Te pressures **nie triggerują** żadnej nowej logiki — istniejące mechaniki (`TurnManager.process_turn` faza passive_pressure) iterują po wszystkich religijnych pressure'ach bez specjalnego handlingu.

---

## Sekcja 5: Warunek "Ziemia Świętych Gajów"

### 5.1 Reason ID

`slavic_sacred_groves`

Etymologia: "Święte gaje" (slav. *svętъ-gaja) — pre-chrześcijańskie miejsca kultu w lasach Słowian (potwierdzone u Helmolda, Sakso Gramatyka, archeologii). "Ziemia świętych gajów" — sakralizacja całego kontrolowanego terytorium.

Pattern naming spójny z istniejącymi reason IDs (manichaeism_illumination, hindu_dharma, coptic_citadel, arabian_submission).

### 5.2 Trigger condition

Religia `slavic_paganism` spełnia warunek gdy **wszystkie z poniższych** są true:

1. **Kontrola 7 prowincji**: dla każdego ID z `SLAVIC_SACRED_GROVES_IDS` — prowincja istnieje w ProvinceGraph (null guard: custom mapy mogą nie zawierać → wtedy warunek niespełniony) i `owner == "slavic_paganism"`.
2. `religion.get_axis("A") <= 30.0` (anti-dogmatism preserved, start 20).
3. `religion.get_axis("B") <= 30.0` (anti-hierarchy preserved, start 25).
4. **Trwałość:** powyższe 3 warunki utrzymane przez ≥ 20 tur (counter `slavic_sacred_groves_turns`).

### 5.3 Stałe

```gdscript
const SLAVIC_SACRED_GROVES_IDS: Array[String] = ["arkona", "gnieszno", "morawy", "panonia", "gardariki", "nowogrod", "kijow"]
const SLAVIC_AXIS_A_MAX := 30.0
const SLAVIC_AXIS_B_MAX := 30.0
const SLAVIC_SACRED_GROVES_TURNS_REQUIRED := 20
```

**Note:** 4 stałe (mniej niż Arabian 7 / Coptic 6) bo prowincje listed jako Array zamiast pojedynczych ID constants. Trade-off: lista jest bardziej idiomatic dla 7 prowincji niż 7 osobnych stałych ID.

### 5.4 Flavor i design intent

**Territorialność (blood_and_soil):** Slavic musi kontrolować WSZYSTKIE 7 prowincji heartland — utrata jakiejkolwiek = reset counter. To literalne "ziemia świętych gajów" — każda piędź ziemi musi być słowiańska.

**Anti-Christianization (A, B ≤ 30):** Slavic startuje A=20 B=25 — Plan 17 wymaga utrzymania tego profilu. Jeśli gracz akceptuje idee podnoszące A (dogmatyzm) lub B (hierarchia) zbyt wysoko → traci unique victory. Mechanicznie: chronisz przed naturalnym dryfem ku zorganizowanej religii.

**Faction dynamics:** 3 Slavic frakcje mają sprzeczne preferences:
- Wolchwi (45% influence): A−1 (anti-dogmatism — WSPIERA warunek A), D+1.
- Plemienna Starszyzna (35%): B−1 (anti-hierarchy — WSPIERA warunek B).
- Herosi Ziemi (20%): D−1, C+1.

**Faction wsparcie warunku:** Wolchwi (A↓) i Plemienna Starszyzna (B↓) NATURALNIE pchają osie w kierunku warunku. Brak opozycji frakcji (vs Arabian gdzie wszystkie 3 opozycjonowały). Plan 17 trudność = **geograficzna** (obrona 7 prowincji), nie doktrynalna.

**20 tur counter** (jak Coptic) — kompensuje geograficzną trudność. 7 prowincji rozciągniętych od Bałtyku po Dniepr = długa linia frontu.

### 5.5 Counter — `slavic_sacred_groves_turns`

Dodawany do istniejącego schema:

```gdscript
{"domination_turns": int, "prestige_hegemony_turns": int, "dharma_turns": int, "coptic_citadel_turns": int, "arabian_submission_turns": int, "slavic_sacred_groves_turns": int}
```

`update_counters` (wzorzec analogiczny do Coptic/Arabian gałęzi):

```gdscript
# Plan 17 §5.5: slavic_sacred_groves_turns — kontrola 7 prowincji + axes preserved.
if religion.id == "slavic_paganism":
	var groves_active: bool = true
	# Warunek 1: kontrola wszystkich 7 prowincji (null guard każda).
	for pid: String in SLAVIC_SACRED_GROVES_IDS:
		var p: Province = state.province_graph.get_province(pid)
		if p == null or p.owner != religion.id:
			groves_active = false
			break
	# Warunki 2-3: osie preserved (tylko jeśli groves_active wciąż true).
	if groves_active and religion.get_axis("A") > SLAVIC_AXIS_A_MAX:
		groves_active = false
	if groves_active and religion.get_axis("B") > SLAVIC_AXIS_B_MAX:
		groves_active = false
	if groves_active:
		state.victory_progress[religion.id]["slavic_sacred_groves_turns"] += 1
	else:
		state.victory_progress[religion.id]["slavic_sacred_groves_turns"] = 0
```

**Note:** używamy `for ... break` zamiast `if/elif` chain (jak Coptic/Arabian) bo lista 7 prowincji. Drugie i trzecie warunki (axes) gałęzią `if groves_active and ...` zamiast `elif` żeby uniknąć ranny exit przed sprawdzeniem provinces.

Dla religii innych niż slavic_paganism: brak inkrementu → counter zostaje 0 (analog Arabian / Coptic).

### 5.6 Helper `_slavic_sacred_groves_satisfied(religion, state) -> bool`

```gdscript
func _slavic_sacred_groves_satisfied(religion: Religion, state: Node) -> bool:
	# Plan 17 §5.6: counter slavic_sacred_groves_turns aktualizowany w update_counters.
	# Pattern z _arabian_submission_satisfied i _coptic_citadel_satisfied.
	var vp: Dictionary = state.victory_progress.get(religion.id, {})
	return vp.get("slavic_sacred_groves_turns", 0) >= SLAVIC_SACRED_GROVES_TURNS_REQUIRED
```

### 5.7 Klauzula w `evaluate_unique_victory`

Po klauzuli Arabian dodaj:

```gdscript
"slavic_paganism":
	if _slavic_sacred_groves_satisfied(religion, state):
		return "slavic_sacred_groves"
```

### 5.8 Reason mapping (UI)

`GameOverDialog.REASON_LABELS["slavic_sacred_groves"] = "Ziemia Świętych Gajów (Religie Słowiańskie)"`.

Format spójny z Plan 13/14/16 (`"<Polish concept> (<religion display>)"`).

---

## Sekcja 6: Test plan

### Fixture (~9 testów)

**`tests/engine/test_province_loader.gd`** — rozszerzenie:
- `test_loader_loads_arkona_with_holy_site_and_slavic_owner`.
- `test_loader_loads_gnieszno_slavic_owner_with_germanic_pressure_15`.
- `test_loader_loads_morawy_slavic_owner_with_western_pressure_15`.
- `test_loader_loads_panonia_slavic_owner_with_eastern_pressure_20`.
- `test_loader_loads_gardariki_slavic_owner_no_minor_pressure`.
- `test_loader_loads_nowogrod_slavic_owner_no_minor_pressure`.
- `test_loader_loads_kijow_slavic_owner_no_minor_pressure`.
- `test_panonia_tracja_mutual_edge` — `panonia.neighbors.has("tracja") AND tracja.neighbors.has("panonia")`.
- Update istniejącego `test_provinces_total_count_19` → `test_provinces_total_count_26` (rename + asercja).

### Ghost edge (modyfikacja istniejącego)

**`tests/engine/test_province_graph.gd`** — `test_no_ghost_edges_in_full_graph`:
- Allowlist pozostaje `[]` (Plan 15 stan).
- Brak nowych negative assertions (7 nowych prowincji nie wprowadza ghost edges).

### Engine — stałe (~1 test)

**`tests/engine/test_victory_manager_constants.gd`**:
- `test_plan17_constants_exist` — 4 stałe (`SLAVIC_SACRED_GROVES_IDS` array, `SLAVIC_AXIS_A_MAX`, `SLAVIC_AXIS_B_MAX`, `SLAVIC_SACRED_GROVES_TURNS_REQUIRED`).

### Engine — counter (~6 testów)

**`tests/engine/test_victory_manager_flags.gd`**:
- `test_update_counters_initializes_slavic_sacred_groves_turns_zero`.
- `test_update_counters_increments_slavic_sacred_groves_when_all_conditions_met` — happy path: 7 prowincji + A=20 + B=25 (start) → counter rośnie.
- `test_update_counters_resets_slavic_sacred_groves_when_arkona_lost` — utrata arkony (owner=western_christianity) → reset.
- `test_update_counters_resets_slavic_sacred_groves_when_kijow_lost` — utrata kijów (province at end of list) → reset (waliduje że pętla nie ranny exit'uje).
- `test_update_counters_resets_slavic_sacred_groves_when_axis_A_rises_to_31` — próg ostry (A>30 → reset).
- `test_update_counters_only_increments_slavic_sacred_groves_for_slavic_paganism` — inne religie counter == 0.

### Engine — predykat (~3 testy)

**`tests/engine/test_victory_manager_unique.gd`**:
- `test_slavic_sacred_groves_requires_20_turns_counter` — happy path (counter == 20 → "slavic_sacred_groves").
- `test_slavic_sacred_groves_blocked_with_19_turns` — próg ostry (≥20).
- `test_slavic_sacred_groves_other_religion_never_returns_reason` — sanity (np. islam z spreparowanym counter nie zwraca).

### Engine — endgame integracja (~1 test)

**`tests/engine/test_victory_manager_endgame.gd`**:
- `test_check_marks_slavic_sacred_groves_with_game_outcome` — pełna integracja: 20× update_counters + check → `game_outcome.reason == "slavic_sacred_groves"`.

### UI — patches (~2 modyfikacje + 1 nowy test)

**`tests/ui/test_map_view.gd`**:
- Rename `test_view_renders_19_province_nodes` → `test_view_renders_26_province_nodes`, asercja `19` → `26`.

**`tests/ui/test_main_shell.gd`**:
- Asercja `19` → `26`.

**`tests/ui/test_game_over_dialog.gd`**:
- Dodać `"slavic_sacred_groves"` do hardcoded `reasons` array z komentarzem `# Plan 17:`.
- Nowy test `test_slavic_sacred_groves_label_contains_polish_religion_name` (parytet z Plan 14/16):
  ```gdscript
  func test_slavic_sacred_groves_label_contains_polish_religion_name() -> void:
      var label: String = GameOverDialog.REASON_LABELS.get("slavic_sacred_groves", "")
      assert_ne(label, "")
      assert_true(label.findn("słowiańskie") != -1 or label.findn("slavic") != -1)
      assert_true(label.findn("gaj") != -1)
  ```

### Łącznie

~22 nowych testów engine/fixture + 1 nowy UI + 3 modyfikacje istniejących (test_provinces_total_count, test_view_renders, test_main_shell, test_dialog_maps_all_reasons). Po Plan 17 oczekiwane ~743 testów (721 z Plan 16 + 22 nowych).

### Backward compatibility

- Plan 12/13/14/15/16 testy: bez zmian poza UI count patches (19→26).
- Domination victory: ceil(0.5 × 26) = 13 (vs 10 po Plan 15). Istniejące testy używają dynamicznego thresholdu → nie pękną.
- Holy land victory: arkona staje się "real" holy site Slavic → Slavic uzyskuje dostęp do uniwersalnego holy_land victory (zdobycie ≥1 cudzego holy site + posiadanie własnego). Świadomy intended side effect (analog Coptic po Plan 14).
- War manager test (`test_compute_strength_terrain_modifier_only_for_defender`): Plan 17 NIE dodaje prowincji Eastern Christianity (panonia ma pressure Eastern 20% ale owner = slavic_paganism). Population sum Eastern = niezmieniona. **Brak patcha test_war_manager.**

---

## Sekcja 7: Otwarte pytania / Future work

### Decyzje implementacyjne (rozstrzygnięte przed planem)

1. **Reason ID `slavic_sacred_groves`** — przekład "Ziemia Świętych Gajów". Pattern `<religion>_<concept>` spójny.

2. **7 prowincji jako lista (`SLAVIC_SACRED_GROVES_IDS: Array[String]`)** — zamiast 7 osobnych stałych ID (jak `COPTIC_ALEKSANDRIA_ID`, `COPTIC_EGIPT_ID`, `COPTIC_ABISYNIA_ID`). Trade-off: lista mniej idiomatic dla 1-3 prowincji, bardziej idiomatic dla 7+. Test `test_plan17_constants_exist` waliduje exact contents listy.

3. **`for ... break` zamiast `if/elif` chain** dla provinces check — wymuszone listą.

4. **Brak axis_D / axis_C constraint** — żadnej z Slavic frakcji nie blokuje D/C; faction-internal tension (Wolchwi D+1 vs Herosi D-1) jest naturalna dynamika, nie warunek wygranej.

5. **Brak faction unity** — Slavic ma 3 frakcje z sprzecznymi preferences, faction unity byłaby mechanicznie problematyczna. Trudność warunku = geograficzna (7 prowincji).

6. **Brak edges do italia_polnocna / mezopotamia / persji** — Alpy, Khazaria, dystans = bariery. Geograficzne uproszczenie.

7. **`panonia ↔ tracja` jako jedyny entry point** — symuluje historyczną Bizantyjsko-Słowiańską linię konfliktu (Tracja była najbardziej eksponowaną na Słowian prowincją Bizancjum).

### Poza zakresem Plan 17

- **Re-balance `DOMINATION_PROVINCE_SHARE`** — po 19→26 threshold rośnie 10→13. Świadome, recalibration odłożona.
- **UI wskaźnik postępu `slavic_sacred_groves_turns`** — analog `dharma_turns`. Future UI feature.
- **Khazaria jako osobna religia** — pomysł historyczny (Khazars przyjęli judaizm ~740 r.). Out of scope.
- **Edges morskie / dalekosiężne** (nowogrod ↔ konstantynopol Varangian, kijow ↔ persja Silk Road) — geograficzne uproszczenie.
- **Faction "tribalization" mechanic** — pomysł: faction zostaje wzmocniona gdy axis B spada. Out of scope.
- **Visual indication w MapTab** — np. prowincje Slavic "kolorują się świętym zielonym" gdy wszystkie 7 kontrolowanych. Future feature.

---

## Sekcja 8: Acceptance criteria

Plan 17 jest gotowy do merge gdy:

1. ✅ `data/provinces_historical.json` zawiera 26 prowincji, w tym 7 nowych słowiańskich (arkona, gnieszno, morawy, panonia, gardariki, nowogrod, kijow) z polami spec §4.2-4.8.
2. ✅ `tracja.neighbors` zawiera `["konstantynopol", "panonia"]` (mutual edge).
3. ✅ Wszystkie 7 nowych prowincji ma `owner == "slavic_paganism"`.
4. ✅ `arkona.is_holy_site == true`; pozostałe 6 słowiańskich ma `is_holy_site == false`.
5. ✅ 4 stałe Plan 17 istnieją w `VictoryManager.gd`.
6. ✅ Counter `slavic_sacred_groves_turns` w `victory_progress` inkrementuje gdy spełnione 9 warunków (7 prowincji + 2 axes) dla Slavic; resetuje gdy choć jeden niespełniony; pozostaje 0 dla innych religii.
7. ✅ `evaluate_unique_victory` dla Slavic z `slavic_sacred_groves_turns >= 20` zwraca `"slavic_sacred_groves"`.
8. ✅ `state.game_outcome.winner_id == "slavic_paganism"` AND `game_outcome.reason == "slavic_sacred_groves"` po `check()` (test integracyjny).
9. ✅ `GameOverDialog.REASON_LABELS["slavic_sacred_groves"]` zwraca polską etykietę zawierającą `"Ziemia Świętych Gajów"` i `"Religie Słowiańskie"`.
10. ✅ Pre-existing testy Plan 12/13/14/15/16 (~721) — wszystkie pass bez modyfikacji poza UI count patches (19→26).
11. ✅ ~22 nowych testów + UI patches — wszystkie pass.
12. ✅ Cała suite (~743) pass.
13. ✅ Brak ghost edges (allowlist pozostaje `[]`).
14. ✅ `CLAUDE.md` wzmiankuje Plan 17 + aktualizuje count prowincji 19→26.

---

## Sekcja 9: Zależności i ryzyka

**Zależności:**
- Plan 12 (VictoryManager pipeline, GameOutcome, GameOverDialog, `_ensure_progress_entry`) — w master.
- Plan 13 (counter+predykat pattern dla unique victories) — w master.
- Plan 14 (per-religion gałąź `update_counters`, helper reads counter) — w master.
- Plan 15 (fixture expansion pattern, mutual edge, allowlist) — w master.
- Plan 16 (Arabian Submission jako precedens Plan 14 pattern bez zmian fixture) — w master.
- `data/religions_historical.json:slavic_paganism` — Slavic profile + `holy_sites=["arkona"]` istnieje, niezmieniany.

**Ryzyka:**

- **R1: 7 prowincji to dużo do obrony przez 20 tur.** Slavic heartland rozciąga się od Bałtyku (arkona) do Dniepru (kijow). Single point of failure: `panonia` (jedyne wejście z istniejącej mapy via tracja). Strata panonia → utrata jednej z 7 → reset counter. Strata `arkona` (holy site, ale tylko 1 sąsiad: gnieszno) → reset counter.
  - **Mitigacja (design intent):** Plan 17 nie dodaje narzędzi obrony — gracz używa istniejących mechanik (war, vassalage, missionaries, diplomacy, trait `blood_and_soil` -10% siła atakującego na słowiańskich prowincjach).

- **R2: Axes A i B preserved (low) konflikt z naturalną doctrinal pressure.** Jeśli gracz akceptuje idee podnoszące A lub B → traci counter. Wolchwi (A-1) i Plemienna Starszyzna (B-1) pomagają przeciwnym kierunkiem, ale Herosi Ziemi (C+1) jest neutralna; idee z różnych źródeł mogą podnieść A/B.
  - **Mitigacja:** Idea acceptance mechanic z Plan 02/13 — gracz filtruje idee.

- **R3: Mapa 26 prowincji to znaczny content size.** Może wpływać na wydajność rendera mapy, czytelność UI, balance domination victory (10→13).
  - **Mitigacja:** MapView jest extensible (`province_graph.all_provinces()` iteruje agnostycznie). Domination recalibration odłożona do playtestingu.

- **R4: Single entry point `panonia ↔ tracja` może być zbyt "samotny".** Jeśli Eastern Christianity / inny silny gracz dominuje Tracja, Slavic heartland jest praktycznie odizolowany — może być over-defended (negatywnie) lub vacuum dla agresji (pozytywnie z perspektywy challenge).
  - **Mitigacja:** Design intent — Slavic heartland ma być semi-izolowany. Future expansion może dodać edges (np. morawy ↔ italia_polnocna jeśli przyszłe specy wprowadzą Karolingów).

**Brak ryzyk struktury:**
- Schema `victory_progress` jest extensible Dictionary — dodanie `slavic_sacred_groves_turns` nie psuje istniejących kluczy.
- Match w `evaluate_unique_victory` ma default branch — nowy case nie wpływa.
- Stałe Plan 17 nie kolidują (prefix SLAVIC_).
- Mapa renderuje agnostycznie po `all_provinces()` (sprawdzone w Plan 15).

**Known limitations (świadomie akceptowane):**
- **arkona z 1 sąsiadem (gnieszno)** — analog abisynia/italia_polnocna/tracja. Akceptowalne.
- **panonia jako single entry point** — design intent.
- **Brak Khazarii / Karolingów / Lombardów jako osobnych religii** — uproszczenie.
- **Domination threshold shift 10→13** — świadome.
