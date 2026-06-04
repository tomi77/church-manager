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
	for pd in province_list:
		graph.add_province(_parse_province(pd as Dictionary))
	for pd in province_list:
		var id: String = (pd as Dictionary).get("id", "")
		var neighbors_raw: Array = (pd as Dictionary).get("neighbors", [])
		for neighbor in neighbors_raw:
			if graph.get_province(neighbor as String) != null:
				graph.add_edge(id, neighbor as String)
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
	p.is_holy_site = pd.get("is_holy_site", false)
	return p
