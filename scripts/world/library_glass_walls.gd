extends RefCounted

## Replaces the two solid south plaster walls with glass panel walls in the
## east-window language (sill + glass panes + posts + rails + mullions +
## header). Runs at room load on the instantiated scene; the .tscn on disk is
## never modified. Collision (SouthBoundary) is untouched, and sampled meshes
## and materials are shared by reference, never duplicated.


static func apply(layout: Node3D) -> void:
	var redesign: Node3D = layout.get_node_or_null("LibraryRedesign") as Node3D
	if redesign == null:
		return
	var glass_sample: MeshInstance3D = redesign.get_node_or_null("EastGlass_-12") as MeshInstance3D
	var post_sample: MeshInstance3D = redesign.get_node_or_null("EastWindowPost") as MeshInstance3D
	var rail_sample: MeshInstance3D = redesign.get_node_or_null("EastWindowRail") as MeshInstance3D
	var mullion_sample: MeshInstance3D = redesign.get_node_or_null("EastWindowMullion") as MeshInstance3D
	var sill_sample: MeshInstance3D = redesign.get_node_or_null("EastWindowSillWall") as MeshInstance3D
	var header_sample: MeshInstance3D = redesign.get_node_or_null("EastWindowHeaderWall") as MeshInstance3D
	if glass_sample == null or post_sample == null or rail_sample == null:
		return
	if mullion_sample == null or sill_sample == null or header_sample == null:
		return
	var glass_material: Material = glass_sample.material_override
	var glass_mesh: Mesh = glass_sample.mesh
	var post_material: Material = post_sample.material_override
	var post_mesh: Mesh = post_sample.mesh
	var rail_material: Material = rail_sample.material_override
	var mullion_material: Material = mullion_sample.material_override
	var mullion_mesh: Mesh = mullion_sample.mesh
	var sill_material: Material = sill_sample.material_override
	var header_material: Material = header_sample.material_override
	if glass_material == null or post_material == null or rail_material == null:
		return
	for wall_name in ["SouthWallLeft", "SouthWallRight"]:
		var wall: MeshInstance3D = redesign.get_node_or_null(wall_name) as MeshInstance3D
		if wall == null:
			continue
		_build_glass_wall(redesign, wall, glass_material, glass_mesh, post_material, post_mesh, rail_material, mullion_material, mullion_mesh, sill_material, header_material)


static func _part(parent: Node3D, mesh: Mesh, material: Material, position: Vector3, rotation_y := 0.0, node_scale := Vector3.ONE) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = position
	node.rotation.y = rotation_y
	node.scale = node_scale
	parent.add_child(node)
	return node


static func _build_glass_wall(redesign: Node3D, wall: MeshInstance3D, glass_material: Material, glass_mesh: Mesh, post_material: Material, post_mesh: Mesh, rail_material: Material, mullion_material: Material, mullion_mesh: Mesh, sill_material: Material, header_material: Material) -> void:
	var center: Vector3 = wall.position
	var width := 18.9
	var root := Node3D.new()
	root.name = wall.name + "Glass"
	redesign.add_child(root)
	# Sill and header span the full former wall footprint.
	_part(root, _box(1.0, 1.0, 1.0), sill_material, Vector3(center.x, 0.32, center.z), 0.0, Vector3(width, 0.95, 0.55))
	_part(root, _box(1.0, 1.0, 1.0), header_material, Vector3(center.x, 5.8, center.z), 0.0, Vector3(width, 1.15, 0.55))
	# Bottom and top rails run the full width.
	_part(root, _box(1.0, 1.0, 1.0), rail_material, Vector3(center.x, 0.98, center.z), 0.0, Vector3(width, 0.2, 0.28))
	_part(root, _box(1.0, 1.0, 1.0), rail_material, Vector3(center.x, 5.1, center.z), 0.0, Vector3(width, 0.2, 0.28))
	# Four posts make three bays; each bay gets a glass pane + mullion.
	# East panes run along Z; south panes rotate 90 degrees so the thin axis
	# faces the room, stretched to the 6.3 m bay width.
	for i in 4:
		var post_x: float = center.x - width * 0.5 + width * float(i) / 3.0
		_part(root, post_mesh, post_material, Vector3(post_x, 3.05, center.z))
	for i in 3:
		var pane_center: float = center.x - width * 0.5 + width * (float(i) + 0.5) / 3.0
		if glass_mesh != null:
			_part(root, glass_mesh, glass_material, Vector3(pane_center, 3.05, center.z), PI * 0.5, Vector3(1.0, 1.0, 1.26))
		if mullion_mesh != null:
			_part(root, mullion_mesh, mullion_material, Vector3(pane_center, 3.05, center.z), PI * 0.5)
	wall.visible = false


static func _box(x: float, y: float, z: float) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(x, y, z)
	return mesh
