extends Node3D

## Garden camera authoring and shared validation base, using the existing StudySpot
## and FocusCameraDirector rather than a second gameplay camera system.
var camera_mask := 17
var main
var lens_bounds: Array[AABB] = []
var reports := {}
var mock_neighbours := false
var last_transition_clear := true
var last_transition_points: Array[Vector3] = []
var subject_spot: StudySpot
var checked_routes: Array[Dictionary] = []


func configure(owner_node) -> void:
	main = owner_node
	name = "GardenSeatDirector"
	var shapes := {}
	for mesh: MeshInstance3D in main.editable_room_layout.find_children("*", "MeshInstance3D", true, false):
		if not include_mesh(mesh): continue
		if mesh.mesh == null:
			continue
		if not shapes.has(mesh.mesh):
			shapes[mesh.mesh] = mesh.mesh.create_trimesh_shape()
		var body := StaticBody3D.new()
		body.name = "CameraGeometry"
		body.set_meta("camera_source_mesh", mesh)
		body.collision_layer = 16
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		collision.shape = shapes[mesh.mesh]
		body.add_child(collision)
		add_child(body)
		body.global_transform = mesh.global_transform
		# Canopy cards have empty interiors: a surface ray alone cannot tell
		# that the lens starts inside foliage. Keep conservative crown volumes.
		if "Leaf" in str(mesh.name) or "leaf" in str(mesh.name):
			lens_bounds.append((mesh.global_transform * mesh.get_aabb()).grow(0.12))


func include_mesh(mesh: MeshInstance3D) -> bool:
	if mesh.mesh == null: return false
	if not mesh.is_inside_tree(): return false
	var size := (mesh.global_transform * mesh.get_aabb()).size
	if size.length() < 0.45 and size.y < 0.5: return false
	var path := str(main.editable_room_layout.get_path_to(mesh))
	if path.begins_with("Terrain/") or path.begins_with("Pond/") or path.begins_with("Surroundings/") or path.begins_with("Students/") or path.begins_with("StudySpots/") or "DriftingClouds/" in path:
		return false
	var parent := mesh.get_parent()
	while parent != main.editable_room_layout and parent != null:
		if parent is NPCController or parent is StudySpot: return false
		parent = parent.get_parent()
	return mesh.is_visible_in_tree()


func session_position_allowed(_position: Vector3) -> bool:
	return true


func candidate_angles() -> Array:
	return [0, 20, -20, 35, -35, 55, -55, 75, -75]


func candidate_distances() -> Array:
	return [3.2, 3.8, 4.5, 5.2]


func candidate_heights() -> Array:
	return [0.7, 1.05, 1.45]


func secondary_fov() -> float:
	return 44.0


func entry_position(spot) -> Vector3:
	return spot.standing_position + Vector3.UP * main.follow_camera_rig.look_height + main.follow_camera_rig.offset


func points(spot) -> Array[Vector3]:
	var adjustment: float = spot.seated_visual_offset.y - 0.20
	var base: Vector3 = spot.sitting_position + Vector3.UP * adjustment
	var right := Basis(Vector3.UP, spot.facing_yaw) * Vector3.RIGHT
	return [base + Vector3.UP * 2.18, base + Vector3.UP * 1.55, base + Vector3.UP * 1.25,
		base + Vector3.UP * 2.05 + right * 0.30, base + Vector3.UP * 2.05 - right * 0.30]


func lens_clear(position: Vector3) -> bool:
	if absf(position.x) > 70 or absf(position.z) > 60 or position.y < 0.45:
		return false
	for bounds in lens_bounds:
		if bounds.has_point(position):
			return false
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.16
	query.shape = sphere
	query.transform.origin = position
	query.collision_mask = camera_mask
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func visibility(position: Vector3, spot) -> Dictionary:
	var result := {"lens": lens_clear(position) and session_position_allowed(position), "head": true, "chest": true, "torso": true, "neighbours": true}
	var targets := points(spot)
	for i in targets.size():
		var query := PhysicsRayQueryParameters3D.create(position, targets[i], camera_mask)
		query.exclude = [main.player.get_rid()]
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			result[["head", "chest", "torso", "head", "head"][i]] = false
	for other in main.study_spots:
		if other == spot or (other.is_available() and not mock_neighbours):
			continue
		if other.sitting_position.distance_to(spot.sitting_position) > 8.0:
			continue
		# A wide seated-character envelope also covers imported animated heads.
		var bounds := AABB(other.sitting_position + Vector3(-0.70, 0.65, -0.70), Vector3(1.4, 2.0, 1.4))
		if bounds.has_point(position):
			result.neighbours = false
		for target in targets:
			if bounds.intersects_segment(position, target) != null:
				result.neighbours = false
	result["clear"] = result.lens and result.head and result.chest and result.torso and result.neighbours
	return result


func solve(spot, force := false) -> bool:
	subject_spot = spot
	if not force and not spot.setup_camera_override.is_empty() and spot.focus_camera_overrides.size() >= 2:
		var all_clear: bool = visibility(spot.to_global(spot.setup_camera_override.position), spot).clear
		for shot in spot.focus_camera_overrides:
			all_clear = all_clear and visibility(spot.to_global(shot.position), spot).clear
		if all_clear:
			var stored_entrance: Vector3 = entry_position(spot)
			var setup_position: Vector3 = spot.to_global(spot.setup_camera_override.position)
			if not transition_route(stored_entrance, setup_position).is_empty() and not transition_route(spot.to_global(spot.focus_camera_overrides[0].position), spot.to_global(spot.focus_camera_overrides[1].position)).is_empty():
				return true
	var basis := Basis(Vector3.UP, spot.facing_yaw)
	var target: Vector3 = spot.sitting_position + Vector3.UP * (1.62 + spot.seated_visual_offset.y - 0.20)
	var candidates: Array[Dictionary] = []
	for angle in candidate_angles():
		for distance in candidate_distances():
			for height in candidate_heights():
				var direction := basis * (Basis(Vector3.UP, deg_to_rad(angle)) * Vector3.FORWARD)
				var position: Vector3 = target + direction * distance + Vector3.UP * height
				var status := visibility(position, spot)
				if not status.clear:
					continue
				var score := absf(angle) * 0.012 + absf(distance - 3.8) * 0.3 + absf(height - 0.7)
				# Per-seat authored starting direction remains a composition preference.
				score += position.distance_to(spot.camera_position) * 0.025
				candidates.append({"position": position, "target": target, "fov": 40.0, "score": score})
	candidates.sort_custom(func(a, b): return a.score < b.score)
	if candidates.size() < 2:
		reports[spot.seat_id] = {"failure": "fewer than two unblocked front-quarter cameras", "candidates": candidates.size()}
		return false
	var first: Dictionary = {}
	var entrance: Vector3 = entry_position(spot)
	for candidate in candidates:
		if not transition_route(entrance, candidate.position).is_empty():
			first = candidate
			break
	if first.is_empty():
		reports[spot.seat_id] = {"failure": "no clear entry transition"}
		return false
	var second: Dictionary = {}
	for candidate in candidates:
		if candidate.position.distance_to(first.position) > 0.85 and not transition_route(first.position, candidate.position).is_empty():
			second = candidate
			break
	if second.is_empty():
		return false
	second = second.duplicate()
	second.fov = secondary_fov()
	spot.focus_camera_overrides.assign([local_shot(spot, first), local_shot(spot, second)])
	var right: Vector3 = (target - first.position).normalized().cross(Vector3.UP).normalized()
	var framing: Vector3 = target - right * first.position.distance_to(target) * tan(deg_to_rad(40.0) * 0.5) * (16.0 / 9.0) * 0.48
	spot.setup_camera_override = local_shot(spot, {"position": first.position, "target": framing, "fov": 40.0})
	reports[spot.seat_id] = {"candidates": candidates.size(), "setup": visibility(first.position, spot), "primary": visibility(first.position, spot), "secondary": visibility(second.position, spot)}
	return true


func local_shot(spot, shot: Dictionary) -> Dictionary:
	return {"position": spot.to_local(shot.position), "target": spot.to_local(shot.target), "fov": shot.fov}


func camera(spot, shot: Dictionary, label: String) -> Camera3D:
	var node: Camera3D = main._make_camera(spot.to_global(shot.position), spot.to_global(shot.target), shot.fov, false)
	node.set_meta("shot_name", label)
	node.set_meta("requires_player_visibility", true)
	node.set_meta("visibility_validated", visibility(node.global_position, spot).clear)
	return node


func segment_clear(a: Vector3, b: Vector3) -> bool:
	for bounds in lens_bounds:
		if bounds.intersects_segment(a, b) != null:
			return false
	for other in main.study_spots:
		if other == subject_spot or (other.is_available() and not mock_neighbours):
			continue
		var bounds := AABB(other.sitting_position + Vector3(-0.70, 0.65, -0.70), Vector3(1.4, 2.0, 1.4)).grow(0.16)
		if bounds.intersects_segment(a, b) != null:
			return false
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.16
	query.shape = sphere
	query.collision_mask = camera_mask
	query.transform.origin = a
	query.motion = b - a
	var fractions := get_world_3d().direct_space_state.cast_motion(query)
	return fractions[0] >= 0.999 and lens_clear(b)


func transition_route(a: Vector3, b: Vector3) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if segment_clear(a, b):
		result = [b]
	else:
		# Exit should be able to reuse the clear entry openings in reverse.
		# Recheck every segment against current occupancy, never trust a cache
		# after another character has taken a neighbouring chair.
		for saved in checked_routes:
			if a.distance_to(saved.end) > 0.55 or b.distance_to(saved.start) > 0.55: continue
			var reverse: Array[Vector3] = []
			for i in range(saved.points.size() - 2, -1, -1): reverse.append(saved.points[i])
			reverse.append(b)
			var previous := a
			var clear := true
			for point in reverse:
				clear = clear and segment_clear(previous, point)
				previous = point
			if clear:
				result = reverse
				break
		# Authored gazebo openings supplement the generic orbit search.
		for waypoint in [Vector3(0, 3.0, -10.2), Vector3(-3.6, 3.0, -14.7), Vector3(3.6, 3.0, -14.7), Vector3(0, 3.0, -18.5)]:
			if not result.is_empty(): break
			if segment_clear(a, waypoint) and segment_clear(waypoint, b):
				result = [waypoint, b]
				break
		for height in [3.2, 5.0, 8.0, 12.0]:
			if not result.is_empty(): break
			for radius in [3.0, 6.0]:
				for i in 8:
					var angle := TAU * float(i) / 8.0
					var waypoint := Vector3(b.x + cos(angle) * radius, height, b.z + sin(angle) * radius)
					if segment_clear(a, waypoint) and segment_clear(waypoint, b):
						result = [waypoint, b]
						break
				if not result.is_empty(): break
			if not result.is_empty(): break
	if result.is_empty():
		result = multi_waypoint_route(a, b)
	last_transition_clear = not result.is_empty()
	last_transition_points = result
	if result.size() > 1:
		checked_routes.append({"start": a, "end": b, "points": result.duplicate()})
		if checked_routes.size() > 128: checked_routes.pop_front()
	return result


func multi_waypoint_route(a: Vector3, b: Vector3) -> Array[Vector3]:
	# Some gazebo exits need two turns around a column AND an occupied
	# chair. A bounded visibility graph finds a short route through openings.
	var nodes: Array[Vector3] = [a]
	var middle := (a + b) * 0.5
	for height in [maxf(a.y, b.y), maxf(a.y, b.y) + 1.0]:
		for radius in [2.5, 4.8]:
			for i in 8:
				var angle := TAU * float(i) / 8.0
				var point := Vector3(middle.x + cos(angle) * radius, height, middle.z + sin(angle) * radius)
				if lens_clear(point): nodes.append(point)
	var costs: Array[float] = []
	var previous: Array[int] = []
	var closed: Array[bool] = []
	for point in nodes:
		costs.append(INF)
		previous.append(-1)
		closed.append(false)
	costs[0] = 0
	for _step in nodes.size():
		var current := -1
		var best := INF
		for i in nodes.size():
			if not closed[i] and costs[i] + nodes[i].distance_to(b) < best:
				current = i
				best = costs[i] + nodes[i].distance_to(b)
		if current < 0: break
		closed[current] = true
		if current > 0 and segment_clear(nodes[current], b):
			var route: Array[Vector3] = [b]
			while current > 0:
				route.push_front(nodes[current])
				current = previous[current]
			return route
		for i in range(1, nodes.size()):
			var cost := costs[current] + nodes[current].distance_to(nodes[i])
			if not closed[i] and cost < costs[i] and segment_clear(nodes[current], nodes[i]):
				costs[i] = cost
				previous[i] = current
	return []


func alignment_camera(spot) -> Camera3D:
	# Diagnostic only: inspect hips/feet with neighbours hidden, but never
	# put this lens inside a post/canopy or let a table conceal the cushion.
	var basis := Basis(Vector3.UP, spot.facing_yaw)
	var target: Vector3 = spot.sitting_position + Vector3.UP * 1.05
	for angle in [65, -65, 45, -45, 80, -80, 25, -25, 0]:
		for height in [1.5, 1.9, 2.3]:
			var direction := basis * (Basis(Vector3.UP, deg_to_rad(angle)) * Vector3.FORWARD)
			var position: Vector3 = spot.sitting_position + direction * 3.7 + Vector3.UP * height
			if not lens_clear(position): continue
			var clear := true
			for aim in [points(spot)[0], target, spot.sitting_position + Vector3.UP * (spot.seat_height + 0.15) + basis * Vector3.FORWARD * 0.30]:
				var query := PhysicsRayQueryParameters3D.create(position, aim, camera_mask)
				if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): clear = false
			if clear:
				return main._make_camera(position, target, 45, false)
	return camera(spot, spot.focus_camera_overrides[1], "Alignment fallback")
