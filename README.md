# Street Garbage 4

A Godot 4.7 recreation of **Street Trash III: Dezombifier**, the top-down zombie roguelike shooter inside GTA VI,
in 3D with a high-angle isometric camera over a night-time city. Art and audio are placeholders (primitive meshes,
synthesised retro sound effects); the focus is gameplay. Notes on the original, taken from a reference video, are in
[docs/reference/original-game-video-notes.md](docs/reference/original-game-video-notes.md).

## Play

Open the project in Godot 4.7.2 and press F5 (main scene `res://core/game_flow.tscn`), or run:

```sh
Godot_v4.7.2-stable_win64.exe --path .
```

**Goal:** find the 6 blue gears scattered through the alleys of Freedom City, then reach the High-Rise in the
quarantine zone (top right) before the 18:00 countdown ends and the city is nuked. Kill zombies for XP; each level
deals 3 perk cards (redraw 3 times per run, or skip). The arrow next to you points to the nearest gear, then to the
High-Rise. Cars and burning barrels can be shot until they explode: the blast hurts zombies and you, and can
set off nearby props.

| Action | Keyboard + mouse | Gamepad | Touch (mobile browser) |
|---|---|---|---|
| Move | WASD / arrows | Left stick | Drag on the left half |
| Aim | Mouse | Right stick | Drag on the right half |
| Shoot | Hold left mouse button | Push right stick (or hold RT) | Push the right stick past half |
| Sprint while held (drains stamina) | Hold Shift | Hold LB or L3 | None: touch play walks only |
| Perk: select / confirm | Left/Right, A/D or mouse / Enter or click | D-pad or stick / A | Tap a card |
| Perk: redraw / skip | R / Esc or X | Y / B | Tap REDRAW / SKIP |
| Start / restart | Enter or Space | A or Start | Tap the button |

## Sound

Every gameplay event has a placeholder sound effect, synthesised by `scripts/sfx/generate_sfx.py` (sfxr-style, Python
standard library only, deterministic) into `audio/sfx/*.wav`:

```sh
python scripts/sfx/generate_sfx.py                    # re-render every effect
python scripts/sfx/generate_sfx.py --only shot_pistol # re-render one
python scripts/sfx/generate_music.py                  # re-render the background loop (audio/music/)
```

Designers tune sound in the Inspector: each event is an `SfxCue` in `audio/cues/` (clips, volume, pitch variance, minimum
interval), the non-weapon events are slots on `audio/sfx_bank_default.tres`, and each gun's shot is `fire_sound` on its
`data/weapons/*.tres`. To change a sound, edit the preset in the generator or drop in your own WAV and point the cue at it.

## Web build (itch.io)

```sh
scripts/build_web.sh            # exports build/web/ and build/street-garbage-web_YYYYMMDD-HHMMSS.zip (single-threaded)
node scripts/serve_web.js       # serves build/web on http://localhost:8060/ (phones on the LAN: use the PC's IP)
node scripts/web_smoke.js       # headless Chrome: loads the build, taps START, drives both touch sticks
```

Upload `build/street-garbage-web_YYYYMMDD-HHMMSS.zip` to itch.io as an HTML project ("This file will be played in the browser").
Leave "SharedArrayBuffer support" off, turn on "Mobile friendly" with landscape orientation, and add a fullscreen button.
The page shell is `web/shell.html` (set as the custom HTML shell in the Web preset). It pins the canvas to the dynamic viewport so no black band is left under it, and adds an in-page Fullscreen button (Android/desktop; iPhone Safari has no Fullscreen API, so it shows "Add to Home Screen" instructions, and the page is iOS standalone-capable).

## Tests

```sh
tests/run_tests.sh   # headless: rules, input, touch, game flow, destructibles, audio, models, difficulty, tuning, zombie pressure; about 1 minute
Godot_v4.7.2-stable_win64_console.exe --path . res://tests/screenshots.tscn   # windowed: saves PNGs to tests/output/
```

## Layout

| Folder | Contents |
|---|---|
| `core/` | `game_flow.tscn`: main scene; owns the run rules and wires world and UI |
| `audio/` | Sound: `SfxCue` and `SfxBank` resources, `SfxPlayer` and `MusicPlayer` scenes, `cues/` (.tres), `sfx/` and `music/` (generated .wav) |
| `rules/` | Node-free rules: `RunState`, `PlayerStats`, `PerkDeck`, `PopulationGrid` |
| `data/` | Resource scripts and `.tres` content: perks (`data/perks/pool/`), weapons, enemies, run/player/director config |
| `world/` | 3D world: camera rig, player (and components), zombies, bullets, pickups, props (buildings, cars, lamps, neon, destructibles), spawners, the Freedom City level |
| `ui/` | HUD, perk cards, title and end screens, touch sticks |
| `tests/` | Headless tests and the screenshot scene |
| `scripts/` | Web build, local web server, browser smoke test |
| `docs/` | ADRs (`docs/adr/`) and PRDs (`docs/prd/`), managed with arkouda |

Designers add or rebalance perks by editing `.tres` files in `data/perks/pool/` and listing them in
`data/perks/perk_pool_default.tres`; run length, gears, redraws, XP curve and rarity weights are in
`data/config/run_default.tres`; the main balance numbers (speeds, zombie health, amounts, bosses, XP per kill) are in `data/config/game_tuning.tres`,
explained in [docs/reference/tuning-guide.md](docs/reference/tuning-guide.md); zombie types and spawn weights are in
`data/config/director_default.tres` and `data/enemies/`.

## Decision history

| # | Date | ADR | Decision |
|---|---|---|---|
| 1 | 2026-11-20 | [godot-4-7-with-typed-gdscript](docs/adr/godot-4-7-with-typed-gdscript.md) | Godot 4.7 with typed GDScript |
| 2 | 2026-11-20 | [feature-folder-module-layout](docs/adr/feature-folder-module-layout.md) | Feature folder module layout |
| 3 | 2026-11-20 | [perk-effects-as-composable-resources](docs/adr/perk-effects-as-composable-resources.md) | Perk effects as composable resources |
| 4 | 2026-11-20 | [node-free-rules-layer](docs/adr/node-free-rules-layer.md) | Node-free rules layer |
| 5 | 2026-11-20 | [level-authored-as-scene-of-prefab-instances](docs/adr/level-authored-as-scene-of-prefab-instances.md) | Level authored as scene of prefab instances (superseded by 10) |
| 6 | 2026-11-20 | [placeholder-art-drawn-in-code](docs/adr/placeholder-art-drawn-in-code.md) | Placeholder art drawn in code (superseded by 10) |
| 7 | 2026-11-20 | [pull-requests-through-github-rest-api](docs/adr/pull-requests-through-github-rest-api.md) | Pull requests through GitHub REST API |
| 8 | 2026-11-20 | [unified-player-input-component](docs/adr/unified-player-input-component.md) | Unified player input component |
| 9 | 2026-11-20 | [single-threaded-web-export-for-itch-io](docs/adr/single-threaded-web-export-for-itch-io.md) | Single-threaded web export for itch.io |
| 10 | 2026-11-20 | [isometric-3d-world](docs/adr/isometric-3d-world.md) | Isometric 3D world (supersedes 5 and 6) |
| 11 | 2026-11-20 | [generated-3d-art-with-meshy](docs/adr/generated-3d-art-with-meshy.md) | Generated 3D art with Meshy |
| 12 | 2026-11-20 | [procedural-sound-effects-with-sfxr-style-generator](docs/adr/procedural-sound-effects-with-sfxr-style-generator.md) | Procedural sound effects with sfxr-style generator |
| 13 | 2026-11-20 | [looping-background-music-from-the-same-synth](docs/adr/looping-background-music-from-the-same-synth.md) | Looping background music from the same synth |
| 14 | 2026-11-20 | [mobile-graphics-profile-and-on-screen-errors](docs/adr/mobile-graphics-profile-and-on-screen-errors.md) | Mobile graphics profile and on-screen errors |
| 15 | 2026-11-21 | [cyberpunk-world-and-female-protagonist](docs/adr/cyberpunk-world-and-female-protagonist.md) | Cyberpunk world and female protagonist |
| 16 | 2026-11-21 | [one-git-worktree-per-claude-session](docs/adr/one-git-worktree-per-claude-session.md) | One git worktree per Claude session |
| 17 | 2026-11-21 | [bullet-hits-go-through-a-zombie-hurtbox-layer](docs/adr/bullet-hits-go-through-a-zombie-hurtbox-layer.md) | Bullet hits go through a zombie hurtbox layer |
| 18 | 2026-11-21 | [beam-bullets-drawn-as-fading-stretched-boxes](docs/adr/beam-bullets-drawn-as-fading-stretched-boxes.md) | Beam bullets drawn as fading stretched boxes |
| 19 | 2026-11-21 | [difficulty-ramp-and-bosses-as-data-in-directorconfig](docs/adr/difficulty-ramp-and-bosses-as-data-in-directorconfig.md) | Difficulty ramp and bosses as data in DirectorConfig |
| 20 | 2026-11-21 | [lazy-horde-activation-and-far-zombie-despawn](docs/adr/lazy-horde-activation-and-far-zombie-despawn.md) | Lazy horde activation and far zombie despawn |
| 21 | 2026-11-21 | [procedural-street-ground-fences-and-skyline-backdrop](docs/adr/procedural-street-ground-fences-and-skyline-backdrop.md) | Procedural street ground, fences and skyline backdrop |
| 22 | 2026-11-21 | [cpuparticles3d-effects-with-capped-effect-spawner](docs/adr/cpuparticles3d-effects-with-capped-effect-spawner.md) | CPUParticles3D effects with capped effect spawner |
| 23 | 2026-11-21 | [real-cc0-audio-samples-with-synthesised-layers](docs/adr/real-cc0-audio-samples-with-synthesised-layers.md) | Real CC0 audio samples with synthesised layers (refines 12) |
| 24 | 2026-11-21 | [survival-style-combat-rooted-shooting-hitscan-line-tougher-zombies](docs/adr/survival-style-combat-rooted-shooting-hitscan-line-tougher-zombies.md) | Survival-style combat: rooted shooting, hitscan line, tougher zombies |
| 25 | 2026-11-22 | [custom-web-page-shell-with-fullscreen-button-for-mobile](docs/adr/custom-web-page-shell-with-fullscreen-button-for-mobile.md) | Custom web page shell with fullscreen button for mobile |
| 26 | 2026-11-22 | [central-gametuning-resource-for-the-main-balance-knobs](docs/adr/central-gametuning-resource-for-the-main-balance-knobs.md) | Central GameTuning resource for the main balance knobs (refines 19 and 24) |
| 27 | 2026-11-22 | [world-anchored-zombie-population](docs/adr/world-anchored-zombie-population.md) | World-anchored zombie population (generalises 20) |
| 28 | 2026-11-22 | [hold-to-sprint-walk-only-on-touch](docs/adr/hold-to-sprint-walk-only-on-touch.md) | Hold to sprint, walk only on touch (refines 8) |
| 29 | 2026-11-22 | [one-character-scale-for-player-and-zombies](docs/adr/one-character-scale-for-player-and-zombies.md) | One character scale for player and zombies |

Product requirements: [slice-1-core-run](docs/prd/slice-1-core-run.md), [slice-2-mobile-touch-and-web-build](docs/prd/slice-2-mobile-touch-and-web-build.md),
[slice-3-isometric-3d-presentation](docs/prd/slice-3-isometric-3d-presentation.md),
[slice-4-sound-effects](docs/prd/slice-4-sound-effects.md).
