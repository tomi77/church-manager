# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**religion-manager** — turn-based strategy game about the evolution of 12 religions in the 7th century. Doctrine axes (Dogmatism/Hierarchy/Syncretism/Transcendence), diplomacy (alliances, councils, interdicts, missionaries, vassalage, coalitions), war (casus belli, crusades/jihads), factions, schisms. Built in **Godot 4.6** with **GDScript 2.0**.

User-facing text, comments, commit messages, and specs are in **Polish**. Code identifiers are English.

## Commands

Test runner (GUT — Godot Unit Testing addon at `addons/gut/`):

```bash
# Full suite (currently 429 tests)
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# Single test file (use res:// absolute path — relative names may not be picked up)
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/ui -gtest=res://tests/ui/test_map_view.gd -gexit

# Subdirectory only
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/engine -gexit
```

No build step — Godot loads from source. Run the editor with `godot --path .` if scenes need re-importing.

### Class cache caveat

Godot resolves `class_name` declarations via `.godot/global_script_class_cache.cfg`, which is gitignored. **After creating a new `class_name` script, headless test runs may fail with "Could not find type X" until the cache is regenerated** — open the project once in the Godot editor (or run `godot --headless --path . --quit`) to refresh it.

## Architecture

### Single source of truth: GameState autoload

`scripts/engine/GameState.gd` is registered as an autoload in `project.godot` (`GameState`). Holds all mutable game data: `current_turn`, `player_religion_id`, `province_graph`, religions dict, `active_wars`, `relations`, `active_coalitions`, `missionary_missions`, `pending_defeat_events`. The UI **only reads** GameState; mutations go through manager classes.

### Stateless Manager pattern

The engine layer is split into **data classes** (resources/data containers — `Religion`, `Province`, `Faction`, `War`, `RelationState`, `Coalition`, `MissionaryMission`, `Idea`, `DefeatEvent`, `ProvinceGraph`) and **stateless Manager classes** (`TurnManager`, `WarManager`, `DiplomacyManager`, `DoctrineManager`, `SchismManager`, `VictoryManager`). Managers extend `RefCounted`, hold no state, and are instantiated per call (`var wm := WarManager.new()`). They take `state: Node` (GameState) as their first parameter and mutate it.

- **`TurnManager.process_turn(state)`** — orchestrates the end-of-turn pipeline in fixed order: passive pressure → holy site prestige → faction tensions → scholar missions → believer exodus → wars → missionaries → diplomacy → resources → vassal revolts → `state.advance_turn()` → VictoryManager.check. Loaders (`ReligionLoader`, `ProvinceLoader`) parse JSON fixtures from `data/` (e.g. `provinces_historical.json` — 12 provinces with hand-authored `position{x,y}` for map rendering).
- **Engine constants are tunable knobs** in each manager (`DiplomacyManager.ALLIANCE_PRESTIGE_COST`, `MISSIONARIES_EXCLUSIVITY_BLOCK`, etc.). Tests and UI **reference these constants directly** rather than hardcoding values — when thresholds shift, the dependent code stays correct.

### UI architecture

- **`MainShell`** (`scripts/ui/MainShell.gd` + `.tscn`) is the root Control. Contains `Header` (player info + End Turn) + `TabBar` + 4 tabs in `ContentArea`: `MapTab` (Plan 09), `FaithTab` (Plan 10), `WorldTab` (diplomacy, Plan 08), `FactionsTab` (Plan 11). Tab IDs are `"map" / "faith" / "world" / "factions"`. Tab visibility flips via `_on_tab_changed`.
- **Cross-tab navigation:** `MapTab` emits `navigate_to_diplomacy(religion_id)` → MainShell switches tab to `"world"` and calls `WorldTab.preselect_religion(id)`.
- **Refresh model:** every component has `bind_state(state)` and `refresh()`. After engine mutations, the chain `state_changed` signal → `MainShell.refresh()` → tab refresh causes a full rerender (no dirty-tracking). MapTab's `ProvinceDetailPanel` additionally refreshes itself on `war_declared` / `missionaries_sent` for immediate feedback.
- **Identifier language:** all code identifiers (class names, file names, variables, signal names, religion/trait/faction/doctrine IDs) are English. Polish appears only in user-facing strings (`Label.text`, `display_name` in JSON), comments, commit messages, and `docs/` specs/plans.
- **End-of-game flow:** `MainShell` instancjonuje `GameOverDialog` (scripts/ui/dialogs/) gdy `state.game_outcome != null` (gra wygrana) lub gracz dostał `defeated_at_turn != -1` (Plan 12). Przycisk End Turn dezaktywuje się przy game_outcome. Plan 13 (`docs/superpowers/specs/13-victory-extensions-design.md`) rozszerza Plan 12 o D3 schizma totalna (3 frakcje w fazie 3 przez 2 tury) i 3 unikalne warunki wygranej: Reformacja Apostolska (Chrześcijaństwo Zachodnie), Dharmiczna Trwałość (Hinduizm), Środkowa Droga Globalna (Buddyzm). Plan 14 (`docs/superpowers/specs/14-coptic-citadel-design.md`) dodaje unikalny warunek "Cytadela Pustelnicza" dla Koptyjskiego Kościoła + 4 nowe prowincje (aleksandria, abisynia, libia, karthago).
- **Map rendering** (`scripts/ui/map/`) uses a node graph: `MapView` is a Control container with two child Control layers (EdgesLayer / NodesLayer, `mouse_filter` IGNORE/PASS). Each `ProvinceNode` is a Polygon2D + Line2D outline + Label + transparent Button "ClickArea" sized 60×40. Edges are `Line2D` between province centroids. **Note:** `ProvinceNode` extends `Control` (not Node2D) so it nests cleanly inside MapView's Control hierarchy — putting Controls inside Node2D breaks input routing.

### Project conventions

- **Indentation: tabs** (normalized 2026-06-07 in commit `1ceecdf`). Godot editor defaults to tabs; mixing with spaces causes editor reformatting churn.
- **`class_name` on every UI script** so scenes can type-hint instances.
- **`unique_name_in_owner = true` + `%Name` resolution** for all named child nodes — never use string paths like `get_node("VBox/Header/Label")`.
- **Setters guard with `is_inside_tree()`** before touching `@onready` vars (e.g. `set_province`, `bind_state`). Cache args and re-apply in `_ready()` if needed (pattern: `RelationListItem.gd`, `PressureRow.gd`).
- **Signals use `emit_signal("name", args)`** (string form) rather than `name.emit(args)` — established convention across all UI files.
- **No `Date.now()` / `Math.random()` in tests** when reproducibility matters — pass timestamps or seeds explicitly. Standard for engine tests in this repo.

### Spec-driven workflow

`docs/superpowers/specs/` holds design specs (numbered 01-09: doctrine, war, diplomacy, map, religion profiles, UI, vassalage, diplomacy-war bridge, diplomacy UI). `docs/superpowers/plans/` holds TDD implementation plans (01-09) that decompose specs into bite-sized tasks. Plans drive the **superpowers:writing-plans** and **superpowers:subagent-driven-development** skills — each task in a plan is a discrete TDD cycle (failing test → minimal impl → verify pass → commit), reviewed by spec-compliance + code-quality subagents before being marked complete.

When implementing a new feature, the workflow is: spec → plan → per-task TDD via subagents. Don't shortcut by writing implementation before tests, and don't pollute commits with multiple tasks.
