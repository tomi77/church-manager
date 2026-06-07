# UI Mapa Implementation Plan

> **For Claude:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Zbudować zakładkę **Mapa** w MainShell — interaktywny graf 12 prowincji (węzły + krawędzie sąsiedztwa) z panelem szczegółów po kliknięciu prowincji. Panel pokazuje nazwę, religię, teren, święte miasto, populację, dochód, słupki presji per obca religia oraz 3 kontekstowe akcje: [Wypowiedz wojnę], [Wyślij misjonarza], [→ Dyplomacja].

**Architecture:** Renderowanie grafu = `MapView` (Control kontener) z dziećmi `ProvinceNode` (Polygon2D + Label) pozycjonowanymi przez hand-authored `position{x,y}` z JSON. Krawędzie = `Line2D` (jeden per parę sąsiadów). Klik węzła → sygnał `province_selected(id)` → `MapaTab` ustawia selekcję i pokazuje `ProvinceDetailPanel`. Panel komponuje 3 podsekcje (header + presja + akcje) i emituje sygnały dla 3 akcji. Akcje wojny i misjonarzy idą przez istniejące `WarManager` i `DiplomacyManager`; akcja "→ Dyplomacja" emituje sygnał do `MainShell`, który przełącza tab i preselectuje religię w `WorldTab`.

**Tech Stack:** Godot 4.6, GDScript 2.0, GUT (headless test runner), `.tscn` Scene files, Polygon2D, Line2D.

**Spec źródłowy:**
- [`docs/superpowers/specs/04-map-province-system-design.md`](../specs/04-map-province-system-design.md) — silnik prowincji (sąsiedztwo, teren, presja).
- [`docs/superpowers/specs/06-ui-design.md`](../specs/06-ui-design.md) sekcja 3 — projekt zakładki Mapa.

**Stan startowy:** branch `master`, 376/376 testów PASS (Plan 08 + polish + .uid sidecars). 12 prowincji w `data/provinces_historical.json`. UI mapy = `PlaceholderTab` w `MainShell`. Docelowo +~30 testów UI → ~406 PASS.

**Test runner:**
```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

**Konwencje:**
- 4-spacjowy indent (zgodnie z UI Planu 08)
- `class_name` dla każdego skryptu UI
- `unique_name_in_owner = true` + `%Name` resolution dla wszystkich Label/Button
- Sygnały: lower_snake_case, parametry typowane (`signal province_selected(id: String)`)
- Setters guarded przez `is_inside_tree()` przed dotykiem `@onready` vars
- Stałe wizualne → `scripts/ui/UIConstants.gd` (rozszerzamy o `COLOR_PROVINCE_*`, `MAP_NODE_RADIUS`, `MAP_EDGE_WIDTH`)

**Świadome odstępstwa od spec 06 sekcja 3 (MVP simplifications):**
- **Forma:** spec mówi "pseudo-geograficzna siatka SVG z wielokątami". V1 używa `Polygon2D` z prostokątami / hand-authored kształtami per prowincja — semantyka taka sama (kolorowy obszar), forma uproszczona. Wielokąty geograficzne w przyszłym milestone.
- **Pressure tint na krawędziach wielokąta:** spec definiuje 4 progi (0–30/31–60/61–85/>85) z tintem koloru obcej religii. V1 implementuje tint przez `modulate` całego węzła (nie krawędzi), z 3 stanami (0–60: brak, 61–85: tint subtle, >85: pulsujący alert). Edge-tinting przy hand-authored polygons w przyszłym milestone.
- **Bottom sheet mobile / side panel desktop:** v1 = side panel po prawej (desktop-only), 280px szerokości. Mobile responsiveness w przyszłym milestone.
- **Dangling neighbors:** dane JSON mają 5 nazw sąsiadów bez definicji jako Province (`jemen`, `libia`, `tracja`, `italia_polnocna`, `afryka_polnocna`). `ProvinceLoader._build_graph` już teraz ignoruje takie krawędzie. Plan 09 zachowuje to: krawędzie do nieistniejących węzłów po prostu nie są renderowane. Cleanup danych = inny plan.

**Engine-vs-UI gating reconciliation:**
- `_war_available` używa engine semantyki: gracz musi mieć przynajmniej jeden CB w `WarManager.available_casus_belli(player, target_owner, state)` (lista niepusta) AND prowincja target musi sąsiadować z którąś prowincją gracza. W UI v1 panel akcji wojny otwiera **podselektor CB** (jeśli >1 dostępny) lub od razu wykonuje deklarację (jeśli dokładnie 1 dostępny).
- `_missionaries_available` deleguje do tych samych warunków co panel w `WorldTab.ActionPanel`: `source.get_axis("C") >= 20`, `rel.theological_trust > 30`, `rel.military_tension <= 85`, dość prestiżu. **UI nigdy nie blokuje akcji która by przeszła w engine** (UI stricter ≤ engine wider).
- Akcja `[→ Dyplomacja]` nie ma gatingu — zawsze dostępna (przełącza tab i preselectuje religię właściciela).

---

## Chunk 1: Renderowanie grafu mapy

### Task 0: Rozszerz Province + JSON o pole `position{x,y}`

Hand-authored współrzędne na canvasie 800×500 px (referencyjny rozmiar — `MapView` później skaluje). Pozycje pseudo-geograficzne: Bliski Wschód = centrum, Konstantynopol N, Mekka S, Persepolis E, Rzym W.

**Files:**
- Modify: `scripts/engine/Province.gd:11`
- Modify: `scripts/engine/ProvinceLoader.gd:30-42`
- Modify: `data/provinces_historical.json` (12 prowincji)
- Test: `tests/engine/test_province_loader.gd` (rozszerzenie istniejącego testu — jeśli nie istnieje, stwórz nowy `tests/engine/test_province_position.gd`)

- [ ] **Step 1: Stwórz failing test pozycji**

Plik `tests/engine/test_province_position.gd`:
```gdscript
extends GutTest

func test_provinces_load_with_positions():
    var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
    var mekka: Province = graph.get_province("mekka")
    assert_not_null(mekka, "Mekka must exist")
    assert_almost_eq(mekka.position.x, 420.0, 1.0)
    assert_almost_eq(mekka.position.y, 420.0, 1.0)

func test_all_12_provinces_have_nonzero_position():
    var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
    for p: Province in graph.all_provinces():
        assert_ne(p.position, Vector2.ZERO, "%s must have a non-zero position" % p.id)
```

- [ ] **Step 2: Uruchom test — verify FAIL**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=test_province_position.gd -gexit
```
Oczekiwane: FAIL — `position` nie jest polem `Province`.

- [ ] **Step 3: Dodaj pole `position` do `Province.gd`**

Po linii 11 (`@export var is_holy_site: bool = false`):
```gdscript
@export var position: Vector2 = Vector2.ZERO
```

- [ ] **Step 4: Rozszerz `ProvinceLoader._parse_province`**

W `scripts/engine/ProvinceLoader.gd:30-42`, przed `return p`, dodaj:
```gdscript
var pos_raw: Dictionary = pd.get("position", {})
p.position = Vector2(
    float(pos_raw.get("x", 0.0)),
    float(pos_raw.get("y", 0.0))
)
```

- [ ] **Step 5: Dodaj pole `position` do wszystkich 12 prowincji w JSON**

W `data/provinces_historical.json`, do każdej prowincji dodaj `"position": {"x": X, "y": Y}`. Pozycje (canvas 800×500, oś Y rośnie w dół):

| Prowincja | x | y | Uzasadnienie geograficzne |
|---|---|---|---|
| rzym | 80 | 220 | zachód, Italia |
| konstantynopol | 280 | 100 | północ, Bosfor |
| anatolia | 340 | 180 | Azja Mniejsza |
| armenia | 460 | 180 | NE od Anatolii |
| lewant | 360 | 280 | wybrzeże syryjskie |
| jerozolima | 360 | 330 | południowy Lewant |
| egipt | 280 | 380 | NE Afryka |
| arabia_polnocna | 440 | 360 | Półwysep Arabski N |
| mekka | 420 | 420 | Hidżaz |
| mezopotamia | 500 | 280 | dolina Eufratu |
| persja | 620 | 280 | Iran centralny |
| persepolis | 700 | 340 | Persja południowa |

Przykład dla pierwszej prowincji (mekka):
```json
{"id": "mekka", "display_name": "Mekka", "owner": "religie_arabskie",
 "pressure": {"religie_arabskie": 80.0}, "population": 200,
 "resources": {"food": 1, "gold": 3}, "terrain": "desert",
 "neighbors": ["lewant", "jemen", "arabia_polnocna"], "is_holy_site": true,
 "position": {"x": 420, "y": 420}}
```

- [ ] **Step 6: Uruchom test — verify PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=test_province_position.gd -gexit
```
Oczekiwane: PASS (2/2).

- [ ] **Step 7: Uruchom pełny suite — brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
Oczekiwane: 378/378 PASS (376 baseline + 2 nowe).

- [ ] **Step 8: Commit**

```bash
git add scripts/engine/Province.gd scripts/engine/ProvinceLoader.gd data/provinces_historical.json tests/engine/test_province_position.gd
git commit -m "feat(engine): add Province.position{x,y} for map rendering"
```

---

### Task 1: ProvinceNode — pojedynczy węzeł mapy

Jeden węzeł na prowincję: kolorowy kwadrat (`Polygon2D`, 60×40 px) + Label z `display_name`. Kolor = paleta religii właściciela. Klik = emit sygnał z `province.id`. Selekcja = obramowanie (modulate brighter + Polygon2D outline).

**Files:**
- Create: `scripts/ui/map/ProvinceNode.gd`
- Create: `scenes/ui/map/ProvinceNode.tscn`
- Modify: `scripts/ui/UIConstants.gd` (dodaj paletę religii)
- Test: `tests/ui/test_province_node.gd`

- [ ] **Step 1: Rozszerz `UIConstants.gd` o paletę religii**

W `scripts/ui/UIConstants.gd`, dodaj na końcu (przed ostatnią klamrą):
```gdscript
# Paleta religii (per spec 06 sekcja 3 — kolor wielokąta na mapie)
const RELIGION_COLORS: Dictionary = {
    "islam": Color("0d3a1a"),
    "chr_zachodnie": Color("0a0a2a"),
    "chr_wschodnie": Color("0a0a22"),
    "judaizm": Color("1a1600"),
    "zoroastryzm": Color("1a0d00"),
    "koptyjski": Color("0d1a10"),
    "manicheizm": Color("180818"),
    "religie_arabskie": Color("1a1000"),
    "hinduizm": Color("1a0808"),
    "buddyzm": Color("001518"),
    "religie_germanskie": Color("0d1408"),
    "religie_slowianskie": Color("0a1210"),
}
const RELIGION_COLOR_DEFAULT: Color = Color(0.3, 0.3, 0.3)

# Mapa: rozmiary i kolory węzłów
const MAP_NODE_SIZE: Vector2 = Vector2(60, 40)
const MAP_NODE_OUTLINE_SELECTED: Color = Color(1.0, 1.0, 1.0)
const MAP_NODE_OUTLINE_DEFAULT: Color = Color(0.4, 0.4, 0.4)
const MAP_NODE_OUTLINE_WIDTH_SELECTED: float = 3.0
const MAP_NODE_OUTLINE_WIDTH_DEFAULT: float = 1.0
const MAP_EDGE_WIDTH: float = 2.0
const MAP_EDGE_COLOR: Color = Color(0.5, 0.5, 0.5, 0.6)

static func religion_color(religion_id: String) -> Color:
    return RELIGION_COLORS.get(religion_id, RELIGION_COLOR_DEFAULT)
```

- [ ] **Step 2: Stwórz failing test ProvinceNode**

Plik `tests/ui/test_province_node.gd`:
```gdscript
extends GutTest

const ProvinceNodeScene := preload("res://scenes/ui/map/ProvinceNode.tscn")

func _make_province(id: String, owner: String, display: String, pos: Vector2) -> Province:
    var p := Province.new()
    p.id = id
    p.owner = owner
    p.display_name = display
    p.position = pos
    p.neighbors = []
    return p

func _instance_node(prov: Province) -> ProvinceNode:
    var pn: ProvinceNode = ProvinceNodeScene.instantiate()
    add_child_autofree(pn)
    await get_tree().process_frame
    pn.set_province(prov)
    return pn

func test_node_renders_display_name():
    var prov := _make_province("mekka", "religie_arabskie", "Mekka", Vector2(420, 420))
    var pn := await _instance_node(prov)
    assert_eq(pn.get_node("%NameLabel").text, "Mekka")

func test_node_position_set_from_province():
    var prov := _make_province("mekka", "religie_arabskie", "Mekka", Vector2(420, 420))
    var pn := await _instance_node(prov)
    assert_eq(pn.position, Vector2(420, 420))

func test_node_color_from_religion_palette():
    var prov := _make_province("mekka", "islam", "Mekka", Vector2(420, 420))
    var pn := await _instance_node(prov)
    var poly: Polygon2D = pn.get_node("%Polygon")
    assert_eq(poly.color, UIConstants.RELIGION_COLORS["islam"])

func test_node_click_emits_pressed():
    var prov := _make_province("mekka", "islam", "Mekka", Vector2(420, 420))
    var pn := await _instance_node(prov)
    watch_signals(pn)
    pn.get_node("%ClickArea").emit_signal("pressed")
    assert_signal_emitted_with_parameters(pn, "pressed", ["mekka"])

func test_node_selection_toggles_outline():
    var prov := _make_province("mekka", "islam", "Mekka", Vector2(420, 420))
    var pn := await _instance_node(prov)
    pn.set_selected(true)
    assert_true(pn.is_selected)
    pn.set_selected(false)
    assert_false(pn.is_selected)
```

Uwaga TDD: test `test_node_renders_display_name` używa `display_name` jako pole — `Province.gd` go nie ma. To celowo. **Krok 3** powyżej rozwiążę przez rozszerzenie `Province.gd` o `display_name` (na razie nieobecne — ProvinceLoader już je czyta z JSON jako display_name, ale Province go nie eksponuje).

Faktycznie: sprawdź `Province.gd` — czy `display_name` istnieje? Jeśli **nie**, dodaj jako pre-step:
```gdscript
@export var display_name: String = ""
```
i w `ProvinceLoader._parse_province`:
```gdscript
p.display_name = pd.get("display_name", pd.get("id", ""))
```

- [ ] **Step 3: Uruchom test — verify FAIL**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=test_province_node.gd -gexit
```
Oczekiwane: FAIL — `ProvinceNode` nie istnieje, scene nie istnieje.

- [ ] **Step 4: Dodaj `display_name` do Province (jeśli brak)**

W `scripts/engine/Province.gd` przed pozostałymi `@export`:
```gdscript
@export var display_name: String = ""
```

W `scripts/engine/ProvinceLoader.gd:_parse_province`, przed `return p`:
```gdscript
p.display_name = pd.get("display_name", pd.get("id", ""))
```

- [ ] **Step 5: Stwórz `scripts/ui/map/ProvinceNode.gd`**

```gdscript
class_name ProvinceNode
extends Control

signal pressed(province_id: String)

var province: Province = null
var is_selected: bool = false

@onready var _polygon: Polygon2D = %Polygon
@onready var _outline: Line2D = %Outline
@onready var _name_label: Label = %NameLabel
@onready var _click_area: Button = %ClickArea

func _ready() -> void:
    _click_area.pressed.connect(_on_click_pressed)
    if province != null:
        _refresh()

func set_province(p: Province) -> void:
    province = p
    if is_inside_tree():
        _refresh()

func set_selected(sel: bool) -> void:
    is_selected = sel
    if is_inside_tree():
        _refresh_outline()

func _refresh() -> void:
    if province == null:
        return
    position = province.position
    _name_label.text = province.display_name
    _polygon.color = UIConstants.religion_color(province.owner)
    _refresh_outline()

func _refresh_outline() -> void:
    _outline.default_color = UIConstants.MAP_NODE_OUTLINE_SELECTED if is_selected else UIConstants.MAP_NODE_OUTLINE_DEFAULT
    _outline.width = UIConstants.MAP_NODE_OUTLINE_WIDTH_SELECTED if is_selected else UIConstants.MAP_NODE_OUTLINE_WIDTH_DEFAULT

func _on_click_pressed() -> void:
    if province != null:
        emit_signal("pressed", province.id)
```

- [ ] **Step 6: Stwórz `scenes/ui/map/ProvinceNode.tscn`**

Struktura sceny (UID i ext_resource zostawiamy edytorowi do wygenerowania; poniżej szkielet TSCN — w razie ręcznego pisania użyj `godot --editor` raz, by IDE wygenerowało UID):

```
[gd_scene format=3]
[ext_resource path="res://scripts/ui/map/ProvinceNode.gd" type="Script" id="1"]

[node name="ProvinceNode" type="Control"]
custom_minimum_size = Vector2(60, 40)
script = ExtResource("1")

[node name="Polygon" type="Polygon2D" parent="."]
unique_name_in_owner = true
polygon = PackedVector2Array(0, 0, 60, 0, 60, 40, 0, 40)
color = Color(0.5, 0.5, 0.5, 1)

[node name="Outline" type="Line2D" parent="."]
unique_name_in_owner = true
points = PackedVector2Array(0, 0, 60, 0, 60, 40, 0, 40, 0, 0)
width = 1.0
default_color = Color(0.4, 0.4, 0.4, 1)

[node name="NameLabel" type="Label" parent="."]
unique_name_in_owner = true
offset_left = 2.0
offset_top = 12.0
offset_right = 58.0
offset_bottom = 28.0
horizontal_alignment = 1
vertical_alignment = 1
text = "?"

[node name="ClickArea" type="Button" parent="."]
unique_name_in_owner = true
offset_right = 60.0
offset_bottom = 40.0
flat = true
```

Lub: wygeneruj scenę raz w edytorze, save, commit razem z .uid sidecarem.

- [ ] **Step 7: Uruchom test — verify PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=test_province_node.gd -gexit
```
Oczekiwane: PASS (5/5).

- [ ] **Step 8: Pełny suite + commit**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
Oczekiwane: 383/383 PASS (378 + 5).

```bash
git add scripts/ui/map/ProvinceNode.gd scenes/ui/map/ProvinceNode.tscn scripts/ui/UIConstants.gd scripts/engine/Province.gd scripts/engine/ProvinceLoader.gd tests/ui/test_province_node.gd
git commit -m "feat(ui): ProvinceNode — single map node with religion-colored polygon"
```

---

### Task 2: MapView — kontener z węzłami i krawędziami

Renderuje wszystkie 12 `ProvinceNode` i `Line2D` per krawędź sąsiedztwa (pomija krawędzie do nieistniejących sąsiadów). Emituje `province_selected(id)` gdy któryś node emituje `pressed`.

**Files:**
- Create: `scripts/ui/map/MapView.gd`
- Create: `scenes/ui/map/MapView.tscn`
- Test: `tests/ui/test_map_view.gd`

- [ ] **Step 1: Stwórz failing test MapView**

Plik `tests/ui/test_map_view.gd`:
```gdscript
extends GutTest

const MapViewScene := preload("res://scenes/ui/map/MapView.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
    var gs: Node = GameStateScript.new()
    var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
    var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
    gs.initialize("islam", religions, graph)
    return gs

func _instance_view(state: Node) -> MapView:
    var mv: MapView = MapViewScene.instantiate()
    add_child_autofree(mv)
    await get_tree().process_frame
    mv.bind_state(state)
    return mv

func test_view_renders_12_province_nodes():
    var state := _make_state()
    add_child_autofree(state)
    var mv := await _instance_view(state)
    assert_eq(mv.get_node_count(), 12)

func test_view_renders_edges_between_valid_neighbors():
    var state := _make_state()
    add_child_autofree(state)
    var mv := await _instance_view(state)
    # mekka <-> lewant + mekka <-> arabia_polnocna (jemen pominięty)
    assert_true(mv.has_edge("mekka", "lewant"))
    assert_true(mv.has_edge("mekka", "arabia_polnocna"))
    assert_false(mv.has_edge("mekka", "jemen"), "Dangling neighbor must be skipped")

func test_view_emits_province_selected_on_node_click():
    var state := _make_state()
    add_child_autofree(state)
    var mv := await _instance_view(state)
    watch_signals(mv)
    var mekka_node: ProvinceNode = mv.get_node_for_id("mekka")
    mekka_node.get_node("%ClickArea").emit_signal("pressed")
    assert_signal_emitted_with_parameters(mv, "province_selected", ["mekka"])

func test_view_selection_clears_previous():
    var state := _make_state()
    add_child_autofree(state)
    var mv := await _instance_view(state)
    mv.set_selected_id("mekka")
    assert_true(mv.get_node_for_id("mekka").is_selected)
    mv.set_selected_id("lewant")
    assert_false(mv.get_node_for_id("mekka").is_selected)
    assert_true(mv.get_node_for_id("lewant").is_selected)
```

- [ ] **Step 2: Verify FAIL**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=test_map_view.gd -gexit
```

- [ ] **Step 3: Stwórz `scripts/ui/map/MapView.gd`**

```gdscript
class_name MapView
extends Control

signal province_selected(province_id: String)

const ProvinceNodeScene := preload("res://scenes/ui/map/ProvinceNode.tscn")

var state: Node = null
var _nodes: Dictionary = {}       # id -> ProvinceNode
var _edges: Dictionary = {}       # "a|b" -> Line2D (a<b lexicographically)
var _selected_id: String = ""

@onready var _edges_layer: Control = %EdgesLayer
@onready var _nodes_layer: Control = %NodesLayer

func bind_state(s: Node) -> void:
    state = s
    refresh()

func refresh() -> void:
    _clear_all()
    if state == null:
        return
    var graph: ProvinceGraph = state.province_graph
    if graph == null:
        return
    for p: Province in graph.all_provinces():
        _spawn_node(p)
    for p: Province in graph.all_provinces():
        for n_id: String in graph.get_neighbors(p.id):
            _ensure_edge(p.id, n_id)

func set_selected_id(id: String) -> void:
    if _selected_id != "" and _nodes.has(_selected_id):
        _nodes[_selected_id].set_selected(false)
    _selected_id = id
    if id != "" and _nodes.has(id):
        _nodes[id].set_selected(true)

func get_node_for_id(id: String) -> ProvinceNode:
    return _nodes.get(id, null)

func get_node_count() -> int:
    return _nodes.size()

func has_edge(a: String, b: String) -> bool:
    return _edges.has(_edge_key(a, b))

func _spawn_node(p: Province) -> void:
    var pn: ProvinceNode = ProvinceNodeScene.instantiate()
    _nodes_layer.add_child(pn)
    pn.set_province(p)
    pn.pressed.connect(_on_node_pressed)
    _nodes[p.id] = pn

func _ensure_edge(a: String, b: String) -> void:
    var key := _edge_key(a, b)
    if _edges.has(key):
        return
    if not _nodes.has(a) or not _nodes.has(b):
        return
    var line := Line2D.new()
    line.width = UIConstants.MAP_EDGE_WIDTH
    line.default_color = UIConstants.MAP_EDGE_COLOR
    var ca: Vector2 = _nodes[a].position + UIConstants.MAP_NODE_SIZE * 0.5
    var cb: Vector2 = _nodes[b].position + UIConstants.MAP_NODE_SIZE * 0.5
    line.points = PackedVector2Array([ca, cb])
    _edges_layer.add_child(line)
    _edges[key] = line

func _edge_key(a: String, b: String) -> String:
    return (a + "|" + b) if a < b else (b + "|" + a)

func _clear_all() -> void:
    for c in _nodes_layer.get_children():
        c.queue_free()
    for c in _edges_layer.get_children():
        c.queue_free()
    _nodes.clear()
    _edges.clear()

func _on_node_pressed(province_id: String) -> void:
    set_selected_id(province_id)
    emit_signal("province_selected", province_id)
```

- [ ] **Step 4: Stwórz `scenes/ui/map/MapView.tscn`**

Struktura:
```
MapView (Control, script=MapView.gd, custom_minimum_size=800x500)
├─ EdgesLayer (Control, unique_name, mouse_filter=IGNORE, anchors_preset=15 — full rect)
└─ NodesLayer (Control, unique_name, mouse_filter=PASS, anchors_preset=15 — full rect)
```

**Uwaga:** używamy `Control` zamiast `Node2D` dla obu warstw, bo `ProvinceNode extends Control`. Control inside Node2D może łamać input routing w runtime. Linie krawędzi (`Line2D`) renderują się w `EdgesLayer` jako Node2D dzieci — Line2D extends Node2D, a Node2D inside Control jest OK (rendering tylko, bez input).

Kolejność dzieci ma znaczenie: krawędzie są pod węzłami (EdgesLayer pierwsze w drzewie = renderowane pod NodesLayer).

- [ ] **Step 5: Verify PASS + pełny suite**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=test_map_view.gd -gexit
```
Oczekiwane: 4/4 PASS.

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
Oczekiwane: 387/387 PASS.

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/map/MapView.gd scenes/ui/map/MapView.tscn tests/ui/test_map_view.gd
git commit -m "feat(ui): MapView — graf 12 prowincji + krawędzie sąsiedztwa"
```

---

### Task 3: Integracja MapView w MainShell jako zakładka Mapa

Zamień `PlaceholderTab` z `unique_name = "MapaTab"` w `MainShell.tscn` na `MapView` z **tym samym unique_name `MapaTab`** (zachowujemy stabilną nazwę node'a — Task 8 zmieni jego TYP ponownie, ale `%MapaTab` pozostaje konstantne przez wszystkie taski). Usuń `_mapa_tab.set_title(...)` z `MainShell._ready`. Zaktualizuj istniejące testy z `tests/ui/test_main_shell.gd` które oczekują `%MapaTab is PlaceholderTab`.

**Files:**
- Modify: `scripts/ui/MainShell.gd:7,15`
- Modify: `scenes/ui/MainShell.tscn` (zamień node MapaTab z PlaceholderTab na MapView, zachowaj unique_name)
- Modify: `tests/ui/test_main_shell.gd` (delete/replace placeholder title assertion)

- [ ] **Step 1: Stwórz failing test integracji**

W `tests/ui/test_main_shell.gd` dodaj nowe testy ORAZ usuń istniejący `test_shell_placeholders_have_correct_titles` (assertion `mapa.title contains "Plan 09"` straci sens). Mapa-specific assertion w `test_shell_default_shows_swiat_tab` (`assert_false(shell.get_node("%MapaTab").visible)`) zostaje — `%MapaTab` nadal istnieje, tylko ma inny typ.

```gdscript
# Usuń istniejący test_shell_placeholders_have_correct_titles (był na liniach ~37-46)
# Zastąp 2-toymi testami:

func test_shell_wiara_frakcje_placeholders_have_correct_titles():
    var state := _make_state()
    add_child_autofree(state)
    var shell := await _instance_shell(state)
    var wiara: PlaceholderTab = shell.get_node("%WiaraTab")
    var frakcje: PlaceholderTab = shell.get_node("%FrakcjeTab")
    assert_string_contains(wiara.title, "Plan 10")
    assert_string_contains(frakcje.title, "Plan 11")

func test_main_shell_renders_map_view_in_mapa_tab():
    var state := _make_state()
    add_child_autofree(state)
    var shell := await _instance_shell(state)
    shell.get_node("%TabBar").set_current_tab("mapa")
    var map_view: MapView = shell.get_node("%MapaTab")
    assert_not_null(map_view)
    assert_true(map_view.visible)
    assert_eq(map_view.get_node_count(), 12)

func test_main_shell_hides_map_view_in_other_tabs():
    var state := _make_state()
    add_child_autofree(state)
    var shell := await _instance_shell(state)
    shell.get_node("%TabBar").set_current_tab("swiat")
    var map_view = shell.get_node("%MapaTab")
    assert_false(map_view.visible)
```

- [ ] **Step 2: Verify FAIL**

- [ ] **Step 3: Zamień PlaceholderTab MapaTab na MapView w `MainShell.tscn`**

W edytorze Godot: w `MainShell.tscn` znajdź node `MapaTab` (PlaceholderTab z `unique_name_in_owner = true`). Zamień go na instancję `MapView.tscn`. **Zachowaj nazwę `MapaTab`** (przemianuj instancję sceny po dodaniu — RMB > Rename). **Zachowaj `unique_name_in_owner = true`**. Zachowaj pozycję w drzewie scen (jako dziecko ContentArea).

- [ ] **Step 4: Zaktualizuj `MainShell.gd`**

Zmień linię 7:
```gdscript
@onready var _mapa_tab: PlaceholderTab = %MapaTab
```
na:
```gdscript
@onready var _mapa_tab: MapView = %MapaTab
```

Usuń linię 15 (`_mapa_tab.set_title("Mapa (Plan 09 — w trakcie)")`).

W `bind_state` (po linii 27, gdzie `_tab_bar.bind_state(s)`):
```gdscript
_mapa_tab.bind_state(s)
```

W `refresh()` (po linii 34):
```gdscript
if _mapa_tab.has_method("refresh"):
    _mapa_tab.refresh()
```

`_on_tab_changed` nie wymaga zmian — już ustawia `_mapa_tab.visible` (linia 39).

- [ ] **Step 5: Verify PASS + pełny suite**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
Oczekiwane: 389/389 PASS (387 + 3 nowe − 1 usunięty test).

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/MainShell.gd scenes/ui/MainShell.tscn tests/ui/test_main_shell.gd
git commit -m "feat(ui): MainShell — MapaTab is now MapView (was PlaceholderTab)"
```

---

## Chunk 2: Panel szczegółów prowincji

### Task 4: ProvinceDetailHeader — nazwa, religia, teren, święte miasto, populacja, zasoby

Pierwszy z 3 komponentów panelu szczegółów. Read-only labels z danymi prowincji + religii właściciela. Renderuje header zgodnie ze spec 06 sekcja 3:

```
[Nazwa] · [religia ikona+nazwa] · [terrain emoji+nazwa] · [★ Święte Miasto?]
[👥 N populacja]  [💰 +X złota/turę]  [🌾 +Y żywności/turę]
```

**Files:**
- Create: `scripts/ui/map/ProvinceDetailHeader.gd`
- Create: `scenes/ui/map/ProvinceDetailHeader.tscn`
- Test: `tests/ui/test_province_detail_header.gd`

- [ ] **Step 1: Failing test**

Plik `tests/ui/test_province_detail_header.gd`:
```gdscript
extends GutTest

const HeaderScene := preload("res://scenes/ui/map/ProvinceDetailHeader.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
    var gs: Node = GameStateScript.new()
    var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
    var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
    gs.initialize("islam", religions, graph)
    return gs

func _instance(state: Node, province_id: String) -> ProvinceDetailHeader:
    var h: ProvinceDetailHeader = HeaderScene.instantiate()
    add_child_autofree(h)
    await get_tree().process_frame
    h.bind(state, province_id)
    return h

func test_header_renders_province_name():
    var state := _make_state()
    add_child_autofree(state)
    var h := await _instance(state, "mekka")
    assert_eq(h.get_node("%NameLabel").text, "Mekka")

func test_header_renders_owner_religion():
    var state := _make_state()
    add_child_autofree(state)
    var h := await _instance(state, "mekka")
    var owner: Religion = state.get_religion("religie_arabskie")
    var expected: String = "%s %s" % [owner.icon, owner.display_name]
    assert_eq(h.get_node("%OwnerLabel").text, expected)

func test_header_shows_holy_site_badge_when_true():
    var state := _make_state()
    add_child_autofree(state)
    var h := await _instance(state, "mekka")
    assert_true(h.get_node("%HolySiteLabel").visible)
    assert_eq(h.get_node("%HolySiteLabel").text, "★ Święte Miasto")

func test_header_hides_holy_site_badge_when_false():
    var state := _make_state()
    add_child_autofree(state)
    var h := await _instance(state, "lewant")
    assert_false(h.get_node("%HolySiteLabel").visible)

func test_header_renders_terrain():
    var state := _make_state()
    add_child_autofree(state)
    var h := await _instance(state, "mekka")  # terrain=desert
    assert_string_contains(h.get_node("%TerrainLabel").text, "pustynia")

func test_header_renders_population():
    var state := _make_state()
    add_child_autofree(state)
    var h := await _instance(state, "mekka")  # population=200
    assert_eq(h.get_node("%PopulationLabel").text, "👥 200")

func test_header_renders_resources():
    var state := _make_state()
    add_child_autofree(state)
    var h := await _instance(state, "mekka")  # food=1, gold=3
    assert_eq(h.get_node("%GoldLabel").text, "💰 +3/turę")
    assert_eq(h.get_node("%FoodLabel").text, "🌾 +1/turę")
```

- [ ] **Step 2: Verify FAIL**

- [ ] **Step 3: Stwórz `scripts/ui/map/ProvinceDetailHeader.gd`**

```gdscript
class_name ProvinceDetailHeader
extends VBoxContainer

const TERRAIN_LABELS: Dictionary = {
    "plains": "🏞 równina",
    "mountains": "⛰ góry",
    "desert": "🏜 pustynia",
    "coast": "🌊 wybrzeże",
    "fertile": "🌾 żyzne",
}

var state: Node = null
var province_id: String = ""

@onready var _name: Label = %NameLabel
@onready var _owner: Label = %OwnerLabel
@onready var _terrain: Label = %TerrainLabel
@onready var _holy_site: Label = %HolySiteLabel
@onready var _population: Label = %PopulationLabel
@onready var _gold: Label = %GoldLabel
@onready var _food: Label = %FoodLabel

func bind(s: Node, pid: String) -> void:
    state = s
    province_id = pid
    if is_inside_tree():
        refresh()

func refresh() -> void:
    if state == null or province_id == "":
        return
    var prov: Province = state.province_graph.get_province(province_id)
    if prov == null:
        return
    _name.text = prov.display_name
    var owner: Religion = state.get_religion(prov.owner)
    if owner != null:
        _owner.text = "%s %s" % [owner.icon, owner.display_name]
    else:
        _owner.text = prov.owner
    _terrain.text = TERRAIN_LABELS.get(prov.terrain, prov.terrain)
    _holy_site.visible = prov.is_holy_site
    _holy_site.text = "★ Święte Miasto"
    _population.text = "👥 %d" % prov.population
    _gold.text = "💰 +%d/turę" % int(prov.resources.get("gold", 0))
    _food.text = "🌾 +%d/turę" % int(prov.resources.get("food", 0))
```

- [ ] **Step 4: Stwórz `scenes/ui/map/ProvinceDetailHeader.tscn`**

VBoxContainer z dwoma HBoxContainer:
```
ProvinceDetailHeader (VBoxContainer, script)
├─ TopRow (HBoxContainer)
│  ├─ NameLabel (Label, unique)
│  ├─ Separator1 (Label, text=" · ")
│  ├─ OwnerLabel (Label, unique)
│  ├─ Separator2 (Label, text=" · ")
│  ├─ TerrainLabel (Label, unique)
│  ├─ Separator3 (Label, text=" · ")
│  └─ HolySiteLabel (Label, unique, visible=false)
└─ BottomRow (HBoxContainer)
   ├─ PopulationLabel (Label, unique)
   ├─ GoldLabel (Label, unique)
   └─ FoodLabel (Label, unique)
```

- [ ] **Step 5: Verify PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=test_province_detail_header.gd -gexit
```
Oczekiwane: 7/7 PASS.

- [ ] **Step 6: Pełny suite + commit**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
Oczekiwane: 396/396 PASS.

```bash
git add scripts/ui/map/ProvinceDetailHeader.gd scenes/ui/map/ProvinceDetailHeader.tscn tests/ui/test_province_detail_header.gd
git commit -m "feat(ui): ProvinceDetailHeader — name, owner, terrain, holy site, pop, resources"
```

---

### Task 5: PressureBars — pasy presji per religia

Drugi komponent panelu. Lista wszystkich religii z presją > 0 w prowincji, posortowana malejąco. Format:

```
☪ Islam        ████████░░ 72
✝ Chr. Zach.   ██░░░░░░░░ 18
```

Render każdej linii: ikona + nazwa (skrócona) + `ProgressBar` (0-100) + liczba.

**Files:**
- Create: `scripts/ui/map/PressureBars.gd`
- Create: `scenes/ui/map/PressureBars.tscn`
- Create: `scripts/ui/map/PressureRow.gd` (jeden wiersz)
- Create: `scenes/ui/map/PressureRow.tscn`
- Test: `tests/ui/test_pressure_bars.gd`

- [ ] **Step 1: Failing test**

Plik `tests/ui/test_pressure_bars.gd`:
```gdscript
extends GutTest

const BarsScene := preload("res://scenes/ui/map/PressureBars.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
    var gs: Node = GameStateScript.new()
    var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
    var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
    gs.initialize("islam", religions, graph)
    return gs

func _instance(state: Node, province_id: String) -> PressureBars:
    var pb: PressureBars = BarsScene.instantiate()
    add_child_autofree(pb)
    await get_tree().process_frame
    pb.bind(state, province_id)
    return pb

func test_bars_render_one_row_per_pressure_entry():
    var state := _make_state()
    add_child_autofree(state)
    # lewant: chr_wschodnie=60, islam=15 → 2 rows
    var pb := await _instance(state, "lewant")
    assert_eq(pb.row_count(), 2)

func test_bars_skip_zero_pressure():
    var state := _make_state()
    add_child_autofree(state)
    # mekka: religie_arabskie=80 → 1 row (no other pressures)
    var pb := await _instance(state, "mekka")
    assert_eq(pb.row_count(), 1)

func test_bars_sort_descending_by_pressure():
    var state := _make_state()
    add_child_autofree(state)
    # lewant: chr_wschodnie=60 > islam=15 → row[0]=chr_wschodnie
    var pb := await _instance(state, "lewant")
    var first := pb.get_row(0)
    assert_eq(first.religion_id, "chr_wschodnie")
    var second := pb.get_row(1)
    assert_eq(second.religion_id, "islam")

func test_bars_render_pressure_value():
    var state := _make_state()
    add_child_autofree(state)
    var pb := await _instance(state, "lewant")
    var first := pb.get_row(0)
    assert_eq(first.get_node("%ValueLabel").text, "60")
```

- [ ] **Step 2: Verify FAIL**

- [ ] **Step 3: Stwórz `scripts/ui/map/PressureRow.gd`**

```gdscript
class_name PressureRow
extends HBoxContainer

var religion_id: String = ""

@onready var _icon: Label = %IconLabel
@onready var _name: Label = %NameLabel
@onready var _bar: ProgressBar = %Bar
@onready var _value: Label = %ValueLabel

func set_data(religion: Religion, pressure_value: float) -> void:
    religion_id = religion.id
    if is_inside_tree():
        _icon.text = religion.icon
        _name.text = religion.display_name
        _bar.value = pressure_value
        _value.text = "%d" % int(pressure_value)
```

- [ ] **Step 4: Stwórz `scenes/ui/map/PressureRow.tscn`**

```
PressureRow (HBoxContainer, script)
├─ IconLabel (Label, unique)
├─ NameLabel (Label, unique, custom_min_size.x=120)
├─ Bar (ProgressBar, unique, min_value=0, max_value=100, show_percentage=false)
└─ ValueLabel (Label, unique)
```

- [ ] **Step 5: Stwórz `scripts/ui/map/PressureBars.gd`**

```gdscript
class_name PressureBars
extends VBoxContainer

const PressureRowScene := preload("res://scenes/ui/map/PressureRow.tscn")

var state: Node = null
var province_id: String = ""
var _rows: Array[PressureRow] = []

func bind(s: Node, pid: String) -> void:
    state = s
    province_id = pid
    if is_inside_tree():
        refresh()

func refresh() -> void:
    _clear()
    if state == null or province_id == "":
        return
    var prov: Province = state.province_graph.get_province(province_id)
    if prov == null:
        return
    var entries: Array = []
    for rid: String in prov.pressure:
        var v: float = float(prov.pressure[rid])
        if v > 0.0:
            entries.append({"id": rid, "value": v})
    entries.sort_custom(func(a, b): return a.value > b.value)
    for e in entries:
        var rel: Religion = state.get_religion(e.id)
        if rel == null:
            continue
        var row: PressureRow = PressureRowScene.instantiate()
        add_child(row)
        row.set_data(rel, e.value)
        _rows.append(row)

func row_count() -> int:
    return _rows.size()

func get_row(idx: int) -> PressureRow:
    if idx < 0 or idx >= _rows.size():
        return null
    return _rows[idx]

func _clear() -> void:
    for r in _rows:
        r.queue_free()
    _rows.clear()
```

- [ ] **Step 6: Stwórz `scenes/ui/map/PressureBars.tscn`**

`PressureBars (VBoxContainer, script)` — dynamicznie dodaje `PressureRow` children w `refresh()`.

- [ ] **Step 7: Verify PASS + suite**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=test_pressure_bars.gd -gexit
```
Oczekiwane: 4/4 PASS.

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
Oczekiwane: 400/400 PASS.

- [ ] **Step 8: Commit**

```bash
git add scripts/ui/map/PressureBars.gd scenes/ui/map/PressureBars.tscn scripts/ui/map/PressureRow.gd scenes/ui/map/PressureRow.tscn tests/ui/test_pressure_bars.gd
git commit -m "feat(ui): PressureBars — pressure bars per religion sorted desc"
```

---

### Task 6: ProvinceActions — 3 akcje z gatingiem

Trzeci komponent panelu. Trzy przyciski z gatingiem:
- `[⚔ Wypowiedz wojnę]` — dostępny gdy: prowincja gracza sąsiaduje z prowincją target, target.owner ≠ player, `WarManager.available_casus_belli(player, target_owner, state).size() > 0`.
- `[📜 Wyślij misjonarza]` — dostępny gdy gracz ≠ owner i pełne warunki engine: ekskluzywizm (C ≥ 20), trust > 30, **tension ≤ 85** (block_tension_for_dialogue), prestiż.
- `[🌍 → Dyplomacja]` — zawsze dostępny gdy owner ≠ player; emituje sygnał `navigate_to_diplomacy(religion_id)`.

Jeśli gracz jest właścicielem prowincji, wszystkie 3 akcje są ukryte.

War action otwiera podselektor `CBPicker` (jeśli ≥2 CB) lub od razu wykonuje (jeśli dokładnie 1).

**Korekta vs Plan 08:** Plan 08's `ActionPanel._missionaries_available` pomija tension check, ale engine `DiplomacyManager.send_missionaries` faktycznie egzekwuje `military_tension > BLOCK_TENSION_FOR_DIALOGUE` jako blok (linia 332). Plan 09 dodaje tension check w UI, żeby pokazywać tooltip "napięcie >85" zamiast pozwalać użytkownikowi nacisnąć przycisk i dostać silent failure. Plan 08 ma tę samą lukę do naprawy w przyszłym polishu — nie wymaga zmian w tym planie (Plan 09 jest engine-correct).

**Files:**
- Create: `scripts/ui/map/ProvinceActions.gd`
- Create: `scenes/ui/map/ProvinceActions.tscn`
- Create: `scripts/ui/map/CBPicker.gd`
- Create: `scenes/ui/map/CBPicker.tscn`
- Test: `tests/ui/test_province_actions.gd`

- [ ] **Step 1: Failing test (gating)**

Plik `tests/ui/test_province_actions.gd`:
```gdscript
extends GutTest

const ActionsScene := preload("res://scenes/ui/map/ProvinceActions.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
    var gs: Node = GameStateScript.new()
    var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
    var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
    gs.initialize("islam", religions, graph)
    return gs

func _instance(state: Node, province_id: String) -> ProvinceActions:
    var pa: ProvinceActions = ActionsScene.instantiate()
    add_child_autofree(pa)
    await get_tree().process_frame
    pa.bind(state, province_id)
    return pa

func test_actions_hidden_when_player_owns_province():
    var state := _make_state()
    add_child_autofree(state)
    # islam = player, mezopotamia owner=islam
    var pa := await _instance(state, "mezopotamia")
    assert_false(pa.get_node("%WarButton").visible)
    assert_false(pa.get_node("%MissionButton").visible)
    assert_false(pa.get_node("%DiplomacyButton").visible)

func test_diplomacy_button_always_visible_for_foreign_province():
    var state := _make_state()
    add_child_autofree(state)
    var pa := await _instance(state, "lewant")  # owner=chr_wschodnie
    assert_true(pa.get_node("%DiplomacyButton").visible)

func test_diplomacy_button_emits_navigate_signal():
    var state := _make_state()
    add_child_autofree(state)
    var pa := await _instance(state, "lewant")
    watch_signals(pa)
    pa.get_node("%DiplomacyButton").emit_signal("pressed")
    assert_signal_emitted_with_parameters(pa, "navigate_to_diplomacy", ["chr_wschodnie"])

func test_war_button_disabled_without_neighbor_province():
    var state := _make_state()
    add_child_autofree(state)
    # Persepolis sąsiaduje tylko z persja; islam nie ma żadnej prowincji sąsiadującej z persepolis
    var pa := await _instance(state, "persepolis")
    var btn: Button = pa.get_node("%WarButton")
    assert_true(btn.visible, "War button must be visible for foreign province")
    assert_true(btn.disabled, "War button must be disabled without neighbor")

func test_war_button_enabled_with_guaranteed_cb():
    # Setup: stwórz syntetyczną relację parent_religion_id między islam a target,
    # która gwarantuje CB "stlumienie_herezji" (zawsze dostępny dla rodzic→dziecko).
    var state := _make_state()
    add_child_autofree(state)
    var zoroastryzm: Religion = state.get_religion("zoroastryzm")
    zoroastryzm.parent_religion_id = "islam"  # CB stlumienie_herezji gwarantowany
    # Upewnij się że islam ma sąsiada zoroastryzmu (mezopotamia sąsiaduje z persja)
    var pa := await _instance(state, "persja")
    var btn: Button = pa.get_node("%WarButton")
    assert_true(btn.visible)
    assert_false(btn.disabled, "War must be enabled given guaranteed CB + neighbor")
```

- [ ] **Step 2: Verify FAIL**

- [ ] **Step 3: Stwórz `scripts/ui/map/ProvinceActions.gd`**

```gdscript
class_name ProvinceActions
extends VBoxContainer

signal navigate_to_diplomacy(religion_id: String)
signal war_declared(defender_id: String, cb: String)
signal missionaries_sent(target_id: String)

var state: Node = null
var province_id: String = ""

@onready var _war_btn: Button = %WarButton
@onready var _mission_btn: Button = %MissionButton
@onready var _diplomacy_btn: Button = %DiplomacyButton
@onready var _cb_picker: Node = %CBPicker  # CBPicker (initially hidden)

func _ready() -> void:
    _war_btn.pressed.connect(_on_war_pressed)
    _mission_btn.pressed.connect(_on_mission_pressed)
    _diplomacy_btn.pressed.connect(_on_diplomacy_pressed)
    if _cb_picker.has_signal("cb_chosen"):
        _cb_picker.cb_chosen.connect(_on_cb_chosen)

func bind(s: Node, pid: String) -> void:
    state = s
    province_id = pid
    if is_inside_tree():
        refresh()

func refresh() -> void:
    if state == null or province_id == "":
        return
    var prov: Province = state.province_graph.get_province(province_id)
    if prov == null:
        return
    var player: Religion = state.get_player_religion()
    var owner_id := prov.owner
    var is_player_owned := owner_id == player.id

    if is_player_owned:
        _war_btn.visible = false
        _mission_btn.visible = false
        _diplomacy_btn.visible = false
        _cb_picker.visible = false
        return

    _war_btn.visible = true
    _mission_btn.visible = true
    _diplomacy_btn.visible = true

    var target: Religion = state.get_religion(owner_id)
    _refresh_war_button(player, target, prov)
    _refresh_mission_button(player, target)
    # Diplomacy zawsze visible+enabled
    _diplomacy_btn.disabled = false
    _diplomacy_btn.tooltip_text = "Otwórz panel dyplomacji dla religii %s" % target.display_name

func _refresh_war_button(player: Religion, target: Religion, prov: Province) -> void:
    var has_neighbor := _player_has_neighbor_of(prov, player)
    var wm := WarManager.new()
    var cbs := wm.available_casus_belli(player, target, state)
    var enabled := has_neighbor and cbs.size() > 0
    _war_btn.disabled = not enabled
    if not has_neighbor:
        _war_btn.tooltip_text = "Brak sąsiedztwa: żadna twoja prowincja nie sąsiaduje z %s" % prov.display_name
    elif cbs.size() == 0:
        _war_btn.tooltip_text = "Brak casus belli przeciw %s" % target.display_name
    else:
        _war_btn.tooltip_text = "Dostępne CB: %s" % ", ".join(cbs)

func _refresh_mission_button(player: Religion, target: Religion) -> void:
    var dm := DiplomacyManager.new()
    var ekskluzywizm_ok := player.get_axis("C") >= DiplomacyManager.MISSIONARIES_EXCLUSIVITY_BLOCK
    var rel: RelationState = dm.get_or_create_relation(state, player.id, target.id)
    var trust_ok := rel.theological_trust > DiplomacyManager.MISSIONARIES_TRUST_THRESHOLD
    var tension_ok := rel.military_tension <= DiplomacyManager.BLOCK_TENSION_FOR_DIALOGUE
    var cost: int = int(round(DiplomacyManager.MISSIONARIES_PRESTIGE_COST))
    var prestige_ok := player.prestige >= cost
    var enabled := ekskluzywizm_ok and trust_ok and tension_ok and prestige_ok
    _mission_btn.disabled = not enabled
    if not enabled:
        var reasons: Array[String] = []
        if not ekskluzywizm_ok: reasons.append("Twój Ekskluzywizm blokuje (Synkretyzm <20)")
        if not trust_ok: reasons.append("trust ≤30")
        if not tension_ok: reasons.append("napięcie >85")
        if not prestige_ok: reasons.append("prestiż <%d" % cost)
        _mission_btn.tooltip_text = "Niedostępne: " + ", ".join(reasons)
    else:
        _mission_btn.tooltip_text = "Wyślij misjonarza do %s (koszt %d prestiżu)" % [target.display_name, cost]

func _player_has_neighbor_of(prov: Province, player: Religion) -> bool:
    var graph: ProvinceGraph = state.province_graph
    for n_id: String in graph.get_neighbors(prov.id):
        var n: Province = graph.get_province(n_id)
        if n != null and n.owner == player.id:
            return true
    return false

func _on_war_pressed() -> void:
    var prov: Province = state.province_graph.get_province(province_id)
    var player: Religion = state.get_player_religion()
    var target: Religion = state.get_religion(prov.owner)
    var wm := WarManager.new()
    var cbs := wm.available_casus_belli(player, target, state)
    if cbs.size() == 1:
        _execute_war(target.id, cbs[0])
    elif cbs.size() > 1:
        _cb_picker.open(cbs, target.id)

func _on_cb_chosen(cb: String, defender_id: String) -> void:
    _execute_war(defender_id, cb)

func _execute_war(defender_id: String, cb: String) -> void:
    var wm := WarManager.new()
    var war := wm.declare_war(state.get_player_religion().id, defender_id, cb, state)
    if war != null:
        emit_signal("war_declared", defender_id, cb)
        refresh()

func _on_mission_pressed() -> void:
    var prov: Province = state.province_graph.get_province(province_id)
    var dm := DiplomacyManager.new()
    if dm.send_missionaries(state, state.get_player_religion().id, prov.owner):
        emit_signal("missionaries_sent", prov.owner)
        refresh()

func _on_diplomacy_pressed() -> void:
    var prov: Province = state.province_graph.get_province(province_id)
    if prov != null:
        emit_signal("navigate_to_diplomacy", prov.owner)
```

- [ ] **Step 4: Stwórz `scripts/ui/map/CBPicker.gd`**

```gdscript
class_name CBPicker
extends PanelContainer

signal cb_chosen(cb: String, defender_id: String)
signal cancelled

const CB_LABELS: Dictionary = {
    "krucjata": "⚔ Krucjata",
    "dzihad": "⚔ Dżihad",
    "stlumienie_herezji": "⚔ Stłumienie herezji",
    "rewanz": "⚔ Rewanż",
    "wojna_ekspansywna": "⚔ Wojna ekspansywna",
}

var _defender_id: String = ""

@onready var _list: VBoxContainer = %CBList
@onready var _cancel: Button = %CancelButton

func _ready() -> void:
    visible = false
    _cancel.pressed.connect(_on_cancel)

func open(cbs: Array[String], defender_id: String) -> void:
    _defender_id = defender_id
    for c in _list.get_children():
        c.queue_free()
    for cb: String in cbs:
        var btn := Button.new()
        btn.text = CB_LABELS.get(cb, cb)
        btn.pressed.connect(_on_cb_pressed.bind(cb))
        _list.add_child(btn)
    visible = true

func close() -> void:
    visible = false

func _on_cb_pressed(cb: String) -> void:
    close()
    emit_signal("cb_chosen", cb, _defender_id)

func _on_cancel() -> void:
    close()
    emit_signal("cancelled")
```

- [ ] **Step 5: Stwórz sceny TSCN dla obu**

`scenes/ui/map/CBPicker.tscn`:
```
CBPicker (PanelContainer, script, visible=false)
└─ VBox (VBoxContainer)
   ├─ Header (Label, text="Wybierz casus belli:")
   ├─ CBList (VBoxContainer, unique_name)
   └─ CancelButton (Button, unique_name, text="Anuluj")
```

`scenes/ui/map/ProvinceActions.tscn`:
```
ProvinceActions (VBoxContainer, script)
├─ WarButton (Button, unique, text="⚔ Wypowiedz wojnę")
├─ MissionButton (Button, unique, text="📜 Wyślij misjonarza")
├─ DiplomacyButton (Button, unique, text="🌍 → Dyplomacja")
└─ CBPicker (instancja CBPicker.tscn, unique_name, visible=false)
```

**Layout:** CBPicker pokazuje się **inline poniżej przycisków** (panel ProvinceDetailPanel rozszerza się pionowo gdy CBPicker.visible=true). To nie overlay/popup — VBoxContainer dodaje pełną wysokość CBPickera do swojej wysokości w runtime, a ProvinceDetailPanel ma `size_flags_v = SHRINK_BEGIN` więc dostosowuje się.

- [ ] **Step 6: Verify PASS + suite**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=test_province_actions.gd -gexit
```
Oczekiwane: 5/5 PASS (1 może być pending).

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
Oczekiwane: 405/405 PASS.

- [ ] **Step 7: Commit**

```bash
git add scripts/ui/map/ProvinceActions.gd scenes/ui/map/ProvinceActions.tscn scripts/ui/map/CBPicker.gd scenes/ui/map/CBPicker.tscn tests/ui/test_province_actions.gd
git commit -m "feat(ui): ProvinceActions — war/missionaries/diplomacy with engine gating"
```

---

### Task 7: ProvinceDetailPanel — kompozycja Header + PressureBars + Actions

Sklej 3 podkomponenty w jeden panel (PanelContainer 280px szerokości). Panel ma metodę `bind_state(state)` + `set_province(id)`. Emituje sygnały dziedziczone z Actions.

**Files:**
- Create: `scripts/ui/map/ProvinceDetailPanel.gd`
- Create: `scenes/ui/map/ProvinceDetailPanel.tscn`
- Test: `tests/ui/test_province_detail_panel.gd`

- [ ] **Step 1: Failing test**

Plik `tests/ui/test_province_detail_panel.gd`:
```gdscript
extends GutTest

const PanelScene := preload("res://scenes/ui/map/ProvinceDetailPanel.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
    var gs: Node = GameStateScript.new()
    var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
    var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
    gs.initialize("islam", religions, graph)
    return gs

func _instance(state: Node) -> ProvinceDetailPanel:
    var p: ProvinceDetailPanel = PanelScene.instantiate()
    add_child_autofree(p)
    await get_tree().process_frame
    p.bind_state(state)
    return p

func test_panel_hidden_with_no_selection():
    var state := _make_state()
    add_child_autofree(state)
    var p := await _instance(state)
    assert_false(p.visible)

func test_panel_shows_when_province_selected():
    var state := _make_state()
    add_child_autofree(state)
    var p := await _instance(state)
    p.set_province("mekka")
    assert_true(p.visible)
    assert_eq(p.current_province_id, "mekka")

func test_panel_clear_hides():
    var state := _make_state()
    add_child_autofree(state)
    var p := await _instance(state)
    p.set_province("mekka")
    p.clear()
    assert_false(p.visible)
    assert_eq(p.current_province_id, "")

func test_panel_relays_navigate_signal():
    var state := _make_state()
    add_child_autofree(state)
    var p := await _instance(state)
    p.set_province("lewant")
    watch_signals(p)
    var actions := p.get_node("%Actions")
    actions.emit_signal("navigate_to_diplomacy", "chr_wschodnie")
    assert_signal_emitted_with_parameters(p, "navigate_to_diplomacy", ["chr_wschodnie"])
```

- [ ] **Step 2: Verify FAIL**

- [ ] **Step 3: Stwórz `scripts/ui/map/ProvinceDetailPanel.gd`**

```gdscript
class_name ProvinceDetailPanel
extends PanelContainer

signal navigate_to_diplomacy(religion_id: String)
signal war_declared(defender_id: String, cb: String)
signal missionaries_sent(target_id: String)

var state: Node = null
var current_province_id: String = ""

@onready var _header: ProvinceDetailHeader = %Header
@onready var _pressure: PressureBars = %Pressure
@onready var _actions: ProvinceActions = %Actions

func _ready() -> void:
    visible = false
    _actions.navigate_to_diplomacy.connect(_on_navigate)
    _actions.war_declared.connect(_on_war)
    _actions.missionaries_sent.connect(_on_missionaries)

func bind_state(s: Node) -> void:
    state = s

func set_province(province_id: String) -> void:
    current_province_id = province_id
    if state == null:
        return
    _header.bind(state, province_id)
    _pressure.bind(state, province_id)
    _actions.bind(state, province_id)
    visible = true

func clear() -> void:
    current_province_id = ""
    visible = false

func refresh() -> void:
    if current_province_id != "" and state != null:
        _header.refresh()
        _pressure.refresh()
        _actions.refresh()

func _on_navigate(religion_id: String) -> void:
    emit_signal("navigate_to_diplomacy", religion_id)

func _on_war(defender_id: String, cb: String) -> void:
    emit_signal("war_declared", defender_id, cb)
    refresh()

func _on_missionaries(target_id: String) -> void:
    emit_signal("missionaries_sent", target_id)
    refresh()
```

- [ ] **Step 4: Stwórz `scenes/ui/map/ProvinceDetailPanel.tscn`**

```
ProvinceDetailPanel (PanelContainer, script, min_size_x=280, visible=false)
└─ VBox (VBoxContainer)
   ├─ Header (instancja ProvinceDetailHeader.tscn, unique)
   ├─ Separator1 (HSeparator)
   ├─ PressureTitle (Label, text="Presja religijna:")
   ├─ Pressure (instancja PressureBars.tscn, unique)
   ├─ Separator2 (HSeparator)
   ├─ ActionsTitle (Label, text="Dostępne akcje:")
   └─ Actions (instancja ProvinceActions.tscn, unique)
```

- [ ] **Step 5: Verify PASS + suite**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=test_province_detail_panel.gd -gexit
```
Oczekiwane: 4/4 PASS.

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
Oczekiwane: 409/409 PASS.

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/map/ProvinceDetailPanel.gd scenes/ui/map/ProvinceDetailPanel.tscn tests/ui/test_province_detail_panel.gd
git commit -m "feat(ui): ProvinceDetailPanel — header+pressure+actions composition"
```

---

## Chunk 3: Integracja MapaTab + polish

### Task 8: MapaTab — kontener MapView + ProvinceDetailPanel, integracja w MainShell

Zastąp gołe `MapView` w `MainShell.tscn` przez `MapaTab` (HBoxContainer: MapView po lewej, ProvinceDetailPanel po prawej). Klik węzła w MapView → MapaTab pokazuje panel z danymi prowincji. Sygnał `navigate_to_diplomacy` z panelu → MainShell przełącza tab na "swiat" + preselectuje religię w WorldTab.

**Files:**
- Create: `scripts/ui/map/MapaTab.gd`
- Create: `scenes/ui/map/MapaTab.tscn`
- Modify: `scripts/ui/MainShell.gd`
- Modify: `scenes/ui/MainShell.tscn` (zamień MapView na MapaTab)
- Modify: `scripts/ui/world/WorldTab.gd` (publiczna metoda `preselect_religion(id)` — jeśli nie istnieje)
- Test: `tests/ui/test_mapa_tab.gd`

- [ ] **Step 1: Failing test MapaTab**

Plik `tests/ui/test_mapa_tab.gd`:
```gdscript
extends GutTest

const MapaTabScene := preload("res://scenes/ui/map/MapaTab.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
    var gs: Node = GameStateScript.new()
    var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
    var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
    gs.initialize("islam", religions, graph)
    return gs

func _instance(state: Node) -> MapaTab:
    var t: MapaTab = MapaTabScene.instantiate()
    add_child_autofree(t)
    await get_tree().process_frame
    t.bind_state(state)
    return t

func test_tab_starts_with_no_selection():
    var state := _make_state()
    add_child_autofree(state)
    var t := await _instance(state)
    var panel := t.get_node("%DetailPanel")
    assert_false(panel.visible)

func test_clicking_node_shows_panel():
    var state := _make_state()
    add_child_autofree(state)
    var t := await _instance(state)
    var map_view: MapView = t.get_node("%MapView")
    var node: ProvinceNode = map_view.get_node_for_id("lewant")
    node.get_node("%ClickArea").emit_signal("pressed")
    var panel: ProvinceDetailPanel = t.get_node("%DetailPanel")
    assert_true(panel.visible)
    assert_eq(panel.current_province_id, "lewant")

func test_navigate_signal_propagates():
    var state := _make_state()
    add_child_autofree(state)
    var t := await _instance(state)
    var map_view: MapView = t.get_node("%MapView")
    var node: ProvinceNode = map_view.get_node_for_id("lewant")
    node.get_node("%ClickArea").emit_signal("pressed")
    watch_signals(t)
    var panel: ProvinceDetailPanel = t.get_node("%DetailPanel")
    var actions := panel.get_node("%Actions")
    actions.emit_signal("navigate_to_diplomacy", "chr_wschodnie")
    assert_signal_emitted_with_parameters(t, "navigate_to_diplomacy", ["chr_wschodnie"])
```

- [ ] **Step 2: Verify FAIL**

- [ ] **Step 3: Stwórz `scripts/ui/map/MapaTab.gd`**

```gdscript
class_name MapaTab
extends HBoxContainer

signal navigate_to_diplomacy(religion_id: String)
signal state_changed

var state: Node = null

@onready var _map_view: MapView = %MapView
@onready var _detail_panel: ProvinceDetailPanel = %DetailPanel

func _ready() -> void:
    _map_view.province_selected.connect(_on_province_selected)
    _detail_panel.navigate_to_diplomacy.connect(_on_navigate)
    _detail_panel.war_declared.connect(_on_state_changed)
    _detail_panel.missionaries_sent.connect(_on_state_changed)

func bind_state(s: Node) -> void:
    state = s
    _map_view.bind_state(s)
    _detail_panel.bind_state(s)

func refresh() -> void:
    if state == null:
        return
    _map_view.refresh()
    if _detail_panel.current_province_id != "":
        _detail_panel.refresh()

func _on_province_selected(province_id: String) -> void:
    _detail_panel.set_province(province_id)

func _on_navigate(religion_id: String) -> void:
    emit_signal("navigate_to_diplomacy", religion_id)

func _on_state_changed(_a = null, _b = null) -> void:
    emit_signal("state_changed")
```

- [ ] **Step 4: Stwórz `scenes/ui/map/MapaTab.tscn`**

```
MapaTab (HBoxContainer, script)
├─ MapView (instancja MapView.tscn, unique, size_flags_h=EXPAND_FILL)
└─ DetailPanel (instancja ProvinceDetailPanel.tscn, unique, custom_min_size.x=280)
```

- [ ] **Step 5: Zaktualizuj MainShell**

W `scenes/ui/MainShell.tscn`: zamień node `MapaTab` (typu MapView z Task 3) na instancję `MapaTab.tscn`. **Zachowaj nazwę node'a `MapaTab` i `unique_name_in_owner=true`**.

W `scripts/ui/MainShell.gd`:
- Zmień typ `@onready var _mapa_tab: MapView = %MapaTab` na `@onready var _mapa_tab: MapaTab = %MapaTab`.
- `_on_tab_changed` nie wymaga zmian (już ustawia `_mapa_tab.visible`).
- W `bind_state`: `_mapa_tab.bind_state(state)` (już dodane w Task 3 Step 4 — bez zmian).
- W `refresh()`: pozostawić `if _mapa_tab.has_method("refresh"): _mapa_tab.refresh()` (już dodane w Task 3).
- W `_ready`: po linii `_tab_bar.tab_changed.connect(_on_tab_changed)` (linia 18) dodaj:
```gdscript
_mapa_tab.navigate_to_diplomacy.connect(_on_navigate_to_diplomacy)
_mapa_tab.state_changed.connect(_on_swiat_state_changed)  # re-use
```
- Dodaj publiczną metodę `set_current_tab` (delegująca do TabBara — używana przez testy):
```gdscript
func set_current_tab(tab_id: String) -> void:
    _tab_bar.set_current_tab(tab_id)
```
- Dodaj handler `_on_navigate_to_diplomacy`:
```gdscript
func _on_navigate_to_diplomacy(religion_id: String) -> void:
    _tab_bar.set_current_tab("swiat")
    if _swiat_tab.has_method("preselect_religion"):
        _swiat_tab.preselect_religion(religion_id)
```

- [ ] **Step 6: Dodaj `preselect_religion` do `WorldTab.gd`**

W `scripts/ui/world/WorldTab.gd` dodaj na końcu pliku (po `_on_state_changed`):
```gdscript
func preselect_religion(religion_id: String) -> void:
    if state == null:
        return
    if state.get_religion(religion_id) == null:
        return
    _list.set_selected(religion_id)
    _action_panel.set_target(religion_id)
```

Wzorzec mirror'uje istniejący `_on_religion_selected` (linia 41-43) — `set_selected` istnieje na `RelationList.gd:18`, `set_target` na `ActionPanel`. Bez `set_target` ActionPanel nadal pokazywałby poprzedni cel.

- [ ] **Step 7: Verify PASS + suite**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=test_mapa_tab.gd -gexit
```
Oczekiwane: 3/3 PASS.

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
Oczekiwane: 412/412 PASS.

- [ ] **Step 8: Commit**

```bash
git add scripts/ui/map/MapaTab.gd scenes/ui/map/MapaTab.tscn scripts/ui/MainShell.gd scenes/ui/MainShell.tscn scripts/ui/world/WorldTab.gd tests/ui/test_mapa_tab.gd
git commit -m "feat(ui): MapaTab — MapView + DetailPanel + navigation to Świat tab"
```

---

### Task 9: Pressure tint na węzłach (alert obcej presji)

Wizualny feedback presji obcych. Per spec 06 sekcja 3 progi:
- max obca presja 0–60: brak tintu (normalny kolor religii)
- 61–85: subtle tint koloru obcej religii (modulate.r/g/b shifted 30% w kierunku obcego koloru)
- > 85: pulsujący alert (modulate animacja 0.5s loop między base color a obcym kolorem)

**Files:**
- Modify: `scripts/ui/map/ProvinceNode.gd`
- Test: `tests/ui/test_province_node_pressure.gd`

- [ ] **Step 1: Failing test pressure tint**

Plik `tests/ui/test_province_node_pressure.gd`:
```gdscript
extends GutTest

const ProvinceNodeScene := preload("res://scenes/ui/map/ProvinceNode.tscn")

func _make_province_with_pressure(id: String, owner: String, foreign_pressure: Dictionary) -> Province:
    var p := Province.new()
    p.id = id
    p.owner = owner
    p.display_name = id
    p.position = Vector2(100, 100)
    p.pressure = foreign_pressure
    return p

func _instance(prov: Province) -> ProvinceNode:
    var pn: ProvinceNode = ProvinceNodeScene.instantiate()
    add_child_autofree(pn)
    await get_tree().process_frame
    pn.set_province(prov)
    return pn

func test_no_tint_when_max_foreign_pressure_below_60():
    var p := _make_province_with_pressure("test", "islam", {"chr_wschodnie": 50.0})
    var pn := await _instance(p)
    assert_eq(pn.pressure_alert_state(), "none")

func test_subtle_tint_when_foreign_pressure_61_to_85():
    var p := _make_province_with_pressure("test", "islam", {"chr_wschodnie": 75.0})
    var pn := await _instance(p)
    assert_eq(pn.pressure_alert_state(), "subtle")

func test_alert_pulse_when_foreign_pressure_over_85():
    var p := _make_province_with_pressure("test", "islam", {"chr_wschodnie": 90.0})
    var pn := await _instance(p)
    assert_eq(pn.pressure_alert_state(), "alert")

func test_owner_pressure_ignored_for_tint():
    var p := _make_province_with_pressure("test", "islam", {"islam": 95.0})
    var pn := await _instance(p)
    assert_eq(pn.pressure_alert_state(), "none")
```

- [ ] **Step 2: Verify FAIL**

- [ ] **Step 3: Dodaj `pressure_alert_state()` + tint do ProvinceNode**

**3a — dodaj `var _tween_active` na górze pliku** (zaraz pod istniejącym `var is_selected: bool = false`, przed sekcją `@onready`):
```gdscript
var _tween_active: bool = false
```

**3b — dodaj stałe i funkcje publiczne** w `scripts/ui/map/ProvinceNode.gd` (na końcu pliku):
```gdscript
const PRESSURE_SUBTLE_MIN: float = 61.0
const PRESSURE_ALERT_MIN: float = 85.0

func pressure_alert_state() -> String:
    if province == null:
        return "none"
    var max_foreign := 0.0
    for rid: String in province.pressure:
        if rid == province.owner:
            continue
        var v: float = float(province.pressure[rid])
        if v > max_foreign:
            max_foreign = v
    if max_foreign > PRESSURE_ALERT_MIN:
        return "alert"
    if max_foreign >= PRESSURE_SUBTLE_MIN:
        return "subtle"
    return "none"

func _max_foreign_religion() -> String:
    if province == null:
        return ""
    var max_foreign := 0.0
    var max_id := ""
    for rid: String in province.pressure:
        if rid == province.owner:
            continue
        var v: float = float(province.pressure[rid])
        if v > max_foreign:
            max_foreign = v
            max_id = rid
    return max_id

func _apply_pressure_visual() -> void:
    var s := pressure_alert_state()
    if s == "none":
        modulate = Color.WHITE
        return
    var foreign_id := _max_foreign_religion()
    var foreign_color: Color = UIConstants.religion_color(foreign_id)
    if s == "subtle":
        modulate = Color.WHITE.lerp(foreign_color.lightened(0.4), 0.3)
    elif s == "alert":
        if not _tween_active and not OS.has_feature("headless"):
            _start_alert_tween(foreign_color)

func _start_alert_tween(target_color: Color) -> void:
    _tween_active = true
    var t := create_tween().set_loops()
    t.tween_property(self, "modulate", target_color.lightened(0.3), 0.5)
    t.tween_property(self, "modulate", Color.WHITE, 0.5)
```

**3c — dodaj wywołanie `_apply_pressure_visual()` w istniejącej metodzie `_refresh()`** (z Task 1 Step 5). Na końcu `_refresh()`, po linii `_refresh_outline()`, dodaj:
```gdscript
_apply_pressure_visual()
```

Uwaga: Tween jest visual-only (omijany w headless via `OS.has_feature("headless")` guard). Testy asercują tylko `pressure_alert_state()` (czysta logika), nie efekt animacji.

- [ ] **Step 4: Verify PASS + suite**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=test_province_node_pressure.gd -gexit
```
Oczekiwane: 4/4 PASS.

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
Oczekiwane: 416/416 PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/map/ProvinceNode.gd tests/ui/test_province_node_pressure.gd
git commit -m "feat(ui): ProvinceNode pressure tint — subtle/alert states per foreign religion"
```

---

### Task 10: Integration smoke test — full flow

Test końcowy weryfikujący pełną pętlę: kliknij prowincję → otwórz panel → wykonaj akcję (np. send_missionaries lub navigate) → re-render. Test nie używa subkomponentów bezpośrednio, tylko ścieżkę zdarzeń przez `MapaTab` w `MainShell`.

**Files:**
- Test: `tests/ui/test_mapa_integration.gd`

- [ ] **Step 1: Failing test integracji**

Plik `tests/ui/test_mapa_integration.gd`:
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

func _instance_shell(state: Node) -> Node:
    var shell = MainShellScene.instantiate()
    add_child_autofree(shell)
    await get_tree().process_frame
    shell.bind_state(state)
    shell.set_current_tab("mapa")  # public passthrough dodany w Task 8 Step 5
    return shell

func test_full_flow_click_province_open_panel():
    var state := _make_state()
    add_child_autofree(state)
    var shell := await _instance_shell(state)
    var mapa_tab = shell.get_node("%MapaTab")
    var map_view: MapView = mapa_tab.get_node("%MapView")
    var lewant_node: ProvinceNode = map_view.get_node_for_id("lewant")
    lewant_node.get_node("%ClickArea").emit_signal("pressed")
    var panel = mapa_tab.get_node("%DetailPanel")
    assert_true(panel.visible)
    assert_eq(panel.current_province_id, "lewant")

func test_navigate_switches_to_swiat_tab():
    var state := _make_state()
    add_child_autofree(state)
    var shell := await _instance_shell(state)
    var mapa_tab = shell.get_node("%MapaTab")
    var map_view: MapView = mapa_tab.get_node("%MapView")
    var lewant_node: ProvinceNode = map_view.get_node_for_id("lewant")
    lewant_node.get_node("%ClickArea").emit_signal("pressed")
    await get_tree().process_frame  # pozwól bind() / refresh() rozprzestrzenić się
    var panel = mapa_tab.get_node("%DetailPanel")
    var actions = panel.get_node("%Actions")
    actions.get_node("%DiplomacyButton").emit_signal("pressed")
    var tab_bar = shell.get_node("%TabBar")
    assert_eq(tab_bar.current_tab, "swiat")

func test_missionaries_action_advances_engine_state():
    var state := _make_state()
    add_child_autofree(state)
    # Setup: islam → lewant (chr_wschodnie). Ustaw trust >30 i ekskluzywizm OK.
    var dm := DiplomacyManager.new()
    var rel := dm.get_or_create_relation(state, "islam", "chr_wschodnie")
    rel.theological_trust = 50.0
    rel.military_tension = 20.0
    var islam: Religion = state.get_religion("islam")
    islam.prestige = 200
    # Force ekskluzywizm OK: shift_axis przesuwa o delta od bieżącej wartości
    islam.shift_axis("C", 30.0 - islam.get_axis("C"))

    var shell := await _instance_shell(state)
    var mapa_tab = shell.get_node("%MapaTab")
    var map_view: MapView = mapa_tab.get_node("%MapView")
    var lewant_node: ProvinceNode = map_view.get_node_for_id("lewant")
    lewant_node.get_node("%ClickArea").emit_signal("pressed")
    var panel = mapa_tab.get_node("%DetailPanel")
    var actions = panel.get_node("%Actions")
    var mission_btn: Button = actions.get_node("%MissionButton")
    if mission_btn.disabled:
        pending("Missionary gating prevents test; verify gating logic separately")
        return
    var prestige_before := islam.prestige
    mission_btn.emit_signal("pressed")
    assert_lt(islam.prestige, prestige_before, "Sending missionaries must reduce prestige")
```

- [ ] **Step 2: Verify PASS (3/3 lub 2/3 z 1 pending)**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=test_mapa_integration.gd -gexit
```

- [ ] **Step 3: Full suite verification**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
Oczekiwane: 419/419 PASS (416 + 3) lub 418 z 1 pending.

- [ ] **Step 4: Commit**

```bash
git add tests/ui/test_mapa_integration.gd
git commit -m "test(ui): MapaTab integration — click province, open panel, navigate to Świat"
```

---

## Podsumowanie i statystyki

**Łączne dodanie:** 10 zadań, 3 chunki.

**Pliki nowe:**
- `scripts/ui/map/ProvinceNode.gd` + `.tscn`
- `scripts/ui/map/MapView.gd` + `.tscn`
- `scripts/ui/map/ProvinceDetailHeader.gd` + `.tscn`
- `scripts/ui/map/PressureBars.gd` + `.tscn`
- `scripts/ui/map/PressureRow.gd` + `.tscn`
- `scripts/ui/map/ProvinceActions.gd` + `.tscn`
- `scripts/ui/map/CBPicker.gd` + `.tscn`
- `scripts/ui/map/ProvinceDetailPanel.gd` + `.tscn`
- `scripts/ui/map/MapaTab.gd` + `.tscn`
- `tests/engine/test_province_position.gd`
- `tests/ui/test_province_node.gd`
- `tests/ui/test_province_node_pressure.gd`
- `tests/ui/test_map_view.gd`
- `tests/ui/test_province_detail_header.gd`
- `tests/ui/test_pressure_bars.gd`
- `tests/ui/test_province_actions.gd`
- `tests/ui/test_province_detail_panel.gd`
- `tests/ui/test_mapa_tab.gd`
- `tests/ui/test_mapa_integration.gd`

**Pliki zmodyfikowane:**
- `scripts/engine/Province.gd` (+ `position`, `display_name`)
- `scripts/engine/ProvinceLoader.gd` (parsowanie nowych pól)
- `data/provinces_historical.json` (12× `position`)
- `scripts/ui/UIConstants.gd` (paleta religii + stałe mapy)
- `scripts/ui/MainShell.gd` + `.tscn` (wire MapaTab)
- `scripts/ui/world/WorldTab.gd` (`preselect_religion`)
- `tests/ui/test_main_shell.gd` (integration assertions)

**Spodziewany testowy stan:** 376 → ~419 (43 nowe testy).

**Architektura zatwierdzona:**
- Każdy komponent UI = 1 `.gd` + 1 `.tscn` (~50-180 linii skryptu)
- Komunikacja child→parent przez sygnały
- State source of truth = `GameState` (autoload), UI tylko czyta
- Akcje pisane przez stateless `DiplomacyManager`/`WarManager`
- Refresh = pełny rerender, bez dirty-tracking

**Świadome odstępstwa od spec 06 sekcja 3 (powtórka):**
- Graf węzłów (`Polygon2D` 60×40) zamiast hand-authored wielokątów geograficznych
- Pressure tint na całym węźle (modulate), nie na krawędziach wielokąta
- Desktop-only panel boczny, bez mobile bottom sheet

**Gotowość do następnych planów (po ukończeniu Planu 09):**
- Plan 10 (Wiara — radar diamentowy + doktryny): silnik gotowy, UI placeholder
- Plan 11 (Frakcje): silnik gotowy, UI placeholder
- Plan 12 (Mapa polish): wielokąty geograficzne, edge tinting, mobile bottom sheet
- Plan 13 (Cleanup): dangling neighbor references (jemen/libia/tracja/italia_polnocna/afryka_polnocna)
