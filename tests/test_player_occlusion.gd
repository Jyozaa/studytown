extends SceneTree

var failures := 0
var checks := 0
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute("/tmp/studytown-xray")
	RenderingServer.force_draw(false)
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("/tmp/studytown-xray/" + name + ".png")

func run() -> void:
	root.size = Vector2i(1280, 720)
	root.get_node("GameState").persistence_enabled = false
	var app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.build_room(0)
	await create_timer(0.5).timeout
	var manager = app.world_root.get_node("PlayerOcclusionXRay")
	if not manager.is_warmed:
		await manager.warmed
	app.player.set_physics_process(false)
	app.follow_camera_rig.set_physics_process(false)
	# An isolated fixture above the room tests the real ray/material pipeline.
	app.player.global_position = Vector3(0, 30, 0)
	app.follow_camera_rig.global_position = Vector3(0, 32, 10)
	app.follow_camera_rig.look_at(Vector3(0, 31.5, 0))
	app.explore_camera.make_current()
	var source := StandardMaterial3D.new()
	source.albedo_color = Color("#52744c")
	source.roughness = 0.83
	var meshes: Array[MeshInstance3D] = []
	for position in [Vector3(0, 31.5, 4), Vector3(0, 31.5, 6), Vector3(8, 31.5, 5)]:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(4, 4, 0.4)
		mesh.mesh = box
		mesh.material_override = source
		app.world_root.add_child(mesh)
		mesh.global_position = position
		meshes.append(mesh)
		var body := StaticBody3D.new()
		body.collision_layer = 33
		body.collision_mask = 0
		body.set_meta("xray_mesh", mesh)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size
		collision.shape = shape
		body.add_child(collision)
		mesh.add_child(body)
		manager.prepare(mesh)
	await create_timer(0.3).timeout
	await capture("fixture-1280")
	check(manager.active.has(meshes[0].get_instance_id()) and manager.active.has(meshes[1].get_instance_id()), "Two consecutive blockers receive the window")
	check(meshes[2].material_override == source, "Unrelated object sharing a material is untouched")
	check(source.albedo_color == Color("#52744c") and is_equal_approx(source.roughness, 0.83), "Source material remains immutable")
	var target := Vector3(0, 31.5, 0)
	var intended := Vector3(0, 32, 10)
	check(app.follow_camera_rig._resolve_obstruction(target, intended).distance_to(intended) < 0.001, "Mid-sightline geometry does not pull camera inward")
	var embedded: Vector3 = app.follow_camera_rig._resolve_obstruction(target, Vector3(0, 31.5, 4))
	check(app.follow_camera_rig.lens_is_clear(embedded), "Embedded lens resolves to a physically clear position")
	var record: Dictionary = manager.active[meshes[0].get_instance_id()]
	var variants_count: int = manager.records.size()
	manager.set_physics_process(false)
	await create_timer(0.08).timeout
	check(manager.active.has(meshes[0].get_instance_id()) and record.strength > 0.85, "Brief missed detection keeps the window alive")
	await create_timer(0.5).timeout
	check(manager.active.is_empty(), "Clear view restores all occluders after fade")
	for mesh in meshes:
		check(mesh.material_override == source and mesh.get_surface_override_material(0) == null, "Original material and surface override restored by identity")
	manager.detect()
	await create_timer(0.05).timeout
	check(manager.records.size() == variants_count, "Repeat occlusion reuses per-instance cache")
	check(record.strength > 0.0 and record.strength < 1.0, "Fade-in has intermediate strengths")
	manager.set_physics_process(true)
	root.size = Vector2i(1920, 1080)
	await create_timer(0.1).timeout
	check(manager.viewport_size == Vector2(1920, 1080), "Viewport resize updates shader dimensions")
	check(manager.radius_px.y >= 160 and manager.radius_px.y <= 270, "Mask radius scales with resolution")
	await capture("fixture-1920")
	var expected: Vector2 = app.explore_camera.unproject_position(manager.target_points()[0].lerp(manager.target_points()[3], 0.46)) / root.get_visible_rect().size
	check(manager.center_uv.distance_to(expected) < 0.001, "Window tracks projected torso centre")
	var other_camera := Camera3D.new()
	app.world_root.add_child(other_camera)
	other_camera.global_position = Vector3(2, 33, 9)
	other_camera.look_at(target)
	other_camera.make_current()
	await create_timer(0.1).timeout
	expected = other_camera.unproject_position(manager.target_points()[0].lerp(manager.target_points()[3], 0.46)) / root.get_visible_rect().size
	check(manager.center_uv.distance_to(expected) < 0.001, "Active camera switch has no stale projection")
	manager.enabled = false
	await create_timer(0.4).timeout
	check(manager.active.is_empty(), "Disable restores materials smoothly")
	app.explore_camera.make_current()
	manager.enabled = true
	root.size = Vector2i(1280, 720)
	var rig = app.follow_camera_rig
	rig.offset = Vector3(0, 0.5, 10)
	rig.look_height = 1.5
	rig.global_position = intended
	var stable := true
	var encountered := false
	# Continuous lateral movement across the blocker edge exercises the live
	# follow algorithm; the controlled fixture is independent of animation.
	for step in 100:
		app.player.global_position.x = -3.0 + step * 0.06
		rig._physics_process(1.0 / 60.0)
		stable = stable and absf(rig.global_position.z - 10.0) < 0.01
		encountered = encountered or not manager.active.is_empty()
		await physics_frame
	check(stable and encountered, "Moving past blocker edges retains intended camera depth")
	var cached_count: int = manager.records.size()
	for cycle in 12:
		manager.enabled = false
		await create_timer(0.3).timeout
		manager.enabled = true
		manager.detect()
		await create_timer(0.06).timeout
	check(manager.records.size() == cached_count, "Repeated dissolve cycles do not accumulate material records")
	# Dynamic neighbours are separate from static scene proxies.
	app.player.global_position = Vector3(0, 30, 0)
	rig.global_position = intended
	rig.look_at(target)
	var npc = app.npcs[0]
	npc.set_process(false)
	npc.set_physics_process(false)
	npc.global_position = Vector3(0, 30, 8)
	await create_timer(0.3).timeout
	var npc_active := false
	for mesh in npc.find_children("*", "MeshInstance3D", true, false):
		npc_active = npc_active or manager.active.has(mesh.get_instance_id())
	print("NPC_XRAY active=", manager.active.size(), " npc=", npc_active, " unsupported=", manager.materials.unsupported.size())
	check(npc_active, "A moving neighbour can receive a local window")
	npc.global_position.x = 12.0
	await create_timer(0.5).timeout
	var npc_restored := true
	for mesh in npc.find_children("*", "MeshInstance3D", true, false):
		npc_restored = npc_restored and not manager.active.has(mesh.get_instance_id())
	check(npc_restored, "Departing neighbour restores original materials")
	# Physical motion sweeps the lens, including a wall crossed between frames.
	rig.global_position = Vector3(0, 31.5, 8)
	rig.offset = Vector3(0, 0, 3)
	rig._physics_process(1.0)
	check(rig.global_position.z > 6.4 and rig.physical_correction, "Lens sweep cannot tunnel through a wall")
	app.build_room(2)
	await create_timer(0.3).timeout
	rig = app.follow_camera_rig
	var train_position: Vector3 = rig._resolve_obstruction(Vector3.ZERO, Vector3(20, 12, 30))
	print("TRAIN_LENS ", train_position, " bounds=", rig.horizontal_camera_bounds, " height=", rig.vertical_camera_bounds, " clear=", rig.lens_is_clear(train_position))
	check(rig.within_bounds(train_position) and train_position.y <= 12.501 and rig.lens_is_clear(train_position), "Train lens stays inside its three-dimensional carriage envelope")
	app.queue_free()
	await process_frame
	print("PLAYER_XRAY_TESTS checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
