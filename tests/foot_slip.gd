class_name FootSlip
extends RefCounted
## Test helper: how fast a model's planted feet slide over the ground while the model moves forward at a ground speed.
## A foot counts as planted while it is within a few centimetres of its lowest point. Returns the worst median planted
## speed over the feet and toes in m/s (0 = the feet stay put, like on a real floor). Clips are advanced by hand, so it
## runs headless and fast.

const FEET: PackedStringArray = ["LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase"]


## `holder` is moved along -Z (the models' forward) by speed x dt each step; `advance(dt)` steps the animation.
static func worst_planted_speed(skeleton: Skeleton3D, holder: Node3D, speed: float, advance: Callable, seconds: float = 4.0) -> float:
	var dt: float = 1.0 / 60.0
	var bones: Array[int] = []
	for bone_name: String in FEET:
		var i: int = skeleton.find_bone(bone_name)
		if i >= 0:
			bones.append(i)
	for i: int in 60:
		holder.position.z -= speed * dt
		advance.call(dt)
	var paths: Array[PackedVector3Array] = []
	for b: int in bones:
		paths.append(PackedVector3Array())
	for frame: int in int(seconds / dt):
		holder.position.z -= speed * dt
		advance.call(dt)
		for k: int in bones.size():
			paths[k].append(skeleton.global_transform * skeleton.get_bone_global_pose(bones[k]).origin)
	var size: float = holder.global_transform.basis.get_scale().x
	var worst: float = 0.0
	for path: PackedVector3Array in paths:
		var lowest: float = INF
		for p: Vector3 in path:
			lowest = minf(lowest, p.y)
		var speeds: Array[float] = []
		for k: int in range(1, path.size()):
			if path[k].y < lowest + 0.03 * size and path[k - 1].y < lowest + 0.03 * size:
				speeds.append(-(path[k].z - path[k - 1].z) / dt)
		if speeds.is_empty():
			return INF
		speeds.sort()
		worst = maxf(worst, absf(speeds[speeds.size() / 2]))
	return worst
