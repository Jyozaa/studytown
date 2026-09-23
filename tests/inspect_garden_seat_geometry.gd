extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.get_node("GameState").persistence_enabled = false
	var app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.build_room(1)
	await create_timer(0.3).timeout
	for node in app.editable_room_layout.find_children("*", "Node3D", true, false):
		if not node.has_meta("physical_seat_id"): continue
		var bounds := AABB()
		var first := true
		for mesh in node.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		print("FURNITURE ", node.get_meta("physical_seat_id"), " bounds=", bounds)
	for index in [0, 4, 14]:
		var spot = app.study_spots[index]
		app.player.set_physics_process(false)
		app.player.global_transform = spot.sitting_transform
		app.character_loader.set_seated(app.player_visual, true, spot.seated_visual_offset)
		app._play_seated_character_animation(app.player_visual, "StudyBook")
		await create_timer(0.25).timeout
		for skeleton in app.player_visual.find_children("*", "Skeleton3D", true, false):
			for bone in skeleton.get_bone_count():
				var bone_name: String = skeleton.get_bone_name(bone)
				if index == 0 or "hip" in bone_name.to_lower() or "leg" in bone_name.to_lower() or "foot" in bone_name.to_lower():
					print("BONE ", index, " ", bone_name, " ", skeleton.to_global(skeleton.get_bone_global_pose(bone).origin))
		var query := PhysicsRayQueryParameters3D.create(spot.sitting_position + Vector3.UP * 2, spot.sitting_position, 16)
		print("SURFACE ", spot.seat_id, " ", app.world_root.get_world_3d().direct_space_state.intersect_ray(query))
	app.queue_free()
	await process_frame
	quit()
