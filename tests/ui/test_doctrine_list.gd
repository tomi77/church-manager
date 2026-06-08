extends GutTest

const DoctrineListScene := preload("res://scenes/ui/wiara/DoctrineList.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func _instance_list(state: Node) -> DoctrineList:
	var l: DoctrineList = DoctrineListScene.instantiate()
	add_child_autofree(l)
	await get_tree().process_frame
	l.bind_state(state)
	return l

func test_list_renders_without_state():
	var l: DoctrineList = DoctrineListScene.instantiate()
	add_child_autofree(l)
	await get_tree().process_frame
	assert_not_null(l)

func test_list_renders_eight_rows():
	var state := _make_state()
	add_child_autofree(state)
	var l := await _instance_list(state)
	assert_eq(l.row_count(), 8)

func test_list_rows_sorted_axis_then_op_then_alphabetical():
	var state := _make_state()
	add_child_autofree(state)
	var l := await _instance_list(state)
	# Oczekiwana kolejnosc (sort: axis -> op[min<max] -> action_id alfabetycznie):
	# A/min/dogma_canon, A/max/mystical_revelation,
	# B/min/papal_interdicts, B/max/popular_council,
	# C/min/ecumenism, C/min/fusion_rite, C/max/anathema, C/max/inquisition
	assert_eq(l.action_id_at(0), "dogma_canon")
	assert_eq(l.action_id_at(1), "mystical_revelation")
	assert_eq(l.action_id_at(2), "papal_interdicts")
	assert_eq(l.action_id_at(3), "popular_council")
	assert_eq(l.action_id_at(4), "ecumenism")
	assert_eq(l.action_id_at(5), "fusion_rite")
	assert_eq(l.action_id_at(6), "anathema")
	assert_eq(l.action_id_at(7), "inquisition")

func test_list_marks_doctrines_available_per_player_axes():
	var state := _make_state()
	add_child_autofree(state)
	# Islam: A=70, B=65, C=30, D=75
	# Dostepne (zaden prog osi nie spelniony — A nie >=75, A nie <=25, B nie >=75, B nie <=25,
	# C nie >=75, C nie <=25): wszystkie zablokowane
	var l := await _instance_list(state)
	for i in range(8):
		var row: DoctrineRow = l.row_at(i)
		assert_eq(row.get_node("%StateIcon").text, "○", "Row " + str(i) + " should be locked")

func test_list_unlocks_doctrines_on_axis_change():
	var state := _make_state()
	add_child_autofree(state)
	var l := await _instance_list(state)
	# Przesun A do 80 → dogma_canon powinien byc dostepny
	state.get_player_religion().axes["A"] = 80.0
	l.refresh()
	var kanon_row: DoctrineRow = l.row_at(0)
	assert_eq(kanon_row.get_node("%StateIcon").text, "◐")
