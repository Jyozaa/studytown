extends RefCounted

const Tactile := preload("res://scripts/ui/tactile_button.gd")
const BG := Color("15161A")
const PANEL := Color("1A1C21")
const NESTED := Color("1E2026")
const BORDER := Color("30333A")
const TEXT := Color("F4F5F7")
const MUTED := Color("8B8F99")
const BLUE := Color("4F8DF7")
const GREEN := Color("75CA72")
const CORAL := Color("FF756F")
const ORANGE := Color("F2A02A")


static func style(color := PANEL, radius := 22, border := BORDER) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.set_corner_radius_all(radius)
	result.set_border_width_all(1)
	result.border_color = border
	result.shadow_color = Color(0, 0, 0, 0.22)
	result.shadow_size = 6
	result.shadow_offset = Vector2(0, 4)
	return result


static func panel(parent: Node, rect: Rect2, color := PANEL, radius := 22) -> Panel:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.add_theme_stylebox_override("panel", style(color, radius))
	parent.add_child(node)
	return node


static func label(parent: Node, text: String, rect: Rect2, font_size := 16, color := TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(node)
	return node


static func button(
	parent: Node, text: String, rect: Rect2, action: Callable, color := Color("272A32")
) -> Button:
	var node := Tactile.new()
	node.position = rect.position
	node.size = rect.size
	node.configure(text, color)
	if action.is_valid():
		node.pressed.connect(action)
	parent.add_child(node)
	return node


static func input(parent: Node, value: String, placeholder: String, rect: Rect2) -> LineEdit:
	var node := LineEdit.new()
	node.position = rect.position
	node.size = rect.size
	node.text = value
	node.placeholder_text = placeholder
	node.add_theme_font_size_override("font_size", 17)
	node.add_theme_color_override("font_color", TEXT)
	node.add_theme_stylebox_override("normal", style(NESTED, 12))
	node.add_theme_stylebox_override("focus", style(NESTED, 12, BLUE))
	for state in ["normal", "focus"]:
		var input_style := node.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		input_style.content_margin_left = 14
		input_style.content_margin_right = 14
		node.add_theme_stylebox_override(state, input_style)
	parent.add_child(node)
	return node


static func slider(
	parent: Node,
	rect: Rect2,
	minimum: float,
	maximum: float,
	step: float,
	value: float,
	changed: Callable,
	color := BLUE
) -> HSlider:
	var node := HSlider.new()
	node.position = rect.position
	node.size = rect.size
	node.min_value = minimum
	node.max_value = maximum
	node.step = step
	node.value = value
	node.add_theme_stylebox_override("slider", style(BORDER, 3))
	node.add_theme_stylebox_override("grabber_area", style(color, 3, color))
	node.add_theme_stylebox_override(
		"grabber_area_highlight", style(color.lightened(0.1), 3, color)
	)
	if changed.is_valid():
		node.value_changed.connect(changed)
	parent.add_child(node)
	return node


static func fade(control: Control, duration := 0.18) -> void:
	control.modulate.a = 0.0
	control.create_tween().tween_property(control, "modulate:a", 1.0, duration)


static func hhmm(seconds: int) -> String:
	return "%02d:%02d" % [seconds / 3600, (seconds % 3600) / 60]


static func countdown(seconds: int) -> String:
	if seconds >= 3600:
		return "%d:%02d:%02d" % [seconds / 3600, (seconds % 3600) / 60, seconds % 60]
	return "%02d:%02d" % [seconds / 60, seconds % 60]


static func flag(parent: Node, country: String, rect: Rect2) -> Control:
	var node := preload("res://scripts/ui/country_flag.gd").new()
	node.country = country
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


static func parse_duration(value: String) -> int:
	var cleaned := value.strip_edges()
	var minutes := 25
	if cleaned.contains(":"):
		var pieces := cleaned.split(":")
		if pieces.size() == 2 and pieces[0].is_valid_int() and pieces[1].is_valid_int():
			minutes = int(pieces[0]) * 60 + int(pieces[1])
	elif cleaned.is_valid_int():
		minutes = (
			int(cleaned)
			if cleaned.length() <= 2
			else int(cleaned.left(-2)) * 60 + int(cleaned.right(2))
		)
	return clampi(roundi(float(minutes) / 5.0) * 5, 5, 120) * 60
