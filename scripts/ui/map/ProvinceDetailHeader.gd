class_name ProvinceDetailHeader
extends VBoxContainer

const TERRAIN_LABELS: Dictionary = {
    "plains": "🏞 równina",
    "mountains": "⛰ góry",
    "desert": "🏜 pustynia",
    "coast": "🌊 wybrzeże",
    "fertile": "🌾 żyzne",
}

var state: Node = null
var province_id: String = ""

@onready var _name: Label = %NameLabel
@onready var _owner: Label = %OwnerLabel
@onready var _terrain: Label = %TerrainLabel
@onready var _holy_site: Label = %HolySiteLabel
@onready var _population: Label = %PopulationLabel
@onready var _gold: Label = %GoldLabel
@onready var _food: Label = %FoodLabel

func bind(s: Node, pid: String) -> void:
    state = s
    province_id = pid
    if is_inside_tree():
        refresh()

func refresh() -> void:
    if state == null or province_id == "":
        return
    var prov: Province = state.province_graph.get_province(province_id)
    if prov == null:
        return
    _name.text = prov.display_name
    var owner: Religion = state.get_religion(prov.owner)
    if owner != null:
        _owner.text = "%s %s" % [owner.icon, owner.display_name]
    else:
        _owner.text = prov.owner
    _terrain.text = TERRAIN_LABELS.get(prov.terrain, prov.terrain)
    _holy_site.visible = prov.is_holy_site
    _holy_site.text = "★ Święte Miasto"
    _population.text = "👥 %d" % prov.population
    _gold.text = "💰 +%d/turę" % int(prov.resources.get("gold", 0))
    _food.text = "🌾 +%d/turę" % int(prov.resources.get("food", 0))
