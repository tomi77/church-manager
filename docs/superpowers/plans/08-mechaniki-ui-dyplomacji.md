# UI Dyplomacji Implementation Plan

> **For Claude:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Zbudować pierwszą warstwę UI projektu — shell desktop (header + 4-zakładkowy pasek + 3 placeholdery + zakładka Świat) plus StartMenu z wyborem religii startowej — pokrywającą 8 akcji dyplomatycznych (Sojusz, Interdykt, Misjonarze, Sobór ekum., 2× Wasalstwo, Sobór wasalski, Rewanż) oraz Sobór Pokojowy w sekcji aktywnych konfliktów.

**Architecture:** Godot 4.6 Control nodes, jedna scena `.tscn` + jeden skrypt `.gd` per komponent (≤150 linii każdy). Komunikacja dziecko→rodzic przez sygnały, rodzic→dziecko przez settery. `GameState` (autoload) jako jedyne źródło prawdy — UI czyta, akcje piszą przez stateless `DiplomacyManager`/`WarManager`. Refresh: pełny rerender, bez dirty-tracking.

**Tech Stack:** Godot 4.6, GDScript 2.0, GUT (headless test runner), `.tscn` Scene files.

**Spec źródłowy:** [`docs/superpowers/specs/09-diplomacy-ui-design.md`](../specs/09-diplomacy-ui-design.md) (wymagana lektura — wszystkie warunki gating'u akcji, konwencje sygnałów, palety kolorów odwołują się tu).

**Stan startowy:** branch `master`, 295/295 testów PASS (Plan 07 zakończony commitem `858127f`). Docelowo +~50 testów UI → ~345 PASS.

**Test runner:**
```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

**Konwencje:**
- 4-spacjowy indent (zgodnie z silnikiem; wyjątek `DoctrineManager.gd` — UI trzyma się spaces)
- `class_name` dla każdego skryptu UI
- Eksport pola startowego: `@export var foo: T = default`
- NodePath w testach przez unique names: `get_node("%LabelName").text`
- Sygnały: lower_snake_case, parametry typowane (`signal religion_selected(id: String)`)

**Świadome odstępstwa od spec 09 (MVP simplifications):**
- **TabBar** używa modulate dimming (active = full color, inactive = gray) zamiast spec'owego "zielony underline + bold" — prostsze w Godot 4 bez własnych themed styles. Polish w przyszłym planie.
- **StartMenu karty** są pojedynczymi `Button` z tekstem `[ikona]\n[nazwa]` zamiast spec'owych kart z subtitlem (dominująca prowincja + trait) i kolorem tła z palety. MVP — wzbogacenie kart w przyszłym planie.
- **Unit testy** używają bezpośrednio `GameStateScript.new()` jako lokalnej instancji `Node`, nie autoloadu `GameState` (autoload używany tylko produkcyjnie przez `StartMenu._on_start_pressed`). Wzorzec już istniejący w `tests/engine/test_diplomacy_manager.gd::_make_state`.

**Engine-vs-UI gating reconciliation (kotwiczone przez plan-document-reviewer Chunk 2):**
- `_alliance_available` używa `<` (engine semantyka: blokuje gdy `trust<50 AND econ<60` → allow gdy `≥50 OR ≥60`), nie `>` (jak literalny spec sek.7). Spec używał luźnego matematycznego zapisu; engine `>=` jest źródłem prawdy.
- `_ecu_council_available` używa `tension > 85` (engine używa `>` strict), nie `≥ 85`. Identyczna reconcylacja.
- W przypadku konfliktu między UI gating a engine guard, **engine ma pierwszeństwo** — UI nigdy nie blokuje akcji która by przeszła w engine (UI stricter ≤ engine wider).

---

## Chunk 1: Foundation + Shell

### Task 0: Rename projektu church-manager → religion-manager

Tylko funkcjonalne pliki konfiguracji + README. Historyczne dokumenty (specs 01-08, plans 01-07) pozostawiamy nietknięte — dokumentują stan z momentu ich powstania. Ścieżka repo, remote i historia git poza zakresem.

**Files:**
- Modify: `project.godot:13`
- Modify: `README.md:1-3`

- [ ] **Step 1: Update `project.godot` config/name**

Zmień linię 13 z:
```
config/name="church-manager"
```
na:
```
config/name="religion-manager"
```

- [ ] **Step 2: Update `README.md` tytuł + krótki opis**

Plik `README.md` aktualnie:
```markdown
# church-manager

Manager kościoła

## Założenia
* Wybór religii (judaizm, chrześcijaństwo, islam, może inne)
* Rozwój od początku
* Zmiany założeń, wchłanianie idei innych religii, prowadzenie wojen
```

Zmień na:
```markdown
# religion-manager

Strategiczna gra o ewolucji 12 religii w VII wieku — doktryna, dyplomacja, wojna, schizmy.

## Założenia
* Wybór jednej z 12 religii startowych (m.in. islam, chrześcijaństwo zachodnie/wschodnie, koptyjski, zoroastryzm, manicheizm, judaizm, hinduizm, buddyzm)
* Rozwój teologiczny przez 4 osie doktrynalne (Dogmatyzm, Hierarchia, Synkretyzm, Transcendencja)
* Dyplomacja: sojusze, sobory, interdykty, misjonarze, wasalstwo, koalicje
* Wojna: casus belli, krucjaty/dżihady, kara w przypadku porażki
* Frakcje wewnętrzne i schizmy
```

- [ ] **Step 3: Weryfikacja braku regresji**

Uruchom test suite (silnik powinien być całkowicie odporny na rename):
```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
Expected: `295/295 PASS` (lub baseline taki jaki był przed Task 0).

- [ ] **Step 4: Commit**

```bash
git add project.godot README.md
git commit -m "chore: rename project church-manager → religion-manager

Spec 09 sek.10 — Task 0. Tylko project.godot (config/name) + README.md.
Historyczne dokumenty (specs/plans 01-08) nietknięte, ścieżka repo i remote
poza zakresem."
```

---

### Task 1: Setup tests/ui directory + smoke test

Utwórz katalogi UI i jeden smoke test żeby zweryfikować że GUT podnosi pliki z subdirów.

**Files:**
- Create: `tests/ui/test_smoke.gd`

- [ ] **Step 1: Utwórz katalogi**

```bash
mkdir -p /Users/tomaszrup/Projects/github.com/tomi77/church-manager/scripts/ui/world
mkdir -p /Users/tomaszrup/Projects/github.com/tomi77/church-manager/scenes/ui/world
mkdir -p /Users/tomaszrup/Projects/github.com/tomi77/church-manager/tests/ui
```

- [ ] **Step 2: Write `tests/ui/test_smoke.gd`**

```gdscript
extends GutTest

func test_ui_test_dir_is_discovered():
    # Smoke test — jeśli runner ten plik podniósł, to katalog tests/ui/ jest discoverable
    assert_true(true, "tests/ui/ jest discoverable przez GUT")
```

- [ ] **Step 3: Run, expect pass**

```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
Expected: `296/296 PASS` (295 baseline + 1 smoke).

- [ ] **Step 4: Commit**

```bash
git add tests/ui/test_smoke.gd
git commit -m "test: add tests/ui/ smoke test (foundation for Plan 08)

Weryfikuje że GUT podnosi pliki z tests/ui/ via -ginclude_subdirs."
```

---

### Task 2: PlaceholderTab (najprostszy komponent — buduje pattern)

Reusable scena dla zakładek Mapa/Wiara/Frakcje. Pokazuje wyśrodkowany Label z param `title`.

**Files:**
- Create: `scenes/ui/PlaceholderTab.tscn`
- Create: `scripts/ui/PlaceholderTab.gd`
- Create: `tests/ui/test_placeholder_tab.gd`

- [ ] **Step 1: Write `scripts/ui/PlaceholderTab.gd`**

```gdscript
class_name PlaceholderTab
extends Control

@export var title: String = "Placeholder"

@onready var _label: Label = %TitleLabel

func _ready() -> void:
    _refresh()

func set_title(new_title: String) -> void:
    title = new_title
    if is_inside_tree():
        _refresh()

func _refresh() -> void:
    _label.text = title
```

- [ ] **Step 2: Write `scenes/ui/PlaceholderTab.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/PlaceholderTab.gd" id="1"]

[node name="PlaceholderTab" type="Control"]
script = ExtResource("1")
anchor_right = 1.0
anchor_bottom = 1.0

[node name="TitleLabel" type="Label" parent="."]
unique_name_in_owner = true
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -100.0
offset_top = -10.0
offset_right = 100.0
offset_bottom = 10.0
horizontal_alignment = 1
vertical_alignment = 1
text = "Placeholder"
```

- [ ] **Step 3: Write `tests/ui/test_placeholder_tab.gd`**

```gdscript
extends GutTest

const PlaceholderTabScene := preload("res://scenes/ui/PlaceholderTab.tscn")

func test_default_title_rendered():
    var tab: PlaceholderTab = PlaceholderTabScene.instantiate()
    add_child_autofree(tab)
    await get_tree().process_frame
    assert_eq(tab.get_node("%TitleLabel").text, "Placeholder")

func test_set_title_updates_label():
    var tab: PlaceholderTab = PlaceholderTabScene.instantiate()
    add_child_autofree(tab)
    await get_tree().process_frame
    tab.set_title("Mapa (Plan 09 — w trakcie)")
    assert_eq(tab.get_node("%TitleLabel").text, "Mapa (Plan 09 — w trakcie)")

func test_set_title_before_ready_persists():
    var tab: PlaceholderTab = PlaceholderTabScene.instantiate()
    tab.title = "Wiara (Plan 10 — w trakcie)"
    add_child_autofree(tab)
    await get_tree().process_frame
    assert_eq(tab.get_node("%TitleLabel").text, "Wiara (Plan 10 — w trakcie)")
```

- [ ] **Step 4: Run, expect pass (3 nowe testy → 299/299)**

```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- [ ] **Step 5: Commit**

```bash
git add scenes/ui/PlaceholderTab.tscn scripts/ui/PlaceholderTab.gd tests/ui/test_placeholder_tab.gd
git commit -m "feat(ui): PlaceholderTab scene + script

Reusable placeholder dla zakładek Mapa/Wiara/Frakcje (Plan 08, spec 09 sek.5).
Param 'title' przez setter; renderuje wyśrodkowany Label."
```

---

### Task 3: Header

Header globalny: religia + tura + prestiż + zasoby + alerts + End Turn button. Bind do stub state.

**Files:**
- Create: `scenes/ui/Header.tscn`
- Create: `scripts/ui/Header.gd`
- Create: `tests/ui/test_header.gd`

- [ ] **Step 1: Write `scripts/ui/Header.gd`**

```gdscript
class_name Header
extends HBoxContainer

signal turn_ended

@onready var _icon: Label = %IconLabel
@onready var _name: Label = %NameLabel
@onready var _turn: Label = %TurnLabel
@onready var _prestige: Label = %PrestigeLabel
@onready var _resources: Label = %ResourcesLabel
@onready var _food: Label = %FoodLabel
@onready var _wars: Label = %WarsLabel
@onready var _faction_alert: Label = %FactionAlertLabel
@onready var _end_turn_btn: Button = %EndTurnButton

var state: Node = null

func _ready() -> void:
    _end_turn_btn.pressed.connect(_on_end_turn_pressed)

func bind_state(s: Node) -> void:
    state = s
    refresh()

func refresh() -> void:
    if state == null:
        return
    var player: Religion = state.get_player_religion()
    if player == null:
        return
    _icon.text = player.icon
    _name.text = player.display_name
    _turn.text = "Tura %d" % state.current_turn
    _prestige.text = "⚑ %d" % player.prestige

    var income := _compute_income(player)
    _resources.text = "📦 %+d/turę" % income
    _food.text = "🌾 %+d/turę" % _compute_food(player)

    var active_wars := _count_active_wars(player.id)
    _wars.text = "⚔ %d aktywna" % active_wars
    _wars.modulate = Color(1.0, 0.4, 0.4) if active_wars > 0 else Color(0.7, 0.7, 0.7)

    var dom := player.dominant_faction()
    if dom != null and dom.tension > 80.0:
        _faction_alert.text = "⚠ Frakcja %s: napięcie %d" % [dom.id, int(dom.tension)]
        _faction_alert.visible = true
    else:
        _faction_alert.visible = false

func _compute_income(player: Religion) -> int:
    var income := DiplomacyManager.PASSIVE_INCOME_PER_TURN
    if player.suzerain_id != "":
        income -= DiplomacyManager.TRIBUTE_PER_TURN
    for r: Religion in state.all_religions():
        if r.suzerain_id == player.id:
            income += DiplomacyManager.TRIBUTE_PER_TURN
    return income

func _compute_food(player: Religion) -> int:
    var total := 0
    for prov: Province in state.province_graph.provinces_with_owner(player.id):
        total += int(prov.resources.get("food", 0))
    return total

func _count_active_wars(player_id: String) -> int:
    var n := 0
    for war: War in state.active_wars:
        if war.state == "ENDED":
            continue
        if war.attacker_id == player_id or war.defender_id == player_id:
            n += 1
    return n

func _on_end_turn_pressed() -> void:
    if state == null:
        return
    var tm := TurnManager.new()
    tm.process_turn(state)
    refresh()
    emit_signal("turn_ended")
```

- [ ] **Step 2: Write `scenes/ui/Header.tscn`**

Scena to `HBoxContainer` z dziećmi `Label` (każdy z `unique_name_in_owner=true`) + `Button` na końcu. Wszystkie Labele mają theme_override_font_sizes/font_size=14, BoxContainer separation=12.

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/Header.gd" id="1"]

[node name="Header" type="HBoxContainer"]
script = ExtResource("1")
theme_override_constants/separation = 12
custom_minimum_size = Vector2(0, 32)

[node name="IconLabel" type="Label" parent="."]
unique_name_in_owner = true
text = "?"

[node name="NameLabel" type="Label" parent="."]
unique_name_in_owner = true
text = "Religia"

[node name="TurnLabel" type="Label" parent="."]
unique_name_in_owner = true
text = "Tura ?"

[node name="PrestigeLabel" type="Label" parent="."]
unique_name_in_owner = true
text = "⚑ ?"

[node name="ResourcesLabel" type="Label" parent="."]
unique_name_in_owner = true
text = "📦 ?"

[node name="FoodLabel" type="Label" parent="."]
unique_name_in_owner = true
text = "🌾 ?"

[node name="WarsLabel" type="Label" parent="."]
unique_name_in_owner = true
text = "⚔ ?"

[node name="FactionAlertLabel" type="Label" parent="."]
unique_name_in_owner = true
visible = false
text = "⚠ Frakcja"

[node name="Spacer" type="Control" parent="."]
size_flags_horizontal = 3

[node name="EndTurnButton" type="Button" parent="."]
unique_name_in_owner = true
text = "Zakończ turę →"
```

- [ ] **Step 3: Write `tests/ui/test_header.gd`**

```gdscript
extends GutTest

const HeaderScene := preload("res://scenes/ui/Header.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
    var gs: Node = GameStateScript.new()
    var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
    var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
    gs.initialize("islam", religions, graph)
    return gs

func _instance_header(state: Node) -> Header:
    var h: Header = HeaderScene.instantiate()
    add_child_autofree(h)
    await get_tree().process_frame
    h.bind_state(state)
    return h

func test_header_renders_player_name():
    var state := _make_state()
    add_child_autofree(state)
    var h := await _instance_header(state)
    var player: Religion = state.get_player_religion()
    assert_eq(h.get_node("%NameLabel").text, player.display_name)
    assert_eq(h.get_node("%IconLabel").text, player.icon)

func test_header_renders_turn():
    var state := _make_state()
    add_child_autofree(state)
    state.current_turn = 14
    var h := await _instance_header(state)
    assert_eq(h.get_node("%TurnLabel").text, "Tura 14")

func test_header_renders_prestige():
    var state := _make_state()
    add_child_autofree(state)
    state.get_player_religion().prestige = 285
    var h := await _instance_header(state)
    assert_eq(h.get_node("%PrestigeLabel").text, "⚑ 285")

func test_header_wars_label_red_when_active():
    var state := _make_state()
    add_child_autofree(state)
    var war := War.new()
    war.attacker_id = "islam"
    war.defender_id = "zoroastryzm"
    war.state = "BATTLING"
    state.active_wars.append(war)
    var h := await _instance_header(state)
    assert_eq(h.get_node("%WarsLabel").text, "⚔ 1 aktywna")
    assert_almost_eq(h.get_node("%WarsLabel").modulate.r, 1.0, 0.01)

func test_header_wars_label_gray_when_no_active():
    var state := _make_state()
    add_child_autofree(state)
    var h := await _instance_header(state)
    assert_eq(h.get_node("%WarsLabel").text, "⚔ 0 aktywna")
    assert_lt(h.get_node("%WarsLabel").modulate.r, 1.0)

func test_header_faction_alert_visible_when_tension_over_80():
    var state := _make_state()
    add_child_autofree(state)
    var player := state.get_player_religion()
    player.factions[0].tension = 85.0
    player.factions[0].influence = 50.0  # dominant
    var h := await _instance_header(state)
    assert_true(h.get_node("%FactionAlertLabel").visible)

func test_header_faction_alert_hidden_when_low_tension():
    var state := _make_state()
    add_child_autofree(state)
    var h := await _instance_header(state)
    assert_false(h.get_node("%FactionAlertLabel").visible)

func test_header_end_turn_button_emits_signal():
    var state := _make_state()
    add_child_autofree(state)
    var h := await _instance_header(state)
    watch_signals(h)
    h.get_node("%EndTurnButton").emit_signal("pressed")
    assert_signal_emitted(h, "turn_ended")

func test_header_end_turn_advances_turn():
    var state := _make_state()
    add_child_autofree(state)
    var initial_turn: int = state.current_turn
    var h := await _instance_header(state)
    h.get_node("%EndTurnButton").emit_signal("pressed")
    assert_eq(state.current_turn, initial_turn + 1)
```

- [ ] **Step 4: Run testy, oczekuj 9 nowych pass (305/305)**

- [ ] **Step 5: Commit**

```bash
git add scenes/ui/Header.tscn scripts/ui/Header.gd tests/ui/test_header.gd
git commit -m "feat(ui): Header — religia, tura, zasoby, alerty, End Turn

Spec 09 sek.4. Wskaźniki: prestiż, +zasoby/turę (📦), żywność, aktywne wojny
(czerwony gdy >0), alert frakcji (gdy dominant.tension >80). Przycisk End
Turn wywołuje TurnManager.process_turn() i emituje sygnał turn_ended."
```

---

### Task 4: TabBar

Pasek 4 przycisków zakładek. Aktywna zakładka ma underline + bold. Alerty (czerwona kropka) na podstawie state.

**Files:**
- Create: `scenes/ui/TabBar.tscn`
- Create: `scripts/ui/TabBar.gd`
- Create: `tests/ui/test_tab_bar.gd`

- [ ] **Step 1: Write `scripts/ui/TabBar.gd`**

```gdscript
class_name TabBar
extends HBoxContainer

signal tab_changed(tab_id: String)

const TABS := ["mapa", "wiara", "swiat", "frakcje"]
const LABELS := {"mapa": "🗺 Mapa", "wiara": "🕌 Wiara", "swiat": "🌍 Świat", "frakcje": "👥 Frakcje"}

var current_tab: String = "swiat"
var state: Node = null

@onready var _buttons := {
    "mapa": %MapaButton,
    "wiara": %WiaraButton,
    "swiat": %SwiatButton,
    "frakcje": %FrakcjeButton,
}
@onready var _dots := {
    "mapa": %MapaDot,
    "wiara": %WiaraDot,
    "swiat": %SwiatDot,
    "frakcje": %FrakcjeDot,
}

func _ready() -> void:
    for tab_id: String in TABS:
        var btn: Button = _buttons[tab_id]
        btn.text = LABELS[tab_id]
        btn.pressed.connect(_on_tab_pressed.bind(tab_id))
    _refresh_active()

func bind_state(s: Node) -> void:
    state = s
    refresh()

func set_current_tab(tab_id: String) -> void:
    if not tab_id in TABS:
        return
    current_tab = tab_id
    _refresh_active()
    emit_signal("tab_changed", tab_id)

func refresh() -> void:
    _refresh_active()
    _refresh_dots()

func _refresh_active() -> void:
    for tab_id: String in TABS:
        var btn: Button = _buttons[tab_id]
        btn.modulate = Color(1, 1, 1) if tab_id == current_tab else Color(0.6, 0.6, 0.6)

func _refresh_dots() -> void:
    for tab_id: String in TABS:
        _dots[tab_id].visible = _should_alert(tab_id)

func _should_alert(tab_id: String) -> bool:
    if state == null:
        return false
    var player: Religion = state.get_player_religion()
    if player == null:
        return false
    if tab_id == "swiat":
        # Alert gdy koalicja przeciw graczowi LUB grievance window aktywne
        for c: Coalition in state.active_coalitions:
            if c.target_id == player.id:
                return true
        if player.interdict_grievance_until > state.current_turn and player.interdict_grievance_from_id != "":
            return true
    elif tab_id == "frakcje":
        var dom: Faction = player.dominant_faction()
        if dom != null and dom.tension > 80.0:
            return true
    return false

func _on_tab_pressed(tab_id: String) -> void:
    set_current_tab(tab_id)
```

- [ ] **Step 2: Write `scenes/ui/TabBar.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/TabBar.gd" id="1"]

[node name="TabBar" type="HBoxContainer"]
script = ExtResource("1")
theme_override_constants/separation = 0
custom_minimum_size = Vector2(0, 36)

[node name="MapaContainer" type="HBoxContainer" parent="."]

[node name="MapaButton" type="Button" parent="MapaContainer"]
unique_name_in_owner = true
text = "🗺 Mapa"

[node name="MapaDot" type="ColorRect" parent="MapaContainer"]
unique_name_in_owner = true
visible = false
custom_minimum_size = Vector2(6, 6)
color = Color(1, 0.4, 0.4, 1)

[node name="WiaraContainer" type="HBoxContainer" parent="."]

[node name="WiaraButton" type="Button" parent="WiaraContainer"]
unique_name_in_owner = true
text = "🕌 Wiara"

[node name="WiaraDot" type="ColorRect" parent="WiaraContainer"]
unique_name_in_owner = true
visible = false
custom_minimum_size = Vector2(6, 6)
color = Color(1, 0.4, 0.4, 1)

[node name="SwiatContainer" type="HBoxContainer" parent="."]

[node name="SwiatButton" type="Button" parent="SwiatContainer"]
unique_name_in_owner = true
text = "🌍 Świat"

[node name="SwiatDot" type="ColorRect" parent="SwiatContainer"]
unique_name_in_owner = true
visible = false
custom_minimum_size = Vector2(6, 6)
color = Color(1, 0.4, 0.4, 1)

[node name="FrakcjeContainer" type="HBoxContainer" parent="."]

[node name="FrakcjeButton" type="Button" parent="FrakcjeContainer"]
unique_name_in_owner = true
text = "👥 Frakcje"

[node name="FrakcjeDot" type="ColorRect" parent="FrakcjeContainer"]
unique_name_in_owner = true
visible = false
custom_minimum_size = Vector2(6, 6)
color = Color(1, 0.4, 0.4, 1)
```

- [ ] **Step 3: Write `tests/ui/test_tab_bar.gd`**

```gdscript
extends GutTest

const TabBarScene := preload("res://scenes/ui/TabBar.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")
const CoalitionScript := preload("res://scripts/engine/Coalition.gd")

func _make_state() -> Node:
    var gs: Node = GameStateScript.new()
    var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
    var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
    gs.initialize("islam", religions, graph)
    return gs

func _instance_tab_bar(state: Node) -> TabBar:
    var tb: TabBar = TabBarScene.instantiate()
    add_child_autofree(tb)
    await get_tree().process_frame
    tb.bind_state(state)
    return tb

func test_default_current_tab_is_swiat():
    var state := _make_state()
    add_child_autofree(state)
    var tb := await _instance_tab_bar(state)
    assert_eq(tb.current_tab, "swiat")

func test_clicking_mapa_changes_current_tab():
    var state := _make_state()
    add_child_autofree(state)
    var tb := await _instance_tab_bar(state)
    watch_signals(tb)
    tb.get_node("%MapaButton").emit_signal("pressed")
    assert_eq(tb.current_tab, "mapa")
    assert_signal_emitted_with_parameters(tb, "tab_changed", ["mapa"])

func test_active_tab_has_full_modulate():
    var state := _make_state()
    add_child_autofree(state)
    var tb := await _instance_tab_bar(state)
    tb.set_current_tab("swiat")
    assert_almost_eq(tb.get_node("%SwiatButton").modulate.r, 1.0, 0.01)
    assert_lt(tb.get_node("%MapaButton").modulate.r, 1.0)

func test_swiat_alert_dot_when_coalition_against_player():
    var state := _make_state()
    add_child_autofree(state)
    var c: Coalition = CoalitionScript.new()
    c.target_id = state.player_religion_id
    c.members = ["chr_zachodnie"]
    state.active_coalitions.append(c)
    var tb := await _instance_tab_bar(state)
    assert_true(tb.get_node("%SwiatDot").visible)

func test_swiat_alert_dot_when_grievance_active():
    var state := _make_state()
    add_child_autofree(state)
    var player := state.get_player_religion()
    player.interdict_grievance_from_id = "chr_zachodnie"
    player.interdict_grievance_until = state.current_turn + 5
    var tb := await _instance_tab_bar(state)
    assert_true(tb.get_node("%SwiatDot").visible)

func test_frakcje_alert_dot_when_faction_tension_over_80():
    var state := _make_state()
    add_child_autofree(state)
    var player := state.get_player_religion()
    player.factions[0].tension = 85.0
    player.factions[0].influence = 50.0
    var tb := await _instance_tab_bar(state)
    assert_true(tb.get_node("%FrakcjeDot").visible)

func test_no_alert_dots_when_calm_state():
    var state := _make_state()
    add_child_autofree(state)
    var tb := await _instance_tab_bar(state)
    assert_false(tb.get_node("%SwiatDot").visible)
    assert_false(tb.get_node("%FrakcjeDot").visible)
    assert_false(tb.get_node("%MapaDot").visible)
    assert_false(tb.get_node("%WiaraDot").visible)
```

- [ ] **Step 4: Run, expect 7 nowych pass (312/312)**

- [ ] **Step 5: Commit**

```bash
git add scenes/ui/TabBar.tscn scripts/ui/TabBar.gd tests/ui/test_tab_bar.gd
git commit -m "feat(ui): TabBar — 4 zakładki + alert dots

Spec 09 sek.4. 4 zakładki (Mapa/Wiara/Świat/Frakcje), aktywna pełne modulate,
niewybrane przyciemnione. Alert dots: Świat → koalicja przeciw lub
grievance window; Frakcje → dominująca.tension >80. Default tab = swiat."
```

---

### Task 5: MainShell

Orchestrator: header + tabbar + content_area (4 zakładki, jedna widoczna). Bind GameState. Refresh całości po End Turn lub state_changed.

**Files:**
- Create: `scenes/ui/MainShell.tscn`
- Create: `scripts/ui/MainShell.gd`
- Create: `tests/ui/test_main_shell.gd`

Dla tej fazy zakładka Świat to **stub** — `Control` z labelem "World tab (Task 12)". Zostanie wymieniony w Task 12.

- [ ] **Step 1: Write `scripts/ui/MainShell.gd`**

```gdscript
class_name MainShell
extends Control

@onready var _header: Header = %Header
@onready var _tab_bar: TabBar = %TabBar
@onready var _content := %ContentArea
@onready var _mapa_tab: PlaceholderTab = %MapaTab
@onready var _wiara_tab: PlaceholderTab = %WiaraTab
@onready var _swiat_tab: Control = %SwiatTab
@onready var _frakcje_tab: PlaceholderTab = %FrakcjeTab

var state: Node = null

func _ready() -> void:
    _mapa_tab.set_title("Mapa (Plan 09 — w trakcie)")
    _wiara_tab.set_title("Wiara (Plan 10 — w trakcie)")
    _frakcje_tab.set_title("Frakcje (Plan 11 — w trakcie)")
    _tab_bar.tab_changed.connect(_on_tab_changed)
    _header.turn_ended.connect(_on_turn_ended)
    _on_tab_changed(_tab_bar.current_tab)

func bind_state(s: Node) -> void:
    state = s
    _header.bind_state(s)
    _tab_bar.bind_state(s)
    if _swiat_tab.has_method("bind_state"):
        _swiat_tab.bind_state(s)
    refresh()

func refresh() -> void:
    _header.refresh()
    _tab_bar.refresh()
    if _swiat_tab.has_method("refresh"):
        _swiat_tab.refresh()

func _on_tab_changed(tab_id: String) -> void:
    _mapa_tab.visible = tab_id == "mapa"
    _wiara_tab.visible = tab_id == "wiara"
    _swiat_tab.visible = tab_id == "swiat"
    _frakcje_tab.visible = tab_id == "frakcje"

func _on_turn_ended() -> void:
    refresh()
```

- [ ] **Step 2: Write `scenes/ui/MainShell.tscn`**

VBoxContainer root: header (top), tabbar (under header), content_area (fill rest). Content area to `Control` z 4 dzieci-zakładkami nakładającymi się (anchor full rect).

```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/ui/MainShell.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/ui/Header.tscn" id="2"]
[ext_resource type="PackedScene" path="res://scenes/ui/TabBar.tscn" id="3"]
[ext_resource type="PackedScene" path="res://scenes/ui/PlaceholderTab.tscn" id="4"]

[node name="MainShell" type="Control"]
script = ExtResource("1")
anchor_right = 1.0
anchor_bottom = 1.0

[node name="VBox" type="VBoxContainer" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0

[node name="Header" parent="VBox" instance=ExtResource("2")]
unique_name_in_owner = true

[node name="TabBar" parent="VBox" instance=ExtResource("3")]
unique_name_in_owner = true

[node name="ContentArea" type="Control" parent="VBox"]
unique_name_in_owner = true
size_flags_horizontal = 3
size_flags_vertical = 3

[node name="MapaTab" parent="VBox/ContentArea" instance=ExtResource("4")]
unique_name_in_owner = true
visible = false

[node name="WiaraTab" parent="VBox/ContentArea" instance=ExtResource("4")]
unique_name_in_owner = true
visible = false

[node name="SwiatTab" type="Control" parent="VBox/ContentArea"]
unique_name_in_owner = true
anchor_right = 1.0
anchor_bottom = 1.0

[node name="SwiatStubLabel" type="Label" parent="VBox/ContentArea/SwiatTab"]
text = "Świat (stub — wymieniony w Task 12)"

[node name="FrakcjeTab" parent="VBox/ContentArea" instance=ExtResource("4")]
unique_name_in_owner = true
visible = false
```

- [ ] **Step 3: Write `tests/ui/test_main_shell.gd`**

```gdscript
extends GutTest

const MainShellScene := preload("res://scenes/ui/MainShell.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
    var gs: Node = GameStateScript.new()
    var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
    var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
    gs.initialize("islam", religions, graph)
    return gs

func _instance_shell(state: Node) -> MainShell:
    var s: MainShell = MainShellScene.instantiate()
    add_child_autofree(s)
    await get_tree().process_frame
    s.bind_state(state)
    return s

func test_shell_default_shows_swiat_tab():
    var state := _make_state()
    add_child_autofree(state)
    var shell := await _instance_shell(state)
    assert_true(shell.get_node("%SwiatTab").visible)
    assert_false(shell.get_node("%MapaTab").visible)
    assert_false(shell.get_node("%WiaraTab").visible)
    assert_false(shell.get_node("%FrakcjeTab").visible)

func test_shell_tab_change_switches_visible_content():
    var state := _make_state()
    add_child_autofree(state)
    var shell := await _instance_shell(state)
    shell.get_node("%TabBar").set_current_tab("wiara")
    assert_true(shell.get_node("%WiaraTab").visible)
    assert_false(shell.get_node("%SwiatTab").visible)

func test_shell_placeholders_have_correct_titles():
    var state := _make_state()
    add_child_autofree(state)
    var shell := await _instance_shell(state)
    var mapa: PlaceholderTab = shell.get_node("%MapaTab")
    var wiara: PlaceholderTab = shell.get_node("%WiaraTab")
    var frakcje: PlaceholderTab = shell.get_node("%FrakcjeTab")
    assert_string_contains(mapa.title, "Plan 09")
    assert_string_contains(wiara.title, "Plan 10")
    assert_string_contains(frakcje.title, "Plan 11")

func test_shell_end_turn_refreshes():
    var state := _make_state()
    add_child_autofree(state)
    state.get_player_religion().prestige = 100
    var shell := await _instance_shell(state)
    var initial_turn: int = state.current_turn
    shell.get_node("%Header").get_node("%EndTurnButton").emit_signal("pressed")
    assert_eq(state.current_turn, initial_turn + 1)
    assert_eq(shell.get_node("%Header").get_node("%TurnLabel").text, "Tura %d" % state.current_turn)
```

- [ ] **Step 4: Run testy (4 nowe → 316/316)**

- [ ] **Step 5: Commit**

```bash
git add scenes/ui/MainShell.tscn scripts/ui/MainShell.gd tests/ui/test_main_shell.gd
git commit -m "feat(ui): MainShell — orchestrator (header + tabbar + content)

Spec 09 sek.4. VBox z headerem na górze, tabbarem pod, content area
z 4 zakładkami (3 placeholdery, Świat stub). Tab change → przełącza
visible. End Turn → refresh całości. Świat tab wymieniony w Task 12."
```

---

### Task 6: StartMenu

Siatka 4×3 z 12 religiami. Klik karty selektuje, klik "Rozpocznij grę" inicjalizuje GameState i przełącza scenę.

**Files:**
- Create: `scenes/ui/StartMenu.tscn`
- Create: `scripts/ui/StartMenu.gd`
- Create: `tests/ui/test_start_menu.gd`

- [ ] **Step 1: Write `scripts/ui/StartMenu.gd`**

```gdscript
class_name StartMenu
extends Control

signal religion_selected(id: String)

var _selected_id: String = ""
var _religions: Array[Religion] = []

@onready var _grid: GridContainer = %ReligionGrid
@onready var _info_label: Label = %SelectedInfoLabel
@onready var _start_btn: Button = %StartButton

func _ready() -> void:
    _religions = ReligionLoader.load_from_file("res://data/religions_historical.json")
    _populate_grid()
    _start_btn.disabled = true
    _start_btn.pressed.connect(_on_start_pressed)

func _populate_grid() -> void:
    for r: Religion in _religions:
        var btn := Button.new()
        btn.text = "%s\n%s" % [r.icon, r.display_name]
        btn.custom_minimum_size = Vector2(180, 100)
        btn.pressed.connect(_on_card_pressed.bind(r.id))
        _grid.add_child(btn)

func _on_card_pressed(religion_id: String) -> void:
    _selected_id = religion_id
    var r := _find_religion(religion_id)
    if r != null:
        _info_label.text = "Wybrana: %s" % r.display_name
    _start_btn.disabled = false
    emit_signal("religion_selected", religion_id)

func _on_start_pressed() -> void:
    if _selected_id == "":
        return
    var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
    var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
    GameState.initialize(_selected_id, religions, graph)
    get_tree().change_scene_to_file("res://scenes/ui/MainShell.tscn")

func _find_religion(id: String) -> Religion:
    for r: Religion in _religions:
        if r.id == id:
            return r
    return null
```

- [ ] **Step 2: Write `scenes/ui/StartMenu.tscn`**

VBox: title label, GridContainer (columns=4), info label + Start button.

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/StartMenu.gd" id="1"]

[node name="StartMenu" type="Control"]
script = ExtResource("1")
anchor_right = 1.0
anchor_bottom = 1.0

[node name="VBox" type="VBoxContainer" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 32.0
offset_top = 32.0
offset_right = -32.0
offset_bottom = -32.0
theme_override_constants/separation = 16

[node name="TitleLabel" type="Label" parent="VBox"]
text = "Religion Manager"
horizontal_alignment = 1

[node name="SubtitleLabel" type="Label" parent="VBox"]
text = "Wybierz religię, którą poprowadzisz przez VII wiek"
horizontal_alignment = 1

[node name="ReligionGrid" type="GridContainer" parent="VBox"]
unique_name_in_owner = true
columns = 4
size_flags_horizontal = 3
size_flags_vertical = 3
theme_override_constants/h_separation = 12
theme_override_constants/v_separation = 12

[node name="BottomRow" type="HBoxContainer" parent="VBox"]

[node name="SelectedInfoLabel" type="Label" parent="VBox/BottomRow"]
unique_name_in_owner = true
text = "Wybierz religię…"
size_flags_horizontal = 3

[node name="StartButton" type="Button" parent="VBox/BottomRow"]
unique_name_in_owner = true
text = "Rozpocznij grę →"
disabled = true
```

- [ ] **Step 3: Write `tests/ui/test_start_menu.gd`**

```gdscript
extends GutTest

const StartMenuScene := preload("res://scenes/ui/StartMenu.tscn")

func _instance_menu() -> StartMenu:
    var m: StartMenu = StartMenuScene.instantiate()
    add_child_autofree(m)
    await get_tree().process_frame
    return m

func test_grid_populated_with_12_religions():
    var m := await _instance_menu()
    var grid: GridContainer = m.get_node("%ReligionGrid")
    assert_eq(grid.get_child_count(), 12)

func test_start_button_disabled_initially():
    var m := await _instance_menu()
    assert_true(m.get_node("%StartButton").disabled)

func test_card_click_enables_start_button():
    var m := await _instance_menu()
    watch_signals(m)
    var first_card: Button = m.get_node("%ReligionGrid").get_child(0)
    first_card.emit_signal("pressed")
    assert_false(m.get_node("%StartButton").disabled)
    assert_signal_emitted(m, "religion_selected")

func test_selected_info_updates_on_card_click():
    var m := await _instance_menu()
    var first_card: Button = m.get_node("%ReligionGrid").get_child(0)
    first_card.emit_signal("pressed")
    var info_text: String = m.get_node("%SelectedInfoLabel").text
    assert_string_contains(info_text, "Wybrana:")

func test_religion_selected_signal_carries_id():
    var m := await _instance_menu()
    watch_signals(m)
    var first_card: Button = m.get_node("%ReligionGrid").get_child(0)
    first_card.emit_signal("pressed")
    var params = get_signal_parameters(m, "religion_selected", 0)
    assert_typeof(params[0], TYPE_STRING)
    assert_true(params[0].length() > 0)
```

- [ ] **Step 4: Run, expect 5 pass (321/321)**

- [ ] **Step 5: Commit**

```bash
git add scenes/ui/StartMenu.tscn scripts/ui/StartMenu.gd tests/ui/test_start_menu.gd
git commit -m "feat(ui): StartMenu — wybór 1 z 12 religii startowych

Spec 09 sek.3. Siatka 4×3 z religiami ładowanymi z
religions_historical.json. Klik karty → religion_selected(id) + enable
Start button. Klik Start → init GameState + change_scene do MainShell."
```

---

### Task 7: Wire StartMenu jako main scene + zaktualizuj scenes/Main.tscn

`project.godot` `main_scene` musi wskazywać na StartMenu (lub Main.tscn który ładuje StartMenu). Per spec 09 sek.2: Main.tscn staje się Control z child=StartMenu.

**Files:**
- Modify: `scenes/Main.tscn`
- Modify: `project.godot` (potwierdzenie main_scene)

- [ ] **Step 1: Replace `scenes/Main.tscn`**

Zastąp aktualną zawartość (gołe Node2D) na Control z StartMenu jako instance child:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="PackedScene" path="res://scenes/ui/StartMenu.tscn" id="1"]

[node name="Main" type="Control"]
anchor_right = 1.0
anchor_bottom = 1.0

[node name="StartMenu" parent="." instance=ExtResource("1")]
```

- [ ] **Step 2: Sprawdź `project.godot:16`**

Powinno wskazywać:
```
config/main_scene="res://scenes/Main.tscn"
```
Nie zmieniaj jeśli już tak jest.

- [ ] **Step 3: Smoke run godota**

```bash
godot --headless --path . --quit-after 2 2>&1 | head -20
```
Expected: brak błędów ładowania scen (warnings dopuszczalne).

- [ ] **Step 4: Run testy (powinno być nadal 321/321 — bez nowych testów, tylko zmiana sceny)**

- [ ] **Step 5: Commit**

```bash
git add scenes/Main.tscn
git commit -m "feat(ui): Main.tscn ładuje StartMenu jako pierwszą scenę

Spec 09 sek.2. Main.tscn staje się Control z embed StartMenu jako child.
Klik 'Rozpocznij grę' wewnątrz StartMenu wywołuje change_scene_to_file
do MainShell.tscn (już zaimplementowane w Task 6)."
```

---

## Chunk 2: World tab components

### Task 8: RelationListItem

Pojedynczy wiersz listy relacji: ikona + nazwa + paski Z/E/N + marker statusu.

**Files:**
- Create: `scenes/ui/world/RelationListItem.tscn`
- Create: `scripts/ui/world/RelationListItem.gd`
- Create: `tests/ui/test_relation_list_item.gd`

- [ ] **Step 1: Write `scripts/ui/world/RelationListItem.gd`**

```gdscript
class_name RelationListItem
extends PanelContainer

signal pressed(religion_id: String)

var religion: Religion = null
var relation: RelationState = null
var marker: String = ""
var is_selected: bool = false

@onready var _btn: Button = %RowButton
@onready var _name_label: Label = %NameLabel
@onready var _z_label: Label = %ZLabel
@onready var _e_label: Label = %ELabel
@onready var _n_label: Label = %NLabel
@onready var _marker_label: Label = %MarkerLabel

func _ready() -> void:
    _btn.pressed.connect(_on_pressed)

func set_data(rel: RelationState, r: Religion, marker_text: String) -> void:
    religion = r
    relation = rel
    marker = marker_text
    if is_inside_tree():
        _refresh()

func set_selected(sel: bool) -> void:
    is_selected = sel
    if is_inside_tree():
        _refresh_selection()

func _refresh() -> void:
    if religion == null:
        return
    _name_label.text = "%s %s" % [religion.icon, religion.display_name]
    if relation != null:
        _z_label.text = "Z %d" % int(relation.theological_trust)
        _e_label.text = "E %d" % int(relation.economic_cooperation)
        _n_label.text = "N %d" % int(relation.military_tension)
    else:
        _z_label.text = "Z 0"
        _e_label.text = "E 0"
        _n_label.text = "N 0"
    _marker_label.text = marker
    _refresh_selection()

func _refresh_selection() -> void:
    modulate = Color(1.1, 1.1, 1.1) if is_selected else Color(1, 1, 1)

func _on_pressed() -> void:
    emit_signal("pressed", religion.id if religion != null else "")
```

- [ ] **Step 2: Write `scenes/ui/world/RelationListItem.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/world/RelationListItem.gd" id="1"]

[node name="RelationListItem" type="PanelContainer"]
script = ExtResource("1")

[node name="RowButton" type="Button" parent="."]
unique_name_in_owner = true
flat = true

[node name="HBox" type="HBoxContainer" parent="RowButton"]
anchor_right = 1.0
anchor_bottom = 1.0
theme_override_constants/separation = 8

[node name="NameLabel" type="Label" parent="RowButton/HBox"]
unique_name_in_owner = true
size_flags_horizontal = 3
text = "?"

[node name="ZLabel" type="Label" parent="RowButton/HBox"]
unique_name_in_owner = true
text = "Z ?"

[node name="ELabel" type="Label" parent="RowButton/HBox"]
unique_name_in_owner = true
text = "E ?"

[node name="NLabel" type="Label" parent="RowButton/HBox"]
unique_name_in_owner = true
text = "N ?"

[node name="MarkerLabel" type="Label" parent="RowButton/HBox"]
unique_name_in_owner = true
text = ""
```

- [ ] **Step 3: Write `tests/ui/test_relation_list_item.gd`**

```gdscript
extends GutTest

const ItemScene := preload("res://scenes/ui/world/RelationListItem.tscn")
const ReligionScript := preload("res://scripts/engine/Religion.gd")
const RelationStateScript := preload("res://scripts/engine/RelationState.gd")

func _make_religion(id: String, name: String, icon: String) -> Religion:
    var r: Religion = ReligionScript.new()
    r.id = id
    r.display_name = name
    r.icon = icon
    return r

func _make_relation(z: float, e: float, n: float) -> RelationState:
    var rel: RelationState = RelationStateScript.new()
    rel.theological_trust = z
    rel.economic_cooperation = e
    rel.military_tension = n
    return rel

func _instance() -> RelationListItem:
    var item: RelationListItem = ItemScene.instantiate()
    add_child_autofree(item)
    await get_tree().process_frame
    return item

func test_renders_name_and_icon():
    var item := await _instance()
    var r := _make_religion("chr_zach", "Chr. Zachodnie", "✝")
    item.set_data(_make_relation(0, 0, 0), r, "")
    var text: String = item.get_node("%NameLabel").text
    assert_string_contains(text, "Chr. Zachodnie")
    assert_string_contains(text, "✝")

func test_renders_zen_values():
    var item := await _instance()
    item.set_data(_make_relation(65.0, 40.0, 35.0), _make_religion("x", "X", "?"), "")
    assert_eq(item.get_node("%ZLabel").text, "Z 65")
    assert_eq(item.get_node("%ELabel").text, "E 40")
    assert_eq(item.get_node("%NLabel").text, "N 35")

func test_renders_marker():
    var item := await _instance()
    item.set_data(_make_relation(0, 0, 0), _make_religion("x", "X", "?"), "🤝")
    assert_eq(item.get_node("%MarkerLabel").text, "🤝")

func test_click_emits_pressed_with_religion_id():
    var item := await _instance()
    item.set_data(_make_relation(0, 0, 0), _make_religion("zoro", "Zoroastryzm", "🔥"), "")
    watch_signals(item)
    item.get_node("%RowButton").emit_signal("pressed")
    assert_signal_emitted_with_parameters(item, "pressed", ["zoro"])

func test_set_selected_changes_modulate():
    var item := await _instance()
    item.set_data(_make_relation(0, 0, 0), _make_religion("x", "X", "?"), "")
    item.set_selected(false)
    var unselected_r: float = item.modulate.r
    item.set_selected(true)
    assert_gt(item.modulate.r, unselected_r)

func test_null_relation_renders_zero():
    var item := await _instance()
    item.set_data(null, _make_religion("x", "X", "?"), "")
    assert_eq(item.get_node("%ZLabel").text, "Z 0")
```

- [ ] **Step 4: Run, expect 6 pass (327/327)**

- [ ] **Step 5: Commit**

```bash
git add scenes/ui/world/RelationListItem.tscn scripts/ui/world/RelationListItem.gd tests/ui/test_relation_list_item.gd
git commit -m "feat(ui): RelationListItem — wiersz listy relacji

Spec 09 sek.6. PanelContainer z Button (flat), name+icon, Z/E/N values,
marker (sojusz/wojna/wasal/koalicja/Rewanż), selekcja przez modulate."
```

---

### Task 9: RelationList

Lista wszystkich religii bez gracza, posortowana wg statusu (wojny → koalicja przeciw → sojusznicy → wasale → reszta alfa).

**Files:**
- Create: `scenes/ui/world/RelationList.tscn`
- Create: `scripts/ui/world/RelationList.gd`
- Create: `tests/ui/test_relation_list.gd`

- [ ] **Step 1: Write `scripts/ui/world/RelationList.gd`**

```gdscript
class_name RelationList
extends ScrollContainer

signal religion_selected(id: String)

const RelationListItemScene := preload("res://scenes/ui/world/RelationListItem.tscn")

var state: Node = null
var _selected_id: String = ""
var _items: Dictionary = {}

@onready var _vbox: VBoxContainer = %ItemsVBox

func bind_state(s: Node) -> void:
    state = s
    refresh()

func set_selected(id: String) -> void:
    _selected_id = id
    for item_id: String in _items:
        _items[item_id].set_selected(item_id == id)

func refresh() -> void:
    if state == null:
        return
    for child in _vbox.get_children():
        child.queue_free()
    _items.clear()

    var player_id: String = state.player_religion_id
    var others: Array[Religion] = []
    for r: Religion in state.all_religions():
        if r.id != player_id:
            others.append(r)

    others.sort_custom(func(a: Religion, b: Religion) -> bool:
        return _sort_key(a) < _sort_key(b))

    for r: Religion in others:
        var rel := _get_relation(r.id)
        var marker := _compute_marker(r)
        var item: RelationListItem = RelationListItemScene.instantiate()
        _vbox.add_child(item)
        item.set_data(rel, r, marker)
        item.set_selected(r.id == _selected_id)
        item.pressed.connect(_on_item_pressed)
        _items[r.id] = item

func _get_relation(other_id: String) -> RelationState:
    var dm := DiplomacyManager.new()
    return dm.get_or_create_relation(state, state.player_religion_id, other_id)

func _sort_key(r: Religion) -> String:
    var player_id: String = state.player_religion_id
    # 0=war, 1=coalition_against, 2=ally, 3=our_vassal, 4=our_patron, 5=rest alpha
    for war: War in state.active_wars:
        if war.state == "ENDED":
            continue
        if (war.attacker_id == player_id and war.defender_id == r.id) or \
           (war.attacker_id == r.id and war.defender_id == player_id):
            return "0_" + r.id
    for c: Coalition in state.active_coalitions:
        if c.target_id == player_id and r.id in c.members:
            return "1_" + r.id
    var rel := _get_relation(r.id)
    if rel != null and rel.alliance_active:
        return "2_" + r.id
    if r.suzerain_id == player_id:
        return "3_" + r.id
    var player := state.get_player_religion()
    if player != null and player.suzerain_id == r.id:
        return "4_" + r.id
    return "5_" + r.display_name

func _compute_marker(r: Religion) -> String:
    var player_id: String = state.player_religion_id
    var player: Religion = state.get_player_religion()
    for war: War in state.active_wars:
        if war.state == "ENDED":
            continue
        if (war.attacker_id == player_id and war.defender_id == r.id) or \
           (war.attacker_id == r.id and war.defender_id == player_id):
            return "⚔"
    for c: Coalition in state.active_coalitions:
        if c.target_id == player_id and r.id in c.members:
            return "●"
    var rel := _get_relation(r.id)
    if rel != null and rel.alliance_active:
        return "🤝"
    if r.suzerain_id == player_id:
        return "↑👑"
    if player != null and player.suzerain_id == r.id:
        return "⛰"
    if player != null and player.interdict_grievance_from_id == r.id and player.interdict_grievance_until > state.current_turn:
        return "⚠"
    return ""

func _on_item_pressed(religion_id: String) -> void:
    set_selected(religion_id)
    emit_signal("religion_selected", religion_id)
```

- [ ] **Step 2: Write `scenes/ui/world/RelationList.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/world/RelationList.gd" id="1"]

[node name="RelationList" type="ScrollContainer"]
script = ExtResource("1")
custom_minimum_size = Vector2(260, 0)

[node name="ItemsVBox" type="VBoxContainer" parent="."]
unique_name_in_owner = true
size_flags_horizontal = 3
size_flags_vertical = 3
theme_override_constants/separation = 3
```

- [ ] **Step 3: Write `tests/ui/test_relation_list.gd`**

```gdscript
extends GutTest

const RelationListScene := preload("res://scenes/ui/world/RelationList.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")
const CoalitionScript := preload("res://scripts/engine/Coalition.gd")
const WarScript := preload("res://scripts/engine/War.gd")

func _make_state() -> Node:
    var gs: Node = GameStateScript.new()
    var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
    var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
    gs.initialize("islam", religions, graph)
    return gs

func _instance_list(state: Node) -> RelationList:
    var l: RelationList = RelationListScene.instantiate()
    add_child_autofree(l)
    await get_tree().process_frame
    l.bind_state(state)
    return l

func test_list_excludes_player():
    var state := _make_state()
    add_child_autofree(state)
    var l := await _instance_list(state)
    var ids: Array = []
    for item in l._items.values():
        ids.append(item.religion.id)
    assert_does_not_have(ids, "islam")

func test_list_includes_all_other_religions():
    var state := _make_state()
    add_child_autofree(state)
    var l := await _instance_list(state)
    var expected_count: int = state.all_religions().size() - 1
    assert_eq(l._items.size(), expected_count)

func test_click_item_emits_religion_selected():
    var state := _make_state()
    add_child_autofree(state)
    var l := await _instance_list(state)
    watch_signals(l)
    var first_id: String = l._items.keys()[0]
    l._items[first_id]._on_pressed()
    assert_signal_emitted_with_parameters(l, "religion_selected", [first_id])

func test_set_selected_updates_only_one_item():
    var state := _make_state()
    add_child_autofree(state)
    var l := await _instance_list(state)
    var target_id: String = l._items.keys()[2]
    l.set_selected(target_id)
    for id: String in l._items:
        assert_eq(l._items[id].is_selected, id == target_id)

func test_war_marker():
    var state := _make_state()
    add_child_autofree(state)
    var war: War = WarScript.new()
    war.attacker_id = "islam"
    war.defender_id = "zoroastryzm"
    war.state = "BATTLING"
    state.active_wars.append(war)
    var l := await _instance_list(state)
    assert_eq(l._items["zoroastryzm"].marker, "⚔")

func test_coalition_marker():
    var state := _make_state()
    add_child_autofree(state)
    var c: Coalition = CoalitionScript.new()
    c.target_id = "islam"
    c.members = ["chr_zachodnie"]
    state.active_coalitions.append(c)
    var l := await _instance_list(state)
    assert_eq(l._items["chr_zachodnie"].marker, "●")

func test_vassal_marker():
    var state := _make_state()
    add_child_autofree(state)
    state.get_religion("koptyjski").suzerain_id = "islam"
    var l := await _instance_list(state)
    assert_eq(l._items["koptyjski"].marker, "↑👑")

func test_grievance_marker():
    var state := _make_state()
    add_child_autofree(state)
    var player := state.get_player_religion()
    player.interdict_grievance_from_id = "chr_zachodnie"
    player.interdict_grievance_until = state.current_turn + 5
    var l := await _instance_list(state)
    assert_eq(l._items["chr_zachodnie"].marker, "⚠")

func test_war_sorted_first():
    var state := _make_state()
    add_child_autofree(state)
    var war: War = WarScript.new()
    war.attacker_id = "islam"
    war.defender_id = "zoroastryzm"
    war.state = "BATTLING"
    state.active_wars.append(war)
    var l := await _instance_list(state)
    var first_child: RelationListItem = l.get_node("%ItemsVBox").get_child(0)
    assert_eq(first_child.religion.id, "zoroastryzm")
```

- [ ] **Step 4: Run, expect 9 pass (336/336)**

- [ ] **Step 5: Commit**

```bash
git add scenes/ui/world/RelationList.tscn scripts/ui/world/RelationList.gd tests/ui/test_relation_list.gd
git commit -m "feat(ui): RelationList — lista wszystkich NPC religii

Spec 09 sek.6. ScrollContainer + VBox z RelationListItem per NPC.
Sortowanie: wojny → koalicja przeciw → sojusznicy → klienci → patron →
reszta alpha. Markery wg statusu (⚔ 🤝 ↑👑 ⛰ ● ⚠). Click → religion_selected."
```

---

### Task 10: ConflictSection

Sekcja "Aktywne konflikty" — czerwone tło, lista wojen gracza, przycisk Sobór Pokojowy obok każdej.

**Files:**
- Create: `scenes/ui/world/ConflictSection.tscn`
- Create: `scripts/ui/world/ConflictSection.gd`
- Create: `tests/ui/test_conflict_section.gd`

- [ ] **Step 1: Write `scripts/ui/world/ConflictSection.gd`**

```gdscript
class_name ConflictSection
extends VBoxContainer

signal state_changed

var state: Node = null

@onready var _header_label: Label = %HeaderLabel
@onready var _list_vbox: VBoxContainer = %ListVBox

func bind_state(s: Node) -> void:
    state = s
    refresh()

func refresh() -> void:
    if state == null:
        return
    for child in _list_vbox.get_children():
        child.queue_free()

    var player_id: String = state.player_religion_id
    var wars := _player_wars(player_id)

    visible = wars.size() > 0
    _header_label.text = "⚔ Aktywne konflikty (%d)" % wars.size()

    for war: War in wars:
        var row := _build_row(war, player_id)
        _list_vbox.add_child(row)

func _player_wars(player_id: String) -> Array[War]:
    var wars: Array[War] = []
    for war: War in state.active_wars:
        if war.state == "ENDED":
            continue
        if war.attacker_id == player_id or war.defender_id == player_id:
            wars.append(war)
    return wars

func _build_row(war: War, player_id: String) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)

    var other_id: String = war.defender_id if war.attacker_id == player_id else war.attacker_id
    var other: Religion = state.get_religion(other_id)
    var attacker_text: String = "atak gracza" if war.attacker_id == player_id else "atak NPC"

    var label := Label.new()
    label.text = "🔥 %s · tura %d · %s · CB: %s" % [
        other.display_name if other != null else other_id,
        war.turns_in_state,
        attacker_text,
        war.casus_belli,
    ]
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)

    var btn := Button.new()
    btn.text = "Sobór Pokojowy (25⚑)"
    var player: Religion = state.get_player_religion()
    btn.disabled = player == null or player.prestige < DiplomacyManager.PEACE_COUNCIL_PRESTIGE_COST
    btn.pressed.connect(_on_peace_council_pressed.bind(war))
    row.add_child(btn)

    return row

func _on_peace_council_pressed(_war: War) -> void:
    var dm := DiplomacyManager.new()
    var ok := dm.peace_council(state, state.player_religion_id)
    if ok:
        emit_signal("state_changed")
    refresh()
```

- [ ] **Step 2: Write `scenes/ui/world/ConflictSection.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/world/ConflictSection.gd" id="1"]

[node name="ConflictSection" type="VBoxContainer"]
script = ExtResource("1")
visible = false
modulate = Color(1, 0.95, 0.95, 1)

[node name="HeaderLabel" type="Label" parent="."]
unique_name_in_owner = true
text = "⚔ Aktywne konflikty"

[node name="ListVBox" type="VBoxContainer" parent="."]
unique_name_in_owner = true
```

- [ ] **Step 3: Write `tests/ui/test_conflict_section.gd`**

```gdscript
extends GutTest

const ConflictSectionScene := preload("res://scenes/ui/world/ConflictSection.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")
const WarScript := preload("res://scripts/engine/War.gd")

func _make_state() -> Node:
    var gs: Node = GameStateScript.new()
    var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
    var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
    gs.initialize("islam", religions, graph)
    return gs

func _instance(state: Node) -> ConflictSection:
    var s: ConflictSection = ConflictSectionScene.instantiate()
    add_child_autofree(s)
    await get_tree().process_frame
    s.bind_state(state)
    return s

func test_invisible_when_no_wars():
    var state := _make_state()
    add_child_autofree(state)
    var s := await _instance(state)
    assert_false(s.visible)

func test_visible_when_player_has_war():
    var state := _make_state()
    add_child_autofree(state)
    var war: War = WarScript.new()
    war.attacker_id = "islam"
    war.defender_id = "zoroastryzm"
    war.state = "BATTLING"
    state.active_wars.append(war)
    var s := await _instance(state)
    assert_true(s.visible)

func test_lists_only_player_wars():
    var state := _make_state()
    add_child_autofree(state)
    var w1: War = WarScript.new()
    w1.attacker_id = "islam"
    w1.defender_id = "zoroastryzm"
    w1.state = "BATTLING"
    var w2: War = WarScript.new()
    w2.attacker_id = "chr_zachodnie"
    w2.defender_id = "chr_wschodnie"
    w2.state = "BATTLING"
    state.active_wars.append(w1)
    state.active_wars.append(w2)
    var s := await _instance(state)
    assert_eq(s.get_node("%ListVBox").get_child_count(), 1)

func test_ended_wars_excluded():
    var state := _make_state()
    add_child_autofree(state)
    var war: War = WarScript.new()
    war.attacker_id = "islam"
    war.defender_id = "zoroastryzm"
    war.state = "ENDED"
    state.active_wars.append(war)
    var s := await _instance(state)
    assert_false(s.visible)

func test_peace_council_button_disabled_when_low_prestige():
    var state := _make_state()
    add_child_autofree(state)
    state.get_player_religion().prestige = 10
    var war: War = WarScript.new()
    war.attacker_id = "islam"
    war.defender_id = "zoroastryzm"
    war.state = "BATTLING"
    state.active_wars.append(war)
    var s := await _instance(state)
    var row: HBoxContainer = s.get_node("%ListVBox").get_child(0)
    var btn: Button = row.get_child(1)
    assert_true(btn.disabled)

func test_peace_council_button_enabled_when_prestige_sufficient():
    var state := _make_state()
    add_child_autofree(state)
    state.get_player_religion().prestige = 100
    var war: War = WarScript.new()
    war.attacker_id = "islam"
    war.defender_id = "zoroastryzm"
    war.state = "BATTLING"
    state.active_wars.append(war)
    var s := await _instance(state)
    var row: HBoxContainer = s.get_node("%ListVBox").get_child(0)
    var btn: Button = row.get_child(1)
    assert_false(btn.disabled)

func test_peace_council_emits_state_changed():
    var state := _make_state()
    add_child_autofree(state)
    state.get_player_religion().prestige = 100
    state.get_player_religion().war_weariness = 60.0
    var war: War = WarScript.new()
    war.attacker_id = "islam"
    war.defender_id = "zoroastryzm"
    war.state = "BATTLING"
    state.active_wars.append(war)
    var s := await _instance(state)
    watch_signals(s)
    var row: HBoxContainer = s.get_node("%ListVBox").get_child(0)
    var btn: Button = row.get_child(1)
    btn.emit_signal("pressed")
    assert_signal_emitted(s, "state_changed")
```

- [ ] **Step 4: Run (7 nowych → 343/343)**

- [ ] **Step 5: Commit**

```bash
git add scenes/ui/world/ConflictSection.tscn scripts/ui/world/ConflictSection.gd tests/ui/test_conflict_section.gd
git commit -m "feat(ui): ConflictSection — lista aktywnych wojen gracza

Spec 09 sek.6. VBoxContainer z header + lista; niewidoczne gdy brak wojen.
Każdy wiersz: opis wojny + przycisk Sobór Pokojowy (25⚑) wywołujący
DiplomacyManager.peace_council(). Emit state_changed po akcji."
```

---

### Task 11: AxisDeltaPicker

Sub-komponent dla soborów: wybór osi A/B/C/D + delty z {−8, −5, +5, +8} + przycisk Wykonaj.

**Files:**
- Create: `scenes/ui/world/AxisDeltaPicker.tscn`
- Create: `scripts/ui/world/AxisDeltaPicker.gd`
- Create: `tests/ui/test_axis_delta_picker.gd`

- [ ] **Step 1: Write `scripts/ui/world/AxisDeltaPicker.gd`**

```gdscript
class_name AxisDeltaPicker
extends HBoxContainer

signal executed(axis: String, delta: float)

const AXES := ["A", "B", "C", "D"]
const DELTAS := [-8.0, -5.0, 5.0, 8.0]

var _selected_axis: String = ""
var _selected_delta: float = 0.0

@onready var _execute_btn: Button = %ExecuteButton

func _ready() -> void:
    for axis: String in AXES:
        var btn: Button = get_node("%%%sButton" % axis)
        btn.pressed.connect(_on_axis_pressed.bind(axis))
    for delta: float in DELTAS:
        var key: String = _delta_key(delta)
        var btn: Button = get_node("%%%sButton" % key)
        btn.pressed.connect(_on_delta_pressed.bind(delta))
    _execute_btn.pressed.connect(_on_execute_pressed)
    _refresh_execute_state()

func reset() -> void:
    _selected_axis = ""
    _selected_delta = 0.0
    _refresh_axis_buttons()
    _refresh_delta_buttons()
    _refresh_execute_state()

func _delta_key(d: float) -> String:
    if d == -8.0: return "DeltaMinus8"
    if d == -5.0: return "DeltaMinus5"
    if d == 5.0: return "DeltaPlus5"
    if d == 8.0: return "DeltaPlus8"
    return "?"

func _on_axis_pressed(axis: String) -> void:
    _selected_axis = axis
    _refresh_axis_buttons()
    _refresh_execute_state()

func _on_delta_pressed(delta: float) -> void:
    _selected_delta = delta
    _refresh_delta_buttons()
    _refresh_execute_state()

func _refresh_axis_buttons() -> void:
    for axis: String in AXES:
        var btn: Button = get_node("%%%sButton" % axis)
        btn.modulate = Color(0.4, 1, 0.4) if axis == _selected_axis else Color(0.7, 0.7, 0.7)

func _refresh_delta_buttons() -> void:
    for delta: float in DELTAS:
        var key: String = _delta_key(delta)
        var btn: Button = get_node("%%%sButton" % key)
        btn.modulate = Color(0.4, 1, 0.4) if delta == _selected_delta else Color(0.7, 0.7, 0.7)

func _refresh_execute_state() -> void:
    _execute_btn.disabled = _selected_axis == "" or _selected_delta == 0.0

func _on_execute_pressed() -> void:
    if _selected_axis == "" or _selected_delta == 0.0:
        return
    emit_signal("executed", _selected_axis, _selected_delta)
    reset()
```

- [ ] **Step 2: Write `scenes/ui/world/AxisDeltaPicker.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/world/AxisDeltaPicker.gd" id="1"]

[node name="AxisDeltaPicker" type="HBoxContainer"]
script = ExtResource("1")
theme_override_constants/separation = 4

[node name="AxisLabel" type="Label" parent="."]
text = "Oś:"

[node name="AButton" type="Button" parent="."]
unique_name_in_owner = true
text = "A"

[node name="BButton" type="Button" parent="."]
unique_name_in_owner = true
text = "B"

[node name="CButton" type="Button" parent="."]
unique_name_in_owner = true
text = "C"

[node name="DButton" type="Button" parent="."]
unique_name_in_owner = true
text = "D"

[node name="DeltaLabel" type="Label" parent="."]
text = "Δ:"

[node name="DeltaMinus8Button" type="Button" parent="."]
unique_name_in_owner = true
text = "−8"

[node name="DeltaMinus5Button" type="Button" parent="."]
unique_name_in_owner = true
text = "−5"

[node name="DeltaPlus5Button" type="Button" parent="."]
unique_name_in_owner = true
text = "+5"

[node name="DeltaPlus8Button" type="Button" parent="."]
unique_name_in_owner = true
text = "+8"

[node name="Spacer" type="Control" parent="."]
size_flags_horizontal = 3

[node name="ExecuteButton" type="Button" parent="."]
unique_name_in_owner = true
text = "Wykonaj"
disabled = true
```

- [ ] **Step 3: Write `tests/ui/test_axis_delta_picker.gd`**

```gdscript
extends GutTest

const PickerScene := preload("res://scenes/ui/world/AxisDeltaPicker.tscn")

func _instance() -> AxisDeltaPicker:
    var p: AxisDeltaPicker = PickerScene.instantiate()
    add_child_autofree(p)
    await get_tree().process_frame
    return p

func test_execute_disabled_initially():
    var p := await _instance()
    assert_true(p.get_node("%ExecuteButton").disabled)

func test_select_axis_only_keeps_execute_disabled():
    var p := await _instance()
    p.get_node("%CButton").emit_signal("pressed")
    assert_true(p.get_node("%ExecuteButton").disabled)

func test_select_axis_and_delta_enables_execute():
    var p := await _instance()
    p.get_node("%CButton").emit_signal("pressed")
    p.get_node("%DeltaPlus5Button").emit_signal("pressed")
    assert_false(p.get_node("%ExecuteButton").disabled)

func test_execute_emits_signal_with_params():
    var p := await _instance()
    p.get_node("%AButton").emit_signal("pressed")
    p.get_node("%DeltaMinus5Button").emit_signal("pressed")
    watch_signals(p)
    p.get_node("%ExecuteButton").emit_signal("pressed")
    assert_signal_emitted_with_parameters(p, "executed", ["A", -5.0])

func test_execute_resets_picker():
    var p := await _instance()
    p.get_node("%CButton").emit_signal("pressed")
    p.get_node("%DeltaPlus5Button").emit_signal("pressed")
    p.get_node("%ExecuteButton").emit_signal("pressed")
    assert_true(p.get_node("%ExecuteButton").disabled)

func test_reset_clears_selection():
    var p := await _instance()
    p.get_node("%CButton").emit_signal("pressed")
    p.get_node("%DeltaPlus5Button").emit_signal("pressed")
    p.reset()
    assert_true(p.get_node("%ExecuteButton").disabled)
```

- [ ] **Step 4: Run (6 nowych → 349/349)**

- [ ] **Step 5: Commit**

```bash
git add scenes/ui/world/AxisDeltaPicker.tscn scripts/ui/world/AxisDeltaPicker.gd tests/ui/test_axis_delta_picker.gd
git commit -m "feat(ui): AxisDeltaPicker — wybór osi + delty dla soborów

Spec 09 sek.7. HBoxContainer: 4 przyciski osi (A/B/C/D) + 4 delty
(−8, −5, +5, +8) + Wykonaj. Wartości delty w zakresie
COUNCIL_MIN_AXIS_DELTA..MAX (3..8). Execute disabled aż obie zaznaczone."
```

---

### Task 12: ActionPanel — najobszerniejszy

Wskaźniki relacji + 7 przycisków akcji per target + AxisDeltaPicker (warunkowo widoczny). Gating wg specu sek.7. Confirm dla Interdykt + Rewanż.

**Files:**
- Create: `scenes/ui/world/ActionPanel.tscn`
- Create: `scripts/ui/world/ActionPanel.gd`
- Create: `tests/ui/test_action_panel.gd`

- [ ] **Step 1: Write `scripts/ui/world/ActionPanel.gd`** (~150 linii, w jednym kawałku)

```gdscript
class_name ActionPanel
extends VBoxContainer

signal state_changed

const AxisDeltaPickerScene := preload("res://scenes/ui/world/AxisDeltaPicker.tscn")

var state: Node = null
var target_id: String = ""
var _pending_action: String = ""

@onready var _name_label: Label = %TargetNameLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _trust_label: Label = %TrustLabel
@onready var _econ_label: Label = %EconLabel
@onready var _tension_label: Label = %TensionLabel
@onready var _grievance_box: PanelContainer = %GrievanceBox
@onready var _grievance_label: Label = %GrievanceLabel
@onready var _coalition_box: PanelContainer = %CoalitionBox
@onready var _coalition_label: Label = %CoalitionLabel
@onready var _alliance_btn: Button = %AllianceButton
@onready var _interdict_btn: Button = %InterdictButton
@onready var _missionaries_btn: Button = %MissionariesButton
@onready var _ecu_council_btn: Button = %EcuCouncilButton
@onready var _vassal_patron_btn: Button = %VassalPatronButton
@onready var _vassal_client_btn: Button = %VassalClientButton
@onready var _vassal_council_btn: Button = %VassalCouncilButton
@onready var _rewanz_btn: Button = %RewanzButton
@onready var _picker_container: VBoxContainer = %PickerContainer
@onready var _picker_label: Label = %PickerLabel
@onready var _confirm_dialog: ConfirmationDialog = %ConfirmDialog

var _picker: AxisDeltaPicker = null

func _ready() -> void:
    _picker = AxisDeltaPickerScene.instantiate()
    _picker_container.add_child(_picker)
    _picker.executed.connect(_on_picker_executed)
    _picker_container.visible = false

    _alliance_btn.pressed.connect(_invoke_alliance)
    _interdict_btn.pressed.connect(_request_confirm.bind("interdykt"))
    _missionaries_btn.pressed.connect(_invoke_missionaries)
    _ecu_council_btn.pressed.connect(_show_picker.bind("sobor_ekum"))
    _vassal_patron_btn.pressed.connect(_invoke_vassal_patron)
    _vassal_client_btn.pressed.connect(_invoke_vassal_client)
    _vassal_council_btn.pressed.connect(_show_picker.bind("sobor_wasalski"))
    _rewanz_btn.pressed.connect(_request_confirm.bind("rewanz"))
    _confirm_dialog.confirmed.connect(_on_confirmed)
    _confirm_dialog.canceled.connect(_on_confirm_canceled)

func bind_state(s: Node) -> void:
    state = s

func set_target(id: String) -> void:
    target_id = id
    _picker_container.visible = false
    refresh()

func refresh() -> void:
    if state == null:
        _hide_all()
        return
    var target: Religion = state.get_religion(target_id)
    var player: Religion = state.get_player_religion()
    if target == null or player == null:
        _hide_all()
        return

    _name_label.text = "%s %s" % [target.icon, target.display_name]
    var rel := _get_rel()
    _trust_label.text = "Zaufanie %d" % int(rel.theological_trust)
    _econ_label.text = "Ekonomia %d" % int(rel.economic_cooperation)
    _tension_label.text = "Napięcie %d" % int(rel.military_tension)
    _subtitle_label.text = _build_subtitle(target, player)

    _refresh_grievance(player, target)
    _refresh_coalition(player)
    _refresh_buttons(player, target, rel)

func _build_subtitle(target: Religion, player: Religion) -> String:
    var parts: Array[String] = []
    if target.suzerain_id == player.id:
        parts.append("nasz klient")
    elif player.suzerain_id == target.id:
        parts.append("nasz patron")
    var rel := _get_rel()
    if rel.alliance_active:
        parts.append("sojusz")
    if _in_active_war(player.id, target.id):
        parts.append("wojna")
    if parts.is_empty():
        parts.append("pokój")
    return " · ".join(parts)

func _refresh_grievance(player: Religion, target: Religion) -> void:
    var active: bool = player.interdict_grievance_from_id == target.id and player.interdict_grievance_until > state.current_turn
    _grievance_box.visible = active
    if active:
        _grievance_label.text = "⚠ Grievance: Interdykt\n%s rzucił Interdykt. CB Rewanż dostępne do tury %d (%d tur)." % [
            target.display_name,
            player.interdict_grievance_until,
            player.interdict_grievance_until - state.current_turn,
        ]

func _refresh_coalition(player: Religion) -> void:
    var c: Coalition = null
    for coalition: Coalition in state.active_coalitions:
        if coalition.target_id == player.id:
            c = coalition
            break
    _coalition_box.visible = c != null
    if c != null:
        var member_names: Array[String] = []
        for m_id: String in c.members:
            var r: Religion = state.get_religion(m_id)
            if r != null:
                member_names.append(r.display_name)
        _coalition_label.text = "🔻 Koalicja przeciw nam\nCzłonkowie (%d): %s" % [c.members.size(), ", ".join(member_names)]

func _refresh_buttons(player: Religion, target: Religion, rel: RelationState) -> void:
    _alliance_btn.disabled = not _alliance_available(player, target, rel)
    _alliance_btn.tooltip_text = _alliance_tooltip(player, target, rel)
    _interdict_btn.disabled = not _interdict_available(player, target)
    _interdict_btn.tooltip_text = _interdict_tooltip(player, target)
    _missionaries_btn.disabled = not _missionaries_available(player, target, rel)
    _missionaries_btn.tooltip_text = _missionaries_tooltip(player, target, rel)
    _ecu_council_btn.disabled = not _ecu_council_available(player, target, rel)
    _ecu_council_btn.tooltip_text = _ecu_council_tooltip(player, target, rel)
    _vassal_patron_btn.visible = _can_show_vassal_patron(player, target)
    _vassal_patron_btn.disabled = not _vassal_patron_available(player, target, rel)
    _vassal_patron_btn.tooltip_text = _vassal_patron_tooltip(player, target, rel)
    _vassal_client_btn.visible = _can_show_vassal_client(player, target)
    _vassal_client_btn.disabled = not _vassal_client_available(player, target, rel)
    _vassal_client_btn.tooltip_text = _vassal_client_tooltip(player, target, rel)
    _vassal_council_btn.visible = target.suzerain_id == player.id
    _vassal_council_btn.disabled = not _vassal_council_available(player, rel)
    _vassal_council_btn.tooltip_text = _vassal_council_tooltip(player, rel)
    _rewanz_btn.visible = _rewanz_available(player, target)

# === Warunki dostępności (per spec 09 sek.7) ===
# UWAGA: progi używają >= (allow at boundary) żeby match z engine (declare_alliance
# blokuje gdy `trust < 50 AND economy < 60` — przy trust=50.0 engine pozwala).
func _alliance_available(player: Religion, target: Religion, rel: RelationState) -> bool:
    if player.prestige < DiplomacyManager.ALLIANCE_PRESTIGE_COST: return false
    if _in_active_war(player.id, target.id): return false
    if rel.theological_trust < DiplomacyManager.ALLIANCE_TRUST_THRESHOLD and rel.economic_cooperation < DiplomacyManager.ALLIANCE_ECONOMIC_THRESHOLD: return false
    if player.get_axis("C") < DiplomacyManager.ALLIANCE_EXCLUSIVITY_BLOCK and target.get_axis("C") > DiplomacyManager.ALLIANCE_PARTNER_SYNKRETYZM_BLOCK: return false
    return true

func _alliance_tooltip(player: Religion, target: Religion, rel: RelationState) -> String:
    if player.prestige < DiplomacyManager.ALLIANCE_PRESTIGE_COST:
        return "Brak prestiżu (potrzeba 20)"
    if _in_active_war(player.id, target.id):
        return "Niedostępne podczas wojny"
    if rel.theological_trust < DiplomacyManager.ALLIANCE_TRUST_THRESHOLD and rel.economic_cooperation < DiplomacyManager.ALLIANCE_ECONOMIC_THRESHOLD:
        return "Wymaga zaufania ≥50 lub ekonomii ≥60"
    if player.get_axis("C") < DiplomacyManager.ALLIANCE_EXCLUSIVITY_BLOCK and target.get_axis("C") > DiplomacyManager.ALLIANCE_PARTNER_SYNKRETYZM_BLOCK:
        return "Zablokowane przez Ekskluzywizm gracza vs Synkretyzm partnera"
    return "Sojusz (20⚑)"

func _interdict_available(player: Religion, target: Religion) -> bool:
    if player.prestige < DiplomacyManager.INTERDICT_PRESTIGE_COST: return false
    if target.interdict_immunity_until > state.current_turn: return false
    return true

func _interdict_tooltip(player: Religion, target: Religion) -> String:
    if player.prestige < DiplomacyManager.INTERDICT_PRESTIGE_COST:
        return "Brak prestiżu (potrzeba 15)"
    if target.interdict_immunity_until > state.current_turn:
        return "Target ma immunitet do tury %d" % target.interdict_immunity_until
    return "Interdykt (15⚑) — wymaga potwierdzenia"

func _missionaries_available(player: Religion, target: Religion, rel: RelationState) -> bool:
    if player.prestige < DiplomacyManager.MISSIONARIES_PRESTIGE_COST: return false
    if rel.theological_trust <= DiplomacyManager.MISSIONARIES_TRUST_THRESHOLD: return false
    if player.get_axis("C") < DiplomacyManager.MISSIONARIES_EXCLUSIVITY_BLOCK: return false
    return true

func _missionaries_tooltip(player: Religion, target: Religion, rel: RelationState) -> String:
    if player.prestige < DiplomacyManager.MISSIONARIES_PRESTIGE_COST:
        return "Brak prestiżu (potrzeba 10)"
    if rel.theological_trust <= DiplomacyManager.MISSIONARIES_TRUST_THRESHOLD:
        return "Wymaga zaufania >30"
    if player.get_axis("C") < DiplomacyManager.MISSIONARIES_EXCLUSIVITY_BLOCK:
        return "Twój Ekskluzywizm blokuje (Synkretyzm <20)"
    return "Misjonarze (10⚑)"

func _ecu_council_available(player: Religion, target: Religion, rel: RelationState) -> bool:
    # Engine ecumenical_council używa: trust ≤60 → block, tension >85 → block, C ≤40 → block.
    # UI match: trust > 60, tension ≤ 85, C > 40. Koszt: COUNCIL_PRESTIGE_COST modyfikowany
    # _axis_cost_modifier (B>60 → ×0.8). UI używa nominalnego kosztu (30) — drobne
    # przeszacowanie 6⚑ gdy gracz ma B>60, ale safe (UI stricter).
    if player.prestige < DiplomacyManager.COUNCIL_PRESTIGE_COST: return false
    if rel.theological_trust <= DiplomacyManager.COUNCIL_TRUST_THRESHOLD: return false
    if rel.military_tension > DiplomacyManager.BLOCK_TENSION_FOR_DIALOGUE: return false
    if player.get_axis("C") <= DiplomacyManager.COUNCIL_SYNKRETYZM_THRESHOLD: return false
    return true

func _ecu_council_tooltip(player: Religion, target: Religion, rel: RelationState) -> String:
    if player.prestige < DiplomacyManager.COUNCIL_PRESTIGE_COST:
        return "Brak prestiżu (potrzeba 30)"
    if rel.theological_trust <= DiplomacyManager.COUNCIL_TRUST_THRESHOLD:
        return "Wymaga zaufania >60"
    if rel.military_tension > DiplomacyManager.BLOCK_TENSION_FOR_DIALOGUE:
        return "Napięcie za wysokie (>85)"
    if player.get_axis("C") <= DiplomacyManager.COUNCIL_SYNKRETYZM_THRESHOLD:
        return "Twój Synkretyzm za niski (potrzeba >40)"
    return "Sobór ekumeniczny (30⚑)"

func _can_show_vassal_patron(player: Religion, target: Religion) -> bool:
    if player.suzerain_id != "": return false
    if target.suzerain_id == player.id: return false
    return true

func _vassal_patron_available(player: Religion, target: Religion, rel: RelationState) -> bool:
    if not _can_show_vassal_patron(player, target): return false
    if target.suzerain_id != "": return false
    if target.get_axis("A") >= DiplomacyManager.SUZERAINTY_DOGMATYZM_BLOCK: return false
    if rel.theological_trust <= DiplomacyManager.SUZERAINTY_TRUST_THRESHOLD: return false
    if _in_active_war(player.id, target.id): return false
    return true

func _vassal_patron_tooltip(player: Religion, target: Religion, rel: RelationState) -> String:
    if target.suzerain_id != "":
        return "NPC ma już patrona"
    if target.get_axis("A") >= DiplomacyManager.SUZERAINTY_DOGMATYZM_BLOCK:
        return "Dogmatyzm NPC za wysoki (≥80)"
    if rel.theological_trust <= DiplomacyManager.SUZERAINTY_TRUST_THRESHOLD:
        return "Wymaga zaufania >40"
    return "Zaproponuj wasalstwo"

func _can_show_vassal_client(player: Religion, target: Religion) -> bool:
    if player.suzerain_id != "": return false
    if target.suzerain_id == player.id: return false
    return player.prestige < target.prestige * 1.5  # heurystyka UI: gracz słabszy

func _vassal_client_available(player: Religion, target: Religion, rel: RelationState) -> bool:
    if not _can_show_vassal_client(player, target): return false
    if player.get_axis("A") >= DiplomacyManager.SUZERAINTY_DOGMATYZM_BLOCK: return false
    if rel.theological_trust <= DiplomacyManager.SUZERAINTY_TRUST_THRESHOLD: return false
    if _in_active_war(player.id, target.id): return false
    return true

func _vassal_client_tooltip(player: Religion, target: Religion, rel: RelationState) -> String:
    if player.get_axis("A") >= DiplomacyManager.SUZERAINTY_DOGMATYZM_BLOCK:
        return "Twój Dogmatyzm za wysoki (≥80)"
    if rel.theological_trust <= DiplomacyManager.SUZERAINTY_TRUST_THRESHOLD:
        return "Wymaga zaufania >40"
    return "Wejdź pod patronat"

func _vassal_council_available(player: Religion, rel: RelationState) -> bool:
    if player.get_axis("B") <= DiplomacyManager.VASSAL_COUNCIL_HIERARCHIA_THRESHOLD: return false
    if state.current_turn <= rel.vassal_council_cooldown_until: return false
    if player.prestige < DiplomacyManager.VASSAL_COUNCIL_PRESTIGE_COST: return false
    return true

func _vassal_council_tooltip(player: Religion, rel: RelationState) -> String:
    if player.get_axis("B") <= DiplomacyManager.VASSAL_COUNCIL_HIERARCHIA_THRESHOLD:
        return "Wymaga Hierarchii >75"
    if state.current_turn <= rel.vassal_council_cooldown_until:
        return "Cooldown do tury %d" % rel.vassal_council_cooldown_until
    if player.prestige < DiplomacyManager.VASSAL_COUNCIL_PRESTIGE_COST:
        return "Brak prestiżu (potrzeba 30)"
    return "Sobór wasalski (30⚑)"

func _rewanz_available(player: Religion, target: Religion) -> bool:
    var wm := WarManager.new()
    return "rewanz" in wm.available_casus_belli(player, target, state)

# === Akcje ===
func _invoke_alliance() -> void:
    var dm := DiplomacyManager.new()
    var _ok := dm.declare_alliance(state, state.player_religion_id, target_id)
    emit_signal("state_changed")
    refresh()

func _invoke_missionaries() -> void:
    var dm := DiplomacyManager.new()
    var _ok := dm.send_missionaries(state, state.player_religion_id, target_id)
    emit_signal("state_changed")
    refresh()

func _invoke_vassal_patron() -> void:
    var dm := DiplomacyManager.new()
    var _ok := dm.recognize_suzerainty(state, target_id, state.player_religion_id)
    emit_signal("state_changed")
    refresh()

func _invoke_vassal_client() -> void:
    var dm := DiplomacyManager.new()
    var _ok := dm.recognize_suzerainty(state, state.player_religion_id, target_id)
    emit_signal("state_changed")
    refresh()

func _show_picker(kind: String) -> void:
    _pending_action = kind
    _picker.reset()
    _picker_label.text = "Sobór ekumeniczny — wybór ustępstwa:" if kind == "sobor_ekum" else "Sobór wasalski — wybór ustępstwa:"
    _picker_container.visible = true

func _on_picker_executed(axis: String, delta: float) -> void:
    var dm := DiplomacyManager.new()
    if _pending_action == "sobor_ekum":
        var _ok := dm.ecumenical_council(state, state.player_religion_id, target_id, axis, delta)
    elif _pending_action == "sobor_wasalski":
        var _ok2 := dm.vassal_council(state, state.player_religion_id, target_id, axis, delta)
    _pending_action = ""
    _picker_container.visible = false
    emit_signal("state_changed")
    refresh()

func _request_confirm(kind: String) -> void:
    _pending_action = kind
    var target: Religion = state.get_religion(target_id)
    var name: String = target.display_name if target != null else target_id
    if kind == "interdykt":
        _confirm_dialog.dialog_text = "Rzucić Interdykt na %s? Kosztuje 15 prestiżu i podnosi napięcie." % name
    elif kind == "rewanz":
        _confirm_dialog.dialog_text = "Wypowiedzieć wojnę %s z CB Rewanż? Akcja jednorazowa." % name
    _confirm_dialog.popup_centered()

func _on_confirmed() -> void:
    var action: String = _pending_action
    _pending_action = ""  # clear pierwszy, żeby przypadkowy double-fire był no-op
    if action == "interdykt":
        var dm := DiplomacyManager.new()
        var _ok := dm.proclaim_interdict(state, state.player_religion_id, target_id)
    elif action == "rewanz":
        var wm := WarManager.new()
        var _war := wm.declare_war(state.player_religion_id, target_id, "rewanz", state)
    emit_signal("state_changed")
    refresh()

func _on_confirm_canceled() -> void:
    _pending_action = ""

# === Helpers ===
func _get_rel() -> RelationState:
    var dm := DiplomacyManager.new()
    return dm.get_or_create_relation(state, state.player_religion_id, target_id)

func _in_active_war(a: String, b: String) -> bool:
    for war: War in state.active_wars:
        if war.state == "ENDED":
            continue
        if (war.attacker_id == a and war.defender_id == b) or (war.attacker_id == b and war.defender_id == a):
            return true
    return false

func _hide_all() -> void:
    _name_label.text = ""
    _grievance_box.visible = false
    _coalition_box.visible = false
```

- [ ] **Step 2: Write `scenes/ui/world/ActionPanel.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/world/ActionPanel.gd" id="1"]

[node name="ActionPanel" type="VBoxContainer"]
script = ExtResource("1")
theme_override_constants/separation = 8

[node name="TargetNameLabel" type="Label" parent="."]
unique_name_in_owner = true
text = "?"

[node name="SubtitleLabel" type="Label" parent="."]
unique_name_in_owner = true
text = "?"

[node name="IndicatorsHBox" type="HBoxContainer" parent="."]
theme_override_constants/separation = 24

[node name="LeftCol" type="VBoxContainer" parent="IndicatorsHBox"]
size_flags_horizontal = 3

[node name="TrustLabel" type="Label" parent="IndicatorsHBox/LeftCol"]
unique_name_in_owner = true
text = "Zaufanie ?"

[node name="EconLabel" type="Label" parent="IndicatorsHBox/LeftCol"]
unique_name_in_owner = true
text = "Ekonomia ?"

[node name="TensionLabel" type="Label" parent="IndicatorsHBox/LeftCol"]
unique_name_in_owner = true
text = "Napięcie ?"

[node name="GrievanceBox" type="PanelContainer" parent="IndicatorsHBox/LeftCol"]
unique_name_in_owner = true
visible = false

[node name="GrievanceLabel" type="Label" parent="IndicatorsHBox/LeftCol/GrievanceBox"]
unique_name_in_owner = true
text = "Grievance"

[node name="CoalitionBox" type="PanelContainer" parent="IndicatorsHBox/LeftCol"]
unique_name_in_owner = true
visible = false

[node name="CoalitionLabel" type="Label" parent="IndicatorsHBox/LeftCol/CoalitionBox"]
unique_name_in_owner = true
text = "Koalicja"

[node name="RightCol" type="VBoxContainer" parent="IndicatorsHBox"]
size_flags_horizontal = 3

[node name="ActionsLabel" type="Label" parent="IndicatorsHBox/RightCol"]
text = "Dostępne akcje"

[node name="ActionsGrid" type="GridContainer" parent="IndicatorsHBox/RightCol"]
columns = 2
theme_override_constants/h_separation = 6
theme_override_constants/v_separation = 6

[node name="AllianceButton" type="Button" parent="IndicatorsHBox/RightCol/ActionsGrid"]
unique_name_in_owner = true
text = "🤝 Sojusz (20⚑)"

[node name="InterdictButton" type="Button" parent="IndicatorsHBox/RightCol/ActionsGrid"]
unique_name_in_owner = true
text = "⛔ Interdykt (15⚑)"

[node name="MissionariesButton" type="Button" parent="IndicatorsHBox/RightCol/ActionsGrid"]
unique_name_in_owner = true
text = "📜 Misjonarze (10⚑)"

[node name="EcuCouncilButton" type="Button" parent="IndicatorsHBox/RightCol/ActionsGrid"]
unique_name_in_owner = true
text = "⚖ Sobór ekum. (30⚑)"

[node name="VassalPatronButton" type="Button" parent="IndicatorsHBox/RightCol/ActionsGrid"]
unique_name_in_owner = true
text = "👑 Wasal: patron"

[node name="VassalClientButton" type="Button" parent="IndicatorsHBox/RightCol/ActionsGrid"]
unique_name_in_owner = true
text = "⛰ Wasal: klient"

[node name="VassalCouncilButton" type="Button" parent="IndicatorsHBox/RightCol/ActionsGrid"]
unique_name_in_owner = true
text = "⚖↓ Sobór wasalski (30⚑)"

[node name="RewanzButton" type="Button" parent="IndicatorsHBox/RightCol/ActionsGrid"]
unique_name_in_owner = true
text = "⚔ Rewanż"

[node name="PickerContainer" type="VBoxContainer" parent="."]
unique_name_in_owner = true
visible = false

[node name="PickerLabel" type="Label" parent="PickerContainer"]
unique_name_in_owner = true
text = "Sobór — wybór:"

[node name="ConfirmDialog" type="ConfirmationDialog" parent="."]
unique_name_in_owner = true
dialog_text = "?"
title = "Potwierdź"
; ConfirmationDialog dziedziczy z Window — popup_centered() decouples z layoutu,
; ale jako child VBoxContainera Godot ostrzega o "container child not auto-resized".
; Ostrzeżenie jest benignne (Window nie używa container size), zostawiamy parent="."
; (VBox root) bo top_level=true na child Window jest niezalecany w 4.6.
```

- [ ] **Step 3: Write `tests/ui/test_action_panel.gd`** (~140 linii)

```gdscript
extends GutTest

const ActionPanelScene := preload("res://scenes/ui/world/ActionPanel.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")
const CoalitionScript := preload("res://scripts/engine/Coalition.gd")

func _make_state() -> Node:
    var gs: Node = GameStateScript.new()
    var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
    var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
    gs.initialize("islam", religions, graph)
    return gs

func _instance(state: Node, target_id: String) -> ActionPanel:
    var p: ActionPanel = ActionPanelScene.instantiate()
    add_child_autofree(p)
    await get_tree().process_frame
    p.bind_state(state)
    p.set_target(target_id)
    return p

func test_renders_target_name():
    var state := _make_state()
    add_child_autofree(state)
    var p := await _instance(state, "chr_zachodnie")
    var text: String = p.get_node("%TargetNameLabel").text
    assert_string_contains(text, "Chrześcijaństwo Zachodnie")

func test_alliance_disabled_when_low_prestige():
    var state := _make_state()
    add_child_autofree(state)
    state.get_player_religion().prestige = 0
    var p := await _instance(state, "chr_zachodnie")
    assert_true(p.get_node("%AllianceButton").disabled)
    assert_string_contains(p.get_node("%AllianceButton").tooltip_text, "Brak prestiżu")

func test_alliance_enabled_when_conditions_met():
    var state := _make_state()
    add_child_autofree(state)
    state.get_player_religion().prestige = 100
    var dm := DiplomacyManager.new()
    var rel := dm.get_or_create_relation(state, "islam", "chr_zachodnie")
    rel.theological_trust = 70.0
    var p := await _instance(state, "chr_zachodnie")
    assert_false(p.get_node("%AllianceButton").disabled)

func test_alliance_click_invokes_manager():
    var state := _make_state()
    add_child_autofree(state)
    state.get_player_religion().prestige = 100
    var dm := DiplomacyManager.new()
    var rel := dm.get_or_create_relation(state, "islam", "chr_zachodnie")
    rel.theological_trust = 70.0
    var p := await _instance(state, "chr_zachodnie")
    watch_signals(p)
    p.get_node("%AllianceButton").emit_signal("pressed")
    assert_signal_emitted(p, "state_changed")
    var rel_after := dm.get_or_create_relation(state, "islam", "chr_zachodnie")
    assert_true(rel_after.alliance_active)

func test_interdict_disabled_when_low_prestige():
    var state := _make_state()
    add_child_autofree(state)
    state.get_player_religion().prestige = 0
    var p := await _instance(state, "chr_zachodnie")
    assert_true(p.get_node("%InterdictButton").disabled)

func test_interdict_opens_confirm_dialog():
    var state := _make_state()
    add_child_autofree(state)
    state.get_player_religion().prestige = 100
    var p := await _instance(state, "chr_zachodnie")
    p.get_node("%InterdictButton").emit_signal("pressed")
    assert_true(p.get_node("%ConfirmDialog").visible)

func test_interdict_confirmed_invokes_manager():
    var state := _make_state()
    add_child_autofree(state)
    state.get_player_religion().prestige = 100
    var p := await _instance(state, "chr_zachodnie")
    p.get_node("%InterdictButton").emit_signal("pressed")
    p.get_node("%ConfirmDialog").emit_signal("confirmed")
    var target := state.get_religion("chr_zachodnie")
    assert_true(target.interdict_immunity_until > state.current_turn)

func test_missionaries_disabled_when_low_trust():
    var state := _make_state()
    add_child_autofree(state)
    state.get_player_religion().prestige = 100
    var p := await _instance(state, "chr_zachodnie")
    assert_true(p.get_node("%MissionariesButton").disabled)

func test_ecu_council_shows_picker_on_click():
    var state := _make_state()
    add_child_autofree(state)
    state.get_player_religion().prestige = 100
    state.get_player_religion().axes["C"] = 60.0
    var dm := DiplomacyManager.new()
    var rel := dm.get_or_create_relation(state, "islam", "chr_zachodnie")
    rel.theological_trust = 70.0
    var p := await _instance(state, "chr_zachodnie")
    p.get_node("%EcuCouncilButton").emit_signal("pressed")
    assert_true(p.get_node("%PickerContainer").visible)

func test_vassal_patron_visible_when_player_unsuzerained():
    var state := _make_state()
    add_child_autofree(state)
    var p := await _instance(state, "chr_zachodnie")
    assert_true(p.get_node("%VassalPatronButton").visible)

func test_vassal_patron_hidden_when_player_is_client():
    var state := _make_state()
    add_child_autofree(state)
    state.get_player_religion().suzerain_id = "chr_wschodnie"
    var p := await _instance(state, "chr_zachodnie")
    assert_false(p.get_node("%VassalPatronButton").visible)

func test_vassal_council_visible_only_for_clients():
    var state := _make_state()
    add_child_autofree(state)
    state.get_religion("koptyjski").suzerain_id = "islam"
    var p := await _instance(state, "koptyjski")
    assert_true(p.get_node("%VassalCouncilButton").visible)
    p.set_target("chr_zachodnie")
    assert_false(p.get_node("%VassalCouncilButton").visible)

func test_rewanz_hidden_when_no_cb():
    var state := _make_state()
    add_child_autofree(state)
    var p := await _instance(state, "chr_zachodnie")
    assert_false(p.get_node("%RewanzButton").visible)

func test_rewanz_visible_when_grievance_active():
    var state := _make_state()
    add_child_autofree(state)
    var player := state.get_player_religion()
    player.interdict_grievance_from_id = "chr_zachodnie"
    player.interdict_grievance_until = state.current_turn + 5
    player.axes["C"] = 20.0
    var p := await _instance(state, "chr_zachodnie")
    assert_true(p.get_node("%RewanzButton").visible)

func test_grievance_box_visible_when_active():
    var state := _make_state()
    add_child_autofree(state)
    var player := state.get_player_religion()
    player.interdict_grievance_from_id = "chr_zachodnie"
    player.interdict_grievance_until = state.current_turn + 5
    var p := await _instance(state, "chr_zachodnie")
    assert_true(p.get_node("%GrievanceBox").visible)

func test_coalition_box_visible_when_targeted():
    var state := _make_state()
    add_child_autofree(state)
    var c: Coalition = CoalitionScript.new()
    c.target_id = "islam"
    c.members = ["chr_zachodnie", "chr_wschodnie"]
    state.active_coalitions.append(c)
    var p := await _instance(state, "chr_zachodnie")
    assert_true(p.get_node("%CoalitionBox").visible)

func test_picker_execute_invokes_ecu_council():
    var state := _make_state()
    add_child_autofree(state)
    var player := state.get_player_religion()
    player.prestige = 100
    player.axes["C"] = 60.0
    player.axes["B"] = 50.0  # B≤60 → _axis_cost_modifier=1.0, cost == COUNCIL_PRESTIGE_COST nominalnie
    var dm := DiplomacyManager.new()
    var rel := dm.get_or_create_relation(state, "islam", "chr_zachodnie")
    rel.theological_trust = 70.0
    var p := await _instance(state, "chr_zachodnie")
    p.get_node("%EcuCouncilButton").emit_signal("pressed")
    p._picker.get_node("%CButton").emit_signal("pressed")
    p._picker.get_node("%DeltaPlus5Button").emit_signal("pressed")
    p._picker.get_node("%ExecuteButton").emit_signal("pressed")
    assert_eq(player.prestige, 70)  # 100 - 30 (cost nominalny przy B≤60)
```

- [ ] **Step 4: Run, expect 17 pass (366/366)**

- [ ] **Step 5: Commit**

```bash
git add scenes/ui/world/ActionPanel.tscn scripts/ui/world/ActionPanel.gd tests/ui/test_action_panel.gd
git commit -m "feat(ui): ActionPanel — wskaźniki + 8 akcji per target

Spec 09 sek.7. Wskaźniki Z/E/N + grievance + koalicja. 8 przycisków akcji
(Sojusz/Interdykt/Misjonarze/Sobór ekum./Wasal patron/Wasal klient/Sobór
wasalski/Rewanż) z gatingiem per warunki spec sek.7. Confirm dialog dla
Interdyktu i Rewanża. AxisDeltaPicker pokazuje się przy Sobór ekum/wasal."
```

---

### Task 13: WorldTab — kompozycja

Złóż RelationList + ConflictSection + ActionPanel w jedną zakładkę. Wymień stub Świat z Task 5 na WorldTab.

**Files:**
- Create: `scenes/ui/world/WorldTab.tscn`
- Create: `scripts/ui/world/WorldTab.gd`
- Modify: `scenes/ui/MainShell.tscn` (wymień stub SwiatTab na instance WorldTab.tscn)
- Create: `tests/ui/test_world_tab.gd`

- [ ] **Step 1: Write `scripts/ui/world/WorldTab.gd`**

```gdscript
class_name WorldTab
extends Control

signal state_changed

var state: Node = null

@onready var _conflict: ConflictSection = %ConflictSection
@onready var _list: RelationList = %RelationList
@onready var _action_panel: ActionPanel = %ActionPanel

func _ready() -> void:
    _list.religion_selected.connect(_on_religion_selected)
    _action_panel.state_changed.connect(_on_state_changed)
    _conflict.state_changed.connect(_on_state_changed)

func bind_state(s: Node) -> void:
    state = s
    _conflict.bind_state(s)
    _list.bind_state(s)
    _action_panel.bind_state(s)
    _auto_select_first()

func refresh() -> void:
    if state == null:
        return
    _conflict.refresh()
    _list.refresh()
    if _action_panel.target_id == "" or state.get_religion(_action_panel.target_id) == null:
        _auto_select_first()
    else:
        _action_panel.refresh()

func _auto_select_first() -> void:
    var player_id: String = state.player_religion_id
    for r: Religion in state.all_religions():
        if r.id != player_id:
            _on_religion_selected(r.id)
            return

func _on_religion_selected(id: String) -> void:
    _list.set_selected(id)
    _action_panel.set_target(id)

func _on_state_changed() -> void:
    refresh()
    emit_signal("state_changed")
```

- [ ] **Step 2: Write `scenes/ui/world/WorldTab.tscn`**

```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/ui/world/WorldTab.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/ui/world/ConflictSection.tscn" id="2"]
[ext_resource type="PackedScene" path="res://scenes/ui/world/RelationList.tscn" id="3"]
[ext_resource type="PackedScene" path="res://scenes/ui/world/ActionPanel.tscn" id="4"]

[node name="WorldTab" type="Control"]
script = ExtResource("1")
anchor_right = 1.0
anchor_bottom = 1.0

[node name="VBox" type="VBoxContainer" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0

[node name="ConflictSection" parent="VBox" instance=ExtResource("2")]
unique_name_in_owner = true

[node name="MasterDetail" type="HSplitContainer" parent="VBox"]
size_flags_vertical = 3

[node name="RelationList" parent="VBox/MasterDetail" instance=ExtResource("3")]
unique_name_in_owner = true

[node name="ActionPanel" parent="VBox/MasterDetail" instance=ExtResource("4")]
unique_name_in_owner = true
```

- [ ] **Step 3: Modify `scenes/ui/MainShell.tscn`**

Wymień stub `SwiatTab` (Control + Label) na instance `WorldTab.tscn`. Zaktualizuj `load_steps` o 1 i dodaj `[ext_resource]` dla WorldTab.

Sekcja w obecnym `MainShell.tscn` do zastąpienia:
```
[node name="SwiatTab" type="Control" parent="VBox/ContentArea"]
unique_name_in_owner = true
anchor_right = 1.0
anchor_bottom = 1.0

[node name="SwiatStubLabel" type="Label" parent="VBox/ContentArea/SwiatTab"]
text = "Świat (stub — wymieniony w Task 12)"
```

Zamień na:
```
[node name="SwiatTab" parent="VBox/ContentArea" instance=ExtResource("5")]
unique_name_in_owner = true
```

i dodaj na górze `[ext_resource type="PackedScene" path="res://scenes/ui/world/WorldTab.tscn" id="5"]`.

Aktualizuj też `MainShell.gd:_swiat_tab` type adnotację jeśli była `Control` → `WorldTab` (lub zostaw `Control` dla luźnego sprzężenia; przy refresh() używamy `has_method` więc OK).

- [ ] **Step 4: Write `tests/ui/test_world_tab.gd`**

```gdscript
extends GutTest

const WorldTabScene := preload("res://scenes/ui/world/WorldTab.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
    var gs: Node = GameStateScript.new()
    var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
    var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
    gs.initialize("islam", religions, graph)
    return gs

func _instance(state: Node) -> WorldTab:
    var t: WorldTab = WorldTabScene.instantiate()
    add_child_autofree(t)
    await get_tree().process_frame
    t.bind_state(state)
    return t

func test_auto_selects_first_npc_religion():
    var state := _make_state()
    add_child_autofree(state)
    var t := await _instance(state)
    assert_ne(t.get_node("%ActionPanel").target_id, "")
    assert_ne(t.get_node("%ActionPanel").target_id, "islam")

func test_list_selection_updates_action_panel():
    var state := _make_state()
    add_child_autofree(state)
    var t := await _instance(state)
    t._on_religion_selected("chr_zachodnie")
    assert_eq(t.get_node("%ActionPanel").target_id, "chr_zachodnie")

func test_action_state_change_emits_state_changed_up():
    var state := _make_state()
    add_child_autofree(state)
    state.get_player_religion().prestige = 100
    var dm := DiplomacyManager.new()
    var rel := dm.get_or_create_relation(state, "islam", "chr_zachodnie")
    rel.theological_trust = 70.0
    var t := await _instance(state)
    t._on_religion_selected("chr_zachodnie")
    watch_signals(t)
    t.get_node("%ActionPanel").get_node("%AllianceButton").emit_signal("pressed")
    assert_signal_emitted(t, "state_changed")
```

- [ ] **Step 5: Run, expect 3 pass + 0 regresji (369/369)**

- [ ] **Step 6: Commit**

```bash
git add scenes/ui/world/WorldTab.tscn scripts/ui/world/WorldTab.gd scenes/ui/MainShell.tscn tests/ui/test_world_tab.gd
git commit -m "feat(ui): WorldTab — kompozycja ConflictSection+RelationList+ActionPanel

Spec 09 sek.6. HSplitContainer master-detail: lista lewa, panel akcji
prawa, ConflictSection na górze. Auto-select pierwszej NPC religii.
Emit state_changed po akcji w panelu. Wymienia stub SwiatTab w MainShell."
```

---

### Task 14: Integration test — pełna pętla

End-to-end test: setup MainShell, klik wiersza, klik akcji, weryfikacja state + header refresh + tab marker.

**Files:**
- Create: `tests/ui/test_world_tab_integration.gd`

- [ ] **Step 1: Write `tests/ui/test_world_tab_integration.gd`**

```gdscript
extends GutTest

const MainShellScene := preload("res://scenes/ui/MainShell.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")
const WarScript := preload("res://scripts/engine/War.gd")

func _make_state() -> Node:
    var gs: Node = GameStateScript.new()
    var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
    var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
    gs.initialize("islam", religions, graph)
    return gs

func _shell(state: Node) -> MainShell:
    var s: MainShell = MainShellScene.instantiate()
    add_child_autofree(s)
    await get_tree().process_frame
    s.bind_state(state)
    return s

func test_full_loop_alliance():
    var state := _make_state()
    add_child_autofree(state)
    state.get_player_religion().prestige = 100
    var dm := DiplomacyManager.new()
    var rel := dm.get_or_create_relation(state, "islam", "chr_zachodnie")
    rel.theological_trust = 70.0

    var shell := await _shell(state)
    var world: WorldTab = shell.get_node("%SwiatTab")
    world._on_religion_selected("chr_zachodnie")

    var panel: ActionPanel = world.get_node("%ActionPanel")
    panel.get_node("%AllianceButton").emit_signal("pressed")

    # Sojusz aktywny
    var rel_after := dm.get_or_create_relation(state, "islam", "chr_zachodnie")
    assert_true(rel_after.alliance_active)
    # Prestiż spadł
    assert_eq(state.get_player_religion().prestige, 80)
    # Header zaktualizowany
    assert_eq(shell.get_node("%Header").get_node("%PrestigeLabel").text, "⚑ 80")
    # Marker w liście (po refreshu)
    var list: RelationList = world.get_node("%RelationList")
    assert_eq(list._items["chr_zachodnie"].marker, "🤝")

func test_full_loop_rewanz():
    var state := _make_state()
    add_child_autofree(state)
    var player := state.get_player_religion()
    player.interdict_grievance_from_id = "chr_zachodnie"
    player.interdict_grievance_until = state.current_turn + 5
    player.axes["C"] = 20.0

    var shell := await _shell(state)
    var world: WorldTab = shell.get_node("%SwiatTab")
    world._on_religion_selected("chr_zachodnie")

    var panel: ActionPanel = world.get_node("%ActionPanel")
    var rewanz_btn: Button = panel.get_node("%RewanzButton")
    assert_true(rewanz_btn.visible)

    rewanz_btn.emit_signal("pressed")
    panel.get_node("%ConfirmDialog").emit_signal("confirmed")

    # Wojna utworzona
    var has_war: bool = false
    for war: War in state.active_wars:
        if war.attacker_id == "islam" and war.defender_id == "chr_zachodnie" and war.casus_belli == "rewanz":
            has_war = true
    assert_true(has_war)
    # Grievance wyzerowany
    assert_eq(player.interdict_grievance_from_id, "")
    # Marker w liście zmienił się na ⚔
    var list: RelationList = world.get_node("%RelationList")
    assert_eq(list._items["chr_zachodnie"].marker, "⚔")

func test_full_loop_peace_council_ends_war():
    var state := _make_state()
    add_child_autofree(state)
    var player := state.get_player_religion()
    player.prestige = 100
    player.war_weariness = 60.0
    var war: War = WarScript.new()
    war.attacker_id = "islam"
    war.defender_id = "zoroastryzm"
    war.state = "BATTLING"
    war.casus_belli = "stlumienie_herezji"
    state.active_wars.append(war)

    var shell := await _shell(state)
    var world: WorldTab = shell.get_node("%SwiatTab")
    var conflict: ConflictSection = world.get_node("%ConflictSection")
    assert_true(conflict.visible)

    var row: HBoxContainer = conflict.get_node("%ListVBox").get_child(0)
    var peace_btn: Button = row.get_child(1)
    peace_btn.emit_signal("pressed")

    # Weariness zmalał per spec 04 sek.4
    assert_lt(state.get_player_religion().war_weariness, 60.0)

func test_full_loop_end_turn_advances():
    var state := _make_state()
    add_child_autofree(state)
    var initial_turn: int = state.current_turn

    var shell := await _shell(state)
    shell.get_node("%Header").get_node("%EndTurnButton").emit_signal("pressed")

    assert_eq(state.current_turn, initial_turn + 1)
    assert_string_contains(shell.get_node("%Header").get_node("%TurnLabel").text, str(state.current_turn))
```

- [ ] **Step 2: Run, expect 4 pass (373/373)**

- [ ] **Step 3: Commit**

```bash
git add tests/ui/test_world_tab_integration.gd
git commit -m "test(ui): integration — pełna pętla Sojusz/Rewanż/Pokój/End Turn

Spec 09 sek.9. End-to-end via MainShell: klik wiersza → klik akcji →
state mutacja w engine → header/list refresh. Pokryte ścieżki:
declare_alliance (sojusz + marker), declare_war(rewanz) (Plan 07 grievance
loop), peace_council, End Turn (process_turn)."
```

---

## Chunk 3: Smoke run + final

### Task 15: Final smoke — uruchom grę headless, weryfikuj stabilność

Końcowy sanity check: pełen test suite + headless run godota.

- [ ] **Step 1: Pełny test suite**

```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
Expected: **373/373 PASS** (lub minimum 295 baseline + ~50 nowych UI testów).

- [ ] **Step 2: Smoke run godota — czy projekt się ładuje**

```bash
godot --headless --path . --quit-after 3 2>&1 | grep -E "(ERROR|WARNING|SCRIPT ERROR)" | head -20
```
Expected: brak `SCRIPT ERROR`. Ostrzeżenia o brakujących zasobach typu fonts/themes są dopuszczalne (out-of-scope dla PoC).

- [ ] **Step 3: Manual eye-check (opcjonalny — wymaga GUI Godota)**

Jeśli środowisko ma display: uruchom `godot --path .`, sprawdź czy:
- StartMenu pokazuje 12 kart
- Klik karty + Start → przechodzi do MainShell
- Świat tab pokazuje listę religii, można kliknąć dowolną
- Akcje są disabled/enabled zgodnie z gatingiem
- End Turn przekręca licznik

Jeśli środowisko jest headless: pomiń ten krok.

- [ ] **Step 4: Final commit (jeśli były jakiekolwiek fix-upy w Step 2/3)**

Jeśli wszystko zielone — brak commitu. Plan zakończony.

---

## Podsumowanie

Po wszystkich taskach:
- ~16 plików scen (`.tscn`)
- ~14 plików skryptów (`.gd`)
- ~14 plików testów (`tests/ui/test_*.gd`)
- ~78 nowych testów UI (rough estimate)
- Total ~373 PASS (z 295 baseline)
- 1 commit per task → ~15 commitów

**Plan dotyka tylko `scripts/ui/`, `scenes/ui/`, `tests/ui/`, plus rename w Task 0 i jedno modyfikowanie `scenes/Main.tscn` i `scenes/ui/MainShell.tscn`. Engine (`scripts/engine/`) pozostaje nietknięty — to zaproszenie aby Plan 09 (UI Mapa) mógł zacząć równolegle bez konfliktów.**

Po zakończeniu: `superpowers:finishing-a-development-branch` aby zaoferować merge/PR/keep options.
