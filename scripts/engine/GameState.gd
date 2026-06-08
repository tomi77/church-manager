extends Node

var current_turn: int = 1
var player_religion_id: String = ""
var province_graph: ProvinceGraph = null

var _religions: Dictionary = {}
var pending_ideas: Array[Idea] = []
var scholar_missions: Array = []  # Untyped: Array[Dictionary] not supported as typed array in GDScript 2.0
var active_wars: Array[War] = []
var pending_defeat_events: Array[DefeatEvent] = []
var relations: Array[RelationState] = []
var active_coalitions: Array[Coalition] = []
var missionary_missions: Array[MissionaryMission] = []

var game_outcome: GameOutcome = null
var victory_progress: Dictionary = {}	# religion_id → {domination_turns: int, prestige_hegemony_turns: int}
var defeat_progress: Dictionary = {}	# religion_id → {zero_provinces_turns: int, vassalage_turns: int}

func initialize(player_id: String, religions: Array[Religion], graph: ProvinceGraph) -> void:
	player_religion_id = player_id
	province_graph = graph
	_religions.clear()
	for r: Religion in religions:
		_religions[r.id] = r
	# Po wpisaniu wszystkich religii i grafu — snapshot startowych prowincji per religia
	# (potrzebny dla warunku Ragnarök w spec 12 §4.2) oraz ustawienie ever_owned_province
	# (prereq dla D1/D2 w spec 12 §5).
	for r: Religion in religions:
		var owned: Array[String] = []
		for province in graph.provinces_with_owner(r.id):
			owned.append(province.id)
		r.starting_provinces_snapshot = owned
		if not owned.is_empty():
			r.ever_owned_province = true

func get_player_religion() -> Religion:
	return get_religion(player_religion_id)

func get_religion(religion_id: String) -> Religion:
	return _religions.get(religion_id, null)

func all_religions() -> Array[Religion]:
	var result: Array[Religion] = []
	for r: Religion in _religions.values():
		result.append(r)
	return result

func add_religion(religion: Religion) -> void:
	_religions[religion.id] = religion

func advance_turn() -> void:
	current_turn += 1

func is_game_over() -> bool:
	return game_outcome != null

func reset() -> void:
	# Zeruje wszystkie pola do stanu sprzed initialize(). Wywoływane przez GameOverDialog
	# "Nowa gra" przed change_scene_to_file. Autoload jest persistent w Godot — brak resetu
	# powoduje wyciek stanu między grami.
	#
	# CRITICAL: gdy w przyszłości dojdzie nowe pole do GameState, MUSI tu trafić.
	# Test test_reset_* w tests/engine/test_game_state.gd weryfikuje każde pole osobno.
	current_turn = 1
	player_religion_id = ""
	province_graph = null
	_religions.clear()
	pending_ideas.clear()
	scholar_missions.clear()
	active_wars.clear()
	pending_defeat_events.clear()
	relations.clear()
	active_coalitions.clear()
	missionary_missions.clear()
	game_outcome = null
	victory_progress.clear()
	defeat_progress.clear()
