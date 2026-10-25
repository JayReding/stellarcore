extends SceneTree
## Verifies research confirmation, spending, turn progress, HUD readout, and
## technology-driven structure unlocks.
## Run with:
##   godot --headless --path . --script res://tests/verify_research.gd

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := preload("res://scenes/stellar_view.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	_check(
		not scene.has_unlocked_structure(StructureData.ANTIMATTER_REFINERY),
		"Antimatter Refinery starts locked"
	)
	_check(
		scene.has_unlocked_structure(StructureData.ORE_PROCESSING),
		"Base structures start unlocked"
	)

	scene._on_technologies_requested()
	await process_frame
	var tree: TechTree = scene._tech_tree
	_check(tree != null and tree.visible, "Technology tree opens")

	var antimatter := _tech_node(tree, 2, "Industrial", "Antimatter Refining")
	var ftl := _tech_node(tree, 1, "Propulsion", "FTL Probes")
	_check(antimatter != null, "Antimatter Refining card exists")
	_check(ftl != null, "FTL Probes card exists")
	if antimatter == null or ftl == null:
		_finish()
		return

	ftl.research_requested.emit(ftl.technology)
	await process_frame
	_check(
		not tree.research_dialog.visible,
		"Default technologies do not open a research dialog"
	)

	antimatter.research_requested.emit(antimatter.technology)
	await process_frame
	_check(tree.research_dialog.visible, "Clicking a researchable tech opens the dialog")
	_check(tree.dialog_backdrop.visible, "The research dialog has a modal backdrop")
	_check(
		tree.dialog_title.text == "Antimatter Refining",
		"The dialog names the technology"
	)
	_check(tree.dialog_cost.text == "50 RD", "The dialog restates the research cost")
	_check(tree.dialog_time.text == "3 turns", "The dialog restates the research time")
	_check(
		tree.dialog_confirm_button.disabled,
		"Research cannot start without enough Research Data"
	)
	_check(
		tree.dialog_warning.visible
		and tree.dialog_warning.text.contains("Insufficient"),
		"The dialog explains the Research Data shortage"
	)

	tree.dialog_cancel_button.pressed.emit()
	await process_frame
	_check(not tree.research_dialog.visible, "Cancel closes the research dialog")
	_check(not tree.is_researching(), "Cancel does not start research")

	scene.set_research_data(120)
	_check(
		scene.research_data == 120,
		"Research Data can be granted for the check"
	)
	antimatter.research_requested.emit(antimatter.technology)
	await process_frame
	_check(
		not tree.dialog_confirm_button.disabled,
		"Begin Research is enabled once the cost is affordable"
	)

	tree.dialog_confirm_button.pressed.emit()
	await process_frame
	_check(not tree.research_dialog.visible, "Confirming closes the dialog")
	_check(tree.is_researching(), "Confirming begins research")
	_check(
		tree.active_research().get("id", "") == "antimatter_refining",
		"Antimatter Refining is the active project"
	)
	_check(scene.research_data == 70, "Starting research spends 50 Research Data")
	_check(
		tree.research_turns_remaining() == 3,
		"Research starts with three turns remaining"
	)
	_check(
		scene.research_project_label.text == "ANTIMATTER REFINING",
		"The HUD names the active research"
	)
	_check(
		scene.research_turns_label.text == "3 TURNS LEFT",
		"The HUD shows the remaining research turns"
	)
	_check(
		scene.research_progress.visible
		and is_zero_approx(scene.research_progress.value),
		"The HUD research bar starts empty"
	)
	_check(
		antimatter.cost_label.visible
		and antimatter.cost_label.text == "50 RD"
		and antimatter.time_label.visible
		and antimatter.status_label.text == "3 TURNS LEFT",
		"The technology card reports active research"
	)

	antimatter.research_requested.emit(antimatter.technology)
	await process_frame
	_check(
		not tree.research_dialog.visible,
		"A second project cannot start while research is active"
	)

	scene.turn_manager.advance_turn()
	await process_frame
	_check(
		tree.research_turns_remaining() == 2,
		"One turn advances research to two turns left"
	)
	_check(
		scene.research_turns_label.text == "2 TURNS LEFT",
		"The HUD updates the remaining turns"
	)
	_check(
		is_equal_approx(scene.research_progress.value, 1.0),
		"The HUD research bar advances"
	)
	_check(
		antimatter.status_label.text == "2 TURNS LEFT",
		"The technology card updates its remaining turns"
	)

	scene.turn_manager.advance_turn()
	await process_frame
	_check(
		tree.research_turns_remaining() == 1,
		"Research reaches its final turn"
	)
	_check(
		scene.research_turns_label.text == "1 TURN LEFT",
		"The HUD uses the singular turn label"
	)

	scene.turn_manager.advance_turn()
	await process_frame
	_check(not tree.is_researching(), "Research completes after its final turn")
	_check(
		tree.completed_technology_ids().has("antimatter_refining"),
		"The completed technology is recorded"
	)
	_check(
		scene.research_project_label.text == "NO ACTIVE RESEARCH",
		"The HUD clears when research completes"
	)
	_check(
		not scene.research_progress.visible,
		"The HUD research bar hides when research completes"
	)
	_check(
		scene.has_unlocked_structure(StructureData.ANTIMATTER_REFINERY),
		"Antimatter Refining unlocks the Antimatter Refinery structure"
	)
	_check(
		scene.unlocked_ships.is_empty(),
		"Antimatter Refining does not unlock a ship"
	)
	_check(
		scene.status_label.text.contains("Research complete"),
		"The status line announces the completed research"
	)
	_check(
		not antimatter.cost_label.visible
		and not antimatter.time_label.visible
		and antimatter.status_label.text == "AVAILABLE",
		"The technology card reports completion"
	)

	tree.close()
	await process_frame
	scene.set_research_data(200)
	scene._on_technologies_requested()
	await process_frame
	antimatter = _tech_node(tree, 2, "Industrial", "Antimatter Refining")
	_check(
		antimatter != null
		and not antimatter.cost_label.visible
		and antimatter.status_label.text == "AVAILABLE",
		"Completed research state persists when the tree reopens"
	)
	if antimatter != null:
		antimatter.research_requested.emit(antimatter.technology)
		await process_frame
		_check(
			not tree.research_dialog.visible,
			"Completed technologies cannot be researched again"
		)

	# Tier 1 Exploration unlocks the Colony Ship for the shipyard.
	_check(
		not scene.unlocked_ships.has("Colony Ship"),
		"Colony Ships start locked"
	)
	var colony_tech := _tech_node(tree, 1, "Exploration", "Colony Ships")
	_check(colony_tech != null, "Colony Ships card exists")
	if colony_tech != null:
		colony_tech.research_requested.emit(colony_tech.technology)
		await process_frame
		_check(tree.research_dialog.visible, "Colony Ships opens a dialog")
		_check(
			tree.dialog_cost.text == "100 RD",
			"The dialog restates the Colony Ships cost"
		)
		_check(
			tree.dialog_time.text == "5 turns",
			"The dialog restates the Colony Ships research time"
		)
		tree.dialog_confirm_button.pressed.emit()
		await process_frame
		_check(
			tree.active_research().get("id", "") == "colony_ships",
			"Colony Ships research begins"
		)
		_check(scene.research_data == 100, "Colony Ships spends 100 Research Data")
		_check(
			tree.research_turns_remaining() == 5,
			"Colony Ships takes five turns"
		)
		for i in 5:
			scene.turn_manager.advance_turn()
			await process_frame
		_check(
			not tree.is_researching()
			and tree.completed_technology_ids().has("colony_ships"),
			"Colony Ships research completes"
		)
		_check(
			scene.unlocked_ships.has("Colony Ship"),
			"Colony Ships unlocks the Colony Ship"
		)

	_finish()


func _tech_node(
	tree: TechTree, tier: int, category: String, tech_name: String
) -> TechNode:
	var cell := tree.tech_grid.get_node_or_null(
		"TechCell_%d_%s" % [tier, category.replace(" ", "")]
	) as VBoxContainer
	if cell == null:
		return null
	for child in cell.get_children():
		var node := child as TechNode
		if node != null and node.name_label.text == tech_name:
			return node
	return null


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FAIL: " + message)


func _finish() -> void:
	if _failures == 0:
		print("Research verification: PASS")
		quit(0)
	else:
		print("Research verification: FAIL (%d checks)" % _failures)
		quit(1)
