class_name SystemView
extends CanvasLayer
## Full-screen simplified view of one surveyed star system.

signal closed
signal structures_changed

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
## Fallback reservation when the sidebar has not been laid out yet.
const SIDEBAR_RESERVED_WIDTH := 460.0

static var _halo_texture: ImageTexture

@onready var root: Control = $Root
@onready var system_viewport: SubViewport = %SystemViewport
@onready var system_root: Node3D = %SystemRoot
@onready var camera: Camera3D = %Camera3D
@onready var name_label: Label = %NameLabel
@onready var meta_label: Label = %MetaLabel
@onready var back_button: Button = %BackButton
@onready var planet_hit_layer: Control = %PlanetHitLayer
@onready var sidebar: PanelContainer = %Sidebar
@onready var overview_eyebrow: Label = %OverviewEyebrow
@onready var system_resource_list: VBoxContainer = %SystemResourceList
@onready var research_resource_list: VBoxContainer = %ResearchResourceList
@onready var structure_summary: Label = %StructureSummary
@onready var structure_list: VBoxContainer = %StructureList
@onready var planet_hint: Label = %PlanetHint
@onready var planet_sidebar: PanelContainer = %PlanetSidebar
@onready var planet_detail: VBoxContainer = %PlanetDetail
@onready var planet_title: Label = %PlanetTitle
@onready var planet_close_button: Button = %PlanetCloseButton
@onready var planet_meta: Label = %PlanetMeta
@onready var planet_structure_list: VBoxContainer = %PlanetStructureList
@onready var planet_flow_list: VBoxContainer = %PlanetFlowList
@onready var build_button: Button = %BuildButton
@onready var build_feedback: Label = %BuildFeedback
@onready var construct_backdrop: ColorRect = %ConstructBackdrop
@onready var construct_popup: PanelContainer = %ConstructPopup
@onready var construct_subtitle: Label = %ConstructSubtitle
@onready var construct_status: Label = %ConstructStatus
@onready var construct_list: VBoxContainer = %ConstructList
@onready var construct_close_button: Button = %ConstructCloseButton

var _data: StarData
var _revealed_resources: Array[String] = []
var _research_data := 0
var _research_per_turn := 0
## Structure types the player may build, set by the Stellar View from completed
## research. Base structures are unlocked from the start.
var _unlocked_structures: Array[String] = []
var _selected_planet: PlanetData
var _spin_nodes: Array[Node3D] = []
var _spin_speeds: Array[float] = []
var _planet_holders: Array[Node3D] = []
var _planet_radii: Array[float] = []
var _planet_data_list: Array[PlanetData] = []
var _planet_hit_buttons: Array[Button] = []
var _tween: Tween


func _ready() -> void:
	back_button.pressed.connect(close)
	planet_close_button.pressed.connect(_deselect_planet)
	build_button.pressed.connect(_open_construct_popup)
	construct_close_button.pressed.connect(_close_construct_popup)
	construct_backdrop.gui_input.connect(_on_construct_backdrop_input)
	system_viewport.size_changed.connect(_update_3d_scale)
	system_viewport.size_changed.connect(_update_camera_centering)
	system_viewport.size_changed.connect(_update_planet_hit_targets)
	planet_hit_layer.resized.connect(_update_planet_hit_targets)
	camera.position = CAMERA_POSITION
	camera.look_at(Vector3.ZERO, Vector3.UP)
	visible = false
	_update_3d_scale()
	_update_camera_centering()


func open(
	data: StarData,
	revealed_resources: Array[String] = [],
	research_data: int = 0,
	research_per_turn: int = 0,
	unlocked_structures: Array[String] = []
) -> void:
	if data == null or not data.surveyed:
		return

	_data = data
	_revealed_resources = revealed_resources.duplicate()
	_research_data = maxi(research_data, 0)
	_research_per_turn = research_per_turn
	_unlocked_structures = unlocked_structures.duplicate()
	_selected_planet = null
	planet_sidebar.visible = false
	planet_detail.visible = false
	_close_construct_popup()
	name_label.text = data.display_name
	meta_label.text = "%s  •  %s  •  %d planets" % [
		data.classification(),
		data.class_name_label(),
		data.planets.size(),
	]

	_update_3d_scale()
	_update_camera_centering()
	_rebuild()
	visible = true
	system_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_refresh_sidebar()
	_update_planet_hit_targets()
	call_deferred("_update_camera_centering")
	call_deferred("_update_planet_hit_targets")

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
	_selected_planet = null
	planet_sidebar.visible = false
	planet_detail.visible = false
	_close_construct_popup()
	_clear_visuals()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	closed.emit()


## Called after turn production changes system balances or galaxy-wide Research
## Data.
func refresh_economy(
	revealed_resources: Array[String] = [],
	research_data: int = 0,
	research_per_turn: int = 0,
	unlocked_structures: Array[String] = []
) -> void:
	_revealed_resources = revealed_resources.duplicate()
	_research_data = maxi(research_data, 0)
	_research_per_turn = research_per_turn
	_unlocked_structures = unlocked_structures.duplicate()
	if _data != null:
		_refresh_sidebar()
		if planet_sidebar.visible and _selected_planet != null:
			_populate_planet_detail()
		if construct_popup.visible:
			_populate_construction()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.is_action_pressed("ui_cancel")
	):
		if construct_popup.visible:
			_close_construct_popup()
		elif planet_sidebar.visible:
			_deselect_planet()
		else:
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
	_planet_holders.clear()
	_planet_radii.clear()
	_planet_data_list.clear()

	for button in _planet_hit_buttons:
		if is_instance_valid(button):
			if button.get_parent() != null:
				button.get_parent().remove_child(button)
			button.queue_free()
	_planet_hit_buttons.clear()

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
	_planet_holders.append(holder)
	_planet_radii.append(radius)
	_planet_data_list.append(planet)


## Creates transparent screen-space hit targets over each rendered planet.
func _update_planet_hit_targets() -> void:
	if planet_hit_layer == null:
		return

	for button in _planet_hit_buttons:
		if is_instance_valid(button):
			if button.get_parent() != null:
				button.get_parent().remove_child(button)
			button.queue_free()
	_planet_hit_buttons.clear()

	if _planet_data_list.is_empty():
		return
	if _planet_holders.size() != _planet_data_list.size():
		return

	var viewport_size := Vector2(system_viewport.size)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var layer_size := planet_hit_layer.size
	if layer_size.x <= 0.0 or layer_size.y <= 0.0:
		layer_size = viewport_size
	var screen_scale := layer_size / viewport_size
	var ortho_size := maxf(camera.size, 0.001)

	for i in _planet_data_list.size():
		var planet := _planet_data_list[i]
		var button := Button.new()
		button.name = "PlanetHit_%d" % i
		button.text = ""
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.tooltip_text = "Inspect %s" % planet.designation
		button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.add_theme_stylebox_override(
			"hover", _hit_button_style(Color(0.45, 0.75, 1.0, 0.12))
		)
		button.add_theme_stylebox_override(
			"pressed", _hit_button_style(Color(0.45, 0.75, 1.0, 0.22))
		)
		button.pressed.connect(_select_planet.bind(planet))
		planet_hit_layer.add_child(button)

		var screen_center := camera.unproject_position(
			_planet_holders[i].global_position
		)
		var screen_radius := _planet_radii[i] * viewport_size.y / ortho_size
		var diameter := maxf(48.0, screen_radius * 2.2)
		var center := Vector2(
			screen_center.x * screen_scale.x,
			screen_center.y * screen_scale.y
		)
		button.size = Vector2(diameter, diameter)
		button.position = center - button.size * 0.5
		_planet_hit_buttons.append(button)


func _hit_button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 999
	style.corner_radius_top_right = 999
	style.corner_radius_bottom_right = 999
	style.corner_radius_bottom_left = 999
	return style


func _select_planet(planet: PlanetData) -> void:
	if planet == null or _data == null:
		return
	_selected_planet = planet
	_refresh_sidebar()
	_populate_planet_detail()
	planet_sidebar.visible = true
	planet_detail.visible = true


## Hides the Planet Detail sidebar without leaving the System View.
func _deselect_planet() -> void:
	_selected_planet = null
	_close_construct_popup()
	planet_sidebar.visible = false
	planet_detail.visible = false
	_refresh_sidebar()


func selected_planet() -> PlanetData:
	return _selected_planet


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


func _refresh_sidebar() -> void:
	if _data == null:
		return
	_populate_system_resources()
	_populate_system_structures()


func _populate_system_resources() -> void:
	_clear_children(system_resource_list)
	_clear_children(research_resource_list)

	var stockpile := _data.resources
	if stockpile == null:
		stockpile = ResourceStockpile.new()
		_data.resources = stockpile

	var flow := _data.resource_flow()
	for resource in stockpile.visible_definitions(_revealed_resources):
		var resource_id := str(resource.get("id", ""))
		system_resource_list.add_child(_make_resource_row(
			resource_id,
			str(resource.get("name", resource_id)),
			resource.get("color", Color.WHITE),
			stockpile.get_amount(resource_id),
			int(flow.get(resource_id, 0))
		))

	research_resource_list.add_child(_make_resource_row(
		ResourceStockpile.RESEARCH_DATA,
		ResourceStockpile.RESEARCH_DATA_NAME,
		ResourceStockpile.RESEARCH_DATA_COLOR,
		_research_data,
		_research_per_turn
	))


func _make_resource_row(
	resource_id: String,
	resource_name: String,
	color: Color,
	amount: int,
	change: int
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Resource_%s" % resource_id
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)

	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(7, 7)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.color = color
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(dot)

	var name_label := Label.new()
	name_label.text = resource_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.68, 0.77, 0.88))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)

	var amount_label := Label.new()
	amount_label.name = "Amount"
	amount_label.text = str(amount)
	amount_label.custom_minimum_size = Vector2(54, 0)
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount_label.add_theme_font_size_override("font_size", 13)
	amount_label.add_theme_color_override("font_color", color)
	amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(amount_label)

	var change_label := Label.new()
	change_label.name = "Change"
	change_label.text = _signed_amount(change)
	change_label.custom_minimum_size = Vector2(50, 0)
	change_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	change_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	change_label.add_theme_font_size_override("font_size", 13)
	change_label.add_theme_color_override(
		"font_color", _change_color(change)
	)
	change_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(change_label)

	return row


func _populate_system_structures() -> void:
	_clear_children(structure_list)

	var by_planet := _data.structures_by_planet()
	var total := _data.all_structures().size()
	if total == 0:
		structure_summary.text = "No structures built in this system."
		_add_muted_label(
			structure_list,
			(
				"This system can support construction."
				if _data.can_build_structures()
				else "A Colony is required before construction."
			)
		)
		return

	structure_summary.text = "%d structure%s across %d planet%s" % [
		total,
		"" if total == 1 else "s",
		by_planet.size(),
		"" if by_planet.size() == 1 else "s",
	]

	var row_index := 0
	for entry in by_planet:
		var planet: PlanetData = entry["planet"]
		var planet_header := Label.new()
		planet_header.text = "%s  •  %s" % [
			planet.designation, planet.class_name_label()
		]
		planet_header.add_theme_font_size_override("font_size", 12)
		planet_header.add_theme_color_override(
			"font_color", planet.class_color().lightened(0.12)
		)
		structure_list.add_child(planet_header)

		for structure in entry["structures"]:
			var row := _make_structure_row(planet, structure)
			row.name = "Structure_%d_%s" % [row_index, structure.type_id]
			structure_list.add_child(row)
			row_index += 1


func _make_structure_row(
	planet: PlanetData,
	structure: StructureData
) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 34)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "%s: %s\nClick to inspect %s" % [
		structure.display_name(), structure.description(), planet.designation
	]
	button.add_theme_stylebox_override(
		"normal",
		_sidebar_row_style(
			Color(0.09, 0.18, 0.3, 0.55)
			if planet == _selected_planet
			else Color(0, 0, 0, 0)
		)
	)
	button.add_theme_stylebox_override(
		"hover", _sidebar_row_style(Color(0.12, 0.25, 0.4, 0.55))
	)
	button.add_theme_stylebox_override(
		"pressed", _sidebar_row_style(Color(0.05, 0.13, 0.23, 0.75))
	)
	button.pressed.connect(_select_planet.bind(planet))

	var row := HBoxContainer.new()
	button.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 6.0
	row.offset_right = -6.0
	row.offset_top = 2.0
	row.offset_bottom = -2.0
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(7, 7)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.color = structure.color()
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(dot)

	var name_label := Label.new()
	name_label.text = structure.display_name()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.82, 0.89, 0.97))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)

	var location_label := Label.new()
	location_label.text = structure.location_label()
	location_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	location_label.add_theme_font_size_override("font_size", 11)
	location_label.add_theme_color_override(
		"font_color", Color(0.52, 0.65, 0.8)
	)
	location_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(location_label)

	return button


func _populate_planet_detail() -> void:
	if _selected_planet == null:
		return

	planet_detail.visible = true
	planet_title.text = _selected_planet.designation
	planet_title.add_theme_color_override(
		"font_color", _selected_planet.class_color().lightened(0.2)
	)
	var count := _selected_planet.structure_count()
	planet_meta.text = "%s  •  %d structure%s" % [
		_selected_planet.class_name_label(),
		count,
		"" if count == 1 else "s",
	]

	_clear_children(planet_structure_list)
	if _selected_planet.structures.is_empty():
		_add_muted_label(planet_structure_list, "No structures on this planet.")
	else:
		for i in _selected_planet.structures.size():
			var row := _make_planet_structure_row(
				_selected_planet.structures[i]
			)
			row.name = "PlanetStructure_%d" % i
			planet_structure_list.add_child(row)

	_clear_children(planet_flow_list)
	var entries := _selected_planet.flow_entries()
	if entries.is_empty():
		_add_muted_label(
			planet_flow_list,
			"No resource contribution or upkeep on this planet."
		)
	else:
		for i in entries.size():
			var row := _make_flow_row(entries[i])
			row.name = "PlanetFlow_%d" % i
			planet_flow_list.add_child(row)

	build_feedback.text = ""


## Opens the construction popup for the selected planet.
func _open_construct_popup() -> void:
	if _selected_planet == null or _data == null:
		return
	construct_subtitle.text = "Build on %s" % _selected_planet.designation
	_populate_construction()
	construct_backdrop.visible = true
	construct_popup.visible = true


func _close_construct_popup() -> void:
	construct_backdrop.visible = false
	construct_popup.visible = false


func _on_construct_backdrop_input(event: InputEvent) -> void:
	if (
		construct_popup.visible
		and event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		_close_construct_popup()


## Lists every non-Colony structure type for the selected planet. Entries are
## gated by the system's Colony construction permission and by the player's
## research unlocks; building is instant and free in this slice.
func _populate_construction() -> void:
	_clear_children(construct_list)
	if _selected_planet == null or _data == null:
		return

	if not _data.can_build_structures():
		construct_status.text = (
			"A Colony is required before construction in this system."
		)
		return

	if _data.is_constructing():
		construct_status.text = "Construction in progress: %s on %s — %d %s left." % [
			_data.construction_display_name(),
			_data.construction_planet.designation if _data.construction_planet != null else "unknown planet",
			_data.construction_turns_remaining,
			"turn" if _data.construction_turns_remaining == 1 else "turns",
		]
	else:
		construct_status.text = "Select a structure to build it on %s." % (
			_selected_planet.designation
		)

	var options := _construction_options()
	if options.is_empty():
		return
	for option in options:
		var row := _make_construction_row(option)
		row.name = "Construct_%s" % str(option.get("type_id", "structure"))
		construct_list.add_child(row)


## One entry per buildable structure type, with the reason when it cannot
## currently be built on the selected planet.
func _construction_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	if _selected_planet == null or _data == null:
		return options

	for type_id in StructureData.DEFINITIONS:
		var id := str(type_id)
		if id == StructureData.COLONY:
			continue
		var definition: Dictionary = StructureData.DEFINITIONS[type_id]
		var cost: Dictionary = definition.get("cost", {})
		var reason := ""
		if not _unlocked_structures.has(id):
			reason = "REQUIRES RESEARCH"
		elif (
			id == StructureData.SHIPYARD and _data.has_shipyard()
		):
			reason = "SHIPYARD PRESENT"
		elif _selected_planet.has_structure(id):
			reason = "ALREADY PRESENT"
		elif _data.is_constructing():
			reason = "IN PROGRESS"
		else:
			reason = _construction_shortfall_reason(cost)
		options.append({
			"type_id": id,
			"definition": definition,
			"reason": reason,
			"cost": cost,
			"build_time": int(definition.get("build_time", 0)),
		})
	return options


## Names the first unaffordable construction cost, or "" when affordable.
func _construction_shortfall_reason(cost: Dictionary) -> String:
	if _data.resources == null:
		return "NO STOCKPILE"
	for resource_id in cost:
		var id := str(resource_id)
		var shortfall := (
			int(cost[resource_id]) - _data.resources.get_amount(id)
		)
		if shortfall > 0:
			return "NEEDS %d %s" % [
				shortfall, ResourceStockpile.display_name(id).to_upper()
			]
	return ""


func _make_construction_row(option: Dictionary) -> Button:
	var definition: Dictionary = option.get("definition", {})
	var reason := str(option.get("reason", ""))
	var buildable := reason.is_empty()

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.disabled = not buildable
	button.tooltip_text = "%s: %s\n%s" % [
		str(definition.get("name", "Structure")),
		str(definition.get("description", "")),
		_structure_flow_summary(definition),
	]
	button.add_theme_stylebox_override(
		"normal", _sidebar_row_style(Color(0, 0, 0, 0))
	)
	button.add_theme_stylebox_override(
		"hover", _sidebar_row_style(Color(0.12, 0.25, 0.4, 0.55))
	)
	button.add_theme_stylebox_override(
		"pressed", _sidebar_row_style(Color(0.05, 0.13, 0.23, 0.75))
	)
	button.add_theme_stylebox_override(
		"disabled", _sidebar_row_style(Color(0, 0, 0, 0))
	)
	button.pressed.connect(
		_on_construct_pressed.bind(str(option.get("type_id", "")))
	)

	var row := HBoxContainer.new()
	button.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 6.0
	row.offset_right = -6.0
	row.offset_top = 2.0
	row.offset_bottom = -2.0
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(7, 7)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.color = definition.get("color", Color.WHITE)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(dot)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 0)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = str(definition.get("name", "Structure"))
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override(
		"font_color",
		Color(0.82, 0.89, 0.97) if buildable else Color(0.45, 0.55, 0.67)
	)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(name_label)

	var flow_label := Label.new()
	flow_label.text = _structure_flow_summary(definition)
	flow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	flow_label.add_theme_font_size_override("font_size", 11)
	flow_label.add_theme_color_override(
		"font_color", Color(0.52, 0.65, 0.8)
	)
	flow_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(flow_label)

	var cost_label := Label.new()
	cost_label.name = "CostLabel"
	cost_label.text = _construction_cost_summary(
		option.get("cost", {}), int(option.get("build_time", 0))
	)
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 11)
	cost_label.add_theme_color_override(
		"font_color",
		Color(0.55, 0.42, 0.4)
		if reason.begins_with("NEEDS") or reason == "NO STOCKPILE"
		else Color(0.62, 0.72, 0.84)
	)
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(cost_label)

	var action_label := Label.new()
	action_label.text = "BUILD" if buildable else reason
	action_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_label.add_theme_font_size_override("font_size", 11)
	action_label.add_theme_color_override(
		"font_color",
		Color(0.52, 0.9, 0.76) if buildable else Color(0.55, 0.42, 0.4)
	)
	action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(action_label)

	return button


## Short production/upkeep summary used in construction tooltips and rows.
func _structure_flow_summary(definition: Dictionary) -> String:
	var parts: Array[String] = []
	var production: Dictionary = definition.get("production", {})
	for resource_id in production:
		parts.append("+%d %s" % [
			int(production[resource_id]),
			ResourceStockpile.display_name(str(resource_id)),
		])
	var upkeep: Dictionary = definition.get("upkeep", {})
	for resource_id in upkeep:
		parts.append("-%d %s" % [
			int(upkeep[resource_id]),
			ResourceStockpile.display_name(str(resource_id)),
		])
	var research := int(definition.get("research_per_turn", 0))
	if research != 0:
		parts.append("+%d %s" % [
			research, ResourceStockpile.display_name(
				ResourceStockpile.RESEARCH_DATA
			),
		])
	if parts.is_empty():
		return "No resource output"
	return "  •  ".join(parts)


## Cost and build-time summary for a construction row, with red shortfalls.
func _construction_cost_summary(cost: Dictionary, build_time: int) -> String:
	var cost_text := "Free"
	if not cost.is_empty():
		var parts: Array[String] = []
		for resource_id in cost:
			var id := str(resource_id)
			var required := int(cost[resource_id])
			var text := "%d %s" % [
				required, ResourceStockpile.display_name(id)
			]
			if _data != null and _data.resources != null:
				var shortfall := (
					required - _data.resources.get_amount(id)
				)
				if shortfall > 0:
					text += " (%d short)" % shortfall
			parts.append(text)
		cost_text = "  •  ".join(parts)

	var time_text := "Instant"
	if build_time > 0:
		time_text = "%d %s" % [
			build_time, "turn" if build_time == 1 else "turns"
		]
	return "%s • %s" % [cost_text, time_text]


func _on_construct_pressed(type_id: String) -> void:
	if _data == null or _selected_planet == null:
		return
	if not _data.can_build_structures():
		return
	if not _unlocked_structures.has(type_id):
		return
	if _data.is_constructing():
		return
	if (
		type_id == StructureData.SHIPYARD and _data.has_shipyard()
	) or _selected_planet.has_structure(type_id):
		return

	var definition: Dictionary = StructureData.definition_for(type_id)
	var cost: Dictionary = definition.get("cost", {})
	var build_time := int(definition.get("build_time", 0))
	if _data.resources == null or not _data.resources.can_afford(cost):
		_populate_construction()
		return

	# Free, instant structures (the Shipyard) complete immediately. Everything
	# else spends its cost up front and finishes after its build time.
	if cost.is_empty() or build_time <= 0:
		var instant := _selected_planet.add_structure(type_id)
		_data.refresh_shipyard_planet()
		_after_construction_changed(
			"Built %s on %s." % [
				instant.display_name(), _selected_planet.designation
			]
		)
		return

	_data.resources.spend(cost)
	_data.start_construction(type_id, _selected_planet, build_time)
	_after_construction_changed(
		"Construction started: %s on %s — %d %s." % [
			_data.construction_display_name(),
			_selected_planet.designation,
			build_time,
			"turn" if build_time == 1 else "turns",
		]
	)


func _after_construction_changed(confirmation: String) -> void:
	_refresh_sidebar()
	_populate_planet_detail()
	_populate_construction()
	structures_changed.emit()
	construct_status.text = confirmation
	build_feedback.text = confirmation


func _make_planet_structure_row(structure: StructureData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.tooltip_text = structure.description()
	row.mouse_filter = Control.MOUSE_FILTER_PASS

	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(7, 7)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.color = structure.color()
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(dot)

	var name_label := Label.new()
	name_label.text = structure.display_name()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.82, 0.89, 0.97))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)

	var location_label := Label.new()
	location_label.text = structure.location_label()
	location_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	location_label.add_theme_font_size_override("font_size", 11)
	location_label.add_theme_color_override(
		"font_color", Color(0.52, 0.65, 0.8)
	)
	location_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(location_label)

	return row


func _make_flow_row(entry: Dictionary) -> HBoxContainer:
	var amount := int(entry.get("amount", 0))
	var resource_id := str(entry.get("resource_id", ""))
	var structure_name := str(entry.get("structure_name", ""))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.tooltip_text = "%s by %s" % [
		"Produced" if amount >= 0 else "Used", structure_name
	]

	var amount_label := Label.new()
	amount_label.text = _signed_amount(amount)
	amount_label.custom_minimum_size = Vector2(46, 0)
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount_label.add_theme_font_size_override("font_size", 13)
	amount_label.add_theme_color_override(
		"font_color", _change_color(amount)
	)
	amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(amount_label)

	var name_label := Label.new()
	name_label.text = ResourceStockpile.display_name(resource_id)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.76, 0.84, 0.94))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)

	var source_label := Label.new()
	source_label.text = structure_name
	source_label.custom_minimum_size = Vector2(96, 0)
	source_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	source_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	source_label.add_theme_font_size_override("font_size", 11)
	source_label.add_theme_color_override(
		"font_color", Color(0.5, 0.62, 0.76)
	)
	source_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(source_label)

	return row


func _add_muted_label(container: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.52, 0.63, 0.76))
	container.add_child(label)


func _clear_children(container: VBoxContainer) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _signed_amount(value: int) -> String:
	if value > 0:
		return "+%d" % value
	return str(value)


func _change_color(value: int) -> Color:
	if value > 0:
		return Color(0.46, 0.9, 0.62)
	if value < 0:
		return Color(0.96, 0.45, 0.45)
	return Color(0.52, 0.63, 0.76)


func _sidebar_row_style(background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	return style


## Centers the star system in the space left of the sidebar instead of centering
## it behind the sidebar. The camera stays orthographic, so shifting it along its
## local right axis translates the view without changing the projection.
func _update_camera_centering() -> void:
	if camera == null or sidebar == null or system_viewport == null:
		return

	var viewport_size := Vector2(system_viewport.size)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var sidebar_left := sidebar.get_global_rect().position.x
	if sidebar_left <= 0.0:
		sidebar_left = maxf(viewport_size.x - SIDEBAR_RESERVED_WIDTH, 0.0)

	var shift_pixels := maxf(viewport_size.x - sidebar_left, 0.0) * 0.5
	var world_shift := shift_pixels * camera.size / viewport_size.y
	camera.position = CAMERA_POSITION + camera.transform.basis.x * world_shift


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
