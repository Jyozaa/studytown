extends SceneTree

# One-shot migration on assets/dev_local/room_layouts/garden.tscn:
#  1. Widen glass-floor collision to the user-extended panels/beams.
#  2. Reseat one floating glass panel back onto the grid.
#  3. Widen + recenter the climb ramp to the widened steps.
#  4. Move the ground east-lounge cluster 1.5 m toward center
#     (couch, armchair, low table, rug, tabletop props, blockers, seats).

const SCENE := "res://assets/dev_local/room_layouts/garden.tscn"
var frame := 0

func _initialize() -> void:
	pass

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 2:
		_run()
		quit()
	return false

func _near(a: Vector3, b: Vector3, tol := 0.05) -> bool:
	return (a - b).length() < tol

func _run() -> void:
	var packed: PackedScene = load(SCENE)
	var layout := packed.instantiate() as Node3D
	root.add_child(layout)
	_fix_glass_collision(layout)
	_fix_floating_panel(layout)
	_fix_ramp(layout)
	_move_lounge_cluster(layout)
	var out := PackedScene.new()
	var pack_err := out.pack(layout)
	print("MIGRATE pack err=", pack_err)
	var err := ResourceSaver.save(out, SCENE)
	print("MIGRATE save err=", err)
	print("MIGRATE DONE")

func _all_nodes(layout: Node3D) -> Array:
	return layout.find_children("*", "Node3D", true, false)

func _fix_glass_collision(layout: Node3D) -> void:
	for b in layout.find_children("*", "StaticBody3D", true, false):
		var bb := b as StaticBody3D
		for cs in bb.find_children("*", "CollisionShape3D", false, false):
			var sh := (cs as CollisionShape3D).shape
			if sh is BoxShape3D:
				var c: Vector3 = bb.global_transform * (cs as Node3D).position
				var s: Vector3 = (sh as BoxShape3D).size
				if _near(c, Vector3(0, 4.7, -7.25), 0.01) and _near(s, Vector3(30, 0.2, 7.5), 0.01):
					(sh as BoxShape3D).size = Vector3(31.95, 0.2, 7.5)
					bb.global_position = Vector3(bb.global_position.x - 0.075, bb.global_position.y, bb.global_position.z)
					print("MIGRATE glass collision now c=", bb.global_position, " s=", (sh as BoxShape3D).size)
					return
	print("MIGRATE WARNING: glass collision not found")

func _fix_floating_panel(layout: Node3D) -> void:
	for m in layout.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh is BoxMesh:
			if _near(mi.global_position, Vector3(-4.78, 4.97, -5.57), 0.15):
				mi.global_position = Vector3(mi.global_position.x, 4.77, mi.global_position.z)
				print("MIGRATE reseated panel ", mi.name, " to y=4.77")
				return
	print("MIGRATE WARNING: floating panel not found")

func _fix_ramp(layout: Node3D) -> void:
	for b in layout.find_children("*", "StaticBody3D", true, false):
		var bb := b as StaticBody3D
		for cs in bb.find_children("*", "CollisionShape3D", false, false):
			var sh := (cs as CollisionShape3D).shape
			if sh is BoxShape3D:
				var c: Vector3 = bb.global_transform * (cs as Node3D).position
				var s: Vector3 = (sh as BoxShape3D).size
				if _near(c, Vector3(13.6, 1.98, 1.9), 0.05) and _near(s, Vector3(2.05, 0.18, 12.55), 0.05):
					# Widen to the new steps (x ~12.5..15.85, center ~14.17).
					(sh as BoxShape3D).size = Vector3(3.2, 0.18, 12.55)
					var csn := cs as Node3D
					csn.position = Vector3(csn.position.x + 0.57, csn.position.y, csn.position.z)
					print("MIGRATE ramp now size=", (sh as BoxShape3D).size, " shape pos=", csn.position)
					return
	print("MIGRATE WARNING: ramp not found")

func _top_roots_at(layout: Node3D, pos: Vector3, tol := 0.05) -> Array:
	var out := []
	for n in _all_nodes(layout):
		var nd := n as Node3D
		if _near(nd.global_position, pos, tol):
			var p := nd.get_parent() as Node3D
			if p == null or not _near(p.global_position, pos, tol):
				out.append(nd)
	return out

func _shift(positions: Array, dx: float) -> void:
	for n in positions:
		(n as Node3D).global_position += Vector3(dx, 0, 0)

func _move_lounge_cluster(layout: Node3D) -> void:
	var dx := -1.5
	# Visual roots (topmost nodes only, so nested children follow).
	_shift(_top_roots_at(layout, Vector3(10.5, 0, 7.2)), dx) # couch
	_shift(_top_roots_at(layout, Vector3(8.0, 0, 6.0)), dx) # armchair
	_shift(_top_roots_at(layout, Vector3(10.5, 0, 5.6)), dx) # low table
	_shift(_top_roots_at(layout, Vector3(10.5, 0.02, 6.4)), dx) # rug
	_shift(_top_roots_at(layout, Vector3(10.2, 0.75, 5.6), 0.15), dx) # book
	_shift(_top_roots_at(layout, Vector3(10.9, 0.54, 5.8), 0.15), dx) # mug
	print("MIGRATE lounge visuals shifted")
	# Collision boxes.
	for b in layout.find_children("*", "StaticBody3D", true, false):
		var bb := b as StaticBody3D
		for cs in bb.find_children("*", "CollisionShape3D", false, false):
			var sh := (cs as CollisionShape3D).shape
			if sh is BoxShape3D:
				var c: Vector3 = bb.global_transform * (cs as Node3D).position
				if _near(c, Vector3(10.5, 0.55, 7.2), 0.05) or _near(c, Vector3(8.0, 0.7, 6.0), 0.05) or _near(c, Vector3(10.5, 0.25, 5.6), 0.05):
					bb.global_position += Vector3(dx, 0, 0)
					print("MIGRATE blocker moved: was ", c)
	# Seat anchors move as units (sitting/standing/cameras derive from origin).
	for n in _all_nodes(layout):
		if (n as Node).get_script() != null and str((n as Node).get_script().resource_path).ends_with("study_spot.gd"):
			var sid := str(n.get("seat_id"))
			if sid in ["cafe-G20", "cafe-G21", "cafe-G22", "cafe-G23"]:
				(n as Node3D).global_position += Vector3(dx, 0, 0)
				print("MIGRATE seat moved: ", sid, " now at ", (n as Node3D).global_position)
