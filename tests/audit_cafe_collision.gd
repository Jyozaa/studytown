extends SceneTree

# Collision audit: segment-sweep the §22 walk route against every
# StaticBody3D box + verify every StudySpot stand anchor is reachable.

var app
var frame := 0
var done := false

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	root.get_node("GameState").persistence_enabled = false
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		app.current_room_name = root.get_node("GameState").ROOMS[1]
		app.build_room(1)
	if frame == 120 and not done:
		done = true
		_run_audit()
		quit()
	return false

func _boxes() -> Array:
	var out := []
	for body in app.world_root.find_children("*", "StaticBody3D", true, false):
		var b := body as StaticBody3D
		for cs in b.find_children("*", "CollisionShape3D", false, false):
			var shape := (cs as CollisionShape3D).shape
			if shape is BoxShape3D:
				var csn := cs as Node3D
				var center: Vector3 = b.global_transform * csn.position
				# Account for shape-node pitch (stair ramp/guards): the
				# rotated Y extent is what the player actually meets.
				var rx: float = (b.global_rotation.x + csn.rotation.x)
				var sy: float = (shape as BoxShape3D).size.y
				var sz: float = (shape as BoxShape3D).size.z
				var y_half: float = absf(cos(rx)) * sy * 0.5 + absf(sin(rx)) * sz * 0.5
				var z_half: float = absf(sin(rx)) * sy * 0.5 + absf(cos(rx)) * sz * 0.5
				out.append({
					"center": center,
					"size": (shape as BoxShape3D).size,
					"yaw": b.global_rotation.y,
					"y_half": y_half,
					"z_half": z_half,
					"pitched": absf(rx) > 0.1,
					"name": b.name,
				})
	return out

func _overlaps_y(c: Vector3, s: Vector3, y0: float, y1: float) -> bool:
	return c.y - s.y * 0.5 < y1 and c.y + s.y * 0.5 > y0

func _overlaps_y2(c: Vector3, y_half: float, y0: float, y1: float) -> bool:
	return c.y - y_half < y1 and c.y + y_half > y0

func _seg_hits_box(ax: float, az: float, bx: float, bz: float, c: Vector3, s: Vector3, yaw: float, r: float) -> bool:
	# Transform segment into box local 2D frame, test vs expanded rect.
	var dx := bx - ax
	var dz := bz - az
	var steps := int(maxf(2.0, Vector2(dx, dz).length() / 0.2))
	for i in steps + 1:
		var t := float(i) / float(steps)
		var px := ax + dx * t - c.x
		var pz := az + dz * t - c.z
		var lx := px * cos(-yaw) - pz * sin(-yaw)
		var lz := px * sin(-yaw) + pz * cos(-yaw)
		if absf(lx) < s.x * 0.5 + r and absf(lz) < s.z * 0.5 + r:
			return true
	return false

func _run_audit() -> void:
	var boxes := _boxes()
	print("AUDIT bodies=", boxes.size())
	var player_r := 0.43
	# Ground route (§22), player vertical span 0..1.9.
	var ground := [
		Vector3(0, 0, 9.0), Vector3(2.5, 0, 9.0), Vector3(2.5, 0, 4.5),
		Vector3(2.5, 0, -0.2), Vector3(9, 0, -0.2), Vector3(11.8, 0, -0.2),
		Vector3(11.8, 0, -0.5), Vector3(4, 0, 0), Vector3(0, 0, -2.4),
		Vector3(8, 0, -2.4), Vector3(11, 0, -2), Vector3(12.0, 0, -2),
		Vector3(11, 0, -2), Vector3(9, 0, -2), Vector3(9, 0, 0.3),
		Vector3(3, 0, 0.3), Vector3(3, 0, 4), Vector3(3, 0, 7),
		Vector3(6, 0, 8.6), Vector3(6, 0, 9.8), Vector3(14, 0, 9.8),
		Vector3(14, 0, 7.6), Vector3(13.6, 0, 7.6), Vector3(13.6, 0, 9.8),
		Vector3(6, 0, 9.8), Vector3(6, 0, 10.8), Vector3(-6, 0, 10.8),
		Vector3(-6, 0, 8.6), Vector3(-5.9, 0, 4.4), Vector3(-5.9, 0, 2.8),
		Vector3(-7.5, 0, 2.0), Vector3(-11.2, 0, 1.0), Vector3(-11.2, 0, 4.3), Vector3(-11.2, 0, 3.2),
		Vector3(-7.0, 0, 3.2), Vector3(-7.0, 0, 5.8), Vector3(-6.0, 0, 5.8),
		Vector3(-6.0, 0, 8.6),
		Vector3(-6.0, 0, 10.6), Vector3(-9.0, 0, 10.6),
		Vector3(-9, 0, 9.4), Vector3(-9, 0, 8.2), Vector3(-6, 0, 8.2),
	]
	# Upstairs route, span 4.7..6.7.
	var upper := [
		Vector3(12.5, 0, -4.6), Vector3(8.0, 0, -4.4), Vector3(2.5, 0, -4.4),
		Vector3(-2.5, 0, -4.4), Vector3(-8.0, 0, -4.4), Vector3(-11.8, 0, -4.6),
		Vector3(-13.2, 0, -4.6), Vector3(-13.2, 0, -9.6), Vector3(-8.0, 0, -9.9),
		Vector3(-2.0, 0, -9.9), Vector3(-2.0, 0, -10.8), Vector3(2.5, 0, -10.8),
		Vector3(2.5, 0, -6.2), Vector3(2.5, 0, -4.4), Vector3(7.0, 0, -4.4),
		Vector3(10.5, 0, -4.4), Vector3(12.5, 0, -4.6),
	]
	# NOTE: stair climb (13.6, 7.6) -> glass (12.5, -4.6) is covered by the
	# invisible climb ramp (verified separately); the sweep test is 2D.
	for route in [["ground", ground, 0.0, 1.9, 0.0], ["upper", upper, 4.7, 6.7, 4.8]]:
		var label: String = route[0]
		var pts: Array = route[1]
		var floor_y: float = route[4]
		for i in range(pts.size() - 1):
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			var hit := ""
			for bx in boxes:
				# Pitched shapes (climb ramp, stair guards) cannot be modeled
				# by this 2D sweep; the full-route walker covers them with the
				# real capsule instead.
				if bool(bx["pitched"]):
					continue
				var bc: Vector3 = bx["center"]
				var bs: Vector3 = bx["size"]
				if not _overlaps_y2(bc, float(bx["y_half"]), route[2], route[3]):
					continue
				# The climb ramp is a tapered wedge: the 2D sweep cannot
				# model headroom tapering, so it is excluded here and
				# covered empirically by the full-route walker instead.
				if bs.x > 2.0 and bs.x < 2.1 and bs.z > 9.8 and bs.z < 10.0:
					continue
				if absf(bc.y + bs.y * 0.5 - floor_y) < 0.35:
					continue # walking surface itself
				var foot := Vector3(bs.x, bs.y, float(bx["z_half"]) * 2.0)
				if _seg_hits_box(a.x, a.z, b.x, b.z, bc, foot, float(bx["yaw"]), player_r):
					hit = "BLOCKED by %s c=%s s=%s" % [bx["name"], str(bc), str(bs)]
					break
			print("ROUTE %s seg %d (%s -> %s): %s" % [label, i, str(a), str(b), hit if hit != "" else "clear"])
	# Stand anchors: must not sit inside any blocker (0.35 margin).
	var bad := 0
	for i in app.study_spots.size():
		var spot = app.study_spots[i]
		var p: Vector3 = spot.standing_position
		for bx in boxes:
			if not _overlaps_y(bx["center"], bx["size"], 0.0, 6.7):
				continue
			var lx: float = (p.x - (bx["center"] as Vector3).x)
			var lz: float = (p.z - (bx["center"] as Vector3).z)
			var yaw: float = float(bx["yaw"])
			var rx: float = lx * cos(-yaw) - lz * sin(-yaw)
			var rz: float = lx * sin(-yaw) + lz * cos(-yaw)
			var sx: float = (bx["size"] as Vector3).x
			var sz: float = (bx["size"] as Vector3).z
			if absf(rx) < sx * 0.5 + 0.35 and absf(rz) < sz * 0.5 + 0.35:
				# Standing inside tall furniture is only bad if the blocker
				# actually reaches standing height.
				var cy: float = (bx["center"] as Vector3).y
				var sy: float = (bx["size"] as Vector3).y
				if cy - sy * 0.5 < p.y + 0.3 and cy + sy * 0.5 > p.y:
					print("ANCHOR spot %d (%s) stand=%s inside %s c=%s s=%s" % [i, spot.seat_id, str(p), bx["name"], str(bx["center"]), str(bx["size"])])
					bad += 1
					break
	print("ANCHOR bad=", bad, " total=", app.study_spots.size())
	print("AUDIT DONE")
