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
	assert_eq(egipt.owner, "coptic_christianity")

# === Plan 14: nowe prowincje koptyjskie ===

func test_loader_loads_aleksandria_with_holy_site_and_coptic_owner() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	var aleksandria := graph.get_province("aleksandria")
	assert_not_null(aleksandria, "aleksandria istnieje")
	assert_eq(aleksandria.owner, "coptic_christianity")
	assert_true(aleksandria.is_holy_site, "aleksandria jest holy site")

func test_loader_loads_abisynia_coptic_owner_no_holy_site() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	var abisynia := graph.get_province("abisynia")
	assert_not_null(abisynia)
	assert_eq(abisynia.owner, "coptic_christianity")
	assert_false(abisynia.is_holy_site)

func test_loader_loads_libia_eastern_owner_with_coptic_pressure() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	var libia := graph.get_province("libia")
	assert_not_null(libia)
	assert_eq(libia.owner, "eastern_christianity")
	assert_almost_eq(libia.pressure.get("coptic_christianity", 0.0), 25.0, 0.001,
		"libia ma 25 pressure dla Coptic (missionary potential)")

func test_loader_loads_karthago_eastern_owner_with_western_pressure() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	var karthago := graph.get_province("karthago")
	assert_not_null(karthago)
	assert_eq(karthago.owner, "eastern_christianity")
	assert_almost_eq(karthago.pressure.get("western_christianity", 0.0), 20.0, 0.001,
		"karthago ma 20 pressure dla Western (Augustyn / dziedzictwo łacińskie)")

func test_egipt_neighbors_include_aleksandria_and_abisynia() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	assert_true(graph.are_neighbors("egipt", "aleksandria"), "egipt ↔ aleksandria")
	assert_true(graph.are_neighbors("egipt", "abisynia"), "egipt ↔ abisynia")
	assert_true(graph.are_neighbors("egipt", "libia"), "egipt ↔ libia (poprzedni ghost teraz waluuje)")

func test_rzym_neighbors_karthago_not_afryka_polnocna() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	assert_true(graph.are_neighbors("rzym", "karthago"), "rzym ↔ karthago")
	assert_null(graph.get_province("afryka_polnocna"),
		"afryka_polnocna nie powinna istnieć — została zastąpiona przez karthago")
