extends SceneTree

# StudyTown Japanese Study redesign.
#
# Rebuilds only:
#   res://assets/dev_local/room_layouts/japanese.tscn
#
# Reference direction:
# - traditional tatami study room
# - central low table with floor cushions
# - shoji architecture and screens
# - warm paper-lantern lighting
# - tea, bonsai, low storage and hanging scrolls
# - evening garden visible through the open/shoji side
#
# The scene keeps the existing 38 x 30 gameplay footprint and the runtime
# "floor_cushion" seat family so FloorStudy animations remain valid.

const JAPANESE_SCENE_PATH := (
	"res://assets/dev_local/room_layouts/japanese.tscn"
)

const BACKUP_DIR := (
	"res://assets/dev_local/room_layouts/backups"
)

const TATAMI_ALBEDO := (
	"res://assets/dev_local/blender_generated/runtime/japanese_tatami_albedo.png"
)

const STUDY_SPOT_SCRIPT := preload(
	"res://scripts/study/study_spot.gd"
)

const NPC_CONTROLLER_SCRIPT := preload(
	"res://scripts/npc/npc_controller.gd"
)

const ASSETS := {
	"low_table":
		"res://assets/dev_local/blender_generated/runtime/japanese_low_table_archive.glb",
	"dining_table":
		"res://assets/dev_local/blender_generated/runtime/japanese_dining_table.glb",
	"lowboard":
		"res://assets/dev_local/blender_generated/runtime/japanese_lowboard.glb",
	"chest":
		"res://assets/dev_local/blender_generated/runtime/japanese_chest.glb",
	"kotatsu":
		"res://assets/dev_local/blender_generated/runtime/japanese_kotatsu.glb",
	"cushion":
		"res://assets/dev_local/blender_generated/runtime/japanese_floor_cushion_archive.glb",
	"cushion_pile":
		"res://assets/dev_local/blender_generated/runtime/japanese_cushion_pile.glb",
	"shoji":
		"res://assets/dev_local/blender_generated/runtime/japanese_shoji_window.glb",
	"round_shoji":
		"res://assets/dev_local/blender_generated/runtime/japanese_round_shoji_window.glb",
	"screen":
		"res://assets/dev_local/blender_generated/runtime/japanese_screen.glb",
	"screen_low":
		"res://assets/dev_local/blender_generated/runtime/japanese_screen_low.glb",
	"byoubu":
		"res://assets/dev_local/blender_generated/runtime/japanese_byoubu.glb",
	"lamp":
		"res://assets/dev_local/blender_generated/runtime/japanese_floor_lamp.glb",
	"ceiling_lamp":
		"res://assets/dev_local/blender_generated/runtime/japanese_ceiling_lamp.glb",
	"bamboo_lamp":
		"res://assets/dev_local/blender_generated/runtime/japanese_bamboo_lamp.glb",
	"kettle":
		"res://assets/dev_local/blender_generated/runtime/japanese_kettle.glb",
	"teacup":
		"res://assets/dev_local/blender_generated/runtime/japanese_teacup.glb",
	"bonsai_pine":
		"res://assets/dev_local/blender_generated/runtime/japanese_bonsai_pine.glb",
	"bonsai_kokedama":
		"res://assets/dev_local/blender_generated/runtime/japanese_bonsai_kokedama.glb",
	"bamboo_shelf":
		"res://assets/dev_local/blender_generated/runtime/japanese_bamboo_shelf.glb",
	"scroll":
		"res://assets/dev_local/blender_generated/runtime/japanese_hanging_scroll.glb",
}

const REQUIRED_ASSETS: Array[String] = [
	"low_table",
	"cushion",
	"shoji",
	"lamp",
	"kettle",
	"teacup",
]

const FLOOR_VISUAL_OFFSET := Vector3(
	0.0,
	-0.18,
	0.02
)

var _scene_root: Node3D
var _room_root: Node3D
var _materials: Dictionary = {}
var _seat_specs: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred(
		"_run"
	)


func _run() -> void:
	print("")
	print("# STUDYTOWN JAPANESE STUDY REDESIGN")
	print("")

	if not FileAccess.file_exists(
		JAPANESE_SCENE_PATH
	):
		_fail(
			"Editable japanese.tscn does not exist."
		)
		return

	for key: String in REQUIRED_ASSETS:
		var path: String = str(
			ASSETS.get(
				key,
				""
			)
		)

		if not ResourceLoader.exists(
			path
		):
			_fail(
				"Missing Japanese Study asset: "
				+ path
				+ "\nRun blender_train_japanese_archive_assets.py "
				+ "and the headless Godot import first."
			)
			return

	if not ResourceLoader.exists(
		TATAMI_ALBEDO
	):
		_fail(
			"Missing Japanese tatami texture: "
			+ TATAMI_ALBEDO
		)
		return

	var packed := load(
		JAPANESE_SCENE_PATH
	) as PackedScene

	if packed == null:
		_fail(
			"Could not load japanese.tscn."
		)
		return

	var instance := packed.instantiate()

	if not (instance is Node3D):
		if instance != null:
			instance.free()

		_fail(
			"Japanese scene root is not Node3D."
		)
		return

	_scene_root = instance as Node3D

	var backup_path: String = (
		_backup_original()
	)

	if backup_path.is_empty():
		_scene_root.free()
		_fail(
			"Could not create Japanese Study backup."
		)
		return

	_clear_scene()

	_scene_root.set_meta(
		"studytown_room_index",
		3
	)
	_scene_root.set_meta(
		"studytown_room_id",
		"japanese"
	)
	_scene_root.set_meta(
		"redesigned_by",
		"apply_japanese_redesign.gd"
	)
	_scene_root.set_meta(
		"japanese_redesign_version",
		1
	)

	_build_materials()

	_room_root = Node3D.new()
	_room_root.name = "JapaneseStudyRedesign"
	_scene_root.add_child(
		_room_root
	)
	_room_root.owner = _scene_root

	_build_environment()
	_build_tatami_floor()
	_build_room_shell()
	_build_shoji_architecture()
	_build_garden()
	_build_central_study()
	_build_side_study_zones()
	_build_decor_and_lighting()

	var spots: Array = (
		_build_study_spots()
	)

	_build_npcs(
		spots
	)
	_build_review_cameras()
	_build_player_spawn()

	var repacked := PackedScene.new()
	var pack_error: int = repacked.pack(
		_scene_root
	)

	if pack_error != OK:
		_scene_root.free()
		_fail(
			"PackedScene.pack failed with error %d"
			% pack_error
		)
		return

	var save_error: int = ResourceSaver.save(
		repacked,
		JAPANESE_SCENE_PATH
	)

	_scene_root.free()
	_scene_root = null

	if save_error != OK:
		_fail(
			"ResourceSaver.save failed with error %d"
			% save_error
		)
		return

	print("Footprint:         38 x 30")
	print("Study positions:   ", _seat_specs.size())
	print("Default NPCs:      4")
	print("Layout:            central low-table study + two quiet side tea/study zones")
	print("Lighting:          warm paper lanterns / soft evening ambient")
	print("Exterior:          dusk Japanese garden with blossom trees and stone path")
	print("Backup:            ", backup_path)
	print("")
	print("DONE")
	print("")

	quit(
		0
	)


func _clear_scene() -> void:
	for child: Node in _scene_root.get_children():
		_scene_root.remove_child(
			child
		)
		child.free()


func _build_materials() -> void:
	var tatami_texture := load(
		TATAMI_ALBEDO
	) as Texture2D

	var tatami := StandardMaterial3D.new()
	tatami.resource_name = "JapaneseTatami"
	tatami.albedo_texture = tatami_texture
	tatami.albedo_color = Color(
		"#d5c69e"
	)
	tatami.roughness = 0.94
	_materials["tatami"] = tatami

	_materials["tatami_border"] = _material(
		"TatamiBorder",
		Color(
			"#4f5647"
		),
		0.92
	)
	_materials["wood_dark"] = _material(
		"JapaneseDarkWood",
		Color(
			"#38271b"
		),
		0.86
	)
	_materials["wood"] = _material(
		"JapaneseWood",
		Color(
			"#60432a"
		),
		0.84
	)
	_materials["plaster"] = _material(
		"JapanesePlaster",
		Color(
			"#b7a98d"
		),
		0.94
	)
	_materials["stone"] = _material(
		"JapaneseGardenStone",
		Color(
			"#65645f"
		),
		0.96
	)
	_materials["grass"] = _material(
		"JapaneseGardenMoss",
		Color(
			"#314630"
		),
		0.98
	)
	_materials["water"] = _material(
		"JapaneseGardenWater",
		Color(
			"#304d5b"
		),
		0.45
	)
	_materials["trunk"] = _material(
		"JapaneseTreeTrunk",
		Color(
			"#3d2a23"
		),
		0.96
	)
	_materials["blossom"] = _material(
		"JapaneseBlossom",
		Color(
			"#d88998"
		),
		0.96
	)
	_materials["lamp_glow"] = _emissive_material(
		"JapaneseLampGlow",
		Color(
			"#ffd59a"
		),
		1.55
	)


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "JapaneseEveningEnvironment"
	_room_root.add_child(
		world_environment
	)
	world_environment.owner = _scene_root

	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()

	sky_material.sky_top_color = Color(
		"#29283b"
	)
	sky_material.sky_horizon_color = Color(
		"#665065"
	)
	sky_material.sky_curve = 0.20
	sky_material.sky_energy_multiplier = 0.52
	sky_material.ground_bottom_color = Color(
		"#171a1b"
	)
	sky_material.ground_horizon_color = Color(
		"#3f463f"
	)

	var sky := Sky.new()
	sky.sky_material = sky_material

	environment.background_mode = (
		Environment.BG_SKY
	)
	environment.sky = sky
	environment.ambient_light_source = (
		Environment.AMBIENT_SOURCE_COLOR
	)
	environment.ambient_light_color = Color(
		"#b48e70"
	)
	environment.ambient_light_energy = 0.44
	environment.tonemap_mode = (
		Environment.TONE_MAPPER_FILMIC
	)
	environment.fog_enabled = true
	environment.fog_light_color = Color(
		"#766776"
	)
	environment.fog_light_energy = 0.28
	environment.fog_density = 0.0045
	environment.fog_sky_affect = 0.55

	world_environment.environment = environment

	var garden_fill := DirectionalLight3D.new()
	garden_fill.name = "JapaneseMoonFill"
	garden_fill.light_color = Color(
		"#9ea8c7"
	)
	garden_fill.light_energy = 0.20
	garden_fill.shadow_enabled = true
	garden_fill.rotation_degrees = Vector3(
		-46.0,
		-34.0,
		0.0
	)

	_room_root.add_child(
		garden_fill
	)
	garden_fill.owner = _scene_root


func _build_tatami_floor() -> void:
	# 4.2 x 2.1 tiles roughly mimic traditional tatami proportions. Alternating
	# orientation keeps the room from reading as one stretched texture.
	var tile_width: float = 4.2
	var tile_length: float = 2.1

	for row: int in range(
		-6,
		7
	):
		for column: int in range(
			-4,
			5
		):
			var rotate_tile: bool = (
				(
					row
					+ column
				)
				% 2
				== 0
			)

			var size := Vector3(
				(
					tile_length
					if rotate_tile
					else tile_width
				),
				0.055,
				(
					tile_width
					if rotate_tile
					else tile_length
				)
			)

			var position_value := Vector3(
				float(
					row
				)
				* 2.9,
				0.0,
				float(
					column
				)
				* 3.1
			)

			_box(
				_room_root,
				size,
				position_value,
				_materials["tatami"],
				"TatamiMat"
			)

			# Narrow dark border on one long edge.
			_box(
				_room_root,
				Vector3(
					size.x,
					0.018,
					0.055
				),
				position_value
				+ Vector3(
					0.0,
					0.035,
					-size.z
					* 0.48
				),
				_materials["tatami_border"],
				"TatamiEdge"
			)

	_add_blocker(
		Vector3(
			0.0,
			-0.20,
			0.0
		),
		Vector3(
			38.0,
			0.42,
			30.0
		),
		0.0,
		"JapaneseFloorCollision"
	)


func _build_room_shell() -> void:
	# South wall.
	_box(
		_room_root,
		Vector3(
			38.0,
			5.4,
			0.38
		),
		Vector3(
			0.0,
			2.45,
			15.0
		),
		_materials["plaster"],
		"JapaneseSouthWall"
	)

	# Low north sill leaves the garden visible.
	_box(
		_room_root,
		Vector3(
			38.0,
			0.65,
			0.36
		),
		Vector3(
			0.0,
			0.18,
			-15.0
		),
		_materials["wood_dark"],
		"JapaneseNorthSill"
	)

	# Side wall base strips.
	for side: float in [
		-1.0,
		1.0
	]:
		_box(
			_room_root,
			Vector3(
				0.36,
				0.72,
				30.0
			),
			Vector3(
				side * 19.0,
				0.22,
				0.0
			),
			_materials["wood_dark"],
			"JapaneseSideSill"
		)

		_add_blocker(
			Vector3(
				side * 18.75,
				2.2,
				0.0
			),
			Vector3(
				0.55,
				4.8,
				30.0
			),
			0.0,
			"JapaneseSideBoundary"
		)

	_add_blocker(
		Vector3(
			0.0,
			2.2,
			14.75
		),
		Vector3(
			38.0,
			4.8,
			0.55
		),
		0.0,
		"JapaneseSouthBoundary"
	)
	_add_blocker(
		Vector3(
			0.0,
			2.2,
			-14.75
		),
		Vector3(
			38.0,
			4.8,
			0.55
		),
		0.0,
		"JapaneseNorthBoundary"
	)

	# Dark timber beams.
	for x_value: float in [
		-18.5,
		-12.0,
		-6.0,
		0.0,
		6.0,
		12.0,
		18.5
	]:
		_box(
			_room_root,
			Vector3(
				0.22,
				5.1,
				0.28
			),
			Vector3(
				x_value,
				2.45,
				14.75
			),
			_materials["wood_dark"],
			"SouthTimberPost"
		)

	_box(
		_room_root,
		Vector3(
			38.0,
			0.22,
			0.30
		),
		Vector3(
			0.0,
			4.95,
			14.75
		),
		_materials["wood_dark"],
		"SouthTopBeam"
	)


func _build_shoji_architecture() -> void:
	# North garden wall: four shoji panels with a wide central opening.
	for x_value: float in [
		-13.5,
		-8.5,
		8.5,
		13.5
	]:
		_instance_asset(
			"shoji",
			Vector3(
				x_value,
				0.58,
				-14.72
			),
			Vector3.ONE,
			0.0,
			"NorthShojiPanel"
		)

	# Side shoji bays.
	for side: float in [
		-1.0,
		1.0
	]:
		for z_value: float in [
			-8.0,
			0.0,
			8.0
		]:
			_instance_asset(
				"shoji",
				Vector3(
					side * 18.72,
					0.58,
					z_value
				),
				Vector3.ONE,
				(
					PI
					/ 2.0
					if side < 0.0
					else -PI
					/ 2.0
				),
				"SideShojiPanel"
			)

	# Decorative round shoji feature on the south wall.
	_instance_asset(
		"round_shoji",
		Vector3(
			-13.6,
			0.60,
			14.70
		),
		Vector3(
			0.88,
			0.88,
			0.88
		),
		PI,
		"SouthRoundShoji"
	)

	# Screens create small, quiet sub-zones.
	_instance_asset(
		"byoubu",
		Vector3(
			-13.5,
			0.0,
			7.0
		),
		Vector3.ONE,
		0.35,
		"LeftByoubu"
	)
	_instance_asset(
		"screen",
		Vector3(
			13.8,
			0.0,
			7.6
		),
		Vector3.ONE,
		-0.35,
		"RightJapaneseScreen"
	)


func _build_garden() -> void:
	# Garden begins beyond the open north shoji.
	_box(
		_room_root,
		Vector3(
			38.0,
			0.20,
			18.0
		),
		Vector3(
			0.0,
			-0.30,
			-23.0
		),
		_materials["grass"],
		"JapaneseGardenGround"
	)

	# Curving-looking stone walk approximated with staggered stepping stones.
	for index: int in range(
		-6,
		7
	):
		var x_value: float = (
			sin(
				float(
					index
				)
				* 0.62
			)
			* 2.2
		)

		var z_value: float = (
			-17.0
			- float(
				index
				+ 6
			)
			* 1.15
		)

		_cylinder(
			_room_root,
			0.58,
			0.12,
			Vector3(
				x_value,
				-0.12,
				z_value
			),
			_materials["stone"],
			"GardenSteppingStone"
		)

	# Small reflective pond off-centre.
	_box(
		_room_root,
		Vector3(
			7.5,
			0.06,
			5.2
		),
		Vector3(
			8.0,
			-0.18,
			-23.5
		),
		_materials["water"],
		"JapaneseGardenPond"
	)

	# Blossom trees frame the view rather than filling it.
	var tree_specs: Array[Dictionary] = [
		{
			"position": Vector3(
				-11.0,
				-0.2,
				-21.0
			),
			"scale": 1.0,
		},
		{
			"position": Vector3(
				13.0,
				-0.2,
				-20.0
			),
			"scale": 0.92,
		},
		{
			"position": Vector3(
				-16.0,
				-0.2,
				-27.0
			),
			"scale": 0.78,
		},
	]

	for spec: Dictionary in tree_specs:
		_build_blossom_tree(
			spec["position"],
			float(
				spec["scale"]
			)
		)

	# Warm garden lanterns.
	for x_value: float in [
		-6.0,
		6.0
	]:
		_build_garden_lantern(
			Vector3(
				x_value,
				-0.15,
				-18.5
			)
		)


func _build_blossom_tree(
	position_value: Vector3,
	scale_value: float
) -> void:
	_cylinder(
		_room_root,
		0.34
		* scale_value,
		4.8
		* scale_value,
		position_value
		+ Vector3.UP
		* 2.4
		* scale_value,
		_materials["trunk"],
		"BlossomTrunk"
	)

	var offsets: Array[Vector3] = [
		Vector3(
			-1.0,
			4.4,
			0.0
		),
		Vector3(
			1.0,
			4.4,
			0.2
		),
		Vector3(
			0.0,
			5.2,
			0.0
		),
		Vector3(
			0.2,
			4.5,
			-1.1
		),
		Vector3(
			-0.4,
			4.3,
			1.0
		),
	]

	for offset: Vector3 in offsets:
		_sphere(
			_room_root,
			Vector3(
				1.45,
				1.05,
				1.30
			)
			* scale_value,
			position_value
			+ offset
			* scale_value,
			_materials["blossom"],
			"BlossomCanopy"
		)


func _build_garden_lantern(
	position_value: Vector3
) -> void:
	_cylinder(
		_room_root,
		0.13,
		1.15,
		position_value
		+ Vector3.UP
		* 0.58,
		_materials["stone"],
		"GardenLanternPost"
	)

	_box(
		_room_root,
		Vector3(
			0.52,
			0.62,
			0.52
		),
		position_value
		+ Vector3.UP
		* 1.38,
		_materials["lamp_glow"],
		"GardenLanternGlow"
	)

	_add_omni_light(
		position_value
		+ Vector3.UP
		* 1.40,
		Color(
			"#ffc37a"
		),
		1.10,
		5.0,
		"GardenWarmLantern"
	)


func _build_central_study() -> void:
	var centre := Vector3.ZERO

	# Large communal low table.
	_instance_asset(
		"low_table",
		centre,
		Vector3(
			2.05,
			1.0,
			1.45
		),
		0.0,
		"CentralLowTable"
	)

	_add_blocker(
		Vector3(
			0.0,
			0.45,
			0.0
		),
		Vector3(
			5.4,
			0.90,
			3.1
		),
		0.0,
		"CentralLowTableBlocker"
	)

	# Tea and study props.
	_instance_asset(
		"kettle",
		Vector3(
			0.25,
			0.78,
			0.0
		),
		Vector3.ONE,
		0.0,
		"CentralKettle"
	)

	for cup_position: Vector3 in [
		Vector3(
			-1.3,
			0.78,
			0.35
		),
		Vector3(
			1.3,
			0.78,
			-0.35
		),
		Vector3(
			-0.3,
			0.78,
			-0.65
		),
	]:
		_instance_asset(
			"teacup",
			cup_position,
			Vector3.ONE,
			0.0,
			"CentralTeacup"
		)

	var central_cushions: Array[Dictionary] = [
		{
			"position": Vector3(
				-3.05,
				0.0,
				0.0
			),
			"yaw": -PI
			/ 2.0,
			"id": "japanese-central-west",
		},
		{
			"position": Vector3(
				3.05,
				0.0,
				0.0
			),
			"yaw": PI
			/ 2.0,
			"id": "japanese-central-east",
		},
		{
			"position": Vector3(
				0.0,
				0.0,
				-2.35
			),
			"yaw": 0.0,
			"id": "japanese-central-north",
		},
		{
			"position": Vector3(
				0.0,
				0.0,
				2.35
			),
			"yaw": PI,
			"id": "japanese-central-south",
		},
	]

	for spec: Dictionary in central_cushions:
		_place_floor_cushion(
			spec["position"],
			float(
				spec["yaw"]
			),
			str(
				spec["id"]
			),
			"Book"
		)


func _build_side_study_zones() -> void:
	# Left quiet reading table.
	_build_side_low_table_zone(
		Vector3(
			-10.6,
			0.0,
			5.2
		),
		"left"
	)

	# Right tea-study table.
	_build_side_low_table_zone(
		Vector3(
			10.6,
			0.0,
			5.2
		),
		"right"
	)


func _build_side_low_table_zone(
	centre: Vector3,
	label: String
) -> void:
	_instance_asset(
		"low_table",
		centre,
		Vector3(
			1.22,
			1.0,
			1.06
		),
		0.0,
		"SideLowTable_%s"
		% label
	)

	_add_blocker(
		centre
		+ Vector3.UP
		* 0.42,
		Vector3(
			3.2,
			0.86,
			2.1
		),
		0.0,
		"SideLowTableBlocker_%s"
		% label
	)

	_instance_asset(
		"kettle",
		centre
		+ Vector3(
			0.35,
			0.76,
			0.0
		),
		Vector3(
			0.90,
			0.90,
			0.90
		),
		0.0,
		"SideKettle"
	)

	_instance_asset(
		"teacup",
		centre
		+ Vector3(
			-0.45,
			0.76,
			0.15
		),
		Vector3.ONE,
		0.0,
		"SideTeacup"
	)

	var west_position := centre + Vector3(
		-2.0,
		0.0,
		0.0
	)
	var east_position := centre + Vector3(
		2.0,
		0.0,
		0.0
	)

	_place_floor_cushion(
		west_position,
		-PI
		/ 2.0,
		"japanese-%s-west"
		% label,
		"Book"
	)

	_place_floor_cushion(
		east_position,
		PI
		/ 2.0,
		"japanese-%s-east"
		% label,
		(
			"Laptop"
			if label == "right"
			else "Book"
		)
	)


func _place_floor_cushion(
	position_value: Vector3,
	seat_yaw: float,
	seat_id: String,
	study_type: String
) -> void:
	_instance_asset(
		"cushion",
		position_value,
		Vector3.ONE,
		seat_yaw,
		"JapaneseFloorCushion"
	)

	var forward: Vector3 = (
		Basis(
			Vector3.UP,
			seat_yaw
		)
		* Vector3.FORWARD
	)

	var right: Vector3 = (
		Basis(
			Vector3.UP,
			seat_yaw
		)
		* Vector3.RIGHT
	)

	var sitting: Vector3 = (
		position_value
		+ Vector3.UP
		* 0.28
	)

	var standing: Vector3 = (
		position_value
		- forward
		* 0.90
	)

	var camera_target: Vector3 = (
		sitting
		+ Vector3.UP
		* 0.85
		+ forward
		* 0.15
	)

	var camera_position: Vector3 = (
		sitting
		+ forward
		* 3.8
		+ right
		* 2.4
		+ Vector3.UP
		* 2.35
	)

	_seat_specs.append(
		{
			"id": seat_id,
			"standing": standing,
			"sitting": sitting,
			"yaw": seat_yaw,
			"study_type": study_type,
			"camera_position": camera_position,
			"camera_target": camera_target,
		}
	)


func _build_decor_and_lighting() -> void:
	# Tokonoma-like south-wall display.
	_instance_asset(
		"scroll",
		Vector3(
			0.0,
			1.75,
			14.65
		),
		Vector3.ONE,
		PI,
		"CentralHangingScroll"
	)

	_instance_asset(
		"lowboard",
		Vector3(
			0.0,
			0.0,
			12.6
		),
		Vector3(
			1.20,
			1.0,
			1.0
		),
		PI,
		"SouthLowboard"
	)

	_instance_asset(
		"bonsai_pine",
		Vector3(
			-1.6,
			0.95,
			12.5
		),
		Vector3.ONE,
		0.15,
		"SouthBonsaiPine"
	)

	_instance_asset(
		"bonsai_kokedama",
		Vector3(
			1.35,
			0.95,
			12.5
		),
		Vector3.ONE,
		-0.15,
		"SouthBonsaiKokedama"
	)

	# Storage on both sides, matching the reference's low furniture.
	_instance_asset(
		"chest",
		Vector3(
			-16.6,
			0.0,
			9.8
		),
		Vector3.ONE,
		PI
		/ 2.0,
		"JapaneseChest"
	)

	_instance_asset(
		"bamboo_shelf",
		Vector3(
			16.5,
			0.0,
			9.8
		),
		Vector3.ONE,
		-PI
		/ 2.0,
		"JapaneseBambooShelf"
	)

	_instance_asset(
		"cushion_pile",
		Vector3(
			-14.6,
			0.0,
			10.8
		),
		Vector3.ONE,
		0.15,
		"SpareCushions"
	)

	# Floor lamps create most of the warm room light.
	var lamp_specs: Array[Vector3] = [
		Vector3(
			-15.5,
			0.0,
			-10.5
		),
		Vector3(
			15.5,
			0.0,
			-10.5
		),
		Vector3(
			-14.8,
			0.0,
			11.5
		),
		Vector3(
			14.8,
			0.0,
			11.5
		),
	]

	for position_value: Vector3 in lamp_specs:
		_instance_asset(
			"lamp",
			position_value,
			Vector3.ONE,
			0.0,
			"JapaneseFloorLamp"
		)

		_add_omni_light(
			position_value
			+ Vector3.UP
			* 1.05,
			Color(
				"#ffc982"
			),
			1.25,
			5.5,
			"JapaneseWarmFloorLight"
		)

	# Two bamboo lamps frame the open garden side.
	for x_value: float in [
		-5.0,
		5.0
	]:
		_instance_asset(
			"bamboo_lamp",
			Vector3(
				x_value,
				0.0,
				-12.5
			),
			Vector3.ONE,
			0.0,
			"JapaneseBambooLamp"
		)

		_add_omni_light(
			Vector3(
				x_value,
				1.0,
				-12.5
			),
			Color(
				"#ffbf70"
			),
			1.10,
			5.0,
			"JapaneseBambooWarmLight"
		)

	# The reference has one soft paper pendant rather than bright modern ceiling
	# strips. Keep it central and gentle.
	_instance_asset(
		"ceiling_lamp",
		Vector3(
			0.0,
			3.75,
			0.0
		),
		Vector3.ONE,
		0.0,
		"JapanesePaperPendant"
	)

	_add_omni_light(
		Vector3(
			0.0,
			3.45,
			0.0
		),
		Color(
			"#ffd59b"
		),
		0.90,
		7.0,
		"JapaneseCentralSoftLight"
	)


func _build_study_spots() -> Array:
	var result: Array = []
	var index: int = 0

	for spec: Dictionary in _seat_specs:
		var spot := STUDY_SPOT_SCRIPT.new()
		spot.name = "StudySpot_%02d" % index

		var sitting: Vector3 = spec[
			"sitting"
		]
		var standing: Vector3 = spec[
			"standing"
		]
		var camera_position: Vector3 = spec[
			"camera_position"
		]
		var camera_target: Vector3 = spec[
			"camera_target"
		]
		var seat_yaw: float = float(
			spec["yaw"]
		)

		var inverse_basis := Basis(
			Vector3.UP,
			seat_yaw
		).inverse()

		spot.position = sitting
		spot.rotation = Vector3(
			0.0,
			seat_yaw,
			0.0
		)
		spot.seat_id = str(
			spec["id"]
		)
		spot.study_type = str(
			spec["study_type"]
		)
		spot.seat_type = "floor_cushion"
		spot.seated_visual_offset = (
			FLOOR_VISUAL_OFFSET
		)
		spot.seat_height = 0.28
		spot.sitting_offset = Vector3.ZERO
		spot.standing_offset = (
			inverse_basis
			* (
				standing
				- sitting
			)
		)
		spot.camera_position_offset = (
			inverse_basis
			* (
				camera_position
				- sitting
			)
		)
		spot.camera_target_offset = (
			inverse_basis
			* (
				camera_target
				- sitting
			)
		)
		spot.local_facing_yaw = 0.0
		spot.reset_occupancy()

		_room_root.add_child(
			spot
		)
		spot.owner = _scene_root
		spot.add_to_group(
			"editable_study_spot",
			true
		)

		result.append(
			spot
		)
		index += 1

	return result


func _build_npcs(
	spots: Array
) -> void:
	var npc_specs: Array[Dictionary] = [
		{
			"name": "Hana",
			"timer": "24m",
			"character": "rosie",
			"seat_index": 0,
		},
		{
			"name": "Iko",
			"timer": "46m",
			"character": "raymond",
			"seat_index": 2,
		},
		{
			"name": "Ren",
			"timer": "39m",
			"character": "bob",
			"seat_index": 5,
		},
		{
			"name": "Ami",
			"timer": "17m",
			"character": "rosie",
			"seat_index": 7,
		},
	]

	for spec: Dictionary in npc_specs:
		var seat_index: int = int(
			spec["seat_index"]
		)

		if (
			seat_index < 0
			or seat_index >= spots.size()
		):
			continue

		var spot = spots[
			seat_index
		]

		var npc := NPC_CONTROLLER_SCRIPT.new()
		npc.name = "NPC_%s" % str(
			spec["name"]
		)
		npc.editor_display_name = str(
			spec["name"]
		)
		npc.editor_occupant_id = str(
			spec["name"]
		)
		npc.editor_timer_text = str(
			spec["timer"]
		)
		npc.editor_seated = true
		npc.editor_study_kind = str(
			spot.study_type
		)
		npc.editor_spot_id = str(
			spot.seat_id
		)
		npc.editor_character_id = str(
			spec["character"]
		)
		npc.position = spot.position
		npc.rotation.y = spot.rotation.y
		npc.process_mode = (
			Node.PROCESS_MODE_DISABLED
		)

		_room_root.add_child(
			npc
		)
		npc.owner = _scene_root
		npc.add_to_group(
			"editable_npc",
			true
		)

		var label := Label3D.new()
		label.name = "NameTimerLabel"
		label.text = "%s  ·  %s" % [
			str(
				spec["name"]
			),
			str(
				spec["timer"]
			),
		]
		label.position = Vector3(
			0.0,
			2.85,
			0.0
		)
		label.font_size = 22
		label.outline_size = 6
		label.modulate = Color(
			"#f6e9d5"
		)
		label.billboard = (
			BaseMaterial3D.BILLBOARD_ENABLED
		)

		npc.add_child(
			label
		)
		label.owner = _scene_root


func _build_review_cameras() -> void:
	var cameras: Array[Dictionary] = [
		{
			"name": "JapaneseWide",
			"position": Vector3(
				15.0,
				8.0,
				13.0
			),
			"target": Vector3(
				0.0,
				0.75,
				0.0
			),
			"broll": true,
		},
		{
			"name": "JapaneseCentralTable",
			"position": Vector3(
				8.8,
				3.8,
				8.0
			),
			"target": Vector3(
				0.0,
				0.65,
				0.0
			),
			"broll": true,
		},
		{
			"name": "JapaneseGarden",
			"position": Vector3(
				7.5,
				3.6,
				-4.0
			),
			"target": Vector3(
				0.0,
				1.6,
				-22.0
			),
			"broll": true,
		},
		{
			"name": "JapaneseTeaCorner",
			"position": Vector3(
				16.0,
				3.2,
				10.0
			),
			"target": Vector3(
				10.6,
				0.75,
				5.2
			),
			"broll": false,
		},
	]

	for spec: Dictionary in cameras:
		var camera := Camera3D.new()
		camera.name = str(
			spec["name"]
		)
		camera.fov = 39.0
		camera.current = false
		camera.look_at_from_position(
			spec["position"],
			spec["target"],
			Vector3.UP
		)

		_room_root.add_child(
			camera
		)
		camera.owner = _scene_root
		camera.add_to_group(
			"editable_focus_camera",
			true
		)

		if bool(
			spec["broll"]
		):
			camera.add_to_group(
				"editable_broll_camera",
				true
			)


func _build_player_spawn() -> void:
	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector3(
		0.0,
		0.65,
		11.5
	)
	spawn.rotation.y = PI

	_room_root.add_child(
		spawn
	)
	spawn.owner = _scene_root
	spawn.add_to_group(
		"editable_player_spawn",
		true
	)


func _instance_asset(
	key: String,
	position_value: Vector3,
	scale_value: Vector3,
	yaw: float,
	node_name: String
) -> Node3D:
	var path: String = str(
		ASSETS.get(
			key,
			""
		)
	)

	if (
		path.is_empty()
		or not ResourceLoader.exists(
			path
		)
	):
		return null

	var packed := load(
		path
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

	_room_root.add_child(
		node
	)
	node.owner = _scene_root

	return node


func _box(
	parent: Node,
	size: Vector3,
	position_value: Vector3,
	material: Material,
	node_name: String
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.position = position_value

	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material

	parent.add_child(
		node
	)
	node.owner = _scene_root

	return node


func _cylinder(
	parent: Node,
	radius: float,
	height: float,
	position_value: Vector3,
	material: Material,
	node_name: String
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.position = position_value

	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 18
	node.mesh = mesh
	node.material_override = material

	parent.add_child(
		node
	)
	node.owner = _scene_root

	return node


func _sphere(
	parent: Node,
	scale_value: Vector3,
	position_value: Vector3,
	material: Material,
	node_name: String
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.position = position_value
	node.scale = scale_value

	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 18
	mesh.rings = 10
	node.mesh = mesh
	node.material_override = material

	parent.add_child(
		node
	)
	node.owner = _scene_root

	return node


func _add_blocker(
	position_value: Vector3,
	size: Vector3,
	yaw: float,
	node_name: String
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.rotation.y = yaw

	var shape_node := CollisionShape3D.new()
	shape_node.name = "CollisionShape"

	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape

	body.add_child(
		shape_node
	)
	_room_root.add_child(
		body
	)

	body.owner = _scene_root
	shape_node.owner = _scene_root

	return body


func _add_omni_light(
	position_value: Vector3,
	color: Color,
	energy: float,
	range_value: float,
	node_name: String
) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = position_value
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	light.shadow_enabled = true

	_room_root.add_child(
		light
	)
	light.owner = _scene_root

	return light


func _material(
	name_value: String,
	color: Color,
	roughness: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = name_value
	material.albedo_color = color
	material.roughness = roughness
	return material


func _emissive_material(
	name_value: String,
	color: Color,
	energy: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = name_value
	material.albedo_color = color
	material.roughness = 0.68
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _backup_original() -> String:
	var absolute_dir: String = (
		ProjectSettings.globalize_path(
			BACKUP_DIR
		)
	)

	var make_error: int = (
		DirAccess.make_dir_recursive_absolute(
			absolute_dir
		)
	)

	if (
		make_error != OK
		and make_error
		!= ERR_ALREADY_EXISTS
	):
		return ""

	var timestamp: String = (
		Time.get_datetime_string_from_system()
	)
	timestamp = timestamp.replace(
		":",
		"-"
	).replace(
		"T",
		"_"
	)

	var backup_path: String = (
		BACKUP_DIR
		+ "/japanese_before_redesign_"
		+ timestamp
		+ ".tscn"
	)

	var copy_error: int = (
		DirAccess.copy_absolute(
			ProjectSettings.globalize_path(
				JAPANESE_SCENE_PATH
			),
			ProjectSettings.globalize_path(
				backup_path
			)
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
		"No new Japanese Study scene changes were saved by this run."
	)
	print("")
	quit(
		1
	)
