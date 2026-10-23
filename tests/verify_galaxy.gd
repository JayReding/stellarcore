extends SceneTree
## Headless sanity check for galaxy generation and travel distances.
## Run with:
##   godot --headless --path . --script res://tests/verify_galaxy.gd

const RANDOM_STAR_COUNT := 25
const SEED := 424242

var _failures := 0


func _initialize() -> void:
	var galaxy := GalaxyGenerator.generate(RANDOM_STAR_COUNT, SEED)

	_check(galaxy.stars.size() == RANDOM_STAR_COUNT + 1, "star count is 25 random + Newhome")
	_check(galaxy.seed_value == SEED, "seed is preserved")

	var home := galaxy.home_star()
	_check(home != null, "home star exists")
	if home == null:
		_finish()
		return

	_check(home.display_name == "Newhome", "home star is named Newhome")
	_check(home.is_home, "home star has the home flag")
	_check(home.spectral_class == StarData.SpectralClass.G, "home star is G-type")
	_check(home.position_ly.is_equal_approx(Vector3.ZERO), "home star is at the center")
	_check(home.surveyed, "Newhome is surveyed")
	_check(home.planets.size() == 4, "Newhome has exactly four planets")

	var home_classes := [
		PlanetData.PlanetClass.ROCKY,
		PlanetData.PlanetClass.HIGH_MINERAL,
		PlanetData.PlanetClass.EARTH_LIKE,
		PlanetData.PlanetClass.GAS_GIANT,
	]
	var home_designations := ["Newhome I", "Newhome II", "Newhome III", "Newhome IV"]
	for i in home.planets.size():
		var home_planet := home.planets[i]
		_check(home_planet.orbit_index == i + 1, "Newhome planet %d has the right orbit index" % (i + 1))
		_check(home_planet.designation == home_designations[i], "Newhome planet %d is named correctly" % (i + 1))
		_check(home_planet.planet_class == home_classes[i], "Newhome planet %d has the right class" % (i + 1))

	_check(PlanetData.roman_numeral(4) == "IV", "Roman numeral conversion works")

	var class_counts := [0, 0, 0, 0, 0, 0]
	var min_separation := INF
	var nearest_home := INF
	var farthest_home := 0.0
	var total_planets := 0

	for i in galaxy.stars.size():
		var star := galaxy.stars[i]
		var horizontal := Vector2(star.position_ly.x, star.position_ly.z).length()
		_check(horizontal <= GalaxyScale.RADIUS_LY + 0.001, "%s lies inside the 100 ly disc" % star.id)
		_check(absf(star.position_ly.y) <= GalaxyGenerator.VERTICAL_SPREAD_LY + 0.001, "%s lies within the vertical spread" % star.id)

		if not star.is_home:
			class_counts[star.spectral_class] += 1
			_check(not star.surveyed, "%s starts unsurveyed" % star.id)
			_check(
				star.planets.size() >= 2 and star.planets.size() <= 6,
				"%s has between two and six planets" % star.id
			)

		total_planets += star.planets.size()
		for j in star.planets.size():
			var planet := star.planets[j]
			_check(planet.orbit_index == j + 1, "%s planet %d has the right orbit index" % [star.id, j + 1])
			_check(
				planet.planet_class >= 0 and planet.planet_class <= PlanetData.PlanetClass.ICE_WORLD,
				"%s planet %d has a valid class" % [star.id, j + 1]
			)
			_check(
				planet.designation == "%s %s" % [star.display_name, PlanetData.roman_numeral(j + 1)],
				"%s planet %d has the right designation" % [star.id, j + 1]
			)
			_check(planet.orbit_au > 0.0, "%s planet %d has a positive orbit" % [star.id, j + 1])
			if j > 0:
				_check(
					planet.orbit_au > star.planets[j - 1].orbit_au,
					"%s planet %d is farther out than planet %d" % [star.id, j + 1, j]
				)

		var home_distance := home.distance_ly_to(star)
		if star != home:
			nearest_home = minf(nearest_home, home_distance)
			farthest_home = maxf(farthest_home, home_distance)

		for j in range(i + 1, galaxy.stars.size()):
			min_separation = minf(min_separation, star.distance_ly_to(galaxy.stars[j]))

	_check(
		class_counts == [1, 2, 4, 5, 6, 7],
		"procedural class mix is 1 O, 2 B, 4 A, 5 F, 6 G, 7 K"
	)
	_check(min_separation >= GalaxyGenerator.MIN_SEPARATION_LY - 0.001, "minimum separation is at least 10 ly")

	for i in galaxy.stars.size():
		for j in galaxy.stars.size():
			var a := galaxy.stars[i]
			var b := galaxy.stars[j]
			var distance := galaxy.distance_between(a, b)
			var expected := a.position_ly.distance_to(b.position_ly)
			_check(absf(distance - expected) < 0.0001, "distance matrix matches %s -> %s" % [a.id, b.id])
			_check(
				absf(distance - galaxy.distance_between(b, a)) < 0.0001,
				"distance matrix is symmetric for %s <-> %s" % [a.id, b.id]
			)

	for star in galaxy.stars_within_range(home, 20.0):
		_check(home.distance_ly_to(star) <= 20.0, "range query only returns stars within 20 ly")

	_check(
		absf(GalaxyScale.to_world(Vector3(GalaxyScale.RADIUS_LY, 0, 0)).x - GalaxyScale.WORLD_RADIUS) < 0.0001,
		"50 ly maps to the 55-unit map radius"
	)

	print(
		"Newhome: nearest %.2f ly, farthest %.2f ly, map diameter %.0f ly, planets %d"
		% [nearest_home, farthest_home, GalaxyScale.DIAMETER_LY, total_planets]
	)
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("FAIL: " + message)


func _finish() -> void:
	if _failures == 0:
		print("Galaxy verification: PASS")
		quit(0)
	else:
		print("Galaxy verification: FAIL (%d checks)" % _failures)
		quit(1)
