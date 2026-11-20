@tool
class_name IsoCamera
extends Node3D
## Orthographic isometric camera rig that follows a target. Converts screen directions and points to the ground.

@export var target: Node3D
## Perspective like the reference video; off = orthographic (true isometric when pitch is 35.26).
@export var perspective: bool = true:
	set(value):
		perspective = value
		_apply()
## Field of view in degrees (perspective only).
@export_range(10, 90) var fov_degrees: float = 40.0:
	set(value):
		fov_degrees = value
		_apply()
## Downward tilt in degrees (35.26 = true isometric, 60 = the reference video).
@export_range(10, 89) var pitch_degrees: float = 60.0:
	set(value):
		pitch_degrees = value
		_apply()
## Rotation around the vertical axis in degrees.
@export_range(-180, 180) var yaw_degrees: float = 45.0:
	set(value):
		yaw_degrees = value
		_apply()
## Vertical extent of the view in metres (orthographic zoom).
@export_range(5, 120) var view_size: float = 24.0:
	set(value):
		view_size = value
		_apply()
@export_range(10, 200) var distance: float = 44.0:
	set(value):
		distance = value
		_apply()
@export_range(0, 30) var follow_speed: float = 8.0

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	_apply()
	if target != null:
		global_position = target.global_position


func _apply() -> void:
	if not is_inside_tree():
		return
	rotation_degrees = Vector3(-pitch_degrees, yaw_degrees, 0.0)
	var cam: Camera3D = get_node_or_null("Camera3D") as Camera3D
	if cam != null:
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE if perspective else Camera3D.PROJECTION_ORTHOGONAL
		cam.fov = fov_degrees
		cam.size = view_size
		cam.position = Vector3(0, 0, distance)
		cam.near = 0.5
		cam.far = distance * 3.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or target == null or not is_instance_valid(target):
		return
	var t: float = 1.0 - exp(-follow_speed * delta) if follow_speed > 0.0 else 1.0
	global_position = global_position.lerp(target.global_position, t)


## Snap to the target immediately (e.g. at spawn or after a teleport).
func snap() -> void:
	if target != null:
		global_position = target.global_position


## Ground-plane direction that corresponds to screen right.
func view_right() -> Vector3:
	var r: Vector3 = global_basis.x
	r.y = 0.0
	return r.normalized()


## Ground-plane direction that corresponds to screen up (away from the camera).
func view_forward() -> Vector3:
	var f: Vector3 = -global_basis.z
	f.y = 0.0
	return f.normalized()


## Screen-space vector (x right, y down, like Input.get_vector) to a ground-plane vector of the same length.
func screen_to_world(v: Vector2) -> Vector3:
	return view_right() * v.x - view_forward() * v.y


## Point on the plane y = height under a screen position, or the rig position if the ray is parallel.
func ground_point(screen_pos: Vector2, height: float = 0.0) -> Vector3:
	var origin: Vector3 = camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return global_position
	var t: float = (height - origin.y) / dir.y
	return origin + dir * t
