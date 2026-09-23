extends RefCounted

## Warm real meshes in the real room/viewport/light configuration. A quad in
## an isolated viewport missed driver variants in measured first-use tests.
static func run(manager: Node) -> void:
	if DisplayServer.get_name() == "headless": return
	manager.warming = true
	manager.main._set_movement_enabled(false)
	var rig = manager.main.follow_camera_rig
	var rig_processing: bool = rig.is_physics_processing()
	rig.set_physics_process(false)
	var original_camera: Camera3D = manager.get_viewport().get_camera_3d()
	var cover := CanvasLayer.new()
	cover.layer = 200
	manager.add_child(cover)
	var panel := ColorRect.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.color = Color("#171c25")
	cover.add_child(panel)
	var label := Label.new()
	label.text = "Preparing your quiet corner…"
	label.position = Vector2(40, 40)
	panel.add_child(label)
	await manager.get_tree().process_frame
	if not is_instance_valid(manager) or not manager.is_inside_tree(): return
	RenderingServer.force_draw(false)
	# One representative per shader/vertex format is enough. Warming every
	# scene instance exhausts Compatibility's finite instance-uniform buffer.
	var prepared: Array = []
	var formats := {}
	for record in manager.records.values():
		var key := ""
		for surface in record.variants.size():
			var format: String = str(record.mesh.mesh.surface_get_format(surface)) if record.mesh.mesh is ArrayMesh else record.mesh.mesh.get_class()
			key += str(record.variants[surface].shader.get_instance_id()) + ":" + format + ";"
		key += str(record.mesh.skin != null)
		if not formats.has(key):
			formats[key] = true
			prepared.append(record)
	for record in prepared:
		record.mesh.material_override = null
		record.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		record.shadow.visible = record.original_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in record.variants.size(): record.mesh.set_surface_override_material(surface, record.variants[surface])
		record.mesh.set_instance_shader_parameter("xray_strength", 0.7)
	# Pre-allocate per-instance uniform storage on every other tracked mesh.
	# The first set on a fresh instance can stall the frame; doing it here (no
	# material change, strength 0 = no visual effect) moves that cost to load.
	for record in manager.records.values():
		record.mesh.set_instance_shader_parameter("xray_strength", 0.0)
		record.mesh.set_instance_shader_parameter("xray_center", Vector2(0.5, 0.5))
		record.mesh.set_instance_shader_parameter("xray_viewport", Vector2(1280, 720))
		record.mesh.set_instance_shader_parameter("xray_radius", Vector2(100, 130))
	var camera := Camera3D.new()
	manager.add_child(camera)
	camera.fov = 80
	var bounds: Vector2 = manager.main.current_room_config.bounds
	var height := 3.2 if manager.main.current_room_config.id == "train" else 10.0
	var views: Array[Vector3] = [original_camera.global_position,
		Vector3(bounds.x * 0.7, height, bounds.y * 0.7), Vector3(-bounds.x * 0.7, height, -bounds.y * 0.7),
		Vector3(-bounds.x * 0.7, height, bounds.y * 0.7), Vector3(bounds.x * 0.7, height, -bounds.y * 0.7)]
	camera.make_current()
	for view in views:
		camera.global_position = view
		camera.look_at(Vector3(0, 1.5, 0))
		for _frame in 2:
			await manager.get_tree().process_frame
			if not is_instance_valid(manager) or not manager.is_inside_tree(): return
			# A covered macOS window may stop presenting automatically.
			RenderingServer.force_draw(false)
	for record in prepared: manager.restore(record)
	original_camera.make_current()
	camera.queue_free()
	rig.set_physics_process(rig_processing)
	cover.queue_free()
	manager.warming = false
	if manager.main.screen == manager.main.Screen.ROOM and not manager.main.session_setup_open:
		manager.main._set_movement_enabled(true)
