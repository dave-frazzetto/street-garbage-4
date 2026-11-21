# Audio credits

Real recordings below are all **CC0 1.0 (public domain dedication)**, downloaded from OpenGameArt.org. No attribution is
required; it is given anyway. The original files are not in the repo: `scripts/sfx/process_real_samples.py` documents
exactly which files are used and turns them into the small mono WAV clips in `audio/sfx/` (trimmed, pitch-varied,
soft-compressed, with synthesised layers added where noted).

| Used for | Source page | Author | Licence |
| --- | --- | --- | --- |
| Gunshots (`shot_*`): .22 pistol, .22 magnum, black powder and a rifle report, cut into single shots | https://opengameart.org/content/gunshots | LarkPay | CC0 |
| Explosions (`explosion_*`) body | https://opengameart.org/content/explosion-0 | number99 | CC0 |
| Zombie groans (`zombie_groan_1..4`) | https://opengameart.org/content/undead-moans | Antum Deluge | CC0 |
| Zombie groans (`zombie_groan_5..6`), grunts in `zombie_hit_*`, cries in `zombie_die_*` | https://opengameart.org/content/zombie-moans and https://opengameart.org/content/hungry-ghoul | darsycho | CC0 |
| Footsteps (`footstep_*`) | https://opengameart.org/content/footsteps-0 | gboxmikefozzy | CC0 |

## What is recorded and what is synthesised

- **Recorded (CC0):** the crack and natural tail of every gunshot, the explosion body, all zombie voices and all footsteps.
- **Synthesised (our own, `scripts/sfx/process_real_samples.py`):** a low sine "thump" with a pitch drop under each gunshot
  and explosion, the explosion's sub boom, debris rumble and crackle tail, and the wet splat/thud under zombie hits and
  deaths. Added because the old recordings are thin in the low end.
- **Fully synthesised (`scripts/sfx/generate_sfx.py`):** the ambient city loop (`audio/ambient/city_bed.wav`: traffic rumble, car
  passes, wind gusts, mains hum) and the far one-shots (`siren_far_*`, `dog_far_*`, `thud_far`), plus all UI and pickup
  sounds. These are placeholders in the same spirit as the rest of the project art.
