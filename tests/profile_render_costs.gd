extends "res://tests/profile_performance.gd"

func run() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	root.get_node("GameState").persistence_enabled = false
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	for room_index in [1, 0, 2]:
		var room_name: String = ["library", "garden", "train"][room_index]
		app.current_room_name = root.get_node("GameState").ROOMS[room_index]
		app.build_room(room_index)
		await process_frame
		var manager = app.world_root.get_node("PlayerOcclusionXRay")
		if not manager.is_warmed: await manager.warmed
		await create_timer(1.0).timeout
		app.player.set_physics_process(false)
		app.follow_camera_rig.set_physics_process(false)
		await sample(room_name, "unchanged")
		var lights: Array = []
		for light in app.world_root.find_children("*", "Light3D", true, false):
			if light.shadow_enabled and not light is DirectionalLight3D:
				lights.append(light)
				light.shadow_enabled = false
		await create_timer(0.3).timeout
		await sample(room_name, "diagnostic_no_point_shadows")
		for light in lights: light.shadow_enabled = true
		var emitters: Array = app.world_root.find_children("*", "GPUParticles3D", true, false)
		for emitter in emitters: emitter.visible = false
		await sample(room_name, "diagnostic_no_particles")
		for emitter in emitters: emitter.visible = true
		var scenery = app.editable_room_layout.get_node_or_null("Surroundings")
		if scenery:
			scenery.visible = false
			await sample(room_name, "diagnostic_no_outer_forest")
			scenery.visible = true
	var file := FileAccess.open("/tmp/studytown-render-costs.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	file.close()
	app.queue_free()
	await process_frame
	quit()
