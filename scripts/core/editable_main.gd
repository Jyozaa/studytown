extends "res://scripts/core/main.gd"

# StudyTown editable-room bridge.
#
# Public/default behaviour remains the procedural room builders in main.gd.
# When a locally baked editable room exists under assets/dev_local/room_layouts,
# this subclass loads that scene instead. This keeps owner-supplied/local assets
# out of Git while letting the room be edited visually in Godot.

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
	var editable_path := str(EDITABLE_ROOM_PATHS.get(index, ""))

	if editable_path.is_empty() or not ResourceLoader.exists(editable_path):
		# Clean public fallback and first-run behaviour.
		super.build_room(index)
		return

	screen = Screen.ROOM
	_clear_scene()

	current_room_config = RoomDefinitionsScript.get_room(index)

	var packed := load(editable_path) as PackedScene
	if packed == null:
		push_warning(
			"Editable StudyTown room could not be loaded: %s. "
			+ "Falling back to the procedural builder."
			% editable_path
		)
		super.build_room(index)
		return

	editable_room_layout = packed.instantiate() as Node3D
	if editable_room_layout == null:
		push_warning(
			"Editable StudyTown room root is not Node3D: %s. "
			+ "Falling back to the procedural builder."
			% editable_path
		)
		super.build_room(index)
		return

	world_root.add_child(editable_room_layout)
	_bind_editable_room(editable_room_layout)

	_create_player()

	if is_instance_valid(editable_player_spawn):
		player.global_position = editable_player_spawn.global_position
		player.rotation.y = editable_player_spawn.global_rotation.y

	_create_follow_camera()
	_build_room_ui()
	_update_camera_current()
	_set_movement_enabled(true)

	# The moving Garden barista is intentionally rebound after all editor
	# anchors and NPCs exist.
	if str(current_room_config.get("id", "")) == "garden":
		for npc in npcs:
			if (
				is_instance_valid(npc)
				and str(npc.get("editor_patrol_kind")) == "garden_barista"
			):
				npc.next_action_at = INF
				call_deferred("_start_garden_barista_leg", npc, 1)
				break


func _bind_editable_room(layout: Node3D) -> void:
	study_spots.clear()
	npcs.clear()
	focus_cameras.clear()
	room_broll_cameras.clear()
	train_scenery_nodes.clear()
	garden_water_jet_nodes.clear()
	garden_fire_nodes.clear()
	editable_barista_patrol.clear()
	editable_player_spawn = null

	var nodes: Array[Node] = [layout]
	_collect_descendants(layout, nodes)

	# Study spots first: NPCs need a complete seat lookup before they bind.
	var spots_by_id := {}

	for node in nodes:
		if node is StudySpot:
			var spot := node as StudySpot
			spot.sync_runtime_from_editor()
			study_spots.append(spot)
			spots_by_id[spot.seat_id] = spot

		if node is Marker3D and node.is_in_group("editable_player_spawn"):
			editable_player_spawn = node as Marker3D

		if node is Marker3D and node.is_in_group("editable_barista_patrol"):
			editable_barista_patrol.append(node as Marker3D)

		if node is Camera3D:
			if node.is_in_group("editable_focus_camera"):
				focus_cameras.append(node as Camera3D)
			if node.is_in_group("editable_broll_camera"):
				room_broll_cameras.append(node as Camera3D)

		if node is Node3D:
			if node.is_in_group("editable_train_scenery"):
				train_scenery_nodes.append(node as Node3D)
			if node.is_in_group("editable_garden_water"):
				garden_water_jet_nodes.append(node as Node3D)
			if node.is_in_group("editable_garden_fire"):
				garden_fire_nodes.append(node as Node3D)

	editable_barista_patrol.sort_custom(
		func(a: Marker3D, b: Marker3D) -> bool:
			return (
				int(a.get_meta("patrol_index", 0))
				< int(b.get_meta("patrol_index", 0))
			)
	)

	# Rebind serialized NPC visuals/controllers to the live CharacterLoader and
	# to the editor-authored StudySpot nodes.
	for node in nodes:
		if node is NPCController:
			var npc := node as NPCController
			npc.rebind_runtime(character_loader, spots_by_id)

			if (
				npc.assigned_spot != null
				and is_instance_valid(npc.assigned_spot)
				and str(npc.assigned_spot.seat_type) == "armchair"
			):
				var armchair_animation := (
					"ArmchairStudyLaptop"
					if str(npc.assigned_spot.study_type) == "Laptop"
					else "ArmchairStudyBook"
				)
				_play_seated_character_animation(
					npc.visual,
					armchair_animation,
					0.0
				)
				npc.next_action_at = INF

			npcs.append(npc)


func _collect_descendants(node: Node, result: Array[Node]) -> void:
	for child in node.get_children():
		result.append(child)
		_collect_descendants(child, result)


func _start_garden_barista_leg(root, target_index: int) -> void:
	# Editable layouts get two visible Marker3D patrol points. Moving those in
	# garden.tscn changes the barista route without touching GDScript.
	if editable_barista_patrol.size() < 2:
		super._start_garden_barista_leg(root, target_index)
		return

	if (
		not is_instance_valid(root)
		or str(current_room_config.get("id", "")) != "garden"
	):
		return

	var clamped_target := clampi(
		target_index,
		0,
		editable_barista_patrol.size() - 1
	)
	var marker := editable_barista_patrol[clamped_target]
	var duration := 3.8

	root.walk_to(marker.global_position, duration)

	await get_tree().create_timer(duration + 0.45).timeout

	if (
		not is_instance_valid(root)
		or str(current_room_config.get("id", "")) != "garden"
	):
		return

	await get_tree().create_timer(0.55).timeout

	if is_instance_valid(root):
		_start_garden_barista_leg(
			root,
			1 - clamped_target
		)
