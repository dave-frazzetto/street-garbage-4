class_name CharacterModel
extends Node3D
## Base of every generated, rigged character visual (zombie, player). Owns what they share: merging animation clips into the
## model's AnimationPlayer, making the texture readable at night (brightness and glow), a variant tint and a hit flash.
## Presentation only: gameplay tells it what to do ("call down") and never reaches into its nodes.

signal clip_finished(clip: StringName)

## Largest bone rotation between the first two frames (degrees) that still counts as a held frame.
const HELD_FRAME_DEGREES: float = 0.5

## Clip name used by the subclass (walk, run, attack, die, ...) -> Animation resource from the Meshy rig.
@export var clips: Dictionary = {}
## Multiplies the texture colour so characters stand out against the dark city (1 = texture as generated).
@export_range(0.5, 4.0, 0.05) var brightness: float = 1.45
## Self-lit share of the texture, so characters stay readable away from any lamp (0 = none).
@export_range(0.0, 2.0, 0.05) var glow: float = 0.2
## Looping clips whose first frame is a held copy of the second one (the generated walk and run repeat their first pose
## for a frame, which stops a planted foot while the body moves on, at every loop). That frame is dropped on install.
@export var trim_held_first_frame: PackedStringArray = ["walk", "run"]
## Trimmed copies of shared clips, made once per source clip (the source Resource is never modified).
static var _trimmed: Dictionary[Animation, Animation] = {}

var _player: AnimationPlayer
var _meshes: Array[MeshInstance3D] = []
var _overlay: StandardMaterial3D = StandardMaterial3D.new()
var _tint: Color = Color(1, 1, 1, 0)


func _ready() -> void:
	_player = _find_player(self)
	_meshes = ModelLook.meshes_of(self)
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.albedo_color = Color(1, 1, 1, 0)
	for mesh: MeshInstance3D in _meshes:
		mesh.material_overlay = _overlay
		ModelLook.lift(mesh, brightness, glow)
	if _player != null:
		_install_clips()
		_player.animation_finished.connect(func(clip: StringName) -> void: clip_finished.emit(clip))


## Tint colour; the alpha is how strongly it is mixed over the texture (0 = untouched).
func set_tint(tint: Color) -> void:
	_tint = tint
	_overlay.albedo_color = tint


## Brief hit flash. Call clear_flash() to return to the tint.
func flash(color: Color) -> void:
	_overlay.albedo_color = Color(color.r, color.g, color.b, 0.75)


func clear_flash() -> void:
	_overlay.albedo_color = _tint


func has_clip(clip: StringName) -> bool:
	return _player != null and _player.has_animation(clip)


func clip_length(clip: StringName) -> float:
	return _player.get_animation(clip).length if has_clip(clip) else 0.0


func current_clip() -> StringName:
	return StringName(_player.current_animation) if _player != null else &""


## Plays a clip (cross-fading) at a playback speed. Does nothing if the model has no such clip.
func play(clip: StringName, blend: float = 0.15, speed: float = 1.0) -> void:
	if not has_clip(clip):
		return
	if _player.current_animation != String(clip) or not _player.is_playing():
		_player.play(clip, blend)
	_player.speed_scale = speed


## Freeze the current pose.
func hold() -> void:
	if _player != null:
		_player.pause()


## The first node of a class below this model (for subclasses that attach things, e.g. a weapon to a hand).
func find_first(node_class: String) -> Node:
	var found: Array[Node] = find_children("*", node_class, true, false)
	return found[0] if not found.is_empty() else null


func _install_clips() -> void:
	var library: AnimationLibrary = _player.get_animation_library(&"")
	if library == null:
		library = AnimationLibrary.new()
		_player.add_animation_library(&"", library)
	for clip_name: StringName in clips:
		if not library.has_animation(clip_name):
			var clip: Animation = clips[clip_name] as Animation
			if trim_held_first_frame.has(String(clip_name)):
				clip = without_held_first_frame(clip)
			library.add_animation(clip_name, clip)


## A copy of a looping clip without its held first frame, or the clip itself when it has none. Cached per clip.
static func without_held_first_frame(clip: Animation) -> Animation:
	if _trimmed.has(clip):
		return _trimmed[clip]
	var result: Animation = clip
	var step: float = clip.step if clip.step > 0.0 else 1.0 / 30.0
	if clip.loop_mode != Animation.LOOP_NONE and clip.length > step * 3.0 and _first_frame_held(clip, step):
		result = _drop_first_frame(clip, step)
	_trimmed[clip] = result
	return result


static func _first_frame_held(clip: Animation, step: float) -> bool:
	var rotations: int = 0
	for t: int in clip.get_track_count():
		if clip.track_get_type(t) != Animation.TYPE_ROTATION_3D or clip.track_get_key_count(t) < 2:
			continue
		rotations += 1
		var a: Quaternion = clip.rotation_track_interpolate(t, 0.0)
		var b: Quaternion = clip.rotation_track_interpolate(t, step)
		if rad_to_deg(a.angle_to(b)) > HELD_FRAME_DEGREES:
			return false
	return rotations > 0


static func _drop_first_frame(clip: Animation, step: float) -> Animation:
	var out: Animation = clip.duplicate(true) as Animation
	var eps: float = step * 0.25
	for t: int in out.get_track_count():
		var kind: Animation.TrackType = out.track_get_type(t)
		var at_step: Variant = null
		match kind:
			Animation.TYPE_ROTATION_3D:
				at_step = out.rotation_track_interpolate(t, step)
			Animation.TYPE_POSITION_3D:
				at_step = out.position_track_interpolate(t, step)
			Animation.TYPE_SCALE_3D:
				at_step = out.scale_track_interpolate(t, step)
		if at_step != null and out.track_find_key(t, step, Animation.FIND_MODE_APPROX) < 0:
			match kind:
				Animation.TYPE_ROTATION_3D:
					out.rotation_track_insert_key(t, step, at_step as Quaternion)
				Animation.TYPE_POSITION_3D:
					out.position_track_insert_key(t, step, at_step as Vector3)
				Animation.TYPE_SCALE_3D:
					out.scale_track_insert_key(t, step, at_step as Vector3)
		while out.track_get_key_count(t) > 0 and out.track_get_key_time(t, 0) < step - eps:
			out.track_remove_key(t, 0)
		for k: int in out.track_get_key_count(t):
			out.track_set_key_time(t, k, maxf(0.0, out.track_get_key_time(t, k) - step))
	out.length = clip.length - step
	return out


func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found: AnimationPlayer = _find_player(child)
		if found != null:
			return found
	return null
