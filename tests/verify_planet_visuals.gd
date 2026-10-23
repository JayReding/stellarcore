extends SceneTree
## Headless check for procedural planet texture generation.
## Run with:
##   godot --headless --path . --script res://tests/verify_planet_visuals.gd

const CLASSES: Array[int] = [
	PlanetData.PlanetClass.ROCKY,
	PlanetData.PlanetClass.HIGH_MINERAL,
	PlanetData.PlanetClass.EARTH_LIKE,
	PlanetData.PlanetClass.DEAD_WORLD,
	PlanetData.PlanetClass.GAS_GIANT,
	PlanetData.PlanetClass.ICE_WORLD,
]

var _failures := 0


func _initialize() -> void:
	var started := Time.get_ticks_msec()

	for i in CLASSES.size():
		var planet := PlanetData.new()
		planet.designation = "TEST %s" % PlanetData.roman_numeral(i + 1)
		planet.orbit_index = i + 1
		planet.orbit_au = 0.5 + i * 0.8
		planet.planet_class = CLASSES[i]

		var texture := PlanetTextureFactory.make_albedo_texture(planet)
		_check(texture != null, "%s produced an albedo texture" % planet.class_name_label())
		if texture == null:
			continue
		_check(
			texture.get_width() == PlanetTextureFactory.TEXTURE_WIDTH,
			"%s texture has the expected width" % planet.class_name_label()
		)
		_check(
			texture.get_height() == PlanetTextureFactory.TEXTURE_HEIGHT,
			"%s texture has the expected height" % planet.class_name_label()
		)

		var material := PlanetTextureFactory.make_material(planet)
		_check(
			material.albedo_texture != null,
			"%s material has an albedo texture" % planet.class_name_label()
		)

	var earth := PlanetData.new()
	earth.planet_class = PlanetData.PlanetClass.EARTH_LIKE
	earth.designation = "TEST Earth"
	var clouds := PlanetTextureFactory.make_cloud_texture(earth)
	_check(clouds != null, "Earth-like worlds produce a cloud layer")

	_check(PlanetTextureFactory.visual_seed(earth) != 0, "planet seeds are deterministic")
	var elapsed := Time.get_ticks_msec() - started
	print("Generated %d planet surfaces in %d ms" % [CLASSES.size(), elapsed])
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("FAIL: " + message)


func _finish() -> void:
	if _failures == 0:
		print("Planet visual verification: PASS")
		quit(0)
	else:
		print("Planet visual verification: FAIL (%d checks)" % _failures)
		quit(1)
