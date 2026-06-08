class_name MainShell
extends Control

const GameOverDialogScene := preload("res://scenes/ui/dialogs/GameOverDialog.tscn")

@onready var _header: Header = %Header
@onready var _tab_bar: UITabBar = %TabBar
@onready var _content := %ContentArea
@onready var _map_tab: MapTab = %MapTab
@onready var _faith_tab: FaithTab = %FaithTab
@onready var _world_tab: Control = %WorldTab
@onready var _factions_tab: FactionsTab = %FactionsTab

var state: Node = null

# Flagi zapobiegające ponownemu pokazaniu modalu przy każdym refresh().
var _shown_outcome_modal: bool = false
var _shown_defeat_modal: bool = false
var _active_dialog: GameOverDialog = null

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
	_refresh_game_over_state()

func _refresh_game_over_state() -> void:
	if state == null:
		return
	# 1) Sprawdź game_outcome (wygrana / cap turowy)
	if state.game_outcome != null and not _shown_outcome_modal:
		_shown_outcome_modal = true
		_show_outcome_dialog(state.game_outcome)
		_header.set_end_turn_enabled(false)
		return
	# 2) Sprawdź czy gracz przegrał (defeated_at_turn != -1)
	if not _shown_defeat_modal:
		var player: Religion = state.get_player_religion()
		if player != null and player.defeated_at_turn != -1:
			_shown_defeat_modal = true
			_show_player_defeat_dialog(player)

func _show_outcome_dialog(outcome: GameOutcome) -> void:
	_active_dialog = GameOverDialogScene.instantiate()
	add_child(_active_dialog)
	_active_dialog.bind_state(state)
	_active_dialog.show_outcome(outcome)
	_active_dialog.new_game_pressed.connect(_on_new_game_pressed)
	_active_dialog.closed.connect(_on_dialog_closed)

func _show_player_defeat_dialog(player: Religion) -> void:
	_active_dialog = GameOverDialogScene.instantiate()
	add_child(_active_dialog)
	_active_dialog.bind_state(state)
	# Spec 12 I3: powód zapisany na Religion przez VictoryManager w momencie wykrycia przegranej.
	# Fallback "elimination" dla retrofitu — religie pokonane przed wprowadzeniem pola.
	var reason: String = player.defeated_reason if player.defeated_reason != "" else "elimination"
	_active_dialog.show_player_defeat(player.id, reason)
	_active_dialog.new_game_pressed.connect(_on_new_game_pressed)
	_active_dialog.closed.connect(_on_dialog_closed)

func _on_new_game_pressed() -> void:
	if state != null and state.has_method("reset"):
		state.reset()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_dialog_closed() -> void:
	if _active_dialog != null:
		_active_dialog.queue_free()
		_active_dialog = null

# Test helpers — publiczne by testy mogły inspekcjonować stan modalu.

func get_active_game_over_dialog_count() -> int:
	var count: int = 0
	for child in get_children():
		if child is GameOverDialog:
			count += 1
	return count

func is_end_turn_disabled() -> bool:
	return _header.is_end_turn_disabled()

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
