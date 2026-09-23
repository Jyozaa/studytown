extends RefCounted

## Add interactions to existing furniture instances, without changing saved rooms.
static func apply(layout: Node3D, room_id: String) -> void:
	if room_id == "train":
		_expand_train_slots(layout)
		for node in layout.find_children("*", "Node3D", true, false):
			if not node is StudySpot: continue
			var spot: StudySpot = node
			if spot.seat_id.begins_with("train-right-"):
				spot.global_position.x = 2.85 + (-0.78 if spot.seat_id.ends_with("-a") else 0.78)
				var forward := Basis(Vector3.UP, spot.facing_yaw) * Vector3.FORWARD
				spot.standing_position = spot.sitting_position + forward * 1.45 - Vector3.UP * 0.05
				continue
			if not spot.seat_id.begins_with("train-left-"): continue
			if spot.seat_id.begins_with("train-left-outer-"):
				var bench_centre := roundf((spot.sitting_position.z + 15.0) / 10.0) * 10.0 - 15.0
				spot.global_position.z = bench_centre + (-0.7 if spot.seat_id.ends_with("-a") else 0.7)
			# The aisle is narrower than the player's walking capsule. Approach
			# from the open bench ends, never spawn a standing body between them.
			var standing := spot.standing_position
			standing.x = -3.6
			var centre_z := roundf((spot.sitting_position.z + 15.0) / 10.0) * 10.0 - 15.0
			standing.z = centre_z + (-1.8 if spot.sitting_position.z < centre_z else 1.8)
			spot.standing_position = standing
	if room_id != "library":
		if room_id == "train": _register_furniture(layout)
		return
	for suffix: String in ["Left", "Right"]:
		var chair := layout.find_child("RightAlcoveArmchair" + suffix, true, false) as Node3D
		if chair == null: continue
		var id := "library-alcove-armchair-" + suffix.to_lower()
		if layout.find_child(id, true, false) != null: continue
		var spot := StudySpot.new()
		spot.name = id
		layout.add_child(spot)
		var yaw := wrapf(chair.global_rotation.y + PI, -PI, PI)
		var forward := Basis(Vector3.UP, yaw) * Vector3.FORWARD
		var sitting := chair.global_position + forward * 0.62 + Vector3.UP * 0.1
		var standing := chair.global_position + forward * 1.65
		standing.y = 0.0
		spot.configure(id, standing, sitting, yaw, "Book", sitting + forward * 3.8 + Vector3.UP * 2.4,
			sitting + Vector3.UP * 1.8, "armchair", Vector3(0, 0.4, 0.12), 0.1)
		spot.seat_label = "Alcove armchair " + suffix.to_lower()
		spot.physical_seat_id = str(layout.get_path_to(chair))
		chair.set_meta("physical_seat_id", spot.physical_seat_id)
		chair.set_meta("seat_capacity", 1)
		spot.convert_to_editor_anchor()
	_register_furniture(layout)


static func _register_furniture(layout: Node3D) -> void:
	var furniture: Array[Node3D] = []
	var spots: Array[StudySpot] = []
	for node in layout.find_children("*", "Node3D", true, false):
		if node is StudySpot:
			spots.append(node)
			continue
		var path: String = node.scene_file_path.to_lower()
		var instance_path := str(layout.get_path_to(node))
		if "TrainLoopTile" in instance_path or "TrainScenery" in instance_path: continue
		if path.is_empty(): continue
		if node.has_meta("xray_exclude"): continue
		if not ("chair" in path or "bench" in path or "seat" in path or "sofa" in path or "stool" in path or "couch" in path): continue
		node.set_meta("physical_seat_id", instance_path)
		node.set_meta("seat_capacity", 0)
		furniture.append(node)
	for spot in spots:
		var closest: Node3D
		var distance := INF
		for item in furniture:
			var d := spot.sitting_position.distance_squared_to(item.global_position)
			if d < distance:
				distance = d
				closest = item
		if closest == null or distance > 2.25:
			push_error("Unmapped seating slot: " + spot.seat_id)
			continue
		spot.physical_seat_id = closest.get_meta("physical_seat_id")
		spot.slot_index = int(closest.get_meta("seat_capacity"))
		closest.set_meta("seat_capacity", spot.slot_index + 1)
	for item in furniture:
		if int(item.get_meta("seat_capacity")) == 0:
			push_error("Furniture has no usable StudySpot: " + str(item.get_meta("physical_seat_id")))


static func _expand_train_slots(layout: Node3D) -> void:
	# The four inner benches use the same two-metre model as the outer ones.
	# Keep both hips within the cushion and give each slot its own occupancy.
	for node in layout.find_children("*", "Node3D", true, false):
		if not node is StudySpot: continue
		var spot: StudySpot = node
		if not spot.seat_id.begins_with("train-left-inner-"): continue
		if spot.seat_id.ends_with("-b"): continue
		if spot.has_meta("two_slot_inventory"): continue
		spot.set_meta("two_slot_inventory", true)
		var second := StudySpot.new()
		second.name = spot.seat_id + "-b"
		layout.add_child(second)
		second.configure(spot.seat_id + "-b", spot.standing_position + Vector3(0, 0, 0.7),
			spot.sitting_position + Vector3(0, 0, 0.7), spot.facing_yaw, spot.study_type,
			spot.camera_position, spot.camera_target, spot.seat_type, spot.seated_visual_offset, spot.seat_height)
		second.slot_index = 1
		second.convert_to_editor_anchor()
		spot.global_position.z -= 0.7
		spot.slot_index = 0
