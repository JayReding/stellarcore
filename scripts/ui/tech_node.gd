class_name TechNode
extends PanelContainer
## Rounded-square card for one technology in the tech tree.
##
## The card shows an icon, the name, the description, the Research Data cost
## and the research time in turns (both yellow). A researched technology hides
## the cost and time and shows AVAILABLE in green instead.

signal research_requested(technology: Dictionary)

const COLOR_COST := Color(1.0, 0.82, 0.35)
const COLOR_AVAILABLE := Color(0.46, 0.84, 0.65)
const COLOR_AWAITING := Color(0.8, 0.6, 0.3)
const COLOR_BLOCKED := Color(0.5, 0.58, 0.68)

@onready var icon_label: Label = %IconLabel
@onready var name_label: Label = %NameLabel
@onready var description_label: Label = %DescriptionLabel
@onready var cost_row: HBoxContainer = %CostRow
@onready var cost_label: Label = %CostLabel
@onready var time_label: Label = %TimeLabel
@onready var status_label: Label = %StatusLabel

var technology: Dictionary = {}
var _clickable := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)
	for child in find_children("*", "Control", true, false):
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(technology_data: Dictionary) -> void:
	technology = technology_data
	var display_name := str(technology.get("name", "Technology"))
	var description := str(technology.get("description", ""))

	icon_label.text = str(technology.get("icon", "T"))
	name_label.text = display_name
	description_label.text = description

	if bool(technology.get("available_by_default", false)):
		_show_available()
		tooltip_text = "%s\n%s\nAvailable by default." % [
			display_name, description
		]
	else:
		_show_available_state()
		tooltip_text = "%s\n%s\nResearch cost: %d RD\nResearch time: %d turns" % [
			display_name,
			description,
			int(technology.get("cost", 0)),
			int(technology.get("time", 0)),
		]


## Refreshes the card for the player's research state: available, active,
## blocked by another project, or completed.
func set_research_state(state: String, turns_remaining := 0) -> void:
	var display_name := str(technology.get("name", "Technology"))
	var description := str(technology.get("description", ""))
	match state:
		"completed":
			_show_available()
			tooltip_text = "%s\n%s\nResearch complete." % [
				display_name, description
			]
		"active":
			_show_cost_and_time()
			_set_status(
				"%d TURN%s LEFT" % [
					turns_remaining, "" if turns_remaining == 1 else "S"
				],
				Color(0.9, 0.7, 0.35),
				false
			)
			tooltip_text = "%s\n%s\nResearch in progress: %d turns left." % [
				display_name, description, turns_remaining
			]
		"blocked":
			_show_cost_and_time()
			_set_status("AWAITING CURRENT RESEARCH", COLOR_BLOCKED, false)
			tooltip_text = "%s\n%s\nAnother research project is in progress." % [
				display_name, description
			]
		_:
			_show_available_state()
			tooltip_text = "%s\n%s\nResearch cost: %d RD\nResearch time: %d turns" % [
				display_name,
				description,
				int(technology.get("cost", 0)),
				int(technology.get("time", 0)),
			]


func _show_available_state() -> void:
	_show_cost_and_time()
	cost_label.text = "%d RD" % int(technology.get("cost", 0))
	cost_label.add_theme_color_override("font_color", COLOR_COST)
	var turns := int(technology.get("time", 0))
	time_label.text = "%d TURN%s" % [turns, "" if turns == 1 else "S"]
	time_label.add_theme_color_override("font_color", COLOR_COST)
	_set_status("", COLOR_AWAITING, true)
	status_label.visible = false


func _show_available() -> void:
	cost_row.visible = false
	cost_label.visible = false
	time_label.visible = false
	_set_status("AVAILABLE", COLOR_AVAILABLE, false)


func _show_cost_and_time() -> void:
	cost_row.visible = true
	cost_label.visible = true
	time_label.visible = true


func _set_status(status_text: String, status_color: Color, clickable: bool) -> void:
	status_label.text = status_text
	status_label.visible = true
	status_label.add_theme_color_override("font_color", status_color)
	_clickable = clickable
	mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW
	)


func _on_gui_input(event: InputEvent) -> void:
	if not _clickable:
		return
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		research_requested.emit(technology)
		accept_event()
