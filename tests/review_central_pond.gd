extends SceneTree

var app
var capture_dir := "/tmp/studytown-garden-sunset"


func _initialize() -> void:
	call_deferred("run")


func capture(label: String) -> void:
	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join(label + ".png"))
	print("GARDEN_CAPTURE ", label)


func run() -> void:
	root.get_node("GameState").persistence_enabled = false
	DirAccess.make_dir_recursive_absolute(capture_dir)
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.current_room_name = root.get_node("GameState").ROOMS[1]
	app.build_room(1)
	await create_timer(0.8).timeout
	await capture("01-entrance")
	app._set_movement_enabled(false)
	var camera := Camera3D.new()
	app.world_root.add_child(camera)
	for d in [
		["02-overview", Vector3(0, 42, 28), Vector3(0, 0, -1), 54.0],
		["03-pond", Vector3(11, 9, 12), Vector3(0, 2, -1), 55.0],
		["04-gazebo", Vector3(2, 4.3, -9), Vector3(0, 2, -14), 65.0],
		["05-cafe", Vector3(-11, 7, 4), Vector3(-19, 1.3, -4), 55.0],
		["06-campfire", Vector3(12, 5, -2), Vector3(17, 1, -7), 55.0],
		["06b-gazebo-toward-pond", Vector3(0.8, 3.7, -15.8), Vector3(0, 1.2, -1), 65.0]
	]:
		camera.position = d[1]
		camera.look_at(d[2])
		camera.fov = d[3]
		camera.make_current()
		await capture(d[0])
	camera.position = Vector3(-16.8, 2.8, 9.7)
	camera.look_at(Vector3(-21, 3.2, 13.8))
	camera.fov = 52.0
	await capture("09-petals-a")
	await create_timer(1.8).timeout
	await capture("09-petals-b")
	# Exploration has one fixed elevated angle, not user orbit/zoom. Stress-test
	# broader 10/65-degree outward views as well as its actual edge positions.
	for edge in [Vector3(0, 0, -17), Vector3(0, 0, 17), Vector3(24, 0, 0), Vector3(-24, 0, 0)]:
		var direction: Vector3 = edge.normalized()
		for pitch in [10.0, 65.0]:
			camera.position = edge + Vector3.UP * 8.0
			camera.look_at(camera.position + direction * cos(deg_to_rad(pitch)) - Vector3.UP * sin(deg_to_rad(pitch)))
			camera.fov = 65.0
			camera.make_current()
			await capture("edge-%s-%s" % [str(edge), pitch])
		app.player.global_position = edge + Vector3.UP * 0.1
		app.explore_camera.make_current()
		await create_timer(1.0).timeout
		await capture("follow-edge-%s" % str(edge))
	camera.queue_free()
	for category in ["island", "gazebo", "cafe", "campfire", "lawn", "grove"]:
		for i in app.study_spots.size():
			var spot = app.study_spots[i]
			if not spot.is_available() or spot.get_meta("garden_category", "") != category:
				continue
			app.player.global_position = spot.standing_position
			app._update_nearest_spot()
			var interact := InputEventKey.new()
			interact.physical_keycode = KEY_E
			interact.pressed = true
			Input.parse_input_event(interact)
			await create_timer(2.4).timeout
			if app.application_flow.state != app.application_flow.State.SESSION_SETUP:
				printerr("GARDEN_E_FAILED ", category)
				quit(1)
				return
			print("GARDEN_E_PASSED ", category)
			await capture("07-setup-" + category)
			if category == "island":
				app.application_flow.start_session()
				await capture("08-active-focus")
				root.get_node("FocusManager").cancel_session()
			await app.application_flow.leave_seat()
			break
	app.queue_free()
	await process_frame
	quit()
