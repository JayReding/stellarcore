class_name TechNode
extends PanelContainer
## Rounded-square card for one technology in the tech tree.

signal research_requested(technology: Dictionary)

@onready var tier_label: Label = %TierLabel
@onready var category_label: Label = %CategoryLabel
@onready var icon_label: Label = %IconLabel
@onready var name_label: Label = %NameLabel
@onready var description_label: Label = %DescriptionLabel
@onready var cost_label: Label = %CostLabel
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
	var cost := int(technology.get("cost", 0))

	tier_label.text = "TIER %d" % int(technology.get("tier", 1))
	category_label.text = str(technology.get("category", "")).to_upper()
	icon_label.text = str(technology.get("icon", "T"))
	name_label.text = display_name
	description_label.text = description

	if bool(technology.get("available_by_default", false)):
		_set_state(
			"NO RESEARCH REQUIRED",
			"AVAILABLE BY DEFAULT",
			Color(0.52, 0.9, 0.76),
			Color(0.46, 0.84, 0.65),
			false
		)
		tooltip_text = "%s\n%s\nAvailable by default." % [
			display_name, description
		]
	else:
		_show_available_state()
		tooltip_text = "%s\n%s\nResearch cost: %d RD\nResearch time: %d turns" % [
			display_name,
			description,
			cost,
			int(technology.get("time", 0)),
		]


## Refreshes the card for the player's research state: available, active,
## blocked by another project, or completed.
func set_research_state(state: String, turns_remaining := 0) -> void:
	var display_name := str(technology.get("name", "Technology"))
	var description := str(technology.get("description", ""))
	match state:
		"completed":
			_set_state(
				"RESEARCH COMPLETE",
				"UNLOCKED",
				Color(0.52, 0.9, 0.76),
				Color(0.46, 0.84, 0.65),
				false
			)
			tooltip_text = "%s\n%s\nResearch complete." % [
				display_name, description
			]
		"active":
			_set_state(
				"IN PROGRESS",
				"%d TURN%s LEFT" % [
					turns_remaining, "" if turns_remaining == 1 else "S"
				],
				Color(1, 0.78, 0.38),
				Color(0.9, 0.7, 0.35),
				false
			)
			tooltip_text = "%s\n%s\nResearch in progress: %d turns left." % [
				display_name, description, turns_remaining
			]
		"blocked":
			_set_state(
				"REQUIRES %d RD" % int(technology.get("cost", 0)),
				"AWAITING CURRENT RESEARCH",
				Color(0.62, 0.68, 0.76),
				Color(0.5, 0.58, 0.68),
				false
			)
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
	_set_state(
		"REQUIRES %d RD" % int(technology.get("cost", 0)),
		"AWAITING FUNDING",
		Color(1, 0.78, 0.38),
		Color(0.8, 0.6, 0.3),
		true
	)


func _set_state(
	cost_text: String,
	status_text: String,
	cost_color: Color,
	status_color: Color,
	clickable: bool
) -> void:
	cost_label.text = cost_text
	cost_label.add_theme_color_override("font_color", cost_color)
	status_label.text = status_text
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
