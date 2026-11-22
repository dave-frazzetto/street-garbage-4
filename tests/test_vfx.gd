extends TestCase
## Slice 11 VFX: effect scenes instantiate, emit, free themselves; the spawner caps live effects; zombie hits and
## deaths create blood in a real level run.

var root3d: Node3D


func _ready() -> void:
	root3d = Node3D.new()
	add_child(root3d)
	run_all()


func _spawn(path: String, at: Vector3 = Vector3.ZERO) -> Node3D:
	var fx: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	fx.position = at
	root3d.add_child(fx)
	return fx


func test_1_one_shot_effects_free_themselves() -> void:
	var hit: Node3D = _spawn("res://world/effects/blood_hit.tscn")
	var boom: Node3D = _spawn("res://world/effects/explosion_effect.tscn")
	check((hit as GPUParticles3D).emitting, "blood hit emits")
	check(boom.get_child_count() >= 4, "explosion has flash, particles and light")
	var total: int = 0
	for c: Node in boom.get_children():
		if c is GPUParticles3D:
			total += (c as GPUParticles3D).amount
	check(total <= 100, "explosion particle budget (%d)" % total)
	await wait_seconds(2.9)
	check(not is_instance_valid(hit), "blood hit freed itself")
	check(not is_instance_valid(boom), "explosion freed itself")


func test_2_radius_scales_explosion() -> void:
	var small: ExplosionEffect = (load("res://world/effects/explosion_effect.tscn") as PackedScene).instantiate() as ExplosionEffect
	small.radius = 1.75
	var big: ExplosionEffect = (load("res://world/effects/explosion_effect.tscn") as PackedScene).instantiate() as ExplosionEffect
	big.radius = 3.5
	root3d.add_child(small)
	root3d.add_child(big)
	var s: VfxBurst = small.get_node("Sparks") as VfxBurst
	var b: VfxBurst = big.get_node("Sparks") as VfxBurst
	check_eq(b.params().initial_velocity_max / s.params().initial_velocity_max, 2.0, "double radius doubles spark speed")
	# The authored Process Material is shared by every instance and must stay untouched.
	var authored: ParticleProcessMaterial = (load("res://world/effects/explosion_effect.tscn") as PackedScene).instantiate().get_node("Sparks").process_material as ParticleProcessMaterial
	check_eq(authored.initial_velocity_max, 9.0, "scaling an instance leaves the shared Process Material alone")
	small.queue_free()
	big.queue_free()


func test_3_splat_and_flame() -> void:
	var splat: Node3D = _spawn("res://world/effects/blood_splat.tscn")
	var tex: ImageTexture = SplatTexture.get_variant(0)
	check(tex.get_width() > 0, "splat texture generated")
	var a: Image = tex.get_image()
	var opaque: int = 0
	for i: int in 200:
		if a.get_pixel(randi() % a.get_width(), randi() % a.get_height()).a > 0.5:
			opaque += 1
	check(opaque > 5 and opaque < 150, "splat is partly covered (%d/200 samples)" % opaque)
	var flame: Node3D = _spawn("res://world/effects/flame_effect.tscn")
	await wait_frames(3)
	var looping: bool = true
	for c: Node in flame.get_children():
		if c is GPUParticles3D:
			looping = looping and not (c as GPUParticles3D).one_shot and (c as GPUParticles3D).emitting
	check(looping, "flame loops and keeps emitting")
	var fire: Node3D = _spawn("res://world/props/fire.tscn")
	check(fire.get_node_or_null("Bulb") == null and fire.get_node_or_null("Flame") is FlameEffect, "barrel fire uses the flame effect")
	var car: Node3D = _spawn("res://world/props/car.tscn")
	check(car.get_node("Burning/Flame") is FlameEffect, "car wreck fire uses the flame effect")
	splat.queue_free()
	flame.queue_free()
	fire.queue_free()
	car.queue_free()


func test_4_spawner_caps_live_effects() -> void:
	var sp: EffectSpawner = EffectSpawner.new()
	sp.max_live = 3
	add_child(sp)
	var scene: PackedScene = load("res://world/effects/blood_hit.tscn") as PackedScene
	var made: int = 0
	for i: int in 10:
		if sp.spawn(scene, root3d, Vector3.ZERO, Vector3.RIGHT) != null:
			made += 1
	check_eq(made, 3, "spawner skips beyond the cap")
	check_eq(sp.live_count(), 3, "live count at cap")
	var sp2: EffectSpawner = EffectSpawner.new()
	sp2.max_live = 2
	sp2.replace_oldest = true
	add_child(sp2)
	var first: Node3D = sp2.spawn(scene, root3d, Vector3.ZERO)
	sp2.spawn(scene, root3d, Vector3.ZERO)
	sp2.spawn(scene, root3d, Vector3.ZERO)
	await wait_frames(2)
	check(not is_instance_valid(first), "replace_oldest frees the oldest")
	check_eq(sp2.live_count(), 2, "replace keeps the cap")
	# Effects that freed themselves earlier must not break the next spawn (regression: typed filter lambda).
	for n: Node in root3d.get_children():
		n.free()
	check(sp.spawn(scene, root3d, Vector3.ZERO) != null, "spawner copes with freed effects")


func test_5_level_hit_and_death_blood() -> void:
	var flow: GameFlow = (load("res://core/game_flow.tscn") as PackedScene).instantiate() as GameFlow
	flow.seed_value = 3
	add_child(flow)
	flow.start_run()
	await wait_frames(3)
	var level: Level = flow.level
	var z: Zombie = (load("res://world/enemies/zombie.tscn") as PackedScene).instantiate() as Zombie
	z.data = load("res://data/enemies/walker.tres") as EnemyData
	level.entities.add_child(z)
	z.global_position = level.player.global_position + Vector3(6, 0, 0)
	level._on_zombie_spawned(z)
	var before: int = level.effects.get_child_count()
	z.take_damage(1.0, Vector3.RIGHT)
	await wait_frames(2)
	check(level.effects.get_child_count() > before, "a hit spawns a blood burst")
	var fx_count: int = level.effects.get_child_count()
	z.take_damage(100000.0, Vector3.RIGHT)
	await wait_frames(3)
	check(level.effects.get_child_count() >= fx_count + 2, "a kill spawns a hit burst and a splat")
	var splats: int = 0
	for c: Node in level.effects.get_children():
		if c is BloodSplat:
			splats += 1
	check(splats >= 1, "blood splat decal exists after death")
	flow.queue_free()


func test_6_aiming_copies_the_shared_process_material() -> void:
	var scene: PackedScene = load("res://world/effects/blood_hit.tscn") as PackedScene
	var a: VfxBurst = scene.instantiate() as VfxBurst
	var b: VfxBurst = scene.instantiate() as VfxBurst
	var authored: Vector3 = (b.process_material as ParticleProcessMaterial).direction
	a.aim(Vector3(1, 0, 0))
	check_eq(a.params().direction, Vector3(1, 0, 0), "aim sets this burst's direction")
	check_eq((b.process_material as ParticleProcessMaterial).direction, authored, "another instance keeps the authored direction")
	check_eq((scene.instantiate() as VfxBurst).params().direction, authored, "the scene's shared material is unchanged")
	a.free()
	b.free()


func test_7_effects_are_gpu_particles_with_compiling_shaders() -> void:
	var cpu: int = 0
	var gpu: int = 0
	for file: String in DirAccess.get_files_at("res://world/effects"):
		if file.get_extension() != "tscn":
			continue
		var fx: Node = (load("res://world/effects/" + file) as PackedScene).instantiate()
		for n: Node in [fx] + fx.find_children("*", "", true, false):
			if n is CPUParticles3D:
				cpu += 1
			elif n is GPUParticles3D:
				gpu += 1
				var g: GPUParticles3D = n as GPUParticles3D
				check(g.process_material is ParticleProcessMaterial, "%s/%s has a Process Material" % [file, n.name])
				check(g.draw_pass_1 != null and g.material_override is ShaderMaterial, "%s/%s draws with a shader material" % [file, n.name])
				check(g.visibility_aabb.size.length() > 1.0, "%s/%s has a visibility box" % [file, n.name])
		fx.free()
	check_eq(cpu, 0, "no CPU particle nodes left in the effect scenes")
	check(gpu >= 12, "GPU particle emitters found (%d)" % gpu)
	for file: String in DirAccess.get_files_at("res://world/effects/shared"):
		if file.get_extension() == "gdshader":
			var sh: Shader = load("res://world/effects/shared/" + file) as Shader
			check(sh.get_shader_uniform_list().size() > 0, "%s compiles and has uniforms" % file)


func test_8_scaled_explosion_keeps_particles_inside_the_cull_box() -> void:
	var scene: PackedScene = load("res://world/effects/explosion_effect.tscn") as PackedScene
	var base: ExplosionEffect = scene.instantiate() as ExplosionEffect
	base.radius = 1.75
	var big: ExplosionEffect = scene.instantiate() as ExplosionEffect
	big.radius = 5.5
	root3d.add_child(base)
	root3d.add_child(big)
	var factor: float = 5.5 / 1.75
	for node_name: String in ["Sparks", "Smoke", "Fireball"]:
		var a: VfxBurst = base.get_node(node_name) as VfxBurst
		var b: VfxBurst = big.get_node(node_name) as VfxBurst
		check_eq(b.visibility_aabb.size.x / a.visibility_aabb.size.x, factor, "%s cull box grows with the radius" % node_name)
		# Fastest particle's straight-line travel (ignoring gravity) must stay inside the box half-width.
		var p: ParticleProcessMaterial = b.params()
		var travel: float = p.initial_velocity_max * b.total_lifetime()
		check(travel < b.visibility_aabb.size.x * 0.5 * 1.5, "%s travel (%.1f m) fits its cull box" % [node_name, travel])
	base.queue_free()
	big.queue_free()


func test_9_impact_tint_goes_to_a_private_material() -> void:
	var shared: ShaderMaterial = load("res://world/effects/shared/mat_spark.tres") as ShaderMaterial
	var before: Color = shared.get_shader_parameter("tint") as Color
	var fx: ImpactEffect = (load("res://world/effects/impact_effect.tscn") as PackedScene).instantiate() as ImpactEffect
	fx.color = Color(1, 0, 0)
	root3d.add_child(fx)
	var sparks: GPUParticles3D = fx.get_node("Sparks") as GPUParticles3D
	var mat: ShaderMaterial = sparks.material_override as ShaderMaterial
	check(mat != shared, "impact uses its own material copy")
	check_eq(mat.get_shader_parameter("tint"), Color(1, 0, 0), "bullet colour reaches the shader tint")
	check_eq(shared.get_shader_parameter("tint"), before, "the shared spark material is unchanged")
	fx.queue_free()
