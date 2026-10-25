class_name ShipyardView
extends CanvasLayer
## Full-screen shipyard. Hull selection is on the left, customization in the
## center, and the system's fleets on the right. Production is queued and
## spends the system's local stockpile up front; one turn of work completes
## each turn, oldest queued hull first.

signal closed

## Pixels the mouse must move before a ship-chip press becomes a drag.
const DRAG_THRESHOLD := 8.0

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
		"build_time": 0.25,
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
			+ "On arrival you choose which planet hosts the new Colony, and "
			+ "the ship is consumed to found it. Travels at 5 light years per "
			+ "turn and costs 1 Antimatter for now; loading fuel for longer "
			+ "voyages comes later."
		),
		"customization": "None",
		"cost": {
			ResourceStockpile.TITANIUM: 500,
			ResourceStockpile.ANTIMATTER: 1,
		},
		"build_time": 3.0,
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
@onready var hull_time_value: Label = %HullTimeValue
@onready var queue_list: VBoxContainer = %QueueList
@onready var queue_note: Label = %QueueNote
@onready var cost_value: HBoxContainer = %CostValue
@onready var no_options_label: Label = %NoOptionsLabel
@onready var no_options_note: Label = %NoOptionsNote
@onready var fleet_list: VBoxContainer = %FleetList
@onready var fleet_scroll: ScrollContainer = %FleetScroll
@onready var fleet_spacer: Control = %FleetSpacer
@onready var fleet_count_label: Label = %FleetCountLabel
@onready var no_fleets_label: Label = %NoFleetsLabel
@onready var new_fleet_button: Button = %NewFleetButton
@onready var feedback_label: Label = %FeedbackLabel
@onready var resource_note: Label = %ResourceNote
@onready var produce_button: Button = %ProduceButton

var _system_data: StarData
var _galaxy: Galaxy
var _resources: ResourceStockpile
var _selected_hull: Dictionary = HULLS[0]
var _feedback := ""
var _unlocked_ships: Array[String] = []
## Manual drag state: a ship chip is being moved between fleet rows.
var _drag_payload: Dictionary = {}
var _drag_preview: PanelContainer
var _drag_active := false
var _drag_press_position := Vector2.ZERO
var _tween: Tween


## Hulls the player may currently build: the default set plus every locked
## hull whose ship name was unlocked by research.
static func available_hulls(unlocked_ships: Array[String] = []) -> Array:
	var hulls: Array = HULLS.duplicate()
	for hull in LOCKED_HULLS:
		if unlocked_ships.has(str(hull.get("name", ""))):
			hulls.append(hull)
	return hulls


## Hull definition by type id, or an empty Dictionary when unknown.
static func hull_by_id(hull_id: String) -> Dictionary:
	for hull in HULLS:
		if str(hull.get("id", "")) == hull_id:
			return hull
	for hull in LOCKED_HULLS:
		if str(hull.get("id", "")) == hull_id:
			return hull
	return {}


## Human-readable build time. Sub-turn hulls report their per-turn rate.
static func build_time_text(build_time: float) -> String:
	if build_time <= 0.0:
		return "Instant"
	var amount := str(build_time)
	if is_equal_approx(build_time, floor(build_time)):
		amount = str(int(build_time))
	if build_time < 1.0:
		var per_turn := maxi(int(round(1.0 / build_time)), 1)
		return "%s turns (%d per turn)" % [amount, per_turn]
	var suffix := "turn" if is_equal_approx(build_time, 1.0) else "turns"
	return "%s %s" % [amount, suffix]


func _ready() -> void:
	back_button.pressed.connect(close)
	produce_button.pressed.connect(_on_produce_pressed)
	new_fleet_button.pressed.connect(_on_new_fleet_pressed)
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
	_unlocked_ships = unlocked_ships.duplicate()
	_ensure_selected_hull()
	_feedback = ""
	_cancel_drag()
	_populate_hulls()
	_show_hull(_selected_hull)
	_populate_fleets()
	_populate_queue()
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
	_cancel_drag()
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
	hull_time_value.text = _build_time_text(float(hull.get("build_time", 1.0)))
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


func _create_fleet_row(fleet: FleetData) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 56)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.tooltip_text = "%s — %s\nDrag a ship onto another fleet to move it" % [
		fleet.name, fleet.ship_summary()
	]
	panel.add_theme_stylebox_override("panel", _fleet_row_style())
	panel.set_meta("fleet_target", fleet)

	var content := VBoxContainer.new()
	panel.add_child(content)
	content.add_theme_constant_override("separation", 4)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(header)

	var name_label := Label.new()
	name_label.text = fleet.name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.84, 0.92, 1))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(name_label)

	var count_label := Label.new()
	var ship_total := fleet.ships.size()
	count_label.text = "%d %s" % [
		ship_total, "ship" if ship_total == 1 else "ships"
	]
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 11)
	count_label.add_theme_color_override("font_color", Color(0.55, 0.68, 0.82))
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(count_label)

	var chips := HBoxContainer.new()
	chips.name = "ShipChips"
	chips.add_theme_constant_override("separation", 6)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(chips)

	if fleet.ships.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No ships — drag ships here."
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 11)
		empty_label.add_theme_color_override(
			"font_color", Color(0.45, 0.57, 0.7)
		)
		empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chips.add_child(empty_label)
	else:
		for i in fleet.ships.size():
			chips.add_child(_make_ship_chip(fleet, i))

	return panel


func _make_ship_chip(fleet: FleetData, ship_index: int) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(0, 26)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chip.tooltip_text = "Drag %s to another fleet" % str(
		fleet.ships[ship_index]
	)
	chip.add_theme_stylebox_override("panel", _chip_style())
	chip.set_meta("ship_chip", true)

	var label := Label.new()
	label.text = str(fleet.ships[ship_index])
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.84, 0.92, 1))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(label)

	chip.gui_input.connect(_on_ship_chip_input.bind(fleet, ship_index))
	return chip


func _on_ship_chip_input(
	event: InputEvent, fleet: FleetData, ship_index: int
) -> void:
	if fleet == null or _system_data == null:
		return
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		if ship_index < 0 or ship_index >= fleet.ships.size():
			return
		_drag_payload = {
			"fleet": fleet,
			"ship_name": str(fleet.ships[ship_index]),
		}
		_drag_press_position = event.position
		_drag_active = false
	else:
		_cancel_drag()


func _input(event: InputEvent) -> void:
	if not visible or _drag_payload.is_empty():
		return
	if event is InputEventMouseMotion:
		if not _drag_active:
			var motion := event as InputEventMouseMotion
			if (
				motion.position - _drag_press_position
			).length() < DRAG_THRESHOLD:
				return
			_begin_drag_preview()
		_update_drag_preview(event.position)
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
			_finish_ship_drag()
	elif (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.is_action_pressed("ui_cancel")
	):
		_cancel_drag()


func _begin_drag_preview() -> void:
	_drag_active = true
	_drag_preview = PanelContainer.new()
	_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_preview.add_theme_stylebox_override("panel", _chip_style(true))
	var label := Label.new()
	label.text = str(_drag_payload.get("ship_name", "Ship"))
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.97, 1, 1))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_preview.add_child(label)
	_drag_preview.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.add_child(_drag_preview)


func _update_drag_preview(screen_position: Vector2) -> void:
	if _drag_preview == null or not is_instance_valid(_drag_preview):
		return
	_drag_preview.position = screen_position + Vector2(14, 10)


func _finish_ship_drag() -> void:
	var payload := _drag_payload.duplicate()
	var was_active := _drag_active
	_cancel_drag()
	if not was_active:
		return

	var target := _drop_target_under_mouse()
	if target == null:
		return
	var source: FleetData = payload.get("fleet")
	var ship_name := str(payload.get("ship_name", ""))
	if source == null or source == target or ship_name.is_empty():
		return
	var ship_index := source.ships.find(ship_name)
	if ship_index >= 0:
		_move_ship(source, target, ship_index)


func _drop_target_under_mouse() -> FleetData:
	var hovered := get_viewport().gui_get_hovered_control()
	return fleet_drop_target_for(hovered)


## Walks up from a control to the fleet row it belongs to, if any.
func fleet_drop_target_for(control: Control) -> FleetData:
	var node: Node = control
	while node != null:
		if node.has_meta("fleet_target"):
			return node.get_meta("fleet_target") as FleetData
		node = node.get_parent()
	return null


func _cancel_drag() -> void:
	_drag_payload = {}
	_drag_active = false
	_drag_press_position = Vector2.ZERO
	if _drag_preview != null and is_instance_valid(_drag_preview):
		_drag_preview.queue_free()
	_drag_preview = null


## Moves one ship between stationed fleets. Emptying a fleet removes it and
## frees its name for future production.
func _move_ship(
	source: FleetData, target: FleetData, ship_index: int
) -> bool:
	if _system_data == null or source == null or target == null:
		return false
	if source == target:
		return false
	if not _system_data.fleets.has(source):
		return false
	if not _system_data.fleets.has(target):
		return false
	if source.in_transit or target.in_transit:
		return false
	if ship_index < 0 or ship_index >= source.ships.size():
		return false

	var ship_name := str(source.ships[ship_index])
	source.ships.remove_at(ship_index)
	target.add_ship(ship_name)

	var note := ""
	if source.ships.is_empty():
		_system_data.fleets.erase(source)
		note = " %s disbanded." % source.name
	_feedback = "Moved 1 %s to %s.%s" % [ship_name, target.name, note]
	_populate_fleets()
	_update_header()
	_update_production_status()
	return true


func _on_new_fleet_pressed() -> void:
	if _system_data == null:
		return
	_cancel_drag()
	var fleet := FleetData.new()
	fleet.name = _next_fleet_name()
	fleet.dock_at(_system_data)
	_system_data.fleets.append(fleet)
	_feedback = "Created %s — drag ships into it." % fleet.name
	_populate_fleets()
	_update_header()
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

	var hull_id := str(_selected_hull.get("id", ""))
	var hull_name := str(_selected_hull.get("name", "ship"))
	if _system_data.resources == null:
		_system_data.resources = ResourceStockpile.new()
	_system_data.ship_queue.append({"hull_id": hull_id, "progress": 0.0})
	_feedback = "Queued 1 %s (position %d)." % [
		hull_name, _system_data.ship_queue.size()
	]
	_populate_queue()
	_update_production_status()


func _populate_queue() -> void:
	for child in queue_list.get_children():
		queue_list.remove_child(child)
		child.queue_free()
	if _system_data == null:
		return

	var queue: Array = _system_data.ship_queue
	for i in queue.size():
		var item: Dictionary = queue[i]
		var definition := hull_by_id(str(item.get("hull_id", "")))
		if definition.is_empty():
			continue
		var row := _make_queue_row(item, definition, i)
		row.name = "Queue_%d" % i
		queue_list.add_child(row)


func _make_queue_row(
	item: Dictionary, definition: Dictionary, index: int
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 1)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = str(definition.get("name", "Ship"))
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.82, 0.89, 0.97))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(name_label)

	var status_label := Label.new()
	status_label.name = "QueueStatus"
	status_label.text = _queue_status_text(item, definition)
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override(
		"font_color", Color(0.52, 0.65, 0.8)
	)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(status_label)

	var cancel_button := Button.new()
	cancel_button.text = "Cancel"
	cancel_button.focus_mode = Control.FOCUS_NONE
	cancel_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cancel_button.tooltip_text = "Cancel this build and refund unused resources"
	cancel_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cancel_button.add_theme_font_size_override("font_size", 11)
	cancel_button.add_theme_color_override("font_color", Color(0.84, 0.93, 1))
	cancel_button.add_theme_color_override(
		"font_hover_color", Color(0.97, 1, 1, 1)
	)
	cancel_button.add_theme_stylebox_override("normal", _cancel_style())
	cancel_button.add_theme_stylebox_override("hover", _cancel_style(true))
	cancel_button.add_theme_stylebox_override("pressed", _cancel_style())
	cancel_button.pressed.connect(_on_cancel_queued.bind(index))
	row.add_child(cancel_button)

	return row


## Which turn of its build a queued item is on.
func _queue_status_text(item: Dictionary, definition: Dictionary) -> String:
	var build_time := maxf(float(definition.get("build_time", 1.0)), 0.0)
	var total := maxi(ceili(build_time), 1)
	var progress := float(item.get("progress", 0.0))
	var elapsed := mini(int(floor(progress)) + 1, total)
	return "Turn %d of %d" % [elapsed, total]


func _on_cancel_queued(index: int) -> void:
	if _system_data == null:
		return
	if index < 0 or index >= _system_data.ship_queue.size():
		return

	var item: Dictionary = _system_data.ship_queue[index]
	var definition := hull_by_id(str(item.get("hull_id", "")))
	_system_data.ship_queue.remove_at(index)

	var refunded := "nothing"
	if not definition.is_empty():
		var refund := _refund_for_cancel(item, definition)
		if _resources == null:
			_resources = _system_data.resources
		if _resources != null:
			for resource_id in refund:
				_resources.add_amount(
					str(resource_id), int(refund[resource_id])
				)
		refunded = _refund_summary_text(refund)

	_feedback = "Cancelled 1 %s — refunded %s." % [
		str(definition.get("name", "ship")), refunded
	]
	_populate_queue()
	_update_production_status()


## Pro-rated refund for cancelled construction. Antimatter is always added
## last, so it is refunded in full no matter the progress.
func _refund_for_cancel(
	item: Dictionary, definition: Dictionary
) -> Dictionary:
	var refund := {}
	var cost: Dictionary = definition.get("cost", {})
	var build_time := float(definition.get("build_time", 1.0))
	var fraction := 1.0
	if build_time > 0.0:
		fraction = clampf(
			(build_time - float(item.get("progress", 0.0))) / build_time,
			0.0,
			1.0
		)
	for resource_id in cost:
		var id := str(resource_id)
		if id == ResourceStockpile.ANTIMATTER:
			refund[id] = int(cost[resource_id])
		else:
			refund[id] = int(
				floor(float(cost[resource_id]) * fraction)
			)
	return refund


func _refund_summary_text(refund: Dictionary) -> String:
	var parts: Array[String] = []
	for resource_id in refund:
		var amount := int(refund[resource_id])
		if amount <= 0:
			continue
		parts.append("%d %s" % [
			amount, ResourceStockpile.display_name(str(resource_id))
		])
	if parts.is_empty():
		return "nothing"
	return " and ".join(parts)


func _cancel_style(hover := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.content_margin_left = 12.0
	style.content_margin_top = 6.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 6.0
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.bg_color = Color(0.05, 0.11, 0.19, 0.95)
	style.border_color = Color(0.22, 0.46, 0.74, 0.7)
	if hover:
		style.bg_color = Color(0.09, 0.2, 0.34, 0.98)
		style.border_color = Color(0.38, 0.68, 1.0, 0.9)
	return style


func _chip_style(highlight := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.content_margin_left = 8.0
	style.content_margin_top = 3.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 3.0
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.bg_color = Color(0.06, 0.14, 0.24, 0.95)
	style.border_color = Color(0.24, 0.5, 0.8, 0.75)
	if highlight:
		style.bg_color = Color(0.1, 0.24, 0.4, 1.0)
		style.border_color = Color(0.5, 0.8, 1.0, 1.0)
	return style


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
	_populate_queue()
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


func _build_time_text(build_time: float) -> String:
	return build_time_text(build_time)


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
		status = "Ships join the newest fleet in the system."
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


func _fleet_row_style(hover := false, pressed := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.bg_color = Color(0.025, 0.05, 0.085, 0.85)
	style.border_color = Color(0.17, 0.31, 0.48, 0.65)

	if hover:
		style.bg_color = Color(0.05, 0.12, 0.2, 0.95)
		style.border_color = Color(0.36, 0.64, 0.96, 0.9)
	if pressed:
		style.bg_color = Color(0.04, 0.1, 0.17, 1.0)

	return style


func _kill_tween() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = null
