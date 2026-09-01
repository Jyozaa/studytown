extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func _wait_physics(frames: int) -> void:
	for _frame in frames:
		await physics_frame

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main/main.tscn")
	var main = packed.instantiate()
	root.add_child(main)
	await _wait_physics(3)
	var expected_npcs := [3, 2, 2, 2]
	for room_index in 4:
		main.current_room_name = GameState.ROOMS[room_index]
		main.build_room(room_index)
		await _wait_physics(150)
		_check(is_instance_valid(main.player), "Room %d has a player" % room_index)
		_check(main.player.is_on_floor(), "Room %d player becomes grounded" % room_index)
		_check(main.player.global_position.y > -0.25, "Room %d player stays above structural floor" % room_index)
		_check(main.world_root.get_node_or_null("StructuralFloor") != null, "Room %d has structural floor collider" % room_index)
		_check(main.npcs.size() == expected_npcs[room_index], "Room %d has calm target NPC count" % room_index)
		_check(main.study_spots.size() >= 1, "Room %d has a StudySpot" % room_index)
		_check(is_instance_valid(main.explore_camera), "Room %d has follow camera" % room_index)
		var camera_start: Vector3 = main.explore_camera.global_position
		main.player.global_position += Vector3(2.5, 0.1, 0.0)
		await _wait_physics(45)
		_check(main.explore_camera.global_position.distance_to(camera_start) > 0.4, "Room %d camera follows player translation" % room_index)
		var camera_forward_before: Vector3 = -main.explore_camera.global_basis.z
		main.player.rotation.y += PI
		await _wait_physics(8)
		var camera_forward_after: Vector3 = -main.explore_camera.global_basis.z
		_check(camera_forward_before.dot(camera_forward_after) > 0.995, "Room %d camera orientation ignores player rotation" % room_index)
		var bounds: Vector2 = main.current_room_config.bounds
		main.player.global_position = Vector3(bounds.x - 1.0, 0.7, 0.0)
		main.player.velocity = Vector3.ZERO
		Input.action_press("move_right")
		await _wait_physics(75)
		Input.action_release("move_right")
		_check(main.player.global_position.x <= bounds.x + 0.35, "Room %d world boundary blocks player" % room_index)
		_check(main.player.is_on_floor(), "Room %d remains grounded at floor edge" % room_index)
		var first_spot = main.study_spots[0]
		await main._transition_player_to_study_spot(first_spot)
		_check(main.player.global_position.distance_to(first_spot.sitting_position) < 0.08, "Room %d StudySpot aligns player to sitting anchor" % room_index)
		main._set_movement_enabled(true)
		if room_index == 0:
			var local_assets_available := ResourceLoader.exists("res://assets/dev_only_acnh/characters/alfonso.glb")
			_check(bool(main.player_visual.get_meta("is_imported_character", false)) == local_assets_available, "Character loader selects local ACNH or public fallback correctly")
			if local_assets_available:
				for character_id in ["alfonso", "gayle", "drago"]:
					var path := "res://assets/dev_only_acnh/characters/%s.glb" % character_id
					_check(ResourceLoader.exists(path), "%s local character resource exists" % character_id)
					var character_scene: PackedScene = load(path)
					var character_instance := character_scene.instantiate()
					var animation_player := _find_animation_player(character_instance)
					_check(animation_player != null, "%s exposes AnimationPlayer" % character_id)
					if animation_player != null:
						for clip in ["Idle", "Walk", "Sit", "StudyLaptop", "StudyBook", "Wave", "Stretch"]:
							_check(animation_player.has_animation(clip), "%s has %s animation" % [character_id, clip])
					character_instance.free()
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("RUNTIME CHECKS PASSED: grounding, structural collision, follow camera, room scale configuration, NPC counts, ACNH animation set")
		quit(0)
	else:
		print("RUNTIME CHECKS FAILED: %d" % failures.size())
		quit(1)
