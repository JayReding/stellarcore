class_name TechTree
extends CanvasLayer
## Full-screen technology tree. Technologies are data entries rendered as
## rounded-square cards and funded with the galaxy-wide Research Data pool.

signal closed

const TECH_NODE_SCENE: PackedScene = preload("res://scenes/ui/tech_node.tscn")
const TECHNOLOGIES := [
	{
		"id": "ftl_probes",
		"name": "FTL Probes",
		"tier": 1,
		"category": "Propulsion",
		"cost": 0,
		"available_by_default": true,
		"icon": "FTL",
		"description": "Faster-than-light probes for deep-space reconnaissance.",
	},
]

@onready var root: Control = $Root
@onready var back_button: Button = %BackButton
@onready var meta_label: Label = %MetaLabel
@onready var funds_label: Label = %FundsLabel
@onready var tech_list: HBoxContainer = %TechList

var _research_data: int = 0
var _tween: Tween


func _ready() -> void:
	back_button.pressed.connect(close)
	_populate()
	_update_funds()
	visible = false


func open(research_data: int = 0) -> void:
	_research_data = maxi(research_data, 0)
	_update_funds()
	visible = true
	_kill_tween()
	root.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(root, "modulate:a", 1.0, 0.2)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func refresh_research_data(research_data: int) -> void:
	_research_data = maxi(research_data, 0)
	_update_funds()


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


func _populate() -> void:
	for child in tech_list.get_children():
		child.queue_free()

	for technology in TECHNOLOGIES:
		var node := TECH_NODE_SCENE.instantiate() as TechNode
		if node == null:
			continue
		tech_list.add_child(node)
		node.setup(technology)

	var noun := "TECHNOLOGY" if TECHNOLOGIES.size() == 1 else "TECHNOLOGIES"
	meta_label.text = "TECH TREE  •  %d %s" % [TECHNOLOGIES.size(), noun]


func _update_funds() -> void:
	funds_label.text = "%d RD" % _research_data


func _kill_tween() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = null
