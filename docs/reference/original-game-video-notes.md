# Street Trash III: Dezombifier, notes from the reference video

Source: YouTube "Street Trash 3: Dezombifier - Top Down Zombie Shooter (GTA 6 Minigame)" (id q4IzdXGOfOs, 20:17 long).
One still every 10 seconds was extracted (122 frames, kept locally only, not committed) and reviewed on 2026-11-20.
The run shown starts at 18:00, reaches level 17, collects 4/6 gears and ends in GAME OVER when the timer hits 00:00.

## Camera and art direction

- 3D, high camera looking down at roughly 55-65°, perspective, quite far (the survivor is small on screen,
  a city block is visible). The camera follows the player and does not rotate.
- Night. Very dark base lighting with strong local lights: sodium street lamps (orange), teal/green fluorescent
  shop fronts, red/pink neon, burning fires and debris, car headlights and red tail lights, gas station sign
  ("GAS 3.65 / 6.66"), shop signs (Bakery, Coffee, SMSH BRGR, Craft Beer, Vapes, Barber).
- Dense props: wrecked and abandoned cars (some with lights on), dumpsters, barricades and fences, rubble and paper
  litter, telephone/power poles with sagging wires across the screen, bare trees, fire escapes and stoops, an
  elevated rail truss, a fenced basketball court, a parking lot with painted bays, zebra crossings, yellow centre lines.
- Gore: blood pools stay where zombies die and accumulate into large red areas; muzzle flash and a long glowing
  orange tracer per shot.
- A purple smoke vignette creeps in from the screen edges at times (late in the run, low health?).
- Floating map pins above items: green pins, cyan pins, green "+" health markers.

## HUD

- Top left: portrait of the survivor with a red level badge ("LV 0", "LV 12"), next to three bars: green health
  (with heart icon), yellow stamina, long cyan XP bar with "LV.N" at its right end.
- Under the bars, when a streak is running: red "KILL STREAK" label, big streak number, and a small multiplier
  ("7 1.01", "20 1.03", "41 1.06", "50 1.08"), which fits multiplier = 1 + 0.0015 x streak.
- Top centre: countdown "MM:SS" from 18:00.
- Top right: gear (cog) icon with "x/6" under it, and a red-framed panel with the current weapon silhouette
  (pistol; heavy machine gun while that perk is active). A green "+" square sometimes appears left of the cog.
- Contextual prompts at the start: "DAY 1", "KILL ZOMBIES TO GET XP AND UPGRADE YOUR CHARACTER.", "MOVE",
  "TOGGLE SPRINT (DRAINS STAMINA)", "COLLECT 6 GEARS". Floating text "HEALTH FULL" when touching a health pickup at
  full health. Radio subtitles at the bottom centre ("Power is out at the High-Rise.", "Thank you for your continued
  cooperation.", "You're deteriorating fast... better patch yourself up.", "Okay, you're making progress.").
- Run end: full-screen blood splatter with "GAME OVER".

## Level-up and perk cards

- "UNLOCK A PERK" screen with a booster-pack graphic ("NEW PERKS INSIDE", OPEN button), then
  "CHOOSE A PERK": three tall cards dealt face down (Street Trash card back) that flip one by one.
- Card layout: category at the top (COMBAT red, ECONOMY blue, SURVIVAL green, MOBILITY yellow, CHAOS orange), big
  illustration (skull with crossed rifles, bloody hand holding coins, heart on a plate, lightning fist, flaming
  skull), perk name on a banner, then the stat name and "before > after".
- Footer: SELECT (d-pad), CONFIRM (X), REDRAW (3) (triangle), SKIP (circle). When redraws are gone the REDRAW entry
  disappears; a forced single choice shows only CONFIRM.

## Perks seen in the video

| Perk | Category | Card text | Steps seen |
|---|---|---|---|
| Brute Force | Combat | Weapon Damage | 0% > 12.5%, 12% > 25% |
| Trigger Happy | Combat | Rate of Fire | 12% > 25% |
| Fatal Precision | Combat | Critical Damage | 0% > 25%, 50% > 75% |
| Dead Eye | Combat | Critical Chance | 7% > 15% |
| Survival Instinct | Combat | While low Health: Damage dealt | 0% > 12.5% |
| Blood Money | Economy | XP from Kills | 0% > 5%, 5% > 10% |
| Regeneration | Survival | Health Regeneration | 0% > 1%, 2% > 3% |
| Built Different | Survival | Maximum Health | 0% > 25% |
| Fortified | Survival | While Stationary: Damage Resistance | 0% > 50% |
| Cardio Training | Mobility | Maximum Stamina | 0% > 25% |
| Leg Day | Mobility | Movement Speed | 0% > 10% |
| Heavy Machine Gun | Chaos | Equip a Heavy Machine Gun for 30 seconds | - |
| Wild Card | Chaos | Receive a perk at random | - |

Known from text guides only: Auto Shotgun (Chaos, 30 s), Micro SMG, Vampire (Duality), Gear (Loadout),
Health Gains (Survival, possibly the same as Built Different).

## Open questions

- What the green "+" square next to the gear counter is (a carried medkit?).
- What the cyan and green map pins mark.
- Whether the purple vignette is low health or a hazard zone.
