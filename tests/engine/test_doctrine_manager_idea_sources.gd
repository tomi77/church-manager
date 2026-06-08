extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("manichaeism", religions, graph)
	return gs

func _make_idea(from_id: String, axis: String = "A", delta: float = 5.0) -> Idea:
	var idea := Idea.new()
	idea.from_religion_id = from_id
	idea.axis = axis
	idea.delta = delta
	return idea

func test_accept_idea_appends_source_to_absorbed_list():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("manichaeism")
	var idea := _make_idea("islam")
	gs.pending_ideas.append(idea)
	var dm := DoctrineManager.new()
	dm.accept_idea(idea, rel, gs)
	assert_true(rel.absorbed_idea_sources.has("islam"))

func test_accept_idea_does_not_duplicate_existing_source():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("manichaeism")
	var idea_a := _make_idea("islam", "A", 3.0)
	var idea_b := _make_idea("islam", "B", 4.0)
	gs.pending_ideas.append(idea_a)
	gs.pending_ideas.append(idea_b)
	var dm := DoctrineManager.new()
	dm.accept_idea(idea_a, rel, gs)
	dm.accept_idea(idea_b, rel, gs)
	assert_eq(rel.absorbed_idea_sources.size(), 1, "duplikaty source NIE powinny być dodawane drugi raz")
	assert_eq(rel.absorbed_idea_sources[0], "islam")

func test_accept_idea_skips_self_source():
	# from_religion_id == religion.id (artificial edge — sami absorbujemy swoje idee)
	var gs := _make_state()
	var rel: Religion = gs.get_religion("manichaeism")
	var idea := _make_idea("manichaeism")
	gs.pending_ideas.append(idea)
	var dm := DoctrineManager.new()
	dm.accept_idea(idea, rel, gs)
	assert_false(rel.absorbed_idea_sources.has("manichaeism"))
	assert_eq(rel.absorbed_idea_sources.size(), 0)

func test_accept_idea_skips_empty_source():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("manichaeism")
	var idea := _make_idea("")
	gs.pending_ideas.append(idea)
	var dm := DoctrineManager.new()
	dm.accept_idea(idea, rel, gs)
	assert_eq(rel.absorbed_idea_sources.size(), 0)

func test_accept_idea_accumulates_multiple_distinct_sources():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("manichaeism")
	var sources := ["islam", "judaism", "zoroastrianism", "buddhism"]
	var dm := DoctrineManager.new()
	for src: String in sources:
		var idea := _make_idea(src)
		gs.pending_ideas.append(idea)
		dm.accept_idea(idea, rel, gs)
	assert_eq(rel.absorbed_idea_sources.size(), 4)
	for src: String in sources:
		assert_true(rel.absorbed_idea_sources.has(src), "missing source: " + src)
