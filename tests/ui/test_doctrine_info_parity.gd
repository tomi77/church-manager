extends GutTest

func test_every_axis_threshold_action_has_doctrine_info_entry():
	var dm := DoctrineManager.new()
	for axis: String in dm.AXIS_THRESHOLDS.keys():
		var rules: Array = dm.AXIS_THRESHOLDS[axis]
		for rule: Dictionary in rules:
			var op := "min" if rule.has("min") else "max"
			var threshold: float = rule.get("min", rule.get("max", 0.0))
			for action_id: String in rule["actions"]:
				assert_true(UIConstants.DOCTRINE_INFO.has(action_id),
					"DOCTRINE_INFO missing entry for action_id: " + action_id)
				var info: Dictionary = UIConstants.DOCTRINE_INFO[action_id]
				assert_eq(info.get("axis", ""), axis,
					action_id + ": axis mismatch")
				assert_eq(info.get("op", ""), op,
					action_id + ": op mismatch")
				assert_eq(info.get("threshold", -1.0), threshold,
					action_id + ": threshold mismatch")

func test_every_doctrine_info_entry_has_matching_axis_threshold():
	var dm := DoctrineManager.new()
	for action_id: String in UIConstants.DOCTRINE_INFO.keys():
		var info: Dictionary = UIConstants.DOCTRINE_INFO[action_id]
		var axis: String = info["axis"]
		var op: String = info["op"]
		var threshold: float = info["threshold"]
		assert_true(dm.AXIS_THRESHOLDS.has(axis),
			"AXIS_THRESHOLDS missing axis " + axis + " for " + action_id)
		var found := false
		for rule: Dictionary in dm.AXIS_THRESHOLDS[axis]:
			var rule_op := "min" if rule.has("min") else "max"
			var rule_threshold: float = rule.get("min", rule.get("max", 0.0))
			if rule_op == op and rule_threshold == threshold:
				if action_id in rule["actions"]:
					found = true
					break
		assert_true(found, action_id + " not found in AXIS_THRESHOLDS[" + axis + "]")

func test_trait_info_has_entries_for_all_historical_religions():
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	for r: Religion in religions:
		assert_true(UIConstants.TRAIT_INFO.has(r.trait_id),
			"TRAIT_INFO missing entry for trait_id: " + r.trait_id)
		var info: Dictionary = UIConstants.TRAIT_INFO[r.trait_id]
		assert_ne(info.get("name", ""), "", r.trait_id + ": missing name")
		assert_ne(info.get("description", ""), "", r.trait_id + ": missing description")

func test_religion_accent_color_returns_color_for_known_id():
	var c := UIConstants.religion_accent_color("islam")
	assert_typeof(c, TYPE_COLOR)

func test_religion_accent_color_returns_default_for_unknown_id():
	var c := UIConstants.religion_accent_color("nonexistent")
	assert_eq(c, UIConstants.RELIGION_ACCENT_COLOR_DEFAULT)
