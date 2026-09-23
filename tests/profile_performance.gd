extends SceneTree

## Repeatable GPU-backed benchmark. Outputs local-only measurements, never assets.
var app
var results: Array = []
var label := "baseline"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--label="): label = arg.trim_prefix("--label=")
	call_deferred("run")

func sample(room: String, phase: String, seconds := 2.0) -> void:
	var rows: Array = []
	var begin := Time.get_ticks_usec()
	var previous := begin
	while Time.get_ticks_usec() - begin < seconds * 1000000.0:
		await process_frame
		var now := Time.get_ticks_usec()
		var xray = app.world_root.get_node_or_null("PlayerOcclusionXRay") if is_instance_valid(app.world_root) else null
		rows.append({"frame_ms": (now - previous) / 1000.0,
			"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000,
			"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000,
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
			"memory_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
			"gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),
			"render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),
			"xray_us": xray.detection_usec if xray else 0,
			"active_xray": xray.active.size() if xray else 0,
			"xray_copies": xray.materials.material_copies if xray else 0,
			"xray_shaders": xray.materials.shader_creations if xray else 0,
			"xray_creation_us": xray.materials.creation_usec if xray else 0,
			"rays": xray.last_query_count if xray else 0})
		previous = now
	var result := {"room": room, "phase": phase, "frames": rows.size(), "mean": {}, "max": {}, "p95_frame_ms": 0.0}
	for key in rows[0]:
		var total := 0.0
		var maximum := 0.0
		for row in rows:
			total += row[key]
			maximum = maxf(maximum, row[key])
		result.mean[key] = total / rows.size()
		result.max[key] = maximum
	var times: Array = rows.map(func(row): return row.frame_ms)
	times.sort()
	result.p95_frame_ms = times[int(times.size() * 0.95)]
	result["fps"] = 1000.0 / result.mean.frame_ms
	results.append(result)
	print("PERF ", JSON.stringify(result))

func inventory(room: String) -> void:
	var data := {"room": room, "phase": "inventory", "nodes": 0, "meshes": 0, "multimeshes": 0, "lights": 0, "shadow_lights": 0, "particle_emitters": 0, "particle_budget": 0, "bodies": 0, "materials": 0, "processing": 0}
	var materials := {}
	for node in app.world_root.find_children("*", "Node", true, false):
		data.nodes += 1
		if node.is_processing() or node.is_physics_processing(): data.processing += 1
		if node is Light3D and node.is_visible_in_tree():
			data.lights += 1
			if node.shadow_enabled: data.shadow_lights += 1
		if node is GPUParticles3D or node is CPUParticles3D:
			data.particle_emitters += 1
			data.particle_budget += node.amount
		if node is PhysicsBody3D: data.bodies += 1
		if node is MultiMeshInstance3D: data.multimeshes += 1
		if node is MeshInstance3D and node.mesh != null:
			data.meshes += 1
			for surface in node.mesh.get_surface_count():
				var material = node.get_active_material(surface)
				if material != null: materials[material.get_instance_id()] = true
	data.materials = materials.size()
	results.append(data)
	print("PERF_INVENTORY ", JSON.stringify(data))

func run() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	root.get_node("GameState").persistence_enabled = false
	root.get_node("GameState").selected_character = 2
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await create_timer(0.6).timeout
	await sample("menu", "idle")
	for room_index in [1, 0, 2]:
		var room_name: String = ["library", "garden", "train"][room_index]
		var start := Time.get_ticks_usec()
		app.current_room_name = root.get_node("GameState").ROOMS[room_index]
		app.build_room(room_index)
		await process_frame
		print("PERF_LOAD ", room_name, " ms=", (Time.get_ticks_usec() - start) / 1000.0)
		var room_manager = app.world_root.get_node_or_null("PlayerOcclusionXRay")
		if room_manager != null and not room_manager.is_warmed: await room_manager.warmed
		await create_timer(0.6).timeout
		inventory(room_name)
		await sample(room_name, "idle")
		Input.action_press("move_forward")
		await sample(room_name, "walking")
		Input.action_release("move_forward")
		var manager = app.world_root.get_node("PlayerOcclusionXRay")
		app.player.set_physics_process(false)
		app.follow_camera_rig.set_physics_process(false)
		var blocker: Node3D
		for node in app.editable_room_layout.find_children("*", "Node3D", true, false):
			if (room_index == 1 and "big_tree" in node.scene_file_path.get_file()) or (room_index == 0 and node.name == "StackBookshelf") or (room_index == 2 and node.name == "LeftInnerLongSeat_00"):
				blocker = node
				break
		if blocker:
			var offset: Vector3 = app.follow_camera_rig.offset
			var flat := Vector3(offset.x, 0, offset.z).normalized()
			app.player.global_position = blocker.global_position - flat * 2.8
			app.player.global_position.y = 0
			var look: Vector3 = app.player.global_position + Vector3.UP * app.follow_camera_rig.look_height
			if room_index == 2:
				# The train's tall exploration offset looks OVER the low booth
				# seats, so the sightline never intersects them. Park a low
				# camera on the far side of the booth for the occlusion phases.
				app.follow_camera_rig.global_position = blocker.global_position + flat * 2.4 + Vector3.UP * 1.0
				app.follow_camera_rig.look_at(app.player.global_position + Vector3.UP * 1.2)
			else:
				app.follow_camera_rig.global_position = app.follow_camera_rig._resolve_obstruction(look, look + offset)
				app.follow_camera_rig.look_at(look)
			manager.enabled = false
			await create_timer(0.5).timeout
			await sample(room_name, "xray_inactive")
			manager.enabled = true
			await sample(room_name, "xray_first", 1.0)
			await sample(room_name, "xray_active")
			manager.enabled = false
			await sample(room_name, "xray_fading", 1.0)
			manager.enabled = true
			await sample(room_name, "xray_repeat", 1.0)
		if room_index == 1:
			app.player.set_physics_process(true)
			app.follow_camera_rig.set_physics_process(true)
			Input.action_press("move_right")
			await sample(room_name, "dense_walking")
			Input.action_release("move_right")
	var path := "/tmp/studytown-performance-" + label + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	file.close()
	print("PERF_SAVED ", path)
	app.queue_free()
	await process_frame
	quit()
