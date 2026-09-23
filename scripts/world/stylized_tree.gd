extends RefCounted

## Chunky stylized trees in the game's cozy language (tapered trunk + blob
## canopy), built from shared primitive resources. Used to replace selected
## hero trees whose archive-derived look clashes with the rest of the art.

static var shared_trunk_mesh: CylinderMesh
static var shared_puff_mesh: SphereMesh
static var shared_bark: StandardMaterial3D
static var shared_leaf_a: StandardMaterial3D
static var shared_leaf_b: StandardMaterial3D
static var shared_blossom_a: StandardMaterial3D
static var shared_blossom_b: StandardMaterial3D


static func _resources() -> void:
	if shared_trunk_mesh == null:
		shared_trunk_mesh = CylinderMesh.new()
		shared_trunk_mesh.top_radius = 0.09
		shared_trunk_mesh.bottom_radius = 0.14
		shared_trunk_mesh.height = 1.0
		shared_trunk_mesh.radial_segments = 10
	if shared_puff_mesh == null:
		shared_puff_mesh = SphereMesh.new()
		shared_puff_mesh.radius = 1.0
		shared_puff_mesh.height = 2.0
		shared_puff_mesh.radial_segments = 12
		shared_puff_mesh.rings = 8
	if shared_bark == null:
		shared_bark = StandardMaterial3D.new()
		shared_bark.albedo_color = Color("#6b4a33")
		shared_bark.roughness = 0.9
	if shared_leaf_a == null:
		shared_leaf_a = StandardMaterial3D.new()
		shared_leaf_a.albedo_color = Color("#3f8f58")
		shared_leaf_a.roughness = 0.9
	if shared_leaf_b == null:
		shared_leaf_b = StandardMaterial3D.new()
		shared_leaf_b.albedo_color = Color("#2e7a4e")
		shared_leaf_b.roughness = 0.9
	if shared_blossom_a == null:
		shared_blossom_a = StandardMaterial3D.new()
		shared_blossom_a.albedo_color = Color("#f2b8c6")
		shared_blossom_a.roughness = 0.9
	if shared_blossom_b == null:
		shared_blossom_b = StandardMaterial3D.new()
		shared_blossom_b.albedo_color = Color("#e78ba5")
		shared_blossom_b.roughness = 0.9


# Puffs as (x, y, z, radius) fractions of (radius, height).
const OAK_PUFFS := [
	[0.0, 0.60, 0.0, 0.42],
	[0.35, 0.50, 0.10, 0.30],
	[-0.33, 0.52, -0.08, 0.31],
	[0.08, 0.78, -0.12, 0.27],
	[-0.10, 0.46, 0.25, 0.24],
	[0.28, 0.66, -0.28, 0.22],
	[-0.30, 0.68, 0.20, 0.21],
]


static func build_oak(height := 9.0, radius := 3.5) -> Node3D:
	return _build(height, radius, false)


static func build_blossom(height := 6.0, radius := 2.8) -> Node3D:
	return _build(height, radius, true)


static func _build(height: float, radius: float, blossom: bool) -> Node3D:
	_resources()
	var root := Node3D.new()
	root.name = "StylizedBlossom" if blossom else "StylizedOak"
	var trunk := MeshInstance3D.new()
	trunk.name = "StylizedTrunk"
	trunk.mesh = shared_trunk_mesh
	trunk.material_override = shared_bark
	var trunk_height: float = height * 0.55
	trunk.scale = Vector3(radius * 0.20, trunk_height, radius * 0.20)
	trunk.position = Vector3(0.0, trunk_height * 0.5, 0.0)
	root.add_child(trunk)
	var leaf_materials := [shared_blossom_a, shared_blossom_b] if blossom else [shared_leaf_a, shared_leaf_b]
	var index := 0
	for puff in OAK_PUFFS:
		var node := MeshInstance3D.new()
		node.name = "CanopyPuff_%d" % index
		node.mesh = shared_puff_mesh
		node.material_override = leaf_materials[index % 2]
		node.position = Vector3(puff[0] * radius, puff[1] * height, puff[2] * radius)
		node.scale = Vector3(puff[3] * radius, puff[3] * radius * 0.8, puff[3] * radius)
		root.add_child(node)
		index += 1
	return root


## Hides the visual root of an archive GLB instance and plants a procedural
## replacement sized to the original's measured world bounds. Collision and
## anchors elsewhere in the scene are untouched.
static func swap_hero_oak(tree_instance: Node3D, blossom := false) -> Node3D:
	if not is_instance_valid(tree_instance):
		return null
	var bounds := AABB()
	var has_bounds := false
	for mesh_instance in tree_instance.find_children("*", "MeshInstance3D", true, false):
		if (mesh_instance as MeshInstance3D).mesh == null:
			continue
		var box: AABB = (mesh_instance as MeshInstance3D).global_transform * (mesh_instance as MeshInstance3D).get_aabb()
		if not has_bounds:
			bounds = box
			has_bounds = true
		else:
			bounds = bounds.merge(box)
	if not has_bounds:
		return null
	var size: Vector3 = bounds.size
	var replacement := build_blossom(size.y, maxf(size.x, size.z) * 0.5) if blossom else build_oak(size.y, maxf(size.x, size.z) * 0.5)
	replacement.position = Vector3(bounds.position.x + size.x * 0.5, bounds.position.y, bounds.position.z + size.z * 0.5)
	tree_instance.get_parent().add_child(replacement)
	tree_instance.visible = false
	return replacement
