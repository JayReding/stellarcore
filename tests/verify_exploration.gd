extends SceneTree
## Verifies fleet selection, the fleet-action dialog, destination selection,
## course confirmation, travel across turns, and arrival-driven surveying.
## Run with:
##   godot --headless --path . --script res://tests/verify_exploration.gd

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
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
	_check(
		home_node.home_label.visible and home_node.home_label.text == "⭐ NEWHOME",
		"Newhome keeps its dedicated home label"
	)
	_check(
		not home_node.survey_label.visible,
		"Newhome does not duplicate its name with a survey label"
	)

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

	# Fleet orders arrive as a cursor popup, not a modal screen.
	var menu: FleetMenu = scene._fleet_menu
	_check(menu != null, "Clicking a fleet opens the orders popup")
	if menu == null:
		_finish()
		return
	_check(menu.visible, "The orders popup is visible")
	_check(scene._is_overlay_open(), "The Stellar View treats the popup as an overlay")
	var dialog: FleetDialog = scene._fleet_dialog
	_check(
		dialog == null or not dialog.visible,
		"No modal dialog appears for fleet orders"
	)
	_check(menu.fleet_name_label.text == "Newhome Alpha", "Popup names the fleet")
	_check(
		menu.set_destination_button.text == "Set Fleet Destination",
		"Set Fleet Destination is present"
	)
	_check(menu.rename_button.text == "Rename Fleet", "Rename Fleet is present")
	_check(menu.modify_button.text == "Modify Fleet", "Modify Fleet is present")
	_check(menu.delete_button.text == "Delete Fleet", "Delete Fleet is present")
	_check(not menu.set_destination_button.disabled, "Set Destination is available")
	_check(menu.rename_button.disabled, "Rename is not implemented yet")
	_check(menu.modify_button.disabled, "Modify is not implemented yet")
	_check(menu.delete_button.disabled, "Delete is not implemented yet")
	var delete_color := menu.delete_button.get_theme_color("font_disabled_color")
	_check(
		delete_color.r > 0.8 and delete_color.g < 0.6,
		"Delete Fleet uses red text"
	)

	# Clicking away dismisses the popup; right-clicking summons it back.
	var away_click := InputEventMouseButton.new()
	away_click.button_index = MOUSE_BUTTON_LEFT
	away_click.pressed = true
	away_click.position = Vector2(960, 540)
	menu.root.gui_input.emit(away_click)
	await process_frame
	_check(not menu.visible, "Clicking away closes the orders popup")

	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	fleet_row.gui_input.emit(right_click)
	await process_frame
	_check(menu.visible, "Right-clicking a fleet reopens the orders popup")

	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	menu._unhandled_input(escape)
	await process_frame
	_check(not menu.visible, "Escape closes the orders popup")

	fleet_row.pressed.emit()
	await process_frame
	_check(menu.visible, "The orders popup reopens")

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
	_check(
		not destination_node.survey_label.visible,
		"Unsurveyed systems do not show a survey label"
	)

	var expected_turns := ceili(
		destination_distance / FleetData.FTL_PROBE_SPEED_LY_PER_TURN
	)
	var turn_word := "turn" if expected_turns == 1 else "turns"

	menu.set_destination_button.pressed.emit()
	await process_frame
	_check(not menu.visible, "Choosing Set Destination closes the popup")
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
	dialog = scene._fleet_dialog
	_check(dialog != null, "Choosing a star opens the confirmation dialog")
	_check(dialog.visible, "The confirmation dialog is visible")
	_check(dialog.confirmation.visible, "Confirmation section is shown")
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

	# Confirming stages the orders: the fleet holds at its system and only
	# departs when the turn advances.
	_check(not dialog.visible, "Confirming closes the dialog")
	_check(not fleet.in_transit, "Confirming stages orders instead of departing")
	_check(fleet.has_orders(), "The fleet holds travel orders")
	_check(
		fleet.ordered_destination_id == destination.id,
		"The fleet remembers its ordered destination"
	)
	_check(
		fleet.route_turns_total == 0,
		"No route is plotted until departure"
	)
	_check(scene._destination_fleet == null, "Destination selection mode ends")
	_check(
		scene.status_label.text.contains("has orders for %s" % destination.display_name),
		"The status line announces the staged orders"
	)
	_check(
		scene.status_label.text.contains("departs when the turn advances"),
		"The status line notes the departure timing"
	)
	_check(
		panel.fleet_list.get_child_count() == 1,
		"A staged fleet stays on Fleet Command"
	)
	_check(
		scene._course_mesh.get_surface_count() == 0,
		"No course line is drawn before departure"
	)
	_check(
		scene._fleet_markers.is_empty(),
		"No transit marker appears before departure"
	)

	# The staged fleet offers cancellation instead of a new destination.
	fleet_row = panel.fleet_list.get_child(0) as Button
	_check(fleet_row != null, "The staged fleet stays listed")
	fleet_row.pressed.emit()
	await process_frame
	_check(menu.visible, "The staged fleet opens the orders popup")
	_check(not menu.set_destination_button.visible, "Staged fleets hide Set Fleet Destination")
	_check(menu.cancel_orders_button.visible, "Staged fleets offer Cancel Fleet Orders")
	_check(
		menu.fleet_meta_label.text.contains("Ordered for %s" % destination.display_name),
		"The popup names the ordered destination"
	)
	menu.cancel_orders_button.pressed.emit()
	await process_frame
	_check(not menu.visible, "Cancelling closes the popup")
	_check(not fleet.has_orders(), "Cancelling withdraws the orders")
	_check(not fleet.in_transit, "A cancelled fleet stays docked")
	_check(
		destination.fleets.has(fleet) or home.fleets.has(fleet),
		"A cancelled fleet keeps its station"
	)
	_check(
		scene.status_label.text.contains("cancelled"),
		"The status line confirms the cancellation"
	)

	# Reorder and let the turn advance depart the fleet for real.
	fleet_row = panel.fleet_list.get_child(0) as Button
	_check(fleet_row != null, "The cancelled fleet is still listed")
	fleet_row.pressed.emit()
	await process_frame
	menu.set_destination_button.pressed.emit()
	await process_frame
	scene._choose_destination_star(destination_node)
	await process_frame
	dialog.confirm_button.pressed.emit()
	await process_frame
	_check(fleet.has_orders(), "The fleet is ordered again")

	# A second departure advances together with the first, so both markers
	# coincide and share one stacked label.
	var second := FleetData.new()
	second.name = "Newhome Beta"
	second.add_ship("FTL Probe")
	second.dock_at(home)
	home.fleets.append(second)
	second.begin_travel(destination)

	scene.turn_manager.advance_turn()
	await process_frame
	_check(fleet.in_transit, "The fleet departs when the turn advances")
	_check(
		fleet.destination_id == destination.id,
		"The departed fleet remembers its destination"
	)
	_check(
		fleet.route_turns_total == expected_turns,
		"The route uses the confirmed travel time"
	)
	_check(
		is_equal_approx(fleet.route_speed_ly_per_turn, 10.0),
		"The route records the fleet speed"
	)
	_check(
		scene._course_mesh.get_surface_count() == 1,
		"A dashed course line is drawn on departure"
	)
	_check(scene._fleet_markers.size() == 2, "Both departures get markers")
	_check(
		scene._fleet_labels.size() == 1,
		"Coincident departures share a single label stack"
	)
	_check(
		_fleet_label_lines(scene) == ["Newhome Alpha", "Newhome Beta"],
		"Fleet names stack vertically in departure order"
	)
	if scene._fleet_labels.size() == 1:
		_check(
			(scene._fleet_labels[0] as Label3D).font_size == 22,
			"Stacked fleet labels use the smaller type size"
		)
		_check(
			_color_is_blue((scene._fleet_labels[0] as Label3D)),
			"Stacked fleet labels use blue text"
		)
	if scene._fleet_markers.size() >= 1:
		var marker: FleetMarker = scene._fleet_markers[0]
		_check(
			marker.fleet == fleet or marker.fleet.name == "Newhome Beta",
			"The transit marker belongs to a departed fleet"
		)
		_check(
			_fleet_label_lines(scene) == ["Newhome Alpha", "Newhome Beta"],
			"The stacked label shows both fleet names"
		)
		_check(
			marker.get_node_or_null("PickBody") != null,
			"The fleet marker is clickable"
		)
		var marker_screen: Vector2 = scene.camera_rig.camera.unproject_position(
			marker.global_position
		)
		var marker_click := InputEventMouseButton.new()
		marker_click.button_index = MOUSE_BUTTON_RIGHT
		marker_click.pressed = true
		marker_click.position = marker_screen
		root.push_input(marker_click)
		await process_frame
		_check(
			scene._fleet_menu.visible,
			"Right-clicking a marker opens the orders popup"
		)
		scene._fleet_menu.close()
		await process_frame
		_check(not scene._fleet_menu.visible, "The orders popup closes")

	_check(
		panel.fleet_list.get_child_count() == 0,
		"In-transit fleets leave Fleet Command"
	)
	_check(panel.no_fleets_label.visible, "Fleet Command reports no stationed fleets")

	scene._on_fleet_selected(fleet)
	await process_frame
	_check(menu.visible, "An in-transit fleet can be opened from its marker")
	_check(
		menu.set_destination_button.disabled,
		"An in-transit fleet cannot receive a new destination"
	)
	_check(
		menu.fleet_meta_label.text.contains("In transit"),
		"The popup reports the fleet's transit state"
	)
	menu.close()
	await process_frame
	_check(not menu.visible, "The orders popup closes")
	_check(
		not menu.cancel_orders_button.visible,
		"Departed fleets offer no cancellation"
	)

	var turns_to_check := maxi(expected_turns - 2, 0)
	for i in turns_to_check:
		scene.turn_manager.advance_turn()
		await process_frame
		_check(fleet.in_transit, "The fleet remains in transit before arrival")

	scene._on_fleet_selected(fleet)
	await process_frame
	_check(menu.visible, "The in-transit fleet popup can remain open")

	scene.turn_manager.advance_turn()
	await process_frame
	_check(not menu.visible, "Arrival closes the destroyed fleet's popup")

	_check(not fleet.in_transit, "The fleet completes its course")
	_check(destination.surveyed, "Arrival surveys the destination")
	_check(
		destination_node.survey_label.visible,
		"Arrival adds the survey label to the explored system"
	)
	_check(
		destination_node.survey_label.font_size == home_node.home_label.font_size,
		"Explored systems use the same label size as Newhome"
	)
	_check(
		destination_node.survey_label.text == destination.display_name,
		"The survey label shows the explored system's name"
	)
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
		_check(home.fleets.is_empty(), "Production queues instead of appearing")
		scene.turn_manager.advance_turn()
		await process_frame
		_check(home.fleets.size() == 1, "A replacement fleet is produced next turn")
		if home.fleets.size() == 1:
			_check(
				home.fleets[0].name == "Newhome Alpha",
				"The shipyard reuses the destroyed fleet's name"
			)
		shipyard.close()
		await process_frame

	# A lone label rides its marker instead of staying at the origin star.
	var rider := FleetData.new()
	rider.name = "Newhome Beta"
	rider.add_ship("FTL Probe")
	rider.dock_at(home)
	home.fleets.append(rider)
	rider.begin_travel(destination)
	scene.turn_manager.advance_turn()
	await process_frame
	var rider_marker: FleetMarker = null
	for marker in scene._fleet_markers:
		if (marker as FleetMarker).fleet == rider:
			rider_marker = marker
	_check(rider_marker != null, "The departing fleet gets a marker")
	if rider_marker != null and scene._fleet_labels.size() == 1:
		var stack := scene._fleet_labels[0] as Label3D
		_check(
			stack != null and stack.text.contains("Newhome Beta"),
			"The stack follows the departure"
		)
		_check(
			stack.position.distance_to(
				rider_marker.global_position + Vector3(3.2, 1.6, 0.0)
			) < 0.6,
			"The stack rides at the marker's side"
		)
		_check(
			stack.position.distance_to(
				GalaxyScale.to_world(home.position_ly)
			) > 2.0,
			"The stack leaves the origin star behind"
		)
	home.fleets.erase(rider)
	scene._rebuild_fleet_markers()
	await process_frame

	_finish()


func _fleet_label_lines(scene: Node) -> Array:
	for child in scene._fleet_labels:
		var label := child as Label3D
		if label != null:
			return Array(label.text.split("\n"))
	return []


func _color_is_blue(label: Label3D) -> bool:
	if label == null:
		return false
	return label.modulate.b > label.modulate.r


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
