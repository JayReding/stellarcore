class_name FleetDialog
extends CanvasLayer
## Modal course-confirmation dialog. It appears after a destination star is
## chosen and shows distance, fleet speed, and required turns. Fleet orders
## themselves live in the FleetMenu popup.

signal destination_confirmed(fleet: FleetData, destination: StarData)
signal confirmation_cancelled
signal closed

@onready var panel: PanelContainer = %Panel
@onready var close_button: Button = %CloseButton
@onready var fleet_name_label: Label = %FleetNameLabel
@onready var fleet_meta_label: Label = %FleetMetaLabel
@onready var confirmation: VBoxContainer = %Confirmation
@onready var confirmation_fleet_label: Label = %ConfirmationFleetLabel
@onready var destination_name_label: Label = %DestinationNameLabel
@onready var distance_value: Label = %DistanceValue
@onready var speed_value: Label = %SpeedValue
@onready var turns_value: Label = %TurnsValue
@onready var confirmation_back_button: Button = %ConfirmationBackButton
@onready var confirm_button: Button = %ConfirmButton

var _fleet: FleetData
var _destination: StarData
var _tween: Tween


func _ready() -> void:
	close_button.pressed.connect(close)
	confirmation_back_button.pressed.connect(_on_confirmation_back_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	visible = false


func show_confirmation(
	fleet: FleetData,
	destination: StarData,
	distance_ly: float,
	turns: int
) -> void:
	if fleet == null or destination == null:
		return

	_fleet = fleet
	_destination = destination
	close_button.visible = false
	confirmation.visible = true

	_fleet_name_label_update()
	confirmation_fleet_label.text = fleet.name
	destination_name_label.text = destination.display_name
	distance_value.text = "%.1f ly" % distance_ly
	speed_value.text = "%.1f ly / turn" % fleet.speed_ly_per_turn()
	var suffix := "turn" if turns == 1 else "turns"
	turns_value.text = "%d %s" % [turns, suffix]
	confirm_button.text = "Confirm Destination"
	confirm_button.disabled = turns <= 0

	_show()


func close() -> void:
	if not visible:
		return
	visible = false
	_fleet = null
	_destination = null
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
		_on_confirmation_back_pressed()
		get_viewport().set_input_as_handled()


func _on_confirm_pressed() -> void:
	if _fleet == null or _destination == null:
		return
	var fleet := _fleet
	var destination := _destination
	destination_confirmed.emit(fleet, destination)
	close()


func _on_confirmation_back_pressed() -> void:
	confirmation_cancelled.emit()
	close()


func _fleet_name_label_update() -> void:
	if _fleet == null:
		return
	fleet_name_label.text = _fleet.name
	var parts: Array[String] = [
		_fleet.location_label(),
		_fleet.ship_summary(),
	]
	if _fleet.in_transit:
		parts.append("%d turns remaining" % _fleet.turns_remaining())
	else:
		parts.append("%.0f ly / turn" % _fleet.speed_ly_per_turn())
	fleet_meta_label.text = "  •  ".join(parts)


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
