class_name StudyTheme
extends RefCounted
## StudyTownTheme — ONE source of truth for StudyTown UI.
## Dark tactile language (lofi.town-inspired rhythm, StudyTown identity):
## soft rounded dark panels, chunky buttons with press-down depth, chips,
## drawers, modals, sliders, toggles, HUD pills, keycaps. No caller hand-styles
## colors/radii/durations outside this file.

const BG := Color("#101114")
const PANEL := Color("#1B1D23")
const PANEL_2 := Color("#23262E")
const NESTED := Color("#262A33")
const BORDER := Color("#353945")
const EDGE := Color("#0A0B0D")
const TEXT := Color("#F2EFE6")
const MUTED := Color("#A7A9B5")
const FAINT := Color("#6E7180")
const ACCENT := Color("#E8A33D")
const ACCENT_DARK := Color("#B97A22")
const PURPLE := Color("#8A63C7")
const GREEN := Color("#75CA72")
const GREEN_DARK := Color("#4E7A48")
const BLUE := Color("#4F8DF7")
const RED := Color("#D7675B")
const ORANGE := Color("#F2A02A")
const SCRIM := Color(0.0, 0.0, 0.0, 0.62)

const R_CHIP := 11
const R_BUTTON := 15
const R_CARD := 18
const R_DRAWER := 22
const R_MODAL := 26

const T_HOVER := 0.09
const T_PRESS := 0.07
const T_RELEASE := 0.11
const T_DRAWER := 0.20
const T_MODAL := 0.22
const T_BAR := 0.16


static func style(color: Color = PANEL, radius: int = R_CARD, border: Color = BORDER, shadow := true) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.set_corner_radius_all(radius)
	result.set_border_width_all(1)
	result.border_color = border
	if shadow:
		result.shadow_color = Color(0, 0, 0, 0.45)
		result.shadow_size = 10
		result.shadow_offset = Vector2(0, 5)
	return result


static func tactile(color: Color, edge: Color, depth := 4) -> StyleBoxFlat:
	var result := style(color, R_BUTTON, edge)
	result.border_width_bottom = depth
	return result


static func _apply_button(node: Button, color: Color, edge: Color, font_size: int, text_color: Color) -> void:
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", text_color)
	node.add_theme_color_override("font_hover_color", text_color)
	node.add_theme_color_override("font_pressed_color", text_color)
	node.add_theme_color_override("font_disabled_color", FAINT)
	node.add_theme_stylebox_override("normal", tactile(color, edge, 4))
	node.add_theme_stylebox_override("hover", tactile(color.lightened(0.08), edge, 4))
	node.add_theme_stylebox_override("pressed", tactile(color.darkened(0.12), edge.darkened(0.1), 1))
	node.add_theme_stylebox_override("disabled", style(Color("#23262E"), R_BUTTON, BORDER, false))
	node.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


static func panel(parent: Node, rect: Rect2, color: Color = PANEL, radius: int = R_CARD) -> Panel:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.add_theme_stylebox_override("panel", style(color, radius))
	parent.add_child(node)
	return node


static func label(parent: Node, text: String, rect: Rect2, font_size := 16, color: Color = TEXT) -> Label:
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


static func wrap(parent: Node, text: String, rect: Rect2, font_size := 14, color: Color = MUTED) -> Label:
	var node := label(parent, text, rect, font_size, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return node


static func section(parent: Node, text: String, rect: Rect2) -> void:
	label(parent, text.to_upper(), rect, 12, FAINT)


static func button(parent: Node, text: String, rect: Rect2, action: Callable, color: Color = PANEL_2) -> Button:
	var node := Button.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	_apply_button(node, color, EDGE, 16, TEXT)
	if action.is_valid():
		node.pressed.connect(action)
	parent.add_child(node)
	return node


static func primary_button(parent: Node, text: String, rect: Rect2, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	_apply_button(node, ACCENT, ACCENT_DARK, 17, Color("#241A08"))
	node.add_theme_color_override("font_hover_color", Color("#241A08"))
	node.add_theme_color_override("font_pressed_color", Color("#241A08"))
	if action.is_valid():
		node.pressed.connect(action)
	parent.add_child(node)
	return node


static func danger_button(parent: Node, text: String, rect: Rect2, action: Callable) -> Button:
	var node := button(parent, text, rect, action, Color("#4A2320"))
	return node


static func icon_button(parent: Node, text: String, rect: Rect2, action: Callable, color: Color = PANEL_2, tooltip := "") -> Button:
	var node := button(parent, text, rect, action, color)
	var s := maxi(44, int(minf(rect.size.x, rect.size.y)))
	node.custom_minimum_size = Vector2(s, s)
	if not tooltip.is_empty():
		node.tooltip_text = tooltip
	return node


static func chip(parent: Node, text: String, rect: Rect2, selected := false, color: Color = PURPLE) -> Button:
	var node := Button.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.toggle_mode = true
	node.button_pressed = selected
	node.add_theme_font_size_override("font_size", 14)
	node.add_theme_color_override("font_color", Color("#141114") if selected else TEXT)
	var on := style(color, R_CHIP, color.darkened(0.25))
	var off := style(NESTED, R_CHIP, BORDER)
	node.add_theme_stylebox_override("normal", off)
	node.add_theme_stylebox_override("hover", style(NESTED.lightened(0.06), R_CHIP, BORDER))
	node.add_theme_stylebox_override("pressed", on)
	node.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	parent.add_child(node)
	return node


static func hud_pill(parent: Node, rect: Rect2) -> Panel:
	var node := panel(parent, rect, Color(0.09, 0.10, 0.13, 0.94), R_CARD)
	return node


static func keycap(parent: Node, text: String, rect: Rect2) -> Panel:
	var node := panel(parent, rect, Color("#2A2E38"), 8)
	node.add_theme_stylebox_override("panel", tactile(Color("#2A2E38"), EDGE, 3))
	label(node, text, Rect2(0, 0, rect.size.x, rect.size.y), 16, TEXT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return node


static func drawer(parent: Node, side := 1, width := 372.0) -> Panel:
	# side: +1 right edge, -1 left edge. Slides in on creation.
	var x_target := 1280.0 - width - 14.0 if side > 0 else 14.0
	var node := panel(parent, Rect2(x_target, 84.0, width, 552.0), PANEL, R_DRAWER)
	node.position.x = 1296.0 if side > 0 else -width - 16.0
	var slide := node.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slide.tween_property(node, "position:x", x_target, T_DRAWER)
	return node


static func modal(parent: Node, rect: Rect2, dim := true) -> Panel:
	if dim:
		var scrim := ColorRect.new()
		scrim.color = SCRIM
		scrim.size = Vector2(1280, 720)
		scrim.mouse_filter = Control.MOUSE_FILTER_STOP
		parent.add_child(scrim)
	var node := panel(parent, rect, PANEL, R_MODAL)
	node.scale = Vector2(0.96, 0.96)
	node.pivot_offset = rect.size * 0.5
	var pop := node.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pop.tween_property(node, "scale", Vector2.ONE, T_MODAL)
	return node


static func text_field(parent: Node, value: String, placeholder: String, rect: Rect2, secret := false) -> LineEdit:
	var node := LineEdit.new()
	node.position = rect.position
	node.size = rect.size
	node.text = value
	node.placeholder_text = placeholder
	node.secret = secret
	node.max_length = 120
	node.add_theme_font_size_override("font_size", 17)
	node.add_theme_color_override("font_color", TEXT)
	node.add_theme_color_override("font_placeholder_color", FAINT)
	var normal := style(NESTED, 12, BORDER)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	var focus := style(NESTED, 12, ACCENT)
	focus.content_margin_left = 14
	focus.content_margin_right = 14
	node.add_theme_stylebox_override("normal", normal)
	node.add_theme_stylebox_override("focus", focus)
	node.add_theme_stylebox_override("read_only", normal)
	parent.add_child(node)
	return node


static func toggle(parent: Node, rect: Rect2, value: bool, changed: Callable) -> Button:
	var node := Button.new()
	node.toggle_mode = true
	node.button_pressed = value
	node.position = rect.position
	node.size = Vector2(maxf(rect.size.x, 66.0), maxf(rect.size.y, 38.0))
	node.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var refresh := func():
		var on: bool = node.button_pressed
		var track := tactile(GREEN if on else Color("#3A3E48"), EDGE if on else EDGE, 3)
		node.add_theme_stylebox_override("normal", track)
		node.add_theme_stylebox_override("hover", track)
		node.add_theme_stylebox_override("pressed", track)
		node.text = "  ON" if on else "OFF  "
		node.alignment = HORIZONTAL_ALIGNMENT_CENTER
		node.add_theme_font_size_override("font_size", 14)
		node.add_theme_color_override("font_color", Color("#0E1A0E") if on else TEXT)
	refresh.call()
	node.toggled.connect(func(_v: bool): refresh.call())
	if changed.is_valid():
		node.toggled.connect(changed)
	parent.add_child(node)
	return node


static func slider(parent: Node, rect: Rect2, minimum: float, maximum: float, step: float, value: float, changed: Callable, color: Color = ACCENT) -> HSlider:
	var node := HSlider.new()
	node.position = rect.position
	node.size = rect.size
	node.min_value = minimum
	node.max_value = maximum
	node.step = step
	node.value = value
	node.add_theme_stylebox_override("slider", style(Color("#3A3E48"), 3, Color("#3A3E48")))
	node.add_theme_stylebox_override("grabber_area", style(color, 4, color.darkened(0.25)))
	node.add_theme_stylebox_override("grabber_area_highlight", style(color.lightened(0.12), 4, color.darkened(0.25)))
	if changed.is_valid():
		node.value_changed.connect(changed)
	parent.add_child(node)
	return node


static func toast(parent: Node, message: String) -> void:
	var card := panel(parent, Rect2(440, 40, 400, 52), PANEL_2, R_CARD)
	label(card, message, Rect2(18, 6, 364, 40), 14, TEXT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.modulate.a = 0.0
	var tw := card.create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.14)
	tw.tween_interval(2.6)
	tw.tween_property(card, "modulate:a", 0.0, 0.2)
	tw.tween_callback(card.queue_free)


static func fade(control: Control, duration := 0.18) -> void:
	control.modulate.a = 0.0
	control.create_tween().tween_property(control, "modulate:a", 1.0, duration)


static func countdown(seconds: int) -> String:
	if seconds >= 3600:
		return "%d:%02d:%02d" % [seconds / 3600, (seconds % 3600) / 60, seconds % 60]
	return "%02d:%02d" % [seconds / 60, seconds % 60]


static func hhmm(seconds: int) -> String:
	return "%02d:%02d" % [seconds / 3600, (seconds % 3600) / 60]


static func input(parent: Node, value: String, placeholder: String, rect: Rect2) -> LineEdit:
	return text_field(parent, value, placeholder, rect, false)


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
