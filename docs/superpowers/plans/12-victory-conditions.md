# Plan 12 — Warunki zwycięstwa i przegranej Implementation Plan

> **For Claude:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Zaimplementować pełną mechanikę końca gry: 3 uniwersalne warunki zwycięstwa, 6 unikalnych warunków per religia, 2 warunki przegranej, twardy cap 200 tur z rankingiem fallback, modal `GameOverDialog` w MainShell.

**Architecture:** Stateless `VictoryManager` (zgodny z konwencją `TurnManager`/`WarManager`/etc.) wywoływany na końcu `TurnManager.process_turn`. Stan końcowy w `GameState.game_outcome: GameOutcome` (Resource). Liczniki "przez N tur" w `GameState.victory_progress`/`defeat_progress` (Dictionary, default-safe access). Trwałe flagi (`ever_owned_province`, `ragnarok_triggered`, `defeated_at_turn`, `birth_turn`, `absorbed_idea_sources`) na `Religion`. Hook-i w `SchismManager.trigger_schism` (birth_turn) i `DoctrineManager.accept_idea` (absorbed_idea_sources). UI: nowy `GameOverDialog` instancjonowany przez `MainShell` przy wykryciu `state.game_outcome != null` lub player defeat.

**Tech Stack:** Godot 4.6.3, GDScript 2.0, GUT (Godot Unit Testing).

**Spec:** [`docs/superpowers/specs/12-victory-conditions-design.md`](../specs/12-victory-conditions-design.md)

---

## Convention reminders (z [CLAUDE.md](../../../CLAUDE.md))

- **Tab indent** w `.gd` i `.tscn`.
- **`class_name`** na każdym skrypcie engine (`VictoryManager`, `GameOutcome`) i UI (`GameOverDialog`).
- **Managery extend `RefCounted`**, hold no state, biorą `state: Node` jako pierwszy parametr.
- **Stałe engine tunable** — testy referencują `VictoryManager.DOMINATION_PROVINCE_SHARE`, `VictoryManager.TURN_LIMIT` itd., **nie hardcoduj wartości**.
- **`unique_name_in_owner = true` + `%Name`** dla nazwanych dzieci w scenach UI.
- **Setters guard with `is_inside_tree()`** przed `@onready` w UI (precedens: `RelationListItem.gd`, `FactionCard.gd`).
- **`emit_signal("name", args)`** (forma stringowa) — w MVP `GameOverDialog` ewentualnie emituje `new_game_pressed` / `closed`.
- **Identyfikatory ANGIELSKIE** — pliki, klasy, zmienne, ID. Polski tylko w `Label.text`, `display_name`, komentarzach, JSON. Zgodne z memory `feedback_english_identifiers.md`.
- **Class cache caveat:** po utworzeniu nowego `class_name` skryptu (`GameOutcome`, `VictoryManager`, `GameOverDialog`) headless GUT może rzucać "Could not find type X". Uruchom `godot --headless --path . --quit` aby zregenerować `.godot/global_script_class_cache.cfg`.

---

## Test command reference

```bash
# Cała suite
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# Pojedynczy plik testu (zawsze res://-absolutna ścieżka)
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_universal.gd -gexit

# Subkatalog
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gexit
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gexit
```

---

## Test helper pattern (kopiować do każdego nowego pliku testu engine)

Wszystkie testy engine używają tego samego pattern do utworzenia GameState:

```gdscript
extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state(player_id: String = "islam") -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize(player_id, religions, graph)
	return gs
```

(Precedens: `tests/engine/test_turn_manager.gd`, `tests/engine/test_diplomacy_manager.gd`.)

**Dla testów UI** dodatkowo helper `_attach_to_tree(node: Control)`:

```gdscript
func _attach_to_tree(node: Control) -> void:
	add_child_autofree(node)
	# autofree dodaje sprzątanie w teardown
```

---

## File Structure

**Tworzone:**

```
scripts/engine/
├── VictoryManager.gd
└── GameOutcome.gd

scripts/ui/dialogs/
└── GameOverDialog.gd

scenes/ui/dialogs/
└── GameOverDialog.tscn

tests/engine/
├── test_game_outcome.gd
├── test_victory_manager_flags.gd
├── test_victory_manager_universal.gd
├── test_victory_manager_unique.gd
├── test_victory_manager_defeat.gd
├── test_victory_manager_endgame.gd
├── test_victory_manager_integration.gd
└── test_doctrine_manager_idea_sources.gd

tests/ui/
├── test_game_over_dialog.gd
└── test_main_shell_game_over.gd
```

**Modyfikowane:**

- `scripts/engine/Religion.gd` — 6 nowych pól.
- `scripts/engine/GameState.gd` — 3 nowe pola + `is_game_over()` + `reset()` + rozszerzenie `initialize()` (snapshot + ever_owned_province).
- `scripts/engine/TurnManager.gd` — wywołanie `VictoryManager.check(state)` na końcu `process_turn`.
- `scripts/engine/SchismManager.gd` — `birth_turn = state.current_turn` w `trigger_schism`.
- `scripts/engine/DoctrineManager.gd` — rejestracja `absorbed_idea_sources` w `accept_idea`.
- `scripts/ui/Header.gd` — metoda `set_end_turn_enabled(enabled: bool)`.
- `scripts/ui/MainShell.gd` — detekcja `state.game_outcome != null` / player defeat, instancjonowanie `GameOverDialog`.
- `tests/engine/test_game_state.gd` — rozszerzenie o testy `initialize` snapshot i `reset()`.
- `tests/engine/test_religion.gd` — rozszerzenie o testy nowych pól.
- `tests/engine/test_schism_manager.gd` (jeśli istnieje) lub nowy test — birth_turn ustawiane w trigger_schism.
- `CLAUDE.md` — wzmianka o `VictoryManager` + `GameOverDialog`.

**Mapa: spec → plik kodu → plik testu**

| Spec §  | Plik kodu                              | Plik testu                                                | Task |
|---------|----------------------------------------|-----------------------------------------------------------|------|
| §8 Religion | `scripts/engine/Religion.gd`        | `tests/engine/test_religion.gd` (rozszerzenie)            | 1    |
| §3 GameOutcome | `scripts/engine/GameOutcome.gd`  | `tests/engine/test_game_outcome.gd`                       | 2    |
| §8 GameState | `scripts/engine/GameState.gd`      | `tests/engine/test_game_state.gd` (rozszerzenie)          | 3, 4 |
| §8 SchismManager | `scripts/engine/SchismManager.gd` | `tests/engine/test_victory_manager_integration.gd`     | 5    |
| §8 DoctrineManager | `scripts/engine/DoctrineManager.gd` | `tests/engine/test_doctrine_manager_idea_sources.gd` | 6    |
| §3 API | `scripts/engine/VictoryManager.gd`     | `tests/engine/test_victory_manager_flags.gd`              | 7, 8 |
| §7 liczniki | `scripts/engine/VictoryManager.gd` | `tests/engine/test_victory_manager_flags.gd`              | 9    |
| §4.1   | `scripts/engine/VictoryManager.gd`     | `tests/engine/test_victory_manager_universal.gd`          | 10   |
| §4.2   | `scripts/engine/VictoryManager.gd`     | `tests/engine/test_victory_manager_unique.gd`             | 11   |
| §5     | `scripts/engine/VictoryManager.gd`     | `tests/engine/test_victory_manager_defeat.gd`             | 12   |
| §6     | `scripts/engine/VictoryManager.gd`     | `tests/engine/test_victory_manager_endgame.gd`            | 13   |
| §8 TurnManager | `scripts/engine/TurnManager.gd` | `tests/engine/test_victory_manager_integration.gd`        | 14   |
| §6 UI  | `scripts/ui/dialogs/GameOverDialog.*`  | `tests/ui/test_game_over_dialog.gd`                       | 15   |
| §6 UI  | `scripts/ui/MainShell.gd` + Header     | `tests/ui/test_main_shell_game_over.gd`                   | 16, 17 |
| §  —   | `CLAUDE.md`                            | — (docs only)                                             | 18   |

---

## Chunk 1: Foundation — data classes

---

### Task 1: Religion — 6 nowych pól

**Cel:** Rozszerzyć `Religion` o pola wymagane przez VictoryManager: `defeated_at_turn`, `birth_turn`, `starting_provinces_snapshot`, `ever_owned_province`, `ragnarok_triggered`, `absorbed_idea_sources`. Backward compatible — wszystkie mają domyślne wartości; istniejące JSON-y nie wymagają zmian.

**Files:**
- Modify: `scripts/engine/Religion.gd`
- Modify: `tests/engine/test_religion.gd`

- [ ] **Step 1: Napisz failing test nowych pól z domyślnymi wartościami**

Dopisz do `tests/engine/test_religion.gd`:

```gdscript
func test_new_field_defeated_at_turn_defaults_to_minus_one():
	var r := Religion.new()
	assert_eq(r.defeated_at_turn, -1)

func test_new_field_birth_turn_defaults_to_zero():
	var r := Religion.new()
	assert_eq(r.birth_turn, 0)

func test_new_field_starting_provinces_snapshot_defaults_to_empty():
	var r := Religion.new()
	assert_eq(r.starting_provinces_snapshot.size(), 0)

func test_new_field_ever_owned_province_defaults_to_false():
	var r := Religion.new()
	assert_false(r.ever_owned_province)

func test_new_field_ragnarok_triggered_defaults_to_false():
	var r := Religion.new()
	assert_false(r.ragnarok_triggered)

func test_new_field_absorbed_idea_sources_defaults_to_empty():
	var r := Religion.new()
	assert_eq(r.absorbed_idea_sources.size(), 0)

func test_starting_provinces_snapshot_is_string_array():
	var r := Religion.new()
	r.starting_provinces_snapshot = ["mekka", "lewant"]
	assert_eq(r.starting_provinces_snapshot[0], "mekka")
	assert_eq(r.starting_provinces_snapshot[1], "lewant")

func test_absorbed_idea_sources_is_string_array():
	var r := Religion.new()
	r.absorbed_idea_sources = ["islam", "judaism"]
	assert_eq(r.absorbed_idea_sources[0], "islam")
	assert_eq(r.absorbed_idea_sources[1], "judaism")
```

- [ ] **Step 2: Uruchom testy — powinny failować**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_religion.gd -gexit
```

Expected: 8 nowych testów failuje z "Invalid get index 'defeated_at_turn' on base: 'Resource'".

- [ ] **Step 3: Dodaj pola do `scripts/engine/Religion.gd`**

Dopisz **przed** funkcjami (zaraz po istniejących `@export` polach, **przed** `func get_axis`):

```gdscript
@export var defeated_at_turn: int = -1					 # -1 = w grze, inaczej numer tury przegranej
@export var birth_turn: int = 0							 # 0 = od startu gry, inaczej numer tury narodzin ze schizmy
@export var starting_provinces_snapshot: Array[String] = []	 # snapshot owner-prowincji w turze init
@export var ever_owned_province: bool = false			 # trwała flaga: religia kontrolowała ≥1 prowincję w jakimś momencie
@export var ragnarok_triggered: bool = false			 # trwała flaga: religia utraciła >50% snapshot (germanic_paganism)
@export var absorbed_idea_sources: Array[String] = []	 # unikalna lista from_religion_id zaabsorbowanych idei
```

- [ ] **Step 4: Uruchom testy — wszystkie zielone**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_religion.gd -gexit
```

Expected: wszystkie testy `test_religion.gd` pass (stare + 8 nowych).

- [ ] **Step 5: Cała suite — brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: All tests passed. (Pola są tylko addytywne, nic nie powinno się popsuć.)

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/Religion.gd tests/engine/test_religion.gd
git commit -m "feat(religion): dodaj pola koncoworozgrywkowe (defeated_at_turn, birth_turn, snapshot, ever_owned, ragnarok, absorbed_sources)"
```

---

### Task 2: GameOutcome resource

**Cel:** Nowy Resource opisujący końcowy stan gry: zwycięzca, powód, tura zakończenia, ranking finalny.

**Files:**
- Create: `scripts/engine/GameOutcome.gd`
- Create: `tests/engine/test_game_outcome.gd`

- [ ] **Step 1: Napisz failing test**

Stwórz `tests/engine/test_game_outcome.gd`:

```gdscript
extends GutTest

func test_game_outcome_has_default_empty_winner_id():
	var outcome := GameOutcome.new()
	assert_eq(outcome.winner_id, "")

func test_game_outcome_has_default_empty_reason():
	var outcome := GameOutcome.new()
	assert_eq(outcome.reason, "")

func test_game_outcome_has_default_zero_end_turn():
	var outcome := GameOutcome.new()
	assert_eq(outcome.end_turn, 0)

func test_game_outcome_has_default_empty_ranking():
	var outcome := GameOutcome.new()
	assert_eq(outcome.ranking.size(), 0)

func test_game_outcome_stores_winner_id():
	var outcome := GameOutcome.new()
	outcome.winner_id = "islam"
	assert_eq(outcome.winner_id, "islam")

func test_game_outcome_stores_reason():
	var outcome := GameOutcome.new()
	outcome.reason = "domination"
	assert_eq(outcome.reason, "domination")

func test_game_outcome_stores_end_turn():
	var outcome := GameOutcome.new()
	outcome.end_turn = 87
	assert_eq(outcome.end_turn, 87)

func test_game_outcome_ranking_accepts_dictionary_entries():
	var outcome := GameOutcome.new()
	outcome.ranking = [
		{"religion_id": "islam", "prestige": 540, "provinces": 6},
		{"religion_id": "western_christianity", "prestige": 510, "provinces": 3},
	]
	assert_eq(outcome.ranking.size(), 2)
	assert_eq(outcome.ranking[0]["religion_id"], "islam")
	assert_eq(outcome.ranking[1]["prestige"], 510)
```

- [ ] **Step 2: Uruchom test — powinien failować**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_game_outcome.gd -gexit
```

Expected: failure — "Could not find type GameOutcome".

- [ ] **Step 3: Utwórz `scripts/engine/GameOutcome.gd`**

```gdscript
class_name GameOutcome
extends Resource

# Resource opisujący końcowy stan gry. GameState.game_outcome != null oznacza
# że gra jest zakończona (VictoryManager.check ustawia, MainShell pokazuje modal).

@export var winner_id: String = ""	# id religii która wygrała (zawsze niepusty — także przy fallback turn_limit)
@export var reason: String = ""		# patrz GameOverDialog reason mapping w Task 15
@export var end_turn: int = 0		# numer tury w momencie ustawienia outcome
@export var ranking: Array = []		# Array[Dictionary{religion_id: String, prestige: int, provinces: int}], DESC po prestiżu
```

- [ ] **Step 4: Regeneruj cache klas i uruchom test — powinien przejść**

```bash
godot --headless --path . --quit
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_game_outcome.gd -gexit
```

Expected: 8/8 testów pass.

- [ ] **Step 5: Cała suite — brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: All tests passed.

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/GameOutcome.gd scripts/engine/GameOutcome.gd.uid tests/engine/test_game_outcome.gd tests/engine/test_game_outcome.gd.uid
git commit -m "feat(engine): dodaj GameOutcome resource (winner_id, reason, end_turn, ranking)"
```

Uwaga: pliki `.uid` mogą być wygenerowane automatycznie po `godot --quit`. Jeśli nie istnieją w git status — pomiń je w `git add`.

---

### Task 3: GameState — game_outcome, victory_progress, defeat_progress, is_game_over(), reset()

**Cel:** Rozszerzyć GameState o stan końcowy (`game_outcome`) i liczniki postępu (`victory_progress`, `defeat_progress`), oraz metody pomocnicze `is_game_over()` i `reset()` (wymaga wymienienia każdego pola — zob. spec §8).

**Files:**
- Modify: `scripts/engine/GameState.gd`
- Modify: `tests/engine/test_game_state.gd`

- [ ] **Step 1: Napisz failing testy**

Dopisz do `tests/engine/test_game_state.gd`:

```gdscript
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _fresh_state() -> Node:
	# Helper: GameState bez initialize, gołe pola domyślne.
	return GameStateScript.new()

func test_game_outcome_defaults_to_null():
	var gs := _fresh_state()
	assert_null(gs.game_outcome)

func test_victory_progress_defaults_to_empty_dict():
	var gs := _fresh_state()
	assert_eq(gs.victory_progress.size(), 0)

func test_defeat_progress_defaults_to_empty_dict():
	var gs := _fresh_state()
	assert_eq(gs.defeat_progress.size(), 0)

func test_is_game_over_false_when_outcome_null():
	var gs := _fresh_state()
	assert_false(gs.is_game_over())

func test_is_game_over_true_when_outcome_set():
	var gs := _fresh_state()
	gs.game_outcome = GameOutcome.new()
	assert_true(gs.is_game_over())

func test_reset_clears_current_turn_to_one():
	var gs := _fresh_state()
	gs.current_turn = 87
	gs.reset()
	assert_eq(gs.current_turn, 1)

func test_reset_clears_player_religion_id():
	var gs := _fresh_state()
	gs.player_religion_id = "islam"
	gs.reset()
	assert_eq(gs.player_religion_id, "")

func test_reset_clears_province_graph():
	var gs := _fresh_state()
	gs.province_graph = ProvinceGraph.new()
	gs.reset()
	assert_null(gs.province_graph)

func test_reset_clears_religions():
	var gs := _fresh_state()
	var r := Religion.new()
	r.id = "islam"
	gs.add_religion(r)
	gs.reset()
	assert_eq(gs.all_religions().size(), 0)

func test_reset_clears_pending_ideas():
	var gs := _fresh_state()
	gs.pending_ideas.append(Idea.new())
	gs.reset()
	assert_eq(gs.pending_ideas.size(), 0)

func test_reset_clears_scholar_missions():
	var gs := _fresh_state()
	gs.scholar_missions.append({"x": 1})
	gs.reset()
	assert_eq(gs.scholar_missions.size(), 0)

func test_reset_clears_active_wars():
	var gs := _fresh_state()
	gs.active_wars.append(War.new())
	gs.reset()
	assert_eq(gs.active_wars.size(), 0)

func test_reset_clears_pending_defeat_events():
	var gs := _fresh_state()
	gs.pending_defeat_events.append(DefeatEvent.new())
	gs.reset()
	assert_eq(gs.pending_defeat_events.size(), 0)

func test_reset_clears_relations():
	var gs := _fresh_state()
	gs.relations.append(RelationState.new())
	gs.reset()
	assert_eq(gs.relations.size(), 0)

func test_reset_clears_active_coalitions():
	var gs := _fresh_state()
	gs.active_coalitions.append(Coalition.new())
	gs.reset()
	assert_eq(gs.active_coalitions.size(), 0)

func test_reset_clears_missionary_missions():
	var gs := _fresh_state()
	gs.missionary_missions.append(MissionaryMission.new())
	gs.reset()
	assert_eq(gs.missionary_missions.size(), 0)

func test_reset_clears_game_outcome():
	var gs := _fresh_state()
	gs.game_outcome = GameOutcome.new()
	gs.reset()
	assert_null(gs.game_outcome)

func test_reset_clears_victory_progress():
	var gs := _fresh_state()
	gs.victory_progress["islam"] = {"domination_turns": 5}
	gs.reset()
	assert_eq(gs.victory_progress.size(), 0)

func test_reset_clears_defeat_progress():
	var gs := _fresh_state()
	gs.defeat_progress["manichaeism"] = {"zero_provinces_turns": 3}
	gs.reset()
	assert_eq(gs.defeat_progress.size(), 0)
```

- [ ] **Step 2: Uruchom testy — powinny failować**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_game_state.gd -gexit
```

Expected: failures dla każdego z 19 nowych testów (brakuje pól + metod).

- [ ] **Step 3: Dodaj pola i metody do `scripts/engine/GameState.gd`**

Dopisz pola **bezpośrednio po istniejących** (między `missionary_missions` a `func initialize`):

```gdscript
var game_outcome: GameOutcome = null
var victory_progress: Dictionary = {}	# religion_id → {domination_turns: int, prestige_hegemony_turns: int}
var defeat_progress: Dictionary = {}	# religion_id → {zero_provinces_turns: int, vassalage_turns: int}
```

Dopisz metody **przed lub po** istniejących (po `advance_turn`, najlepiej na końcu pliku):

```gdscript
func is_game_over() -> bool:
	return game_outcome != null

func reset() -> void:
	# Zeruje wszystkie pola do stanu sprzed initialize(). Wywoływane przez GameOverDialog
	# "Nowa gra" przed change_scene_to_file. Autoload jest persistent w Godot — brak resetu
	# powoduje wyciek stanu między grami.
	#
	# CRITICAL: gdy w przyszłości dojdzie nowe pole do GameState, MUSI tu trafić.
	# Test test_reset_* w tests/engine/test_game_state.gd weryfikuje każde pole osobno.
	current_turn = 1
	player_religion_id = ""
	province_graph = null
	_religions.clear()
	pending_ideas.clear()
	scholar_missions.clear()
	active_wars.clear()
	pending_defeat_events.clear()
	relations.clear()
	active_coalitions.clear()
	missionary_missions.clear()
	game_outcome = null
	victory_progress.clear()
	defeat_progress.clear()
```

- [ ] **Step 4: Uruchom testy — wszystkie zielone**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_game_state.gd -gexit
```

Expected: wszystkie testy pass.

- [ ] **Step 5: Cała suite — brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: All tests passed.

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/GameState.gd tests/engine/test_game_state.gd
git commit -m "feat(engine): GameState.game_outcome + victory/defeat_progress + is_game_over() + reset()"
```

---

### Task 4: GameState.initialize — snapshot starting_provinces + ever_owned_province

**Cel:** Rozszerzyć `GameState.initialize` o snapshot startowych prowincji per religia oraz ustawienie `ever_owned_province = true` dla religii ze startowymi prowincjami. Wywoływane raz, na początku gry.

**Files:**
- Modify: `scripts/engine/GameState.gd`
- Modify: `tests/engine/test_game_state.gd`

- [ ] **Step 1: Napisz failing testy**

Dopisz do `tests/engine/test_game_state.gd`:

```gdscript
func _make_initialized_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func test_initialize_snapshots_starting_provinces_for_arabian_paganism():
	# arabian_paganism kontroluje mekka na mapie historycznej (provinces_historical.json)
	var gs := _make_initialized_state()
	var r := gs.get_religion("arabian_paganism")
	assert_true(r.starting_provinces_snapshot.has("mekka"),
		"arabian_paganism powinno mieć mekka w snapshot, miało: " + str(r.starting_provinces_snapshot))

func test_initialize_snapshots_starting_provinces_for_eastern_christianity():
	# eastern_christianity kontroluje jerozolima i konstantynopol
	var gs := _make_initialized_state()
	var r := gs.get_religion("eastern_christianity")
	assert_true(r.starting_provinces_snapshot.has("jerozolima"))
	assert_true(r.starting_provinces_snapshot.has("konstantynopol"))

func test_initialize_sets_ever_owned_true_for_religion_with_starting_provinces():
	var gs := _make_initialized_state()
	var r := gs.get_religion("islam")
	# Islam ma prowincje startowe w historycznym fixture
	assert_true(r.ever_owned_province, "islam ma startowe prowincje → ever_owned_province == true")

func test_initialize_leaves_ever_owned_false_for_religion_without_starting_provinces():
	# Manicheizm jest w JSON ale nie ma żadnej prowincji w provinces_historical.json
	var gs := _make_initialized_state()
	var r := gs.get_religion("manichaeism")
	assert_false(r.ever_owned_province, "manichaeism bez prowincji startowych → ever_owned_province == false")
	assert_eq(r.starting_provinces_snapshot.size(), 0)

func test_initialize_leaves_ever_owned_false_for_germanic_paganism():
	var gs := _make_initialized_state()
	var r := gs.get_religion("germanic_paganism")
	assert_false(r.ever_owned_province)
	assert_eq(r.starting_provinces_snapshot.size(), 0)
```

- [ ] **Step 2: Uruchom testy — powinny failować**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_game_state.gd -gexit
```

Expected: 5 testów failuje (snapshot pusty / `ever_owned_province == false` dla islamu).

- [ ] **Step 3: Rozszerz `GameState.initialize` w `scripts/engine/GameState.gd`**

Zmień funkcję `initialize`:

```gdscript
func initialize(player_id: String, religions: Array[Religion], graph: ProvinceGraph) -> void:
	player_religion_id = player_id
	province_graph = graph
	_religions.clear()
	for r: Religion in religions:
		_religions[r.id] = r
	# Po wpisaniu wszystkich religii i grafu — snapshot startowych prowincji per religia
	# (potrzebny dla warunku Ragnarök w spec 12 §4.2) oraz ustawienie ever_owned_province
	# (prereq dla D1/D2 w spec 12 §5).
	for r: Religion in religions:
		var owned: Array[String] = []
		for province in graph.provinces_with_owner(r.id):
			owned.append(province.id)
		r.starting_provinces_snapshot = owned
		if not owned.is_empty():
			r.ever_owned_province = true
```

- [ ] **Step 4: Uruchom testy — wszystkie zielone**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_game_state.gd -gexit
```

Expected: wszystkie testy pass.

- [ ] **Step 5: Cała suite — brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: All tests passed.

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/GameState.gd tests/engine/test_game_state.gd
git commit -m "feat(engine): GameState.initialize snapshotuje startowe prowincje i ustawia ever_owned_province"
```

---

## Chunk 2: Engine hooks — SchismManager + DoctrineManager

---

### Task 5: SchismManager.trigger_schism — ustaw birth_turn

**Cel:** Każda religia powstała ze schizmy dostaje `birth_turn = state.current_turn`. Pozwala VictoryManager nakładać schism grace (10 tur od narodzin warunki wygranej są pomijane — spec 12 §6).

**Files:**
- Modify: `scripts/engine/SchismManager.gd`
- Create: `tests/engine/test_schism_manager_birth_turn.gd` (lub rozszerz istniejący jeśli jest)

- [ ] **Step 1: Sprawdź istnienie pliku testu schism managera**

```bash
ls tests/engine/test_schism_manager*.gd 2>/dev/null
```

Jeśli istnieje — dopisz testy do niego. Jeśli nie — stwórz nowy plik `tests/engine/test_schism_manager_birth_turn.gd`.

- [ ] **Step 2: Napisz failing test**

W odpowiednim pliku testu dopisz/utwórz:

```gdscript
extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func test_trigger_schism_sets_birth_turn_to_current_turn():
	var gs := _make_state()
	gs.current_turn = 42
	var religion: Religion = gs.get_religion("islam")
	var faction: Faction = religion.get_faction("sufis") if religion.get_faction("sufis") != null else religion.factions[0]
	faction.influence = 0.5  # spełnia SCHISM_MIN_INFLUENCE
	var sm := SchismManager.new()
	var new_rel: Religion = sm.trigger_schism(faction, religion, gs)
	assert_not_null(new_rel, "schism powinien się powieść (influence >= SCHISM_MIN_INFLUENCE)")
	assert_eq(new_rel.birth_turn, 42, "nowa religia powinna mieć birth_turn == state.current_turn")

func test_trigger_schism_sets_parent_religion_id():
	# Smoke test: parent_religion_id już istnieje, ale upewniamy się że schism nadal go ustawia
	var gs := _make_state()
	var religion: Religion = gs.get_religion("islam")
	var faction: Faction = religion.factions[0]
	faction.influence = 0.5
	var sm := SchismManager.new()
	var new_rel: Religion = sm.trigger_schism(faction, religion, gs)
	assert_eq(new_rel.parent_religion_id, "islam")
```

- [ ] **Step 3: Uruchom test — powinien failować**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_schism_manager_birth_turn.gd -gexit
```

Expected: `test_trigger_schism_sets_birth_turn_to_current_turn` failuje — `new_rel.birth_turn == 0` zamiast 42.

- [ ] **Step 4: Dodaj `birth_turn` setting w `scripts/engine/SchismManager.gd`**

Zmień funkcję `trigger_schism` — dodaj linię po `new_rel.prestige = SCHISM_INITIAL_PRESTIGE`:

```gdscript
new_rel.prestige = SCHISM_INITIAL_PRESTIGE
new_rel.birth_turn = state.current_turn	# spec 12 §6: schism grace 10 tur od narodzin
```

- [ ] **Step 5: Uruchom test — pass**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_schism_manager_birth_turn.gd -gexit
```

Expected: pass.

- [ ] **Step 6: Cała suite — brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: All tests passed.

- [ ] **Step 7: Commit**

```bash
git add scripts/engine/SchismManager.gd tests/engine/test_schism_manager_birth_turn.gd
git commit -m "feat(schism): ustaw birth_turn dla religii powstalej ze schizmy"
```

---

### Task 6: DoctrineManager.accept_idea — rejestruj absorbed_idea_sources

**Cel:** Każde wywołanie `accept_idea(idea, religion, state)` rejestruje `idea.from_religion_id` w `religion.absorbed_idea_sources` (jeśli source != religion.id i jeszcze nie ma na liście). Konieczne dla warunku Manicheizm Synkretyczna Iluminacja (spec 12 §4.2 (4)).

**Files:**
- Modify: `scripts/engine/DoctrineManager.gd`
- Create: `tests/engine/test_doctrine_manager_idea_sources.gd`

- [ ] **Step 1: Napisz failing testy**

Stwórz `tests/engine/test_doctrine_manager_idea_sources.gd`:

```gdscript
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
```

- [ ] **Step 2: Uruchom testy — powinny failować**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_doctrine_manager_idea_sources.gd -gexit
```

Expected: 5 testów failuje (`rel.absorbed_idea_sources.is_empty()`).

- [ ] **Step 3: Zmodyfikuj `DoctrineManager.accept_idea` w `scripts/engine/DoctrineManager.gd`**

Aktualnie linia 91–93:

```gdscript
func accept_idea(idea: Idea, religion: Religion, state: Node) -> void:
	religion.shift_axis(idea.axis, idea.delta)
	state.pending_ideas.erase(idea)
```

Zmień na:

```gdscript
func accept_idea(idea: Idea, religion: Religion, state: Node) -> void:
	religion.shift_axis(idea.axis, idea.delta)
	# Spec 12 §8: rejestracja źródła dla warunku Manicheizm Synkretyczna Iluminacja.
	# Guard chroni przed self-source (artefakt edge case) i pustym from_religion_id.
	if idea.from_religion_id != "" and idea.from_religion_id != religion.id:
		if not religion.absorbed_idea_sources.has(idea.from_religion_id):
			religion.absorbed_idea_sources.append(idea.from_religion_id)
	state.pending_ideas.erase(idea)
```

- [ ] **Step 4: Uruchom testy — wszystkie zielone**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_doctrine_manager_idea_sources.gd -gexit
```

Expected: 5/5 pass.

- [ ] **Step 5: Cała suite — brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: All tests passed.

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/DoctrineManager.gd tests/engine/test_doctrine_manager_idea_sources.gd
git commit -m "feat(doctrine): rejestruj absorbed_idea_sources w accept_idea (Manicheizm prereq)"
```

---

## Chunk 3: VictoryManager core

---

### Task 7: VictoryManager — szkielet pliku + stałe

**Cel:** Pusty szkielet `VictoryManager` z `class_name`, wszystkimi stałymi (progi z spec §3 — DOMINATION, PRESTIGE_HEGEMONY, ELIMINATION, VASSAL, SCHISM_GRACE, oraz progi unikalne dla 6 religii) i pustą `check()`. Testy sprawdzają tylko że klasa istnieje i ma stałe; logika dodawana w kolejnych taskach.

**Files:**
- Create: `scripts/engine/VictoryManager.gd`
- Create: `tests/engine/test_victory_manager_constants.gd`

- [ ] **Step 1: Napisz failing test stałych**

Stwórz `tests/engine/test_victory_manager_constants.gd`:

```gdscript
extends GutTest

# Sanity test: stałe istnieją i mają sensowne wartości. Chroni przed milczącym
# usunięciem stałej (która jest referencowana z testów warunków).

func test_universal_constants_exist():
	assert_eq(VictoryManager.TURN_LIMIT, 200)
	assert_almost_eq(VictoryManager.DOMINATION_PROVINCE_SHARE, 0.5, 0.001)
	assert_eq(VictoryManager.DOMINATION_TURNS_REQUIRED, 3)
	assert_almost_eq(VictoryManager.PRESTIGE_HEGEMONY_RATIO, 2.0, 0.001)
	assert_eq(VictoryManager.PRESTIGE_HEGEMONY_TURNS_REQUIRED, 10)
	assert_eq(VictoryManager.ELIMINATION_TURNS_REQUIRED, 5)
	assert_eq(VictoryManager.VASSAL_DEFEAT_TURNS_REQUIRED, 20)
	assert_eq(VictoryManager.SCHISM_GRACE_TURNS, 10)

func test_unique_constants_exist():
	assert_eq(VictoryManager.JUDAISM_PROVINCES_REQUIRED, 4)
	assert_eq(VictoryManager.JUDAISM_JERUSALEM_ID, "jerozolima")
	assert_almost_eq(VictoryManager.JUDAISM_FACTION_UNITY_TENSION_MAX, 30.0, 0.001)
	assert_eq(VictoryManager.ZOROASTRIANISM_PROVINCES_REQUIRED, 3)
	assert_eq(VictoryManager.ZOROASTRIANISM_PERSEPOLIS_ID, "persepolis")
	assert_eq(VictoryManager.ISLAM_PROVINCES_REQUIRED, 5)
	assert_eq(VictoryManager.ISLAM_MEKKA_ID, "mekka")
	assert_eq(VictoryManager.ISLAM_JERUSALEM_ID, "jerozolima")
	assert_eq(VictoryManager.EAST_CHRISTIANITY_VASSALS_REQUIRED, 3)
	assert_almost_eq(VictoryManager.MANICHAEISM_AXIS_C_REQUIRED, 90.0, 0.001)
	assert_eq(VictoryManager.MANICHAEISM_DISTINCT_SOURCES_REQUIRED, 4)

func test_victory_manager_instantiable():
	var vm := VictoryManager.new()
	assert_not_null(vm)
```

- [ ] **Step 2: Uruchom — powinien failować**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_constants.gd -gexit
```

Expected: "Could not find type VictoryManager".

- [ ] **Step 3: Stwórz `scripts/engine/VictoryManager.gd`**

```gdscript
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
	# Spec §6: główny entry point. Pełna pipeline w Task 13.
	pass

func update_flags(state: Node) -> void:
	pass

func update_counters(state: Node) -> void:
	pass

func evaluate_universal_victory(religion: Religion, state: Node) -> String:
	return ""

func evaluate_unique_victory(religion: Religion, state: Node) -> String:
	return ""

func evaluate_defeat(religion: Religion, state: Node) -> String:
	return ""

func compute_ranking(state: Node, exclude_defeated: bool = true) -> Array:
	return []
```

- [ ] **Step 4: Regeneruj cache i uruchom test**

```bash
godot --headless --path . --quit
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_constants.gd -gexit
```

Expected: 3/3 pass.

- [ ] **Step 5: Cała suite — brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/VictoryManager.gd scripts/engine/VictoryManager.gd.uid tests/engine/test_victory_manager_constants.gd tests/engine/test_victory_manager_constants.gd.uid
git commit -m "feat(engine): VictoryManager szkielet + stale uniwersalne i unikalne"
```

---

### Task 8: VictoryManager.update_flags — ever_owned_province + ragnarok_triggered

**Cel:** `update_flags(state)` iteruje wszystkie religie z `defeated_at_turn == -1` i ustawia trwałe flagi:
- `ever_owned_province = true` gdy ma ≥1 prowincję.
- `ragnarok_triggered = true` dla `germanic_paganism` gdy utraciła >50% snapshot.

**Files:**
- Modify: `scripts/engine/VictoryManager.gd`
- Create: `tests/engine/test_victory_manager_flags.gd`

- [ ] **Step 1: Napisz failing testy**

Stwórz `tests/engine/test_victory_manager_flags.gd`:

```gdscript
extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func _grant_province_to(state: Node, religion_id: String, province_id: String) -> void:
	state.province_graph.get_province(province_id).owner = religion_id

func test_update_flags_sets_ever_owned_for_religion_acquiring_first_province():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("manichaeism")
	assert_false(rel.ever_owned_province, "manicheizm startuje bez prowincji")
	_grant_province_to(gs, "manichaeism", "mezopotamia")
	var vm := VictoryManager.new()
	vm.update_flags(gs)
	assert_true(rel.ever_owned_province, "po zdobyciu prowincji flaga ustawiona")

func test_update_flags_keeps_ever_owned_true_after_losing_provinces():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	assert_true(rel.ever_owned_province, "islam startuje z prowincjami")
	# Utrata wszystkich prowincji
	for p in gs.province_graph.provinces_with_owner("islam"):
		p.owner = ""
	var vm := VictoryManager.new()
	vm.update_flags(gs)
	assert_true(rel.ever_owned_province, "flaga jest trwała — nie resetuje się")

func test_update_flags_does_not_touch_defeated_religion():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("manichaeism")
	rel.defeated_at_turn = 50  # już pokonana
	_grant_province_to(gs, "manichaeism", "mezopotamia")
	var vm := VictoryManager.new()
	vm.update_flags(gs)
	# Defeated religion nie podlega update — flaga pozostaje false
	assert_false(rel.ever_owned_province)

func test_update_flags_sets_ragnarok_for_germanic_after_losing_more_than_half_snapshot():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("germanic_paganism")
	# Symulujemy posiadanie 4 prowincji startowych
	rel.starting_provinces_snapshot = ["p1", "p2", "p3", "p4"]
	rel.ever_owned_province = true
	# Dodajemy te prowincje do grafu, owner = germanic_paganism
	for pid in rel.starting_provinces_snapshot:
		var p := Province.new()
		p.id = pid
		p.owner = "germanic_paganism"
		gs.province_graph.add_province(p)
	# Religia utraciła 3 z 4 (75%) — owner zmieniony
	gs.province_graph.get_province("p1").owner = "other"
	gs.province_graph.get_province("p2").owner = "other"
	gs.province_graph.get_province("p3").owner = "other"
	assert_false(rel.ragnarok_triggered)
	var vm := VictoryManager.new()
	vm.update_flags(gs)
	assert_true(rel.ragnarok_triggered, "germanic_paganism utracił >50% snapshot → flag set")

func test_update_flags_does_not_set_ragnarok_when_snapshot_empty():
	# Na mapie historycznej germanic_paganism nie ma startowych prowincji
	var gs := _make_state()
	var rel: Religion = gs.get_religion("germanic_paganism")
	assert_eq(rel.starting_provinces_snapshot.size(), 0)
	var vm := VictoryManager.new()
	vm.update_flags(gs)
	assert_false(rel.ragnarok_triggered, "pusty snapshot → nigdy nie trigger")

func test_update_flags_ragnarok_only_applies_to_germanic_paganism():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	# Symulacja utraty wszystkich startowych prowincji
	for pid in rel.starting_provinces_snapshot:
		gs.province_graph.get_province(pid).owner = "other"
	var vm := VictoryManager.new()
	vm.update_flags(gs)
	assert_false(rel.ragnarok_triggered, "ragnarok_triggered nie dotyczy religii innych niż germanic_paganism")

func test_update_flags_ragnarok_persists_after_recovery():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("germanic_paganism")
	rel.starting_provinces_snapshot = ["p1", "p2"]
	rel.ever_owned_province = true
	for pid in rel.starting_provinces_snapshot:
		var p := Province.new()
		p.id = pid
		p.owner = "germanic_paganism"
		gs.province_graph.add_province(p)
	gs.province_graph.get_province("p1").owner = "other"  # 1/2 lost = 50%
	var vm := VictoryManager.new()
	vm.update_flags(gs)
	assert_true(rel.ragnarok_triggered)
	# Religia odzyskuje prowincję
	gs.province_graph.get_province("p1").owner = "germanic_paganism"
	vm.update_flags(gs)
	assert_true(rel.ragnarok_triggered, "raz ustawiona flaga nie resetuje się")
```

- [ ] **Step 2: Uruchom testy — powinny failować**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_flags.gd -gexit
```

Expected: 7 testów failuje (update_flags jest no-op).

- [ ] **Step 3: Zaimplementuj `update_flags` w `scripts/engine/VictoryManager.gd`**

Zamień pustą funkcję na:

```gdscript
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
```

- [ ] **Step 4: Uruchom testy — pass**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_flags.gd -gexit
```

Expected: 7/7 pass.

- [ ] **Step 5: Cała suite — brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/VictoryManager.gd tests/engine/test_victory_manager_flags.gd
git commit -m "feat(victory): update_flags — ever_owned_province + ragnarok_triggered"
```

---

### Task 9: VictoryManager.update_counters — victory_progress + defeat_progress

**Cel:** Per-religia liczniki "przez N tur": `victory_progress[id] = {domination_turns, prestige_hegemony_turns}`, `defeat_progress[id] = {zero_provinces_turns, vassalage_turns}`. **Reset przy chwilowej utracie warunku** (spec §7). Iteruje religie z `defeated_at_turn == -1`.

**Files:**
- Modify: `scripts/engine/VictoryManager.gd`
- Modify: `tests/engine/test_victory_manager_flags.gd` (lub osobny — wybór dewelopera)

- [ ] **Step 1: Napisz failing testy** — dodaj do `test_victory_manager_flags.gd`:

```gdscript
func test_update_counters_increments_domination_when_above_threshold():
	var gs := _make_state()
	# Daj islamowi >=50% prowincji (6/12). Sprawdź ile islam już ma.
	var current := gs.province_graph.provinces_with_owner("islam").size()
	var needed: int = int(ceil(VictoryManager.DOMINATION_PROVINCE_SHARE * gs.province_graph.all_provinces().size())) - current
	var available := []
	for p in gs.province_graph.all_provinces():
		if p.owner != "islam":
			available.append(p)
	for i in range(needed):
		available[i].owner = "islam"
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("islam", {})
	assert_eq(prog.get("domination_turns", 0), 1)
	vm.update_counters(gs)
	prog = gs.victory_progress.get("islam", {})
	assert_eq(prog.get("domination_turns", 0), 2)

func test_update_counters_resets_domination_on_drop_below_threshold():
	var gs := _make_state()
	# Symulacja: licznik już > 0
	gs.victory_progress["islam"] = {"domination_turns": 5, "prestige_hegemony_turns": 0}
	# Islam startowo nie ma 50% prowincji → po update licznik dominacji powinien wrócić do 0
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("islam", {})
	assert_eq(prog.get("domination_turns", 0), 0, "spadek poniżej progu → reset")

func test_update_counters_increments_prestige_hegemony_when_2x_second():
	var gs := _make_state()
	# Ustaw islam prestige = 1000, wszyscy inni < 500
	for r in gs.all_religions():
		r.prestige = 100 if r.id != "islam" else 1000
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("islam", {})
	assert_eq(prog.get("prestige_hegemony_turns", 0), 1)

func test_update_counters_resets_prestige_hegemony_when_below_ratio():
	var gs := _make_state()
	# Wszyscy mają taki sam prestiż — żadna religia nie ma 2× drugiej
	for r in gs.all_religions():
		r.prestige = 100
	gs.victory_progress["islam"] = {"domination_turns": 0, "prestige_hegemony_turns": 5}
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.victory_progress.get("islam", {})
	assert_eq(prog.get("prestige_hegemony_turns", 0), 0)

func test_update_counters_increments_zero_provinces_when_religion_has_no_provinces():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.ever_owned_province = true
	for p in gs.province_graph.provinces_with_owner("islam"):
		p.owner = ""
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.defeat_progress.get("islam", {})
	assert_eq(prog.get("zero_provinces_turns", 0), 1)

func test_update_counters_resets_zero_provinces_on_reconquest():
	var gs := _make_state()
	gs.defeat_progress["islam"] = {"zero_provinces_turns": 4, "vassalage_turns": 0}
	# Islam wciąż ma prowincje
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.defeat_progress.get("islam", {})
	assert_eq(prog.get("zero_provinces_turns", 0), 0, "ma prowincje → reset")

func test_update_counters_increments_vassalage_when_suzerain_set():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.suzerain_id = "western_christianity"
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.defeat_progress.get("islam", {})
	assert_eq(prog.get("vassalage_turns", 0), 1)

func test_update_counters_resets_vassalage_on_independence():
	var gs := _make_state()
	gs.defeat_progress["islam"] = {"zero_provinces_turns": 0, "vassalage_turns": 15}
	var rel: Religion = gs.get_religion("islam")
	rel.suzerain_id = ""  # niezależna
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	var prog: Dictionary = gs.defeat_progress.get("islam", {})
	assert_eq(prog.get("vassalage_turns", 0), 0)

func test_update_counters_does_not_touch_defeated_religion():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("manichaeism")
	rel.defeated_at_turn = 50
	rel.suzerain_id = "islam"
	var vm := VictoryManager.new()
	vm.update_counters(gs)
	# Pokonana religia nie podlega aktualizacji liczników
	assert_false(gs.defeat_progress.has("manichaeism"))
```

- [ ] **Step 2: Uruchom — failuje**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_flags.gd -gexit
```

Expected: 9 nowych testów failuje (update_counters no-op).

- [ ] **Step 3: Zaimplementuj `update_counters`**

Zamień pustą funkcję w `scripts/engine/VictoryManager.gd`:

```gdscript
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
```

- [ ] **Step 4: Uruchom — pass**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_flags.gd -gexit
```

Expected: wszystkie testy pass.

- [ ] **Step 5: Cała suite — brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/VictoryManager.gd tests/engine/test_victory_manager_flags.gd
git commit -m "feat(victory): update_counters — victory_progress + defeat_progress (reset on miss)"
```

---

### Task 10: VictoryManager.evaluate_universal_victory — 3 warunki uniwersalne

**Cel:** `evaluate_universal_victory(religion, state) -> String` zwraca `"domination"` / `"prestige_hegemony"` / `"holy_land"` jeśli religia spełnia warunek, lub `""` jeśli żaden. Sprawdzane liczniki + dodatkowe warunki Holy Land.

**Files:**
- Modify: `scripts/engine/VictoryManager.gd`
- Create: `tests/engine/test_victory_manager_universal.gd`

- [ ] **Step 1: Napisz failing testy**

Stwórz `tests/engine/test_victory_manager_universal.gd`:

```gdscript
extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func _set_counter(state: Node, rid: String, key: String, value: int) -> void:
	if not state.victory_progress.has(rid):
		state.victory_progress[rid] = {"domination_turns": 0, "prestige_hegemony_turns": 0}
	state.victory_progress[rid][key] = value

func test_domination_returns_reason_when_counter_meets_threshold():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	_set_counter(gs, "islam", "domination_turns", VictoryManager.DOMINATION_TURNS_REQUIRED)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_universal_victory(rel, gs), "domination")

func test_domination_returns_empty_one_below_threshold():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	_set_counter(gs, "islam", "domination_turns", VictoryManager.DOMINATION_TURNS_REQUIRED - 1)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_universal_victory(rel, gs), "")

func test_prestige_hegemony_returns_reason_when_counter_meets_threshold():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	_set_counter(gs, "islam", "prestige_hegemony_turns", VictoryManager.PRESTIGE_HEGEMONY_TURNS_REQUIRED)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_universal_victory(rel, gs), "prestige_hegemony")

func test_holy_land_returns_reason_when_all_own_holy_sites_plus_one_foreign():
	# Western Christianity ma own holy_sites: ["rzym", "jerozolima"] (fixture).
	# Startowo zachód kontroluje rzym; jerozolima jest eastern's; konstantynopol jest is_holy_site eastern's.
	# Aby spełnić warunek: kontrola obu własnych (rzym + jerozolima) + 1 cudzy is_holy_site (konstantynopol).
	var gs := _make_state()
	var rel: Religion = gs.get_religion("western_christianity")
	gs.province_graph.get_province("jerozolima").owner = "western_christianity"		# własne (z eastern's posiadania)
	gs.province_graph.get_province("konstantynopol").owner = "western_christianity"	# cudze is_holy_site (NIE na liście zachodu)
	assert_eq(gs.province_graph.get_province("rzym").owner, "western_christianity",
		"sanity: rzym jest startowo zachodu")
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_universal_victory(rel, gs), "holy_land")

func test_holy_land_blocked_when_no_own_holy_sites():
	# Manicheizm ma puste holy_sites — warunek niedostępny mimo zdobycia cudzego
	var gs := _make_state()
	var rel: Religion = gs.get_religion("manichaeism")
	assert_eq(rel.holy_sites.size(), 0)
	gs.province_graph.get_province("jerozolima").owner = "manichaeism"
	var vm := VictoryManager.new()
	assert_ne(vm.evaluate_universal_victory(rel, gs), "holy_land")

func test_holy_land_blocked_when_own_holy_site_lost():
	# Zachód straci rzym (jego własne) — mimo posiadania cudzego (konstantynopol) i jerozolimy → nie wygrywa
	var gs := _make_state()
	var rel: Religion = gs.get_religion("western_christianity")
	gs.province_graph.get_province("rzym").owner = "islam"							# utrata własnego
	gs.province_graph.get_province("jerozolima").owner = "western_christianity"		# drugie własne kontrolowane
	gs.province_graph.get_province("konstantynopol").owner = "western_christianity"	# cudze is_holy_site
	var vm := VictoryManager.new()
	assert_ne(vm.evaluate_universal_victory(rel, gs), "holy_land")

func test_holy_land_blocked_without_foreign_holy_site():
	# Zachód kontroluje wszystkie własne (rzym + jerozolima), ale żadnego cudzego is_holy_site
	var gs := _make_state()
	var rel: Religion = gs.get_religion("western_christianity")
	gs.province_graph.get_province("jerozolima").owner = "western_christianity"
	# konstantynopol pozostaje eastern's; brak cudzego is_holy_site pod zachodu kontrolą
	var vm := VictoryManager.new()
	assert_ne(vm.evaluate_universal_victory(rel, gs), "holy_land")

func test_universal_victory_returns_empty_when_nothing_met():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_universal_victory(rel, gs), "")
```

- [ ] **Step 2: Uruchom — failuje**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_universal.gd -gexit
```

Expected: 8 testów failuje (funkcja zwraca pusty string).

- [ ] **Step 3: Zaimplementuj `evaluate_universal_victory`**

```gdscript
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
```

- [ ] **Step 4: Uruchom — pass**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_universal.gd -gexit
```

Expected: 8/8 pass.

- [ ] **Step 5: Cała suite — brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/VictoryManager.gd tests/engine/test_victory_manager_universal.gd
git commit -m "feat(victory): evaluate_universal_victory — dominacja, hegemonia, swieta ziemia"
```

---

### Task 11: VictoryManager.evaluate_unique_victory — 6 unikalnych warunków

**Cel:** `evaluate_unique_victory(religion, state) -> String` zwraca jeden z: `"manichaeism_illumination"`, `"judaism_return"`, `"zoroastrianism_renaissance"`, `"east_christianity_pentarchy"`, `"islam_caliphate"`, `"germanic_ragnarok"` lub `""`. Każda religia ma najwyżej jeden unikalny warunek.

**Files:**
- Modify: `scripts/engine/VictoryManager.gd`
- Create: `tests/engine/test_victory_manager_unique.gd`

- [ ] **Step 1: Napisz failing testy**

Stwórz `tests/engine/test_victory_manager_unique.gd`:

```gdscript
extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state(player_id: String = "islam") -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize(player_id, religions, graph)
	return gs

func _grant(state: Node, religion_id: String, province_ids: Array) -> void:
	for pid: String in province_ids:
		state.province_graph.get_province(pid).owner = religion_id

# === Manicheizm ===

func test_manichaeism_illumination_requires_C_90_and_4_distinct_sources():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("manichaeism")
	rel.axes["C"] = 90.0
	rel.absorbed_idea_sources = ["islam", "judaism", "zoroastrianism", "buddhism"]
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "manichaeism_illumination")

func test_manichaeism_illumination_blocked_with_3_sources():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("manichaeism")
	rel.axes["C"] = 95.0
	rel.absorbed_idea_sources = ["islam", "judaism", "zoroastrianism"]
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

func test_manichaeism_illumination_blocked_with_C_89():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("manichaeism")
	rel.axes["C"] = 89.0
	rel.absorbed_idea_sources = ["islam", "judaism", "zoroastrianism", "buddhism", "hinduism"]
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

func test_manichaeism_can_win_with_zero_provinces():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("manichaeism")
	rel.axes["C"] = 90.0
	rel.absorbed_idea_sources = ["islam", "judaism", "zoroastrianism", "buddhism"]
	# Manicheizm w fixture nie ma prowincji (ever_owned_province == false)
	assert_false(rel.ever_owned_province)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "manichaeism_illumination")

# === Judaizm ===

func test_judaism_return_requires_jerusalem_4_provinces_and_unity():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("judaism")
	_grant(gs, "judaism", ["jerozolima", "lewant", "egipt", "anatolia"])
	# Wszystkie 3 frakcje tension < 30
	for f: Faction in rel.factions:
		f.tension = 10.0
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "judaism_return")

func test_judaism_return_blocked_when_one_faction_tension_above_30():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("judaism")
	_grant(gs, "judaism", ["jerozolima", "lewant", "egipt", "anatolia"])
	for f: Faction in rel.factions:
		f.tension = 10.0
	rel.factions[0].tension = 31.0
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

func test_judaism_return_blocked_without_jerusalem():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("judaism")
	# 4 prowincje, bez jerozolimy
	_grant(gs, "judaism", ["lewant", "egipt", "anatolia", "arabia_polnocna"])
	for f: Faction in rel.factions:
		f.tension = 10.0
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

func test_judaism_return_blocked_with_3_provinces():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("judaism")
	_grant(gs, "judaism", ["jerozolima", "lewant", "egipt"])
	for f: Faction in rel.factions:
		f.tension = 10.0
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

# === Zoroastryzm ===

func test_zoroastrianism_renaissance_requires_persepolis_and_3_provinces():
	# Zoroastryzm startowo ma persję + persepolis (2 prowincje) — dodajmy trzecią (mezopotamia)
	var gs := _make_state()
	var rel: Religion = gs.get_religion("zoroastrianism")
	gs.province_graph.get_province("mezopotamia").owner = "zoroastrianism"
	assert_eq(gs.province_graph.provinces_with_owner("zoroastrianism").size(), 3)
	assert_eq(gs.province_graph.get_province("persepolis").owner, "zoroastrianism")
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "zoroastrianism_renaissance")

func test_zoroastrianism_renaissance_blocked_without_persepolis():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("zoroastrianism")
	gs.province_graph.get_province("mezopotamia").owner = "zoroastrianism"
	gs.province_graph.get_province("persepolis").owner = "islam"  # utrata persepolis
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

func test_zoroastrianism_renaissance_blocked_with_only_2_provinces():
	# Startowo zoroastryzm ma 2 prowincje (persja + persepolis) — to dokładnie poniżej progu 3.
	# Test weryfikuje że stan startowy nie spełnia warunku.
	var gs := _make_state()
	var rel: Religion = gs.get_religion("zoroastrianism")
	assert_eq(gs.province_graph.provinces_with_owner("zoroastrianism").size(), 2,
		"sanity: zoroastryzm startuje z 2 prowincjami (mapa historyczna)")
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

# === Chrześcijaństwo Wschodnie ===

func test_east_christianity_pentarchy_requires_3_simultaneous_vassals():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("eastern_christianity")
	gs.get_religion("coptic_christianity").suzerain_id = "eastern_christianity"
	gs.get_religion("judaism").suzerain_id = "eastern_christianity"
	gs.get_religion("zoroastrianism").suzerain_id = "eastern_christianity"
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "east_christianity_pentarchy")

func test_east_christianity_pentarchy_blocked_with_2_vassals():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("eastern_christianity")
	gs.get_religion("coptic_christianity").suzerain_id = "eastern_christianity"
	gs.get_religion("judaism").suzerain_id = "eastern_christianity"
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

# === Islam ===

func test_islam_caliphate_requires_mekka_jerusalem_and_5_provinces():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	_grant(gs, "islam", ["mekka", "jerozolima", "lewant", "egipt", "anatolia"])
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "islam_caliphate")

func test_islam_caliphate_blocked_without_mekka():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	# Daj jerozolimę + 5 innych ale nie mekka
	_grant(gs, "islam", ["jerozolima", "lewant", "egipt", "anatolia", "armenia", "konstantynopol"])
	gs.province_graph.get_province("mekka").owner = "arabian_paganism"
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

func test_islam_caliphate_blocked_with_4_provinces():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	_grant(gs, "islam", ["mekka", "jerozolima", "lewant", "egipt"])
	# 4 prowincje (mekka + 3 inne), poniżej progu 5
	for p in gs.province_graph.all_provinces():
		if p.owner == "islam" and not ["mekka", "jerozolima", "lewant", "egipt"].has(p.id):
			p.owner = "other"
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

# === Germanic Ragnarök ===

func test_germanic_ragnarok_victory_requires_flag_and_100_percent_starting_recovered():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("germanic_paganism")
	rel.starting_provinces_snapshot = ["p1", "p2"]
	rel.ragnarok_triggered = true
	for pid: String in rel.starting_provinces_snapshot:
		var p := Province.new()
		p.id = pid
		p.owner = "germanic_paganism"
		gs.province_graph.add_province(p)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "germanic_ragnarok")

func test_germanic_ragnarok_blocked_if_flag_not_set():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("germanic_paganism")
	rel.starting_provinces_snapshot = ["p1", "p2"]
	rel.ragnarok_triggered = false
	for pid: String in rel.starting_provinces_snapshot:
		var p := Province.new()
		p.id = pid
		p.owner = "germanic_paganism"
		gs.province_graph.add_province(p)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

func test_germanic_ragnarok_blocked_if_not_all_starting_recovered():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("germanic_paganism")
	rel.starting_provinces_snapshot = ["p1", "p2"]
	rel.ragnarok_triggered = true
	for pid: String in rel.starting_provinces_snapshot:
		var p := Province.new()
		p.id = pid
		p.owner = "germanic_paganism"
		gs.province_graph.add_province(p)
	gs.province_graph.get_province("p2").owner = "other"  # tylko p1 odzyskane
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

func test_germanic_ragnarok_unreachable_with_empty_snapshot():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("germanic_paganism")
	assert_eq(rel.starting_provinces_snapshot.size(), 0)
	rel.ragnarok_triggered = true  # nawet z fałszywie ustawioną flagą
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")

# === No unique victory dla innych religii ===

func test_no_unique_victory_for_western_christianity():
	# ChrZ nie ma unikalnego warunku w Plan 12 (in-scope to ChrW)
	var gs := _make_state()
	var rel: Religion = gs.get_religion("western_christianity")
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_unique_victory(rel, gs), "")
```

- [ ] **Step 2: Uruchom — failuje**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_unique.gd -gexit
```

Expected: wszystkie pozytywne testy failują.

- [ ] **Step 3: Zaimplementuj `evaluate_unique_victory`**

Zamień pustą funkcję w `scripts/engine/VictoryManager.gd`:

```gdscript
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
```

- [ ] **Step 4: Uruchom — pass**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_unique.gd -gexit
```

Expected: wszystkie testy pass.

- [ ] **Step 5: Cała suite — brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/VictoryManager.gd tests/engine/test_victory_manager_unique.gd
git commit -m "feat(victory): evaluate_unique_victory — 6 unikalnych warunkow per religia"
```

---

### Task 12: VictoryManager.evaluate_defeat — D1 + D2

**Cel:** `evaluate_defeat(religion, state) -> String` zwraca `"elimination"` lub `"long_vassalage"` (lub `""`). Każdy warunek ma prerequisite `ever_owned_province == true`.

**Files:**
- Modify: `scripts/engine/VictoryManager.gd`
- Create: `tests/engine/test_victory_manager_defeat.gd`

- [ ] **Step 1: Napisz failing testy**

Stwórz `tests/engine/test_victory_manager_defeat.gd`:

```gdscript
extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func _set_defeat_counter(state: Node, rid: String, key: String, value: int) -> void:
	if not state.defeat_progress.has(rid):
		state.defeat_progress[rid] = {"zero_provinces_turns": 0, "vassalage_turns": 0}
	state.defeat_progress[rid][key] = value

func test_elimination_returns_reason_when_5_turns_zero_provinces_and_ever_owned():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.ever_owned_province = true
	_set_defeat_counter(gs, "islam", "zero_provinces_turns", VictoryManager.ELIMINATION_TURNS_REQUIRED)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_defeat(rel, gs), "elimination")

func test_elimination_blocked_without_ever_owned_province():
	# Manicheizm nigdy nie miał prowincji → mimo licznika 100 nie jest eliminated
	var gs := _make_state()
	var rel: Religion = gs.get_religion("manichaeism")
	assert_false(rel.ever_owned_province)
	_set_defeat_counter(gs, "manichaeism", "zero_provinces_turns", 100)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_defeat(rel, gs), "")

func test_elimination_blocked_one_below_threshold():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.ever_owned_province = true
	_set_defeat_counter(gs, "islam", "zero_provinces_turns", VictoryManager.ELIMINATION_TURNS_REQUIRED - 1)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_defeat(rel, gs), "")

func test_long_vassalage_returns_reason_when_20_turns_with_suzerain_and_ever_owned():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.ever_owned_province = true
	_set_defeat_counter(gs, "islam", "vassalage_turns", VictoryManager.VASSAL_DEFEAT_TURNS_REQUIRED)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_defeat(rel, gs), "long_vassalage")

func test_long_vassalage_blocked_without_ever_owned():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("manichaeism")
	assert_false(rel.ever_owned_province)
	_set_defeat_counter(gs, "manichaeism", "vassalage_turns", 50)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_defeat(rel, gs), "")

func test_long_vassalage_blocked_one_below_threshold():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.ever_owned_province = true
	_set_defeat_counter(gs, "islam", "vassalage_turns", VictoryManager.VASSAL_DEFEAT_TURNS_REQUIRED - 1)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_defeat(rel, gs), "")

func test_no_defeat_when_neither_condition_met():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.ever_owned_province = true
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_defeat(rel, gs), "")

func test_elimination_takes_precedence_over_vassalage_when_both_met():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.ever_owned_province = true
	_set_defeat_counter(gs, "islam", "zero_provinces_turns", VictoryManager.ELIMINATION_TURNS_REQUIRED)
	_set_defeat_counter(gs, "islam", "vassalage_turns", VictoryManager.VASSAL_DEFEAT_TURNS_REQUIRED)
	var vm := VictoryManager.new()
	assert_eq(vm.evaluate_defeat(rel, gs), "elimination", "elimination ma pierwszeństwo (tematycznie definitywne)")
```

- [ ] **Step 2: Uruchom — failuje**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_defeat.gd -gexit
```

Expected: 8 testów failuje.

- [ ] **Step 3: Zaimplementuj `evaluate_defeat`**

```gdscript
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
```

- [ ] **Step 4: Uruchom — pass**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_defeat.gd -gexit
```

Expected: 8/8 pass.

- [ ] **Step 5: Cała suite — brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/VictoryManager.gd tests/engine/test_victory_manager_defeat.gd
git commit -m "feat(victory): evaluate_defeat — D1 elimination i D2 long_vassalage z ever_owned prereq"
```

---

## Chunk 4: Orchestration + TurnManager integration

---

### Task 13: VictoryManager.check + compute_ranking — pełna pipeline

**Cel:** `check(state)` orkiestruje update_flags + update_counters + evaluate_unique + evaluate_universal + evaluate_defeat + turn-limit fallback. Schism grace blocking. Ranking sortowany DESC po prestiżu, tie-break po `id` ASC.

**Files:**
- Modify: `scripts/engine/VictoryManager.gd`
- Create: `tests/engine/test_victory_manager_endgame.gd`

- [ ] **Step 1: Napisz failing testy**

Stwórz `tests/engine/test_victory_manager_endgame.gd`:

```gdscript
extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func test_check_sets_outcome_when_universal_victory_met():
	# Używamy western_christianity — nie ma unique-victory w Plan 12, więc domination zadziała.
	var gs := _make_state()
	for p in gs.province_graph.all_provinces():
		if p.owner != "western_christianity":
			p.owner = "western_christianity"
	gs.victory_progress["western_christianity"] = {"domination_turns": VictoryManager.DOMINATION_TURNS_REQUIRED - 1, "prestige_hegemony_turns": 0}
	var vm := VictoryManager.new()
	vm.check(gs)
	assert_not_null(gs.game_outcome)
	assert_eq(gs.game_outcome.winner_id, "western_christianity")
	assert_eq(gs.game_outcome.reason, "domination")

func test_check_does_nothing_when_game_already_over():
	var gs := _make_state()
	var prior := GameOutcome.new()
	prior.winner_id = "judaism"
	prior.reason = "test_prior"
	gs.game_outcome = prior
	var vm := VictoryManager.new()
	vm.check(gs)
	# Outcome nie zmienił się
	assert_eq(gs.game_outcome.winner_id, "judaism")
	assert_eq(gs.game_outcome.reason, "test_prior")

func test_check_unique_victory_takes_precedence_over_universal():
	# Islam ma jednocześnie spełniony unique (Pełen Kalifat) i universal (Hegemonia)
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	for p in gs.province_graph.all_provinces():
		p.owner = "islam"
	rel.prestige = 1000
	for r in gs.all_religions():
		if r.id != "islam":
			r.prestige = 100
	gs.victory_progress["islam"] = {"domination_turns": 99, "prestige_hegemony_turns": 99}
	var vm := VictoryManager.new()
	vm.check(gs)
	assert_eq(gs.game_outcome.reason, "islam_caliphate", "unique ma pierwszeństwo")

func test_check_schism_grace_blocks_victory_for_schism_religion():
	var gs := _make_state()
	# Stwórz schism religię ręcznie
	var schism := Religion.new()
	schism.id = "test_schism"
	schism.parent_religion_id = "islam"
	schism.birth_turn = gs.current_turn
	schism.prestige = 10000
	gs.add_religion(schism)
	gs.victory_progress["test_schism"] = {"domination_turns": 99, "prestige_hegemony_turns": 99}
	var vm := VictoryManager.new()
	vm.check(gs)
	# Schism nie wygrywa (grace), ale ktoś inny też nie — gra trwa
	assert_null(gs.game_outcome)

func test_check_starting_religion_not_affected_by_schism_grace():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	assert_eq(rel.parent_religion_id, "")
	assert_eq(rel.birth_turn, 0)
	# Mimo birth_turn=0, current_turn=1, parent_religion_id="" → grace nie blokuje
	for p in gs.province_graph.all_provinces():
		p.owner = "islam"
	gs.victory_progress["islam"] = {"domination_turns": VictoryManager.DOMINATION_TURNS_REQUIRED, "prestige_hegemony_turns": 0}
	var vm := VictoryManager.new()
	vm.check(gs)
	assert_not_null(gs.game_outcome, "starting religion ma wygrywać natychmiast (no grace)")

func test_check_schism_religion_can_win_after_grace_period():
	var gs := _make_state()
	var schism := Religion.new()
	schism.id = "test_schism"
	schism.parent_religion_id = "islam"
	schism.birth_turn = 0  # narodzona w turze 0
	schism.prestige = 10000
	schism.ever_owned_province = true
	gs.add_religion(schism)
	# Ustaw current_turn na 15 (>10 od narodzin)
	gs.current_turn = 15
	# Daj jej prowincje
	for p in gs.province_graph.all_provinces():
		p.owner = "test_schism"
	gs.victory_progress["test_schism"] = {"domination_turns": VictoryManager.DOMINATION_TURNS_REQUIRED, "prestige_hegemony_turns": 0}
	var vm := VictoryManager.new()
	vm.check(gs)
	assert_not_null(gs.game_outcome)
	assert_eq(gs.game_outcome.winner_id, "test_schism")

func test_check_sets_defeated_at_turn_when_defeat_met():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.ever_owned_province = true
	for p in gs.province_graph.provinces_with_owner("islam"):
		p.owner = ""
	gs.defeat_progress["islam"] = {"zero_provinces_turns": VictoryManager.ELIMINATION_TURNS_REQUIRED - 1, "vassalage_turns": 0}
	gs.current_turn = 50
	var vm := VictoryManager.new()
	vm.check(gs)
	assert_eq(rel.defeated_at_turn, 50)

func test_check_turn_limit_triggers_ranking_winner():
	var gs := _make_state()
	gs.current_turn = VictoryManager.TURN_LIMIT
	# Wyzeruj wszystkie liczniki, ale ustaw różne prestiże
	for r: Religion in gs.all_religions():
		r.prestige = 100
	gs.get_religion("western_christianity").prestige = 1000
	gs.get_religion("islam").prestige = 500
	var vm := VictoryManager.new()
	vm.check(gs)
	assert_not_null(gs.game_outcome)
	assert_eq(gs.game_outcome.winner_id, "western_christianity")
	assert_eq(gs.game_outcome.reason, "turn_limit")

func test_check_turn_limit_tiebreak_alphabetical_by_id():
	var gs := _make_state()
	gs.current_turn = VictoryManager.TURN_LIMIT
	# Wszyscy z tym samym prestiżem
	for r: Religion in gs.all_religions():
		r.prestige = 100
	var vm := VictoryManager.new()
	vm.check(gs)
	# Najmniejszy id alfabetycznie pierwszy. Sprawdź który religion_id jest pierwszy:
	# arabian_paganism < buddhism < coptic_christianity < ... alfabetycznie pierwszy.
	# Z fixture: arabian_paganism, buddhism, coptic_christianity, eastern_christianity,
	# germanic_paganism, hinduism, islam, judaism, manichaeism, slavic_paganism,
	# western_christianity, zoroastrianism
	assert_eq(gs.game_outcome.winner_id, "arabian_paganism")

func test_check_turn_limit_excludes_defeated_from_ranking():
	var gs := _make_state()
	gs.current_turn = VictoryManager.TURN_LIMIT
	for r: Religion in gs.all_religions():
		r.prestige = 100
	# Wyklucz "arabian_paganism" przez defeat
	gs.get_religion("arabian_paganism").defeated_at_turn = 50
	var vm := VictoryManager.new()
	vm.check(gs)
	# Buddhism powinien być teraz pierwszy
	assert_eq(gs.game_outcome.winner_id, "buddhism")

func test_check_sets_end_turn_in_outcome():
	var gs := _make_state()
	gs.current_turn = 42
	for p in gs.province_graph.all_provinces():
		p.owner = "islam"
	gs.victory_progress["islam"] = {"domination_turns": VictoryManager.DOMINATION_TURNS_REQUIRED, "prestige_hegemony_turns": 0}
	var vm := VictoryManager.new()
	vm.check(gs)
	assert_eq(gs.game_outcome.end_turn, 42)

func test_check_includes_ranking_in_outcome():
	var gs := _make_state()
	for p in gs.province_graph.all_provinces():
		p.owner = "islam"
	gs.victory_progress["islam"] = {"domination_turns": VictoryManager.DOMINATION_TURNS_REQUIRED, "prestige_hegemony_turns": 0}
	var vm := VictoryManager.new()
	vm.check(gs)
	assert_gt(gs.game_outcome.ranking.size(), 0)
	# Pierwszy w rankingu to islam (ma najwięcej prestiżu po wygranej + provinces)
	var first_entry: Dictionary = gs.game_outcome.ranking[0]
	assert_true(first_entry.has("religion_id"))
	assert_true(first_entry.has("prestige"))
	assert_true(first_entry.has("provinces"))

func test_compute_ranking_sorts_desc_by_prestige_then_id_asc():
	var gs := _make_state()
	for r: Religion in gs.all_religions():
		r.prestige = 100
	gs.get_religion("zoroastrianism").prestige = 500
	gs.get_religion("islam").prestige = 500
	# Tie-break: islam < zoroastrianism alphabetically, więc islam pierwszy
	var vm := VictoryManager.new()
	var ranking := vm.compute_ranking(gs)
	assert_eq(ranking[0]["religion_id"], "islam")
	assert_eq(ranking[1]["religion_id"], "zoroastrianism")
```

- [ ] **Step 2: Uruchom — failuje**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_endgame.gd -gexit
```

Expected: wszystkie testy failują (check i compute_ranking są no-op).

- [ ] **Step 3: Zaimplementuj `check` i `compute_ranking`**

```gdscript
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
```

- [ ] **Step 4: Uruchom — pass**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_endgame.gd -gexit
```

Expected: wszystkie pass.

- [ ] **Step 5: Cała suite — brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/VictoryManager.gd tests/engine/test_victory_manager_endgame.gd
git commit -m "feat(victory): check() orkiestracja + compute_ranking + turn_limit fallback"
```

---

### Task 14: TurnManager.process_turn invokes VictoryManager.check

**Cel:** Po `state.advance_turn()` w `TurnManager.process_turn` wywołać `VictoryManager.check(state)`.

**Files:**
- Modify: `scripts/engine/TurnManager.gd`
- Create: `tests/engine/test_victory_manager_integration.gd`

- [ ] **Step 1: Napisz failing test integracji**

Stwórz `tests/engine/test_victory_manager_integration.gd`:

```gdscript
extends GutTest

const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func test_turn_manager_invokes_victory_check_after_advance_turn():
	var gs := _make_state()
	# Western_christianity — nie ma unique-victory, więc dominacja terytorialna zadziała.
	for p in gs.province_graph.all_provinces():
		p.owner = "western_christianity"
	# Trzy tury z rzędu z dominacją — po trzeciej powinien wygrać
	var tm := TurnManager.new()
	tm.process_turn(gs)  # domination_turns = 1
	tm.process_turn(gs)  # domination_turns = 2
	tm.process_turn(gs)  # domination_turns = 3 → wygrywa
	assert_not_null(gs.game_outcome)
	assert_eq(gs.game_outcome.winner_id, "western_christianity")
	assert_eq(gs.game_outcome.reason, "domination")

func test_full_pipeline_does_not_crash_when_no_winner():
	var gs := _make_state()
	var tm := TurnManager.new()
	# Kilka tur startowych — żaden warunek nie powinien być spełniony
	for _i in range(5):
		tm.process_turn(gs)
	assert_null(gs.game_outcome)

func test_victory_check_not_invoked_when_game_already_over():
	var gs := _make_state()
	var prior := GameOutcome.new()
	prior.winner_id = "judaism"
	prior.end_turn = 5
	gs.game_outcome = prior
	var tm := TurnManager.new()
	tm.process_turn(gs)
	# Pipeline turn manager przeszedł, ale check nie powinien był nadpisać outcome
	assert_eq(gs.game_outcome.winner_id, "judaism")
	assert_eq(gs.game_outcome.end_turn, 5)
```

- [ ] **Step 2: Uruchom — failuje**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_integration.gd -gexit
```

Expected: `test_turn_manager_invokes_victory_check_after_advance_turn` failuje (`game_outcome == null`).

- [ ] **Step 3: Zmodyfikuj `TurnManager.process_turn` w `scripts/engine/TurnManager.gd`**

Dodaj wywołanie na końcu funkcji:

```gdscript
func process_turn(state: Node) -> void:
	_apply_passive_pressure(state.province_graph)
	_apply_holy_site_prestige(state)
	_update_faction_tensions(state)
	_process_scholar_missions(state)
	_apply_believer_exodus(state)
	_process_active_wars(state)
	_process_missionaries(state)
	_process_diplomacy(state)
	_process_resources(state)
	_process_vassal_revolts(state)
	state.advance_turn()
	# Spec 12 §6: po advance_turn — sprawdzenie zwycięstwa / przegranej / cap turowego
	var vm := VictoryManager.new()
	vm.check(state)
```

- [ ] **Step 4: Uruchom test — pass**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gtest=res://tests/engine/test_victory_manager_integration.gd -gexit
```

Expected: 3/3 pass.

- [ ] **Step 5: Cała suite — brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

**Uwaga:** Jeśli istniejące testy `tests/engine/test_turn_manager.gd` zaczną failować z powodu cap-turowego (np. testy puszczające 200+ tur), to **regresja zamierzona** — VictoryManager teraz zatrzymuje grę. Sprawdź każdy failing test indywidualnie:
- Jeśli test nie zależał od pełnego stanu post-turn → ignoruje game_outcome, ok.
- Jeśli test musi przerwać przed cap → ustaw `gs.current_turn = 1` przed pętlą.
- Jeśli test specjalnie testuje >200 tur → dostosuj założenia testu.

- [ ] **Step 6: Commit**

```bash
git add scripts/engine/TurnManager.gd tests/engine/test_victory_manager_integration.gd
git commit -m "feat(turn): wywoluj VictoryManager.check po advance_turn"
```

---

## Chunk 5: UI — GameOverDialog + MainShell integration

---

### Task 15: GameOverDialog — scena + skrypt

**Cel:** Modal pokazujący wynik gry (wygrana/przegrana/cap), ranking finalny, przyciski "Nowa gra" i "Zamknij". Dwa tryby: "outcome" (gra zakończona) i "player_defeat" (sam gracz przegrał, gra trwa).

**Files:**
- Create: `scripts/ui/dialogs/GameOverDialog.gd`
- Create: `scenes/ui/dialogs/GameOverDialog.tscn`
- Create: `tests/ui/test_game_over_dialog.gd`

- [ ] **Step 1: Napisz failing testy**

Stwórz `tests/ui/test_game_over_dialog.gd`:

```gdscript
extends GutTest

const GameOverDialogScene := preload("res://scenes/ui/dialogs/GameOverDialog.tscn")

func _make_outcome(winner_id: String = "islam", reason: String = "domination") -> GameOutcome:
	var o := GameOutcome.new()
	o.winner_id = winner_id
	o.reason = reason
	o.end_turn = 87
	o.ranking = [
		{"religion_id": "islam", "prestige": 540, "provinces": 6},
		{"religion_id": "western_christianity", "prestige": 510, "provinces": 3},
		{"religion_id": "eastern_christianity", "prestige": 480, "provinces": 2},
	]
	return o

func _instantiate() -> Control:
	var dialog: Control = GameOverDialogScene.instantiate()
	add_child_autofree(dialog)
	return dialog

func test_dialog_shows_winner_display_name_in_outcome_mode():
	var dialog := _instantiate()
	var outcome := _make_outcome("islam", "domination")
	dialog.show_outcome(outcome)
	# Powinien zawierać nazwę religii (display_name z fixture: "☪ Islam") gdzieś w tekście
	var title_text: String = dialog.get_title_text()
	assert_true(title_text.contains("Islam") or title_text.contains("☪"),
		"Tytuł powinien zawierać nazwę zwycięzcy, miał: " + title_text)

func test_dialog_shows_reason_label_in_polish():
	var dialog := _instantiate()
	var outcome := _make_outcome("islam", "domination")
	dialog.show_outcome(outcome)
	assert_true(dialog.get_reason_text().contains("Dominacja"),
		"Powinno być polskie etykieta dla 'domination', miał: " + dialog.get_reason_text())

func test_dialog_maps_all_reasons_to_non_empty_polish_labels():
	var dialog := _instantiate()
	var reasons := ["domination", "prestige_hegemony", "holy_land",
		"manichaeism_illumination", "judaism_return", "zoroastrianism_renaissance",
		"east_christianity_pentarchy", "islam_caliphate", "germanic_ragnarok",
		"turn_limit", "elimination", "long_vassalage"]
	for r: String in reasons:
		var outcome := _make_outcome("islam", r)
		dialog.show_outcome(outcome)
		var text: String = dialog.get_reason_text()
		assert_ne(text, "", "Reason " + r + " powinien mieć etykietę")

func test_dialog_shows_end_turn():
	var dialog := _instantiate()
	var outcome := _make_outcome()
	outcome.end_turn = 87
	dialog.show_outcome(outcome)
	assert_true(dialog.get_turn_text().contains("87"))

func test_dialog_shows_ranking_with_3_entries():
	var dialog := _instantiate()
	var outcome := _make_outcome()
	dialog.show_outcome(outcome)
	assert_eq(dialog.get_ranking_row_count(), 3)

func test_dialog_emits_new_game_pressed():
	var dialog := _instantiate()
	dialog.show_outcome(_make_outcome())
	watch_signals(dialog)
	dialog.press_new_game()  # helper do testowego pressed
	assert_signal_emitted(dialog, "new_game_pressed")

func test_dialog_emits_closed_when_close_pressed():
	var dialog := _instantiate()
	dialog.show_outcome(_make_outcome())
	watch_signals(dialog)
	dialog.press_close()
	assert_signal_emitted(dialog, "closed")

func test_dialog_player_defeat_mode_shows_defeat_message():
	var dialog := _instantiate()
	dialog.show_player_defeat("islam", "elimination")
	var text: String = dialog.get_title_text()
	assert_true(text.contains("Przegrałeś") or text.contains("Pokonany"))

func test_dialog_player_defeat_mode_emits_close_signal():
	var dialog := _instantiate()
	dialog.show_player_defeat("islam", "elimination")
	watch_signals(dialog)
	dialog.press_close()
	assert_signal_emitted(dialog, "closed")
```

- [ ] **Step 2: Stwórz scenę `scenes/ui/dialogs/GameOverDialog.tscn`**

Otwórz Godot editor i utwórz scenę z taką hierarchią (lub stwórz `.tscn` ręcznie):

```
GameOverDialog (Control, root)
├── BackgroundDim (ColorRect, color = Color(0,0,0,0.5), full anchor)
├── PanelContainer (centered, custom_minimum_size = Vector2(640, 480))
│   └── MarginContainer (margin 20)
│       └── VBoxContainer (%MainBox)
│           ├── Label (%TitleLabel) "PLACEHOLDER" 
│           ├── HSeparator
│           ├── Label (%ReasonLabel) "PLACEHOLDER"
│           ├── Label (%TurnLabel) "PLACEHOLDER"
│           ├── HSeparator
│           ├── Label "Ranking końcowy:"
│           ├── VBoxContainer (%RankingList) (puste — dynamiczne)
│           ├── HBoxContainer (%ButtonBox)
│           │   ├── Button (%NewGameButton) "Nowa gra"
│           │   └── Button (%CloseButton) "Zamknij"
```

Wszystkie nazwane węzły mają `unique_name_in_owner = true`. Skrypt root: `res://scripts/ui/dialogs/GameOverDialog.gd`.

Jeśli ręcznie tworzysz `.tscn`, można skopiować schematy z innych modal'i w projekcie (np. jakiekolwiek istniejące dialogi w `scenes/ui/`) i zaadaptować.

- [ ] **Step 3: Stwórz `scripts/ui/dialogs/GameOverDialog.gd`**

```gdscript
class_name GameOverDialog
extends Control

signal new_game_pressed
signal closed

@onready var _title_label: Label = %TitleLabel
@onready var _reason_label: Label = %ReasonLabel
@onready var _turn_label: Label = %TurnLabel
@onready var _ranking_list: VBoxContainer = %RankingList
@onready var _new_game_btn: Button = %NewGameButton
@onready var _close_btn: Button = %CloseButton

# Polskie etykiety dla każdego reason ID. Spec 12 §6 (lista).
const REASON_LABELS: Dictionary = {
	"domination": "Dominacja terytorialna",
	"prestige_hegemony": "Hegemonia prestiżu",
	"holy_land": "Święta Ziemia",
	"manichaeism_illumination": "Synkretyczna Iluminacja (Manicheizm)",
	"judaism_return": "Powrót do Syjonu (Judaizm)",
	"zoroastrianism_renaissance": "Renesans Saszański (Zoroastryzm)",
	"east_christianity_pentarchy": "Pentarchia (Chrześcijaństwo Wschodnie)",
	"islam_caliphate": "Pełen Kalifat (Islam)",
	"germanic_ragnarok": "Ragnarök Triumfalny (Religie Germańskie)",
	"turn_limit": "Koniec ery (limit 200 tur)",
	"elimination": "Eliminacja",
	"long_vassalage": "Długi wasal",
}

var _state: Node = null
var _mode: String = ""	# "outcome" lub "player_defeat"
var _pending_outcome: GameOutcome = null
var _pending_defeat_id: String = ""
var _pending_defeat_reason: String = ""

func _ready() -> void:
	_new_game_btn.pressed.connect(_on_new_game_pressed)
	_close_btn.pressed.connect(_on_close_pressed)
	# Apply pending bind
	if _pending_outcome != null:
		_apply_outcome(_pending_outcome)
	elif _pending_defeat_id != "":
		_apply_player_defeat(_pending_defeat_id, _pending_defeat_reason)

func bind_state(s: Node) -> void:
	_state = s

func show_outcome(outcome: GameOutcome) -> void:
	_mode = "outcome"
	if is_inside_tree():
		_apply_outcome(outcome)
	else:
		_pending_outcome = outcome

func show_player_defeat(religion_id: String, reason: String) -> void:
	_mode = "player_defeat"
	if is_inside_tree():
		_apply_player_defeat(religion_id, reason)
	else:
		_pending_defeat_id = religion_id
		_pending_defeat_reason = reason

func _apply_outcome(outcome: GameOutcome) -> void:
	var winner_name: String = _religion_display_name(outcome.winner_id)
	_title_label.text = "KONIEC GRY — wygrał %s" % winner_name
	_reason_label.text = "Warunek: " + REASON_LABELS.get(outcome.reason, outcome.reason)
	_turn_label.text = "Tura: %d" % outcome.end_turn
	_populate_ranking(outcome.ranking)

func _apply_player_defeat(religion_id: String, reason: String) -> void:
	var name_str: String = _religion_display_name(religion_id)
	_title_label.text = "Przegrałeś — religia %s została pokonana" % name_str
	_reason_label.text = "Powód: " + REASON_LABELS.get(reason, reason)
	_turn_label.text = ""
	_populate_ranking([])

func _religion_display_name(rid: String) -> String:
	if _state != null:
		var r: Religion = _state.get_religion(rid)
		if r != null:
			return r.display_name
	return rid

func _populate_ranking(ranking: Array) -> void:
	for child in _ranking_list.get_children():
		child.queue_free()
	for i in range(ranking.size()):
		var entry: Dictionary = ranking[i]
		var label := Label.new()
		var rid: String = entry["religion_id"]
		var name_str: String = _religion_display_name(rid)
		label.text = "%d. %s — prestiż %d (%d prow.)" % [i + 1, name_str, entry["prestige"], entry["provinces"]]
		_ranking_list.add_child(label)

func _on_new_game_pressed() -> void:
	emit_signal("new_game_pressed")

func _on_close_pressed() -> void:
	emit_signal("closed")

# Test helpers (publiczne by testy mogły czytać)

func get_title_text() -> String:
	return _title_label.text if is_inside_tree() else ""

func get_reason_text() -> String:
	return _reason_label.text if is_inside_tree() else ""

func get_turn_text() -> String:
	return _turn_label.text if is_inside_tree() else ""

func get_ranking_row_count() -> int:
	return _ranking_list.get_child_count() if is_inside_tree() else 0

func press_new_game() -> void:
	_on_new_game_pressed()

func press_close() -> void:
	_on_close_pressed()
```

- [ ] **Step 4: Regeneruj cache i uruchom testy**

```bash
godot --headless --path . --quit
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_game_over_dialog.gd -gexit
```

Expected: wszystkie testy pass.

- [ ] **Step 5: Cała suite — brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/dialogs/ scenes/ui/dialogs/ tests/ui/test_game_over_dialog.gd
git commit -m "feat(ui): GameOverDialog modal (outcome + player_defeat) z ranking"
```

---

### Task 16: Header — set_end_turn_enabled(bool)

**Cel:** Mała pomocnicza metoda na `Header.gd` umożliwiająca MainShell wyłączenie przycisku End Turn po zakończeniu gry.

**Files:**
- Modify: `scripts/ui/Header.gd`
- Create: `tests/ui/test_header_end_turn_toggle.gd`

- [ ] **Step 1: Napisz failing test**

Stwórz `tests/ui/test_header_end_turn_toggle.gd`:

```gdscript
extends GutTest

const HeaderScene := preload("res://scenes/ui/Header.tscn")

func test_set_end_turn_enabled_disables_button():
	var header: Header = HeaderScene.instantiate()
	add_child_autofree(header)
	header.set_end_turn_enabled(false)
	assert_true(header.is_end_turn_disabled())

func test_set_end_turn_enabled_re_enables_button():
	var header: Header = HeaderScene.instantiate()
	add_child_autofree(header)
	header.set_end_turn_enabled(false)
	header.set_end_turn_enabled(true)
	assert_false(header.is_end_turn_disabled())
```

- [ ] **Step 2: Uruchom — failuje** (metody nie istnieją)

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_header_end_turn_toggle.gd -gexit
```

- [ ] **Step 3: Dodaj metody do `scripts/ui/Header.gd`**

Dopisz na końcu pliku (lub razem z metodami publicznymi):

```gdscript
func set_end_turn_enabled(enabled: bool) -> void:
	if is_inside_tree():
		_end_turn_btn.disabled = not enabled

func is_end_turn_disabled() -> bool:
	return _end_turn_btn.disabled if is_inside_tree() else false
```

- [ ] **Step 4: Test pass**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_header_end_turn_toggle.gd -gexit
```

- [ ] **Step 5: Cała suite — brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/Header.gd tests/ui/test_header_end_turn_toggle.gd
git commit -m "feat(header): set_end_turn_enabled() do blokowania koncoworozgrywkowo"
```

---

### Task 17: MainShell — detekcja outcome + integracja GameOverDialog

**Cel:** `MainShell` wykrywa `state.game_outcome != null` (gra zakończona) lub player defeat. Instancjonuje `GameOverDialog`, pokazuje raz, dezaktywuje End Turn button przy outcome. "Nowa gra" → `state.reset()` + `change_scene_to_file("res://scenes/Main.tscn")`.

**Files:**
- Modify: `scripts/ui/MainShell.gd`
- Create: `tests/ui/test_main_shell_game_over.gd`

- [ ] **Step 1: Napisz failing testy**

Stwórz `tests/ui/test_main_shell_game_over.gd`:

```gdscript
extends GutTest

const MainShellScene := preload("res://scenes/ui/MainShell.tscn")
const GameStateScript := preload("res://scripts/engine/GameState.gd")

func _make_state() -> Node:
	var gs: Node = GameStateScript.new()
	var religions := ReligionLoader.load_from_file("res://data/religions_historical.json")
	var graph := ProvinceLoader.load_graph_from_file("res://data/provinces_historical.json")
	gs.initialize("islam", religions, graph)
	return gs

func _instantiate_with_state(state: Node) -> MainShell:
	var shell: MainShell = MainShellScene.instantiate()
	add_child_autofree(shell)
	shell.bind_state(state)
	return shell

func test_main_shell_does_not_show_dialog_when_no_outcome():
	var gs := _make_state()
	var shell := _instantiate_with_state(gs)
	shell.refresh()
	assert_eq(shell.get_active_game_over_dialog_count(), 0)

func test_main_shell_shows_dialog_when_game_outcome_set():
	var gs := _make_state()
	var outcome := GameOutcome.new()
	outcome.winner_id = "islam"
	outcome.reason = "domination"
	outcome.end_turn = 42
	gs.game_outcome = outcome
	var shell := _instantiate_with_state(gs)
	shell.refresh()
	assert_eq(shell.get_active_game_over_dialog_count(), 1)

func test_main_shell_shows_dialog_only_once_on_repeated_refresh():
	var gs := _make_state()
	var outcome := GameOutcome.new()
	outcome.winner_id = "islam"
	outcome.reason = "domination"
	gs.game_outcome = outcome
	var shell := _instantiate_with_state(gs)
	shell.refresh()
	shell.refresh()
	shell.refresh()
	assert_eq(shell.get_active_game_over_dialog_count(), 1)

func test_main_shell_disables_end_turn_button_when_game_over():
	var gs := _make_state()
	var outcome := GameOutcome.new()
	outcome.winner_id = "islam"
	outcome.reason = "domination"
	gs.game_outcome = outcome
	var shell := _instantiate_with_state(gs)
	shell.refresh()
	# Header dostępne przez shell
	assert_true(shell.is_end_turn_disabled())

func test_main_shell_keeps_end_turn_enabled_after_player_defeat():
	# Gracz przegrał, ale nikt nie wygrał — gra trwa, gracz może obserwować swoją religię
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.defeated_at_turn = 30
	var shell := _instantiate_with_state(gs)
	shell.refresh()
	assert_false(shell.is_end_turn_disabled())

func test_main_shell_shows_defeat_dialog_when_player_defeated():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.defeated_at_turn = 30
	var shell := _instantiate_with_state(gs)
	shell.refresh()
	assert_eq(shell.get_active_game_over_dialog_count(), 1)

func test_main_shell_shows_player_defeat_dialog_only_once():
	var gs := _make_state()
	var rel: Religion = gs.get_religion("islam")
	rel.defeated_at_turn = 30
	var shell := _instantiate_with_state(gs)
	shell.refresh()
	shell.refresh()
	assert_eq(shell.get_active_game_over_dialog_count(), 1)
```

- [ ] **Step 2: Uruchom — failuje** (brak detekcji + helpera)

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_main_shell_game_over.gd -gexit
```

- [ ] **Step 3: Zmodyfikuj `scripts/ui/MainShell.gd`**

Dodaj imports (na górze, po istniejących):

```gdscript
const GameOverDialogScene := preload("res://scenes/ui/dialogs/GameOverDialog.tscn")
```

Dodaj pola:

```gdscript
var _shown_outcome_modal: bool = false
var _shown_defeat_modal: bool = false
var _active_dialog: GameOverDialog = null
```

Zmodyfikuj `refresh()`:

```gdscript
func refresh() -> void:
	_header.refresh()
	_tab_bar.refresh()
	if _map_tab.has_method("refresh"):
		_map_tab.refresh()
	_faith_tab.refresh()
	_factions_tab.refresh()
	if _world_tab.has_method("refresh"):
		_world_tab.refresh()
	_refresh_game_over_state()

func _refresh_game_over_state() -> void:
	if state == null:
		return
	# 1) Sprawdź game_outcome (wygrana / cap turowy)
	if state.game_outcome != null and not _shown_outcome_modal:
		_shown_outcome_modal = true
		_show_outcome_dialog(state.game_outcome)
		_header.set_end_turn_enabled(false)
		return
	# 2) Sprawdź czy gracz przegrał (defeat_at_turn != -1)
	if not _shown_defeat_modal:
		var player: Religion = state.get_player_religion()
		if player != null and player.defeated_at_turn != -1:
			_shown_defeat_modal = true
			_show_player_defeat_dialog(player)

func _show_outcome_dialog(outcome: GameOutcome) -> void:
	_active_dialog = GameOverDialogScene.instantiate()
	add_child(_active_dialog)
	_active_dialog.bind_state(state)
	_active_dialog.show_outcome(outcome)
	_active_dialog.new_game_pressed.connect(_on_new_game_pressed)
	_active_dialog.closed.connect(_on_dialog_closed)

func _show_player_defeat_dialog(player: Religion) -> void:
	_active_dialog = GameOverDialogScene.instantiate()
	add_child(_active_dialog)
	_active_dialog.bind_state(state)
	# Powód deduktujemy z stanu: 0 prowincji = elimination, suzerain_id != "" = long_vassalage
	var reason := "elimination"
	if player.suzerain_id != "":
		reason = "long_vassalage"
	_active_dialog.show_player_defeat(player.id, reason)
	_active_dialog.new_game_pressed.connect(_on_new_game_pressed)
	_active_dialog.closed.connect(_on_dialog_closed)

func _on_new_game_pressed() -> void:
	if state != null and state.has_method("reset"):
		state.reset()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_dialog_closed() -> void:
	if _active_dialog != null:
		_active_dialog.queue_free()
		_active_dialog = null

# Test helpers

func get_active_game_over_dialog_count() -> int:
	var count: int = 0
	for child in get_children():
		if child is GameOverDialog:
			count += 1
	return count

func is_end_turn_disabled() -> bool:
	return _header.is_end_turn_disabled()
```

- [ ] **Step 4: Uruchom test — pass**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_main_shell_game_over.gd -gexit
```

Expected: 7/7 pass.

- [ ] **Step 5: Cała suite — brak regresji**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

**Uwaga:** Jeśli istniejące testy `tests/ui/test_main_shell.gd` zaczną failować bo dodaliśmy nowe pole `state == null` guard — to zamierzone. Sprawdź czy `_refresh_game_over_state` poprawnie pomija sytuacje gdy state nie ma `game_outcome`/`get_player_religion`. Jeśli starsze testy nie bindują state — `_refresh_game_over_state` zwraca wcześnie.

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/MainShell.gd tests/ui/test_main_shell_game_over.gd
git commit -m "feat(ui): MainShell detekcja game_outcome + player_defeat + GameOverDialog"
```

---

## Chunk 6: Cleanup

---

### Task 18: CLAUDE.md update

**Cel:** Dopisać `VictoryManager` do listy managerów engine oraz `GameOverDialog` do UI architecture. Plan 12 ukończony.

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Zaktualizuj `CLAUDE.md`**

Sekcja "Stateless Manager pattern" (linia ~40): dopisz `VictoryManager` do listy managerów.

Z:
```
**stateless Manager classes** (`TurnManager`, `WarManager`, `DiplomacyManager`, `DoctrineManager`, `SchismManager`)
```

Na:
```
**stateless Manager classes** (`TurnManager`, `WarManager`, `DiplomacyManager`, `DoctrineManager`, `SchismManager`, `VictoryManager`)
```

Sekcja "TurnManager.process_turn" — dopisz na końcu pipeline-u:

Z:
```
passive pressure → ... → vassal revolts → `state.advance_turn()`
```

Na:
```
passive pressure → ... → vassal revolts → `state.advance_turn()` → VictoryManager.check
```

Sekcja "UI architecture" — dopisz w punkcie o `MainShell`:

Po linii o `FactionsTab`:
```
- **End-of-game flow:** `MainShell` instancjonuje `GameOverDialog` (scripts/ui/dialogs/) gdy `state.game_outcome != null` (gra wygrana) lub gracz dostał `defeated_at_turn != -1` (Plan 12). Przycisk End Turn dezaktywuje się przy game_outcome.
```

- [ ] **Step 2: Cała suite — sanity**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

Expected: All tests passed.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: zaktualizuj CLAUDE.md po wdrozeniu Plan 12 (VictoryManager + GameOverDialog)"
```

---

## Podsumowanie zakresu i kolejności

| Chunk | Tasks | Pliki engine | Pliki UI | Pliki testów |
|-------|-------|--------------|----------|--------------|
| 1: Foundation | 1–4 | Religion + GameOutcome + GameState | — | test_religion + test_game_outcome + test_game_state |
| 2: Hooks | 5–6 | SchismManager + DoctrineManager | — | test_schism_manager_birth_turn + test_doctrine_manager_idea_sources |
| 3: VictoryManager core | 7–12 | VictoryManager (stałe → flags → counters → universal → unique → defeat) | — | test_victory_manager_constants + _flags + _universal + _unique + _defeat |
| 4: Orchestration | 13–14 | VictoryManager.check + TurnManager invoke | — | test_victory_manager_endgame + _integration |
| 5: UI | 15–17 | — | GameOverDialog + Header + MainShell | test_game_over_dialog + test_header_end_turn_toggle + test_main_shell_game_over |
| 6: Cleanup | 18 | — | — | CLAUDE.md |

**Łącznie: 18 tasków, ~70 nowych testów (60–80 zakładane w spec §9), bez modyfikacji JSON-ów ani fixture'ów.**

**Edge cases świadomie obsłużone w spec → testach:**

- Manicheizm (0 prowincji startowych) — może wygrać przez unique-victory, nie podlega D1/D2 (`ever_owned_province == false`).
- Religie eurazjatyckie (hinduism/buddhism/germanic/slavic) — na mapie historycznej nie podlegają warunkom kosmetycznym (warunki wymagają geograficznych prerequisitów).
- Schism grace — chroni nowe religie tylko `parent_religion_id != ""`; religie startowe (birth_turn=0, parent_religion_id="") są wolne od grace.
- Holy Land prereq — Manicheizm z pustym holy_sites nie spełnia (vacuous truth zablokowane).
- Ragnarök — flag set raz w VictoryManager.update_flags, nie resetuje się.
- Liczniki "przez N tur" — reset przy chwilowej utracie warunku (DOMINATION_TURNS_REQUIRED=3 wymusza skonsolidowaną dominację).
- Turn limit fallback — wygrywa najwyższy prestiż, tie-break po `id` ASC, pomija pokonane religie.
- GameState.reset() — wymienia każde pole eksplicitnie (test_reset_clears_* per pole zabezpiecza przed cichym dryfem).

---

## Otwarte dla wykonawcy

- **Plik `.uid`**: po każdym `class_name` skrypcie Godot wygeneruje `.uid` sidecar. Może wymagać oddzielnego commitu `chore: regenerate .uid sidecars` jeśli automatyczna regeneracja przez `godot --quit` nie obejmuje wszystkich plików.
- **Edytorska scena `GameOverDialog.tscn`**: jeśli ręczne tworzenie `.tscn` jest niepraktyczne, otwórz Godot editor i zbuduj scenę interaktywnie wg layoutu w Task 15. Test-driven approach pozwala iteracyjnie weryfikować.
- **MainShell.tscn**: nie jest modyfikowany — `GameOverDialog` jest instancjonowany dynamicznie jako child MainShell, nie jako ExtResource w scenie.
