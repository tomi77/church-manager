class_name AIManager
extends RefCounted

# Plan 18 — NPC AI doctrine MVP.
# Spec: docs/superpowers/specs/18-npc-doctrine-ai-design.md
# Stateless (pattern jak DiplomacyManager, WarManager). RNG injection dla determinizmu testów.

const AI_SCHOLAR_MIN_PRESTIGE := 50
const AI_SCHOLAR_DISPATCH_CHANCE := 0.15

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
