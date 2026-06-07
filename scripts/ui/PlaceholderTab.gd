class_name PlaceholderTab
extends Control

@export var title: String = "Placeholder"

@onready var _label: Label = %TitleLabel

func _ready() -> void:
    _refresh()

func set_title(new_title: String) -> void:
    title = new_title
    if is_inside_tree():
        _refresh()

func _refresh() -> void:
    _label.text = title
