# scripts/engine/DoctrineManager.gd
class_name DoctrineManager
extends RefCounted

const SOBOR_PRESTIGE_COST := 30
const EDICT_PRESTIGE_COST := 15
const EDICT_MAX_DELTA := 5.0
const FACTION_TENSION_FROM_SOBOR := 8.0
const SCHOLAR_MISSION_TURNS := 3
const IDEA_MIN_AXIS_DIFF := 10.0
const IDEA_DELTA_FACTOR := 0.3
const IDEA_MAX_DELTA := 8.0

const AXIS_THRESHOLDS: Dictionary = {
	"A": [
		{"min": 75.0, "actions": ["kanon_doktryny"]},
		{"max": 25.0, "actions": ["objawienie"]},
	],
	"B": [
		{"min": 75.0, "actions": ["papieskie_interdykty"]},
		{"max": 25.0, "actions": ["sobor_ludowy"]},
	],
	"C": [
		{"min": 75.0, "actions": ["ekumenizm", "obrzad_fuzji"]},
		{"max": 25.0, "actions": ["inkwizycja", "klatwa"]},
	],
	# Oś D (Doczesność↔Transcendencja) nie ma akcji progowych w tym PoC — celowe pominięcie.
}

func available_threshold_actions(religion: Religion) -> Array[String]:
	var result: Array[String] = []
	for axis: String in AXIS_THRESHOLDS.keys():
		var value := religion.get_axis(axis)
		for rule: Dictionary in AXIS_THRESHOLDS[axis]:
			if rule.has("min") and value >= rule["min"]:
				for action: String in rule["actions"]:
					result.append(action)
			elif rule.has("max") and value <= rule["max"]:
				for action: String in rule["actions"]:
					result.append(action)
	return result
