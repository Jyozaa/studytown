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
		print("INSPECT DONE")
		quit()
	return false

func _dump(layout: Node3D) -> void:
	print("--- children named like couch/lounge/stair/glass ---")
	for n in layout.find_children("*", "Node3D", true, false):
		var nm := str(n.name).to_lower()
		if nm.contains("couch") or nm.contains("pillow") or nm.contains("sofa") or nm.contains("armchair"):
			print("SOFA node=", n.name, " pos=", (n as Node3D).global_position, " rot=", (n as Node3D).global_rotation)
	print("--- StudySpots near east lounge ---")
	for n in layout.find_children("*", "Node3D", true, false):
		if (n as Node).get_script() != null and str((n as Node).get_script().resource_path).ends_with("study_spot.gd"):
			var p: Vector3 = n.get("sitting_position")
			if p.x > 5.0 and p.z > 3.0 and p.y < 2.0:
				print("SEAT id=", n.get("seat_id"), " sit=", n.get("sitting_position"), " stand=", n.get("standing_position"))
	print("--- StaticBodies (collision) ---")
	var bodies := 0
	for b in layout.find_children("*", "StaticBody3D", true, false):
		bodies += 1
	print("static bodies=", bodies)
	print("--- glass panel meshes (BoxMesh transparents) ---")
	var glass := []
	for m in layout.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh is BoxMesh:
			var bm := mi.mesh as BoxMesh
			var gp: Vector3 = mi.global_position
			if gp.y > 4.0 and gp.y < 5.6 and absf(gp.x) < 17.0 and gp.z > -13.0 and gp.z < -2.0:
				glass.append([mi.name, gp, bm.size])
	print("glass-candidate boxes=", glass.size())
	for g in glass:
		print("  ", g[0], " pos=", g[1], " size=", g[2])
