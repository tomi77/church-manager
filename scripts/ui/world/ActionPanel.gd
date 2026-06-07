class_name ActionPanel
extends VBoxContainer

signal state_changed

const AxisDeltaPickerScene := preload("res://scenes/ui/world/AxisDeltaPicker.tscn")

var state: Node = null
var target_id: String = ""
var _pending_action: String = ""

@onready var _name_label: Label = %TargetNameLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _trust_label: Label = %TrustLabel
@onready var _econ_label: Label = %EconLabel
@onready var _tension_label: Label = %TensionLabel
@onready var _grievance_box: PanelContainer = %GrievanceBox
@onready var _grievance_label: Label = %GrievanceLabel
@onready var _coalition_box: PanelContainer = %CoalitionBox
@onready var _coalition_label: Label = %CoalitionLabel
@onready var _alliance_btn: Button = %AllianceButton
@onready var _interdict_btn: Button = %InterdictButton
@onready var _missionaries_btn: Button = %MissionariesButton
@onready var _ecu_council_btn: Button = %EcuCouncilButton
@onready var _vassal_patron_btn: Button = %VassalPatronButton
@onready var _vassal_client_btn: Button = %VassalClientButton
@onready var _vassal_council_btn: Button = %VassalCouncilButton
@onready var _rewanz_btn: Button = %RewanzButton
@onready var _picker_container: VBoxContainer = %PickerContainer
@onready var _picker_label: Label = %PickerLabel
@onready var _confirm_dialog: ConfirmationDialog = %ConfirmDialog

var _picker: AxisDeltaPicker = null

func _ready() -> void:
	_picker = AxisDeltaPickerScene.instantiate()
	_picker_container.add_child(_picker)
	_picker.executed.connect(_on_picker_executed)
	_picker_container.visible = false

	_alliance_btn.pressed.connect(_invoke_alliance)
	_interdict_btn.pressed.connect(_request_confirm.bind("interdykt"))
	_missionaries_btn.pressed.connect(_invoke_missionaries)
	_ecu_council_btn.pressed.connect(_show_picker.bind("sobor_ekum"))
	_vassal_patron_btn.pressed.connect(_invoke_vassal_patron)
	_vassal_client_btn.pressed.connect(_invoke_vassal_client)
	_vassal_council_btn.pressed.connect(_show_picker.bind("sobor_wasalski"))
	_rewanz_btn.pressed.connect(_request_confirm.bind("rewanz"))
	_confirm_dialog.confirmed.connect(_on_confirmed)
	_confirm_dialog.canceled.connect(_on_confirm_canceled)

func bind_state(s: Node) -> void:
	state = s

func set_target(id: String) -> void:
	target_id = id
	_picker_container.visible = false
	refresh()

func refresh() -> void:
	if state == null:
		_hide_all()
		return
	var target: Religion = state.get_religion(target_id)
	var player: Religion = state.get_player_religion()
	if target == null or player == null:
		_hide_all()
		return

	_name_label.text = "%s %s" % [target.icon, target.display_name]
	var rel := _get_rel()
	_trust_label.text = "Zaufanie %d" % int(rel.theological_trust)
	_econ_label.text = "Ekonomia %d" % int(rel.economic_cooperation)
	_tension_label.text = "Napięcie %d" % int(rel.military_tension)
	_subtitle_label.text = _build_subtitle(target, player)

	_refresh_grievance(player, target)
	_refresh_coalition(player)
	_refresh_buttons(player, target, rel)

func _build_subtitle(target: Religion, player: Religion) -> String:
	var parts: Array[String] = []
	if target.suzerain_id == player.id:
		parts.append("nasz klient")
	elif player.suzerain_id == target.id:
		parts.append("nasz patron")
	var rel := _get_rel()
	if rel.alliance_active:
		parts.append("sojusz")
	if _in_active_war(player.id, target.id):
		parts.append("wojna")
	if parts.is_empty():
		parts.append("pokój")
	return " · ".join(parts)

func _refresh_grievance(player: Religion, target: Religion) -> void:
	var active: bool = player.interdict_grievance_from_id == target.id and player.interdict_grievance_until > state.current_turn
	_grievance_box.visible = active
	if active:
		_grievance_label.text = "⚠ Grievance: Interdykt\n%s rzucił Interdykt. CB Rewanż dostępne do tury %d (%d tur)." % [
			target.display_name,
			player.interdict_grievance_until,
			player.interdict_grievance_until - state.current_turn,
		]

func _refresh_coalition(player: Religion) -> void:
	var c: Coalition = null
	for coalition: Coalition in state.active_coalitions:
		if coalition.target_id == player.id:
			c = coalition
			break
	_coalition_box.visible = c != null
	if c != null:
		var member_names: Array[String] = []
		for m_id: String in c.members:
			var r: Religion = state.get_religion(m_id)
			if r != null:
				member_names.append(r.display_name)
		_coalition_label.text = "🔻 Koalicja przeciw nam\nCzłonkowie (%d): %s" % [c.members.size(), ", ".join(member_names)]

func _refresh_buttons(player: Religion, target: Religion, rel: RelationState) -> void:
	_alliance_btn.disabled = not _alliance_available(player, target, rel)
	_alliance_btn.tooltip_text = _alliance_tooltip(player, target, rel)
	_interdict_btn.disabled = not _interdict_available(player, target)
	_interdict_btn.tooltip_text = _interdict_tooltip(player, target)
	_missionaries_btn.disabled = not _missionaries_available(player, target, rel)
	_missionaries_btn.tooltip_text = _missionaries_tooltip(player, target, rel)
	_ecu_council_btn.disabled = not _ecu_council_available(player, target, rel)
	_ecu_council_btn.tooltip_text = _ecu_council_tooltip(player, target, rel)
	_vassal_patron_btn.visible = _can_show_vassal_patron(player, target)
	_vassal_patron_btn.disabled = not _vassal_patron_available(player, target, rel)
	_vassal_patron_btn.tooltip_text = _vassal_patron_tooltip(player, target, rel)
	_vassal_client_btn.visible = _can_show_vassal_client(player, target)
	_vassal_client_btn.disabled = not _vassal_client_available(player, target, rel)
	_vassal_client_btn.tooltip_text = _vassal_client_tooltip(player, target, rel)
	_vassal_council_btn.visible = target.suzerain_id == player.id
	_vassal_council_btn.disabled = not _vassal_council_available(player, rel)
	_vassal_council_btn.tooltip_text = _vassal_council_tooltip(player, rel)
	_rewanz_btn.visible = _rewanz_available(player, target)

# === Warunki dostępności (per spec 09 sek.7) ===
# UWAGA: progi używają >= (allow at boundary) żeby match z engine (declare_alliance
# blokuje gdy `trust < 50 AND economy < 60` — przy trust=50.0 engine pozwala).
func _alliance_available(player: Religion, target: Religion, rel: RelationState) -> bool:
	if player.prestige < DiplomacyManager.ALLIANCE_PRESTIGE_COST: return false
	if _in_active_war(player.id, target.id): return false
	if rel.theological_trust < DiplomacyManager.ALLIANCE_TRUST_THRESHOLD and rel.economic_cooperation < DiplomacyManager.ALLIANCE_ECONOMIC_THRESHOLD: return false
	if player.get_axis("C") < DiplomacyManager.ALLIANCE_EXCLUSIVITY_BLOCK and target.get_axis("C") > DiplomacyManager.ALLIANCE_PARTNER_SYNKRETYZM_BLOCK: return false
	return true

func _alliance_tooltip(player: Religion, target: Religion, rel: RelationState) -> String:
	if player.prestige < DiplomacyManager.ALLIANCE_PRESTIGE_COST:
		return "Brak prestiżu (potrzeba 20)"
	if _in_active_war(player.id, target.id):
		return "Niedostępne podczas wojny"
	if rel.theological_trust < DiplomacyManager.ALLIANCE_TRUST_THRESHOLD and rel.economic_cooperation < DiplomacyManager.ALLIANCE_ECONOMIC_THRESHOLD:
		return "Wymaga zaufania ≥50 lub ekonomii ≥60"
	if player.get_axis("C") < DiplomacyManager.ALLIANCE_EXCLUSIVITY_BLOCK and target.get_axis("C") > DiplomacyManager.ALLIANCE_PARTNER_SYNKRETYZM_BLOCK:
		return "Zablokowane przez Ekskluzywizm gracza vs Synkretyzm partnera"
	return "Sojusz (20⚑)"

func _interdict_available(player: Religion, target: Religion) -> bool:
	if player.prestige < DiplomacyManager.INTERDICT_PRESTIGE_COST: return false
	if target.interdict_immunity_until > state.current_turn: return false
	return true

func _interdict_tooltip(player: Religion, target: Religion) -> String:
	if player.prestige < DiplomacyManager.INTERDICT_PRESTIGE_COST:
		return "Brak prestiżu (potrzeba 15)"
	if target.interdict_immunity_until > state.current_turn:
		return "Target ma immunitet do tury %d" % target.interdict_immunity_until
	return "Interdykt (15⚑) — wymaga potwierdzenia"

func _missionaries_available(player: Religion, target: Religion, rel: RelationState) -> bool:
	if player.prestige < DiplomacyManager.MISSIONARIES_PRESTIGE_COST: return false
	if rel.theological_trust <= DiplomacyManager.MISSIONARIES_TRUST_THRESHOLD: return false
	if player.get_axis("C") < DiplomacyManager.MISSIONARIES_EXCLUSIVITY_BLOCK: return false
	return true

func _missionaries_tooltip(player: Religion, target: Religion, rel: RelationState) -> String:
	if player.prestige < DiplomacyManager.MISSIONARIES_PRESTIGE_COST:
		return "Brak prestiżu (potrzeba 10)"
	if rel.theological_trust <= DiplomacyManager.MISSIONARIES_TRUST_THRESHOLD:
		return "Wymaga zaufania >30"
	if player.get_axis("C") < DiplomacyManager.MISSIONARIES_EXCLUSIVITY_BLOCK:
		return "Twój Ekskluzywizm blokuje (Synkretyzm <20)"
	return "Misjonarze (10⚑)"

func _ecu_council_available(player: Religion, target: Religion, rel: RelationState) -> bool:
	# Engine ecumenical_council używa: trust ≤60 → block, tension >85 → block, C ≤40 → block.
	# UI match: trust > 60, tension ≤ 85, C > 40. Koszt: COUNCIL_PRESTIGE_COST modyfikowany
	# _axis_cost_modifier (B>60 → ×0.8). UI używa nominalnego kosztu (30) — drobne
	# przeszacowanie 6⚑ gdy gracz ma B>60, ale safe (UI stricter).
	if player.prestige < DiplomacyManager.COUNCIL_PRESTIGE_COST: return false
	if rel.theological_trust <= DiplomacyManager.COUNCIL_TRUST_THRESHOLD: return false
	if rel.military_tension > DiplomacyManager.BLOCK_TENSION_FOR_DIALOGUE: return false
	if player.get_axis("C") <= DiplomacyManager.COUNCIL_SYNKRETYZM_THRESHOLD: return false
	return true

func _ecu_council_tooltip(player: Religion, target: Religion, rel: RelationState) -> String:
	if player.prestige < DiplomacyManager.COUNCIL_PRESTIGE_COST:
		return "Brak prestiżu (potrzeba 30)"
	if rel.theological_trust <= DiplomacyManager.COUNCIL_TRUST_THRESHOLD:
		return "Wymaga zaufania >60"
	if rel.military_tension > DiplomacyManager.BLOCK_TENSION_FOR_DIALOGUE:
		return "Napięcie za wysokie (>85)"
	if player.get_axis("C") <= DiplomacyManager.COUNCIL_SYNKRETYZM_THRESHOLD:
		return "Twój Synkretyzm za niski (potrzeba >40)"
	return "Sobór ekumeniczny (30⚑)"

func _can_show_vassal_patron(player: Religion, target: Religion) -> bool:
	if player.suzerain_id != "": return false
	if target.suzerain_id == player.id: return false
	return true

func _vassal_patron_available(player: Religion, target: Religion, rel: RelationState) -> bool:
	if not _can_show_vassal_patron(player, target): return false
	if target.suzerain_id != "": return false
	if target.get_axis("A") >= DiplomacyManager.SUZERAINTY_DOGMATYZM_BLOCK: return false
	if rel.theological_trust <= DiplomacyManager.SUZERAINTY_TRUST_THRESHOLD: return false
	if _in_active_war(player.id, target.id): return false
	return true

func _vassal_patron_tooltip(player: Religion, target: Religion, rel: RelationState) -> String:
	if target.suzerain_id != "":
		return "NPC ma już patrona"
	if target.get_axis("A") >= DiplomacyManager.SUZERAINTY_DOGMATYZM_BLOCK:
		return "Dogmatyzm NPC za wysoki (≥80)"
	if rel.theological_trust <= DiplomacyManager.SUZERAINTY_TRUST_THRESHOLD:
		return "Wymaga zaufania >40"
	return "Zaproponuj wasalstwo"

func _can_show_vassal_client(player: Religion, target: Religion) -> bool:
	if player.suzerain_id != "": return false
	if target.suzerain_id == player.id: return false
	return player.prestige < target.prestige * 1.5	# heurystyka UI: gracz słabszy

func _vassal_client_available(player: Religion, target: Religion, rel: RelationState) -> bool:
	if not _can_show_vassal_client(player, target): return false
	if player.get_axis("A") >= DiplomacyManager.SUZERAINTY_DOGMATYZM_BLOCK: return false
	if rel.theological_trust <= DiplomacyManager.SUZERAINTY_TRUST_THRESHOLD: return false
	if _in_active_war(player.id, target.id): return false
	return true

func _vassal_client_tooltip(player: Religion, target: Religion, rel: RelationState) -> String:
	if player.get_axis("A") >= DiplomacyManager.SUZERAINTY_DOGMATYZM_BLOCK:
		return "Twój Dogmatyzm za wysoki (≥80)"
	if rel.theological_trust <= DiplomacyManager.SUZERAINTY_TRUST_THRESHOLD:
		return "Wymaga zaufania >40"
	return "Wejdź pod patronat"

func _vassal_council_available(player: Religion, rel: RelationState) -> bool:
	if player.get_axis("B") <= DiplomacyManager.VASSAL_COUNCIL_HIERARCHIA_THRESHOLD: return false
	if state.current_turn <= rel.vassal_council_cooldown_until: return false
	if player.prestige < DiplomacyManager.VASSAL_COUNCIL_PRESTIGE_COST: return false
	return true

func _vassal_council_tooltip(player: Religion, rel: RelationState) -> String:
	if player.get_axis("B") <= DiplomacyManager.VASSAL_COUNCIL_HIERARCHIA_THRESHOLD:
		return "Wymaga Hierarchii >75"
	if state.current_turn <= rel.vassal_council_cooldown_until:
		return "Cooldown do tury %d" % rel.vassal_council_cooldown_until
	if player.prestige < DiplomacyManager.VASSAL_COUNCIL_PRESTIGE_COST:
		return "Brak prestiżu (potrzeba 30)"
	return "Sobór wasalski (30⚑)"

func _rewanz_available(player: Religion, target: Religion) -> bool:
	var wm := WarManager.new()
	return "rewanz" in wm.available_casus_belli(player, target, state)

# === Akcje ===
func _invoke_alliance() -> void:
	var dm := DiplomacyManager.new()
	var _ok := dm.declare_alliance(state, state.player_religion_id, target_id)
	emit_signal("state_changed")
	refresh()

func _invoke_missionaries() -> void:
	var dm := DiplomacyManager.new()
	var _ok := dm.send_missionaries(state, state.player_religion_id, target_id)
	emit_signal("state_changed")
	refresh()

func _invoke_vassal_patron() -> void:
	var dm := DiplomacyManager.new()
	var _ok := dm.recognize_suzerainty(state, target_id, state.player_religion_id)
	emit_signal("state_changed")
	refresh()

func _invoke_vassal_client() -> void:
	var dm := DiplomacyManager.new()
	var _ok := dm.recognize_suzerainty(state, state.player_religion_id, target_id)
	emit_signal("state_changed")
	refresh()

func _show_picker(kind: String) -> void:
	_pending_action = kind
	_picker.reset()
	_picker_label.text = "Sobór ekumeniczny — wybór ustępstwa:" if kind == "sobor_ekum" else "Sobór wasalski — wybór ustępstwa:"
	_picker_container.visible = true

func _on_picker_executed(axis: String, delta: float) -> void:
	var dm := DiplomacyManager.new()
	if _pending_action == "sobor_ekum":
		var _ok := dm.ecumenical_council(state, state.player_religion_id, target_id, axis, delta)
	elif _pending_action == "sobor_wasalski":
		var _ok2 := dm.vassal_council(state, state.player_religion_id, target_id, axis, delta)
	_pending_action = ""
	_picker_container.visible = false
	emit_signal("state_changed")
	refresh()

func _request_confirm(kind: String) -> void:
	_pending_action = kind
	var target: Religion = state.get_religion(target_id)
	var name: String = target.display_name if target != null else target_id
	if kind == "interdykt":
		_confirm_dialog.dialog_text = "Rzucić Interdykt na %s? Kosztuje 15 prestiżu i podnosi napięcie." % name
	elif kind == "rewanz":
		_confirm_dialog.dialog_text = "Wypowiedzieć wojnę %s z CB Rewanż? Akcja jednorazowa." % name
	_confirm_dialog.popup_centered()

func _on_confirmed() -> void:
	var action: String = _pending_action
	_pending_action = ""  # clear pierwszy, żeby przypadkowy double-fire był no-op
	if action == "interdykt":
		var dm := DiplomacyManager.new()
		var _ok := dm.proclaim_interdict(state, state.player_religion_id, target_id)
	elif action == "rewanz":
		var wm := WarManager.new()
		var _war := wm.declare_war(state.player_religion_id, target_id, "rewanz", state)
	emit_signal("state_changed")
	refresh()

func _on_confirm_canceled() -> void:
	_pending_action = ""

# === Helpers ===
func _get_rel() -> RelationState:
	var dm := DiplomacyManager.new()
	return dm.get_or_create_relation(state, state.player_religion_id, target_id)

func _in_active_war(a: String, b: String) -> bool:
	for war: War in state.active_wars:
		if war.state == "ENDED":
			continue
		if (war.attacker_id == a and war.defender_id == b) or (war.attacker_id == b and war.defender_id == a):
			return true
	return false

func _hide_all() -> void:
	_name_label.text = ""
	_grievance_box.visible = false
	_coalition_box.visible = false
