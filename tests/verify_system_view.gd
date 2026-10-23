extends SceneTree
## Verifies the System View entry points and close paths.
## Run with:
##   godot --headless --path . --script res://tests/verify_system_view.gd

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := preload("res://scenes/stellar_view.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var home: StarData = scene._galaxy.home_star()
	var panel: StarInfoPanel = scene.star_panel

	panel.show_star(home)
	_check(panel.planet_list.visible, "Home system exposes planets")
	_check(
		panel.planet_list.get_child_count() == home.planets.size(),
		"Home system lists every planet"
	)
	_check(not panel.scan_button.visible, "Home system hides Scan")
	_check(
		panel.find_child("SystemViewButton", true, false) == null,
		"System View button is removed"
	)
	var fleet_eyebrow := panel.find_child("FleetEyebrow", true, false) as Label
	_check(
		fleet_eyebrow != null and fleet_eyebrow.text == "FLEET COMMAND",
		"Fleet Command section is present"
	)
	_check(panel.fleet_list.get_child_count() == 0, "Fleet Command has no fleet rows")
	_check(panel.no_fleets_label.visible, "Fleet Command shows its empty state")
	_check(panel.no_fleets_label.text == "No fleets", "Fleet Command says no fleets")
	_check(panel.shipyard_button.visible, "Shipyard button is visible")
	_check(panel.shipyard_button.text == "Shipyard", "Shipyard button has the right label")

	var planet_row := panel.planet_list.get_child(0) as Button
	_check(planet_row != null, "Planet rows are clickable")
	if planet_row == null:
		_finish()
		return

	planet_row.pressed.emit()
	_check(scene._system_view != null, "System View is created from a planet row")
	_check(scene._system_view.visible, "Clicking a planet opens System View")

	var system_view: SystemView = scene._system_view
	_check(system_view.system_root.get_child_count() > 0, "System View builds 3D content")
	_check(
		system_view.system_viewport.msaa_3d == Viewport.MSAA_4X,
		"System View uses 4x MSAA"
	)
	system_view.back_button.pressed.emit()
	_check(not system_view.visible, "Back button closes System View")

	panel.show_star(home)
	planet_row = panel.planet_list.get_child(0) as Button
	planet_row.pressed.emit()
	_check(system_view.visible, "Clicking a planet reopens System View")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	system_view._unhandled_input(escape)
	_check(not system_view.visible, "Escape closes System View")

	var unsurveyed: StarData
	for star in scene._galaxy.stars:
		if not star.surveyed:
			unsurveyed = star
			break
	_check(unsurveyed != null, "Galaxy contains an unsurveyed system")
	if unsurveyed == null:
		_finish()
		return

	panel.show_star(unsurveyed)
	_check(not panel.planet_list.visible, "Unsurveyed systems hide the planet list")
	_check(not panel.scan_button.visible, "Unsurveyed systems hide Scan")
	scene._on_system_view_requested(unsurveyed)
	_check(not system_view.visible, "Unsurveyed systems cannot open System View")

	scene._on_scan_requested(unsurveyed)
	_check(unsurveyed.surveyed, "The debug survey marks the system surveyed")
	_check(panel.planet_list.visible, "Surveying reveals clickable planets")
	_check(not panel.scan_button.visible, "Surveyed systems hide Scan")

	planet_row = panel.planet_list.get_child(0) as Button
	_check(planet_row != null, "Scanned planets are clickable")
	if planet_row != null:
		planet_row.pressed.emit()
		_check(system_view.visible, "Clicking a scanned planet opens System View")

	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FAIL: " + message)


func _finish() -> void:
	if _failures == 0:
		print("System View verification: PASS")
		quit(0)
	else:
		print("System View verification: FAIL (%d checks)" % _failures)
		quit(1)
