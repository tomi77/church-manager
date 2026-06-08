class_name FactionCard
extends PanelContainer

@onready var _name_label: Label = %NameLabel
@onready var _phase_label: Label = %PhaseLabel
@onready var _influence_value: Label = %InfluenceValue
@onready var _influence_label: Label = %InfluenceLabel
@onready var _tension_bar: ProgressBar = %TensionBar
@onready var _tension_value: Label = %TensionValue
@onready var _preferences_label: Label = %PreferencesLabel
@onready var _preferences_list: Label = %PreferencesList

var _faction: Faction = null
var _religion: Religion = null
var _is_dominant: bool = false

func bind_faction(faction: Faction, religion: Religion, is_dominant: bool) -> void:
	_faction = faction
	_religion = religion
	_is_dominant = is_dominant
	if is_inside_tree():
		refresh()

func _ready() -> void:
	if _faction != null:
		refresh()

func refresh() -> void:
	if _faction == null:
		return
	_name_label.text = _faction.display_name
	_influence_value.text = "%d%%" % clampi(int(round(_faction.influence * 100.0)), 0, 100)
	_tension_bar.value = _faction.tension
	_tension_value.text = "napięcie %d" % int(round(_faction.tension))
	_apply_phase()
	_apply_preferences()
	_apply_style()

func _apply_phase() -> void:
	var sm := SchismManager.new()
	var phase: int = sm.get_phase(_faction)
	_phase_label.text = UIConstants.FACTION_PHASE_LABELS.get(phase, "")
	var fill_color: Color = UIConstants.FACTION_PHASE_COLORS.get(phase, Color(0.5, 0.5, 0.5))
	var fill_sb := StyleBoxFlat.new()
	fill_sb.bg_color = fill_color
	_tension_bar.add_theme_stylebox_override("fill", fill_sb)

func _apply_preferences() -> void:
	# Strzalka ↑ zawsze w gore — pokazujemy biegun ktory frakcja PROMUJE
	# (nie kierunek delta osi). direction=+1 → biegun "100", -1 → biegun "0".
	var parts: Array[String] = []
	for pref: Dictionary in _faction.axis_preferences:
		var axis: String = pref.get("axis", "")
		var direction: int = pref.get("direction", 0)
		if axis == "" or direction == 0 or not UIConstants.AXIS_POLE_NAMES.has(axis):
			continue
		var poles: Dictionary = UIConstants.AXIS_POLE_NAMES[axis]
		if not poles.has(direction):
			continue
		parts.append("↑ " + poles[direction])
	_preferences_list.text = " · ".join(parts)

func _apply_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	if _is_dominant:
		sb.bg_color = Color(0.12, 0.18, 0.12)
		sb.border_color = Color("3aa83a")
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_width_bottom = 2
	else:
		sb.bg_color = Color(0.1, 0.1, 0.1)
	add_theme_stylebox_override("panel", sb)
