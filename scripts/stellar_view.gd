extends Node3D
## Stellar View: procedural galaxy, camera navigation, star selection, and the
## galaxy-wide Research Data pool.

const STAR_SCENE: PackedScene = preload("res://scenes/star.tscn")
const SYSTEM_VIEW_SCENE: PackedScene = preload("res://scenes/system_view.tscn")
const TECH_TREE_SCENE: PackedScene = preload("res://scenes/tech_tree.tscn")
const SHIPYARD_SCENE: PackedScene = preload("res://scenes/shipyard.tscn")
const FLEET_DIALOG_SCENE: PackedScene = preload("res://scenes/ui/fleet_dialog.tscn")
const STAR_COLLISION_LAYER := 2
const FLEET_COLLISION_LAYER := 4
const DRAG_THRESHOLD := 5.0
const HOVER_INTERVAL := 0.05
const RAY_LENGTH := 5000.0
const GRID_RINGS_LY: Array[float] = [15.0, 30.0, 45.0, 50.0]
const GRID_SPOKES := 12
const GRID_SEGMENTS := 96
const GRID_INNER_LY := 10.0
const COURSE_DASH_LENGTH := 0.9
const COURSE_GAP_LENGTH := 0.58
const COURSE_HALF_WIDTH := 0.12
const STATUS_INFO_COLOR := Color(0.68, 0.84, 1.0, 1.0)
const STATUS_PROMPT_COLOR := Color(0.95, 0.78, 0.45, 1.0)
const STATUS_SUCCESS_COLOR := Color(0.55, 0.92, 0.78, 1.0)

@export var star_count := 25
## Set to a non-zero value to reproduce a specific galaxy.
@export var galaxy_seed := 0

@onready var camera_rig: CameraRig = $CameraRig
@onready var stars_root: Node3D = $Stars
@onready var fleets_root: Node3D = $Fleets
@onready var fleet_courses_root: Node3D = $FleetCourses
@onready var star_panel: StarInfoPanel = $UI/StarInfoPanel
@onready var seed_label: Label = $UI/HUD/SeedLabel
@onready var technologies_button: Button = $UI/HUD/TechnologiesButton
@onready var research_amount_label: Label = %ResearchAmount
@onready var turn_manager: TurnManager = $TurnManager
@onready var turn_label: Label = $UI/HUD/TurnLabel
@onready var end_turn_button: Button = $UI/HUD/EndTurnButton
@onready var turn_countdown_label: Label = $UI/HUD/TurnCountdownLabel
@onready var status_label: Label = $UI/HUD/StatusLabel

## Research Data is the only galaxy-wide resource.
var research_data: int = 0
## Hidden system resources become visible in every system once revealed.
var revealed_resources: Array[String] = []
var _galaxy: Galaxy
var _home_star: StarData
var _star_nodes: Array[StarNode] = []
var _selected_star: StarNode
var _system_view: SystemView
var _tech_tree: TechTree
var _shipyard: ShipyardView
var _fleet_dialog: FleetDialog
var _destination_fleet: FleetData
var _fleet_markers: Array[FleetMarker] = []
var _course_mesh: ImmediateMesh
var _course_material: StandardMaterial3D
var _course_instance: MeshInstance3D

var _press_active := false
var _drag_active := false
var _ignore_release := false
var _press_position := Vector2.ZERO
var _press_hit: StarNode
var _press_fleet: FleetMarker
var _hover_timer := 0.0


func _ready() -> void:
	var seed_value := galaxy_seed
	if seed_value == 0:
		seed_value = randi() % 900000 + 100000

	_build_reference_grid()
	_build_fleet_course_layer()
	_spawn_galaxy(seed_value)
	star_panel.scan_requested.connect(_on_scan_requested)
	star_panel.system_view_requested.connect(_on_system_view_requested)
	star_panel.shipyard_requested.connect(_on_shipyard_requested)
	star_panel.fleet_selected.connect(_on_fleet_selected)
	technologies_button.pressed.connect(_on_technologies_requested)
	turn_manager.turn_advanced.connect(_on_turn_advanced)
	turn_manager.end_turn_started.connect(_on_end_turn_started)
	turn_manager.end_turn_countdown_changed.connect(_on_end_turn_countdown_changed)
	turn_manager.end_turn_cancelled.connect(_on_end_turn_cancelled)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	turn_label.text = _turn_text(turn_manager.current_turn)
	_reset_end_turn_ui()
	status_label.text = ""
	_update_research_data_hud()
	_rebuild_fleet_markers()
	_rebuild_fleet_courses()

	seed_label.text = "GALAXY SEED  %06d   /   %d SYSTEMS   /   %d LY ACROSS" % [
		seed_value, _galaxy.stars.size(), int(GalaxyScale.DIAMETER_LY)
	]
	print(
		"Stellar Core | seed %d | %d systems | %d ly across"
		% [seed_value, _galaxy.stars.size(), int(GalaxyScale.DIAMETER_LY)]
	)


func refresh_resources() -> void:
	if not is_node_ready():
		return
	_update_research_data_hud()
	if star_panel.visible:
		star_panel.refresh_resources(revealed_resources)
	if _tech_tree != null:
		_tech_tree.refresh_research_data(research_data)
	if _shipyard != null and _shipyard.visible:
		_shipyard.refresh()


func set_research_data(amount: int) -> void:
	research_data = maxi(amount, 0)
	if is_node_ready():
		refresh_resources()


func add_research_data(amount: int) -> void:
	set_research_data(research_data + amount)


## Reveals a hidden system resource in every system's resource list.
func reveal_resource(resource_id: String) -> bool:
	if not ResourceStockpile.is_hidden_by_default(resource_id):
		return false
	if revealed_resources.has(resource_id):
		return false
	revealed_resources.append(resource_id)
	refresh_resources()
	return true


func _update_research_data_hud() -> void:
	research_amount_label.text = "%d RD" % research_data


func _process(delta: float) -> void:
	if _is_overlay_open():
		return

	_hover_timer -= delta
	if _hover_timer <= 0.0:
		_hover_timer = HOVER_INTERVAL
		_update_hover_cursor()


func _unhandled_input(event: InputEvent) -> void:
	if _is_overlay_open():
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_left_pressed(event)
			else:
				_on_left_released()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_rig.zoom(1)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_rig.zoom(-1)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("ui_cancel"):
			if _destination_fleet != null:
				_cancel_destination_selection("Destination selection canceled.")
			else:
				_clear_selection()


func _spawn_galaxy(seed_value: int) -> void:
	_galaxy = GalaxyGenerator.generate(star_count, seed_value)
	_home_star = _galaxy.home_star()
	for data in _galaxy.stars:
		var star := STAR_SCENE.instantiate() as StarNode
		if star == null:
			continue
		stars_root.add_child(star)
		star.setup(data)
		_star_nodes.append(star)


func _on_left_pressed(event: InputEventMouseButton) -> void:
	_press_active = true
	_drag_active = false
	_ignore_release = false
	_press_position = event.position
	_press_fleet = _fleet_under_mouse()
	_press_hit = null
	if _press_fleet == null:
		_press_hit = _star_under_mouse()

	if (
		event.double_click
		and _press_hit != null
		and _destination_fleet == null
		and _press_fleet == null
	):
		_select_star(_press_hit)
		camera_rig.focus_on(
			_press_hit.global_position, _focus_distance_for(_press_hit)
		)
		_ignore_release = true


func _on_mouse_motion(event: InputEventMouseMotion) -> void:
	if not _press_active:
		return

	if not _drag_active:
		if (event.position - _press_position).length() < DRAG_THRESHOLD:
			return
		_drag_active = true
		_press_hit = null
		_press_fleet = null
		_ignore_release = false
		Input.set_default_cursor_shape(Input.CURSOR_DRAG)

	camera_rig.orbit_by_screen_delta(event.relative)


func _on_left_released() -> void:
	_press_active = false

	if _drag_active:
		_drag_active = false
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		return

	if _ignore_release:
		_ignore_release = false
		return

	if _destination_fleet != null:
		if _press_hit != null:
			_choose_destination_star(_press_hit)
		_press_hit = null
		_press_fleet = null
		return

	if _press_fleet != null:
		var fleet := _press_fleet.fleet
		_press_fleet = null
		_press_hit = null
		_on_fleet_selected(fleet)
		return

	if _press_hit != null:
		_select_star(_press_hit)
	else:
		_clear_selection()
	_press_hit = null
	_press_fleet = null


func _select_star(star: StarNode) -> void:
	if star == null:
		return

	if _selected_star == star:
		_show_star_panel(star)
		return

	_selected_star = star
	for node in _star_nodes:
		node.set_selected(node == star)
	_show_star_panel(star)


func _show_star_panel(star: StarNode) -> void:
	var distance_from_home := 0.0
	if _galaxy != null and _home_star != null:
		distance_from_home = _galaxy.distance_between(star.data, _home_star)
	star_panel.show_star(star.data, distance_from_home, revealed_resources)


## Debug/test hook for surveying a system before the full discovery system.
## Exploration surveys systems automatically when fleets arrive.
func _on_scan_requested(data: StarData) -> void:
	if data == null or _galaxy == null:
		return

	data.surveyed = true
	var distance_from_home := 0.0
	if _home_star != null and data != _home_star:
		distance_from_home = _galaxy.distance_between(data, _home_star)

	print("Scanned %s | %d planets" % [data.display_name, data.planets.size()])
	star_panel.show_star(data, distance_from_home, revealed_resources)


func _on_system_view_requested(data: StarData) -> void:
	if data == null or not data.surveyed:
		return

	if _system_view == null:
		_system_view = SYSTEM_VIEW_SCENE.instantiate() as SystemView
		add_child(_system_view)
	_system_view.open(data)


func _on_technologies_requested() -> void:
	if _tech_tree == null:
		_tech_tree = TECH_TREE_SCENE.instantiate() as TechTree
		add_child(_tech_tree)
	_tech_tree.open(research_data)


func _on_shipyard_requested(data: StarData) -> void:
	if data == null or not data.has_shipyard():
		return

	if _shipyard == null:
		_shipyard = SHIPYARD_SCENE.instantiate() as ShipyardView
		if _shipyard == null:
			return
		add_child(_shipyard)
		_shipyard.closed.connect(_on_shipyard_closed)
	if data.resources == null:
		data.resources = ResourceStockpile.new()
	_shipyard.open(data, _galaxy, data.resources)


func _on_shipyard_closed() -> void:
	_rebuild_fleet_markers()
	if _selected_star != null:
		_show_star_panel(_selected_star)


func _on_fleet_selected(fleet: FleetData) -> void:
	if fleet == null:
		return
	_ensure_fleet_dialog()
	if _fleet_dialog == null:
		return
	_fleet_dialog.open_menu(fleet)


func _ensure_fleet_dialog() -> void:
	if _fleet_dialog != null:
		return
	_fleet_dialog = FLEET_DIALOG_SCENE.instantiate() as FleetDialog
	if _fleet_dialog == null:
		return
	add_child(_fleet_dialog)
	_fleet_dialog.destination_requested.connect(_on_destination_requested)
	_fleet_dialog.destination_confirmed.connect(_on_destination_confirmed)
	_fleet_dialog.confirmation_cancelled.connect(
		_on_destination_confirmation_cancelled
	)


func _on_destination_requested(fleet: FleetData) -> void:
	if fleet == null or fleet.in_transit:
		return
	_destination_fleet = fleet
	star_panel.hide_panel(true)
	_set_status(
		"Select a destination for %s — click a star. Esc cancels." % fleet.name,
		STATUS_PROMPT_COLOR
	)


func _on_destination_confirmation_cancelled() -> void:
	if _destination_fleet == null:
		return
	_set_status(
		"Select a destination for %s — click a star. Esc cancels."
		% _destination_fleet.name,
		STATUS_PROMPT_COLOR
	)


func _choose_destination_star(star: StarNode) -> void:
	if _destination_fleet == null or star == null:
		return

	var fleet := _destination_fleet
	if not fleet.in_transit and star.data.id == fleet.system_id:
		_set_status(
			"%s is already at %s." % [fleet.name, star.data.display_name],
			STATUS_INFO_COLOR
		)
		return

	var distance := fleet.position_ly.distance_to(star.data.position_ly)
	var turns := fleet.turns_to_position(star.data.position_ly)
	if turns <= 0:
		_set_status("That destination is not reachable.", STATUS_INFO_COLOR)
		return

	_ensure_fleet_dialog()
	if _fleet_dialog == null:
		return
	_fleet_dialog.show_confirmation(fleet, star.data, distance, turns)


func _on_destination_confirmed(fleet: FleetData, destination: StarData) -> void:
	if fleet == null or destination == null:
		return

	var distance := fleet.position_ly.distance_to(destination.position_ly)
	if distance <= 0.0:
		_set_status(
			"%s is already at %s." % [fleet.name, destination.display_name],
			STATUS_INFO_COLOR
		)
		_cancel_destination_selection("")
		return

	fleet.begin_travel(destination)
	_destination_fleet = null
	_rebuild_fleet_markers()
	_rebuild_fleet_courses()
	_set_status(
		"%s set course for %s — %d turns at %.0f ly/turn."
		% [
			fleet.name,
			destination.display_name,
			fleet.route_turns_total,
			fleet.route_speed_ly_per_turn,
		],
		STATUS_INFO_COLOR
	)
	if _selected_star != null:
		_show_star_panel(_selected_star)


func _cancel_destination_selection(message: String) -> void:
	_destination_fleet = null
	if _fleet_dialog != null and _fleet_dialog.visible:
		_fleet_dialog.close()
	if not message.is_empty():
		_set_status(message, STATUS_INFO_COLOR)
	if _selected_star != null:
		_show_star_panel(_selected_star)


func _on_end_turn_pressed() -> void:
	if turn_manager.is_ending_turn():
		turn_manager.cancel_end_turn()
	else:
		turn_manager.start_end_turn()


func _on_end_turn_started(seconds_left: float) -> void:
	end_turn_button.text = "Cancel End Turn"
	end_turn_button.tooltip_text = "Cancel ending the turn"
	turn_countdown_label.visible = true
	_set_countdown_text(seconds_left)


func _on_end_turn_countdown_changed(seconds_left: float) -> void:
	if not turn_countdown_label.visible:
		return
	_set_countdown_text(seconds_left)


func _on_end_turn_cancelled() -> void:
	_reset_end_turn_ui()


func _on_turn_advanced(turn: int) -> void:
	turn_label.text = _turn_text(turn)
	_reset_end_turn_ui()
	_advance_fleets()


func _set_countdown_text(seconds_left: float) -> void:
	var seconds := maxi(1, ceili(seconds_left))
	turn_countdown_label.text = "Ending turn in %d..." % seconds


func _reset_end_turn_ui() -> void:
	end_turn_button.text = "End Turn"
	end_turn_button.tooltip_text = "End the turn after the countdown"
	turn_countdown_label.visible = false


func _turn_text(turn: int) -> String:
	return "Turn %d" % turn


func _set_status(message: String, color: Color = STATUS_INFO_COLOR) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", color)


func _advance_fleets() -> void:
	if _galaxy == null:
		return

	var arrivals: Array[String] = []
	var any_moved := false
	var panel_changed := false

	for star in _galaxy.stars:
		for fleet_data in star.fleets.duplicate():
			var fleet: FleetData = fleet_data
			if not fleet.in_transit:
				continue
			var destination := _star_by_id(fleet.destination_id)
			if destination == null:
				continue

			var arrived: bool = fleet.advance_travel_turn()
			any_moved = true
			if arrived:
				var probe_destroyed := fleet.ships.has("FTL Probe")
				var fleet_destroyed := _complete_fleet_arrival(
					star, fleet, destination
				)
				arrivals.append(
					_arrival_notice(
						fleet, destination, probe_destroyed, fleet_destroyed
					)
				)
				if _fleet_dialog != null:
					_fleet_dialog.close_if_showing_fleet(fleet)
				panel_changed = true

	if any_moved:
		_rebuild_fleet_markers()
		_rebuild_fleet_courses()
		if panel_changed and _selected_star != null:
			_show_star_panel(_selected_star)
		if panel_changed and _shipyard != null and _shipyard.visible:
			_shipyard.refresh()

	if not arrivals.is_empty():
		_set_status(arrivals[-1], STATUS_SUCCESS_COLOR)


func _complete_fleet_arrival(
	origin: StarData, fleet: FleetData, destination: StarData
) -> bool:
	if origin != null:
		origin.fleets.erase(fleet)

	fleet.remove_one_ship("FTL Probe")
	var fleet_destroyed := fleet.ships.is_empty()
	if fleet_destroyed:
		fleet.clear_route()
		fleet.in_transit = false
	else:
		if not destination.fleets.has(fleet):
			destination.fleets.append(fleet)
		fleet.dock_at(destination)

	destination.surveyed = true
	return fleet_destroyed


func _arrival_notice(
	fleet: FleetData,
	destination: StarData,
	probe_destroyed: bool,
	fleet_destroyed: bool
) -> String:
	var status := "%s arrived at %s" % [
		fleet.name, destination.display_name
	]
	if probe_destroyed:
		status += " — an FTL Probe was destroyed"
		if fleet_destroyed:
			status += " and the fleet was disbanded"

	var count := destination.planets.size()
	if count == 0:
		return status + "; no planets detected."

	var types: Array[String] = []
	for planet in destination.planets:
		types.append(planet.class_name_label())
	var noun := "planet" if count == 1 else "planets"
	return status + "; system surveyed: %d %s (%s)." % [
		count,
		noun,
		", ".join(types),
	]


func _star_by_id(star_id: String) -> StarData:
	if _galaxy == null:
		return null
	for star in _galaxy.stars:
		if star.id == star_id:
			return star
	return null


func _build_fleet_course_layer() -> void:
	_course_mesh = ImmediateMesh.new()
	_course_material = StandardMaterial3D.new()
	_course_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_course_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_course_material.albedo_color = Color(0.5, 0.83, 1.0, 0.9)
	_course_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_course_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_course_material.no_depth_test = true

	_course_instance = MeshInstance3D.new()
	_course_instance.name = "FleetCourseLines"
	_course_instance.mesh = _course_mesh
	_course_instance.material_override = _course_material
	_course_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fleet_courses_root.add_child(_course_instance)


func _rebuild_fleet_courses() -> void:
	if _course_mesh == null:
		return
	_course_mesh.clear_surfaces()

	var surface_started := false
	for star in _galaxy.stars:
		for fleet in star.fleets:
			if not fleet.in_transit:
				continue
			if not surface_started:
				_course_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _course_material)
				surface_started = true
			_add_course_dashes(
				GalaxyScale.to_world(fleet.route_origin_ly),
				GalaxyScale.to_world(fleet.route_destination_ly)
			)

	if surface_started:
		_course_mesh.surface_end()


func _add_course_dashes(from: Vector3, to: Vector3) -> void:
	var span := to - from
	var length := span.length()
	if length <= 0.001:
		return
	var direction := span / length
	var side := direction.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	side = side.normalized() * COURSE_HALF_WIDTH

	var cursor := 0.0
	while cursor < length:
		var dash_end := minf(cursor + COURSE_DASH_LENGTH, length)
		var start_point := from + direction * cursor
		var end_point := from + direction * dash_end
		_course_mesh.surface_add_vertex(start_point - side)
		_course_mesh.surface_add_vertex(start_point + side)
		_course_mesh.surface_add_vertex(end_point + side)
		_course_mesh.surface_add_vertex(start_point - side)
		_course_mesh.surface_add_vertex(end_point + side)
		_course_mesh.surface_add_vertex(end_point - side)
		cursor += COURSE_DASH_LENGTH + COURSE_GAP_LENGTH


func _rebuild_fleet_markers() -> void:
	for marker in _fleet_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	_fleet_markers.clear()

	if _galaxy == null:
		return

	for star in _galaxy.stars:
		for fleet in star.fleets:
			if fleet.in_transit:
				_add_fleet_marker(
					fleet, GalaxyScale.to_world(fleet.position_ly)
				)


func _add_fleet_marker(fleet: FleetData, world_position: Vector3) -> void:
	var marker := FleetMarker.new()
	fleets_root.add_child(marker)
	marker.setup(fleet, world_position)
	_fleet_markers.append(marker)


func _is_overlay_open() -> bool:
	return (
		(_system_view != null and _system_view.visible)
		or (_tech_tree != null and _tech_tree.visible)
		or (_shipyard != null and _shipyard.visible)
		or (_fleet_dialog != null and _fleet_dialog.visible)
	)


func _clear_selection() -> void:
	if _selected_star != null:
		_selected_star = null
		for node in _star_nodes:
			node.set_selected(false)
	star_panel.hide_panel()


func _focus_distance_for(star: StarNode) -> float:
	return clampf(star.data.visual_radius * 18.0, 30.0, 50.0)


func _star_under_mouse() -> StarNode:
	return _star_under_position(get_viewport().get_mouse_position())


func _fleet_under_mouse() -> FleetMarker:
	return _fleet_under_position(get_viewport().get_mouse_position())


func _fleet_under_position(screen_position: Vector2) -> FleetMarker:
	if _fleet_markers.is_empty():
		return null

	var camera := camera_rig.camera
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)

	var query := PhysicsRayQueryParameters3D.create(
		origin, origin + direction * RAY_LENGTH, FLEET_COLLISION_LAYER
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null

	var collider := hit.get("collider") as Node
	if collider == null:
		return null
	return collider.get_parent() as FleetMarker


func _star_under_position(screen_position: Vector2) -> StarNode:
	var camera := camera_rig.camera
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)

	var query := PhysicsRayQueryParameters3D.create(
		origin, origin + direction * RAY_LENGTH, STAR_COLLISION_LAYER
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null

	var collider := hit.get("collider") as Node
	if collider == null:
		return null
	return collider.get_parent() as StarNode


func _update_hover_cursor() -> void:
	if _drag_active:
		return

	var mouse := get_viewport().get_mouse_position()
	if technologies_button.get_global_rect().has_point(mouse):
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
		return
	var hovered_button := get_viewport().gui_get_hovered_control() as BaseButton
	if hovered_button != null and not hovered_button.disabled:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
		return
	if star_panel.visible and star_panel.get_global_rect().has_point(mouse):
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		return

	var fleet := _fleet_under_mouse()
	if fleet != null:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
		return

	var star := _star_under_mouse()
	Input.set_default_cursor_shape(
		Input.CURSOR_POINTING_HAND if star != null else Input.CURSOR_ARROW
	)


func _build_reference_grid() -> void:
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.28, 0.44, 0.66, 0.085)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var grid_y := -0.05
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)

	for ring_ly in GRID_RINGS_LY:
		var ring_radius := ring_ly * GalaxyScale.WORLD_UNITS_PER_LY
		for segment in GRID_SEGMENTS:
			var a1 := TAU * float(segment) / GRID_SEGMENTS
			var a2 := TAU * float(segment + 1) / GRID_SEGMENTS
			mesh.surface_add_vertex(
				Vector3(cos(a1), 0.0, sin(a1)) * ring_radius + Vector3(0.0, grid_y, 0.0)
			)
			mesh.surface_add_vertex(
				Vector3(cos(a2), 0.0, sin(a2)) * ring_radius + Vector3(0.0, grid_y, 0.0)
			)

	var inner_radius := GRID_INNER_LY * GalaxyScale.WORLD_UNITS_PER_LY
	var outer_radius := GalaxyScale.WORLD_RADIUS
	for spoke in GRID_SPOKES:
		var angle := TAU * float(spoke) / GRID_SPOKES
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		mesh.surface_add_vertex(direction * inner_radius + Vector3(0.0, grid_y, 0.0))
		mesh.surface_add_vertex(direction * outer_radius + Vector3(0.0, grid_y, 0.0))

	mesh.surface_end()

	var grid := MeshInstance3D.new()
	grid.name = "ReferenceGrid"
	grid.mesh = mesh
	grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grid)
