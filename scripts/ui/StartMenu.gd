class_name StartMenu
extends Control

signal religion_selected(id: String)

var _selected_id: String = ""
var _religions: Array[Religion] = []

@onready var _grid: GridContainer = %ReligionGrid
@onready var _info_label: Label = %SelectedInfoLabel
@onready var _start_btn: Button = %StartButton

func _ready() -> void:
	_religions = ReligionLoader.load_from_file("res://data/religions_historical.json")
	_populate_grid()
	_start_btn.disabled = true
	_start_btn.pressed.connect(_on_start_pressed)

func _populate_grid() -> void:
	for r: Religion in _religions:
		var btn := Button.new()
		btn.text = "%s\n%s" % [r.icon, r.display_name]
		btn.custom_minimum_size = Vector2(180, 100)
		btn.pressed.connect(_on_card_pressed.bind(r.id))
		_grid.add_child(btn)

func _on_card_pressed(religion_id: String) -> void:
	_selected_id = religion_id
	var r := _find_religion(religion_id)
	if r != null:
		_info_label.text = "Wybrana: %s" % r.display_name
	_start_btn.disabled = false
	emit_signal("religion_selected", religion_id)

func _on_start_pressed() -> void:
	if _selected_id == "":
		return
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	GameState.initialize(_selected_id, religions, graph)
	get_tree().change_scene_to_file("res://scenes/ui/MainShell.tscn")

func _find_religion(id: String) -> Religion:
	for r: Religion in _religions:
		if r.id == id:
			return r
	return null
