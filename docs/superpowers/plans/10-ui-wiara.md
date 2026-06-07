# Plan 10 — UI Wiara Implementation Plan

> **For Claude:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Zaimplementować zakładkę Wiara — read-only widok profilu teologicznego religii gracza (radar 4 osi + karta traitu + lista doktryn).

**Architecture:** 5 komponentów UI w `scripts/ui/wiara/` (AxisRadar, TraitCard, DoctrineRow, DoctrineList, WiaraTab) + dodatki do `UIConstants` (TRAIT_INFO, DOCTRINE_INFO, RELIGION_ACCENT_COLORS) + integracja z `MainShell`. Każdy komponent ma `bind_state(state) + refresh()`. Diament radar rysowany Polygon2D + Line2D w 400×400 `Control`. Brak własnego sygnału `state_changed` — zakładka read-only, nie mutuje GameState.

**Tech Stack:** Godot 4.6.3, GDScript 2.0, GUT (Godot Unit Testing).

**Spec:** [`docs/superpowers/specs/10-ui-wiara-design.md`](../specs/10-ui-wiara-design.md)

---

## Convention reminders (z [CLAUDE.md](../../../CLAUDE.md))

- **Tab indent** w `.gd` i `.tscn`.
- **`class_name`** na każdym skrypcie UI.
- **`unique_name_in_owner = true` + `%Name`** dla nazwanych dzieci w scenach.
- **Setters guard with `is_inside_tree()`** przed `@onready` (precedens: `RelationListItem.gd`, `PressureRow.gd`).
- **`emit_signal("name", args)`** (forma stringowa) — używamy tylko w `MainShell` integracji.
- **Polish** w commitach i user-facing string; English w identyfikatorach.
- **Class cache caveat:** po utworzeniu nowego `class_name` skryptu headless GUT może rzucać "Could not find type X". Otwórz raz `godot --headless --path . --quit` aby zregenerować `.godot/global_script_class_cache.cfg`.

---

## Test command reference

```bash
# Cała sweet (wzrost: 429 → ~445)
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# Pojedynczy plik testu (zawsze res://-absolutna ścieżka)
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_axis_radar.gd -gexit

# Subkatalog
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gexit
```

---

## Test helper pattern (kopiować do każdego nowego pliku testu)

Wszystkie testy używają tego samego pattern do utworzenia GameState:

```gdscript
extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs
```

(Precedens: `tests/ui/test_map_view.gd`, `tests/ui/test_header.gd`.)

---

## File Structure

**Tworzone:**

```
scripts/ui/wiara/
├── AxisRadar.gd
├── TraitCard.gd
├── DoctrineRow.gd
├── DoctrineList.gd
└── WiaraTab.gd

scenes/ui/wiara/
├── AxisRadar.tscn
├── TraitCard.tscn
├── DoctrineRow.tscn
├── DoctrineList.tscn
└── WiaraTab.tscn

tests/ui/
├── test_axis_radar.gd
├── test_trait_card.gd
├── test_doctrine_row.gd
├── test_doctrine_list.gd
├── test_doctrine_info_parity.gd
└── test_wiara_tab.gd
```

**Modyfikowane:**
- `scripts/ui/UIConstants.gd` — `TRAIT_INFO`, `DOCTRINE_INFO`, `RELIGION_ACCENT_COLORS` + helper `religion_accent_color()`.
- `scripts/ui/MainShell.gd` — typ `_wiara_tab`, `bind_state`, `refresh`, usunięcie `set_title`.
- `scenes/ui/MainShell.tscn` — `ExtResource` na `WiaraTab.tscn` zamiast `PlaceholderTab.tscn` dla węzła `WiaraTab`.

---

## Chunk 1: Foundation + AxisRadar

---

### Task 0: UIConstants — TRAIT_INFO + DOCTRINE_INFO + RELIGION_ACCENT_COLORS + parity test

**Cel:** Dodać kompletne dane referencyjne dla traitów, doktryn i kolorów akcentu. Test parytetu zapewnia, że `DOCTRINE_INFO` zawsze odpowiada `DoctrineManager.AXIS_THRESHOLDS`.

**Files:**
- Modify: `scripts/ui/UIConstants.gd`
- Create: `tests/ui/test_doctrine_info_parity.gd`

- [ ] **Step 1: Napisz failing test parytetu**

Stwórz `tests/ui/test_doctrine_info_parity.gd`:

```gdscript
extends GutTest

func test_every_axis_threshold_action_has_doctrine_info_entry():
	var dm := DoctrineManager.new()
	for axis: String in dm.AXIS_THRESHOLDS.keys():
		var rules: Array = dm.AXIS_THRESHOLDS[axis]
		for rule: Dictionary in rules:
			var op := "min" if rule.has("min") else "max"
			var threshold: float = rule.get("min", rule.get("max", 0.0))
			for action_id: String in rule["actions"]:
				assert_true(UIConstants.DOCTRINE_INFO.has(action_id),
					"DOCTRINE_INFO missing entry for action_id: " + action_id)
				var info: Dictionary = UIConstants.DOCTRINE_INFO[action_id]
				assert_eq(info.get("axis", ""), axis,
					action_id + ": axis mismatch")
				assert_eq(info.get("op", ""), op,
					action_id + ": op mismatch")
				assert_eq(info.get("threshold", -1.0), threshold,
					action_id + ": threshold mismatch")

func test_every_doctrine_info_entry_has_matching_axis_threshold():
	var dm := DoctrineManager.new()
	for action_id: String in UIConstants.DOCTRINE_INFO.keys():
		var info: Dictionary = UIConstants.DOCTRINE_INFO[action_id]
		var axis: String = info["axis"]
		var op: String = info["op"]
		var threshold: float = info["threshold"]
		assert_true(dm.AXIS_THRESHOLDS.has(axis),
			"AXIS_THRESHOLDS missing axis " + axis + " for " + action_id)
		var found := false
		for rule: Dictionary in dm.AXIS_THRESHOLDS[axis]:
			var rule_op := "min" if rule.has("min") else "max"
			var rule_threshold: float = rule.get("min", rule.get("max", 0.0))
			if rule_op == op and rule_threshold == threshold:
				if action_id in rule["actions"]:
					found = true
					break
		assert_true(found, action_id + " not found in AXIS_THRESHOLDS[" + axis + "]")

func test_trait_info_has_entries_for_all_historical_religions():
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	for r: Religion in religions:
		assert_true(UIConstants.TRAIT_INFO.has(r.trait_id),
			"TRAIT_INFO missing entry for trait_id: " + r.trait_id)
		var info: Dictionary = UIConstants.TRAIT_INFO[r.trait_id]
		assert_ne(info.get("name", ""), "", r.trait_id + ": missing name")
		assert_ne(info.get("description", ""), "", r.trait_id + ": missing description")

func test_religion_accent_color_returns_color_for_known_id():
	var c := UIConstants.religion_accent_color("islam")
	assert_typeof(c, TYPE_COLOR)

func test_religion_accent_color_returns_default_for_unknown_id():
	var c := UIConstants.religion_accent_color("nonexistent")
	assert_eq(c, UIConstants.RELIGION_ACCENT_COLOR_DEFAULT)
```

- [ ] **Step 2: Uruchom test — oczekuj FAIL**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_doctrine_info_parity.gd -gexit
```

Oczekiwane: FAIL z "DOCTRINE_INFO missing..." lub "TRAIT_INFO missing..." lub "religion_accent_color not found".

- [ ] **Step 3: Rozszerz `scripts/ui/UIConstants.gd`**

Dodaj na końcu pliku (po istniejącym `static func religion_color`):

```gdscript
# Kolory akcentu religii (per spec 06 sekcja 3 — outline radaru, obrysy, akcenty)
const RELIGION_ACCENT_COLORS: Dictionary = {
	"islam": Color("5aaa5a"),
	"chr_zachodnie": Color("7a7aff"),
	"chr_wschodnie": Color("6a6aee"),
	"judaizm": Color("bbaa00"),
	"zoroastryzm": Color("cc7a1a"),
	"koptyjski": Color("4aaa6a"),
	"manicheizm": Color("cc55cc"),
	"religie_arabskie": Color("dd9922"),
	"hinduizm": Color("ee5533"),
	"buddyzm": Color("33bbcc"),
	"religie_germanskie": Color("88cc44"),
	"religie_slowianskie": Color("55bb88"),
}
const RELIGION_ACCENT_COLOR_DEFAULT: Color = Color(0.7, 0.7, 0.7)

static func religion_accent_color(religion_id: String) -> Color:
	return RELIGION_ACCENT_COLORS.get(religion_id, RELIGION_ACCENT_COLOR_DEFAULT)

# Trait info — 12 wpisów, wiernie zsumaryzowane z 05-religion-profiles-design.md
const TRAIT_INFO: Dictionary = {
	"umma": {
		"name": "Umma",
		"description": "Próg CB Dżihadu obniżony o dodatkowe −5 (łącznie −15). Kontrola Mekki: każda prowincja Islamu globalnie +1 prestiż/turę.",
	},
	"cezaropapizm": {
		"name": "Cezaropapizm",
		"description": "Cesarz może zwołać Sobór raz na epokę za darmo. Napięcie przegranej frakcji ×2.",
	},
	"sukcesja_apostolska": {
		"name": "Sukcesja Apostolska",
		"description": "Klienci uznający Rzym jako patrona: −10% odporności na Synkretyzm. Rzym zyskuje +5 prestiżu za każde nowe Uznanie.",
	},
	"diaspora": {
		"name": "Diaspora",
		"description": "Prowincje utracone nadal generują +1 prestiż/turę. Synagogi w obcych prowincjach (10 złota): +0.5 presji/turę.",
	},
	"zmartwychwstanie_saszanskie": {
		"name": "Zmartwychwstanie Saszańskie",
		"description": "Przy <5 prowincjach: pasywna presja sąsiedzka ×2. Kontrola persepolis: +10% Modyfikator CB we wszystkich kampaniach.",
	},
	"pamiec_pustynna": {
		"name": "Pamięć Pustynna",
		"description": "Akcja [Ojciec Pustyni] (15 prestiżu): mnich do prowincji w odległości do 3 kroków grafu. Po 5 turach +20 presji jednorazowo.",
	},
	"synkretyzm_radykalny": {
		"name": "Synkretyzm Radykalny",
		"description": "Akcja [Zaakceptuj Ideę] bez kosztu prestiżu. Może absorbować doktryny od 2 religii naraz. +5 napięcia Wybranych.",
	},
	"pluralizm_plemienny": {
		"name": "Pluralizm Plemienny",
		"description": "Misjonarze bez limitu liczby. 40% szansy „schizmy plemiennej" przy każdym zdobyciu nowej prowincji.",
	},
	"dharma_i_varna": {
		"name": "Dharma i Varna",
		"description": "Immunizacja na obowiązkowe CB doktrynalne. Prowincja kontrolowana 10+ tur: +2 żywność. Konwersja przez najeźdźcę: +20% kosztu presji.",
	},
	"srodkowa_droga": {
		"name": "Środkowa Droga",
		"description": "Immunizacja na obowiązkowe CB doktrynalne. Akcja [Dharma-Yatra] (25 prestiżu): pielgrzymi przez do 5 kroków grafu.",
	},
	"ragnarok": {
		"name": "Ragnarök",
		"description": "Po utracie >50% prowincji startowych: tryb [Zmierzch Bogów] — Modyfikator CB +20%, zmęczenie wojenne narasta 50% wolniej.",
	},
	"ziemia_i_krew": {
		"name": "Ziemia i Krew",
		"description": "Prowincje góry/pustynia/żyzne: +1 żywność extra. Atak na słowiańską prowincję: dodatkowe −10% siły najeźdźcy.",
	},
}

# Doctrine info — 8 wpisów, parytet z DoctrineManager.AXIS_THRESHOLDS (test_doctrine_info_parity.gd)
const DOCTRINE_INFO: Dictionary = {
	"kanon_doktryny": {
		"name": "Kanon Doktrynalny",
		"axis": "A", "op": "min", "threshold": 75.0,
		"description": "Ortodoksja chroni przed obcymi ideami.",
	},
	"objawienie": {
		"name": "Objawienie Mistyczne",
		"axis": "A", "op": "max", "threshold": 25.0,
		"description": "Mistyczna interpretacja otwiera nowe doktryny.",
	},
	"papieskie_interdykty": {
		"name": "Papieskie Interdykty",
		"axis": "B", "op": "min", "threshold": 75.0,
		"description": "Hierarchia może rzucać Interdykt.",
	},
	"sobor_ludowy": {
		"name": "Sobór Ludowy",
		"axis": "B", "op": "max", "threshold": 25.0,
		"description": "Egalitarne sobory tańsze o połowę.",
	},
	"ekumenizm": {
		"name": "Ekumenizm",
		"axis": "C", "op": "min", "threshold": 75.0,
		"description": "Łatwiejsza absorpcja doktryn obcych religii.",
	},
	"obrzad_fuzji": {
		"name": "Obrzęd Fuzji",
		"axis": "C", "op": "min", "threshold": 75.0,
		"description": "Możliwa fuzja z religią synkretyczną.",
	},
	"inkwizycja": {
		"name": "Inkwizycja",
		"axis": "C", "op": "max", "threshold": 25.0,
		"description": "Schizmy odpierane brutalnie.",
	},
	"klatwa": {
		"name": "Klątwa",
		"axis": "C", "op": "max", "threshold": 25.0,
		"description": "Można rzucić klątwę na heretyka.",
	},
}
```

- [ ] **Step 4: Uruchom test — oczekuj PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_doctrine_info_parity.gd -gexit
```

Oczekiwane: 5/5 passing.

- [ ] **Step 5: Uruchom całą suitę — sprawdź brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Oczekiwane: wszystkie wcześniejsze testy + 5 nowych = passing.

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/UIConstants.gd tests/ui/test_doctrine_info_parity.gd
git commit -m "$(cat <<'EOF'
feat(ui): UIConstants — TRAIT_INFO, DOCTRINE_INFO, RELIGION_ACCENT_COLORS

12 traitów z wiernymi opisami z spec 05-religion-profiles-design.md.
8 doktryn parytetycznych z DoctrineManager.AXIS_THRESHOLDS — test pilnuje,
ze obie strony trzymaja te same axis/op/threshold. Paleta akcentu (per
spec 06 sekcja 3) + helper religion_accent_color() analogiczny do
istniejacego religion_color().
EOF
)"
```

---

### Task 1: AxisRadar — diament 4 osi

**Cel:** Komponent rysujący diament wartości osi (Polygon2D + Line2D w 400×400 Control) z 4 etykietami + tabelą wartości pod spodem.

**Files:**
- Create: `scripts/ui/wiara/AxisRadar.gd`
- Create: `scenes/ui/wiara/AxisRadar.tscn`
- Test: `tests/ui/test_axis_radar.gd`

- [ ] **Step 1: Napisz failing test**

Stwórz `tests/ui/test_axis_radar.gd`:

```gdscript
extends GutTest

const AxisRadarScene := preload("res://scenes/ui/wiara/AxisRadar.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func _instance_radar(state: Node) -> AxisRadar:
	var r: AxisRadar = AxisRadarScene.instantiate()
	add_child_autofree(r)
	await get_tree().process_frame
	r.bind_state(state)
	return r

func test_radar_renders_without_state():
	var r: AxisRadar = AxisRadarScene.instantiate()
	add_child_autofree(r)
	await get_tree().process_frame
	# Brak crasha gdy state == null
	assert_not_null(r)

func test_radar_value_polygon_has_4_vertices_at_axis_radii():
	var state := _make_state()
	add_child_autofree(state)
	var r := await _instance_radar(state)
	var poly: Polygon2D = r.get_node("%ValuePolygon")
	assert_eq(poly.polygon.size(), 4)
	# Islam: A=70, B=65, C=30, D=75 (z religions_historical.json)
	# A (góra)  → (200, 200 - 70/100*160) = (200, 88)
	# B (prawo) → (200 + 65/100*160, 200) = (304, 200)
	# C (dół)   → (200, 200 + 30/100*160) = (200, 248)
	# D (lewo)  → (200 - 75/100*160, 200) = (80, 200)
	assert_almost_eq(poly.polygon[0].x, 200.0, 0.5)
	assert_almost_eq(poly.polygon[0].y, 88.0, 0.5)
	assert_almost_eq(poly.polygon[1].x, 304.0, 0.5)
	assert_almost_eq(poly.polygon[2].y, 248.0, 0.5)
	assert_almost_eq(poly.polygon[3].x, 80.0, 0.5)

func test_radar_outline_color_matches_religion_accent():
	var state := _make_state()
	add_child_autofree(state)
	var r := await _instance_radar(state)
	var outline: Line2D = r.get_node("%ValueOutline")
	assert_eq(outline.default_color, UIConstants.religion_accent_color("islam"))

func test_radar_value_labels_show_axis_values():
	var state := _make_state()
	add_child_autofree(state)
	var r := await _instance_radar(state)
	assert_eq(r.get_node("%ValueLabelA").text, "A: 70")
	assert_eq(r.get_node("%ValueLabelB").text, "B: 65")
	assert_eq(r.get_node("%ValueLabelC").text, "C: 30")
	assert_eq(r.get_node("%ValueLabelD").text, "D: 75")

func test_radar_refresh_updates_polygon_on_axis_change():
	var state := _make_state()
	add_child_autofree(state)
	var r := await _instance_radar(state)
	state.get_player_religion().axes["A"] = 100.0
	r.refresh()
	var poly: Polygon2D = r.get_node("%ValuePolygon")
	# A=100 → (200, 200 - 160) = (200, 40)
	assert_almost_eq(poly.polygon[0].y, 40.0, 0.5)
	assert_eq(r.get_node("%ValueLabelA").text, "A: 100")

func test_radar_handles_zero_axis_value():
	var state := _make_state()
	add_child_autofree(state)
	state.get_player_religion().axes["A"] = 0.0
	var r := await _instance_radar(state)
	var poly: Polygon2D = r.get_node("%ValuePolygon")
	# A=0 → (200, 200) (centrum)
	assert_almost_eq(poly.polygon[0].x, 200.0, 0.5)
	assert_almost_eq(poly.polygon[0].y, 200.0, 0.5)
```

- [ ] **Step 2: Uruchom test — oczekuj FAIL**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_axis_radar.gd -gexit
```

Oczekiwane: FAIL z "AxisRadar not found" lub "scene not loadable".

- [ ] **Step 3: Stwórz `scripts/ui/wiara/AxisRadar.gd`**

```gdscript
class_name AxisRadar
extends Control

const CENTER: Vector2 = Vector2(200, 200)
const MAX_RADIUS: float = 160.0

var state: Node = null

@onready var _value_polygon: Polygon2D = %ValuePolygon
@onready var _value_outline: Line2D = %ValueOutline
@onready var _label_a: Label = %ValueLabelA
@onready var _label_b: Label = %ValueLabelB
@onready var _label_c: Label = %ValueLabelC
@onready var _label_d: Label = %ValueLabelD

func bind_state(s: Node) -> void:
	state = s
	if not is_inside_tree():
		return
	refresh()

func _ready() -> void:
	if state != null:
		refresh()

func refresh() -> void:
	if state == null:
		return
	var religion: Religion = state.get_player_religion()
	if religion == null:
		return
	var vertices := _compute_vertices(religion.axes)
	_value_polygon.polygon = PackedVector2Array(vertices)
	_value_polygon.color = _with_alpha(UIConstants.religion_color(religion.id), 0.4)
	_value_outline.points = PackedVector2Array(vertices + [vertices[0]])
	_value_outline.default_color = UIConstants.religion_accent_color(religion.id)
	_label_a.text = "A: " + str(int(round(religion.get_axis("A"))))
	_label_b.text = "B: " + str(int(round(religion.get_axis("B"))))
	_label_c.text = "C: " + str(int(round(religion.get_axis("C"))))
	_label_d.text = "D: " + str(int(round(religion.get_axis("D"))))

func _compute_vertices(axes: Dictionary) -> Array[Vector2]:
	var ra: float = axes.get("A", 0.0) / 100.0 * MAX_RADIUS
	var rb: float = axes.get("B", 0.0) / 100.0 * MAX_RADIUS
	var rc: float = axes.get("C", 0.0) / 100.0 * MAX_RADIUS
	var rd: float = axes.get("D", 0.0) / 100.0 * MAX_RADIUS
	return [
		CENTER + Vector2(0, -ra),	# A — góra
		CENTER + Vector2(rb, 0),	# B — prawo
		CENTER + Vector2(0, rc),	# C — dół
		CENTER + Vector2(-rd, 0),	# D — lewo
	]

func _with_alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)
```

- [ ] **Step 4: Stwórz `scenes/ui/wiara/AxisRadar.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/wiara/AxisRadar.gd" id="1"]

[node name="AxisRadar" type="Control"]
script = ExtResource("1")
custom_minimum_size = Vector2(400, 480)

[node name="RadarArea" type="Control" parent="."]
custom_minimum_size = Vector2(400, 400)
mouse_filter = 2

[node name="GridPolygon25" type="Line2D" parent="RadarArea"]
unique_name_in_owner = true
points = PackedVector2Array(200, 160, 240, 200, 200, 240, 160, 200, 200, 160)
default_color = Color(0.27, 0.27, 0.27, 1)
width = 1.0

[node name="GridPolygon50" type="Line2D" parent="RadarArea"]
unique_name_in_owner = true
points = PackedVector2Array(200, 120, 280, 200, 200, 280, 120, 200, 200, 120)
default_color = Color(0.27, 0.27, 0.27, 1)
width = 1.0

[node name="GridPolygon75" type="Line2D" parent="RadarArea"]
unique_name_in_owner = true
points = PackedVector2Array(200, 80, 320, 200, 200, 320, 80, 200, 200, 80)
default_color = Color(0.27, 0.27, 0.27, 1)
width = 1.0

[node name="AxisLineA" type="Line2D" parent="RadarArea"]
points = PackedVector2Array(200, 200, 200, 40)
default_color = Color(0.4, 0.4, 0.4, 1)
width = 1.0

[node name="AxisLineB" type="Line2D" parent="RadarArea"]
points = PackedVector2Array(200, 200, 360, 200)
default_color = Color(0.4, 0.4, 0.4, 1)
width = 1.0

[node name="AxisLineC" type="Line2D" parent="RadarArea"]
points = PackedVector2Array(200, 200, 200, 360)
default_color = Color(0.4, 0.4, 0.4, 1)
width = 1.0

[node name="AxisLineD" type="Line2D" parent="RadarArea"]
points = PackedVector2Array(200, 200, 40, 200)
default_color = Color(0.4, 0.4, 0.4, 1)
width = 1.0

[node name="ValuePolygon" type="Polygon2D" parent="RadarArea"]
unique_name_in_owner = true
color = Color(1, 1, 1, 0.4)

[node name="ValueOutline" type="Line2D" parent="RadarArea"]
unique_name_in_owner = true
default_color = Color(1, 1, 1, 1)
width = 2.0

[node name="AxisLabelA" type="Label" parent="RadarArea"]
offset_left = 175.0
offset_top = 10.0
offset_right = 225.0
offset_bottom = 30.0
text = "Dogmatyzm"
horizontal_alignment = 1

[node name="AxisLabelB" type="Label" parent="RadarArea"]
offset_left = 365.0
offset_top = 190.0
offset_right = 405.0
offset_bottom = 210.0
text = "Hierarchia"

[node name="AxisLabelC" type="Label" parent="RadarArea"]
offset_left = 170.0
offset_top = 370.0
offset_right = 230.0
offset_bottom = 390.0
text = "Synkretyzm"
horizontal_alignment = 1

[node name="AxisLabelD" type="Label" parent="RadarArea"]
offset_left = 0.0
offset_top = 190.0
offset_right = 40.0
offset_bottom = 210.0
text = "Transcendencja"

[node name="ValueTable" type="HBoxContainer" parent="."]
offset_top = 410.0
offset_right = 400.0
offset_bottom = 460.0
alignment = 1

[node name="ValueLabelA" type="Label" parent="ValueTable"]
unique_name_in_owner = true
text = "A: 0"

[node name="Sep1" type="Label" parent="ValueTable"]
text = "  ·  "

[node name="ValueLabelB" type="Label" parent="ValueTable"]
unique_name_in_owner = true
text = "B: 0"

[node name="Sep2" type="Label" parent="ValueTable"]
text = "  ·  "

[node name="ValueLabelC" type="Label" parent="ValueTable"]
unique_name_in_owner = true
text = "C: 0"

[node name="Sep3" type="Label" parent="ValueTable"]
text = "  ·  "

[node name="ValueLabelD" type="Label" parent="ValueTable"]
unique_name_in_owner = true
text = "D: 0"
```

- [ ] **Step 5: Regeneruj class cache (jeśli potrzeba)**

```bash
godot --headless --path . --quit 2>/dev/null || true
```

- [ ] **Step 6: Uruchom test — oczekuj PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_axis_radar.gd -gexit
```

Oczekiwane: 6/6 passing.

- [ ] **Step 7: Commit**

```bash
git add scripts/ui/wiara/AxisRadar.gd scenes/ui/wiara/AxisRadar.tscn tests/ui/test_axis_radar.gd
git commit -m "$(cat <<'EOF'
feat(ui): AxisRadar — diament 4 osi profilu teologicznego

Polygon2D + Line2D outline w 400x400 Control + tabela wartosci pod spodem.
Centrum (200, 200), maksymalny promien 160 px (40 px padding na etykiety).
Wartosci osi mapowane: A=gora, B=prawo, C=dol, D=lewo. Wypelnienie z
religion_color, outline z religion_accent_color. Refresh przelicza
wierzcholki i etykiety na biezacych wartosciach religion.axes.
EOF
)"
```

---

## Chunk 2: TraitCard + DoctrineRow + DoctrineList

---

### Task 2: TraitCard — karta unikalnego traitu

**Cel:** Panel z nazwą i opisem traitu religii gracza. Dane z `UIConstants.TRAIT_INFO[religion.trait_id]`.

**Files:**
- Create: `scripts/ui/wiara/TraitCard.gd`
- Create: `scenes/ui/wiara/TraitCard.tscn`
- Test: `tests/ui/test_trait_card.gd`

- [ ] **Step 1: Napisz failing test**

Stwórz `tests/ui/test_trait_card.gd`:

```gdscript
extends GutTest

const TraitCardScene := preload("res://scenes/ui/wiara/TraitCard.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state(player_id: String = "islam") -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize(player_id, religions, graph)
	return gs

func _instance_card(state: Node) -> TraitCard:
	var c: TraitCard = TraitCardScene.instantiate()
	add_child_autofree(c)
	await get_tree().process_frame
	c.bind_state(state)
	return c

func test_card_renders_without_state():
	var c: TraitCard = TraitCardScene.instantiate()
	add_child_autofree(c)
	await get_tree().process_frame
	assert_not_null(c)

func test_card_shows_islam_umma_trait():
	var state := _make_state("islam")
	add_child_autofree(state)
	var c := await _instance_card(state)
	assert_eq(c.get_node("%NameLabel").text, "Umma")
	assert_string_contains(c.get_node("%DescriptionLabel").text, "Dżihadu")

func test_card_shows_chr_zachodnie_sukcesja_trait():
	var state := _make_state("chr_zachodnie")
	add_child_autofree(state)
	var c := await _instance_card(state)
	assert_eq(c.get_node("%NameLabel").text, "Sukcesja Apostolska")
	assert_string_contains(c.get_node("%DescriptionLabel").text, "Synkretyzm")

func test_card_handles_unknown_trait_id():
	var state := _make_state("islam")
	add_child_autofree(state)
	state.get_player_religion().trait_id = "nieznany_trait"
	var c := await _instance_card(state)
	# Fallback gdy trait_id nie istnieje w TRAIT_INFO — brak crasha
	assert_not_null(c.get_node("%NameLabel"))

func test_card_refresh_after_trait_change():
	var state := _make_state("islam")
	add_child_autofree(state)
	var c := await _instance_card(state)
	state.get_player_religion().trait_id = "diaspora"
	c.refresh()
	assert_eq(c.get_node("%NameLabel").text, "Diaspora")
```

- [ ] **Step 2: Uruchom test — oczekuj FAIL**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_trait_card.gd -gexit
```

Oczekiwane: FAIL ("TraitCard not found").

- [ ] **Step 3: Stwórz `scripts/ui/wiara/TraitCard.gd`**

```gdscript
class_name TraitCard
extends PanelContainer

var state: Node = null

@onready var _name_label: Label = %NameLabel
@onready var _description_label: Label = %DescriptionLabel

func bind_state(s: Node) -> void:
	state = s
	if not is_inside_tree():
		return
	refresh()

func _ready() -> void:
	if state != null:
		refresh()

func refresh() -> void:
	if state == null:
		return
	var religion: Religion = state.get_player_religion()
	if religion == null:
		return
	var info: Dictionary = UIConstants.TRAIT_INFO.get(religion.trait_id, {})
	_name_label.text = info.get("name", "(nieznany trait)")
	_description_label.text = info.get("description", "")
```

- [ ] **Step 4: Stwórz `scenes/ui/wiara/TraitCard.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/wiara/TraitCard.gd" id="1"]

[node name="TraitCard" type="PanelContainer"]
script = ExtResource("1")
custom_minimum_size = Vector2(0, 80)

[node name="VBox" type="VBoxContainer" parent="."]

[node name="NameLabel" type="Label" parent="VBox"]
unique_name_in_owner = true
text = "(brak)"
theme_override_font_sizes/font_size = 16

[node name="DescriptionLabel" type="Label" parent="VBox"]
unique_name_in_owner = true
text = ""
autowrap_mode = 3
theme_override_font_sizes/font_size = 12
```

- [ ] **Step 5: Uruchom test — oczekuj PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_trait_card.gd -gexit
```

Oczekiwane: 5/5 passing.

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/wiara/TraitCard.gd scenes/ui/wiara/TraitCard.tscn tests/ui/test_trait_card.gd
git commit -m "$(cat <<'EOF'
feat(ui): TraitCard — karta unikalnego traitu religii gracza

PanelContainer z nazwa (bold 16 px) i opisem (12 px, word wrap). Dane z
UIConstants.TRAIT_INFO[religion.trait_id]. Fallback "(nieznany trait)"
gdy id nie ma wpisu — bez crasha.
EOF
)"
```

---

### Task 3: DoctrineRow — pojedynczy wiersz doktryny

**Cel:** Wiersz z ikoną stanu (`◐`/`○`), nazwą doktryny i warunkiem osi. Tooltip z pełnym opisem.

**Files:**
- Create: `scripts/ui/wiara/DoctrineRow.gd`
- Create: `scenes/ui/wiara/DoctrineRow.tscn`
- Test: `tests/ui/test_doctrine_row.gd`

- [ ] **Step 1: Napisz failing test**

Stwórz `tests/ui/test_doctrine_row.gd`:

```gdscript
extends GutTest

const DoctrineRowScene := preload("res://scenes/ui/wiara/DoctrineRow.tscn")

func _instance_row() -> DoctrineRow:
	var r: DoctrineRow = DoctrineRowScene.instantiate()
	add_child_autofree(r)
	await get_tree().process_frame
	return r

func test_row_shows_available_state_when_min_threshold_met():
	var r := await _instance_row()
	r.set_doctrine("kanon_doktryny", 80.0)  # A=80 vs min 75 → dostępna
	assert_eq(r.get_node("%StateIcon").text, "◐")
	assert_eq(r.get_node("%NameLabel").text, "Kanon Doktrynalny")
	assert_string_contains(r.get_node("%ConditionLabel").text, "A")
	assert_string_contains(r.get_node("%ConditionLabel").text, "75")

func test_row_shows_locked_state_when_min_threshold_unmet():
	var r := await _instance_row()
	r.set_doctrine("kanon_doktryny", 50.0)  # A=50 vs min 75 → zablokowana
	assert_eq(r.get_node("%StateIcon").text, "○")

func test_row_shows_available_at_min_threshold_boundary():
	var r := await _instance_row()
	r.set_doctrine("kanon_doktryny", 75.0)  # boundary >= 75 → dostępna
	assert_eq(r.get_node("%StateIcon").text, "◐")

func test_row_shows_available_at_max_threshold_boundary():
	var r := await _instance_row()
	r.set_doctrine("objawienie", 25.0)  # boundary <= 25 → dostępna
	assert_eq(r.get_node("%StateIcon").text, "◐")

func test_row_locked_when_max_threshold_exceeded():
	var r := await _instance_row()
	r.set_doctrine("objawienie", 26.0)  # A=26 vs max 25 → zablokowana
	assert_eq(r.get_node("%StateIcon").text, "○")

func test_row_tooltip_contains_description():
	var r := await _instance_row()
	r.set_doctrine("kanon_doktryny", 80.0)
	assert_string_contains(r.tooltip_text, "Ortodoksja")

func test_row_handles_unknown_doctrine_id():
	var r := await _instance_row()
	r.set_doctrine("nieznany", 50.0)
	# Brak crasha; placeholder
	assert_not_null(r)
```

- [ ] **Step 2: Uruchom test — oczekuj FAIL**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_doctrine_row.gd -gexit
```

Oczekiwane: FAIL.

- [ ] **Step 3: Stwórz `scripts/ui/wiara/DoctrineRow.gd`**

```gdscript
class_name DoctrineRow
extends HBoxContainer

const ICON_AVAILABLE: String = "◐"
const ICON_LOCKED: String = "○"
const COLOR_AVAILABLE: Color = Color("dda820")
const COLOR_LOCKED: Color = Color(0.4, 0.4, 0.4)

var _action_id: String = ""
var _current_axis_value: float = 0.0

@onready var _state_icon: Label = %StateIcon
@onready var _name_label: Label = %NameLabel
@onready var _condition_label: Label = %ConditionLabel

func set_doctrine(action_id: String, axis_value: float) -> void:
	_action_id = action_id
	_current_axis_value = axis_value
	if not is_inside_tree():
		return
	refresh()

func _ready() -> void:
	if _action_id != "":
		refresh()

func refresh() -> void:
	var info: Dictionary = UIConstants.DOCTRINE_INFO.get(_action_id, {})
	if info.is_empty():
		_state_icon.text = ICON_LOCKED
		_name_label.text = "(nieznana doktryna)"
		_condition_label.text = ""
		tooltip_text = ""
		return
	var op: String = info.get("op", "min")
	var threshold: float = info.get("threshold", 0.0)
	var available := _is_available(op, threshold)
	_state_icon.text = ICON_AVAILABLE if available else ICON_LOCKED
	_state_icon.modulate = COLOR_AVAILABLE if available else COLOR_LOCKED
	_name_label.text = info.get("name", "")
	var op_glyph := "≥" if op == "min" else "≤"
	_condition_label.text = "wymaga " + info["axis"] + " " + op_glyph + " " + str(int(threshold))
	tooltip_text = info.get("description", "")

func _is_available(op: String, threshold: float) -> bool:
	if op == "min":
		return _current_axis_value >= threshold
	return _current_axis_value <= threshold
```

- [ ] **Step 4: Stwórz `scenes/ui/wiara/DoctrineRow.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/wiara/DoctrineRow.gd" id="1"]

[node name="DoctrineRow" type="HBoxContainer"]
script = ExtResource("1")

[node name="StateIcon" type="Label" parent="."]
unique_name_in_owner = true
text = "○"
custom_minimum_size = Vector2(24, 0)

[node name="NameLabel" type="Label" parent="."]
unique_name_in_owner = true
text = ""
custom_minimum_size = Vector2(180, 0)
size_flags_horizontal = 3

[node name="ConditionLabel" type="Label" parent="."]
unique_name_in_owner = true
text = ""
modulate = Color(0.7, 0.7, 0.7, 1)
theme_override_font_sizes/font_size = 10
```

- [ ] **Step 5: Uruchom test — oczekuj PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_doctrine_row.gd -gexit
```

Oczekiwane: 7/7 passing.

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/wiara/DoctrineRow.gd scenes/ui/wiara/DoctrineRow.tscn tests/ui/test_doctrine_row.gd
git commit -m "$(cat <<'EOF'
feat(ui): DoctrineRow — wiersz pojedynczej doktryny

HBox: ikona stanu (◐ zolty 'dostepna' / ○ szary 'zablokowana'), nazwa,
warunek osi (np. 'wymaga A ≥ 75'). Tooltip z pelnym opisem mechanicznym.
Operator >=/<= z granicami wlasciwie obslugiwany (wartosc rowna progowi
= dostepna). Fallback dla nieznanego action_id — bez crasha.
EOF
)"
```

---

### Task 4: DoctrineList — VBox z 8 wierszami doktryn

**Cel:** Lista 8 `DoctrineRow` z `UIConstants.DOCTRINE_INFO`, posortowana A→B→C / min→max / alfabet. Recalc stanu na każdy refresh.

**Files:**
- Create: `scripts/ui/wiara/DoctrineList.gd`
- Create: `scenes/ui/wiara/DoctrineList.tscn`
- Test: `tests/ui/test_doctrine_list.gd`

- [ ] **Step 1: Napisz failing test**

Stwórz `tests/ui/test_doctrine_list.gd`:

```gdscript
extends GutTest

const DoctrineListScene := preload("res://scenes/ui/wiara/DoctrineList.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func _instance_list(state: Node) -> DoctrineList:
	var l: DoctrineList = DoctrineListScene.instantiate()
	add_child_autofree(l)
	await get_tree().process_frame
	l.bind_state(state)
	return l

func test_list_renders_without_state():
	var l: DoctrineList = DoctrineListScene.instantiate()
	add_child_autofree(l)
	await get_tree().process_frame
	assert_not_null(l)

func test_list_renders_eight_rows():
	var state := _make_state()
	add_child_autofree(state)
	var l := await _instance_list(state)
	assert_eq(l.row_count(), 8)

func test_list_rows_sorted_axis_then_op_then_alphabetical():
	var state := _make_state()
	add_child_autofree(state)
	var l := await _instance_list(state)
	# Oczekiwana kolejnosc: A/min/kanon_doktryny, A/max/objawienie,
	# B/min/papieskie_interdykty, B/max/sobor_ludowy,
	# C/min/ekumenizm, C/min/obrzad_fuzji, C/max/inkwizycja, C/max/klatwa
	assert_eq(l.action_id_at(0), "kanon_doktryny")
	assert_eq(l.action_id_at(1), "objawienie")
	assert_eq(l.action_id_at(2), "papieskie_interdykty")
	assert_eq(l.action_id_at(3), "sobor_ludowy")
	assert_eq(l.action_id_at(4), "ekumenizm")
	assert_eq(l.action_id_at(5), "obrzad_fuzji")
	assert_eq(l.action_id_at(6), "inkwizycja")
	assert_eq(l.action_id_at(7), "klatwa")

func test_list_marks_doctrines_available_per_player_axes():
	var state := _make_state()
	add_child_autofree(state)
	# Islam: A=70, B=65, C=30, D=75
	# Dostepne (zaden prog osi nie spelniony — A nie >=75, A nie <=25, B nie >=75, B nie <=25,
	# C nie >=75, C nie <=25): wszystkie zablokowane
	var l := await _instance_list(state)
	for i in range(8):
		var row: DoctrineRow = l.row_at(i)
		assert_eq(row.get_node("%StateIcon").text, "○", "Row " + str(i) + " should be locked")

func test_list_unlocks_doctrines_on_axis_change():
	var state := _make_state()
	add_child_autofree(state)
	var l := await _instance_list(state)
	# Przesun A do 80 → kanon_doktryny powinien byc dostepny
	state.get_player_religion().axes["A"] = 80.0
	l.refresh()
	var kanon_row: DoctrineRow = l.row_at(0)
	assert_eq(kanon_row.get_node("%StateIcon").text, "◐")
```

- [ ] **Step 2: Uruchom test — oczekuj FAIL**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_doctrine_list.gd -gexit
```

Oczekiwane: FAIL.

- [ ] **Step 3: Stwórz `scripts/ui/wiara/DoctrineList.gd`**

```gdscript
class_name DoctrineList
extends VBoxContainer

const DoctrineRowScene := preload("res://scenes/ui/wiara/DoctrineRow.tscn")
const AXIS_ORDER: Array = ["A", "B", "C"]

var state: Node = null
var _rows: Array[DoctrineRow] = []
var _action_ids: Array[String] = []

func bind_state(s: Node) -> void:
	state = s
	if not is_inside_tree():
		return
	_build_rows()
	refresh()

func _ready() -> void:
	if state != null and _rows.is_empty():
		_build_rows()
		refresh()

func row_count() -> int:
	return _rows.size()

func row_at(index: int) -> DoctrineRow:
	if index < 0 or index >= _rows.size():
		return null
	return _rows[index]

func action_id_at(index: int) -> String:
	if index < 0 or index >= _action_ids.size():
		return ""
	return _action_ids[index]

func refresh() -> void:
	if state == null:
		return
	var religion: Religion = state.get_player_religion()
	if religion == null:
		return
	for i in range(_rows.size()):
		var action_id := _action_ids[i]
		var info: Dictionary = UIConstants.DOCTRINE_INFO[action_id]
		var value: float = religion.get_axis(info["axis"])
		_rows[i].set_doctrine(action_id, value)

func _build_rows() -> void:
	for child in get_children():
		child.queue_free()
	_rows.clear()
	_action_ids = _sorted_action_ids()
	for action_id in _action_ids:
		var row: DoctrineRow = DoctrineRowScene.instantiate()
		add_child(row)
		_rows.append(row)

func _sorted_action_ids() -> Array[String]:
	var entries: Array = []
	for action_id: String in UIConstants.DOCTRINE_INFO.keys():
		var info: Dictionary = UIConstants.DOCTRINE_INFO[action_id]
		entries.append({
			"id": action_id,
			"axis": info["axis"],
			"op": info["op"],
			"threshold": info["threshold"],
		})
	entries.sort_custom(_compare_entries)
	var result: Array[String] = []
	for entry: Dictionary in entries:
		result.append(entry["id"])
	return result

func _compare_entries(a: Dictionary, b: Dictionary) -> bool:
	var ai := AXIS_ORDER.find(a["axis"])
	var bi := AXIS_ORDER.find(b["axis"])
	if ai != bi:
		return ai < bi
	# min przed max
	if a["op"] != b["op"]:
		return a["op"] == "min"
	if a["threshold"] != b["threshold"]:
		return a["threshold"] < b["threshold"]
	return a["id"] < b["id"]
```

- [ ] **Step 4: Stwórz `scenes/ui/wiara/DoctrineList.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/wiara/DoctrineList.gd" id="1"]

[node name="DoctrineList" type="VBoxContainer"]
script = ExtResource("1")
```

- [ ] **Step 5: Uruchom test — oczekuj PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_doctrine_list.gd -gexit
```

Oczekiwane: 5/5 passing.

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/wiara/DoctrineList.gd scenes/ui/wiara/DoctrineList.tscn tests/ui/test_doctrine_list.gd
git commit -m "$(cat <<'EOF'
feat(ui): DoctrineList — VBox z 8 DoctrineRow

Wiersze posortowane A->B->C, w obrebie osi min przed max, na koniec
alfabetycznie po action_id (deterministyczne dla testow). Refresh
przelicza stan kazdego wiersza wedle religion.axes[axis] vs threshold.
EOF
)"
```

---

## Chunk 3: WiaraTab composition + MainShell integration

---

### Task 5: WiaraTab — kompozycja AxisRadar + TraitCard + DoctrineList

**Cel:** Root komponent zakładki — VBox spinający 3 sekcje. `bind_state` i `refresh` propagują do dzieci.

**Files:**
- Create: `scripts/ui/wiara/WiaraTab.gd`
- Create: `scenes/ui/wiara/WiaraTab.tscn`
- Test: `tests/ui/test_wiara_tab.gd`

- [ ] **Step 1: Napisz failing test**

Stwórz `tests/ui/test_wiara_tab.gd`:

```gdscript
extends GutTest

const WiaraTabScene := preload("res://scenes/ui/wiara/WiaraTab.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func _instance_tab(state: Node) -> WiaraTab:
	var t: WiaraTab = WiaraTabScene.instantiate()
	add_child_autofree(t)
	await get_tree().process_frame
	t.bind_state(state)
	return t

func test_tab_renders_without_state():
	var t: WiaraTab = WiaraTabScene.instantiate()
	add_child_autofree(t)
	await get_tree().process_frame
	assert_not_null(t)

func test_tab_renders_three_child_components():
	var state := _make_state()
	add_child_autofree(state)
	var t := await _instance_tab(state)
	assert_not_null(t.get_node("%AxisRadar"))
	assert_not_null(t.get_node("%TraitCard"))
	assert_not_null(t.get_node("%DoctrineList"))

func test_tab_propagates_state_to_children():
	var state := _make_state()
	add_child_autofree(state)
	var t := await _instance_tab(state)
	var radar: AxisRadar = t.get_node("%AxisRadar")
	var card: TraitCard = t.get_node("%TraitCard")
	var list: DoctrineList = t.get_node("%DoctrineList")
	assert_eq(radar.state, state)
	assert_eq(card.state, state)
	assert_eq(list.state, state)

func test_tab_refresh_propagates_to_children():
	var state := _make_state()
	add_child_autofree(state)
	var t := await _instance_tab(state)
	# Mutuj os i sprawdz, ze refresh dociera
	state.get_player_religion().axes["A"] = 100.0
	t.refresh()
	var radar: AxisRadar = t.get_node("%AxisRadar")
	assert_eq(radar.get_node("%ValueLabelA").text, "A: 100")

func test_tab_refresh_no_op_when_state_null():
	var t: WiaraTab = WiaraTabScene.instantiate()
	add_child_autofree(t)
	await get_tree().process_frame
	t.refresh()  # Bez crasha
	assert_null(t.state)
```

- [ ] **Step 2: Uruchom test — oczekuj FAIL**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_wiara_tab.gd -gexit
```

Oczekiwane: FAIL.

- [ ] **Step 3: Stwórz `scripts/ui/wiara/WiaraTab.gd`**

```gdscript
class_name WiaraTab
extends Control

var state: Node = null

@onready var _axis_radar: AxisRadar = %AxisRadar
@onready var _trait_card: TraitCard = %TraitCard
@onready var _doctrine_list: DoctrineList = %DoctrineList

func bind_state(s: Node) -> void:
	state = s
	if not is_inside_tree():
		return
	_axis_radar.bind_state(s)
	_trait_card.bind_state(s)
	_doctrine_list.bind_state(s)

func _ready() -> void:
	if state != null:
		_axis_radar.bind_state(state)
		_trait_card.bind_state(state)
		_doctrine_list.bind_state(state)

func refresh() -> void:
	if state == null:
		return
	_axis_radar.refresh()
	_trait_card.refresh()
	_doctrine_list.refresh()
```

- [ ] **Step 4: Stwórz `scenes/ui/wiara/WiaraTab.tscn`**

```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/ui/wiara/WiaraTab.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/ui/wiara/AxisRadar.tscn" id="2"]
[ext_resource type="PackedScene" path="res://scenes/ui/wiara/TraitCard.tscn" id="3"]
[ext_resource type="PackedScene" path="res://scenes/ui/wiara/DoctrineList.tscn" id="4"]

[node name="WiaraTab" type="Control"]
script = ExtResource("1")
anchor_right = 1.0
anchor_bottom = 1.0

[node name="VBox" type="VBoxContainer" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 20.0
offset_top = 20.0
offset_right = -20.0
offset_bottom = -20.0

[node name="AxisRadar" parent="VBox" instance=ExtResource("2")]
unique_name_in_owner = true
size_flags_horizontal = 4

[node name="TraitCard" parent="VBox" instance=ExtResource("3")]
unique_name_in_owner = true
size_flags_horizontal = 3

[node name="DoctrineList" parent="VBox" instance=ExtResource("4")]
unique_name_in_owner = true
size_flags_horizontal = 3
```

- [ ] **Step 5: Uruchom test — oczekuj PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_wiara_tab.gd -gexit
```

Oczekiwane: 5/5 passing.

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/wiara/WiaraTab.gd scenes/ui/wiara/WiaraTab.tscn tests/ui/test_wiara_tab.gd
git commit -m "$(cat <<'EOF'
feat(ui): WiaraTab — kompozycja AxisRadar + TraitCard + DoctrineList

Root Control z VBox: radar (centrum), trait card (pelna szerokosc), lista
doktryn. bind_state i refresh propaguja do trzech dzieci. Zakladka
read-only — brak wlasnego state_changed (mutacje silnika nie pochodza
z tego widoku).
EOF
)"
```

---

### Task 6: MainShell integracja — podmiana PlaceholderTab na WiaraTab

**Cel:** Zamiana `_wiara_tab: PlaceholderTab` na `_wiara_tab: WiaraTab` w `MainShell.gd`, dodanie `bind_state` i `refresh` do pipeline, podmiana sceny w `MainShell.tscn`.

**Files:**
- Modify: `scripts/ui/MainShell.gd`
- Modify: `scenes/ui/MainShell.tscn`

- [ ] **Step 1a: Zaktualizuj istniejący test placeholderów w `tests/ui/test_main_shell.gd`**

Plik istnieje. Funkcja `test_shell_wiara_frakcje_placeholders_have_correct_titles` (linie 36-43) zakłada, że `%WiaraTab` to `PlaceholderTab` — po Plan 10 tak już nie jest. Zmodyfikuj na **Frakcje-only**:

```gdscript
# PRZED:
func test_shell_wiara_frakcje_placeholders_have_correct_titles():
	var state := _make_state()
	add_child_autofree(state)
	var shell := await _instance_shell(state)
	var wiara: PlaceholderTab = shell.get_node("%WiaraTab")
	var frakcje: PlaceholderTab = shell.get_node("%FrakcjeTab")
	assert_string_contains(wiara.title, "Plan 10")
	assert_string_contains(frakcje.title, "Plan 11")

# PO:
func test_shell_frakcje_placeholder_has_correct_title():
	var state := _make_state()
	add_child_autofree(state)
	var shell := await _instance_shell(state)
	var frakcje: PlaceholderTab = shell.get_node("%FrakcjeTab")
	assert_string_contains(frakcje.title, "Plan 11")
```

- [ ] **Step 1b: Dodaj 2 nowe testy integracji `MainShell ↔ WiaraTab` na końcu `test_main_shell.gd`**

```gdscript
func test_shell_instantiates_wiara_tab_as_real_component():
	var state := _make_state()
	add_child_autofree(state)
	var shell := await _instance_shell(state)
	var wiara = shell.get_node("%WiaraTab")
	assert_true(wiara is WiaraTab, "WiaraTab should be a WiaraTab instance, not PlaceholderTab")

func test_shell_binds_state_to_wiara_tab():
	var state := _make_state()
	add_child_autofree(state)
	var shell := await _instance_shell(state)
	var wiara: WiaraTab = shell.get_node("%WiaraTab")
	assert_eq(wiara.state, state)
```

(Helpery `_make_state` i `_instance_shell` są już w pliku — nie duplikujemy.)

- [ ] **Step 2: Uruchom test — oczekuj FAIL**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_main_shell.gd -gexit
```

Oczekiwane: 2 nowe testy fail (`wiara is WiaraTab` = false — wciąż PlaceholderTab) + `test_shell_frakcje_placeholder_has_correct_title` pass (Frakcje już była placeholder).

- [ ] **Step 3: Wykonaj 4 konkretne edycje w `scripts/ui/MainShell.gd`**

Plik ma 60 linii. Wykonaj te 4 zmiany **przyrostowo** — nie nadpisuj pliku w całości (resztę zachować bez zmian).

**Edycja 1** — linia 8, zmień typ `_wiara_tab`:

```
# PRZED (linia 8):
@onready var _wiara_tab: PlaceholderTab = %WiaraTab

# PO:
@onready var _wiara_tab: WiaraTab = %WiaraTab
```

**Edycja 2** — linia 15, usuń wywołanie `set_title` (cała linia znika):

```
# USUŃ:
	_wiara_tab.set_title("Wiara (Plan 10 — w trakcie)")
```

(Linia `_frakcje_tab.set_title("Frakcje (Plan 11 — w trakcie)")` pozostaje — FrakcjeTab nadal jest placeholderem.)

**Edycja 3** — w funkcji `bind_state(s)`, po `_mapa_tab.bind_state(s)` (linia ~29), dodaj:

```gdscript
	_wiara_tab.bind_state(s)
```

**Edycja 4** — w funkcji `refresh()`, po bloku `if _mapa_tab.has_method("refresh"): _mapa_tab.refresh()` (linia ~38), dodaj:

```gdscript
	_wiara_tab.refresh()
```

**Co pozostaje bez zmian (NIE TYKAJ):**
- Wszystkie `connect` w `_ready()` (tab_changed, navigate_to_diplomacy, state_changed, turn_ended)
- `_on_tab_changed(_tab_bar.current_tab)` na końcu `_ready()`
- Funkcje `_on_tab_changed`, `_on_turn_ended`, `_on_swiat_state_changed`, `_on_navigate_to_diplomacy`, `set_current_tab`

Po zmianach `MainShell.gd` powinien mieć ~62 linie (nadal w okolicach oryginalnych 60).

- [ ] **Step 4: Zmień `scenes/ui/MainShell.tscn`**

Dodaj ExtResource dla `WiaraTab.tscn` (po linii 8) i podmień instancję `WiaraTab` (linia 34) z `ExtResource("4")` (PlaceholderTab) na nowy id.

Wynikowo:

```
[gd_scene load_steps=8 format=3]

[ext_resource type="Script" path="res://scripts/ui/MainShell.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/ui/Header.tscn" id="2"]
[ext_resource type="PackedScene" path="res://scenes/ui/TabBar.tscn" id="3"]
[ext_resource type="PackedScene" path="res://scenes/ui/PlaceholderTab.tscn" id="4"]
[ext_resource type="PackedScene" path="res://scenes/ui/world/WorldTab.tscn" id="5"]
[ext_resource type="PackedScene" path="res://scenes/ui/map/MapaTab.tscn" id="6"]
[ext_resource type="PackedScene" path="res://scenes/ui/wiara/WiaraTab.tscn" id="7"]

...

[node name="WiaraTab" parent="VBox/ContentArea" instance=ExtResource("7")]
unique_name_in_owner = true
visible = false
```

`load_steps` rośnie z 7 na 8 (nowy ExtResource). `ExtResource("4")` (`PlaceholderTab.tscn`) wciąż użyte przez `FrakcjeTab` — nie usuwaj go.

- [ ] **Step 5: Regeneruj class cache (jeśli potrzeba)**

```bash
godot --headless --path . --quit 2>/dev/null || true
```

- [ ] **Step 6: Uruchom testy main_shell — oczekuj PASS**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_main_shell.gd -gexit
```

Oczekiwane: 8/8 passing (6 dotychczasowych + 2 nowe integracyjne; `test_shell_wiara_frakcje_placeholders_have_correct_titles` został przemianowany na `test_shell_frakcje_placeholder_has_correct_title`).

- [ ] **Step 7: Uruchom całą suitę — sprawdź brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Oczekiwane: wszystkie testy passing (poprzednie + nowe z Task 0-6).

- [ ] **Step 8: Smoke test w edytorze (MANUAL — wymaga GUI)**

Pomiń w środowiskach headless/CI. Lokalnie:

```bash
godot --path .
```

Otworzy się okno gry. Kliknij zakładkę "Wiara" i sprawdź wzrokowo:
- radar Islamu (diament A=70/B=65/C=30/D=75)
- karta traitu "Umma"
- 8 doktryn (wszystkie zablokowane przy startowych wartościach Islamu)

Zamknij okno.

- [ ] **Step 9: Commit**

```bash
git add scripts/ui/MainShell.gd scenes/ui/MainShell.tscn tests/ui/test_main_shell.gd
git commit -m "$(cat <<'EOF'
feat(ui): MainShell integruje WiaraTab — koniec placeholdera

Typ _wiara_tab: PlaceholderTab → WiaraTab. bind_state i refresh propaguja
do nowego komponentu. Set_title placeholdera usuniety. MainShell.tscn:
ExtResource dla WiaraTab.tscn (id=7) zastepuje instancje PlaceholderTab
w slocie Wiara (PlaceholderTab nadal uzywany dla FrakcjeTab).
EOF
)"
```

---

### Task 7 (opcjonalny): Dodaj sidecary .uid

Godot 4.6 generuje pliki `.uid` dla każdego skryptu i sceny przy pierwszym otwarciu w edytorze. Jeśli zostały utworzone, dodaj je do commita.

- [ ] **Step 1: Sprawdź nowe pliki .uid**

```bash
git status --short | grep "\.uid$"
```

- [ ] **Step 2: Commit jeśli istnieją**

```bash
git add scripts/ui/wiara/*.uid scenes/ui/wiara/*.uid tests/ui/test_axis_radar.gd.uid tests/ui/test_trait_card.gd.uid tests/ui/test_doctrine_row.gd.uid tests/ui/test_doctrine_list.gd.uid tests/ui/test_doctrine_info_parity.gd.uid tests/ui/test_wiara_tab.gd.uid 2>/dev/null
git diff --cached --quiet && echo "no .uid files to commit" || git commit -m "chore: add .uid sidecars for Plan 10 scripts and tests"
```

---

## Podsumowanie

Po wszystkich taskach:
- Nowe pliki: 5 GD scripts + 5 TSCN + 6 test files = 16 plików
- Zmiany: `UIConstants.gd`, `MainShell.gd`, `MainShell.tscn`
- Nowe testy: ~30 (5 parity + 6 radar + 5 card + 7 row + 5 list + 7 tab)
- Spodziewany przyrost suity: 429 → ~459 tests

**Cele MVP zrealizowane:**
- Radar 4 osi z aktualnych wartości religii gracza
- Karta traitu z opisem mechanicznie zgodnym ze spec 05
- Lista 8 doktryn z DoctrineManager.AXIS_THRESHOLDS, stany dostępna/zablokowana
- Test parytetu pilnuje przyszłej zgodności DOCTRINE_INFO ↔ AXIS_THRESHOLDS
- MainShell integracja — koniec placeholdera dla zakładki Wiara

**Co świadomie nie wchodzi (future plans):**
- Aktywacja doktryn (`[Aktywuj]` button + state.active_doctrines)
- Akcje doktrynalne (`[Sobor]`, `[Edykt]`, `[Wyślij Badacza]`)
- Pending ideas UI (`state.pending_ideas` accept/reject)
- Animacje przejść osi między turami
- Frakcje (Plan 11 — `FrakcjeTab`)
