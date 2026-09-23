extends Node3D

## Room-scoped screen-space visibility, independent of camera collision.
const XRAY_LAYER := 32
const DETECTION_INTERVAL := 0.05
const GRACE := 0.14
const FADE_IN := 0.18
const FADE_OUT := 0.26
const MAX_LAYERS := 8
const MAX_ACTIVE := 8
signal warmed
var is_warmed := false
var warming := false
var default_material := StandardMaterial3D.new()
var space: PhysicsDirectSpaceState3D
var ray_query := PhysicsRayQueryParameters3D.new()
var tracked_meshes: Array[MeshInstance3D] = []
var active_ids: Array[int] = []
var debug_countdown := 0.0
var target_cache: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var last_camera_transform := Transform3D()
var last_player_position := Vector3.INF
var last_full_detection := -1.0
var ray_total := 0
var query_rate := 0.0
var rate_clock := 0.0
var previous_ray_total := 0
var last_seen_ids: Array[int] = []
var pending_proxy_sync := false
var main
var materials := preload("res://scripts/camera/xray_material_cache.gd").new()
var records: Dictionary = {}
var active: Dictionary = {}
var indexed: Dictionary = {}
var shape_cache: Dictionary = {}
var elapsed := 0.0
var countdown := 0.0
var center_uv := Vector2(0.5, 0.5)
var radius_px := Vector2(100, 130)
var viewport_size := Vector2(1280, 720)
var rays: Array[Vector3] = []
var last_query_count := 0
var detection_usec := 0
var enabled := true
var debug_enabled := false
var debug_label: Label
var dynamic_proxies: Array[Dictionary] = []


func configure(owner_node) -> void:
	main = owner_node
	name = "PlayerOcclusionXRay"
	set_process(false)
	set_physics_process(false)
	space = get_world_3d().direct_space_state
	ray_query.collision_mask = XRAY_LAYER
	ray_query.hit_back_faces = true
	ray_query.hit_from_inside = true
	# Reuse the seat audit's exact triangle proxies when available.
	for body in main.world_root.find_children("*", "StaticBody3D", true, false):
		if not body.has_meta("camera_source_mesh"): continue
		var mesh = body.get_meta("camera_source_mesh", null)
		if is_instance_valid(mesh) and eligible(mesh):
			body.collision_layer |= XRAY_LAYER
			body.set_meta("xray_mesh", mesh)
			indexed[mesh.get_instance_id()] = true
			tracked_meshes.append(mesh)
	for mesh in main.world_root.find_children("*", "MeshInstance3D", true, false):
		if not eligible(mesh) or indexed.has(mesh.get_instance_id()): continue
		if not shape_cache.has(mesh.mesh): shape_cache[mesh.mesh] = mesh.mesh.create_trimesh_shape()
		var body := StaticBody3D.new()
		body.collision_layer = XRAY_LAYER
		body.collision_mask = 0
		body.set_meta("xray_mesh", mesh)
		var collision := CollisionShape3D.new()
		collision.shape = shape_cache[mesh.mesh]
		body.add_child(collision)
		add_child(body)
		body.global_transform = mesh.global_transform
		indexed[mesh.get_instance_id()] = true
		tracked_meshes.append(mesh)
	for npc in main.npcs:
		var body := StaticBody3D.new()
		body.collision_layer = XRAY_LAYER
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.60
		capsule.height = 2.5
		collision.shape = capsule
		body.add_child(collision)
		add_child(body)
		body.set_meta("xray_meshes", npc.find_children("*", "MeshInstance3D", true, false))
		for mesh in body.get_meta("xray_meshes"):
			if mesh.mesh != null and mesh.is_visible_in_tree(): tracked_meshes.append(mesh)
		dynamic_proxies.append({"actor": npc, "body": body})
	process_priority = 50
	for mesh in tracked_meshes: prepare(mesh)
	await preload("res://scripts/camera/xray_warmup.gd").run(self)
	if not is_inside_tree(): return
	is_warmed = true
	set_process(true)
	set_physics_process(true)
	warmed.emit()


func eligible(mesh: MeshInstance3D) -> bool:
	if mesh.mesh == null or not mesh.is_inside_tree() or not mesh.is_visible_in_tree(): return false
	var node: Node = mesh
	while node != main.world_root and node != null:
		if node == main.player or node is NPCController or node is StudySpot or node is GPUParticles3D or node is CPUParticles3D: return false
		if node.has_meta("xray_exclude") and node.get_meta("xray_exclude"): return false
		var label := str(node.name).to_lower()
		if "trainlooptile" in label or "surroundings" in label or "particle" in label or "debug" in label: return false
		node = node.get_parent()
	var substantial := false
	for i in mesh.mesh.get_surface_count():
		var material := mesh.get_active_material(i)
		if material is BaseMaterial3D:
			if material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and material.albedo_color.a < 0.5: continue
		elif material is ShaderMaterial:
			var path: String = material.shader.resource_path.to_lower() if material.shader != null else ""
			if "water" in path or "stream" in path or "fountain" in path or "leaf" in path: continue
		substantial = true
	var size := (mesh.global_transform * mesh.get_aabb()).size
	# A cup/flower is not a character occluder. Thin tall posts still qualify.
	return substantial and size.length() > 0.9 and size.y > 0.45


func target_points() -> Array[Vector3]:
	var height := 2.7
	if is_instance_valid(main.player_visual):
		var profile = main.player_visual.get_meta("character_profile", null)
		if profile != null: height = clampf(profile.label_height - 0.15, 2.0, 3.4)
	var base: Vector3 = main.player.global_position
	if is_instance_valid(main.active_study_spot): base.y += main.active_study_spot.seated_visual_offset.y - 0.2
	target_cache[0] = base + Vector3.UP * height * 0.86
	target_cache[1] = base + Vector3.UP * height * 0.64
	target_cache[2] = base + Vector3.UP * height * 0.46
	target_cache[3] = base + Vector3.UP * height * 0.30
	return target_cache


func _process(delta: float) -> void:
	if not is_instance_valid(main) or not is_instance_valid(main.player): return
	elapsed = Time.get_ticks_usec() / 1000000.0
	rate_clock += delta
	if rate_clock >= 1.0:
		query_rate = (ray_total - previous_ray_total) / rate_clock
		previous_ray_total = ray_total
		rate_clock = 0.0
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	var targets := target_points()
	var logical_size := get_viewport().get_visible_rect().size
	viewport_size = Vector2(get_viewport().size) if get_viewport() is Window or get_viewport() is SubViewport else logical_size
	var center := targets[0].lerp(targets[3], 0.46)
	if not camera.is_position_behind(center):
		center_uv = camera.unproject_position(center) / logical_size
		var scale_factor := maxf(viewport_size.y / 720.0, 0.5)
		var projected_height := camera.unproject_position(targets[0]).distance_to(camera.unproject_position(targets[3])) * viewport_size.y / logical_size.y
		radius_px = Vector2(100, 130) * scale_factor * clampf(projected_height / (170 * scale_factor), 0.85, 1.35)
	for index in range(active_ids.size() - 1, -1, -1):
		var id := active_ids[index]
		var record: Dictionary = active[id]
		if not is_instance_valid(record.mesh):
			active.erase(id)
			active_ids.remove_at(index)
			records.erase(id)
			continue
		var visible_effect: bool = enabled and elapsed - record.last_seen <= GRACE and not camera.is_position_behind(center)
		record.strength = move_toward(record.strength, 1.0 if visible_effect else 0.0, delta / (FADE_IN if visible_effect else FADE_OUT))
		record.mesh.set_instance_shader_parameter("xray_center", center_uv)
		record.mesh.set_instance_shader_parameter("xray_viewport", viewport_size)
		record.mesh.set_instance_shader_parameter("xray_radius", radius_px)
		record.mesh.set_instance_shader_parameter("xray_strength", record.strength)
		if record.strength <= 0.0 and not visible_effect:
			restore(record)
			active.erase(id)
			active_ids.remove_at(index)
	debug_countdown -= delta
	if debug_enabled and debug_countdown <= 0:
		debug_countdown = 0.25
		update_debug()


func _physics_process(delta: float) -> void:
	countdown -= delta
	if countdown > 0.0: return
	countdown = DETECTION_INTERVAL
	detect()


func detect() -> void:
	elapsed = Time.get_ticks_usec() / 1000000.0
	last_query_count = 0
	if not enabled or not is_instance_valid(main.player):
		last_full_detection = -1000.0
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	var start := Time.get_ticks_usec()
	var recheck := pending_proxy_sync
	var neighbours_moved := false
	for proxy in dynamic_proxies:
		if not is_instance_valid(proxy.actor):
			proxy.body.collision_layer = 0
			continue
		var layer: int = XRAY_LAYER if proxy.actor.is_visible_in_tree() else 0
		var position: Vector3 = proxy.actor.global_position + Vector3.UP * 1.3
		neighbours_moved = neighbours_moved or proxy.body.global_position.distance_squared_to(position) > 0.0001 or proxy.body.collision_layer != layer
		proxy.body.collision_layer = layer
		proxy.body.global_position = position
	pending_proxy_sync = neighbours_moved
	if not recheck and not neighbours_moved and elapsed - last_full_detection < 0.3 and camera.global_transform.is_equal_approx(last_camera_transform) and main.player.global_position.distance_squared_to(last_player_position) < 0.0001:
		for id in last_seen_ids:
			if active.has(id): active[id].last_seen = elapsed
		detection_usec = Time.get_ticks_usec() - start
		return
	last_camera_transform = camera.global_transform
	last_player_position = main.player.global_position
	last_full_detection = elapsed
	last_seen_ids.clear()
	rays = target_points()
	for target in rays:
		if camera.is_position_behind(target): continue
		var query := ray_query
		query.from = camera.global_position
		query.to = target
		query.exclude = []
		for _layer in MAX_LAYERS:
			last_query_count += 1
			ray_total += 1
			var hit := space.intersect_ray(query)
			if hit.is_empty(): break
			var body = hit.collider
			var excluded := query.exclude
			excluded.append(body.get_rid())
			query.exclude = excluded
			if body.has_meta("xray_mesh"):
				var mesh = body.get_meta("xray_mesh")
				if is_instance_valid(mesh) and mesh.is_visible_in_tree(): activate(mesh)
			elif body.has_meta("xray_meshes"):
				for mesh in body.get_meta("xray_meshes"):
					if is_instance_valid(mesh) and mesh.is_visible_in_tree() and not str(mesh.name).begins_with("XRay"): activate(mesh)
	detection_usec = Time.get_ticks_usec() - start


func prepare(mesh: MeshInstance3D) -> void:
	# Called only during room setup: no resource construction in detect/activate.
	var id := mesh.get_instance_id()
	if not records.has(id):
		var overrides: Array[Material] = []
		var variants: Array[ShaderMaterial] = []
		for surface in mesh.mesh.get_surface_count():
			overrides.append(mesh.get_surface_override_material(surface))
			var source := mesh.get_active_material(surface)
			if source == null: source = default_material
			var variant: ShaderMaterial = materials.variant(source)
			if variant == null: return
			variants.append(variant)
		records[id] = {"mesh": mesh, "override": mesh.material_override, "surfaces": overrides,
			"variants": variants, "strength": 0.0, "last_seen": elapsed}
		var shadow := MeshInstance3D.new()
		shadow.name = "XRayOriginalShadow"
		shadow.mesh = mesh.mesh
		shadow.layers = mesh.layers
		shadow.skin = mesh.skin
		if not mesh.skeleton.is_empty() and mesh.has_node(mesh.skeleton): shadow.skeleton = mesh.get_node(mesh.skeleton).get_path()
		shadow.material_override = mesh.material_override
		for i in overrides.size(): shadow.set_surface_override_material(i, overrides[i])
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		shadow.visible = false
		shadow.set_meta("xray_exclude", true)
		mesh.add_child(shadow)
		records[id].shadow = shadow
		records[id].original_shadow = mesh.cast_shadow


func activate(mesh: MeshInstance3D) -> void:
	var id := mesh.get_instance_id()
	if not last_seen_ids.has(id): last_seen_ids.append(id)
	if active.has(id):
		active[id].last_seen = elapsed
		return
	if active.size() >= MAX_ACTIVE or not records.has(id): return
	var record: Dictionary = records[id]
	record.last_seen = elapsed
	record.shadow.visible = record.original_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.material_override = null
	for i in record.variants.size(): mesh.set_surface_override_material(i, record.variants[i])
	active[id] = record
	active_ids.append(id)


func restore(record: Dictionary) -> void:
	if not is_instance_valid(record.mesh): return
	record.mesh.material_override = record.override
	record.mesh.cast_shadow = record.original_shadow
	if is_instance_valid(record.shadow): record.shadow.visible = false
	for i in record.surfaces.size(): record.mesh.set_surface_override_material(i, record.surfaces[i])


func _exit_tree() -> void:
	for record in active.values(): restore(record)
	for record in records.values():
		if is_instance_valid(record.shadow): record.shadow.queue_free()
	active.clear()
	active_ids.clear()
	records.clear()


func set_debug(value: bool) -> void:
	debug_enabled = value
	if debug_label == null:
		var layer := CanvasLayer.new()
		layer.layer = 110
		add_child(layer)
		debug_label = Label.new()
		debug_label.position = Vector2(20, 100)
		debug_label.add_theme_color_override("font_outline_color", Color.BLACK)
		debug_label.add_theme_constant_override("outline_size", 5)
		layer.add_child(debug_label)
	debug_label.visible = value


func update_debug() -> void:
	var names: Array[String] = []
	for record in active.values(): names.append(str(record.mesh.name))
	debug_label.text = "X-RAY · %d blockers · %.0f rays/s · %.2f ms · %d shared variants · %d prepared meshes\nUV %s · radius %s · visibility zoom OFF · lens safety %s\n%s" % [active.size(), query_rate, detection_usec / 1000.0, materials.templates.size(), records.size(), center_uv, radius_px, "ON" if main.follow_camera_rig.physical_correction else "clear", ", ".join(names).left(200)]
