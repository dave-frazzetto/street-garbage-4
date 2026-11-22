class_name ExplosionEffect
extends Node3D
## Explosion: a white-hot flash puff, a ground shockwave ring, a fireball, a smoke puff, streaking sparks, lingering
## embers and a short light. Each part is a child VfxBurst (tune amount, speed, colours in its Inspector). `radius` scales the whole thing relative to
## `reference_radius`, so a barrel blast and a small explosive round use the same scene.

## Blast radius this effect is drawn for. Prop blasts and explosive rounds set it when they spawn the effect.
@export var radius: float = 1.75
## Radius at which the authored particle speeds and sizes look right.
@export_range(0.25, 10, 0.05) var reference_radius: float = 1.75
## How long the light lasts (the flash is a particle, see its own lifetime), in seconds.
@export_range(0.05, 2, 0.05) var lifetime: float = 0.3
@export var color: Color = Color(1.0, 0.6, 0.2)
@export_range(0, 20, 0.1) var light_energy: float = 6.0

@onready var _light: OmniLight3D = $Light

var _age: float = 0.0
var _free_after: float = 0.0


func _ready() -> void:
	var factor: float = radius / reference_radius
	for child: Node in get_children():
		var burst: VfxBurst = child as VfxBurst
		if burst == null:
			continue
		burst.scale_by(factor)
		_free_after = maxf(_free_after, burst.total_lifetime())
	_free_after = maxf(_free_after, lifetime) + 0.1
	_light.light_color = color
	_light.omni_range = maxf(radius * 3.0, 3.0)


func _process(delta: float) -> void:
	_age += delta
	var t: float = clampf(_age / lifetime, 0.0, 1.0)
	_light.light_energy = light_energy * (1.0 - t)
	if _age >= _free_after:
		queue_free()
