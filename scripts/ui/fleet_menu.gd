class_name FleetMenu
extends CanvasLayer
## Cursor-anchored popup menu for fleet orders. Set Fleet Destination is
## implemented; the other fleet-management actions are present but disabled
## for the current slice. Clicking anywhere outside the menu dismisses it.

signal destination_requested(fleet: FleetData)
signal orders_cancelled(fleet: FleetData)
signal closed

@onready var root: Control = %Root
@onready var panel: PanelContainer = %Panel
@onready var fleet_name_label: Label = %FleetNameLabel
@onready var fleet_meta_label: Label = %FleetMetaLabel
@onready var set_destination_button: Button = %SetDestinationButton
@onready var cancel_orders_button: Button = %CancelOrdersButton
@onready var rename_button: Button = %RenameButton
@onready var modify_button: Button = %ModifyButton
@onready var delete_button: Button = %DeleteButton
@onready var menu_note: Label = %MenuNote

var _fleet: FleetData


func _ready() -> void:
	set_destination_button.pressed.connect(_on_set_destination_pressed)
	cancel_orders_button.pressed.connect(_on_cancel_orders_pressed)
	root.gui_input.connect(_on_root_input)
	visible = false


func open_menu(fleet: FleetData, screen_position: Vector2) -> void:
	if fleet == null:
		return

	_fleet = fleet
	fleet_name_label.text = fleet.name
	var parts: Array[String] = [
		fleet.location_label(),
		fleet.ship_summary(),
	]
	if fleet.in_transit:
		parts.append("%d turns remaining" % fleet.turns_remaining())
	elif fleet.has_orders():
		parts.append("Ordered for %s" % fleet.ordered_destination_name)
		parts.append("%.0f ly / turn" % fleet.speed_ly_per_turn())
	else:
		parts.append("%.0f ly / turn" % fleet.speed_ly_per_turn())
	fleet_meta_label.text = "  •  ".join(parts)

	var speed := fleet.speed_ly_per_turn()
	var ordered := fleet.has_orders()
	set_destination_button.visible = not ordered
	set_destination_button.disabled = fleet.in_transit or speed <= 0.0
	if fleet.in_transit:
		set_destination_button.tooltip_text = "Fleet is already in transit"
	elif speed <= 0.0:
		set_destination_button.tooltip_text = "Fleet has no ships"
	else:
		set_destination_button.tooltip_text = "Choose a destination star"
	cancel_orders_button.visible = ordered
	cancel_orders_button.disabled = false
	cancel_orders_button.tooltip_text = "Withdraw the fleet's travel orders"

	rename_button.disabled = true
	modify_button.disabled = true
	delete_button.disabled = true
	rename_button.tooltip_text = "Fleet renaming will be implemented later"
	modify_button.tooltip_text = "Fleet modification will be implemented later"
	delete_button.tooltip_text = "Fleet deletion will be implemented later"
	menu_note.text = (
		"Orders depart at the end of the turn."
		if ordered
		else "Only Set Fleet Destination is available in this build."
	)

	visible = true
	_place_panel(screen_position)


func close() -> void:
	if not visible:
		return
	visible = false
	_fleet = null
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	closed.emit()


## Closes the menu when the fleet it is showing has arrived or been removed.
func close_if_showing_fleet(fleet: FleetData) -> void:
	if not visible or fleet == null or _fleet != fleet:
		return
	close()


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


func _on_root_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.pressed
	):
		close()
		root.accept_event()


func _on_set_destination_pressed() -> void:
	if _fleet == null or _fleet.in_transit or _fleet.has_orders():
		return
	if _fleet.speed_ly_per_turn() <= 0.0:
		return
	destination_requested.emit(_fleet)
	close()


func _on_cancel_orders_pressed() -> void:
	if _fleet == null or _fleet.in_transit or not _fleet.has_orders():
		return
	orders_cancelled.emit(_fleet)
	close()


## Keeps the menu fully inside the viewport, opening up-left of the cursor
## when there is no room down-right.
func _place_panel(screen_position: Vector2) -> void:
	var view_size := get_viewport().get_visible_rect().size
	var menu_size := panel.get_combined_minimum_size()
	var margin := 8.0
	var position := screen_position
	if position.x + menu_size.x > view_size.x - margin:
		position.x = screen_position.x - menu_size.x
	if position.y + menu_size.y > view_size.y - margin:
		position.y = screen_position.y - menu_size.y
	position.x = clampf(position.x, margin, maxf(margin, view_size.x - menu_size.x - margin))
	position.y = clampf(position.y, margin, maxf(margin, view_size.y - menu_size.y - margin))
	panel.position = position
	panel.size = menu_size
