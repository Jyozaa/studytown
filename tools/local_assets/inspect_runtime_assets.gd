extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for path in OS.get_cmdline_user_args():
		if not ResourceLoader.exists(path):
			print("MISSING ", path)
			continue
		var resource = load(path)
		if not resource is PackedScene:
			print("NOT_SCENE ", path)
			continue
		var instance: Node = resource.instantiate()
		root.add_child(instance)
		await process_frame
		var bounds := _bounds_for(instance)
		print("ASSET_BOUNDS ", path, " position=", bounds.position, " size=", bounds.size)
		instance.free()
	quit()

func _bounds_for(node: Node) -> AABB:
	var result := AABB()
	var initialized := false
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var local_bounds := mesh_instance.global_transform * mesh_instance.get_aabb()
		if not initialized:
			result = local_bounds
			initialized = true
		else:
			result = result.merge(local_bounds)
	return result
