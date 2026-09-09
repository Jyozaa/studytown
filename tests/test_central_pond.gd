extends SceneTree

var app
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", message)


func run() -> void:
	root.get_node("GameState").persistence_enabled = false
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	for index in [0, 2, 3, 1]:
		app.current_room_name = root.get_node("GameState").ROOMS[index]
		app.build_room(index)
		await create_timer(0.5).timeout
		check(app.player.is_on_floor(), "Room %d grounded spawn" % index)
		check(app.study_spots.size() > 0, "Room %d has seats" % index)
	check(app.study_spots.size() == 18, "18 Garden seats")
	check(app.npcs.size() == 6, "6 Garden students")
	check_sunset(app.editable_room_layout)
	app.player.set_physics_process(false)
	app.player.velocity = Vector3.ZERO
	var builder := preload("res://scripts/rooms/garden_builder.gd").new()
	var shore := builder.smooth_loop(PackedVector2Array(builder.SHORE), 5)
	var ring := builder.expanded(shore, 2.55)
	# Test the entire ring with the real player collision, in small increments.
	for i in ring.size():
		var a := Vector3(ring[i].x, 0.02, ring[i].y)
		var b := Vector3(ring[(i + 1) % ring.size()].x, 0.02, ring[(i + 1) % ring.size()].y)
		check(clear_motion(a, b), "Ring segment %d" % i)
	await cross_bridge(-1)
	await cross_bridge(1)
	check(
		not clear_motion(Vector3(0, 0.04, 8), Vector3(0, 0.04, 3.9)),
		"South shoreline blocks pond entry"
	)
	check(
		not clear_motion(Vector3(7, 0.13, -1), Vector3(7, 0.13, 3)),
		"Bridge rail prevents pond entry"
	)
	for spot in app.study_spots:
		check(
			clear_motion(
				spot.standing_position + Vector3.UP * 0.04,
				spot.standing_position + Vector3.UP * 0.04 + Vector3(0.02, 0, 0)
			),
			spot.seat_id + " standing anchor clear"
		)
		if not spot.is_available():
			continue
		app.session_setup_camera = app._ft_make_session_setup_camera(spot)
		check(
			app.session_setup_camera.get_meta("visibility_validated", false),
			spot.seat_id + " clear setup camera"
		)
		await process_frame
	check_reachability()
	var public_builder := preload("res://scripts/rooms/garden_builder.gd").new()
	public_builder.use_local_assets = false
	var public_room := public_builder.build()
	check(public_builder.spots.size() == 18, "Public fallback retains all seats")
	check_sunset(public_room)
	check(
		public_room.find_children("*", "MeshInstance3D", true, false).size() > 50,
		"Public fallback has visible props"
	)
	check(
		public_room.find_children("*", "NPCController", true, false).size() == 6,
		"Public fallback retains six student anchors"
	)
	public_room.free()
	print("CENTRAL_POND_TESTS checks=", checks, " failures=", failures)
	app.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)


func check_sunset(garden: Node3D) -> void:
	var environment: Environment = garden.get_node("Lighting/GardenSunset").environment
	check(environment.background_mode == Environment.BG_SKY and environment.sky != null, "Garden owns a sunset sky")
	check(environment.fog_enabled and environment.fog_depth_begin >= 40, "Fog leaves playable Garden clear")
	var sun: DirectionalLight3D = garden.get_node("Lighting/GardenWarmSun")
	check(sun.rotation_degrees.x <= -25 and sun.rotation_degrees.x >= -35, "Sun is 25–35 degrees above horizon")
	check(garden.find_children("*", "OmniLight3D", true, false).size() <= 8, "At most eight real lamps")
	var terrain: MeshInstance3D = garden.get_node("Surroundings/RollingLandscape480x400")
	check(terrain.get_aabb().size.x >= 140 and terrain.get_aabb().size.z >= 110, "Extended visual terrain")
	check(terrain.get_aabb().size.y > 10, "Outer terrain is rolling, not a flat rectangle")
	check(terrain.has_node("RollingLandscapeFloor"), "Visible terrain has structural floor")
	var count := 0
	var materials := {}
	for particle: GPUParticles3D in garden.find_children("*", "GPUParticles3D", true, false):
		count += particle.amount
		materials[particle.process_material] = true
		check(particle.get_parent() == garden.get_node("Planting"), "No distant-tree particles")
	check(count == 224, "Bounded 224-live-leaf budget")
	check(materials.size() == 2, "Two shared leaf process materials")
	for node in garden.get_node("Surroundings").get_children():
		if node is MultiMeshInstance3D:
			check(node.placements.size() == node.multimesh.instance_count, "Forest transforms survive headless bake")


func clear_motion(a: Vector3, b: Vector3) -> bool:
	var parameters := PhysicsTestMotionParameters3D.new()
	parameters.from = Transform3D(Basis.IDENTITY, a)
	parameters.motion = b - a
	parameters.margin = 0.01
	var result := PhysicsTestMotionResult3D.new()
	var hit := PhysicsServer3D.body_test_motion(app.player.get_rid(), parameters, result)
	return not hit


func cross_bridge(side: int) -> void:
	app.player.global_position = Vector3(side * 13, 0.8, -1)
	app.player.velocity = Vector3.ZERO
	for i in 470:
		await physics_frame
		app.player.velocity.x = -side * 4.0 if i > 30 else 0.0
		app.player.velocity.z = 0.0
		app.player.velocity.y = (
			-0.1 if app.player.is_on_floor() else app.player.velocity.y - 9.8 / 60.0
		)
		app.player.move_and_slide()
	print("BRIDGE_TRAVERSAL side=", side, " end=", app.player.global_position)
	check(
		app.player.global_position.x * side < -12.0, "Physical bridge traversal from side %d" % side
	)
	check(app.player.is_on_floor(), "Bridge traversal stays grounded")


func check_reachability() -> void:
	# Clearance graph supplements the explicit grounded ramp test. The probe
	# sits above both ground and bridge decks, but below pond/prop blockers.
	var start := Vector2i(0, 32)
	var visited := {start: true}
	var frontier: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < frontier.size():
		var at := frontier[cursor]
		cursor += 1
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = at + offset
			if absi(next.x) > 48 or absi(next.y) > 34 or visited.has(next):
				continue
			if clear_motion(grid_position(at), grid_position(next)):
				visited[next] = true
				frontier.append(next)
	for spot in app.study_spots:
		var connected := false
		for offset_x in [-1, 0, 1]:
			for offset_z in [-1, 0, 1]:
				var cell := Vector2i(
					roundi(spot.standing_position.x * 2) + offset_x,
					roundi(spot.standing_position.z * 2) + offset_z
				)
				if (
					visited.has(cell)
					and clear_motion(
						grid_position(cell),
						Vector3(spot.standing_position.x, 0.43, spot.standing_position.z)
					)
				):
					connected = true
		check(connected, spot.seat_id + " reachable from south entrance")
		if not connected:
			print("UNREACHABLE anchor=", spot.standing_position)
	print("REACHABILITY visited=", visited.size())


func grid_position(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * 0.5, 0.43, cell.y * 0.5)
