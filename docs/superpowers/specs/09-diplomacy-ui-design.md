# UI Dyplomacji — Specyfikacja

**Data:** 2026-06-07
**Projekt:** religion-manager (rename z church-manager — Task 0 w Planie 08)
**Status:** Zatwierdzony — gotowy do planowania implementacji
**Powiązane:** [UI design — master spec](06-ui-design.md), [dyplomacja](03-diplomacy-system-design.md), [wasalstwo](07-vassalage-system-design.md), [dyplomacja vs wojna](08-diplomacy-war-bridge-design.md), [plan dyplomacji](../plans/04-mechaniki-dyplomacja.md), [plan wasalstwa](../plans/06-mechaniki-dyplomacja-wasal.md), [plan dyplomacja vs wojna](../plans/07-mechaniki-dyplomacja-vs-wojna.md)

---

## Kontekst

To pierwszy plan UI w projekcie. Stan wyjściowy:
- `scripts/ui/` puste · `scenes/Main.tscn` to gołe `Node2D`
- Plany 01–07 zaimplementowały silnik gry (262 → 295 testów PASS)
- Spec [06-ui-design.md](06-ui-design.md) opisuje docelowe UI (4 zakładki, responsywność mobile↔desktop) — jest "platform-agnostyczny"

Plan 08 implementuje **podzbiór spec 06**: tylko zakładka Świat (sek.6) + obowiązkowy shell wokół niej, **wyłącznie dla desktop (≥ 768 px)**. Pozostałe zakładki (Mapa/Wiara/Frakcje) są placeholderami. Mobile breakpoint, animacje przejść i pełny UI wojny trafiają do późniejszych planów.

**Tech stack:** Godot 4.6, GDScript 2.0, sceny `.tscn` z osobnymi skryptami, sygnały Godota dla komunikacji, GUT do testów.

Spec 09 **nie zastępuje** spec 06 — uszczegóławia go i w jednym miejscu (zakładka Świat, sek.6) **rewiduje** ("siatka kart 2-kol + modal" → "master-detail: lista lewa + panel akcji prawa", patrz Sekcja 6 niżej).

---

## Sekcja 1: Zakres Plan 08

### W zakresie

- **Task 0 — rename projektu:** `church-manager` → `religion-manager` (project.godot, README, ewentualne cross-refs)
- **Shell UI:** header globalny (spec 06 sek.2 wariant desktop) + pasek 4 zakładek
- **3 placeholdery:** Mapa / Wiara / Frakcje — zawierają `Label` "Plan X — w trakcie", reszta pusta
- **StartMenu:** wybór jednej z 12 religii startowych przed rozpoczęciem gry
- **Zakładka Świat:** pełna implementacja per Sekcja 6
- **8 akcji dyplomatycznych** plus 1 sekcja "Aktywne konflikty" z akcją Sobór Pokojowy (per Sekcja 7)
- **Display-only:** grievance counter, koalicja przeciw graczowi, status wasalstwa, bonus HolyWar

### Poza zakresem (przyszłe plany)

| Plan | Zakres |
|---|---|
| 09 | UI Mapa — pseudo-geograficzna siatka SVG, panel prowincji, akcja Wypowiedz wojnę (pełny CB picker) |
| 10 | UI Wiara — wykres radarowy osi, lista doktryn, trait |
| 11 | UI Frakcje — kolumny frakcji, żądania, Sobór ludowy |
| 12 | UI Wojna — `offer_peace` z konfigurowalnymi warunkami, `attack_province`, `resolve_defeat` |
| 13 | Podsumowanie tury (overlay 4-kafelkowy ze spec 06 sek.7) |
| 14 | Mobile responsive (spec 06 sek.8) |

---

## Sekcja 2: Architektura plików

```
scenes/
├── Main.tscn                          (root staje się Control z child=StartMenu)
├── StartMenu.tscn                     (nowe)
└── ui/
    ├── MainShell.tscn                 (Control · Header + TabBar + content_area)
    ├── Header.tscn                    (HBoxContainer)
    ├── TabBar.tscn                    (HBoxContainer · 4 przyciski)
    ├── PlaceholderTab.tscn            (reusable — param Title)
    └── world/
        ├── WorldTab.tscn
        ├── ConflictSection.tscn
        ├── RelationList.tscn
        ├── RelationListItem.tscn
        ├── ActionPanel.tscn
        └── AxisDeltaPicker.tscn

scripts/ui/
├── StartMenu.gd
├── MainShell.gd
├── Header.gd
├── TabBar.gd
├── PlaceholderTab.gd
└── world/
    ├── WorldTab.gd
    ├── ConflictSection.gd
    ├── RelationList.gd
    ├── RelationListItem.gd
    ├── ActionPanel.gd
    └── AxisDeltaPicker.gd

tests/ui/
├── test_start_menu.gd
├── test_main_shell.gd
├── test_header.gd
├── test_tab_bar.gd
├── test_placeholder_tab.gd
├── test_relation_list.gd
├── test_relation_list_item.gd
├── test_action_panel.gd
├── test_axis_delta_picker.gd
├── test_conflict_section.gd
└── test_world_tab_integration.gd
```

### Wzorce

- Każda scena UI ma jeden odpowiadający skrypt z `class_name`. Pliki ≤ ~150 linii każdy.
- Komunikacja **dziecko → rodzic** przez sygnały Godota (`signal religion_selected(id: String)`).
- Komunikacja **rodzic → dziecko** przez settery (`set_relation(rel, religion)`).
- `GameState` (autoload) — jedyne źródło prawdy. UI **czyta** stan, akcje **modyfikują** przez managery: `DiplomacyManager.new()`, `WarManager.new()` (stateless RefCounted).
- 4-spacjowy indent zgodnie z konwencją silnika (z wyjątkiem `DoctrineManager.gd` który używa tabów — UI trzyma się spaces).

---

## Sekcja 3: StartMenu

### Layout

Siatka 4×3 z 12 religiami (kolejność z pal[ety spec 06 sek.3). Każda karta:
- Ikona religii (emoji)
- Nazwa
- Podpis: dominująca prowincja startowa + nazwa traitu (per spec 05)
- Kolor tła = kolor wielokąta z palety spec 06

Stan wybrany: zielona ramka. Pasek dolny: tekst "Wybrana: X — opis traitu" + przycisk "Rozpocznij grę →" (disabled gdy nic nie wybrane).

### Zachowanie

1. Klik karty → emit `religion_selected(id)`
2. `StartMenu.gd` przechowuje `selected_id`, włącza przycisk
3. Klik "Rozpocznij grę" → `GameState.initialize(selected_id, religions, graph)` → `get_tree().change_scene_to_file("res://scenes/ui/MainShell.tscn")`

### Źródło religii

`ReligionLoader.load_all()` (istniejący w silniku — wczytuje 12 plików `.tres` z `data/religions/`). Lista jest stała, brak edycji w UI.

---

## Sekcja 4: Shell — Header + TabBar

### Header globalny (1 linia desktop)

Per spec 06 sek.2 wariant desktop:

```
[ikona] [Nazwa religii] [Tura N] [⚑ N] [📦 +X/turę] [🌾 +Y/turę] [⚔ N aktywna] [⚠ Frakcja] [Zakończ turę →]
```

Wartości:
- ikona/nazwa: `player.icon`, `player.name`
- Tura: `state.current_turn`
- prestiż: `player.prestige`
- 📦 zasoby/turę: `DiplomacyManager.PASSIVE_INCOME_PER_TURN` plus suma trybutu od klientów (`+TRIBUTE_PER_TURN × |clients|`), minus trybut do patrona jeśli gracz jest klientem (`-TRIBUTE_PER_TURN`). Per spec 07 sek.3. Ikona `📦` (nie `💰`) — silnik nie rozróżnia złota/żywności, jedno pole `Religion.resources`.
- 🌾 żywność: zsumowane `province.resources["food"]` ze wszystkich prowincji gracza (per spec 04)
- ⚔ liczba aktywnych wojen (czerwony gdy >0): liczba wojen z `war.state != "ENDED"` gdzie gracz jest stroną
- ⚠ alert frakcji: jeśli `player.dominant_faction().tension > 80`
- Zakończ turę: przycisk wywołuje `TurnManager.new().process_turn(state)`, potem emit `turn_ended`

### TabBar

4 przyciski w `HBoxContainer`: 🗺 Mapa · 🕌 Wiara · 🌍 Świat · 👥 Frakcje.

- Aktywna zakładka: zielony underline + bold
- Placeholdery (Mapa/Wiara/Frakcje): klik przełącza, pokazuje `PlaceholderTab` z tekstem "Plan X — w trakcie"
- Świat: domyślnie aktywna po starcie
- Alert dot (czerwona kropka 6px): pokazuje się gdy:
  - Świat → koalicja przeciw graczowi LUB dostępny CB Rewanż
  - Frakcje → `player.dominant_faction().tension > 80`
  - Mapa/Wiara — brak alertów w Plan 08

### MainShell

Kontener orchestrujący:
- Header + TabBar zawsze widoczne
- Content area: stack of {WorldTab, MapPlaceholder, FaithPlaceholder, FactionsPlaceholder}, tylko aktywna `visible = true`
- Slot `_on_state_changed()` woła `_refresh_all()` na header + aktywną zakładkę

---

## Sekcja 5: Placeholdery (Mapa/Wiara/Frakcje)

Każda używa wspólnego `PlaceholderTab.tscn`:
- Centralny `Label`: nazwa zakładki + "(Plan X — w trakcie)"
- Tło: jednolite ciemne
- Brak interakcji

Param `title` ustawiany w `_ready()` z eksportu w `.tscn`.

---

## Sekcja 6: Zakładka Świat — master-detail

**Rewizja spec 06 sek.6:** spec 06 zakładał "siatka kart 2-kol + modal akcji" dla desktop. Plan 08 zmienia to na **master-detail** ze względu na rozszerzoną listę akcji (8 + axis picker dla soborów), która jest zbyt obciążona dla modalu.

### Layout (top-down)

1. **Sekcja "Aktywne konflikty"** (zwijana — widoczna tylko gdy są wojny gracza)
   - Czerwone tło, każda wojna w 1 wierszu
   - Format: `🔥 [target] · tura T/? · [atak gracza / atak NPC] · CB: [nazwa]`
   - Wskaźnik weariness: pasek 4-segmentowy
   - Przycisk po prawej: `Sobór Pokojowy (25⚑)` — disabled gdy prestiż < 25
   - HolyWar indicator: gdy `CB ∈ {krucjata, dżihad}` AND ma sojusznika w świętej wojnie → ikona `+15%`

2. **Główna sekcja: 2 kolumny CSS-grid (260px ↔ 1fr)**

   **Lewa kolumna: RelationList**
   - `ScrollContainer` z `VBoxContainer` w środku
   - Iteracja po `state.all_religions()` z filtrem `id != player_id`
   - Każdy wiersz `RelationListItem`:
     - Ikona + nazwa religii
     - Pasek mini Z/E/N (po 6px wysokie) z liczbą
     - Marker statusu po prawej:
       - `🤝` (sojusznik) · `⚔` (aktywna wojna) · `↑👑` (nasz klient) · `⛰` (nasz patron)
       - `●` (członek koalicji przeciw nam) · `⚠` (CB Rewanż dostępne)
   - Klik wiersza: emit `religion_selected(id)`, wiersz dostaje lewy border w kolorze religii
   - Sortowanie: aktywne wojny → koalicja przeciw → sojusznicy → wasale → reszta alfabetycznie

   **Prawa kolumna: ActionPanel** (patrz Sekcja 7)

### Pusty stan

Gdy `state.all_religions().size() == 1` (tylko gracz, edge case testowy): RelationList pokazuje "Brak innych religii", ActionPanel pokazuje pusty placeholder.

---

## Sekcja 7: ActionPanel — akcje per target

### Layout panelu

```
[Ikona+Nazwa target religii]
[Subtitle: sąsiad · pokój · koalicja · wasal]

┌─ Wskaźniki relacji ──┐  ┌─ Akcje ──────────────┐
│ Z: ████████░░ 65     │  │ [🤝 Sojusz 20⚑]      │
│ E: █████░░░░░ 40     │  │ [⛔ Interdykt 15⚑]   │
│ N: ███░░░░░░░ 35     │  │ [📜 Misjon. 10⚑]     │
│                      │  │ [⚖ Sob.ekum. 30⚑]    │
│ ⚠ Grievance: …       │  │ [👑 Wasal: patron]   │
│ (gdy aktywne)        │  │ [⚔ Rewanż] ← cond.   │
│                      │  │ [⛰ Wasal: klient]    │
│ Koalicja: …          │  └──────────────────────┘
│ (gdy gracz target)   │
└──────────────────────┘  ┌─ AxisDeltaPicker ────┐
                          │ Oś: A B [C] D        │
                          │ Δ: −8 −5 [+5] +8     │
                          │              [Wykonaj]│
                          │ (widoczny gdy klik Sobór) │
                          └──────────────────────┘
```

### Specyfikacja akcji

| # | Akcja | Engine call | Warunki włączenia | Confirm | Tooltip gdy disabled |
|---|---|---|---|---|---|
| 1 | **Sojusz** 🤝 | `DiplomacyManager.declare_alliance(state, player_id, target_id)` | prestiż ≥ 20 · brak aktywnej wojny · `rel.trust > 50` OR `rel.economy > 60` · NIE (player.C<20 AND target.C>60) | nie | "Wymaga zaufania >50 lub ekonomii >60" · "Brak prestiżu (20⚑)" · "Zablokowane przez Ekskluzywizm" |
| 2 | **Interdykt** ⛔ | `DiplomacyManager.proclaim_interdict(state, player_id, target_id)` | prestiż ≥ 15 · `target.interdict_immunity_until ≤ state.current_turn` | **tak** | "Brak prestiżu (15⚑)" · "Target ma immunitet do tury X" |
| 3 | **Misjonarze** 📜 | `DiplomacyManager.send_missionaries(state, player_id, target_id)` | prestiż ≥ 10 · `rel.trust > 30` · `player.C ≥ 20` | nie | "Wymaga zaufania >30" · "Twój Ekskluzywizm blokuje (C<20)" |
| 4 | **Sobór ekum.** ⚖ | `DiplomacyManager.ecumenical_council(state, player_id, target_id, axis, delta)` | prestiż ≥ 30 · `rel.trust > 60` · `rel.military_tension < 85` · `player.C > 40` · `\|delta\| ∈ [3,8]` | nie | "Wymaga zaufania >60" · "Napięcie za wysokie (>85)" · "Twój Synkretyzm <40" |
| 5 | **Wasal: patron** 👑 | `DiplomacyManager.recognize_suzerainty(state, client_id=target_id, patron_id=player_id)` | engine guardy: `target.suzerain_id == ""` · `target.A < SUZERAINTY_DOGMATYZM_BLOCK (80)` · `rel.trust > SUZERAINTY_TRUST_THRESHOLD (40)` · brak aktywnej wojny gracz↔target · UI policy: ukryj gdy `player.suzerain_id != ""` (chains-of-vassalage zabronione w UI) | nie | "NPC ma już patrona" · "Dogmatyzm NPC za wysoki (≥80)" · "Wymaga zaufania >40" |
| 6 | **Wasal: klient** ⛰ | `DiplomacyManager.recognize_suzerainty(state, client_id=player_id, patron_id=target_id)` | engine guardy: `player.suzerain_id == ""` · `player.A < 80` · `rel.trust > 40` · brak aktywnej wojny | nie | (ukryty gdy gracz silniejszy — heurystyka UI: `player.prestige > target.prestige × 1.5`) |
| 7 | **Sobór wasalski** ⚖↓ | `DiplomacyManager.vassal_council(state, patron_id=player_id, client_id=target_id, axis, delta)` | tylko gdy `target.suzerain_id == player_id` · `player.B > VASSAL_COUNCIL_HIERARCHIA_THRESHOLD (75)` · `state.current_turn > rel.vassal_council_cooldown_until` · prestiż ≥ 30 · `\|delta\| ∈ [3,8]` | nie | (niewidoczny gdy nie patron tego target) · "Wymaga Hierarchii >75" · "Cooldown do tury X" |
| 8 | **Rewanż** ⚔ | `WarManager.new().declare_war(player_id, target_id, "rewanz", state)` | `"rewanz" in WarManager.new().available_casus_belli(player, target, state)` (per Plan 07) | **tak** | (niewidoczny gdy brak CB) |

**Sobór Pokojowy** (poza panelem akcji — w sekcji "Aktywne konflikty"):
- Engine: `DiplomacyManager.peace_council(state, player_id)`
- Warunki: aktywna wojna gracza · prestiż ≥ 25
- Confirm: nie (akcja konstruktywna)

### AxisDeltaPicker

Widoczny tylko gdy klik "Sobór ekum." lub "Sobór wasalski":
- 4 przyciski osi (A/B/C/D), single-select
- 4 przyciski delty (−8, −5, +5, +8), single-select. Wartości pasują do `COUNCIL_MIN_AXIS_DELTA=3` i `COUNCIL_MAX_AXIS_DELTA=8` z `DiplomacyManager`.
- Przycisk "Wykonaj" — disabled dopóki nie wybrane oś AND delta
- Klik "Wykonaj" → wywołanie odpowiedniego soboru z parametrami, picker chowa się

### Stany niedostępności

- **Wyszarzone (disabled) + tooltip** dla wszystkich akcji których warunek osiowy/prestiżowy/kontekstowy nie jest spełniony
- **Ukryte** tylko gdy akcja **fundamentalnie nie ma sensu**:
  - Sobór wasalski: gdy target nie jest naszym klientem
  - Rewanż: gdy CB niedostępne
  - Wasal: klient: gdy gracz silniejszy

### Confirm dialog

`ConfirmationDialog` Godota z tytułem akcji + krótkim podsumowaniem ("Rzucić Interdykt na Chr.Zach? Kosztuje 15 prestiżu i podnosi napięcie."). Tylko dla Interdyktu i Rewanża.

### Wskaźnik Grievance

Gdy `player.interdict_grievance_until > state.current_turn` AND `player.interdict_grievance_from_id == selected_target_id`:

```
⚠ Grievance: Interdykt
[target] rzuciło na nas Interdykt tura X.
CB Rewanż dostępne do tury Y (Z tur).
```

### Wskaźnik koalicji przeciw graczowi

Gdy istnieje `c ∈ state.active_coalitions` gdzie `c.target_id == player.id`:

```
🔻 Koalicja przeciw nam
Członkowie (4): Chr.Zach, Chr.Wsch, Zoroastryzm, Manicheizm
```

Wskaźnik pokazany w panelu **niezależnie od wybranego target** (każdy panel pokazuje stan koalicji od strony gracza).

---

## Sekcja 8: Refresh policy + sygnały

### Pętla danych

1. UI inicjalnie buduje się z `GameState` w `_ready()` MainShella
2. Akcja gracza:
   - Klik przycisku w `ActionPanel`
   - Wywołanie metody managera (`DiplomacyManager` / `WarManager`)
   - Manager modyfikuje GameState (Religion fields, state.relations, state.active_wars)
   - Manager zwraca `bool` (success)
3. `ActionPanel` emit `state_changed`
4. `WorldTab._on_action_panel_state_changed()` woła `refresh()`:
   - `RelationList.refresh()` — odtwarza wiersze
   - `ActionPanel.refresh()` — odtwarza wskaźniki + buttony dla selected target
   - `ConflictSection.refresh()` — odtwarza listę wojen
5. `MainShell._on_world_tab_state_changed()` woła `Header.refresh()`

### End Turn

Klik "Zakończ turę" w Header:
- `Header.gd` woła `TurnManager.new().process_turn(state)`
- emit `turn_ended` (Header signal)
- `MainShell._on_header_turn_ended()` woła `_refresh_all()` (header + active tab)

### Brak optymalizacji częściowych refresów

Plan 08 nie implementuje dirty-tracking ani delta-renderowania. Każdy `refresh()` przepisuje całą sekcję. To akceptowalne na małej liście (≤12 religii, ≤4 aktywne wojny).

---

## Sekcja 9: Strategia testów

Runner: GUT, headless: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit`.

### Wzorzec testów scen

Każda scena testowana przez `preload(...).instantiate()`, dodana do drzewa testowego przez `add_child_autofree()`, parametryzowana setterem, asercja przez `get_node("%LabelName").text` lub `signal_emitted`.

### Pliki testowe i pokrycie

| Plik | Co weryfikuje |
|---|---|
| `test_start_menu.gd` | klik karty → emit `religion_selected(id)` · "Rozpocznij grę" disabled gdy brak wyboru |
| `test_main_shell.gd` | End Turn → `TurnManager.process_turn` wywołane · header refresh po turze |
| `test_header.gd` | render `player.prestige` · refresh po sygnale · czerwony `⚔` gdy `active_wars > 0` · alert frakcji gdy tension > 80 |
| `test_tab_bar.gd` | klik zakładki → przełączenie · alert dots · Świat domyślnie aktywna |
| `test_placeholder_tab.gd` | renderuje param `title` |
| `test_relation_list.gd` | filtruje gracza · sortuje · emit `religion_selected` |
| `test_relation_list_item.gd` | render ZEN · markery sojuszu/wojny/wasala/koalicji/Rewanża |
| `test_action_panel.gd` | gating 8 akcji (osobny test per akcja) · tooltipy · klik wywołuje manager · refresh po akcji · confirm dialog dla Interdyktu i Rewanża |
| `test_axis_delta_picker.gd` | wybór osi · wybór delty · "Wykonaj" emit sygnał z parametrami |
| `test_conflict_section.gd` | filtruje wojny gracza · klik Negocjuj → peace_council · HolyWar indicator |
| `test_world_tab_integration.gd` | end-to-end: klik wiersza → klik Sojusz → state.relations zaktualizowany, prestiż gracza spadł, header refresh |

### Stuby / izolacja

- `GameState` autoload: w testach unit zastępujemy lokalnym Node z minimalnymi polami (wzorzec już używany w `tests/engine/`)
- Sceny: testowane z `.tscn`, nie konstruowane programatycznie (łapie błędy NodePath)
- Sygnały: `watch_signals(node)` + `assert_signal_emitted_with_parameters`

### Cel pokrycia

- Każdy publiczny `func` w `scripts/ui/` ma ≥1 test
- Każdy stan UI (selected/disabled/hidden/with-axis-picker/with-grievance/with-coalition) ma test renderowania
- Każda z 8 akcji ma test end-to-end w `test_world_tab_integration.gd`

### Stan startowy testów

Plan 07 zostawił 295/295 PASS. Plan 08 dodaje **co najmniej 50 testów UI** (orientacyjnie: 11 plików × 4-6 testów średnio). Docelowo ~345-360 PASS.

---

## Sekcja 10: Decyzje zatwierdzone w brainstormingu (2026-06-07)

| Decyzja | Wartość |
|---|---|
| Zakres Plan 08 | Shell + zakładka Świat (placeholdery Mapa/Wiara/Frakcje) |
| Responsywność | Tylko desktop ≥768 px (mobile w przyszłym planie) |
| UI wojny | Tylko Rewanż jednoprzyciskowo (pełny CB picker w Plan 09) |
| Bootstrap gracza | StartMenu z 12 religiami (osobna scena) |
| Confirm akcji | Tylko destrukcyjne (Interdykt, Rewanż) |
| Akcje niedostępne | Wyszarzone + tooltip "dlaczego" (chyba że fundamentalnie bez sensu → ukryte) |
| Wasalstwo dwukierunkowe | Dwa przyciski warunkowe (Patron / Klient) |
| Layout zakładki Świat | Master-detail (lista lewa + panel akcji prawa) — rewizja spec 06 sek.6 |
| Sobór ludowy | Wycięty z Plan 08 (trafia do Plan 11 — Frakcje) |
| Rename projektu | Task 0 w Plan 08: church-manager → religion-manager |

---

## Pytania otwarte

*(brak — wszystko rozstrzygnięte w brainstormingu)*

---

*Spec zatwierdzona — gotowa do planowania implementacji w `docs/superpowers/plans/08-mechaniki-ui-dyplomacji.md`.*
