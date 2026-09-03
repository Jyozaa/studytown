extends SceneTree

# StudyTown Garden natural-world replacement.
#
# This script intentionally DOES NOT modify:
#   - WorldEnvironment
#   - sunset sky
#   - DirectionalLight3D / sunset sun
#   - broad Garden fill light
#   - existing Garden props / NPCs / study spots / perimeter fence
#
# It DOES:
#   1. make the playable Garden grass use the EXACT SAME material resource as
#      ExtendedForestGround;
#   2. enlarge ExtendedForestGround;
#   3. remove the previous generated GardenExpandedWorld (brown placeholder
#      mountains / placeholder waterfalls);
#   4. create a more natural surrounding world using existing StudyTown assets:
#      - archive-derived oak trees
#      - existing scenic_mountain.glb
#      - archive-derived rocks.glb
#      - ACNH water_albedo.png for lakes + waterfalls
#
# A timestamped backup is created before garden.tscn is overwritten.

const GARDEN_SCENE_PATH := "res://assets/dev_local/room_layouts/garden.tscn"
const BACKUP_DIR := "res://assets/dev_local/room_layouts/backups"

const OLD_WORLD_NODE_NAME := "GardenExpandedWorld"
const NATURAL_WORLD_NODE_NAME := "GardenNaturalWorld"
const EXTENDED_GROUND_NAME := "ExtendedForestGround"

const WATER_TEXTURE_PATH := "res://assets/dev_local/environment/water_albedo.png"
const ROCKS_PATH := "res://assets/dev_local/environment/rocks.glb"
const SCENIC_MOUNTAIN_PATH := "res://assets/dev_local/blender_generated/runtime/scenic_mountain.glb"

const TREE_CANDIDATES := [
	"res://assets/dev_local/blender_generated/runtime/garden_oak_tree.glb",
	"res://assets/dev_local/environment/oak_tree.glb",
	"res://assets/dev_local/environment/big_tree.glb",
]

const EXPANDED_GROUND_SIZE := Vector3(230.0, 0.16, 200.0)
const EXPANDED_GROUND_Y := -0.10

# Playable Garden is roughly X ±25 / Z ±18.
const GARDEN_CLEAR_X := 31.0
const GARDEN_CLEAR_Z := 24.0

const WORLD_X := 88.0
const WORLD_Z := 74.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var force := "--force" in OS.get_cmdline_user_args()

	print("")
	print("# STUDYTOWN GARDEN — NATURAL OUTSIDE WORLD")
	print("Force rebuild natural world: ", force)
	print("")

	if not FileAccess.file_exists(GARDEN_SCENE_PATH):
		_fail("Editable garden.tscn does not exist.")
		return

	var garden_scene := load(GARDEN_SCENE_PATH) as PackedScene

	if garden_scene == null:
		_fail("Could not load garden.tscn as PackedScene.")
		return

	var garden_root := garden_scene.instantiate()

	if garden_root == null or not (garden_root is Node3D):
		if garden_root != null:
			garden_root.free()

		_fail("Garden root is not Node3D.")
		return

	var existing_natural := garden_root.get_node_or_null(
		NATURAL_WORLD_NODE_NAME
	)

	if existing_natural != null and not force:
		garden_root.free()

		_fail(
			(
				"%s already exists. Nothing was changed. "
				+ "Use -- --force only if you intentionally want to rebuild it."
			) % NATURAL_WORLD_NODE_NAME
		)
		return

	var backup_path := _backup_original()

	if backup_path.is_empty():
		garden_root.free()
		_fail("Backup creation failed; Garden was not modified.")
		return

	# Remove the old generated placeholder world from the previous pass.
	var old_world := garden_root.get_node_or_null(
		OLD_WORLD_NODE_NAME
	)

	if old_world != null:
		old_world.get_parent().remove_child(old_world)
		old_world.free()

	# If this is an intentional rerun, replace only our natural-world node.
	if existing_natural != null:
		existing_natural.get_parent().remove_child(existing_natural)
		existing_natural.free()

	var ground := _find_node_recursive(
		garden_root,
		EXTENDED_GROUND_NAME
	)

	if ground == null or not (ground is MeshInstance3D):
		garden_root.free()

		_fail(
			"ExtendedForestGround was not found. "
			+ "The cozy-sunset backdrop needs to exist first."
		)
		return

	var outer_ground := ground as MeshInstance3D
	_expand_outer_ground(outer_ground)

	var outer_material := _get_mesh_material(
		outer_ground
	)

	if outer_material == null:
		garden_root.free()

		_fail(
			"Could not read the material from ExtendedForestGround."
		)
		return

	# This is the key grass fix: both inside and outside now reference the exact
	# same material resource, not merely similar tint values.
	var matched_grass_count := _apply_exact_outer_material_to_inside_grass(
		garden_root,
		outer_material
	)

	var tree_path := _first_existing_path(
		TREE_CANDIDATES
	)

	if tree_path.is_empty():
		garden_root.free()
		_fail("No usable oak/big-tree GLB exists.")
		return

	var tree_scene := load(tree_path) as PackedScene

	if tree_scene == null:
		garden_root.free()
		_fail("Could not load tree asset: %s" % tree_path)
		return

	var mountain_scene: PackedScene = null

	if ResourceLoader.exists(SCENIC_MOUNTAIN_PATH):
		mountain_scene = load(
			SCENIC_MOUNTAIN_PATH
		) as PackedScene

	var rocks_scene: PackedScene = null

	if ResourceLoader.exists(ROCKS_PATH):
		rocks_scene = load(
			ROCKS_PATH
		) as PackedScene

	var water_texture: Texture2D = null

	if ResourceLoader.exists(WATER_TEXTURE_PATH):
		water_texture = load(
			WATER_TEXTURE_PATH
		) as Texture2D

	var natural_world := Node3D.new()
	natural_world.name = NATURAL_WORLD_NODE_NAME
	natural_world.set_meta(
		"studytown_natural_world",
		true
	)
	natural_world.set_meta(
		"sunset_lighting_modified",
		false
	)
	garden_root.add_child(natural_world)
	natural_world.owner = garden_root

	var lake_root := Node3D.new()
	lake_root.name = "Lakes"
	natural_world.add_child(lake_root)
	lake_root.owner = garden_root

	var mountain_root := Node3D.new()
	mountain_root.name = "Mountains"
	natural_world.add_child(mountain_root)
	mountain_root.owner = garden_root

	var waterfall_root := Node3D.new()
	waterfall_root.name = "Waterfalls"
	natural_world.add_child(waterfall_root)
	waterfall_root.owner = garden_root

	var forest_root := Node3D.new()
	forest_root.name = "NaturalForest"
	natural_world.add_child(forest_root)
	forest_root.owner = garden_root

	var shoreline_root := Node3D.new()
	shoreline_root.name = "ShorelineRocks"
	natural_world.add_child(shoreline_root)
	shoreline_root.owner = garden_root

	var water_material := _make_lake_material(
		water_texture
	)

	var waterfall_material := _make_waterfall_material(
		water_texture
	)

	var lakes := _build_lakes(
		lake_root,
		garden_root,
		water_material
	)

	var mountain_count := _build_asset_mountains(
		mountain_root,
		garden_root,
		mountain_scene
	)

	var waterfall_count := _build_asset_waterfalls(
		waterfall_root,
		garden_root,
		waterfall_material,
		water_material
	)

	var rock_count := _build_shoreline_rocks(
		shoreline_root,
		garden_root,
		rocks_scene
	)

	var forest_count := _build_irregular_forest(
		forest_root,
		garden_root,
		tree_scene
	)

	var packed := PackedScene.new()
	var pack_error := packed.pack(
		garden_root
	)

	if pack_error != OK:
		garden_root.free()

		_fail(
			"PackedScene.pack failed with error %d. Backup: %s"
			% [
				pack_error,
				backup_path,
			]
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
			% [
				save_error,
				backup_path,
			]
		)
		return

	print("Interior grass nodes matched exactly: ", matched_grass_count)
	print("Extended ground size:                 ", EXPANDED_GROUND_SIZE)
	print("Lakes created:                        ", lakes)
	print("Scenic mountain assets created:       ", mountain_count)
	print("Waterfalls created:                   ", waterfall_count)
	print("Shoreline rock assets created:        ", rock_count)
	print("Forest tree assets created:           ", forest_count)
	print("Tree asset:                           ", tree_path)
	print("Mountain asset available:             ", mountain_scene != null)
	print("ACNH water texture available:         ", water_texture != null)
	print("Backup:                               ", backup_path)
	print("")
	print("DONE")
	print("")
	print("Sunset Environment and lighting were NOT changed.")
	print("")
	quit(0)


func _expand_outer_ground(
	ground: MeshInstance3D
) -> void:
	if ground.mesh is BoxMesh:
		var mesh := (
			ground.mesh.duplicate(true)
			as BoxMesh
		)

		mesh.size = EXPANDED_GROUND_SIZE
		ground.mesh = mesh

	else:
		var replacement := BoxMesh.new()
		replacement.size = EXPANDED_GROUND_SIZE

		var old_material := _get_mesh_material(
			ground
		)

		if old_material != null:
			replacement.material = old_material

		ground.mesh = replacement

	ground.position.y = EXPANDED_GROUND_Y


func _apply_exact_outer_material_to_inside_grass(
	root: Node,
	outer_material: Material
) -> int:
	var inside_grass: Array[MeshInstance3D] = []
	_collect_inside_grass(
		root,
		inside_grass
	)

	for tile: MeshInstance3D in inside_grass:
		tile.material_override = outer_material

	return inside_grass.size()


func _get_mesh_material(
	mesh_instance: MeshInstance3D
) -> Material:
	if mesh_instance.material_override != null:
		return mesh_instance.material_override

	if mesh_instance.mesh == null:
		return null

	if mesh_instance.mesh is PrimitiveMesh:
		var primitive := (
			mesh_instance.mesh
			as PrimitiveMesh
		)

		if primitive.material != null:
			return primitive.material

	if mesh_instance.mesh.get_surface_count() > 0:
		return mesh_instance.mesh.surface_get_material(
			0
		)

	return null


func _build_lakes(
	parent: Node3D,
	scene_owner: Node,
	water_material: Material
) -> int:
	# Lakes are outside the playable Garden and deliberately asymmetric so study
	# camera pans see landscape rather than a uniform ring.
	var lake_specs := [
		{
			"name": "NorthWestLake",
			"center": Vector3(-47.0, 0.035, -35.0),
			"points": PackedVector2Array([
				Vector2(-11.0, -4.0),
				Vector2(-7.0, -8.0),
				Vector2(-1.0, -9.5),
				Vector2(6.5, -7.5),
				Vector2(11.0, -3.0),
				Vector2(10.0, 3.0),
				Vector2(6.0, 7.0),
				Vector2(0.0, 8.5),
				Vector2(-6.5, 6.0),
				Vector2(-10.5, 2.0),
			]),
		},
		{
			"name": "EastLake",
			"center": Vector3(49.0, 0.035, 4.0),
			"points": PackedVector2Array([
				Vector2(-8.0, -5.0),
				Vector2(-2.5, -8.0),
				Vector2(4.5, -7.0),
				Vector2(9.0, -2.5),
				Vector2(8.0, 4.0),
				Vector2(3.0, 7.0),
				Vector2(-4.0, 6.5),
				Vector2(-9.0, 2.0),
			]),
		},
		{
			"name": "SouthLake",
			"center": Vector3(-8.0, 0.035, 48.0),
			"points": PackedVector2Array([
				Vector2(-12.0, -4.5),
				Vector2(-7.0, -8.0),
				Vector2(0.0, -9.0),
				Vector2(8.0, -7.0),
				Vector2(12.5, -2.0),
				Vector2(10.0, 4.0),
				Vector2(4.0, 7.0),
				Vector2(-3.5, 7.5),
				Vector2(-10.5, 4.0),
			]),
		},
	]

	for spec in lake_specs:
		var lake := MeshInstance3D.new()
		lake.name = str(spec.name)
		lake.position = spec.center as Vector3
		lake.mesh = _make_irregular_water_mesh(
			spec.points as PackedVector2Array,
			water_material
		)
		lake.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
		lake.set_meta(
			"studytown_natural_lake",
			true
		)

		parent.add_child(lake)
		lake.owner = scene_owner

	return lake_specs.size()


func _make_irregular_water_mesh(
	points: PackedVector2Array,
	material: Material
) -> ArrayMesh:
	var mesh := ArrayMesh.new()

	if points.size() < 3:
		return mesh

	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF

	for point: Vector2 in points:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_z = minf(min_z, point.y)
		max_z = maxf(max_z, point.y)

	vertices.append(
		Vector3.ZERO
	)
	uvs.append(
		Vector2(0.5, 0.5)
	)

	for point: Vector2 in points:
		vertices.append(
			Vector3(
				point.x,
				0.0,
				point.y
			)
		)

		var u := (
			(point.x - min_x)
			/ maxf(0.001, max_x - min_x)
		)

		var v := (
			(point.y - min_z)
			/ maxf(0.001, max_z - min_z)
		)

		uvs.append(
			Vector2(u, v)
		)

	for index in range(points.size()):
		var next_index := (
			(index + 1)
			% points.size()
		)

		indices.append(0)
		indices.append(index + 1)
		indices.append(next_index + 1)

	var arrays := []
	arrays.resize(
		Mesh.ARRAY_MAX
	)
	arrays[
		Mesh.ARRAY_VERTEX
	] = vertices
	arrays[
		Mesh.ARRAY_TEX_UV
	] = uvs
	arrays[
		Mesh.ARRAY_INDEX
	] = indices

	mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES,
		arrays
	)
	mesh.surface_set_material(
		0,
		material
	)

	return mesh


func _build_asset_mountains(
	parent: Node3D,
	scene_owner: Node,
	mountain_scene: PackedScene
) -> int:
	if mountain_scene == null:
		push_warning(
			"scenic_mountain.glb is unavailable; skipping mountains."
		)
		return 0

	var rng := RandomNumberGenerator.new()
	rng.seed = 9032702

	# Broad overlapping clusters on the far horizon. Their bases are hidden by
	# the forest, so they read as mountain silhouettes rather than isolated props.
	var specs := [
		[Vector3(-63.0, -0.5, -54.0), Vector3(4.2, 3.1, 3.5)],
		[Vector3(-43.0, -0.5, -61.0), Vector3(5.3, 3.8, 4.0)],
		[Vector3(-20.0, -0.5, -66.0), Vector3(4.7, 3.4, 3.8)],
		[Vector3(4.0, -0.5, -68.0), Vector3(5.8, 4.0, 4.2)],
		[Vector3(30.0, -0.5, -65.0), Vector3(4.6, 3.4, 3.6)],
		[Vector3(55.0, -0.5, -57.0), Vector3(5.2, 3.7, 4.0)],

		[Vector3(74.0, -0.5, -30.0), Vector3(4.6, 3.3, 3.6)],
		[Vector3(77.0, -0.5, 2.0), Vector3(5.5, 3.8, 4.1)],
		[Vector3(73.0, -0.5, 31.0), Vector3(4.8, 3.5, 3.7)],

		[Vector3(49.0, -0.5, 62.0), Vector3(5.2, 3.6, 4.1)],
		[Vector3(20.0, -0.5, 67.0), Vector3(4.4, 3.3, 3.5)],
		[Vector3(-13.0, -0.5, 68.0), Vector3(5.6, 3.9, 4.3)],
		[Vector3(-44.0, -0.5, 63.0), Vector3(4.9, 3.5, 3.8)],

		[Vector3(-75.0, -0.5, 33.0), Vector3(4.6, 3.4, 3.6)],
		[Vector3(-78.0, -0.5, 2.0), Vector3(5.4, 3.8, 4.0)],
		[Vector3(-73.0, -0.5, -28.0), Vector3(4.8, 3.5, 3.8)],
	]

	var created := 0

	for index in range(specs.size()):
		var instance := mountain_scene.instantiate()

		if instance == null or not (instance is Node3D):
			if instance != null:
				instance.free()
			continue

		var mountain := instance as Node3D
		mountain.name = "ScenicMountain_%02d" % (
			index + 1
		)
		mountain.position = specs[index][0] as Vector3
		mountain.scale = (
			mountain.scale
			* (specs[index][1] as Vector3)
		)
		mountain.rotation.y = rng.randf_range(
			-0.45,
			0.45
		)
		mountain.set_meta(
			"studytown_asset_mountain",
			true
		)

		parent.add_child(mountain)
		mountain.owner = scene_owner
		created += 1

	return created


func _build_asset_waterfalls(
	parent: Node3D,
	scene_owner: Node,
	waterfall_material: Material,
	lake_material: Material
) -> int:
	# Waterfall sheets sit against distant mountain/forest clusters and descend
	# toward the corresponding lakes.
	var specs := [
		{
			"name": "NorthWestWaterfall",
			"position": Vector3(-48.0, 7.0, -49.0),
			"rotation_y": 0.05,
			"width": 4.6,
			"height": 13.0,
		},
		{
			"name": "EastWaterfall",
			"position": Vector3(63.0, 6.5, 4.0),
			"rotation_y": -PI * 0.50,
			"width": 4.0,
			"height": 11.5,
		},
	]

	for spec in specs:
		var group := Node3D.new()
		group.name = str(spec.name)
		group.set_meta(
			"studytown_natural_waterfall",
			true
		)
		parent.add_child(group)
		group.owner = scene_owner

		var sheet := MeshInstance3D.new()
		sheet.name = "WaterSheet"
		sheet.position = spec.position as Vector3
		sheet.rotation.y = float(
			spec.rotation_y
		)

		var mesh := QuadMesh.new()
		mesh.size = Vector2(
			float(spec.width),
			float(spec.height)
		)
		mesh.material = waterfall_material
		sheet.mesh = mesh
		sheet.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)

		group.add_child(sheet)
		sheet.owner = scene_owner

		# A small irregular plunge pool makes the bottom of the waterfall feel
		# connected to the landscape instead of terminating in empty space.
		var plunge := MeshInstance3D.new()
		plunge.name = "PlungePool"

		if str(spec.name) == "NorthWestWaterfall":
			plunge.position = Vector3(
				-48.0,
				0.04,
				-43.0
			)
		else:
			plunge.position = Vector3(
				57.0,
				0.04,
				4.0
			)

		plunge.mesh = _make_irregular_water_mesh(
			PackedVector2Array([
				Vector2(-4.0, -2.5),
				Vector2(0.0, -3.4),
				Vector2(4.0, -2.1),
				Vector2(4.5, 1.8),
				Vector2(0.0, 3.0),
				Vector2(-4.2, 1.6),
			]),
			lake_material
		)

		group.add_child(plunge)
		plunge.owner = scene_owner

	return specs.size()


func _build_shoreline_rocks(
	parent: Node3D,
	scene_owner: Node,
	rocks_scene: PackedScene
) -> int:
	if rocks_scene == null:
		push_warning(
			"rocks.glb unavailable; shoreline rock dressing skipped."
		)
		return 0

	var rng := RandomNumberGenerator.new()
	rng.seed = 9032703

	var positions := [
		# NW lake.
		Vector3(-58.0, 0.0, -37.0),
		Vector3(-54.0, 0.0, -43.0),
		Vector3(-47.0, 0.0, -44.5),
		Vector3(-39.0, 0.0, -42.0),
		Vector3(-36.0, 0.0, -35.0),
		Vector3(-40.0, 0.0, -28.5),
		Vector3(-48.0, 0.0, -26.5),
		Vector3(-56.0, 0.0, -30.0),

		# East lake.
		Vector3(40.0, 0.0, -2.0),
		Vector3(44.0, 0.0, -4.5),
		Vector3(51.0, 0.0, -4.5),
		Vector3(57.0, 0.0, -1.0),
		Vector3(58.0, 0.0, 5.5),
		Vector3(53.0, 0.0, 10.0),
		Vector3(45.0, 0.0, 9.5),
		Vector3(40.0, 0.0, 5.0),

		# South lake.
		Vector3(-19.0, 0.0, 44.0),
		Vector3(-13.0, 0.0, 39.5),
		Vector3(-4.0, 0.0, 39.0),
		Vector3(3.0, 0.0, 43.0),
		Vector3(4.0, 0.0, 50.0),
		Vector3(-2.0, 0.0, 55.0),
		Vector3(-11.0, 0.0, 55.5),
		Vector3(-18.0, 0.0, 51.0),
	]

	var created := 0

	for index in range(positions.size()):
		var instance := rocks_scene.instantiate()

		if instance == null or not (instance is Node3D):
			if instance != null:
				instance.free()
			continue

		var rock := instance as Node3D
		rock.name = "LakeRock_%02d" % (
			index + 1
		)
		rock.position = positions[index]
		rock.rotation.y = rng.randf_range(
			-PI,
			PI
		)

		var scale_value := rng.randf_range(
			0.65,
			1.20
		)
		rock.scale = (
			rock.scale
			* scale_value
		)
		rock.set_meta(
			"studytown_shoreline_rock",
			true
		)

		parent.add_child(rock)
		rock.owner = scene_owner
		created += 1

	return created


func _build_irregular_forest(
	parent: Node3D,
	scene_owner: Node,
	tree_scene: PackedScene
) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9032704

	var created := 0
	var attempts := 0
	var target_count := 118

	while created < target_count and attempts < 1500:
		attempts += 1

		var x := rng.randf_range(
			-WORLD_X,
			WORLD_X
		)
		var z := rng.randf_range(
			-WORLD_Z,
			WORLD_Z
		)

		# Keep the authored Garden itself open.
		if (
			absf(x) < GARDEN_CLEAR_X
			and absf(z) < GARDEN_CLEAR_Z
		):
			continue

		# Avoid filling the three main lakes with trees.
		if _inside_ellipse(
			Vector2(x, z),
			Vector2(-47.0, -35.0),
			Vector2(15.0, 12.0)
		):
			continue

		if _inside_ellipse(
			Vector2(x, z),
			Vector2(49.0, 4.0),
			Vector2(13.0, 11.0)
		):
			continue

		if _inside_ellipse(
			Vector2(x, z),
			Vector2(-8.0, 48.0),
			Vector2(16.0, 12.0)
		):
			continue

		# Avoid placing trees directly in the closest foreground corridor around
		# the Garden entrance while still maintaining a dense distant horizon.
		if (
			z > 20.0
			and z < 34.0
			and absf(x) < 10.0
		):
			continue

		var instance := tree_scene.instantiate()

		if instance == null or not (instance is Node3D):
			if instance != null:
				instance.free()
			continue

		var tree := instance as Node3D
		tree.name = "NaturalOak_%03d" % (
			created + 1
		)
		tree.position = Vector3(
			x,
			0.0,
			z
		)
		tree.rotation.y = rng.randf_range(
			-PI,
			PI
		)

		var radial := Vector2(
			x,
			z
		).length()

		var scale_value := rng.randf_range(
			0.82,
			1.18
		)

		if radial > 60.0:
			scale_value *= rng.randf_range(
				1.04,
				1.24
			)

		tree.scale = (
			tree.scale
			* scale_value
		)
		tree.set_meta(
			"studytown_natural_forest_tree",
			true
		)

		parent.add_child(tree)
		tree.owner = scene_owner
		created += 1

	return created


func _inside_ellipse(
	point: Vector2,
	center: Vector2,
	radii: Vector2
) -> bool:
	var dx := (
		(point.x - center.x)
		/ maxf(radii.x, 0.001)
	)
	var dz := (
		(point.y - center.y)
		/ maxf(radii.y, 0.001)
	)

	return (
		dx * dx
		+ dz * dz
		<= 1.0
	)


func _make_lake_material(
	water_texture: Texture2D
) -> ShaderMaterial:
	var shader := Shader.new()

	shader.code = """
shader_type spatial;
render_mode blend_mix, cull_disabled;

uniform sampler2D water_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 water_tint : source_color = vec4(0.38, 0.67, 0.71, 0.94);

void fragment() {
	vec2 uv_a = UV * 3.0 + vec2(TIME * 0.010, TIME * 0.006);
	vec2 uv_b = UV * 4.4 + vec2(-TIME * 0.006, TIME * 0.009);

	vec3 tex_a = texture(water_tex, uv_a).rgb;
	vec3 tex_b = texture(water_tex, uv_b).rgb;

	float ripple = sin((UV.x + UV.y) * 26.0 + TIME * 1.2) * 0.018;

	ALBEDO = mix(water_tint.rgb, (tex_a + tex_b) * 0.5, 0.34) + ripple;
	ROUGHNESS = 0.18;
	METALLIC = 0.0;
	ALPHA = water_tint.a;
}
"""

	var material := ShaderMaterial.new()
	material.shader = shader

	if water_texture != null:
		material.set_shader_parameter(
			"water_tex",
			water_texture
		)

	return material


func _make_waterfall_material(
	water_texture: Texture2D
) -> ShaderMaterial:
	var shader := Shader.new()

	shader.code = """
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded;

uniform sampler2D water_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 water_tint : source_color = vec4(0.58, 0.80, 0.84, 0.88);

void fragment() {
	vec2 flow_uv = vec2(
		UV.x * 2.2,
		UV.y * 3.0 - TIME * 0.50
	);

	vec3 tex = texture(water_tex, flow_uv).rgb;

	float vertical = sin(
		UV.y * 55.0
		- TIME * 10.0
		+ sin(UV.x * 14.0) * 1.5
	);

	float foam = smoothstep(
		0.58,
		0.94,
		vertical * 0.5 + 0.5
	);

	ALBEDO = mix(
		water_tint.rgb,
		vec3(0.92, 0.96, 0.95),
		foam * 0.34
	) * mix(vec3(0.92), tex + vec3(0.30), 0.22);

	ROUGHNESS = 0.12;
	ALPHA = water_tint.a;
}
"""

	var material := ShaderMaterial.new()
	material.shader = shader

	if water_texture != null:
		material.set_shader_parameter(
			"water_tex",
			water_texture
		)

	return material


func _collect_inside_grass(
	node: Node,
	result: Array[MeshInstance3D]
) -> void:
	if (
		node is MeshInstance3D
		and str(node.name).begins_with(
			"GardenGrassTile"
		)
	):
		result.append(
			node as MeshInstance3D
		)

	for child: Node in node.get_children():
		_collect_inside_grass(
			child,
			result
		)


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
	timestamp = timestamp.replace(
		":",
		"-"
	)
	timestamp = timestamp.replace(
		"T",
		"_"
	)

	var backup_path := (
		BACKUP_DIR
		+ "/garden_before_natural_world_"
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


func _fail(
	message: String
) -> void:
	push_error(message)
	print("")
	print(
		"ABORTED — ",
		message
	)
	print(
		"No new Garden scene changes were saved by this run."
	)
	print("")
	quit(1)
