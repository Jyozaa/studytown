extends RefCounted

# StudyTown scrapbook / noticeboard UI helpers.
# Assumes the supplied folder has been copied to:
#   res://assets/ui_elements/

const ASSET_ROOT := "res://assets/ui_elements"

const INK := Color("#2d241d")
const INK_SOFT := Color("#5f5144")
const PAPER := Color("#f5e7c6")
const PAPER_LIGHT := Color("#fff6df")
const MOSS := Color("#6f7f56")
const MOSS_DARK := Color("#4d6141")
const BLUSH := Color("#cf8f7f")
const TAN := Color("#c8a46d")
const RED := Color("#a95546")
const SHADOW := Color(0.12, 0.08, 0.045, 0.26)


static func hand_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Noteworthy",
		"Chalkboard SE",
		"Marker Felt",
		"Bradley Hand",
		"Comic Sans MS",
		"Arial Rounded MT Bold",
	])
	return font


static func title_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Chalkboard SE",
		"Noteworthy",
		"Marker Felt",
		"Arial Rounded MT Bold",
	])
	font.font_weight = 700
	return font


static func asset(relative_path: String) -> Texture2D:
	var full_path := "%s/%s" % [
		ASSET_ROOT,
		relative_path,
	]

	if not ResourceLoader.exists(full_path):
		push_warning(
			"Scrapbook UI asset missing: %s" % full_path
		)
		return null

	return load(full_path) as Texture2D


static func texture(
	relative_path: String,
	position_value: Vector2,
	size_value: Vector2,
	rotation_degrees_value := 0.0,
	mouse_passthrough := true
) -> TextureRect:
	var rect := TextureRect.new()
	# Set expand mode before the texture. Godot otherwise caches the source
	# image as this Control's minimum size and silently overrides our authored
	# dimensions when it enters the tree.
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.texture = asset(relative_path)
	rect.position = position_value
	rect.size = size_value
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.rotation = deg_to_rad(rotation_degrees_value)
	rect.pivot_offset = size_value * 0.5

	if mouse_passthrough:
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	return rect


static func paper(
	parent: Node,
	relative_path: String,
	position_value: Vector2,
	size_value: Vector2,
	rotation_degrees_value := 0.0
) -> NinePatchRect:
	var rect := NinePatchRect.new()
	var paper_texture := asset(relative_path)
	rect.texture = paper_texture
	rect.position = position_value
	rect.size = size_value
	rect.rotation = deg_to_rad(rotation_degrees_value)
	rect.pivot_offset = size_value * 0.5
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if paper_texture != null:
		var source_size := paper_texture.get_size()
		var margin := mini(
			48,
			maxi(
				16,
				roundi(minf(source_size.x, source_size.y) * 0.16)
			)
		)
		rect.patch_margin_left = margin
		rect.patch_margin_top = margin
		rect.patch_margin_right = margin
		rect.patch_margin_bottom = margin

	parent.add_child(rect)
	return rect


static func sticker(
	parent: Node,
	relative_path: String,
	position_value: Vector2,
	size_value: Vector2,
	rotation_degrees_value := 0.0
) -> TextureRect:
	var rect := texture(
		relative_path,
		position_value,
		size_value,
		rotation_degrees_value,
		true
	)
	parent.add_child(rect)
	return rect


static func label(
	text_value: String,
	size_value := 18,
	color_value := INK,
	title := false
) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_override(
		"font",
		title_font() if title else hand_font()
	)
	label.add_theme_font_size_override(
		"font_size",
		size_value
	)
	label.add_theme_color_override(
		"font_color",
		color_value
	)
	label.add_theme_color_override(
		"font_shadow_color",
		Color(1.0, 0.96, 0.87, 0.16)
	)
	label.add_theme_constant_override(
		"shadow_offset_x",
		1
	)
	label.add_theme_constant_override(
		"shadow_offset_y",
		1
	)
	return label


static func rough_style(
	background: Color,
	radius := 8,
	border_width := 1,
	border_color := Color("#aa9474")
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius + 2
	style.corner_radius_bottom_left = radius + 1
	style.corner_radius_bottom_right = maxi(radius - 1, 0)

	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.border_color = border_color

	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0

	style.shadow_color = SHADOW
	style.shadow_size = 2
	style.shadow_offset = Vector2(1.5, 2.5)
	return style


static func apply_paper_button(
	button: Button,
	selected := false,
	green := false
) -> void:
	var base := (
		Color("#788768")
		if green or selected
		else Color("#ead9b7")
	)

	var border := (
		MOSS_DARK
		if green or selected
		else Color("#b59a73")
	)

	button.add_theme_font_override(
		"font",
		hand_font()
	)
	button.add_theme_font_size_override(
		"font_size",
		15
	)
	button.add_theme_color_override(
		"font_color",
		Color("#fff7e3") if green else INK
	)
	button.add_theme_color_override(
		"font_hover_color",
		Color("#fff7e3") if green else INK
	)
	button.add_theme_color_override(
		"font_pressed_color",
		Color("#fff7e3") if green else INK
	)

	button.add_theme_stylebox_override(
		"normal",
		rough_style(
			base,
			7,
			1,
			border
		)
	)

	button.add_theme_stylebox_override(
		"hover",
		rough_style(
			base.lightened(0.08),
			8,
			2,
			border
		)
	)

	button.add_theme_stylebox_override(
		"pressed",
		rough_style(
			base.darkened(0.08),
			7,
			2,
			border
		)
	)


static func apply_text_button(
	button: Button
) -> void:
	button.flat = true
	button.add_theme_font_override(
		"font",
		hand_font()
	)
	button.add_theme_font_size_override(
		"font_size",
		15
	)
	button.add_theme_color_override(
		"font_color",
		INK
	)
	button.add_theme_color_override(
		"font_hover_color",
		MOSS_DARK
	)
	button.add_theme_color_override(
		"font_pressed_color",
		MOSS_DARK
	)


static func apply_line_edit(input: LineEdit) -> void:
	input.add_theme_font_override(
		"font",
		hand_font()
	)
	input.add_theme_font_size_override(
		"font_size",
		16
	)
	input.add_theme_color_override(
		"font_color",
		INK
	)
	input.add_theme_color_override(
		"font_placeholder_color",
		Color("#8f7c67")
	)
	input.add_theme_stylebox_override(
		"normal",
		rough_style(
			Color("#f8edda"),
			6,
			1,
			Color("#c4ab83")
		)
	)
	input.add_theme_stylebox_override(
		"focus",
		rough_style(
			Color("#fff4dc"),
			6,
			2,
			MOSS
		)
	)


static func apply_spin_box(spin: SpinBox) -> void:
	spin.add_theme_font_override(
		"font",
		hand_font()
	)
	spin.add_theme_font_size_override(
		"font_size",
		15
	)


static func make_click_area(
	position_value: Vector2,
	size_value: Vector2
) -> Button:
	var button := Button.new()
	button.position = position_value
	button.size = size_value
	button.text = ""
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL

	var transparent := StyleBoxFlat.new()
	transparent.bg_color = Color.TRANSPARENT

	button.add_theme_stylebox_override(
		"normal",
		transparent
	)
	button.add_theme_stylebox_override(
		"hover",
		transparent
	)
	button.add_theme_stylebox_override(
		"pressed",
		transparent
	)
	return button
