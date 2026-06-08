# Warunki zwycięstwa i przegranej

**Data:** 2026-06-08
**Projekt:** religion-manager
**Status:** Zatwierdzony
**Powiązane:** [profile religii](05-religion-profiles-design.md) (Sekcja "Otwarte pytania"), [system wojen](02-war-system-design.md) (force_loss), [system dyplomacji](03-diplomacy-system-design.md) (wasalstwo), [system doktryn](01-doctrine-system-design.md) (oś C — Synkretyzm), [UI design](06-ui-design.md)

---

## Kontekst

Gra do tej pory nie ma stanu końcowego. Tury można naliczać w nieskończoność, religie mogą zniknąć z mapy (utrata wszystkich prowincji) bez konsekwencji mechanicznej, a gracz nie ma momentu "wygrałem". Spec 05 ("Profile startowe religii") eksplicite zostawił **trzy otwarte pytania** dotyczące warunków zwycięstwa (Manicheizm, mechanika konwersji Religii Arabskich do Islamu, zjednoczenie ChrZ/ChrW) — ten dokument je adresuje.

Każda religia (gracz i NPC) podlega tym samym zasadom — silnik traktuje je symetrycznie. Pierwsza religia spełniająca dowolny warunek zwycięstwa **kończy grę**. Przegrana jest **per-religia** (nie kończy gry, chyba że przegra gracz w trybie "modal i wyjście"). Hard cap na **200 turach** gwarantuje deterministyczne zakończenie nawet w grze patowej.

---

## Cele projektowe

1. **Mechaniczna symetria gracza i NPC** — te same warunki, te same progi, te same liczniki. Pod przyszłą AI z planu po Plan 12.
2. **Wiele ścieżek do zwycięstwa** — uniwersalne 3 (dostępne dla każdej religii) + unikalne per religia, by trait ze spec 05 ("realna ścieżka wygranej niedostępna dla innych") miał odbicie w warunku końcowym.
3. **Deterministyczne zakończenie** — twardy cap turowy + ranking fallback przy żadnym warunku spełnionym.
4. **Czytelny modal końcowy** — kto wygrał, jakim warunkiem, jak gracz wypadł, ranking finalny.
5. **Stateless manager** zgodny z konwencją (`TurnManager`, `WarManager`, `DiplomacyManager`, `DoctrineManager`, `SchismManager`).

---

## Architektura

### Komponenty

```
scripts/engine/
├── VictoryManager.gd         (RefCounted, stateless)
└── GameOutcome.gd            (Resource, opisuje końcowy stan)

scripts/ui/dialogs/
├── GameOverDialog.gd         (AcceptDialog lub PanelContainer)
└── GameOverDialog.tscn
```

Modyfikacje:
- `GameState` — nowe pola (sekcja "Modyfikacje danych" niżej).
- `TurnManager.process_turn` — wywołanie `VictoryManager.check(state)` jako **ostatni krok** po `state.advance_turn()`.
- `Religion` — `defeated_at_turn: int = -1`, `starting_provinces_snapshot: Array[String]` (potrzebne do Ragnaröka).
- `ReligionLoader` — wypełnia `starting_provinces_snapshot` z owner-prowincji wgranych w fazie init.
- `MainShell` — wykrywa `state.game_outcome != null`, pokazuje `GameOverDialog`, disable Button "Zakończ turę".

### VictoryManager — API

```gdscript
class_name VictoryManager
extends RefCounted

# Progi uniwersalne — tunable, kalibrowane do mapy historycznej (12 prowincji)
const TURN_LIMIT := 200
const DOMINATION_PROVINCE_SHARE := 0.5            # ≥50% prowincji świata
const DOMINATION_TURNS_REQUIRED := 3
const PRESTIGE_HEGEMONY_RATIO := 2.0              # ≥2× drugiej najwyższej
const PRESTIGE_HEGEMONY_TURNS_REQUIRED := 10
const ELIMINATION_TURNS_REQUIRED := 5             # 0 prowincji przez N tur
const VASSAL_DEFEAT_TURNS_REQUIRED := 20          # suzerain_id != "" przez N tur
const SCHISM_GRACE_TURNS := 10                    # ile tur po schizmie zanim nowa religia może wygrać

# Progi unikalne — patrz Sekcja 4.2
const JUDAISM_PROVINCES_REQUIRED := 4
const JUDAISM_JERUSALEM_ID := "jerozolima"
const JUDAISM_FACTION_UNITY_TENSION_MAX := 30.0
const ZOROASTRIANISM_PROVINCES_REQUIRED := 3
const ZOROASTRIANISM_PERSEPOLIS_ID := "persepolis"
const ISLAM_PROVINCES_REQUIRED := 5
const ISLAM_MEKKA_ID := "mekka"
const ISLAM_JERUSALEM_ID := "jerozolima"
const EAST_CHRISTIANITY_VASSALS_REQUIRED := 3
const MANICHAEISM_AXIS_C_REQUIRED := 90.0
const MANICHAEISM_DISTINCT_SOURCES_REQUIRED := 4

# Główny entry point — wywoływany przez TurnManager na końcu process_turn
func check(state: Node) -> void

# Helpery (publiczne dla testów)
func evaluate_universal_victory(religion: Religion, state: Node) -> String  # "" jeśli żaden, inaczej powód
func evaluate_unique_victory(religion: Religion, state: Node) -> String     # "" jeśli żaden lub schism-grace
func evaluate_defeat(religion: Religion, state: Node) -> String             # "" jeśli żaden lub brak prereq ever_owned
func compute_ranking(state: Node, exclude_defeated: bool = true) -> Array   # Array[Dictionary{religion_id, prestige, provinces}]
func update_flags(state: Node) -> void                                       # Krok 2 z Sekcji 6 (ever_owned + ragnarok)
func update_counters(state: Node) -> void                                    # Krok 3 z Sekcji 6 (victory_progress + defeat_progress)
```

### GameOutcome — schemat danych

```gdscript
class_name GameOutcome
extends Resource

@export var winner_id: String = ""              # "" jeśli cap z fallbackiem — i tak ustawiamy zwycięzcę po prestiżu
@export var reason: String = ""                 # "domination" / "prestige_hegemony" / "holy_land" / "manichaeism_illumination" / "judaism_return" / "zoroastrianism_renaissance" / "east_christianity_pentarchy" / "islam_caliphate" / "germanic_ragnarok" / "turn_limit"
@export var end_turn: int = 0
@export var ranking: Array = []                 # Array[Dictionary]: posortowana DESC po prestiżu na chwilę końca
```

---

## Sekcja 4: Warunki zwycięstwa

### 4.1 Uniwersalne — każda aktywna religia

**(1) Dominacja Terytorialna** (`reason: "domination"`)

- Religia kontroluje `≥ DOMINATION_PROVINCE_SHARE * total_provinces` prowincji
- Utrzymane przez `≥ DOMINATION_TURNS_REQUIRED` **kolejnych** tur (licznik resetuje się przy chwilowej utracie progu — patrz Sekcja 7)

Mapa historyczna (12 prowincji) → próg = 6 prowincji.

**(2) Hegemonia Prestiżu** (`reason: "prestige_hegemony"`)

- `religion.prestige ≥ PRESTIGE_HEGEMONY_RATIO * second_highest_prestige` wśród **aktywnych** religii (Sekcja 6)
- Utrzymane przez `≥ PRESTIGE_HEGEMONY_TURNS_REQUIRED` kolejnych tur

Margines 10 tur celowy — daje innym religiom czas na reakcję (wojny, misje), nie pozwala na natychmiastowe zwycięstwo prestiżem startowym ChrZ (500).

**(3) Święta Ziemia** (`reason: "holy_land"`)

- **Prerequisite**: `religion.holy_sites.size() > 0` — religia musi mieć przynajmniej jedno własne święte miejsce zdefiniowane w profilu. Bez tego warunek jest **niedostępny** (Manicheizm w fixture historycznym ma `holy_sites: []` — nie może wygrać tym warunkiem; jego ścieżką jest Synkretyczna Iluminacja, Sekcja 4.2 (4)).
- Wszystkie własne `holy_sites` pod kontrolą (każdy `holy_site_id ∈ religion.holy_sites` spełnia `state.province_graph.get_province(holy_site_id).owner == religion.id`)
- **ORAZ** ≥1 prowincja z `is_holy_site == true` należąca do innej religii (z dowolnej kategorii) pod kontrolą

Drugi warunek wymusza ofensywę — religia z jedną własną świętą prowincją nie wygrywa natychmiast bez zdobycia cudzej.

### 4.2 Unikalne — wybrane religie (in-scope w Plan 12)

Religie bez unikalnego warunku poniżej mają dostępne wyłącznie 3 warunki uniwersalne. To **świadoma decyzja designu** — każda religia ze spec 05 dostanie unikalny warunek w przyszłych planach (po Plan 12), gdy mapa eurazjatycka i dodatkowe mechaniki będą gotowe.

**(4) Manicheizm — Synkretyczna Iluminacja** (`reason: "manichaeism_illumination"`)

- `religion.id == "manichaeism"`
- `religion.get_axis("C") ≥ MANICHAEISM_AXIS_C_REQUIRED` (90)
- Religia zaabsorbowała idee od `≥ MANICHAEISM_DISTINCT_SOURCES_REQUIRED` (4) różnych religii źródłowych

**Wymaga nowego pola w `Religion`**: `absorbed_idea_sources: Array[String]` (lista `source_id` zaabsorbowanych idei, unikalna, dodawana w `DoctrineManager.apply_idea` lub równoważnym punkcie). Historia trwała — nie resetuje się.

**(5) Judaizm — Powrót do Syjonu** (`reason: "judaism_return"`)

- `religion.id == "judaism"`
- Kontrola prowincji `JUDAISM_JERUSALEM_ID` (`jerozolima`)
- `≥ JUDAISM_PROVINCES_REQUIRED` (4) prowincji łącznie
- Wszystkie 3 frakcje religii: `tension < JUDAISM_FACTION_UNITY_TENSION_MAX` (30) — symbol wewnętrznej jedności po powrocie

**(6) Zoroastryzm — Renesans Saszański** (`reason: "zoroastrianism_renaissance"`)

- `religion.id == "zoroastrianism"`
- Kontrola prowincji `ZOROASTRIANISM_PERSEPOLIS_ID` (`persepolis`)
- `≥ ZOROASTRIANISM_PROVINCES_REQUIRED` (3) prowincji łącznie

Próg 3 dopasowany do realiów mapy historycznej (Persja, Persepolis, Mezopotamia, Armenia — 4 prowincje historycznie zoroastryjskie; warunek wymaga 3 z nich, dowolnych).

**(7) Chrześcijaństwo Wschodnie — Pentarchia** (`reason: "east_christianity_pentarchy"`)

- `religion.id == "eastern_christianity"`
- Być suzerain (`other.suzerain_id == religion.id`) dla `≥ EAST_CHRISTIANITY_VASSALS_REQUIRED` (3) innych religii **równocześnie**

Tylko ta religia ze spec 05 dostała Cezaropapizm — warunek tematycznie nawiązuje do zwierzchnictwa hierarchicznego.

**(8) Islam — Pełen Kalifat** (`reason: "islam_caliphate"`)

- `religion.id == "islam"`
- Kontrola prowincji `ISLAM_MEKKA_ID` (`mekka`) i `ISLAM_JERUSALEM_ID` (`jerozolima`)
- `≥ ISLAM_PROVINCES_REQUIRED` (5) prowincji łącznie

Próg 5 (a nie 10) jest dopasowany do mapy 12 prowincji — wymaga znaczącej dominacji bez konieczności kontroli ~80% mapy.

**(9) Religie Germańskie — Ragnarök Triumfalny** (`reason: "germanic_ragnarok"`)

- `religion.id == "germanic_paganism"`
- **Prerequisite** (trwała flaga): `religion.ragnarok_triggered == true`
- Religia odzyskała **100% prowincji startowych** (każdy `province_id ∈ starting_provinces_snapshot` ma `state.province_graph.get_province(province_id).owner == religion.id` w obecnej turze)

**Ustawianie flagi `ragnarok_triggered`**: VictoryManager update step (Sekcja 7) sprawdza dla każdej aktywnej religii: jeśli `not ragnarok_triggered` i `starting_provinces_snapshot.size() > 0` i `liczba_obecnie_kontrolowanych_z_snapshot ≤ starting_provinces_snapshot.size() / 2` (utracone >50% startowych) → set `ragnarok_triggered = true`. Flaga jest **trwała** — raz ustawiona nie resetuje się.

**Realia**: Na mapie historycznej Religie Germańskie nie mają startowych prowincji (`starting_provinces_snapshot.is_empty()`) → `ragnarok_triggered` nigdy nie zostanie ustawione (warunek `snapshot.size() > 0` wyklucza) → warunek **niedostępny**. To poprawne — na mapie historycznej Religie Germańskie nie są w grze geograficznie. Na mapie eurazjatyckiej (future) snapshot będzie niepusty i warunek aktywuje się normalnie.

---

## Sekcja 5: Warunki przegranej

Przegrana ustawia `religion.defeated_at_turn = state.current_turn`. Religia nie znika — pozostaje w `GameState`, jej prowincje (jeśli jakieś zostały) dalej istnieją w grafie, ale **przestaje liczyć się** do warunków zwycięstwa (Sekcja 6). Defeat nie kończy gry, chyba że przegrał gracz — wtedy MainShell pokazuje `GameOverDialog` w trybie "Przegrałeś" jednorazowo, gracz wybiera "Zamknij" (NPC kontynuują, gracz obserwuje) lub "Nowa gra". Szczegóły UI w Sekcji 6.

**(D1) Eliminacja** (`reason: "elimination"`)

- **Prerequisite**: `religion.ever_owned_province == true` (Sekcja 6 — religia która nigdy nie miała prowincji nie podlega eliminacji)
- Religia ma **0 prowincji** (`state.province_graph.provinces_with_owner(religion.id).is_empty()`)
- Utrzymane przez `≥ ELIMINATION_TURNS_REQUIRED` (5) kolejnych tur

5 tur buforu daje czas na rekonkwistę po `WarManager.force_loss` lub przegranej dyplomatycznej. Religia która **nigdy** nie miała prowincji (np. Manicheizm na mapie historycznej, gdzie żaden owner-province nie jest mu przypisany) nie podlega D1 — gra może toczyć się w nieskończoność, a religia będzie próbować unique-victory (Synkretyczna Iluminacja). Dopiero gdy zdobędzie pierwszą prowincję, ustawi `ever_owned_province = true` i odtąd może być wyeliminowana.

**(D2) Długi wasal** (`reason: "long_vassalage"`)

- **Prerequisite**: `religion.ever_owned_province == true` (musi być realną stroną w grze, by mogła stracić niezależność)
- `religion.suzerain_id != ""` przez `≥ VASSAL_DEFEAT_TURNS_REQUIRED` (20) kolejnych tur
- Bunt (`_process_vassal_revolts` w `TurnManager`) zeruje `suzerain_id` i tym samym resetuje licznik (Sekcja 7)

20 tur to długo — daje miejsce na bunt frakcji, rewolucję, atak patrona. Religia trwale w klientelskim układzie jest defeated tematycznie.

**Future work (poza Plan 12):**
- **Schizma totalna** — wszystkie 3 frakcje religii w Fazie 3 (`SchismManager.get_phase >= 3`) jednocześnie. Wymaga reinterpretacji "jednoczesności" (faza 3 → trigger schizmy → nowa religia → stara religia nie ma już tej frakcji). Odłożone.

---

## Sekcja 6: Koniec gry — flow

### Detekcja w TurnManager

```gdscript
func process_turn(state: Node) -> void:
    # ... istniejący pipeline (passive pressure → ... → vassal revolts) ...
    state.advance_turn()
    var vm := VictoryManager.new()
    vm.check(state)
```

### VictoryManager.check — kolejność

1. Jeśli `state.game_outcome != null` → return (gra już zakończona).
2. **Update flags** dla wszystkich religii (`defeated_at_turn == -1`):
   - Jeśli religia ma `provinces_with_owner.size() > 0` → set `ever_owned_province = true` (trwałe).
   - Jeśli `id == "germanic_paganism"` i `not ragnarok_triggered` i `starting_provinces_snapshot.size() > 0` i `liczba_obecnie_kontrolowanych_z_snapshot ≤ snapshot.size() / 2` → set `ragnarok_triggered = true` (trwałe).
3. **Update liczników** (Sekcja 7) — dla każdej religii z `defeated_at_turn == -1`.
4. **Sprawdź zwycięstwa** — iteruj wszystkie religie z `defeated_at_turn == -1` w deterministycznej kolejności (sortowane po `id` alfabetycznie):
   - Pomiń jeśli `religion.parent_religion_id != ""` ORAZ `state.current_turn - religion.birth_turn < SCHISM_GRACE_TURNS` (schism grace, niżej).
   - Sprawdź `evaluate_unique_victory` → jeśli zwróciło `reason` → set `game_outcome`, return.
   - Sprawdź `evaluate_universal_victory` → jeśli zwróciło `reason` → set `game_outcome`, return.
5. **Sprawdź przegrane** — iteruj wszystkie religie z `defeated_at_turn == -1` i sprawdź `evaluate_defeat`. Pierwsza religia spełniająca warunek → set `religion.defeated_at_turn = state.current_turn`. Defeat-checks **z natury** pomijają religie nigdy-aktywne, bo D1 i D2 mają prerequisite `ever_owned_province == true` (Sekcja 5).
6. Jeśli `state.current_turn ≥ TURN_LIMIT` i `game_outcome` wciąż `null`:
   - Zbuduj ranking spośród religii z `defeated_at_turn == -1` po `prestige` DESC, tie-break alfabetycznie po `id` ASC.
   - `winner_id := ranking[0].religion_id`.
   - `reason := "turn_limit"`.
   - Set `game_outcome`.

**Kolejność unique→universal**: religia, której unikalny warunek został spełniony równocześnie z uniwersalnym, dostaje "swoje" zakończenie tematycznie (np. Islam wygrywa Pełnym Kalifatem, nie Dominacją Terytorialną).

### Stan religii — flagi i ich znaczenie

Brak osobnego pojęcia "dormant" — religia jest opisana **trzema niezależnymi flagami**:

| Flaga | Pole `Religion` | Default | Ustawiana gdy | Resetowana? |
|-------|----------------|---------|---------------|-------------|
| `ever_owned_province` | `bool` | `false` | religia ma ≥1 prowincję w `provinces_with_owner` (sprawdzane w VictoryManager update step **oraz** w `GameState.initialize` dla startowych prowincji) | Nie (trwała) |
| `defeated_at_turn` | `int` | `-1` | warunek D1 lub D2 spełniony (Sekcja 5) | Nie (trwała) |
| `parent_religion_id` | `String` | `""` | religia powstała ze schizmy (SchismManager) | Nie (immutable po utworzeniu) |
| `birth_turn` | `int` | `0` | religia startowa (turn 0) lub `state.current_turn` (schizma) | Nie (immutable po utworzeniu) |
| `ragnarok_triggered` | `bool` | `false` | `germanic_paganism` straciła >50% snapshot (VictoryManager update step) | Nie (trwała) |

**Konsekwencje:**

- Religia z `provinces_with_owner.is_empty() AND ever_owned_province == false` (np. Manicheizm na mapie historycznej):
  - **Może wygrać** przez warunek unikalny niezależny od posiadania prowincji (Manicheizm: C ≥ 90 + 4 absorpcje — żadna z tych metryk nie wymaga prowincji).
  - **Może wygrać** przez warunki uniwersalne (1)/(2)/(3), jeśli zdobędzie prowincje (wtedy `ever_owned_province` ustawia się na true).
  - **Nie podlega D1/D2** dopóki `ever_owned_province == false`.
  - **Liczy się do `second_highest_prestige`** — Manicheizm z prestiż 100 jest realnym kandydatem do warunku (2).
  - **Nie liczy się do `total_provinces`** — bo nie ma prowincji.
- Religia z `defeated_at_turn != -1`:
  - **Nie liczy się do `second_highest_prestige`** — pokonana religia nie blokuje hegemonii.
  - **Nie liczy się do** warunków zwycięstwa (pomijana w iteracji w kroku 4).
  - Jej prowincje (jeśli jakieś jeszcze są — możliwe gdy D2 wasalstwo nie wymaga 0 prowincji) liczą się normalnie w grafie (mogą mieć innego owner-a po wojnach).

**Schizmowe religie:** `parent_religion_id != ""` ORAZ `state.current_turn - birth_turn < SCHISM_GRACE_TURNS` (10) → wszystkie warunki zwycięstwa pomijane (krok 4 spec'a wyżej). **Religie startowe** mają `parent_religion_id == ""` → grace **nigdy się nie aktywuje** dla nich, nawet jeśli `birth_turn = 0` (warunek wymaga obu).

### Total provinces dla dominacji

`total_provinces` w warunku Dominacji Terytorialnej to **statyczna** liczba prowincji w grze: `state.province_graph.all_provinces().size()`. Mapa historyczna = 12. Nie filtruje po `owner != ""` — prowincje bez właściciela (jeśli kiedykolwiek powstaną) wciąż liczą się do denominator, tylko żaden licznik się nie zwiększa. To **deterministyczne** i niewrażliwe na chwilowe stany "no-owner" w trakcie tury.

### UI modal — GameOverDialog

```
┌─────────────────────────────────────────────────┐
│  KONIEC GRY — tura 87                           │
├─────────────────────────────────────────────────┤
│  Zwycięzca: ☪ Islam                             │
│  Warunek: Pełen Kalifat                         │
│  (kontrola Mekki, Jerozolimy i 5 prowincji)     │
├─────────────────────────────────────────────────┤
│  Ranking końcowy:                               │
│  1. ☪ Islam              prestiż 540 (6 prow.)  │
│  2. ✝ Chrz. Zachodnie    prestiż 510 (3 prow.)  │
│  3. ✝ Chrz. Wschodnie    prestiż 480 (2 prow.)  │
│  ...                                            │
├─────────────────────────────────────────────────┤
│  [Nowa gra]  [Zamknij]                          │
└─────────────────────────────────────────────────┘
```

- "Nowa gra" — woła `state.reset()` (Sekcja 8) a następnie `get_tree().change_scene_to_file("res://scenes/Main.tscn")` (powrót do StartMenu — gracz wybiera religię od nowa).
- "Zamknij" — zamyka modal. Button "Zakończ turę" **pozostaje disabled** (gra jest skończona). Gracz może klikać po zakładkach (Mapa, Wiara, Świat, Frakcje) i oglądać końcowy stan świata — żadne dane nie zmienią się.

Jeśli gracz przegrał (`state.get_player_religion().defeated_at_turn != -1`) zanim ktokolwiek wygrał:
- Jednorazowo: modal "Przegrałeś — religia [nazwa] została [eliminowana / długim wasalem]"
- Opcje: "Zamknij" (NPC kontynuują tury, gracz może obserwować) / "Nowa gra"
- Po zamknięciu modal-defeat: Button "Zakończ turę" **pozostaje aktywny** — gracz kontroluje swoją religię w trybie "ducha" (już pokonany, ale technicznie może klikać). Decyzja UX: pozostawić wszystkie akcje dostępne (gracz może próbować rekonkwista, choć jest "defeated"). Alternatywa byłaby disable end-turn, ale to odbiera agency — zostaje aktywny.
- Gdy potem ktokolwiek wygra — wyświetla się drugi modal "Koniec gry" (ten standardowy z opcją "Nowa gra"/"Zamknij").

### MainShell — integracja

```gdscript
func refresh() -> void:
    # ... istniejący kod ...
    _refresh_game_over_state()

func _refresh_game_over_state() -> void:
    var outcome = _state.game_outcome
    if outcome != null and not _shown_outcome_modal:
        _shown_outcome_modal = true
        _show_game_over_dialog(outcome)
    var defeated = _player_just_defeated()
    if defeated and not _shown_defeat_modal:
        _shown_defeat_modal = true
        _show_player_defeat_dialog()
    _end_turn_button.disabled = (outcome != null)
```

Flagi `_shown_outcome_modal` / `_shown_defeat_modal` zapobiegają wielokrotnemu otwarciu po każdym `refresh()` (które jest wywoływane wielokrotnie po End Turn).

---

## Sekcja 7: Liczniki "przez N tur" — semantyka

**Reset przy chwilowej utracie warunku.** Liczniki są kumulatywne **tylko po sobie** — gdy warunek przestaje być spełniony nawet w jednej turze, licznik resetuje się do 0.

Przykład: religia trzyma 6/12 prowincji przez 2 tury, traci jedną prowincję (5/12) w turze 3, odzyskuje w turze 4. Licznik **resetuje się** w turze 3 i startuje od 1 w turze 4. **Nie wygrywa** w turze 5 — wygrałaby dopiero w turze 6 (3 kolejne tury 6+/12).

To wymusza skonsolidowaną dominację. Tematycznie: chwilowa hegemonia ≠ trwałe zwycięstwo.

**Storage liczników** w `GameState.victory_progress` (Dictionary):
```gdscript
victory_progress = {
    "islam": {
        "domination_turns": 2,           # ile tur z rzędu trzyma DOMINATION_PROVINCE_SHARE
        "prestige_hegemony_turns": 0,    # ile tur z rzędu ma 2× drugiego
    },
    "judaism": { ... },
    ...
}
```

**Storage liczników przegranej** w `GameState.defeat_progress`:
```gdscript
defeat_progress = {
    "manichaeism": {
        "zero_provinces_turns": 3,       # ile tur z rzędu ma 0 prowincji
        "vassalage_turns": 0,            # ile tur z rzędu ma suzerain_id != ""
    },
    ...
}
```

Brak licznika → wartość 0 przy odczycie (`get(..., {}).get(..., 0)`).

**Update Cadence**: `VictoryManager.check` w kroku 3 (Sekcja 6) iteruje wszystkie nie-pokonane religie i wykonuje per-licznik:
- Jeśli warunek prerequisitu spełniony → `++licznik`
- Inaczej → `licznik = 0`

Dopiero po update wszystkich liczników następuje sprawdzenie zwycięstw (krok 4) — które porównuje licznik z progiem (`>= DOMINATION_TURNS_REQUIRED` itd.).

**Default-safe access** (chroni przed KeyError przy pierwszym sprawdzaniu):

```gdscript
var prog: Dictionary = state.victory_progress.get(religion.id, {})
var domination_turns: int = prog.get("domination_turns", 0)
```

Update zapisuje z powrotem:

```gdscript
if not state.victory_progress.has(religion.id):
    state.victory_progress[religion.id] = {}
state.victory_progress[religion.id]["domination_turns"] = new_value
```

**Trwałe flagi vs liczniki**:
- **Liczniki** (`victory_progress`, `defeat_progress`): resetują się przy chwilowej utracie warunku.
- **Trwałe flagi** (pola na `Religion`): `ever_owned_province`, `ragnarok_triggered`, `defeated_at_turn`, `birth_turn`, `parent_religion_id`, `absorbed_idea_sources`. Ustawiane raz, nie cofają się. Bez nich nie da się sprawdzić warunków typu "kiedyś-wcześniej-X-potem-Y" (Ragnarök, Manicheizm absorpcja).

---

## Sekcja 8: Modyfikacje danych i kodu

### Nowe pola w `Religion` (`scripts/engine/Religion.gd`)

```gdscript
@export var defeated_at_turn: int = -1                      # -1 = w grze
@export var birth_turn: int = 0                             # 0 = od startu; >0 = ze schizmy
@export var starting_provinces_snapshot: Array[String] = [] # snapshot owner-prowincji w turze 0
@export var ever_owned_province: bool = false               # ustawiane na true przy pierwszej kontrolowanej prowincji
@export var ragnarok_triggered: bool = false                # flaga prefix dla warunku Germanic
@export var absorbed_idea_sources: Array[String] = []       # unikalna lista from_religion_id zaabsorbowanych idei
```

**Backward compatibility**: wszystkie pola mają wartości domyślne. Istniejące fixture JSON-y nie wymagają zmian. `ReligionLoader.load_from_file` pomija nieobecne pola.

### Nowe pola w `GameState` (`scripts/engine/GameState.gd`)

```gdscript
var game_outcome: GameOutcome = null
var victory_progress: Dictionary = {}     # religion_id → {domination_turns, prestige_hegemony_turns}
var defeat_progress: Dictionary = {}      # religion_id → {zero_provinces_turns, vassalage_turns}
```

### Nowe metody pomocnicze w `GameState`

```gdscript
func is_game_over() -> bool:
    return game_outcome != null

func reset() -> void:
    # Zeruje wszystkie pola do stanu sprzed initialize(). Wywoływane przez GameOverDialog
    # "Nowa gra" przed change_scene_to_file. Wszystkie pola muszą być wymienione
    # eksplicitnie — autoload jest persistent w Godot, brak resetu = wyciek stanu.
    current_turn = 1
    player_religion_id = ""
    province_graph = null
    _religions.clear()
    pending_ideas.clear()
    scholar_missions.clear()
    active_wars.clear()
    pending_defeat_events.clear()
    relations.clear()
    active_coalitions.clear()
    missionary_missions.clear()
    game_outcome = null
    victory_progress.clear()
    defeat_progress.clear()
```

**Uwaga**: gdy w przyszłości pojawi się nowe pole w `GameState`, **musi zostać dopisane do `reset()`**. Testy `test_game_state_reset_clears_all_fields` (Plan 12) sprawdzą każde pole indywidualnie.

### `GameState.initialize` — rozszerzenie o snapshot

Snapshot startowych prowincji i flag `ever_owned_province` jest częścią `GameState.initialize`, **nie** osobnej metody w `ReligionLoader` (który jest static-only). Modyfikacja istniejącej metody:

```gdscript
func initialize(player_id: String, religions: Array[Religion], graph: ProvinceGraph) -> void:
    player_religion_id = player_id
    province_graph = graph
    _religions.clear()
    for r: Religion in religions:
        _religions[r.id] = r
    # Po wpisaniu wszystkich religii i grafu — snapshot startowych prowincji.
    # Religia ze startowymi prowincjami dostaje ever_owned_province = true od razu.
    for r: Religion in religions:
        var owned: Array[String] = []
        for province in graph.provinces_with_owner(r.id):
            owned.append(province.id)
        r.starting_provinces_snapshot = owned
        if not owned.is_empty():
            r.ever_owned_province = true
```

`StartMenu._on_start_pressed` (`scripts/ui/StartMenu.gd:40`) już wywołuje `GameState.initialize(...)` — żaden dodatkowy hook nie jest wymagany.

### `SchismManager.trigger_schism` — ustaw `birth_turn`

W `scripts/engine/SchismManager.gd` funkcja `trigger_schism` (linia 48–69), po `new_rel.prestige = SCHISM_INITIAL_PRESTIGE` (linia 55), dodać:

```gdscript
new_rel.birth_turn = state.current_turn
# ever_owned_province ustawia się naturalnie w następnym VictoryManager.check —
# schizma transferuje frakcję bez prowincji, więc flaga zaczyna jako false; jeśli schism
# dostaje prowincje w kolejnych turach (np. via missionary/conquest), flaga ustawi się wtedy.
```

### `DoctrineManager.accept_idea` — track absorbed sources

W `scripts/engine/DoctrineManager.gd` funkcja `accept_idea` (linia 91–93), **po** `religion.shift_axis(idea.axis, idea.delta)`, **przed** `state.pending_ideas.erase(idea)`:

```gdscript
func accept_idea(idea: Idea, religion: Religion, state: Node) -> void:
    religion.shift_axis(idea.axis, idea.delta)
    if idea.from_religion_id != "" and idea.from_religion_id != religion.id:
        if not religion.absorbed_idea_sources.has(idea.from_religion_id):
            religion.absorbed_idea_sources.append(idea.from_religion_id)
    state.pending_ideas.erase(idea)
```

Pole `Idea.from_religion_id` (`scripts/engine/Idea.gd:4`) już istnieje. Guard `from_religion_id != religion.id` chroni przed self-source (krawędziowy przypadek gdy idea jest własna). Test `test_accept_idea_records_source` (Plan 12) zweryfikuje ten hook.

### `TurnManager.process_turn` — końcowe wywołanie

```gdscript
func process_turn(state: Node) -> void:
    # ... istniejący pipeline ...
    state.advance_turn()
    _check_victory_and_defeat(state)

func _check_victory_and_defeat(state: Node) -> void:
    var vm := VictoryManager.new()
    vm.check(state)
```

### `MainShell.gd` — wykrywanie outcome

(patrz pseudokod w Sekcji 6 powyżej — `_refresh_game_over_state`). Modal `GameOverDialog` instancjonowany dynamicznie (jeden raz przy pierwszym wykryciu outcome / defeated player), dodawany jako child do `MainShell`, otwierany `popup_centered()` lub równoważne dla wybranego node-type.

### Scene flow — restart

`GameOverDialog` przycisk "Nowa gra":
1. Wywołuje `GameState.reset()` (Sekcja 8) — zeruje autoload **przed** zmianą sceny, bo autoloady w Godot są persistent między reloadami.
2. Wywołuje `get_tree().change_scene_to_file("res://scenes/Main.tscn")` — wraca do `StartMenu`, gracz wybiera religię od nowa.

**Nie używać** `reload_current_scene()` — to przeładowuje tylko aktywną scenę (`MainShell.tscn`), nie wraca do `Main.tscn`/`StartMenu`. Test `test_new_game_button_calls_reset_then_change_scene` (Plan 12) zweryfikuje kolejność.

---

## Sekcja 9: Test plan

Pliki testowe w `tests/engine/` (silnikowe) i `tests/ui/` (dialog).

### `tests/engine/test_game_state_initialize.gd` (rozszerzenie)

Pokrycie nowych zachowań `initialize` + `reset` — 6–8 testów:
- `test_initialize_snapshots_starting_provinces_per_religion`
- `test_initialize_sets_ever_owned_province_true_for_religions_with_starting_provinces`
- `test_initialize_leaves_ever_owned_province_false_for_religions_with_no_provinces`
- `test_reset_clears_all_engine_fields` (assertion per pole z Sekcji 8 — chroni przed cichym dryfem stanu)
- `test_reset_clears_victory_and_defeat_progress`

### `tests/engine/test_doctrine_manager_idea_sources.gd`

Hook absorbed_idea_sources — 4 testy:
- `test_accept_idea_appends_source_to_absorbed_list`
- `test_accept_idea_does_not_duplicate_existing_source`
- `test_accept_idea_skips_self_source` (idea z `from_religion_id == religion.id` lub `""`)
- `test_absorbed_sources_persist_across_multiple_accepts`

### `tests/engine/test_victory_manager_universal.gd`

Pokrycie warunków uniwersalnych — 10–15 testów:
- `test_domination_triggers_after_3_turns_with_50_percent_provinces`
- `test_domination_resets_counter_on_temporary_loss`
- `test_prestige_hegemony_requires_2x_second_for_10_turns`
- `test_prestige_hegemony_includes_never_owned_religions_in_second_calculation` (Manicheizm prestige 100 liczy się!)
- `test_prestige_hegemony_excludes_defeated_religions_in_second_calculation`
- `test_holy_land_requires_holy_sites_non_empty_prereq` (Manicheizm z `holy_sites=[]` nie spełnia)
- `test_holy_land_requires_all_own_plus_one_foreign`
- `test_unique_victory_takes_precedence_over_universal_when_both_match`
- `test_never_owned_religion_can_win_universal_after_acquiring_provinces`

### `tests/engine/test_victory_manager_unique.gd`

Pokrycie unikalnych warunków — 12–18 testów (≥2 per warunek + edge cases):
- `test_manichaeism_illumination_requires_C_90_and_4_distinct_sources`
- `test_manichaeism_illumination_blocked_with_3_sources`
- `test_manichaeism_illumination_blocked_with_C_89`
- `test_manichaeism_can_win_with_zero_provinces` (never_owned nie blokuje)
- `test_judaism_return_requires_jerusalem_4_provinces_and_unity`
- `test_judaism_return_blocked_when_one_faction_tension_above_30`
- `test_zoroastrianism_renaissance_requires_persepolis_and_3_provinces`
- `test_east_christianity_pentarchy_requires_3_simultaneous_vassals`
- `test_islam_caliphate_requires_mekka_jerusalem_and_5_provinces`
- `test_germanic_ragnarok_triggered_flag_set_on_50_percent_starting_loss`
- `test_germanic_ragnarok_victory_requires_flag_and_100_percent_starting_recovered`
- `test_germanic_ragnarok_blocked_if_flag_not_set`
- `test_germanic_ragnarok_unreachable_with_empty_snapshot` (mapa historyczna — flag nigdy nie set)
- `test_ragnarok_flag_persists_after_temporary_recovery_before_trigger`

### `tests/engine/test_victory_manager_defeat.gd`

Pokrycie warunków przegranej — 8–10 testów:
- `test_elimination_requires_ever_owned_province_prereq` (Manicheizm z 0 prowincji od startu NIE jest eliminated)
- `test_elimination_after_5_turns_zero_provinces_with_ever_owned`
- `test_elimination_resets_counter_on_reconquest`
- `test_long_vassalage_after_20_turns_with_suzerain`
- `test_long_vassalage_requires_ever_owned_province_prereq`
- `test_vassalage_counter_resets_on_revolt`
- `test_defeated_religion_does_not_count_in_active_for_universal_victory`
- `test_defeated_religion_skipped_in_defeat_check_subsequent_turns`

### `tests/engine/test_victory_manager_endgame.gd`

Pokrycie cap turowego + game_outcome — 6–8 testów:
- `test_turn_limit_200_triggers_ranking_winner`
- `test_turn_limit_tiebreak_by_id_alphabetical`
- `test_turn_limit_excludes_defeated_from_ranking`
- `test_game_outcome_set_only_once`
- `test_check_returns_early_when_game_outcome_already_set`
- `test_schism_grace_blocks_victory_for_10_turns_after_birth`
- `test_schism_religion_can_win_after_grace_period`
- `test_starting_religion_not_affected_by_schism_grace` (parent_religion_id="" → grace pomijane mimo birth_turn=0)

### `tests/engine/test_victory_manager_integration.gd`

Integracja z `TurnManager` + SchismManager — 4–6 testów:
- `test_turn_manager_invokes_victory_check_after_advance_turn`
- `test_full_pipeline_does_not_crash_when_no_winner`
- `test_full_pipeline_sets_game_outcome_when_domination_achieved`
- `test_schism_manager_sets_birth_turn_on_new_religion`

### `tests/ui/test_game_over_dialog.gd`

Pokrycie modala — 6–8 testów:
- `test_dialog_displays_winner_name_and_reason`
- `test_dialog_displays_ranking_sorted_desc_by_prestige`
- `test_dialog_ranking_shows_prestige_and_province_count_per_row`
- `test_dialog_displays_correct_polish_reason_label_per_reason_id` (mapping wszystkich 10+ `reason` → PL label)
- `test_main_shell_disables_end_turn_button_when_game_over`
- `test_main_shell_shows_dialog_only_once_after_outcome_set`
- `test_player_defeat_dialog_shows_independently_from_game_over`

### `tests/ui/test_main_shell_game_over.gd`

Integracja MainShell + outcome — 3–5 testów:
- `test_player_defeat_shows_defeat_modal_when_player_defeated`
- `test_new_game_button_calls_reset_then_change_scene` (mock change_scene; weryfikacja kolejności wywołań)
- `test_close_button_keeps_end_turn_disabled_after_outcome`

**Łącznie**: 60–80 testów dla Plan 12. Proporcjonalnie do zakresu spec.

---

## Sekcja 10: Otwarte pytania / future work

**Zapisane do późniejszych spec'ów (poza zakresem Plan 12):**

1. **Schizma totalna jako warunek przegranej** (D3 — odłożone z Sekcji 5). Wymaga reinterpretacji jednoczesności fazy 3 wszystkich frakcji.
2. **Unikalne warunki zwycięstwa dla pozostałych religii:**
   - **Chrześcijaństwo Zachodnie** — "Reformacja Apostolska" (kontrola Rzymu + ≥4 wasali + prestiż ≥600)?
   - **Koptyjski Kościół** — "Pustelnictwo Powszechne" (≥X aktywnych Ojców Pustyni + kontrola Aleksandrii)?
   - **Religie Arabskie** — kontrowersyjne: konwersja do Islamu jako "alternatywne zwycięstwo"? Spec 05 sygnalizuje akcję `[Przyjęcie Islamu]`.
   - **Hinduizm** — "Dharmiczna Trwałość" (kontrola ≥X prowincji przez ≥50 tur — najdłużej trwająca religia)?
   - **Buddyzm** — "Środkowa Droga Globalna" (synkretyczna absorpcja podobna do Manicheizmu, ale skupiona na osi D=Transcendencja)?
   - **Religie Słowiańskie** — "Ziemia Świętych Gajów" (kontrola wszystkich Świętych Gajów + ≥X tur stabilności)?
3. **Konwersja religii** — `[Przyjęcie Islamu]` dla Religii Arabskich (spec 05 otwarte pytanie #3). Mechanika: gdy spełnione warunki C<30 ∧ A>65, dostępna jednorazowa akcja konwertująca Religie Arabskie → Islam. Kto wygrywa? Player kontroluje teraz Islam? Połączone roszczenia o prowincje? Wymaga osobnej spec.
4. **Zjednoczenie ChrZ + ChrW przez dyplomację** (spec 05 otwarte pytanie #1). Mechanika: akcja dyplomatyczna "Sobór Zjednoczeniowy" merguje obie religie w jedną. Wymaga osobnej spec.
5. **Mapa eurazjatycka** — gdy zostanie dodana (>20 prowincji), trzeba **rekalibrować progi** uniwersalne (DOMINATION_PROVINCE_SHARE pozostaje, ale unikalne `_PROVINCES_REQUIRED` dla Islam/Judaism/Zoroastrianism wymagają zwiększenia). Tunable constants w VictoryManager są celowe — zmiana nie wymaga refactor.
6. **Wygrana drużynowa (koalicja)** — czy religie w koalicji mogą wygrać razem? Obecnie nie — każda spełnia warunki osobno. Wymaga osobnej decyzji designu.
7. **Wskaźnik postępu warunków w UI** — sidebar "Do zwycięstwa: 4/6 prowincji (2 tury)" — UX improvement, nie blokujący. Plan 13?
