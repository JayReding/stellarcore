class_name TechNode
extends PanelContainer
## Rounded-square card for one technology in the tech tree.

@onready var tier_label: Label = %TierLabel
@onready var category_label: Label = %CategoryLabel
@onready var icon_label: Label = %IconLabel
@onready var name_label: Label = %NameLabel
@onready var description_label: Label = %DescriptionLabel
@onready var cost_label: Label = %CostLabel
@onready var status_label: Label = %StatusLabel


func setup(technology: Dictionary) -> void:
	var display_name := str(technology.get("name", "Technology"))
	var description := str(technology.get("description", ""))
	var cost := int(technology.get("cost", 0))
	var available_by_default := bool(technology.get("available_by_default", false))

	tier_label.text = "TIER %d" % int(technology.get("tier", 1))
	category_label.text = str(technology.get("category", "")).to_upper()
	icon_label.text = str(technology.get("icon", "T"))
	name_label.text = display_name
	description_label.text = description

	if available_by_default:
		cost_label.text = "NO RESEARCH REQUIRED"
		cost_label.add_theme_color_override("font_color", Color(0.52, 0.9, 0.76))
		status_label.text = "AVAILABLE BY DEFAULT"
		status_label.add_theme_color_override("font_color", Color(0.46, 0.84, 0.65))
		tooltip_text = "%s\n%s\nAvailable by default." % [display_name, description]
	else:
		cost_label.text = "REQUIRES %d RP" % cost
		cost_label.add_theme_color_override("font_color", Color(1, 0.78, 0.38))
		status_label.text = "AWAITING FUNDING"
		status_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3))
		tooltip_text = "%s\n%s\nResearch cost: %d RP" % [display_name, description, cost]
