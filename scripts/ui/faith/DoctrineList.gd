class_name DoctrineList
extends VBoxContainer

const DoctrineRowScene := preload("res://scenes/ui/faith/DoctrineRow.tscn")
const AXIS_ORDER: Array = ["A", "B", "C"]

var state: Node = null
var _rows: Array[DoctrineRow] = []
var _action_ids: Array[String] = []

func bind_state(s: Node) -> void:
	state = s
	if not is_inside_tree():
		return
	_build_rows()
	refresh()

func _ready() -> void:
	if state != null and _rows.is_empty():
		_build_rows()
		refresh()

func row_count() -> int:
	return _rows.size()

func row_at(index: int) -> DoctrineRow:
	if index < 0 or index >= _rows.size():
		return null
	return _rows[index]

func action_id_at(index: int) -> String:
	if index < 0 or index >= _action_ids.size():
		return ""
	return _action_ids[index]

func refresh() -> void:
	if state == null:
		return
	var religion: Religion = state.get_player_religion()
	if religion == null:
		return
	for i in range(_rows.size()):
		var action_id := _action_ids[i]
		var info: Dictionary = UIConstants.DOCTRINE_INFO[action_id]
		var value: float = religion.get_axis(info["axis"])
		_rows[i].set_doctrine(action_id, value)

func _build_rows() -> void:
	for child in get_children():
		child.queue_free()
	_rows.clear()
	_action_ids = _sorted_action_ids()
	for action_id in _action_ids:
		var row: DoctrineRow = DoctrineRowScene.instantiate()
		add_child(row)
		_rows.append(row)

func _sorted_action_ids() -> Array[String]:
	var entries: Array = []
	for action_id: String in UIConstants.DOCTRINE_INFO.keys():
		var info: Dictionary = UIConstants.DOCTRINE_INFO[action_id]
		entries.append({
			"id": action_id,
			"axis": info["axis"],
			"op": info["op"],
			"threshold": info["threshold"],
		})
	entries.sort_custom(_compare_entries)
	var result: Array[String] = []
	for entry: Dictionary in entries:
		result.append(entry["id"])
	return result

func _compare_entries(a: Dictionary, b: Dictionary) -> bool:
	var ai := AXIS_ORDER.find(a["axis"])
	var bi := AXIS_ORDER.find(b["axis"])
	if ai != bi:
		return ai < bi
	# min przed max
	if a["op"] != b["op"]:
		return a["op"] == "min"
	if a["threshold"] != b["threshold"]:
		return a["threshold"] < b["threshold"]
	return a["id"] < b["id"]
