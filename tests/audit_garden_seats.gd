extends SceneTree

var app
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	root.get_node("GameState").persistence_enabled = false
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.current_room_name = root.get_node("GameState").ROOMS[1]
	app.build_room(1)
	await create_timer(0.5).timeout
	for npc in app.npcs:
		npc.set_process(false)
		npc.set_physics_process(false)
		npc.visible = false
	for spot in app.study_spots: spot.reset_occupancy()
	var objects := {}
	for node in app.editable_room_layout.find_children("*", "Node3D", true, false):
		if node.has_meta("physical_seat_id"):
			objects[str(node.get_meta("physical_seat_id"))] = int(node.get_meta("seat_capacity"))
	var capacity := 0
	for id in objects:
		capacity += objects[id]
		var slots: Array = app.study_spots.filter(func(spot): return spot.physical_seat_id == id)
		if slots.size() != objects[id]: failures += 1
	if objects.size() != 23 or capacity != 32: failures += 1
	print("GARDEN_FURNITURE objects=", objects.size(), " capacity=", capacity)
	app.player.set_physics_process(false)
	app.garden_seat_director.mock_neighbours = true
	for spot in app.study_spots:
		app.player.global_position = spot.standing_position
		app.player.rotation.y = spot.facing_yaw
		app._update_nearest_spot()
		var correct: bool = app.study_spots[app.nearest_spot] == spot if app.nearest_spot >= 0 else false
		var params := PhysicsTestMotionParameters3D.new()
		params.from = Transform3D(Basis.IDENTITY, spot.standing_position + Vector3.UP * 0.04)
		params.motion = Vector3(0.01, 0, 0)
		var grounded_anchor := not PhysicsServer3D.body_test_motion(app.player.get_rid(), params)
		var solved: bool = app.garden_seat_director.solve(spot, true)
		var glow = spot.get_node_or_null("AvailabilityGlow")
		var independent: bool = glow != null and spot.reserve("audit-user", StudySpot.OccupantType.PLAYER)
		await process_frame
		independent = independent and not glow.visible
		for neighbour in app.study_spots:
			if neighbour != spot and neighbour.physical_seat_id == spot.physical_seat_id:
				independent = independent and neighbour.is_available() and neighbour.get_node("AvailabilityGlow").visible
		spot.release("audit-user")
		await process_frame
		independent = independent and glow.visible
		var route := false
		if solved:
			var from: Vector3 = spot.standing_position + Vector3.UP * app.follow_camera_rig.look_height + app.follow_camera_rig.offset
			route = not app.garden_seat_director.transition_route(from, spot.to_global(spot.setup_camera_override.position)).is_empty()
		print("SEAT_AUDIT ", spot.seat_id, " prompt=", correct, " anchor=", grounded_anchor, " cameras=", solved, " transition=", route, " report=", app.garden_seat_director.reports.get(spot.seat_id, {}))
		if not correct or not grounded_anchor or not solved or not route or not independent: failures += 1
	print("GARDEN_SEAT_AUDIT seats=", app.study_spots.size(), " failures=", failures)
	app.queue_free()
	await process_frame
	quit(1 if failures else 0)
