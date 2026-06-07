class_name PressureBars
extends VBoxContainer

const PressureRowScene := preload("res://scenes/ui/map/PressureRow.tscn")

var state: Node = null
var province_id: String = ""
var _rows: Array[PressureRow] = []

func bind(s: Node, pid: String) -> void:
	state = s
	province_id = pid
	if is_inside_tree():
		refresh()

func refresh() -> void:
	_clear()
	if state == null or province_id == "":
		return
	var prov: Province = state.province_graph.get_province(province_id)
	if prov == null:
		return
	var entries: Array = []
	for rid: String in prov.pressure:
		var v: float = float(prov.pressure[rid])
		if v > 0.0:
			entries.append({"id": rid, "value": v})
	entries.sort_custom(func(a, b): return a.value > b.value)
	for e in entries:
		var rel: Religion = state.get_religion(e.id)
		if rel == null:
			continue
		var row: PressureRow = PressureRowScene.instantiate()
		add_child(row)
		row.set_data(rel, e.value)
		_rows.append(row)

func row_count() -> int:
	return _rows.size()

func get_row(idx: int) -> PressureRow:
	if idx < 0 or idx >= _rows.size():
		return null
	return _rows[idx]

func _clear() -> void:
	for r in _rows:
		r.queue_free()
	_rows.clear()
