class_name EffectSpawner
extends Node
## Spawns one-shot effect scenes under a parent while capping how many are alive, so a horde fight stays fast.
## When the cap is reached the new effect is dropped, or the oldest one is replaced (for lasting decals).

## Most effects of this kind alive at once.
@export_range(1, 500) var max_live: int = 24
## True: at the cap the oldest effect is freed to make room. False: the new effect is skipped.
@export var replace_oldest: bool = false

var _live: Array[Node3D] = []


## Instantiates the scene at a world position under parent; returns it, or null if the cap skipped it.
func spawn(scene: PackedScene, parent: Node3D, at: Vector3, dir: Vector3 = Vector3.ZERO) -> Node3D:
	if scene == null:
		return null
	_live.assign(_live.filter(func(n: Variant) -> bool: return is_instance_valid(n)))
	if _live.size() >= max_live:
		if not replace_oldest:
			return null
		_live.pop_front().queue_free()
	var fx: Node3D = scene.instantiate() as Node3D
	fx.position = at
	if fx is VfxBurst and dir != Vector3.ZERO:
		(fx as VfxBurst).aim(dir)
	parent.add_child(fx)
	_live.append(fx)
	return fx


func live_count() -> int:
	_live.assign(_live.filter(func(n: Variant) -> bool: return is_instance_valid(n)))
	return _live.size()
