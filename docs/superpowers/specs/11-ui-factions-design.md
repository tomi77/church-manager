# Projekt zakładki Frakcje (UI frakcji religii gracza)

**Data:** 2026-06-08
**Projekt:** religion-manager
**Status:** Zatwierdzony
**Powiązane:** [UI design](06-ui-design.md) (Sekcja 5), [system doktryn — frakcje](01-doctrine-system-design.md) (Sekcja 2.3, Sekcja 3), [zakładka Wiara](10-ui-wiara-design.md) (wzorzec analogiczny)

---

## Kontekst

Zakładka **Frakcje** to czwarty z czterech tabów `MainShell` (po Mapie, Wierze i Świecie). Obecnie istnieje jako `PlaceholderTab` z napisem `"Frakcje (Plan 11 — w trakcie)"` (`MainShell.gd:15`). Spec opisuje zawartość Sekcji 5 z `06-ui-design.md` — wizualizację trzech frakcji religii gracza: nazwa, wpływ, napięcie, faza schizmy, preferencje doktrynalne.

Zakres MVP — **widok read-only**. Brak akcji `[Stłumienie]`, `[Dialog]`, `[Koncesja]` z `SchismManager.respond_*` — odłożone do future plan (wymagają decyzji UX: modal? lista pending events? walidacja kosztu prestiżu Koncesji). Brak własnych sygnałów wychodzących z FactionsTab (analogicznie do FaithTab — Plan 10).

### Co świadomie odrzucamy z mockupa spec 06 §5 (linia 200–216)

Mockup `06-ui-design.md` §5 zawiera elementy, których obecny engine nie wspiera; **świadomie pomijamy** w MVP, deferowane do future plan:

- **Status "rośnie/słabnie"** — wymaga persystencji `previous_tension` w `Faction` lub historii. Pomijane.
- **"⚠ Żąda: ↑ Mistycyzm (tura 3)"** — pola `Faction.demand`, `demand_axis`, `demand_turn` nie istnieją. Pomijane wraz z pomarańczowym obramowaniem dla aktywnego żądania.
- **Czerwona kropka alertu na zakładce** (06-ui-design.md §1, linia 38) — alert na ikonie zakładki sygnalizujący aktywne żądanie frakcji. W MVP brak żądań → brak alert-dot. Pomijane.
- **Responsywność mobile (swipe między 3 kolumnami)** — MVP zakłada desktop layout (3 widoczne jednocześnie). Mobile deferred.

### Co z mockupa MVP **zachowuje**

Nazwa frakcji, status fazy (`SchismManager.get_phase`), wpływ % (`Faction.influence`), pasek napięcia z wartością (`Faction.tension`), preferencje doktrynalne (`Faction.axis_preferences`), zielone obramowanie dominującej frakcji.

---

## Architektura

Komponenty UI w `scripts/ui/factions/` (analogicznie do `scripts/ui/faith/` z Plan 10):

```
FactionsTab (Control, root)
├── MarginContainer (20 px wokół)
│   └── HBoxContainer (3 kolumny równe, separation 12 px)
│       └── FactionCard (per frakcja, instancjowana dynamicznie)
│           └── VBoxContainer (PanelContainer parent)
```

Każdy komponent ma `bind_state(state: Node)` i `refresh()` — identyczny model jak istniejące taby. Brak własnych sygnałów (zakładka read-only, nie mutuje GameState).

**Integracja `MainShell.gd`** (cztery punktowe zmiany, jeden commit):

1. `MainShell.gd:10` — zmień typ:
   - Z: `@onready var _factions_tab: PlaceholderTab = %FactionsTab`
   - Na: `@onready var _factions_tab: FactionsTab = %FactionsTab`
2. `MainShell.gd:15` — usuń wiersz:
   - `_factions_tab.set_title("Frakcje (Plan 11 — w trakcie)")`
3. `MainShell.gd:28-36` (`bind_state`) — dodaj wywołanie:
   - `_factions_tab.bind_state(s)` (analogicznie do `_faith_tab.bind_state(s)` w linii 33)
4. `MainShell.gd:38-45` (`refresh`) — dodaj wywołanie:
   - `_factions_tab.refresh()` (analogicznie do `_faith_tab.refresh()` w linii 43)

**Integracja `MainShell.tscn`** — `ExtResource` dla `FactionsTab.tscn` zamiast `PlaceholderTab.tscn` dla węzła `FactionsTab` (zachowanie `unique_name_in_owner=true + %FactionsTab`).

---

## Sekcja 1: FactionsTab (kontener)

### Renderowanie

`FactionsTab` to `Control` z `anchors_preset=15` (full rect). Pojedyncze dziecko: `MarginContainer` (margin 20 px po każdej stronie) → `HBoxContainer` (`%CardsContainer`, `unique_name_in_owner=true`) z `separation=12 px` i `size_flags_horizontal=SIZE_EXPAND_FILL`.

`HBoxContainer` nie ma początkowo dzieci — `FactionCard`-y są instancjonowane w `refresh()` z `preload`-owanej sceny `FactionCard.tscn`.

### Refresh model (dynamiczny rebuild)

`FactionsTab.refresh()` postępuje analogicznie do `DoctrineList.refresh()` (Plan 10):

1. Wczesny return jeśli `state == null` lub `state.get_player_religion() == null`.
2. Niszczy wszystkie istniejące dzieci `%CardsContainer` (`for child in %CardsContainer.get_children(): child.queue_free()`).
3. Pobiera religię gracza: `var religion := state.get_player_religion()`.
4. Pobiera dominującą: `var dominant := religion.dominant_faction()` (może być `null` jeśli brak frakcji).
5. Sortuje frakcje stabilnie po `influence` DESC (`stable=true` — zachowuje JSON order przy remisie, zgodne z `Religion.dominant_faction()` linia 36–41).
6. Dla każdej frakcji instancjuje `FactionCard.tscn`, dodaje do `%CardsContainer`, woła `card.bind_faction(faction, religion, faction == dominant)`.

**Wybór dynamicznego rebuild zamiast 3 stałych slotów**: analogicznie do `DoctrineList` (Plan 10). Schizma usuwa frakcję z `religion.factions` (`SchismManager.gd:67`), trait `tribal_pluralism` może w przyszłości tworzyć nowe (UIConstants.gd:97-100 — "40% szansy schizmy plemiennej..."). Hardkod 3 slotów byłby kruchy. Dynamiczny rebuild obsługuje 0, 1, 2, 3, 4+ frakcji bez założeń, koszt GC per refresh akceptowalny (najwyżej 4–6 węzłów).

### Stabilne sortowanie

GDScript `Array.sort_custom(callable)` nie gwarantuje stabilności. Wymagamy stabilności (zachowanie JSON order przy remisie influence), więc używamy wzorca "sort by tuple":

```gdscript
var indexed: Array = []
for i in range(religion.factions.size()):
    indexed.append({"faction": religion.factions[i], "original_index": i})
indexed.sort_custom(func(a, b):
    if a.faction.influence != b.faction.influence:
        return a.faction.influence > b.faction.influence
    return a.original_index < b.original_index
)
```

Inwariant: dla `factions[0].influence == factions[1].influence == factions[2].influence` posortowana kolejność = `[factions[0], factions[1], factions[2]]` (JSON order zachowany).

---

## Sekcja 2: FactionCard

### Layout

`PanelContainer` (root) z `StyleBoxFlat` (theme_override_styles/panel) + `VBoxContainer` jako dziecko. Szerokość `size_flags_horizontal=SIZE_EXPAND_FILL` (równe trzecie wpaść w HBoxContainer). Wysokość ustalona przez zawartość.

```
FactionCard (PanelContainer, size_flags expand)
└── VBoxContainer (margin 12 px wokół przez StyleBoxFlat content_margin)
    ├── %NameLabel              (16 px bold)   "Ulema"
    ├── %PhaseLabel             (12 px szary)  "Faza 1: ruch heretycki"
    ├── HSeparator
    ├── %InfluenceValue         (24 px bold)   "40%"
    ├── %InfluenceLabel         (10 px szary)  "wpływ"
    ├── %TensionBar (ProgressBar, max=100, allow_greater=false)
    ├── %TensionValue           (12 px)        "napięcie 35"
    ├── HSeparator
    ├── %PreferencesLabel       (10 px szary)  "preferencje"
    └── %PreferencesList        (12 px)        "↑ Dogmatyzm · ↑ Hierarchia"
```

Wszystkie nazwane węzły mają `unique_name_in_owner=true` (konwencja CLAUDE.md).

### StyleBoxFlat — dominująca vs zwykła

**Dominująca frakcja** (`is_dominant == true`):
- `bg_color = Color(0.12, 0.18, 0.12)` (lekko zielony półcień)
- `border_color = Color("3aa83a")` (`#3aa83a`)
- `border_width_left/right/top/bottom = 2`
- `content_margin_left/right/top/bottom = 12`

**Zwykła frakcja** (`is_dominant == false`):
- `bg_color = Color(0.1, 0.1, 0.1)` (jak `TraitCard` z Plan 10 §2)
- `border_width_* = 0`
- `content_margin_* = 12`

Style ustawiane w `FactionCard.refresh()` po `bind_faction` (re-tworzone, bo `is_dominant` może się zmienić między refreshami przy schizmie).

### bind_faction + refresh

```gdscript
var _faction: Faction = null
var _religion: Religion = null
var _is_dominant: bool = false

func bind_faction(faction: Faction, religion: Religion, is_dominant: bool) -> void:
    _faction = faction
    _religion = religion
    _is_dominant = is_dominant
    if is_inside_tree():
        refresh()

func _ready() -> void:
    if _faction != null:
        refresh()
```

Wzorzec `is_inside_tree() + deferred refresh` zgodny z konwencjami CLAUDE.md (precedens: `RelationListItem`, `PressureRow`, `TraitCard`).

### Faza schizmy — single source of truth

`FactionCard.refresh()` woła `SchismManager.get_phase(_faction)` (NIE własną implementację):

```gdscript
var sm := SchismManager.new()
var phase: int = sm.get_phase(_faction)
```

Skutek: gdy progi `SchismManager.PHASE1_THRESHOLD/PHASE2/PHASE3` się zmienią, UI automatycznie podąża. Brak duplikacji logiki. Wzorzec analogiczny do referowania `DoctrineManager.AXIS_THRESHOLDS` z Plan 10.

`PhaseLabel.text` i `TensionBar` fill color = `UIConstants.FACTION_PHASE_LABELS[phase]` / `UIConstants.FACTION_PHASE_COLORS[phase]`.

### Mapowanie preferencji osi

`Faction.axis_preferences` to `Array` z elementami `{axis: "A", direction: 1|-1}`. UI mapuje na "↑ {biegun}":

```gdscript
var parts: Array[String] = []
for pref: Dictionary in _faction.axis_preferences:
    var axis: String = pref.get("axis", "")
    var direction: int = pref.get("direction", 0)
    if axis == "" or direction == 0 or not UIConstants.AXIS_POLE_NAMES.has(axis):
        continue
    var pole_dict: Dictionary = UIConstants.AXIS_POLE_NAMES[axis]
    if not pole_dict.has(direction):
        continue
    parts.append("↑ " + pole_dict[direction])
%PreferencesList.text = " · ".join(parts)
```

Strzałka `↑` zawsze w górę — pokazujemy biegun który frakcja **promuje**.

**Semantyka `direction`** (kluczowa, do udokumentowania): wartość `+1` oznacza biegun na wartości 100 osi, `-1` oznacza biegun na wartości 0. Zgodne z `Religion.shift_axis(axis, delta)` (`Religion.gd:25-28`) i `SchismManager.respond_dialoguj` (`SchismManager.gd:38`), gdzie `direction` mnoży deltę przesunięcia. Inwariant ten wymusza `test_axis_pole_names_match_doctrine_spec.gd` (sekcja 4).

### Formatowanie wpływu

`Faction.influence` to `float` 0.0–1.0 (zgodnie z JSON, np. `influence_start: 0.40`). UI formatuje defensywnie z `clampi`, żeby uniknąć "123%" gdyby manager przypadkowo wyszedł poza zakres:

```gdscript
%InfluenceValue.text = "%d%%" % clampi(int(round(_faction.influence * 100.0)), 0, 100)
```

Inwariant: `influence=0.405` → "41%" (round), `influence=0.404` → "40%". Deterministyczne dla testów.

### Formatowanie napięcia

`Faction.tension` to `float` 0.0–100.0. UI:

```gdscript
%TensionBar.value = _faction.tension
%TensionValue.text = "napięcie %d" % int(round(_faction.tension))
```

---

## Sekcja 3: Dodatki w `UIConstants.gd`

### FACTION_PHASE_COLORS

Cztery wpisy (klucze: int 0..3) odpowiadające fazom z `SchismManager`:

```gdscript
const FACTION_PHASE_COLORS: Dictionary = {
    0: Color(0.3, 0.7, 0.3),    # zielony — spokój (<40)
    1: Color(0.85, 0.7, 0.15),  # żółty — ruch heretycki (40..64)
    2: Color(0.95, 0.55, 0.1),  # pomarańczowy — odpływ wiernych (65..84)
    3: Color(0.85, 0.2, 0.2),   # czerwony — pełna schizma (>=85)
}
```

### FACTION_PHASE_LABELS

```gdscript
const FACTION_PHASE_LABELS: Dictionary = {
    0: "Spokój",
    1: "Faza 1: ruch heretycki",
    2: "Faza 2: odpływ wiernych",
    3: "Faza 3: pełna schizma",
}
```

Konwencja kapitalizacji: wszystkie wpisy zaczynają się wielką literą (jak początek zdania w `Label.text`). Frazy po dwukropku z małej (spójne z spec 01 §3).

### AXIS_POLE_NAMES

Mapowanie `{axis_id: {direction: pole_name}}` zgodne ze spec 01 §1 (tabela osi):

```gdscript
const AXIS_POLE_NAMES: Dictionary = {
    "A": {1: "Dogmatyzm",     -1: "Mistycyzm"},
    "B": {1: "Hierarchia",    -1: "Równouprawnienie"},
    "C": {1: "Synkretyzm",    -1: "Ekskluzywizm"},
    "D": {1: "Transcendencja", -1: "Doczesność"},
}
```

Semantyka: klucz `+1` = biegun na wartości 100 osi (tabela spec 01 §1 "Wysoka strona"), klucz `-1` = biegun na wartości 0 ("Niska strona"). **Test parytetu wymagany** (sekcja 4).

---

## Sekcja 4: Testy

### Pliki testowe

```
tests/ui/
├── test_factions_tab.gd
├── test_faction_card.gd
└── test_faction_phase_parity.gd
```

### test_factions_tab.gd — kryteria pokrycia

- `test_tab_renders_without_state`: instancja bez `bind_state` nie crashuje, brak kart.
- `test_tab_renders_three_islam_factions`: po `bind_state` z islamem (3 frakcje w JSON) — 3 instancje `FactionCard` w `%CardsContainer`.
- `test_tab_hides_when_zero_factions`: religia bez frakcji (np. sztuczna `state.get_player_religion().factions = []`) — `%CardsContainer.get_child_count() == 0`, brak crasha.
- `test_tab_handles_two_factions`: religia z 2 frakcjami → 2 karty, nie 3.
- `test_tab_handles_four_or_more_factions`: sztuczne `religion.factions.append(extra_faction)` → 4 karty. Uzasadnia wybór dynamicznego rebuild zamiast 3 stałych slotów (sekcja 1.2 rationale).
- `test_tab_refresh_rebuilds_on_faction_removed`: schizma usuwa frakcję (`SchismManager.trigger_schism`), `refresh()` → 2 karty.
- `test_tab_sorts_by_influence_desc_stable`: 3 frakcje z `influence = [0.30, 0.50, 0.20]` — kolejność kart `[1, 0, 2]`. Z `influence = [0.40, 0.40, 0.20]` (remis [0, 1]) — kolejność `[0, 1, 2]` (JSON order zachowany dla remisu).
- `test_tab_marks_dominant_via_engine_helper`: `religion.dominant_faction()` zwraca frakcję X → odpowiednia karta ma `_is_dominant == true`, pozostałe `false`.
- `test_tab_handles_null_player_religion`: `state.player_religion_id == ""` (lub brak religii) → wczesny return, brak crasha.

### test_faction_card.gd — kryteria pokrycia

- `test_card_renders_without_state`: instancja bez `bind_faction` nie crashuje.
- `test_card_shows_faction_name_and_influence`: po `bind_faction` z Ulema (influence=0.40) — `%NameLabel.text == "Ulema"`, `%InfluenceValue.text == "40%"`.
- `test_card_phase_label_uses_schism_manager`: frakcja z `tension=50` → `%PhaseLabel.text == FACTION_PHASE_LABELS[1]` (faza 1, z `SchismManager.get_phase()`).
- `test_card_phase_boundaries`: `tension=39` → faza 0; `tension=40` → faza 1; `tension=64` → faza 1; `tension=65` → faza 2; `tension=84` → faza 2; `tension=85` → faza 3; `tension=100` → faza 3. Każdy próg referuje `SchismManager.PHASE*_THRESHOLD` (nie literały).
- `test_card_tension_bar_color_matches_phase`: dla każdej fazy 0..3, `%TensionBar` fill color == `FACTION_PHASE_COLORS[phase]`.
- `test_card_preferences_maps_direction_to_pole`: Ulema (`A=+1, B=+1`) → `%PreferencesList.text == "↑ Dogmatyzm · ↑ Hierarchia"`. Sufici (`A=-1, D=+1`) → `"↑ Mistycyzm · ↑ Transcendencja"`. Wojownicy (`C=-1, D=-1`) → `"↑ Ekskluzywizm · ↑ Doczesność"`.
- `test_card_dominant_has_green_border`: `is_dominant=true` → `get_theme_stylebox("panel").border_color == Color("3aa83a")` i `border_width_left == 2`.
- `test_card_non_dominant_has_dark_bg_no_border`: `is_dominant=false` → `bg_color == Color(0.1, 0.1, 0.1)`, `border_width_left == 0`.
- `test_card_handles_influence_zero`: frakcja z `influence=0.0` → `%InfluenceValue.text == "0%"`, brak crasha. (Asercja markingu dominującej przy remisie influence=0 należy do `test_factions_tab.gd::test_tab_sorts_by_influence_desc_stable` — sprawdzane wcześniej.)
- `test_card_handles_all_tension_zero`: faza 0 dla wszystkich, color zielony, `%TensionValue.text == "napięcie 0"`.
- `test_card_handles_empty_axis_preferences`: frakcja bez preferencji → `%PreferencesList.text == ""` (pusty string, brak crasha).
- `test_card_skips_unknown_axis_in_preferences`: `axis="Z"` (nieznana) → pomijany w PreferencesList, brak crasha.

### test_faction_phase_parity.gd — parytety

- `test_phase_colors_keys_match_phases`: `FACTION_PHASE_COLORS.keys()` posortowane = `[0, 1, 2, 3]`.
- `test_phase_labels_keys_match_phases`: `FACTION_PHASE_LABELS.keys()` posortowane = `[0, 1, 2, 3]`.
- `test_phase_keys_are_complete_for_schism_manager`: dla każdej `tension` w `[0, PHASE1_THRESHOLD, PHASE2_THRESHOLD, PHASE3_THRESHOLD, 100]` — `SchismManager.new().get_phase(faction_with_tension(t))` zwraca klucz istniejący w obu słownikach (`FACTION_PHASE_COLORS.has(phase)` i `FACTION_PHASE_LABELS.has(phase)`).
- `test_axis_pole_names_cover_all_doctrine_axes`: `AXIS_POLE_NAMES.keys()` posortowane = `["A", "B", "C", "D"]`. Każdy wpis ma dokładnie klucze `{1, -1}`.
- `test_axis_pole_names_match_doctrine_spec`: weryfikuje literalne wartości:
  - `AXIS_POLE_NAMES["A"][1] == "Dogmatyzm"`, `AXIS_POLE_NAMES["A"][-1] == "Mistycyzm"`
  - `AXIS_POLE_NAMES["B"][1] == "Hierarchia"`, `AXIS_POLE_NAMES["B"][-1] == "Równouprawnienie"`
  - `AXIS_POLE_NAMES["C"][1] == "Synkretyzm"`, `AXIS_POLE_NAMES["C"][-1] == "Ekskluzywizm"`
  - `AXIS_POLE_NAMES["D"][1] == "Transcendencja"`, `AXIS_POLE_NAMES["D"][-1] == "Doczesność"`
  - Zgodne ze spec 01 §1 tabela osi.

---

## Sekcja 5: Pliki

**Nowe:**

```
scripts/ui/factions/
├── FactionsTab.gd
└── FactionCard.gd

scenes/ui/factions/
├── FactionsTab.tscn
└── FactionCard.tscn

tests/ui/
├── test_factions_tab.gd
├── test_faction_card.gd
└── test_faction_phase_parity.gd
```

**Zmienione:**

- `scripts/ui/UIConstants.gd` — dodać `FACTION_PHASE_COLORS`, `FACTION_PHASE_LABELS`, `AXIS_POLE_NAMES`.
- `scripts/ui/MainShell.gd` — cztery punktowe zmiany (Architektura, "Integracja MainShell.gd").
- `scenes/ui/MainShell.tscn` — `ExtResource` dla `FactionsTab.tscn` zamiast `PlaceholderTab.tscn` dla węzła `FactionsTab`.
- `CLAUDE.md` — `FactionsTab` dodać do listy zaimplementowanych tabów w "UI architecture" (przestaje być placeholderem).

---

## Sekcja 6: Konwencje i wzorce

Wszystkie konwencje z `CLAUDE.md` mają zastosowanie:

- **Tab indent** dla wszystkich `.gd`.
- **`class_name`** na każdym skrypcie UI (`FactionsTab`, `FactionCard`).
- **`unique_name_in_owner = true` + `%Name`** dla wszystkich nazwanych dzieci (`%CardsContainer`, `%NameLabel`, `%PhaseLabel`, `%InfluenceValue`, `%InfluenceLabel`, `%TensionBar`, `%TensionValue`, `%PreferencesLabel`, `%PreferencesList`).
- **`is_inside_tree()` guard** w setterach przed dostępem do `@onready` (precedens: `RelationListItem`, `PressureRow`, `TraitCard`).
- **`emit_signal("name", args)`** — w MVP nieużywane (read-only).
- **Identyfikatory ANGIELSKIE**: nazwy plików, klas, zmiennych, sygnałów, ID — angielski. Polski tylko w `Label.text`, `display_name`, komentarzach, JSON. Zgodne z memory `feedback_english_identifiers.md` i CLAUDE.md "Identifier language".
- **Stałe progowe z managerów** — `FactionCard` referuje `SchismManager.get_phase()` i `SchismManager.PHASE*_THRESHOLD` zamiast literałów. Tests też.
- **Regeneracja class cache po dodaniu `class_name`** — spec wprowadza dwa nowe `class_name` (`FactionsTab`, `FactionCard`). Per `CLAUDE.md:30`, headless GUT może zwrócić "Could not find type X" dopóki `.godot/global_script_class_cache.cfg` nie zostanie odświeżony. Przed pierwszym headless runie należy otworzyć projekt w edytorze Godot raz (lub uruchomić `godot --headless --path . --quit`) — wzorzec analogiczny do Plan 10.

---

## Pytania otwarte

Brak — wszystkie decyzje projektowe rozstrzygnięte w wyniku review designu (C1–C4, I1–I5).

---

*Spec zatwierdzona — gotowa do planowania implementacji.*
