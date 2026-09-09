extends RefCounted

const HoverFrameScript := preload(
	"res://scripts/ui/retro_hover_frame.gd"
)

# Dark rounded StudyTown UI, inspired by the interaction language in the
# supplied reference while retaining StudyTown's own content and mechanics.
const NAVY := Color("#111318")
const BLUE := Color("#4f8df7")
const BLUE_DARK := Color("#2f65cb")
const BLUE_LIGHT := Color("#252936")
const BLUE_CARD := Color("#21242b")
const BLUE_HOVER := Color("#2b2f38")

const GREEN := Color("#75ca72")
const GREEN_DARK := Color("#355f3b")
const ORANGE := Color("#f2a02a")
const CORAL := Color("#ff756f")
const LILAC := Color("#c8b5ff")
const PEACH := Color("#ffb98f")

const PANEL := Color("#1a1c21")
const PANEL_ALT := Color("#202228")
const PANEL_DARK := Color("#15171b")

const INK := Color("#f4f5f7")
const WHITE := Color("#ffffff")
const MUTED := Color("#8b8f99")
const OUTLINE := Color("#30333a")
const LIGHT_OUTLINE := Color("#3c3f47")
const RUNNER := Color("#79adff")
const DANGER := Color("#d75f67")


static func heading_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Arial Rounded MT Bold",
		"Avenir Next",
		"Trebuchet MS",
		"Helvetica Neue",
	])
	font.font_weight = 800
	return font


static func body_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Inter",
		"SF Pro Text",
		"Helvetica Neue",
		"Arial",
	])
	return font


static func mono_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Menlo",
		"Monaco",
		"Courier New",
	])
	font.font_weight = 800
	return font


static func panel_style(
	background: Color,
	border_color := OUTLINE,
	border_width := 2,
	radius := 18,
	shadow_size := 0,
	shadow_offset := Vector2.ZERO
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background

	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.border_color = border_color

	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius

	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0

	if shadow_size > 0:
		style.shadow_color = Color(0.01, 0.02, 0.04, 0.66)
		style.shadow_size = shadow_size
		style.shadow_offset = shadow_offset

	return style


static func header_style(
	background := PANEL_ALT,
	radius := 14
) -> StyleBoxFlat:
	return panel_style(
		background,
		background.lightened(0.04),
		1,
		radius
	)


static func label(
	text_value: String,
	size_value := 14,
	color_value := INK,
	heading := false,
	mono := false
) -> Label:
	var output := Label.new()
	output.text = text_value

	var font := body_font()

	if heading:
		font = heading_font()
	elif mono:
		font = mono_font()

	output.add_theme_font_override("font", font)
	output.add_theme_font_size_override("font_size", size_value)
	output.add_theme_color_override("font_color", color_value)
	return output


static func apply_button(
	button: Button,
	selected := false,
	green := false,
	danger := false,
	compact := false,
	radius := 18,
	orange := false
) -> void:
	var base := BLUE
	var hover := Color("#639bf9")
	var border := BLUE_DARK
	var pressed_base := BLUE_DARK

	if selected:
		base = Color("#2b3040")
		hover = Color("#343a4c")
		border = BLUE
		pressed_base = Color("#252a36")

	if green:
		base = GREEN
		hover = GREEN.lightened(0.06)
		border = GREEN_DARK
		pressed_base = GREEN_DARK

	if danger:
		base = DANGER
		hover = DANGER.lightened(0.05)
		border = Color("#8f3940")
		pressed_base = Color("#8f3940")

	if orange:
		base = ORANGE
		hover = ORANGE.lightened(0.06)
		border = Color("#a96816")
		pressed_base = Color("#c57b1e")

	button.add_theme_font_override("font", heading_font())
	button.add_theme_font_size_override(
		"font_size",
		11 if compact else 14
	)
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_color_override("font_hover_color", WHITE)
	button.add_theme_color_override("font_pressed_color", WHITE)
	button.add_theme_color_override("font_focus_color", WHITE)

	button.add_theme_stylebox_override(
		"normal",
		panel_style(
			base,
			border,
			2,
			radius,
			5,
			Vector2(0, 5)
		)
	)

	button.add_theme_stylebox_override(
		"hover",
		panel_style(
			hover,
			hover.lightened(0.16),
			2,
			radius,
			5,
			Vector2(0, 5)
		)
	)

	button.add_theme_stylebox_override(
		"pressed",
		panel_style(
			pressed_base,
			pressed_base.darkened(0.12),
			2,
			radius,
			1,
			Vector2(0, 1)
		)
	)

	button.add_theme_stylebox_override(
		"focus",
		panel_style(
			base,
			Color("#9bc1ff"),
			2,
			radius,
			5,
			Vector2(0, 5)
		)
	)

	enable_press_animation(button)


static func enable_press_animation(
	button: Button,
	depth := 3.0
) -> void:
	if bool(
		button.get_meta(
			"studytown_press_animation",
			false
		)
	):
		return

	button.set_meta(
		"studytown_press_animation",
		true
	)

	button.button_down.connect(
		func():
			button.pivot_offset = button.size * 0.5

			if not button.get_parent() is Container:
				button.set_meta(
					"studytown_press_origin",
					button.position
				)
				button.position.y += depth

			var tween := button.create_tween()
			tween.set_trans(Tween.TRANS_QUAD)
			tween.set_ease(Tween.EASE_OUT)
			tween.tween_property(
				button,
				"scale",
				Vector2(0.994, 0.972),
				0.045
			)
	)

	var release := func():
		button.pivot_offset = button.size * 0.5

		if (
			not button.get_parent() is Container
			and button.has_meta(
				"studytown_press_origin"
			)
		):
			button.position = button.get_meta(
				"studytown_press_origin"
			)

		var tween := button.create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(
			button,
			"scale",
			Vector2.ONE,
			0.10
		)

	button.button_up.connect(release)
	button.mouse_exited.connect(
		func():
			if not button.is_pressed():
				release.call()
	)


static func apply_sidebar_button(
	button: Button,
	selected := false
) -> void:
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT

	if selected:
		apply_button(
			button,
			true,
			false,
			false,
			true,
			22
		)
		return

	button.flat = true
	button.add_theme_font_override(
		"font",
		heading_font()
	)
	button.add_theme_font_size_override(
		"font_size",
		11
	)
	button.add_theme_color_override(
		"font_color",
		MUTED
	)
	button.add_theme_color_override(
		"font_hover_color",
		WHITE
	)
	button.add_theme_color_override(
		"font_pressed_color",
		WHITE
	)
	enable_press_animation(
		button,
		2.0
	)


static func apply_line_edit(
	input: LineEdit,
	radius := 14
) -> void:
	input.add_theme_font_override(
		"font",
		body_font()
	)
	input.add_theme_font_size_override(
		"font_size",
		14
	)
	input.add_theme_color_override(
		"font_color",
		WHITE
	)
	input.add_theme_color_override(
		"font_placeholder_color",
		Color("#7c808b")
	)
	input.add_theme_color_override(
		"caret_color",
		BLUE
	)

	input.add_theme_stylebox_override(
		"normal",
		panel_style(
			Color("#181a1f"),
			LIGHT_OUTLINE,
			2,
			radius
		)
	)

	input.add_theme_stylebox_override(
		"focus",
		panel_style(
			Color("#1e2127"),
			BLUE,
			2,
			radius
		)
	)


static func apply_text_edit(
	input: TextEdit,
	radius := 16
) -> void:
	input.add_theme_font_override(
		"font",
		body_font()
	)
	input.add_theme_font_size_override(
		"font_size",
		14
	)
	input.add_theme_color_override(
		"font_color",
		WHITE
	)
	input.add_theme_color_override(
		"font_placeholder_color",
		MUTED
	)
	input.add_theme_color_override(
		"caret_color",
		BLUE
	)
	input.add_theme_stylebox_override(
		"normal",
		panel_style(
			Color("#181a1f"),
			LIGHT_OUTLINE,
			2,
			radius
		)
	)
	input.add_theme_stylebox_override(
		"focus",
		panel_style(
			Color("#1e2127"),
			BLUE,
			2,
			radius
		)
	)


static func apply_spin_box(
	spin: SpinBox
) -> void:
	spin.add_theme_font_override(
		"font",
		body_font()
	)
	spin.add_theme_font_size_override(
		"font_size",
		14
	)


static func attach_hover_frame(
	target: Control,
	selected := false
) -> Control:
	var frame := HoverFrameScript.new()
	frame.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	frame.offset_left = -2.0
	frame.offset_top = -2.0
	frame.offset_right = 2.0
	frame.offset_bottom = 2.0
	frame.set_selected(selected)
	frame.base_color = OUTLINE
	frame.selected_color = WHITE
	frame.runner_color = RUNNER

	target.add_child(frame)
	target.move_child(
		frame,
		target.get_child_count() - 1
	)

	target.mouse_entered.connect(
		func():
			frame.set_hovered(true)
	)

	target.mouse_exited.connect(
		func():
			frame.set_hovered(false)
	)

	return frame


static func create_window(
	parent: Node,
	position_value: Vector2,
	size_value: Vector2,
	title_text: String,
	header_color := PANEL_ALT,
	radius := 22
) -> Control:
	var root := Control.new()
	root.position = position_value
	root.size = size_value
	parent.add_child(root)

	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	panel.add_theme_stylebox_override(
		"panel",
		panel_style(
			PANEL,
			OUTLINE,
			2,
			radius,
			4,
			Vector2(0, 4)
		)
	)
	root.add_child(panel)

	if not title_text.is_empty():
		var header := Panel.new()
		header.position = Vector2(10, 10)
		header.size = Vector2(
			size_value.x - 20,
			36
		)
		header.add_theme_stylebox_override(
			"panel",
			header_style(
				header_color,
				maxi(
					radius - 8,
					10
				)
			)
		)
		root.add_child(header)

		var title := label(
			title_text,
			13,
			WHITE,
			true
		)
		title.position = Vector2(10, 6)
		title.size = Vector2(
			header.size.x - 20,
			24
		)
		header.add_child(title)

	return root
