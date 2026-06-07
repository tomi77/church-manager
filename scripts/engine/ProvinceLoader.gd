class_name ProvinceLoader
extends RefCounted

static func load_graph_from_file(path: String) -> ProvinceGraph:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ProvinceLoader: cannot open " + path)
		return ProvinceGraph.new()
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK:
		push_error("ProvinceLoader: JSON parse error in " + path)
		return ProvinceGraph.new()
	return _build_graph(json.get_data())

static func _build_graph(data: Dictionary) -> ProvinceGraph:
	var graph := ProvinceGraph.new()
	var province_list: Array = data.get("provinces", [])
	for pd: Dictionary in province_list:
		graph.add_province(_parse_province(pd))
	for pd: Dictionary in province_list:
		var id: String = pd.get("id", "")
		var neighbors_raw: Array = pd.get("neighbors", [])
		for neighbor: String in neighbors_raw:
			if graph.get_province(neighbor) != null:
				graph.add_edge(id, neighbor)
	return graph

static func _parse_province(pd: Dictionary) -> Province:
	var p := Province.new()
	p.id = pd.get("id", "")
	p.owner = pd.get("owner", "")
	p.pressure = pd.get("pressure", {})
	p.population = pd.get("population", 0)
	p.resources = pd.get("resources", {"food": 0, "gold": 0})
	p.terrain = pd.get("terrain", "plains")
	var neighbors_raw: Array = pd.get("neighbors", [])
	p.neighbors.assign(neighbors_raw)
	p.display_name = pd.get("display_name", pd.get("id", ""))
	p.is_holy_site = pd.get("is_holy_site", false)
	var pos_raw: Dictionary = pd.get("position", {})
	p.position = Vector2(
		float(pos_raw.get("x", 0.0)),
		float(pos_raw.get("y", 0.0))
	)
	return p
