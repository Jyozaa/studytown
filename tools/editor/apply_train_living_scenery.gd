extends SceneTree

# Adds animated exterior life to the CURRENT editable Train scene.
#
# This script deliberately does NOT rebuild the carriage, seats, tables,
# decorations, StudySpots, NPCs, cameras, or any other interior content.
# It only adds/removes the TrainLivingScenery nodes under the existing scenery
# tiles, preserving manual Train interior fixes.

const TRAIN_SCENE_PATH := (
	"res://assets/dev_local/room_layouts/train.tscn"
)

const BACKUP_DIR := (
	"res://assets/dev_local/room_layouts/backups"
)

const LIVING_RUNTIME_SCRIPT := preload(
	"res://scripts/rooms/train_living_scenery.gd"
)

const ASSETS := {
	"boat":
		"res://assets/dev_local/blender_generated/runtime/train_scenery_boat.glb",
	"fish_ayu":
		"res://assets/dev_local/blender_generated/runtime/train_scenery_fish_ayu.glb",
	"fish_koi":
		"res://assets/dev_local/blender_generated/runtime/train_scenery_fish_nishikigoi.glb",
	"bird":
		"res://assets/dev_local/blender_generated/runtime/train_scenery_bird_day.glb",
	"lighthouse":
		"res://assets/dev_local/blender_generated/runtime/train_scenery_lighthouse.glb",
	"windmill":
		"res://assets/dev_local/blender_generated/runtime/train_scenery_windmill.glb",
	"tractor":
		"res://assets/dev_local/blender_generated/runtime/train_scenery_tractor.glb",
}

const REQUIRED_ASSETS: Array[String] = [
	"boat",
	"fish_ayu",
	"fish_koi",
	"bird",
	"lighthouse",
	"windmill",
	"tractor",
]

var _scene_root: Node3D

var _shared_water_mesh: PlaneMesh
var _shared_water_material: StandardMaterial3D
var _shared_ripple_mesh: TorusMesh
var _shared_ripple_material: StandardMaterial3D
var _shared_firefly_mesh: SphereMesh
var _shared_firefly_material: StandardMaterial3D
var _shared_flame_mesh: SphereMesh
var _shared_flame_material: StandardMaterial3D
var _shared_smoke_mesh: SphereMesh
var _shared_smoke_material: StandardMaterial3D
var _shared_beam_mesh: CylinderMesh
var _shared_beam_material: StandardMaterial3D


func _initialize() -> void:
	call_deferred(
		"_run"
	)


func _run() -> void:
	print("")
	print("# STUDYTOWN TRAIN LIVING SCENERY V7")
	print("")

	if not FileAccess.file_exists(
		TRAIN_SCENE_PATH
	):
		_fail(
			"Editable train.tscn does not exist."
		)
		return

	for key: String in REQUIRED_ASSETS:
		var asset_path: String = str(
			ASSETS.get(
				key,
				""
			)
		)

		if not ResourceLoader.exists(
			asset_path
		):
			_fail(
				"Missing living-scenery runtime asset: "
				+ asset_path
			)
			return

	var packed := load(
		TRAIN_SCENE_PATH
	) as PackedScene

	if packed == null:
		_fail(
			"Could not load editable train.tscn."
		)
		return

	var instance := packed.instantiate()

	if not (instance is Node3D):
		if instance != null:
			instance.free()

		_fail(
			"Train scene root is not Node3D."
		)
		return

	_scene_root = instance as Node3D

	var backup_path: String = (
		_backup_original()
	)

	if backup_path.is_empty():
		_scene_root.free()
		_fail(
			"Could not create Train backup."
		)
		return

	var tiles: Array[Node3D] = (
		_find_scenery_tiles()
	)

	if (
		tiles.size() != 10
		and tiles.size() != 20
	):
		_scene_root.free()
		_fail(
			"Expected 10 original or 20 extended TrainLoopTile nodes, found %d. "
			+ "No changes were saved."
			% tiles.size()
		)
		return

	var room_root: Node3D = (
		tiles[0].get_parent()
		as Node3D
	)

	if room_root == null:
		_scene_root.free()
		_fail(
			"Could not resolve the Train room root."
		)
		return

	_remove_previous_living_scenery(
		room_root,
		tiles
	)

	tiles = _prepare_extended_scenery(
		room_root,
		tiles
	)

	if tiles.size() != 20:
		_scene_root.free()
		_fail(
			"Could not prepare the 100 m Train scenery loop."
		)
		return

	_build_horizon_safety_land(
		room_root
	)

	_create_shared_procedural_resources()
	_build_continuous_water(
		room_root,
		tiles
	)

	var runtime := LIVING_RUNTIME_SCRIPT.new()
	runtime.name = "TrainLivingSceneryRuntimeV7"
	room_root.add_child(
		runtime
	)
	runtime.owner = _scene_root

	for tile: Node3D in tiles:
		var side: float = (
			-1.0
				if str(
					tile.name
				).contains(
					"_Left_"
				)
				else 1.0
		)

		var tile_index: int = (
			_parse_tile_index(
				str(
					tile.name
				)
			)
		)

		_build_tile_life(
			tile,
			side,
			tile_index
		)

	var repacked := PackedScene.new()
	var pack_error: Error = repacked.pack(
		_scene_root
	)

	if pack_error != OK:
		_scene_root.free()
		_fail(
			"PackedScene.pack failed with error %d"
			% pack_error
		)
		return

	var save_error: Error = ResourceSaver.save(
		repacked,
		TRAIN_SCENE_PATH
	)

	if save_error != OK:
		_scene_root.free()
		_scene_root = null

		_fail(
			"ResourceSaver.save failed with error %d"
			% save_error
		)
		return

	print("Interior changed:     NO")
	print("Scenery tiles:        20 (10 per side / 100 m wrap)")
	print("Water life:           seamless transparent plane + fully submerged fish + surface-breaking jumps")
	print("Watercraft:           1 boat per viewing side")
	print("Sky life:             intermittent bird crossings")
	print("Land motion:          slow tractors + extended 100 m scenery")
	print("Landmarks:            lighthouse + windmill")
	print("Campsite motion:      flames + smoke + fireflies (shared resources)")
	print("Backup:               ", backup_path)
	print("")
	print("DONE")
	print("")

	# Do not quit the SceneTree from inside this function while the local
	# PackedScene/repacked resources are still on the GDScript stack. That caused
	# the headless editor process to shut the renderer down while hundreds of
	# Train resources were still strongly referenced.
	_scene_root.free()
	_scene_root = null
	_release_builder_resources()

	# Return from _run() first so local PackedScene variables are released.
	# _finish_cleanly() runs on a later frame after Godot has processed frees.
	call_deferred(
		"_finish_cleanly"
	)


func _release_builder_resources() -> void:
	_shared_water_mesh = null
	_shared_water_material = null
	_shared_ripple_mesh = null
	_shared_ripple_material = null
	_shared_firefly_mesh = null
	_shared_firefly_material = null
	_shared_flame_mesh = null
	_shared_flame_material = null
	_shared_smoke_mesh = null
	_shared_smoke_material = null
	_shared_beam_mesh = null
	_shared_beam_material = null


func _finish_cleanly() -> void:
	# Give queued renderer/object cleanup time to run before terminating the
	# headless process. Two frames are intentional: the first flushes scene
	# deletion, the second lets dependent rendering resources release.
	await process_frame
	await process_frame

	quit(
		0
	)


func _find_scenery_tiles() -> Array[Node3D]:
	var result: Array[Node3D] = []

	var nodes: Array[Node] = [
		_scene_root
	]

	_collect_descendants(
		_scene_root,
		nodes
	)

	for node: Node in nodes:
		if (
			node is Node3D
			and str(
				node.name
			).begins_with(
				"TrainLoopTile_"
			)
		):
			result.append(
				node as Node3D
			)

	result.sort_custom(
		func(
			a: Node3D,
			b: Node3D
		) -> bool:
			return (
				str(
					a.name
				)
				<
				str(
					b.name
				)
			)
	)

	return result


func _collect_descendants(
	node: Node,
	result: Array[Node]
) -> void:
	for child: Node in node.get_children():
		result.append(
			child
		)

		_collect_descendants(
			child,
			result
		)


func _parse_tile_index(
	tile_name: String
) -> int:
	var pieces: PackedStringArray = (
		tile_name.split(
			"_"
		)
	)

	if pieces.is_empty():
		return 0

	return int(
		pieces[
			pieces.size() - 1
		]
	)


func _remove_previous_living_scenery(
	room_root: Node3D,
	tiles: Array[Node3D]
) -> void:
	for child: Node in room_root.get_children():
		var child_name: String = str(
			child.name
		)

		if (
			child_name.begins_with(
				"TrainLivingSceneryRuntime"
			)
			or child_name == "TrainLivingHorizonSafety"
			or child_name == "TrainLivingContinuousWater"
		):
			room_root.remove_child(
				child
			)
			child.free()

	for tile: Node3D in tiles:
		for child: Node in tile.get_children():
			if str(
				child.name
			).begins_with(
				"TrainLivingScenery"
			):
				tile.remove_child(
					child
				)
				child.free()


func _prepare_extended_scenery(
	room_root: Node3D,
	tiles: Array[Node3D]
) -> Array[Node3D]:
	# v1/v2 authored five 10 m tiles per side. Extend that to ten per side so
	# distant review/focus cameras never see the longitudinal end of the land.
	if tiles.size() == 10:
		var originals_by_side: Dictionary = {
			"Left": [],
			"Right": [],
		}

		for tile: Node3D in tiles:
			var side_name: String = (
				"Left"
					if str(
						tile.name
					).contains(
						"_Left_"
					)
					else "Right"
			)

			originals_by_side[
				side_name
			].append(
				tile
			)

		for side_name: String in [
			"Left",
			"Right",
		]:
			var originals: Array = originals_by_side[
				side_name
			]

			originals.sort_custom(
				func(
					a: Node3D,
					b: Node3D
				) -> bool:
					return (
						_parse_tile_index(
							str(
								a.name
							)
						)
						<
						_parse_tile_index(
							str(
								b.name
							)
						)
					)
			)

			for new_index: int in range(
				5,
				10
			):
				var source_tile: Node3D = originals[
					new_index % 5
				]

				var clone_node: Node = (
					source_tile.duplicate()
				)

				if not (
					clone_node is Node3D
				):
					if clone_node != null:
						clone_node.free()
					continue

				var clone := clone_node as Node3D
				clone.name = "TrainLoopTile_%s_%02d" % [
					side_name,
					new_index,
				]

				room_root.add_child(
					clone
				)

				_set_owner_recursive(
					clone
				)

		tiles = _find_scenery_tiles()

	var left_tiles: Array[Node3D] = []
	var right_tiles: Array[Node3D] = []

	for tile: Node3D in tiles:
		if str(
			tile.name
		).contains(
			"_Left_"
		):
			left_tiles.append(
				tile
			)
		else:
			right_tiles.append(
				tile
			)

	if (
		left_tiles.size() != 10
		or right_tiles.size() != 10
	):
		return []

	_configure_extended_side(
		left_tiles,
		"Left"
	)
	_configure_extended_side(
		right_tiles,
		"Right"
	)

	return _find_scenery_tiles()


func _configure_extended_side(
	tiles: Array[Node3D],
	side_name: String
) -> void:
	tiles.sort_custom(
		func(
			a: Node3D,
			b: Node3D
		) -> bool:
			return (
				_parse_tile_index(
					str(
						a.name
					)
				)
				<
				_parse_tile_index(
					str(
						b.name
					)
				)
			)
	)

	for index: int in range(
		tiles.size()
	):
		var tile: Node3D = tiles[
			index
		]

		tile.name = "TrainLoopTile_%s_%02d" % [
			side_name,
			index,
		]

		tile.position.z = (
			-45.0
			+ float(
				index
			)
			* 10.0
		)

		tile.remove_from_group(
			"editable_train_scenery"
		)

		tile.add_to_group(
			"train_extended_scenery",
			true
		)

		if not tile.has_meta(
			"parallax_speed"
		):
			tile.set_meta(
				"parallax_speed",
				1.65
			)


func _set_owner_recursive(
	node: Node
) -> void:
	node.owner = _scene_root

	for child: Node in node.get_children():
		_set_owner_recursive(
			child
		)


func _build_horizon_safety_land(
	room_root: Node3D
) -> void:
	var existing := room_root.get_node_or_null(
		"TrainLivingHorizonSafety"
	)

	if existing != null:
		room_root.remove_child(
			existing
		)
		existing.free()

	var root := Node3D.new()
	root.name = "TrainLivingHorizonSafety"

	room_root.add_child(
		root
	)
	root.owner = _scene_root

	var material := StandardMaterial3D.new()
	material.resource_name = "TrainLivingHorizonLand"
	material.albedo_color = Color(
		"#263229"
	)
	material.roughness = 1.0

	# This sits just below the moving land. It is not intended to be noticed;
	# it simply guarantees that a long diagonal camera ray never reaches empty
	# world beyond the 100 m moving tile loop.
	for side: float in [
		-1.0,
		1.0
	]:
		var ground := MeshInstance3D.new()
		ground.name = "HorizonLandUnderlay"
		ground.position = Vector3(
			side * 25.0,
			-0.79,
			0.0
		)

		var mesh := BoxMesh.new()
		mesh.size = Vector3(
			24.0,
			0.20,
			160.0
		)
		ground.mesh = mesh
		ground.material_override = material

		root.add_child(
			ground
		)
		ground.owner = _scene_root


func _create_shared_procedural_resources() -> void:
	# One mesh/material resource per effect type. Previously every ripple/smoke
	# node owned its own Mesh and Material subresource, which multiplied renderer
	# resources across the 20-tile Train scene.

	# One continuous water plane per side replaces the overlapping transparent
	# LoopWater slabs. Transparent slab overlap was the horizontal dark line
	# visible in the user's screenshot.
	_shared_water_mesh = PlaneMesh.new()
	_shared_water_mesh.size = Vector2(
		7.90,
		200.0
	)

	_shared_water_material = StandardMaterial3D.new()
	_shared_water_material.resource_name = "TrainContinuousSemiTransparentWater"
	_shared_water_material.albedo_color = Color(
		0.14,
		0.23,
		0.32,
		0.48
	)
	_shared_water_material.roughness = 0.28
	_shared_water_material.metallic = 0.0
	_shared_water_material.transparency = (
		BaseMaterial3D.TRANSPARENCY_ALPHA
	)
	_shared_water_material.cull_mode = (
		BaseMaterial3D.CULL_DISABLED
	)

	_shared_ripple_mesh = TorusMesh.new()
	_shared_ripple_mesh.inner_radius = 0.16
	_shared_ripple_mesh.outer_radius = 0.19
	_shared_ripple_mesh.rings = 18
	_shared_ripple_mesh.ring_segments = 10

	_shared_ripple_material = StandardMaterial3D.new()
	_shared_ripple_material.resource_name = "TrainLivingRippleShared"
	_shared_ripple_material.albedo_color = Color(
		0.92,
		0.76,
		0.64,
		0.15
	)
	_shared_ripple_material.transparency = (
		BaseMaterial3D.TRANSPARENCY_ALPHA
	)
	_shared_ripple_material.shading_mode = (
		BaseMaterial3D.SHADING_MODE_UNSHADED
	)
	_shared_ripple_material.cull_mode = (
		BaseMaterial3D.CULL_DISABLED
	)

	_shared_firefly_mesh = SphereMesh.new()
	_shared_firefly_mesh.radius = 0.035
	_shared_firefly_mesh.height = 0.070
	_shared_firefly_mesh.radial_segments = 8
	_shared_firefly_mesh.rings = 5

	_shared_firefly_material = StandardMaterial3D.new()
	_shared_firefly_material.resource_name = "TrainLivingFireflyShared"
	_shared_firefly_material.albedo_color = Color(
		"#ffd877"
	)
	_shared_firefly_material.emission_enabled = true
	_shared_firefly_material.emission = Color(
		"#ffd877"
	)
	_shared_firefly_material.emission_energy_multiplier = 2.0
	_shared_firefly_material.shading_mode = (
		BaseMaterial3D.SHADING_MODE_UNSHADED
	)

	_shared_flame_mesh = SphereMesh.new()
	_shared_flame_mesh.radius = 1.0
	_shared_flame_mesh.height = 2.0
	_shared_flame_mesh.radial_segments = 9
	_shared_flame_mesh.rings = 6

	_shared_flame_material = StandardMaterial3D.new()
	_shared_flame_material.resource_name = "TrainLivingCampfireShared"
	_shared_flame_material.albedo_color = Color(
		"#ff944d"
	)
	_shared_flame_material.emission_enabled = true
	_shared_flame_material.emission = Color(
		"#ff7d38"
	)
	_shared_flame_material.emission_energy_multiplier = 2.4
	_shared_flame_material.shading_mode = (
		BaseMaterial3D.SHADING_MODE_UNSHADED
	)

	_shared_smoke_mesh = SphereMesh.new()
	_shared_smoke_mesh.radius = 0.22
	_shared_smoke_mesh.height = 0.44
	_shared_smoke_mesh.radial_segments = 8
	_shared_smoke_mesh.rings = 5

	_shared_smoke_material = StandardMaterial3D.new()
	_shared_smoke_material.resource_name = "TrainLivingSmokeShared"
	_shared_smoke_material.albedo_color = Color(
		0.42,
		0.39,
		0.38,
		0.13
	)
	_shared_smoke_material.transparency = (
		BaseMaterial3D.TRANSPARENCY_ALPHA
	)
	_shared_smoke_material.shading_mode = (
		BaseMaterial3D.SHADING_MODE_UNSHADED
	)
	_shared_smoke_material.cull_mode = (
		BaseMaterial3D.CULL_DISABLED
	)

	_shared_beam_mesh = CylinderMesh.new()
	_shared_beam_mesh.top_radius = 0.08
	_shared_beam_mesh.bottom_radius = 0.72
	_shared_beam_mesh.height = 8.4
	_shared_beam_mesh.radial_segments = 12
	_shared_beam_mesh.rings = 1

	_shared_beam_material = StandardMaterial3D.new()
	_shared_beam_material.resource_name = "TrainLivingLighthouseBeamShared"
	_shared_beam_material.albedo_color = Color(
		1.0,
		0.82,
		0.58,
		0.055
	)
	_shared_beam_material.emission_enabled = true
	_shared_beam_material.emission = Color(
		"#ffd099"
	)
	_shared_beam_material.emission_energy_multiplier = 0.45
	_shared_beam_material.transparency = (
		BaseMaterial3D.TRANSPARENCY_ALPHA
	)
	_shared_beam_material.shading_mode = (
		BaseMaterial3D.SHADING_MODE_UNSHADED
	)
	_shared_beam_material.cull_mode = (
		BaseMaterial3D.CULL_DISABLED
	)


func _build_continuous_water(
	room_root: Node3D,
	tiles: Array[Node3D]
) -> void:
	# Hide all old per-tile water meshes. Keeping transparent overlapping boxes
	# would darken every tile boundary and create visible horizontal cut lines.
	for tile: Node3D in tiles:
		var descendants: Array[Node] = [
			tile
		]

		_collect_descendants(
			tile,
			descendants
		)

		for node: Node in descendants:
			if (
				node is MeshInstance3D
				and str(
					node.name
				) == "LoopWater"
			):
				(
					node as MeshInstance3D
				).visible = false

	var existing := room_root.get_node_or_null(
		"TrainLivingContinuousWater"
	)

	if existing != null:
		room_root.remove_child(
			existing
		)
		existing.free()

	var water_root := Node3D.new()
	water_root.name = "TrainLivingContinuousWater"

	room_root.add_child(
		water_root
	)
	water_root.owner = _scene_root

	for side: float in [
		-1.0,
		1.0
	]:
		var water := MeshInstance3D.new()
		water.name = (
			"ContinuousWaterLeft"
				if side < 0.0
				else "ContinuousWaterRight"
		)
		water.position = Vector3(
			side * 9.25,
			-0.78,
			0.0
		)
		water.mesh = _shared_water_mesh
		water.material_override = (
			_shared_water_material
		)

		water_root.add_child(
			water
		)
		water.owner = _scene_root

func _build_tile_life(
	tile: Node3D,
	side: float,
	tile_index: int
) -> void:
	var root := Node3D.new()
	root.name = "TrainLivingSceneryV7"

	tile.add_child(
		root
	)
	root.owner = _scene_root

	_build_water_life(
		root,
		side,
		tile_index
	)

	_build_sky_life(
		root,
		side,
		tile_index
	)

	_build_land_life(
		root,
		side,
		tile_index
	)

	_build_campsite_atmosphere(
		root,
		side,
		tile_index
	)


func _build_water_life(
	root: Node3D,
	side: float,
	tile_index: int
) -> void:
	# Fish remain shallow so they are visible through/against the existing dark
	# water slab without changing the user's existing water material.
	for fish_index: int in range(
		2
	):
		var use_koi: bool = (
			fish_index == 1
			and tile_index % 2 == 0
		)

		var key: String = (
			"fish_koi"
				if use_koi
				else "fish_ayu"
		)

		var fish := _instance_asset_under(
			root,
			key,
			Vector3(
				side
				* (
					8.05
					+ float(
						fish_index
					)
					* 1.05
				),
				-1.34,
				-3.2
				+ float(
					fish_index
				)
				* 2.65
			),
			Vector3.ONE
			* (
				0.78
					if use_koi
					else 0.68
			),
			# Fish models are lengthwise on local Z. Align them with their
			# longitudinal swimming direction instead of turning them sideways.
			PI,
			"LivingFish_%02d"
			% fish_index
		)

		if fish != null:
			fish.add_to_group(
				"train_living_fish",
				true
			)
			fish.set_meta(
				"living_base_position",
				fish.position
			)
			fish.set_meta(
				"living_base_rotation",
				fish.rotation
			)
			fish.set_meta(
				"living_phase",
				float(
					tile_index
					* 2
					+ fish_index
				)
				* 0.71
			)
			fish.set_meta(
				"living_speed",
				0.34
				+ float(
					fish_index
				)
				* 0.07
			)
			fish.set_meta(
				"living_direction",
				1.0
			)
			fish.set_meta(
				"living_base_scale",
				fish.scale
			)
			fish.set_meta(
				"living_swim_rate",
				3.4
				+ float(
					fish_index
				)
				* 0.45
			)

	# A few repeating surface ripples make the water feel active without
	# replacing the established seamless water slabs.
	for ripple_index: int in range(
		2
	):
		_build_ripple(
			root,
			Vector3(
				side
				* (
					8.7
					+ float(
						ripple_index
					)
					* 1.75
				),
				-0.775,
				-2.1
				+ float(
					ripple_index
				)
				* 4.2
			),
			float(
				tile_index
				* 2
				+ ripple_index
			)
			* 0.17
		)

	# One boat per viewing side across the whole 50 m loop.
	var should_have_boat: bool = (
		(
			side < 0.0
			and tile_index == 1
		)
		or (
			side > 0.0
			and tile_index == 3
		)
	)

	if should_have_boat:
		var boat := _instance_asset_under(
			root,
			"boat",
			Vector3(
				side * 9.55,
				-0.785,
				0.25
			),
			Vector3.ONE
			* 0.82,
			(
				PI
					if side < 0.0
					else 0.0
			),
			"LivingPassingBoat"
		)

		if boat != null:
			boat.add_to_group(
				"train_living_boat",
				true
			)
			boat.set_meta(
				"living_base_position",
				boat.position
			)
			boat.set_meta(
				"living_base_rotation",
				boat.rotation
			)
			boat.set_meta(
				"living_phase",
				1.2
				+ tile_index
			)


func _build_sky_life(
	root: Node3D,
	side: float,
	tile_index: int
) -> void:
	if tile_index not in [
		0,
		3,
	]:
		return

	for bird_index: int in range(
		3
	):
		var start_position := Vector3(
			side * 18.0,
			4.2
			+ float(
				bird_index
			)
			* 0.42,
			-3.0
			+ float(
				bird_index
			)
			* 1.35
		)

		var end_position := Vector3(
			side * 8.4,
			4.7
			+ float(
				bird_index
			)
			* 0.32,
			2.8
			- float(
				bird_index
			)
			* 1.15
		)

		var bird := _instance_asset_under(
			root,
			"bird",
			start_position,
			Vector3.ONE
			* (
				0.72
				+ float(
					bird_index
				)
				* 0.06
			),
			(
				-PI / 2.0
					if side < 0.0
					else PI / 2.0
			),
			"LivingBird_%02d"
			% bird_index
		)

		if bird == null:
			continue

		bird.add_to_group(
			"train_living_bird",
			true
		)
		bird.set_meta(
			"living_start_position",
			start_position
		)
		bird.set_meta(
			"living_end_position",
			end_position
		)
		bird.set_meta(
			"living_base_rotation",
			bird.rotation
		)
		bird.set_meta(
			"living_phase",
			float(
				tile_index * 5
				+ bird_index
			)
			* 2.35
		)
		bird.set_meta(
			"living_cycle",
			24.0
			+ float(
				bird_index
			)
			* 2.5
		)
		bird.set_meta(
			"living_duration",
			6.8
			+ float(
				bird_index
			)
			* 0.45
		)


func _build_land_life(
	root: Node3D,
	side: float,
	tile_index: int
) -> void:
	# Landmark variety: windmill on the left side, lighthouse on the right.
	if (
		side < 0.0
		and tile_index == 2
	):
		_instance_asset_under(
			root,
			"windmill",
			Vector3(
				side * 20.7,
				-0.55,
				0.7
			),
			Vector3.ONE
			* 0.86,
			PI / 2.0,
			"LivingCountrysideWindmill"
		)

	if (
		side > 0.0
		and tile_index == 2
	):
		_instance_asset_under(
			root,
			"lighthouse",
			Vector3(
				side * 22.0,
				-0.55,
				0.4
			),
			Vector3.ONE
			* 0.82,
			-PI / 2.0,
			"LivingSunsetLighthouse"
		)

		_build_lighthouse_beam(
			root,
			Vector3(
				side * 22.0,
				4.30,
				0.4
			),
			float(
				tile_index
			)
		)

	# One slow field tractor on each side, but on different tiles.
	var should_have_tractor: bool = (
		(
			side < 0.0
			and tile_index == 4
		)
		or (
			side > 0.0
			and tile_index == 0
		)
	)

	if should_have_tractor:
		var tractor := _instance_asset_under(
			root,
			"tractor",
			Vector3(
				side * 18.1,
				-0.55,
				-3.9
			),
			Vector3.ONE
			* 0.72,
			(
				PI
					if side < 0.0
					else 0.0
			),
			"LivingFieldTractor"
		)

		if tractor != null:
			tractor.add_to_group(
				"train_living_tractor",
				true
			)
			tractor.set_meta(
				"living_base_position",
				tractor.position
			)
			tractor.set_meta(
				"living_phase",
				2.2
				+ tile_index
			)
			tractor.set_meta(
				"living_speed",
				0.18
			)


func _build_campsite_atmosphere(
	root: Node3D,
	side: float,
	tile_index: int
) -> void:
	var pattern_index: int = (
		tile_index
		% 5
	)

	# Existing campsite-pattern tiles get animated flame/smoke layers.
	if pattern_index == 1:
		var fire_position := Vector3(
			side * 15.2,
			-0.12,
			2.2
		)

		_build_flame(
			root,
			fire_position,
			float(
				tile_index
			)
			+ (
				0.5
					if side > 0.0
					else 0.0
			)
		)

		for smoke_index: int in range(
			3
		):
			_build_smoke(
				root,
				fire_position
				+ Vector3(
					0.0,
					0.18
					+ float(
						smoke_index
					)
					* 0.12,
					0.0
				),
				float(
					smoke_index
				)
				* 0.31
			)

	# Fireflies appear around campsite/trailer/lantern stretches.
	if pattern_index in [
		1,
		3,
		4,
	]:
		for firefly_index: int in range(
			4
		):
			_build_firefly(
				root,
				Vector3(
					side
						* (
							15.2
							+ float(
								firefly_index % 2
							)
							* 0.85
						),
					0.35
					+ float(
						firefly_index % 3
					)
					* 0.24,
					-2.6
					+ float(
						firefly_index
					)
					* 1.55
				),
				float(
					tile_index * 4
					+ firefly_index
				)
				* 0.67
			)


func _build_ripple(
	parent: Node3D,
	position_value: Vector3,
	phase: float
) -> void:
	var ripple := MeshInstance3D.new()
	ripple.name = "LivingWaterRipple"
	ripple.position = position_value
	ripple.mesh = _shared_ripple_mesh
	ripple.material_override = _shared_ripple_material

	parent.add_child(
		ripple
	)
	ripple.owner = _scene_root
	ripple.add_to_group(
		"train_living_ripple",
		true
	)
	ripple.set_meta(
		"living_phase",
		phase
	)

func _build_firefly(
	parent: Node3D,
	position_value: Vector3,
	phase: float
) -> void:
	var firefly := MeshInstance3D.new()
	firefly.name = "LivingFirefly"
	firefly.position = position_value
	firefly.mesh = _shared_firefly_mesh
	firefly.material_override = _shared_firefly_material

	parent.add_child(
		firefly
	)
	firefly.owner = _scene_root
	firefly.add_to_group(
		"train_living_firefly",
		true
	)
	firefly.set_meta(
		"living_base_position",
		position_value
	)
	firefly.set_meta(
		"living_phase",
		phase
	)

func _build_flame(
	parent: Node3D,
	position_value: Vector3,
	phase: float
) -> void:
	var flame := MeshInstance3D.new()
	flame.name = "LivingCampfireFlame"
	flame.position = position_value
	flame.scale = Vector3(
		0.12,
		0.25,
		0.12
	)
	flame.mesh = _shared_flame_mesh
	flame.material_override = _shared_flame_material

	parent.add_child(
		flame
	)
	flame.owner = _scene_root
	flame.add_to_group(
		"train_living_flame",
		true
	)
	flame.set_meta(
		"living_base_scale",
		flame.scale
	)
	flame.set_meta(
		"living_phase",
		phase
	)

func _build_smoke(
	parent: Node3D,
	position_value: Vector3,
	phase: float
) -> void:
	var smoke := MeshInstance3D.new()
	smoke.name = "LivingCampfireSmoke"
	smoke.position = position_value
	smoke.scale = (
		Vector3.ONE
		* 0.45
	)
	smoke.mesh = _shared_smoke_mesh
	smoke.material_override = _shared_smoke_material

	parent.add_child(
		smoke
	)
	smoke.owner = _scene_root
	smoke.add_to_group(
		"train_living_smoke",
		true
	)
	smoke.set_meta(
		"living_base_position",
		position_value
	)
	smoke.set_meta(
		"living_phase",
		phase
	)

func _build_lighthouse_beam(
	parent: Node3D,
	position_value: Vector3,
	phase: float
) -> void:
	var pivot := Node3D.new()
	pivot.name = "LivingLighthouseBeamPivot"
	pivot.position = position_value

	parent.add_child(
		pivot
	)
	pivot.owner = _scene_root
	pivot.add_to_group(
		"train_living_lighthouse_beam",
		true
	)
	pivot.set_meta(
		"living_speed",
		0.23
	)
	pivot.set_meta(
		"living_phase",
		phase
	)

	var spot := SpotLight3D.new()
	spot.name = "LivingLighthouseSpot"
	spot.position = Vector3.ZERO
	spot.light_color = Color(
		"#ffd49a"
	)
	spot.light_energy = 1.6
	spot.spot_range = 18.0
	spot.spot_angle = 12.0
	spot.shadow_enabled = false

	pivot.add_child(
		spot
	)
	spot.owner = _scene_root

	var beam := MeshInstance3D.new()
	beam.name = "LivingLighthouseBeamVisual"
	beam.position = Vector3(
		0.0,
		0.0,
		-4.2
	)
	beam.rotation.x = PI / 2.0

	beam.mesh = _shared_beam_mesh
	beam.material_override = _shared_beam_material

	pivot.add_child(
		beam
	)
	beam.owner = _scene_root


func _instance_asset_under(
	parent: Node3D,
	key: String,
	position_value: Vector3,
	scale_value: Vector3,
	yaw: float,
	node_name: String
) -> Node3D:
	var asset_path: String = str(
		ASSETS.get(
			key,
			""
		)
	)

	if (
		asset_path.is_empty()
		or not ResourceLoader.exists(
			asset_path
		)
	):
		return null

	var packed := load(
		asset_path
	) as PackedScene

	if packed == null:
		return null

	var instance := packed.instantiate()

	if not (instance is Node3D):
		if instance != null:
			instance.free()
		return null

	var node := instance as Node3D
	node.name = node_name
	node.position = position_value
	node.scale = scale_value
	node.rotation.y = yaw

	parent.add_child(
		node
	)
	node.owner = _scene_root

	return node


func _backup_original() -> String:
	var backup_absolute: String = (
		ProjectSettings.globalize_path(
			BACKUP_DIR
		)
	)

	var make_error: Error = (
		DirAccess.make_dir_recursive_absolute(
			backup_absolute
		)
	)

	if make_error != OK:
		return ""

	var timestamp: String = (
		Time.get_datetime_string_from_system()
		.replace(
			":",
			"-"
		)
		.replace(
			"T",
			"_"
		)
	)

	var backup_path: String = (
		BACKUP_DIR
		+ "/train_before_living_scenery_"
		+ timestamp
		+ ".tscn"
	)

	var copy_error: Error = DirAccess.copy_absolute(
		ProjectSettings.globalize_path(
			TRAIN_SCENE_PATH
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
	print("FAILED: ", message)
	print("")

	if is_instance_valid(
		_scene_root
	):
		_scene_root.free()

	_scene_root = null
	_release_builder_resources()

	call_deferred(
		"_finish_failure_cleanly"
	)


func _finish_failure_cleanly() -> void:
	await process_frame
	await process_frame

	quit(
		1
	)
