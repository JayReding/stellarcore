class_name FleetMarker
extends Node3D
## Clickable map marker for a fleet in transit. The marker shows the fleet name
## and is removed when the fleet arrives.

const PICK_RADIUS := 2.15
const ICON_TEXTURE_SIZE := 64
const ICON_PIXEL_SIZE := 0.058

static var _icon_texture: ImageTexture

var fleet: FleetData

var _sprite: Sprite3D
var _label: Label3D


func setup(fleet_data: FleetData, world_position: Vector3) -> void:
	fleet = fleet_data
	position = world_position
	name = "FleetMarker_%s" % fleet.name.replace(" ", "_")
	_build_visuals()
	_refresh()


func _build_visuals() -> void:
	_sprite = Sprite3D.new()
	_sprite.texture = _get_icon_texture()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.no_depth_test = true
	_sprite.pixel_size = ICON_PIXEL_SIZE
	_sprite.render_priority = 3
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_sprite)

	_label = Label3D.new()
	_label.position = Vector3(0.0, 2.2, 0.0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 30
	_label.pixel_size = 0.045
	_label.outline_size = 10
	_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.92)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.render_priority = 2
	add_child(_label)

	var pick_body := StaticBody3D.new()
	pick_body.name = "PickBody"
	pick_body.collision_layer = 4
	pick_body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = PICK_RADIUS
	collision.shape = shape
	pick_body.add_child(collision)
	add_child(pick_body)


func _refresh() -> void:
	if fleet == null:
		return

	_sprite.modulate = Color(1.0, 0.82, 0.46, 1.0)
	_label.modulate = Color(1.0, 0.88, 0.62, 1.0)
	_label.text = fleet.name


static func _get_icon_texture() -> ImageTexture:
	if _icon_texture == null:
		_icon_texture = _make_icon_texture()
	return _icon_texture


static func _make_icon_texture() -> ImageTexture:
	var image := Image.create(
		ICON_TEXTURE_SIZE,
		ICON_TEXTURE_SIZE,
		false,
		Image.FORMAT_RGBA8
	)
	var center := (ICON_TEXTURE_SIZE - 1) * 0.5
	for y in ICON_TEXTURE_SIZE:
		for x in ICON_TEXTURE_SIZE:
			var dx := (float(x) - center) / center
			var dy := (float(y) - center) / center
			var diamond := absf(dx) + absf(dy)
			var alpha := 0.0
			if diamond > 0.46 and diamond < 0.62:
				alpha = 1.0
			elif diamond <= 0.25:
				alpha = (1.0 - diamond / 0.25) * 0.95
			if diamond < 1.0:
				alpha = maxf(alpha, pow(1.0 - diamond, 4.2) * 0.30)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)
