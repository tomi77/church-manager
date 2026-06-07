class_name ProvinceGraph
extends RefCounted

var _provinces: Dictionary = {}
var _edges: Dictionary = {}

func add_province(province: Province) -> void:
	_provinces[province.id] = province
	if not _edges.has(province.id):
		_edges[province.id] = []

func add_edge(id_a: String, id_b: String) -> void:
	if not _edges.has(id_a):
		_edges[id_a] = []
	if not _edges.has(id_b):
		_edges[id_b] = []
	if not _edges[id_a].has(id_b):
		_edges[id_a].append(id_b)
	if not _edges[id_b].has(id_a):
		_edges[id_b].append(id_a)

func get_province(id: String) -> Province:
	return _provinces.get(id, null)

func province_count() -> int:
	return _provinces.size()

func get_neighbors(id: String) -> Array[String]:
	var result: Array[String] = []
	for n: String in _edges.get(id, []):
		result.append(n)
	return result

func are_neighbors(id_a: String, id_b: String) -> bool:
	return _edges.get(id_a, []).has(id_b)

func provinces_with_owner(owner_id: String) -> Array[Province]:
	var result: Array[Province] = []
	for p: Province in _provinces.values():
		if p.owner == owner_id:
			result.append(p)
	return result

func border_provinces(owner_id: String) -> Array[String]:
	var result: Array[String] = []
	for p: Province in provinces_with_owner(owner_id):
		for neighbor_id: String in get_neighbors(p.id):
			var neighbor := get_province(neighbor_id)
			if neighbor != null and neighbor.owner != owner_id:
				if not result.has(p.id):
					result.append(p.id)
				break
	return result

func all_provinces() -> Array[Province]:
	var result: Array[Province] = []
	for p: Province in _provinces.values():
		result.append(p)
	return result
