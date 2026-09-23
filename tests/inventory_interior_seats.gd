extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.get_node("GameState").persistence_enabled = false
	var app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	for index in [0, 2]:
		app.build_room(index)
		await create_timer(0.3).timeout
		print("ROOM_INVENTORY ", index, " spots=", app.study_spots.size())
		for spot in app.study_spots:
			print("SPOT ", spot.seat_id, " sit=", spot.sitting_position, " stand=", spot.standing_position, " yaw=", spot.facing_yaw)
		for node in app.editable_room_layout.find_children("*", "Node3D", true, false):
			var path: String = node.scene_file_path.to_lower()
			if path.is_empty(): continue
			if not ("chair" in path or "bench" in path or "seat" in path or "sofa" in path or "stool" in path): continue
			var bounds := AABB()
			var first := true
			for mesh in node.find_children("*", "MeshInstance3D", true, false):
				var box: AABB = mesh.global_transform * mesh.get_aabb()
				bounds = box if first else bounds.merge(box)
				first = false
			print("PHYSICAL_SEAT ", app.editable_room_layout.get_path_to(node), " model=", path.get_file(), " bounds=", bounds)
	app.queue_free()
	await process_frame
	quit()
