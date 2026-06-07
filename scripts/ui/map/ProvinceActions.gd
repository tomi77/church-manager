class_name ProvinceActions
extends VBoxContainer

signal navigate_to_diplomacy(religion_id: String)
signal war_declared(defender_id: String, cb: String)
signal missionaries_sent(target_id: String)

var state: Node = null
var province_id: String = ""

@onready var _war_btn: Button = %WarButton
@onready var _mission_btn: Button = %MissionButton
@onready var _diplomacy_btn: Button = %DiplomacyButton
@onready var _cb_picker: Node = %CBPicker

func _ready() -> void:
    _war_btn.pressed.connect(_on_war_pressed)
    _mission_btn.pressed.connect(_on_mission_pressed)
    _diplomacy_btn.pressed.connect(_on_diplomacy_pressed)
    if _cb_picker.has_signal("cb_chosen"):
        _cb_picker.cb_chosen.connect(_on_cb_chosen)
    if _cb_picker.has_signal("cancelled"):
        _cb_picker.cancelled.connect(_on_cb_cancelled)
    if state != null and province_id != "":
        refresh()

func bind(s: Node, pid: String) -> void:
    state = s
    province_id = pid
    if is_inside_tree():
        refresh()

func refresh() -> void:
    if state == null or province_id == "":
        return
    var prov: Province = state.province_graph.get_province(province_id)
    if prov == null:
        return
    var player: Religion = state.get_player_religion()
    var owner_id := prov.owner
    var is_player_owned := owner_id == player.id

    if is_player_owned:
        _war_btn.visible = false
        _mission_btn.visible = false
        _diplomacy_btn.visible = false
        _cb_picker.visible = false
        return

    _war_btn.visible = true
    _mission_btn.visible = true
    _diplomacy_btn.visible = true

    var target: Religion = state.get_religion(owner_id)
    _refresh_war_button(player, target, prov)
    _refresh_mission_button(player, target)
    _diplomacy_btn.disabled = false
    _diplomacy_btn.tooltip_text = "Otwórz panel dyplomacji dla religii %s" % target.display_name

func _refresh_war_button(player: Religion, target: Religion, prov: Province) -> void:
    var has_neighbor := _player_has_neighbor_of(prov, player)
    var wm := WarManager.new()
    var cbs := wm.available_casus_belli(player, target, state)
    var enabled := has_neighbor and cbs.size() > 0
    _war_btn.disabled = not enabled
    if not has_neighbor:
        _war_btn.tooltip_text = "Brak sąsiedztwa: żadna twoja prowincja nie sąsiaduje z %s" % prov.display_name
    elif cbs.size() == 0:
        _war_btn.tooltip_text = "Brak casus belli przeciw %s" % target.display_name
    else:
        _war_btn.tooltip_text = "Dostępne CB: %s" % ", ".join(cbs)

func _refresh_mission_button(player: Religion, target: Religion) -> void:
    var dm := DiplomacyManager.new()
    var ekskluzywizm_ok := player.get_axis("C") >= DiplomacyManager.MISSIONARIES_EXCLUSIVITY_BLOCK
    var rel: RelationState = dm.get_or_create_relation(state, player.id, target.id)
    var trust_ok := rel.theological_trust > DiplomacyManager.MISSIONARIES_TRUST_THRESHOLD
    var tension_ok := rel.military_tension <= DiplomacyManager.BLOCK_TENSION_FOR_DIALOGUE
    var cost: int = int(round(DiplomacyManager.MISSIONARIES_PRESTIGE_COST))
    var prestige_ok := player.prestige >= cost
    var enabled := ekskluzywizm_ok and trust_ok and tension_ok and prestige_ok
    _mission_btn.disabled = not enabled
    if not enabled:
        var reasons: Array[String] = []
        if not ekskluzywizm_ok: reasons.append("Twój Ekskluzywizm blokuje (Synkretyzm <20)")
        if not trust_ok: reasons.append("trust ≤30")
        if not tension_ok: reasons.append("napięcie >85")
        if not prestige_ok: reasons.append("prestiż <%d" % cost)
        _mission_btn.tooltip_text = "Niedostępne: " + ", ".join(reasons)
    else:
        _mission_btn.tooltip_text = "Wyślij misjonarza do %s (koszt %d prestiżu)" % [target.display_name, cost]

func _player_has_neighbor_of(prov: Province, player: Religion) -> bool:
    var graph: ProvinceGraph = state.province_graph
    for n_id: String in graph.get_neighbors(prov.id):
        var n: Province = graph.get_province(n_id)
        if n != null and n.owner == player.id:
            return true
    return false

func _on_war_pressed() -> void:
    var prov: Province = state.province_graph.get_province(province_id)
    var player: Religion = state.get_player_religion()
    var target: Religion = state.get_religion(prov.owner)
    var wm := WarManager.new()
    var cbs := wm.available_casus_belli(player, target, state)
    if cbs.size() == 1:
        _execute_war(target.id, cbs[0])
    elif cbs.size() > 1:
        _cb_picker.open(cbs, target.id)

func _on_cb_chosen(cb: String, defender_id: String) -> void:
    _execute_war(defender_id, cb)

func _on_cb_cancelled() -> void:
    if state != null and province_id != "":
        refresh()

func _execute_war(defender_id: String, cb: String) -> void:
    var wm := WarManager.new()
    var war := wm.declare_war(state.get_player_religion().id, defender_id, cb, state)
    if war != null:
        emit_signal("war_declared", defender_id, cb)
        refresh()

func _on_mission_pressed() -> void:
    var prov: Province = state.province_graph.get_province(province_id)
    var dm := DiplomacyManager.new()
    if dm.send_missionaries(state, state.get_player_religion().id, prov.owner):
        emit_signal("missionaries_sent", prov.owner)
        refresh()

func _on_diplomacy_pressed() -> void:
    var prov: Province = state.province_graph.get_province(province_id)
    if prov != null:
        emit_signal("navigate_to_diplomacy", prov.owner)
