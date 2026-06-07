extends GutTest

const ProvinceNodeScene := preload("res://scenes/ui/map/ProvinceNode.tscn")

func _make_province(id: String, owner: String, display: String, pos: Vector2) -> Province:
    var p := Province.new()
    p.id = id
    p.owner = owner
    p.display_name = display
    p.position = pos
    p.neighbors = []
    return p

func _instance_node(prov: Province) -> ProvinceNode:
    var pn: ProvinceNode = ProvinceNodeScene.instantiate()
    add_child_autofree(pn)
    await get_tree().process_frame
    pn.set_province(prov)
    return pn

func test_node_renders_display_name():
    var prov := _make_province("mekka", "religie_arabskie", "Mekka", Vector2(420, 420))
    var pn := await _instance_node(prov)
    assert_eq(pn.get_node("%NameLabel").text, "Mekka")

func test_node_position_set_from_province():
    var prov := _make_province("mekka", "religie_arabskie", "Mekka", Vector2(420, 420))
    var pn := await _instance_node(prov)
    assert_eq(pn.position, Vector2(420, 420))

func test_node_color_from_religion_palette():
    var prov := _make_province("mekka", "islam", "Mekka", Vector2(420, 420))
    var pn := await _instance_node(prov)
    var poly: Polygon2D = pn.get_node("%Polygon")
    assert_eq(poly.color, UIConstants.RELIGION_COLORS["islam"])

func test_node_click_emits_pressed():
    var prov := _make_province("mekka", "islam", "Mekka", Vector2(420, 420))
    var pn := await _instance_node(prov)
    watch_signals(pn)
    pn.get_node("%ClickArea").emit_signal("pressed")
    assert_signal_emitted_with_parameters(pn, "pressed", ["mekka"])

func test_node_selection_toggles_outline():
    var prov := _make_province("mekka", "islam", "Mekka", Vector2(420, 420))
    var pn := await _instance_node(prov)
    pn.set_selected(true)
    assert_true(pn.is_selected)
    pn.set_selected(false)
    assert_false(pn.is_selected)
