extends Button

# The hit target never moves: only the face moves towards its permanent base.
var face: Panel
var caption: Label
var face_color := Color("272A32")
var motion: Tween
var depth := 0.0:
	set(value):
		depth = value
		if is_instance_valid(face):
			face.position.y = value


func configure(value: String, color: Color) -> void:
	text = value
	face_color = color
	add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	add_theme_color_override("font_color", Color.TRANSPARENT)
	add_theme_color_override("font_focus_color", Color.TRANSPARENT)
	add_theme_color_override("font_hover_color", Color.TRANSPARENT)
	add_theme_color_override("font_pressed_color", Color.TRANSPARENT)
	add_theme_color_override("font_disabled_color", Color.TRANSPARENT)
	var base := Panel.new()
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.offset_top = 5
	base.offset_bottom = 5
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.add_theme_stylebox_override("panel", _style(color.darkened(0.5)))
	add_child(base)
	face = Panel.new()
	face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_theme_stylebox_override("panel", _style(color))
	add_child(face)
	caption = Label.new()
	caption.text = value
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption.offset_left = 8
	caption.offset_right = -8
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.add_theme_font_size_override("font_size", 15)
	caption.add_theme_color_override("font_color", Color("F4F5F7"))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(caption)
	button_down.connect(func(): _move_face(3.5, 0.05))
	button_up.connect(func(): _move_face(0.0, 0.10))
	focus_entered.connect(
		func(): face.add_theme_stylebox_override("panel", _style(face_color.lightened(0.16)))
	)
	focus_exited.connect(func(): face.add_theme_stylebox_override("panel", _style(face_color)))
	mouse_entered.connect(func(): face.modulate = Color(1.12, 1.12, 1.12))
	mouse_exited.connect(
		func():
			face.modulate = Color.WHITE
			_move_face(0.0, 0.10)
	)


func _process(_delta: float) -> void:
	if is_instance_valid(caption):
		caption.text = text
		face.modulate.a = 0.45 if disabled else 1.0


func _move_face(value: float, duration: float) -> void:
	if motion != null:
		motion.kill()
	motion = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.tween_property(self, "depth", value, duration)
	face.pivot_offset = size * 0.5
	motion.parallel().tween_property(
		face, "scale", Vector2.ONE * (0.99 if value > 0.0 else 1.0), duration
	)


func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(18)
	style.border_color = color.lightened(0.1)
	style.set_border_width_all(1)
	return style
