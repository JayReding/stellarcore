extends Node3D
## Stellar View: procedural galaxy, camera navigation, and star selection.

const STAR_SCENE: PackedScene = preload("res://scenes/star.tscn")
const SYSTEM_VIEW_SCENE: PackedScene = preload("res://scenes/system_view.tscn")
const TECH_TREE_SCENE: PackedScene = preload("res://scenes/tech_tree.tscn")
const SHIPYARD_SCENE: PackedScene = preload("res://scenes/shipyard.tscn")
const STAR_COLLISION_LAYER := 2
const DRAG_THRESHOLD := 5.0
const HOVER_INTERVAL := 0.05
const RAY_LENGTH := 5000.0
const GRID_RINGS_LY: Array[float] = [15.0, 30.0, 45.0, 50.0]
const GRID_SPOKES := 12
const GRID_SEGMENTS := 96
const GRID_INNER_LY := 10.0

@export var star_count := 25
## Set to a non-zero value to reproduce a specific galaxy.
@export var galaxy_seed := 0

@onready var camera_rig: CameraRig = $CameraRig
@onready var stars_root: Node3D = $Stars
@onready var star_panel: StarInfoPanel = $UI/StarInfoPanel
@onready var seed_label: Label = $UI/HUD/SeedLabel
@onready var technologies_button: Button = $UI/HUD/TechnologiesButton
@onready var turn_manager: TurnManager = $TurnManager
@onready var turn_label: Label = $UI/HUD/TurnLabel
@onready var end_turn_button: Button = $UI/HUD/EndTurnButton
@onready var turn_countdown_label: Label = $UI/HUD/TurnCountdownLabel

var _galaxy: Galaxy
var _home_star: StarData
var _star_nodes: Array[StarNode] = []
var _selected_star: StarNode
var _system_view: SystemView
var _tech_tree: TechTree
var _shipyard: ShipyardView

var _press_active := false
var _drag_active := false
var _ignore_release := false
var _press_position := Vector2.ZERO
var _press_hit: StarNode
var _hover_timer := 0.0


func _ready() -> void:
	var seed_value := galaxy_seed
	if seed_value == 0:
		seed_value = randi() % 900000 + 100000

	_build_reference_grid()
	_spawn_galaxy(seed_value)
	star_panel.scan_requested.connect(_on_scan_requested)
	star_panel.system_view_requested.connect(_on_system_view_requested)
	star_panel.shipyard_requested.connect(_on_shipyard_requested)
	technologies_button.pressed.connect(_on_technologies_requested)
	turn_manager.turn_advanced.connect(_on_turn_advanced)
	turn_manager.end_turn_started.connect(_on_end_turn_started)
	turn_manager.end_turn_countdown_changed.connect(_on_end_turn_countdown_changed)
	turn_manager.end_turn_cancelled.connect(_on_end_turn_cancelled)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	turn_label.text = _turn_text(turn_manager.current_turn)
	_reset_end_turn_ui()

	seed_label.text = "GALAXY SEED  %06d   /   %d SYSTEMS   /   %d LY ACROSS" % [
		seed_value, _galaxy.stars.size(), int(GalaxyScale.DIAMETER_LY)
	]
	print(
		"Stellar Core | seed %d | %d systems | %d ly across"
		% [seed_value, _galaxy.stars.size(), int(GalaxyScale.DIAMETER_LY)]
	)


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
	_press_hit = _star_under_mouse()

	if event.double_click and _press_hit != null:
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

	if _press_hit != null:
		_select_star(_press_hit)
	else:
		_clear_selection()
	_press_hit = null


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
	star_panel.show_star(star.data, distance_from_home)


## Temporary debug hook: the Scan button reveals a system's generated planets.
func _on_scan_requested(data: StarData) -> void:
	if data == null or _galaxy == null:
		return

	data.surveyed = true
	var distance_from_home := 0.0
	if _home_star != null and data != _home_star:
		distance_from_home = _galaxy.distance_between(data, _home_star)

	print("Scanned %s | %d planets" % [data.display_name, data.planets.size()])
	star_panel.show_star(data, distance_from_home)


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
	_tech_tree.open()


func _on_shipyard_requested(data: StarData) -> void:
	if data == null or not data.has_shipyard():
		return

	if _shipyard == null:
		_shipyard = SHIPYARD_SCENE.instantiate() as ShipyardView
		if _shipyard == null:
			return
		add_child(_shipyard)
		_shipyard.closed.connect(_on_shipyard_closed)
	_shipyard.open(data)


func _on_shipyard_closed() -> void:
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


func _set_countdown_text(seconds_left: float) -> void:
	var seconds := maxi(1, ceili(seconds_left))
	turn_countdown_label.text = "Ending turn in %d..." % seconds


func _reset_end_turn_ui() -> void:
	end_turn_button.text = "End Turn"
	end_turn_button.tooltip_text = "End the turn after the countdown"
	turn_countdown_label.visible = false


func _turn_text(turn: int) -> String:
	return "Turn %d" % turn


func _is_overlay_open() -> bool:
	return (
		(_system_view != null and _system_view.visible)
		or (_tech_tree != null and _tech_tree.visible)
		or (_shipyard != null and _shipyard.visible)
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
