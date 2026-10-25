class_name ColonyDialog
extends CanvasLayer
## Modal dialog for choosing which planet hosts a newly arrived colony.
## Opening it does not found anything; confirming spends one Colony Ship from
## the fleet and builds a Colony on the chosen planet. Closing it postpones
## the decision, which can be reopened by selecting the fleet again.

signal colony_chosen(fleet: FleetData, star: StarData, planet: PlanetData)
signal cancelled
signal closed

@onready var root: Control = %Root
@onready var dim: ColorRect = $Root/Dim
@onready var panel: PanelContainer = %Panel
@onready var close_button: Button = %CloseButton
@onready var colony_title_label: Label = %ColonyTitleLabel
@onready var colony_system_label: Label = %ColonySystemLabel
@onready var colony_planet_list: VBoxContainer = %ColonyPlanetList
@onready var colony_note_label: Label = %ColonyNoteLabel

var _fleet: FleetData
var _star: StarData
var _tween: Tween


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	dim.gui_input.connect(_on_dim_input)
	visible = false


func open_dialog(fleet: FleetData, star: StarData) -> void:
	if fleet == null or star == null:
		return

	_fleet = fleet
	_star = star
	colony_title_label.text = "Choose a home for the colony"
	colony_system_label.text = "%s  •  %s" % [
		fleet.name, star.display_name
	]
	_populate_planets()
	_show()


func close() -> void:
	if not visible:
		return
	visible = false
	_fleet = null
	_star = null
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	closed.emit()


## Closes the dialog when the fleet it is showing has arrived or been removed.
func close_if_showing_fleet(fleet: FleetData) -> void:
	if not visible or fleet == null or _fleet != fleet:
		return
	close()


func showing_fleet(fleet: FleetData) -> bool:
	return visible and fleet != null and _fleet == fleet


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.is_action_pressed("ui_cancel")
	):
		_on_close_pressed()
		get_viewport().set_input_as_handled()


func _populate_planets() -> void:
	for child in colony_planet_list.get_children():
		colony_planet_list.remove_child(child)
		child.queue_free()

	if _star == null:
		return
	for planet in _star.planets:
		if planet == null:
			continue
		colony_planet_list.add_child(_make_planet_row(planet))


func _make_planet_row(planet: PlanetData) -> Button:
	var taken := planet.has_structure(StructureData.COLONY)
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.disabled = taken
	button.text = "%s  •  %s" % [
		planet.designation, planet.class_name_label()
	]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.tooltip_text = "%s — %s" % [
		planet.designation, planet.class_name_label()
	]
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color(0.84, 0.93, 1))
	button.add_theme_color_override("font_hover_color", Color(0.97, 1, 1))
	button.add_theme_color_override(
		"font_disabled_color", Color(0.42, 0.52, 0.64)
	)
	button.add_theme_stylebox_override("normal", _row_style(false))
	button.add_theme_stylebox_override("hover", _row_style(true))
	button.add_theme_stylebox_override("pressed", _row_style(false, true))
	button.add_theme_stylebox_override("disabled", _row_style(false))
	if taken:
		button.text += "  •  OCCUPIED"
	else:
		button.pressed.connect(_on_planet_pressed.bind(planet))
	return button


func _row_style(hover := false, pressed := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.content_margin_left = 16.0
	style.content_margin_top = 10.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 10.0
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.bg_color = Color(0.04, 0.1, 0.17, 0.95)
	style.border_color = Color(0.18, 0.34, 0.52, 0.7)
	if hover:
		style.bg_color = Color(0.08, 0.2, 0.34, 0.98)
		style.border_color = Color(0.38, 0.68, 1, 0.9)
	if pressed:
		style.bg_color = Color(0.03, 0.08, 0.14, 1)
	return style


func _on_planet_pressed(planet: PlanetData) -> void:
	if _fleet == null or _star == null or planet == null:
		return
	var fleet := _fleet
	var star := _star
	close()
	colony_chosen.emit(fleet, star, planet)


func _on_close_pressed() -> void:
	close()
	cancelled.emit()


func _on_dim_input(event: InputEvent) -> void:
	if (
		visible
		and event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		_on_close_pressed()


func _show() -> void:
	visible = true
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_kill_tween()
	panel.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(panel, "modulate:a", 1.0, 0.14)


func _kill_tween() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = null
