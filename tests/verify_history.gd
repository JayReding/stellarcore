extends SceneTree
## Verifies the message history page: logging with star context, newest-first
## rows, opening from the status line, focusing a row's star, and closing.
## Run with:
##   godot --headless --path . --script res://tests/verify_history.gd

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
	var other: StarData = null
	for star in scene._galaxy.stars:
		if star != home:
			other = star
			break
	_check(home != null and other != null, "Home and another system exist")
	if home == null or other == null:
		_finish()
		return

	_check(scene._message_log.is_empty(), "The log starts empty")

	scene._set_status("First notice", Color.WHITE, home)
	scene._set_status("Second notice", Color.WHITE)
	scene._set_status("Third notice", Color.WHITE, other)
	_check(scene._message_log.size() == 3, "Status messages are logged")
	_check(
		scene._message_log[0].get("star_id", "") == home.id,
		"Entries record the generating system"
	)
	_check(
		scene._message_log[1].get("star_id", "") == "",
		"System-free messages record no star"
	)

	_click_status_label(scene)
	await process_frame
	var history: HistoryView = scene._history_view
	_check(history != null, "History view is created on demand")
	if history == null:
		_finish()
		return
	_check(history.visible, "Clicking the status line opens history")
	_check(scene._is_overlay_open(), "Stellar View treats history as an overlay")
	_check(
		history.count_label.text == "3 MESSAGES",
		"History counts its entries"
	)
	_check(
		history.message_list.get_child_count() == 3,
		"History lists every entry"
	)
	var first_row := history.message_list.get_child(0) as Button
	_check(first_row != null, "History rows are buttons")
	if first_row == null:
		_finish()
		return
	_check(
		(first_row.get_child(0) as HBoxContainer) != null,
		"Rows carry their content"
	)
	var first_text := ""
	for label in first_row.find_children("*", "Label", true, false):
		if (label as Label).text == "Third notice":
			first_text = "Third notice"
	_check(first_text == "Third notice", "Newest messages come first")
	_check(not first_row.disabled, "Starred messages are clickable")

	# The middle row has no star, so clicking it dismisses nothing.
	var plain_row := history.message_list.get_child(1) as Button
	_check(plain_row != null and plain_row.disabled, "Star-free rows are disabled")
	if plain_row != null:
		plain_row.pressed.emit()
		await process_frame
		_check(history.visible, "Disabled rows do not close history")

	# Clicking a starred row focuses its system on the map.
	first_row.pressed.emit()
	await process_frame
	_check(not history.visible, "Choosing a message closes history")
	_check(
		scene._selected_star != null and scene._selected_star.data == other,
		"The chosen system is selected"
	)
	_check(
		scene.camera_rig._focus_tween != null,
		"The camera starts focusing the chosen system"
	)

	# Back and Escape both close the page.
	_click_status_label(scene)
	await process_frame
	_check(history.visible, "History reopens from the status line")
	history.back_button.pressed.emit()
	await process_frame
	_check(not history.visible, "Back button closes history")
	_click_status_label(scene)
	await process_frame
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	history._unhandled_input(escape)
	await process_frame
	_check(not history.visible, "Escape closes history")

	# Old entries drop off past the cap, newest survive.
	for i in 210:
		scene._set_status("Filler %d" % i, Color.WHITE)
	_check(
		scene._message_log.size() == 200,
		"The log caps at two hundred entries"
	)
	_check(
		scene._message_log.back().get("text", "") == "Filler 209",
		"The newest entry survives the cap"
	)

	_finish()


func _click_status_label(scene: Node) -> void:
	var label := scene.status_label as Control
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(960, 1030)
	label.gui_input.emit(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(960, 1030)
	label.gui_input.emit(release)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FAIL: " + message)


func _finish() -> void:
	if _failures == 0:
		print("History verification: PASS")
		quit(0)
	else:
		print("History verification: FAIL (%d checks)" % _failures)
		quit(1)
