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

# === Plan 15: ghost edges cleanup ===

func test_loader_loads_jemen_arabian_owner_with_eastern_pressure_15() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	var jemen := graph.get_province("jemen")
	assert_not_null(jemen, "Plan 15: jemen powinien istnieć w fixturze")
	assert_eq(jemen.display_name, "Jemen")
	assert_eq(jemen.owner, "arabian_paganism")
	assert_eq(jemen.population, 250)
	assert_eq(jemen.terrain, "mountains")
	assert_false(jemen.is_holy_site)
	assert_eq(jemen.pressure.get("arabian_paganism", 0.0), 65.0)
	assert_eq(jemen.pressure.get("eastern_christianity", 0.0), 15.0)
	assert_eq(jemen.resources.get("food", 0), 1)
	assert_eq(jemen.resources.get("gold", 0), 3)
	assert_true("mekka" in jemen.neighbors, "jemen ma sąsiada mekka")
	assert_true("abisynia" in jemen.neighbors, "jemen ma sąsiada abisynia")

func test_loader_loads_italia_polnocna_western_owner_with_germanic_pressure_20() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	var italia := graph.get_province("italia_polnocna")
	assert_not_null(italia, "Plan 15: italia_polnocna powinna istnieć w fixturze")
	assert_eq(italia.display_name, "Italia Północna")
	assert_eq(italia.owner, "western_christianity")
	assert_eq(italia.population, 350)
	assert_eq(italia.terrain, "plains")
	assert_false(italia.is_holy_site)
	assert_eq(italia.pressure.get("western_christianity", 0.0), 60.0)
	assert_eq(italia.pressure.get("germanic_paganism", 0.0), 20.0)
	assert_eq(italia.resources.get("food", 0), 3)
	assert_eq(italia.resources.get("gold", 0), 2)
	assert_eq(italia.neighbors.size(), 1)
	assert_true("rzym" in italia.neighbors)

func test_loader_loads_tracja_eastern_owner_with_slavic_pressure_25() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	var tracja := graph.get_province("tracja")
	assert_not_null(tracja, "Plan 15: tracja powinna istnieć w fixturze")
	assert_eq(tracja.display_name, "Tracja")
	assert_eq(tracja.owner, "eastern_christianity")
	assert_eq(tracja.population, 300)
	assert_eq(tracja.terrain, "plains")
	assert_false(tracja.is_holy_site)
	assert_eq(tracja.pressure.get("eastern_christianity", 0.0), 60.0)
	assert_eq(tracja.pressure.get("slavic_paganism", 0.0), 25.0)
	assert_eq(tracja.resources.get("food", 0), 2)
	assert_eq(tracja.resources.get("gold", 0), 1)
	assert_eq(tracja.neighbors.size(), 1)
	assert_true("konstantynopol" in tracja.neighbors)

func test_jemen_abisynia_mutual_edge() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	var jemen := graph.get_province("jemen")
	var abisynia := graph.get_province("abisynia")
	assert_not_null(jemen)
	assert_not_null(abisynia)
	assert_true("abisynia" in jemen.neighbors, "jemen.neighbors zawiera abisynia (Task 1)")
	assert_true("jemen" in abisynia.neighbors, "abisynia.neighbors zawiera jemen (Task 4 patch)")

# Regression guard: chroni przed przypadkowym usunięciem prowincji w przyszłych edycjach.
# Nie jest red-test — po Task 1-4 fixture ma już 19 prowincji.
func test_provinces_total_count_19() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	assert_eq(graph.province_count(), 19, "Plan 15: mapa ma 19 prowincji (16 z Plan 14 + 3 nowe z Plan 15)")

# === Plan 17: Slavic heartland ===

func test_loader_loads_arkona_with_holy_site_and_slavic_owner() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	var arkona := graph.get_province("arkona")
	assert_not_null(arkona, "Plan 17: arkona powinna istnieć")
	assert_eq(arkona.display_name, "Arkona")
	assert_eq(arkona.owner, "slavic_paganism")
	assert_eq(arkona.population, 200)
	assert_eq(arkona.terrain, "coast")
	assert_true(arkona.is_holy_site, "arkona jest holy site Slavic")
	assert_eq(arkona.pressure.get("slavic_paganism", 0.0), 80.0)
	assert_eq(arkona.resources.get("food", 0), 1)
	assert_eq(arkona.resources.get("gold", 0), 2)
	assert_eq(arkona.neighbors.size(), 1)
	assert_true("gnieszno" in arkona.neighbors)

func test_loader_loads_gnieszno_slavic_owner_with_germanic_pressure_15() -> void:
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	var gnieszno := graph.get_province("gnieszno")
	assert_not_null(gnieszno)
	assert_eq(gnieszno.display_name, "Gniezno")
	assert_eq(gnieszno.owner, "slavic_paganism")
	assert_eq(gnieszno.population, 280)
	assert_eq(gnieszno.terrain, "plains")
	assert_false(gnieszno.is_holy_site)
	assert_eq(gnieszno.pressure.get("slavic_paganism", 0.0), 70.0)
	assert_eq(gnieszno.pressure.get("germanic_paganism", 0.0), 15.0)
	assert_eq(gnieszno.resources.get("food", 0), 3)
	assert_eq(gnieszno.resources.get("gold", 0), 1)
	assert_true("arkona" in gnieszno.neighbors)
	assert_true("morawy" in gnieszno.neighbors)
	assert_true("gardariki" in gnieszno.neighbors)
