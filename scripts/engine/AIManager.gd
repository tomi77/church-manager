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
