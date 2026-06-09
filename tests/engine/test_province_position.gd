extends GutTest

func test_provinces_load_with_positions():
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	var mekka: Province = graph.get_province("mekka")
	assert_not_null(mekka, "Mekka must exist")
	assert_almost_eq(mekka.position.x, 420.0, 1.0)
	assert_almost_eq(mekka.position.y, 420.0, 1.0)

func test_all_provinces_have_nonzero_position():
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	for p: Province in graph.all_provinces():
		assert_ne(p.position, Vector2.ZERO, "%s must have a non-zero position" % p.id)
