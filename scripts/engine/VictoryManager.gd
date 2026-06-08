class_name VictoryManager
extends RefCounted

# Stateless manager sprawdzający warunki zwycięstwa i przegranej.
# Spec: docs/superpowers/specs/12-victory-conditions-design.md
# Wywoływany przez TurnManager.process_turn na końcu, po state.advance_turn().

# === Stałe uniwersalne — kalibracja do mapy historycznej (12 prowincji) ===

const TURN_LIMIT := 200								# hard cap; po tym tura wygrywa religia z najwyższym prestiżem
const DOMINATION_PROVINCE_SHARE := 0.5				# ≥50% wszystkich prowincji
const DOMINATION_TURNS_REQUIRED := 3				# kolejnych tur ze spełnionym progiem dominacji
const PRESTIGE_HEGEMONY_RATIO := 2.0				# prestiż ≥ 2× drugiej najwyższej
const PRESTIGE_HEGEMONY_TURNS_REQUIRED := 10		# kolejnych tur ze spełnionym progiem hegemonii
const ELIMINATION_TURNS_REQUIRED := 5				# 0 prowincji przez N kolejnych tur (D1)
const VASSAL_DEFEAT_TURNS_REQUIRED := 20			# suzerain_id != "" przez N kolejnych tur (D2)
const SCHISM_GRACE_TURNS := 10						# nowa religia ze schizmy nie może wygrać przez N tur

# === Stałe unikalne per religia ===

const JUDAISM_PROVINCES_REQUIRED := 4
const JUDAISM_JERUSALEM_ID := "jerozolima"
const JUDAISM_FACTION_UNITY_TENSION_MAX := 30.0

const ZOROASTRIANISM_PROVINCES_REQUIRED := 3
const ZOROASTRIANISM_PERSEPOLIS_ID := "persepolis"

const ISLAM_PROVINCES_REQUIRED := 5
const ISLAM_MEKKA_ID := "mekka"
const ISLAM_JERUSALEM_ID := "jerozolima"

const EAST_CHRISTIANITY_VASSALS_REQUIRED := 3

const MANICHAEISM_AXIS_C_REQUIRED := 90.0
const MANICHAEISM_DISTINCT_SOURCES_REQUIRED := 4

# === Public API (implementacja w kolejnych taskach) ===

func check(state: Node) -> void:
	# Spec §6: główny entry point. Pełna pipeline w Task 13.
	pass

func update_flags(state: Node) -> void:
	pass

func update_counters(state: Node) -> void:
	pass

func evaluate_universal_victory(religion: Religion, state: Node) -> String:
	return ""

func evaluate_unique_victory(religion: Religion, state: Node) -> String:
	return ""

func evaluate_defeat(religion: Religion, state: Node) -> String:
	return ""

func compute_ranking(state: Node, exclude_defeated: bool = true) -> Array:
	return []
