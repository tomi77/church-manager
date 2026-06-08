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
	"religie_slowianski": Color("0a1210"),
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

# Kolory akcentu religii (per spec 06 sekcja 3 — outline radaru, obrysy, akcenty)
const RELIGION_ACCENT_COLORS: Dictionary = {
	"islam": Color("5aaa5a"),
	"chr_zachodnie": Color("7a7aff"),
	"chr_wschodnie": Color("6a6aee"),
	"judaizm": Color("bbaa00"),
	"zoroastryzm": Color("cc7a1a"),
	"koptyjski": Color("4aaa6a"),
	"manicheizm": Color("cc55cc"),
	"religie_arabskie": Color("dd9922"),
	"hinduizm": Color("ee5533"),
	"buddyzm": Color("33bbcc"),
	"religie_germanskie": Color("88cc44"),
	"religie_slowianski": Color("55bb88"),
}
const RELIGION_ACCENT_COLOR_DEFAULT: Color = Color(0.7, 0.7, 0.7)

static func religion_accent_color(religion_id: String) -> Color:
	return RELIGION_ACCENT_COLORS.get(religion_id, RELIGION_ACCENT_COLOR_DEFAULT)

# Trait info — 12 wpisów, wiernie zsumaryzowane z 05-religion-profiles-design.md
const TRAIT_INFO: Dictionary = {
	"umma": {
		"name": "Umma",
		"description": "Próg CB Dżihadu obniżony o dodatkowe −5 (łącznie −15). Kontrola Mekki: każda prowincja Islamu globalnie +1 prestiż/turę.",
	},
	"cezaropapizm": {
		"name": "Cezaropapizm",
		"description": "Cesarz może zwołać Sobór raz na epokę za darmo. Napięcie przegranej frakcji ×2.",
	},
	"sukcesja_apostolska": {
		"name": "Sukcesja Apostolska",
		"description": "Klienci uznający Rzym jako patrona: −10% odporności na Synkretyzm. Rzym zyskuje +5 prestiżu za każde nowe Uznanie.",
	},
	"diaspora": {
		"name": "Diaspora",
		"description": "Prowincje utracone nadal generują +1 prestiż/turę. Synagogi w obcych prowincjach (10 złota): +0.5 presji/turę.",
	},
	"zmartwychwstanie_saszanskie": {
		"name": "Zmartwychwstanie Saszańskie",
		"description": "Przy <5 prowincjach: pasywna presja sąsiedzka ×2. Kontrola persepolis: +10% Modyfikator CB we wszystkich kampaniach.",
	},
	"pamiec_pustynna": {
		"name": "Pamięć Pustynna",
		"description": "Akcja [Ojciec Pustyni] (15 prestiżu): mnich do prowincji w odległości do 3 kroków grafu. Po 5 turach +20 presji jednorazowo.",
	},
	"synkretyzm_radykalny": {
		"name": "Synkretyzm Radykalny",
		"description": "Akcja [Zaakceptuj Ideę] bez kosztu prestiżu. Może absorbować doktryny od 2 religii naraz. +5 napięcia Wybranych.",
	},
	"pluralizm_plemienny": {
		"name": "Pluralizm Plemienny",
		"description": "Misjonarze bez limitu liczby. 40% szansy „schizmy plemiennej\" przy każdym zdobyciu nowej prowincji.",
	},
	"dharma_i_varna": {
		"name": "Dharma i Varna",
		"description": "Immunizacja na obowiązkowe CB doktrynalne. Prowincja kontrolowana 10+ tur: +2 żywność. Konwersja przez najeźdźcę: +20% kosztu presji.",
	},
	"srodkowa_droga": {
		"name": "Środkowa Droga",
		"description": "Immunizacja na obowiązkowe CB doktrynalne. Akcja [Dharma-Yatra] (25 prestiżu): pielgrzymi przez do 5 kroków grafu.",
	},
	"ragnarok": {
		"name": "Ragnarök",
		"description": "Po utracie >50% prowincji startowych: tryb [Zmierzch Bogów] — Modyfikator CB +20%, zmęczenie wojenne narasta 50% wolniej.",
	},
	"ziemia_i_krew": {
		"name": "Ziemia i Krew",
		"description": "Prowincje góry/pustynia/żyzne: +1 żywność extra. Atak na słowiańską prowincję: dodatkowe −10% siły najeźdźcy.",
	},
}

# Doctrine info — 8 wpisów, parytet z DoctrineManager.AXIS_THRESHOLDS (test_doctrine_info_parity.gd)
const DOCTRINE_INFO: Dictionary = {
	"dogma_canon": {
		"name": "Kanon Doktrynalny",
		"axis": "A", "op": "min", "threshold": 75.0,
		"description": "Ortodoksja chroni przed obcymi ideami.",
	},
	"mystical_revelation": {
		"name": "Objawienie Mistyczne",
		"axis": "A", "op": "max", "threshold": 25.0,
		"description": "Mistyczna interpretacja otwiera nowe doktryny.",
	},
	"papal_interdicts": {
		"name": "Papieskie Interdykty",
		"axis": "B", "op": "min", "threshold": 75.0,
		"description": "Hierarchia może rzucać Interdykt.",
	},
	"popular_council": {
		"name": "Sobór Ludowy",
		"axis": "B", "op": "max", "threshold": 25.0,
		"description": "Egalitarne sobory tańsze o połowę.",
	},
	"ecumenism": {
		"name": "Ekumenizm",
		"axis": "C", "op": "min", "threshold": 75.0,
		"description": "Łatwiejsza absorpcja doktryn obcych religii.",
	},
	"fusion_rite": {
		"name": "Obrzęd Fuzji",
		"axis": "C", "op": "min", "threshold": 75.0,
		"description": "Możliwa fuzja z religią synkretyczną.",
	},
	"inquisition": {
		"name": "Inkwizycja",
		"axis": "C", "op": "max", "threshold": 25.0,
		"description": "Schizmy odpierane brutalnie.",
	},
	"anathema": {
		"name": "Klątwa",
		"axis": "C", "op": "max", "threshold": 25.0,
		"description": "Można rzucić klątwę na heretyka.",
	},
}
