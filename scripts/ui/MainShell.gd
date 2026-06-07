class_name MainShell
extends Control

@onready var _header: Header = %Header
@onready var _tab_bar: UITabBar = %TabBar
@onready var _content := %ContentArea
@onready var _mapa_tab: PlaceholderTab = %MapaTab
@onready var _wiara_tab: PlaceholderTab = %WiaraTab
@onready var _swiat_tab: Control = %SwiatTab
@onready var _frakcje_tab: PlaceholderTab = %FrakcjeTab

var state: Node = null

func _ready() -> void:
    _mapa_tab.set_title("Mapa (Plan 09 — w trakcie)")
    _wiara_tab.set_title("Wiara (Plan 10 — w trakcie)")
    _frakcje_tab.set_title("Frakcje (Plan 11 — w trakcie)")
    _tab_bar.tab_changed.connect(_on_tab_changed)
    _header.turn_ended.connect(_on_turn_ended)
    _on_tab_changed(_tab_bar.current_tab)

func bind_state(s: Node) -> void:
    state = s
    _header.bind_state(s)
    _tab_bar.bind_state(s)
    if _swiat_tab.has_method("bind_state"):
        _swiat_tab.bind_state(s)
    refresh()

func refresh() -> void:
    _header.refresh()
    _tab_bar.refresh()
    if _swiat_tab.has_method("refresh"):
        _swiat_tab.refresh()

func _on_tab_changed(tab_id: String) -> void:
    _mapa_tab.visible = tab_id == "mapa"
    _wiara_tab.visible = tab_id == "wiara"
    _swiat_tab.visible = tab_id == "swiat"
    _frakcje_tab.visible = tab_id == "frakcje"

func _on_turn_ended() -> void:
    refresh()
