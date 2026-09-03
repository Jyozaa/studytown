extends SceneTree

# StudyTown Garden cozy-sunset updater v2.
#
# Safe to run after v1 partially completed.
#
# By default this script:
#   - fixes/updates the Garden sunset Environment
#   - fixes/updates the broad Garden sun/fill lights
#   - reapplies the darker grass material
#   - KEEPS an existing GardenCozyBackdrop/forest intact
#   - creates the backdrop only if it does not already exist
#
# Use -- --rebuild-backdrop only if you intentionally want to delete and
# recreate GardenCozyBackdrop (this would replace manual edits inside it).

const GARDEN_SCENE_PATH := "res://assets/dev_local/room_layouts/garden.tscn"
const BACKUP_DIR := "res://assets/dev_local/room_layouts/backups"

const BACKDROP_NODE_NAME := "GardenCozyBackdrop"
const EXTENDED_GROUND_NAME := "ExtendedForestGround"
const FOREST_NODE_NAME := "ForestRing"

const GRASS_TEXTURE_PATH := "res://assets/dev_local/environment/garden_grass.jpeg"

const TREE_CANDIDATES := [
	"res://assets/dev_local/blender_generated/runtime/garden_oak_tree.glb",
	"res://assets/dev_local/environment/oak_tree.glb",
	"res://assets/dev_local/environment/big_tree.glb",
]

const INTERIOR_GRASS_TINT := Color("#87986a")
const OUTER_GRASS_TINT := Color("#596947")

const OUTER_GROUND_SIZE := Vector3(100.0, 0.16, 86.0)
const OUTER_GROUND_Y := -0.10


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var rebuild_backdrop := "--rebuild-backdrop" in OS.get_cmdline_user_args()

	print("")
	print("# STUDYTOWN GARDEN — COZY SUNSET v2")
	print("Rebuild backdrop: ", rebuild_backdrop)
	print("")

	if not FileAccess.file_exists(GARDEN_SCENE_PATH):
		_fail("Editable garden.tscn does not exist.")
		return

	var garden_packed := load(GARDEN_SCENE_PATH) as PackedScene
	if garden_packed == null:
		_fail("Could not load garden.tscn as PackedScene.")
		return

	var garden_root := garden_packed.instantiate()
	if garden_root == null or not (garden_root is Node3D):
		if garden_root != null:
			garden_root.free()
		_fail("Garden root is not a Node3D.")
		return

	var backup_path := _backup_original()
	if backup_path.is_empty():
		garden_root.free()
		_fail("Backup creation failed, so the Garden was not modified.")
		return

	var environment_count := _apply_sunset_environment(garden_root)
	var light_count := _apply_sunset_lighting(garden_root)
	var grass_tile_count := _tone_down_grass(garden_root)

	var tree_count := 0
	var backdrop_status := "kept existing"

	var existing_backdrop := garden_root.get_node_or_null(BACKDROP_NODE_NAME)

	if existing_backdrop != null and rebuild_backdrop:
		existing_backdrop.get_parent().remove_child(existing_backdrop)
		existing_backdrop.free()
		existing_backdrop = null
		backdrop_status = "rebuilt"

	if existing_backdrop == null:
		var tree_path := _first_existing_path(TREE_CANDIDATES)

		if tree_path.is_empty():
			garden_root.free()
			_fail(
				"No oak/big-tree GLB candidate exists. "
				+ "Sunset changes were NOT saved because the scene update "
				+ "is treated atomically."
			)
			return

		var tree_scene := load(tree_path) as PackedScene
		if tree_scene == null:
			garden_root.free()
			_fail("Tree resource could not be loaded: %s" % tree_path)
			return

		_create_backdrop(
			garden_root,
			tree_scene,
			tree_path
		)

		tree_count = 30

		if backdrop_status != "rebuilt":
			backdrop_status = "created"

	else:
		tree_count = _count_forest_trees(existing_backdrop)

	var packed := PackedScene.new()
	var pack_error := packed.pack(garden_root)

	if pack_error != OK:
		garden_root.free()
		_fail(
			"PackedScene.pack failed with error %d. Backup: %s"
			% [pack_error, backup_path]
		)
		return

	var save_error := ResourceSaver.save(
		packed,
		GARDEN_SCENE_PATH
	)
	garden_root.free()

	if save_error != OK:
		_fail(
			"ResourceSaver.save failed with error %d. Backup: %s"
			% [save_error, backup_path]
		)
		return

	print("Environment nodes tuned: ", environment_count)
	print("Base lights tuned:       ", light_count)
	print("Grass tile nodes tinted: ", grass_tile_count)
	print("Backdrop:                ", backdrop_status)
	print("Forest trees present:    ", tree_count)
	print("Backup:                  ", backup_path)
	print("")
	print("DONE — sunset Environment is now valid for Godot 4.7.")
	print("")
	quit(0)


func _apply_sunset_environment(root: Node) -> int:
	var environments: Array[WorldEnvironment] = []
	_collect_world_environments(root, environments)

	var world_environment: WorldEnvironment

	if environments.is_empty():
		world_environment = WorldEnvironment.new()
		world_environment.name = "GardenSunsetEnvironment"
		root.add_child(world_environment)
		world_environment.owner = root
	else:
		world_environment = environments[0]
		world_environment.name = "GardenSunsetEnvironment"

	var env: Environment

	if world_environment.environment != null:
		env = world_environment.environment.duplicate(true) as Environment
	else:
		env = Environment.new()

	var sky_material := ProceduralSkyMaterial.new()

	# Warm peach horizon with a dusky muted-violet upper sky.
	sky_material.sky_top_color = Color("#6f708f")
	sky_material.sky_horizon_color = Color("#e9a779")
	sky_material.sky_curve = 0.18
	sky_material.sky_energy_multiplier = 0.72

	sky_material.ground_bottom_color = Color("#3f443d")
	sky_material.ground_horizon_color = Color("#bd8063")
	sky_material.ground_curve = 0.22
	sky_material.ground_energy_multiplier = 0.62

	# Godot 4.7 ProceduralSkyMaterial has sun_angle_max and sun_curve, but NOT
	# sun_energy_multiplier. The visible sun receives its energy/color from the
	# DirectionalLight3D below.
	sky_material.sun_angle_max = 12.0
	sky_material.sun_curve = 0.12
	sky_material.energy_multiplier = 0.82
	sky_material.use_debanding = true

	var sky := Sky.new()
	sky.sky_material = sky_material

	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.background_energy_multiplier = 0.72

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#d6a17e")
	env.ambient_light_energy = 0.38

	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.66

	# Use property-safe setters for post effects because renderer/build support
	# can differ. Unsupported optional properties are simply skipped.
	_set_if_property(env, "glow_enabled", true)
	_set_if_property(env, "glow_intensity", 0.20)
	_set_if_property(env, "glow_bloom", 0.07)

	_set_if_property(env, "adjustment_enabled", true)
	_set_if_property(env, "adjustment_brightness", 0.92)
	_set_if_property(env, "adjustment_contrast", 1.06)
	_set_if_property(env, "adjustment_saturation", 0.90)

	world_environment.environment = env

	return 1


func _apply_sunset_lighting(root: Node) -> int:
	var changed := 0

	var sun := _find_direct_directional_light(root)

	if sun == null:
		sun = _find_directional_light(root)

	if sun == null:
		sun = DirectionalLight3D.new()
		root.add_child(sun)
		sun.owner = root

	sun.name = "GardenSunsetSun"
	sun.rotation_degrees = Vector3(-24.0, -58.0, 0.0)
	sun.light_color = Color("#ffad67")
	sun.light_energy = 0.82
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 78.0
	changed += 1

	var fill := _find_direct_omni_light(root)

	if fill != null:
		fill.name = "GardenSunsetFill"
		fill.position = Vector3(-8.0, 7.0, 7.0)
		fill.light_color = Color("#ffd0a0")
		fill.light_energy = 0.34
		fill.omni_range = 28.0
		fill.shadow_enabled = false
		changed += 1

	return changed


func _tone_down_grass(root: Node) -> int:
	var tiles: Array[MeshInstance3D] = []
	_collect_grass_tiles(root, tiles)

	if tiles.is_empty():
		push_warning(
			"No GardenGrassTile nodes found. "
			+ "Global sunset exposure will still reduce brightness."
		)
		return 0

	var material := StandardMaterial3D.new()
	material.albedo_color = INTERIOR_GRASS_TINT
	material.roughness = 0.96
	material.metallic = 0.0

	if ResourceLoader.exists(GRASS_TEXTURE_PATH):
		material.albedo_texture = load(GRASS_TEXTURE_PATH)

	for tile: MeshInstance3D in tiles:
		# Preserve the mesh's own UVs. A material_override only changes the look.
		tile.material_override = material

	return tiles.size()


func _create_backdrop(
	garden_root: Node3D,
	tree_scene: PackedScene,
	tree_path: String
) -> void:
	var backdrop := Node3D.new()
	backdrop.name = BACKDROP_NODE_NAME
	backdrop.set_meta("studytown_cozy_sunset", true)
	backdrop.set_meta("tree_source", tree_path)
	garden_root.add_child(backdrop)
	backdrop.owner = garden_root

	_add_extended_ground(
		backdrop,
		garden_root
	)

	var forest := Node3D.new()
	forest.name = FOREST_NODE_NAME
	forest.set_meta(
		"purpose",
		"hide_room_edge_and_create_forest_horizon"
	)
	backdrop.add_child(forest)
	forest.owner = garden_root

	_add_forest_ring(
		forest,
		garden_root,
		tree_scene
	)


func _add_extended_ground(
	parent: Node3D,
	scene_owner: Node
) -> void:
	var ground := MeshInstance3D.new()
	ground.name = EXTENDED_GROUND_NAME
	ground.position = Vector3(
		0.0,
		OUTER_GROUND_Y,
		0.0
	)
	ground.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)

	var mesh := BoxMesh.new()
	mesh.size = OUTER_GROUND_SIZE

	var material := StandardMaterial3D.new()
	material.albedo_color = OUTER_GRASS_TINT
	material.roughness = 0.98
	material.metallic = 0.0

	if ResourceLoader.exists(GRASS_TEXTURE_PATH):
		material.albedo_texture = load(
			GRASS_TEXTURE_PATH
		)
		material.uv1_scale = Vector3(
			12.0,
			12.0,
			12.0
		)

	mesh.material = material
	ground.mesh = mesh

	parent.add_child(ground)
	ground.owner = scene_owner


func _add_forest_ring(
	parent: Node3D,
	scene_owner: Node,
	tree_scene: PackedScene
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9032026

	var positions: Array[Vector3] = [
		# North visible horizon.
		Vector3(-28.0, 0.0, -23.3),
		Vector3(-22.0, 0.0, -23.9),
		Vector3(-16.0, 0.0, -23.1),
		Vector3(-10.0, 0.0, -24.0),
		Vector3(-4.0, 0.0, -23.4),
		Vector3(2.0, 0.0, -24.1),
		Vector3(8.0, 0.0, -23.2),
		Vector3(14.0, 0.0, -23.9),
		Vector3(20.0, 0.0, -23.1),
		Vector3(27.0, 0.0, -23.7),

		# Second north row.
		Vector3(-25.0, 0.0, -29.5),
		Vector3(-15.0, 0.0, -30.4),
		Vector3(-5.0, 0.0, -29.2),
		Vector3(5.0, 0.0, -30.2),
		Vector3(15.0, 0.0, -29.3),
		Vector3(25.0, 0.0, -30.0),

		# South.
		Vector3(-25.0, 0.0, 24.7),
		Vector3(-15.0, 0.0, 25.3),
		Vector3(-5.0, 0.0, 24.5),
		Vector3(6.0, 0.0, 25.1),
		Vector3(16.0, 0.0, 24.4),
		Vector3(26.0, 0.0, 25.2),

		# West.
		Vector3(-31.0, 0.0, -16.0),
		Vector3(-30.4, 0.0, -6.0),
		Vector3(-31.3, 0.0, 5.0),
		Vector3(-30.6, 0.0, 15.5),

		# East.
		Vector3(31.0, 0.0, -16.0),
		Vector3(30.5, 0.0, -6.0),
		Vector3(31.2, 0.0, 5.0),
		Vector3(30.7, 0.0, 15.5),
	]

	for index in range(positions.size()):
		var instance := tree_scene.instantiate()

		if instance == null or not (instance is Node3D):
			if instance != null:
				instance.free()
			continue

		var tree := instance as Node3D
		tree.name = "ForestOak_%02d" % (index + 1)
		tree.position = positions[index]

		tree.position.x += rng.randf_range(
			-0.65,
			0.65
		)
		tree.position.z += rng.randf_range(
			-0.55,
			0.55
		)
		tree.rotation.y = rng.randf_range(
			-PI,
			PI
		)

		var scale_value := rng.randf_range(
			0.92,
			1.22
		)

		if index >= 10 and index <= 15:
			scale_value *= 1.10

		tree.scale = tree.scale * scale_value

		tree.set_meta(
			"studytown_forest_tree",
			true
		)
		tree.set_meta(
			"forest_ring_index",
			index
		)

		parent.add_child(tree)
		tree.owner = scene_owner


func _count_forest_trees(
	node: Node
) -> int:
	var count := 0

	if node.has_meta("studytown_forest_tree"):
		count += 1

	for child: Node in node.get_children():
		count += _count_forest_trees(child)

	return count


func _collect_world_environments(
	node: Node,
	result: Array[WorldEnvironment]
) -> void:
	if node is WorldEnvironment:
		result.append(node as WorldEnvironment)

	for child: Node in node.get_children():
		_collect_world_environments(
			child,
			result
		)


func _collect_grass_tiles(
	node: Node,
	result: Array[MeshInstance3D]
) -> void:
	if (
		node is MeshInstance3D
		and str(node.name).begins_with(
			"GardenGrassTile"
		)
	):
		result.append(node as MeshInstance3D)

	for child: Node in node.get_children():
		_collect_grass_tiles(
			child,
			result
		)


func _find_direct_directional_light(
	root: Node
) -> DirectionalLight3D:
	for child: Node in root.get_children():
		if child is DirectionalLight3D:
			return child as DirectionalLight3D

	return null


func _find_directional_light(
	node: Node
) -> DirectionalLight3D:
	if node is DirectionalLight3D:
		return node as DirectionalLight3D

	for child: Node in node.get_children():
		var found := _find_directional_light(child)

		if found != null:
			return found

	return null


func _find_direct_omni_light(
	root: Node
) -> OmniLight3D:
	for child: Node in root.get_children():
		if child is OmniLight3D:
			return child as OmniLight3D

	return null


func _first_existing_path(
	paths: Array
) -> String:
	for path_value in paths:
		var path := str(path_value)

		if ResourceLoader.exists(path):
			return path

	return ""


func _set_if_property(
	object: Object,
	property_name: String,
	value: Variant
) -> void:
	for property_info: Dictionary in object.get_property_list():
		if str(property_info.get("name", "")) == property_name:
			object.set(property_name, value)
			return


func _backup_original() -> String:
	var absolute_backup_dir := ProjectSettings.globalize_path(
		BACKUP_DIR
	)

	var make_error := DirAccess.make_dir_recursive_absolute(
		absolute_backup_dir
	)

	if (
		make_error != OK
		and make_error != ERR_ALREADY_EXISTS
	):
		return ""

	var timestamp := Time.get_datetime_string_from_system()
	timestamp = timestamp.replace(":", "-")
	timestamp = timestamp.replace("T", "_")

	var backup_path := (
		BACKUP_DIR
		+ "/garden_before_cozy_sunset_v2_"
		+ timestamp
		+ ".tscn"
	)

	var copy_error := DirAccess.copy_absolute(
		ProjectSettings.globalize_path(
			GARDEN_SCENE_PATH
		),
		ProjectSettings.globalize_path(
			backup_path
		)
	)

	if copy_error != OK:
		return ""

	return backup_path


func _fail(message: String) -> void:
	push_error(message)
	print("")
	print("ABORTED — ", message)
	print("No Garden scene changes were saved by this run.")
	print("")
	quit(1)
