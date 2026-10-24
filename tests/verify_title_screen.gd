extends SceneTree
## Verifies the title screen: background art, title theme, menu entries,
## New Game transition, Credits popup, and Quit wiring.
## Run with:
##   godot --headless --path . --script res://tests/verify_title_screen.gd

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	change_scene_to_file("res://scenes/title_screen.tscn")
	for i in 4:
		await process_frame
	var title := current_scene as TitleScreen

	_check(title != null and title.visible, "Title screen is visible")
	_check(
		title.background.texture != null,
		"Title screen shows its background art"
	)
	_check(
		title.music_player.stream != null,
		"Title screen has its theme music"
	)
	_check(title.music_player.playing, "Title theme starts playing")

	var buttons := _menu_buttons(title)
	_check(buttons.size() == 5, "Menu has five entries")
	var labels := ["New Game", "Load Saved Game", "Options", "Credits", "Quit to Desktop"]
	_check(
		_button_labels(buttons) == labels,
		"Menu entries are in order"
	)
	_check(
		title.new_game_button != null and not title.new_game_button.disabled,
		"New Game is available"
	)
	_check(
		title.load_button != null and title.load_button.disabled,
		"Load Saved Game waits for a later slice"
	)
	_check(
		title.options_button != null and title.options_button.disabled,
		"Options wait for a later slice"
	)
	_check(
		title.credits_button != null and not title.credits_button.disabled,
		"Credits is available"
	)
	_check(
		title.quit_button != null and not title.quit_button.disabled,
		"Quit to Desktop is available"
	)

	_check(
		not title.credits_panel.visible,
		"Credits start hidden"
	)
	title.credits_button.pressed.emit()
	await process_frame
	_check(title.credits_panel.visible, "Credits opens its panel")
	_check(
		title.credits_panel.visible and title.credits_backdrop.visible,
		"Credits dims the background"
	)
	title.credits_close_button.pressed.emit()
	await process_frame
	_check(not title.credits_panel.visible, "Credits closes")

	title.new_game_button.pressed.emit()
	for i in 6:
		await process_frame
	_check(not is_instance_valid(title), "New Game leaves the title screen")
	var stellar_view := root.get_node_or_null("StellarView")
	_check(
		stellar_view != null and stellar_view.visible,
		"New Game starts the Stellar View"
	)

	_finish()


func _menu_buttons(title: Control) -> Array:
	var menu := title.get_node_or_null("Menu") as VBoxContainer
	if menu == null:
		return []
	var buttons: Array = []
	for child in menu.get_children():
		if child is Button:
			buttons.append(child)
	return buttons


func _button_labels(buttons: Array) -> Array:
	var labels: Array = []
	for button in buttons:
		labels.append((button as Button).text)
	return labels


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FAIL: " + message)


func _finish() -> void:
	if _failures == 0:
		print("Title screen verification: PASS")
		quit(0)
	else:
		print("Title screen verification: FAIL (%d checks)" % _failures)
		quit(1)
