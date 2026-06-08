class_name MainShell
extends Control

@onready var _header: Header = %Header
@onready var _tab_bar: UITabBar = %TabBar
@onready var _content := %ContentArea
@onready var _map_tab: MapTab = %MapTab
@onready var _faith_tab: FaithTab = %FaithTab
@onready var _world_tab: Control = %WorldTab
@onready var _factions_tab: FactionsTab = %FactionsTab

var state: Node = null

func _ready() -> void:
	_tab_bar.tab_changed.connect(_on_tab_changed)
	_map_tab.navigate_to_diplomacy.connect(_on_navigate_to_diplomacy)
	_map_tab.state_changed.connect(_on_world_state_changed)
	_header.turn_ended.connect(_on_turn_ended)
	if _world_tab.has_signal("state_changed"):
		_world_tab.state_changed.connect(_on_world_state_changed)
	_on_tab_changed(_tab_bar.current_tab)
	# Live mode: StartMenu inicjalizuje autoload GameState i zmienia scenę.
	# Sami podpinamy autoload, bo nikt inny nas nie spina. Testy nadpisują własnym state.
	if state == null and GameState.player_religion_id != "":
		bind_state(GameState)

func bind_state(s: Node) -> void:
	state = s
	_header.bind_state(s)
	_tab_bar.bind_state(s)
	_map_tab.bind_state(s)
	_faith_tab.bind_state(s)
	_factions_tab.bind_state(s)
	if _world_tab.has_method("bind_state"):
		_world_tab.bind_state(s)
	refresh()

func refresh() -> void:
	_header.refresh()
	_tab_bar.refresh()
	if _map_tab.has_method("refresh"):
		_map_tab.refresh()
	_faith_tab.refresh()
	_factions_tab.refresh()
	if _world_tab.has_method("refresh"):
		_world_tab.refresh()

func _on_tab_changed(tab_id: String) -> void:
	_map_tab.visible = tab_id == "map"
	_faith_tab.visible = tab_id == "faith"
	_world_tab.visible = tab_id == "world"
	_factions_tab.visible = tab_id == "factions"

func _on_turn_ended() -> void:
	refresh()

func _on_world_state_changed() -> void:
	refresh()

func _on_navigate_to_diplomacy(religion_id: String) -> void:
	_tab_bar.set_current_tab("world")
	if _world_tab.has_method("preselect_religion"):
		_world_tab.preselect_religion(religion_id)

func set_current_tab(tab_id: String) -> void:
	_tab_bar.set_current_tab(tab_id)
