class_name UITabBar
extends HBoxContainer

signal tab_changed(tab_id: String)

const TABS := ["mapa", "wiara", "swiat", "frakcje"]
const LABELS := {"mapa": "🗺 Mapa", "wiara": "🕌 Wiara", "swiat": "🌍 Świat", "frakcje": "👥 Frakcje"}

var current_tab: String = "swiat"
var state: Node = null

@onready var _buttons := {
    "mapa": %MapaButton,
    "wiara": %WiaraButton,
    "swiat": %SwiatButton,
    "frakcje": %FrakcjeButton,
}
@onready var _dots := {
    "mapa": %MapaDot,
    "wiara": %WiaraDot,
    "swiat": %SwiatDot,
    "frakcje": %FrakcjeDot,
}

func _ready() -> void:
    for tab_id: String in TABS:
        var btn: Button = _buttons[tab_id]
        btn.text = LABELS[tab_id]
        btn.pressed.connect(_on_tab_pressed.bind(tab_id))
    _refresh_active()

func bind_state(s: Node) -> void:
    state = s
    refresh()

func set_current_tab(tab_id: String) -> void:
    if not tab_id in TABS:
        return
    current_tab = tab_id
    _refresh_active()
    emit_signal("tab_changed", tab_id)

func refresh() -> void:
    _refresh_active()
    _refresh_dots()

func _refresh_active() -> void:
    for tab_id: String in TABS:
        var btn: Button = _buttons[tab_id]
        btn.modulate = UIConstants.COLOR_TAB_ACTIVE if tab_id == current_tab else UIConstants.COLOR_TAB_INACTIVE

func _refresh_dots() -> void:
    for tab_id: String in TABS:
        _dots[tab_id].visible = _should_alert(tab_id)

func _should_alert(tab_id: String) -> bool:
    if state == null:
        return false
    var player: Religion = state.get_player_religion()
    if player == null:
        return false
    if tab_id == "swiat":
        # Alert gdy koalicja przeciw graczowi LUB grievance window aktywne
        for c: Coalition in state.active_coalitions:
            if c.target_id == player.id:
                return true
        if player.interdict_grievance_until > state.current_turn and player.interdict_grievance_from_id != "":
            return true
    elif tab_id == "frakcje":
        var dom: Faction = player.dominant_faction()
        if dom != null and dom.tension > UIConstants.TENSION_ALERT_THRESHOLD:
            return true
    return false

func _on_tab_pressed(tab_id: String) -> void:
    set_current_tab(tab_id)
