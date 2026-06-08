extends GutTest

func test_game_outcome_has_default_empty_winner_id():
	var outcome := GameOutcome.new()
	assert_eq(outcome.winner_id, "")

func test_game_outcome_has_default_empty_reason():
	var outcome := GameOutcome.new()
	assert_eq(outcome.reason, "")

func test_game_outcome_has_default_zero_end_turn():
	var outcome := GameOutcome.new()
	assert_eq(outcome.end_turn, 0)

func test_game_outcome_has_default_empty_ranking():
	var outcome := GameOutcome.new()
	assert_eq(outcome.ranking.size(), 0)

func test_game_outcome_stores_winner_id():
	var outcome := GameOutcome.new()
	outcome.winner_id = "islam"
	assert_eq(outcome.winner_id, "islam")

func test_game_outcome_stores_reason():
	var outcome := GameOutcome.new()
	outcome.reason = "domination"
	assert_eq(outcome.reason, "domination")

func test_game_outcome_stores_end_turn():
	var outcome := GameOutcome.new()
	outcome.end_turn = 87
	assert_eq(outcome.end_turn, 87)

func test_game_outcome_ranking_accepts_dictionary_entries():
	var outcome := GameOutcome.new()
	outcome.ranking = [
		{"religion_id": "islam", "prestige": 540, "provinces": 6},
		{"religion_id": "western_christianity", "prestige": 510, "provinces": 3},
	]
	assert_eq(outcome.ranking.size(), 2)
	assert_eq(outcome.ranking[0]["religion_id"], "islam")
	assert_eq(outcome.ranking[1]["prestige"], 510)
