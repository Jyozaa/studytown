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


func build_room(index: int) -> void:
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

	var packed: PackedScene = (
		load(editable_path)
		as PackedScene
	)

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

	_bind_editable_room(
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
