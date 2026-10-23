class_name GalaxyGenerator
extends RefCounted
## Builds a reproducible galaxy of procedural stars plus the player's home star.

const MIN_SEPARATION_LY := 10.0
const VERTICAL_SPREAD_LY := 4.0
const BASE_VISUAL_RADIUS := 1.44

## Gameplay-weighted class mix. For 25 procedural stars these weights add up to
## exactly 25, guaranteeing at least one O and two B stars.
const CLASS_WEIGHTS: Array[int] = [1, 2, 4, 5, 6, 7]
const CLASS_COUNT := 6

const HOME_ID := "SC-000"
const HOME_NAME := "Newhome"


static func generate(count: int, seed_value: int) -> Galaxy:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var home := _build_home_star()
	var positions := _generate_positions(rng, count, home.position_ly)
	var class_pool := _build_class_pool(rng, count)

	var stars: Array[StarData] = [home]
	for i in count:
		var cls := class_pool[i]
		var data := StarData.new()
		data.id = "SC-%03d" % (i + 1)
		data.display_name = data.id
		data.spectral_class = cls
		data.spectral_subclass = rng.randi_range(0, 9)
		data.position_ly = positions[i]

		var temp_range := StarData.temperature_range_for(cls)
		data.temperature_k = rng.randf_range(temp_range.x, temp_range.y)
		data.visual_radius = BASE_VISUAL_RADIUS * StarData.size_factor_for(cls)
		data.pick_radius = maxf(3.3, data.visual_radius + 1.5)
		data.planets = _generate_planets(data, rng)

		stars.append(data)

	var galaxy := Galaxy.new()
	galaxy.seed_value = seed_value
	galaxy.stars = stars
	galaxy.rebuild_distances()
	return galaxy


static func _build_home_star() -> StarData:
	var home := StarData.new()
	home.id = HOME_ID
	home.display_name = HOME_NAME
	home.is_home = true
	home.spectral_class = StarData.SpectralClass.G
	home.spectral_subclass = 2
	home.position_ly = Vector3.ZERO
	home.temperature_k = 5778.0
	home.visual_radius = (
		BASE_VISUAL_RADIUS * StarData.size_factor_for(StarData.SpectralClass.G)
	)
	home.pick_radius = maxf(3.3, home.visual_radius + 1.5)
	home.surveyed = true
	home.planets = _build_home_planets()
	# Newhome III is the only shipyard in the current slice.
	home.shipyard_planet = home.planets[2]
	return home


static func _build_home_planets() -> Array[PlanetData]:
	var classes: Array[int] = [
		PlanetData.PlanetClass.ROCKY,
		PlanetData.PlanetClass.HIGH_MINERAL,
		PlanetData.PlanetClass.EARTH_LIKE,
		PlanetData.PlanetClass.GAS_GIANT,
	]
	var orbits: Array[float] = [0.55, 0.95, 1.25, 5.2]

	var planets: Array[PlanetData] = []
	for i in classes.size():
		planets.append(_make_planet(HOME_NAME, i + 1, classes[i], orbits[i]))
	return planets


static func _generate_planets(
	star: StarData, rng: RandomNumberGenerator
) -> Array[PlanetData]:
	var count := rng.randi_range(2, 6)
	var planets: Array[PlanetData] = []
	var has_earth_like := false

	for index in range(1, count + 1):
		var cls := _random_planet_class(index, count, rng)
		if cls == PlanetData.PlanetClass.EARTH_LIKE:
			if has_earth_like:
				cls = PlanetData.PlanetClass.DEAD_WORLD
			else:
				has_earth_like = true
		planets.append(
			_make_planet(star.display_name, index, cls, _random_orbit_au(index, rng))
		)
	return planets


static func _make_planet(
	star_name: String, index: int, cls: int, orbit_au: float
) -> PlanetData:
	var planet := PlanetData.new()
	planet.orbit_index = index
	planet.planet_class = cls
	planet.orbit_au = orbit_au
	planet.designation = "%s %s" % [star_name, PlanetData.roman_numeral(index)]
	return planet


static func _random_planet_class(
	index: int, count: int, rng: RandomNumberGenerator
) -> int:
	var ratio := 0.0 if count <= 1 else float(index - 1) / float(count - 1)
	var weights: Array[int]

	if ratio < 0.34:
		# Rocky and high-mineral worlds dominate the inner system.
		weights = [60, 30, 0, 10, 0, 0]
	elif ratio < 0.67:
		# Habitable-zone and just-beyond worlds.
		weights = [15, 12, 12, 24, 27, 10]
	else:
		# Gas giants and ice worlds dominate the outer system.
		weights = [3, 4, 2, 12, 48, 31]

	return _weighted_planet_class(weights, rng)


static func _weighted_planet_class(
	weights: Array[int], rng: RandomNumberGenerator
) -> int:
	var total := 0
	for weight in weights:
		total += weight

	var roll := rng.randi_range(1, total)
	var cumulative := 0
	for cls in weights.size():
		cumulative += weights[cls]
		if roll <= cumulative:
			return cls
	return PlanetData.PlanetClass.ROCKY


static func _random_orbit_au(index: int, rng: RandomNumberGenerator) -> float:
	return 0.45 * pow(1.7, index - 1) * rng.randf_range(0.9, 1.1)


static func _generate_positions(
	rng: RandomNumberGenerator, count: int, home_position: Vector3
) -> Array[Vector3]:
	var occupied: Array[Vector3] = [home_position]
	var total := count + 1
	var attempts := 0
	var max_attempts := total * 500

	while occupied.size() < total and attempts < max_attempts:
		attempts += 1
		var candidate := _random_disc_position(rng)

		var valid := true
		for other in occupied:
			if candidate.distance_squared_to(other) < MIN_SEPARATION_LY * MIN_SEPARATION_LY:
				valid = false
				break
		if valid:
			occupied.append(candidate)

	# The rejection sampler is extremely unlikely to run dry at these counts,
	# but never return fewer stars than requested.
	while occupied.size() < total:
		occupied.append(_random_disc_position(rng))

	occupied.remove_at(0)
	return occupied


static func _random_disc_position(rng: RandomNumberGenerator) -> Vector3:
	var angle := rng.randf() * TAU
	# sqrt gives a uniform distribution across the disc's area.
	var radius := sqrt(rng.randf()) * GalaxyScale.RADIUS_LY
	return Vector3(
		cos(angle) * radius,
		rng.randf_range(-VERTICAL_SPREAD_LY, VERTICAL_SPREAD_LY),
		sin(angle) * radius
	)


static func _build_class_pool(rng: RandomNumberGenerator, count: int) -> Array[int]:
	var pool: Array[int] = []

	if count == 25:
		for cls in CLASS_COUNT:
			for _i in CLASS_WEIGHTS[cls]:
				pool.append(cls)
	else:
		for _i in count:
			pool.append(_weighted_class(rng))

	_shuffle(pool, rng)
	return pool


static func _weighted_class(rng: RandomNumberGenerator) -> int:
	var total := 0
	for weight in CLASS_WEIGHTS:
		total += weight

	var roll := rng.randi_range(1, total)
	var cumulative := 0
	for cls in CLASS_COUNT:
		cumulative += CLASS_WEIGHTS[cls]
		if roll <= cumulative:
			return cls
	return CLASS_COUNT - 1


static func _shuffle(values: Array, rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = values[i]
		values[i] = values[j]
		values[j] = swap
