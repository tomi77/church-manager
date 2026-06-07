class_name MainShell
extends Control

@onready var _header: Header = %Header
@onready var _tab_bar: UITabBar = %TabBar
@onready var _content := %ContentArea
@onready var _mapa_tab: MapaTab = %MapaTab
@onready var _wiara_tab: PlaceholderTab = %WiaraTab
@onready var _swiat_tab: Control = %SwiatTab
@onready var _frakcje_tab: PlaceholderTab = %FrakcjeTab

var state: Node = null

func _ready() -> void:
    _wiara_tab.set_title("Wiara (Plan 10 — w trakcie)")
    _frakcje_tab.set_title("Frakcje (Plan 11 — w trakcie)")
    _tab_bar.tab_changed.connect(_on_tab_changed)
    _mapa_tab.navigate_to_diplomacy.connect(_on_navigate_to_diplomacy)
    _mapa_tab.state_changed.connect(_on_swiat_state_changed)
    _header.turn_ended.connect(_on_turn_ended)
    if _swiat_tab.has_signal("state_changed"):
        _swiat_tab.state_changed.connect(_on_swiat_state_changed)
    _on_tab_changed(_tab_bar.current_tab)

func bind_state(s: Node) -> void:
    state = s
    _header.bind_state(s)
    _tab_bar.bind_state(s)
    _mapa_tab.bind_state(s)
    if _swiat_tab.has_method("bind_state"):
        _swiat_tab.bind_state(s)
    refresh()

func refresh() -> void:
    _header.refresh()
    _tab_bar.refresh()
    if _mapa_tab.has_method("refresh"):
        _mapa_tab.refresh()
    if _swiat_tab.has_method("refresh"):
        _swiat_tab.refresh()

func _on_tab_changed(tab_id: String) -> void:
    _mapa_tab.visible = tab_id == "mapa"
    _wiara_tab.visible = tab_id == "wiara"
    _swiat_tab.visible = tab_id == "swiat"
    _frakcje_tab.visible = tab_id == "frakcje"

func _on_turn_ended() -> void:
    refresh()

func _on_swiat_state_changed() -> void:
    refresh()

func _on_navigate_to_diplomacy(religion_id: String) -> void:
    _tab_bar.set_current_tab("swiat")
    if _swiat_tab.has_method("preselect_religion"):
        _swiat_tab.preselect_religion(religion_id)

func set_current_tab(tab_id: String) -> void:
    _tab_bar.set_current_tab(tab_id)
