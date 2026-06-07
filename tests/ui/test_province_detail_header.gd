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

func test_header_terrain_labels_for_all_terrain_types():
    var state := _make_state()
    add_child_autofree(state)
    var expected_substrings := {
        "plains": "równina",
        "mountains": "góry",
        "desert": "pustynia",
        "coast": "wybrzeże",
        "fertile": "żyzne",
    }
    for terrain_key in expected_substrings.keys():
        var prov: Province = state.province_graph.get_province("mekka")
        var saved_terrain: String = prov.terrain
        prov.terrain = terrain_key
        var h := await _instance(state, "mekka")
        var label_text: String = h.get_node("%TerrainLabel").text
        assert_string_contains(label_text, expected_substrings[terrain_key])
        prov.terrain = saved_terrain

func test_header_falls_back_to_raw_owner_id_when_religion_missing():
    var state := _make_state()
    add_child_autofree(state)
    var prov: Province = state.province_graph.get_province("mekka")
    var saved_owner: String = prov.owner
    prov.owner = "nieistniejaca_religia"
    var h := await _instance(state, "mekka")
    assert_eq(h.get_node("%OwnerLabel").text, "nieistniejaca_religia")
    prov.owner = saved_owner
