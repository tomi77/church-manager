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

# Każda reguła: {"min": X} = oś >= X, {"max": X} = oś <= X. Klucze są wzajemnie wykluczające się.
const AXIS_THRESHOLDS: Dictionary = {
	"A": [
		{"min": 75.0, "actions": ["dogma_canon"]},
		{"max": 25.0, "actions": ["mystical_revelation"]},
	],
	"B": [
		{"min": 75.0, "actions": ["papal_interdicts"]},
		{"max": 25.0, "actions": ["popular_council"]},
	],
	"C": [
		{"min": 75.0, "actions": ["ecumenism", "fusion_rite"]},
		{"max": 25.0, "actions": ["inquisition", "anathema"]},
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

func call_sobor(religion: Religion, axis: String, delta: float) -> bool:
	if religion.prestige < SOBOR_PRESTIGE_COST:
		return false
	religion.add_prestige(-SOBOR_PRESTIGE_COST)
	religion.shift_axis(axis, delta)
	for faction: Faction in religion.factions:
		faction.add_tension(FACTION_TENSION_FROM_SOBOR)
	return true

func issue_edict(religion: Religion, axis: String, delta: float) -> bool:
	if religion.prestige < EDICT_PRESTIGE_COST:
		return false
	religion.add_prestige(-EDICT_PRESTIGE_COST)
	var clamped_delta := clampf(delta, -EDICT_MAX_DELTA, EDICT_MAX_DELTA)
	religion.shift_axis(axis, clamped_delta)
	return true

func dispatch_scholar(state: Node, from_religion_id: String, to_religion_id: String) -> void:
	state.scholar_missions.append({
		"from_religion_id": from_religion_id,
		"to_religion_id": to_religion_id,
		"turns_remaining": SCHOLAR_MISSION_TURNS,
	})

func generate_idea(from_religion_id: String, to_religion_id: String, state: Node) -> Idea:
	var from_rel: Religion = state.get_religion(from_religion_id)
	var to_rel: Religion = state.get_religion(to_religion_id)
	if from_rel == null or to_rel == null:
		return null
	var best_axis := ""
	var best_diff := 0.0
	for axis: String in ["A", "B", "C", "D"]:
		var diff := absf(to_rel.get_axis(axis) - from_rel.get_axis(axis))
		if diff > best_diff:
			best_diff = diff
			best_axis = axis
	if best_diff < IDEA_MIN_AXIS_DIFF:
		return null
	var idea := Idea.new()
	idea.from_religion_id = from_religion_id
	idea.axis = best_axis
	idea.delta = minf(best_diff * IDEA_DELTA_FACTOR, IDEA_MAX_DELTA)
	var sign_val := 1.0 if to_rel.get_axis(best_axis) > from_rel.get_axis(best_axis) else -1.0
	idea.delta *= sign_val
	idea.description = "Idea z " + from_religion_id + " (oś " + best_axis + ")"
	return idea

func accept_idea(idea: Idea, religion: Religion, state: Node) -> void:
	religion.shift_axis(idea.axis, idea.delta)
	# Spec 12 §8: rejestracja źródła dla warunku Manicheizm Synkretyczna Iluminacja.
	# Guard chroni przed self-source (artefakt edge case) i pustym from_religion_id.
	if idea.from_religion_id != "" and idea.from_religion_id != religion.id:
		if not religion.absorbed_idea_sources.has(idea.from_religion_id):
			religion.absorbed_idea_sources.append(idea.from_religion_id)
	state.pending_ideas.erase(idea)

func reject_idea(idea: Idea, state: Node) -> void:
	state.pending_ideas.erase(idea)
