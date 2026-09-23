extends "res://scripts/core/main.gd"

const EDITABLE_ROOM_PATHS := {
	0: "res://assets/dev_local/room_layouts/library.tscn",
	1: "res://assets/dev_local/room_layouts/garden.tscn",
	2: "res://assets/dev_local/room_layouts/train.tscn",
	3: "res://assets/dev_local/room_layouts/japanese.tscn",
}

var editable_room_layout: Node3D
var editable_player_spawn: Marker3D
var editable_barista_patrol: Array[Marker3D] = []
var garden_seat_director: Node3D


func build_room(index: int) -> void:
	# All four rooms load baked editable scenes (assets/dev_local/room_layouts/).
	# Room 1's baked scene IS the Study Café (see CafeRoomMarker); the
	# procedural CafeBuilder only runs inside the room baker now. If the baked
	# scene is missing, fall back to the procedural builder.
	var editable_path: String = str(
		EDITABLE_ROOM_PATHS.get(
			index,
			""
		)
	)

	if (
		editable_path.is_empty()
		or not ResourceLoader.exists(
			editable_path
		)
	):
		super.build_room(index)
		return

	screen = Screen.ROOM
	_clear_scene()

	current_room_config = (
		RoomDefinitionsScript.get_room(
			index
		)
	)

	var packed: PackedScene
	if ResourceLoader.exists(editable_path):
		packed = preload("res://scripts/performance/room_resource_cache.gd").get_scene(editable_path)
	elif index == 1:
		super.build_room(index)
		return

	if packed == null:
		push_warning(
			"Editable StudyTown room could not be loaded: %s. "
			+ "Falling back to the procedural builder."
			% editable_path
		)
		super.build_room(index)
		return

	editable_room_layout = (
		packed.instantiate()
		as Node3D
	)

	if editable_room_layout == null:
		push_warning(
			"Editable StudyTown room root is not Node3D: %s. "
			+ "Falling back to the procedural builder."
			% editable_path
		)
		super.build_room(index)
		return

	world_root.add_child(
		editable_room_layout
	)
	# Room 1's baked scene is the Study Café (CafeRoomMarker), not the legacy
	# Garden: it ships its own sunset sky, clouds and dressing, so the garden
	# post-processing below must not run on it.
	var is_cafe: bool = (
		editable_room_layout.get_node_or_null(
			"CafeRoomMarker"
		)
		!= null
	)
	if str(current_room_config.get("id", "")) == "library":
		preload("res://scripts/world/library_glass_walls.gd").apply(editable_room_layout)
	if str(current_room_config.get("id", "")) == "garden" and not is_cafe:
		preload("res://scripts/world/sky_clouds.gd").build(editable_room_layout, 7, Vector3(70.0, 24.0, 60.0), 0.6, Color(0.35, 0.42, 0.60, 1.0))
		preload("res://scripts/rooms/garden_sunset.gd").soften_baked_light(editable_room_layout)
		preload("res://scripts/world/craftpix_garden_dressing.gd").apply(editable_room_layout)
	preload("res://scripts/study/interior_seat_inventory.gd").apply(editable_room_layout, str(current_room_config.id))

	_bind_editable_room(
		editable_room_layout
	)

	if is_cafe:
		_rebuild_cafe_traffic(
			editable_room_layout
		)

	_create_player()

	if is_instance_valid(
		editable_player_spawn
	):
		player.global_position = (
			editable_player_spawn.global_position
		)
		player.rotation.y = (
			editable_player_spawn.global_rotation.y
		)

	_create_follow_camera()
	_build_room_ui()
	_update_camera_current()
	_set_movement_enabled(true)
	if index in [0, 1, 2]:
		if index == 1 and editable_room_layout.get_node_or_null("CafeRoomMarker") != null:
			garden_seat_director = preload("res://scripts/study/cafe_seat_director.gd").new()
		else:
			garden_seat_director = preload("res://scripts/study/garden_seat_director.gd").new() if index == 1 else preload("res://scripts/study/interior_seat_director.gd").new()
		world_root.add_child(garden_seat_director)
		garden_seat_director.configure(self)
		focus_camera_director.clearance_provider = garden_seat_director
	else:
		garden_seat_director = null
		focus_camera_director.clearance_provider = null
	_install_exit_trigger(index)

	if (
		str(
			current_room_config.get(
				"id",
				""
			)
		) == "garden"
	):
		for npc in npcs:
			if not is_instance_valid(npc):
				continue

			var is_barista: bool = (
				str(
					npc.get(
						"editor_patrol_kind"
					)
				) == "garden_barista"
				or str(npc.name)
				== "NPC_GardenBarista"
			)

			if is_barista:
				npc.editor_patrol_kind = (
					"garden_barista"
				)
				npc.next_action_at = INF

				call_deferred(
					"_start_garden_barista_leg",
					npc,
					1
				)
				break


func _transition_back_to_follow_camera() -> void:
	if is_instance_valid(garden_seat_director):
		# The hidden follow rig is still damping toward the standing anchor.
		# Resolve its final pose before testing/dollying to it; otherwise the
		# moving endpoint can briefly lie inside a gazebo beam.
		var look: Vector3 = player.global_position + Vector3.UP * follow_camera_rig.look_height
		follow_camera_rig.global_position = follow_camera_rig._resolve_obstruction(look, look + follow_camera_rig.offset)
		follow_camera_rig.smoothed_look = look
		follow_camera_rig.look_at(look, Vector3.UP)
	super._transition_back_to_follow_camera()


func _ft_make_session_setup_camera(spot) -> Camera3D:
	if not is_instance_valid(garden_seat_director):
		return super._ft_make_session_setup_camera(spot)
	if is_instance_valid(session_setup_camera):
		session_setup_camera.queue_free()
	if not garden_seat_director.solve(spot):
		push_error("No validated seat camera: " + spot.seat_id)
		return null
	return garden_seat_director.camera(spot, spot.setup_camera_override, "setup / " + spot.seat_id)


func _prepare_focus_camera_pool(spot, report := true) -> void:
	if not is_instance_valid(garden_seat_director):
		super._prepare_focus_camera_pool(spot, report)
		return
	for camera in focus_cameras:
		if is_instance_valid(camera): camera.queue_free()
	focus_cameras.clear()
	if not garden_seat_director.solve(spot): return
	for i in spot.focus_camera_overrides.size():
		var camera: Camera3D = garden_seat_director.camera(spot, spot.focus_camera_overrides[i], ("primary" if i == 0 else "secondary") + " / " + spot.seat_id)
		if camera.get_meta("visibility_validated", false):
			focus_cameras.append(camera)
		else:
			camera.queue_free()


func _is_focus_shot_clear(position: Vector3, spot) -> bool:
	if is_instance_valid(garden_seat_director):
		return garden_seat_director.visibility(position, spot).clear
	return super._is_focus_shot_clear(position, spot)


func _eligible_room_broll() -> Array[Camera3D]:
	# Audited rooms use only the selected seat's validated pool. Preserve the
	# room's legacy wide cameras in the scene, but not in a personal session.
	if is_instance_valid(garden_seat_director): return []
	return super._eligible_room_broll()


func _rebuild_cafe_traffic(
	layout: Node3D
) -> void:
	# The baked CafeTraffic driver node carries a stale movers array, so it
	# is replaced with a fresh driver wired to the (possibly editor-moved)
	# traffic cars. Each car remembers its route in baked metadata; cars snap
	# back onto their routes, exactly like the procedural build.
	var stale = (
		layout.get_node_or_null(
			"CafeTraffic"
		)
	)

	if is_instance_valid(stale):
		layout.remove_child(stale)
		stale.free()

	var traffic = (
		CafeBuilderScript.CafeTraffic.new()
	)
	traffic.name = "CafeTraffic"
	layout.add_child(traffic)

	for car in layout.find_children(
		"*",
		"Node3D",
		true,
		false
	):
		if not (car as Node).is_in_group(
			"editable_cafe_traffic"
		):
			continue
		var pts: PackedVector3Array = car.get_meta(
			"traffic_pts",
			PackedVector3Array()
		)
		if pts.size() < 2:
			continue
		traffic.add_car(
			car as Node3D,
			pts,
			float(
				car.get_meta(
					"traffic_speed",
					2.2
				)
			),
			int(
				car.get_meta(
					"traffic_start",
					1
				)
			)
		)


func _bind_editable_room(
	layout: Node3D
) -> void:
	study_spots.clear()
	npcs.clear()
	focus_cameras.clear()
	room_broll_cameras.clear()
	train_scenery_nodes.clear()
	garden_water_jet_nodes.clear()
	garden_fire_nodes.clear()
	editable_barista_patrol.clear()
	editable_player_spawn = null

	var nodes: Array[Node] = [
		layout
	]

	_collect_descendants(
		layout,
		nodes
	)

	var spots_by_id: Dictionary = {}

	for node: Node in nodes:
		if node is StudySpot:
			var spot: StudySpot = (
				node as StudySpot
			)

			spot.sync_runtime_from_editor()
			study_spots.append(spot)
			spots_by_id[
				spot.seat_id
			] = spot

		if (
			node is Marker3D
			and node.is_in_group(
				"editable_player_spawn"
			)
		):
			editable_player_spawn = (
				node as Marker3D
			)

		if (
			node is Marker3D
			and node.is_in_group(
				"editable_barista_patrol"
			)
		):
			editable_barista_patrol.append(
				node as Marker3D
			)

		if node is Camera3D:
			if node.is_in_group(
				"editable_focus_camera"
			):
				focus_cameras.append(
					node as Camera3D
				)

		# Baked CollisionDebug meshes lose their transient group on save;
		# rejoin here so the in-game collision toggle works in every room.
		if node.name == "CollisionDebug":
			node.add_to_group("collision_debug")

			if node.is_in_group(
				"editable_broll_camera"
			):
				room_broll_cameras.append(
					node as Camera3D
				)

		if node is Node3D:
			if node.is_in_group(
				"editable_train_scenery"
			):
				train_scenery_nodes.append(
					node as Node3D
				)

			if node.is_in_group(
				"editable_garden_water"
			):
				garden_water_jet_nodes.append(
					node as Node3D
				)

			if node.is_in_group(
				"editable_garden_fire"
			):
				garden_fire_nodes.append(
					node as Node3D
				)

	editable_barista_patrol.sort_custom(
		func(
			a: Marker3D,
			b: Marker3D
		) -> bool:
			return (
				int(
					a.get_meta(
						"patrol_index",
						0
					)
				)
				<
				int(
					b.get_meta(
						"patrol_index",
						0
					)
				)
			)
	)

	# Capture only the controller nodes BEFORE rebinding any of them.
	#
	# rebind_runtime() deliberately replaces/frees each baked VisualRoot_* child.
	# The broad `nodes` descendant snapshot therefore becomes stale as soon as
	# the first NPC is rebound. Iterating that stale snapshot afterwards can hit
	# a freed child and make an expression such as `node is NPCController` throw:
	# "Left operand of 'is' is a previously freed instance."
	var npc_controllers: Array[NPCController] = []

	for node: Node in nodes:
		if node is NPCController:
			npc_controllers.append(
				node as NPCController
			)

	# From this point onward, iterate ONLY the stable NPCController references.
	# NPCController.rebind_runtime() may freely replace its visual children.
	for npc: NPCController in npc_controllers:
		if not is_instance_valid(npc):
			continue

		npc.rebind_runtime(
			character_loader,
			spots_by_id
		)

		# The new Garden stores only NPC identity/anchors. Public checkouts
		# without owner-local GLBs still need visible, seated fallback students.
		if current_room_config.get("id", "") == "garden" and not is_instance_valid(npc.visual):
			var fallback_visual := _create_character(npc, npcs.size() % 3, true)
			var fallback_spot = npc.assigned_spot
			character_loader.set_seated(fallback_visual, true, fallback_spot.seated_visual_offset if fallback_spot != null else Vector3.ZERO)
			npc.setup(fallback_visual, character_loader, true, npc.editor_study_kind, fallback_spot, npc.editor_occupant_id)

		if (
			npc.assigned_spot != null
			and is_instance_valid(
				npc.assigned_spot
			)
			and str(
				npc.assigned_spot.seat_type
			) == "armchair"
		):
			var armchair_animation: String = (
				"ArmchairStudyLaptop"
				if str(
					npc.assigned_spot.study_type
				) == "Laptop"
				else "ArmchairStudyBook"
			)

			_play_seated_character_animation(
				npc.visual,
				armchair_animation,
				0.0
			)

			npc.next_action_at = INF

		npcs.append(npc)


func _collect_descendants(
	node: Node,
	result: Array[Node]
) -> void:
	for child: Node in node.get_children():
		result.append(child)

		_collect_descendants(
			child,
			result
		)


func _start_garden_barista_leg(
	root,
	target_index: int
) -> void:
	if editable_barista_patrol.size() < 2:
		super._start_garden_barista_leg(
			root,
			target_index
		)
		return

	if (
		not is_instance_valid(root)
		or str(
			current_room_config.get(
				"id",
				""
			)
		) != "garden"
	):
		return

	var clamped_target: int = clampi(
		target_index,
		0,
		editable_barista_patrol.size() - 1
	)

	var marker: Marker3D = (
		editable_barista_patrol[
			clamped_target
		]
	)

	var duration: float = 3.8

	root.walk_to(
		marker.global_position,
		duration
	)

	await get_tree().create_timer(
		duration + 0.45
	).timeout

	if (
		not is_instance_valid(root)
		or str(
			current_room_config.get(
				"id",
				""
			)
		) != "garden"
	):
		return

	await get_tree().create_timer(
		0.55
	).timeout

	if is_instance_valid(root):
		_start_garden_barista_leg(
			root,
			1 - clamped_target
		)
