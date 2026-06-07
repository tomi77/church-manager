extends GutTest

const ItemScene := preload("res://scenes/ui/world/RelationListItem.tscn")
const ReligionScript := preload("res://scripts/engine/Religion.gd")
const RelationStateScript := preload("res://scripts/engine/RelationState.gd")

func _make_religion(id: String, name: String, icon: String) -> Religion:
    var r: Religion = ReligionScript.new()
    r.id = id
    r.display_name = name
    r.icon = icon
    return r

func _make_relation(z: float, e: float, n: float) -> RelationState:
    var rel: RelationState = RelationStateScript.new()
    rel.theological_trust = z
    rel.economic_cooperation = e
    rel.military_tension = n
    return rel

func _instance() -> RelationListItem:
    var item: RelationListItem = ItemScene.instantiate()
    add_child_autofree(item)
    await get_tree().process_frame
    return item

func test_renders_name_and_icon():
    var item := await _instance()
    var r := _make_religion("chr_zach", "Chr. Zachodnie", "✝")
    item.set_data(_make_relation(0, 0, 0), r, "")
    var text: String = item.get_node("%NameLabel").text
    assert_string_contains(text, "Chr. Zachodnie")
    assert_string_contains(text, "✝")

func test_renders_zen_values():
    var item := await _instance()
    item.set_data(_make_relation(65.0, 40.0, 35.0), _make_religion("x", "X", "?"), "")
    assert_eq(item.get_node("%ZLabel").text, "Z 65")
    assert_eq(item.get_node("%ELabel").text, "E 40")
    assert_eq(item.get_node("%NLabel").text, "N 35")

func test_renders_marker():
    var item := await _instance()
    item.set_data(_make_relation(0, 0, 0), _make_religion("x", "X", "?"), "🤝")
    assert_eq(item.get_node("%MarkerLabel").text, "🤝")

func test_click_emits_pressed_with_religion_id():
    var item := await _instance()
    item.set_data(_make_relation(0, 0, 0), _make_religion("zoro", "Zoroastryzm", "🔥"), "")
    watch_signals(item)
    item.get_node("%RowButton").emit_signal("pressed")
    assert_signal_emitted_with_parameters(item, "pressed", ["zoro"])

func test_set_selected_changes_modulate():
    var item := await _instance()
    item.set_data(_make_relation(0, 0, 0), _make_religion("x", "X", "?"), "")
    item.set_selected(false)
    var unselected_r: float = item.modulate.r
    item.set_selected(true)
    assert_gt(item.modulate.r, unselected_r)

func test_null_relation_renders_zero():
    var item := await _instance()
    item.set_data(null, _make_religion("x", "X", "?"), "")
    assert_eq(item.get_node("%ZLabel").text, "Z 0")
