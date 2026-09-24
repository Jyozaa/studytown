class_name MapLocation
extends Control
## One map destination: vignette art (project-rendered PNG, placeholder
## fallback) + hover lift/glow + click + keyboard focus. Same hit area and
## layout regardless of which texture loads.

signal chosen(location_id: String)
signal hovered(location_id: String)

const SIZE := Vector2(300, 250)

var location_id := ""
var display_name := ""
var blurb := ""
var accent := Color("#D9A441")
var is_current := false
var _tex: TextureRect
var _glow: Panel
var _base_pos := Vector2.ZERO
var _tw: Tween = null


func setup(parent: Control, loc: Dictionary, pos: Vector2, current: bool) -> void:
	location_id = str(loc["id"])
	display_name = str(loc["name"])
	blurb = str(loc["blurb"])
	is_current = current
	position = pos
	size = SIZE
	_base_pos = pos
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	parent.add_child(self)
	# Backing shadow card (also the hover halo host).
	_glow = Panel.new()
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glow_sb := StyleBoxFlat.new()
	glow_sb.bg_color = Color(0, 0, 0, 0)
	glow_sb.set_corner_radius_all(20)
	glow_sb.shadow_color = Color(1.0, 0.85, 0.45, 0.0)
	glow_sb.shadow_size = 18
	add_child(_glow)
	# Vignette art with rounded clip.
	var clip := Panel.new()
	clip.set_anchors_preset(Control.PRESET_FULL_RECT)
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var clip_sb := StyleBoxFlat.new()
	clip_sb.bg_color = Color("#2B2118")
	clip_sb.set_corner_radius_all(18)
	clip_sb.set_border_width_all(3)
	clip_sb.border_color = accent if not is_current else Color("#7A9B6E")
	clip.add_theme_stylebox_override("panel", clip_sb)
	add_child(clip)
	_tex = TextureRect.new()
	_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(_tex)
	var loaded := UIAssetRegistry.load_vignette(location_id)
	if loaded != null:
		_tex.texture = loaded
	else:
		_draw_placeholder_art()
	# Name plate.
	var plate := Panel.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate_sb := StyleBoxFlat.new()
	plate_sb.bg_color = Color(0.13, 0.10, 0.07, 0.88)
	plate_sb.set_corner_radius_all(10)
	plate_sb.content_margin_left = 12
	plate_sb.content_margin_right = 12
	plate_sb.content_margin_top = 5
	plate_sb.content_margin_bottom = 5
	plate.add_theme_stylebox_override("panel", plate_sb)
	add_child(plate)
	var name_label := Label.new()
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", Color("#F9F1DC"))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.position = Vector2(12, 0)
	name_label.size = Vector2(SIZE.x - 48, 34)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	plate.add_child(name_label)
	plate.position = Vector2(12, SIZE.y - 44)
	plate.size = Vector2(SIZE.x - 24, 34)
	if is_current:
		var pin := Label.new()
		pin.text = "▼ YOU ARE HERE"
		pin.add_theme_font_size_override("font_size", 12)
		pin.add_theme_color_override("font_color", Color("#7A9B6E"))
		pin.position = Vector2(12, -22)
		pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pin)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	focus_entered.connect(_on_hover.bind(true))
	focus_exited.connect(_on_hover.bind(false))
	gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				accept_event()
				chosen.emit(location_id)
		if event.is_action_pressed("ui_accept"):
			accept_event()
			chosen.emit(location_id))


func _draw_placeholder_art() -> void:
	# Procedural stand-in: silhouette + name + ART PENDING marker.
	var under := ColorRect.new()
	under.color = Color("#EFE3C8")
	under.set_anchors_preset(Control.PRESET_FULL_RECT)
	under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex.add_child(under)
	var mark := Label.new()
	mark.text = display_name + "\nART PENDING"
	mark.add_theme_font_size_override("font_size", 18)
	mark.add_theme_color_override("font_color", Color("#4A3B2C"))
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.set_anchors_preset(Control.PRESET_FULL_RECT)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	under.add_child(mark)


func _on_hover(active: bool) -> void:
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tw.set_parallel(true)
	var reduced: bool = bool(GameState.preferences.get("reduced_motion", false))
	if active:
		hovered.emit(location_id)
		var target_scale := 1.0 if reduced else 1.045
		_tw.tween_property(self, "scale", Vector2(target_scale, target_scale), ProductionTheme.T_MAP_HOVER)
		_tw.tween_property(self, "position", _base_pos - SIZE * (target_scale - 1.0) * 0.5, ProductionTheme.T_MAP_HOVER)
		_tw.tween_property(self, "modulate", Color(1.06, 1.05, 1.0), ProductionTheme.T_MAP_HOVER)
		var glow_sb := _glow.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		glow_sb.shadow_color = Color(1.0, 0.82, 0.4, 0.85)
		_glow.add_theme_stylebox_override("panel", glow_sb)
	else:
		_tw.tween_property(self, "scale", Vector2.ONE, ProductionTheme.T_MAP_HOVER)
		_tw.tween_property(self, "position", _base_pos, ProductionTheme.T_MAP_HOVER)
		_tw.tween_property(self, "modulate", Color.WHITE, ProductionTheme.T_MAP_HOVER)
		var glow_sb2 := _glow.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		glow_sb2.shadow_color = Color(1.0, 0.85, 0.45, 0.0)
		_glow.add_theme_stylebox_override("panel", glow_sb2)
