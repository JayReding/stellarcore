class_name ShipyardView
extends CanvasLayer
## Full-screen shipyard. Hull selection is on the left, customization in the
## center, and the system's fleets on the right. Production spends resources
## from the system's local stockpile.

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
			+ "can be built quickly from limited resources. Exploring new "
			+ "worlds grants bonus Research Data."
		),
		"customization": "None",
		"cost": {
			ResourceStockpile.TITANIUM: 25,
			ResourceStockpile.ANTIMATTER: 10,
		},
	},
]


## Hulls gated behind research. Each unlocks when its ship name appears in the
## player's unlocked-ships list.
const LOCKED_HULLS := [
	{
		"id": "colony_ship",
		"name": "Colony Ship",
		"role": "Colonization",
		"icon": "COL",
		"description": (
			"A slow sleeper ship that carries colonists to a new star system. "
			+ "It is consumed on arrival to found a Colony on the system's "
			+ "first open planet. Travels at 5 light years per turn and costs "
			+ "1 Antimatter for now; loading fuel for longer voyages comes later."
		),
		"customization": "None",
		"cost": {
			ResourceStockpile.TITANIUM: 500,
			ResourceStockpile.ANTIMATTER: 1,
		},
	},
]

@onready var root: Control = $Root
@onready var back_button: Button = %BackButton
@onready var meta_label: Label = %MetaLabel
@onready var hull_list: VBoxContainer = %HullList
@onready var hull_count_label: Label = %HullCountLabel
@onready var hull_note: Label = %HullNote
@onready var hull_icon_label: Label = %HullIconLabel
@onready var hull_name_label: Label = %HullNameLabel
@onready var hull_role_label: Label = %HullRoleLabel
@onready var hull_description_label: Label = %HullDescriptionLabel
@onready var hull_type_value: Label = %HullTypeValue
@onready var hull_role_value: Label = %HullRoleValue
@onready var hull_customization_value: Label = %HullCustomizationValue
@onready var cost_value: HBoxContainer = %CostValue
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
var _unlocked_ships: Array[String] = []
var _tween: Tween


## Hulls the player may currently build: the default set plus every locked
## hull whose ship name was unlocked by research.
static func available_hulls(unlocked_ships: Array[String] = []) -> Array:
	var hulls: Array = HULLS.duplicate()
	for hull in LOCKED_HULLS:
		if unlocked_ships.has(str(hull.get("name", ""))):
			hulls.append(hull)
	return hulls


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
	resources: ResourceStockpile = null,
	unlocked_ships: Array[String] = []
) -> void:
	_galaxy = galaxy
	if data == null or not data.has_shipyard():
		return

	_resources = resources if resources != null else data.resources
	_system_data = data
	_selected_fleet = null
	_unlocked_ships = unlocked_ships.duplicate()
	_selected_hull = _available_hulls()[0]
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

	var available := _available_hulls()
	hull_count_label.text = str(available.size())
	if available.size() == 1:
		hull_note.text = (
			"One hull type is available.\n"
			+ "Additional hulls will unlock through research."
		)
	else:
		hull_note.text = "%d hull types are available." % available.size()

	for hull in available:
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


func _selected_hull_cost() -> Dictionary:
	var cost: Dictionary = _selected_hull.get("cost", {})
	return cost


func _can_afford_selected_hull() -> bool:
	var cost := _selected_hull_cost()
	if cost.is_empty():
		return true
	return _resources != null and _resources.can_afford(cost)


func _missing_resources() -> Dictionary:
	var missing: Dictionary = {}
	if _resources == null:
		return _selected_hull_cost().duplicate()
	for resource_id in _selected_hull_cost():
		var shortfall := (
			int(_selected_hull_cost()[resource_id])
			- _resources.get_amount(str(resource_id))
		)
		if shortfall > 0:
			missing[str(resource_id)] = shortfall
	return missing


func _on_produce_pressed() -> void:
	if _system_data == null:
		return
	if not _can_afford_selected_hull():
		_feedback = "Insufficient resources — %s." % _missing_resources_text()
		_update_production_status()
		return
	if _resources != null:
		_resources.spend(_selected_hull_cost())

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
	_ensure_selected_hull()
	_populate_hulls()
	_show_hull(_selected_hull)
	_populate_fleets()
	_update_header()
	_update_resource_note()
	_update_production_status()


func _available_hulls() -> Array:
	return available_hulls(_unlocked_ships)


## Keeps the selection valid when the available hull set changes.
func _ensure_selected_hull() -> void:
	var hulls := _available_hulls()
	if hulls.is_empty():
		return
	if not hulls.has(_selected_hull):
		_selected_hull = hulls[0]


func _update_resource_note() -> void:
	var cost := _selected_hull_cost()
	if cost.is_empty():
		resource_note.text = "This hull has no resource cost."
		return
	if _resources == null:
		resource_note.text = "No local stockpile is available for production."
		return

	var parts: Array[String] = []
	for resource_id in cost:
		var id := str(resource_id)
		parts.append("%d %s" % [
			_resources.get_amount(id),
			ResourceStockpile.display_name(id),
		])
	resource_note.text = "Local stockpile: %s" % "  •  ".join(parts)


func _update_cost_readout() -> void:
	for child in cost_value.get_children():
		cost_value.remove_child(child)
		child.queue_free()

	var cost := _selected_hull_cost()
	if cost.is_empty():
		_add_cost_label("Free", Color(0.78, 0.86, 0.96), "")
		return

	var missing := _missing_resources()
	for resource_id in cost:
		var id := str(resource_id)
		var required := int(cost[resource_id])
		var shortfall := int(missing.get(id, 0))
		var text := "%d %s" % [
			required, ResourceStockpile.display_name(id)
		]
		var color := Color(0.78, 0.86, 0.96)
		if shortfall > 0:
			text += " (%d short)" % shortfall
			color = Color(0.96, 0.45, 0.45)
		_add_cost_label(text, color, id)


func _add_cost_label(text: String, color: Color, resource_id: String) -> void:
	var label := Label.new()
	label.name = "Cost_%s" % resource_id if not resource_id.is_empty() else "Cost"
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_value.add_child(label)


func _missing_resources_text() -> String:
	var missing := _missing_resources()
	var parts: Array[String] = []
	for resource_id in missing:
		parts.append("%d %s" % [
			int(missing[resource_id]),
			ResourceStockpile.display_name(str(resource_id)),
		])
	if parts.is_empty():
		return "none"
	return " and ".join(parts)


func _update_production_status() -> void:
	_update_cost_readout()
	_update_resource_note()

	var affordable := _system_data != null and _can_afford_selected_hull()
	produce_button.disabled = not affordable
	if affordable:
		produce_button.tooltip_text = "Build one %s" % str(
			_selected_hull.get("name", "ship")
		)
	else:
		produce_button.tooltip_text = "Insufficient resources: %s" % (
			_missing_resources_text()
		)

	if _system_data == null:
		feedback_label.text = ""
		return

	if affordable and _feedback.begins_with("Insufficient resources"):
		_feedback = ""

	var status := _feedback
	if status.is_empty():
		if _selected_fleet == null:
			status = "No fleet selected — Produce Ship will create a new fleet."
		else:
			status = "Selected %s — Produce Ship will add one %s." % [
				_selected_fleet.name,
				str(_selected_hull.get("name", "ship")),
			]
	if not affordable:
		var warning := "Insufficient resources — %s." % _missing_resources_text()
		status = warning if status.is_empty() else "%s %s" % [status, warning]
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
