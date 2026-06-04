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
