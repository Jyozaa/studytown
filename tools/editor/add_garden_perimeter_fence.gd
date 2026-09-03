extends SceneTree

# One-time StudyTown editor utility:
# Adds an individually editable Fence node to the existing baked Garden scene.
# Existing Garden children/transforms are left untouched.
# Before saving, it writes a timestamped backup of garden.tscn.

const GARDEN_SCENE_PATH := "res://assets/dev_local/room_layouts/garden.tscn"
const HEDGE_SCENE_PATH := "res://assets/dev_local/blender_generated/runtime/garden_hedge.glb"
const FENCE_NODE_NAME := "GardenPerimeterFence"

const ROOM_DEFINITIONS := preload("res://scripts/rooms/room_definitions.gd")

const PERIMETER_INSET := 0.55
const SOUTH_ENTRANCE_WIDTH := 6.0
const HEDGE_NOMINAL_LENGTH := 3.0
const LENGTH_OVERLAP := 1.015
const HEDGE_Y := 0.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("")
	print("# STUDYTOWN GARDEN PERIMETER FENCE")
	print("Garden: ", GARDEN_SCENE_PATH)
	print("Hedge:  ", HEDGE_SCENE_PATH)
	print("")

	if not ResourceLoader.exists(GARDEN_SCENE_PATH):
		_fail("Garden scene does not exist. Bake/open the editable rooms first.")
		return

	if not ResourceLoader.exists(HEDGE_SCENE_PATH):
		_fail("garden_hedge.glb does not exist. Convert the FenceIkegaki asset first.")
		return

	var garden_resource: PackedScene = load(GARDEN_SCENE_PATH) as PackedScene
	if garden_resource == null:
		_fail("Could not load garden.tscn as a PackedScene.")
		return

	var hedge_resource: PackedScene = load(HEDGE_SCENE_PATH) as PackedScene
	if hedge_resource == null:
		_fail("Could not load garden_hedge.glb as a PackedScene.")
		return

	var garden_root: Node = garden_resource.instantiate()
	if garden_root == null:
		_fail("Could not instantiate the Garden scene.")
		return

	if not (garden_root is Node3D):
		garden_root.free()
		_fail("Garden scene root is not a Node3D.")
		return

	if garden_root.get_node_or_null(FENCE_NODE_NAME) != null:
		garden_root.free()
		_fail("A node named '%s' already exists. Nothing was changed." % FENCE_NODE_NAME)
		return

	var room: Dictionary = ROOM_DEFINITIONS.get_room(1)
	var bounds: Vector2 = room.get("bounds", Vector2(25.2, 18.2))
	var half_x := bounds.x - PERIMETER_INSET
	var half_z := bounds.y - PERIMETER_INSET

	if half_x <= 4.0 or half_z <= 4.0:
		garden_root.free()
		_fail("Garden bounds look invalid; refusing to modify the scene.")
		return

	var backup_path := _backup_original()
	if backup_path.is_empty():
		garden_root.free()
		_fail("Could not create a backup; refusing to modify the scene.")
		return

	var fence := Node3D.new()
	fence.name = FENCE_NODE_NAME
	fence.set_meta("studytown_editable_fence", true)
	fence.set_meta("source_asset", HEDGE_SCENE_PATH)
	fence.set_meta("entrance_side", "south_positive_z")
	fence.set_meta("entrance_width", SOUTH_ENTRANCE_WIDTH)

	garden_root.add_child(fence)
	fence.owner = garden_root

	var segment_count := 0

	# North edge: full-width hedge.
	segment_count += _add_x_run(
		fence,
		garden_root,
		hedge_resource,
		-half_x,
		half_x,
		-half_z,
		"North",
		0.0
	)

	# South edge: leave a centered entrance opening.
	var entrance_half := SOUTH_ENTRANCE_WIDTH * 0.5

	segment_count += _add_x_run(
		fence,
		garden_root,
		hedge_resource,
		-half_x,
		-entrance_half,
		half_z,
		"SouthLeft",
		0.0
	)

	segment_count += _add_x_run(
		fence,
		garden_root,
		hedge_resource,
		entrance_half,
		half_x,
		half_z,
		"SouthRight",
		0.0
	)

	# West/east edges. FenceIkegaki's long axis is local X, so rotate 90 degrees.
	segment_count += _add_z_run(
		fence,
		garden_root,
		hedge_resource,
		-half_z,
		half_z,
		-half_x,
		"West",
		PI * 0.5
	)

	segment_count += _add_z_run(
		fence,
		garden_root,
		hedge_resource,
		-half_z,
		half_z,
		half_x,
		"East",
		PI * 0.5
	)

	var packed := PackedScene.new()
	var pack_error := packed.pack(garden_root)
	if pack_error != OK:
		garden_root.free()
		_fail("PackedScene.pack failed with error %d. Original remains backed up at %s" % [pack_error, backup_path])
		return

	var save_error := ResourceSaver.save(packed, GARDEN_SCENE_PATH)
	garden_root.free()

	if save_error != OK:
		_fail("ResourceSaver.save failed with error %d. Backup: %s" % [save_error, backup_path])
		return

	print("Added:  ", FENCE_NODE_NAME)
	print("Pieces: ", segment_count)
	print("Bounds: X ±%.2f, Z ±%.2f" % [half_x, half_z])
	print("South entrance opening: %.2f m" % SOUTH_ENTRANCE_WIDTH)
	print("Backup: ", backup_path)
	print("")
	print("DONE — existing Garden objects/transforms were left untouched.")
	print("Open garden.tscn and expand GardenPerimeterFence to move any piece.")
	print("")
	quit(0)


func _add_x_run(
	parent: Node3D,
	scene_owner: Node,
	hedge_resource: PackedScene,
	start_x: float,
	end_x: float,
	z: float,
	prefix: String,
	yaw: float
) -> int:
	var span := absf(end_x - start_x)
	if span < 0.05:
		return 0

	var count := maxi(1, int(ceil(span / HEDGE_NOMINAL_LENGTH)))
	var fitted_length := span / float(count)
	var local_length_scale := (fitted_length / HEDGE_NOMINAL_LENGTH) * LENGTH_OVERLAP
	var direction := 1.0 if end_x >= start_x else -1.0

	for index in range(count):
		var along := (float(index) + 0.5) * fitted_length
		var x := start_x + direction * along
		_add_segment(
			parent,
			scene_owner,
			hedge_resource,
			Vector3(x, HEDGE_Y, z),
			yaw,
			local_length_scale,
			"%s_%02d" % [prefix, index + 1],
			prefix
		)

	return count


func _add_z_run(
	parent: Node3D,
	scene_owner: Node,
	hedge_resource: PackedScene,
	start_z: float,
	end_z: float,
	x: float,
	prefix: String,
	yaw: float
) -> int:
	var span := absf(end_z - start_z)
	if span < 0.05:
		return 0

	var count := maxi(1, int(ceil(span / HEDGE_NOMINAL_LENGTH)))
	var fitted_length := span / float(count)
	var local_length_scale := (fitted_length / HEDGE_NOMINAL_LENGTH) * LENGTH_OVERLAP
	var direction := 1.0 if end_z >= start_z else -1.0

	for index in range(count):
		var along := (float(index) + 0.5) * fitted_length
		var z := start_z + direction * along
		_add_segment(
			parent,
			scene_owner,
			hedge_resource,
			Vector3(x, HEDGE_Y, z),
			yaw,
			local_length_scale,
			"%s_%02d" % [prefix, index + 1],
			prefix
		)

	return count


func _add_segment(
	parent: Node3D,
	scene_owner: Node,
	hedge_resource: PackedScene,
	world_position: Vector3,
	yaw: float,
	local_length_scale: float,
	node_name: String,
	side_name: String
) -> void:
	var instance: Node = hedge_resource.instantiate()
	if not (instance is Node3D):
		if instance != null:
			instance.free()
		return

	var hedge := instance as Node3D
	hedge.name = node_name
	hedge.position = world_position
	hedge.rotation.y = yaw

	var authored_scale := hedge.scale
	authored_scale.x *= local_length_scale
	hedge.scale = authored_scale

	hedge.set_meta("studytown_fence_segment", true)
	hedge.set_meta("fence_side", side_name)

	parent.add_child(hedge)
	hedge.owner = scene_owner


func _backup_original() -> String:
	var timestamp := Time.get_datetime_string_from_system()
	timestamp = timestamp.replace(":", "-")
	timestamp = timestamp.replace("T", "_")

	var backup_dir := "res://assets/dev_local/room_layouts/backups"
	var backup_dir_absolute := ProjectSettings.globalize_path(backup_dir)

	var mkdir_error := DirAccess.make_dir_recursive_absolute(backup_dir_absolute)
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		push_error("Could not create backup directory: %s" % backup_dir)
		return ""

	var source := FileAccess.open(GARDEN_SCENE_PATH, FileAccess.READ)
	if source == null:
		push_error("Could not open Garden scene for backup.")
		return ""

	var bytes := source.get_buffer(source.get_length())
	source.close()

	var backup_path := "%s/garden_before_fence_%s.tscn" % [backup_dir, timestamp]
	var destination := FileAccess.open(backup_path, FileAccess.WRITE)
	if destination == null:
		push_error("Could not create backup file.")
		return ""

	destination.store_buffer(bytes)
	destination.close()
	return backup_path


func _fail(message: String) -> void:
	push_error(message)
	print("")
	print("ABORTED — ", message)
	print("No Garden changes were saved.")
	print("")
	quit(1)
