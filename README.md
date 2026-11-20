# Street Garbage 4

A Godot 4.7 recreation of **Street Trash III: Dezombifier**, the top-down zombie roguelike shooter inside GTA VI.
Art and audio are placeholders; the focus is gameplay.

## Play

Open the project in Godot 4.7.2 and press F5 (main scene `res://core/game_flow.tscn`), or run:

```sh
Godot_v4.7.2-stable_win64.exe --path .
```

**Goal:** find the 6 blue gears scattered through the alleys of Freedom City, then reach the High-Rise in the
quarantine zone (top right) before the 18:00 countdown ends and the city is nuked. Kill zombies for XP; each level
deals 3 perk cards (redraw 3 times per run, or skip). The arrow next to you points to the nearest gear, then to the
High-Rise.

| Action | Keyboard + mouse | Gamepad |
|---|---|---|
| Move | WASD / arrows | Left stick |
| Aim | Mouse | Right stick |
| Shoot | Hold left mouse button | Push right stick (or hold RT) |
| Toggle sprint (drains stamina) | Shift | L3 |
| Perk: select / confirm | ←/→, A/D or mouse / Enter or click | D-pad or stick / A |
| Perk: redraw / skip | R / Esc or X | Y / B |
| Start / restart | Enter or Space | A or Start |

## Tests

```sh
tests/run_tests.sh   # headless: rules, player input (keyboard+mouse and gamepad), full game flow; under 10 s total
Godot_v4.7.2-stable_win64_console.exe --path . res://tests/screenshots.tscn   # windowed: saves PNGs to tests/output/
```

## Layout

| Folder | Contents |
|---|---|
| `core/` | `game_flow.tscn`: main scene; owns the run rules and wires world and UI |
| `rules/` | Node-free rules: `RunState`, `PlayerStats`, `PerkDeck` |
| `data/` | Resource scripts and `.tres` content: perks (`data/perks/pool/`), weapons, enemies, run/player/director config |
| `world/` | Player (and components), zombies, bullets, pickups, props, spawners, the Freedom City level |
| `ui/` | HUD, perk cards, title and end screens |
| `tests/` | Headless tests and the screenshot scene |
| `docs/` | ADRs (`docs/adr/`) and PRDs (`docs/prd/`), managed with arkouda |

Designers add or rebalance perks by editing `.tres` files in `data/perks/pool/` and listing them in
`data/perks/perk_pool_default.tres`; run length, gears, redraws, XP curve and rarity weights are in
`data/config/run_default.tres`; zombie pressure is in `data/config/director_default.tres`.

## Decision history

| # | Date | ADR | Decision |
|---|---|---|---|
| 1 | 2026-11-20 | [godot-4-7-with-typed-gdscript](docs/adr/godot-4-7-with-typed-gdscript.md) | Godot 4.7 with typed GDScript |
| 2 | 2026-11-20 | [feature-folder-module-layout](docs/adr/feature-folder-module-layout.md) | Feature folder module layout |
| 3 | 2026-11-20 | [perk-effects-as-composable-resources](docs/adr/perk-effects-as-composable-resources.md) | Perk effects as composable resources |
| 4 | 2026-11-20 | [node-free-rules-layer](docs/adr/node-free-rules-layer.md) | Node-free rules layer |
| 5 | 2026-11-20 | [level-authored-as-scene-of-prefab-instances](docs/adr/level-authored-as-scene-of-prefab-instances.md) | Level authored as scene of prefab instances |
| 6 | 2026-11-20 | [placeholder-art-drawn-in-code](docs/adr/placeholder-art-drawn-in-code.md) | Placeholder art drawn in code |
| 7 | 2026-11-20 | [pull-requests-through-github-rest-api](docs/adr/pull-requests-through-github-rest-api.md) | Pull requests through GitHub REST API |
| 8 | 2026-11-20 | [unified-player-input-component](docs/adr/unified-player-input-component.md) | Unified player input component |

Product requirements: [slice-1-core-run](docs/prd/slice-1-core-run.md).
