extends Node
## Development / test panel. NOT production UI: plain controls, no theme.
## Rebuilt into ui_root after every room build (ui_layer is recreated).
## Every button keeps focus_mode NONE so game input always works.

var main_ref = null
var flow_ref = null
var root_box: Control = null
var tab_button: Button = null
var state_label: Label = null
var collapsed := false
var tick := 0.0
var xray_on := false
var spots_on := false
var collision_on := false


func setup(main_node) -> void:
	main_ref = main_node
	flow_ref = main_node.application_flow


func _mk_button(parent: Control, text: String, rect: Rect2, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_size_override("font_size", 14)
	if action.is_valid():
		node.pressed.connect(action)
	parent.add_child(node)
	return node


func _mk_check(parent: Control, text: String, rect: Rect2, value: bool, action: Callable) -> CheckButton:
	var node := CheckButton.new()
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.focus_mode = Control.FOCUS_NONE
	node.button_pressed = value
	node.add_theme_font_size_override("font_size", 14)
	if action.is_valid():
		node.toggled.connect(action)
	parent.add_child(node)
	return node


func _header(parent: Control, text: String, y: float) -> void:
	var node := Label.new()
	node.text = text
	node.position = Vector2(12, y)
	node.size = Vector2(280, 22)
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_size_override("font_size", 13)
	node.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	parent.add_child(node)


func refresh() -> void:
	if main_ref == null or not is_instance_valid(main_ref.ui_root):
		return
	collapsed = false
	if not is_instance_valid(tab_button):
		tab_button = Button.new()
		tab_button.text = "Debug"
		tab_button.focus_mode = Control.FOCUS_NONE
		tab_button.add_theme_font_size_override("font_size", 13)
		main_ref.ui_root.add_child(tab_button)
	tab_button.visible = false
	tab_button.position = Vector2(1280 - 76, 10)
	tab_button.size = Vector2(66, 32)
	tab_button.pressed.connect(func(): _set_collapsed(false))
	_hide_name_labels()
	_build_hint()
	_build_panel()


func _style_box() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.88)
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_color = Color(0.3, 0.31, 0.36)
	return style


func _build_hint() -> void:
	var panel := Panel.new()
	panel.position = Vector2(12, 676)
	panel.size = Vector2(300, 32)
	panel.add_theme_stylebox_override("panel", _style_box())
	main_ref.ui_root.add_child(panel)
	var label := Label.new()
	label.text = "WASD move · E interact · F wave"
	label.position = Vector2(12, 4)
	label.size = Vector2(276, 24)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)


func _build_panel() -> void:
	root_box = Panel.new()
	root_box.position = Vector2(1280 - 316, 52)
	root_box.size = Vector2(306, 640)
	root_box.add_theme_stylebox_override("panel", _style_box())
	main_ref.ui_root.add_child(root_box)
	var y := 8.0
	_mk_button(root_box, "< collapse", Rect2(12, y, 120, 30), func(): _set_collapsed(true))
	y += 38.0
	state_label = Label.new()
	state_label.position = Vector2(12, y)
	state_label.size = Vector2(282, 96)
	state_label.focus_mode = Control.FOCUS_NONE
	state_label.add_theme_font_size_override("font_size", 13)
	state_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_box.add_child(state_label)
	y += 102.0
	_header(root_box, "ROOM", y)
	y += 24.0
	var rooms: Array = ["Library", "Café", "Train"]
	for i in 3:
		_mk_button(root_box, rooms[i], Rect2(12 + i * 96, y, 90, 32), _switch_room.bind(i))
	y += 40.0
	_header(root_box, "SEATING", y)
	y += 24.0
	_mk_check(
		root_box, "Seat availability view", Rect2(12, y, 282, 28),
		bool(GameState.preferences.get("seat_availability_view", true)),
		func(on: bool):
			GameState.preferences["seat_availability_view"] = on
			GameState.save()
	)
	y += 32.0
	_mk_button(root_box, "Refresh highlights", Rect2(12, y, 138, 30), _refresh_glows)
	_mk_button(root_box, "Stand up", Rect2(156, y, 138, 30), _stand)
	y += 36.0
	_mk_button(root_box, "Sit nearest seat", Rect2(12, y, 282, 30), _sit_nearest)
	y += 38.0
	_header(root_box, "FOCUS", y)
	y += 24.0
	_mk_button(root_box, "Start 5m", Rect2(12, y, 90, 30), _start_focus.bind(5))
	_mk_button(root_box, "Start 25m", Rect2(108, y, 90, 30), _start_focus.bind(25))
	_mk_button(root_box, "Complete", Rect2(204, y, 90, 30), _complete_focus)
	y += 36.0
	_mk_button(root_box, "Cancel / end early", Rect2(12, y, 282, 30), _cancel_focus)
	y += 38.0
	_header(root_box, "DEBUG", y)
	y += 24.0
	_mk_check(root_box, "StudySpot anchors", Rect2(12, y, 282, 28), spots_on, _toggle_spots)
	y += 32.0
	_mk_check(root_box, "Collision shapes", Rect2(12, y, 282, 28), collision_on, _toggle_collision)
	y += 32.0
	_mk_check(root_box, "X-ray debug", Rect2(12, y, 282, 28), xray_on, _toggle_xray)
	y += 40.0
	_header(root_box, "AUDIO", y)
	y += 24.0
	_mk_button(root_box, "Music on/off", Rect2(12, y, 138, 30), _toggle_music)
	_mk_button(root_box, "Mute", Rect2(156, y, 138, 30), _toggle_mute)


func _set_collapsed(value: bool) -> void:
	collapsed = value
	if is_instance_valid(root_box):
		root_box.visible = not collapsed
	if is_instance_valid(tab_button):
		tab_button.visible = collapsed


func _hide_name_labels() -> void:
	if not is_instance_valid(main_ref.world_root):
		return
	for label in main_ref.world_root.find_children("*", "Label3D", true, false):
		var parent: Node = (label as Node).get_parent()
		if parent == null:
			continue
		if parent == main_ref.player or str(parent.name).begins_with("NPC_"):
			(label as Node3D).visible = false


func _switch_room(index: int) -> void:
	if flow_ref.transitioning or flow_ref.joining:
		print("[StudyTown] room switch busy")
		return
	await _stand()
	main_ref._enter_room(index)
	refresh()


func _stand() -> void:
	if is_instance_valid(main_ref.active_study_spot):
		await flow_ref.leave_seat()


func _sit_nearest() -> void:
	main_ref._update_nearest_spot()
	if main_ref.nearest_spot >= 0:
		await flow_ref.take_seat(main_ref.nearest_spot)
	else:
		print("[StudyTown] no available seat in reach")


func _refresh_glows() -> void:
	var driver = main_ref.world_root.get_node_or_null("SeatHighlightDriver")
	if driver != null:
		(driver.get("applied") as Dictionary).clear()
	print("[StudyTown] highlight cache cleared")


func _start_focus(minutes: int) -> void:
	if FocusManager.active:
		print("[StudyTown] focus already active")
		return
	if not is_instance_valid(main_ref.active_study_spot):
		print("[StudyTown] sit first (walk to a glowing seat, press E)")
		return
	flow_ref.duration = minutes * 60
	flow_ref.debug_short = false
	flow_ref.start_session()
	print("[StudyTown] focus started: %dm" % minutes)


func _complete_focus() -> void:
	if not FocusManager.active:
		print("[StudyTown] no active focus session")
		return
	FocusManager.end_timestamp = Time.get_unix_time_from_system() - 1.0
	print("[StudyTown] completing (reward on tick)")


func _cancel_focus() -> void:
	if not FocusManager.active:
		print("[StudyTown] no active focus session")
		return
	await flow_ref.end_early()
	print("[StudyTown] session ended early")


func _toggle_spots(on: bool) -> void:
	spots_on = on
	main_ref._set_debug_spots(on)


func _toggle_collision(on: bool) -> void:
	collision_on = on
	main_ref._set_collision_debug(on)


func _toggle_xray(on: bool) -> void:
	xray_on = on
	var manager = main_ref.world_root.get_node_or_null("PlayerOcclusionXRay")
	if manager != null and manager.has_method("set_debug"):
		manager.call("set_debug", on)
	else:
		print("[StudyTown] x-ray manager not present")


func _toggle_music() -> void:
	if flow_ref.radio != null and flow_ref.radio.has_method("toggle_playback"):
		flow_ref.radio.toggle_playback()
		print("[StudyTown] music toggled")
	else:
		print("[StudyTown] music backend not present")


func _toggle_mute() -> void:
	if flow_ref.radio != null:
		flow_ref.radio.muted = not bool(flow_ref.radio.get("muted"))
		flow_ref.radio._update_mix()
		print("[StudyTown] muted=", flow_ref.radio.muted)


func _process(_delta: float) -> void:
	tick += _delta
	if tick < 0.25 or not is_instance_valid(state_label):
		return
	tick = 0.0
	if main_ref == null:
		return
	var seated := is_instance_valid(main_ref.active_study_spot)
	var focus_text := "Focus active: false"
	if FocusManager.active:
		focus_text = "Focus active: true (%ds left)" % FocusManager.get_remaining_seconds()
	var nearest := "none"
	if main_ref.get("nearest_spot") != null and int(main_ref.get("nearest_spot")) >= 0:
		var spot = main_ref.study_spots[int(main_ref.get("nearest_spot"))]
		nearest = str(spot.seat_id)
	state_label.text = "Room: %s\nSeated: %s\nSeat availability: %s\n%s\nNearest: %s" % [
		str(main_ref.current_room_name),
		str(seated),
		str(bool(GameState.preferences.get("seat_availability_view", true))),
		focus_text,
		nearest,
	]
