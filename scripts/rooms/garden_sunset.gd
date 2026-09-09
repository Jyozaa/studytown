extends RefCounted

## Garden-only scenery. Baked nodes, shared meshes/materials, no per-frame scripts.
var builder
var rng := RandomNumberGenerator.new()


func build(source) -> void:
	builder = source
	rng.seed = 283048
	landscape()
	forest()
	leaves()
	builder.room.set_meta("sunset_environment_version", 1)


func height_at(p: Vector2) -> float:
	var distance_out := maxf(absf(p.x) - 27.0, absf(p.y) - 20.0)
	var rise := smoothstep(0.0, 38.0, distance_out)
	var hills := 3.5 + 2.0 * sin(p.x * 0.049 + p.y * 0.032) + 1.5 * cos(p.y * 0.077)
	var mountains := smoothstep(65.0, 125.0, distance_out) * (
		12.0 + 7.0 * sin(p.x * 0.029) * cos(p.y * 0.035) + 5.0 * sin(p.y * 0.061)
	)
	return -0.024 + rise * hills + mountains


func landscape() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# A rounded 480 x 400 landscape; the entire edge is beyond full depth haze.
	for ring in 48:
		for segment in 160:
			var points: Array[Vector3] = []
			for corner in [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)]:
				var radius := float(ring + corner.x) / 48.0
				var angle := TAU * float(segment + corner.y) / 160.0
				var p := Vector2(cos(angle) * (30.0 + radius * 210.0), sin(angle) * (23.0 + radius * 177.0))
				points.append(Vector3(p.x, height_at(p), p.y))
			for i in [0, 2, 1, 0, 3, 2]:
				surface.set_uv(Vector2(points[i].x, points[i].z) * 0.085)
				surface.add_vertex(points[i])
	surface.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.name = "RollingLandscape480x400"
	terrain.mesh = surface.commit()
	terrain.material_override = builder.materials.grass
	builder.zones.Surroundings.add_child(terrain)
	# Structural counterpart for the visible ground, outside gameplay bounds.
	var body := StaticBody3D.new()
	body.name = "RollingLandscapeFloor"
	body.collision_layer = 1
	body.collision_mask = 2
	var shape := CollisionShape3D.new()
	shape.shape = terrain.mesh.create_trimesh_shape()
	body.add_child(shape)
	terrain.add_child(body)


func forest() -> void:
	# Near belt: varied clusters with deliberate gaps, not rectangular rows.
	for cluster in 22:
		var angle := TAU * float(cluster) / 22.0 + rng.randf_range(-0.09, 0.09)
		var center := Vector2(cos(angle) * rng.randf_range(34, 43), sin(angle) * rng.randf_range(28, 36))
		for i in rng.randi_range(2, 4):
			var p := center + Vector2(rng.randf_range(-4, 4), rng.randf_range(-4, 4))
			builder.tree(Vector3(p.x, height_at(p), p.y), rng.randf_range(1.05, 1.65), "Surroundings")
		var shrub := center * 0.85
		builder.prop("Surroundings", "garden_shrub", Vector3(shrub.x, height_at(shrub), shrub.y), angle, Vector3.ONE * 1.1)
		if cluster % 3 == 0:
			builder.prop("Surroundings", "garden_rock_a", Vector3(center.x, height_at(center), center.y), angle, Vector3.ONE * 1.7)
	# The middle forest keeps the existing oak silhouette, batched by mesh.
	var middle: Array[Transform3D] = []
	for i in 380:
		var angle := rng.randf_range(0, TAU)
		var radius := rng.randf_range(42, 102)
		var p := Vector2(cos(angle) * radius * 1.15, sin(angle) * radius)
		var size := rng.randf_range(1.0, 1.65)
		middle.append(Transform3D(Basis(Vector3.UP, angle).scaled(Vector3.ONE * size), Vector3(p.x, height_at(p), p.y)))
	var sample: Node3D = builder.prop("Surroundings", "garden_oak_tree", Vector3.ZERO)
	for child in sample.find_children("*", "MeshInstance3D", true, false):
		var local: Transform3D = child.transform
		var parent: Node = child.get_parent()
		while parent != sample:
			local = parent.transform * local
			parent = parent.get_parent()
		var placements: Array[Transform3D] = []
		for transform in middle:
			placements.append(transform * sample.transform * local)
		instances("MiddleForest_" + str(child.name), child.mesh, placements, child.material_override)
	sample.free()
	# Only the final hazy ridge uses simplified clustered crowns.
	var crowns := silhouette_crown()
	var trunks := CylinderMesh.new()
	trunks.radial_segments = 5
	trunks.top_radius = 0.10
	trunks.bottom_radius = 0.19
	trunks.height = 1.0
	var crown_transforms: Array[Transform3D] = []
	var trunk_transforms: Array[Transform3D] = []
	for i in 900:
		var angle := rng.randf_range(0, TAU)
		var radius := rng.randf_range(108, 185)
		var p := Vector2(cos(angle) * radius * 1.15, sin(angle) * radius)
		# Irregular open corridors between groves interrupt the forest silhouette.
		if sin(angle * 9.0 + radius * 0.09) > 0.86:
			continue
		var base := Vector3(p.x, height_at(p), p.y)
		var size := rng.randf_range(4.0, 7.0)
		trunk_transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1, size * 0.7, 1)), base + Vector3.UP * size * 0.35))
		for lobe in 3:
			var spread := Vector3(sin(lobe * 2.1) * size * 0.16, size * (0.62 + lobe * 0.07), cos(lobe * 2.1) * size * 0.16)
			crown_transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(size * 0.28, size * 0.34, size * 0.28)), base + spread))
	instances("DistantForestCrowns", crowns, crown_transforms, builder.material("#293c35"))
	instances("DistantForestTrunks", trunks, trunk_transforms, builder.material("#493d39"))


func silhouette_crown() -> ArrayMesh:
	# Uneven tapered tiers keep the far ridge wooded rather than balloon-shaped.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radii := [0.15, 1.0, 0.67, 0.73, 0.39, 0.0]
	for tier in 5:
		for segment in 10:
			var points: Array[Vector3] = []
			for corner in [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)]:
				var level := tier + int(corner.x)
				var angle := TAU * float(segment + corner.y) / 10.0
				var width: float = radii[level] * (1.0 + 0.13 * sin(angle * 3.0 + level))
				points.append(Vector3(cos(angle) * width, -1.0 + level * 0.4, sin(angle) * width))
			for i in [0, 1, 2, 0, 2, 3]:
				surface.add_vertex(points[i])
	surface.generate_normals()
	return surface.commit()


func instances(label: String, mesh: Mesh, transforms: Array[Transform3D], mat: Material) -> void:
	# Spatial batches let the renderer discard forest behind the camera. One
	# map-wide MultiMesh would submit every tree even in close seated shots.
	var cells := {}
	for transform in transforms:
		var cell := Vector2i(floori(transform.origin.x / 48.0), floori(transform.origin.z / 48.0))
		if not cells.has(cell):
			cells[cell] = []
		cells[cell].append(transform)
	for cell in cells:
		var batch: Array[Transform3D] = []
		batch.assign(cells[cell])
		instance_batch(label + "_%s_%s" % [cell.x, cell.y], mesh, batch, mat)


func instance_batch(label: String, mesh: Mesh, transforms: Array[Transform3D], mat: Material) -> void:
	var node := MultiMeshInstance3D.new()
	node.set_script(preload("res://scripts/world/garden_forest_instances.gd"))
	node.name = label
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	node.multimesh.use_colors = true
	node.multimesh.mesh = mesh
	node.multimesh.instance_count = transforms.size()
	node.placements = transforms
	var colors := PackedColorArray()
	for i in transforms.size():
		node.multimesh.set_instance_transform(i, transforms[i])
		var tint := rng.randf_range(0.8, 1.18)
		node.multimesh.set_instance_color(i, Color(tint, tint, tint, 1))
		colors.append(Color(tint, tint, tint, 1))
	node.tints = colors
	if mat is StandardMaterial3D:
		mat.vertex_color_use_as_albedo = true
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	builder.zones.Surroundings.add_child(node)


func particle_material(pink: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.resource_name = "CherryPetalMaterial" if pink else "GreenLeafMaterial"
	mat.shader = load("res://shaders/garden_leaf_motion.gdshader")
	mat.set_shader_parameter("tint_a", Color("#efbbcd") if pink else Color("#66794e"))
	mat.set_shader_parameter("tint_b", Color("#f3d8c8") if pink else Color("#a39a58"))
	return mat


func leaves() -> void:
	var pink := particle_material(true)
	var green := particle_material(false)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.09, 0.14)
	var draw := ShaderMaterial.new()
	draw.shader = load("res://shaders/garden_drifting_leaf.gdshader")
	mesh.material = draw
	for node in builder.zones.Planting.get_children():
		if not node is Node3D:
			continue
		var blossom: bool = node.get_meta("garden_asset_id", "") == "garden_pond_blossom"
		var oak: bool = node.get_meta("garden_asset_id", "") == "garden_oak_tree"
		if blossom or oak:
			emitter(node.position + Vector3.UP * (4.3 if blossom else 3.8 * node.scale.y), 20 if blossom else 5, pink if blossom else green, mesh)
	emitter(Vector3(0, 6.3, -3), 14, green, mesh)


func emitter(pos: Vector3, count: int, mat: Material, mesh: Mesh) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "CherryPetals" if count == 20 else "GreenLeaves"
	particles.position = pos
	particles.amount = count
	particles.lifetime = 7.0 if count == 20 else 8.5
	particles.preprocess = rng.randf_range(0.0, 8.0)
	particles.randomness = 0.35
	particles.fixed_fps = 30
	particles.process_material = mat
	particles.draw_pass_1 = mesh
	particles.visibility_aabb = AABB(Vector3(-3, -8, -4), Vector3(8, 10, 7))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	builder.zones.Planting.add_child(particles)
