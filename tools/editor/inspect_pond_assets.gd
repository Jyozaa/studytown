extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	for file in [
		"garden_big_tree",
		"garden_oak_tree",
		"garden_western_gazebo",
		"garden_forest_bench",
		"cafe_chair",
		"garden_cafe_table",
		"garden_party_light_arch",
		"garden_pond_log_bridge",
		"garden_pond_parasol",
		"garden_log_seat"
	]:
		var path := "res://assets/dev_local/blender_generated/runtime/%s.glb" % file
		if not ResourceLoader.exists(path):
			continue
		var node: Node3D = load(path).instantiate()
		root.add_child(node)
		var bounds := AABB()
		var first := true
		for mesh in node.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			if file == "garden_big_tree":
				print("  ", mesh.name, " ", box)
			bounds = box if first else bounds.merge(box)
			first = false
		print(file, " ", bounds)
		node.free()
	quit()
