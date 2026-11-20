# Art direction and asset manifest

How the 3D art for Street Trash is generated with Meshy (see ADR `generated-3d-art-with-meshy`). Reference images live in
`art/concept art/` (gitignored, third-party, mood reference only). Prompts below describe the *style* in our own words; never
name a franchise, character or studio in a prompt, and never feed a reference image to Meshy as an input.

## What we take from the references

Read from the Doom Eternal and Doom: The Dark Ages ideation sheets:

- **Silhouette first.** Each creature reads from its outline alone: one exaggerated feature (an oversized clawed arm, a
  bulky shoulder mass, a tiny head on a heavy frame). The game camera is high and isometric, so shape beats detail.
- **Anatomy that looks sculpted, not drawn.** Exposed muscle, tendon and bone; ribs and spines pushing out; asymmetric
  limbs. Flesh is raw red-brown, bone is pale ivory, hard parts are dark worn metal.
- **Desaturated base, one hot accent.** Neutral, dirty mid-values everywhere, with a single saturated accent per class
  (glowing eyes, a wound, a power cell, a neon sign).
- **Armour that looks worn and made, not designed.** Riveted plates, straps, bandages, fur trim, scratched paint, mismatched pieces.
- **Neutral turnaround sheets.** Front-facing, full body, plain grey or white background: the format Meshy reads best.

## Style statement (prepend to every prompt)

> Gritty sci-fi dark-horror stylised realism, chunky exaggerated proportions, strong readable silhouette, hand-painted PBR
> Main character is a female cyberpunk punk rocker, with neon hair and cybernetic implants, wearing worn leather and metal armor. 
> textures, desaturated dirty palette with a single saturated accent colour, worn metal and leather, raw flesh and bone,
> no text, no logos.

## Technical rules

- Units are metres, +Y up, model faces -Z (Godot forward). Pivot at the feet (characters) or the base centre (props).
- Humanoids: A-pose, neutral expression, nothing held in front of the body, so Meshy can rig them.
- Textures 1k or 2k. The camera is far away and the web build must stay small.
- Triangle budgets (smart topology): player 10k, zombies 8k, hero props 5k, small props 2k, pickups 1.5k.
- Format GLB, saved under `art/models/<group>/<name>.glb` with the sidecar `<name>_meta.json` kept beside it.
- Collision stays the hand-made shapes already in each scene; generated meshes are visual only.
- Each generated model is wrapped in a scene `Visual` child. The gameplay scene keeps its script, collision and data Resources.
- Procedural stays procedural: ground shader, blood splats, explosion, fire, bullets, extraction zone, objective arrow, health bars.

## Asset manifest

Order is the order we generate in. Heights are in metres.

| # | Asset | Scene it replaces | Height | Tris | Rig + anim | Prompt (after the style statement) |
|---|---|---|---|---|---|---|
| 1 | Zombie walker | `world/enemies/zombie.tscn` (Visual) | 1.8 | 8k | walk, attack, die | Emaciated street zombie hunched forward, one oversized clawed arm, torn dirty hoodie and jeans, exposed ribs, pale grey-green skin, small glowing red eyes, A-pose |
| 2 | Zombie armoured | `zombie.tscn` with `armoured.tres` | 1.9 | 8k | walk, attack, die | Bloated zombie wearing improvised armour: scrap-metal shoulder plates, riot-shield fragment strapped to one arm, road-sign chest plate, rusted and scratched, red eyes, A-pose |
| 3 | Player survivor | `world/player/player.tscn` (Visual) | 1.8 | 10k | idle, run, shoot | Heavily built street survivor in patched green tactical armour, spiked shoulder pads, scarf and half mask, bandaged forearms, ammo belt across chest, scuffed knee guards, orange scarf accent, A-pose |
| 4 | Pistol | weapon mesh in player | 0.25 | 1.5k | none | Chunky battered handgun, worn dark metal, taped grip |
| 5 | Micro SMG | weapon mesh | 0.4 | 1.5k | none | Compact machine pistol with extended magazine, scratched black metal, orange tape accent |
| 6 | Auto shotgun | weapon mesh | 0.9 | 2k | none | Heavy drum-fed automatic shotgun, riveted barrel shroud, worn wood furniture |
| 7 | Heavy machine gun | weapon mesh | 1.0 | 2k | none | Belt-fed heavy machine gun with bipod folded, dented receiver, ammo belt |
| 8 | Health pickup | `world/pickups/health_pickup.tscn` | 0.4 | 1.5k | spin in engine | Small battered medical satchel with a soft green glowing vial poking out, taped seams, no logos or symbols |
| 9 | Gear pickup | `world/pickups/gear_pickup.tscn` | 0.5 | 1.5k | spin in engine | Scavenged supply crate with cogs and wires spilling out, one glowing power cell |
| 10 | Car (wreck) | `world/props/car.tscn` | 1.5 | 4k | none | Abandoned rusted sedan, flat tyres, smashed windows, scorched paint, dented panels |
| 11 | Street lamp | `world/props/street_lamp.tscn` | 5.0 | 1.5k | none | Bent old street lamp post with cracked lamp head, rust streaks, wire hanging |
| 12 | Power pole | `world/props/power_pole.tscn` | 8.0 | 1.5k | none | Weathered wooden utility pole with crossbeam, tangled cables, a transformer drum |
| 13 | Neon sign | `world/props/neon_sign.tscn` | 1.5 | 1k | flicker in engine | Wall-mounted pub-style neon sign frame with dead tubes and one lit tube, blank face, no text |
| 14 | Building A (shopfront) | `world/props/building.tscn` | 6.0 | 5k | none | Run-down two-storey city shopfront, boarded windows, graffiti-free brick, fire escape, rooftop vents |
| 15 | Building B (tower) | `building.tscn` | 12.0 | 5k | none | Grim brutalist apartment block, stained concrete, broken balconies, rooftop water tank |
| 16 | Building C (warehouse) | `building.tscn` | 5.0 | 5k | none | Industrial warehouse with roller door, corrugated roof, pipes and rusted tanks |
| 17 | Dumpster, barrels, barricade | new props (street clutter) | 1.0 | 1.5k | none | Dented metal dumpster; stack of rusty barrels; makeshift barricade of planks and tyres |

Rows 1 to 3 are done first (the image route, one at a time, each approved before the next). Rows 4 to 17 use the cheaper
smart-topology prop route.

## Pipeline per asset

1. `text-to-image` for a turnaround reference, plain background (2D, cheap). Show it, wait for approval.
2. `image-to-3d` from that task: smart topology, `--target-polycount` from the table, texture model `meshy-n1`, GLB.
   Characters add `--pose-mode a-pose`.
3. Characters only: `rigging` on the result, then bundled walk and run, plus any library action we need.
4. Download the GLB with `-o`, keep the sidecar, inspect the preview, import into Godot, set scale and pivot, wire into the scene.
5. Screenshot it in the isometric camera (windowed) and compare against the placeholder before moving on.
