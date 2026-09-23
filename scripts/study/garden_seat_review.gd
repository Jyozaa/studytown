extends CanvasLayer

var main
var index := 0
var shot_index := 0
var busy := false
var label: Label
var mocks: Array[Node3D] = []
var wide_variant := 0
var neighbour_mode := true
var diagnostic_camera: Camera3D
var prompt_visible := false


func configure(owner_node) -> void:
	main = owner_node
	layer = 100
	for i in main.character_loader.profiles.size():
		if main.character_loader.profiles[i].character_id == "bangle": wide_variant = i
	for npc in main.npcs:
		npc.visible = false
		npc.set_process(false)
		npc.set_physics_process(false)
	for spot in main.study_spots: spot.reset_occupancy()
	label = Label.new()
	label.position = Vector2(20, 78)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or busy: return
	match event.physical_keycode:
		KEY_RIGHT: select(index + 1)
		KEY_LEFT: select(index - 1)
		KEY_1: show_shot(0)
		KEY_2: show_shot(1)
		KEY_3: show_shot(2)
		KEY_4: show_shot(3)
		KEY_N:
			neighbour_mode = not neighbour_mode
			select(index)
		KEY_C:
			var current = main.player_visual.get_meta("character_profile", null)
			var variant := 2 if current != null and current.character_id == "bangle" else wide_variant
			main.player_visual.free()
			main.player_visual = main._create_character(main.player, variant, false)
			select(index)
		KEY_R:
			main.garden_seat_director.solve(main.study_spots[index], true)
			select(index)
		_: return
	get_viewport().set_input_as_handled()


func populate_neighbours(spot) -> void:
	for mock in mocks: mock.queue_free()
	mocks.clear()
	for other in main.study_spots: other.reset_occupancy()
	main.garden_seat_director.mock_neighbours = neighbour_mode
	if not neighbour_mode: return
	for other in main.study_spots:
		if other == spot or other.sitting_position.distance_to(spot.sitting_position) > 4.0: continue
		var holder := Node3D.new()
		main.world_root.add_child(holder)
		holder.position = other.sitting_position
		holder.rotation.y = other.facing_yaw
		var visual: Node3D = main._create_character(holder, wide_variant, true)
		main.character_loader.set_seated(visual, true, other.seated_visual_offset)
		main._play_seated_character_animation(visual, "StudyBook")
		other.reserve("review-neighbour-" + other.seat_id, StudySpot.OccupantType.NPC)
		mocks.append(holder)


func select(next_index: int) -> bool:
	if busy: return false
	busy = true
	if is_instance_valid(main.active_study_spot):
		var focus = get_tree().root.get_node("FocusManager")
		if focus.active: focus.cancel_session()
		await main.application_flow.leave_seat()
	index = posmod(next_index, main.study_spots.size())
	var spot = main.study_spots[index]
	populate_neighbours(spot)
	main.player.global_position = spot.standing_position
	main.player.rotation.y = spot.facing_yaw
	if str(main.current_room_config.id) != "garden":
		var toward: Vector3 = spot.sitting_position - spot.standing_position
		main.player.rotation.y = atan2(-toward.x, -toward.z)
	main.player.velocity = Vector3.ZERO
	main.explore_camera.make_current()
	await get_tree().create_timer(0.25).timeout
	main._update_nearest_spot()
	prompt_visible = main.prompt_label.visible and main.prompt_label.text == "E  TAKE SEAT" and main.nearest_spot == index
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventKey.new()
	event.physical_keycode = KEY_E
	Input.parse_input_event(event)
	await get_tree().create_timer(2.15).timeout
	var passed: bool = main.application_flow.state == main.application_flow.State.SESSION_SETUP and main.active_study_spot == spot
	if passed:
		main._prepare_focus_camera_pool(spot, false)
		show_shot(0)
	else:
		label.text = "FAILED E / transition: " + spot.seat_id
	busy = false
	return passed


func show_shot(which: int) -> void:
	shot_index = which
	# Alignment is an isolated diagnostic view; the three accepted session
	# views above it are always reviewed with occupied neighbours visible.
	for mock in mocks: mock.visible = which != 3
	var spot = main.study_spots[index]
	var camera: Camera3D = main.session_setup_camera
	if which in [1, 2] and main.focus_cameras.size() >= which:
		camera = main.focus_cameras[which - 1]
	if which == 3:
		if is_instance_valid(diagnostic_camera): diagnostic_camera.queue_free()
		diagnostic_camera = main.garden_seat_director.alignment_camera(spot)
		camera = diagnostic_camera
	if not is_instance_valid(camera): return
	camera.make_current()
	var status: Dictionary = main.garden_seat_director.visibility(camera.global_position, spot)
	var prefix: String = {"garden": "G", "library": "L", "train": "T"}.get(str(main.current_room_config.id), "S")
	label.text = "%s%02d/%02d %s\n%s | Head %s · Chest %s · Torso %s · Lens %s · Neighbours %s\n←/→ seat · 1 setup · 2 primary · 3 secondary · 4 alignment · N neighbours · C size · R solve" % [
		prefix, index + 1, main.study_spots.size(), spot.seat_label, ["SETUP", "PRIMARY", "SECONDARY", "ALIGNMENT"][which],
		status.head, status.chest, status.torso, status.lens, status.neighbours]
