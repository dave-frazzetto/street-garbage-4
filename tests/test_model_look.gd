extends TestCase
## ModelLook: the outline pass is only added when asked for, and equal settings share one material.


func _mesh() -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.set_surface_override_material(0, StandardMaterial3D.new())
	return mesh


func _lifted_material(mesh: MeshInstance3D) -> StandardMaterial3D:
	return mesh.get_surface_override_material(0) as StandardMaterial3D


func test_1_no_outline_by_default() -> void:
	var mesh: MeshInstance3D = _mesh()
	ModelLook.lift(mesh, 1.2, 0.1)
	check(_lifted_material(mesh).next_pass == null, "no outline pass without an outline colour")
	mesh.free()


func test_2_outline_pass_added_and_shared() -> void:
	var a: MeshInstance3D = _mesh()
	var b: MeshInstance3D = _mesh()
	ModelLook.lift(a, 1.2, 0.1, Color(1, 0, 0, 1), 0.06)
	ModelLook.lift(b, 1.2, 0.1, Color(1, 0, 0, 1), 0.06)
	var outline: ShaderMaterial = _lifted_material(a).next_pass as ShaderMaterial
	check(outline != null, "outline pass is a ShaderMaterial")
	check_eq(outline.get_shader_parameter("width"), 0.06, "outline width is passed to the shader")
	check(outline.get_shader_parameter("outline_color") == Color(1, 0, 0, 1), "outline colour is passed to the shader")
	a.free()
	b.free()


func test_3_zombie_and_player_scenes_have_outlines() -> void:
	for path: String in ["res://world/enemies/zombie_model.tscn", "res://world/enemies/zombie_armoured_model.tscn", "res://world/player/player_model.tscn"]:
		var model: CharacterModel = (load(path) as PackedScene).instantiate() as CharacterModel
		check(model.outline_color.a > 0.0 and model.outline_width > 0.0, "%s has a visible outline" % path.get_file())
		model.free()
	check(true, "done")


func _ready() -> void:
	run_all()
