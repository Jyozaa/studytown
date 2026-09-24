class_name ProductionTheme
extends RefCounted
## StudyTown production UI theme (world-first, cream/parchment identity).
## Single source of truth for colors, radii, timings, and primitives.
## Tactile buttons: hover brighten, press depresses (moves down + shrinks).

const PAPER_BG := Color("#EFE3C8")
const PAPER := Color("#F9F1DC")
const PAPER_HI := Color("#FFFDF4")
const PAPER_BORDER := Color("#D9C69C")
const PAPER_SHADOW := Color(0.25, 0.18, 0.10, 0.28)
const INK := Color("#4A3B2C")
const INK_SOFT := Color("#7A6A55")
const INK_FAINT := Color("#A08E73")
const GREEN := Color("#7A9B6E")
const GREEN_DARK := Color("#57744E")
const BLUEGREY := Color("#7E93A3")
const BLUEGREY_DARK := Color("#5E7280")
const AMBER := Color("#D9A441")
const AMBER_DARK := Color("#A87B28")
const CORAL := Color("#D96A5B")
const CORAL_DARK := Color("#A84A3E")
const SCRIM := Color(0.16, 0.11, 0.07, 0.45)

const R_CHIP := 10
const R_BUTTON := 14
const R_CARD := 18
const R_DRAWER := 22
const R_MODAL := 28

const T_HOVER := 0.12
const T_PRESS := 0.08
const T_DRAWER := 0.19
const T_MODAL := 0.17
const T_MAP_HOVER := 0.15

const F_TINY := 12
const F_CAPTION := 13
const F_BODY := 16
const F_BUTTON := 16
const F_TITLE := 19
const F_HEADING := 23
const F_MODAL_TITLE := 30
const F_HERO := 46
const F_MAJOR := 40


static func panel_style(color: Color = PAPER, radius: int = R_CARD) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(2)
	sb.border_color = PAPER_BORDER
	sb.shadow_color = PAPER_SHADOW
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	return sb


static func button_style(color: Color, edge: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(R_BUTTON)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 5
	sb.border_color = edge
	sb.shadow_color = PAPER_SHADOW
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func panel(parent: Control, rect: Rect2, color: Color = PAPER, radius: int = R_CARD) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", panel_style(color, radius))
	parent.add_child(p)
	return p


static func label(parent: Control, text: String, size: int = F_BODY, color: Color = INK, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_constant_override("line_spacing", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


static func section(parent: Control, text: String) -> Label:
	return label(parent, text.to_upper(), F_TINY, INK_FAINT)


static func _wire_tactile(btn: BaseButton) -> void:
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.mouse_entered.connect(func(): btn.modulate = Color(1.06, 1.05, 1.02))
	btn.mouse_exited.connect(func(): btn.modulate = Color.WHITE)
	btn.button_down.connect(func():
		btn.pivot_offset = btn.size * 0.5
		var tw := btn.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.set_parallel(true)
		tw.tween_property(btn, "scale", Vector2(0.965, 0.965), T_PRESS)
		tw.tween_property(btn, "position:y", btn.position.y + 2.0, T_PRESS))
	btn.button_up.connect(func():
		var tw := btn.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.set_parallel(true)
		tw.tween_property(btn, "scale", Vector2.ONE, T_PRESS + 0.03)
		tw.tween_property(btn, "position:y", btn.position.y - 2.0, T_PRESS + 0.03))


static func button(parent: Control, text: String, color: Color = PAPER_HI, text_color: Color = INK) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", F_BUTTON)
	b.add_theme_color_override("font_color", text_color)
	b.add_theme_color_override("font_hover_color", text_color)
	b.add_theme_color_override("font_pressed_color", text_color)
	b.add_theme_color_override("font_disabled_color", INK_FAINT)
	b.add_theme_stylebox_override("normal", button_style(color, color.darkened(0.28)))
	b.add_theme_stylebox_override("hover", button_style(color.lightened(0.06), color.darkened(0.28)))
	b.add_theme_stylebox_override("pressed", button_style(color.darkened(0.10), color.darkened(0.38)))
	b.add_theme_stylebox_override("disabled", button_style(Color("#E7DCC2"), Color("#CFC09E")))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	parent.add_child(b)
	_wire_tactile(b)
	return b


static func primary_button(parent: Control, text: String) -> Button:
	return button(parent, text, AMBER, Color("#3D2C12"))


static func icon_button(parent: Control, text: String, tooltip := "") -> Button:
	var b := button(parent, text, PAPER_HI, INK)
	b.custom_minimum_size = Vector2(44, 44)
	if tooltip != "":
		b.tooltip_text = tooltip
	return b


static func chip(parent: Control, text: String, selected: bool, color: Color = GREEN) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_pressed = selected
	b.add_theme_font_size_override("font_size", F_CAPTION)
	b.add_theme_color_override("font_color", Color("#FDF8EA") if selected else INK)
	var on := StyleBoxFlat.new()
	on.bg_color = color
	on.set_corner_radius_all(R_CHIP)
	on.border_width_bottom = 3
	on.border_color = color.darkened(0.3)
	on.content_margin_left = 12
	on.content_margin_right = 12
	on.content_margin_top = 6
	on.content_margin_bottom = 6
	var off := StyleBoxFlat.new()
	off.bg_color = PAPER_HI
	off.set_corner_radius_all(R_CHIP)
	off.set_border_width_all(1)
	off.border_color = PAPER_BORDER
	off.content_margin_left = 12
	off.content_margin_right = 12
	off.content_margin_top = 6
	off.content_margin_bottom = 6
	b.add_theme_stylebox_override("normal", off)
	b.add_theme_stylebox_override("hover", off)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	parent.add_child(b)
	_wire_tactile(b)
	return b


static func toggle(parent: Control, value: bool) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = value
	b.custom_minimum_size = Vector2(58, 32)
	b.add_theme_font_size_override("font_size", F_CAPTION)
	b.add_theme_color_override("font_color", Color("#FDF8EA"))
	var refresh := func():
		var on: bool = b.button_pressed
		var sb := StyleBoxFlat.new()
		sb.bg_color = GREEN if on else Color("#C9BC9E")
		sb.set_corner_radius_all(16)
		sb.set_border_width_all(2)
		sb.border_color = GREEN_DARK if on else Color("#A08E73")
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.text = "ON" if on else "OFF"
	refresh.call()
	b.toggled.connect(func(_v: bool): refresh.call())
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	parent.add_child(b)
	return b


static func slider(parent: Control, minimum: float, maximum: float, step: float, value: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = minimum
	s.max_value = maximum
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(200, 26)
	var groove := StyleBoxFlat.new()
	groove.bg_color = Color("#E2D3AE")
	groove.set_corner_radius_all(6)
	groove.content_margin_top = 10
	groove.content_margin_bottom = 10
	var grab := StyleBoxFlat.new()
	grab.bg_color = PAPER_HI
	grab.set_corner_radius_all(11)
	grab.set_border_width_all(2)
	grab.border_color = AMBER_DARK
	s.add_theme_stylebox_override("slider", groove)
	s.add_theme_stylebox_override("grabber_area", grab)
	s.add_theme_stylebox_override("grabber_area_highlight", grab)
	parent.add_child(s)
	return s


static func text_field(parent: Control, value: String, placeholder: String, secret := false) -> LineEdit:
	var f := LineEdit.new()
	f.text = value
	f.placeholder_text = placeholder
	f.secret = secret
	f.max_length = 160
	f.custom_minimum_size = Vector2(200, 42)
	f.add_theme_font_size_override("font_size", F_BODY)
	f.add_theme_color_override("font_color", INK)
	f.add_theme_color_override("font_placeholder_color", INK_FAINT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER_HI
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	sb.border_color = PAPER_BORDER
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	f.add_theme_stylebox_override("normal", sb)
	var sb2: StyleBoxFlat = sb.duplicate()
	sb2.border_color = AMBER_DARK
	f.add_theme_stylebox_override("focus", sb2)
	parent.add_child(f)
	return f


static func vp_size(node: Control) -> Vector2:
	# Viewport-relative layout: fixed 1280x720 coordinates strand panels on
	# other window sizes. Fall back to 1280x720 before layout runs.
	if node != null and node.is_inside_tree():
		var vp: Vector2 = node.get_viewport_rect().size
		if vp.x > 100.0 and vp.y > 100.0:
			return vp
	return Vector2(1280, 720)


static func drawer(parent: Control, side: int, width: float, full_height := 560.0) -> Panel:
	var d := Panel.new()
	var vp := vp_size(parent)
	var x := vp.x - width - 12.0 if side > 0 else 12.0
	d.position = Vector2(x, vp.y - full_height - 12.0)
	d.size = Vector2(width, full_height)
	d.add_theme_stylebox_override("panel", panel_style(PAPER, R_DRAWER))
	parent.add_child(d)
	d.modulate.a = 0.0
	var start_x := x + 40.0 if side > 0 else x - 40.0
	d.position.x = start_x
	var tw := d.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.set_parallel(true)
	tw.tween_property(d, "modulate:a", 1.0, T_DRAWER)
	tw.tween_property(d, "position:x", x, T_DRAWER)
	return d


static func modal(parent: Control, rect: Rect2) -> Panel:
	var dim := ColorRect.new()
	dim.color = Color(0.16, 0.11, 0.07, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(dim)
	var m := Panel.new()
	m.position = rect.position
	m.size = rect.size
	m.add_theme_stylebox_override("panel", panel_style(PAPER, R_MODAL))
	m.pivot_offset = rect.size * 0.5
	m.scale = Vector2(0.96, 0.96)
	parent.add_child(m)
	var tw := m.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "scale", Vector2.ONE, T_MODAL)
	return m


static func toast(parent: Control, text: String) -> void:
	var t := Panel.new()
	t.add_theme_stylebox_override("panel", panel_style(Color("#3E3226"), R_CARD))
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", F_CAPTION)
	l.add_theme_color_override("font_color", Color("#F9F1DC"))
	t.add_child(l)
	# Bottom-center stack.
	var count := 0
	for c in parent.get_children():
		if c.has_meta("stw_toast"):
			count += 1
	t.set_meta("stw_toast", true)
	var vpt := vp_size(parent)
	t.position = Vector2(vpt.x * 0.5 - 160, vpt.y - 96 - count * 52)
	t.size = Vector2(320, 44)
	t.modulate.a = 0.0
	parent.add_child(t)
	var tw := t.create_tween()
	tw.tween_property(t, "modulate:a", 1.0, 0.14)
	tw.tween_interval(2.2)
	tw.tween_property(t, "modulate:a", 0.0, 0.2)
	tw.tween_callback(t.queue_free)


static func keycap(parent: Control, text: String) -> Panel:
	var k := Panel.new()
	k.add_theme_stylebox_override("panel", button_style(PAPER_HI, PAPER_BORDER))
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", F_BUTTON)
	l.add_theme_color_override("font_color", INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	k.add_child(l)
	parent.add_child(k)
	return k


static func countdown(seconds: int) -> String:
	var m := int(seconds / 60)
	var s := int(seconds) % 60
	if seconds >= 3600:
		return "%d:%02d:%02d" % [int(seconds / 3600), m % 60, s]
	return "%02d:%02d" % [m, s]


static func wrap(parent: Control, text: String, rect: Rect2, size: int = F_BODY, color: Color = INK_SOFT) -> Label:
	var l := label(parent, text, size, color)
	# Autowrap BEFORE size: Control.size clamps up to the text minimum width,
	# which is only the longest-word width once wrapping is enabled.
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = rect.position
	l.size = rect.size
	return l
