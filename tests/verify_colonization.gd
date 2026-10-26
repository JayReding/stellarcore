extends SceneTree
## Verifies Colony Ship travel speed and player-chosen colonization on arrival:
## the arrival opens a planet picker, founding consumes the ship, dismissing
## postpones the choice, and settled systems keep later ships.
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

	# Head for the nearest unsurveyed multi-planet system so the player has a
	# real choice of colony site.
	var destination: StarData
	var destination_distance := INF
	for star in scene._galaxy.stars:
		if star.surveyed or star.planets.size() < 2 or star == home:
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
	_check(not fleet.in_transit, "Confirming stages orders instead of departing")
	_check(fleet.has_orders(), "Confirming stores the destination as orders")
	_check(
		fleet.ordered_destination_id == destination.id,
		"Orders name the destination"
	)
	_check(
		fleet.route_turns_total == 0,
		"No route is plotted before departure"
	)

	scene.turn_manager.advance_turn()
	await process_frame
	_check(fleet.in_transit, "The fleet departs when the turn advances")
	_check(
		fleet.destination_id == destination.id,
		"The departed fleet remembers its destination"
	)
	_check(
		fleet.route_turns_total == expected_turns,
		"The route uses the Colony Ship travel time"
	)
	_check(
		is_equal_approx(fleet.route_speed_ly_per_turn, 5.0),
		"The route records the Colony Ship speed"
	)

	var turns_taken := 1
	for i in 60:
		if not fleet.in_transit:
			break
		scene.turn_manager.advance_turn()
		await process_frame
		turns_taken += 1
	_check(not fleet.in_transit, "The Colony Ship completes its course")
	_check(destination.surveyed, "Arrival surveys the destination")
	_check(not destination.has_colony(), "Arrival does not found a Colony itself")
	_check(
		_colony_count(destination) == 0,
		"No Colony exists before the player chooses"
	)
	_check(
		fleet.ships == ["Colony Ship"],
		"The Colony Ship stays aboard until a planet is chosen"
	)
	_check(
		destination.fleets.has(fleet),
		"The arriving fleet docks with its colonists"
	)
	_check(
		scene.status_label.text.contains("colonists await a landing site"),
		"The arrival notice asks for a landing site"
	)
	var colony_dialog: ColonyDialog = scene._colony_dialog
	_check(
		colony_dialog != null and colony_dialog.visible,
		"Arrival opens the colony planet picker"
	)
	if colony_dialog == null:
		_finish()
		return
	_check(
		colony_dialog.colony_planet_list.get_child_count()
		== destination.planets.size(),
		"The picker lists every planet in the system"
	)
	_check(
		_has_planet_option(colony_dialog, destination.planets[1].designation),
		"The picker offers the second planet"
	)
	_check(
		scene.research_data == research_before + 25 + 5 * turns_taken,
		"Arrival grants the survey bonus and home output only"
	)


	# Dismissing the picker postpones the choice; selecting the fleet brings
	# it back.
	colony_dialog.close_button.pressed.emit()
	await process_frame
	_check(not colony_dialog.visible, "The picker can be dismissed")
	_check(
		_colony_count(destination) == 0,
		"Dismissing founds no Colony"
	)
	_check(
		fleet.ships == ["Colony Ship"],
		"The postponed Colony Ship survives"
	)
	_check(
		destination.fleets.has(fleet),
		"The postponed fleet stays docked"
	)
	_check(
		scene.status_label.text.contains("postponed"),
		"Dismissing explains how to choose later"
	)
	scene._on_fleet_selected(fleet)
	await process_frame
	_check(
		colony_dialog.visible,
		"Selecting the fleet reopens the picker"
	)

	# Founding on the chosen planet consumes the ship and its fleet.
	var choice := _planet_option(colony_dialog, destination.planets[1].designation)
	_check(choice != null, "The chosen planet has a button")
	if choice == null:
		_finish()
		return
	choice.pressed.emit()
	await process_frame
	_check(
		destination.planets[1].has_structure(StructureData.COLONY),
		"The Colony lands on the chosen planet"
	)
	_check(
		not destination.planets[0].has_structure(StructureData.COLONY),
		"Unchosen planets stay untouched"
	)
	_check(
		_colony_count(destination) == 1,
		"Founding creates exactly one Colony"
	)
	_check(fleet.ships.is_empty(), "The Colony Ship is consumed by founding")
	_check(
		not home.fleets.has(fleet),
		"The consumed fleet leaves its origin system"
	)
	_check(
		not destination.fleets.has(fleet),
		"An empty founding fleet is deleted"
	)
	_check(
		not colony_dialog.visible,
		"The picker closes once the Colony is founded"
	)
	_check(
		scene.status_label.text.contains(
			"Colony founded on %s (%s)." % [
				destination.planets[1].designation, destination.display_name
			]
		),
		"The status line reports the founded colony"
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
		scene.research_data == research_before + 25 + 5 * turns_taken + 10,
		"Both colonies produce Research Data"
	)

	# A system that already has a Colony keeps the ship with no popup.
	var second := FleetData.new()
	second.name = "Newhome Beta"
	second.add_ship("Colony Ship")
	second.dock_at(home)
	home.fleets.append(second)
	var research_before_second: int = scene.research_data
	second.begin_travel(destination)
	var second_turns := 0
	for i in 60:
		if not second.in_transit:
			break
		scene.turn_manager.advance_turn()
		await process_frame
		second_turns += 1
	_check(not second.in_transit, "The second Colony Ship arrives")
	_check(
		scene.research_data
		== research_before_second + 10 * second_turns,
		"Both colonies produce during the second voyage"
	)
	_check(
		_colony_count(destination) == 1,
		"No further Colony is founded where a colony exists"
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
		not colony_dialog.visible,
		"No picker opens where a colony already exists"
	)
	_check(
		not scene.status_label.text.contains("landing site"),
		"The arrival notice requests no choice when one is unneeded"
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


func _planet_option(dialog: ColonyDialog, designation: String) -> Button:
	for child in dialog.colony_planet_list.get_children():
		var button := child as Button
		if button != null and button.text.contains(designation):
			return button
	return null


func _has_planet_option(dialog: ColonyDialog, designation: String) -> bool:
	return _planet_option(dialog, designation) != null


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
