class_name AIManager
extends RefCounted

# Plan 18 — NPC AI doctrine MVP.
# Spec: docs/superpowers/specs/18-npc-doctrine-ai-design.md
# Stateless (pattern jak DiplomacyManager, WarManager). RNG injection dla determinizmu testów.

const AI_SCHOLAR_MIN_PRESTIGE := 50
const AI_SCHOLAR_DISPATCH_CHANCE := 0.15

# === Plan 20: war declarations + peace ===
const AI_WAR_TENSION_THRESHOLD := 70.0
const AI_WAR_DECLARE_CHANCE := 0.2
const AI_PEACE_ATTACKER_WEARINESS_GIVE_UP := 70.0
const AI_PEACE_DEFENDER_WEARINESS := 60.0

var rng: RandomNumberGenerator

func _init(injected_rng: RandomNumberGenerator = null) -> void:
	if injected_rng != null:
		rng = injected_rng
	else:
		rng = RandomNumberGenerator.new()
		rng.randomize()

func decide_accept_idea(religion: Religion, idea: Idea) -> bool:
	# Plan 18 §4.1: faction-weighted sum > 0 → accept.
	# sign_match = pref.direction × sign(idea.delta).
	# net_support = Σ faction.influence × sign_match.
	var net_support: float = 0.0
	var shift_direction: int = 1 if idea.delta > 0.0 else -1
	for faction: Faction in religion.factions:
		for pref: Dictionary in faction.axis_preferences:
			if pref.get("axis", "") == idea.axis:
				var pref_dir: int = pref.get("direction", 0)
				net_support += faction.influence * pref_dir * shift_direction
				break
	return net_support > 0.0

func should_dispatch_scholar(religion: Religion) -> bool:
	# Plan 18 §5.1: defeated/prestige/RNG gates.
	if religion.defeated_at_turn != -1:
		return false
	if religion.prestige < AI_SCHOLAR_MIN_PRESTIGE:
		return false
	return rng.randf() < AI_SCHOLAR_DISPATCH_CHANCE

func choose_scholar_target(state: Node, religion: Religion) -> String:
	# Plan 18 §5.2: random non-self, non-defeated.
	var candidates: Array[String] = []
	for r: Religion in state.all_religions():
		if r.id == religion.id:
			continue
		if r.defeated_at_turn != -1:
			continue
		candidates.append(r.id)
	if candidates.is_empty():
		return ""
	return candidates[rng.randi() % candidates.size()]

func should_attack_in_war(attacker: Religion, war: War) -> bool:
	# Plan 19 §4.1: gating attacker AI per war.
	# MVP: zawsze true gdy attacker żyje + war.state == BATTLING.
	if attacker == null or attacker.defeated_at_turn != -1:
		return false
	if war.state != "BATTLING":
		return false
	return true

func choose_attack_target(state: Node, attacker: Religion, defender_id: String) -> String:
	# Plan 19 §5.1: border-adjacent preferred, fallback random defender province.
	var defender_provs: Array[Province] = state.province_graph.provinces_with_owner(defender_id)
	if defender_provs.is_empty():
		return ""
	var border_candidates: Array[String] = []
	for d_prov: Province in defender_provs:
		for neighbor_id: String in d_prov.neighbors:
			var neighbor: Province = state.province_graph.get_province(neighbor_id)
			if neighbor != null and neighbor.owner == attacker.id:
				border_candidates.append(d_prov.id)
				break  # 1 entry per defender province
	if not border_candidates.is_empty():
		return border_candidates[rng.randi() % border_candidates.size()]
	return defender_provs[rng.randi() % defender_provs.size()].id

func should_declare_war(attacker: Religion, defender: Religion, state: Node) -> bool:
	# Plan 20 §4.2: pełne guards przed declaration.
	if attacker == null or defender == null:
		return false
	if attacker.id == defender.id:
		return false
	if attacker.defeated_at_turn != -1 or defender.defeated_at_turn != -1:
		return false
	if attacker.prestige < WarManager.DECLARE_WAR_PRESTIGE:
		return false
	# Already at war?
	for war: War in state.active_wars:
		if war.state == "ENDED":
			continue
		if (war.attacker_id == attacker.id and war.defender_id == defender.id) \
				or (war.attacker_id == defender.id and war.defender_id == attacker.id):
			return false
	# Alliance check.
	var dm := DiplomacyManager.new()
	var rel := dm.get_or_create_relation(state, attacker.id, defender.id)
	if rel.alliance_active:
		return false
	# Suzerain/vassal chain.
	if attacker.suzerain_id == defender.id or defender.suzerain_id == attacker.id:
		return false
	# Same coalition.
	for coalition: Coalition in state.active_coalitions:
		if attacker.id in coalition.members and defender.id in coalition.members:
			return false
	# Tension threshold (próg ostry >=).
	if rel.military_tension < AI_WAR_TENSION_THRESHOLD:
		return false
	# CB available.
	var wm := WarManager.new()
	if wm.available_casus_belli(attacker, defender, state).is_empty():
		return false
	return true
