class_name TurnManager
extends RefCounted

const HOLY_SITE_PRESTIGE_PER_TURN := 3
const FACTION_TENSION_PER_DIVERGED_AXIS := 2.0
const AXIS_DIVERGENCE_THRESHOLD := 20.0
const BELIEVER_EXODUS_PER_TURN := 5

# Plan 18: AI override dla test isolation.
# Produkcja: _get_ai zwraca świeży AIManager (jak inne managery — per-step).
# Testy: set_ai_override pinuje konkretną instancję (np. z seeded RNG lub disabled chance).
var _ai_override: AIManager = null

func set_ai_override(ai: AIManager) -> void:
	_ai_override = ai

func _get_ai() -> AIManager:
	if _ai_override != null:
		return _ai_override
	return AIManager.new()

func process_turn(state: Node) -> void:
	# Spec 12 §5: pokonane religie (defeated_at_turn != -1) wciąż przechodzą cały pipeline
	# — zostają w świecie (mogą mieć prestiż, frakcje, zasoby). VictoryManager.update_counters
	# pomija je w drugim-najwyższym prestiżu i nie próbuje już ustawiać warunków wygranej.
	_apply_passive_pressure(state.province_graph)
	_apply_holy_site_prestige(state)
	_update_faction_tensions(state)
	_npc_dispatch_scholars(state)
	_process_scholar_missions(state)
	_apply_believer_exodus(state)
	_process_active_wars(state)
	_npc_attack_wars(state)
	_npc_offer_peace(state)
	_npc_declare_wars(state)
	_process_missionaries(state)
	_process_diplomacy(state)
	_process_resources(state)
	_process_vassal_revolts(state)
	state.advance_turn()
	# Spec 12 §6: po advance_turn — sprawdzenie zwycięstwa / przegranej / cap turowego
	var vm := VictoryManager.new()
	vm.check(state)

func _apply_passive_pressure(graph: ProvinceGraph) -> void:
	for province: Province in graph.all_provinces():
		for neighbor_id: String in graph.get_neighbors(province.id):
			var neighbor := graph.get_province(neighbor_id)
			if neighbor == null or neighbor.owner == province.owner:
				continue
			var delta := _pressure_delta(province.terrain)
			province.add_pressure(neighbor.owner, delta)

# Uproszczenie PoC: delta na podstawie terenu prowincji odbierającej presję.
# Plan mechaniki.md rozszerzy o populację sąsiada jako mnożnik.
func _pressure_delta(terrain: String) -> float:
	match terrain:
		"mountains": return 1.0
		"desert": return 1.0
		_: return 2.0

func _apply_holy_site_prestige(state: Node) -> void:
	for province: Province in state.province_graph.all_provinces():
		if not province.is_holy_site or province.owner == "":
			continue
		var owner: Religion = state.get_religion(province.owner)
		if owner != null:
			owner.add_prestige(HOLY_SITE_PRESTIGE_PER_TURN)

func _update_faction_tensions(state: Node) -> void:
	for religion: Religion in state.all_religions():
		for faction: Faction in religion.factions:
			var tension_delta := _compute_faction_tension_delta(religion, faction)
			faction.add_tension(tension_delta)

func _compute_faction_tension_delta(religion: Religion, faction: Faction) -> float:
	var delta := 0.0
	for pref: Dictionary in faction.axis_preferences:
		var axis: String = pref.get("axis", "")
		var direction: int = pref.get("direction", 0)
		var axis_val := religion.get_axis(axis)
		var preferred_high := direction > 0
		var diverged := (preferred_high and axis_val < 100.0 - AXIS_DIVERGENCE_THRESHOLD) or \
						(not preferred_high and axis_val > AXIS_DIVERGENCE_THRESHOLD)
		if diverged:
			delta += FACTION_TENSION_PER_DIVERGED_AXIS
	return delta

func _npc_dispatch_scholars(state: Node) -> void:
	# Plan 18 §6.1: per-turn NPC scholar dispatch.
	var ai := _get_ai()
	var dm := DoctrineManager.new()
	for religion: Religion in state.all_religions():
		if religion.id == state.player_religion_id:
			continue
		if not ai.should_dispatch_scholar(religion):
			continue
		var target_id: String = ai.choose_scholar_target(state, religion)
		if target_id != "":
			dm.dispatch_scholar(state, religion.id, target_id)

func _npc_attack_wars(state: Node) -> void:
	# Plan 19 §6.1: NPC attacker performs 1 attack per war per turn (gdy BATTLING).
	var ai := _get_ai()
	var wm := WarManager.new()
	for war: War in state.active_wars.duplicate():
		if war.state != "BATTLING":
			continue
		if war.attacker_id == state.player_religion_id:
			continue
		var attacker: Religion = state.get_religion(war.attacker_id)
		if attacker == null:
			continue
		if not ai.should_attack_in_war(attacker, war):
			continue
		var target_id: String = ai.choose_attack_target(state, attacker, war.defender_id)
		if target_id != "":
			wm.attack_province(war, target_id, state)

func _npc_offer_peace(state: Node) -> void:
	# Plan 20 §5.1: NPC contextually ends wars.
	# Iteration: attacker first, then defender (deterministic).
	# active_wars.duplicate() — offer_peace może mutować state.active_wars (erase),
	# więc iterowanie raw array byłoby niebezpieczne.
	var ai := _get_ai()
	var wm := WarManager.new()
	for war: War in state.active_wars.duplicate():
		if war.state == "ENDED":
			continue
		# Attacker NPC
		if war.attacker_id != state.player_religion_id:
			if ai.should_offer_peace(war, war.attacker_id, state):
				var terms := ai.compose_peace_terms(war, war.attacker_id, state)
				wm.offer_peace(war, terms, state)
				continue
		if war.state == "ENDED":
			continue
		# Defender NPC
		if war.defender_id != state.player_religion_id:
			if ai.should_offer_peace(war, war.defender_id, state):
				var terms := ai.compose_peace_terms(war, war.defender_id, state)
				wm.offer_peace(war, terms, state)

func _npc_declare_wars(state: Node) -> void:
	# Plan 20 §5.2: NPC declarations per turn.
	var ai := _get_ai()
	var wm := WarManager.new()
	for religion: Religion in state.all_religions():
		if religion.id == state.player_religion_id:
			continue
		if religion.defeated_at_turn != -1:
			continue
		var target := ai.choose_war_target(state, religion)
		if target.is_empty():
			continue
		wm.declare_war(religion.id, target["defender_id"], target["cb"], state)

func _process_scholar_missions(state: Node) -> void:
	var dm := DoctrineManager.new()
	var ai := _get_ai()
	var still_active: Array = []
	for mission: Dictionary in state.scholar_missions:
		mission["turns_remaining"] -= 1
		if mission["turns_remaining"] <= 0:
			var idea := dm.generate_idea(mission["from_religion_id"], mission["to_religion_id"], state)
			if idea != null:
				_resolve_idea(idea, mission["from_religion_id"], state, dm, ai)
		else:
			still_active.append(mission)
	state.scholar_missions = still_active

func _resolve_idea(idea: Idea, dispatcher_id: String, state: Node, dm: DoctrineManager, ai: AIManager) -> void:
	# Plan 18 §6.2: rozróżnij player vs NPC.
	if dispatcher_id == state.player_religion_id:
		state.pending_ideas.append(idea)
		return
	var dispatcher: Religion = state.get_religion(dispatcher_id)
	if dispatcher == null or dispatcher.defeated_at_turn != -1:
		return  # NPC defeated mid-mission — drop idea.
	if ai.decide_accept_idea(dispatcher, idea):
		dm.accept_idea(idea, dispatcher, state)
	else:
		dm.reject_idea(idea, state)

func _apply_believer_exodus(state: Node) -> void:
	var sm := SchismManager.new()
	for religion: Religion in state.all_religions():
		var has_phase2 := false
		for faction: Faction in religion.factions:
			if sm.get_phase(faction) >= 2:
				has_phase2 = true
				break
		if not has_phase2:
			continue
		for province: Province in state.province_graph.provinces_with_owner(religion.id):
			province.population = maxi(0, province.population - BELIEVER_EXODUS_PER_TURN)

func _process_active_wars(state: Node) -> void:
	var wm := WarManager.new()
	# Najpierw przejścia stanów i naliczanie weariness
	var still_active: Array[War] = []
	for war: War in state.active_wars:
		war.turns_in_state += 1
		if war.state == "MOBILIZING" and war.turns_in_state >= WarManager.MOBILIZATION_TURNS:
			war.state = "BATTLING"
			war.turns_in_state = 0
		elif war.state == "OCCUPYING" and war.turns_in_state >= WarManager.OCCUPATION_TURNS:
			war.state = "BATTLING"
			war.turns_in_state = 0
		var attacker: Religion = state.get_religion(war.attacker_id)
		var defender: Religion = state.get_religion(war.defender_id)
		if attacker != null:
			attacker.war_weariness = clampf(attacker.war_weariness + WarManager.WEARINESS_PER_TURN, 0.0, 100.0)
		if defender != null:
			defender.war_weariness = clampf(defender.war_weariness + WarManager.WEARINESS_PER_TURN, 0.0, 100.0)
		still_active.append(war)
	state.active_wars = still_active
	# Drugi przebieg: force_loss dla stron z weariness >= próg.
	# Tie-break: atakujący sprawdzany pierwszy (elif), więc przy jednoczesnym przekroczeniu
	# progu obie strony — atakujący przegrywa. Defender'a excess weariness pozostaje
	# i wyzwoli force_loss w kolejnej turze, jeśli wojna by trwała (a nie trwa, bo wojna
	# właśnie się skończyła force_loss atakującego).
	var to_force: Array = []
	for war: War in state.active_wars:
		var attacker: Religion = state.get_religion(war.attacker_id)
		var defender: Religion = state.get_religion(war.defender_id)
		if attacker != null and attacker.war_weariness >= WarManager.WEARINESS_FORCED_PEACE:
			to_force.append({"war": war, "loser_id": war.attacker_id})
		elif defender != null and defender.war_weariness >= WarManager.WEARINESS_FORCED_PEACE:
			to_force.append({"war": war, "loser_id": war.defender_id})
	for entry: Dictionary in to_force:
		wm.force_loss(entry["war"], entry["loser_id"], state)

func _process_diplomacy(state: Node) -> void:
	var dm := DiplomacyManager.new()
	for rel: RelationState in state.relations:
		if not _pair_in_active_war(state, rel.religion_a_id, rel.religion_b_id):
			rel.military_tension = clampf(rel.military_tension - DiplomacyManager.PEACE_TENSION_DECAY_PER_TURN, 0.0, 100.0)
	dm.evaluate_coalitions(state)
	dm.auto_join_allies_to_coalitions(state)
	dm.auto_join_vassals_to_coalitions(state)
	dm.dissolve_coalitions(state)

func _pair_in_active_war(state: Node, a: String, b: String) -> bool:
	for war: War in state.active_wars:
		if war.state == "ENDED":
			continue
		if (war.attacker_id == a and war.defender_id == b) or (war.attacker_id == b and war.defender_id == a):
			return true
	return false

func _process_missionaries(state: Node) -> void:
	var doctm := DoctrineManager.new()
	var still_active: Array[MissionaryMission] = []
	for mission: MissionaryMission in state.missionary_missions:
		mission.turns_remaining -= 1
		if mission.turns_remaining > 0:
			still_active.append(mission)
			continue
		# Spec sec.2 "Misjonarze Wymienni" — przy powrocie misjonarza, target to religia
		# przyjmująca obcą ideę; jej Dogmatyzm zmniejsza skuteczność, jej Ekskluzywizm
		# generuje napięcie u własnej dominującej frakcji ("własna frakcja konserwatywna").
		# send_missionaries tworzy symetryczną parę misji, więc każda religia jest sprawdzana
		# jako target dokładnie raz.
		var target: Religion = state.get_religion(mission.target_id)
		var idea := doctm.generate_idea(mission.source_id, mission.target_id, state)
		if idea != null:
			if target != null and target.get_axis("A") > DiplomacyManager.DOGMATYZM_RESISTANCE_THRESHOLD:
				idea.delta *= DiplomacyManager.DOGMATYZM_IDEA_DELTA_MULTIPLIER
			state.pending_ideas.append(idea)
		if target != null and target.get_axis("C") < DiplomacyManager.EKSKLUZYWIZM_FACTION_THRESHOLD:
			var dom := target.dominant_faction()
			if dom != null:
				dom.add_tension(DiplomacyManager.EKSKLUZYWIZM_FACTION_TENSION_BUMP)
	state.missionary_missions = still_active

func _process_resources(state: Node) -> void:
	# Najpierw passive income wszystkim, potem trybut klient → patron.
	# Spec 07 sek.3: ta kolejność gwarantuje że klient zaczyna turę z +PASSIVE-TRIBUTE netto,
	# nie wpada w nędzę nawet jeśli zaczyna z 0 zasobami.
	for religion: Religion in state.all_religions():
		religion.resources += DiplomacyManager.PASSIVE_INCOME_PER_TURN
	for client: Religion in state.all_religions():
		if client.suzerain_id == "":
			continue
		var patron: Religion = state.get_religion(client.suzerain_id)
		if patron == null:
			continue
		var amount: int = mini(DiplomacyManager.TRIBUTE_PER_TURN, client.resources)
		client.resources -= amount
		patron.resources += amount

func _process_vassal_revolts(state: Node) -> void:
	# Spec 07 sek.3: gdy dominująca frakcja klienta ma tension > 80, klient zrywa.
	# Bunt skutkuje: utratą patrona, wzrostem napięcia militarnego klient↔patron,
	# ulgą frakcji (rozładowanie energii społecznej po wyzwoleniu).
	var dm := DiplomacyManager.new()
	for client: Religion in state.all_religions():
		if client.suzerain_id == "":
			continue
		var dom: Faction = client.dominant_faction()
		if dom == null:
			continue
		if dom.tension <= DiplomacyManager.REVOLT_FACTION_TENSION_THRESHOLD:
			continue
		var patron_id := client.suzerain_id
		client.suzerain_id = ""
		var rel := dm.get_or_create_relation(state, client.id, patron_id)
		rel.military_tension = clampf(rel.military_tension + DiplomacyManager.REVOLT_TENSION_INCREASE, 0.0, 100.0)
		dom.add_tension(-DiplomacyManager.REVOLT_TENSION_RELIEF)
