class_name SfxBank
extends Resource
## Every non-weapon sound event in the game. Weapons carry their own `fire_sound` on their WeaponData.
## Leave a slot empty to silence that event.

@export_group("Combat")
@export var zombie_hit: SfxCue
@export var zombie_die: SfxCue
@export var player_hurt: SfxCue
@export var prop_explode: SfxCue
@export var prop_break: SfxCue

@export_group("Movement and voices")
## One footstep of the player on asphalt (several clips picked at random).
@export var footstep: SfxCue
## A zombie groaning somewhere near the player.
@export var zombie_groan: SfxCue

@export_group("Pickups")
@export var pickup_gear: SfxCue
@export var pickup_health: SfxCue

@export_group("Perks and UI")
@export var level_up: SfxCue
@export var perk_pick: SfxCue
@export var perk_redraw: SfxCue
@export var perk_skip: SfxCue
@export var run_start: SfxCue
@export var extraction_denied: SfxCue

@export_group("End of run")
@export var run_extracted: SfxCue
@export var run_killed: SfxCue
@export var run_nuked: SfxCue
