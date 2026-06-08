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
