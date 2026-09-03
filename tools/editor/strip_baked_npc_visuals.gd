extends SceneTree

# Safe one-time migration for StudyTown editable rooms.
#
# Purpose:
#   - Keep each NPCController / seat / label / transform in the editable .tscn.
#   - Remove the baked Bob/Rosie/Raymond visual subtree from the .tscn.
#   - Persist editor_character_id so NPCController can recreate a fresh animated
#     cat from the original GLB at runtime.
#
# This does NOT rebuild the room and does NOT touch furniture/decor positions.
# A timestamped backup of every room scene is created before any overwrite.

const ROOM_PATHS := [
	"res://assets/dev_local/room_layouts/library.tscn",
	"res://assets/dev_local/room_layouts/garden.tscn",
	"res://assets/dev_local/room_layouts/train.tscn",
	"res://assets/dev_local/room_layouts/japanese.tscn",
]

const BACKUP_ROOT := "res://assets/dev_local/room_layouts/backups"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var dry_run: bool = "--dry-run" in OS.get_cmdline_user_args()
	var timestamp := str(int(Time.get_unix_time_from_system()))
	var backup_dir := BACKUP_ROOT + "/" + timestamp

	print("")
	print("STUDYTOWN STRIP BAKED NPC VISUALS")
	print("=================================")
	print("Dry run: %s" % str(dry_run))
	print("")

	if not dry_run:
		var backup_abs := ProjectSettings.globalize_path(backup_dir)
		var mkdir_error := DirAccess.make_dir_recursive_absolute(backup_abs)
		if mkdir_error != OK:
			push_error(
				"Could not create backup directory: %s (error %d)"
				% [backup_dir, mkdir_error]
			)
			quit(1)
			return

	var total_rooms := 0
	var total_npcs := 0
	var total_visuals_removed := 0
	var failed := false

	for room_path: String in ROOM_PATHS:
		if not FileAccess.file_exists(room_path):
			print("SKIP %s — file does not exist" % room_path)
			continue

		total_rooms += 1

		if not dry_run:
			var backup_path := backup_dir + "/" + room_path.get_file()
			var copy_error := DirAccess.copy_absolute(
				ProjectSettings.globalize_path(room_path),
				ProjectSettings.globalize_path(backup_path)
			)

			if copy_error != OK:
				push_error(
					"Backup failed for %s (error %d). "
					+ "This room will NOT be modified."
					% [room_path, copy_error]
				)
				failed = true
				continue

			print("BACKUP %s" % backup_path)

		var packed := load(room_path) as PackedScene
		if packed == null:
			push_error("Could not load %s" % room_path)
			failed = true
			continue

		var layout := packed.instantiate()
		if layout == null:
			push_error("Could not instantiate %s" % room_path)
			failed = true
			continue

		var controllers: Array[Node] = []
		_collect_npc_controllers(layout, controllers)

		var room_removed := 0

		for controller_node: Node in controllers:
			if not is_instance_valid(controller_node):
				continue

			total_npcs += 1

			var baked_visual := _find_baked_character_visual(controller_node)
			var character_id := _read_string_property(
				controller_node,
				"editor_character_id"
			)

			if character_id.is_empty() and is_instance_valid(baked_visual):
				character_id = _character_id_from_visual(baked_visual)

			if character_id.is_empty():
				push_warning(
					"Could not determine character id for %s in %s; "
					+ "leaving its visual untouched."
					% [controller_node.name, room_path]
				)
				continue

			if not _has_property(controller_node, "editor_character_id"):
				push_error(
					"%s does not expose editor_character_id. "
					+ "Replace scripts/npc/npc_controller.gd with the v2+ "
					+ "runtime version before running this migration."
					% controller_node.name
				)
				failed = true
				continue

			controller_node.set(
				"editor_character_id",
				character_id
			)

			if (
				str(controller_node.name) == "NPC_GardenBarista"
				and _has_property(controller_node, "editor_patrol_kind")
			):
				controller_node.set(
					"editor_patrol_kind",
					"garden_barista"
				)

			if is_instance_valid(baked_visual):
				var visual_parent := baked_visual.get_parent()
				if visual_parent != null:
					visual_parent.remove_child(baked_visual)
				baked_visual.free()

				room_removed += 1
				total_visuals_removed += 1

		print(
			"%s: %d NPC controller(s), %d baked visual(s) %s"
			% [
				room_path,
				controllers.size(),
				room_removed,
				"would be removed" if dry_run else "removed",
			]
		)

		if dry_run:
			layout.free()
			continue

		var clean_packed := PackedScene.new()
		var pack_error := clean_packed.pack(layout)

		if pack_error != OK:
			push_error(
				"Could not repack %s (error %d). "
				+ "Your backup is unchanged."
				% [room_path, pack_error]
			)
			failed = true
			layout.free()
			continue

		var save_error := ResourceSaver.save(
			clean_packed,
			room_path
		)

		if save_error != OK:
			push_error(
				"Could not save %s (error %d). "
				+ "Restore from %s if necessary."
				% [room_path, save_error, backup_dir]
			)
			failed = true
		else:
			print("SAVED %s" % room_path)

		layout.free()

	print("")
	print("Rooms processed: %d" % total_rooms)
	print("NPC controllers found: %d" % total_npcs)
	print(
		"Baked character visuals %s: %d"
		% [
			"that would be removed" if dry_run else "removed",
			total_visuals_removed,
		]
	)

	if not dry_run:
		print("Backups: %s" % backup_dir)

	print("")

	if dry_run:
		print(
			"Dry run complete. Run again without --dry-run "
			+ "to apply the migration."
		)
		quit(0)
		return

	if failed:
		push_error(
			"Migration completed with one or more errors. "
			+ "Review the output and use the timestamped backups if needed."
		)
		quit(1)
	else:
		print(
			"DONE. Editable room transforms were preserved; "
			+ "NPC visuals will now be created fresh at runtime."
		)
		quit(0)


func _collect_npc_controllers(
	node: Node,
	result: Array[Node]
) -> void:
	# Avoid relying on `is NPCController` here so the migration can still give
	# a useful error if the class script is temporarily in a broken state.
	if (
		node.get_script() != null
		and _has_property(node, "editor_occupant_id")
		and node.has_method("rebind_runtime")
	):
		result.append(node)

	for child: Node in node.get_children():
		_collect_npc_controllers(child, result)


func _find_baked_character_visual(
	node: Node
) -> Node3D:
	# Prefer the stable wrapper name generated by CharacterLoader.
	for child: Node in node.get_children():
		if (
			child is Node3D
			and str(child.name).begins_with("VisualRoot_")
		):
			return child as Node3D

	# Compatibility with older baked rooms.
	for child: Node in node.get_children():
		if child is Node3D:
			var child_3d := child as Node3D
			if (
				child_3d.has_meta("is_imported_character")
				or child_3d.has_meta("character_profile")
				or child_3d.has_meta("parts")
			):
				return child_3d

	for child: Node in node.get_children():
		var nested := _find_baked_character_visual(child)
		if nested != null:
			return nested

	return null


func _character_id_from_visual(
	visual: Node3D
) -> String:
	var visual_name := str(visual.name)

	if visual_name.begins_with("VisualRoot_"):
		return visual_name.trim_prefix("VisualRoot_")

	var profile_meta: Variant = visual.get_meta(
		"character_profile",
		null
	)

	if profile_meta != null:
		var profile_id: Variant = profile_meta.get(
			"character_id"
		)
		if profile_id != null:
			return str(profile_id)

	return ""


func _has_property(
	object: Object,
	property_name: String
) -> bool:
	for property_info: Dictionary in object.get_property_list():
		if str(property_info.get("name", "")) == property_name:
			return true

	return false


func _read_string_property(
	object: Object,
	property_name: String
) -> String:
	if not _has_property(object, property_name):
		return ""

	var value: Variant = object.get(property_name)
	return "" if value == null else str(value)
