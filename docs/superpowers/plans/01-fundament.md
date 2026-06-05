# Fundament — Model Danych i Pętla Tury

> **For Claude:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Zbudować core data model gry w Godot 4 — prowincje, religie, frakcje, stan gry i podstawową pętlę tury (pasywna presja, zasoby, frakcje).

**Architecture:** Czysta warstwa silnika (`scripts/engine/`) bez UI, testowana przez GUT. Dane startowe w JSON (`data/`). Autoload `GameState` jako singleton trzymający aktualny stan partii. `TurnManager` przetwarza jedną turę: zbiera zasoby, aplikuje presję, aktualizuje napięcia frakcji.

**Tech Stack:** Godot 4.x, GDScript 2.0, GUT (Godot Unit Testing framework)

---

## Struktura plików

```
project.godot
addons/
  gut/                          ← GUT plugin (zainstalowany w kroku 1)
data/
  religions_historical.json     ← startowe profile 12 religii
  provinces_historical.json     ← mapa historyczna ~20 prowincji
scripts/
  engine/
    Province.gd                 ← klasa danych prowincji (Resource)
    ProvinceGraph.gd            ← graf sąsiedztwa + zapytania
    Faction.gd                  ← klasa danych frakcji (Resource)
    Religion.gd                 ← klasa danych religii (Resource)
    ReligionLoader.gd           ← ładuje religions_historical.json → Religion[]
    ProvinceLoader.gd           ← ładuje provinces_historical.json → Province[]
    GameState.gd                ← Autoload: aktualny stan partii
    TurnManager.gd              ← przetwarza jedną turę
tests/
  engine/
    test_province.gd
    test_province_graph.gd
    test_religion.gd
    test_religion_loader.gd
    test_province_loader.gd
    test_game_state.gd
    test_turn_manager.gd
scenes/
  Main.tscn                     ← minimalna scena startowa (tylko uruchamia GameState)
```

**Odpowiedzialności:**
- `Province.gd` — dane jednej prowincji, logika presji per-prowincja
- `ProvinceGraph.gd` — cały graf: dodawanie prowincji, zapytania o sąsiadów, ścieżki
- `Faction.gd` — dane frakcji: wpływ, napięcie, preferencje osi
- `Religion.gd` — dane religii: osie A/B/C/D, frakcje, prestiż, święte miasta
- `ReligionLoader.gd` — parsuje JSON → tablicę `Religion`
- `ProvinceLoader.gd` — parsuje JSON → tablicę `Province`
- `GameState.gd` — singleton: aktualna religia gracza, wszystkie prowincje, tura
- `TurnManager.gd` — logika jednej tury: presja, zasoby, aktualizacja frakcji

---

## Chunk 1: Godot Setup + Province

### Zadanie 1: Setup projektu Godot + GUT

**Pliki:**
- Utwórz: `project.godot`
- Utwórz: `addons/gut/` (plugin)
- Utwórz: `.gitignore` (rozszerz istniejący)

- [ ] **Krok 1: Utwórz projekt Godot 4**

  Otwórz Godot 4 (min. 4.2). Kliknij "New Project":
  - Project Name: `church-manager`
  - Project Path: `/Users/tomaszrup/Projects/github.com/tomi77/church-manager`
  - Renderer: Forward+
  - Kliknij "Create & Edit"

  Godot tworzy `project.godot` i `icon.svg` w katalogu.

- [ ] **Krok 2: Zainstaluj GUT przez AssetLib**

  W edytorze Godot: AssetLib (górny pasek) → szukaj "GUT" → wybierz "Gut - Godot Unit Testing" → Download → Install.

  Alternatywnie przez terminal:
  ```bash
  cd /Users/tomaszrup/Projects/github.com/tomi77/church-manager
  mkdir -p addons
  git submodule add https://github.com/bitwes/Gut.git addons/gut
  ```

  Następnie w Godot: Project → Project Settings → Plugins → GUT → Enable.

- [ ] **Krok 3: Utwórz strukturę katalogów**

  W terminalu (lub w edytorze Godot przez FileSystem):
  ```bash
  mkdir -p scripts/engine scripts/ui data tests/engine scenes
  ```

- [ ] **Krok 4: Rozszerz .gitignore**

  Dodaj do istniejącego `.gitignore`:
  ```
  # Godot
  .godot/
  *.import
  export_credentials.cfg
  ```

- [ ] **Krok 5: Utwórz pustą scenę Main**

  W Godot: Scene → New Scene → Node2D jako root → zmień nazwę na "Main" → Ctrl+S → zapisz jako `scenes/Main.tscn`.

- [ ] **Krok 6: Commit setup**

  ```bash
  git add project.godot scenes/ scripts/ data/ tests/ addons/ .gitignore
  git commit -m "chore: inicjalizuj projekt Godot 4 z GUT"
  ```

---

### Zadanie 2: Province — model danych

**Pliki:**
- Utwórz: `scripts/engine/Province.gd`
- Utwórz: `tests/engine/test_province.gd`

- [ ] **Krok 1: Napisz test prowincji**

  Utwórz `tests/engine/test_province.gd`:
  ```gdscript
  extends GutTest

  func test_province_initial_pressure_is_zero_for_unknown_religion() -> void:
      var p := Province.new()
      p.id = "anatolia"
      p.pressure = {}
      assert_eq(p.get_pressure("islam"), 0.0)

  func test_province_get_pressure_returns_stored_value() -> void:
      var p := Province.new()
      p.pressure = {"islam": 45.0, "chr_zachodnie": 20.0}
      assert_eq(p.get_pressure("islam"), 45.0)
      assert_eq(p.get_pressure("chr_zachodnie"), 20.0)

  func test_province_add_pressure_clamps_to_100() -> void:
      var p := Province.new()
      p.pressure = {"islam": 90.0}
      p.add_pressure("islam", 20.0)
      assert_eq(p.get_pressure("islam"), 100.0)

  func test_province_add_pressure_cannot_go_below_zero() -> void:
      var p := Province.new()
      p.pressure = {"islam": 5.0}
      p.add_pressure("islam", -10.0)
      assert_eq(p.get_pressure("islam"), 0.0)

  func test_province_dominant_pressure_returns_religion_with_highest_pressure() -> void:
      var p := Province.new()
      p.owner = "chr_zachodnie"
      p.pressure = {"islam": 72.0, "chr_zachodnie": 80.0, "judaizm": 10.0}
      assert_eq(p.dominant_pressure_religion(), "chr_zachodnie")

  func test_province_holy_site_flag() -> void:
      var p := Province.new()
      p.is_holy_site = true
      assert_true(p.is_holy_site)

  func test_province_resources_food_and_gold() -> void:
      var p := Province.new()
      p.resources = {"food": 2, "gold": 1}
      assert_eq(p.resources["food"], 2)
      assert_eq(p.resources["gold"], 1)
  ```

- [ ] **Krok 2: Uruchom test — oczekuj FAIL**

  W Godot Editor: otwórz panel GUT (dolna zakładka) → kliknij Run All → oczekuj błąd `Class "Province" not found`.

  Lub z terminalu (headless):
  ```bash
  godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
    -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20
  ```
  Oczekiwany wynik: `Class "Province" not found`.

- [ ] **Krok 3: Zaimplementuj Province**

  Utwórz `scripts/engine/Province.gd`:
  ```gdscript
  class_name Province
  extends Resource

  @export var id: String = ""
  @export var owner: String = ""
  @export var pressure: Dictionary = {}
  @export var population: int = 0
  @export var resources: Dictionary = {"food": 0, "gold": 0}
  @export var terrain: String = "plains"
  @export var neighbors: Array[String] = []
  @export var is_holy_site: bool = false

  func get_pressure(religion_id: String) -> float:
      return pressure.get(religion_id, 0.0)

  func add_pressure(religion_id: String, delta: float) -> void:
      var current := get_pressure(religion_id)
      pressure[religion_id] = clampf(current + delta, 0.0, 100.0)

  func dominant_pressure_religion() -> String:
      var best_id := owner
      var best_val := get_pressure(owner)
      for rid: String in pressure:
          if pressure[rid] > best_val:
              best_val = pressure[rid]
              best_id = rid
      return best_id
  ```

- [ ] **Krok 4: Uruchom test — oczekuj PASS**

  ```bash
  godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
    -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20
  ```
  Oczekiwany wynik: `7 passed, 0 failed`.

- [ ] **Krok 5: Commit**

  ```bash
  git add scripts/engine/Province.gd tests/engine/test_province.gd
  git commit -m "feat: dodaj model danych Province z presją i zasobami"
  ```

---

### Zadanie 3: Faction — model danych

**Pliki:**
- Utwórz: `scripts/engine/Faction.gd`
- Utwórz: `tests/engine/test_faction.gd`

- [ ] **Krok 1: Napisz test frakcji**

  Utwórz `tests/engine/test_faction.gd`:
  ```gdscript
  extends GutTest

  func test_faction_influence_starts_in_range() -> void:
      var f := Faction.new()
      f.influence = 0.40
      assert_true(f.influence >= 0.0 and f.influence <= 1.0)

  func test_faction_tension_clamps_to_100() -> void:
      var f := Faction.new()
      f.tension = 50.0
      f.add_tension(60.0)
      assert_eq(f.tension, 100.0)

  func test_faction_tension_cannot_go_below_zero() -> void:
      var f := Faction.new()
      f.tension = 10.0
      f.add_tension(-30.0)
      assert_eq(f.tension, 0.0)

  func test_faction_prefers_axis_direction() -> void:
      var f := Faction.new()
      f.axis_preferences = [{"axis": "A", "direction": 1}, {"axis": "B", "direction": 1}]
      assert_eq(f.get_preference_for_axis("A"), 1)
      assert_eq(f.get_preference_for_axis("C"), 0)
  ```

- [ ] **Krok 2: Uruchom test — oczekuj FAIL**

  ```bash
  godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
    -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20
  ```
  Oczekiwany wynik: `Class "Faction" not found`.

- [ ] **Krok 3: Zaimplementuj Faction**

  Utwórz `scripts/engine/Faction.gd`:
  ```gdscript
  class_name Faction
  extends Resource

  @export var id: String = ""
  @export var display_name: String = ""
  @export var axis_preferences: Array = []
  @export var influence: float = 0.0
  @export var tension: float = 0.0

  func add_tension(delta: float) -> void:
      tension = clampf(tension + delta, 0.0, 100.0)

  func get_preference_for_axis(axis: String) -> int:
      for pref: Dictionary in axis_preferences:
          if pref.get("axis", "") == axis:
              return pref.get("direction", 0)
      return 0
  ```

- [ ] **Krok 4: Uruchom test — oczekuj PASS**

  Oczekiwany wynik: `4 passed, 0 failed`.

- [ ] **Krok 5: Commit**

  ```bash
  git add scripts/engine/Faction.gd tests/engine/test_faction.gd
  git commit -m "feat: dodaj model danych Faction z napięciem i preferencjami osi"
  ```

---

## Chunk 2: ProvinceGraph + Religion

### Zadanie 4: ProvinceGraph

**Pliki:**
- Utwórz: `scripts/engine/ProvinceGraph.gd`
- Utwórz: `tests/engine/test_province_graph.gd`

- [ ] **Krok 1: Napisz test grafu**

  Utwórz `tests/engine/test_province_graph.gd`:
  ```gdscript
  extends GutTest

  var graph: ProvinceGraph

  func before_each() -> void:
      graph = ProvinceGraph.new()
      var anatolia := Province.new()
      anatolia.id = "anatolia"
      anatolia.owner = "chr_wschodnie"
      anatolia.pressure = {"chr_wschodnie": 80.0, "islam": 30.0}
      var lewant := Province.new()
      lewant.id = "lewant"
      lewant.owner = "islam"
      lewant.pressure = {"islam": 72.0}
      var egipt := Province.new()
      egipt.id = "egipt"
      egipt.owner = "islam"
      graph.add_province(anatolia)
      graph.add_province(lewant)
      graph.add_province(egipt)
      graph.add_edge("anatolia", "lewant")
      graph.add_edge("lewant", "egipt")

  func test_graph_has_correct_province_count() -> void:
      assert_eq(graph.province_count(), 3)

  func test_graph_get_province_by_id() -> void:
      var p := graph.get_province("anatolia")
      assert_not_null(p)
      assert_eq(p.id, "anatolia")

  func test_graph_get_missing_province_returns_null() -> void:
      assert_null(graph.get_province("rzym"))

  func test_graph_neighbors_are_bidirectional() -> void:
      var neighbors := graph.get_neighbors("anatolia")
      assert_true(neighbors.has("lewant"))
      var neighbors2 := graph.get_neighbors("lewant")
      assert_true(neighbors2.has("anatolia"))

  func test_graph_are_neighbors_true() -> void:
      assert_true(graph.are_neighbors("anatolia", "lewant"))

  func test_graph_are_neighbors_false_for_nonadjacent() -> void:
      assert_false(graph.are_neighbors("anatolia", "egipt"))

  func test_graph_provinces_with_owner() -> void:
      var islam_provinces := graph.provinces_with_owner("islam")
      assert_eq(islam_provinces.size(), 2)

  func test_graph_border_provinces_returns_own_provinces_adjacent_to_foreign() -> void:
      var borders := graph.border_provinces("chr_wschodnie")
      assert_true(borders.has("anatolia"))
  ```

- [ ] **Krok 2: Uruchom test — oczekuj FAIL**

  Oczekiwany wynik: `Class "ProvinceGraph" not found`.

- [ ] **Krok 3: Zaimplementuj ProvinceGraph**

  Utwórz `scripts/engine/ProvinceGraph.gd`:
  ```gdscript
  class_name ProvinceGraph
  extends RefCounted

  var _provinces: Dictionary = {}
  var _edges: Dictionary = {}

  func add_province(province: Province) -> void:
      _provinces[province.id] = province
      if not _edges.has(province.id):
          _edges[province.id] = []

  func add_edge(id_a: String, id_b: String) -> void:
      if not _edges.has(id_a):
          _edges[id_a] = []
      if not _edges.has(id_b):
          _edges[id_b] = []
      if not _edges[id_a].has(id_b):
          _edges[id_a].append(id_b)
      if not _edges[id_b].has(id_a):
          _edges[id_b].append(id_a)

  func get_province(id: String) -> Province:
      return _provinces.get(id, null)

  func province_count() -> int:
      return _provinces.size()

  func get_neighbors(id: String) -> Array[String]:
      var result: Array[String] = []
      for n: String in _edges.get(id, []):
          result.append(n)
      return result

  func are_neighbors(id_a: String, id_b: String) -> bool:
      return _edges.get(id_a, []).has(id_b)

  func provinces_with_owner(owner_id: String) -> Array[Province]:
      var result: Array[Province] = []
      for p: Province in _provinces.values():
          if p.owner == owner_id:
              result.append(p)
      return result

  func border_provinces(owner_id: String) -> Array[String]:
      var result: Array[String] = []
      for p: Province in provinces_with_owner(owner_id):
          for neighbor_id: String in get_neighbors(p.id):
              var neighbor := get_province(neighbor_id)
              if neighbor != null and neighbor.owner != owner_id:
                  if not result.has(p.id):
                      result.append(p.id)
                  break
      return result

  func all_provinces() -> Array[Province]:
      var result: Array[Province] = []
      for p: Province in _provinces.values():
          result.append(p)
      return result
  ```

- [ ] **Krok 4: Uruchom test — oczekuj PASS**

  Oczekiwany wynik: `8 passed, 0 failed`.

- [ ] **Krok 5: Commit**

  ```bash
  git add scripts/engine/ProvinceGraph.gd tests/engine/test_province_graph.gd
  git commit -m "feat: dodaj ProvinceGraph z sąsiedztwem i zapytaniami"
  ```

---

### Zadanie 5: Religion — model danych

**Pliki:**
- Utwórz: `scripts/engine/Religion.gd`
- Utwórz: `tests/engine/test_religion.gd`

- [ ] **Krok 1: Napisz test religii**

  Utwórz `tests/engine/test_religion.gd`:
  ```gdscript
  extends GutTest

  func _make_test_religion() -> Religion:
      var r := Religion.new()
      r.id = "islam"
      r.display_name = "Islam"
      r.axes = {"A": 70.0, "B": 65.0, "C": 30.0, "D": 75.0}
      r.prestige = 300
      r.holy_sites = ["mekka", "jerozolima"]
      var ulema := Faction.new()
      ulema.id = "ulema"
      ulema.influence = 0.40
      ulema.tension = 20.0
      ulema.axis_preferences = [{"axis": "A", "direction": 1}, {"axis": "B", "direction": 1}]
      var sufici := Faction.new()
      sufici.id = "sufici"
      sufici.influence = 0.30
      sufici.tension = 20.0
      r.factions = [ulema, sufici]
      return r

  func test_religion_has_four_axes() -> void:
      var r := _make_test_religion()
      assert_true(r.axes.has("A"))
      assert_true(r.axes.has("B"))
      assert_true(r.axes.has("C"))
      assert_true(r.axes.has("D"))

  func test_religion_axis_value_returns_correct() -> void:
      var r := _make_test_religion()
      assert_eq(r.get_axis("A"), 70.0)
      assert_eq(r.get_axis("C"), 30.0)

  func test_religion_axis_shift_clamps_to_range() -> void:
      var r := _make_test_religion()
      r.shift_axis("A", 40.0)
      assert_eq(r.get_axis("A"), 100.0)
      r.shift_axis("A", -200.0)
      assert_eq(r.get_axis("A"), 0.0)

  func test_religion_get_faction_by_id() -> void:
      var r := _make_test_religion()
      var f := r.get_faction("ulema")
      assert_not_null(f)
      assert_eq(f.id, "ulema")

  func test_religion_get_faction_missing_returns_null() -> void:
      var r := _make_test_religion()
      assert_null(r.get_faction("wojownicy"))

  func test_religion_dominant_faction_is_highest_influence() -> void:
      var r := _make_test_religion()
      assert_eq(r.dominant_faction().id, "ulema")

  func test_religion_prestige_cannot_go_below_zero() -> void:
      var r := _make_test_religion()
      r.add_prestige(-9999)
      assert_eq(r.prestige, 0)
  ```

- [ ] **Krok 2: Uruchom test — oczekuj FAIL**

  Oczekiwany wynik: `Class "Religion" not found`.

- [ ] **Krok 3: Zaimplementuj Religion**

  Utwórz `scripts/engine/Religion.gd`:
  ```gdscript
  class_name Religion
  extends Resource

  @export var id: String = ""
  @export var display_name: String = ""
  @export var icon: String = ""
  @export var axes: Dictionary = {"A": 50.0, "B": 50.0, "C": 50.0, "D": 50.0}
  @export var prestige: int = 0
  @export var holy_sites: Array[String] = []
  @export var factions: Array[Faction] = []
  @export var trait_id: String = ""
  @export var color: String = "#ffffff"
  @export var accent_color: String = "#ffffff"

  func get_axis(axis: String) -> float:
      return axes.get(axis, 50.0)

  func shift_axis(axis: String, delta: float) -> void:
      if not axes.has(axis):
          return
      axes[axis] = clampf(get_axis(axis) + delta, 0.0, 100.0)

  func get_faction(faction_id: String) -> Faction:
      for f: Faction in factions:
          if f.id == faction_id:
              return f
      return null

  func dominant_faction() -> Faction:
      var best: Faction = null
      for f: Faction in factions:
          if best == null or f.influence > best.influence:
              best = f
      return best

  func add_prestige(delta: int) -> void:
      prestige = maxi(0, prestige + delta)
  ```

- [ ] **Krok 4: Uruchom test — oczekuj PASS**

  ```bash
  godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
    -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -20
  ```
  Oczekiwany wynik: `7 passed, 0 failed`.

- [ ] **Krok 5: Commit**

  ```bash
  git add scripts/engine/Religion.gd tests/engine/test_religion.gd
  git commit -m "feat: dodaj model danych Religion z osiami i frakcjami"
  ```

---

## Chunk 3: Ładowanie danych + GameState + TurnManager

### Zadanie 6: Dane JSON — religie historyczne

**Pliki:**
- Utwórz: `data/religions_historical.json`
- Utwórz: `scripts/engine/ReligionLoader.gd`
- Utwórz: `tests/engine/test_religion_loader.gd`

- [ ] **Krok 1: Utwórz plik JSON religii**

  Utwórz `data/religions_historical.json` (fragment — Bliski Wschód):
  ```json
  {
    "religions": [
      {
        "id": "islam",
        "display_name": "Islam",
        "icon": "☪",
        "axes": {"A": 70.0, "B": 65.0, "C": 30.0, "D": 75.0},
        "prestige_start": 300,
        "holy_sites": ["mekka", "jerozolima"],
        "color": "#0d3a1a",
        "accent_color": "#5aaa5a",
        "trait_id": "umma",
        "factions": [
          {"id": "ulema", "display_name": "Ulema", "influence_start": 0.40, "tension_start": 20.0,
           "axis_preferences": [{"axis": "A", "direction": 1}, {"axis": "B", "direction": 1}]},
          {"id": "sufici", "display_name": "Sufici", "influence_start": 0.30, "tension_start": 20.0,
           "axis_preferences": [{"axis": "A", "direction": -1}, {"axis": "D", "direction": 1}]},
          {"id": "wojownicy_wiary", "display_name": "Wojownicy Wiary", "influence_start": 0.30, "tension_start": 20.0,
           "axis_preferences": [{"axis": "C", "direction": -1}, {"axis": "D", "direction": -1}]}
        ]
      },
      {
        "id": "chr_zachodnie",
        "display_name": "Chrześcijaństwo Zachodnie",
        "icon": "✝",
        "axes": {"A": 65.0, "B": 80.0, "C": 35.0, "D": 55.0},
        "prestige_start": 500,
        "holy_sites": ["rzym", "jerozolima"],
        "color": "#0a0a2a",
        "accent_color": "#7a7aff",
        "trait_id": "sukcesja_apostolska",
        "factions": [
          {"id": "papiestwo", "display_name": "Papiestwo", "influence_start": 0.40, "tension_start": 20.0,
           "axis_preferences": [{"axis": "B", "direction": 1}, {"axis": "A", "direction": 1}]},
          {"id": "zakonnicy", "display_name": "Zakonnicy", "influence_start": 0.35, "tension_start": 20.0,
           "axis_preferences": [{"axis": "D", "direction": 1}, {"axis": "A", "direction": -1}]},
          {"id": "reformatorzy", "display_name": "Reformatorzy", "influence_start": 0.25, "tension_start": 20.0,
           "axis_preferences": [{"axis": "B", "direction": -1}]}
        ]
      },
      {
        "id": "chr_wschodnie",
        "display_name": "Chrześcijaństwo Wschodnie",
        "icon": "✝",
        "axes": {"A": 60.0, "B": 75.0, "C": 40.0, "D": 60.0},
        "prestige_start": 450,
        "holy_sites": ["konstantynopol", "jerozolima"],
        "color": "#0a0a22",
        "accent_color": "#6a6aee",
        "trait_id": "cezaropapizm",
        "factions": [
          {"id": "patriarchowie", "display_name": "Patriarchowie", "influence_start": 0.45, "tension_start": 20.0,
           "axis_preferences": [{"axis": "B", "direction": 1}, {"axis": "A", "direction": 1}]},
          {"id": "hezychazm", "display_name": "Hezychazm", "influence_start": 0.30, "tension_start": 20.0,
           "axis_preferences": [{"axis": "A", "direction": -1}, {"axis": "D", "direction": 1}]},
          {"id": "cesarze_teologowie", "display_name": "Cesarze-Teologowie", "influence_start": 0.25, "tension_start": 20.0,
           "axis_preferences": [{"axis": "B", "direction": 1}, {"axis": "D", "direction": -1}]}
        ]
      },
      {
        "id": "judaizm",
        "display_name": "Judaizm",
        "icon": "✡",
        "axes": {"A": 75.0, "B": 45.0, "C": 20.0, "D": 65.0},
        "prestige_start": 250,
        "holy_sites": ["jerozolima"],
        "color": "#1a1600",
        "accent_color": "#bbaa00",
        "trait_id": "diaspora",
        "factions": [
          {"id": "rabini", "display_name": "Rabini", "influence_start": 0.50, "tension_start": 20.0,
           "axis_preferences": [{"axis": "A", "direction": 1}]},
          {"id": "ortodoksi", "display_name": "Ortodoksi", "influence_start": 0.30, "tension_start": 20.0,
           "axis_preferences": [{"axis": "A", "direction": 1}, {"axis": "C", "direction": -1}]},
          {"id": "zeloci", "display_name": "Zeloci", "influence_start": 0.20, "tension_start": 20.0,
           "axis_preferences": [{"axis": "D", "direction": -1}]}
        ]
      },
      {
        "id": "zoroastryzm",
        "display_name": "Zoroastryzm",
        "icon": "🔥",
        "axes": {"A": 60.0, "B": 70.0, "C": 30.0, "D": 70.0},
        "prestige_start": 350,
        "holy_sites": ["persepolis"],
        "color": "#1a0d00",
        "accent_color": "#cc7a1a",
        "trait_id": "zmartwychwstanie_saszanskie",
        "factions": [
          {"id": "magi_wielcy", "display_name": "Magi Wielcy", "influence_start": 0.45, "tension_start": 20.0,
           "axis_preferences": [{"axis": "B", "direction": 1}, {"axis": "A", "direction": 1}]},
          {"id": "kaplani_ognia", "display_name": "Kapłani Ognia", "influence_start": 0.35, "tension_start": 20.0,
           "axis_preferences": [{"axis": "D", "direction": 1}, {"axis": "A", "direction": 1}]},
          {"id": "zurwanizm", "display_name": "Zurwanizm", "influence_start": 0.20, "tension_start": 20.0,
           "axis_preferences": [{"axis": "A", "direction": -1}, {"axis": "C", "direction": 1}]}
        ]
      },
      {
        "id": "koptyjski",
        "display_name": "Koptyjski Kościół",
        "icon": "☥",
        "axes": {"A": 55.0, "B": 50.0, "C": 35.0, "D": 70.0},
        "prestige_start": 200,
        "holy_sites": ["aleksandria"],
        "color": "#0d1a10",
        "accent_color": "#4aaa6a",
        "trait_id": "pamiec_pustynna",
        "factions": [
          {"id": "papież_aleksandryjski", "display_name": "Papież Aleksandryjski", "influence_start": 0.40, "tension_start": 20.0,
           "axis_preferences": [{"axis": "B", "direction": 1}, {"axis": "A", "direction": 1}]},
          {"id": "ojcowie_pustyni", "display_name": "Ojcowie Pustyni", "influence_start": 0.40, "tension_start": 20.0,
           "axis_preferences": [{"axis": "D", "direction": 1}, {"axis": "A", "direction": -1}]},
          {"id": "wierni_egipscy", "display_name": "Wierni Egipscy", "influence_start": 0.20, "tension_start": 20.0,
           "axis_preferences": [{"axis": "B", "direction": -1}]}
        ]
      },
      {
        "id": "manicheizm",
        "display_name": "Manicheizm",
        "icon": "☯",
        "axes": {"A": 40.0, "B": 35.0, "C": 85.0, "D": 80.0},
        "prestige_start": 100,
        "holy_sites": [],
        "color": "#180818",
        "accent_color": "#cc55cc",
        "trait_id": "synkretyzm_radykalny",
        "factions": [
          {"id": "wybrani", "display_name": "Wybrani", "influence_start": 0.45, "tension_start": 20.0,
           "axis_preferences": [{"axis": "D", "direction": 1}, {"axis": "C", "direction": 1}]},
          {"id": "sluchacze", "display_name": "Słuchacze", "influence_start": 0.40, "tension_start": 20.0,
           "axis_preferences": [{"axis": "C", "direction": 1}]},
          {"id": "teolodzy_gnostyccy", "display_name": "Teologowie Gnostyccy", "influence_start": 0.15, "tension_start": 20.0,
           "axis_preferences": [{"axis": "A", "direction": -1}, {"axis": "C", "direction": 1}]}
        ]
      },
      {
        "id": "religie_arabskie",
        "display_name": "Religie Arabskie",
        "icon": "🌙",
        "axes": {"A": 25.0, "B": 30.0, "C": 55.0, "D": 45.0},
        "prestige_start": 150,
        "holy_sites": ["mekka"],
        "color": "#1a1000",
        "accent_color": "#dd9922",
        "trait_id": "pluralizm_plemienny",
        "factions": [
          {"id": "straznicy_kaaby", "display_name": "Strażnicy Kaaby", "influence_start": 0.40, "tension_start": 20.0,
           "axis_preferences": [{"axis": "C", "direction": 1}, {"axis": "B", "direction": -1}]},
          {"id": "kaplani_plemienni", "display_name": "Kapłani Plemienni", "influence_start": 0.35, "tension_start": 20.0,
           "axis_preferences": [{"axis": "B", "direction": -1}]},
          {"id": "kupcy_wedrowcy", "display_name": "Kupcy i Wędrowcy", "influence_start": 0.25, "tension_start": 20.0,
           "axis_preferences": [{"axis": "C", "direction": 1}]}
        ]
      },
      {
        "id": "hinduizm",
        "display_name": "Hinduizm",
        "icon": "🕉",
        "axes": {"A": 50.0, "B": 70.0, "C": 45.0, "D": 65.0},
        "prestige_start": 400,
        "holy_sites": ["varanasi"],
        "color": "#1a0808",
        "accent_color": "#ee5533",
        "trait_id": "dharma_i_varna",
        "factions": [
          {"id": "brahmani", "display_name": "Brahmani", "influence_start": 0.45, "tension_start": 20.0,
           "axis_preferences": [{"axis": "B", "direction": 1}, {"axis": "D", "direction": 1}]},
          {"id": "kszatrijowie", "display_name": "Kszatrijowie", "influence_start": 0.35, "tension_start": 20.0,
           "axis_preferences": [{"axis": "D", "direction": -1}]},
          {"id": "wisznuici", "display_name": "Wisznuici", "influence_start": 0.20, "tension_start": 20.0,
           "axis_preferences": [{"axis": "C", "direction": 1}, {"axis": "D", "direction": 1}]}
        ]
      },
      {
        "id": "buddyzm",
        "display_name": "Buddyzm",
        "icon": "☸",
        "axes": {"A": 35.0, "B": 40.0, "C": 70.0, "D": 85.0},
        "prestige_start": 350,
        "holy_sites": ["bodh_gaja"],
        "color": "#001518",
        "accent_color": "#33bbcc",
        "trait_id": "srodkowa_droga",
        "factions": [
          {"id": "sangha_monastyczna", "display_name": "Sangha Monastyczna", "influence_start": 0.50, "tension_start": 20.0,
           "axis_preferences": [{"axis": "D", "direction": 1}, {"axis": "B", "direction": -1}]},
          {"id": "buddyzm_swiatowy", "display_name": "Buddyzm Światowy", "influence_start": 0.30, "tension_start": 20.0,
           "axis_preferences": [{"axis": "C", "direction": 1}]},
          {"id": "mahayana", "display_name": "Mahajana", "influence_start": 0.20, "tension_start": 20.0,
           "axis_preferences": [{"axis": "C", "direction": 1}, {"axis": "D", "direction": 1}]}
        ]
      },
      {
        "id": "religie_germanskie",
        "display_name": "Religie Germańskie",
        "icon": "⚡",
        "axes": {"A": 20.0, "B": 35.0, "C": 60.0, "D": 50.0},
        "prestige_start": 150,
        "holy_sites": ["uppsala"],
        "color": "#0d1408",
        "accent_color": "#88cc44",
        "trait_id": "ragnarok",
        "factions": [
          {"id": "seidmeni", "display_name": "Seidmeni i Wróże", "influence_start": 0.40, "tension_start": 20.0,
           "axis_preferences": [{"axis": "A", "direction": -1}, {"axis": "D", "direction": 1}]},
          {"id": "jarle", "display_name": "Jarlowie Wojownicy", "influence_start": 0.35, "tension_start": 20.0,
           "axis_preferences": [{"axis": "D", "direction": -1}, {"axis": "C", "direction": -1}]},
          {"id": "wolni_wikingi", "display_name": "Wolni Wikingowie", "influence_start": 0.25, "tension_start": 20.0,
           "axis_preferences": [{"axis": "B", "direction": -1}]}
        ]
      },
      {
        "id": "religie_slowianski",
        "display_name": "Religie Słowiańskie",
        "icon": "🌿",
        "axes": {"A": 20.0, "B": 25.0, "C": 65.0, "D": 55.0},
        "prestige_start": 120,
        "holy_sites": ["arkona"],
        "color": "#0a1210",
        "accent_color": "#55bb88",
        "trait_id": "ziemia_i_krew",
        "factions": [
          {"id": "wolchwi", "display_name": "Wolchwi", "influence_start": 0.45, "tension_start": 20.0,
           "axis_preferences": [{"axis": "D", "direction": 1}, {"axis": "A", "direction": -1}]},
          {"id": "plemienna_starszyzna", "display_name": "Plemienna Starszyzna", "influence_start": 0.35, "tension_start": 20.0,
           "axis_preferences": [{"axis": "B", "direction": -1}]},
          {"id": "herosi_zemi", "display_name": "Herosi Ziemi", "influence_start": 0.20, "tension_start": 20.0,
           "axis_preferences": [{"axis": "D", "direction": -1}, {"axis": "C", "direction": 1}]}
        ]
      }
    ]
  }
  ```

- [ ] **Krok 2: Napisz test loadera religii**

  Utwórz `tests/engine/test_religion_loader.gd`:
  ```gdscript
  extends GutTest

  func test_loader_returns_12_religions() -> void:
      var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
      assert_eq(religions.size(), 12)

  func test_loader_islam_axes_correct() -> void:
      var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
      var islam: Religion = null
      for r: Religion in religions:
          if r.id == "islam":
              islam = r
              break
      assert_not_null(islam)
      assert_eq(islam.get_axis("A"), 70.0)
      assert_eq(islam.get_axis("C"), 30.0)

  func test_loader_islam_has_three_factions() -> void:
      var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
      var islam: Religion = null
      for r: Religion in religions:
          if r.id == "islam":
              islam = r
              break
      assert_eq(islam.factions.size(), 3)

  func test_loader_prestige_loaded_correctly() -> void:
      var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
      var islam: Religion = null
      for r: Religion in religions:
          if r.id == "islam":
              islam = r
              break
      assert_eq(islam.prestige, 300)
  ```

- [ ] **Krok 3: Zaimplementuj ReligionLoader**

  Utwórz `scripts/engine/ReligionLoader.gd`:
  ```gdscript
  class_name ReligionLoader
  extends RefCounted

  static func load_from_file(path: String) -> Array[Religion]:
      var file := FileAccess.open(path, FileAccess.READ)
      if file == null:
          push_error("ReligionLoader: cannot open " + path)
          return []
      var json := JSON.new()
      var error := json.parse(file.get_as_text())
      file.close()
      if error != OK:
          push_error("ReligionLoader: JSON parse error in " + path)
          return []
      return _parse_religions(json.get_data())

  static func _parse_religions(data: Dictionary) -> Array[Religion]:
      var result: Array[Religion] = []
      for rd: Dictionary in data.get("religions", []):
          result.append(_parse_religion(rd))
      return result

  static func _parse_religion(rd: Dictionary) -> Religion:
      var r := Religion.new()
      r.id = rd.get("id", "")
      r.display_name = rd.get("display_name", "")
      r.icon = rd.get("icon", "")
      r.axes = rd.get("axes", {"A": 50.0, "B": 50.0, "C": 50.0, "D": 50.0})
      r.prestige = rd.get("prestige_start", 0)
      r.holy_sites = rd.get("holy_sites", [])
      r.color = rd.get("color", "#ffffff")
      r.accent_color = rd.get("accent_color", "#ffffff")
      r.trait_id = rd.get("trait_id", "")
      for fd: Dictionary in rd.get("factions", []):
          r.factions.append(_parse_faction(fd))
      return r

  static func _parse_faction(fd: Dictionary) -> Faction:
      var f := Faction.new()
      f.id = fd.get("id", "")
      f.display_name = fd.get("display_name", "")
      f.influence = fd.get("influence_start", 0.0)
      f.tension = fd.get("tension_start", 0.0)
      f.axis_preferences = fd.get("axis_preferences", [])
      return f
  ```

- [ ] **Krok 4: Napisz test loadera prowincji**

  Utwórz `data/provinces_historical.json` (kluczowe prowincje Bliskiego Wschodu):
  ```json
  {
    "provinces": [
      {"id": "mekka", "display_name": "Mekka", "owner": "religie_arabskie",
       "pressure": {"religie_arabskie": 80.0}, "population": 200,
       "resources": {"food": 1, "gold": 3}, "terrain": "desert",
       "neighbors": ["lewant", "jemen", "arabia_polnocna"], "is_holy_site": true},
      {"id": "lewant", "display_name": "Lewant", "owner": "chr_wschodnie",
       "pressure": {"chr_wschodnie": 60.0, "islam": 15.0}, "population": 300,
       "resources": {"food": 2, "gold": 2}, "terrain": "coast",
       "neighbors": ["mekka", "anatolia", "egipt", "jerozolima"], "is_holy_site": false},
      {"id": "jerozolima", "display_name": "Jerozolima", "owner": "chr_wschodnie",
       "pressure": {"chr_wschodnie": 70.0, "judaizm": 40.0}, "population": 150,
       "resources": {"food": 1, "gold": 2}, "terrain": "plains",
       "neighbors": ["lewant", "egipt"], "is_holy_site": true},
      {"id": "egipt", "display_name": "Egipt", "owner": "koptyjski",
       "pressure": {"koptyjski": 65.0, "islam": 10.0}, "population": 500,
       "resources": {"food": 4, "gold": 2}, "terrain": "fertile",
       "neighbors": ["lewant", "jerozolima", "libia"], "is_holy_site": false},
      {"id": "anatolia", "display_name": "Anatolia", "owner": "chr_wschodnie",
       "pressure": {"chr_wschodnie": 75.0}, "population": 400,
       "resources": {"food": 2, "gold": 1}, "terrain": "plains",
       "neighbors": ["lewant", "konstantynopol", "armenia"], "is_holy_site": false},
      {"id": "konstantynopol", "display_name": "Konstantynopol", "owner": "chr_wschodnie",
       "pressure": {"chr_wschodnie": 85.0}, "population": 600,
       "resources": {"food": 2, "gold": 4}, "terrain": "coast",
       "neighbors": ["anatolia", "tracja"], "is_holy_site": true},
      {"id": "persja", "display_name": "Persja", "owner": "zoroastryzm",
       "pressure": {"zoroastryzm": 70.0, "islam": 20.0}, "population": 450,
       "resources": {"food": 2, "gold": 2}, "terrain": "plains",
       "neighbors": ["persepolis", "mezopotamia", "armenia"], "is_holy_site": false},
      {"id": "persepolis", "display_name": "Persepolis", "owner": "zoroastryzm",
       "pressure": {"zoroastryzm": 80.0}, "population": 300,
       "resources": {"food": 1, "gold": 3}, "terrain": "plains",
       "neighbors": ["persja"], "is_holy_site": false},
      {"id": "mezopotamia", "display_name": "Mezopotamia", "owner": "islam",
       "pressure": {"islam": 55.0, "zoroastryzm": 20.0}, "population": 400,
       "resources": {"food": 3, "gold": 2}, "terrain": "fertile",
       "neighbors": ["persja", "lewant", "arabia_polnocna"], "is_holy_site": false},
      {"id": "arabia_polnocna", "display_name": "Arabia Północna", "owner": "religie_arabskie",
       "pressure": {"religie_arabskie": 70.0, "islam": 10.0}, "population": 200,
       "resources": {"food": 1, "gold": 2}, "terrain": "desert",
       "neighbors": ["mekka", "mezopotamia", "lewant"], "is_holy_site": false},
      {"id": "rzym", "display_name": "Rzym", "owner": "chr_zachodnie",
       "pressure": {"chr_zachodnie": 85.0}, "population": 350,
       "resources": {"food": 2, "gold": 3}, "terrain": "plains",
       "neighbors": ["italia_polnocna", "afryka_polnocna"], "is_holy_site": true},
      {"id": "armenia", "display_name": "Armenia", "owner": "chr_wschodnie",
       "pressure": {"chr_wschodnie": 55.0, "zoroastryzm": 25.0}, "population": 200,
       "resources": {"food": 2, "gold": 1}, "terrain": "mountains",
       "neighbors": ["anatolia", "persja", "konstantynopol"], "is_holy_site": false}
    ]
  }
  ```

  Utwórz `scripts/engine/ProvinceLoader.gd`:
  ```gdscript
  class_name ProvinceLoader
  extends RefCounted

  static func load_graph_from_file(path: String) -> ProvinceGraph:
      var file := FileAccess.open(path, FileAccess.READ)
      if file == null:
          push_error("ProvinceLoader: cannot open " + path)
          return ProvinceGraph.new()
      var json := JSON.new()
      var error := json.parse(file.get_as_text())
      file.close()
      if error != OK:
          push_error("ProvinceLoader: JSON parse error in " + path)
          return ProvinceGraph.new()
      return _build_graph(json.get_data())

  static func _build_graph(data: Dictionary) -> ProvinceGraph:
      var graph := ProvinceGraph.new()
      var province_list: Array[Dictionary] = data.get("provinces", [])
      for pd: Dictionary in province_list:
          graph.add_province(_parse_province(pd))
      for pd: Dictionary in province_list:
          var id: String = pd.get("id", "")
          for neighbor: String in pd.get("neighbors", []):
              if graph.get_province(neighbor) != null:
                  graph.add_edge(id, neighbor)
      return graph

  static func _parse_province(pd: Dictionary) -> Province:
      var p := Province.new()
      p.id = pd.get("id", "")
      p.owner = pd.get("owner", "")
      p.pressure = pd.get("pressure", {})
      p.population = pd.get("population", 0)
      p.resources = pd.get("resources", {"food": 0, "gold": 0})
      p.terrain = pd.get("terrain", "plains")
      p.neighbors = pd.get("neighbors", [])
      p.is_holy_site = pd.get("is_holy_site", false)
      return p
  ```

  Utwórz `tests/engine/test_province_loader.gd`:
  ```gdscript
  extends GutTest

  func test_loader_returns_non_empty_graph() -> void:
      var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
      assert_gt(graph.province_count(), 0)

  func test_loader_mekka_is_holy_site() -> void:
      var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
      var mekka := graph.get_province("mekka")
      assert_not_null(mekka)
      assert_true(mekka.is_holy_site)

  func test_loader_mekka_neighbors_lewant() -> void:
      var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
      assert_true(graph.are_neighbors("mekka", "lewant"))

  func test_loader_province_has_correct_owner() -> void:
      var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
      var egipt := graph.get_province("egipt")
      assert_eq(egipt.owner, "koptyjski")
  ```

- [ ] **Krok 5: Uruchom wszystkie testy — oczekuj PASS**

  ```bash
  godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
    -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -30
  ```
  Oczekiwany wynik: wszystkie testy PASS (w tym nowe 4+4 testy loaderów).

- [ ] **Krok 6: Commit**

  ```bash
  git add data/ scripts/engine/ReligionLoader.gd scripts/engine/ProvinceLoader.gd \
    tests/engine/test_religion_loader.gd tests/engine/test_province_loader.gd
  git commit -m "feat: dodaj dane JSON i loadery prowincji/religii"
  ```

---

### Zadanie 7: GameState — autoload

**Pliki:**
- Utwórz: `scripts/engine/GameState.gd`
- Utwórz: `tests/engine/test_game_state.gd`

- [ ] **Krok 1: Zarejestruj GameState jako Autoload**

  W Godot Editor: Project → Project Settings → Autoload → kliknij "+ Add":
  - Path: `res://scripts/engine/GameState.gd`
  - Name: `GameState`
  - Global Variable: włączone

- [ ] **Krok 2: Napisz test GameState**

  Utwórz `tests/engine/test_game_state.gd`:
  ```gdscript
  extends GutTest

  func _make_state() -> GameState:
      var gs := GameState.new()
      var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
      var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
      gs.initialize("islam", religions, graph)
      return gs

  func test_game_state_turn_starts_at_one() -> void:
      var gs := _make_state()
      assert_eq(gs.current_turn, 1)

  func test_game_state_player_religion_set_correctly() -> void:
      var gs := _make_state()
      assert_eq(gs.player_religion_id, "islam")

  func test_game_state_get_player_religion_returns_correct() -> void:
      var gs := _make_state()
      assert_eq(gs.get_player_religion().id, "islam")

  func test_game_state_get_religion_by_id() -> void:
      var gs := _make_state()
      var r := gs.get_religion("chr_zachodnie")
      assert_not_null(r)
      assert_eq(r.id, "chr_zachodnie")

  func test_game_state_provinces_graph_accessible() -> void:
      var gs := _make_state()
      assert_not_null(gs.province_graph)
      assert_gt(gs.province_graph.province_count(), 0)

  func test_game_state_all_religions_loaded() -> void:
      var gs := _make_state()
      assert_eq(gs.all_religions().size(), 12)
  ```

- [ ] **Krok 3: Zaimplementuj GameState**

  Utwórz `scripts/engine/GameState.gd`:
  ```gdscript
  class_name GameState
  extends Node

  var current_turn: int = 1
  var player_religion_id: String = ""
  var province_graph: ProvinceGraph = null

  var _religions: Dictionary = {}

  func initialize(player_id: String, religions: Array[Religion], graph: ProvinceGraph) -> void:
      player_religion_id = player_id
      province_graph = graph
      _religions.clear()
      for r: Religion in religions:
          _religions[r.id] = r

  func get_player_religion() -> Religion:
      return get_religion(player_religion_id)

  func get_religion(religion_id: String) -> Religion:
      return _religions.get(religion_id, null)

  func all_religions() -> Array[Religion]:
      var result: Array[Religion] = []
      for r: Religion in _religions.values():
          result.append(r)
      return result

  func advance_turn() -> void:
      current_turn += 1
  ```

- [ ] **Krok 4: Uruchom test — oczekuj PASS**

  Oczekiwany wynik: `6 passed, 0 failed`.

- [ ] **Krok 5: Commit**

  ```bash
  git add scripts/engine/GameState.gd tests/engine/test_game_state.gd
  git commit -m "feat: dodaj GameState autoload z inicjalizacją stanu gry"
  ```

---

### Zadanie 8: TurnManager — pętla tury

**Pliki:**
- Utwórz: `scripts/engine/TurnManager.gd`
- Utwórz: `tests/engine/test_turn_manager.gd`

TurnManager przetwarza jedną turę: (1) pasywna presja między sąsiednimi prowincjami, (2) prestiż za święte miasta, (3) aktualizacja napięć frakcji na podstawie odchylenia osi.

Per spec mapy sekcja 3: pasywna presja +1-3/turę zależnie od terenu. Per spec profili: frakcje z niespełnioną preferencją osi narastają o +2 napięcia/turę.

- [ ] **Krok 1: Napisz test TurnManager**

  Utwórz `tests/engine/test_turn_manager.gd`:
  ```gdscript
  extends GutTest

  var _tm: TurnManager
  var _state: GameState

  func before_each() -> void:
      _state = GameState.new()
      var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
      var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
      _state.initialize("islam", religions, graph)
      _tm = TurnManager.new()

  func test_process_turn_advances_turn_counter() -> void:
      _tm.process_turn(_state)
      assert_eq(_state.current_turn, 2)

  func test_passive_pressure_increases_on_adjacent_foreign_province() -> void:
      var graph := _state.province_graph
      var mezopotamia := graph.get_province("mezopotamia")
      var initial_zoroastr := mezopotamia.get_pressure("zoroastryzm")
      _tm.process_turn(_state)
      assert_gt(mezopotamia.get_pressure("zoroastryzm"), initial_zoroastr)

  func test_no_pressure_from_same_owner_neighbor() -> void:
      # persepolis (owner=zoroastryzm) sąsiaduje z persja (owner=zoroastryzm)
      # persepolis NIE powinna dostawać presji "zoroastryzm" — sąsiad to ta sama religia
      var graph := _state.province_graph
      var persepolis := graph.get_province("persepolis")
      var initial_zor := persepolis.get_pressure("zoroastryzm")
      _tm.process_turn(_state)
      assert_eq(persepolis.get_pressure("zoroastryzm"), initial_zor)

  func test_passive_pressure_foreign_religion_increases_on_border_province() -> void:
      var graph := _state.province_graph
      var persja := graph.get_province("persja")
      var initial_islam := persja.get_pressure("islam")
      _tm.process_turn(_state)
      assert_gt(persja.get_pressure("islam"), initial_islam)

  func test_holy_site_owner_gains_prestige() -> void:
      var islam := _state.get_religion("religie_arabskie")
      var initial_prestige := islam.prestige
      _tm.process_turn(_state)
      assert_gt(islam.prestige, initial_prestige)

  func test_faction_tension_increases_when_axis_diverges() -> void:
      var islam := _state.get_religion("islam")
      var sufici := islam.get_faction("sufici")
      islam.axes["A"] = 90.0
      var initial_tension := sufici.tension
      _tm.process_turn(_state)
      assert_gt(sufici.tension, initial_tension)
  ```

- [ ] **Krok 2: Uruchom test — oczekuj FAIL**

  Oczekiwany wynik: `Class "TurnManager" not found`.

- [ ] **Krok 3: Zaimplementuj TurnManager**

  Utwórz `scripts/engine/TurnManager.gd`:
  ```gdscript
  class_name TurnManager
  extends RefCounted

  const HOLY_SITE_PRESTIGE_PER_TURN := 3
  const FACTION_TENSION_PER_DIVERGED_AXIS := 2.0
  const AXIS_DIVERGENCE_THRESHOLD := 20.0

  func process_turn(state: GameState) -> void:
      _apply_passive_pressure(state.province_graph)
      _apply_holy_site_prestige(state)
      _update_faction_tensions(state)
      state.advance_turn()

  func _apply_passive_pressure(graph: ProvinceGraph) -> void:
      for province: Province in graph.all_provinces():
          for neighbor_id: String in graph.get_neighbors(province.id):
              var neighbor := graph.get_province(neighbor_id)
              if neighbor == null or neighbor.owner == province.owner:
                  continue
              var delta := _pressure_delta(province.terrain)
              province.add_pressure(neighbor.owner, delta)

  # Uproszczenie PoC: delta na podstawie terenu prowincji odbierającej presję.
  # Plan mechaniki.md rozszerzy o populację sąsiada jako mnożnik.
  func _pressure_delta(terrain: String) -> float:
      match terrain:
          "mountains": return 1.0
          "desert": return 1.0
          _: return 2.0

  func _apply_holy_site_prestige(state: GameState) -> void:
      for province: Province in state.province_graph.all_provinces():
          if not province.is_holy_site or province.owner == "":
              continue
          var owner := state.get_religion(province.owner)
          if owner != null:
              owner.add_prestige(HOLY_SITE_PRESTIGE_PER_TURN)

  func _update_faction_tensions(state: GameState) -> void:
      for religion: Religion in state.all_religions():
          for faction: Faction in religion.factions:
              var tension_delta := _compute_faction_tension_delta(religion, faction)
              faction.add_tension(tension_delta)

  func _compute_faction_tension_delta(religion: Religion, faction: Faction) -> float:
      var delta := 0.0
      for pref: Dictionary in faction.axis_preferences:
          var axis: String = pref.get("axis", "")
          var direction: int = pref.get("direction", 0)
          var axis_val := religion.get_axis(axis)
          var preferred_high := direction > 0
          var diverged := (preferred_high and axis_val < 100.0 - AXIS_DIVERGENCE_THRESHOLD) or \
                          (not preferred_high and axis_val > AXIS_DIVERGENCE_THRESHOLD)
          if diverged:
              delta += FACTION_TENSION_PER_DIVERGED_AXIS
      return delta
  ```

- [ ] **Krok 4: Uruchom wszystkie testy — oczekuj PASS**

  ```bash
  godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
    -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -30
  ```
  Oczekiwany wynik: `6 passed, 0 failed` dla `test_turn_manager.gd`, wszystkie pozostałe testy PASS.

- [ ] **Krok 5: Commit końcowy**

  ```bash
  git add scripts/engine/TurnManager.gd tests/engine/test_turn_manager.gd
  git commit -m "feat: dodaj TurnManager z presją pasywną, prestiżem i napięciami frakcji"
  ```

---

## Weryfikacja końcowa

Po zakończeniu wszystkich zadań:

```bash
# Uruchom wszystkie testy
godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
  -gdir=res://tests -ginclude_subdirs -gexit 2>&1 | tail -40
```

Oczekiwany wynik: wszystkie testy z `tests/engine/` PASS, 0 FAIL.

**Co zostało zbudowane:**
- Model danych: `Province`, `Faction`, `Religion` z pełną logiką
- Graf prowincji: `ProvinceGraph` z sąsiedztwem i zapytaniami
- Dane startowe: JSON dla 12 religii i ~12 prowincji historycznych
- Loadery: `ReligionLoader`, `ProvinceLoader`
- Stan gry: `GameState` autoload
- Pętla tury: `TurnManager` z presją, prestiżem i frakcjami

**Następny plan:** `2026-06-04-mechaniki.md` — doktryny, dyplomacja, system wojen.
