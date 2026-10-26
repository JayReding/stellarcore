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
## Categories stay hidden until unlocked by a later game stage. Advanced
## Technology has no unlock yet, so its column is reserved for the future.
const HIDDEN_CATEGORIES: Array[String] = ["Advanced Technology"]
## Mouse-wheel zoom limits for the tech tree grid.
const MIN_ZOOM := 0.5
const MAX_ZOOM := 2.0
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
	{
		"id": "destroyer_hull_plan",
		"name": "Destroyer Hull Plan",
		"tier": 1,
		"category": "Military",
		"cost": 50,
		"time": 3,
		"available_by_default": false,
		"icon": "DES",
		"description": "Small and light military platform. Uses standard "
		+ "missiles for long range combat.",
		"unlocks": {
			"structures": [],
			"ships": [],
		},
	},
]

@onready var root: Control = $Root
@onready var back_button: Button = %BackButton
@onready var meta_label: Label = %MetaLabel
@onready var funds_label: Label = %FundsLabel
@onready var tech_scroll: ScrollContainer = %TreeScroll
@onready var tech_grid: GridContainer = %TechGrid
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
var _zoom := 1.0
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
	_reset_zoom()
	refresh_tech_cards()
	visible = true
	_kill_tween()
	root.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(root, "modulate:a", 1.0, 0.2)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _reset_zoom() -> void:
	_zoom = 1.0
	tech_grid.scale = Vector2.ONE
	tech_grid.custom_minimum_size = Vector2.ZERO


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


## Ctrl+mouse wheel zooms the grid around the cursor. Plain wheel input is
## left alone so the scroll container keeps scrolling normally.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventMouseButton):
		return
	var wheel := event as InputEventMouseButton
	if not wheel.pressed or not wheel.ctrl_pressed:
		return
	if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
		_apply_zoom(1.1, wheel.position)
		get_viewport().set_input_as_handled()
	elif wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_apply_zoom(1.0 / 1.1, wheel.position)
		get_viewport().set_input_as_handled()


func _apply_zoom(factor: float, anchor: Vector2) -> void:
	var old := _zoom
	_zoom = clampf(_zoom * factor, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(_zoom, old):
		return
	# custom_minimum_size feeds the scrollbars, so re-derive the unscaled
	# base before scaling; everything happens before the next frame.
	tech_grid.custom_minimum_size = Vector2.ZERO
	var base := tech_grid.get_combined_minimum_size()
	tech_grid.custom_minimum_size = base * _zoom
	tech_grid.scale = Vector2(_zoom, _zoom)
	# Keep the content under the cursor stable across the zoom step.
	var local := anchor - tech_scroll.get_global_rect().position
	var content := (
		Vector2(tech_scroll.scroll_horizontal, tech_scroll.scroll_vertical)
		+ local
	) / old
	var target := content * _zoom - local
	tech_scroll.scroll_horizontal = int(maxf(target.x, 0.0))
	tech_scroll.scroll_vertical = int(maxf(target.y, 0.0))


func _shown_categories() -> Array[String]:
	var shown: Array[String] = []
	for category in CATEGORY_ORDER:
		if HIDDEN_CATEGORIES.has(str(category)):
			continue
		shown.append(str(category))
	return shown


func _populate() -> void:
	for child in tech_grid.get_children():
		tech_grid.remove_child(child)
		child.queue_free()
	_tech_nodes.clear()

	var max_tier := 1
	for technology in TECHNOLOGIES:
		max_tier = maxi(max_tier, int(technology.get("tier", 1)))

	var categories := _shown_categories()
	tech_grid.columns = categories.size() + 1

	var corner := Control.new()
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tech_grid.add_child(corner)
	for category in categories:
		tech_grid.add_child(_make_category_header(str(category)))

	for tier in range(1, max_tier + 1):
		tech_grid.add_child(_make_tier_cell(tier))
		for category in categories:
			var cell := _make_tech_cell(tier, str(category))
			tech_grid.add_child(cell)
			_populate_tech_cell(cell, tier, str(category))

	var noun := "TECHNOLOGY" if TECHNOLOGIES.size() == 1 else "TECHNOLOGIES"
	meta_label.text = "TECH TREE  •  %d %s  •  %d CATEGORIES  •  %d %s" % [
		TECHNOLOGIES.size(), noun,
		categories.size(),
		max_tier, "TIER" if max_tier == 1 else "TIERS",
	]
	refresh_tech_cards()


func _category_color(category: String) -> Color:
	return CATEGORY_COLORS.get(category, Color(0.48, 0.7, 0.92))


## One centered header per category column, in the configured category order.
func _make_category_header(category: String) -> Label:
	var header := Label.new()
	header.name = "CategoryHeader_%s" % category.replace(" ", "")
	header.text = category.to_upper()
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", _category_color(category))
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return header


## Tier gutter label marking the start of each technology row.
func _make_tier_cell(tier: int) -> Label:
	var label := Label.new()
	label.name = "TierLabel_%d" % tier
	label.text = "TIER %d" % tier
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.48, 0.7, 0.92))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## One cell per tier/category pair holding that slot's cards top to bottom.
## Cards are added after the cell joins the tree so their _ready hooks run.
func _make_tech_cell(tier: int, category: String) -> VBoxContainer:
	var cell := VBoxContainer.new()
	cell.name = "TechCell_%d_%s" % [tier, category.replace(" ", "")]
	cell.custom_minimum_size = Vector2(208, 0)
	cell.add_theme_constant_override("separation", 16)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return cell


func _populate_tech_cell(cell: VBoxContainer, tier: int, category: String) -> void:
	for technology in TECHNOLOGIES:
		if (
			int(technology.get("tier", 1)) != tier
			or str(technology.get("category", "")) != category
		):
			continue
		var node := TECH_NODE_SCENE.instantiate() as TechNode
		if node == null:
			continue
		cell.add_child(node)
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
