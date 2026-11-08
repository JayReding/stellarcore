extends SceneTree
## Verifies the turn readout, the five-second end-turn countdown, cancellation,
## and turn advancement.
## Run with:
##   godot --headless --path . --script res://tests/verify_turns.gd

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var scene := preload("res://scenes/stellar_view.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var manager: TurnManager = scene.turn_manager
	var button: Button = scene.end_turn_button
	var turn_label: Label = scene.turn_label

	_check(
		scene.get_node_or_null("UI/HUD/HintLabel") == null,
		"The old bottom hint text is removed"
	)
	_check(turn_label.visible, "Turn readout is visible")
	_check(turn_label.text == "Turn 1", "Turn readout starts at Turn 1")
	_check(manager.current_turn == 1, "Turn manager starts at turn 1")
	_check(
		is_equal_approx(manager.end_turn_seconds, 5.0),
		"End-turn countdown defaults to five seconds"
	)
	_check(button.visible, "End Turn button is visible")
	_check(button.text == "END TURN", "End Turn button has the right label")
	_check(
		button.anchor_left == 1.0
		and button.anchor_top == 1.0
		and button.anchor_right == 1.0
		and button.anchor_bottom == 1.0,
		"End Turn button is anchored to the bottom right"
	)

	button.pressed.emit()
	_check(manager.is_ending_turn(), "Clicking End Turn starts the countdown")
	_check(
		button.text == "ENDING TURN IN 5...",
		"The button itself shows the countdown"
	)
	_check(manager.current_turn == 1, "The turn does not advance immediately")
	_check(turn_label.text == "Turn 1", "The readout remains on the current turn")

	await process_frame
	_check(manager.current_turn == 1, "The turn remains current during countdown")
	_check(manager.is_ending_turn(), "The countdown is still running")

	button.pressed.emit()
	_check(not manager.is_ending_turn(), "Clicking again cancels the countdown")
	_check(button.text == "END TURN", "The button returns to End Turn")
	_check(manager.current_turn == 1, "Canceling does not advance the turn")
	_check(turn_label.text == "Turn 1", "Canceling leaves the readout unchanged")

	manager.end_turn_seconds = 0.12
	button.pressed.emit()
	_check(manager.is_ending_turn(), "A shortened countdown starts")
	await create_timer(0.25).timeout
	_check(not manager.is_ending_turn(), "The countdown completes")
	_check(manager.current_turn == 2, "The turn advances after the countdown")
	_check(turn_label.text == "Turn 2", "The readout updates to Turn 2")
	_check(button.text == "END TURN", "The button resets after advancing")

	manager.end_turn_seconds = 0.05
	button.pressed.emit()
	await create_timer(0.12).timeout
	_check(manager.current_turn == 3, "Turns continue advancing")
	_check(turn_label.text == "Turn 3", "The readout tracks later turns")

	# Main menu popup on the top left.
	scene.menu_button.pressed.emit()
	await process_frame
	_check(scene.menu_popup.visible, "MENU opens the main menu popup")
	_check(scene._is_overlay_open(), "The open menu counts as an overlay")
	_check(
		scene.exit_to_menu_button.text == "EXIT TO MAIN MENU",
		"The menu offers an exit to the title screen"
	)
	_check(
		scene.quit_button.text == "QUIT GAME",
		"The menu offers quitting the game"
	)
	scene.exit_to_menu_button.pressed.emit()
	await process_frame
	_check(
		not scene.menu_popup.visible and scene.menu_confirm.visible,
		"Exit swaps the menu for a confirmation"
	)
	scene.confirm_cancel_button.pressed.emit()
	await process_frame
	_check(
		scene.menu_popup.visible and not scene.menu_confirm.visible,
		"Cancel returns to the menu"
	)
	scene.menu_button.pressed.emit()
	await process_frame
	_check(not scene.menu_popup.visible, "MENU toggles the popup closed")
	scene.menu_button.pressed.emit()
	await process_frame
	var away_click := InputEventMouseButton.new()
	away_click.button_index = MOUSE_BUTTON_LEFT
	away_click.pressed = true
	away_click.position = Vector2(1600, 900)
	root.push_input(away_click)
	await process_frame
	_check(not scene.menu_popup.visible, "Clicking the dim closes the menu")

	_finish()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FAIL: " + message)


func _finish() -> void:
	if _failures == 0:
		print("Turn verification: PASS")
		quit(0)
	else:
		print("Turn verification: FAIL (%d checks)" % _failures)
		quit(1)
