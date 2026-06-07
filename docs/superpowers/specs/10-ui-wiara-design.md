# Projekt zakładki Wiara (UI profilu teologicznego)

**Data:** 2026-06-07
**Projekt:** religion-manager
**Status:** Zatwierdzony
**Powiązane:** [UI design](06-ui-design.md), [system doktryn](01-doctrine-system-design.md), [profile religii](05-religion-profiles-design.md)

---

## Kontekst

Zakładka **Wiara** to drugi z czterech tabów `MainShell` (po Mapie, przed Światem i Frakcjami). Obecnie istnieje jako `PlaceholderTab` z napisem "Wiara (Plan 10 — w trakcie)". Spec opisuje zawartość Sekcji 4 z `06-ui-design.md` — profil teologiczny religii gracza: radar diamentowy 4 osi, karta unikalnego traitu, lista doktryn z mechaniki osi progowych.

Frakcje (Sekcja 5 specu UI) **nie** wchodzą w zakres tego speca — są osobnym Plan 11 (`FrakcjeTab` placeholder w `MainShell`).

Zakres MVP — **widok read-only**. Brak akcji `[Sobor]`, `[Edykt]`, `[Wyślij Badacza]`, `[Aktywuj doktrynę]`. Doktryny mają tylko 2 stany: `dostępna` / `zablokowana` (engine nie persystuje aktywnych doktryn — to future plan).

---

## Architektura

Komponenty UI w `scripts/ui/wiara/` (analogicznie do `scripts/ui/map/` z Plan 09):

```
WiaraTab (Control, root)
├── VBox
│   ├── AxisRadar       — diament 4 osi + tabela wartości
│   ├── TraitCard       — karta traitu (nazwa + opis)
│   └── DoctrineList    — VBox z DoctrineRow per akcja
│       └── DoctrineRow — ikona stanu + nazwa + warunek osi
```

Każdy komponent ma `bind_state(state: Node)` i `refresh()` — identyczny model jak istniejące taby. Brak własnych sygnałów `state_changed` (zakładka read-only, nie mutuje GameState).

**Integracja `MainShell`** (jedna spójna zmiana):
- `_wiara_tab: PlaceholderTab` → `_wiara_tab: WiaraTab` w `MainShell.gd:8`
- Usunąć `_wiara_tab.set_title("Wiara (Plan 10 — w trakcie)")` z `_ready()` (`MainShell.gd:15`)
- Dodać `_wiara_tab.bind_state(s)` w `bind_state()` analogicznie do `_mapa_tab.bind_state(s)`
- Dodać `_wiara_tab.refresh()` w `refresh()` analogicznie do `_mapa_tab.refresh()`
- W `MainShell.tscn` instancja `PlaceholderTab.tscn` zastąpiona `WiaraTab.tscn` (ExtResource id="4" pozostaje używana przez `FrakcjeTab`, więc nie usuwamy jej z listy zewnętrznych zasobów — dodajemy nową ExtResource dla `WiaraTab.tscn`)

---

## Sekcja 1: AxisRadar

### Renderowanie

Diament rysowany jak `MapView`: `Control` kontener (fixed size **400×400**) z dziećmi `Polygon2D` i `Line2D`. Centrum diamentu = centrum kontrolki (200, 200). Każda wartość osi 0–100 mapuje się na promień 0 → **160 px** (pozostawia 40 px paddingu od krawędzi pod etykiety osi).

**Węzły dzieci:**
- `GridPolygon25`, `GridPolygon50`, `GridPolygon75` — `Line2D` zamknięte (4 wierzchołki, closed=true), kolor `Color(0.27, 0.27, 0.27)` (`#444`), szerokość 1 px. Statyczne, rysowane raz w `_ready()`.
- `AxisLines` — 4 osobne `Line2D` od centrum do wierzchołka 100% (kolor `Color(0.4, 0.4, 0.4)` `#666`, szerokość 1 px). Statyczne.
- `ValuePolygon` — `Polygon2D` z 4 wierzchołkami = aktualne wartości osi. Kolor wypełnienia = `UIConstants.religion_color(religion.id)` z alfą 0.4.
- `ValueOutline` — `Line2D` zamknięty po tych samych 4 wierzchołkach, kolor = `UIConstants.religion_accent_color(religion.id)`, szerokość 2 px.
- `LabelA`, `LabelB`, `LabelC`, `LabelD` — `Label` w 4 rogach (góra/prawo/dół/lewo, w obszarze 40 px paddingu poza wierzchołkami 100%), tekst odpowiednio: "Dogmatyzm" / "Hierarchia" / "Synkretyzm" / "Transcendencja".

Pola `Religion.color` i `Religion.accent_color` to `String` (hex). UI **nie czyta ich bezpośrednio** — używa helperów z `UIConstants`, które zwracają `Color`. Wzorzec spójny z `MapView` (Plan 09).

**Konwencja osi** (z `06-ui-design.md` Sekcja 4):
- A (góra) — Dogmatyzm
- B (prawo) — Hierarchia
- C (dół) — Synkretyzm
- D (lewo) — Transcendencja

**Mapowanie wartości na pozycję** (offset od centrum kontrolki 200, 200): dla wartości `v` w osi:
- `radius = (v / 100.0) * 160.0`
- A → `Vector2(200, 200 - radius)` (góra)
- B → `Vector2(200 + radius, 200)` (prawo)
- C → `Vector2(200, 200 + radius)` (dół)
- D → `Vector2(200 - radius, 200)` (lewo)

### Tabela wartości

Pod radarem `HBoxContainer` z 4 `Label`-ami: `A: 70 · B: 65 · C: 30 · D: 75`. Separator `·` między wartościami. Wartości zaokrąglone do `int`.

### Refresh

`refresh()` przelicza `ValuePolygon.polygon` i `ValueOutline.points` z aktualnych wartości `state.get_player_religion().axes`, plus aktualizuje 4 etykiety wartości. Outline i fill colors są ustawiane raz po `bind_state` (zmieniają się tylko gdy zmienia się religia gracza — co w MVP nie zachodzi).

---

## Sekcja 2: TraitCard

Karta z dwoma `Label`-ami: nazwa traitu (bold, 16 px) i opis (regular, 12 px, word wrap). Stylizowana jako `PanelContainer` z subtelnym tłem (kolor `Color(0.1, 0.1, 0.1)`).

**Źródło danych:** `UIConstants.TRAIT_INFO[religion.trait_id]` → `{name: String, description: String}`.

**12 wpisów** (skrócone wiernie z `05-religion-profiles-design.md` — opisy odpowiadają mechanikom z odpowiednich sekcji "Trait: X"):

| trait_id | name | description (1–2 zdania, faithful do spec 05) |
|---|---|---|
| `umma` | Umma | Próg CB Dżihadu obniżony o dodatkowe −5 (łącznie −15). Kontrola Mekki: każda prowincja Islamu globalnie +1 prestiż/turę. |
| `cezaropapizm` | Cezaropapizm | Cesarz może zwołać Sobór raz na epokę za darmo. Napięcie przegranej frakcji ×2. |
| `sukcesja_apostolska` | Sukcesja Apostolska | Klienci uznający Rzym jako patrona: −10% odporności na Synkretyzm. Rzym zyskuje +5 prestiżu za każde nowe Uznanie. |
| `diaspora` | Diaspora | Prowincje utracone nadal generują +1 prestiż/turę. Synagogi w obcych prowincjach (10 złota): +0.5 presji/turę w tej prowincji. |
| `zmartwychwstanie_saszanskie` | Zmartwychwstanie Saszańskie | Przy <5 prowincjach: pasywna presja sąsiedzka ×2. Kontrola `persepolis`: +10% Modyfikator CB we wszystkich kampaniach. |
| `pamiec_pustynna` | Pamięć Pustynna | Akcja `[Ojciec Pustyni]` (15 prestiżu): mnich do prowincji w odległości do 3 kroków grafu. Po 5 turach +20 presji jednorazowo. |
| `synkretyzm_radykalny` | Synkretyzm Radykalny | Akcja `[Zaakceptuj Ideę]` bez kosztu prestiżu. Może absorbować doktryny od 2 religii naraz (standard: 1). +5 napięcia Wybranych. |
| `pluralizm_plemienny` | Pluralizm Plemienny | Misjonarze bez limitu liczby (standard: max 3). 40% szansy "schizmy plemiennej" przy każdym zdobyciu nowej prowincji. |
| `dharma_i_varna` | Dharma i Varna | Immunizacja na obowiązkowe CB doktrynalne. Prowincja kontrolowana 10+ tur: +2 żywność. Konwersja przez najeźdźcę: +20% kosztu presji. |
| `srodkowa_droga` | Środkowa Droga | Immunizacja na obowiązkowe CB doktrynalne. Akcja `[Dharma-Yatra]` (25 prestiżu): pielgrzymi przez do 5 kroków grafu, presja na każdej prowincji trasy. |
| `ragnarok` | Ragnarök | Po utracie >50% prowincji startowych: tryb `[Zmierzch Bogów]` — Modyfikator CB +20%, zmęczenie wojenne narasta 50% wolniej. |
| `ziemia_i_krew` | Ziemia i Krew | Prowincje góry/pustynia/żyzne: +1 żywność extra. Atak na słowiańską prowincję: dodatkowe −10% siły najeźdźcy. |

Opisy w `UIConstants.TRAIT_INFO` to **literalne** wartości (Polish-only MVP, lokalizacja future).

---

## Sekcja 3: DoctrineList + DoctrineRow

### Lista doktryn

`DoctrineList` to `VBoxContainer` z jednym `DoctrineRow` per wpis w `UIConstants.DOCTRINE_INFO`. Lista posortowana wg osi (A → B → C; oś D nie ma akcji progowych w `AXIS_THRESHOLDS` — patrz komentarz `DoctrineManager.gd:28`), w obrębie osi wg progu (`min` na początku, `max` na końcu), przy równym progu — alfabetycznie po `action_id` (deterministyczna kolejność dla testów).

**Wpisy `DOCTRINE_INFO`** (8 doktryn dokładnie odpowiadających `DoctrineManager.AXIS_THRESHOLDS`):

| action_id | name | axis | op | threshold | description (efekt) |
|---|---|---|---|---|---|
| `kanon_doktryny` | Kanon Doktrynalny | A | min | 75 | Ortodoksja chroni przed obcymi ideami. |
| `objawienie` | Objawienie Mistyczne | A | max | 25 | Mistyczna interpretacja otwiera nowe doktryny. |
| `papieskie_interdykty` | Papieskie Interdykty | B | min | 75 | Hierarchia może rzucać Interdykt. |
| `sobor_ludowy` | Sobór Ludowy | B | max | 25 | Egalitarne sobory tańsze o połowę. |
| `ekumenizm` | Ekumenizm | C | min | 75 | Łatwiejsza absorpcja doktryn obcych religii. |
| `obrzad_fuzji` | Obrzęd Fuzji | C | min | 75 | Możliwa fuzja z religią synkretyczną. |
| `inkwizycja` | Inkwizycja | C | max | 25 | Schizmy odpierane brutalnie. |
| `klatwa` | Klątwa | C | max | 25 | Można rzucić klątwę na heretyka. |

`description` to 1-zdaniowy efekt mechaniczny (skrót orientacyjny — pełne efekty doprecyzują się w future plan aktywacji).

### DoctrineRow

`HBoxContainer` z 3 elementami:
1. **Ikona stanu** (`Label`) — `◐` (żółty `Color("dda820")`) gdy dostępna, `○` (szary `Color(0.4, 0.4, 0.4)`) gdy zablokowana.
2. **Nazwa doktryny** (`Label`) — `DOCTRINE_INFO[id].name`.
3. **Warunek osi** (`Label` mały, 10 px, szary) — np. `"wymaga A ≥ 75"` (dla `op=min`) / `"wymaga C ≤ 25"` (dla `op=max`).

Pełny opis (`description`) wyświetlany jako tooltip po hover — ustawiany w `tooltip_text` na wierszu (Godot natywny mechanizm; mobile-touch deferred — read-only widok nie blokuje na braku tooltipa).

**Stan obliczany w `refresh()`:**
- pobierz `religion = state.get_player_religion()`
- dla każdego wpisu `DOCTRINE_INFO[id]`:
  - `value = religion.get_axis(info.axis)`
  - `available = (info.op == "min" and value >= info.threshold) or (info.op == "max" and value <= info.threshold)`
  - ustaw ikonę i kolor odpowiednio

---

## Sekcja 4: WiaraTab (kompozycja)

```
WiaraTab (Control, anchors fullscreen)
└── VBoxContainer (margin 20 px wokół)
    ├── AxisRadar (size_flags expand)
    ├── TraitCard (size_flags fill_horizontal, fixed height ~80 px)
    └── DoctrineList (size_flags fill_horizontal)
```

Brak HBoxa lewo/prawo — wszystko ułożone wertykalnie, pełna szerokość. Diament wycentrowany w swoim slotie.

**Refresh:** `WiaraTab.refresh()` → `_axis_radar.refresh()`, `_trait_card.refresh()`, `_doctrine_list.refresh()`. Wywoływane z `MainShell.refresh()`.

---

## Sekcja 5: Konwencje i wzorce

Wszystkie konwencje z `CLAUDE.md` mają zastosowanie:
- **Tab indent** dla wszystkich `.gd`.
- **`class_name`** na każdym skrypcie UI.
- **`unique_name_in_owner = true` + `%Name`** dla wszystkich nazwanych dzieci.
- **`is_inside_tree()` guard** w setterach przed dostępem do `@onready` (precedens: `RelationListItem`, `PressureRow`).
- **`emit_signal("name", args)`** w razie potrzeby (tu prawie nieużywane, bo zakładka read-only).
- **Stałe progowe z managerów** — kod UI referuje `DoctrineManager.AXIS_THRESHOLDS` jako prawdę o tym, które doktryny istnieją; `UIConstants.DOCTRINE_INFO` musi mieć wpisy dla wszystkich 8 action_id z `AXIS_THRESHOLDS`. Test parytetu wymagany (Sekcja 6).

**Pliki do utworzenia:**

```
scripts/ui/wiara/
├── AxisRadar.gd
├── TraitCard.gd
├── DoctrineList.gd
├── DoctrineRow.gd
└── WiaraTab.gd

scenes/ui/wiara/
├── AxisRadar.tscn
├── TraitCard.tscn
├── DoctrineList.tscn
├── DoctrineRow.tscn
└── WiaraTab.tscn

tests/ui/
├── test_axis_radar.gd
├── test_trait_card.gd
├── test_doctrine_list.gd
├── test_doctrine_row.gd
├── test_doctrine_info_parity.gd     # parytet DOCTRINE_INFO ↔ AXIS_THRESHOLDS
└── test_wiara_tab.gd
```

**Pliki do zmiany:**
- `scripts/ui/UIConstants.gd` — dodać:
  - `TRAIT_INFO: Dictionary` (12 wpisów z Sekcji 2).
  - `DOCTRINE_INFO: Dictionary` (8 wpisów z Sekcji 3).
  - `RELIGION_ACCENT_COLORS: Dictionary` (12 wpisów `religion_id` → `Color` z palety `06-ui-design.md` Sekcja 3; jeśli `data/religions_historical.json` ma pole `accent_color`, wartości tam i tu powinny się zgadzać).
  - `static func religion_accent_color(religion_id: String) -> Color` (parallel do istniejącego `religion_color`).
  - `RELIGION_ACCENT_COLOR_DEFAULT: Color = Color(0.7, 0.7, 0.7)`.
- `scripts/ui/MainShell.gd` — patrz "Integracja MainShell" w Architekturze (wszystkie 4 zmiany w jednym commit).
- `scenes/ui/MainShell.tscn` — `ExtResource` dla `WiaraTab.tscn` zamiast użycia `PlaceholderTab` dla węzła `WiaraTab`.

---

## Sekcja 6: Testy

**Kryteria pokrycia** (każdy komponent przynajmniej):
- Renderuje się bez stanu (brak crasha gdy `bind_state` nie został jeszcze wywołany).
- Po `bind_state(state)` pokazuje dane religii gracza.
- `refresh()` aktualizuje widok po mutacji `religion.axes` / `religion.trait_id`.

**Szczególne przypadki:**
- `AxisRadar`: oś o wartości 0 (radius=0) — wierzchołek w centrum, polygon nie crashuje.
- `AxisRadar`: oś o wartości 100 — wierzchołek na pełnym promieniu 160 px od centrum.
- `TraitCard`: nieznany `trait_id` → puste pola lub fallback "(nieznany trait)", brak crasha.
- `DoctrineRow`: doktryna z `op="max"` przy `value=threshold` (np. A=25, próg max 25) — **dostępna** (operator `<=`).
- `DoctrineRow`: doktryna z `op="min"` przy `value=threshold` (np. A=75, próg min 75) — **dostępna** (operator `>=`).
- `WiaraTab`: integracja po zmianie osi → DoctrineRow przechodzi z `zablokowana` → `dostępna`.

**Test parytetu `DOCTRINE_INFO` ↔ `AXIS_THRESHOLDS`** (`test_doctrine_info_parity.gd`):
- Dla każdej osi w `DoctrineManager.AXIS_THRESHOLDS`, każda akcja z każdej reguły musi mieć wpis w `UIConstants.DOCTRINE_INFO`.
- Każdy wpis `DOCTRINE_INFO[id]` musi mieć odpowiadającą regułę w `AXIS_THRESHOLDS` z dokładnie tym samym `axis`, `op`, `threshold`.
- Cel: jeśli ktoś doda doktrynę do engine lub UI bez aktualizacji drugiej strony, test pada od razu.

---

## Pytania otwarte

Brak — wszystkie decyzje projektowe rozstrzygnięte.

---

*Spec zatwierdzona — gotowa do planowania implementacji.*
