class_name GameOverDialog
extends Control

# Modal pokazywany przez MainShell gdy gra się kończy (state.game_outcome != null,
# tryb "outcome") lub gdy religia gracza została pokonana ale gra trwa
# (tryb "player_defeat"). Wyświetla powód, tura zakończenia oraz finalny
# ranking. Emituje sygnały dla "Nowa gra" i "Zamknij".

signal new_game_pressed
signal closed

@onready var _title_label: Label = %TitleLabel
@onready var _reason_label: Label = %ReasonLabel
@onready var _turn_label: Label = %TurnLabel
@onready var _ranking_list: VBoxContainer = %RankingList
@onready var _new_game_btn: Button = %NewGameButton
@onready var _close_btn: Button = %CloseButton

# Polskie etykiety dla każdego reason ID. Spec 12 §6 (lista).
const REASON_LABELS: Dictionary = {
	"domination": "Dominacja terytorialna",
	"prestige_hegemony": "Hegemonia prestiżu",
	"holy_land": "Święta Ziemia",
	"manichaeism_illumination": "Synkretyczna Iluminacja (Manicheizm)",
	"judaism_return": "Powrót do Syjonu (Judaizm)",
	"zoroastrianism_renaissance": "Renesans Saszański (Zoroastryzm)",
	"east_christianity_pentarchy": "Pentarchia (Chrześcijaństwo Wschodnie)",
	"islam_caliphate": "Pełen Kalifat (Islam)",
	"germanic_ragnarok": "Ragnarök Triumfalny (Religie Germańskie)",
	"turn_limit": "Koniec ery (limit 200 tur)",
	"elimination": "Eliminacja",
	"long_vassalage": "Długi wasal",
}

var _state: Node = null
var _mode: String = ""	# "outcome" lub "player_defeat"
var _pending_outcome: GameOutcome = null
var _pending_defeat_id: String = ""
var _pending_defeat_reason: String = ""

func _ready() -> void:
	_new_game_btn.pressed.connect(_on_new_game_pressed)
	_close_btn.pressed.connect(_on_close_pressed)
	# Apply pending bind
	if _pending_outcome != null:
		_apply_outcome(_pending_outcome)
		_pending_outcome = null
	elif _pending_defeat_id != "":
		_apply_player_defeat(_pending_defeat_id, _pending_defeat_reason)
		_pending_defeat_id = ""
		_pending_defeat_reason = ""

func bind_state(s: Node) -> void:
	_state = s

func show_outcome(outcome: GameOutcome) -> void:
	_mode = "outcome"
	if is_inside_tree():
		_apply_outcome(outcome)
	else:
		_pending_outcome = outcome

func show_player_defeat(religion_id: String, reason: String) -> void:
	_mode = "player_defeat"
	if is_inside_tree():
		_apply_player_defeat(religion_id, reason)
	else:
		_pending_defeat_id = religion_id
		_pending_defeat_reason = reason

func _apply_outcome(outcome: GameOutcome) -> void:
	var winner_name: String = _religion_display_name(outcome.winner_id)
	_title_label.text = "KONIEC GRY — wygrał %s" % winner_name
	_reason_label.text = "Warunek: " + str(REASON_LABELS.get(outcome.reason, outcome.reason))
	_turn_label.text = "Tura: %d" % outcome.end_turn
	_populate_ranking(outcome.ranking)

func _apply_player_defeat(religion_id: String, reason: String) -> void:
	var name_str: String = _religion_display_name(religion_id)
	_title_label.text = "Przegrałeś — religia %s została pokonana" % name_str
	_reason_label.text = "Powód: " + str(REASON_LABELS.get(reason, reason))
	_turn_label.text = ""
	_populate_ranking([])

func _religion_display_name(rid: String) -> String:
	if _state != null and _state.has_method("get_religion"):
		var r: Religion = _state.get_religion(rid)
		if r != null and r.display_name != "":
			return r.display_name
	# Fallback: kapitalizacja ID (np. "islam" -> "Islam") gdy state nie jest bound
	return rid.capitalize()

func _populate_ranking(ranking: Array) -> void:
	for child in _ranking_list.get_children():
		child.queue_free()
	for i in range(ranking.size()):
		var entry: Dictionary = ranking[i]
		var label := Label.new()
		var rid: String = entry["religion_id"]
		var name_str: String = _religion_display_name(rid)
		label.text = "%d. %s — prestiż %d (%d prow.)" % [i + 1, name_str, entry["prestige"], entry["provinces"]]
		_ranking_list.add_child(label)

func _on_new_game_pressed() -> void:
	emit_signal("new_game_pressed")

func _on_close_pressed() -> void:
	emit_signal("closed")

# Test helpers (publiczne by testy mogły czytać)

func get_title_text() -> String:
	return _title_label.text if is_inside_tree() else ""

func get_reason_text() -> String:
	return _reason_label.text if is_inside_tree() else ""

func get_turn_text() -> String:
	return _turn_label.text if is_inside_tree() else ""

func get_ranking_row_count() -> int:
	return _ranking_list.get_child_count() if is_inside_tree() else 0

func press_new_game() -> void:
	_on_new_game_pressed()

func press_close() -> void:
	_on_close_pressed()
