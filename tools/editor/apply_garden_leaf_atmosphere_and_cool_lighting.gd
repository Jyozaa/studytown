extends SceneTree

# StudyTown Garden — cool dusk + whole-map leaf atmosphere.
#
# This intentionally makes the existing sunset LESS orange while keeping warm
# local lamps as accents.
#
# Adds:
#   GardenLeafAtmosphere
#
# Changes:
#   Garden WorldEnvironment -> cooler blue-grey dusk
#   Garden directional sun  -> neutral warm-white instead of orange
#   Garden broad fill       -> cool sky-blue
#
# Does NOT change:
#   localized camper / campsite lamps
#   Garden furniture
#   NPCs
#   houses / structures
#   forest placement
#   mountains / lakes / waterfalls
#
# A timestamped garden.tscn backup is created before save.

const GARDEN_SCENE_PATH := (
	"res://assets/dev_local/room_layouts/garden.tscn"
)

const BACKUP_DIR := (
	"res://assets/dev_local/room_layouts/backups"
)

const LEAF_RUNTIME_SCRIPT := preload(
	"res://scripts/world/garden_leaf_atmosphere.gd"
)

const LEAF_ASSET_PATH := (
	"res://assets/dev_local/blender_generated/runtime/"
	+ "garden_falling_leaf.glb"
)

const LEAF_NODE_NAME := "GardenLeafAtmosphere"


func _initialize() -> void:
	call_deferred(
		"_run"
	)


func _run() -> void:
	print("")
	print("# STUDYTOWN GARDEN — COOL DUSK + FALLING LEAVES")
	print("")

	if not FileAccess.file_exists(
		GARDEN_SCENE_PATH
	):
		_fail(
			"Editable garden.tscn does not exist."
		)
		return

	if not ResourceLoader.exists(
		LEAF_ASSET_PATH
	):
		_fail(
			"Missing real FenceIkegaki leaf asset: "
			+ LEAF_ASSET_PATH
		)
		return

	var packed := load(
		GARDEN_SCENE_PATH
	) as PackedScene

	if packed == null:
		_fail(
			"Could not load garden.tscn."
		)
		return

	var root := packed.instantiate()

	if (
		root == null
		or not (root is Node3D)
	):
		if root != null:
			root.free()

		_fail(
			"Garden scene root is not Node3D."
		)
		return

	var backup_path := _backup_original()

	if backup_path.is_empty():
		root.free()

		_fail(
			"Could not create Garden backup."
		)
		return

	_apply_cool_environment(
		root
	)

	_apply_cool_base_lighting(
		root
	)

	var old_leaf_node := root.get_node_or_null(
		LEAF_NODE_NAME
	)

	if old_leaf_node != null:
		old_leaf_node.get_parent().remove_child(
			old_leaf_node
		)
		old_leaf_node.free()

	var leaf_atmosphere := Node3D.new()
	leaf_atmosphere.name = LEAF_NODE_NAME
	leaf_atmosphere.set_script(
		LEAF_RUNTIME_SCRIPT
	)

	leaf_atmosphere.set(
		"static_leaf_count",
		950
	)

	leaf_atmosphere.set(
		"falling_leaf_count",
		150
	)

	leaf_atmosphere.set(
		"map_half_extent",
		Vector2(
			108.0,
			92.0
		)
	)

	root.add_child(
		leaf_atmosphere
	)
	leaf_atmosphere.owner = root

	var repacked := PackedScene.new()

	var pack_error := repacked.pack(
		root
	)

	if pack_error != OK:
		root.free()

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

	root.free()

	if save_error != OK:
		_fail(
			"ResourceSaver.save failed with error %d. Backup: %s"
			% [
				save_error,
				backup_path,
			]
		)
		return

	print("Leaf source:            real FenceIkegaki leaf")
	print("Permanent ground leaves: 950")
	print("Falling leaves:          150")
	print("Map coverage:            216 x 184")
	print("Environment:             cool blue-grey dusk")
	print("Directional sun:         neutral warm-white")
	print("Broad fill:              cool sky fill")
	print("Localized lamps:         unchanged warm accents")
	print("Backup:                  ", backup_path)
	print("")
	print("DONE")
	print("")

	quit(
		0
	)


func _apply_cool_environment(
	root: Node
) -> void:
	var environments: Array[WorldEnvironment] = []

	_collect_environments(
		root,
		environments
	)

	var world_environment: WorldEnvironment

	if environments.is_empty():
		world_environment = WorldEnvironment.new()
		world_environment.name = "GardenCoolDuskEnvironment"

		root.add_child(
			world_environment
		)
		world_environment.owner = root
	else:
		world_environment = environments[0]
		world_environment.name = "GardenCoolDuskEnvironment"

	var env: Environment

	if world_environment.environment != null:
		env = world_environment.environment.duplicate(
			true
		) as Environment
	else:
		env = Environment.new()

	var sky_material := ProceduralSkyMaterial.new()

	# Blue-grey upper sky and dusty neutral horizon. This removes the strong
	# orange wash while retaining enough dusk colour to avoid looking sterile.
	sky_material.sky_top_color = Color(
		"#536b86"
	)

	sky_material.sky_horizon_color = Color(
		"#b4a0a0"
	)

	sky_material.sky_curve = 0.20
	sky_material.sky_energy_multiplier = 0.80

	sky_material.ground_bottom_color = Color(
		"#293632"
	)

	sky_material.ground_horizon_color = Color(
		"#756f70"
	)

	sky_material.ground_curve = 0.24
	sky_material.ground_energy_multiplier = 0.66

	sky_material.sun_angle_max = 10.0
	sky_material.sun_curve = 0.14
	sky_material.energy_multiplier = 0.88
	sky_material.use_debanding = true

	var sky := Sky.new()
	sky.sky_material = sky_material

	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.background_energy_multiplier = 0.79

	# Cool sky ambience replaces the previous orange ambient colour.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(
		"#a8b9ca"
	)
	env.ambient_light_energy = 0.46

	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.76

	_set_if_property(
		env,
		"glow_enabled",
		true
	)

	_set_if_property(
		env,
		"glow_intensity",
		0.16
	)

	_set_if_property(
		env,
		"glow_bloom",
		0.05
	)

	_set_if_property(
		env,
		"adjustment_enabled",
		true
	)

	_set_if_property(
		env,
		"adjustment_brightness",
		1.00
	)

	_set_if_property(
		env,
		"adjustment_contrast",
		1.04
	)

	_set_if_property(
		env,
		"adjustment_saturation",
		0.94
	)

	world_environment.environment = env


func _apply_cool_base_lighting(
	root: Node
) -> void:
	var sun := _find_named_directional(
		root,
		"GardenSunsetSun"
	)

	if sun == null:
		sun = _find_first_directional(
			root
		)

	if sun != null:
		sun.name = "GardenCoolDuskSun"

		# Keep a little warmth so surfaces do not become blue/grey, but remove
		# the previous saturated orange #ffad67.
		sun.light_color = Color(
			"#ffe0c6"
		)

		sun.light_energy = 0.84
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 82.0

	var fill := _find_named_omni(
		root,
		"GardenSunsetFill"
	)

	if fill == null:
		fill = _find_named_omni(
			root,
			"GardenCoolDuskFill"
		)

	if fill != null:
		fill.name = "GardenCoolDuskFill"
		fill.light_color = Color(
			"#b7cbe0"
		)
		fill.light_energy = 0.30
		fill.omni_range = 34.0
		fill.shadow_enabled = false


func _collect_environments(
	node: Node,
	result: Array[WorldEnvironment]
) -> void:
	if node is WorldEnvironment:
		result.append(
			node as WorldEnvironment
		)

	for child: Node in node.get_children():
		_collect_environments(
			child,
			result
		)


func _find_named_directional(
	node: Node,
	target_name: String
) -> DirectionalLight3D:
	if (
		node is DirectionalLight3D
		and str(node.name) == target_name
	):
		return node as DirectionalLight3D

	for child: Node in node.get_children():
		var found := _find_named_directional(
			child,
			target_name
		)

		if found != null:
			return found

	return null


func _find_first_directional(
	node: Node
) -> DirectionalLight3D:
	if node is DirectionalLight3D:
		return node as DirectionalLight3D

	for child: Node in node.get_children():
		var found := _find_first_directional(
			child
		)

		if found != null:
			return found

	return null


func _find_named_omni(
	node: Node,
	target_name: String
) -> OmniLight3D:
	if (
		node is OmniLight3D
		and str(node.name) == target_name
	):
		return node as OmniLight3D

	for child: Node in node.get_children():
		var found := _find_named_omni(
			child,
			target_name
		)

		if found != null:
			return found

	return null


func _set_if_property(
	object: Object,
	property_name: StringName,
	value: Variant
) -> void:
	for property_data: Dictionary in object.get_property_list():
		if StringName(
			property_data.get(
				"name",
				""
			)
		) == property_name:
			object.set(
				property_name,
				value
			)
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
		+ "/garden_before_leaf_cool_dusk_"
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
	push_error(
		message
	)

	print("")
	print(
		"ABORTED — ",
		message
	)
	print(
		"No new Garden scene changes were saved by this run."
	)
	print("")

	quit(
		1
	)
