extends SceneTree

var meshes := {}
var textures := {}
var materials := {}

func _initialize() -> void: call_deferred("run")

func inspect_material(material: Material) -> void:
	if material == null or materials.has(material): return
	materials[material] = true
	if material is ShaderMaterial and material.shader != null:
		for uniform in material.shader.get_shader_uniform_list(): inspect_texture(material.get_shader_parameter(uniform.name))
	else:
		for property in material.get_property_list():
			if property.type == TYPE_OBJECT: inspect_texture(material.get(property.name))

func inspect_texture(value) -> void:
	if value is Texture2D and not textures.has(value):
		textures[value] = {"path": value.resource_path, "width": value.get_width(), "height": value.get_height(), "pixels": value.get_width() * value.get_height()}

func run() -> void:
	var report := {}
	for room in ["garden", "library", "train"]:
		meshes.clear()
		textures.clear()
		materials.clear()
		var scene = load("res://assets/dev_local/room_layouts/" + room + ".tscn").instantiate()
		root.add_child(scene)
		for node in scene.find_children("*", "GeometryInstance3D", true, false):
			var mesh: Mesh
			var count := 1
			if node is MeshInstance3D: mesh = node.mesh
			elif node is MultiMeshInstance3D and node.multimesh != null:
				mesh = node.multimesh.mesh
				count = node.multimesh.instance_count
			if mesh == null: continue
			if not meshes.has(mesh):
				var vertices := 0
				var triangles := 0
				for surface in mesh.get_surface_count():
					var arrays := mesh.surface_get_arrays(surface)
					vertices += arrays[Mesh.ARRAY_VERTEX].size()
					triangles += (arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null else arrays[Mesh.ARRAY_VERTEX].size()) / 3
				meshes[mesh] = {"name": str(scene.get_path_to(node)), "resource": mesh.resource_path, "vertices": vertices, "triangles": triangles, "instances": 0, "submitted_triangles": 0}
			meshes[mesh].instances += count
			meshes[mesh].submitted_triangles += meshes[mesh].triangles * count
			inspect_material(node.material_override)
			for surface in mesh.get_surface_count():
				inspect_material(mesh.surface_get_material(surface))
				if node is MeshInstance3D: inspect_material(node.get_surface_override_material(surface))
		var mesh_list := meshes.values()
		mesh_list.sort_custom(func(a, b): return a.submitted_triangles > b.submitted_triangles)
		var texture_list := textures.values()
		texture_list.sort_custom(func(a, b): return a.pixels > b.pixels)
		report[room] = {"unique_meshes": meshes.size(), "unique_materials": materials.size(), "unique_textures": textures.size(), "largest_meshes": mesh_list.slice(0, 20), "largest_textures": texture_list.slice(0, 20)}
		scene.queue_free()
		await process_frame
	var file := FileAccess.open("/tmp/studytown-render-resources.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("RESOURCE_AUDIT_SAVED")
	quit()
