class_name StarNode
extends Node3D
## Visual representation of one star system.

const TEXTURE_SIZE := 128
const HOME_LABEL_REFERENCE_DISTANCE := 120.0

@onready var visual: MeshInstance3D = $Visual
@onready var halo: MeshInstance3D = $Halo
@onready var selection_ring: MeshInstance3D = $SelectionRing
@onready var home_label: Label3D = $HomeLabel
@onready var survey_label: Label3D = $SurveyLabel
@onready var pick_body: StaticBody3D = $PickBody
@onready var pick_shape: CollisionShape3D = $PickBody/CollisionShape3D

var data: StarData

var _star_color := Color.WHITE
var _ring_base_scale := 1.0
var _selected := false
var _surveyed := false
var _pulse_time := 0.0

static var _halo_texture: ImageTexture
static var _ring_texture: ImageTexture


func setup(star_data: StarData) -> void:
	data = star_data
	if data == null:
		return

	name = "Star_%s" % data.id
	position = GalaxyScale.to_world(data.position_ly)
	_star_color = data.class_color()

	var radius := data.visual_radius
	visual.scale = Vector3.ONE * radius

	home_label.visible = data.is_home
	if data.is_home:
		home_label.text = "⭐ " + data.display_name.to_upper()
		home_label.position = Vector3(0.0, radius + 2.0, 0.0)

	refresh_survey_label()

	var surface_material := visual.material_override as ShaderMaterial
	if surface_material != null:
		surface_material = surface_material.duplicate() as ShaderMaterial
		visual.material_override = surface_material
		surface_material.set_shader_parameter("star_color", _star_color)
		surface_material.set_shader_parameter("intensity", 2.0)

	halo.scale = Vector3.ONE * radius * 7.0
	halo.visible = true
	halo.material_override = _make_glow_material(
		_get_halo_texture(), Color(_star_color.r, _star_color.g, _star_color.b, 0.42)
	)
	_refresh_halo()

	_ring_base_scale = radius * 3.2
	selection_ring.scale = Vector3.ONE * _ring_base_scale
	selection_ring.visible = false
	selection_ring.material_override = _make_glow_material(
		_get_ring_texture(), Color(0.55, 0.85, 1.0, 0.9)
	)


func set_selected(value: bool) -> void:
	if _selected == value:
		return
	_selected = value
	selection_ring.visible = value
	_refresh_halo()


func _process(delta: float) -> void:
	if data != null and data.surveyed != _surveyed:
		refresh_survey_label()

	if home_label.visible or survey_label.visible:
		_update_label_scales()

	if not _selected:
		return
	_pulse_time += delta
	var pulse := 1.0 + sin(_pulse_time * 4.0) * 0.05
	selection_ring.scale = Vector3.ONE * _ring_base_scale * pulse


## Names explored systems beneath the star. Newhome keeps its dedicated
## home label, so its survey label stays hidden to avoid duplicating the name.
## Colonized systems get a dot after their name.
func refresh_survey_label() -> void:
	_surveyed = data != null and data.surveyed
	survey_label.visible = _surveyed and not data.is_home
	if not survey_label.visible:
		return
	survey_label.text = data.display_name
	if data.has_colony():
		survey_label.text += " ●"
	survey_label.position = Vector3(0.0, -(data.visual_radius + 1.35), 0.0)


func _update_label_scales() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var camera_distance := camera.global_position.distance_to(global_position)
	var scale_factor := clampf(
		camera_distance / HOME_LABEL_REFERENCE_DISTANCE, 0.3, 1.5
	)
	if home_label.visible:
		home_label.scale = Vector3.ONE * scale_factor
	if survey_label.visible:
		survey_label.scale = Vector3.ONE * scale_factor


func _refresh_halo() -> void:
	var material := halo.material_override as StandardMaterial3D
	if material == null:
		return
	var alpha := 0.6 if _selected else 0.42
	material.albedo_color = Color(_star_color.r, _star_color.g, _star_color.b, alpha)


func _make_glow_material(texture: Texture2D, color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.albedo_texture = texture
	material.albedo_color = color
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return material


static func _get_halo_texture() -> ImageTexture:
	if _halo_texture == null:
		_halo_texture = _make_halo_texture()
	return _halo_texture


static func _get_ring_texture() -> ImageTexture:
	if _ring_texture == null:
		_ring_texture = _make_ring_texture()
	return _ring_texture


static func _make_halo_texture() -> ImageTexture:
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center := (TEXTURE_SIZE - 1) * 0.5
	for y in TEXTURE_SIZE:
		for x in TEXTURE_SIZE:
			var distance := Vector2(x - center, y - center).length() / center
			var alpha := 0.0
			if distance < 1.0:
				alpha = pow(1.0 - distance, 3.8)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)


static func _make_ring_texture() -> ImageTexture:
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center := (TEXTURE_SIZE - 1) * 0.5
	var inner := 0.82
	var outer := 0.88
	var softness := 0.012
	for y in TEXTURE_SIZE:
		for x in TEXTURE_SIZE:
			var distance := Vector2(x - center, y - center).length() / center
			var outer_fade := smoothstep(outer + softness, outer - softness, distance)
			var inner_fade := smoothstep(inner - softness, inner + softness, distance)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, outer_fade * inner_fade))
	return ImageTexture.create_from_image(image)
