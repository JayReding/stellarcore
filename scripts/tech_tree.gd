class_name TechTree
extends CanvasLayer
## Full-screen technology tree. Technologies are data entries rendered as
## rounded-square cards and funded with the galaxy-wide Research Data pool.

signal closed
signal research_started(technology: Dictionary)
signal research_progressed(technology: Dictionary, turns_remaining: int)
signal research_completed(technology: Dictionary)

const TECH_NODE_SCENE: PackedScene = preload("res://scenes/ui/tech_node.tscn")
## Display order for known categories. Unknown categories sort last.
const CATEGORY_ORDER: Array[String] = [
	"Propulsion",
	"Exploration",
	"Industrial",
	"Military",
	"Advanced Technology",
]
const CATEGORY_COLORS := {
	"Propulsion": Color(0.48, 0.74, 1.0),
	"Exploration": Color(0.55, 0.9, 0.76),
	"Industrial": Color(0.95, 0.72, 0.38),
	"Military": Color(0.96, 0.48, 0.48),
	"Advanced Technology": Color(0.8, 0.6, 1.0),
}
const TECHNOLOGIES := [
	{
		"id": "ftl_probes",
		"name": "FTL Probes",
		"tier": 1,
		"category": "Propulsion",
		"cost": 0,
		"time": 0,
		"available_by_default": true,
		"icon": "FTL",
		"description": "Faster-than-light probes for deep-space reconnaissance.",
	},
	{
		"id": "ore_processing",
		"name": "Ore Processing",
		"tier": 1,
		"category": "Industrial",
		"cost": 0,
		"time": 0,
		"available_by_default": true,
		"icon": "OPC",
		"description": "Technology to mine titanium from planetary cores.",
	},
	{
		"id": "colony_ships",
		"name": "Colony Ships",
		"tier": 1,
		"category": "Exploration",
		"cost": 100,
		"time": 5,
		"available_by_default": false,
		"icon": "COL",
		"description": "Sleeper ships that carry colonists to distant systems "
		+ "and found new colonies on arrival.",
		"unlocks": {
			"structures": [],
			"ships": ["Colony Ship"],
		},
	},
	{
		"id": "antimatter_refining",
		"name": "Antimatter Refining",
		"tier": 2,
		"category": "Industrial",
		"cost": 50,
		"time": 3,
		"available_by_default": false,
		"icon": "AMR",
		"description": "Structures that allow for processing Helium3 into "
		+ "antimatter for ship operations",
		"unlocks": {
			"structures": [StructureData.ANTIMATTER_REFINERY],
			"ships": [],
		},
	},
]

@onready var root: Control = $Root
@onready var back_button: Button = %BackButton
@onready var meta_label: Label = %MetaLabel
@onready var funds_label: Label = %FundsLabel
@onready var tech_list: VBoxContainer = %TechList
@onready var dialog_backdrop: ColorRect = %DialogBackdrop
@onready var research_dialog: PanelContainer = %ResearchDialog
@onready var dialog_title: Label = %DialogTitle
@onready var dialog_meta: Label = %DialogMeta
@onready var dialog_description: Label = %DialogDescription
@onready var dialog_cost: Label = %DialogCost
@onready var dialog_time: Label = %DialogTime
@onready var dialog_warning: Label = %DialogWarning
@onready var dialog_cancel_button: Button = %DialogCancelButton
@onready var dialog_confirm_button: Button = %DialogConfirmButton

var _research_data: int = 0
var _tech_nodes: Array[TechNode] = []
var _active_research: Dictionary = {}
var _turns_total: int = 0
var _turns_remaining: int = 0
var _completed_tech_ids: Array[String] = []
var _dialog_technology: Dictionary = {}
var _tween: Tween


func _ready() -> void:
	back_button.pressed.connect(close)
	dialog_cancel_button.pressed.connect(_hide_research_dialog)
	dialog_confirm_button.pressed.connect(_confirm_research)
	dialog_backdrop.gui_input.connect(_on_dialog_backdrop_input)
	_populate()
	_update_funds()
	visible = false


func open(research_data: int = 0) -> void:
	_research_data = maxi(research_data, 0)
	_update_funds()
	_hide_research_dialog()
	refresh_tech_cards()
	visible = true
	_kill_tween()
	root.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(root, "modulate:a", 1.0, 0.2)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func refresh_research_data(research_data: int) -> void:
	_research_data = maxi(research_data, 0)
	_update_funds()
	refresh_tech_cards()
	if research_dialog.visible:
		_update_dialog_funding()


func close() -> void:
	if not visible:
		return

	_kill_tween()
	_hide_research_dialog()
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
		if research_dialog.visible:
			_hide_research_dialog()
		else:
			close()
		get_viewport().set_input_as_handled()


func _populate() -> void:
	for child in tech_list.get_children():
		tech_list.remove_child(child)
		child.queue_free()
	_tech_nodes.clear()

	var groups := _technology_groups()
	var tier_rows := _tier_rows(groups)
	for tier_row in tier_rows:
		var row_section := _make_tier_section(int(tier_row["tier"]))
		tech_list.add_child(row_section)
		var category_row := row_section.get_node("CategoryRow") as HBoxContainer
		for group in tier_row["groups"]:
			var section := _make_category_section(group)
			category_row.add_child(section)
			_populate_category_section(section, group)

	var categories: Dictionary = {}
	for group in groups:
		categories[str(group["category"])] = true

	var noun := "TECHNOLOGY" if TECHNOLOGIES.size() == 1 else "TECHNOLOGIES"
	var category_noun := "CATEGORY" if categories.size() == 1 else "CATEGORIES"
	var tier_noun := "TIER" if tier_rows.size() == 1 else "TIERS"
	meta_label.text = "TECH TREE  •  %d %s  •  %d %s  •  %d %s" % [
		TECHNOLOGIES.size(), noun,
		categories.size(), category_noun,
		tier_rows.size(), tier_noun,
	]
	refresh_tech_cards()


## Groups technologies by tier and then category, preserving the configured
## category order. Each group becomes one labelled card section.
func _technology_groups() -> Array[Dictionary]:
	var sorted: Array[Dictionary] = []
	for technology in TECHNOLOGIES:
		sorted.append(technology)
	sorted.sort_custom(_sort_technologies)

	var groups: Array[Dictionary] = []
	for technology in sorted:
		var tier := int(technology.get("tier", 1))
		var category := str(technology.get("category", "Uncategorized"))
		if (
			groups.is_empty()
			or int(groups[-1]["tier"]) != tier
			or str(groups[-1]["category"]) != category
		):
			groups.append({
				"tier": tier,
				"category": category,
				"technologies": [],
			})
		groups[-1]["technologies"].append(technology)
	return groups


## Collapses the ordered category groups into one display row per tier.
func _tier_rows(groups: Array[Dictionary]) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for group in groups:
		var tier := int(group["tier"])
		if rows.is_empty() or int(rows[-1]["tier"]) != tier:
			rows.append({"tier": tier, "groups": []})
		rows[-1]["groups"].append(group)
	return rows


func _sort_technologies(a: Dictionary, b: Dictionary) -> bool:
	var tier_a := int(a.get("tier", 1))
	var tier_b := int(b.get("tier", 1))
	if tier_a != tier_b:
		return tier_a < tier_b

	var order_a := _category_order_index(str(a.get("category", "")))
	var order_b := _category_order_index(str(b.get("category", "")))
	if order_a != order_b:
		return order_a < order_b
	return str(a.get("name", "")) < str(b.get("name", ""))


func _category_order_index(category: String) -> int:
	var index := CATEGORY_ORDER.find(category)
	return index if index >= 0 else CATEGORY_ORDER.size()


func _category_color(category: String) -> Color:
	return CATEGORY_COLORS.get(category, Color(0.48, 0.7, 0.92))


func _make_tier_section(tier: int) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.name = "Tier_%d" % tier
	section.add_theme_constant_override("separation", 10)

	var header := Label.new()
	header.name = "TierHeader"
	header.text = "TIER %d" % tier
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 15)
	header.add_theme_color_override("font_color", Color(0.48, 0.7, 0.92))
	section.add_child(header)

	var category_row := HBoxContainer.new()
	category_row.name = "CategoryRow"
	category_row.alignment = BoxContainer.ALIGNMENT_CENTER
	category_row.add_theme_constant_override("separation", 48)
	section.add_child(category_row)
	return section


func _make_category_section(group: Dictionary) -> VBoxContainer:
	var category := str(group["category"])

	var section := VBoxContainer.new()
	section.name = "Category_%s" % category.replace(" ", "")
	section.add_theme_constant_override("separation", 10)
	section.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var header := Label.new()
	header.name = "CategoryHeader"
	header.text = category.to_upper()
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 13)
	header.add_theme_color_override("font_color", _category_color(category))
	section.add_child(header)

	var card_row := HBoxContainer.new()
	card_row.name = "TechCards"
	card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	card_row.add_theme_constant_override("separation", 24)
	section.add_child(card_row)
	return section


func _populate_category_section(
	section: VBoxContainer, group: Dictionary
) -> void:
	var card_row := section.get_node_or_null("TechCards") as HBoxContainer
	if card_row == null:
		return
	for technology in group["technologies"]:
		var node := TECH_NODE_SCENE.instantiate() as TechNode
		if node == null:
			continue
		card_row.add_child(node)
		node.setup(technology)
		node.research_requested.connect(_on_research_requested)
		_tech_nodes.append(node)


func active_research() -> Dictionary:
	return _active_research.duplicate(true)


func is_researching() -> bool:
	return not _active_research.is_empty()


func research_turns_remaining() -> int:
	return _turns_remaining


func research_turns_total() -> int:
	return _turns_total


func completed_technology_ids() -> Array[String]:
	return _completed_tech_ids.duplicate()


## Advances active research by one turn. Completing a project clears the active
## slot and emits research_completed so the Stellar View can apply unlocks.
func advance_research() -> void:
	if _active_research.is_empty():
		return

	_turns_remaining = maxi(0, _turns_remaining - 1)
	if _turns_remaining > 0:
		refresh_tech_cards()
		research_progressed.emit(
			_active_research.duplicate(true), _turns_remaining
		)
		return

	var completed := _active_research.duplicate(true)
	var tech_id := str(completed.get("id", ""))
	if not tech_id.is_empty() and not _completed_tech_ids.has(tech_id):
		_completed_tech_ids.append(tech_id)
	_active_research = {}
	_turns_total = 0
	_turns_remaining = 0
	refresh_tech_cards()
	research_completed.emit(completed)


func refresh_tech_cards() -> void:
	for node in _tech_nodes:
		if node == null or node.technology.is_empty():
			continue
		if bool(node.technology.get("available_by_default", false)):
			continue

		var tech_id := str(node.technology.get("id", ""))
		if _completed_tech_ids.has(tech_id):
			node.set_research_state("completed")
		elif _active_research.is_empty():
			node.set_research_state("available")
		elif str(_active_research.get("id", "")) == tech_id:
			node.set_research_state("active", _turns_remaining)
		else:
			node.set_research_state("blocked")


func _on_research_requested(technology: Dictionary) -> void:
	if not _active_research.is_empty():
		return
	if bool(technology.get("available_by_default", false)):
		return
	var tech_id := str(technology.get("id", ""))
	if _completed_tech_ids.has(tech_id):
		return
	_show_research_dialog(technology)


func _show_research_dialog(technology: Dictionary) -> void:
	_dialog_technology = technology.duplicate(true)
	var cost := int(technology.get("cost", 0))
	var time := int(technology.get("time", 0))

	dialog_title.text = str(technology.get("name", "Technology"))
	dialog_meta.text = "TIER %d  •  %s" % [
		int(technology.get("tier", 1)),
		str(technology.get("category", "")).to_upper(),
	]
	dialog_description.text = str(technology.get("description", ""))
	dialog_cost.text = "%d RD" % cost
	dialog_time.text = "%d %s" % [
		time, "turn" if time == 1 else "turns"
	]
	_update_dialog_funding()
	dialog_backdrop.visible = true
	research_dialog.visible = true


func _update_dialog_funding() -> void:
	if _dialog_technology.is_empty():
		return
	var cost := int(_dialog_technology.get("cost", 0))
	var affordable := _research_data >= cost
	dialog_confirm_button.disabled = not affordable
	dialog_warning.visible = not affordable
	if not affordable:
		dialog_warning.text = (
			"Insufficient Research Data — %d RD required, %d available."
			% [cost, _research_data]
		)


func _confirm_research() -> void:
	if _dialog_technology.is_empty() or not _active_research.is_empty():
		return

	var cost := int(_dialog_technology.get("cost", 0))
	if _research_data < cost:
		_update_dialog_funding()
		return

	var time := maxi(int(_dialog_technology.get("time", 1)), 1)
	_active_research = _dialog_technology.duplicate(true)
	_turns_total = time
	_turns_remaining = time
	_dialog_technology = {}
	_hide_research_dialog()
	refresh_tech_cards()
	research_started.emit(_active_research.duplicate(true))


func _hide_research_dialog() -> void:
	research_dialog.visible = false
	dialog_backdrop.visible = false
	_dialog_technology = {}


func _on_dialog_backdrop_input(event: InputEvent) -> void:
	if (
		research_dialog.visible
		and event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		_hide_research_dialog()


func _update_funds() -> void:
	funds_label.text = "%d RD" % _research_data


func _kill_tween() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = null
