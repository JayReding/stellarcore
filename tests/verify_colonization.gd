extends SceneTree
## Verifies Colony Ship travel speed and automatic colonization on arrival.
## Run with:
##   godot --headless --path . --script res://tests/verify_colonization.gd

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

	# A Colony Ship flies alone so the arrival consumes the whole fleet.
	var fleet := FleetData.new()
	fleet.name = "Newhome Alpha"
	fleet.add_ship("Colony Ship")
	fleet.dock_at(home)
	home.fleets.append(fleet)
	scene._rebuild_fleet_markers()
	_check(
		is_equal_approx(fleet.speed_ly_per_turn(), 5.0),
		"A Colony Ship travels 5 light years per turn"
	)

	# Head for the nearest unsurveyed system that has planets to colonize.
	var destination: StarData
	var destination_distance := INF
	for star in scene._galaxy.stars:
		if star.surveyed or star.planets.is_empty() or star == home:
			continue
		var distance := home.position_ly.distance_to(star.position_ly)
		if distance < destination_distance:
			destination = star
			destination_distance = distance
	_check(destination != null, "An uncolonized destination with planets exists")
	if destination == null:
		_finish()
		return
	var expected_turns := maxi(ceili(destination_distance / 5.0), 1)

	# The destination dialog prices the slow voyage in turns.
	scene._select_star(home_node)
	await process_frame
	var panel: StarInfoPanel = scene.star_panel
	var fleet_row := panel.fleet_list.get_child(0) as Button
	_check(fleet_row != null, "Fleet Command lists the Colony Ship fleet")
	if fleet_row == null:
		_finish()
		return
	fleet_row.pressed.emit()
	await process_frame
	var menu: FleetMenu = scene._fleet_menu
	_check(menu != null and menu.visible, "Fleet orders popup opens")
	if menu == null:
		_finish()
		return
	menu.set_destination_button.pressed.emit()
	await process_frame
	_check(not menu.visible, "Set Destination dismisses the popup")

	var dialog: FleetDialog

	var destination_node: StarNode
	for node in scene._star_nodes:
		if node.data == destination:
			destination_node = node
			break
	_check(destination_node != null, "Destination star node exists")
	if destination_node == null:
		_finish()
		return

	scene._choose_destination_star(destination_node)
	await process_frame
	dialog = scene._fleet_dialog
	_check(dialog != null and dialog.visible, "Choosing a star opens confirmation")
	var turn_word := "turn" if expected_turns == 1 else "turns"
	_check(
		dialog.turns_value.text == "%d %s" % [expected_turns, turn_word],
		"Confirmation prices the Colony Ship voyage"
	)
	var research_before: int = scene.research_data
	dialog.confirm_button.pressed.emit()
	await process_frame
	_check(fleet.in_transit, "Confirming sends the Colony Ship into transit")
	_check(
		fleet.route_turns_total == expected_turns,
		"The route uses the Colony Ship travel time"
	)
	_check(
		is_equal_approx(fleet.route_speed_ly_per_turn, 5.0),
		"The route records the Colony Ship speed"
	)

	var turns_taken := 0
	for i in 60:
		if not fleet.in_transit:
			break
		scene.turn_manager.advance_turn()
		await process_frame
		turns_taken += 1
	_check(not fleet.in_transit, "The Colony Ship completes its course")
	_check(destination.surveyed, "Arrival surveys the destination")
	_check(destination.has_colony(), "Arrival founds a Colony")
	_check(
		destination.planets[0].has_structure(StructureData.COLONY),
		"The Colony lands on the system's first open planet"
	)
	_check(
		_colony_count(destination) == 1,
		"Arrival founds exactly one Colony"
	)
	_check(fleet.ships.is_empty(), "The Colony Ship is consumed by founding")
	_check(
		not home.fleets.has(fleet),
		"The consumed fleet leaves its origin system"
	)
	_check(
		not destination.fleets.has(fleet),
		"An empty arriving fleet is deleted"
	)
	_check(
		scene.status_label.text.contains("arrived at"),
		"The status line announces the arrival"
	)
	_check(
		scene.status_label.text.contains(
			"colony founded on %s" % destination.planets[0].designation
		),
		"The arrival notice reports the founded colony"
	)
	_check(
		scene.research_data == research_before + 25 + 5 * turns_taken + 5,
		"Arrival grants the survey bonus, home output, and arrival-turn Colony output"
	)

	# The new Colony produces like any other from the next turn.
	scene.turn_manager.advance_turn()
	await process_frame
	_check(
		destination.resources.titanium == 10,
		"The new Colony produces Titanium"
	)
	_check(
		destination.resources.helium_3 == 2,
		"The new Colony produces Helium 3"
	)
	_check(
		scene.research_data == research_before + 25 + 5 * turns_taken + 15,
		"Both colonies produce Research Data"
	)

	# A system that already has a Colony keeps the ship.
	var second := FleetData.new()
	second.name = "Newhome Alpha"
	second.add_ship("Colony Ship")
	second.dock_at(home)
	home.fleets.append(second)
	second.begin_travel(destination)
	for i in 60:
		if not second.in_transit:
			break
		scene.turn_manager.advance_turn()
		await process_frame
	_check(not second.in_transit, "The second Colony Ship arrives")
	_check(
		_colony_count(destination) == 1,
		"No second Colony is founded where one exists"
	)
	_check(
		second.ships == ["Colony Ship"],
		"The unneeded Colony Ship survives"
	)
	_check(
		destination.fleets.has(second),
		"The surviving fleet docks at the destination"
	)
	_check(
		not scene.status_label.text.contains("colony founded"),
		"The arrival notice reports no colony when one exists"
	)

	_finish()


func _colony_count(data: StarData) -> int:
	var total := 0
	for planet in data.planets:
		if planet == null:
			continue
		for structure in planet.structures:
			if structure != null and structure.type_id == StructureData.COLONY:
				total += 1
	return total


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FAIL: " + message)


func _finish() -> void:
	if _failures == 0:
		print("Colonization verification: PASS")
		quit(0)
	else:
		print("Colonization verification: FAIL (%d checks)" % _failures)
		quit(1)
