class_name LocomotionProfile
extends Resource
## How the player's directional walk and run clips map to ground speed. Each number is the ground speed in m/s at which the
## clip's planted foot matches the floor at normal playback (measured with art/tools/extract_clips.gd and measure_clips.gd);
## the model plays the clip at ground speed / this value so feet do not slide. Re-measure when a clip is replaced.

@export_group("Walk clips")
@export_range(0.3, 6.0, 0.05) var walk_forward: float = 1.52
@export_range(0.3, 6.0, 0.05) var walk_back: float = 1.37
@export_range(0.3, 6.0, 0.05) var walk_left: float = 1.38
@export_range(0.3, 6.0, 0.05) var walk_right: float = 1.07
@export_group("Run clips")
@export_range(0.5, 12.0, 0.05) var run_forward: float = 5.24
@export_range(0.5, 12.0, 0.05) var run_back: float = 2.4
@export_range(0.5, 12.0, 0.05) var run_left: float = 3.0
@export_range(0.5, 12.0, 0.05) var run_right: float = 3.0
@export_group("Direction changes")
## How fast the leg direction follows the movement direction, in degrees per second. Lower is smoother but laggier; a
## full reversal always sweeps through the strafe pose.
@export_range(90.0, 2000.0, 10.0) var turn_rate_degrees: float = 600.0


## Reference speed of one clip: gait is &"walk" or &"run", side one of forward, back, left, right.
func speed_of(gait: StringName, side: StringName) -> float:
	return float(get("%s_%s" % [gait, side]))


## Reference speed of a gait for a direction: the clips' speeds weighted by how much of each the blend space plays.
func reference_speed(gait: StringName, direction: Vector2) -> float:
	var weights: Dictionary = LocomotionBlend.weights(direction)
	var total: float = 0.0
	for side: StringName in weights:
		total += float(weights[side]) * speed_of(gait, side)
	return total
