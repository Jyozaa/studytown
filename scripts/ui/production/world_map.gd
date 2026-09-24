class_name WorldMap
extends Control
## Centered world-map panel over the live room: 4 vignette locations on a
## cohesive parchment sheet with dotted routes, keyboard nav, back/close.

signal travel_requested(room_index: int)
signal closed

const SPOTS := [
	{"rect": Rect2(60, 90, 300, 250), "slot": 0},
	{"rect": Rect2(400, 90, 300, 250), "slot": 1},
	{"rect": Rect2(60, 370, 300, 250), "slot": 2},
	{"rect": Rect2(400, 370, 300, 250), "slot": 3},
]

var _locations: Array = []
var _info_name: Label
var _info_blurb: Label
var _current_id := ""


static func open(parent: Control, current_location_id: String) -> WorldMap:
	var m := WorldMap.new()
	m._current_id = current_location_id
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(m)
	return m


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.16, 0.11, 0.07, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var sheet := Panel.new()
	var sh_size := Vector2(1000, 640)
	var sh_vp := get_viewport_rect().size
	if sh_vp.x < 100.0 or sh_vp.y < 100.0:
		sh_vp = Vector2(1280, 720)
	sheet.position = Vector2(maxf(8.0, (sh_vp.x - sh_size.x) * 0.5), maxf(8.0, (sh_vp.y - sh_size.y) * 0.5))
	sheet.size = sh_size
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#F1E4C4")
	sb.set_corner_radius_all(26)
	sb.set_border_width_all(3)
	sb.border_color = Color("#D9C69C")
	sb.shadow_color = Color(0.2, 0.13, 0.07, 0.4)
	sb.shadow_size = 16
	sb.shadow_offset = Vector2(0, 6)
	sheet.add_theme_stylebox_override("panel", sb)
	add_child(sheet)
	var title := Label.new()
	title.text = "StudyTown Map"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#4A3B2C"))
	title.position = Vector2(60, 18)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(title)
	var hint := Label.new()
	hint.text = "Tab / arrows + Enter · Esc closes"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color("#A08E73"))
	hint.position = Vector2(700, 30)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(hint)
	var close_btn := ProductionTheme.button(sheet, "‹ Back", Color("#FDF8EA"), Color("#4A3B2C"))
	close_btn.position = Vector2(880, 560)
	close_btn.size = Vector2(96, 44)
	close_btn.pressed.connect(func(): closed.emit())
	_info_name = Label.new()
	_info_name.add_theme_font_size_override("font_size", 19)
	_info_name.add_theme_color_override("font_color", Color("#4A3B2C"))
	_info_name.position = Vector2(740, 180)
	_info_name.size = Vector2(220, 30)
	_info_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(_info_name)
	_info_blurb = Label.new()
	_info_blurb.add_theme_font_size_override("font_size", 13)
	_info_blurb.add_theme_color_override("font_color", Color("#7A6A55"))
	_info_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_blurb.position = Vector2(740, 212)
	_info_blurb.size = Vector2(220, 120)
	_info_blurb.clip_text = true
	_info_blurb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(_info_blurb)
	_set_info(-1)
	var routes := RouteLayer.new()
	routes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	routes.position = Vector2.ZERO
	routes.size = Vector2(1000, 640)
	routes.points = [Vector2(40, 110), Vector2(720, 110), Vector2(720, 628), Vector2(40, 628), Vector2(40, 110)]
	sheet.add_child(routes)
	sheet.move_child(routes, 0)
	for i in UIAssetRegistry.LOCATIONS.size():
		var loc: Dictionary = UIAssetRegistry.LOCATIONS[i]
		var spot: Rect2 = SPOTS[i]["rect"]
		var current: bool = str(loc["id"]) == _current_id
		var ml := MapLocation.new()
		# Position relative to sheet.
		ml.setup(sheet, loc, spot.position, current)
		ml.chosen.connect(_on_chosen)
		ml.hovered.connect(_on_hovered)
		_locations.append(ml)
	if _locations.size() > 0:
		(_locations[0] as Control).grab_focus()


func configure(current_location_id: String) -> void:
	_current_id = current_location_id


class RouteLayer extends Control:
	var points: Array = []

	func _draw() -> void:
		for i in range(points.size() - 1):
			var a: Vector2 = points[i]
			var b: Vector2 = points[i + 1]
			var dist := a.distance_to(b)
			var steps := int(dist / 14.0)
			for s in steps + 1:
				var p: Vector2 = a.lerp(b, float(s) / float(maxi(steps, 1)))
				draw_circle(p, 3.0, Color(0.55, 0.45, 0.30, 0.8))


func _draw() -> void:
	pass


func _on_hovered(location_id: String) -> void:
	for i in UIAssetRegistry.LOCATIONS.size():
		if str(UIAssetRegistry.LOCATIONS[i]["id"]) == location_id:
			_set_info(i)
			return


func _set_info(slot: int) -> void:
	if slot < 0 or slot >= UIAssetRegistry.LOCATIONS.size():
		_info_name.text = "Where to?"
		_info_blurb.text = "Hover a place to preview it."
		return
	var loc: Dictionary = UIAssetRegistry.LOCATIONS[slot]
	_info_name.text = str(loc["name"])
	_info_blurb.text = str(loc["blurb"])


func _on_chosen(location_id: String) -> void:
	for loc in UIAssetRegistry.LOCATIONS:
		if str(loc["id"]) == location_id:
			if location_id == _current_id:
				closed.emit()
				return
			travel_requested.emit(int(loc["room_index"]))
			return


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			accept_event()
			closed.emit()
