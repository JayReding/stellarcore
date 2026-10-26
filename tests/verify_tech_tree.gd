extends SceneTree
## Verifies the clickable Research Data panel, the category-column tech tree
## grid with tier rows, card contents, and the research readout and close paths.
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

	var panel := scene.get_node("UI/HUD/ResearchPanel") as PanelContainer
	_check(panel != null, "Research Data panel exists")
	_check(panel.visible, "Research Data panel is visible")
	_check(
		panel.tooltip_text == "Open the technology tree",
		"Research panel advertises the tech tree"
	)

	_click_research_panel(scene)
	var tech_tree: TechTree = scene._tech_tree
	_check(tech_tree != null, "Technology tree is created on demand")
	_check(tech_tree.visible, "Technology tree opens")
	_check(scene._is_overlay_open(), "Stellar View recognizes the open overlay")

	var grid := tech_tree.tech_grid
	_check(grid != null, "The tree renders a category grid")
	_check(grid.columns == 5, "The grid has a tier gutter plus four shown categories")

	var headers: Array[String] = []
	for child in grid.get_children():
		if child.name.begins_with("CategoryHeader_"):
			headers.append((child as Label).text)
	_check(
		headers == [
			"PROPULSION", "EXPLORATION", "INDUSTRIAL", "MILITARY",
		],
		"Shown category columns follow the configured order"
	)
	_check(
		grid.get_node_or_null("CategoryHeader_AdvancedTechnology") == null,
		"Advanced Technology stays hidden until unlocked"
	)

	_check(_tier_label(grid, 1) == "TIER 1", "Tier rows start at Tier 1")
	_check(_tier_label(grid, 2) == "TIER 2", "The tree grows a second tier row")

	var ftl := _tech_node(grid, 1, "Propulsion", "FTL Probes")
	_check(ftl != null, "Tier 1 Propulsion holds FTL Probes")
	if ftl != null:
		_check(ftl.icon_label.text == "FTL", "Card shows the tech icon")
		_check(
			ftl.description_label.text.contains("reconnaissance"),
			"Card shows the tech description"
		)
		_check(
			not ftl.cost_label.visible and not ftl.time_label.visible,
			"Available techs hide cost and time"
		)
		_check(
			ftl.status_label.text == "AVAILABLE",
			"Available techs say AVAILABLE"
		)
		_check(
			_color_is_green(ftl.status_label),
			"AVAILABLE is shown in green"
		)

	var ore := _tech_node(grid, 1, "Industrial", "Ore Processing")
	_check(ore != null, "Tier 1 Industrial holds Ore Processing")
	if ore != null:
		_check(not ore.cost_label.visible, "Default techs hide their cost")

	var colony := _tech_node(grid, 1, "Exploration", "Colony Ships")
	_check(colony != null, "Tier 1 Exploration holds Colony Ships")
	if colony != null:
		_check(
			colony.cost_label.text == "100 RD",
			"Researchable techs state their Research Data cost"
		)
		_check(
			_color_is_yellow(colony.cost_label),
			"Research cost is shown in yellow"
		)
		_check(
			colony.time_label.visible and colony.time_label.text == "5 TURNS",
			"Researchable techs state their research time"
		)
		_check(
			_color_is_yellow(colony.time_label),
			"Research time is shown in yellow"
		)

	var refining := _tech_node(grid, 2, "Industrial", "Antimatter Refining")
	_check(refining != null, "Tier 2 Industrial holds Antimatter Refining")

	var destroyer := _tech_node(grid, 1, "Military", "Destroyer Hull Plan")
	_check(destroyer != null, "Tier 1 Military holds Destroyer Hull Plan")
	if destroyer != null:
		_check(
			destroyer.icon_label.text == "DES",
			"Destroyer card shows its icon"
		)
		_check(
			destroyer.name_label.text == "Destroyer Hull Plan",
			"Destroyer card shows its name"
		)
		_check(
			destroyer.description_label.text
			== "Small and light military platform. Uses standard missiles "
			+ "for long range combat.",
			"Destroyer card shows its description"
		)
		_check(
			destroyer.cost_label.visible and destroyer.cost_label.text == "50 RD",
			"Destroyer research costs 50 Research Data"
		)
		_check(
			destroyer.time_label.visible and destroyer.time_label.text == "3 TURNS",
			"Destroyer research takes 3 turns"
		)

	_check(
		grid.get_node_or_null("TechCell_2_AdvancedTechnology") == null,
		"Hidden categories render no cells"
	)
	_check(
		tech_tree.meta_label.text.contains("5 TECHNOLOGIES"),
		"Technology count is displayed"
	)
	_check(
		tech_tree.meta_label.text.contains("4 CATEGORIES"),
		"Shown category count is displayed"
	)
	_check(
		tech_tree.meta_label.text.contains("2 TIERS"),
		"Tier count is displayed"
	)

	var card_height := -1.0
	var cards_match := true
	await process_frame
	await process_frame
	for child in tech_tree.tech_grid.find_children("*", "TechNode", true, false):
		var card := child as TechNode
		if card == null:
			continue
		if card_height < 0.0:
			card_height = card.size.y
		elif not is_equal_approx(card.size.y, card_height):
			cards_match = false
	_check(cards_match and card_height > 0.0, "Every tech card has the same height")
	_check(
		tech_tree.funds_label.text == "0 RD",
		"Galaxy-wide Research Data is displayed"
	)

	root.size = Vector2i(1100, 700)
	await process_frame
	await process_frame
	_check(
		tech_tree.tech_scroll.get_h_scroll_bar().max_value > 0.0,
		"The tree scrolls horizontally when the grid overflows"
	)
	root.size = Vector2i(1920, 1080)
	await process_frame
	await process_frame

	# Ctrl+mouse wheel zooms the grid; plain wheel input leaves it alone.
	var zoom_in := InputEventMouseButton.new()
	zoom_in.button_index = MOUSE_BUTTON_WHEEL_UP
	zoom_in.pressed = true
	zoom_in.ctrl_pressed = true
	zoom_in.position = Vector2(960, 540)
	tech_tree._input(zoom_in)
	_check(tech_tree._zoom > 1.0, "Ctrl+wheel up zooms in")
	_check(
		tech_tree.tech_grid.scale.x > 1.0,
		"Zooming scales the grid"
	)
	var plain_wheel := InputEventMouseButton.new()
	plain_wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	plain_wheel.pressed = true
	plain_wheel.ctrl_pressed = false
	plain_wheel.position = Vector2(960, 540)
	var zoom_before_plain := tech_tree._zoom
	tech_tree._input(plain_wheel)
	_check(
		is_equal_approx(tech_tree._zoom, zoom_before_plain),
		"Plain wheel input does not zoom"
	)
	for i in 20:
		tech_tree._input(zoom_in)
	_check(
		is_equal_approx(tech_tree._zoom, 2.0),
		"Zooming in clamps at the maximum"
	)
	var zoom_out := InputEventMouseButton.new()
	zoom_out.button_index = MOUSE_BUTTON_WHEEL_DOWN
	zoom_out.pressed = true
	zoom_out.ctrl_pressed = true
	zoom_out.position = Vector2(960, 540)
	for i in 30:
		tech_tree._input(zoom_out)
	_check(
		is_equal_approx(tech_tree._zoom, 0.5),
		"Zooming out clamps at the minimum"
	)

	tech_tree.back_button.pressed.emit()
	_check(not tech_tree.visible, "Back button closes the technology tree")
	_check(not scene._is_overlay_open(), "Stellar View recognizes the closed overlay")

	# Dragging out of the panel is a map gesture, not a tree request.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = panel.get_global_rect().get_center()
	panel.gui_input.emit(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = panel.get_global_rect().get_center() + Vector2(200, 0)
	panel.gui_input.emit(release)
	_check(not tech_tree.visible, "Dragging off the panel keeps the tree closed")

	_click_research_panel(scene)
	_check(tech_tree.visible, "Technology tree reopens")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	tech_tree._unhandled_input(escape)
	_check(not tech_tree.visible, "Escape closes the technology tree")

	_finish()


func _click_research_panel(scene: Node) -> void:
	var panel := scene.get_node("UI/HUD/ResearchPanel") as Control
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = panel.get_global_rect().get_center()
	panel.gui_input.emit(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = panel.get_global_rect().get_center()
	panel.gui_input.emit(release)


func _tier_label(grid: GridContainer, tier: int) -> String:
	var label := grid.get_node_or_null("TierLabel_%d" % tier) as Label
	return label.text if label != null else ""


func _tech_cell(grid: GridContainer, tier: int, category: String) -> VBoxContainer:
	return grid.get_node_or_null(
		"TechCell_%d_%s" % [tier, category.replace(" ", "")]
	) as VBoxContainer


func _tech_node(
	grid: GridContainer, tier: int, category: String, tech_name: String
) -> TechNode:
	var cell := _tech_cell(grid, tier, category)
	if cell == null:
		return null
	for child in cell.get_children():
		var node := child as TechNode
		if node != null and node.name_label.text == tech_name:
			return node
	return null


func _count_cards(grid: GridContainer, tier: int, category: String) -> int:
	var cell := _tech_cell(grid, tier, category)
	if cell == null:
		return -1
	var count := 0
	for child in cell.get_children():
		if child is TechNode:
			count += 1
	return count


func _color_is_green(label: Label) -> bool:
	if label == null:
		return false
	var color := label.get_theme_color("font_color")
	return color.g > color.r and color.g > color.b


func _color_is_yellow(label: Label) -> bool:
	if label == null:
		return false
	var color := label.get_theme_color("font_color")
	return color.r > 0.9 and color.g > 0.7 and color.b < 0.5


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
