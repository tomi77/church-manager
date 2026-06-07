extends GutTest

func test_province_initial_pressure_is_zero_for_unknown_religion() -> void:
	var p := Province.new()
	p.id = "anatolia"
	p.pressure = {}
	assert_eq(p.get_pressure("islam"), 0.0)

func test_province_get_pressure_returns_stored_value() -> void:
	var p := Province.new()
	p.pressure = {"islam": 45.0, "chr_zachodnie": 20.0}
	assert_eq(p.get_pressure("islam"), 45.0)
	assert_eq(p.get_pressure("chr_zachodnie"), 20.0)

func test_province_add_pressure_clamps_to_100() -> void:
	var p := Province.new()
	p.pressure = {"islam": 90.0}
	p.add_pressure("islam", 20.0)
	assert_eq(p.get_pressure("islam"), 100.0)

func test_province_add_pressure_cannot_go_below_zero() -> void:
	var p := Province.new()
	p.pressure = {"islam": 5.0}
	p.add_pressure("islam", -10.0)
	assert_eq(p.get_pressure("islam"), 0.0)

func test_province_dominant_pressure_returns_religion_with_highest_pressure() -> void:
	var p := Province.new()
	p.owner = "chr_zachodnie"
	p.pressure = {"islam": 72.0, "chr_zachodnie": 80.0, "judaizm": 10.0}
	assert_eq(p.dominant_pressure_religion(), "chr_zachodnie")

func test_province_holy_site_flag() -> void:
	var p := Province.new()
	p.is_holy_site = true
	assert_true(p.is_holy_site)

func test_province_resources_food_and_gold() -> void:
	var p := Province.new()
	p.resources = {"food": 2, "gold": 1}
	assert_eq(p.resources["food"], 2)
	assert_eq(p.resources["gold"], 1)
