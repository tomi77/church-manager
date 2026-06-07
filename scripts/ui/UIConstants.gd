class_name UIConstants
extends RefCounted

const TENSION_ALERT_THRESHOLD: float = 80.0

const COLOR_WARS_ACTIVE: Color = Color(1.0, 0.4, 0.4)
const COLOR_WARS_IDLE: Color = Color(0.7, 0.7, 0.7)

const COLOR_TAB_ACTIVE: Color = Color(1.0, 1.0, 1.0)
const COLOR_TAB_INACTIVE: Color = Color(0.6, 0.6, 0.6)

const COLOR_LIST_ITEM_SELECTED: Color = Color(1.1, 1.1, 1.1)
const COLOR_LIST_ITEM_DEFAULT: Color = Color(1.0, 1.0, 1.0)

const COLOR_PICKER_SELECTED: Color = Color(0.4, 1.0, 0.4)
const COLOR_PICKER_UNSELECTED: Color = Color(0.7, 0.7, 0.7)

# Paleta religii (per spec 06 sekcja 3 — kolor wielokąta na mapie)
const RELIGION_COLORS: Dictionary = {
	"islam": Color("0d3a1a"),
	"chr_zachodnie": Color("0a0a2a"),
	"chr_wschodnie": Color("0a0a22"),
	"judaizm": Color("1a1600"),
	"zoroastryzm": Color("1a0d00"),
	"koptyjski": Color("0d1a10"),
	"manicheizm": Color("180818"),
	"religie_arabskie": Color("1a1000"),
	"hinduizm": Color("1a0808"),
	"buddyzm": Color("001518"),
	"religie_germanskie": Color("0d1408"),
	"religie_slowianskie": Color("0a1210"),
}
const RELIGION_COLOR_DEFAULT: Color = Color(0.3, 0.3, 0.3)

# Mapa: rozmiary i kolory węzłów
const MAP_NODE_SIZE: Vector2 = Vector2(60, 40)
const MAP_NODE_OUTLINE_SELECTED: Color = Color(1.0, 1.0, 1.0)
const MAP_NODE_OUTLINE_DEFAULT: Color = Color(0.4, 0.4, 0.4)
const MAP_NODE_OUTLINE_WIDTH_SELECTED: float = 3.0
const MAP_NODE_OUTLINE_WIDTH_DEFAULT: float = 1.0
const MAP_EDGE_WIDTH: float = 2.0
const MAP_EDGE_COLOR: Color = Color(0.5, 0.5, 0.5, 0.6)

static func religion_color(religion_id: String) -> Color:
	return RELIGION_COLORS.get(religion_id, RELIGION_COLOR_DEFAULT)
