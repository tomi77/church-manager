extends GutTest

const TraitCardScene := preload("res://scenes/ui/faith/TraitCard.tscn")
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

func test_card_shows_western_christianity_sukcesja_trait():
	var state := _make_state("western_christianity")
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

# Spec 10 §2: PanelContainer z subtelnym tłem Color(0.1, 0.1, 0.1).
func test_card_panel_has_subtle_dark_background():
	var c: TraitCard = TraitCardScene.instantiate()
	add_child_autofree(c)
	await get_tree().process_frame
	var style: StyleBox = c.get_theme_stylebox("panel")
	assert_not_null(style, "TraitCard musi mieć theme_override_styles/panel")
	assert_true(style is StyleBoxFlat, "panel stylebox powinien być StyleBoxFlat")
	var flat: StyleBoxFlat = style
	assert_eq(flat.bg_color, Color(0.1, 0.1, 0.1), "spec 10 §2: tło Color(0.1, 0.1, 0.1)")
