class_name LCARS
extends RefCounted
## Shared LCARS-47 visual language for Stellar Core.
##
## Reference: `assets/LCARS 47 Anticuus System Directory.png`.
## Black ground, thick saturated blue/green frames with large corner radii,
## solid pill buttons carrying black text, and dense uppercase readouts in
## bright blue/green with yellow/red reserved for highlights and alerts.
##
## The previous UI used the common AI-generated look: translucent dark-navy
## glass panels, 1px low-contrast borders, 4-10px radii, drop shadows, and
## pale blue-gray body copy. Everything here pushes the other way: opaque
## black, 3-6px solid borders, 14-28px radii, no shadows, no translucency.

# Ground and frame accents sampled from the exemplar.
const BG := Color(0.0, 0.0, 0.0, 1.0)
const BLUE := Color(0.0, 0.565, 0.941, 1.0) # #0090F0
const BLUE_BRIGHT := Color(0.2, 0.68, 1.0, 1.0)
const BLUE_PALE := Color(0.55, 0.76, 1.0, 1.0)
const BLUE_DIM := Color(0.16, 0.34, 0.55, 1.0)
const GREEN := Color(0.0, 0.627, 0.188, 1.0) # #00A030
const GREEN_BRIGHT := Color(0.2, 0.85, 0.42, 1.0)
const GREEN_PALE := Color(0.55, 0.88, 0.66, 1.0)
const GREEN_DIM := Color(0.1, 0.38, 0.2, 1.0)
# Highlights / alerts. Yellow for costs and in-progress work, red for
# destructive or blocking states. Matches OUTLINE.md ("yellow and red
# highlight colors").
const YELLOW := Color(1.0, 0.8, 0.4, 1.0) # #FFCC66
const YELLOW_DIM := Color(0.72, 0.55, 0.28, 1.0)
const RED := Color(0.85, 0.25, 0.25, 1.0)
const RED_BRIGHT := Color(1.0, 0.38, 0.36, 1.0)
# Ink on top of solid pills, and running text on black.
const INK := Color(0.0, 0.0, 0.0, 1.0)
const TEXT_MAIN := Color(0.82, 0.9, 1.0, 1.0)
const TEXT_DIM := Color(0.5, 0.64, 0.82, 1.0)
const TEXT_FAINT := Color(0.38, 0.48, 0.62, 1.0)

const RADIUS_PANEL := 26
const RADIUS_BUTTON := 16
const RADIUS_PILL := 12
const BORDER_PANEL := 4
const BORDER_BUTTON := 0


## Opaque black panel with a thick saturated frame. No shadow, no blur.
static func panel_style(accent: Color = BLUE) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BG
	style.border_color = accent
	style.border_width_left = BORDER_PANEL
	style.border_width_top = BORDER_PANEL
	style.border_width_right = BORDER_PANEL
	style.border_width_bottom = BORDER_PANEL
	style.corner_radius_top_left = RADIUS_PANEL
	style.corner_radius_top_right = RADIUS_PANEL
	style.corner_radius_bottom_right = RADIUS_PANEL
	style.corner_radius_bottom_left = RADIUS_PANEL
	style.content_margin_left = 22.0
	style.content_margin_top = 20.0
	style.content_margin_right = 22.0
	style.content_margin_bottom = 22.0
	style.shadow_color = Color(0, 0, 0, 0)
	style.shadow_size = 0
	return style


## Solid LCARS pill. Black text on a saturated ground, per the exemplar's
## green/blue capsules ("2-745", "6-798", "MENU", "EXIT").
static func button_style(bg: Color = BLUE) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left = BORDER_BUTTON
	style.border_width_top = BORDER_BUTTON
	style.border_width_right = BORDER_BUTTON
	style.border_width_bottom = BORDER_BUTTON
	style.corner_radius_top_left = RADIUS_BUTTON
	style.corner_radius_top_right = RADIUS_BUTTON
	style.corner_radius_bottom_right = RADIUS_BUTTON
	style.corner_radius_bottom_left = RADIUS_BUTTON
	style.content_margin_left = 18.0
	style.content_margin_top = 10.0
	style.content_margin_right = 18.0
	style.content_margin_bottom = 10.0
	style.shadow_color = Color(0, 0, 0, 0)
	style.shadow_size = 0
	return style


static func button_hover_style(bg: Color = BLUE) -> StyleBoxFlat:
	return button_style(bg.lightened(0.18))


static func button_pressed_style(bg: Color = BLUE) -> StyleBoxFlat:
	return button_style(bg.darkened(0.22))


## Secondary action: black ground with a 2px accent outline and accent text.
static func ghost_style(
	accent: Color = BLUE, hover := false, pressed := false
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BG
	style.border_color = accent.lightened(0.18) if hover else accent
	if pressed:
		style.border_color = accent.darkened(0.2)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = RADIUS_PILL
	style.corner_radius_top_right = RADIUS_PILL
	style.corner_radius_bottom_right = RADIUS_PILL
	style.corner_radius_bottom_left = RADIUS_PILL
	style.content_margin_left = 16.0
	style.content_margin_top = 10.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 10.0
	style.shadow_color = Color(0, 0, 0, 0)
	style.shadow_size = 0
	return style


static func disabled_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.08, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.25, 0.27, 0.3, 1.0)
	style.corner_radius_top_left = RADIUS_PILL
	style.corner_radius_top_right = RADIUS_PILL
	style.corner_radius_bottom_right = RADIUS_PILL
	style.corner_radius_bottom_left = RADIUS_PILL
	style.content_margin_left = 16.0
	style.content_margin_top = 10.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 10.0
	return style


## Flat row highlight used inside sidebars and lists.
static func row_style(background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	return style


static func hover_row() -> StyleBoxFlat:
	return row_style(Color(BLUE.r, BLUE.g, BLUE.b, 0.28))


static func pressed_row() -> StyleBoxFlat:
	return row_style(Color(0.0, 0.08, 0.16, 1.0))


## Applies the solid-pill look to an existing Button.
## kind: "blue" | "green" | "yellow" | "red" | "ghost_blue" | "ghost_green"
static func style_button(button: Button, kind: String = "blue") -> void:
	match kind:
		"green":
			_apply_solid(button, GREEN)
		"yellow":
			_apply_solid(button, YELLOW)
		"red":
			_apply_solid(button, RED)
		"ghost_blue":
			_apply_ghost(button, BLUE)
		"ghost_green":
			_apply_ghost(button, GREEN)
		_:
			_apply_solid(button, BLUE)


static func _apply_solid(button: Button, bg: Color) -> void:
	button.add_theme_stylebox_override("normal", button_style(bg))
	button.add_theme_stylebox_override("hover", button_hover_style(bg))
	button.add_theme_stylebox_override("pressed", button_pressed_style(bg))
	button.add_theme_stylebox_override("disabled", disabled_style())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.57, 0.6))
	button.add_theme_color_override("font_focus_color", INK)


static func _apply_ghost(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", ghost_style(accent))
	button.add_theme_stylebox_override("hover", ghost_style(accent, true))
	button.add_theme_stylebox_override(
		"pressed", ghost_style(accent, false, true)
	)
	button.add_theme_stylebox_override("disabled", disabled_style())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", accent.lightened(0.35))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", accent.lightened(0.2))
	button.add_theme_color_override(
		"font_disabled_color", Color(0.42, 0.45, 0.5)
	)


## Header eyebrow: bright LCARS blue, uppercase, small.
static func style_eyebrow(label: Label, accent: Color = BLUE_BRIGHT) -> void:
	label.add_theme_color_override("font_color", accent)
	label.add_theme_font_size_override("font_size", 14)


## Large view title: bright blue on black, uppercase.
static func style_title(label: Label, size := 32) -> void:
	label.add_theme_color_override("font_color", BLUE_BRIGHT)
	label.add_theme_font_size_override("font_size", size)


## Meta line under a title: dim blue-green.
static func style_meta(label: Label) -> void:
	label.add_theme_color_override("font_color", TEXT_DIM)


## Numeric readout: right-aligned bright value in blue or green.
static func style_value(
	label: Label, accent: Color = GREEN_BRIGHT, size := 13
) -> void:
	label.add_theme_color_override("font_color", accent)
	label.add_theme_font_size_override("font_size", size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
