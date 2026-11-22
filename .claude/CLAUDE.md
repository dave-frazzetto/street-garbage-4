# Working on a Godot game

General instructions for developing and maintaining a Godot 4 game with several developers over time. Project-specific
facts (goal, paths, process, current gaps) live in `.claude/rules/`.

## Working with Godot from the command line and MCP

- Prefer the Godot MCP server's tools when they are connected (run the project, read debug output, create scenes and nodes).
  The common `@coding-solo/godot-mcp` server drives Godot through the command line, so the editor does not need to be open.
  If its tools are not available in the session, fall back to the Godot executable on the command line.
- On Windows register the server from PowerShell, not Git Bash: Git Bash rewrites `/c` in `cmd /c npx ...` into `C:/` and the
  server then fails with a connection timeout. After changing MCP config, fully restart the session (other open sessions can
  overwrite the config), then check with `claude mcp list`.
- Logic tests run headless: `godot --headless --path . res://path/to/test.tscn`. Anything that depends on rendering
  (visuals, shaders, real input) must run windowed; verify visual changes by saving screenshots from a test scene and
  looking at them, not by assuming.
- After adding or renaming a script with a `class_name`, refresh the class cache (`godot --headless --path . --import`) or
  other scripts will fail with "Identifier not declared".
- A test run that ends early with exit code 0 and no completion line is not a pass. Treat a missing "done" marker as a failure
  until explained.
- Do not leave debug or preview scenes, generated screenshots or editor `.import` sidecars in commits unless they are documentation.

## Architecture for a multi-developer, designer-tunable Godot project

The game must be maintainable by several developers working in parallel (e.g. one on combat, one on the world) and tunable by
a game designer without touching code. Apply these rules to all new work, and when touching existing code move it toward
them. Sources: Godot docs "Scene organization" and "Data preferences" (best practices), Godot custom-Resource and
data-driven design guides, and the "Godot 4 Best Practices" book (data-driven design chapter).

1. **Scenes are the unit of work and of reuse (Godot's "prefabs").** Every game element (player, NPC, enemy, door/warp,
   pickup, shop, level, combat screen, dialogue box, menu) is its own `.tscn` with a root script, in a feature folder.
   Instantiate scenes; do not rebuild them node by node in code. Code-built nodes are only for truly procedural content.
2. **Every scene runs on its own** (F6) with no hard dependency on its parent or siblings. "Call down, signal up": a parent
   configures children (exported properties, injected Resources/Callables), children report upward with signals. No
   `get_node("../..")` and no reaching into another scene's internals. Siblings talk through their common ancestor.
   Tool scripts that need external setup implement `_get_configuration_warnings()` so the editor tells designers what is missing.
3. **Entity-component by composition.** Behaviour lives in small single-responsibility child nodes (mover, interactable,
   dialogue trigger, vision/sight, warp, shop, health) attached to entities, not in one class with `match kind:` branches
   on strings. Prefer composition over deep inheritance. Follow SOLID in script design.
4. **Designer-tunable data is Resources, not code.** Define `class_name Foo extends Resource` with typed `@export` fields
   (`@export_range`, enums, `##` doc comments for tooltips) and save instances as `.tres` (characters, abilities, items,
   enemies, spawn/encounter tables, shop stock, levels). A designer must be able to add or rebalance content in the Inspector
   with zero code changes. Never mutate a shared Resource at runtime: `duplicate()` a runtime copy, or build a runtime object
   from the Resource. Anything a designer might want to change (speeds, probabilities, damage constants, sizes, colours) is an
   `@export` or a Resource field, never a buried literal.
5. **Levels are authored in the editor.** A level is a scene (TileMapLayer + TileSet, or a level Resource) with placed
   instances of entity prefabs whose parameters are exported (dialogue, enemy Resource, facing, sight range, destination
   level and spawn point). Level layouts defined as strings or arrays in code are a stopgap; do not extend that pattern.
6. **Modules with clear ownership and narrow interfaces.** Folders per feature (`world/`, `combat/`, `ui/`, `data/`, `core/`);
   one module never imports another's internals. Modules talk through a small contract of signals (e.g. the world emits
   `combat_requested(foes, context)`; combat emits `combat_finished(result)`); a top-level flow/coordinator scene wires them.
   Each module can be launched and tested alone with fake inputs, so developers rarely touch the same files.
7. **Separate model from view.** Rules and state (grid, collision, combat maths, party/inventory, flags) live in node-free
   `RefCounted`/`Resource` classes that can be unit-tested headless; scenes only present them and forward input. The
   presentation (2D, isometric, 3D) can change without touching the rules.
8. **Autoloads only for genuinely global, scene-independent services** (event bus, settings, save/session state, input map).
   Keep them thin, document each, and put no scene-specific logic or UI in them. Prefer injecting what a scene needs.
   Define input actions in the Input Map (project settings), not at runtime.
9. **Static typing and naming.** Typed GDScript everywhere (typed vars, params, returns, arrays, signals), `class_name` for
   shared types, snake_case files/functions, PascalCase classes/nodes, signals named in the past tense (`item_collected`).
10. **Merge-friendly files.** Text `.tscn`/`.tres`, commit `.uid` files, never commit `.godot/`; keep scenes small and focused
    (split a scene when two people would edit it), keep `project.godot` edits minimal, avoid churn in large binaries.
11. **Tests.** Keep the headless smoke test green; add node-free unit tests for rules; add a per-module test scene
    (e.g. a combat test scene with a canned party) so a module can be verified without playing through the game.
12. **Before adding a feature ask:** which scene owns it, which Resource holds its tunables, which signal is its contract?
    Record non-trivial architectural choices as written decisions, and when a task is a refactor keep behaviour identical.

## Builds

Every build (web zip, exports) is tagged with its build date and time, `YYYYMMDD-HHMMSS`, in the artifact file name,
so builds are easy to tell apart. `scripts/build_web.sh` does this; never overwrite an untagged build artifact.
