# Plan 14 — Cytadela Pustelnicza (Koptyjski Kościół)

> **Spec dla:** Plan 14 — domknięcie deferred item z spec 13 §8 (Koptyjski Kościół) oraz minimalne rozszerzenie mapy historycznej o region Egipt–Afryka Północna.
>
> **W zakresie:**
> 1. Dodanie 4 prowincji do fixture (aleksandria, abisynia, libia, karthago).
> 2. Naprawa 2 broken edges (egipt↔libia, rzym↔afryka_polnocna).
> 3. Unikalny warunek zwycięstwa "Cytadela Pustelnicza" dla `coptic_christianity`.
>
> **Wyłączone z zakresu:**
> - Religie Arabskie (osobna spec, wymaga konwersji religii).
> - Religie Słowiańskie (osobna spec, wymaga eurazjatyckiej ekspansji mapy).
> - Pozostałe broken edges (`mekka↔jemen`, `rzym↔italia_polnocna`) — dokumentowane jako known issues, future work.

---

## Sekcja 1: Kontekst i motywacja

Plan 13 (Sekcja 8) wymienił Koptyjski Kościół jako deferred — warunek zwycięstwa wymagał prowincji `aleksandria`, której **nie ma** w `data/provinces_historical.json`, mimo że `religions_historical.json` deklaruje ją w `coptic_christianity.holy_sites`. Stan obecny:

- Coptic startuje z 1 prowincji (`egipt`).
- `holy_sites = ["aleksandria"]` wskazuje na nieistniejącą prowincję (silent — engine tego nie waliduje).
- `egipt.neighbors` zawiera `"libia"` — ghost edge (ProvinceGraph ignoruje krawędzie do nieistniejących prowincji).
- `rzym.neighbors` zawiera `"afryka_polnocna"` — kolejny ghost edge.

Po Plan 14:
- 10 z 12 religii ma unique victory (Plan 13 dał 9, Plan 14 dodaje Coptic).
- Mapa historyczna ma 16 prowincji (z 12), z naturalną osią Egipt–Afryka Północna–Italia.
- 2 z 4 ghost edges naprawione; pozostałe 2 (`mekka↔jemen`, `rzym↔italia_polnocna`) zostają jako jawnie udokumentowane known issues poza zakresem Plan 14.

---

## Sekcja 2: Cele projektowe

1. **Domknięcie deferred item** — Coptic dostaje unique victory dopasowane do profilu doktrynalnego (D=70 transcendencja, trait `desert_memory`, frakcja Ojcowie Pustyni).
2. **Minimalna ekspansja mapy** — 4 prowincje, każda z konkretnym uzasadnieniem (holy site Coptic, secondary core Coptic, bufor Bizantyński, naprawa edge do Western).
3. **Spójność z istniejącym pattern Plan 13** — warunek używa istniejącej infrastruktury VictoryManager (constants → `update_counters` → predykat → `evaluate_unique_victory` → REASON_LABELS).
4. **Zero zmian w logice istniejących Plan 12/13 warunków** — Plan 14 nie modyfikuje predykatów ani thresholdów. **Implicit balance shift do udokumentowania:** `DOMINATION_PROVINCE_SHARE = 0.5` × `total_provinces` daje teraz 8 prowincji (przedtem 6 przy 12 prowincji). Istniejące testy używają dynamicznego `ceil(SHARE * size())` → nie pęknie. Domination victory delikatnie cięższy dla wszystkich religii — świadoma konsekwencja ekspansji mapy, recalibration odłożona do playtestingu.
5. **Naprawa real ghost edges, nie introducing new ones** — wszystkie sąsiedztwa w nowych prowincjach wskazują na istniejące (po zmianach) prowincje.

---

## Sekcja 3: Architektura — co zmienia Plan 14

### Modyfikacje istniejące

**`data/provinces_historical.json`:**
- Dodanie 4 nowych obiektów prowincji (aleksandria, abisynia, libia, karthago).
- Modyfikacja `egipt.neighbors`: dodanie `aleksandria` i `abisynia` (libia już była — broken edge teraz waluuje).
- Modyfikacja `rzym.neighbors`: `"afryka_polnocna"` → `"karthago"`.

**`scripts/engine/VictoryManager.gd`:**
- Dodanie 6 stałych dla Coptic.
- Rozszerzenie domyślnego schema w `_ensure_progress_entry(state.victory_progress, ...)` o `"coptic_citadel_turns": 0`.
- Rozszerzenie `update_counters` o inkrement/reset `coptic_citadel_turns`.
- Rozszerzenie `evaluate_unique_victory` o klauzulę `"coptic_christianity":`.
- Nowy helper `_coptic_citadel_satisfied(religion, state) -> bool`.
- Aktualizacja komentarza nagłówka stałych (linia ~8) — "kalibracja do mapy historycznej (12 prowincji)" → "(16 prowincji)".

**`scripts/ui/dialogs/GameOverDialog.gd`:**
- Rozszerzenie `REASON_LABELS` o 1 nową etykietę (`"coptic_citadel"`).

**`tests/ui/test_map_view.gd`:**
- Aktualizacja `test_view_renders_12_province_nodes` (i nazwy testu) → 16.

**`tests/ui/test_main_shell.gd`:**
- Aktualizacja asercji `12` → `16` w teście liczącym prowincje (linia ~73).

**`CLAUDE.md`:**
- Cross-reference do spec 14 w bullet "End-of-game flow".

### Brak nowych klas, brak zmian pól w Resource'ach

Religion.gd / Province.gd / GameState.gd — bez zmian. Plan 14 to czyste rozszerzenie fixture + VictoryManager + GameOverDialog.

---

## Sekcja 4: Fixture — nowe prowincje

### 4.1 Schemat (zgodny z Province.from_dict)

Każda prowincja w `provinces_historical.json` ma pola: `id`, `display_name`, `owner`, `pressure` (dict), `population`, `resources` (dict z `food`, `gold`), `terrain`, `neighbors` (list), `is_holy_site`, `position` (dict z `x`, `y`).

### 4.2 Aleksandria

```json
{"id": "aleksandria", "display_name": "Aleksandria", "owner": "coptic_christianity",
 "pressure": {"coptic_christianity": 75.0, "eastern_christianity": 15.0}, "population": 400,
 "resources": {"food": 2, "gold": 4}, "terrain": "coast",
 "neighbors": ["egipt", "libia"], "is_holy_site": true,
 "position": {"x": 200, "y": 350}}
```

**Uzasadnienie:**
- **Owner Coptic + holy site:** Patriarchat Aleksandryjski był sercem monofizyckiej tradycji apostolskiej; `coptic_christianity.holy_sites` już ją wymienia.
- **Pressure 75 Coptic, 15 Eastern:** historyczny konflikt Chalcedon (451) — Bizancjum miało roszczenia, ale lokalna wspólnota była koptyjska.
- **Resources `{food: 2, gold: 4}` + coast:** Aleksandria jako port handlowy (gold 4 najwyższy obok Konstantynopola).
- **Neighbors:** `egipt` (Delta Nilu), `libia` (oś wschód-zachód wzdłuż Morza Śródziemnego).

### 4.3 Abisynia

```json
{"id": "abisynia", "display_name": "Abisynia", "owner": "coptic_christianity",
 "pressure": {"coptic_christianity": 70.0}, "population": 250,
 "resources": {"food": 2, "gold": 1}, "terrain": "mountains",
 "neighbors": ["egipt"], "is_holy_site": false,
 "position": {"x": 320, "y": 520}}
```

**Uzasadnienie:**
- **Owner Coptic:** Aksum/Etiopia historycznie wyznawała monofizyzm, w komunii z Patriarchatem Aleksandryjskim; secondary core dla Coptic.
- **Pressure 70 Coptic, brak konkurencji:** geograficznie izolowana, brak realistycznych konkurentów na tym etapie.
- **Terrain mountains:** Płaskowyż Etiopski, niski food (2), niski gold (1).
- **Neighbors:** tylko `egipt` — endpoint na osi południowej. (Brak `jemen` — ghost edge `mekka↔jemen` pozostaje out of scope.)

### 4.4 Libia

```json
{"id": "libia", "display_name": "Libia", "owner": "eastern_christianity",
 "pressure": {"eastern_christianity": 50.0, "coptic_christianity": 25.0}, "population": 200,
 "resources": {"food": 1, "gold": 1}, "terrain": "desert",
 "neighbors": ["aleksandria", "egipt", "karthago"], "is_holy_site": false,
 "position": {"x": 140, "y": 420}}
```

**Uzasadnienie:**
- **Owner Eastern Christianity:** Bizantyjski Egzarchat Cyrenajki/Tripolitanii — administracyjnie podlegał Konstantynopolowi.
- **Pressure 50 Eastern, 25 Coptic:** Coptic ma realny missionary potential (sąsiad aleksandrii), ale formalnie Bizancjum.
- **Resources `{food: 1, gold: 1}` + desert:** uboga ekonomicznie, geograficznie bufer.
- **Neighbors:** `aleksandria`, `egipt`, `karthago` — most między Egiptem a Afryką Zachodnią.

### 4.5 Karthago

```json
{"id": "karthago", "display_name": "Kartagina", "owner": "eastern_christianity",
 "pressure": {"eastern_christianity": 55.0, "western_christianity": 20.0}, "population": 300,
 "resources": {"food": 2, "gold": 3}, "terrain": "coast",
 "neighbors": ["libia", "rzym"], "is_holy_site": false,
 "position": {"x": 60, "y": 320}}
```

**Uzasadnienie:**
- **Owner Eastern Christianity:** Egzarchat Kartagina ustanowiony przez Justyniana (Bizancjum), historycznie w VII w. bizantyjski.
- **Pressure 55 Eastern, 20 Western:** geograficzna bliskość Rzymu + kulturowe dziedzictwo łacińskie (Augustyn z Hippony) = pressure Western.
- **Resources `{food: 2, gold: 3}` + coast:** żyzne wybrzeże, port handlowy.
- **Neighbors:** `libia`, `rzym` — naprawia ghost edge `rzym↔afryka_polnocna`.

### 4.6 Patche istniejących prowincji

**`egipt.neighbors`:**
- Przed: `["lewant", "jerozolima", "libia"]`
- Po: `["lewant", "jerozolima", "libia", "aleksandria", "abisynia"]`

**`rzym.neighbors`:**
- Przed: `["italia_polnocna", "afryka_polnocna"]`
- Po: `["italia_polnocna", "karthago"]`
- Zmiana: `"afryka_polnocna"` → `"karthago"`. `"italia_polnocna"` pozostaje (out of scope ghost edge — future map expansion).

### 4.7 Topologia po Plan 14

```
                konstantynopol
                     |
       tracja      anatolia ── armenia ── persja ── persepolis
                     |                       |
                   lewant ── mezopotamia ── arabia_polnocna
                  /  |  \      |              |
        jerozolima  |  mekka  (...)          (...)
                    |    \
                  egipt   jemen [ghost — out of scope]
                /  |  \
   aleksandria  |  abisynia
        \       |
         libia ─┴── karthago ── rzym ── italia_polnocna [ghost — out of scope]
                                  \
                                   (sąsiad: italia_polnocna ghost)
```

Lewa krawędź `aleksandria — libia` i centralna `egipt — libia` oraz prawa `egipt — abisynia` są jednoznacznie wyliczone w liście poniżej.

Krawędzie nowo wprowadzone:
- aleksandria ↔ egipt, aleksandria ↔ libia
- abisynia ↔ egipt
- libia ↔ egipt (waluuje istniejący `egipt.neighbors["libia"]`), libia ↔ aleksandria, libia ↔ karthago
- karthago ↔ libia, karthago ↔ rzym (zastępuje ghost `rzym↔afryka_polnocna`)

16 prowincji total. 2 ghost edges pozostają (`mekka↔jemen`, `rzym↔italia_polnocna`) — explicit out of scope.

---

## Sekcja 5: Warunek "Cytadela Pustelnicza"

### 5.1 Reason ID

`coptic_citadel`

### 5.2 Trigger condition

Religia `coptic_christianity` spełnia warunek gdy **wszystkie z poniższych** są true:

1. `aleksandria` istnieje w ProvinceGraph i `aleksandria.owner == "coptic_christianity"`.
2. `egipt` istnieje w ProvinceGraph i `egipt.owner == "coptic_christianity"`.
3. `abisynia` istnieje w ProvinceGraph i `abisynia.owner == "coptic_christianity"`.
4. `religion.get_axis("D") >= 85.0`.
5. `religion.factions.size() >= 3` **AND** wszystkie frakcje spełniają `tension < 50.0`. (Guard: schizma jest doktrynalnie sprzeczna z "monastyczną jednością" — utrata frakcji = reset countera, nawet jeśli pozostałe są spokojne. Vacuous truth dla 0/1/2 frakcji jest niedopuszczalna.)
6. **Trwałość:** powyższe 5 warunków utrzymane przez ≥ 20 tur (counter `coptic_citadel_turns`).

### 5.3 Konstanty

```gdscript
const COPTIC_ALEKSANDRIA_ID := "aleksandria"
const COPTIC_EGIPT_ID := "egipt"
const COPTIC_ABISYNIA_ID := "abisynia"
const COPTIC_AXIS_D_REQUIRED := 85.0
const COPTIC_FACTION_TENSION_MAX := 50.0
const COPTIC_CITADEL_TURNS_REQUIRED := 20
```

### 5.4 Flavor

Aleksandria + Egipt + Abisynia = trzy bastiony tradycji monofizyckiej (geograficzne, polityczne, duchowe). Axis D ≥ 85 = transcendencja na bardzo wysokim poziomie. **Coptic ma cięższy axis lift niż Buddyzm:** Coptic start D=70, próg 85 → +15 punktów do wypracowania. Buddhism start D=85, próg 90 → +5 punktów. Coptic wymaga zatem więcej cykli idei z impactem D+1. Próg 85 (nie 90 jak buddhism) jest zatem **kompromisem** — niższy bezwzględny próg dla Coptic kompensowany trzymaniem 3 konkretnych prowincji + faction unity (zestaw bardziej splotowy niż "axis + 4 sources" w Buddyzmie). Tension < 50 dla wszystkich 3 frakcji = brak rozłamu między Papieżem Aleksandryjskim, Ojcami Pustyni a Wiernymi Egipskimi (poniżej phase 1 threshold 60.0 z SchismManager).

20 tur ≈ 1/3 horyzontu Hindu Dharma (50 tur). Coptic ma niższy próg czasowy bo wymaga trzymania konkretnych prowincji + axis + faction unity — zestaw bardziej "kruchych" warunków niż Hindu (≥2 prowincje, raczej luźne).

### 5.5 Counter — `coptic_citadel_turns`

Dodawany do istniejącego `state.victory_progress[id]` schema:

```gdscript
{"domination_turns": int, "prestige_hegemony_turns": int, "dharma_turns": int, "coptic_citadel_turns": int}
```

`update_counters` (wzorzec analogiczny do `dharma_turns` w obecnym `VictoryManager.gd:165-171`):

```gdscript
# W pętli for religion in state.all_religions(), wewnątrz update_counters:
if religion.id == "coptic_christianity":
    var citadel_active: bool = true
    # Warunki 1-3: kontrola 3 prowincji (null guard na każdej)
    var aleksandria: Province = state.province_graph.get_province(COPTIC_ALEKSANDRIA_ID)
    var egipt: Province = state.province_graph.get_province(COPTIC_EGIPT_ID)
    var abisynia: Province = state.province_graph.get_province(COPTIC_ABISYNIA_ID)
    if aleksandria == null or aleksandria.owner != religion.id:
        citadel_active = false
    elif egipt == null or egipt.owner != religion.id:
        citadel_active = false
    elif abisynia == null or abisynia.owner != religion.id:
        citadel_active = false
    # Warunek 4: axis D
    elif religion.get_axis("D") < COPTIC_AXIS_D_REQUIRED:
        citadel_active = false
    # Warunek 5: faction unity (z guard ≥ 3 frakcje)
    elif religion.factions.size() < 3:
        citadel_active = false
    else:
        for f: Faction in religion.factions:
            if f.tension >= COPTIC_FACTION_TENSION_MAX:
                citadel_active = false
                break
    if citadel_active:
        state.victory_progress[religion.id]["coptic_citadel_turns"] += 1
    else:
        state.victory_progress[religion.id]["coptic_citadel_turns"] = 0
```

Dla religii innych niż Coptic: brak inkrementu → counter zostaje 0 przez całą grę (analog `dharma_turns` dla Hindu).

### 5.6 Helper `_coptic_citadel_satisfied(religion, state) -> bool`

```gdscript
func _coptic_citadel_satisfied(religion: Religion, state: Node) -> bool:
    # Counter coptic_citadel_turns aktualizowany w update_counters.
    var vp: Dictionary = state.victory_progress.get(religion.id, {})
    return vp.get("coptic_citadel_turns", 0) >= COPTIC_CITADEL_TURNS_REQUIRED
```

Wzór z `_hindu_dharma_satisfied` (Plan 13) — predykat reads tylko counter, faktyczne warunki ewaluuje `update_counters`. To zapewnia że counter + predykat są spójne (nie da się "udać" 20 tur w jednej turze).

### 5.7 Prereq

`evaluate_unique_victory` (Plan 12 §4.2) ma już prereq `not religion.is_defeated() and religion.player_controlled`. Coptic case dodaje:

```gdscript
"coptic_christianity":
    if _coptic_citadel_satisfied(religion, state):
        return "coptic_citadel"
```

`ever_owned_province` nie jest wymagane jako prereq — utrata wszystkich prowincji najpierw triggerujee D1 elimination (kolejność check w `check()`), więc unique victory dla defeated religion nie zostanie wyewaluowane.

### 5.8 Reason mapping (UI)

`GameOverDialog.REASON_LABELS["coptic_citadel"] = "Cytadela Pustelnicza (Koptyjski Kościół)"`.

Format spójny z Plan 13 (`"Reformacja Apostolska (Chrześcijaństwo Zachodnie)"` itd.).

---

## Sekcja 6: Test plan

### Fixture (~7 nowych testów)

**`tests/engine/test_province_loader.gd`** lub równoważny (sprawdzić jaki test pokrywa fixture):
- `test_loader_loads_aleksandria_with_holy_site_and_coptic_owner`.
- `test_loader_loads_abisynia_coptic_owner_no_holy_site`.
- `test_loader_loads_libia_eastern_owner_with_coptic_pressure_25`.
- `test_loader_loads_karthago_eastern_owner_with_western_pressure_20`.
- `test_egipt_neighbors_include_aleksandria_and_abisynia` — patch verification.
- `test_rzym_neighbors_include_karthago_not_afryka_polnocna` — patch verification.
- `test_no_ghost_edges_in_full_graph` — **cały graf** (nie tylko 4 nowe): każdy neighbor każdej prowincji albo wskazuje na istniejącą prowincję, albo jest w explicit allowlist `["jemen", "afryka_polnocna", "italia_polnocna"]` (znane out-of-scope ghosts). Allowlist musi się skurczyć do `["jemen", "italia_polnocna"]` po Plan 14 — test waliduje że `afryka_polnocna` już NIE pojawia się jako ghost.

### UI test patches (~2 modyfikacje istniejących testów)

**`tests/ui/test_map_view.gd`** (linia ~24, `test_view_renders_12_province_nodes`):
- Zaktualizować nazwę testu na `test_view_renders_16_province_nodes`.
- Zmienić asercję `assert_eq(mv.get_node_count(), 12)` → `16`.

**`tests/ui/test_main_shell.gd`** (linia ~73, asercja `12`):
- Zmienić `12` → `16` w teście liczącym prowincje.

### Engine (~10 nowych testów)

**`tests/engine/test_victory_manager_constants.gd`** — rozszerzenie:
- `test_plan14_constants_exist` — 6 nowych stałych z asercjami wartości.

**`tests/engine/test_victory_manager_flags.gd`** — rozszerzenie (update_counters):
- `test_update_counters_initializes_coptic_citadel_turns_zero` — domyślnie 0 w victory_progress.
- `test_update_counters_increments_coptic_citadel_when_all_5_conditions_met` — happy path.
- `test_update_counters_resets_coptic_citadel_when_aleksandria_lost`.
- `test_update_counters_resets_coptic_citadel_when_axis_D_drops_to_84` — próg ostry.
- `test_update_counters_resets_coptic_citadel_when_one_faction_tension_50` — próg ostry (< 50, nie <=).
- `test_update_counters_only_increments_coptic_citadel_for_coptic_christianity` — inne religie nie dotyczą (counter zostaje 0).

**`tests/engine/test_victory_manager_unique.gd`** — rozszerzenie:
- `test_coptic_citadel_requires_20_turns_counter` — happy path (counter == 20).
- `test_coptic_citadel_blocked_with_19_turns` — próg ostry (>= nie >).
- `test_coptic_citadel_other_religion_never_returns_reason` — sanity check (np. Islam z spreparowanym victory_progress[islam][coptic_citadel_turns] = 30 nie zwraca "coptic_citadel" bo nie ma case'a w match).

**`tests/engine/test_victory_manager_endgame.gd`** — rozszerzenie:
- `test_check_marks_coptic_citadel_with_game_outcome` — pełna integracja: ustaw warunki, advance turn 20x, sprawdź że `state.game_outcome.winner_religion_id == "coptic_christianity"` i `game_outcome.reason == "coptic_citadel"`.

### UI (~1 nowy test)

**`tests/ui/test_game_over_dialog.gd`** — rozszerzenie:
- Update `test_dialog_maps_all_reasons_to_non_empty_polish_labels` — dodać `"coptic_citadel"` do listy weryfikowanych reasonów (test parametryczny).

### Backward compatibility

- Plan 12/13 testy: bez zmian. Plan 14 tylko dodaje 4 prowincje + 1 unique victory.
- Wszystkie wcześniejsze warunki (domination, hegemony, holy_land, 9 unique z Plan 12+13, D1/D2/D3 defeats) — bez zmian zachowania.
- Religie inne niż Coptic: `evaluate_unique_victory` zachowuje istniejący match — nowy case nie wpływa.
- Religie istniejących prowincji nie są zmienione (rzym.owner = western pozostaje, egipt.owner = coptic pozostaje).

---

## Sekcja 7: Otwarte pytania / Future work

### Decyzje implementacyjne (rozstrzygnięte przed planem)

1. **`is_holy_site` aleksandria triggeruje passive pressure/prestige automatycznie** przez istniejące mechaniki: `TurnManager.process_turn` (faza passive_pressure i holy_site_prestige) iteruje po `province_graph.all_provinces()` filtrując po `is_holy_site`. Brak specjalnego handlingu wymagany — aleksandria wejdzie do pipeline naturalnie. Wzmiankowane jako acceptance criterion (sanity test integracyjny opcjonalny).

2. **Nowy victory path dla Coptic przez `holy_land`:** Przed Plan 14 `_evaluate_holy_land` zwracał `false` dla Coptic bo `aleksandria` (jedyne `coptic.holy_sites`) nie istniała — null guard blokował. Po Plan 14 Coptic kontroluje własne święte miejsce (aleksandria) i może wygrać uniwersalnie przez zdobycie ≥1 cudzego (jerozolima/mekka/konstantynopol/rzym). To **świadomy intended side effect** — Coptic uzyskuje dostęp do dwóch ścieżek zwycięstwa (unique `coptic_citadel` + uniwersalny `holy_land`), spójnie z innymi religiami posiadającymi święte miejsca.

3. **Karthago jako nowy sąsiad Rzymu:** Western może misjonarzyć/atakować Karthago, Eastern Christianity dalej wpływa na rzym (poprzednio przez ghost `afryka_polnocna`, teraz przez waluuje karthago). Net effect: minimalna zmiana topologii, naprawia broken edge.

### Poza zakresem Plan 14

- **Religie Arabskie — "Przyjęcie Islamu"** — wymaga konwersji religii. Osobna spec.
- **Religie Słowiańskie — "Ziemia Świętych Gajów"** — wymaga eurazjatyckiej ekspansji mapy. Osobna spec.
- **Ghost edges `mekka↔jemen`, `rzym↔italia_polnocna`** — udokumentowane jako known issues. Naprawa = osobny ticket lub future map expansion spec (italia_polnocna jako prowincja Western Christianity, jemen jako prowincja arabian_paganism).
- **UI wskaźnik postępu `coptic_citadel_turns`** — analog `dharma_turns` (spec 13 §8). Future UI feature.
- **Re-balance progu 20 tur na podstawie playtestingu** — początkowe ustawienie, do tuningu.

---

## Sekcja 8: Acceptance criteria

Plan 14 jest gotowy do merge gdy:

1. `data/provinces_historical.json` zawiera 16 prowincji, w tym 4 nowe (aleksandria, abisynia, libia, karthago) z polami spec §4.2-4.5.
2. `egipt.neighbors` zawiera `aleksandria` i `abisynia` (oraz istniejące, w tym `libia` które teraz waluuje).
3. `rzym.neighbors` zawiera `karthago` i NIE zawiera `afryka_polnocna`.
4. 6 stałych Plan 14 istnieje w `VictoryManager.gd`.
5. Counter `coptic_citadel_turns` w `victory_progress` inkrementuje gdy spełnione 5 warunków z §5.2 (1-5) i religia to Coptic; resetuje gdy choć jeden niespełniony; pozostaje 0 dla innych religii.
6. `evaluate_unique_victory` dla Coptic z `coptic_citadel_turns >= 20` zwraca `"coptic_citadel"`.
7. `state.game_outcome.reason == "coptic_citadel"` po `check()` gdy gracz Coptic wygra.
8. `GameOverDialog.REASON_LABELS["coptic_citadel"]` zwraca polską etykietę z `"Coptic"` lub `"Koptyjski"` w nazwie.
9. `CLAUDE.md` wzmiankuje Plan 14 (1-liner cross-reference w bullet "End-of-game flow").
10. Wszystkie istniejące testy (683 po Plan 13) + nowe (~14 fixture/engine + 1 UI) passing, łącznie ze zaktualizowanymi `test_view_renders_16_province_nodes` i `test_main_shell` (12 → 16).

---

## Sekcja 9: Zależności i ryzyka

**Zależności:**
- Plan 12 (VictoryManager pipeline, GameOutcome, GameOverDialog, `_ensure_progress_entry`) — w master.
- Plan 13 (`victory_progress[id]` dictionary schema, pattern counter+predykat dla Hindu Dharma) — w master.
- `data/religions_historical.json` `coptic_christianity.holy_sites = ["aleksandria"]` — istniejące, niezmieniane.
- ProvinceLoader / ProvinceGraph — istniejące, działają bez modyfikacji (loader iteruje po `provinces` array w JSON).

**Ryzyka:**

- **R1: Coptic axis D start = 70, próg = 85 — różnica 15 punktów.** Wymaga `shift_axis(D, +15)` np. przez ideas boostujące D (transcendencja). Realistyczne — frakcja Ojcowie Pustyni ma `axis_preferences D direction +1`, faction influence może popychać D w górę przez doctrine pressure (DoctrineManager z Plan 02).

- **R2: Wszystkie 3 frakcje Coptic z tension < 50.** Startowo wszystkie 3 mają tension_start = 20.0. Phase 1 schism threshold = 60.0; 50 jest poniżej tego ale daje warning margin. Wymaga zarządzania frakcjami (idea acceptance balancing axis_preferences, faction support actions, nie pozwalanie na phase 1).

- **R3: Trzymanie 3 prowincji (Egipt+Aleksandria+Abisynia) przez 20 tur.** Egipt sąsiaduje z lewant (Eastern) i mekka (Arabian) — realne ryzyko inwazji. Aleksandria sąsiaduje z libia (Eastern). Abisynia geograficznie izolowana (tylko egipt jako sąsiad) — najbezpieczniejsza. Coptic musi obronić oś przed Eastern i ekspansją islamic.

**Mitigacja ryzyk:**
- R1, R2, R3 to **design intent** — warunek "Cytadela Pustelnicza" ma być wymagający. Tuning progów odłożony do playtestingu (§7 future work).
- R3: Plan 14 nie dodaje mechaniki obrony — Coptic używa istniejących systemów (war, vassalage, missionaries, diplomacy).

**Known limitations (świadomie akceptowane):**
- **Abisynia ma tylko 1 sąsiada (egipt)** — jeśli Coptic straci egipt, abisynia staje się "wyspowa" (niedostępna dla missionary/war). To geograficzna prawda (Płaskowyż Etiopski izolowany w VII w. od głównych dróg handlowych), ale potencjalny exploit "schowaj się w abisyni do końca gry". Akceptowalne na poziomie Plan 14; future map expansion może dodać `jemen` (przez Morze Czerwone) jako drugi neighbor.
- **2 ghost edges pozostają** (`mekka↔jemen`, `rzym↔italia_polnocna`) — udokumentowane, allowlist w `test_no_ghost_edges_in_full_graph`.

**Brak ryzyk struktury:**
- Schema `victory_progress` jest extensible Dictionary — dodanie `coptic_citadel_turns` nie psuje istniejących kluczy.
- Match w `evaluate_unique_victory` ma default branch (zwraca `""`) — nowy case nie wpływa na istniejące religie.
- ProvinceGraph buduje krawędzie z `neighbors` listy — dodanie 4 prowincji jest aditywne, nie modyfikuje istniejących.
