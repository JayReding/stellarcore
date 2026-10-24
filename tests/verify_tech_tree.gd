extends SceneTree
## Verifies the Technologies button and technology tree overlay.
## Run with:
##   godot --headless --path . --script res://tests/verify_tech_tree.gd

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := preload("res://scenes/stellar_view.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var button: Button = scene.get_node("UI/HUD/TechnologiesButton")
	_check(button != null, "Technologies button exists")
	_check(button.visible, "Technologies button is visible")
	_check(button.text == "Technologies", "Technologies button has the right label")

	button.pressed.emit()
	var tech_tree: TechTree = scene._tech_tree
	_check(tech_tree != null, "Technology tree is created on demand")
	_check(tech_tree.visible, "Technology tree opens")
	_check(scene._is_overlay_open(), "Stellar View recognizes the open overlay")

	_check(
		tech_tree.tech_list.get_child_count() == 2,
		"Technologies are grouped into two tier rows"
	)
	var tier_one := _tier_section(tech_tree, 1)
	var tier_two := _tier_section(tech_tree, 2)
	_check(tier_one != null, "A Tier 1 row exists")
	_check(tier_two != null, "A Tier 2 row exists")
	_check(
		tech_tree.tech_list.get_child(0) == tier_one,
		"Tier 1 is sorted before Tier 2"
	)
	if tier_one != null:
		_check(_tier_header(tier_one) == "TIER 1", "The first row is labelled TIER 1")
		var tier_one_categories := tier_one.get_node(
			"CategoryRow"
		) as HBoxContainer
		_check(
			tier_one_categories != null
			and tier_one_categories.get_child_count() == 3,
			"Tier 1 contains three category sections"
		)
		var propulsion := _category_section(tier_one, "Propulsion")
		var exploration := _category_section(tier_one, "Exploration")
		var industrial := _category_section(tier_one, "Industrial")
		_check(propulsion != null, "A Propulsion category section exists")
		_check(exploration != null, "An Exploration category section exists")
		_check(industrial != null, "An Industrial category section exists")
		_check(
			propulsion != null
			and exploration != null
			and tier_one_categories != null
			and tier_one_categories.get_child(0) == propulsion
			and tier_one_categories.get_child(1) == exploration,
			"Propulsion is sorted before Exploration before Industrial"
		)
		if propulsion != null:
			_check(
				_category_header(propulsion) == "PROPULSION",
				"The Propulsion section is labelled"
			)
			var ftl_node := _first_tech_node(propulsion)
			_check(ftl_node != null, "The Propulsion section renders a card")
			if ftl_node != null:
				_check(
					ftl_node.name_label.text == "FTL Probes",
					"FTL Probes is displayed"
				)
				_check(
					ftl_node.category_label.text == "PROPULSION",
					"The FTL Probe card reports Propulsion"
				)
				_check(
					ftl_node.cost_label.text == "NO RESEARCH REQUIRED",
					"Default technology has no research cost"
				)
				_check(
					ftl_node.status_label.text == "AVAILABLE BY DEFAULT",
					"Default technology is available"
				)
		if exploration != null:
			_check(
				_category_header(exploration) == "EXPLORATION",
				"The Exploration section is labelled"
			)
			var colony_node := _first_tech_node(exploration)
			_check(colony_node != null, "The Exploration section renders a card")
			if colony_node != null:
				_check(
					colony_node.name_label.text == "Colony Ships",
					"Colony Ships is displayed under Exploration"
				)
				_check(
					colony_node.category_label.text == "EXPLORATION",
					"The Colony Ships card reports Exploration"
				)
				_check(
					colony_node.cost_label.text == "REQUIRES 100 RD",
					"Colony Ships costs 100 Research Data"
				)
		if industrial != null:
			_check(
				_category_header(industrial) == "INDUSTRIAL",
				"The Industrial section is labelled"
			)
			var ore_node := _first_tech_node(industrial)
			_check(ore_node != null, "The Industrial section renders a card")
			if ore_node != null:
				_check(
					ore_node.name_label.text == "Ore Processing",
					"Ore Processing is displayed under Industrial"
				)
				_check(
					ore_node.category_label.text == "INDUSTRIAL",
					"The Ore Processing card reports Industrial"
				)
	if tier_two != null:
		_check(_tier_header(tier_two) == "TIER 2", "The second row is labelled TIER 2")
		var tier_two_industrial := _category_section(tier_two, "Industrial")
		_check(
			tier_two_industrial != null,
			"Tier 2 contains an Industrial category section"
		)
		if tier_two_industrial != null:
			var refining := _first_tech_node(tier_two_industrial)
			_check(refining != null, "Tier 2 Industrial renders a card")
			if refining != null:
				_check(
					refining.name_label.text == "Antimatter Refining",
					"Antimatter Refining is displayed in Tier 2 Industrial"
				)
	_check(
		tech_tree.meta_label.text.contains("4 TECHNOLOGIES"),
		"Technology count is displayed"
	)
	_check(
		tech_tree.meta_label.text.contains("3 CATEGORIES"),
		"Category count is displayed"
	)
	_check(
		tech_tree.meta_label.text.contains("2 TIERS"),
		"Tier count is displayed"
	)
	_check(
		tech_tree.funds_label.text == "0 RD",
		"Galaxy-wide Research Data is displayed"
	)

	tech_tree.back_button.pressed.emit()
	_check(not tech_tree.visible, "Back button closes the technology tree")
	_check(not scene._is_overlay_open(), "Stellar View recognizes the closed overlay")

	button.pressed.emit()
	_check(tech_tree.visible, "Technology tree reopens")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	tech_tree._unhandled_input(escape)
	_check(not tech_tree.visible, "Escape closes the technology tree")

	_finish()


func _tier_section(tech_tree: TechTree, tier: int) -> VBoxContainer:
	return tech_tree.tech_list.get_node_or_null("Tier_%d" % tier) as VBoxContainer


func _tier_header(tier_section: VBoxContainer) -> String:
	var header := tier_section.get_node_or_null("TierHeader") as Label
	return header.text if header != null else ""


func _category_section(
	tier_section: VBoxContainer, category: String
) -> VBoxContainer:
	var category_row := tier_section.get_node_or_null(
		"CategoryRow"
	) as HBoxContainer
	if category_row == null:
		return null
	return category_row.get_node_or_null(
		"Category_%s" % category.replace(" ", "")
	) as VBoxContainer


func _category_header(section: VBoxContainer) -> String:
	var header := section.get_node_or_null("CategoryHeader") as Label
	return header.text if header != null else ""


func _first_tech_node(section: VBoxContainer) -> TechNode:
	var cards := section.get_node_or_null("TechCards") as HBoxContainer
	if cards == null or cards.get_child_count() == 0:
		return null
	return cards.get_child(0) as TechNode


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FAIL: " + message)


func _finish() -> void:
	if _failures == 0:
		print("Technology tree verification: PASS")
		quit(0)
	else:
		print("Technology tree verification: FAIL (%d checks)" % _failures)
		quit(1)
