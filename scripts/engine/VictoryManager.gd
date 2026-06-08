class_name VictoryManager
extends RefCounted

# Stateless manager sprawdzający warunki zwycięstwa i przegranej.
# Spec: docs/superpowers/specs/12-victory-conditions-design.md
# Wywoływany przez TurnManager.process_turn na końcu, po state.advance_turn().

# === Stałe uniwersalne — kalibracja do mapy historycznej (12 prowincji) ===

const TURN_LIMIT := 200								# hard cap; po tym tura wygrywa religia z najwyższym prestiżem
const DOMINATION_PROVINCE_SHARE := 0.5				# ≥50% wszystkich prowincji
const DOMINATION_TURNS_REQUIRED := 3				# kolejnych tur ze spełnionym progiem dominacji
const PRESTIGE_HEGEMONY_RATIO := 2.0				# prestiż ≥ 2× drugiej najwyższej
const PRESTIGE_HEGEMONY_TURNS_REQUIRED := 10		# kolejnych tur ze spełnionym progiem hegemonii
const ELIMINATION_TURNS_REQUIRED := 5				# 0 prowincji przez N kolejnych tur (D1)
const VASSAL_DEFEAT_TURNS_REQUIRED := 20			# suzerain_id != "" przez N kolejnych tur (D2)
const SCHISM_GRACE_TURNS := 10						# nowa religia ze schizmy nie może wygrać przez N tur

# === Stałe unikalne per religia ===

const JUDAISM_PROVINCES_REQUIRED := 4
const JUDAISM_JERUSALEM_ID := "jerozolima"
const JUDAISM_FACTION_UNITY_TENSION_MAX := 30.0

const ZOROASTRIANISM_PROVINCES_REQUIRED := 3
const ZOROASTRIANISM_PERSEPOLIS_ID := "persepolis"

const ISLAM_PROVINCES_REQUIRED := 5
const ISLAM_MEKKA_ID := "mekka"
const ISLAM_JERUSALEM_ID := "jerozolima"

const EAST_CHRISTIANITY_VASSALS_REQUIRED := 3

const MANICHAEISM_AXIS_C_REQUIRED := 90.0
const MANICHAEISM_DISTINCT_SOURCES_REQUIRED := 4

# === Public API (implementacja w kolejnych taskach) ===

func check(state: Node) -> void:
	# Spec §6: pełna pipeline. Pomijamy jeśli gra już zakończona.
	if state.game_outcome != null:
		return
	update_flags(state)
	update_counters(state)
	# Lista religii sortowana deterministycznie po id ASC (krok 4 spec).
	var religions: Array[Religion] = []
	for r: Religion in state.all_religions():
		if r.defeated_at_turn == -1:
			religions.append(r)
	religions.sort_custom(func(a: Religion, b: Religion) -> bool: return a.id < b.id)

	# Krok 4: sprawdź zwycięstwa
	for religion: Religion in religions:
		if _is_in_schism_grace(religion, state):
			continue
		var reason: String = evaluate_unique_victory(religion, state)
		if reason == "":
			reason = evaluate_universal_victory(religion, state)
		if reason != "":
			_set_outcome(state, religion.id, reason)
			return

	# Krok 5: sprawdź przegrane
	for religion: Religion in religions:
		var defeat_reason: String = evaluate_defeat(religion, state)
		if defeat_reason != "":
			religion.defeated_at_turn = state.current_turn

	# Krok 6: turn limit fallback
	if state.current_turn >= TURN_LIMIT:
		var ranking := compute_ranking(state, true)
		if ranking.size() > 0:
			_set_outcome(state, ranking[0]["religion_id"], "turn_limit")

func _is_in_schism_grace(religion: Religion, state: Node) -> bool:
	return religion.parent_religion_id != "" \
			and state.current_turn - religion.birth_turn < SCHISM_GRACE_TURNS

func _set_outcome(state: Node, winner_id: String, reason: String) -> void:
	var outcome := GameOutcome.new()
	outcome.winner_id = winner_id
	outcome.reason = reason
	outcome.end_turn = state.current_turn
	outcome.ranking = compute_ranking(state, true)
	state.game_outcome = outcome

func update_flags(state: Node) -> void:
	# Spec §6 krok 2: ever_owned_province i ragnarok_triggered są trwałymi flagami
	# — raz ustawione nigdy nie resetują się. Pomijamy pokonane religie.
	for religion: Religion in state.all_religions():
		if religion.defeated_at_turn != -1:
			continue
		var owned_count: int = state.province_graph.provinces_with_owner(religion.id).size()
		if owned_count > 0 and not religion.ever_owned_province:
			religion.ever_owned_province = true
		# Ragnarök — tylko germanic_paganism, snapshot niepusty, jeszcze nie wytrigerowane
		if religion.id == "germanic_paganism" and not religion.ragnarok_triggered \
				and religion.starting_provinces_snapshot.size() > 0:
			var current_from_snapshot: int = 0
			for pid: String in religion.starting_provinces_snapshot:
				var p: Province = state.province_graph.get_province(pid)
				if p != null and p.owner == religion.id:
					current_from_snapshot += 1
			# Utracone >50% = obecnie kontrolowane ≤ snapshot.size() / 2 (integer division)
			if current_from_snapshot * 2 <= religion.starting_provinces_snapshot.size():
				religion.ragnarok_triggered = true

func update_counters(state: Node) -> void:
	# Spec §7: liczniki "przez N tur" — kumulatywne tylko po sobie, reset przy chwilowej utracie warunku.
	# Iterujemy religie z defeated_at_turn == -1; pokonane są pomijane.
	var total_provinces: int = state.province_graph.all_provinces().size()
	var domination_threshold: float = DOMINATION_PROVINCE_SHARE * total_provinces

	# Drugi najwyższy prestiż (potrzebny do warunku Hegemonia Prestiżu).
	# Pomijamy pokonane religie ze second_highest.
	var prestiges: Array = []
	for r: Religion in state.all_religions():
		if r.defeated_at_turn == -1:
			prestiges.append(r.prestige)
	prestiges.sort()
	prestiges.reverse()
	var second_highest: int = prestiges[1] if prestiges.size() >= 2 else 0

	for religion: Religion in state.all_religions():
		if religion.defeated_at_turn != -1:
			continue
		_ensure_progress_entry(state.victory_progress, religion.id, {"domination_turns": 0, "prestige_hegemony_turns": 0})
		_ensure_progress_entry(state.defeat_progress, religion.id, {"zero_provinces_turns": 0, "vassalage_turns": 0})

		# Dominacja
		var owned: int = state.province_graph.provinces_with_owner(religion.id).size()
		if float(owned) >= domination_threshold:
			state.victory_progress[religion.id]["domination_turns"] += 1
		else:
			state.victory_progress[religion.id]["domination_turns"] = 0

		# Hegemonia prestiżu
		var has_hegemony: bool = religion.prestige >= PRESTIGE_HEGEMONY_RATIO * float(second_highest)
		# Edge case: jedna religia w grze → second_highest = 0, każda > 0 spełnia automatycznie.
		# To jest zamierzone — gdy zostaje tylko jedna religia, wygrywa hegemonią natychmiast.
		# Dodatkowy guard: hegemonia wymaga prestiżu > 0 (inaczej trywialnie spełnione przy wszystkich 0).
		if has_hegemony and religion.prestige > 0:
			state.victory_progress[religion.id]["prestige_hegemony_turns"] += 1
		else:
			state.victory_progress[religion.id]["prestige_hegemony_turns"] = 0

		# Defeat counters
		if owned == 0:
			state.defeat_progress[religion.id]["zero_provinces_turns"] += 1
		else:
			state.defeat_progress[religion.id]["zero_provinces_turns"] = 0

		if religion.suzerain_id != "":
			state.defeat_progress[religion.id]["vassalage_turns"] += 1
		else:
			state.defeat_progress[religion.id]["vassalage_turns"] = 0

func _ensure_progress_entry(dict: Dictionary, key: String, default: Dictionary) -> void:
	if not dict.has(key):
		dict[key] = default.duplicate()

func evaluate_universal_victory(religion: Religion, state: Node) -> String:
	# Spec §4.1: trzy uniwersalne warunki. Sprawdzane w fixed order.
	var vp: Dictionary = state.victory_progress.get(religion.id, {})

	# (1) Dominacja terytorialna
	if vp.get("domination_turns", 0) >= DOMINATION_TURNS_REQUIRED:
		return "domination"

	# (2) Hegemonia prestiżu
	if vp.get("prestige_hegemony_turns", 0) >= PRESTIGE_HEGEMONY_TURNS_REQUIRED:
		return "prestige_hegemony"

	# (3) Święta Ziemia
	if _evaluate_holy_land(religion, state):
		return "holy_land"

	return ""

func _evaluate_holy_land(religion: Religion, state: Node) -> bool:
	# Prerequisite: religia musi mieć przynajmniej jedno własne święte miejsce.
	if religion.holy_sites.is_empty():
		return false
	# Wszystkie własne holy_sites pod kontrolą
	for site_id: String in religion.holy_sites:
		var p: Province = state.province_graph.get_province(site_id)
		if p == null or p.owner != religion.id:
			return false
	# Plus ≥1 cudze święte miejsce
	for p: Province in state.province_graph.all_provinces():
		if p.is_holy_site and p.owner == religion.id and not religion.holy_sites.has(p.id):
			return true
	return false

func evaluate_unique_victory(religion: Religion, state: Node) -> String:
	# Spec §4.2: jeden unikalny warunek per religia (in-scope w Plan 12).
	match religion.id:
		"manichaeism":
			if religion.get_axis("C") >= MANICHAEISM_AXIS_C_REQUIRED \
					and religion.absorbed_idea_sources.size() >= MANICHAEISM_DISTINCT_SOURCES_REQUIRED:
				return "manichaeism_illumination"
		"judaism":
			if _judaism_return_satisfied(religion, state):
				return "judaism_return"
		"zoroastrianism":
			if _zoroastrianism_renaissance_satisfied(religion, state):
				return "zoroastrianism_renaissance"
		"eastern_christianity":
			if _east_christianity_pentarchy_satisfied(religion, state):
				return "east_christianity_pentarchy"
		"islam":
			if _islam_caliphate_satisfied(religion, state):
				return "islam_caliphate"
		"germanic_paganism":
			if _germanic_ragnarok_satisfied(religion, state):
				return "germanic_ragnarok"
	return ""

func _judaism_return_satisfied(religion: Religion, state: Node) -> bool:
	if state.province_graph.get_province(JUDAISM_JERUSALEM_ID).owner != religion.id:
		return false
	if state.province_graph.provinces_with_owner(religion.id).size() < JUDAISM_PROVINCES_REQUIRED:
		return false
	for f: Faction in religion.factions:
		if f.tension >= JUDAISM_FACTION_UNITY_TENSION_MAX:
			return false
	return true

func _zoroastrianism_renaissance_satisfied(religion: Religion, state: Node) -> bool:
	if state.province_graph.get_province(ZOROASTRIANISM_PERSEPOLIS_ID).owner != religion.id:
		return false
	return state.province_graph.provinces_with_owner(religion.id).size() >= ZOROASTRIANISM_PROVINCES_REQUIRED

func _east_christianity_pentarchy_satisfied(religion: Religion, state: Node) -> bool:
	var vassal_count: int = 0
	for r: Religion in state.all_religions():
		if r.suzerain_id == religion.id:
			vassal_count += 1
	return vassal_count >= EAST_CHRISTIANITY_VASSALS_REQUIRED

func _islam_caliphate_satisfied(religion: Religion, state: Node) -> bool:
	if state.province_graph.get_province(ISLAM_MEKKA_ID).owner != religion.id:
		return false
	if state.province_graph.get_province(ISLAM_JERUSALEM_ID).owner != religion.id:
		return false
	return state.province_graph.provinces_with_owner(religion.id).size() >= ISLAM_PROVINCES_REQUIRED

func _germanic_ragnarok_satisfied(religion: Religion, state: Node) -> bool:
	if not religion.ragnarok_triggered:
		return false
	if religion.starting_provinces_snapshot.is_empty():
		return false
	for pid: String in religion.starting_provinces_snapshot:
		var p: Province = state.province_graph.get_province(pid)
		if p == null or p.owner != religion.id:
			return false
	return true

func evaluate_defeat(religion: Religion, state: Node) -> String:
	# Spec §5: D1 (elimination) i D2 (long_vassalage), oba wymagają ever_owned_province.
	if not religion.ever_owned_province:
		return ""
	var dp: Dictionary = state.defeat_progress.get(religion.id, {})
	if dp.get("zero_provinces_turns", 0) >= ELIMINATION_TURNS_REQUIRED:
		return "elimination"
	if dp.get("vassalage_turns", 0) >= VASSAL_DEFEAT_TURNS_REQUIRED:
		return "long_vassalage"
	return ""

func compute_ranking(state: Node, exclude_defeated: bool = true) -> Array:
	var entries: Array = []
	for r: Religion in state.all_religions():
		if exclude_defeated and r.defeated_at_turn != -1:
			continue
		entries.append({
			"religion_id": r.id,
			"prestige": r.prestige,
			"provinces": state.province_graph.provinces_with_owner(r.id).size(),
		})
	# DESC po prestiżu, tie-break po id ASC
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["prestige"] != b["prestige"]:
			return a["prestige"] > b["prestige"]
		return a["religion_id"] < b["religion_id"]
	)
	return entries
