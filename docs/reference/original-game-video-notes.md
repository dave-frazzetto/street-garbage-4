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

## Level layout

Read from about 300 frames (2 s contact sheets over 40-238 s, 680-894 s and 980-1108 s, plus full-size stills),
calibrated on the basketball court's 3.6 m centre circle (about 42 px/m at 720p; error about 25%). Times below are
the in-game countdown.

| Element | Original (m) | Original, in heights of the original's 1.8 m hero | Ours (m) | Ours, in our 2.07 m character heights | Seen at |
|---|---|---|---|---|---|
| Main street, curb to curb (2 lanes, parking both sides, double yellow line) | 9-10 | about 5 | 7 | 3.4 | 17:54, 05:51 |
| Sidewalk | 3-4.5 | 2-2.5 | 2 | 1 | 17:42, 05:51 |
| Main street, facade to facade | 16-18 | 9-10 | 11 | 5.3 | |
| Residential street with stoops (stoops take 1.5-2.5 m of sidewalk) | 14-16 | about 8 | 9 (Back Street) | 4.3 | 15:58-15:50, 14:49 |
| Back alley between brick walls | 3.5-4.5 | 2-2.5 | 3.5-4 | 1.7-1.9 | 08:19, 02:10 |
| Service passages and yards | 5-8, yards 12-20 | 3-4 | passage 4, yards and bays 10-20 | 2 | 08:15, 02:52-02:28 |

- **Frontage is continuous.** Shopfronts and walk-ups 6-10 m wide (SMSH BRGR, COFFEE, Bakery, Barber, Vapes, Yoga
  Studio, Craft Beers, Happy Hour) run for the whole 50-80 m block. The only breaks are 3-4 m alleys every 25-40 m and
  fenced lots.
- **Ends are closed but see-through.** The start street is closed by chain-link with red/white and blue barricades and
  the city visible beyond (17:59); lots and corners are closed by chain-link gates (03:16, 15:25); the community centre
  has brick pillars and iron railings (15:40); the court is fully fenced.
- **Clutter narrows the street** to a 4-6 m free lane: parked and wrecked cars (about one per 8-12 m per side, some
  angled into the lanes), dumpsters and rubble on the sidewalks, police barricades, roadworks with Jersey barriers and
  cones across half the street (03:22-03:12).
- **Few crossings** (2-lane by 2-lane, zebra on every arm, traffic lights), about 50-70 m apart; dead ends (the fenced
  start street; the elevated-rail street with a collapsed truss, 07:09-06:49); plazas: gas station corner (about
  20-25 m), fenced court behind the backyards (about 30 x 17 m), parking lot by a garage (about 25 x 15 m).
- **Alleys link yards and streets:** at 03:22-02:08 the player goes from the barricaded BUMRUSH street through a
  fenced back lot (water tanks, a container), a narrow passage, a courtyard ringed by 4-5 storey brick buildings with
  fire escapes and a brick alley, and comes out on the main street at the Vapes stoop.
- **Why it feels trapped:** facades on both sides with only an alley or the far end as a way out; zombies arriving
  from both ends of the street, alley mouths and yards (hordes of 10-20); clutter; closed ends you can see through; a
  tight fixed-yaw camera (about 30 x 28 m visible) so threats arrive from just off screen; a small map you keep crossing.
- **Topology (moderate confidence, distances low):** a main street with the start (Vapes/Yoga) between two crossings,
  a gas station corner, a cross street with Jersey barriers leading to a fenced lot, courtyard and alley back to the
  main street, an elevated-rail dead end, and behind the main street the backyards, court and parking lot, then a
  railed community-centre street and a stoop street. Overall about 150 x 120 m.

Our Freedom City (slice 16, ADR enclosed-street-layout-with-walk-grid-and-flow-field) keeps 120 x 120 m and follows
this topology, but with narrower streets than the original, because the owner found even the old 10 m grid streets
too wide: Main Avenue 11 m facade to facade (7 m road, cars on both curbs), Back Street 9 m with stoops, Cross Street
and its continuation the rail street 9.5 m, alleys 3.5-4 m, every street end fenced with a barricade line from facade
to facade, two crossings, and the court, a fenced parking lot, the gas station, and small yards and bays (10-20 m,
split by workshops, sheds and container rows) inside the blocks. Since our camera looks from the south-east, rows on
the south and east side of a street are low and the building east of each alley is one storey, so the player stays
visible in the alleys.

## Open questions

- What the green "+" square next to the gear counter is (a carried medkit?).
- What the cyan and green map pins mark.
- Whether the purple vignette is low health or a hazard zone.
