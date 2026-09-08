extends RefCounted

const PAPER := Color("#F7F0DF")
const PAPER_SOFT := Color("#FBF7EC")
const PAPER_HOVER := Color("#F1E8D5")
const INK := Color("#2B251F")
const MUTED := Color("#796E61")
const LINE := Color("#CFC3AD")
const MOSS := Color("#66775A")
const MOSS_SOFT := Color("#DCE3D4")
const NIGHT_GLASS := Color(0.075, 0.065, 0.055, 0.68)
const LIGHT_TEXT := Color("#F6EEDC")
const LIGHT_MUTED := Color("#D6CBB8")


static func heading_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Georgia",
		"Times New Roman",
		"Times",
	])
	font.font_weight = 400
	return font


static func body_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Avenir Next",
		"Helvetica Neue",
		"Arial",
	])
	return font


static func paper_style(
	background := PAPER,
	radius := 18,
	border_width := 1,
	border_color := LINE,
	shadow_size := 0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.border_color = border_color
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0

	if shadow_size > 0:
		style.shadow_color = Color(0.10, 0.08, 0.06, 0.16)
		style.shadow_size = shadow_size
		style.shadow_offset = Vector2(0.0, 3.0)

	return style


static func dark_glass_style(
	alpha := 0.68,
	radius := 18,
	border_width := 1
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(
		NIGHT_GLASS.r,
		NIGHT_GLASS.g,
		NIGHT_GLASS.b,
		alpha
	)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.border_color = Color(1.0, 0.95, 0.86, 0.16)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style


static func apply_heading(
	label: Label,
	size := 32,
	color := INK
) -> void:
	label.add_theme_font_override("font", heading_font())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)


static func apply_body(
	label: Label,
	size := 15,
	color := INK
) -> void:
	label.add_theme_font_override("font", body_font())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)


static func apply_room_button(
	button: Button,
	selected := false
) -> void:
	button.add_theme_font_override("font", body_font())
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_stylebox_override(
		"normal",
		paper_style(
			MOSS_SOFT if selected else Color(1, 1, 1, 0.0),
			14,
			1 if selected else 0,
			Color(MOSS.r, MOSS.g, MOSS.b, 0.42),
			0
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		paper_style(PAPER_HOVER, 14, 1, LINE, 0)
	)
	button.add_theme_stylebox_override(
		"pressed",
		paper_style(MOSS_SOFT, 14, 1, MOSS, 0)
	)


static func apply_soft_button(
	button: Button,
	selected := false
) -> void:
	button.add_theme_font_override("font", body_font())
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_stylebox_override(
		"normal",
		paper_style(
			MOSS_SOFT if selected else PAPER_SOFT,
			14,
			1,
			MOSS if selected else LINE,
			0
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		paper_style(PAPER_HOVER, 14, 1, MOSS, 0)
	)
	button.add_theme_stylebox_override(
		"pressed",
		paper_style(MOSS_SOFT, 14, 1, MOSS, 0)
	)


static func apply_dark_button(button: Button) -> void:
	button.add_theme_font_override("font", body_font())
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", LIGHT_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override(
		"normal",
		dark_glass_style(0.56, 18, 1)
	)
	button.add_theme_stylebox_override(
		"hover",
		dark_glass_style(0.82, 18, 1)
	)
	button.add_theme_stylebox_override(
		"pressed",
		dark_glass_style(0.92, 18, 1)
	)


static func apply_line_edit(input: LineEdit) -> void:
	input.add_theme_font_override("font", body_font())
	input.add_theme_font_size_override("font_size", 16)
	input.add_theme_color_override("font_color", INK)
	input.add_theme_color_override(
		"font_placeholder_color",
		Color("#9B8F80")
	)
	input.add_theme_stylebox_override(
		"normal",
		paper_style(PAPER_SOFT, 12, 1, LINE, 0)
	)
	input.add_theme_stylebox_override(
		"focus",
		paper_style(PAPER_SOFT, 12, 2, MOSS, 0)
	)


static func apply_spinbox(input: SpinBox) -> void:
	input.add_theme_font_override("font", body_font())
	input.add_theme_font_size_override("font_size", 15)
