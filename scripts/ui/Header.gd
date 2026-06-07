class_name Header
extends HBoxContainer

signal turn_ended

@onready var _icon: Label = %IconLabel
@onready var _name: Label = %NameLabel
@onready var _turn: Label = %TurnLabel
@onready var _prestige: Label = %PrestigeLabel
@onready var _resources: Label = %ResourcesLabel
@onready var _food: Label = %FoodLabel
@onready var _wars: Label = %WarsLabel
@onready var _faction_alert: Label = %FactionAlertLabel
@onready var _end_turn_btn: Button = %EndTurnButton

var state: Node = null

func _ready() -> void:
    _end_turn_btn.pressed.connect(_on_end_turn_pressed)

func bind_state(s: Node) -> void:
    state = s
    refresh()

func refresh() -> void:
    if state == null:
        return
    var player: Religion = state.get_player_religion()
    if player == null:
        return
    _icon.text = player.icon
    _name.text = player.display_name
    _turn.text = "Tura %d" % state.current_turn
    _prestige.text = "⚑ %d" % player.prestige

    var income := _compute_income(player)
    _resources.text = "📦 %+d/turę" % income
    _food.text = "🌾 %+d/turę" % _compute_food(player)

    var active_wars := _count_active_wars(player.id)
    _wars.text = "⚔ %d aktywna" % active_wars
    _wars.modulate = Color(1.0, 0.4, 0.4) if active_wars > 0 else Color(0.7, 0.7, 0.7)

    var dom := player.dominant_faction()
    if dom != null and dom.tension > 80.0:
        _faction_alert.text = "⚠ Frakcja %s: napięcie %d" % [dom.id, int(dom.tension)]
        _faction_alert.visible = true
    else:
        _faction_alert.visible = false

func _compute_income(player: Religion) -> int:
    var income := DiplomacyManager.PASSIVE_INCOME_PER_TURN
    if player.suzerain_id != "":
        income -= DiplomacyManager.TRIBUTE_PER_TURN
    for r: Religion in state.all_religions():
        if r.suzerain_id == player.id:
            income += DiplomacyManager.TRIBUTE_PER_TURN
    return income

func _compute_food(player: Religion) -> int:
    var total := 0
    for prov: Province in state.province_graph.provinces_with_owner(player.id):
        total += int(prov.resources.get("food", 0))
    return total

func _count_active_wars(player_id: String) -> int:
    var n := 0
    for war: War in state.active_wars:
        if war.state == "ENDED":
            continue
        if war.attacker_id == player_id or war.defender_id == player_id:
            n += 1
    return n

func _on_end_turn_pressed() -> void:
    if state == null:
        return
    var tm := TurnManager.new()
    tm.process_turn(state)
    refresh()
    emit_signal("turn_ended")
