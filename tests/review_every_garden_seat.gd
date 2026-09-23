extends SceneTree

var app
var review
var directory := "/tmp/studytown-garden-seats"
var rows: Array[Dictionary] = []
var sheet: Image
var failed := 0
var only_seat := -1
var only_variant := -1
var selected_seats: Array[int] = []
var merge_results := false
var room_index := 1


func _initialize() -> void:
	call_deferred("run")


func capture(file: String, column: int, row: int) -> void:
	if DisplayServer.get_name() == "headless": return
	await create_timer(0.12).timeout
	RenderingServer.force_draw(false)
	await process_frame
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	image.save_png(directory.path_join(file + ".png"))
	image.resize(384, 216, Image.INTERPOLATE_LANCZOS)
	image.convert(Image.FORMAT_RGBA8)
	sheet.blit_rect(image, Rect2i(0, 0, 384, 216), Vector2i(column * 384, row * 216))


func run() -> void:
	root.size = Vector2i(1280, 720)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--room="):
			room_index = {"library": 0, "garden": 1, "train": 2}.get(argument.trim_prefix("--room="), 1)
		if argument.begins_with("--seat="): only_seat = int(argument.trim_prefix("--seat="))
		if argument.begins_with("--character="): only_variant = int(argument.trim_prefix("--character="))
		if argument.begins_with("--output="): directory = argument.trim_prefix("--output=")
		if argument.begins_with("--seats="):
			for value in argument.trim_prefix("--seats=").split(","): selected_seats.append(int(value))
		if argument == "--merge": merge_results = true
	if merge_results and FileAccess.file_exists(directory.path_join("validation.json")):
		rows.assign(JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("validation.json"))))
	var state = root.get_node("GameState")
	state.persistence_enabled = false
	state.selected_character = 2
	DirAccess.make_dir_recursive_absolute(directory)
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.current_room_name = state.ROOMS[room_index]
	app.build_room(room_index)
	if room_index != 1 and not is_instance_valid(app.garden_seat_director):
		app.garden_seat_director = preload("res://scripts/study/interior_seat_director.gd").new()
		app.world_root.add_child(app.garden_seat_director)
		app.garden_seat_director.configure(app)
		app.focus_camera_director.clearance_provider = app.garden_seat_director
	review = preload("res://scripts/study/garden_seat_review.gd").new()
	app.add_child(review)
	review.configure(app)
	await create_timer(0.5).timeout
	for variant in [2, review.wide_variant]:
		if only_variant >= 0 and variant != only_variant: continue
		if is_instance_valid(app.active_study_spot):
			await app.application_flow.leave_seat()
		app.player_visual.free()
		app.player_visual = app._create_character(app.player, variant, false)
		var profile = app.player_visual.get_meta("character_profile")
		var sheet_group := -1
		for i in app.study_spots.size():
			if only_seat >= 0 and i != only_seat: continue
			if not selected_seats.is_empty() and i not in selected_seats: continue
			var sheet_file := directory.path_join("sheet-%s-%02d.png" % [profile.character_id, i / 4])
			if sheet_group != i / 4:
				sheet = Image.load_from_file(sheet_file) if merge_results and FileAccess.file_exists(sheet_file) else Image.create(1536, 864, false, Image.FORMAT_RGBA8)
				sheet_group = i / 4
			var spot = app.study_spots[i]
			var entered: bool = await review.select(i)
			var record := {"id": spot.seat_id, "label": spot.seat_label, "character": profile.character_id, "E": entered, "prompt": review.prompt_visible}
			if entered:
				record["position"] = app.player.global_position.distance_to(spot.sitting_position) < 0.025
				record["facing"] = absf(angle_difference(app.player.rotation.y, spot.facing_yaw)) < 0.01
				record["setup"] = app.garden_seat_director.visibility(app.session_setup_camera.global_position, spot)
				record["transition"] = app.focus_camera_director.last_transition_clear
				var head: Vector3 = app.garden_seat_director.points(spot)[0]
				var screen_x: float = app.session_setup_camera.unproject_position(head).x / root.size.x
				record["right_third"] = screen_x >= 0.65 and screen_x <= 0.82
				record["screen_x"] = screen_x
				await capture("%s-%s-setup" % [profile.character_id, spot.seat_id], 0, i % 4)
				app.application_flow.start_session()
				await create_timer(0.85).timeout
				review.show_shot(1)
				record["primary"] = app.garden_seat_director.visibility(app.focus_cameras[0].global_position, spot)
				await capture("%s-%s-primary" % [profile.character_id, spot.seat_id], 1, i % 4)
				app.focus_camera_director.transition(root.get_camera_3d(), app.focus_cameras[1], 0.8)
				await create_timer(0.85).timeout
				record["secondary_transition"] = app.focus_camera_director.last_transition_clear
				review.show_shot(2)
				record["secondary"] = app.garden_seat_director.visibility(app.focus_cameras[1].global_position, spot)
				await capture("%s-%s-secondary" % [profile.character_id, spot.seat_id], 2, i % 4)
				review.show_shot(3)
				await capture("%s-%s-alignment" % [profile.character_id, spot.seat_id], 3, i % 4)
				# Diagnostic camera is never part of the normal session route.
				review.show_shot(2)
				# Complete through the real timer callback, check break reservation,
				# then cancel/stand using the same exit used in ordinary play.
				root.get_node("FocusManager").end_timestamp = Time.get_unix_time_from_system() - 1.0
				await create_timer(2.6).timeout
				record["completion_retains_slot"] = spot.occupant_id == "local_player" and app.application_flow.state == app.application_flow.State.BREAK_SETUP
				record["completion_transition"] = app.focus_camera_director.last_transition_clear
				await app.application_flow.leave_seat()
				await create_timer(0.08).timeout
				record["exit"] = spot.is_available() and app.player.global_position.distance_to(spot.standing_position) < 0.15
				record["exit_camera"] = app.focus_camera_director.last_transition_clear and root.get_camera_3d() == app.explore_camera
				if not record.exit_camera:
					print("EXIT_DEBUG ", spot.seat_id, " from=", root.get_camera_3d().global_position, " to=", app.explore_camera.global_position, " lens=", app.garden_seat_director.lens_clear(app.explore_camera.global_position), " current=", root.get_camera_3d().name)
					for direction in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
						var a: Vector3 = app.explore_camera.global_position
						var hit := root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, a + direction * 2, 17))
						print("EXIT_RAY ", direction, " ", hit)
				record["camera_coordinates"] = {"setup": spot.setup_camera_override, "focus": spot.focus_camera_overrides}
			var passed := entered
			for key in record:
				if record[key] is bool: passed = passed and record[key]
				if record[key] is Dictionary and record[key].has("clear"): passed = passed and record[key].clear
			record["passed"] = passed
			if not passed:
				failed += 1
				print("CAMERA_FAILURE ", app.garden_seat_director.reports.get(spot.seat_id, {}))
			rows = rows.filter(func(row): return row.id != record.id or row.character != record.character)
			rows.append(record)
			print("GARDEN_SEAT_REVIEW ", JSON.stringify(record))
			if DisplayServer.get_name() != "headless": sheet.save_png(sheet_file)
			FileAccess.open(directory.path_join("validation.json"), FileAccess.WRITE).store_string(JSON.stringify(rows, "\t"))
	print("GARDEN_VISUAL_REVIEW_COMPLETE rows=", rows.size(), " failures=", failed)
	app.queue_free()
	await process_frame
	quit(1 if failed else 0)
