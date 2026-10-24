extends SceneTree
## Verifies per-system resource stockpiles, the system-panel resource list,
## hidden-resource visibility, galaxy-wide Research Data, and the local
## shipyard Titanium readout.
## Run with:
##   godot --headless --path . --script res://tests/verify_resources.gd

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := preload("res://scenes/stellar_view.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var home: StarData = scene._galaxy.home_star()
	var home_node: StarNode
	var other: StarData
	var other_node: StarNode
	for node in scene._star_nodes:
		if node.data == home:
			home_node = node
		elif other == null:
			other = node.data
			other_node = node

	_check(home != null, "Newhome exists")
	_check(home_node != null, "Newhome has a star node")
	_check(other != null and other_node != null, "A non-home system exists")
	if home == null or home_node == null or other == null:
		_finish()
		return

	var home_resources: ResourceStockpile = home.resources
	_check(home_resources != null, "Newhome owns a local resource stockpile")
	if home_resources == null:
		_finish()
		return

	_check(home_resources.titanium == 200, "Newhome starts with 200 Titanium")
	_check(home_resources.helium_3 == 200, "Newhome starts with 200 Helium 3")
	_check(home_resources.composites == 0, "Newhome Composites start at zero")
	_check(home_resources.antimatter == 50, "Newhome starts with 50 Antimatter")
	_check(home_resources.meta_matter == 0, "Newhome Meta-Matter starts at zero")
	_check(scene.research_data == 0, "Galaxy-wide Research Data starts at zero")
	_check(
		scene.revealed_resources.is_empty(),
		"No hidden resources are revealed at the start"
	)
	_check(
		home_resources != other.resources,
		"Each star system owns a separate stockpile"
	)
	_check(
		not _stockpile_has_resources(other.resources),
		"Non-home systems start with no local resources"
	)

	var empty := ResourceStockpile.new()
	_check(_stockpile_has_resources(empty) == false, "New stockpiles start empty")
	var starting := ResourceStockpile.starting_home()
	_check(starting.titanium == 200, "Starting-home Titanium is 200")
	_check(starting.helium_3 == 200, "Starting-home Helium 3 is 200")
	_check(starting.antimatter == 50, "Starting-home Antimatter is 50")

	_check(
		ResourceStockpile.is_visible(ResourceStockpile.TITANIUM),
		"Titanium is visible by default"
	)
	_check(
		ResourceStockpile.is_visible(ResourceStockpile.HELIUM_3),
		"Helium 3 is visible by default"
	)
	_check(
		ResourceStockpile.is_visible(ResourceStockpile.ANTIMATTER),
		"Antimatter is visible by default"
	)
	_check(
		not ResourceStockpile.is_visible(ResourceStockpile.COMPOSITES),
		"Composites start hidden"
	)
	_check(
		not ResourceStockpile.is_visible(ResourceStockpile.META_MATTER),
		"Meta-Matter starts hidden"
	)
	_check(
		home_resources.visible_definitions().size() == 3,
		"Only three local resources are visible initially"
	)

	var panel: StarInfoPanel = scene.star_panel
	scene._select_star(home_node)
	await process_frame
	_check(
		panel.resource_list.get_child_count() == 3,
		"The system panel lists Newhome's three visible resources"
	)
	_check(_amount_text(panel, ResourceStockpile.TITANIUM) == "200", "Panel shows 200 Titanium")
	_check(_amount_text(panel, ResourceStockpile.HELIUM_3) == "200", "Panel shows 200 Helium 3")
	_check(_amount_text(panel, ResourceStockpile.ANTIMATTER) == "50", "Panel shows 50 Antimatter")
	_check(
		panel.resource_list.get_node_or_null("Resource_composites") == null,
		"The system panel hides Composites"
	)
	_check(
		panel.resource_list.get_node_or_null("Resource_meta_matter") == null,
		"The system panel hides Meta-Matter"
	)
	_check(
		panel.resource_list.get_node_or_null("Resource_research_data") == null,
		"Research Data is not listed as a system resource"
	)

	var research_panel := scene.get_node("UI/HUD/ResearchPanel") as PanelContainer
	_check(research_panel != null, "The HUD has a galaxy-wide Research Data panel")
	_check(
		scene.get_node_or_null("UI/HUD/ResourcesPanel") == null,
		"The old HUD resource list is removed"
	)
	_check(scene.research_amount_label.text == "0 RD", "The HUD shows 0 Research Data")

	scene._select_star(other_node)
	await process_frame
	_check(
		panel.resource_list.get_child_count() == 3,
		"Other systems still show the local resource list"
	)
	_check(_amount_text(panel, ResourceStockpile.TITANIUM) == "0", "Other systems show 0 Titanium")
	_check(_amount_text(panel, ResourceStockpile.HELIUM_3) == "0", "Other systems show 0 Helium 3")
	_check(_amount_text(panel, ResourceStockpile.ANTIMATTER) == "0", "Other systems show 0 Antimatter")

	var wallet := ResourceStockpile.starting_home()
	_check(
		wallet.can_afford(
			{
				ResourceStockpile.TITANIUM: 200,
				ResourceStockpile.HELIUM_3: 200,
				ResourceStockpile.ANTIMATTER: 50,
			}
		),
		"A local stockpile can afford its contents"
	)
	_check(
		not wallet.can_afford({ResourceStockpile.TITANIUM: 201}),
		"A local stockpile rejects unaffordable costs"
	)
	_check(
		wallet.spend(
			{
				ResourceStockpile.TITANIUM: 50,
				ResourceStockpile.HELIUM_3: 25,
			}
		),
		"A local stockpile spends affordable costs"
	)
	_check(wallet.titanium == 150, "Spending Titanium updates the local balance")
	_check(wallet.helium_3 == 175, "Spending Helium 3 updates the local balance")
	_check(
		not wallet.spend({ResourceStockpile.ANTIMATTER: 51}),
		"Failed spending is rejected"
	)
	_check(wallet.antimatter == 50, "Failed spending leaves the balance unchanged")

	var cargo_target := ResourceStockpile.new()
	_check(
		wallet.transfer_to(cargo_target, {ResourceStockpile.TITANIUM: 20}),
		"Resources can be transferred to another system stockpile"
	)
	_check(wallet.titanium == 130, "Transfers remove resources from the origin")
	_check(cargo_target.titanium == 20, "Transfers add resources to the destination")

	home_resources.set_amount(ResourceStockpile.COMPOSITES, 12)
	other.resources.set_amount(ResourceStockpile.COMPOSITES, 4)
	scene._select_star(home_node)
	await process_frame
	_check(
		panel.resource_list.get_node_or_null("Resource_composites") == null,
		"Hidden Composites stay out of the system panel"
	)
	_check(
		scene.reveal_resource(ResourceStockpile.COMPOSITES),
		"A hidden resource can be revealed galaxy-wide"
	)
	_check(
		not scene.reveal_resource(ResourceStockpile.COMPOSITES),
		"Revealing the same resource twice is a no-op"
	)
	_check(
		panel.resource_list.get_node_or_null("Resource_composites") != null,
		"Revealed Composites appear in the system panel"
	)
	_check(
		_amount_text(panel, ResourceStockpile.COMPOSITES) == "12",
		"Revealed resources show the selected system's balance"
	)
	scene._select_star(other_node)
	await process_frame
	_check(
		_amount_text(panel, ResourceStockpile.COMPOSITES) == "4",
		"Reveal state applies across systems while balances stay local"
	)
	_check(
		panel.resource_list.get_node_or_null("Resource_meta_matter") == null,
		"Meta-Matter remains hidden"
	)

	scene._select_star(home_node)
	await process_frame
	home_resources.set_amount(ResourceStockpile.TITANIUM, 180)
	scene.refresh_resources()
	_check(
		_amount_text(panel, ResourceStockpile.TITANIUM) == "180",
		"The system panel refreshes local resource changes"
	)

	scene.set_research_data(125)
	_check(scene.research_data == 125, "Research Data can be set globally")
	_check(scene.research_amount_label.text == "125 RD", "The HUD tracks Research Data")
	scene.add_research_data(5)
	_check(scene.research_data == 130, "Research Data can be added globally")
	_check(scene.research_amount_label.text == "130 RD", "The HUD adds Research Data")

	scene.technologies_button.pressed.emit()
	var tech_tree: TechTree = scene._tech_tree
	_check(tech_tree != null and tech_tree.visible, "The technology tree opens")
	if tech_tree != null:
		_check(
			tech_tree.funds_label.text == "130 RD",
			"The technology tree reads galaxy-wide Research Data"
		)
		scene.set_research_data(140)
		_check(
			tech_tree.funds_label.text == "140 RD",
			"The technology tree refreshes with Research Data changes"
		)
		tech_tree.close()
		await process_frame

	home_resources.set_amount(ResourceStockpile.TITANIUM, 175)
	scene._select_star(home_node)
	await process_frame
	panel.shipyard_button.pressed.emit()
	await process_frame
	var shipyard: ShipyardView = scene._shipyard
	_check(shipyard != null and shipyard.visible, "The shipyard opens")
	if shipyard != null:
		_check(
			shipyard.resource_note.text.contains("175 Titanium"),
			"The shipyard uses Newhome's local Titanium"
		)
		_check(
			shipyard.resource_note.text.contains("Antimatter"),
			"The shipyard reads both production resources locally"
		)
		shipyard.close()
		await process_frame

	_finish()


func _stockpile_has_resources(stockpile: ResourceStockpile) -> bool:
	if stockpile == null:
		return false
	if stockpile.titanium > 0:
		return true
	if stockpile.helium_3 > 0:
		return true
	if stockpile.composites > 0:
		return true
	if stockpile.antimatter > 0:
		return true
	if stockpile.meta_matter > 0:
		return true
	return false


func _amount_text(panel: StarInfoPanel, resource_id: String) -> String:
	var amount := panel.resource_list.get_node_or_null(
		"Resource_%s/Amount" % resource_id
	) as Label
	if amount == null:
		return ""
	return amount.text


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FAIL: " + message)


func _finish() -> void:
	if _failures == 0:
		print("Resource verification: PASS")
		quit(0)
	else:
		print("Resource verification: FAIL (%d checks)" % _failures)
		quit(1)
