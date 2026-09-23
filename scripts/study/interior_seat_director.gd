extends "res://scripts/study/garden_seat_director.gd"

## Runtime-only camera audit for the existing Library/Train scene instances.
## Does not rebuild, save, rotate or relocate their furniture.
var room_id := "library"
var room_bounds := Vector2(21.2, 15.2)


func configure(owner_node) -> void:
	# Legacy furniture uses solid walking boxes through the seated torso.
	# Camera rays use the exact visible mesh triangles, not those oversized boxes.
	camera_mask = 16
	room_id = str(owner_node.current_room_config.id)
	room_bounds = owner_node.current_room_config.bounds
	super.configure(owner_node)
	if room_id == "train": main.follow_camera_rig.horizontal_camera_bounds = room_bounds - Vector2.ONE * 0.3
	name = "InteriorSeatDirector"
	var path := "res://resources/cameras/%s_seats.json" % room_id
	if FileAccess.file_exists(path):
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for spot in main.study_spots: spot.apply_camera_data(data.get(spot.seat_id, {}))
	for spot in main.study_spots:
		if spot.seat_label.is_empty(): spot.seat_label = spot.seat_id.replace("-", " ").capitalize()


func include_mesh(mesh: MeshInstance3D) -> bool:
	var path := str(main.editable_room_layout.get_path_to(mesh))
	if "TrainLoopTile" in path or "TrainScenery" in path: return false
	return super.include_mesh(mesh)


func session_position_allowed(position: Vector3) -> bool:
	return absf(position.x) <= room_bounds.x - 0.12 and absf(position.z) <= room_bounds.y - 0.12 and position.y >= 1.1 and position.y <= (3.65 if room_id == "train" else 5.2)


func candidate_angles() -> Array:
	if is_instance_valid(subject_spot) and subject_spot.seat_id.begins_with("library-window-"):
		return [-20, -35, -55, -75, -82]
	return [0, 20, -20, 35, -35, 55, -55, 75, -75, 82, -82]


func candidate_distances() -> Array:
	return [3.3, 3.7] if room_id == "train" else [3.2, 3.8, 4.5, 5.2]


func candidate_heights() -> Array:
	return [0.55, 0.85, 1.15, 1.45] if room_id == "train" else [0.55, 0.85, 1.15, 1.45, 1.75, 2.05]


func points(spot) -> Array[Vector3]:
	var targets := super.points(spot)
	# Include the lower shirt, not only the upper chest above desk dividers.
	targets[1].y -= 0.10
	targets[2].y -= 0.25
	return targets


func secondary_fov() -> float:
	return 42.0 if room_id == "train" else 44.0


func entry_position(spot) -> Vector3:
	var look: Vector3 = spot.standing_position + Vector3.UP * main.follow_camera_rig.look_height
	return main.follow_camera_rig._resolve_obstruction(look, look + main.follow_camera_rig.offset)


func segment_clear(a: Vector3, b: Vector3) -> bool:
	if room_id == "train" and (absf(a.x) > 5.0 or absf(b.x) > 5.0 or absf(a.z) > 20.8 or absf(b.z) > 20.8):
		return false
	return super.segment_clear(a, b)
