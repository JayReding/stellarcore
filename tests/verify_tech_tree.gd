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

	_check(tech_tree.tech_list.get_child_count() == 1, "One technology is rendered")
	if tech_tree.tech_list.get_child_count() == 1:
		var node := tech_tree.tech_list.get_child(0) as TechNode
		_check(node != null, "Technology card uses TechNode")
		if node != null:
			_check(node.name_label.text == "FTL Probes", "FTL Probes is displayed")
			_check(node.cost_label.text == "NO RESEARCH REQUIRED", "Default technology has no research cost")
			_check(node.status_label.text == "AVAILABLE BY DEFAULT", "Default technology is available")
	_check(tech_tree.meta_label.text.contains("1 TECHNOLOGY"), "Technology count is displayed")
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
