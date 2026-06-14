extends GutTest

var graph: ProvinceGraph

func before_each() -> void:
	graph = ProvinceGraph.new()
	var anatolia := Province.new()
	anatolia.id = "anatolia"
	anatolia.owner = "eastern_christianity"
	anatolia.pressure = {"eastern_christianity": 80.0, "islam": 30.0}
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
	var borders := graph.border_provinces("eastern_christianity")
	assert_true(borders.has("anatolia"))

# === Plan 15: ghost edge integrity — wszystkie znane ghost edges naprawione ===

func test_no_ghost_edges_in_full_graph() -> void:
	var full_graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	# Po Plan 15 allowlist jest pusty — wszystkie znane ghost edges naprawione (jemen, italia_polnocna, tracja).
	var allowed_ghosts: Array[String] = []
	var actual_ghosts: Array[String] = []
	for p: Province in full_graph.all_provinces():
		for n: String in p.neighbors:
			if full_graph.get_province(n) == null and not (n in actual_ghosts):
				actual_ghosts.append(n)
	# Każdy znaleziony ghost MUSI być w allowlist (po Plan 15: zero ghost edges).
	for ghost: String in actual_ghosts:
		assert_true(ghost in allowed_ghosts,
			"Ghost edge '%s' nie jest w allowlist %s — usuń edge lub uzasadnij w spec 15" % [ghost, allowed_ghosts])
	# Sanity: 3 prowincje Plan 15 NIE są ghostami (dodane w Task 1-3).
	assert_false("jemen" in actual_ghosts,
		"jemen ghost edge powinien zostać naprawiony przez Task 1 w Plan 15")
	assert_false("italia_polnocna" in actual_ghosts,
		"italia_polnocna ghost edge powinien zostać naprawiony przez Task 2 w Plan 15")
	assert_false("tracja" in actual_ghosts,
		"tracja ghost edge powinien zostać naprawiony przez Task 3 w Plan 15")
	# Zachowane z Plan 14 — sanity check, że afryka_polnocna nadal naprawiona.
	assert_false("afryka_polnocna" in actual_ghosts,
		"afryka_polnocna ghost edge powinien zostać naprawiony przez karthago w Plan 14")
