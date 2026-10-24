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
	_check(shipyard.produce_button.text == "Produce Ship", "Produce button has the right label")
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
		shipyard.produce_button.anchor_left == 0.5
		and shipyard.produce_button.anchor_right == 0.5
		and shipyard.produce_button.anchor_top == 1.0,
		"Produce button is anchored to the bottom center"
	)
	_check(shipyard.meta_label.text.contains("NEWHOME III"), "Header shows Newhome III")
	_check(shipyard.meta_label.text.contains("0 FLEETS"), "Header shows the fleet count")
	_check(shipyard.no_fleets_label.visible, "Shipyard starts with no fleets")
	_check(not shipyard.fleet_scroll.visible, "Empty fleet list hides its scroll area")
	_check(shipyard.fleet_count_label.text == "0", "Fleet count starts at zero")
	_check(home.fleets.is_empty(), "Newhome starts with no fleet data")
	_check(
		shipyard.feedback_label.text.contains("No fleet selected"),
		"Production hint explains the new-fleet default"
	)

	shipyard.produce_button.pressed.emit()
	_check(home.resources.titanium == 175, "Production spends 25 Titanium")
	_check(home.resources.antimatter == 40, "Production spends 10 Antimatter")
	_check(home.fleets.size() == 1, "Producing without a selection creates a fleet")
	if home.fleets.size() == 1:
		var first := home.fleets[0]
		_check(first.name == "Newhome Alpha", "First fleet is Newhome Alpha")
		_check(first.system_name == "Newhome", "Fleet records its home system")
		_check(first.ships == ["FTL Probe"], "Fleet contains one FTL Probe")
		_check(first.ship_summary() == "1 FTL Probe", "Fleet summary shows its ship")
	_check(shipyard.fleet_list.get_child_count() == 1, "Fleet list refreshes after production")
	_check(not shipyard.no_fleets_label.visible, "Empty state hides after production")
	_check(shipyard.meta_label.text.contains("1 FLEET"), "Header updates its fleet count")
	_check(
		shipyard.feedback_label.text.contains("Newhome Alpha"),
		"Production feedback names the new fleet"
	)

	shipyard.produce_button.pressed.emit()
	_check(home.fleets.size() == 2, "No selection creates another fleet")
	if home.fleets.size() == 2:
		_check(home.fleets[1].name == "Newhome Beta", "Second fleet is Newhome Beta")
		_check(shipyard.fleet_list.get_child_count() == 2, "Both fleets are listed")

	if home.fleets.size() >= 1:
		shipyard._on_fleet_pressed(home.fleets[0])
		_check(
			shipyard.feedback_label.text.contains("Selected Newhome Alpha"),
			"Selecting a fleet changes the production hint"
		)
		shipyard.produce_button.pressed.emit()
		_check(home.fleets.size() == 2, "A selection produces into the existing fleet")
		_check(home.fleets[0].ships.size() == 2, "Selected fleet receives the ship")
		_check(
			home.fleets[0].ship_summary() == "2 FTL Probes",
			"Selected fleet summary updates"
		)

		shipyard._on_fleet_pressed(home.fleets[0])
		_check(
			shipyard.feedback_label.text.contains("No fleet selected"),
			"Clicking a selected fleet clears the selection"
		)
		shipyard.produce_button.pressed.emit()
		_check(home.fleets.size() == 3, "Clearing selection creates a new fleet")
		if home.fleets.size() == 3:
			_check(home.fleets[2].name == "Newhome Gamma", "Third fleet is Newhome Gamma")

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
		panel.fleet_list.get_child_count() == 3,
		"Fleet Command refreshes after the shipyard closes"
	)
	_check(not panel.no_fleets_label.visible, "Fleet Command hides its empty state")
	_check(
		panel.fleet_list.get_child(0).tooltip_text.contains("Newhome Alpha"),
		"Fleet Command lists Newhome Alpha"
	)

	panel.shipyard_button.pressed.emit()
	_check(shipyard.visible, "Shipyard reopens with its fleet data")
	_check(shipyard.fleet_count_label.text == "3", "Existing fleets are restored")

	# Five probes cost 125 Titanium and all 50 starting Antimatter.
	shipyard.produce_button.pressed.emit()
	_check(home.resources.titanium == 75, "Five probes leave 75 Titanium")
	_check(home.resources.antimatter == 0, "Five probes exhaust Antimatter")
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
	var fleets_before := home.fleets.size()
	shipyard.produce_button.pressed.emit()
	_check(
		home.fleets.size() == fleets_before,
		"Insufficient resources block production"
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
	_check(home.resources.titanium == 100, "Colony Ship spends 500 Titanium")
	_check(home.resources.antimatter == 4, "Colony Ship spends 1 Antimatter")
	_check(home.fleets.size() == 5, "Colony Ship production creates a fleet")
	if home.fleets.size() == 5:
		var colony_fleet := home.fleets[4]
		_check(colony_fleet.name == "Newhome Epsilon", "Fifth fleet is Newhome Epsilon")
		_check(colony_fleet.ships == ["Colony Ship"], "Fleet contains one Colony Ship")
		_check(
			colony_fleet.ship_summary() == "1 Colony Ship",
			"Fleet summary shows the Colony Ship"
		)
		_check(
			is_equal_approx(colony_fleet.speed_ly_per_turn(), 5.0),
			"A Colony Ship travels 5 light years per turn"
		)

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
