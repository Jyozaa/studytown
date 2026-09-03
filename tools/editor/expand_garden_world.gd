extends SceneTree

# StudyTown Garden world-expansion utility.
#
# This DOES NOT change the current sunset Environment or its lights.
#
# It only:
#   1. makes the playable Garden grass use the SAME tint as the current
#      ExtendedForestGround;
#   2. enlarges the existing outer grass floor substantially;
#   3. adds a 360-degree layered forest beyond the fence;
#   4. adds a distant low-poly mountain ring;
#   5. adds two stylized animated waterfalls and small receiving pools.
#
# Existing Garden props, NPCs, fence, study spots, sunset sky, sun and fill
# lighting remain untouched.
#
# A timestamped garden.tscn backup is created before saving.

const GARDEN_SCENE_PATH := "res://assets/dev_local/room_layouts/garden.tscn"
const BACKUP_DIR := "res://assets/dev_local/room_layouts/backups"

const COZY_BACKDROP_NAME := "GardenCozyBackdrop"
const EXTENDED_GROUND_NAME := "ExtendedForestGround"
const WORLD_NODE_NAME := "GardenExpandedWorld"

const GRASS_TEXTURE_PATH := "res://assets/dev_local/environment/garden_grass.jpeg"

const TREE_CANDIDATES := [
	"res://assets/dev_local/blender_generated/runtime/garden_oak_tree.glb",
	"res://assets/dev_local/environment/oak_tree.glb",
	"res://assets/dev_local/environment/big_tree.glb",
]

# Same base tint used by the current outer grass.
const MATCHED_GRASS_TINT := Color("#596947")

# Much larger than the playable ~52 x 38 m Garden.
const EXPANDED_GROUND_SIZE := Vector3(190.0, 0.16, 165.0)
const EXPANDED_GROUND_Y := -0.10

# Forest bands. The nearest band starts beyond the fence/playable area.
const INNER_FOREST_X := 33.0
const INNER_FOREST_Z := 27.0
const OUTER_FOREST_X := 47.0
const OUTER_FOREST_Z := 39.0

# Mountain horizon radius.
const MOUNTAIN_RADIUS_X := 70.0
const MOUNTAIN_RADIUS_Z := 58.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var force := "--force" in OS.get_cmdline_user_args()

	print("")
	print("# STUDYTOWN GARDEN — EXPANDED FOREST WORLD")
	print("Force rebuild GardenExpandedWorld: ", force)
	print("")

	if not FileAccess.file_exists(GARDEN_SCENE_PATH):
		_fail("Editable garden.tscn does not exist.")
		return

	var packed_garden := load(GARDEN_SCENE_PATH) as PackedScene
	if packed_garden == null:
		_fail("Could not load garden.tscn as PackedScene.")
		return

	var garden_root := packed_garden.instantiate()
	if garden_root == null or not (garden_root is Node3D):
		if garden_root != null:
			garden_root.free()
		_fail("Garden scene root is not Node3D.")
		return

	var backup_path := _backup_original()
	if backup_path.is_empty():
		garden_root.free()
		_fail("Could not create backup; Garden was not modified.")
		return

	# Keep the existing sunset environment/lights completely unchanged.
	var grass_nodes_changed := _match_inside_grass_to_outer(garden_root)
	var ground_updated := _expand_existing_outer_ground(garden_root)

	var existing_world := garden_root.get_node_or_null(WORLD_NODE_NAME)

	if existing_world != null:
		if not force:
			garden_root.free()
			_fail(
				(
					"%s already exists. Nothing else was changed. "
					+ "Use -- --force only if you intentionally want to rebuild "
					+ "the generated distant world."
				) % WORLD_NODE_NAME
			)
			return

		existing_world.get_parent().remove_child(existing_world)
		existing_world.free()

	var tree_path := _first_existing_path(TREE_CANDIDATES)
	if tree_path.is_empty():
		garden_root.free()
		_fail("No usable oak/big-tree GLB could be found.")
		return

	var tree_scene := load(tree_path) as PackedScene
	if tree_scene == null:
		garden_root.free()
		_fail("Could not load tree scene: %s" % tree_path)
		return

	var expanded_world := Node3D.new()
	expanded_world.name = WORLD_NODE_NAME
	expanded_world.set_meta("studytown_expanded_garden_world", true)
	expanded_world.set_meta("tree_source", tree_path)
	garden_root.add_child(expanded_world)
	expanded_world.owner = garden_root

	var forest_root := Node3D.new()
	forest_root.name = "LayeredForest"
	expanded_world.add_child(forest_root)
	forest_root.owner = garden_root

	var mountain_root := Node3D.new()
	mountain_root.name = "MountainRing"
	expanded_world.add_child(mountain_root)
	mountain_root.owner = garden_root

	var waterfall_root := Node3D.new()
	waterfall_root.name = "Waterfalls"
	expanded_world.add_child(waterfall_root)
	waterfall_root.owner = garden_root

	var forest_count := _build_layered_forest(
		forest_root,
		garden_root,
		tree_scene
	)

	var mountain_count := _build_mountain_ring(
		mountain_root,
		garden_root
	)

	var waterfall_count := _build_waterfalls(
		waterfall_root,
		garden_root
	)

	var repacked := PackedScene.new()
	var pack_error := repacked.pack(garden_root)
	if pack_error != OK:
		garden_root.free()
		_fail(
			"PackedScene.pack failed with error %d. Backup: %s"
			% [pack_error, backup_path]
		)
		return

	var save_error := ResourceSaver.save(
		repacked,
		GARDEN_SCENE_PATH
	)
	garden_root.free()

	if save_error != OK:
		_fail(
			"ResourceSaver.save failed with error %d. Backup: %s"
			% [save_error, backup_path]
		)
		return

	print("Interior grass nodes matched: ", grass_nodes_changed)
	print("Outer ground expanded:        ", ground_updated)
	print("Forest trees added:           ", forest_count)
	print("Mountains added:              ", mountain_count)
	print("Waterfalls added:             ", waterfall_count)
	print("Tree asset:                   ", tree_path)
	print("Backup:                       ", backup_path)
	print("")
	print("DONE")
	print("")
	print("Sunset Environment/lights were NOT changed.")
	print("")
	print("New editable hierarchy:")
	print("  GardenExpandedWorld")
	print("    LayeredForest")
	print("    MountainRing")
	print("    Waterfalls")
	print("")
	quit(0)


func _match_inside_grass_to_outer(root: Node) -> int:
	var tiles: Array[MeshInstance3D] = []
	_collect_inside_grass(root, tiles)

	if tiles.is_empty():
		push_warning("No GardenGrassTile mesh was found.")
		return 0

	var matched_material := StandardMaterial3D.new()
	matched_material.albedo_color = MATCHED_GRASS_TINT
	matched_material.roughness = 0.98
	matched_material.metallic = 0.0

	if ResourceLoader.exists(GRASS_TEXTURE_PATH):
		matched_material.albedo_texture = load(GRASS_TEXTURE_PATH)

	for tile: MeshInstance3D in tiles:
		# Keep the existing mesh/UVs and change only its visual material.
		tile.material_override = matched_material

	return tiles.size()


func _expand_existing_outer_ground(root: Node) -> bool:
	var ground := _find_node_recursive(
		root,
		EXTENDED_GROUND_NAME
	)

	if ground == null or not (ground is MeshInstance3D):
		push_warning(
			"ExtendedForestGround was not found; creating a new expanded ground."
		)
		_create_fallback_expanded_ground(
			root,
			root
		)
		return true

	var ground_mesh := ground as MeshInstance3D

	if ground_mesh.mesh is BoxMesh:
		var duplicated := ground_mesh.mesh.duplicate(true) as BoxMesh
		duplicated.size = EXPANDED_GROUND_SIZE
		ground_mesh.mesh = duplicated
	else:
		var new_mesh := BoxMesh.new()
		new_mesh.size = EXPANDED_GROUND_SIZE

		if ground_mesh.material_override != null:
			new_mesh.material = ground_mesh.material_override
		elif ground_mesh.mesh != null and ground_mesh.mesh.get_surface_count() > 0:
			new_mesh.material = ground_mesh.mesh.surface_get_material(0)

		ground_mesh.mesh = new_mesh

	ground_mesh.position.y = EXPANDED_GROUND_Y

	return true


func _create_fallback_expanded_ground(
	parent: Node,
	scene_owner: Node
) -> void:
	var backdrop := parent.get_node_or_null(
		COZY_BACKDROP_NAME
	)

	var actual_parent: Node = backdrop if backdrop != null else parent

	var ground := MeshInstance3D.new()
	ground.name = EXTENDED_GROUND_NAME
	ground.position = Vector3(0.0, EXPANDED_GROUND_Y, 0.0)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mesh := BoxMesh.new()
	mesh.size = EXPANDED_GROUND_SIZE

	var material := StandardMaterial3D.new()
	material.albedo_color = MATCHED_GRASS_TINT
	material.roughness = 0.98

	if ResourceLoader.exists(GRASS_TEXTURE_PATH):
		material.albedo_texture = load(GRASS_TEXTURE_PATH)
		material.uv1_scale = Vector3(18.0, 18.0, 18.0)

	mesh.material = material
	ground.mesh = mesh

	actual_parent.add_child(ground)
	ground.owner = scene_owner


func _build_layered_forest(
	parent: Node3D,
	scene_owner: Node,
	tree_scene: PackedScene
) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9032601

	var positions: Array[Vector3] = []

	# Near north and south rows.
	for x in range(-30, 31, 5):
		positions.append(
			Vector3(
				float(x) + rng.randf_range(-1.1, 1.1),
				0.0,
				-INNER_FOREST_Z + rng.randf_range(-1.0, 1.0)
			)
		)
		positions.append(
			Vector3(
				float(x) + rng.randf_range(-1.1, 1.1),
				0.0,
				INNER_FOREST_Z + rng.randf_range(-1.0, 1.0)
			)
		)

	# Near west/east rows.
	for z in range(-22, 23, 5):
		positions.append(
			Vector3(
				-INNER_FOREST_X + rng.randf_range(-1.0, 1.0),
				0.0,
				float(z) + rng.randf_range(-1.1, 1.1)
			)
		)
		positions.append(
			Vector3(
				INNER_FOREST_X + rng.randf_range(-1.0, 1.0),
				0.0,
				float(z) + rng.randf_range(-1.1, 1.1)
			)
		)

	# Far north/south rows.
	for x in range(-42, 43, 7):
		positions.append(
			Vector3(
				float(x) + rng.randf_range(-1.6, 1.6),
				0.0,
				-OUTER_FOREST_Z + rng.randf_range(-1.4, 1.4)
			)
		)
		positions.append(
			Vector3(
				float(x) + rng.randf_range(-1.6, 1.6),
				0.0,
				OUTER_FOREST_Z + rng.randf_range(-1.4, 1.4)
			)
		)

	# Far west/east rows.
	for z in range(-32, 33, 7):
		positions.append(
			Vector3(
				-OUTER_FOREST_X + rng.randf_range(-1.3, 1.3),
				0.0,
				float(z) + rng.randf_range(-1.6, 1.6)
			)
		)
		positions.append(
			Vector3(
				OUTER_FOREST_X + rng.randf_range(-1.3, 1.3),
				0.0,
				float(z) + rng.randf_range(-1.6, 1.6)
			)
		)

	var created := 0

	for index in range(positions.size()):
		var instance := tree_scene.instantiate()

		if instance == null or not (instance is Node3D):
			if instance != null:
				instance.free()
			continue

		var tree := instance as Node3D
		tree.name = "WorldOak_%03d" % (index + 1)
		tree.position = positions[index]
		tree.rotation.y = rng.randf_range(-PI, PI)

		var distance_from_center := Vector2(
			tree.position.x,
			tree.position.z
		).length()

		var scale_value := rng.randf_range(0.88, 1.18)

		if distance_from_center > 40.0:
			scale_value *= rng.randf_range(1.04, 1.22)

		tree.scale = tree.scale * scale_value

		tree.set_meta("studytown_world_tree", true)
		tree.set_meta("world_tree_index", index)

		parent.add_child(tree)
		tree.owner = scene_owner
		created += 1

	return created


func _build_mountain_ring(
	parent: Node3D,
	scene_owner: Node
) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9032602

	var material_near := StandardMaterial3D.new()
	material_near.albedo_color = Color("#5f655b")
	material_near.roughness = 1.0

	var material_far := StandardMaterial3D.new()
	material_far.albedo_color = Color("#686b6b")
	material_far.roughness = 1.0

	var count := 0

	# 16 low-poly peaks distributed around the distant horizon.
	for index in range(16):
		var angle := TAU * float(index) / 16.0

		var position := Vector3(
			cos(angle) * MOUNTAIN_RADIUS_X,
			0.0,
			sin(angle) * MOUNTAIN_RADIUS_Z
		)

		position.x += rng.randf_range(-4.0, 4.0)
		position.z += rng.randf_range(-3.0, 3.0)

		var mountain := MeshInstance3D.new()
		mountain.name = "Mountain_%02d" % (index + 1)
		mountain.position = position
		mountain.rotation.y = rng.randf_range(-PI, PI)

		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = rng.randf_range(8.0, 14.0)
		mesh.height = rng.randf_range(11.0, 19.0)
		mesh.radial_segments = rng.randi_range(5, 7)
		mesh.rings = 1
		mesh.material = material_near if index % 2 == 0 else material_far

		mountain.mesh = mesh
		mountain.set_meta("studytown_mountain", true)

		parent.add_child(mountain)
		mountain.owner = scene_owner
		count += 1

	# A few larger back peaks to break the otherwise even silhouette.
	var back_data := [
		[Vector3(-42.0, 0.0, -68.0), 18.0, 24.0],
		[Vector3(-5.0, 0.0, -74.0), 21.0, 28.0],
		[Vector3(36.0, 0.0, -69.0), 17.0, 23.0],
		[Vector3(-55.0, 0.0, 60.0), 16.0, 21.0],
		[Vector3(48.0, 0.0, 63.0), 19.0, 25.0],
	]

	for data in back_data:
		var mountain := MeshInstance3D.new()
		mountain.name = "Mountain_Back_%02d" % (count + 1)
		mountain.position = data[0] as Vector3
		mountain.rotation.y = rng.randf_range(-PI, PI)

		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = float(data[1])
		mesh.height = float(data[2])
		mesh.radial_segments = 6
		mesh.rings = 1
		mesh.material = material_far
		mountain.mesh = mesh

		mountain.set_meta("studytown_mountain", true)
		parent.add_child(mountain)
		mountain.owner = scene_owner
		count += 1

	return count


func _build_waterfalls(
	parent: Node3D,
	scene_owner: Node
) -> int:
	var waterfall_material := _make_waterfall_material()
	var pool_material := _make_pool_material()

	# Put them outside the playable Garden, framed by the mountain/forest layers.
	var specs := [
		{
			"name": "NorthWestWaterfall",
			"position": Vector3(-37.0, 6.2, -39.0),
			"rotation_y": 0.18,
			"size": Vector2(4.8, 11.5),
			"pool_position": Vector3(-37.0, 0.02, -33.8),
			"pool_scale": Vector3(5.7, 0.20, 3.8),
		},
		{
			"name": "EastWaterfall",
			"position": Vector3(44.0, 5.4, -7.0),
			"rotation_y": -PI * 0.50,
			"size": Vector2(4.0, 9.8),
			"pool_position": Vector3(38.8, 0.02, -7.0),
			"pool_scale": Vector3(4.8, 0.20, 3.2),
		},
	]

	var created := 0

	for spec in specs:
		var group := Node3D.new()
		group.name = str(spec.name)
		group.set_meta("studytown_waterfall", true)
		parent.add_child(group)
		group.owner = scene_owner

		var cliff := MeshInstance3D.new()
		cliff.name = "Cliff"
		cliff.position = spec.position as Vector3
		cliff.rotation.y = float(spec.rotation_y)

		var cliff_mesh := BoxMesh.new()
		cliff_mesh.size = Vector3(
			8.4,
			12.5,
			2.8
		)

		var cliff_material := StandardMaterial3D.new()
		cliff_material.albedo_color = Color("#62645a")
		cliff_material.roughness = 1.0
		cliff_mesh.material = cliff_material
		cliff.mesh = cliff_mesh

		group.add_child(cliff)
		cliff.owner = scene_owner

		var water := MeshInstance3D.new()
		water.name = "WaterfallSheet"
		water.position = (
			spec.position as Vector3
			+ Vector3(0.0, 0.0, -1.46)
		)
		water.rotation.y = float(spec.rotation_y)

		var water_mesh := QuadMesh.new()
		water_mesh.size = spec.size as Vector2
		water_mesh.material = waterfall_material
		water.mesh = water_mesh

		group.add_child(water)
		water.owner = scene_owner

		var pool := MeshInstance3D.new()
		pool.name = "ReceivingPool"
		pool.position = spec.pool_position as Vector3

		var pool_mesh := CylinderMesh.new()
		pool_mesh.top_radius = 1.0
		pool_mesh.bottom_radius = 1.0
		pool_mesh.height = 0.10
		pool_mesh.radial_segments = 28
		pool_mesh.material = pool_material
		pool.mesh = pool_mesh
		pool.scale = spec.pool_scale as Vector3

		group.add_child(pool)
		pool.owner = scene_owner

		created += 1

	return created


func _make_waterfall_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, cull_disabled;

uniform vec4 water_color : source_color = vec4(0.48, 0.78, 0.86, 0.78);

void fragment() {
	float stripe_a = sin(UV.y * 46.0 - TIME * 8.0 + sin(UV.x * 13.0) * 1.4);
	float stripe_b = sin(UV.y * 21.0 - TIME * 5.0 + UV.x * 9.0);
	float foam = smoothstep(0.45, 0.92, stripe_a * 0.5 + stripe_b * 0.25 + 0.55);

	ALBEDO = mix(water_color.rgb, vec3(0.88, 0.94, 0.94), foam * 0.35);
	ROUGHNESS = 0.20;
	METALLIC = 0.0;
	ALPHA = water_color.a * (0.72 + foam * 0.22);
}
"""

	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _make_pool_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.66, 0.72, 0.82)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.18
	material.metallic = 0.0
	return material


func _collect_inside_grass(
	node: Node,
	result: Array[MeshInstance3D]
) -> void:
	if (
		node is MeshInstance3D
		and str(node.name).begins_with("GardenGrassTile")
	):
		result.append(node as MeshInstance3D)

	for child: Node in node.get_children():
		_collect_inside_grass(child, result)


func _find_node_recursive(
	node: Node,
	target_name: String
) -> Node:
	if str(node.name) == target_name:
		return node

	for child: Node in node.get_children():
		var found := _find_node_recursive(
			child,
			target_name
		)

		if found != null:
			return found

	return null


func _first_existing_path(
	paths: Array
) -> String:
	for value in paths:
		var path := str(value)

		if ResourceLoader.exists(path):
			return path

	return ""


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
		+ "/garden_before_expanded_world_"
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
	print("No new Garden scene changes were saved by this run.")
	print("")
	quit(1)
