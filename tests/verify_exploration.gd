extends SceneTree
## Verifies fleet selection, the fleet-action dialog, destination selection,
## course confirmation, travel across turns, and arrival-driven surveying.
## Run with:
##   godot --headless --path . --script res://tests/verify_exploration.gd

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := preload("res://scenes/stellar_view.tscn").instantiate()
	scene.galaxy_seed = 424242
	root.add_child(scene)
	await process_frame
	await process_frame

	var home: StarData = scene._galaxy.home_star()
	var home_node: StarNode
	for node in scene._star_nodes:
		if node.data == home:
			home_node = node
			break
	_check(home_node != null, "Home star node exists")
	if home_node == null:
		_finish()
		return

	var fleet := FleetData.new()
	fleet.name = "Newhome Alpha"
	fleet.add_ship("FTL Probe")
	fleet.dock_at(home)
	home.fleets.append(fleet)
	scene._rebuild_fleet_markers()

	_check(
		scene._fleet_markers.is_empty(),
		"Docked fleets do not clutter the map with markers"
	)
	_check(
		is_equal_approx(fleet.speed_ly_per_turn(), 10.0),
		"An FTL Probe travels 10 light years per turn"
	)
	_check(fleet.position_ly == home.position_ly, "A docked fleet starts at its system")
	_check(not fleet.in_transit, "A new fleet is not in transit")

	scene._select_star(home_node)
	await process_frame
	var panel: StarInfoPanel = scene.star_panel
	_check(panel.fleet_list.get_child_count() == 1, "Fleet Command lists the fleet")
	if panel.fleet_list.get_child_count() != 1:
		_finish()
		return

	var fleet_row := panel.fleet_list.get_child(0) as Button
	_check(fleet_row != null, "Fleet Command rows are clickable")
	if fleet_row == null:
		_finish()
		return
	_check(
		fleet_row.tooltip_text.contains("Newhome Alpha"),
		"Fleet row identifies the fleet"
	)

	fleet_row.pressed.emit()
	await process_frame

	var dialog: FleetDialog = scene._fleet_dialog
	_check(dialog != null, "Clicking a fleet opens the fleet dialog")
	if dialog == null:
		_finish()
		return
	_check(dialog.visible, "Fleet dialog is visible")
	_check(scene._is_overlay_open(), "Fleet dialog blocks Stellar View input")
	_check(dialog.fleet_name_label.text == "Newhome Alpha", "Dialog names the fleet")
	_check(
		dialog.set_destination_button.text == "Set Fleet Destination",
		"Set Fleet Destination is present"
	)
	_check(dialog.rename_button.text == "Rename Fleet", "Rename Fleet is present")
	_check(dialog.modify_button.text == "Modify Fleet", "Modify Fleet is present")
	_check(dialog.delete_button.text == "Delete Fleet", "Delete Fleet is present")
	_check(not dialog.set_destination_button.disabled, "Set Destination is available")
	_check(dialog.rename_button.disabled, "Rename is not implemented yet")
	_check(dialog.modify_button.disabled, "Modify is not implemented yet")
	_check(dialog.delete_button.disabled, "Delete is not implemented yet")
	var delete_color := dialog.delete_button.get_theme_color("font_disabled_color")
	_check(
		delete_color.r > 0.8 and delete_color.g < 0.6,
		"Delete Fleet uses red text"
	)

	var destination: StarData
	var destination_distance := -1.0
	for star in scene._galaxy.stars:
		if star.surveyed:
			continue
		var distance := home.position_ly.distance_to(star.position_ly)
		if distance > destination_distance:
			destination = star
			destination_distance = distance
	_check(destination != null, "An unsurveyed destination exists")
	if destination == null:
		_finish()
		return
	_check(not destination.surveyed, "Destination starts unsurveyed")

	var destination_node: StarNode
	for node in scene._star_nodes:
		if node.data == destination:
			destination_node = node
			break
	_check(destination_node != null, "Destination star node exists")
	if destination_node == null:
		_finish()
		return

	var expected_turns := ceili(
		destination_distance / FleetData.FTL_PROBE_SPEED_LY_PER_TURN
	)
	var turn_word := "turn" if expected_turns == 1 else "turns"

	dialog.set_destination_button.pressed.emit()
	await process_frame
	_check(not dialog.visible, "Choosing Set Destination closes the menu")
	_check(scene._destination_fleet == fleet, "Destination selection targets the fleet")
	_check(
		not panel.visible,
		"The system panel is hidden while choosing a destination"
	)
	_check(
		scene.status_label.text.contains("Select a destination"),
		"The status line prompts for a destination star"
	)

	scene._choose_destination_star(destination_node)
	await process_frame
	_check(dialog.visible, "Choosing a star opens the confirmation dialog")
	_check(dialog.confirmation.visible, "Confirmation section is shown")
	_check(not dialog.menu.visible, "Fleet action menu is hidden in confirmation")
	_check(
		dialog.destination_name_label.text == destination.display_name,
		"Confirmation names the destination"
	)
	_check(
		dialog.turns_value.text == "%d %s" % [expected_turns, turn_word],
		"Confirmation shows the required turns"
	)
	_check(
		dialog.confirm_button.text == "Confirm Destination",
		"Confirmation has a confirm button"
	)
	_check(not dialog.confirm_button.disabled, "Confirmation can be accepted")

	dialog.confirmation_back_button.pressed.emit()
	await process_frame
	_check(not dialog.visible, "Back closes the confirmation dialog")
	_check(
		scene._destination_fleet == fleet,
		"Back returns to destination selection"
	)
	_check(
		scene.status_label.text.contains("Select a destination"),
		"Back restores the destination prompt"
	)

	scene._choose_destination_star(destination_node)
	await process_frame
	dialog.confirm_button.pressed.emit()
	await process_frame

	_check(not dialog.visible, "Confirming closes the dialog")
	_check(fleet.in_transit, "Confirming sends the fleet into transit")
	_check(
		fleet.destination_id == destination.id,
		"The fleet remembers its destination"
	)
	_check(
		fleet.route_turns_total == expected_turns,
		"The route uses the confirmed travel time"
	)
	_check(
		is_equal_approx(fleet.route_speed_ly_per_turn, 10.0),
		"The route records the fleet speed"
	)
	_check(scene._destination_fleet == null, "Destination selection mode ends")
	_check(
		scene.status_label.text.contains("set course"),
		"The status line announces the departure"
	)
	_check(
		scene._course_mesh.get_surface_count() == 1,
		"A dashed course line is drawn"
	)
	_check(scene._fleet_markers.size() == 1, "A transit marker is created")
	if scene._fleet_markers.size() == 1:
		var marker: FleetMarker = scene._fleet_markers[0]
		_check(marker.fleet == fleet, "The transit marker belongs to the fleet")
		_check(
			marker._label.text == fleet.name,
			"The transit marker shows only the fleet name"
		)
		_check(
			marker.get_node_or_null("PickBody") != null,
			"The fleet marker is clickable"
		)
	_check(
		panel.fleet_list.get_child_count() == 0,
		"In-transit fleets leave Fleet Command"
	)
	_check(panel.no_fleets_label.visible, "Fleet Command reports no stationed fleets")

	scene._on_fleet_selected(fleet)
	await process_frame
	_check(dialog.visible, "An in-transit fleet can be opened from its marker")
	_check(
		dialog.set_destination_button.disabled,
		"An in-transit fleet cannot receive a new destination"
	)
	_check(
		dialog.fleet_meta_label.text.contains("In transit"),
		"The dialog reports the fleet's transit state"
	)
	dialog.close_button.pressed.emit()
	await process_frame
	_check(not dialog.visible, "The fleet dialog closes")

	var turns_to_check := maxi(expected_turns - 1, 0)
	for i in turns_to_check:
		scene.turn_manager.advance_turn()
		await process_frame
		_check(fleet.in_transit, "The fleet remains in transit before arrival")

	scene._on_fleet_selected(fleet)
	await process_frame
	_check(dialog.visible, "The in-transit fleet dialog can remain open")

	scene.turn_manager.advance_turn()
	await process_frame
	_check(not dialog.visible, "Arrival closes the destroyed fleet's dialog")

	_check(not fleet.in_transit, "The fleet completes its course")
	_check(destination.surveyed, "Arrival surveys the destination")
	_check(fleet.ships.is_empty(), "The arriving FTL Probe is destroyed")
	_check(not home.fleets.has(fleet), "The destroyed fleet leaves its origin system")
	_check(
		not destination.fleets.has(fleet),
		"A fleet with no remaining ships is deleted"
	)
	_check(
		scene._course_mesh.get_surface_count() == 0,
		"The course line is removed on arrival"
	)
	_check(
		scene._fleet_markers.is_empty(),
		"The fleet marker disappears after arrival"
	)
	_check(
		scene.status_label.text.contains("arrived at"),
		"The status line announces the arrival"
	)
	_check(
		scene.status_label.text.contains("FTL Probe was destroyed"),
		"The arrival notice reports the probe destruction"
	)
	_check(
		scene.status_label.text.contains("fleet was disbanded"),
		"The arrival notice reports the fleet deletion"
	)
	_check(
		scene.status_label.text.contains(
			"system surveyed: %d" % destination.planets.size()
		),
		"The arrival notice reports the planet count"
	)
	if not destination.planets.is_empty():
		_check(
			scene.status_label.text.contains(
				destination.planets[0].class_name_label()
			),
			"The arrival notice reports planet types"
		)

	scene._select_star(destination_node)
	await process_frame
	_check(panel.planet_list.visible, "The surveyed arrival system shows planets")
	_check(
		panel.planet_count_label.text == "%d planets" % destination.planets.size(),
		"The arrival system reports its planet count"
	)
	_check(not panel.scan_button.visible, "A surveyed system hides Scan")
	_check(
		panel.fleet_list.get_child_count() == 0,
		"The destroyed fleet is removed from Fleet Command"
	)
	_check(panel.no_fleets_label.visible, "Fleet Command reports no surviving fleets")
	_check(
		scene._galaxy.next_fleet_name("Newhome") == "Newhome Alpha",
		"The destroyed fleet's name is available again"
	)

	scene._on_shipyard_requested(home)
	await process_frame
	var shipyard: ShipyardView = scene._shipyard
	_check(shipyard != null and shipyard.visible, "The shipyard opens after the loss")
	if shipyard != null:
		shipyard.produce_button.pressed.emit()
		_check(home.fleets.size() == 1, "A replacement fleet can be produced")
		if home.fleets.size() == 1:
			_check(
				home.fleets[0].name == "Newhome Alpha",
				"The shipyard reuses the destroyed fleet's name"
			)
		shipyard.close()
		await process_frame

	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FAIL: " + message)


func _finish() -> void:
	if _failures == 0:
		print("Exploration verification: PASS")
		quit(0)
	else:
		print("Exploration verification: FAIL (%d checks)" % _failures)
		quit(1)
