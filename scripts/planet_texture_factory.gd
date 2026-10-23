class_name PlanetTextureFactory
extends RefCounted
## Builds deterministic equirectangular surface textures for procedural planets.

const TEXTURE_WIDTH := 256
const TEXTURE_HEIGHT := 128

static var _albedo_cache: Dictionary = {}
static var _cloud_cache: Dictionary = {}


static func visual_seed(planet: PlanetData) -> int:
	return planet.designation.hash() + planet.planet_class * 7919


static func make_albedo_texture(planet: PlanetData) -> ImageTexture:
	var cache_key := visual_seed(planet)
	if _albedo_cache.has(cache_key):
		return _albedo_cache[cache_key] as ImageTexture

	var seed_value := cache_key
	var image: Image
	match planet.planet_class:
		PlanetData.PlanetClass.ROCKY:
			image = _make_rocky(seed_value)
		PlanetData.PlanetClass.HIGH_MINERAL:
			image = _make_high_mineral(seed_value)
		PlanetData.PlanetClass.EARTH_LIKE:
			image = _make_earth_like(seed_value)
		PlanetData.PlanetClass.DEAD_WORLD:
			image = _make_dead_world(seed_value)
		PlanetData.PlanetClass.GAS_GIANT:
			image = _make_gas_giant(seed_value)
		PlanetData.PlanetClass.ICE_WORLD:
			image = _make_ice_world(seed_value)
		_:
			image = Image.create(
				TEXTURE_WIDTH, TEXTURE_HEIGHT, false, Image.FORMAT_RGB8
			)
			image.fill(Color.WHITE)

	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_albedo_cache[cache_key] = texture
	return texture


static func make_material(planet: PlanetData) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = make_albedo_texture(planet)
	material.roughness = _roughness_for(planet.planet_class)
	material.metallic = _metallic_for(planet.planet_class)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.texture_repeat = true
	return material


static func make_cloud_texture(planet: PlanetData) -> ImageTexture:
	var cache_key := visual_seed(planet)
	if _cloud_cache.has(cache_key):
		return _cloud_cache[cache_key] as ImageTexture

	var seed_value := cache_key + 511
	var cloud_noise := _make_noise(seed_value, 2.8, 5)
	var wisp_noise := _make_noise(seed_value + 29, 8.5, 3)
	var image := Image.create(
		TEXTURE_WIDTH, TEXTURE_HEIGHT, false, Image.FORMAT_RGBA8
	)

	for y in TEXTURE_HEIGHT:
		var v := (float(y) + 0.5) / float(TEXTURE_HEIGHT)
		for x in TEXTURE_WIDTH:
			var u := (float(x) + 0.5) / float(TEXTURE_WIDTH)
			var point := _uv_to_point(u, v)
			var base := cloud_noise.get_noise_3d(point.x, point.y, point.z)
			var wisp := wisp_noise.get_noise_3d(point.x, point.y, point.z)
			var coverage := _smoothstep(0.02, 0.42, base + wisp * 0.18)
			var alpha := coverage * 0.82
			image.set_pixel(x, y, Color(0.92, 0.95, 1.0, alpha))

	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_cloud_cache[cache_key] = texture
	return texture


static func make_cloud_material(planet: PlanetData) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = make_cloud_texture(planet)
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.9)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 1.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.texture_repeat = true
	return material


static func _roughness_for(cls: int) -> float:
	match cls:
		PlanetData.PlanetClass.GAS_GIANT:
			return 0.58
		PlanetData.PlanetClass.EARTH_LIKE:
			return 0.72
		PlanetData.PlanetClass.ICE_WORLD:
			return 0.52
		PlanetData.PlanetClass.HIGH_MINERAL:
			return 0.78
		_:
			return 0.94


static func _metallic_for(cls: int) -> float:
	return 0.16 if cls == PlanetData.PlanetClass.HIGH_MINERAL else 0.0


static func _make_rocky(seed_value: int) -> Image:
	var broad := _make_noise(seed_value + 3, 1.9, 4)
	var fine := _make_noise(seed_value + 17, 9.0, 3)
	var craters := _make_craters(seed_value, 34, 0.016, 0.085)
	var image := Image.create(
		TEXTURE_WIDTH, TEXTURE_HEIGHT, false, Image.FORMAT_RGB8
	)

	var dark := Color(0.33, 0.29, 0.26)
	var mid := Color(0.49, 0.42, 0.36)
	var light := Color(0.65, 0.56, 0.47)

	for y in TEXTURE_HEIGHT:
		var v := (float(y) + 0.5) / float(TEXTURE_HEIGHT)
		for x in TEXTURE_WIDTH:
			var u := (float(x) + 0.5) / float(TEXTURE_WIDTH)
			var p := _uv_to_point(u, v)
			var broad_value := broad.get_noise_3d(p.x, p.y, p.z)
			var fine_value := fine.get_noise_3d(p.x, p.y, p.z)
			var color := dark.lerp(mid, 0.5 + 0.5 * broad_value)
			color = color.lerp(light, _smoothstep(0.05, 0.6, broad_value) * 0.45)
			color = color.lerp(dark, clampf(0.5 + 0.5 * fine_value, 0.0, 1.0) * 0.22)
			color = _apply_craters(color, p, craters)
			image.set_pixel(x, y, color)

	return image


static func _make_high_mineral(seed_value: int) -> Image:
	var broad := _make_noise(seed_value + 5, 1.7, 4)
	var patches := _make_noise(seed_value + 19, 3.1, 3)
	var fine := _make_noise(seed_value + 31, 11.0, 3)
	var craters := _make_craters(seed_value, 24, 0.014, 0.07)
	var image := Image.create(
		TEXTURE_WIDTH, TEXTURE_HEIGHT, false, Image.FORMAT_RGB8
	)

	var stone := Color(0.54, 0.54, 0.52)
	var pale := Color(0.84, 0.84, 0.81)
	var rust := Color(0.48, 0.28, 0.18)
	var deep_rust := Color(0.35, 0.19, 0.14)

	for y in TEXTURE_HEIGHT:
		var v := (float(y) + 0.5) / float(TEXTURE_HEIGHT)
		for x in TEXTURE_WIDTH:
			var u := (float(x) + 0.5) / float(TEXTURE_WIDTH)
			var p := _uv_to_point(u, v)
			var broad_value := broad.get_noise_3d(p.x, p.y, p.z)
			var patch_value := patches.get_noise_3d(p.x, p.y, p.z)
			var fine_value := fine.get_noise_3d(p.x, p.y, p.z)

			var color := stone.lerp(pale, 0.5 + 0.5 * broad_value)
			var rust_amount := _smoothstep(0.12, 0.48, patch_value)
			rust_amount *= 0.55 + 0.45 * (0.5 + 0.5 * fine_value)
			color = color.lerp(rust, rust_amount * 0.78)
			color = color.lerp(deep_rust, _smoothstep(0.58, 0.85, patch_value) * 0.35)
			color = _apply_craters(color, p, craters)
			image.set_pixel(x, y, color)

	return image


static func _make_dead_world(seed_value: int) -> Image:
	var broad := _make_noise(seed_value + 7, 1.5, 4)
	var fine := _make_noise(seed_value + 23, 7.0, 3)
	var craters := _make_craters(seed_value, 17, 0.012, 0.06)
	var image := Image.create(
		TEXTURE_WIDTH, TEXTURE_HEIGHT, false, Image.FORMAT_RGB8
	)

	var rust_dark := Color(0.35, 0.18, 0.14)
	var rust_mid := Color(0.55, 0.28, 0.19)
	var dust := Color(0.72, 0.43, 0.29)
	var pale_dust := Color(0.78, 0.58, 0.43)

	for y in TEXTURE_HEIGHT:
		var v := (float(y) + 0.5) / float(TEXTURE_HEIGHT)
		for x in TEXTURE_WIDTH:
			var u := (float(x) + 0.5) / float(TEXTURE_WIDTH)
			var p := _uv_to_point(u, v)
			var broad_value := broad.get_noise_3d(p.x, p.y, p.z)
			var fine_value := fine.get_noise_3d(p.x, p.y, p.z)

			var color := rust_dark.lerp(rust_mid, 0.5 + 0.5 * broad_value)
			color = color.lerp(dust, _smoothstep(0.1, 0.65, broad_value) * 0.55)
			color = color.lerp(pale_dust, maxf(fine_value, 0.0) * 0.12)
			var polar := _smoothstep(0.86, 0.98, absf(p.y) + fine_value * 0.025)
			color = color.lerp(Color(0.78, 0.72, 0.66), polar * 0.55)
			color = _apply_craters(color, p, craters)
			image.set_pixel(x, y, color)

	return image


static func _make_earth_like(seed_value: int) -> Image:
	var continents := _make_noise(seed_value + 11, 1.9, 5)
	var detail := _make_noise(seed_value + 41, 7.5, 4)
	var moisture := _make_noise(seed_value + 71, 3.2, 4)
	var image := Image.create(
		TEXTURE_WIDTH, TEXTURE_HEIGHT, false, Image.FORMAT_RGB8
	)

	var deep_ocean := Color(0.025, 0.12, 0.28)
	var shallow_ocean := Color(0.06, 0.33, 0.50)
	var green_dark := Color(0.16, 0.38, 0.16)
	var green_light := Color(0.33, 0.55, 0.22)
	var dry_land := Color(0.58, 0.50, 0.31)
	var mountain := Color(0.43, 0.42, 0.37)
	var snow := Color(0.90, 0.93, 0.95)
	var sea_level := 0.06

	for y in TEXTURE_HEIGHT:
		var v := (float(y) + 0.5) / float(TEXTURE_HEIGHT)
		for x in TEXTURE_WIDTH:
			var u := (float(x) + 0.5) / float(TEXTURE_WIDTH)
			var p := _uv_to_point(u, v)
			var elevation := continents.get_noise_3d(p.x, p.y, p.z)
			var fine := detail.get_noise_3d(p.x, p.y, p.z)
			elevation += fine * 0.18

			var color: Color
			if elevation < sea_level:
				var depth := _smoothstep(-0.48, sea_level, elevation)
				color = deep_ocean.lerp(shallow_ocean, depth)
				color = color.lightened(maxf(fine, 0.0) * 0.035)
			else:
				var land_height := _smoothstep(sea_level, 0.72, elevation)
				var dampness := 0.5 + 0.5 * moisture.get_noise_3d(p.x, p.y, p.z)
				var arid_band := exp(-pow((absf(p.y) - 0.42) / 0.23, 2.0))
				dampness = clampf(dampness - arid_band * 0.33, 0.0, 1.0)

				var lowland := green_dark.lerp(green_light, dampness)
				var dry := dry_land.lerp(green_light, dampness * 0.35)
				var land := dry.lerp(lowland, _smoothstep(0.18, 0.7, dampness))
				var rock := mountain.lerp(Color(0.61, 0.57, 0.50), fine * 0.5 + 0.5)
				color = land.lerp(rock, _smoothstep(0.42, 0.9, land_height))

			var ice := _smoothstep(0.82, 0.96, absf(p.y) + fine * 0.045)
			color = color.lerp(snow, ice * 0.88)
			image.set_pixel(x, y, color)

	return image


static func _make_gas_giant(seed_value: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var archetype := rng.randi_range(0, 2)
	var palette := _gas_palette(archetype)
	var bands: float = [8.0, 6.0, 4.0][archetype]

	var swirl := _make_noise(seed_value + 101, 1.8, 4)
	var fine := _make_noise(seed_value + 131, 8.0, 3)
	var image := Image.create(
		TEXTURE_WIDTH, TEXTURE_HEIGHT, false, Image.FORMAT_RGB8
	)

	for y in TEXTURE_HEIGHT:
		var v := (float(y) + 0.5) / float(TEXTURE_HEIGHT)
		for x in TEXTURE_WIDTH:
			var u := (float(x) + 0.5) / float(TEXTURE_WIDTH)
			var p := _uv_to_point(u, v)
			var broad := swirl.get_noise_3d(p.x * 1.5, p.y * 3.0, p.z * 1.5)
			var detail := fine.get_noise_3d(p.x * 4.0, p.y * 24.0, p.z * 4.0)
			var phase := p.y * bands + broad * 0.9 + detail * 0.18
			var band := 0.5 + 0.5 * sin(phase * PI * 2.0)
			var secondary := 0.5 + 0.5 * sin(p.y * bands * 2.1 + broad * 2.2)

			var color := palette[0].lerp(palette[1], band)
			color = color.lerp(palette[2], secondary * 0.36)
			color = color.lightened(maxf(detail, 0.0) * 0.035)

			if archetype == 0:
				color = _blend_storm(
					color, p, 0.35, -0.9, 0.30, Color(0.58, 0.25, 0.17), 0.72
				)
			elif archetype == 1:
				color = _blend_storm(
					color, p, -0.32, 0.7, 0.20, Color(0.015, 0.06, 0.22), 0.72
				)

			image.set_pixel(x, y, color)

	return image


static func _make_ice_world(seed_value: int) -> Image:
	var broad := _make_noise(seed_value + 13, 1.4, 4)
	var patches := _make_noise(seed_value + 47, 3.6, 3)
	var fine := _make_noise(seed_value + 83, 10.0, 3)
	var craters := _make_craters(seed_value, 10, 0.015, 0.055)
	var image := Image.create(
		TEXTURE_WIDTH, TEXTURE_HEIGHT, false, Image.FORMAT_RGB8
	)

	var gray := Color(0.76, 0.79, 0.82)
	var white := Color(0.95, 0.96, 0.97)
	var brown := Color(0.50, 0.40, 0.31)

	for y in TEXTURE_HEIGHT:
		var v := (float(y) + 0.5) / float(TEXTURE_HEIGHT)
		for x in TEXTURE_WIDTH:
			var u := (float(x) + 0.5) / float(TEXTURE_WIDTH)
			var p := _uv_to_point(u, v)
			var broad_value := broad.get_noise_3d(p.x, p.y, p.z)
			var patch_value := patches.get_noise_3d(p.x, p.y, p.z)
			var fine_value := fine.get_noise_3d(p.x, p.y, p.z)

			var color := gray.lerp(white, 0.5 + 0.5 * broad_value)
			var stain := _smoothstep(0.33, 0.58, patch_value)
			stain *= _smoothstep(-0.15, 0.3, fine_value)
			color = color.lerp(brown, stain * 0.62)
			color = color.darkened(maxf(-fine_value, 0.0) * 0.035)
			color = _apply_craters(color, p, craters)
			image.set_pixel(x, y, color)

	return image


static func _gas_palette(archetype: int) -> Array[Color]:
	match archetype:
		0:
			# Jupiter-like creams, tans, and umber bands.
			return [
				Color(0.30, 0.21, 0.15),
				Color(0.58, 0.43, 0.29),
				Color(0.90, 0.82, 0.66),
			]
		1:
			# Neptune-like deep blues.
			return [
				Color(0.04, 0.14, 0.36),
				Color(0.10, 0.30, 0.64),
				Color(0.42, 0.68, 0.90),
			]
		_:
			# Uranus-like pale cyan.
			return [
				Color(0.42, 0.68, 0.70),
				Color(0.60, 0.84, 0.85),
				Color(0.76, 0.92, 0.92),
			]


static func _blend_storm(
	color: Color,
	point: Vector3,
	latitude: float,
	longitude: float,
	size: float,
	storm_color: Color,
	strength: float
) -> Color:
	var center := _lat_lon_to_point(latitude, longitude)
	var east := Vector3.UP.cross(center)
	if east.length_squared() < 0.001:
		east = Vector3.RIGHT
	east = east.normalized()
	var north := center.cross(east).normalized()
	var offset := point - center
	var u := offset.dot(east)
	var v := offset.dot(north)
	var distance := sqrt(u * u + v * v * 3.2)
	var amount := (1.0 - _smoothstep(size * 0.45, size, distance)) * strength
	return color.lerp(storm_color, amount)


static func _apply_craters(
	color: Color, point: Vector3, craters: Array[Vector4]
) -> Color:
	var shade := 1.0
	for crater in craters:
		var center := Vector3(crater.x, crater.y, crater.z)
		var radius := crater.w
		var limit := cos(radius * 1.15)
		var dot := point.dot(center)
		if dot < limit:
			continue

		var angle := acos(clampf(dot, -1.0, 1.0))
		var normalized := angle / radius
		var shadow := (1.0 - _smoothstep(0.0, 0.92, normalized)) * 0.16
		var rim := exp(-pow((normalized - 0.87) / 0.11, 2.0)) * 0.24
		shade *= 1.0 - shadow + rim

	shade = clampf(shade, 0.62, 1.34)
	return Color(color.r * shade, color.g * shade, color.b * shade, 1.0)


static func _make_craters(
	seed_value: int, count: int, min_radius: float, max_radius: float
) -> Array[Vector4]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 919
	var craters: Array[Vector4] = []

	for _i in count:
		var z := rng.randf_range(-1.0, 1.0)
		var angle := rng.randf() * TAU
		var ring := sqrt(maxf(0.0, 1.0 - z * z))
		var center := Vector3(ring * cos(angle), z, ring * sin(angle))
		var radius := rng.randf_range(min_radius, max_radius)
		craters.append(Vector4(center.x, center.y, center.z, radius))

	return craters


static func _make_noise(
	seed_value: int, frequency: float, octaves: int
) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5
	return noise


static func _uv_to_point(u: float, v: float) -> Vector3:
	var longitude := (u - 0.5) * TAU
	var latitude := (0.5 - v) * PI
	var cos_latitude := cos(latitude)
	return Vector3(
		cos_latitude * cos(longitude),
		sin(latitude),
		cos_latitude * sin(longitude)
	)


static func _lat_lon_to_point(latitude: float, longitude: float) -> Vector3:
	var cos_latitude := cos(latitude)
	return Vector3(
		cos_latitude * cos(longitude),
		sin(latitude),
		cos_latitude * sin(longitude)
	)


static func _smoothstep(edge0: float, edge1: float, value: float) -> float:
	var t := clampf((value - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
