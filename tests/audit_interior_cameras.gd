extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.get_node("GameState").persistence_enabled = false
	var app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var failed := 0
	for room_index in [0, 2]:
		app.build_room(room_index)
		var director = app.garden_seat_director
		director.mock_neighbours = true
		app.player.set_physics_process(false)
		for npc in app.npcs:
			npc.set_process(false)
			npc.set_physics_process(false)
		for spot in app.study_spots: spot.reset_occupancy()
		await create_timer(0.3).timeout
		var objects := 0
		var capacity := 0
		for item in app.editable_room_layout.find_children("*", "Node3D", true, false):
			if not item.has_meta("seat_capacity"): continue
			objects += 1
			capacity += int(item.get_meta("seat_capacity"))
			if int(item.get_meta("seat_capacity")) == 0: failed += 1
		if capacity != app.study_spots.size(): failed += 1
		if objects != (17 if room_index == 0 else 12) or capacity != (18 if room_index == 0 else 24): failed += 1
		print("INTERIOR_INVENTORY room=", room_index, " objects=", objects, " capacity=", capacity, " spots=", app.study_spots.size())
		for spot in app.study_spots:
			app.player.global_position = spot.standing_position
			var toward: Vector3 = spot.sitting_position - spot.standing_position
			app.player.rotation.y = atan2(-toward.x, -toward.z)
			app._update_nearest_spot()
			if app.nearest_spot < 0 or app.study_spots[app.nearest_spot] != spot:
				failed += 1
				print("WRONG_PROMPT ", spot.seat_id)
			var glow = spot.get_node_or_null("AvailabilityGlow")
			var independent: bool = glow != null and spot.reserve("inventory-audit", StudySpot.OccupantType.PLAYER)
			await create_timer(0.03).timeout
			independent = independent and not glow.visible
			for other in app.study_spots:
				if other == spot or other.physical_seat_id != spot.physical_seat_id: continue
				independent = independent and other.is_available() and other.get_node("AvailabilityGlow").visible
			spot.release("inventory-audit")
			await create_timer(0.03).timeout
			if not independent or not glow.visible:
				failed += 1
				print("SLOT_OCCUPANCY_FAILURE ", spot.seat_id, " independent=", independent, " visible=", glow.visible, " enabled=", glow.enabled)
			var params := PhysicsTestMotionParameters3D.new()
			params.from = Transform3D(Basis.IDENTITY, spot.standing_position + Vector3.UP * 0.04)
			params.motion = Vector3(0.01, 0, 0)
			var collision := PhysicsTestMotionResult3D.new()
			if PhysicsServer3D.body_test_motion(app.player.get_rid(), params, collision):
				failed += 1
				print("BLOCKED_STANDING ", spot.seat_id, " ", collision.get_collider().get_path())
			app.player.global_position = spot.sitting_position
			var passed: bool = director.solve(spot, true)
			if not passed: failed += 1
			if not passed and spot == app.study_spots[0]:
				var origin: Vector3 = spot.sitting_position + Basis(Vector3.UP, spot.facing_yaw) * Vector3(0, 0, -3.8) + Vector3.UP * 2.7
				print("SAMPLE ", origin, " ", director.visibility(origin, spot))
				for target in director.points(spot):
					var query := PhysicsRayQueryParameters3D.create(origin, target, 17)
					query.exclude = [app.player.get_rid()]
					var hit := root.world_3d.direct_space_state.intersect_ray(query)
					if not hit.is_empty(): print("BLOCKER ", hit.collider.get_path(), " at ", hit.position, " target ", target)
			print("INTERIOR_CAMERA ", spot.seat_id, " passed=", passed, " report=", director.reports.get(spot.seat_id, {}))
			for camera in app.room_broll_cameras:
				print("LEGACY_WIDE_AUDIT ", spot.seat_id, " shot=", camera.name, " clear=", director.visibility(camera.global_position, spot).clear)
	print("INTERIOR_CAMERA_FAILURES ", failed)
	app.queue_free()
	await process_frame
	quit(1 if failed else 0)
