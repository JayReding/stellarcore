extends SceneTree
## Verifies the Newhome III shipyard, hull selection, production, fleet naming,
## and the Fleet Command refresh path.
## Run with:
##   godot --headless --path . --script res://tests/verify_shipyard.gd

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
	var home_node: StarNode
	var other_node: StarNode
	for node in scene._star_nodes:
		if node.data == home:
			home_node = node
		elif other_node == null:
			other_node = node

	_check(home_node != null, "Home star node exists")
	_check(other_node != null, "A non-home star node exists")
	if home_node == null or other_node == null:
		_finish()
		return

	_check(home.shipyard_planet != null, "Newhome has a shipyard")
	if home.shipyard_planet != null:
		_check(
			home.shipyard_planet == home.planets[2],
			"Newhome III hosts the shipyard"
		)
		_check(
			home.shipyard_planet.designation == "Newhome III",
			"Shipyard planet is Newhome III"
		)
	for star in scene._galaxy.stars:
		if star != home:
			_check(star.shipyard_planet == null, "%s has no shipyard" % star.display_name)

	scene._select_star(home_node)
	_check(not panel.shipyard_button.disabled, "Shipyard button is enabled at Newhome")
	panel.shipyard_button.pressed.emit()

	var shipyard: ShipyardView = scene._shipyard
	_check(shipyard != null, "Shipyard view is created on demand")
	if shipyard == null:
		_finish()
		return
	_check(shipyard.visible, "Shipyard opens from the panel")
	_check(scene._is_overlay_open(), "Stellar View treats the shipyard as an overlay")

	_check(shipyard.hull_list.get_child_count() == 1, "Hull list has one hull type")
	if shipyard.hull_list.get_child_count() == 1:
		var hull_button := shipyard.hull_list.get_child(0) as Button
		_check(hull_button != null, "Hull type is a button")
		if hull_button != null:
			_check(hull_button.text == "FTL Probe", "The hull type is FTL Probe")
	_check(shipyard.hull_name_label.text == "FTL Probe", "Center shows FTL Probe")
	_check(
		shipyard.hull_time_value.text == "0.25 turns (4 per turn)",
		"The FTL Probe builds four to a turn"
	)
	_check(
		shipyard.hull_customization_value.text == "None",
		"FTL Probe has no customization"
	)
	_check(
		shipyard.no_options_label.text == "NO CUSTOMIZATION OPTIONS",
		"No-options state is explicit"
	)
	_check(
		shipyard.no_options_note.text.contains("no modules or variants"),
		"No-options explanation is present"
	)
	_check(shipyard.produce_button.text == "Add To Construction Queue", "Produce button has the right label")
	_check(
		not shipyard.produce_button.disabled,
		"Produce button is enabled while resources are sufficient"
	)
	var titanium_cost := _cost_label(shipyard, "Titanium")
	var antimatter_cost := _cost_label(shipyard, "Antimatter")
	_check(titanium_cost != null, "Cost readout lists Titanium")
	_check(antimatter_cost != null, "Cost readout lists Antimatter")
	if titanium_cost != null:
		_check(
			titanium_cost.text.contains("25"),
			"FTL Probe costs 25 Titanium"
		)
		_check(
			not _color_is_red(titanium_cost),
			"Affordable Titanium cost is not red"
		)
	if antimatter_cost != null:
		_check(
			antimatter_cost.text.contains("10"),
			"FTL Probe costs 10 Antimatter"
		)
		_check(
			not _color_is_red(antimatter_cost),
			"Affordable Antimatter cost is not red"
		)
	_check(
		shipyard.produce_button.get_parent() != null
		and shipyard.produce_button.get_parent().name == "ProduceRow",
		"Produce button sits in the middle column's right-aligned row"
	)
	_check(shipyard.meta_label.text.contains("NEWHOME III"), "Header shows Newhome III")
	_check(shipyard.meta_label.text.contains("0 FLEETS"), "Header shows the fleet count")
	_check(shipyard.no_fleets_label.visible, "Shipyard starts with no fleets")
	_check(not shipyard.fleet_scroll.visible, "Empty fleet list hides its scroll area")
	_check(shipyard.fleet_count_label.text == "0", "Fleet count starts at zero")
	_check(home.fleets.is_empty(), "Newhome starts with no fleet data")
	_check(shipyard.queue_list.get_child_count() == 0, "Shipyard starts with no queue")
	_check(
		shipyard.feedback_label.text.contains("newest fleet"),
		"Production hint explains the newest-fleet default"
	)

	# Producing queues the hull and spends its cost up front.
	shipyard.produce_button.pressed.emit()
	_check(home.resources.titanium == 175, "Queuing spends 25 Titanium")
	_check(home.resources.antimatter == 40, "Queuing spends 10 Antimatter")
	_check(home.fleets.is_empty(), "Queuing creates no fleet yet")
	_check(home.ship_queue.size() == 1, "Queuing adds one build to the queue")
	_check(
		shipyard.queue_list.get_child_count() == 1,
		"Queue list shows the queued build"
	)
	_check(
		shipyard.feedback_label.text.contains("Queued 1 FTL Probe"),
		"Queue feedback names the hull"
	)

	# A quarter-turn hull completes on the next turn into a new fleet.
	scene.turn_manager.advance_turn()
	await process_frame
	_check(home.ship_queue.is_empty(), "The finished build leaves the queue")
	_check(home.fleets.size() == 1, "Completion creates a fleet when none exists")
	if home.fleets.size() == 1:
		var first := home.fleets[0]
		_check(first.name == "Newhome Alpha", "First fleet is Newhome Alpha")
		_check(first.system_name == "Newhome", "Fleet records its home system")
		_check(first.ships == ["FTL Probe"], "Fleet contains one FTL Probe")
		_check(first.ship_summary() == "1 FTL Probe", "Fleet summary shows its ship")
		_check(
			is_equal_approx(first.speed_ly_per_turn(), 10.0),
			"The probe fleet travels 10 light years per turn"
		)
	_check(shipyard.fleet_list.get_child_count() == 1, "Fleet list refreshes after completion")
	_check(not shipyard.no_fleets_label.visible, "Empty state hides after completion")
	_check(shipyard.meta_label.text.contains("1 FLEET"), "Header updates its fleet count")
	_check(
		scene.status_label.text.contains("1 FTL Probe"),
		"Completion is announced on the status line"
	)

	# Four quarter-turn hulls finish in a single turn of work.
	shipyard.produce_button.pressed.emit()
	shipyard.produce_button.pressed.emit()
	shipyard.produce_button.pressed.emit()
	shipyard.produce_button.pressed.emit()
	_check(home.resources.titanium == 110, "Four probes cost 100 Titanium up front")
	_check(home.resources.antimatter == 1, "Four probes cost 40 Antimatter up front")
	_check(home.ship_queue.size() == 4, "Four probes queue up")
	_check(
		shipyard.produce_button.disabled,
		"Missing Antimatter greys out production"
	)
	scene.turn_manager.advance_turn()
	await process_frame
	_check(home.ship_queue.is_empty(), "One turn of work finishes four probes")
	_check(
		home.fleets[0].ships.size() == 5,
		"Completed probes join the newest fleet"
	)
	_check(
		scene.status_label.text.contains("4 FTL Probes"),
		"The status line batches the four completions"
	)

	# The New Fleet button creates an empty fleet to drag ships into.
	shipyard.new_fleet_button.pressed.emit()
	await process_frame
	_check(home.fleets.size() == 2, "New Fleet adds a second fleet")
	var alpha := home.fleets[0]
	var beta := home.fleets[1]
	_check(alpha.name == "Newhome Alpha", "The probe fleet is still first")
	_check(beta.name == "Newhome Beta", "The new fleet is Newhome Beta")
	_check(beta.ships.is_empty(), "A new fleet starts empty")
	_check(
		shipyard.fleet_count_label.text == "2",
		"Fleet count includes the empty fleet"
	)

	# Dragging a ship between fleets moves it; emptying a fleet removes it.
	_check(
		shipyard._move_ship(alpha, beta, 0),
		"Ships can move between stationed fleets"
	)
	_check(alpha.ships.size() == 4, "The source fleet loses the ship")
	_check(beta.ships == ["FTL Probe"], "The target fleet gains the ship")
	_check(
		shipyard.feedback_label.text.contains("Moved 1 FTL Probe to Newhome Beta"),
		"Moving reports the transfer"
	)
	var beta_row := _fleet_row_panel(shipyard, beta)
	_check(beta_row != null, "Fleet rows expose drop targets")
	_check(
		shipyard.fleet_drop_target_for(beta_row) == beta,
		"Drop targets resolve to their fleet"
	)
	_check(
		shipyard.fleet_drop_target_for(shipyard.hull_list.get_child(0)) == null,
		"Non-fleet controls are not drop targets"
	)
	_check(
		not shipyard._move_ship(beta, beta, 0),
		"Dropping onto the same fleet does nothing"
	)
	_check(
		not shipyard._move_ship(beta, alpha, 99),
		"Out-of-range ship moves are rejected"
	)
	for i in 4:
		shipyard._move_ship(alpha, beta, 0)
	_check(alpha not in home.fleets, "An emptied fleet is removed")
	_check(beta.ships.size() == 5, "All probes end up in one fleet")
	_check(
		scene._galaxy.next_fleet_name("Newhome") == "Newhome Alpha",
		"The removed fleet's name is available again"
	)

	# Clicking a chip without dragging changes nothing.
	var chip := _first_ship_chip(shipyard, beta)
	_check(chip != null, "Ships render as draggable chips")
	if chip != null:
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		chip.gui_input.emit(press)
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		chip.gui_input.emit(release)
		_check(beta.ships.size() == 5, "Clicking a chip moves no ships")
		_check(
			shipyard._drag_payload.is_empty(),
			"A click without dragging leaves no drag behind"
		)

	# A second new fleet reuses the disbanded name and becomes the completion
	# target for later builds.
	shipyard.new_fleet_button.pressed.emit()
	await process_frame
	_check(home.fleets.size() == 2, "A second new fleet is created")
	var second := home.fleets[1]
	_check(
		second.name == "Newhome Alpha",
		"The disbanded fleet's name is available again"
	)
	_check(second.ships.is_empty(), "The second new fleet starts empty")
	_check(
		shipyard._move_ship(beta, second, 0),
		"Ships move into the second fleet"
	)
	_check(beta.ships.size() == 4, "Beta keeps four probes")
	_check(second.ships == ["FTL Probe"], "The second fleet receives one probe")
	_check(
		shipyard.fleet_drop_target_for(_fleet_row_panel(shipyard, second)) == second,
		"Drop targets resolve for the second fleet"
	)

	# An empty fleet can be deleted with a right-click on its row.
	shipyard.new_fleet_button.pressed.emit()
	await process_frame
	_check(home.fleets.size() == 3, "A third fleet is created")
	var third := home.fleets[2]
	_check(third.name == "Newhome Gamma", "The third fleet is Newhome Gamma")
	_right_click_control(_fleet_row_panel(shipyard, third))
	_check(not home.fleets.has(third), "Right-click deletes the empty fleet")
	_check(home.fleets.size() == 2, "Only the working fleets remain")
	_check(
		shipyard.feedback_label.text.contains("Deleted empty Newhome Gamma"),
		"Deletion names the removed fleet"
	)
	_check(
		scene._galaxy.next_fleet_name("Newhome") == "Newhome Gamma",
		"The deleted empty fleet's name is available again"
	)
	_right_click_control(_fleet_row_panel(shipyard, beta))
	_check(home.fleets.size() == 2, "Occupied fleets survive right-clicks")
	_check(beta.ships.size() == 4, "Occupied fleets keep their ships")

	_check(FleetData.default_name("Newhome", 0) == "Newhome Alpha", "Greek naming starts at Alpha")
	_check(FleetData.default_name("Newhome", 23) == "Newhome Omega", "Greek naming ends at Omega")
	_check(
		FleetData.default_name("Newhome", 24) == "Newhome Alpha 2",
		"Greek naming restarts with a suffix"
	)
	_check(
		FleetData.default_name("Newhome", 47) == "Newhome Omega 2",
		"Greek naming carries the suffix across the alphabet"
	)
	_check(
		FleetData.default_name("Newhome", 48) == "Newhome Alpha 3",
		"Greek naming increments the suffix after another cycle"
	)

	shipyard.back_button.pressed.emit()
	_check(not shipyard.visible, "Back button closes the shipyard")
	_check(not scene._is_overlay_open(), "Stellar View sees the closed shipyard")
	_check(
		panel.fleet_list.get_child_count() == 2,
		"Fleet Command refreshes after the shipyard closes"
	)
	_check(not panel.no_fleets_label.visible, "Fleet Command hides its empty state")
	_check(
		panel.fleet_list.get_child(0).tooltip_text.contains("Newhome Beta"),
		"Fleet Command lists Newhome Beta first"
	)

	panel.shipyard_button.pressed.emit()
	_check(shipyard.visible, "Shipyard reopens with its fleet data")
	_check(shipyard.fleet_count_label.text == "2", "Existing fleets are restored")
	_check(home.ship_queue.is_empty(), "The queue stays empty across reopen")

	# Queuing is still blocked while Antimatter is missing.
	shipyard.produce_button.pressed.emit()
	_check(home.resources.titanium == 145, "Blocked queuing spends no Titanium")
	_check(home.resources.antimatter == 2, "Blocked queuing spends no Antimatter")
	_check(
		shipyard.produce_button.disabled,
		"The produce button greys out when resources are missing"
	)
	_check(
		shipyard.feedback_label.text.contains("Insufficient resources"),
		"The shipyard reports insufficient resources"
	)
	antimatter_cost = _cost_label(shipyard, "Antimatter")
	_check(
		antimatter_cost != null and _color_is_red(antimatter_cost),
		"Missing Antimatter is shown in red"
	)
	_check(
		antimatter_cost != null and antimatter_cost.text.contains("short"),
		"The missing amount is shown on the cost readout"
	)
	titanium_cost = _cost_label(shipyard, "Titanium")
	_check(
		titanium_cost != null and not _color_is_red(titanium_cost),
		"Affordable Titanium stays out of red"
	)
	_check(
		home.ship_queue.is_empty(),
		"Blocked production adds nothing to the queue"
	)

	# Researching Colony Ships unlocks the hull in the shipyard.
	scene.unlocked_ships.append("Colony Ship")
	shipyard.back_button.pressed.emit()
	_check(not shipyard.visible, "Shipyard closes before reopening unlocked")
	panel.shipyard_button.pressed.emit()
	_check(shipyard.visible, "Shipyard reopens with unlocked hulls")
	_check(shipyard.hull_list.get_child_count() == 2, "Hull list gains the Colony Ship")
	_check(shipyard.hull_count_label.text == "2", "Hull count includes the Colony Ship")
	var colony_button := shipyard.hull_list.get_child(1) as Button
	_check(colony_button != null, "Colony Ship hull is a button")
	if colony_button != null:
		_check(colony_button.text == "Colony Ship", "The second hull is Colony Ship")
		colony_button.pressed.emit()
		await process_frame
	_check(shipyard.hull_name_label.text == "Colony Ship", "Center shows Colony Ship")
	_check(
		shipyard.hull_role_value.text == "Colonization",
		"Colony Ship reports its role"
	)
	_check(
		shipyard.hull_time_value.text == "3 turns",
		"The Colony Ship takes 3 turns to build"
	)
	var colony_titanium := _cost_label(shipyard, "Titanium")
	var colony_antimatter := _cost_label(shipyard, "Antimatter")
	if colony_titanium != null:
		_check(
			colony_titanium.text.contains("500"),
			"Colony Ship costs 500 Titanium"
		)
	if colony_antimatter != null:
		_check(
			colony_antimatter.text.contains("1"),
			"Colony Ship costs 1 Antimatter"
		)
	_check(
		shipyard.produce_button.disabled,
		"Colony Ship production waits on resources"
	)

	home.resources.titanium = 600
	home.resources.antimatter = 5
	shipyard.refresh()
	await process_frame
	_check(
		not shipyard.produce_button.disabled,
		"Funded Colony Ship production is enabled"
	)
	shipyard.produce_button.pressed.emit()
	_check(home.resources.titanium == 100, "Queuing spends 500 Titanium up front")
	_check(home.resources.antimatter == 4, "Queuing spends 1 Antimatter up front")
	_check(home.ship_queue.size() == 1, "Queuing adds the Colony Ship")
	_check(
		_queue_status_text(shipyard, 0) == "Turn 1 of 3",
		"A fresh multi-turn build starts on turn one"
	)

	# The queue survives closing and reopening the shipyard.
	shipyard.back_button.pressed.emit()
	await process_frame
	panel.shipyard_button.pressed.emit()
	await process_frame
	_check(
		shipyard.queue_list.get_child_count() == 1,
		"The queued build persists across reopen"
	)

	# Cancelling refunds unused Titanium in full measure and Antimatter always.
	scene.turn_manager.advance_turn()
	await process_frame
	scene.turn_manager.advance_turn()
	await process_frame
	_check(
		_queue_status_text(shipyard, 0) == "Turn 3 of 3",
		"Two turns leave one turn of work"
	)
	_queue_cancel_button(shipyard, 0).pressed.emit()
	await process_frame
	_check(home.ship_queue.is_empty(), "Cancelling clears the queue")
	_check(
		home.resources.titanium == 336,
		"Cancelling refunds one third of the Titanium"
	)
	_check(home.resources.antimatter == 7, "Antimatter is always fully refunded")
	_check(
		shipyard.feedback_label.text.contains("166 Titanium"),
		"Cancellation reports the Titanium refund"
	)
	_check(
		shipyard.feedback_label.text.contains("1 Antimatter"),
		"Cancellation reports the Antimatter refund"
	)

	# Cancelling an unstarted build refunds everything.
	home.resources.titanium = 600
	home.resources.antimatter = 50
	shipyard._on_hull_pressed(ShipyardView.available_hulls(scene.unlocked_ships)[0])
	shipyard.produce_button.pressed.emit()
	_queue_cancel_button(shipyard, 0).pressed.emit()
	await process_frame
	_check(home.resources.titanium == 600, "Fresh builds refund all Titanium")
	_check(home.resources.antimatter == 50, "Fresh builds refund all Antimatter")

	# A finished Colony Ship joins the newest stationed fleet.
	home.resources.titanium = 600
	home.resources.antimatter = 50
	shipyard._on_hull_pressed(ShipyardView.available_hulls(scene.unlocked_ships)[1])
	shipyard.produce_button.pressed.emit()
	scene.turn_manager.advance_turn()
	await process_frame
	scene.turn_manager.advance_turn()
	await process_frame
	scene.turn_manager.advance_turn()
	await process_frame
	_check(home.ship_queue.is_empty(), "Three turns finish the Colony Ship")
	_check(
		home.fleets.size() == 2,
		"Completion joins the newest stationed fleet"
	)
	_check(second.name == "Newhome Alpha", "The newest fleet keeps its recycled name")
	_check(
		second.ships == ["FTL Probe", "Colony Ship"],
		"The Colony Ship joins the second fleet alongside its probe"
	)
	_check(
		second.ship_summary() == "1 FTL Probe, 1 Colony Ship",
		"Fleet summary shows both ships"
	)
	_check(
		is_equal_approx(second.speed_ly_per_turn(), 5.0),
		"A Colony Ship slows its fleet to 5 light years per turn"
	)
	_check(home.resources.titanium == 205, "Three turns net +60 Titanium overall")

	# Fleets holding orders are skipped by completions.
	var ordered_target: StarData = null
	for star in scene._galaxy.stars:
		if star != home:
			ordered_target = star
			break
	_check(ordered_target != null, "Another system exists to order toward")
	second.set_orders(ordered_target)
	home.resources.titanium = 600
	home.resources.antimatter = 50
	shipyard._on_hull_pressed(ShipyardView.available_hulls(scene.unlocked_ships)[0])
	shipyard.produce_button.pressed.emit()
	scene.turn_manager.advance_turn()
	await process_frame
	_check(second.ships.size() == 2, "Ordered fleets receive no new ships")
	_check(
		beta.ships.size() == 5,
		"Completions fall through to the newest unordered fleet"
	)
	_check(second.in_transit, "The ordered fleet still departs on schedule")

	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	shipyard._unhandled_input(escape)
	_check(not shipyard.visible, "Escape closes the shipyard")

	scene._select_star(other_node)
	_check(panel.shipyard_button.disabled, "Shipyard button is disabled away from Newhome")
	_check(
		panel.shipyard_button.tooltip_text == "No shipyard in this system",
		"Disabled shipyard explains why"
	)
	scene._on_shipyard_requested(other_node.data)
	_check(not shipyard.visible, "Systems without a shipyard cannot open the view")

	_finish()


func _right_click_control(control: Control) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	control.gui_input.emit(click)


func _fleet_row_panel(
	shipyard: ShipyardView, fleet: FleetData
) -> PanelContainer:
	for child in shipyard.fleet_list.get_children():
		var panel := child as PanelContainer
		if panel != null and panel.has_meta("fleet_target"):
			if panel.get_meta("fleet_target") == fleet:
				return panel
	return null


func _first_ship_chip(
	shipyard: ShipyardView, fleet: FleetData
) -> PanelContainer:
	var row := _fleet_row_panel(shipyard, fleet)
	if row == null:
		return null
	var chips := row.find_child("ShipChips", true, false) as HBoxContainer
	if chips == null:
		return null
	for child in chips.get_children():
		var chip := child as PanelContainer
		if chip != null and chip.has_meta("ship_chip"):
			return chip
	return null


func _queue_status_text(shipyard: ShipyardView, index: int) -> String:
	if index < 0 or index >= shipyard.queue_list.get_child_count():
		return ""
	var row := shipyard.queue_list.get_child(index)
	var label := row.find_child("QueueStatus", true, false) as Label
	return label.text if label != null else ""


func _queue_cancel_button(shipyard: ShipyardView, index: int) -> Button:
	if index < 0 or index >= shipyard.queue_list.get_child_count():
		return null
	var row := shipyard.queue_list.get_child(index)
	for child in row.get_children():
		var button := child as Button
		if button != null:
			return button
	return null


func _cost_label(shipyard: ShipyardView, needle: String) -> Label:
	for child in shipyard.cost_value.get_children():
		if child is Label and (child as Label).text.contains(needle):
			return child as Label
	return null


func _color_is_red(label: Label) -> bool:
	if label == null:
		return false
	var color := label.get_theme_color("font_color")
	return color.r > color.g and color.r > color.b


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FAIL: " + message)


func _finish() -> void:
	if _failures == 0:
		print("Shipyard verification: PASS")
		quit(0)
	else:
		print("Shipyard verification: FAIL (%d checks)" % _failures)
		quit(1)
