extends GutTest

# Sanity test: stałe istnieją i mają sensowne wartości. Chroni przed milczącym
# usunięciem stałej (która jest referencowana z testów warunków).

func test_universal_constants_exist():
	assert_eq(VictoryManager.TURN_LIMIT, 200)
	assert_almost_eq(VictoryManager.DOMINATION_PROVINCE_SHARE, 0.5, 0.001)
	assert_eq(VictoryManager.DOMINATION_TURNS_REQUIRED, 3)
	assert_almost_eq(VictoryManager.PRESTIGE_HEGEMONY_RATIO, 2.0, 0.001)
	assert_eq(VictoryManager.PRESTIGE_HEGEMONY_TURNS_REQUIRED, 10)
	assert_eq(VictoryManager.ELIMINATION_TURNS_REQUIRED, 5)
	assert_eq(VictoryManager.VASSAL_DEFEAT_TURNS_REQUIRED, 20)
	assert_eq(VictoryManager.SCHISM_GRACE_TURNS, 10)

func test_unique_constants_exist():
	assert_eq(VictoryManager.JUDAISM_PROVINCES_REQUIRED, 4)
	assert_eq(VictoryManager.JUDAISM_JERUSALEM_ID, "jerozolima")
	assert_almost_eq(VictoryManager.JUDAISM_FACTION_UNITY_TENSION_MAX, 30.0, 0.001)
	assert_eq(VictoryManager.ZOROASTRIANISM_PROVINCES_REQUIRED, 3)
	assert_eq(VictoryManager.ZOROASTRIANISM_PERSEPOLIS_ID, "persepolis")
	assert_eq(VictoryManager.ISLAM_PROVINCES_REQUIRED, 5)
	assert_eq(VictoryManager.ISLAM_MEKKA_ID, "mekka")
	assert_eq(VictoryManager.ISLAM_JERUSALEM_ID, "jerozolima")
	assert_eq(VictoryManager.EAST_CHRISTIANITY_VASSALS_REQUIRED, 3)
	assert_almost_eq(VictoryManager.MANICHAEISM_AXIS_C_REQUIRED, 90.0, 0.001)
	assert_eq(VictoryManager.MANICHAEISM_DISTINCT_SOURCES_REQUIRED, 4)

func test_victory_manager_instantiable():
	var vm := VictoryManager.new()
	assert_not_null(vm)

func test_plan13_constants_exist():
	# D3 schizma totalna
	assert_eq(VictoryManager.SCHISM_TOTAL_TURNS_REQUIRED, 2)
	# Western Reformacja Apostolska
	assert_eq(VictoryManager.WESTERN_ROME_ID, "rzym")
	assert_eq(VictoryManager.WESTERN_VASSALS_REQUIRED, 4)
	assert_eq(VictoryManager.WESTERN_PRESTIGE_REQUIRED, 600)
	# Hindu Dharmiczna Trwałość
	assert_eq(VictoryManager.HINDU_PROVINCES_REQUIRED, 2)
	assert_eq(VictoryManager.HINDU_DHARMA_TURNS_REQUIRED, 50)
	# Buddhism Środkowa Droga
	assert_almost_eq(VictoryManager.BUDDHISM_AXIS_D_REQUIRED, 90.0, 0.001)
	assert_eq(VictoryManager.BUDDHISM_DISTINCT_SOURCES_REQUIRED, 4)
