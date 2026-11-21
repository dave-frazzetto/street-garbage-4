# Art direction and asset manifest

How the 3D art for Street Trash is generated with Meshy (see ADRs `generated-3d-art-with-meshy` and
`cyberpunk-world-and-female-protagonist`). Reference images live in `art/concept art/` (gitignored, third-party, mood
reference only). Prompts below describe the *style* in our own words; never name a franchise, character or studio in a
prompt, and never feed a reference image to Meshy as an input.

## Direction (updated 2026-11-21)

- **World:** a cyberpunk megacity block at night, overrun by the infected. Rain-slick concrete and chrome, neon signs and
  holographic ad panels, cables, vents, wet reflections. Gritty and worn, not clean sci-fi.
- **Protagonist:** a woman, a cyberpunk punk rocker: neon hair, cybernetic implants, worn leather and scavenged metal armour.
- **Zombies:** infected citizens. Raw flesh and bone, with failing cybernetics (sparking implants, dead chrome limbs,
  cracked visors) so they belong to the same world.
- **Palette:** desaturated dirty base, one saturated neon accent per asset, picked from magenta, cyan or orange. Red stays
  reserved for the infected (eyes, wounds) and danger.

## What we take from the references

Read from the Doom Eternal and Doom: The Dark Ages ideation sheets (shape language only; the setting is our own):

- **Silhouette first.** Each creature reads from its outline alone: one exaggerated feature (an oversized clawed arm, a
  bulky shoulder mass, a tiny head on a heavy frame). The game camera is high and isometric, so shape beats detail.
- **Anatomy that looks sculpted, not drawn.** Exposed muscle, tendon and bone; ribs and spines pushing out; asymmetric
  limbs. Flesh is raw red-brown, bone is pale ivory, hard parts are dark worn metal.
- **Desaturated base, one hot accent.** Neutral, dirty mid-values everywhere, with a single saturated accent per asset.
- **Armour that looks worn and made, not designed.** Riveted plates, straps, bandages, scratched paint, mismatched pieces.
- **Neutral turnaround sheets.** Front-facing, full body, plain grey or white background: the format Meshy reads best.

## Style statement (prepend to every prompt)

> Gritty cyberpunk dark-horror stylised realism, chunky exaggerated proportions, strong readable silhouette, hand-painted
> PBR textures, desaturated dirty palette with a single neon accent colour (magenta, cyan or orange), worn metal and
> leather, chrome and circuitry details, raw flesh and bone on the infected, no text, no logos.

## Protagonist brief (use in every prompt that shows the player character)

> Athletic woman, cyberpunk punk rocker, determined expression. Neon magenta undercut mohawk, a glowing cyan cybernetic eye
> implant and chrome forearm plates. Worn black leather jacket with metal shoulder studs and patched armour plates, ripped
> sleeveless tee with no print, ammo bandolier across the chest, cargo trousers with scuffed knee guards, heavy boots, a gas
> mask hanging at the neck.

Keep her consistent across every asset that shows her: same hair, same implant colour, same jacket.

## Technical rules

- Units are metres, +Y up, model faces -Z (Godot forward). Pivot at the feet (characters) or the base centre (props).
- Humanoids: A-pose, neutral expression, nothing held in front of the body, so Meshy can rig them.
- Textures 1k or 2k. The camera is far away and the web build must stay small.
- Triangle budgets (smart topology): player 6k, zombies 6k to 8k, hero props 5k, small props 2k, pickups 1.5k.
- Format GLB, saved under `art/models/<group>/<name>.glb`; clips extracted with `art/tools/extract_clips.gd`.
- Collision stays the hand-made shapes already in each scene; generated meshes are visual only.
- Each generated model is wrapped in a scene `Visual` child. The gameplay scene keeps its script, collision and data Resources.
- Light sources (lamps, signs, implants) get a real `OmniLight3D` plus an emissive bulb in the scene. The texture alone never
  glows. Neon accents on characters come from the texture and the shared glow setting in `CharacterModel`.
- Procedural stays procedural: ground shader, blood splats, explosion, fire, bullets, extraction zone, objective arrow, health bars.

## Asset manifest

Order is the order we generate in. Heights are in metres. **State:** *done* = generated and in the game; *regen* = generated
before the 2026-11-21 direction change and no longer matches it; *todo* = still a primitive.

| # | Asset | State | Scene it replaces | Height | Tris | Rig + anim | Prompt (after the style statement) |
|---|---|---|---|---|---|---|---|
| 1 | Zombie walker | regen | `world/enemies/zombie.tscn` (Visual) | 1.8 | 8k | walk, run, attack, die | Emaciated infected city dweller hunched forward, one oversized clawed arm, torn dirty hoodie and jeans, exposed ribs, pale grey-green skin, a cracked cybernetic implant on the temple sparking cyan, small glowing red eyes, A-pose |
| 2 | Zombie armoured | todo | `zombie.tscn` with `armoured.tres` | 1.9 | 8k | walk, attack, die | Bloated infected wearing improvised armour: scrap-metal shoulder plates, a riot-shield fragment on one arm, dead chrome prosthetic leg, rusted and scratched, red eyes, A-pose |
| 3 | Player (female punk rocker) | regen | `world/player/player.tscn` (Visual) | 1.8 | 6k | idle, run, shoot, die | Protagonist brief above. A-pose with arms slightly away from the body and empty hands, feet visible, no weapon |
| 4 | Pistol | regen | weapon mesh in player | 0.25 | 1.5k | none | Chunky battered handgun with glowing neon-magenta circuit lines along the slide, worn dark gunmetal, taped grip |
| 5 | Micro SMG | todo | weapon mesh | 0.4 | 1.5k | none | Compact machine pistol with extended magazine, scratched black metal, cyan glowing energy-cell window |
| 6 | Auto shotgun | todo | weapon mesh | 0.9 | 2k | none | Heavy drum-fed automatic shotgun, riveted barrel shroud, chrome heat-sink fins, orange glowing chamber |
| 7 | Heavy machine gun | todo | weapon mesh | 1.0 | 2k | none | Belt-fed heavy machine gun with folded bipod, dented receiver, glowing cyan targeting module |
| 8 | Health pickup | todo | `world/pickups/health_pickup.tscn` | 0.4 | 1.5k | spin in engine | Battered medical injector case with a soft green glowing stim vial poking out, taped seams, no logos or symbols |
| 9 | Gear pickup | todo | `world/pickups/gear_pickup.tscn` | 0.5 | 1.5k | spin in engine | Salvaged tech crate with cogs and wires spilling out, one glowing cyan power cell |
| 10 | Car (wreck) | todo | `world/props/car.tscn` | 1.5 | 4k | none | Abandoned boxy electric sedan, dead headlights, smashed windows, scorched paint, faint magenta underglow still flickering |
| 11 | Street lamp | regen | `world/props/street_lamp.tscn` | 5.0 | 2.5k | none | Cyberpunk street lamp post, slim dark metal with a curved arm, a flat LED panel head instead of a bulb, cables hanging, rust streaks |
| 12 | Power pole | todo | `world/props/power_pole.tscn` | 8.0 | 1.5k | none | Weathered utility pole with crossbeam, tangled cables, a transformer drum, a small blinking cyan relay box |
| 13 | Neon sign | todo | `world/props/neon_sign.tscn` | 1.5 | 1k | flicker in engine | Wall-mounted holographic-ad projector frame with a dead panel and one flickering neon tube, blank face, no text |
| 14 | Building A (shopfront) | todo | `world/props/building.tscn` | 6.0 | 5k | none | Run-down two-storey megacity shopfront, boarded windows, neon sign brackets, air-con units, fire escape, rooftop vents |
| 15 | Building B (tower) | todo | `building.tscn` | 12.0 | 5k | none | Grim brutalist megablock apartment tower, stained concrete, stacked balconies with cables, rooftop water tank and antenna array |
| 16 | Building C (warehouse) | todo | `building.tscn` | 5.0 | 5k | none | Industrial warehouse with roller door, corrugated roof, pipes, rusted tanks, a glowing hazard strip along the roof edge |
| 17 | Street clutter | todo | new props | 1.0 | 1.5k | none | Dented metal dumpster; stack of barrels with a faint glowing leak; makeshift barricade of planks, tyres and a crushed drone |
| 18 | Traffic light | regen | `world/props/traffic_light.tscn` | 4.5 | 2.5k | none | Cyberpunk traffic signal: tall dark pole, a vertical three-lamp head with visor hoods, scuffed yellow-black housing, cracked lenses, a tilted pedestrian signal box |

Regenerating rows 1, 3, 4, 11 and 18 is the first step after this change (the protagonist first). They keep their scenes,
scripts and clips, so only the GLB, its extracted texture and the clip files are replaced.

## Pipeline per asset

1. `text-to-image` for a turnaround reference, plain background (2D, cheap). Show it, wait for approval.
2. `image-to-3d` from that task: smart topology, `--target-polycount` from the table, texture model `meshy-n1`, GLB.
   Characters add `--pose-mode a-pose`.
3. Characters only: `rigging` on the result, then bundled walk and run, plus any library action we need.
4. Download the GLB and clips, extract clips with `art/tools/extract_clips.gd`, import into Godot, set scale and pivot, wire
   into the scene.
5. Screenshot it in the isometric camera (windowed) and compare against the placeholder before moving on.
