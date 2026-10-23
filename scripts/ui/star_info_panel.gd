class_name StarInfoPanel
extends PanelContainer
## Right-hand readout for the currently selected star system.

signal scan_requested(data: StarData)
signal system_view_requested(data: StarData)
signal shipyard_requested(data: StarData)
signal fleet_selected(fleet: FleetData)

@onready var swatch: ColorRect = %Swatch
@onready var name_label: Label = %NameLabel
@onready var class_label: Label = %ClassLabel
@onready var description_label: Label = %DescriptionLabel
@onready var temperature_label: Label = %TemperatureLabel
@onready var size_label: Label = %SizeLabel
@onready var distance_label: Label = %DistanceLabel
@onready var survey_label: Label = %SurveyLabel
@onready var planet_count_label: Label = %PlanetCountLabel
@onready var planet_list: VBoxContainer = %PlanetList
@onready var scan_button: Button = %ScanButton
@onready var fleet_list: VBoxContainer = %FleetList
@onready var no_fleets_label: Label = %NoFleetsLabel
@onready var shipyard_button: Button = %ShipyardButton
@onready var eyebrow: Label = %Eyebrow

var _tween: Tween
var _current_data: StarData


func _ready() -> void:
	hide_panel(true)
	# The Scan button is retired now that arriving probes survey systems.
	scan_button.visible = false
	scan_button.pressed.connect(_on_scan_pressed)
	shipyard_button.pressed.connect(_on_shipyard_pressed)


func show_star(data: StarData, distance_from_home: float = 0.0) -> void:
	if data == null:
		return

	_current_data = data
	name_label.text = data.display_name
	swatch.color = data.class_color()
	class_label.text = data.classification()
	class_label.add_theme_color_override(
		"font_color", data.class_color().lightened(0.18)
	)
	description_label.text = data.class_description()
	temperature_label.text = data.temperature_display()
	size_label.text = "%.2f × G-class" % data.size_factor()
	distance_label.text = "Home system" if data.is_home else "%.1f ly" % distance_from_home
	_populate_planets(data)
	_populate_fleets(data)
	_update_shipyard(data)

	eyebrow.text = "HOME SYSTEM" if data.is_home else "SELECTED SYSTEM"
	eyebrow.add_theme_color_override(
		"font_color",
		Color(0.95, 0.78, 0.45) if data.is_home else Color(0.42, 0.62, 0.84)
	)
	_fade_in()


func _populate_planets(data: StarData) -> void:
	for child in planet_list.get_children():
		planet_list.remove_child(child)
		child.queue_free()

	planet_count_label.visible = data.surveyed
	planet_list.visible = data.surveyed and not data.planets.is_empty()
	survey_label.visible = not data.surveyed

	if not data.surveyed:
		survey_label.text = "Unsurveyed"
		return

	planet_count_label.text = "%d planets" % data.planets.size()
	for planet in data.planets:
		planet_list.add_child(_create_planet_row(planet))


func _populate_fleets(data: StarData) -> void:
	for child in fleet_list.get_children():
		fleet_list.remove_child(child)
		child.queue_free()

	var fleets: Array[FleetData] = []
	for fleet in data.fleets:
		if not fleet.in_transit:
			fleets.append(fleet)

	no_fleets_label.visible = fleets.is_empty()
	fleet_list.visible = not fleets.is_empty()
	for fleet in fleets:
		fleet_list.add_child(_create_fleet_row(fleet))


func _create_fleet_row(fleet: FleetData) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 26)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "%s — %s\nClick to manage this fleet" % [
		fleet.name, fleet.ship_summary()
	]
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override(
		"hover", _planet_row_style(Color(0.12, 0.25, 0.4, 0.45))
	)
	button.add_theme_stylebox_override(
		"pressed", _planet_row_style(Color(0.05, 0.13, 0.23, 0.7))
	)
	button.pressed.connect(_on_fleet_pressed.bind(fleet))

	var row := HBoxContainer.new()
	button.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 6.0
	row.offset_top = 2.0
	row.offset_right = -6.0
	row.offset_bottom = -2.0
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(7, 7)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.color = Color(0.42, 0.72, 1.0)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(dot)

	var name_label := Label.new()
	name_label.text = fleet.name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.8, 0.87, 0.96))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)

	var summary_label := Label.new()
	summary_label.text = fleet.ship_summary()
	summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary_label.add_theme_font_size_override("font_size", 10)
	summary_label.add_theme_color_override("font_color", Color(0.55, 0.68, 0.82))
	summary_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(summary_label)

	return button


func _on_fleet_pressed(fleet: FleetData) -> void:
	if fleet == null:
		return
	fleet_selected.emit(fleet)


func _update_shipyard(data: StarData) -> void:
	var has_shipyard := data.has_shipyard()
	shipyard_button.disabled = not has_shipyard
	if has_shipyard:
		shipyard_button.tooltip_text = "Open the %s shipyard" % data.shipyard_planet.designation
	else:
		shipyard_button.tooltip_text = "No shipyard in this system"


func _on_shipyard_pressed() -> void:
	if _current_data == null or not _current_data.has_shipyard():
		return
	shipyard_requested.emit(_current_data)


func _on_scan_pressed() -> void:
	if _current_data == null:
		return
	scan_requested.emit(_current_data)


func _on_planet_pressed() -> void:
	if _current_data == null or not _current_data.surveyed:
		return
	system_view_requested.emit(_current_data)


func _create_planet_row(planet: PlanetData) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 24)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "Open %s in System View" % planet.designation
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override(
		"hover", _planet_row_style(Color(0.12, 0.25, 0.4, 0.45))
	)
	button.add_theme_stylebox_override(
		"pressed", _planet_row_style(Color(0.05, 0.13, 0.23, 0.7))
	)
	button.pressed.connect(_on_planet_pressed)

	var row := HBoxContainer.new()
	button.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 6.0
	row.offset_top = 2.0
	row.offset_right = -6.0
	row.offset_bottom = -2.0
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(8, 8)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.color = planet.class_color()
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(dot)

	var name_label := Label.new()
	name_label.text = planet.designation
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color(0.8, 0.87, 0.96))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)

	var class_label := Label.new()
	class_label.text = planet.class_name_label()
	class_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	class_label.add_theme_font_size_override("font_size", 11)
	class_label.add_theme_color_override("font_color", Color(0.55, 0.66, 0.78))
	class_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(class_label)

	return button


func _planet_row_style(background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	return style


func hide_panel(immediate := false) -> void:
	_kill_tween()

	if immediate:
		visible = false
		modulate.a = 0.0
		return

	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.18)
	_tween.tween_callback(func() -> void: visible = false)


func _fade_in() -> void:
	_kill_tween()
	var was_hidden := not visible
	visible = true
	if was_hidden:
		modulate.a = 0.0

	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.2)


func _kill_tween() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = null
