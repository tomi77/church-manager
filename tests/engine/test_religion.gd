extends GutTest

func _make_test_religion() -> Religion:
    var r := Religion.new()
    r.id = "islam"
    r.display_name = "Islam"
    r.axes = {"A": 70.0, "B": 65.0, "C": 30.0, "D": 75.0}
    r.prestige = 300
    r.holy_sites = ["mekka", "jerozolima"]
    var ulema := Faction.new()
    ulema.id = "ulema"
    ulema.influence = 0.40
    ulema.tension = 20.0
    ulema.axis_preferences = [{"axis": "A", "direction": 1}, {"axis": "B", "direction": 1}]
    var sufici := Faction.new()
    sufici.id = "sufici"
    sufici.influence = 0.30
    sufici.tension = 20.0
    r.factions = [ulema, sufici]
    return r

func test_religion_has_four_axes() -> void:
    var r := _make_test_religion()
    assert_true(r.axes.has("A"))
    assert_true(r.axes.has("B"))
    assert_true(r.axes.has("C"))
    assert_true(r.axes.has("D"))

func test_religion_axis_value_returns_correct() -> void:
    var r := _make_test_religion()
    assert_eq(r.get_axis("A"), 70.0)
    assert_eq(r.get_axis("C"), 30.0)

func test_religion_axis_shift_clamps_to_range() -> void:
    var r := _make_test_religion()
    r.shift_axis("A", 40.0)
    assert_eq(r.get_axis("A"), 100.0)
    r.shift_axis("A", -200.0)
    assert_eq(r.get_axis("A"), 0.0)

func test_religion_get_faction_by_id() -> void:
    var r := _make_test_religion()
    var f := r.get_faction("ulema")
    assert_not_null(f)
    assert_eq(f.id, "ulema")

func test_religion_get_faction_missing_returns_null() -> void:
    var r := _make_test_religion()
    assert_null(r.get_faction("wojownicy"))

func test_religion_dominant_faction_is_highest_influence() -> void:
    var r := _make_test_religion()
    assert_eq(r.dominant_faction().id, "ulema")

func test_religion_prestige_cannot_go_below_zero() -> void:
    var r := _make_test_religion()
    r.add_prestige(-9999)
    assert_eq(r.prestige, 0)
