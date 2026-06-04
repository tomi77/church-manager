extends GutTest

var graph: ProvinceGraph

func before_each() -> void:
    graph = ProvinceGraph.new()
    var anatolia := Province.new()
    anatolia.id = "anatolia"
    anatolia.owner = "chr_wschodnie"
    anatolia.pressure = {"chr_wschodnie": 80.0, "islam": 30.0}
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
    var borders := graph.border_provinces("chr_wschodnie")
    assert_true(borders.has("anatolia"))
