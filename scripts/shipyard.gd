class_name ShipyardView
extends CanvasLayer
## Full-screen shipyard. Hull selection is on the left, customization in the
## center, and the system's fleets on the right. Production is free until ship
## costs are assigned.

signal closed

const HULLS := [
	{
		"id": "ftl_probe",
		"name": "FTL Probe",
		"role": "Reconnaissance",
		"icon": "FTL",
		"description": (
			"A small, unmanned faster-than-light probe built for deep-space "
			+ "reconnaissance and survey support. FTL Probes are single-use "
			+ "vehicles. The power needed to transmit system data casuses them "
			+ "to burn out after arrival and data transmission. However, they "
			+ "can be built quickly from limited resources."
		),
		"customization": "None",
	},
]

@onready var root: Control = $Root
@onready var back_button: Button = %BackButton
@onready var meta_label: Label = %MetaLabel
@onready var hull_list: VBoxContainer = %HullList
@onready var hull_icon_label: Label = %HullIconLabel
@onready var hull_name_label: Label = %HullNameLabel
@onready var hull_role_label: Label = %HullRoleLabel
@onready var hull_description_label: Label = %HullDescriptionLabel
@onready var hull_type_value: Label = %HullTypeValue
@onready var hull_role_value: Label = %HullRoleValue
@onready var hull_customization_value: Label = %HullCustomizationValue
@onready var no_options_label: Label = %NoOptionsLabel
@onready var no_options_note: Label = %NoOptionsNote
@onready var fleet_list: VBoxContainer = %FleetList
@onready var fleet_scroll: ScrollContainer = %FleetScroll
@onready var fleet_spacer: Control = %FleetSpacer
@onready var fleet_count_label: Label = %FleetCountLabel
@onready var no_fleets_label: Label = %NoFleetsLabel
@onready var feedback_label: Label = %FeedbackLabel
@onready var resource_note: Label = %ResourceNote
@onready var produce_button: Button = %ProduceButton

var _system_data: StarData
var _galaxy: Galaxy
var _resources: ResourceStockpile
var _selected_hull: Dictionary = HULLS[0]
var _selected_fleet: FleetData
var _feedback := ""
var _tween: Tween


func _ready() -> void:
	back_button.pressed.connect(close)
	produce_button.pressed.connect(_on_produce_pressed)
	_populate_hulls()
	_show_hull(_selected_hull)
	_populate_fleets()
	_update_header()
	_update_production_status()
	visible = false


func open(
	data: StarData,
	galaxy: Galaxy = null,
	resources: ResourceStockpile = null
) -> void:
	_galaxy = galaxy
	_resources = resources
	if data == null or not data.has_shipyard():
		return

	_system_data = data
	_selected_fleet = null
	_selected_hull = HULLS[0]
	_feedback = ""
	_populate_hulls()
	_show_hull(_selected_hull)
	_populate_fleets()
	_update_header()
	_update_resource_note()
	_update_production_status()

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
	closed.emit()


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


func _populate_hulls() -> void:
	for child in hull_list.get_children():
		hull_list.remove_child(child)
		child.queue_free()

	for hull in HULLS:
		var button := Button.new()
		button.text = str(hull.get("name", "Hull"))
		button.custom_minimum_size = Vector2(0, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = str(hull.get("description", ""))
		button.add_theme_font_size_override("font_size", 16)

		var selected := (
			str(hull.get("id", "")) == str(_selected_hull.get("id", ""))
		)
		button.add_theme_stylebox_override(
			"normal", _hull_button_style(selected)
		)
		button.add_theme_stylebox_override(
			"hover", _hull_button_style(selected, true)
		)
		button.add_theme_stylebox_override(
			"pressed", _hull_button_style(selected, false, true)
		)
		button.pressed.connect(_on_hull_pressed.bind(hull))
		hull_list.add_child(button)


func _on_hull_pressed(hull: Dictionary) -> void:
	_selected_hull = hull
	_feedback = ""
	_populate_hulls()
	_show_hull(hull)
	_update_production_status()


func _show_hull(hull: Dictionary) -> void:
	hull_icon_label.text = str(hull.get("icon", "H"))
	hull_name_label.text = str(hull.get("name", "Hull"))
	hull_role_label.text = str(hull.get("role", ""))
	hull_description_label.text = str(hull.get("description", ""))
	hull_type_value.text = str(hull.get("name", "Hull"))
	hull_role_value.text = str(hull.get("role", ""))
	hull_customization_value.text = str(hull.get("customization", "None"))
	no_options_label.text = "NO CUSTOMIZATION OPTIONS"
	no_options_note.text = (
		"This hull type has no modules or variants to configure."
	)


func _populate_fleets() -> void:
	for child in fleet_list.get_children():
		fleet_list.remove_child(child)
		child.queue_free()

	if _system_data == null:
		fleet_count_label.text = "0"
		fleet_scroll.visible = false
		fleet_spacer.visible = true
		no_fleets_label.visible = true
		return

	var fleets := _stationed_fleets()
	fleet_count_label.text = str(fleets.size())
	fleet_scroll.visible = not fleets.is_empty()
	fleet_spacer.visible = fleets.is_empty()
	no_fleets_label.visible = fleets.is_empty()

	for fleet in fleets:
		fleet_list.add_child(_create_fleet_row(fleet))


func _stationed_fleets() -> Array[FleetData]:
	var fleets: Array[FleetData] = []
	if _system_data == null:
		return fleets
	for fleet in _system_data.fleets:
		if not fleet.in_transit:
			fleets.append(fleet)
	return fleets


func _create_fleet_row(fleet: FleetData) -> Button:
	var selected := fleet == _selected_fleet
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 56)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = "Select or deselect %s" % fleet.name
	button.add_theme_stylebox_override("normal", _fleet_row_style(selected))
	button.add_theme_stylebox_override(
		"hover", _fleet_row_style(selected, true)
	)
	button.add_theme_stylebox_override(
		"pressed", _fleet_row_style(selected, false, true)
	)
	button.pressed.connect(_on_fleet_pressed.bind(fleet))

	var row := HBoxContainer.new()
	button.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10.0
	row.offset_top = 6.0
	row.offset_right = -10.0
	row.offset_bottom = -6.0
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 1)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = fleet.name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.84, 0.92, 1))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(name_label)

	var summary_label := Label.new()
	summary_label.text = fleet.ship_summary()
	summary_label.add_theme_font_size_override("font_size", 11)
	summary_label.add_theme_color_override("font_color", Color(0.55, 0.68, 0.82))
	summary_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(summary_label)

	if selected:
		var selected_label := Label.new()
		selected_label.text = "SELECTED"
		selected_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		selected_label.add_theme_font_size_override("font_size", 9)
		selected_label.add_theme_color_override(
			"font_color", Color(0.48, 0.8, 1)
		)
		selected_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(selected_label)

	return button


func _on_fleet_pressed(fleet: FleetData) -> void:
	if _selected_fleet == fleet:
		_selected_fleet = null
	else:
		_selected_fleet = fleet
	_feedback = ""
	_populate_fleets()
	_update_production_status()


func _on_produce_pressed() -> void:
	if _system_data == null:
		return

	var hull_name := str(_selected_hull.get("name", "FTL Probe"))
	var fleet: FleetData = _selected_fleet
	if fleet == null or fleet.in_transit or not _system_data.fleets.has(fleet):
		fleet = FleetData.new()
		fleet.name = _next_fleet_name()
		fleet.dock_at(_system_data)
		_system_data.fleets.append(fleet)
		_selected_fleet = null

	fleet.add_ship(hull_name)
	_feedback = "Produced 1 %s in %s." % [hull_name, fleet.name]
	_populate_fleets()
	_update_header()
	_update_production_status()


func _next_fleet_name() -> String:
	if _galaxy != null:
		return _galaxy.next_fleet_name(_system_data.display_name)

	var used: Dictionary = {}
	for fleet in _system_data.fleets:
		used[fleet.name] = true
	var ordinal := 0
	while used.has(FleetData.default_name(_system_data.display_name, ordinal)):
		ordinal += 1
	return FleetData.default_name(_system_data.display_name, ordinal)


func _update_header() -> void:
	if _system_data == null or not _system_data.has_shipyard():
		return

	var count := _stationed_fleets().size()
	var noun := "FLEET" if count == 1 else "FLEETS"
	meta_label.text = "%s  •  %s SYSTEM  •  %d %s" % [
		_system_data.shipyard_planet.designation.to_upper(),
		_system_data.display_name.to_upper(),
		count,
		noun,
	]


func refresh() -> void:
	if not visible:
		return
	_populate_fleets()
	_update_header()
	_update_resource_note()
	_update_production_status()


func _update_resource_note() -> void:
	if _resources == null:
		resource_note.text = "Ship production costs are not yet assigned."
		return
	resource_note.text = (
		"Local Titanium: %d. Ship production costs are not yet assigned."
		% _resources.get_amount(ResourceStockpile.TITANIUM)
	)


func _update_production_status() -> void:
	if _system_data == null:
		feedback_label.text = ""
		return

	var status := _feedback
	if status.is_empty():
		if _selected_fleet == null:
			status = "No fleet selected — Produce Ship will create a new fleet."
		else:
			status = "Selected %s — Produce Ship will add one %s." % [
				_selected_fleet.name,
				str(_selected_hull.get("name", "ship")),
			]
	feedback_label.text = status


func _hull_button_style(
	selected: bool, hover := false, pressed := false
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 10.0
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6

	if selected:
		style.bg_color = Color(0.08, 0.2, 0.34, 0.95)
		style.border_color = Color(0.42, 0.72, 1.0, 0.9)
	else:
		style.bg_color = Color(0.028, 0.055, 0.09, 0.9)
		style.border_color = Color(0.18, 0.34, 0.52, 0.7)

	if hover:
		style.bg_color = (
			Color(0.11, 0.26, 0.43, 1.0)
			if selected
			else Color(0.05, 0.12, 0.2, 0.95)
		)
		style.border_color = Color(0.38, 0.68, 1.0, 0.9)
	if pressed:
		style.bg_color = Color(0.045, 0.12, 0.21, 1.0)

	return style


func _fleet_row_style(
	selected: bool, hover := false, pressed := false
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6

	if selected:
		style.bg_color = Color(0.06, 0.16, 0.27, 0.95)
		style.border_color = Color(0.4, 0.7, 1.0, 0.85)
	else:
		style.bg_color = Color(0.025, 0.05, 0.085, 0.85)
		style.border_color = Color(0.17, 0.31, 0.48, 0.65)

	if hover:
		style.bg_color = (
			Color(0.09, 0.22, 0.36, 1.0)
			if selected
			else Color(0.05, 0.12, 0.2, 0.95)
		)
		style.border_color = Color(0.36, 0.64, 0.96, 0.9)
	if pressed:
		style.bg_color = Color(0.04, 0.1, 0.17, 1.0)

	return style


func _kill_tween() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = null
