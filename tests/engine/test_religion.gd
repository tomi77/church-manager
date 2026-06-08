extends GutTest

func _make_test_religion() -> Religion:
	var r := Religion.new()
	r.id = "islam"
	r.display_name = "Islam"
	r.axes = {"A": 70.0, "B": 65.0, "C": 30.0, "D": 75.0}
	r.prestige = 300
	r.holy_sites = ["mekka", "jerozolima"]
	var ulama := Faction.new()
	ulama.id = "ulama"
	ulama.influence = 0.40
	ulama.tension = 20.0
	ulama.axis_preferences = [{"axis": "A", "direction": 1}, {"axis": "B", "direction": 1}]
	var sufis := Faction.new()
	sufis.id = "sufis"
	sufis.influence = 0.30
	sufis.tension = 20.0
	r.factions = [ulama, sufis]
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
	var f := r.get_faction("ulama")
	assert_not_null(f)
	assert_eq(f.id, "ulama")

func test_religion_get_faction_missing_returns_null() -> void:
	var r := _make_test_religion()
	assert_null(r.get_faction("wojownicy"))

func test_religion_dominant_faction_is_highest_influence() -> void:
	var r := _make_test_religion()
	assert_eq(r.dominant_faction().id, "ulama")

func test_religion_prestige_cannot_go_below_zero() -> void:
	var r := _make_test_religion()
	r.add_prestige(-9999)
	assert_eq(r.prestige, 0)

func test_religion_vassal_fields_defaults() -> void:
	var r := Religion.new()
	assert_eq(r.resources, 0)
	assert_eq(r.suzerain_id, "")
	assert_eq(r.interdict_immunity_until, 0)

func test_religion_grievance_fields_defaults() -> void:
	var r := Religion.new()
	assert_eq(r.interdict_grievance_from_id, "")
	assert_eq(r.interdict_grievance_until, 0)

func test_new_field_defeated_at_turn_defaults_to_minus_one():
	var r := Religion.new()
	assert_eq(r.defeated_at_turn, -1)

func test_new_field_birth_turn_defaults_to_zero():
	var r := Religion.new()
	assert_eq(r.birth_turn, 0)

func test_new_field_starting_provinces_snapshot_defaults_to_empty():
	var r := Religion.new()
	assert_eq(r.starting_provinces_snapshot.size(), 0)

func test_new_field_ever_owned_province_defaults_to_false():
	var r := Religion.new()
	assert_false(r.ever_owned_province)

func test_new_field_ragnarok_triggered_defaults_to_false():
	var r := Religion.new()
	assert_false(r.ragnarok_triggered)

func test_new_field_absorbed_idea_sources_defaults_to_empty():
	var r := Religion.new()
	assert_eq(r.absorbed_idea_sources.size(), 0)

func test_starting_provinces_snapshot_is_string_array():
	var r := Religion.new()
	r.starting_provinces_snapshot = ["mekka", "lewant"]
	assert_eq(r.starting_provinces_snapshot[0], "mekka")
	assert_eq(r.starting_provinces_snapshot[1], "lewant")

func test_absorbed_idea_sources_is_string_array():
	var r := Religion.new()
	r.absorbed_idea_sources = ["islam", "judaism"]
	assert_eq(r.absorbed_idea_sources[0], "islam")
	assert_eq(r.absorbed_idea_sources[1], "judaism")
