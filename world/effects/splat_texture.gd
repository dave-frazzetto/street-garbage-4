class_name SplatTexture
extends RefCounted
## Procedurally generated irregular blood splat textures (white, alpha shaped; tinted by the material). A few variants
## are generated once and shared by every decal, so there is no texture memory per splat.

const SIZE: int = 96

static var _cache: Array[ImageTexture] = []


## Returns a shared splat texture; `variant_count` different shapes exist, `index` picks one (wraps).
static func get_variant(index: int, variant_count: int = 4) -> ImageTexture:
	while _cache.size() < variant_count:
		_cache.append(_generate(_cache.size() + 1))
	return _cache[posmod(index, _cache.size())]


static func _generate(seed_value: int) -> ImageTexture:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value * 7919
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 1.0
	# Satellite droplets and tendrils around the main blob: [x, y, radius] in -1..1 space.
	var drops: Array[Vector3] = []
	for i: int in 14:
		var a: float = rng.randf() * TAU
		var d: float = rng.randf_range(0.45, 0.9)
		drops.append(Vector3(cos(a) * d, sin(a) * d, rng.randf_range(0.02, 0.09)))
	var spikes: int = rng.randi_range(5, 9)
	var spike_phase: float = rng.randf() * TAU
	var img: Image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y: int in SIZE:
		for x: int in SIZE:
			var p: Vector2 = Vector2((x + 0.5) / SIZE * 2.0 - 1.0, (y + 0.5) / SIZE * 2.0 - 1.0)
			var dist: float = p.length()
			var ang: float = atan2(p.y, p.x)
			var edge: float = 0.36 + 0.14 * noise.get_noise_2d(cos(ang) * 2.2, sin(ang) * 2.2)
			edge += 0.2 * maxf(0.0, sin(ang * spikes + spike_phase)) * (0.5 + 0.5 * noise.get_noise_2d(ang * 3.0, 9.0))
			var cover: float = clampf((edge - dist) / 0.04, 0.0, 1.0)
			for dr: Vector3 in drops:
				cover = maxf(cover, clampf((dr.z - Vector2(p.x - dr.x, p.y - dr.y).length()) / 0.015, 0.0, 1.0))
			# Darker, thicker pool in the middle.
			var shade: float = lerpf(1.0, 0.7, clampf(1.0 - dist / 0.4, 0.0, 1.0))
			img.set_pixel(x, y, Color(shade, shade, shade, cover))
	return ImageTexture.create_from_image(img)
