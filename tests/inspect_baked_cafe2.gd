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
		print("INSPECT2 DONE")
		quit()
	return false

func _dump(layout: Node3D) -> void:
	print("--- thin glass-like boxes y 4.4..5.2 ---")
	for m in layout.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh is BoxMesh:
			var bm := mi.mesh as BoxMesh
			var gp: Vector3 = mi.global_position
			if bm.size.y < 0.12 and gp.y > 4.4 and gp.y < 5.2 and absf(gp.x) < 20.0:
				print("PANEL ", mi.name, " pos=", gp, " size=", bm.size)
	print("--- beam-like boxes y 4.5..5.1 (dark, thin) ---")
	var n := 0
	for m in layout.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh is BoxMesh:
			var bm := mi.mesh as BoxMesh
			var gp: Vector3 = mi.global_position
			if gp.y > 4.5 and gp.y < 5.1 and ((bm.size.x > 5.0 and bm.size.y < 0.3) or (bm.size.z > 5.0 and bm.size.y < 0.3)):
				print("BEAM ", mi.name, " pos=", gp, " size=", bm.size)
				n += 1
				if n > 30:
					break
	print("--- step-like boxes x 11..16, z -5..8 ---")
	n = 0
	for m in layout.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh is BoxMesh:
			var bm := mi.mesh as BoxMesh
			var gp: Vector3 = mi.global_position
			if gp.x > 11.0 and gp.x < 16.0 and gp.z > -5.0 and gp.z < 8.0 and bm.size.x < 3.0 and bm.size.y < 1.0:
				print("STEP ", mi.name, " pos=", gp, " size=", bm.size, " rot=", mi.global_rotation)
				n += 1
				if n > 40:
					break
	print("--- collision boxes x 11..16, z -5..8 ---")
	for b in layout.find_children("*", "StaticBody3D", true, false):
		var bb := b as StaticBody3D
		for cs in bb.find_children("*", "CollisionShape3D", false, false):
			var sh := (cs as CollisionShape3D).shape
			if sh is BoxShape3D:
				var c: Vector3 = bb.global_transform * (cs as Node3D).position
				if c.x > 10.0 and c.x < 17.0 and c.z > -6.0 and c.z < 9.0:
					print("COL name=", bb.name, " c=", c, " s=", (sh as BoxShape3D).size, " yaw=", bb.global_rotation.y, " pitch=", bb.global_rotation.x)
	print("--- glass collision + railing blockers anywhere ---")
	for b in layout.find_children("*", "StaticBody3D", true, false):
		var bb := b as StaticBody3D
		for cs in bb.find_children("*", "CollisionShape3D", false, false):
			var sh := (cs as CollisionShape3D).shape
			if sh is BoxShape3D:
				var c: Vector3 = bb.global_transform * (cs as Node3D).position
				var s: Vector3 = (sh as BoxShape3D).size
				if (s.x > 20.0) or (bb.name == "MajorFurnitureCollision" and c.y > 4.5 and c.y < 6.5 and s.x > 10.0):
					print("BIGCOL name=", bb.name, " c=", c, " s=", s)
