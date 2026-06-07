extends GutTest

const TraitCardScene := preload("res://scenes/ui/wiara/TraitCard.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state(player_id: String = "islam") -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize(player_id, religions, graph)
	return gs

func _instance_card(state: Node) -> TraitCard:
	var c: TraitCard = TraitCardScene.instantiate()
	add_child_autofree(c)
	await get_tree().process_frame
	c.bind_state(state)
	return c

func test_card_renders_without_state():
	var c: TraitCard = TraitCardScene.instantiate()
	add_child_autofree(c)
	await get_tree().process_frame
	assert_not_null(c)

func test_card_shows_islam_umma_trait():
	var state := _make_state("islam")
	add_child_autofree(state)
	var c := await _instance_card(state)
	assert_eq(c.get_node("%NameLabel").text, "Umma")
	assert_string_contains(c.get_node("%DescriptionLabel").text, "Dżihadu")

func test_card_shows_chr_zachodnie_sukcesja_trait():
	var state := _make_state("chr_zachodnie")
	add_child_autofree(state)
	var c := await _instance_card(state)
	assert_eq(c.get_node("%NameLabel").text, "Sukcesja Apostolska")
	assert_string_contains(c.get_node("%DescriptionLabel").text, "Synkretyzm")

func test_card_handles_unknown_trait_id():
	var state := _make_state("islam")
	add_child_autofree(state)
	state.get_player_religion().trait_id = "nieznany_trait"
	var c := await _instance_card(state)
	# Fallback gdy trait_id nie istnieje w TRAIT_INFO — brak crasha
	assert_not_null(c.get_node("%NameLabel"))

func test_card_refresh_after_trait_change():
	var state := _make_state("islam")
	add_child_autofree(state)
	var c := await _instance_card(state)
	state.get_player_religion().trait_id = "diaspora"
	c.refresh()
	assert_eq(c.get_node("%NameLabel").text, "Diaspora")
