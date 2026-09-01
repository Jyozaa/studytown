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
	var focus_manager = root.get_node("FocusManager")
	root.add_child(main)
	await _wait_physics(3)
	var expected_npcs := [6, 5, 4, 5]
	for room_index in 4:
		main.current_room_name = GameState.ROOMS[room_index]
		main.build_room(room_index)
		await _wait_physics(150)
		_check(is_instance_valid(main.player), "Room %d has a player" % room_index)
		_check(main.player.is_on_floor(), "Room %d player becomes grounded" % room_index)
		_check(main.player.global_position.y > -0.25, "Room %d player stays above structural floor" % room_index)
		_check(main.world_root.get_node_or_null("StructuralFloor") != null, "Room %d has structural floor collider" % room_index)
		_check(main.npcs.size() == expected_npcs[room_index], "Room %d has target NPC count" % room_index)
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
		var input_directions := [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2(-1,-1).normalized(), Vector2(1,-1).normalized(), Vector2(-1,1).normalized(), Vector2(1,1).normalized()]
		var flat_forward: Vector3 = -main.explore_camera.global_basis.z
		var flat_right: Vector3 = main.explore_camera.global_basis.x
		flat_forward.y = 0.0
		flat_right.y = 0.0
		for input_direction in input_directions:
			var expected_direction: Vector3 = (flat_right.normalized() * input_direction.x + flat_forward.normalized() * -input_direction.y).normalized()
			var actual_direction: Vector3 = main.player.get_camera_relative_direction(input_direction)
			_check(actual_direction.dot(expected_direction) > 0.999, "Room %d camera-relative movement maps %s" % [room_index, input_direction])
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
		main.active_study_spot = first_spot
		main._restore_player_standing()
		_check(main.player.global_position.distance_to(first_spot.standing_position) < 0.08, "Room %d exits focus at standing anchor" % room_index)
		if not main.npcs.is_empty():
			var npc_visual: Node3D = main.npcs[0].visual
			var npc_base_y := npc_visual.position.y
			await _wait_physics(30)
			_check(absf(npc_visual.position.y - npc_base_y) < 0.001, "Room %d NPC remains vertically grounded" % room_index)
		if room_index == 2 and not main.train_scenery_nodes.is_empty():
			var scenery: Node3D = main.train_scenery_nodes[0]
			var scenery_start_z := scenery.position.z
			await _wait_physics(20)
			_check(absf(scenery.position.z - scenery_start_z) > 0.1, "Train scenery moves with parallax")
		main._set_movement_enabled(true)
		if room_index == 0:
			var local_assets_available := ResourceLoader.exists("res://assets/dev_local/characters/bob.glb")
			_check(bool(main.player_visual.get_meta("is_imported_character", false)) == local_assets_available, "Character loader selects local cats or public fallback correctly")
			if local_assets_available:
				var player_animation := _find_animation_player(main.player_visual)
				_check(player_animation != null, "Configured player exposes AnimationPlayer")
				if player_animation != null:
					for clip in ["Idle", "Walk", "StudyLaptop", "StudyBook"]:
						_check(player_animation.get_animation(clip).loop_mode == Animation.LOOP_LINEAR, "Configured player %s loops" % clip)
					for clip in ["Sit", "Wave", "Stretch"]:
						_check(player_animation.get_animation(clip).loop_mode == Animation.LOOP_NONE, "Configured player %s is one-shot" % clip)
					main.character_loader.play_animation(main.player_visual, "StudyLaptop", 0.0)
					player_animation.advance(player_animation.get_animation("StudyLaptop").length * 20.0 + 0.25)
					_check(player_animation.current_animation == "StudyLaptop" and player_animation.is_playing(), "StudyLaptop survives simulated 30+ seconds")
					main.character_loader.play_animation(main.player_visual, "StudyBook", 0.0)
					player_animation.advance(player_animation.get_animation("StudyBook").length * 12.0 + 0.25)
					_check(player_animation.current_animation == "StudyBook" and player_animation.is_playing(), "StudyBook survives simulated 30+ seconds")
					main.character_loader.play_animation(main.player_visual, "Wave", 0.0)
					player_animation.advance(player_animation.get_animation("Wave").length + 0.1)
					_check(player_animation.current_animation == "StudyBook", "Wave returns to the prior study loop")
					main.character_loader.play_animation(main.player_visual, "Stretch", 0.0)
					player_animation.advance(player_animation.get_animation("Stretch").length + 0.1)
					_check(player_animation.current_animation == "StudyBook", "Stretch returns to the prior study loop")
				for character_id in ["bob", "rosie", "raymond"]:
					var path := "res://assets/dev_local/characters/%s.glb" % character_id
					_check(ResourceLoader.exists(path), "%s local character resource exists" % character_id)
					var character_scene: PackedScene = load(path)
					var character_instance := character_scene.instantiate()
					var animation_player := _find_animation_player(character_instance)
					_check(animation_player != null, "%s exposes AnimationPlayer" % character_id)
					if animation_player != null:
						for clip in ["Idle", "Walk", "Sit", "StudyLaptop", "StudyBook", "Wave", "Stretch"]:
							_check(animation_player.has_animation(clip), "%s has %s animation" % [character_id, clip])
					character_instance.free()
			var focus_input := LineEdit.new()
			focus_input.text = "Runtime focus sequence"
			main.task_input = focus_input
			main.selected_duration = 10
			await main._begin_focus(0)
			_check(main.screen == main.Screen.FOCUS and focus_manager.active, "Study action enters active focus mode")
			_check(main.focus_cameras.size() >= 2, "Focus mode includes personal and room-authored cameras")
			focus_manager.cancel_session()
			await _wait_physics(60)
			_check(main.screen == main.Screen.ROOM, "Cancelling focus returns to room mode")
			_check(is_instance_valid(main.explore_camera) and main.explore_camera.current, "Cancelling focus restores follow camera")
			focus_input.free()
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("RUNTIME CHECKS PASSED: grounding, collision, camera-relative movement, follow/focus cameras, NPC counts, cat animation loops, train parallax")
		quit(0)
	else:
		print("RUNTIME CHECKS FAILED: %d" % failures.size())
		quit(1)
