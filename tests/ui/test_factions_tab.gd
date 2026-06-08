extends GutTest

const FactionsTabScene := preload("res://scenes/ui/factions/FactionsTab.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state(player_id: String = "islam") -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize(player_id, religions, graph)
	return gs

func _instance_tab(state: Node = null) -> FactionsTab:
	var t: FactionsTab = FactionsTabScene.instantiate()
	add_child_autofree(t)
	await get_tree().process_frame
	if state != null:
		t.bind_state(state)
	return t

func _cards(t: FactionsTab) -> Array:
	return t.get_node("%CardsContainer").get_children()

func test_tab_renders_without_state():
	var t: FactionsTab = FactionsTabScene.instantiate()
	add_child_autofree(t)
	await get_tree().process_frame
	assert_not_null(t)
	assert_eq(_cards(t).size(), 0)

func test_tab_renders_three_islam_factions():
	var state := _make_state("islam")
	add_child_autofree(state)
	var t := await _instance_tab(state)
	assert_eq(_cards(t).size(), 3)

func test_tab_card_names_match_islam_factions():
	# Islam JSON: ulama (0.40), sufis (0.30), warriors_of_faith (0.30)
	# Sortowanie DESC po influence → ulama pierwsza
	var state := _make_state("islam")
	add_child_autofree(state)
	var t := await _instance_tab(state)
	var cards := _cards(t)
	assert_eq(cards[0].get_node("%NameLabel").text, "Ulema")

func test_tab_handles_zero_factions():
	var state := _make_state("islam")
	add_child_autofree(state)
	state.get_player_religion().factions.clear()
	var t := await _instance_tab(state)
	assert_eq(_cards(t).size(), 0)

func test_tab_handles_two_factions():
	var state := _make_state("islam")
	add_child_autofree(state)
	var rel: Religion = state.get_player_religion()
	rel.factions.pop_back()  # 3 → 2
	var t := await _instance_tab(state)
	assert_eq(_cards(t).size(), 2)

func test_tab_handles_four_or_more_factions():
	# Uzasadnia dynamiczny rebuild zamiast 3 statycznych slotow
	var state := _make_state("islam")
	add_child_autofree(state)
	var rel: Religion = state.get_player_religion()
	var extra := Faction.new()
	extra.id = "synthetic"
	extra.display_name = "Synthetic"
	extra.influence = 0.1
	rel.factions.append(extra)
	var t := await _instance_tab(state)
	assert_eq(_cards(t).size(), 4)

func test_tab_sorts_by_influence_desc():
	var state := _make_state("islam")
	add_child_autofree(state)
	var rel: Religion = state.get_player_religion()
	# Force unique influences
	rel.factions[0].influence = 0.30  # ulama
	rel.factions[1].influence = 0.50  # sufis (sztucznie najwyzsze)
	rel.factions[2].influence = 0.20  # warriors_of_faith
	var t := await _instance_tab(state)
	var cards := _cards(t)
	assert_eq(cards[0].get_node("%NameLabel").text, "Sufici")
	assert_eq(cards[1].get_node("%NameLabel").text, "Ulema")
	assert_eq(cards[2].get_node("%NameLabel").text, "Wojownicy Wiary")

func test_tab_sort_is_stable_preserves_json_order_on_ties():
	# Sufici i warriors_of_faith oba na 0.30 w JSON. JSON order: sufis przed warriors.
	# Stable sort musi to zachowac.
	var state := _make_state("islam")
	add_child_autofree(state)
	var rel: Religion = state.get_player_religion()
	# rel.factions[1] = sufis, rel.factions[2] = warriors_of_faith
	# influence z JSON: 0.40, 0.30, 0.30
	var t := await _instance_tab(state)
	var cards := _cards(t)
	# Indeks 0 to ulama (najwyzszy 0.40), 1 i 2 = sufis i warriors w JSON order
	assert_eq(cards[1].get_node("%NameLabel").text, "Sufici")
	assert_eq(cards[2].get_node("%NameLabel").text, "Wojownicy Wiary")

func test_tab_marks_dominant_via_engine_helper():
	var state := _make_state("islam")
	add_child_autofree(state)
	var rel: Religion = state.get_player_religion()
	var dominant: Faction = rel.dominant_faction()
	var t := await _instance_tab(state)
	var cards := _cards(t)
	var dominant_found := false
	for card: FactionCard in cards:
		var is_dom: bool = card.get_node("%NameLabel").text == dominant.display_name
		if is_dom:
			dominant_found = true
			var sb: StyleBoxFlat = card.get_theme_stylebox("panel")
			assert_eq(sb.border_color, Color("3aa83a"), "Dominant card must have green border")
		else:
			var sb: StyleBoxFlat = card.get_theme_stylebox("panel")
			assert_eq(sb.border_width_left, 0, "Non-dominant card must have no border")
	assert_true(dominant_found, "Dominant card not rendered")

func test_tab_refresh_rebuilds_on_faction_removed():
	var state := _make_state("islam")
	add_child_autofree(state)
	var t := await _instance_tab(state)
	assert_eq(_cards(t).size(), 3)
	state.get_player_religion().factions.pop_back()
	t.refresh()
	await get_tree().process_frame
	assert_eq(_cards(t).size(), 2)

func test_tab_handles_null_player_religion():
	var gs: Node = GameStateScript.new()
	# Brak initialize() → player_religion_id == ""
	add_child_autofree(gs)
	var t: FactionsTab = FactionsTabScene.instantiate()
	add_child_autofree(t)
	await get_tree().process_frame
	t.bind_state(gs)
	# Brak crasha, brak kart
	assert_eq(_cards(t).size(), 0)
