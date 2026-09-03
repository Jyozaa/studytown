extends SceneTree

# StudyTown Garden — forest village + localized lighting pass.
#
# Requires runtime GLBs created by blender_garden_forest_pack.py.
#
# This script intentionally DOES NOT alter:
# - the existing sunset WorldEnvironment
# - the current DirectionalLight3D
# - the existing broad Garden fill
# - playable Garden props / NPCs / study spots / fence
# - lakes / mountains / waterfalls
#
# It adds:
# - one Garden camper structure
# - one campsite/tent structure
# - forest path lamps
# - two taller curved streetlamps
# - portable lanterns around structures
# - party-light arch at campsite
# - firepit + subtle flicker
# - warm localized window/structure lighting
#
# It hides only NaturalOak_* forest trees that overlap the two new clearings.
# Hidden trees are marked so --force can safely unhide/recalculate them.

const GARDEN_SCENE_PATH := "res://assets/dev_local/room_layouts/garden.tscn"
const BACKUP_DIR := "res://assets/dev_local/room_layouts/backups"

const VILLAGE_NODE_NAME := "GardenForestVillage"

const FLICKER_SCRIPT := preload(
	"res://scripts/world/forest_light_flicker.gd"
)

const TRAILER_PATH := (
	"res://assets/dev_local/blender_generated/runtime/"
	+ "garden_forest_trailer.glb"
)

const CAMPSITE_TENT_PATH := (
	"res://assets/dev_local/blender_generated/runtime/"
	+ "garden_campsite_tent.glb"
)

const GARDEN_LAMP_PATH := (
	"res://assets/dev_local/blender_generated/runtime/"
	+ "garden_forest_lamp.glb"
)

const STREETLAMP_PATH := (
	"res://assets/dev_local/blender_generated/runtime/"
	+ "garden_forest_streetlamp.glb"
)

const PARTY_ARCH_PATH := (
	"res://assets/dev_local/blender_generated/runtime/"
	+ "garden_party_light_arch.glb"
)

const LANTERN_PATH := (
	"res://assets/dev_local/blender_generated/runtime/"
	+ "garden_forest_lantern.glb"
)

const FIREPIT_PATH := (
	"res://assets/dev_local/blender_generated/runtime/"
	+ "garden_forest_firepit.glb"
)

const BENCH_PATH := (
	"res://assets/dev_local/blender_generated/runtime/"
	+ "garden_forest_bench.glb"
)

const TRAILER_POSITION := Vector3(-39.0, 0.0, 6.0)
const TRAILER_YAW := 1.35

const CAMPSITE_POSITION := Vector3(37.0, 0.0, -25.0)
const CAMPSITE_YAW := -0.62

const WARM_LIGHT := Color("#ffb56f")
const WINDOW_LIGHT := Color("#ffc47f")
const FIRE_LIGHT := Color("#ff8f4d")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var force := "--force" in OS.get_cmdline_user_args()

	print("")
	print("# STUDYTOWN GARDEN — FOREST VILLAGE + LOCAL LIGHTING")
	print("Force rebuild: ", force)
	print("")

	for required_path: String in [
		TRAILER_PATH,
		CAMPSITE_TENT_PATH,
		GARDEN_LAMP_PATH,
		STREETLAMP_PATH,
		PARTY_ARCH_PATH,
		LANTERN_PATH,
		FIREPIT_PATH,
	]:
		if not ResourceLoader.exists(required_path):
			_fail(
				"Missing runtime asset: %s"
				% required_path
			)
			return

	if not FileAccess.file_exists(GARDEN_SCENE_PATH):
		_fail("Editable garden.tscn does not exist.")
		return

	var packed := load(
		GARDEN_SCENE_PATH
	) as PackedScene

	if packed == null:
		_fail("Could not load garden.tscn.")
		return

	var garden_root := packed.instantiate()

	if garden_root == null or not (garden_root is Node3D):
		if garden_root != null:
			garden_root.free()

		_fail("Garden scene root is not Node3D.")
		return

	var existing := garden_root.get_node_or_null(
		VILLAGE_NODE_NAME
	)

	if existing != null and not force:
		garden_root.free()

		_fail(
			(
				"%s already exists. "
				+ "Use -- --force only if you intentionally "
				+ "want to rebuild the generated forest village."
			) % VILLAGE_NODE_NAME
		)
		return

	var backup_path := _backup_original()

	if backup_path.is_empty():
		garden_root.free()
		_fail("Could not create backup.")
		return

	# Restore only trees hidden by a previous run before rebuilding.
	_restore_village_hidden_trees(
		garden_root
	)

	if existing != null:
		existing.get_parent().remove_child(
			existing
		)
		existing.free()

	var village := Node3D.new()
	village.name = VILLAGE_NODE_NAME
	village.set_meta(
		"studytown_forest_village",
		true
	)

	garden_root.add_child(village)
	village.owner = garden_root

	var structures := Node3D.new()
	structures.name = "Structures"
	village.add_child(structures)
	structures.owner = garden_root

	var forest_lamps := Node3D.new()
	forest_lamps.name = "ForestLamps"
	village.add_child(forest_lamps)
	forest_lamps.owner = garden_root

	var campsite := Node3D.new()
	campsite.name = "CampsiteDetails"
	village.add_child(campsite)
	campsite.owner = garden_root

	var ambient_pockets := Node3D.new()
	ambient_pockets.name = "AmbientLightPockets"
	village.add_child(ambient_pockets)
	ambient_pockets.owner = garden_root

	var trailer_scene := load(
		TRAILER_PATH
	) as PackedScene

	var campsite_scene := load(
		CAMPSITE_TENT_PATH
	) as PackedScene

	var garden_lamp_scene := load(
		GARDEN_LAMP_PATH
	) as PackedScene

	var streetlamp_scene := load(
		STREETLAMP_PATH
	) as PackedScene

	var party_arch_scene := load(
		PARTY_ARCH_PATH
	) as PackedScene

	var lantern_scene := load(
		LANTERN_PATH
	) as PackedScene

	var firepit_scene := load(
		FIREPIT_PATH
	) as PackedScene

	var bench_scene: PackedScene = null

	if ResourceLoader.exists(BENCH_PATH):
		bench_scene = load(
			BENCH_PATH
		) as PackedScene

	var hidden_trees := 0

	hidden_trees += _hide_trees_in_radius(
		garden_root,
		TRAILER_POSITION,
		9.2
	)

	hidden_trees += _hide_trees_in_radius(
		garden_root,
		CAMPSITE_POSITION,
		9.5
	)

	var trailer := _add_asset(
		structures,
		garden_root,
		trailer_scene,
		"ForestTrailer",
		TRAILER_POSITION,
		TRAILER_YAW
	)

	var tent := _add_asset(
		structures,
		garden_root,
		campsite_scene,
		"CampsiteTent",
		CAMPSITE_POSITION,
		CAMPSITE_YAW
	)

	if trailer == null or tent == null:
		garden_root.free()
		_fail("Could not instantiate one of the two main structures.")
		return

	# Window / structure glow. These are deliberately local rather than a global
	# exposure increase, which keeps the sunset contrast intact.
	_add_omni(
		structures,
		garden_root,
		"TrailerWarmWindowLight",
		TRAILER_POSITION + Vector3(0.5, 2.0, 0.2),
		WINDOW_LIGHT,
		1.18,
		8.0,
		false
	)

	_add_omni(
		structures,
		garden_root,
		"CampsiteWarmInteriorLight",
		CAMPSITE_POSITION + Vector3(-0.2, 1.8, 0.5),
		WINDOW_LIGHT,
		1.05,
		7.0,
		false
	)

	# Main low forest lamps.
	var garden_lamp_positions := [
		Vector3(-28.5, 0.0, 5.5),
		Vector3(-33.3, 0.0, 5.8),
		Vector3(-37.0, 0.0, 6.0),

		Vector3(27.8, 0.0, -18.0),
		Vector3(31.8, 0.0, -21.0),
		Vector3(35.0, 0.0, -23.5),

		Vector3(-14.0, 0.0, -24.7),
		Vector3(13.5, 0.0, -24.4),
	]

	for index in range(
		garden_lamp_positions.size()
	):
		_add_lit_asset(
			forest_lamps,
			garden_root,
			garden_lamp_scene,
			"GardenLamp_%02d" % (index + 1),
			garden_lamp_positions[index],
			0.0,
			Vector3(0.0, 1.28, 0.0),
			WARM_LIGHT,
			0.72,
			5.4,
			false,
			false,
			float(index) * 0.51
		)

	# Taller lamps mark the two destination clearings.
	_add_lit_asset(
		forest_lamps,
		garden_root,
		streetlamp_scene,
		"TrailerStreetlamp",
		Vector3(-34.2, 0.0, 10.0),
		0.20,
		Vector3(0.0, 3.03, 0.0),
		WARM_LIGHT,
		1.05,
		8.2,
		true,
		false,
		0.2
	)

	_add_lit_asset(
		forest_lamps,
		garden_root,
		streetlamp_scene,
		"CampsiteStreetlamp",
		Vector3(32.8, 0.0, -28.0),
		-0.35,
		Vector3(0.0, 3.03, 0.0),
		WARM_LIGHT,
		1.05,
		8.2,
		true,
		false,
		1.1
	)

	# Camper lanterns.
	for lantern_data in [
		[
			Vector3(-42.7, 0.0, 3.0),
			0.2,
		],
		[
			Vector3(-35.5, 0.0, 4.1),
			-0.5,
		],
	]:
		_add_lit_asset(
			forest_lamps,
			garden_root,
			lantern_scene,
			"TrailerLantern_%02d"
			% (
				forest_lamps.get_child_count()
				+ 1
			),
			lantern_data[0],
			float(lantern_data[1]),
			Vector3(0.0, 0.43, 0.0),
			WARM_LIGHT,
			0.52,
			3.8,
			false,
			true,
			randf() * 5.0
		)

	# Campsite lanterns.
	for lantern_data in [
		[
			Vector3(33.6, 0.0, -23.2),
			0.4,
		],
		[
			Vector3(40.8, 0.0, -27.8),
			-0.4,
		],
	]:
		_add_lit_asset(
			campsite,
			garden_root,
			lantern_scene,
			"CampsiteLantern_%02d"
			% (
				campsite.get_child_count()
				+ 1
			),
			lantern_data[0],
			float(lantern_data[1]),
			Vector3(0.0, 0.43, 0.0),
			WARM_LIGHT,
			0.55,
			3.9,
			false,
			true,
			randf() * 5.0
		)

	# Party-light entrance to the campsite clearing.
	var arch := _add_asset(
		campsite,
		garden_root,
		party_arch_scene,
		"CampsitePartyLightArch",
		Vector3(30.8, 0.0, -20.0),
		-0.62
	)

	if arch != null:
		for local_offset: Vector3 in [
			Vector3(-1.0, 2.55, 0.0),
			Vector3(0.0, 2.75, 0.0),
			Vector3(1.0, 2.55, 0.0),
		]:
			_add_local_omni(
				arch,
				garden_root,
				"PartyBulbLight",
				local_offset,
				WARM_LIGHT,
				0.34,
				4.0,
				false
			)

	# Firepit with more noticeable, but still restrained, flicker.
	var firepit := _add_asset(
		campsite,
		garden_root,
		firepit_scene,
		"CampsiteFirepit",
		Vector3(40.8, 0.0, -20.8),
		0.0
	)

	if firepit != null:
		var fire_light := _add_local_omni(
			firepit,
			garden_root,
			"FirepitLight",
			Vector3(0.0, 0.72, 0.0),
			FIRE_LIGHT,
			1.28,
			6.8,
			true
		)

		if fire_light != null:
			fire_light.set_script(
				FLICKER_SCRIPT
			)
			fire_light.set(
				"energy_variation",
				0.12
			)
			fire_light.set(
				"speed",
				4.1
			)

	# Optional benches make the two areas feel inhabited without adding another
	# major structure.
	if bench_scene != null:
		_add_asset(
			structures,
			garden_root,
			bench_scene,
			"TrailerBench",
			Vector3(-35.5, 0.0, 10.6),
			-1.15
		)

		_add_asset(
			campsite,
			garden_root,
			bench_scene,
			"CampsiteBench",
			Vector3(43.0, 0.0, -23.3),
			2.45
		)

	# Very low-energy pockets prevent the deep forest from becoming a flat black
	# wall between visible lamps. They are intentionally weak and shadowless.
	for pocket_data in [
		[
			Vector3(-48.0, 3.0, 19.0),
			Color("#cf9b70"),
		],
		[
			Vector3(46.0, 3.0, -31.0),
			Color("#d0a27a"),
		],
		[
			Vector3(3.0, 3.5, -33.0),
			Color("#b99a78"),
		],
	]:
		_add_omni(
			ambient_pockets,
			garden_root,
			"ForestAmbientPocket",
			pocket_data[0],
			pocket_data[1],
			0.16,
			15.0,
			false
		)

	var repacked := PackedScene.new()
	var pack_error := repacked.pack(
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
		repacked,
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

	print("Main structures added:       2")
	print("Forest trees hidden:         ", hidden_trees)
	print("Garden path lamps added:     ", garden_lamp_positions.size())
	print("Tall streetlamps added:      2")
	print("Portable lanterns added:     4")
	print("Party-light arch added:      1")
	print("Firepit added:               1")
	print("Ambient forest pockets:      3")
	print("Backup:                      ", backup_path)
	print("")
	print("DONE")
	print("")
	print("Existing sunset Environment and base lights were NOT modified.")
	print("")
	quit(0)


func _add_asset(
	parent: Node3D,
	scene_owner: Node,
	scene: PackedScene,
	node_name: String,
	position: Vector3,
	yaw: float
) -> Node3D:
	if scene == null:
		return null

	var instance := scene.instantiate()

	if instance == null or not (instance is Node3D):
		if instance != null:
			instance.free()

		return null

	var node := instance as Node3D
	node.name = node_name
	node.position = position
	node.rotation.y = yaw

	parent.add_child(node)
	node.owner = scene_owner

	return node


func _add_lit_asset(
	parent: Node3D,
	scene_owner: Node,
	scene: PackedScene,
	node_name: String,
	position: Vector3,
	yaw: float,
	local_light_position: Vector3,
	color: Color,
	energy: float,
	light_range: float,
	shadows: bool,
	flicker: bool,
	phase: float
) -> Node3D:
	var asset := _add_asset(
		parent,
		scene_owner,
		scene,
		node_name,
		position,
		yaw
	)

	if asset == null:
		return null

	var light := _add_local_omni(
		asset,
		scene_owner,
		"WarmLight",
		local_light_position,
		color,
		energy,
		light_range,
		shadows
	)

	if light != null and flicker:
		light.set_script(
			FLICKER_SCRIPT
		)
		light.set(
			"energy_variation",
			0.035
		)
		light.set(
			"speed",
			2.2
		)
		light.set(
			"phase",
			phase
		)

	return asset


func _add_local_omni(
	parent: Node3D,
	scene_owner: Node,
	node_name: String,
	local_position: Vector3,
	color: Color,
	energy: float,
	light_range: float,
	shadows: bool
) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = local_position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = shadows

	parent.add_child(light)
	light.owner = scene_owner

	return light


func _add_omni(
	parent: Node3D,
	scene_owner: Node,
	node_name: String,
	position: Vector3,
	color: Color,
	energy: float,
	light_range: float,
	shadows: bool
) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = shadows

	parent.add_child(light)
	light.owner = scene_owner

	return light


func _hide_trees_in_radius(
	root: Node,
	center: Vector3,
	radius: float
) -> int:
	var hidden := 0
	var trees: Array[Node3D] = []

	_collect_natural_trees(
		root,
		trees
	)

	for tree: Node3D in trees:
		var delta := Vector2(
			tree.global_position.x - center.x,
			tree.global_position.z - center.z
		)

		if delta.length() > radius:
			continue

		tree.visible = false
		tree.set_meta(
			"studytown_hidden_for_forest_village",
			true
		)
		hidden += 1

	return hidden


func _restore_village_hidden_trees(
	root: Node
) -> void:
	var trees: Array[Node3D] = []

	_collect_natural_trees(
		root,
		trees
	)

	for tree: Node3D in trees:
		if bool(
			tree.get_meta(
				"studytown_hidden_for_forest_village",
				false
			)
		):
			tree.visible = true
			tree.remove_meta(
				"studytown_hidden_for_forest_village"
			)


func _collect_natural_trees(
	node: Node,
	result: Array[Node3D]
) -> void:
	if (
		node is Node3D
		and str(node.name).begins_with(
			"NaturalOak_"
		)
	):
		result.append(
			node as Node3D
		)

	for child: Node in node.get_children():
		_collect_natural_trees(
			child,
			result
		)


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
		+ "/garden_before_forest_village_"
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
	print("ABORTED — ", message)
	print("No new Garden scene changes were saved by this run.")
	print("")
	quit(1)
