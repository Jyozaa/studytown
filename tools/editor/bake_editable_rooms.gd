extends SceneTree

# One-time local room baker.
#
# It executes the CURRENT procedural room builders from scripts/core/main.gd,
# captures their actual output (including your local GLBs/materials), and saves
# four editable local .tscn files under assets/dev_local/room_layouts/.
#
# By default it refuses to overwrite an existing layout so manual Godot edits
# are safe. Use:
#
#   -- --force
#
# only when you intentionally want to regenerate every room from procedural
# code and discard local scene edits.

const OUTPUT_DIR := "res://assets/dev_local/room_layouts"

const ROOMS := [
	{
		"index": 0,
		"id": "library",
		"name": "Grand Library",
	},
	{
		"index": 1,
		"id": "garden",
		"name": "Garden Café",
	},
	{
		"index": 2,
		"id": "train",
		"name": "Scenic Train",
	},
	{
		"index": 3,
		"id": "japanese",
		"name": "Japanese Study Room",
	},
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var force: bool = "--force" in OS.get_cmdline_user_args()

	var absolute_output := ProjectSettings.globalize_path(
		OUTPUT_DIR
	)
	DirAccess.make_dir_recursive_absolute(
		absolute_output
	)

	print("")
	print("STUDYTOWN EDITABLE ROOM BAKE")
	print("============================")
	print(
		"Output: %s"
		% absolute_output
	)
	print(
		"Overwrite existing rooms: %s"
		% str(force)
	)
	print("")

	# Instantiate the ORIGINAL procedural main.gd directly. Do not instantiate
	# scenes/main/main.tscn here because that scene uses editable_main.gd after
	# this migration.
	var base_script := load(
		"res://scripts/core/main.gd"
	)
	var main := Node.new()
	main.name = "RoomBakeRuntime"
	main.set_script(base_script)
	root.add_child(main)

	# _ready() builds the menu and initializes CharacterLoader/materials.
	await process_frame

	for room_data in ROOMS:
		var room_index := int(room_data.index)
		var room_id := str(room_data.id)
		var output_path := (
			OUTPUT_DIR
			+ "/"
			+ room_id
			+ ".tscn"
		)

		if ResourceLoader.exists(output_path) and not force:
			print(
				"SKIP %s — editable scene already exists"
				% output_path
			)
			continue

		print(
			"BAKE %s -> %s"
			% [
				room_data.name,
				output_path,
			]
		)

		# build_room() synchronously produces the exact latest procedural room.
		# We capture it before the next frame so deferred barista movement etc.
		# cannot alter the authored starting transforms.
		main.current_room_name = GameState.ROOMS[room_index]
		main.build_room(room_index)

		_remove_runtime_player_and_follow_camera(
			main
		)

		_prepare_study_spots(main)
		_prepare_npcs(main)
		_tag_runtime_arrays(main)

		var layout: Node3D = Node3D.new()
		layout.name = (
			"Editable_%s"
			% str(room_data.name).replace(
				" ",
				"_"
			)
		)
		layout.set_meta(
			"studytown_room_index",
			room_index
		)
		layout.set_meta(
			"studytown_room_id",
			room_id
		)
		layout.set_meta(
			"generated_from",
			"scripts/core/main.gd"
		)

		root.add_child(layout)

		# Move every actual world node under a clean RoomLayout root while
		# preserving global transforms.
		for child in main.world_root.get_children():
			if child is Node3D:
				(child as Node3D).reparent(
					layout,
					true
				)
			else:
				child.reparent(
					layout
				)

		_add_editor_anchors(
			layout,
			main,
			room_index
		)

		_set_owner_recursive(
			layout,
			layout
		)

		var packed: PackedScene = PackedScene.new()
		var pack_error := packed.pack(layout)

		if pack_error != OK:
			push_error(
				"Could not pack %s: error %d"
				% [
					output_path,
					pack_error,
				]
			)
			layout.free()
			continue

		var save_error := ResourceSaver.save(
			packed,
			output_path
		)

		if save_error != OK:
			push_error(
				"Could not save %s: error %d"
				% [
					output_path,
					save_error,
				]
			)
		else:
			print(
				"DONE %s"
				% output_path
			)

		layout.free()

	print("")
	print("All requested rooms processed.")
	print("")
	print("Open these in Godot:")
	print(
		"  %s/library.tscn"
		% OUTPUT_DIR
	)
	print(
		"  %s/garden.tscn"
		% OUTPUT_DIR
	)
	print(
		"  %s/train.tscn"
		% OUTPUT_DIR
	)
	print(
		"  %s/japanese.tscn"
		% OUTPUT_DIR
	)
	print("")
	print(
		"Do NOT run this baker with --force "
		+ "after you start manually editing the scenes "
		+ "unless you want those edits replaced."
	)

	main.free()
	quit()


func _remove_runtime_player_and_follow_camera(
	main: Node
) -> void:
	if is_instance_valid(main.player):
		var player_parent: Node = main.player.get_parent()
		if player_parent != null:
			player_parent.remove_child(
				main.player
			)
		main.player.free()
		main.player = null
		main.player_visual = null

	if is_instance_valid(main.follow_camera_rig):
		var camera_parent: Node = (
			main.follow_camera_rig.get_parent()
		)
		if camera_parent != null:
			camera_parent.remove_child(
				main.follow_camera_rig
			)
		main.follow_camera_rig.free()
		main.follow_camera_rig = null
		main.explore_camera = null


func _prepare_study_spots(main: Node) -> void:
	for spot in main.study_spots:
		if not is_instance_valid(spot):
			continue

		spot.convert_to_editor_anchor()
		spot.add_to_group(
			"editable_study_spot",
			true
		)


func _prepare_npcs(main: Node) -> void:
	for npc in main.npcs:
		if not is_instance_valid(npc):
			continue

		npc.capture_for_editable_scene()
		npc.add_to_group(
			"editable_npc",
			true
		)


func _tag_runtime_arrays(main: Node) -> void:
	for camera in main.focus_cameras:
		if is_instance_valid(camera):
			camera.add_to_group(
				"editable_focus_camera",
				true
			)

	for camera in main.room_broll_cameras:
		if is_instance_valid(camera):
			camera.add_to_group(
				"editable_broll_camera",
				true
			)

	for scenery in main.train_scenery_nodes:
		if is_instance_valid(scenery):
			scenery.add_to_group(
				"editable_train_scenery",
				true
			)

	for water_node in main.garden_water_jet_nodes:
		if is_instance_valid(water_node):
			water_node.add_to_group(
				"editable_garden_water",
				true
			)

	for fire_node in main.garden_fire_nodes:
		if is_instance_valid(fire_node):
			fire_node.add_to_group(
				"editable_garden_fire",
				true
			)


func _add_editor_anchors(
	layout: Node3D,
	main: Node,
	room_index: int
) -> void:
	var spawn: Marker3D = Marker3D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = main.current_room_config.spawn
	spawn.add_to_group(
		"editable_player_spawn",
		true
	)
	layout.add_child(spawn)

	if room_index == 1:
		var patrol_a: Marker3D = Marker3D.new()
		patrol_a.name = "BaristaPatrolA"
		patrol_a.position = Vector3(
			-20.5,
			0.05,
			-15.15
		)
		patrol_a.set_meta(
			"patrol_index",
			0
		)
		patrol_a.add_to_group(
			"editable_barista_patrol",
			true
		)
		layout.add_child(patrol_a)

		var patrol_b: Marker3D = Marker3D.new()
		patrol_b.name = "BaristaPatrolB"
		patrol_b.position = Vector3(
			-14.5,
			0.05,
			-15.15
		)
		patrol_b.set_meta(
			"patrol_index",
			1
		)
		patrol_b.add_to_group(
			"editable_barista_patrol",
			true
		)
		layout.add_child(patrol_b)


func _set_owner_recursive(
	node: Node,
	owner_node: Node
) -> void:
	# get_children() excludes internal children by default in Godot 4.x, so
	# there is no need (and in Godot 4.7 no API) to call child.is_internal().
	# Every returned child here is a normal scene child that should be owned by
	# the editable room root so PackedScene.pack() serializes it.
	for child: Node in node.get_children():
		child.owner = owner_node
		_set_owner_recursive(
			child,
			owner_node
		)
