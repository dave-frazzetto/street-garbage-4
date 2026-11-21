class_name ZombieHurtbox
extends Area3D
## Bullet-only hit volume of a zombie, larger than its body so shots that pass close still count.
## Lives on its own physics layer (HURTBOX_LAYER) that only bullets query; it never affects zombie movement.
## Works from the parent Zombie's EnemyData.radius, so bigger zombies get a proportionally bigger hurtbox.

const HURTBOX_LAYER: int = 8
## Natural radius of the zombie model (EnemyData.radius at scale 1).
const BASE_RADIUS: float = 0.33
const BASE_HEIGHT: float = 1.8

## Extra metres around the body within which a bullet still hits.
@export_range(0, 2, 0.05) var hit_forgiveness: float = 0.3

@onready var _shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	collision_layer = HURTBOX_LAYER
	collision_mask = 0
	monitoring = false
	refresh()
	# The zombie applies its data in its own _ready, which runs after ours.
	refresh.call_deferred()


## The zombie this hurtbox belongs to.
func get_zombie() -> Zombie:
	return get_parent() as Zombie


## Re-reads the zombie's radius; call after changing EnemyData.radius at runtime.
func refresh() -> void:
	var zombie: Zombie = get_zombie()
	var body_radius: float = zombie.data.radius if zombie != null and zombie.data != null else BASE_RADIUS
	var scale_factor: float = maxf(1.0, body_radius / BASE_RADIUS)
	var cylinder: CylinderShape3D = _shape.shape as CylinderShape3D
	cylinder.radius = body_radius + hit_forgiveness
	cylinder.height = BASE_HEIGHT * scale_factor + hit_forgiveness
	_shape.position.y = cylinder.height * 0.5 - hit_forgiveness * 0.5
