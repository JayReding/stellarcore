class_name CameraRig
extends Node3D
## Orbiting strategy camera driven by mouse drag and wheel zoom.

const MIN_DISTANCE := 20.0
const MAX_DISTANCE := 220.0
const PAN_LIMIT := 80.0
const MIN_ELEVATION := 14.0
const MAX_ELEVATION := 86.0
const ZOOM_STEP := 1.13
const ORBIT_SENSITIVITY := 0.22
const TILT_SENSITIVITY := 0.16
const FOCUS_ELEVATION := 55.0
const LOOK_TARGET_LIFT := -8.0

@onready var camera: Camera3D = $Camera3D

var focus_point := Vector3.ZERO
var azimuth := 32.0
var elevation := 48.0
var distance := 120.0

var _focus_tween: Tween


func _ready() -> void:
	_update_camera()


func _process(_delta: float) -> void:
	_update_camera()


func orbit_by_screen_delta(delta: Vector2) -> void:
	_cancel_focus_tween()

	azimuth -= delta.x * ORBIT_SENSITIVITY
	elevation = clampf(
		elevation - delta.y * TILT_SENSITIVITY, MIN_ELEVATION, MAX_ELEVATION
	)


func zoom(direction: int) -> void:
	_cancel_focus_tween()
	distance = clampf(distance / pow(ZOOM_STEP, direction), MIN_DISTANCE, MAX_DISTANCE)


func focus_on(target: Vector3, target_distance: float) -> void:
	_cancel_focus_tween()

	var destination := Vector3(
		clampf(target.x, -PAN_LIMIT, PAN_LIMIT),
		0.0,
		clampf(target.z, -PAN_LIMIT, PAN_LIMIT)
	)
	var new_distance := clampf(target_distance, MIN_DISTANCE, MAX_DISTANCE)

	_focus_tween = create_tween()
	_focus_tween.set_parallel(true)
	_focus_tween.set_trans(Tween.TRANS_CUBIC)
	_focus_tween.set_ease(Tween.EASE_IN_OUT)
	_focus_tween.tween_property(self, "focus_point", destination, 0.65)
	_focus_tween.tween_property(self, "distance", new_distance, 0.65)
	_focus_tween.tween_property(self, "elevation", FOCUS_ELEVATION, 0.65)


func _cancel_focus_tween() -> void:
	if _focus_tween != null and _focus_tween.is_running():
		_focus_tween.kill()
	_focus_tween = null


func _update_camera() -> void:
	var elev := deg_to_rad(elevation)
	var az := deg_to_rad(azimuth)
	var offset := Vector3(
		cos(elev) * sin(az),
		sin(elev),
		cos(elev) * cos(az)
	) * distance

	camera.global_position = focus_point + offset
	camera.look_at(focus_point + Vector3(0.0, LOOK_TARGET_LIFT, 0.0), Vector3.UP)
