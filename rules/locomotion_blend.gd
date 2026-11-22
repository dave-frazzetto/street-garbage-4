class_name LocomotionBlend
extends RefCounted
## Node-free maths of directional locomotion: which way the body moves relative to where it faces, and how that picks and
## mixes the forward, backward and strafe clips. Directions are Vector2(x = to the character's right, y = forward), so
## (0, 1) is running forward, (0, -1) backpedalling, (1, 0) strafing right. PlayerModel feeds it; tests run it headless.

## Ground speeds below this have no direction (the legs are idle and the last direction is kept).
const MIN_SPEED: float = 0.05


## Unit direction of a world velocity in the frame of a body whose forward is -Z turned by facing_yaw radians about Y
## (the convention of Player.visual). Vector2.ZERO when the body is practically still.
static func local_direction(velocity: Vector3, facing_yaw: float) -> Vector2:
	var ground: Vector2 = Vector2(velocity.x, velocity.z)
	if ground.length() < MIN_SPEED:
		return Vector2.ZERO
	var forward: Vector2 = Vector2(-sin(facing_yaw), -cos(facing_yaw))
	var right: Vector2 = Vector2(cos(facing_yaw), -sin(facing_yaw))
	return Vector2(ground.dot(right), ground.dot(forward)).normalized()


## Turns direction toward target by at most max_step radians along the shortest arc, so a reversal sweeps through the
## strafe pose instead of cutting through the middle of the blend space. A zero target keeps the current direction.
static func turn_toward(current: Vector2, target: Vector2, max_step: float) -> Vector2:
	if target == Vector2.ZERO:
		return current
	if current == Vector2.ZERO:
		return target
	var angle: float = rotate_toward(atan2(current.x, current.y), atan2(target.x, target.y), max_step)
	return Vector2(sin(angle), cos(angle))


## Position in the blend space (the diamond with forward, backward, left and right at its corners) of a unit direction.
## It lies on the edge between the two nearest clips, so only those two are mixed: (0.5, 0.5) is half forward, half right.
static func blend_position(direction: Vector2) -> Vector2:
	var reach: float = absf(direction.x) + absf(direction.y)
	return direction / reach if reach > 0.0001 else Vector2(0.0, 1.0)


## How much of each clip the blend space mixes for a direction: {forward, back, left, right}, summing to 1.
static func weights(direction: Vector2) -> Dictionary:
	var position: Vector2 = blend_position(direction)
	return {
		&"forward": maxf(position.y, 0.0),
		&"back": maxf(-position.y, 0.0),
		&"left": maxf(-position.x, 0.0),
		&"right": maxf(position.x, 0.0),
	}


## Name of the clip for a direction of a gait: "walk" + "back" = &"walk_back"; forward keeps the plain gait name.
static func clip_name(gait: StringName, side: StringName) -> StringName:
	return gait if side == &"forward" else StringName("%s_%s" % [gait, side])
