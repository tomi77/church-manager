extends GutTest

const PlaceholderTabScene := preload("res://scenes/ui/PlaceholderTab.tscn")

func test_default_title_rendered():
    var tab: PlaceholderTab = PlaceholderTabScene.instantiate()
    add_child_autofree(tab)
    await get_tree().process_frame
    assert_eq(tab.get_node("%TitleLabel").text, "Placeholder")

func test_set_title_updates_label():
    var tab: PlaceholderTab = PlaceholderTabScene.instantiate()
    add_child_autofree(tab)
    await get_tree().process_frame
    tab.set_title("Mapa (Plan 09 — w trakcie)")
    assert_eq(tab.get_node("%TitleLabel").text, "Mapa (Plan 09 — w trakcie)")

func test_set_title_before_ready_persists():
    var tab: PlaceholderTab = PlaceholderTabScene.instantiate()
    tab.title = "Wiara (Plan 10 — w trakcie)"
    add_child_autofree(tab)
    await get_tree().process_frame
    assert_eq(tab.get_node("%TitleLabel").text, "Wiara (Plan 10 — w trakcie)")
