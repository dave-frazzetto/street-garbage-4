---
type: Product Requirements Document
title: Slice 1 core run
description: 'One level, one survivor, a full run: shoot zombies, level up with 20 perk cards, collect 6 gears, extract before the nuke.'
tags: [slice-1]
generated:
  by: arkouda/0.8.0
  at: 2026-11-20T15:32:16Z
status: stable
lifecycle: approved
owner: [claude]
decisions:
  - godot-4-7-with-typed-gdscript
  - feature-folder-module-layout
  - perk-effects-as-composable-resources
  - node-free-rules-layer
  - level-authored-as-scene-of-prefab-instances
  - placeholder-art-drawn-in-code
---

# Slice 1 core run

## Status

Approved

## Problem

We are recreating Street Trash III: Dezombifier, the top-down zombie shooter inside GTA VI, in Godot. The first
playable slice must show the whole core loop on one map with one character, so the owner can play a complete run.

What we know about the original (sources: nerdschalk.com perk and first-part guides, gta6map.net, IGN GTA 6 wiki,
thegameswiki.com, readdork.com, howtovideogame.com):

- Top-down twin-stick shooter. Left stick moves, right stick aims and shoots. L3 toggles sprint, which drains stamina.
- The run starts on "DAY 54" outside a garage. Objective text: "Kill zombies to get XP and upgrade your character",
  then "Collect 6 gears". Gears are floating blue cog icons at random spots (alleys, courtyards). The HUD shows a cog
  tally (x/6) in the top right.
- A countdown of about 18 minutes runs at the top. At zero the city is nuked and the run is lost.
- With 6 gears, reach the High-Rise in the quarantine zone to extract and win.
- Kills give XP. Each level-up pauses the game and deals 3 perk cards. You can redraw (3 per run) or skip.
- You start with a pistol. Some cards give a temporary Micro SMG, Auto Shotgun (30 s) or Heavy Machine Gun.
- Standard zombies, plus armoured zombies later in the run. A big horde gathers around a crashed helicopter on a
  basketball court. Health pickups drop.
- Known perks: Auto Shotgun (Chaos), Trigger Happy (Combat, rate of fire +12.5%), Blood Money (Economy, XP from kills
  +5%), Health Gains (Survival, max health), Vampire (Duality, heal on hit, no health pickups), Gear (Loadout, instant
  gear), health regeneration. A kill streak is tracked (there is a "666 kill streak" challenge).

## Approach

One hand-authored city level with code-drawn placeholder art. Perks are data (`.tres`). The owner also asked for
rare perks that change mechanics, so perks have a COMMON or RARE rarity.

## Requirements

- R1 Title screen, then a run on the Freedom City map with one survivor.
- R2 Controls: WASD or left stick to move; mouse or right stick to aim; hold left mouse button or right trigger (or
  push the right stick) to shoot; Shift or L3 toggles sprint, which drains stamina and turns off when stamina is empty.
- R2a The game must be fully playable on PC with both input schemes, with no setting to change: a gamepad (twin
  stick: left stick moves, right stick aims and fires, d-pad and face buttons drive the menus) and mouse plus keyboard.
  The last device used decides the aim source (mouse cursor or right stick). All menus (title, perk cards, end
  screen) work with either scheme.
- R2b (Nice to have) Mobile: the game is exported for HTML5 and playable in a mobile browser from itch.io, in landscape.
  Two touch sticks appear on touch screens: the left half of the screen moves, the right half aims and fires
  (fire while the right stick is pushed past a dead zone). The sprint toggle and the perk cards are tappable.
  Touch controls are hidden on devices without a touch screen.
- R3 Countdown from 18:00 (tunable). At 0 the run ends with "nuked".
- R4 Six gears spawn at 6 of the authored gear spawn points, chosen at random. A HUD tally and an off-screen arrow
  point to the nearest gear. With all gears, the arrow points to the High-Rise.
- R5 Entering the High-Rise with all gears wins. Without them, a message shows how many are missing.
- R6 Walker zombies from the start, armoured zombies after a tunable time, and spawn pressure that rises over time.
  A horde waits at the helicopter crash on the basketball court.
- R7 Zombies damage on contact. Player death ends the run. Taking damage resets the kill streak.
- R8 Kills give XP; the XP curve is tunable. Each level-up pauses and shows 3 distinct cards (category, name, rarity,
  "stat: before → after"). Select with arrows/A-D/d-pad or the mouse, confirm with Enter/A, redraw with R/Y (3 per
  run), skip with Esc/B. Several pending level-ups are shown one after another.
- R9 Health pickups drop from zombies (tunable chance) unless Vampire is active.
- R10 Twenty perks. Original perks are marked (O); the others are designed in the same style.

  | Perk | Category | Rarity | Effect |
  |---|---|---|---|
  | Auto Shotgun (O) | Chaos | Common | Automatic shotgun for 30 s |
  | Micro SMG (O) | Chaos | Common | Micro SMG for 30 s |
  | Heavy Machine Gun (O) | Chaos | Common | Heavy machine gun for 20 s |
  | Trigger Happy (O) | Combat | Common | Rate of fire +12.5% |
  | Hollow Points | Combat | Common | Damage +15% |
  | Long Barrel | Combat | Common | Bullet range +20% |
  | Blood Money (O) | Economy | Common | XP from kills +5% |
  | Scavenger | Economy | Common | Health drop chance +5 points |
  | Magnet | Economy | Common | Pickup radius +50% |
  | Health Gains (O) | Survival | Common | Max health +20 |
  | Regeneration (O) | Survival | Common | Regenerate 0.5 health/s |
  | Thick Skin | Survival | Common | Damage taken −10% |
  | Fleet Foot | Survival | Common | Move speed +10% |
  | Gear (O) | Loadout | Common | Gain a gear now (only while gears are missing) |
  | Vampire (O) | Duality | Rare | Heal 25% of damage dealt; no health pickups |
  | Glass Cannon | Duality | Rare | Damage +40%, max health −30% |
  | Double Sprint | Duality | Rare | Sprint speed bonus doubled, sprint drains stamina 50% faster |
  | Ricochet Rounds | Weapon Mod | Rare | Bullets bounce to another zombie after a hit (+1 bounce) |
  | Explosive Rounds | Weapon Mod | Rare | Hits explode for 50% damage in a radius |
  | Twin Barrel | Weapon Mod | Rare | Permanently +1 projectile on every weapon |

- R11 HUD: health, stamina, XP bar and level, countdown, gear tally, kill streak, active temporary weapon and its time.
- R12 End screen with outcome (extracted, killed, nuked), time, kills, best streak and level. Enter restarts.

## Non-Goals

- Multiple levels, characters, 666 Mode, "Trusting the Process", Code and Obsidian cards, challenges and saves.
- Real art, audio, animation.
- Pathfinding around buildings (zombies chase in a straight line and slide along walls).

## Success Metrics

- Headless unit and smoke tests pass, each in under 30 seconds.
- A test drives the player with simulated keyboard/mouse events and with simulated joypad axis events and both move
  and shoot.
- (Nice to have) An HTML5 export loads in a browser and the touch sticks move and shoot.
- A windowed screenshot shows the player, zombies, buildings, HUD and a perk hand.
- The owner can play a full run from the title screen to extraction or death.

## Open Questions

- Exact original perk numbers beyond the three seen on screen, and the full original perk list.
- Whether the original has a dodge roll in addition to sprint.
