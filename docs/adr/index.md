---
okf_version: "0.2"
---

# Architecture Decision Record

## Accepted

* [Beam bullets drawn as fading stretched boxes](beam-bullets-drawn-as-fading-stretched-boxes.md) - Bullets are ray-cast steppers with an unshaded fading beam box and exported impact scenes, cheap for mobile.
* [Bullet hits go through a zombie hurtbox layer](bullet-hits-go-through-a-zombie-hurtbox-layer.md) - Bullets query a separate hurtbox Area3D on physics layer 8 sized from EnemyData.radius plus a forgiveness margin, leaving movement collision untouched.
* [Central GameTuning resource for the main balance knobs](central-gametuning-resource-for-the-main-balance-knobs.md) - One Resource holds the numbers a designer tunes (speeds, zombie health, amounts, mix, bosses, XP per kill); DirectorConfig, EnemyData and PlayerConfig keep per-type shapes and are scaled by it.
* [Custom web page shell with fullscreen button for mobile](custom-web-page-shell-with-fullscreen-button-for-mobile.md) - Use a custom Godot HTML shell that pins the canvas to the dynamic viewport and adds a fullscreen button, so mobile browsers show no black band.
* [Cyberpunk world and female protagonist](cyberpunk-world-and-female-protagonist.md) - Art direction change: a cyberpunk megacity at night, a female cyberpunk punk-rocker protagonist, infected citizens with failing cybernetics, neon accent palette.
* [Difficulty ramp and bosses as data in DirectorConfig](difficulty-ramp-and-bosses-as-data-in-directorconfig.md) - Node-free ramp functions for count, speed and health, plus boss as EnemyData.size_scale 1.2 and spawn-table weights, no boss-specific code.
* [Directional locomotion from angle-smoothed blend spaces](directional-locomotion-from-angle-smoothed-blend-spaces.md) - Player legs mix forward, backward and strafe clips in two 2D blend spaces driven by the movement angle relative to the facing, turned at a capped rate so reversals sweep through a strafe; clips are Meshy library and text-to-motion output with root motion stripped.
* [Feature folder module layout](feature-folder-module-layout.md) - Code lives in core/, data/, rules/, world/, ui/ and tests/ folders; modules talk only through signals wired by core/game_flow.
* [Generated 3D art with Meshy](generated-3d-art-with-meshy.md) - Replace code-built placeholder meshes with GLB models generated through the Meshy CLI, guided by a written art direction and asset manifest.
* [Godot 4.7 with typed GDScript](godot-4-7-with-typed-gdscript.md) - Build the game in Godot 4.7.2 using statically typed GDScript only.
* [GPU particle effects with shader-driven look, desktop first](gpu-particle-effects-with-shader-driven-look.md) - All VFX are GPUParticles3D with three shared spatial shaders (noise puff, velocity streak, ground ring); desktop quality is the target, web keeps working on gl_compatibility.
* [Hero art upgrade and silhouette outlines](hero-art-upgrade-and-silhouette-outlines.md) - Raise triangle budgets and keep 2k textures for hero assets, and add world-space outlines and a colour grade so characters read from the iso camera.
* [Hold to sprint, walk only on touch](hold-to-sprint-walk-only-on-touch.md) - Sprint lasts while the sprint action (Shift, LB, L3) is held and stamina remains; touch play has no sprint control and always walks.
* [Isometric 3D world](isometric-3d-world.md) - The world is real 3D (CharacterBody3D, StaticBody3D, 3D ray casts) seen through an orthographic isometric camera rig; 1 unit = 1 m; buildings fade when they hide the player; placeholder primitive meshes.
* [Lazy horde activation and far zombie despawn](lazy-horde-activation-and-far-zombie-despawn.md) - Hordes are data instantiated only near the player with hysteresis; far ambient zombies are freed and respawned near the player.
* [Looping background music from the same synth](looping-background-music-from-the-same-synth.md) - One 20-second generated loop plays through a MusicPlayer node owned by GameFlow, fading in with the run and out when it ends.
* [Mobile graphics profile and on-screen errors](mobile-graphics-profile-and-on-screen-errors.md) - Mobile browsers get a cheap GraphicsProfile (no shadows, glow or fog, 0.6 render scale, 8 nearest static lights); web builds show engine errors on screen; the title shows LOADING and starts on any tap.
* [Node-free rules layer](node-free-rules-layer.md) - RunState, PlayerStats and PerkDeck are RefCounted classes with no node dependencies, unit-tested headless; scenes only present them.
* [One character scale for player and zombies](one-character-scale-for-player-and-zombies.md) - GameTuning.character_scale (1.15) sizes the player and every zombie with their bodies, hurtboxes and held weapon; models divide ground speed by their scale for foot-planted playback.
* [One git worktree per Claude session](one-git-worktree-per-claude-session.md) - Every Claude session works in its own linked git worktree on its own branch, never in the shared main checkout, so parallel sessions cannot overwrite each other's files, branch or Godot import cache.
* [Perk effects as composable resources](perk-effects-as-composable-resources.md) - A Perk .tres holds a rarity, a category and a list of PerkEffect sub-resources (stat modifier, temporary weapon, grant gear, flag) that apply themselves to the run.
* [Procedural sound effects with sfxr-style generator](procedural-sound-effects-with-sfxr-style-generator.md) - Sound effects are synthesised by a deterministic sfxr-style Python script into WAV files, played through designer-tunable SfxCue resources.
* [Procedural street ground, fences and skyline backdrop](procedural-street-ground-fences-and-skyline-backdrop.md) - World-space ground shader, an instanced Fence prefab and a MultiMesh skyline ring hide the map end without texture files.
* [Pull requests through GitHub REST API](pull-requests-through-github-rest-api.md) - Without gh installed, slice PRs are opened and merged via the GitHub REST API using the Git Credential Manager token.
* [Real CC0 audio samples with synthesised layers](real-cc0-audio-samples-with-synthesised-layers.md) - Gunshots, zombie voices, explosions and footsteps are processed CC0 recordings with synth layers; ambience is synthesised; sources in audio/CREDITS.md.
* [Single-threaded web export for itch.io](single-threaded-web-export-for-itch-io.md) - Export with the Web nothreads template and gl_compatibility so the game runs on itch.io and mobile browsers without SharedArrayBuffer headers.
* [Survival-style combat: rooted shooting, hitscan line, tougher zombies](survival-style-combat-rooted-shooting-hitscan-line-tougher-zombies.md) - Shooting roots the player, bullets are instant lines of light, zombies are fewer but tougher and flinch when hit; phones get a population scale.
* [Unified player input component](unified-player-input-component.md) - A PlayerInput node merges keyboard/mouse, twin-stick gamepad and on-screen touch sticks into move, aim and fire intents; the last used device picks the aim source.
* [World-anchored zombie population](world-anchored-zombie-population.md) - Zombies are planned as data across the whole map from the run seed, wake near the player, sleep when far and respawn slowly; the director only tops up.

## Superseded

* [CPUParticles3D effects with capped effect spawner](cpuparticles3d-effects-with-capped-effect-spawner.md) - All VFX are CPUParticles3D scenes limited per kind by an EffectSpawner; Zombie.damaged signal is the hit-VFX contract.
* [Level authored as scene of prefab instances](level-authored-as-scene-of-prefab-instances.md) - The city is a .tscn of placed Building, GearSpawnPoint, HordeSpawner and ExtractionZone instances, not tilemaps or code layouts.
* [Placeholder art drawn in code](placeholder-art-drawn-in-code.md) - Entities render with _draw() shapes and exported colours, so no binary art assets are committed in slice 1.
