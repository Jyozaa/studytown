extends SceneTree

var app
var directory := "/tmp/studytown-xray"
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	RenderingServer.force_draw(false)
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(directory.path_join(name + ".png"))

func run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	root.size = Vector2i(1280, 720)
	root.get_node("GameState").persistence_enabled = false
	root.get_node("GameState").selected_character = 2
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	for room_index in [1, 0, 2]:
		app.current_room_name = root.get_node("GameState").ROOMS[room_index]
		app.build_room(room_index)
		await create_timer(0.6).timeout
		var manager = app.world_root.get_node("PlayerOcclusionXRay")
		if not manager.is_warmed: await manager.warmed
		manager.set_debug(true)
		app.player.set_physics_process(false)
		app.follow_camera_rig.set_physics_process(false)
		var cases: Array = []
		for node in app.editable_room_layout.find_children("*", "Node3D", true, false):
			var file: String = node.scene_file_path.get_file().to_lower()
			var kind := ""
			if room_index == 0 and node is MeshInstance3D and node.mesh != null:
				var size: Vector3 = (node.global_transform * node.get_aabb()).size
				if size.y > 3.2 and size.x < 0.8 and size.z < 0.8: kind = "pillar"
			if room_index == 1:
				for pattern in ["big_tree", "blossom", "gazebo", "cafe_counter", "hedge", "rock", "pergola"]:
					if pattern in file: kind = pattern
			elif room_index == 0:
				for pattern in ["bookshelf", "pillar", "antique_bureau"]:
					if pattern in file: kind = pattern
				if kind == "bookshelf" and node.name != "StackBookshelf": continue
			elif room_index == 2 and node.name == "LeftInnerLongSeat_00": kind = "seat_back"
			if kind.is_empty() or cases.any(func(item): return item.kind == kind): continue
			cases.append({"kind": kind, "node": node})
		print("XRAY_CASES room=", room_index, " ", cases.map(func(item): return item.kind))
		for item in cases:
			var offset: Vector3 = app.follow_camera_rig.offset
			var flat := Vector3(offset.x, 0, offset.z).normalized()
			var position: Vector3 = item.node.global_position - flat * 2.8
			position.y = 0.0
			if room_index == 2: position = Vector3(-3.6, 0, -16.8)
			app.player.global_position = position
			var look: Vector3 = position + Vector3.UP * app.follow_camera_rig.look_height
			app.follow_camera_rig.global_position = app.follow_camera_rig._resolve_obstruction(look, look + offset)
			app.follow_camera_rig.look_at(look)
			app.explore_camera.make_current()
			manager.enabled = false
			await create_timer(0.5).timeout
			await capture("%d-%s-before" % [room_index, item.kind])
			manager.enabled = true
			await create_timer(0.6).timeout
			await capture("%d-%s-xray" % [room_index, item.kind])
			print("XRAY_CASE ", room_index, " ", item.kind, " blockers=", manager.active.size(), " queries=", manager.last_query_count, " usec=", manager.detection_usec, " templates=", manager.materials.templates.size(), " unsupported=", manager.materials.unsupported)
			# These low props do not obstruct a standing silhouette from the
			# elevated follow camera; they must not trigger a gratuitous fade.
			if manager.active.is_empty() and item.kind not in ["rock", "hedge", "seat_back"]: failures += 1
			manager.enabled = false
			await create_timer(0.5).timeout
			for record in manager.records.values():
				if is_instance_valid(record.mesh) and record.mesh.material_override != record.override: failures += 1
			if not manager.active.is_empty(): failures += 1
			await capture("%d-%s-restored" % [room_index, item.kind])
			manager.enabled = true
	app.queue_free()
	await process_frame
	print("XRAY_REVIEW_FAILURES ", failures)
	quit(1 if failures else 0)
