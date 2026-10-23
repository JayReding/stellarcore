class_name SystemView
extends CanvasLayer
## Full-screen simplified view of one surveyed star system.

signal closed

const STAR_SHADER: Shader = preload("res://shaders/star_surface.gdshader")
const ATMOSPHERE_SHADER: Shader = preload("res://shaders/planet_atmosphere.gdshader")

const ORBIT_INNER := 4.8
const ORBIT_OUTER := 12.6
const ORBIT_SEGMENTS := 128
const ORBIT_HALF_WIDTH := 0.022
const CAMERA_POSITION := Vector3(0.0, 18.0, 20.0)
const HALO_TEXTURE_SIZE := 128
const TARGET_3D_HEIGHT := 1440.0
const MAX_3D_SUPERSAMPLE := 2.0

static var _halo_texture: ImageTexture

@onready var root: Control = $Root
@onready var system_viewport: SubViewport = %SystemViewport
@onready var system_root: Node3D = %SystemRoot
@onready var camera: Camera3D = %Camera3D
@onready var name_label: Label = %NameLabel
@onready var meta_label: Label = %MetaLabel
@onready var back_button: Button = %BackButton

var _data: StarData
var _spin_nodes: Array[Node3D] = []
var _spin_speeds: Array[float] = []
var _tween: Tween


func _ready() -> void:
	back_button.pressed.connect(close)
	system_viewport.size_changed.connect(_update_3d_scale)
	camera.position = CAMERA_POSITION
	camera.look_at(Vector3.ZERO, Vector3.UP)
	visible = false
	_update_3d_scale()


func open(data: StarData) -> void:
	if data == null or not data.surveyed:
		return

	_data = data
	name_label.text = data.display_name
	meta_label.text = "%s  •  %s  •  %d planets" % [
		data.classification(),
		data.class_name_label(),
		data.planets.size(),
	]

	_update_3d_scale()
	_rebuild()
	visible = true
	system_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	_kill_tween()
	root.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(root, "modulate:a", 1.0, 0.2)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func close() -> void:
	if not visible:
		return

	_kill_tween()
	visible = false
	system_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_clear_visuals()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.is_action_pressed("ui_cancel")
	):
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return

	for i in _spin_nodes.size():
		var node := _spin_nodes[i]
		if is_instance_valid(node):
			node.rotate_y(_spin_speeds[i] * delta)


func _rebuild() -> void:
	_clear_visuals()
	_add_star()

	var planets := _data.planets
	if planets.is_empty():
		return

	var max_orbit := 0.0
	for planet in planets:
		max_orbit = maxf(max_orbit, planet.orbit_au)

	var rng := RandomNumberGenerator.new()
	rng.seed = _data.id.hash() + 7331
	var angle_offset := rng.randf() * TAU

	for i in planets.size():
		var planet := planets[i]
		var orbit_radius := _orbit_radius_for(planet.orbit_au, max_orbit)
		var angle := angle_offset + TAU * float(i) / float(planets.size())
		angle += rng.randf_range(-0.08, 0.08)
		var position := Vector3(
			cos(angle) * orbit_radius, 0.0, sin(angle) * orbit_radius
		)
		_add_orbit(orbit_radius)
		_add_planet(planet, position, i)


func _clear_visuals() -> void:
	_spin_nodes.clear()
	_spin_speeds.clear()

	for child in system_root.get_children():
		system_root.remove_child(child)
		child.queue_free()


func _add_star() -> void:
	var radius := 2.0 + _data.size_factor() * 0.35
	var visual := MeshInstance3D.new()
	visual.mesh = _make_sphere(radius, 64, 32)
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var material := ShaderMaterial.new()
	material.shader = STAR_SHADER
	material.set_shader_parameter("star_color", _data.class_color())
	material.set_shader_parameter("intensity", 1.45)
	material.set_shader_parameter("limb_darkening", 0.40)
	visual.material_override = material
	system_root.add_child(visual)

	var halo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	halo.mesh = quad
	halo.scale = Vector3.ONE * radius * 7.0
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var halo_material := StandardMaterial3D.new()
	halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo_material.billboard_keep_scale = true
	halo_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	halo_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	halo_material.albedo_texture = _get_halo_texture()
	halo_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var star_color := _data.class_color()
	halo_material.albedo_color = Color(star_color.r, star_color.g, star_color.b, 0.32)
	halo.material_override = halo_material
	system_root.add_child(halo)

	var light := OmniLight3D.new()
	light.position = Vector3.ZERO
	light.light_color = _data.class_color().lerp(Color.WHITE, 0.42)
	light.light_energy = 3.4
	light.omni_range = 90.0
	light.omni_attenuation = 0.45
	light.shadow_enabled = false
	system_root.add_child(light)

	# A cool, low-energy fill from the camera reveals the dark hemispheres
	# without removing the star-driven terminator.
	var fill := DirectionalLight3D.new()
	fill.rotation = camera.rotation
	fill.light_color = Color(0.52, 0.64, 0.84)
	fill.light_energy = 0.60
	fill.shadow_enabled = false
	system_root.add_child(fill)


func _add_orbit(radius: float) -> void:
	var inner := radius - ORBIT_HALF_WIDTH
	var outer := radius + ORBIT_HALF_WIDTH
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in ORBIT_SEGMENTS + 1:
		var angle := TAU * float(i) / float(ORBIT_SEGMENTS)
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		vertices.append(direction * inner)
		vertices.append(direction * outer)
		if i < ORBIT_SEGMENTS:
			var base := i * 2
			indices.append(base)
			indices.append(base + 1)
			indices.append(base + 2)
			indices.append(base + 1)
			indices.append(base + 3)
			indices.append(base + 2)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.34, 0.55, 0.82, 0.20)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var orbit := MeshInstance3D.new()
	orbit.mesh = mesh
	orbit.material_override = material
	orbit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	system_root.add_child(orbit)


func _add_planet(planet: PlanetData, planet_position: Vector3, index: int) -> void:
	var holder := Node3D.new()
	holder.name = "Planet_%d_%s" % [index + 1, planet.planet_class]
	holder.position = planet_position
	system_root.add_child(holder)

	var rng := RandomNumberGenerator.new()
	rng.seed = PlanetTextureFactory.visual_seed(planet)
	var radius := _planet_radius_for(planet.planet_class) * rng.randf_range(0.92, 1.08)

	var spin_root := Node3D.new()
	holder.add_child(spin_root)

	var surface := MeshInstance3D.new()
	surface.mesh = _make_sphere(radius, 64, 32)
	surface.material_override = PlanetTextureFactory.make_material(planet)
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spin_root.add_child(surface)

	_spin_nodes.append(spin_root)
	_spin_speeds.append(0.018 + rng.randf_range(0.0, 0.035))

	if planet.planet_class == PlanetData.PlanetClass.EARTH_LIKE:
		_add_clouds(holder, planet, radius)
		_add_atmosphere(holder, radius, Color(0.26, 0.52, 1.0), 0.85)
	elif planet.planet_class == PlanetData.PlanetClass.DEAD_WORLD:
		_add_atmosphere(holder, radius, Color(0.72, 0.38, 0.22), 0.48)

	_add_planet_labels(holder, planet, radius)


func _add_clouds(holder: Node3D, planet: PlanetData, radius: float) -> void:
	var cloud_holder := Node3D.new()
	holder.add_child(cloud_holder)

	var clouds := MeshInstance3D.new()
	clouds.mesh = _make_sphere(radius * 1.018, 64, 32)
	clouds.material_override = PlanetTextureFactory.make_cloud_material(planet)
	clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cloud_holder.add_child(clouds)

	_spin_nodes.append(cloud_holder)
	_spin_speeds.append(0.045)


func _add_atmosphere(
	holder: Node3D, radius: float, color: Color, intensity: float
) -> void:
	var atmosphere := MeshInstance3D.new()
	atmosphere.mesh = _make_sphere(radius * 1.045, 48, 24)
	atmosphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var material := ShaderMaterial.new()
	material.shader = ATMOSPHERE_SHADER
	material.set_shader_parameter(
		"atmosphere_color", Color(color.r, color.g, color.b, 0.55)
	)
	material.set_shader_parameter("intensity", intensity)
	material.set_shader_parameter("star_position", Vector3.ZERO)
	atmosphere.material_override = material
	holder.add_child(atmosphere)


func _add_planet_labels(holder: Node3D, planet: PlanetData, radius: float) -> void:
	var designation := Label3D.new()
	designation.text = planet.designation
	designation.position = Vector3(0.0, radius + 1.7, 0.0)
	designation.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	designation.no_depth_test = true
	designation.font_size = 46
	designation.pixel_size = 0.014
	designation.outline_size = 12
	designation.outline_modulate = Color(0.0, 0.0, 0.0, 0.96)
	designation.modulate = Color(0.94, 0.98, 1.0, 1.0)
	designation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	designation.render_priority = 2
	holder.add_child(designation)

	var class_label := Label3D.new()
	class_label.text = planet.class_name_label()
	class_label.position = Vector3(0.0, radius + 0.8, 0.0)
	class_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	class_label.no_depth_test = true
	class_label.font_size = 32
	class_label.pixel_size = 0.014
	class_label.outline_size = 9
	class_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.95)
	class_label.modulate = planet.class_color().lightened(0.3)
	class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	class_label.render_priority = 2
	holder.add_child(class_label)


func _update_3d_scale() -> void:
	if system_viewport == null:
		return
	var viewport_height := float(maxi(system_viewport.size.y, 1))
	var scale := clampf(TARGET_3D_HEIGHT / viewport_height, 1.0, MAX_3D_SUPERSAMPLE)
	system_viewport.scaling_3d_scale = scale


func _planet_radius_for(cls: int) -> float:
	match cls:
		PlanetData.PlanetClass.GAS_GIANT:
			return 2.05
		PlanetData.PlanetClass.ICE_WORLD:
			return 1.38
		PlanetData.PlanetClass.EARTH_LIKE:
			return 1.20
		PlanetData.PlanetClass.HIGH_MINERAL:
			return 1.08
		PlanetData.PlanetClass.DEAD_WORLD:
			return 1.02
		_:
			return 1.06


func _orbit_radius_for(orbit_au: float, max_orbit: float) -> float:
	if max_orbit <= 0.0:
		return ORBIT_INNER
	var t := log(1.0 + maxf(orbit_au, 0.0)) / log(1.0 + max_orbit)
	return lerpf(ORBIT_INNER, ORBIT_OUTER, clampf(t, 0.0, 1.0))


func _make_sphere(radius: float, radial_segments: int, rings: int) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = radial_segments
	mesh.rings = rings
	return mesh


static func _get_halo_texture() -> ImageTexture:
	if _halo_texture == null:
		_halo_texture = _make_halo_texture()
	return _halo_texture


static func _make_halo_texture() -> ImageTexture:
	var image := Image.create(
		HALO_TEXTURE_SIZE, HALO_TEXTURE_SIZE, false, Image.FORMAT_RGBA8
	)
	var center := (HALO_TEXTURE_SIZE - 1) * 0.5
	for y in HALO_TEXTURE_SIZE:
		for x in HALO_TEXTURE_SIZE:
			var distance := Vector2(x - center, y - center).length() / center
			var alpha := 0.0
			if distance < 1.0:
				alpha = pow(1.0 - distance, 3.8)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)


func _kill_tween() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = null
