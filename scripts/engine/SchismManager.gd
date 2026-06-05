class_name SchismManager
extends RefCounted

const PHASE1_THRESHOLD := 40.0
const PHASE2_THRESHOLD := 65.0
const PHASE3_THRESHOLD := 85.0
const SCHISM_MIN_INFLUENCE := 0.30

const TENSION_REDUCE_STLUM := 15.0
const INFLUENCE_REDUCE_STLUM := 0.10
const TENSION_REDUCE_DIALOGUJ := 8.0
const AXIS_CONCESSION_DIALOGUJ := 3.0
const TENSION_REDUCE_KONCESJA := 20.0
const KONCESJA_PRESTIGE_COST := 15

const SCHISM_AXIS_OFFSET := 15.0
const SCHISM_INITIAL_PRESTIGE := 50

func get_phase(faction: Faction) -> int:
	if faction.tension >= PHASE3_THRESHOLD:
		return 3
	if faction.tension >= PHASE2_THRESHOLD:
		return 2
	if faction.tension >= PHASE1_THRESHOLD:
		return 1
	return 0

func respond_stlumienie(faction: Faction) -> void:
	faction.tension = maxf(0.0, faction.tension - TENSION_REDUCE_STLUM)
	faction.influence = maxf(0.0, faction.influence - INFLUENCE_REDUCE_STLUM)

func respond_dialoguj(faction: Faction, religion: Religion) -> void:
	faction.tension = maxf(0.0, faction.tension - TENSION_REDUCE_DIALOGUJ)
	for pref: Dictionary in faction.axis_preferences:
		var axis: String = pref.get("axis", "")
		var direction: int = pref.get("direction", 1)
		if axis != "" and religion.axes.has(axis):
			religion.shift_axis(axis, AXIS_CONCESSION_DIALOGUJ * direction)
			break  # Reaguj tylko na pierwszą preferencję z ważną osią

func respond_koncesja(faction: Faction, religion: Religion) -> bool:
	if religion.prestige < KONCESJA_PRESTIGE_COST:
		return false
	religion.add_prestige(-KONCESJA_PRESTIGE_COST)
	faction.tension = maxf(0.0, faction.tension - TENSION_REDUCE_KONCESJA)
	return true

func trigger_schism(faction: Faction, religion: Religion, state: Node) -> Religion:
	if faction.influence < SCHISM_MIN_INFLUENCE:
		return null
	var new_rel := Religion.new()
	new_rel.id = religion.id + "_" + faction.id + "_schizma"
	new_rel.display_name = faction.display_name + " (Schizma)"
	new_rel.prestige = SCHISM_INITIAL_PRESTIGE
	new_rel.color = religion.color
	new_rel.accent_color = religion.accent_color
	for axis: String in religion.axes.keys():
		new_rel.axes[axis] = religion.get_axis(axis)
	for pref: Dictionary in faction.axis_preferences:
		var axis: String = pref.get("axis", "")
		var direction: int = pref.get("direction", 1)
		if axis != "" and new_rel.axes.has(axis):
			new_rel.axes[axis] = clampf(new_rel.get_axis(axis) + SCHISM_AXIS_OFFSET * direction, 0.0, 100.0)
	new_rel.factions.append(faction)
	religion.factions.erase(faction)
	state._religions[new_rel.id] = new_rel
	return new_rel
