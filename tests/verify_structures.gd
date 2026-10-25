extends SceneTree
## Verifies starting structures, per-turn production/upkeep, and the System View
## structure/resource sidebar.
## Run with:
##   godot --headless --path . --script res://tests/verify_structures.gd

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var scene := preload("res://scenes/stellar_view.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var home: StarData = scene._galaxy.home_star()
	var home_node: StarNode
	var other: StarData
	for node in scene._star_nodes:
		if node.data == home:
			home_node = node
		elif other == null:
			other = node.data

	_check(home != null, "Newhome exists")
	_check(home_node != null, "Newhome has a star node")
	_check(other != null, "A non-home system exists")
	if home == null or home_node == null or other == null:
		_finish()
		return

	_check(
		home.planets[1].has_structure(StructureData.ORE_PROCESSING),
		"Newhome II hosts an Ore Processing Station"
	)
	_check(
		home.planets[2].has_structure(StructureData.COLONY),
		"Newhome III hosts a Colony"
	)
	_check(
		home.planets[2].has_structure(StructureData.SHIPYARD),
		"Newhome III hosts a Shipyard"
	)
	_check(
		home.planets[3].has_structure(StructureData.HELIUM_3_STATION),
		"Newhome IV hosts a Helium3 Station"
	)
	_check(
		home.planets[0].structures.is_empty(),
		"Newhome I starts without structures"
	)
	_check(other.all_structures().is_empty(), "Non-home systems start empty")
	_check(home.all_structures().size() == 4, "Newhome starts with four structures")

	var colony := _find_structure(home.planets[2], StructureData.COLONY)
	var shipyard := _find_structure(home.planets[2], StructureData.SHIPYARD)
	var ore_station := _find_structure(home.planets[1], StructureData.ORE_PROCESSING)
	var helium_station := _find_structure(
		home.planets[3], StructureData.HELIUM_3_STATION
	)
	_check(colony != null, "Colony is present on Newhome III")
	_check(shipyard != null, "Shipyard is present on Newhome III")
	_check(ore_station != null, "Ore Processing Station is present on Newhome II")
	_check(
		helium_station != null,
		"Helium3 Station is present on Newhome IV"
	)
	if (
		colony == null
		or shipyard == null
		or ore_station == null
		or helium_station == null
	):
		_finish()
		return

	_check(colony.location_label() == "Surface", "The Colony is a surface structure")
	_check(shipyard.location_label() == "Orbit", "The Shipyard is an orbital structure")
	_check(
		ore_station.location_label() == "Orbit",
		"The Ore Processing Station is orbital"
	)
	_check(
		helium_station.location_label() == "Orbit",
		"The Helium3 Station is orbital"
	)

	_check(
		int(colony.production_per_turn().get(ResourceStockpile.TITANIUM, 0)) == 10,
		"The Colony produces 10 Titanium"
	)
	_check(
		int(colony.production_per_turn().get(ResourceStockpile.HELIUM_3, 0)) == 2,
		"The Colony produces 2 Helium 3"
	)
	_check(colony.research_per_turn() == 5, "The Colony produces 5 Research Data")
	_check(
		int(shipyard.upkeep_per_turn().get(ResourceStockpile.HELIUM_3, 0)) == 2,
		"The Shipyard consumes 2 Helium 3"
	)
	_check(
		int(ore_station.production_per_turn().get(ResourceStockpile.TITANIUM, 0)) == 25,
		"The Ore Processing Station produces 25 Titanium"
	)
	_check(
		int(ore_station.upkeep_per_turn().get(ResourceStockpile.HELIUM_3, 0)) == 2,
		"The Ore Processing Station consumes 2 Helium 3"
	)
	_check(
		int(helium_station.production_per_turn().get(ResourceStockpile.HELIUM_3, 0)) == 20,
		"The Helium3 Station produces 20 Helium 3"
	)

	_check(home.has_shipyard(), "The Shipyard structure enables ship production")
	_check(
		home.shipyard_planet == home.planets[2],
		"Newhome III remains the shipyard planet"
	)
	_check(not other.has_shipyard(), "Non-home systems have no shipyard")
	_check(home.can_build_structures(), "The Colony permits construction at Newhome")
	_check(
		not other.can_build_structures(),
		"Systems without a Colony cannot build structures"
	)

	var flow := home.resource_flow()
	_check(
		int(flow.get(ResourceStockpile.TITANIUM, 0)) == 35,
		"Newhome's net Titanium production is +35 per turn"
	)
	_check(
		int(flow.get(ResourceStockpile.HELIUM_3, 0)) == 18,
		"Newhome's net Helium 3 production is +18 per turn"
	)
	_check(
		int(flow.get(ResourceStockpile.ANTIMATTER, 0)) == 1,
		"Newhome produces +1 Antimatter per turn"
	)
	_check(home.research_flow() == 5, "Newhome produces 5 Research Data per turn")
	_check(other.resource_flow().is_empty(), "Non-home systems have no resource flow")
	_check(other.research_flow() == 0, "Non-home systems produce no Research Data")

	var home_iii_entries := home.planets[2].flow_entries()
	_check(home_iii_entries.size() == 4, "Newhome III reports four flow entries")
	_check(
		_entry_total(home_iii_entries, ResourceStockpile.TITANIUM) == 10,
		"Newhome III contributes 10 Titanium"
	)
	_check(
		_entry_total(home_iii_entries, ResourceStockpile.HELIUM_3) == 0,
		"Newhome III breaks even on Helium 3"
	)
	_check(
		_entry_total(home_iii_entries, ResourceStockpile.RESEARCH_DATA) == 5,
		"Newhome III contributes 5 Research Data"
	)
	var home_ii_entries := home.planets[1].flow_entries()
	_check(
		_entry_total(home_ii_entries, ResourceStockpile.TITANIUM) == 25,
		"Newhome II contributes 25 Titanium"
	)
	_check(
		_entry_total(home_ii_entries, ResourceStockpile.HELIUM_3) == -2,
		"Newhome II uses 2 Helium 3"
	)
	var home_iv_entries := home.planets[3].flow_entries()
	_check(
		_entry_total(home_iv_entries, ResourceStockpile.HELIUM_3) == 20,
		"Newhome IV contributes 20 Helium 3"
	)

	_check(home.resources.titanium == 200, "Turn 1 begins with 200 Titanium")
	_check(home.resources.helium_3 == 200, "Turn 1 begins with 200 Helium 3")
	_check(scene.research_data == 0, "Turn 1 begins with 0 Research Data")

	scene._on_system_view_requested(home)
	await process_frame
	await process_frame
	var system_view: SystemView = scene._system_view
	_check(system_view != null and system_view.visible, "System View opens")
	if system_view == null:
		_finish()
		return

	_check(system_view.sidebar.visible, "System View shows its sidebar")
	var system_center := system_view.camera.unproject_position(Vector3.ZERO)
	var sidebar_left := system_view.sidebar.get_global_rect().position.x
	_check(
		absf(system_center.x - sidebar_left * 0.5) < 2.0,
		"The star system is centered left of the sidebar"
	)
	var titanium_row := system_view.system_resource_list.get_node_or_null(
		"Resource_titanium"
	) as HBoxContainer
	var titanium_label := (
		titanium_row.get_child(1) as Label if titanium_row != null else null
	)
	_check(
		titanium_label != null
		and titanium_label.get_theme_font_size("font_size") >= 12,
		"System Overview text uses the larger sidebar font"
	)
	_check(
		system_view.overview_eyebrow.get_theme_font_size("font_size") >= 19,
		"System Overview heading uses a larger font"
	)
	_check(
		system_view.system_resource_list.get_child_count() == 3,
		"Sidebar lists the three visible local resources"
	)
	_check(
		system_view.system_resource_list.get_node_or_null(
			"Resource_composites"
		) == null,
		"Sidebar hides unrevealed Composites"
	)
	_check(
		system_view.system_resource_list.get_node_or_null(
			"Resource_meta_matter"
		) == null,
		"Sidebar hides unrevealed Meta-Matter"
	)
	_check(
		_amount_text(system_view.system_resource_list, ResourceStockpile.TITANIUM) == "200",
		"Sidebar shows 200 Titanium"
	)
	_check(
		_change_text(system_view.system_resource_list, ResourceStockpile.TITANIUM) == "+35",
		"Sidebar shows +10 Titanium per turn"
	)
	_check(
		_amount_text(system_view.system_resource_list, ResourceStockpile.HELIUM_3) == "200",
		"Sidebar shows 200 Helium 3"
	)
	_check(
		_change_text(system_view.system_resource_list, ResourceStockpile.HELIUM_3) == "+18",
		"Sidebar shows +2 Helium 3 per turn"
	)
	_check(
		_change_text(system_view.system_resource_list, ResourceStockpile.ANTIMATTER) == "+1",
		"Sidebar shows +1 Antimatter per turn"
	)
	_check(
		_color_is_green(
			_change_label(
				system_view.system_resource_list, ResourceStockpile.TITANIUM
			)
		),
		"Positive resource changes are green"
	)
	_check(
		system_view.research_resource_list.get_child_count() == 1,
		"Sidebar has a galaxy-wide Research Data row"
	)
	_check(
		_amount_text(
			system_view.research_resource_list, ResourceStockpile.RESEARCH_DATA
		) == "0",
		"Sidebar shows the global Research Data balance"
	)
	_check(
		_change_text(
			system_view.research_resource_list, ResourceStockpile.RESEARCH_DATA
		) == "+5",
		"Sidebar shows the galaxy-wide Research Data change"
	)
	_check(
		_color_is_green(
			_change_label(
				system_view.research_resource_list,
				ResourceStockpile.RESEARCH_DATA
			)
		),
		"Positive Research Data change is green"
	)

	_check(
		system_view.structure_summary.text == "4 structures across 3 planets",
		"Sidebar summarizes the system's structures"
	)
	_check(
		_count_buttons(system_view.structure_list) == 4,
		"Sidebar lists every built structure"
	)
	_check(
		_has_button_tooltip(system_view.structure_list, "Colony:"),
		"Structure list includes the Colony"
	)
	_check(
		_has_button_tooltip(system_view.structure_list, "Shipyard:"),
		"Structure list includes the Shipyard"
	)
	_check(
		_has_button_tooltip(system_view.structure_list, "Ore Processing Station:"),
		"Structure list includes the Ore Processing Station"
	)
	_check(
		_has_button_tooltip(system_view.structure_list, "Helium3 Station:"),
		"Structure list includes the Helium3 Station"
	)

	_check(
		system_view._planet_hit_buttons.size() == home.planets.size(),
		"Every rendered planet has a click target"
	)
	var sidebar_rect := system_view.sidebar.get_global_rect()
	for button in system_view._planet_hit_buttons:
		_check(
			not sidebar_rect.intersects(button.get_global_rect()),
			"Planet click targets stay clear of the sidebar"
		)
	if not system_view._planet_hit_buttons.is_empty():
		var click_position := (
			system_view._planet_hit_buttons[0].get_global_rect().get_center()
		)
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = click_position
		press.global_position = click_position
		root.push_input(press)
		await process_frame
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		release.position = click_position
		release.global_position = click_position
		root.push_input(release)
		await process_frame
		_check(
			system_view.selected_planet() == home.planets[0],
			"Clicking a planet selects it"
		)
		_check(
			system_view.planet_sidebar.visible,
			"Selecting a planet opens a detail sidebar over the overview"
		)
		_check(
			system_view.planet_detail.visible,
			"Selecting a planet opens its detail section"
		)
		_check(
			system_view.planet_title.text == home.planets[0].designation,
			"Planet detail names the selected planet"
		)
		_check(
			_count_named_children(system_view.planet_structure_list, "PlanetStructure_") == 0,
			"Newhome I reports no structures"
		)
		_check(
			_count_named_children(system_view.planet_flow_list, "PlanetFlow_") == 0,
			"Newhome I reports no resource flow"
		)

	system_view._select_planet(home.planets[2])
	await process_frame
	_check(
		system_view.planet_title.text == "Newhome III",
		"Planet detail switches to Newhome III"
	)
	_check(
		_count_named_children(system_view.planet_structure_list, "PlanetStructure_") == 2,
		"Newhome III lists its Colony and Shipyard"
	)
	_check(
		_count_named_children(system_view.planet_flow_list, "PlanetFlow_") == 4,
		"Newhome III lists each contribution and upkeep"
	)
	_check(
		_has_flow(
			system_view.planet_flow_list, "+10", "Titanium", "Colony"
		),
		"Newhome III detail shows Colony Titanium output"
	)
	_check(
		_has_flow(
			system_view.planet_flow_list, "+2", "Helium 3", "Colony"
		),
		"Newhome III detail shows Colony Helium 3 output"
	)
	_check(
		_has_flow(
			system_view.planet_flow_list, "+5", "Research Data", "Colony"
		),
		"Newhome III detail shows Colony Research Data output"
	)
	_check(
		_has_flow(
			system_view.planet_flow_list, "-2", "Helium 3", "Shipyard"
		),
		"Newhome III detail shows Shipyard Helium 3 upkeep"
	)
	var shipyard_upkeep := _find_flow_row(
		system_view.planet_flow_list, "-2", "Helium 3", "Shipyard"
	)
	_check(
		shipyard_upkeep != null
		and _color_is_red(shipyard_upkeep.get_child(0) as Label),
		"Negative planet flows are red"
	)

	system_view._select_planet(home.planets[1])
	await process_frame
	_check(
		_count_named_children(system_view.planet_structure_list, "PlanetStructure_") == 1,
		"Newhome II lists its Ore Processing Station"
	)
	_check(
		_count_named_children(system_view.planet_flow_list, "PlanetFlow_") == 2,
		"Newhome II lists its Titanium output and Helium 3 upkeep"
	)

	system_view._select_planet(home.planets[3])
	await process_frame
	_check(
		_count_named_children(system_view.planet_structure_list, "PlanetStructure_") == 1,
		"Newhome IV lists its Helium3 Station"
	)
	_check(
		_has_flow(
			system_view.planet_flow_list, "+20", "Helium 3", "Helium3 Station"
		),
		"Newhome IV detail shows Helium 3 output"
	)
	_check(
		_has_flow(
			system_view.planet_flow_list, "+1", "Antimatter", "Helium3 Station"
		),
		"Newhome IV detail shows Antimatter output"
	)

	scene.turn_manager.advance_turn()
	await process_frame
	_check(home.resources.titanium == 235, "Turn 2 adds 35 Titanium")
	_check(home.resources.helium_3 == 218, "Turn 2 adds 18 Helium 3")
	_check(home.resources.antimatter == 51, "Turn 2 adds 1 Antimatter")
	_check(home.resources.composites == 0, "Composites remain zero")
	_check(home.resources.meta_matter == 0, "Meta-Matter remains zero")
	_check(scene.research_data == 5, "Turn 2 adds 5 galaxy-wide Research Data")
	_check(
		not _stockpile_has_resources(other.resources),
		"Production does not add resources to other systems"
	)
	_check(
		_amount_text(system_view.system_resource_list, ResourceStockpile.TITANIUM) == "235",
		"The open sidebar refreshes Titanium after production"
	)
	_check(
		_amount_text(system_view.system_resource_list, ResourceStockpile.HELIUM_3) == "218",
		"The open sidebar refreshes Helium 3 after production"
	)
	_check(
		_amount_text(
			system_view.research_resource_list, ResourceStockpile.RESEARCH_DATA
		) == "5",
		"The open sidebar refreshes Research Data after production"
	)
	_check(
		_change_text(system_view.system_resource_list, ResourceStockpile.TITANIUM) == "+35",
		"The sidebar keeps showing per-turn Titanium change"
	)
	_check(
		_change_text(system_view.system_resource_list, ResourceStockpile.HELIUM_3) == "+18",
		"The sidebar keeps showing per-turn Helium 3 change"
	)

	scene.turn_manager.advance_turn()
	await process_frame
	_check(home.resources.titanium == 270, "Turn 3 adds another 35 Titanium")
	_check(home.resources.helium_3 == 236, "Turn 3 adds another 18 Helium 3")
	_check(scene.research_data == 10, "Turn 3 adds another 5 Research Data")

	# A system without structures still shows the galaxy-wide Research Data
	# change, but no local production and no construction permission.
	other.surveyed = true
	scene._on_system_view_requested(other)
	await process_frame
	await process_frame
	_check(
		system_view._data == other,
		"System View can inspect a system without structures"
	)
	_check(
		system_view.structure_summary.text == "No structures built in this system.",
		"System View reports an empty structure list"
	)
	_check(
		_container_has_label_text(
			system_view.structure_list,
			"A Colony is required before construction."
		),
		"Systems without a Colony explain the construction requirement"
	)
	_check(
		_amount_text(system_view.system_resource_list, ResourceStockpile.TITANIUM) == "0",
		"Empty systems show zero local Titanium"
	)
	_check(
		_change_text(system_view.system_resource_list, ResourceStockpile.TITANIUM) == "0",
		"Empty systems show no local Titanium change"
	)
	_check(
		_amount_text(
			system_view.research_resource_list, ResourceStockpile.RESEARCH_DATA
		) == "10",
		"Empty systems still show the global Research Data balance"
	)
	_check(
		_change_text(
			system_view.research_resource_list, ResourceStockpile.RESEARCH_DATA
		) == "+5",
		"Empty systems still show the galaxy-wide Research Data change"
	)
	_check(
		system_view.planet_hint.visible and not system_view.planet_detail.visible,
		"An empty system starts with the planet-detail hint"
	)
	_check(
		not system_view.planet_sidebar.visible,
		"No planet sidebar appears before a planet is selected"
	)
	_check(
		system_view._planet_hit_buttons.size() == other.planets.size(),
		"Empty systems still expose planet click targets"
	)

	# Construction costs 200 Titanium (except the free, instant Shipyard) and
	# takes 3 turns, with one project per system at a time. Home has 220
	# Titanium here; Newhome I starts empty, so it exercises the full flow.
	scene._on_system_view_requested(home)
	await process_frame
	await process_frame
	system_view._select_planet(home.planets[0])
	await process_frame
	_check(
		system_view.planet_title.text == "Newhome I",
		"Planet detail switches to Newhome I"
	)
	_check(
		system_view.planet_sidebar.visible,
		"The planet sidebar appears on top of the System Overview"
	)
	_check(
		not system_view.construct_popup.visible,
		"The construction popup stays hidden until requested"
	)
	# Without enough Titanium the buildable rows are disabled with shortfalls.
	home.resources.titanium = 50
	system_view.build_button.pressed.emit()
	await process_frame
	_check(
		system_view.construct_popup.visible,
		"The Build button opens the construction popup"
	)
	_check(
		system_view.construct_subtitle.text == "Build on Newhome I",
		"The popup names the selected planet"
	)
	_check(
		system_view.construct_list.get_child_count() == 4,
		"Construction lists the four non-Colony structure types"
	)
	_check(
		system_view.construct_list.get_node_or_null("Construct_colony") == null,
		"Colonies come from colonization, not construction"
	)
	var refinery_button := system_view.construct_list.get_node_or_null(
		"Construct_%s" % StructureData.ANTIMATTER_REFINERY
	) as Button
	var shipyard_button := system_view.construct_list.get_node_or_null(
		"Construct_%s" % StructureData.SHIPYARD
	) as Button
	var ore_button := system_view.construct_list.get_node_or_null(
		"Construct_%s" % StructureData.ORE_PROCESSING
	) as Button
	_check(refinery_button != null, "Construction lists the Antimatter Refinery")
	_check(shipyard_button != null, "Construction lists the Shipyard")
	_check(ore_button != null, "Construction lists the Ore Processing Station")
	_check(
		_construction_cost_text(ore_button) == "200 Titanium (150 short) • 3 turns",
		"Construction rows restate the cost, build time, and shortfall"
	)
	_check(
		_construction_cost_text(shipyard_button) == "Free • Instant",
		"The Shipyard stays free and instant"
	)
	_check(
		ore_button != null and ore_button.disabled,
		"Construction is disabled without enough Titanium"
	)
	_check(
		_has_construction_action(ore_button, "NEEDS 150 TITANIUM"),
		"Unaffordable rows name the missing resources"
	)
	ore_button.pressed.emit()
	await process_frame
	_check(
		not home.is_constructing() and home.resources.titanium == 50,
		"Nothing is spent or queued without enough Titanium"
	)

	# Locked technologies cannot be built even when affordable.
	home.resources.titanium = 220
	scene.refresh_resources()
	await process_frame
	refinery_button = system_view.construct_list.get_node_or_null(
		"Construct_%s" % StructureData.ANTIMATTER_REFINERY
	) as Button
	shipyard_button = system_view.construct_list.get_node_or_null(
		"Construct_%s" % StructureData.SHIPYARD
	) as Button
	_check(
		refinery_button != null and refinery_button.disabled,
		"The Antimatter Refinery is locked before its research"
	)
	_check(
		shipyard_button != null and shipyard_button.disabled,
		"A second Shipyard cannot be built while one exists"
	)
	ore_button = system_view.construct_list.get_node_or_null(
		"Construct_%s" % StructureData.ORE_PROCESSING
	) as Button
	_check(
		_construction_cost_text(ore_button) == "200 Titanium • 3 turns",
		"Funded rows show the clean cost and build time"
	)
	_check(
		ore_button != null and not ore_button.disabled,
		"Affordable structures can be queued on the selected planet"
	)
	system_view._on_construct_pressed(StructureData.ANTIMATTER_REFINERY)
	await process_frame
	_check(
		not home.is_constructing(),
		"Locked structures cannot be built"
	)

	# Building spends the cost up front and queues a 3-turn project.
	ore_button.pressed.emit()
	await process_frame
	_check(
		home.resources.titanium == 20,
		"Building spends 200 Titanium up front"
	)
	_check(
		home.is_constructing()
		and home.construction_type_id == StructureData.ORE_PROCESSING
		and home.construction_turns_remaining == 3
		and home.construction_turns_total == 3,
		"Building queues a 3-turn project"
	)
	_check(
		not home.planets[0].has_structure(StructureData.ORE_PROCESSING),
		"The structure appears only when construction finishes"
	)
	_check(
		system_view.construct_status.text.contains(
			"Construction started: Ore Processing Station on Newhome I"
		),
		"Building reports the queued project"
	)
	_check(
		system_view.build_feedback.text.contains("3 turns."),
		"The planet sidebar reports the build time"
	)
	_check(
		scene.construction_panel.visible,
		"The Stellar View shows the active construction"
	)
	_check(
		_has_construction_hud_row(
			scene, "Newhome — Ore Processing Station", "3 TURNS LEFT"
		),
		"The Stellar View shows the structure and its remaining turns"
	)

	# Only one project runs per system at a time.
	var helium_button := system_view.construct_list.get_node_or_null(
		"Construct_%s" % StructureData.HELIUM_3_STATION
	) as Button
	_check(
		helium_button != null and helium_button.disabled,
		"No second project starts while one is in progress"
	)
	helium_button.pressed.emit()
	await process_frame
	_check(
		home.construction_type_id == StructureData.ORE_PROCESSING
		and home.resources.titanium == 20,
		"Pressing another option does not replace the active project"
	)

	# Turns advance the project on both the HUD and the popup.
	scene.turn_manager.advance_turn()
	await process_frame
	_check(
		home.construction_turns_remaining == 2,
		"One turn leaves two turns of construction"
	)
	_check(
		_has_construction_hud_row(
			scene, "Newhome — Ore Processing Station", "2 TURNS LEFT"
		),
		"The Stellar View counts construction down"
	)
	_check(home.resources.titanium == 55, "Turn 4 adds 35 Titanium while building")
	scene.turn_manager.advance_turn()
	await process_frame
	_check(
		home.construction_turns_remaining == 1,
		"Construction reaches its final turn"
	)
	_check(
		_has_construction_hud_row(
			scene, "Newhome — Ore Processing Station", "1 TURN LEFT"
		),
		"The Stellar View uses the singular turn label"
	)
	scene.turn_manager.advance_turn()
	await process_frame
	_check(
		not home.is_constructing(),
		"Construction finishes after its final turn"
	)
	_check(
		home.planets[0].has_structure(StructureData.ORE_PROCESSING),
		"Finishing adds the Ore Processing Station to Newhome I"
	)
	_check(
		not scene.construction_panel.visible,
		"The Stellar View clears finished construction"
	)
	_check(
		scene.status_label.text.contains(
			"Construction complete: Ore Processing Station on Newhome I (Newhome)."
		),
		"The status line announces the finished structure"
	)
	_check(
		system_view.structure_summary.text == "5 structures across 4 planets",
		"The sidebar summary counts the new structure"
	)
	_check(
		_change_text(system_view.system_resource_list, ResourceStockpile.TITANIUM) == "+60",
		"The finished station contributes Titanium the turn it completes"
	)
	_check(home.resources.titanium == 150, "Turn 6 nets +60 Titanium with the station")
	_check(home.resources.helium_3 == 288, "Turn 6 nets +16 Helium 3 with the station")
	_check(home.resources.antimatter == 55, "Turn 6 adds 1 Antimatter")
	_check(scene.research_data == 25, "Turn 6 adds another 5 Research Data")
	ore_button = system_view.construct_list.get_node_or_null(
		"Construct_%s" % StructureData.ORE_PROCESSING
	) as Button
	_check(
		ore_button != null and ore_button.disabled,
		"A structure already on the planet cannot be built again"
	)

	# Completing Antimatter Refining unlocks the refinery for construction.
	scene.unlocked_structures.append(StructureData.ANTIMATTER_REFINERY)
	home.resources.titanium = 250
	scene.refresh_resources()
	await process_frame
	refinery_button = system_view.construct_list.get_node_or_null(
		"Construct_%s" % StructureData.ANTIMATTER_REFINERY
	) as Button
	_check(
		refinery_button != null and not refinery_button.disabled,
		"Research unlocks the Antimatter Refinery for construction"
	)
	refinery_button.pressed.emit()
	await process_frame
	_check(home.resources.titanium == 50, "The refinery spends 200 Titanium")
	_check(
		home.is_constructing()
		and home.construction_type_id == StructureData.ANTIMATTER_REFINERY
		and home.construction_turns_remaining == 3,
		"The refinery queues like any other structure"
	)
	scene.turn_manager.advance_turn()
	await process_frame
	scene.turn_manager.advance_turn()
	await process_frame
	scene.turn_manager.advance_turn()
	await process_frame
	_check(
		not home.is_constructing()
		and home.planets[0].has_structure(StructureData.ANTIMATTER_REFINERY),
		"Finishing adds the Antimatter Refinery to Newhome I"
	)
	_check(
		system_view.structure_summary.text == "6 structures across 4 planets",
		"The sidebar summary counts the refinery"
	)
	_check(
		_change_text(system_view.system_resource_list, ResourceStockpile.HELIUM_3) == "+11",
		"The sidebar flow includes the refinery's Helium 3 upkeep"
	)
	_check(
		_change_text(system_view.system_resource_list, ResourceStockpile.ANTIMATTER) == "+6",
		"The sidebar flow includes the refinery's Antimatter output"
	)
	_check(home.resources.titanium == 230, "Turn 9 nets +60 Titanium with both stations")
	_check(home.resources.helium_3 == 331, "Turn 9 nets +11 Helium 3 with the refinery")
	_check(home.resources.antimatter == 63, "Turn 9 adds 6 Antimatter with the refinery")
	_check(scene.research_data == 40, "Turn 9 adds another 5 Research Data")
	_check(
		system_view.construct_popup.visible,
		"The popup stays open after building"
	)

	# The popup closes on demand while the planet sidebar stays in place.
	system_view.construct_close_button.pressed.emit()
	await process_frame
	_check(
		not system_view.construct_popup.visible
		and system_view.planet_sidebar.visible,
		"Closing the popup returns to the planet sidebar"
	)

	# Esc dismisses the popup first, then the planet sidebar, then the view.
	system_view.build_button.pressed.emit()
	await process_frame
	_push_escape()
	await process_frame
	_check(
		not system_view.construct_popup.visible
		and system_view.planet_sidebar.visible
		and system_view.visible,
		"Esc closes the popup before the planet sidebar"
	)
	_push_escape()
	await process_frame
	_check(
		not system_view.planet_sidebar.visible
		and system_view.visible
		and system_view.selected_planet() == null,
		"Esc closes the planet sidebar before the System View"
	)

	# The Shipyard is the exception: free and instant. A fresh colony system
	# proves it completes immediately without spending or queueing.
	var yard_star := StarData.new()
	yard_star.id = "test-yard"
	yard_star.display_name = "Testyard"
	yard_star.surveyed = true
	var yard_planet := PlanetData.new()
	yard_planet.designation = "Testyard I"
	yard_planet.planet_class = PlanetData.PlanetClass.EARTH_LIKE
	yard_planet.add_structure(StructureData.COLONY)
	var yard_planets: Array[PlanetData] = [yard_planet]
	yard_star.planets = yard_planets
	yard_star.resources = ResourceStockpile.new()
	scene._on_system_view_requested(yard_star)
	await process_frame
	await process_frame
	system_view._select_planet(yard_planet)
	await process_frame
	system_view.build_button.pressed.emit()
	await process_frame
	var yard_shipyard := system_view.construct_list.get_node_or_null(
		"Construct_%s" % StructureData.SHIPYARD
	) as Button
	var yard_ore := system_view.construct_list.get_node_or_null(
		"Construct_%s" % StructureData.ORE_PROCESSING
	) as Button
	_check(
		yard_shipyard != null and not yard_shipyard.disabled,
		"The Shipyard is buildable with an empty stockpile"
	)
	_check(
		yard_ore != null and yard_ore.disabled,
		"Paid structures stay disabled with an empty stockpile"
	)
	yard_shipyard.pressed.emit()
	await process_frame
	_check(
		yard_planet.has_structure(StructureData.SHIPYARD),
		"The Shipyard completes immediately"
	)
	_check(
		not yard_star.is_constructing(),
		"The instant Shipyard queues no project"
	)
	_check(
		yard_star.resources.titanium == 0,
		"The instant Shipyard spends nothing"
	)
	_check(
		system_view.structure_summary.text == "2 structures across 1 planet",
		"The sidebar summary counts the instant Shipyard"
	)

	# Systems without a Colony cannot build anything.
	scene._on_system_view_requested(other)
	await process_frame
	await process_frame
	system_view._select_planet(other.planets[0])
	await process_frame
	_check(
		system_view.planet_sidebar.visible,
		"The planet sidebar opens even without construction permission"
	)
	system_view.build_button.pressed.emit()
	await process_frame
	_check(
		system_view.construct_popup.visible,
		"The popup opens to explain why construction is blocked"
	)
	_check(
		system_view.construct_list.get_child_count() == 0,
		"Systems without a Colony offer no construction"
	)
	_check(
		system_view.construct_status.text.contains("A Colony is required"),
		"Construction explains the Colony requirement"
	)

	_finish()


func _push_escape() -> void:
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await process_frame


func _find_structure(
	planet: PlanetData, type_id: String
) -> StructureData:
	for structure in planet.structures:
		if structure != null and structure.type_id == type_id:
			return structure
	return null


func _entry_total(entries: Array[Dictionary], resource_id: String) -> int:
	var total := 0
	for entry in entries:
		if str(entry.get("resource_id", "")) == resource_id:
			total += int(entry.get("amount", 0))
	return total


func _resource_row(
	container: VBoxContainer, resource_id: String
) -> HBoxContainer:
	return container.get_node_or_null("Resource_%s" % resource_id) as HBoxContainer


func _amount_label(
	container: VBoxContainer, resource_id: String
) -> Label:
	var row := _resource_row(container, resource_id)
	if row == null:
		return null
	return row.get_node_or_null("Amount") as Label


func _change_label(
	container: VBoxContainer, resource_id: String
) -> Label:
	var row := _resource_row(container, resource_id)
	if row == null:
		return null
	return row.get_node_or_null("Change") as Label


func _amount_text(container: VBoxContainer, resource_id: String) -> String:
	var label := _amount_label(container, resource_id)
	return label.text if label != null else ""


func _change_text(container: VBoxContainer, resource_id: String) -> String:
	var label := _change_label(container, resource_id)
	return label.text if label != null else ""


func _color_is_green(label: Label) -> bool:
	if label == null:
		return false
	var color := label.get_theme_color("font_color")
	return color.g > color.r and color.g > color.b


func _color_is_red(label: Label) -> bool:
	if label == null:
		return false
	var color := label.get_theme_color("font_color")
	return color.r > color.g and color.r > color.b


func _count_buttons(container: VBoxContainer) -> int:
	var count := 0
	for child in container.get_children():
		if child is Button:
			count += 1
	return count


func _has_button_tooltip(container: VBoxContainer, prefix: String) -> bool:
	for child in container.get_children():
		if child is Button and (child as Button).tooltip_text.begins_with(prefix):
			return true
	return false


func _count_named_children(container: VBoxContainer, prefix: String) -> int:
	var count := 0
	for child in container.get_children():
		if child.name.begins_with(prefix):
			count += 1
	return count


func _find_flow_row(
	container: VBoxContainer,
	amount: String,
	resource_name: String,
	structure_name: String
) -> HBoxContainer:
	for child in container.get_children():
		if not child is HBoxContainer:
			continue
		var labels: Array[Label] = []
		for label_child in child.get_children():
			if label_child is Label:
				labels.append(label_child as Label)
		if labels.size() < 3:
			continue
		if (
			labels[0].text == amount
			and labels[1].text == resource_name
			and labels[2].text == structure_name
		):
			return child as HBoxContainer
	return null


func _has_flow(
	container: VBoxContainer,
	amount: String,
	resource_name: String,
	structure_name: String
) -> bool:
	return _find_flow_row(
		container, amount, resource_name, structure_name
	) != null


func _container_has_label_text(container: VBoxContainer, text: String) -> bool:
	for child in container.get_children():
		if child is Label and (child as Label).text == text:
			return true
	return false


func _stockpile_has_resources(stockpile: ResourceStockpile) -> bool:
	if stockpile == null:
		return false
	return (
		stockpile.titanium > 0
		or stockpile.helium_3 > 0
		or stockpile.composites > 0
		or stockpile.antimatter > 0
		or stockpile.meta_matter > 0
	)


func _construction_cost_text(button: Button) -> String:
	if button == null:
		return ""
	var label := button.find_child("CostLabel", true, false) as Label
	return label.text if label != null else ""


func _has_construction_action(button: Button, text: String) -> bool:
	if button == null or button.get_child_count() == 0:
		return false
	var row := button.get_child(0) as HBoxContainer
	if row == null:
		return false
	for child in row.get_children():
		if child is Label and (child as Label).text == text:
			return true
	return false


func _has_construction_hud_row(
	view: Node, name_text: String, turns_text: String
) -> bool:
	for child in view.construction_list.get_children():
		var row := child as HBoxContainer
		if row == null:
			continue
		var labels: Array[Label] = []
		for sub in row.get_children():
			if sub is Label:
				labels.append(sub as Label)
		if (
			labels.size() == 2
			and labels[0].text == name_text
			and labels[1].text == turns_text
		):
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FAIL: " + message)


func _finish() -> void:
	if _failures == 0:
		print("Structure verification: PASS")
		quit(0)
	else:
		print("Structure verification: FAIL (%d checks)" % _failures)
		quit(1)
