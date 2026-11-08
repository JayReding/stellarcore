class_name HistoryView
extends CanvasLayer
## Full-screen message history. Lists every past status message, newest
## first. Entries tied to a star system are clickable and focus that star.

signal message_chosen(star_id: String)

@onready var root: Control = $Root
@onready var back_button: Button = %BackButton
@onready var count_label: Label = %HistoryCount
@onready var message_list: VBoxContainer = %MessageList
@onready var empty_label: Label = %EmptyLabel

var _tween: Tween


func _ready() -> void:
	back_button.pressed.connect(close)
	visible = false


func open(log: Array) -> void:
	_populate(log)
	visible = true
	_kill_tween()
	root.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(root, "modulate:a", 1.0, 0.2)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func close() -> void:
	if not visible:
		return
	_kill_tween()
	visible = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.is_action_pressed("ui_cancel")
	):
		close()
		get_viewport().set_input_as_handled()


func _populate(log: Array) -> void:
	for child in message_list.get_children():
		message_list.remove_child(child)
		child.queue_free()

	var count := log.size()
	if count == 1:
		count_label.text = "1 MESSAGE"
	else:
		count_label.text = "%d MESSAGES" % count
	empty_label.visible = count == 0

	for i in range(log.size() - 1, -1, -1):
		message_list.add_child(_make_row(log[i]))


func _make_row(entry: Dictionary) -> Button:
	var star_id := str(entry.get("star_id", ""))
	var system_name := str(entry.get("system_name", ""))
	var clickable := not star_id.is_empty()

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 52)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW
	)
	button.disabled = not clickable
	button.tooltip_text = ("Focus %s" % system_name) if clickable else ""
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", entry.get("color", Color.WHITE))
	button.add_theme_stylebox_override("normal", _row_style(Color(0, 0, 0, 1)))
	button.add_theme_stylebox_override("hover", _row_style(Color(0, 0.565, 0.941, 0.28)))
	button.add_theme_stylebox_override("pressed", _row_style(Color(0, 0.08, 0.16, 1)))
	button.add_theme_stylebox_override("disabled", _row_style(Color(0.07, 0.07, 0.08, 1)))
	if clickable:
		button.pressed.connect(_on_row_pressed.bind(star_id))

	var row := HBoxContainer.new()
	button.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12.0
	row.offset_top = 6.0
	row.offset_right = -12.0
	row.offset_bottom = -6.0
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var message_label := Label.new()
	message_label.text = str(entry.get("text", ""))
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 16)
	message_label.add_theme_color_override(
		"font_color", entry.get("color", Color.WHITE)
	)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(message_label)

	var system_label := Label.new()
	system_label.text = system_name if not system_name.is_empty() else "—"
	system_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	system_label.add_theme_font_size_override("font_size", 13)
	system_label.add_theme_color_override("font_color", LCARS.TEXT_DIM)
	system_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(system_label)

	return button


func _row_style(background: Color) -> StyleBoxFlat:
	return LCARS.row_style(background)


func _on_row_pressed(star_id: String) -> void:
	message_chosen.emit(star_id)


func _kill_tween() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = null
