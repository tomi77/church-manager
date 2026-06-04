extends GutTest

func test_faction_influence_starts_in_range() -> void:
    var f := Faction.new()
    f.influence = 0.40
    assert_true(f.influence >= 0.0 and f.influence <= 1.0)

func test_faction_tension_clamps_to_100() -> void:
    var f := Faction.new()
    f.tension = 50.0
    f.add_tension(60.0)
    assert_eq(f.tension, 100.0)

func test_faction_tension_cannot_go_below_zero() -> void:
    var f := Faction.new()
    f.tension = 10.0
    f.add_tension(-30.0)
    assert_eq(f.tension, 0.0)

func test_faction_prefers_axis_direction() -> void:
    var f := Faction.new()
    f.axis_preferences = [{"axis": "A", "direction": 1}, {"axis": "B", "direction": 1}]
    assert_eq(f.get_preference_for_axis("A"), 1)
    assert_eq(f.get_preference_for_axis("C"), 0)
