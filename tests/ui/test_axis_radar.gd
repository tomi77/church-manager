extends GutTest

const AxisRadarScene := preload("res://scenes/ui/faith/AxisRadar.tscn")
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
