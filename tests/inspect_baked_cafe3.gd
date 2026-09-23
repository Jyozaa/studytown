extends SceneTree

var frame := 0

func _initialize() -> void:
	pass

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 2:
		var packed: PackedScene = load("res://assets/dev_local/room_layouts/garden.tscn")
		var layout := packed.instantiate() as Node3D
		root.add_child(layout)
		_dump(layout)
		print("INSPECT3 DONE")
		quit()
	return false

func _dump(layout: Node3D) -> void:
	print("--- ALL MeshInstance3D x 11..17.5, z -6..9 ---")
	var n := 0
	for m in layout.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var gp: Vector3 = mi.global_position
		if gp.x > 11.0 and gp.x < 17.5 and gp.z > -6.0 and gp.z < 9.0:
			var sz := Vector3.ZERO
			if mi.mesh is BoxMesh:
				sz = (mi.mesh as BoxMesh).size
			elif mi.mesh is CylinderMesh:
				sz = Vector3(1, 1, 1)
			print("M ", mi.name, " pos=", gp, " size=", sz, " mesh=", mi.mesh.get_class() if mi.mesh != null else "none")
			n += 1
			if n > 60:
				break
	print("--- CollisionDebug group count ---")
	print("debug nodes=", get_nodes_in_group("collision_debug").size())
