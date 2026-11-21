class_name CharacterModel
extends Node3D
## Base of every generated, rigged character visual (zombie, player). Owns what they share: merging animation clips into the
## model's AnimationPlayer, making the texture readable at night (brightness and glow), a variant tint and a hit flash.
## Presentation only: gameplay tells it what to do ("call down") and never reaches into its nodes.

signal clip_finished(clip: StringName)

## Clip name used by the subclass (walk, run, attack, die, ...) -> Animation resource from the Meshy rig.
@export var clips: Dictionary = {}
## Multiplies the texture colour so characters stand out against the dark city (1 = texture as generated).
@export_range(0.5, 4.0, 0.05) var brightness: float = 1.45
## Self-lit share of the texture, so characters stay readable away from any lamp (0 = none).
@export_range(0.0, 2.0, 0.05) var glow: float = 0.2

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
			library.add_animation(clip_name, clips[clip_name] as Animation)


func _find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found: AnimationPlayer = _find_player(child)
		if found != null:
			return found
	return null
