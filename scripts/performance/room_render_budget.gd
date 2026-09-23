extends Node

const Quality := preload("res://scripts/performance/graphics_quality.gd")
var main
var settings: Dictionary
var shadow_lights: Array[Light3D] = []
var countdown := 0.0
var tiny_shadows_removed := 0
var original_emitters := 0
var grouped_emitters := 0
var decorative_lights: Array[Light3D] = []
var light_energy := {}

func configure(owner_node) -> void:
	main = owner_node
	settings = Quality.settings()
	name = "RoomRenderBudget"
	get_viewport().mesh_lod_threshold = settings.lod
	get_viewport().positional_shadow_atlas_size = 2048 if Quality.selected() == "high" else 1024
	var layout: Node3D = main.get("editable_room_layout") if main.get("editable_room_layout") != null else main.world_root
	for mesh in layout.find_children("*", "GeometryInstance3D", true, false):
		var path := str(layout.get_path_to(mesh)).to_lower()
		var exterior := "surroundings/" in path or "trainlooptile" in path or "extendedscenery" in path
		if mesh is MeshInstance3D and mesh.mesh != null:
			if not (mesh as Node).is_inside_tree():
				continue
			var size: Vector3 = (mesh.global_transform * mesh.get_aabb()).size
			if exterior or size.length() < 0.65:
				if mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: tiny_shadows_removed += 1
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if exterior and "mountain" in path: mesh.lod_bias = 0.20
		if exterior and mesh is MultiMeshInstance3D and mesh.multimesh != null:
			# Duplicate only the instance buffer when density changes; source
			# placements/materials and every interactive foreground tree survive.
			if settings.forest_density < 1.0:
				mesh.multimesh = mesh.multimesh.duplicate()
				mesh.multimesh.visible_instance_count = maxi(1, roundi(mesh.multimesh.instance_count * settings.forest_density))
			if settings.scenery_range > 0.0:
				mesh.visibility_range_end = settings.scenery_range
				mesh.visibility_range_end_margin = 20.0
	for light in layout.find_children("*", "Light3D", true, false):
		if light is DirectionalLight3D:
			light.directional_shadow_max_distance = minf(light.directional_shadow_max_distance, settings.shadow_distance)
		elif light.shadow_enabled:
			shadow_lights.append(light)
		elif light is OmniLight3D:
			decorative_lights.append(light)
			light_energy[light] = light.light_energy
	if str(main.current_room_config.id) == "garden":
		group_leaves(layout)
		if settings.water < 1.0:
			for mesh in layout.find_children("*", "MeshInstance3D", true, false):
				if mesh.mesh == null: continue
				for surface in mesh.mesh.get_surface_count():
					var material: Material = mesh.get_active_material(surface)
					if material is ShaderMaterial and "garden_sunset_water" in material.shader.resource_path:
						var reduced: ShaderMaterial = material.duplicate()
						reduced.set_shader_parameter("water_quality", settings.water)
						mesh.material_override = reduced
	update_lights()

func _process(delta: float) -> void:
	countdown -= delta
	if countdown > 0.0: return
	countdown = 0.25
	update_lights()

func update_lights() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	shadow_lights.sort_custom(func(a, b): return a.global_position.distance_squared_to(camera.global_position) < b.global_position.distance_squared_to(camera.global_position))
	for i in shadow_lights.size():
		var light := shadow_lights[i]
		# Keep illumination and emissive props; budget only costly shadow maps.
		var selected: bool = i < int(settings.point_shadows)
		if light.shadow_enabled != selected: light.shadow_enabled = selected
	if settings.decorative_lights < decorative_lights.size():
		decorative_lights.sort_custom(func(a, b): return a.global_position.distance_squared_to(main.player.global_position) < b.global_position.distance_squared_to(main.player.global_position))
		for i in decorative_lights.size():
			var light := decorative_lights[i]
			light.light_energy = lerpf(light.light_energy, light_energy[light] if i < int(settings.decorative_lights) else 0.0, 0.6)
			light.visible = light.light_energy > 0.02

func group_leaves(layout: Node3D) -> void:
	var groups := {}
	for emitter in layout.find_children("*", "GPUParticles3D", true, false):
		if not emitter.process_material is ShaderMaterial or not "garden_leaf_motion" in emitter.process_material.shader.resource_path: continue
		var key := str(emitter.amount) + ":" + str(emitter.process_material.get_instance_id())
		if not groups.has(key): groups[key] = []
		groups[key].append(emitter)
		original_emitters += 1
	for group in groups.values():
		var original: GPUParticles3D = group[0]
		var emitter := GPUParticles3D.new()
		emitter.name = "Grouped" + str(original.name)
		emitter.amount = maxi(group.size(), roundi(original.amount * group.size() * float(settings.particles)))
		emitter.lifetime = original.lifetime
		emitter.preprocess = minf(original.lifetime, 7.0)
		emitter.fixed_fps = 30
		emitter.randomness = original.randomness
		emitter.draw_pass_1 = original.draw_pass_1
		emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material: ShaderMaterial = original.process_material.duplicate()
		var centers := PackedVector3Array()
		centers.resize(32)
		for i in mini(group.size(), 32): centers[i] = group[i].position
		material.set_shader_parameter("canopy_count", mini(group.size(), 32))
		material.set_shader_parameter("canopy_centers", centers)
		emitter.process_material = material
		emitter.visibility_aabb = AABB(Vector3(-30, -3, -24), Vector3(60, 15, 48))
		original.get_parent().add_child(emitter)
		for old in group:
			old.visible = false
			old.emitting = false
			old.queue_free()
		grouped_emitters += 1
