class_name ReligionLoader
extends RefCounted

static func load_from_file(path: String) -> Array[Religion]:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ReligionLoader: cannot open " + path)
		return []
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK:
		push_error("ReligionLoader: JSON parse error in " + path)
		return []
	return _parse_religions(json.get_data())

static func _parse_religions(data: Dictionary) -> Array[Religion]:
	var result: Array[Religion] = []
	for rd: Dictionary in data.get("religions", []):
		result.append(_parse_religion(rd))
	return result

static func _parse_religion(rd: Dictionary) -> Religion:
	var r := Religion.new()
	r.id = rd.get("id", "")
	r.display_name = rd.get("display_name", "")
	r.icon = rd.get("icon", "")
	r.axes = rd.get("axes", {"A": 50.0, "B": 50.0, "C": 50.0, "D": 50.0})
	r.prestige = rd.get("prestige_start", 0)
	var holy_sites_raw: Array = rd.get("holy_sites", [])
	r.holy_sites.assign(holy_sites_raw)
	r.color = rd.get("color", "#ffffff")
	r.accent_color = rd.get("accent_color", "#ffffff")
	r.trait_id = rd.get("trait_id", "")
	for fd: Dictionary in rd.get("factions", []):
		r.factions.append(_parse_faction(fd))
	return r

static func _parse_faction(fd: Dictionary) -> Faction:
	var f := Faction.new()
	f.id = fd.get("id", "")
	f.display_name = fd.get("display_name", "")
	f.influence = fd.get("influence_start", 0.0)
	f.tension = fd.get("tension_start", 0.0)
	f.axis_preferences = fd.get("axis_preferences", [])
	return f
