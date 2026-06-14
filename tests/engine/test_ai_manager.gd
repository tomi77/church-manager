extends GutTest

const AIManagerScript := preload("res://scripts/engine/AIManager.gd")

# === Plan 18: AIManager skeleton ===

func test_ai_manager_has_plan18_constants() -> void:
	assert_eq(AIManager.AI_SCHOLAR_MIN_PRESTIGE, 50)
	assert_almost_eq(AIManager.AI_SCHOLAR_DISPATCH_CHANCE, 0.15, 0.001)

func test_ai_manager_init_creates_rng_when_no_injection() -> void:
	var ai := AIManagerScript.new()
	assert_not_null(ai.rng, "AIManager bez injection tworzy własny rng")

func test_ai_manager_init_uses_injected_rng() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var ai := AIManagerScript.new(rng)
	assert_eq(ai.rng, rng, "AIManager używa injected rng")
