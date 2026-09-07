extends SceneTree

# StudyTown Grand Library redesign.
#
# This script replaces ONLY the editable Library scene:
#
#   res://assets/dev_local/room_layouts/library.tscn
#
# It does NOT rebake rooms and it does NOT touch the Garden, Train, or
# Japanese Study scenes.
#
# Design goals:
# - preserve the existing 44 x 32 gameplay footprint
# - clear entrance / player spawn
# - two communal antique study tables (8 seats)
# - four east-window study desks (4 seats)
# - fireplace lounge (4 seats)
# - 16 usable study positions total
# - only 4 NPCs by default
# - dense real bookshelves along west / north-west
# - cool dusk ambient light + localized warm lamps / fireplace
# - visible exterior courtyard beyond the east windows
#
# A timestamped backup of library.tscn is created before saving.

const LIBRARY_SCENE_PATH := (
	"res://assets/dev_local/room_layouts/library.tscn"
)

const BACKUP_DIR := (
	"res://assets/dev_local/room_layouts/backups"
)

const RUNTIME_DIR := (
	"res://assets/dev_local/blender_generated/runtime/"
)

const STUDY_SPOT_SCRIPT := preload(
	"res://scripts/study/study_spot.gd"
)

const NPC_CONTROLLER_SCRIPT := preload(
	"res://scripts/npc/npc_controller.gd"
)

const ASSETS := {
	"bookshelf":
		"res://assets/dev_local/blender_generated/runtime/library_bookshelf.glb",
	"bookstand":
		"res://assets/dev_local/blender_generated/runtime/library_bookstand.glb",
	"study_desk":
		"res://assets/dev_local/blender_generated/runtime/library_study_desk.glb",
	"antique_bureau":
		"res://assets/dev_local/blender_generated/runtime/library_antique_bureau.glb",
	"antique_table":
		"res://assets/dev_local/blender_generated/runtime/library_antique_table.glb",
	"serving_cart":
		"res://assets/dev_local/blender_generated/runtime/library_serving_cart.glb",
	"study_chair":
		"res://assets/dev_local/blender_generated/runtime/library_study_chair.glb",
	"antique_chair":
		"res://assets/dev_local/blender_generated/runtime/library_antique_chair.glb",
	"elegant_sofa":
		"res://assets/dev_local/blender_generated/runtime/library_elegant_sofa.glb",
	"fireplace":
		"res://assets/dev_local/blender_generated/runtime/library_fireplace.glb",
	"bankers_lamp":
		"res://assets/dev_local/blender_generated/runtime/library_bankers_lamp.glb",
	"globe":
		"res://assets/dev_local/blender_generated/runtime/library_globe.glb",
	"antique_clock":
		"res://assets/dev_local/blender_generated/runtime/library_antique_clock.glb",
	"books":
		"res://assets/dev_local/blender_generated/runtime/library_books.glb",
	"book_opened":
		"res://assets/dev_local/blender_generated/runtime/library_book_opened.glb",
	"magazine_rack":
		"res://assets/dev_local/blender_generated/runtime/library_magazine_rack.glb",
	"typewriter":
		"res://assets/dev_local/blender_generated/runtime/library_typewriter.glb",
	"corkboard":
		"res://assets/dev_local/blender_generated/runtime/library_corkboard.glb",
	"study_set":
		"res://assets/dev_local/blender_generated/runtime/library_study_set.glb",
}

const REQUIRED_ASSET_KEYS := [
	"bookshelf",
	"study_desk",
	"antique_table",
	"study_chair",
	"antique_chair",
	"elegant_sofa",
	"fireplace",
]

const OPTIONAL_TREE_PATHS := [
	"res://assets/dev_local/blender_generated/runtime/garden_big_tree.glb",
	"res://assets/dev_local/blender_generated/runtime/garden_oak_tree.glb",
]

const DESK_VISUAL_OFFSET := Vector3(
	0.0,
	0.15,
	0.12
)

const ARMCHAIR_VISUAL_OFFSET := Vector3(
	0.0,
	0.40,
	0.12
)

var _scene_root: Node3D
var _redesign_root: Node3D
var _materials: Dictionary = {}
var _seat_specs: Array = []


func _initialize() -> void:
	call_deferred(
		"_run"
	)


func _run() -> void:
	print("")
	print("# STUDYTOWN GRAND LIBRARY REDESIGN")
	print("")

	if not FileAccess.file_exists(
		LIBRARY_SCENE_PATH
	):
		_fail(
			"Editable library.tscn does not exist. "
			+ "Do not use --force on the room baker; "
			+ "create the editable rooms only if they have never been baked."
		)
		return

	for key in REQUIRED_ASSET_KEYS:
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
			_fail(
				"Missing required Library runtime asset: "
				+ path
				+ "\nRun blender_library_archive_assets.py first, "
				+ "then run a headless Godot import."
			)
			return

	var packed := load(
		LIBRARY_SCENE_PATH
	) as PackedScene

	if packed == null:
		_fail(
			"Could not load library.tscn."
		)
		return

	var loaded_root := packed.instantiate()

	if (
		loaded_root == null
		or not (loaded_root is Node3D)
	):
		if loaded_root != null:
			loaded_root.free()

		_fail(
			"Library scene root is not Node3D."
		)
		return

	_scene_root = loaded_root as Node3D

	var backup_path := _backup_original()

	if backup_path.is_empty():
		_scene_root.free()

		_fail(
			"Could not create Library backup."
		)
		return

	_clear_existing_library_content()

	_scene_root.set_meta(
		"studytown_room_index",
		0
	)

	_scene_root.set_meta(
		"studytown_room_id",
		"library"
	)

	_scene_root.set_meta(
		"redesigned_by",
		"apply_library_redesign.gd"
	)

	_scene_root.set_meta(
		"library_redesign_version",
		1
	)

	_build_materials()

	_redesign_root = Node3D.new()
	_redesign_root.name = "LibraryRedesign"
	_scene_root.add_child(
		_redesign_root
	)
	_redesign_root.owner = _scene_root

	_build_environment()
	_build_shell()
	_build_exterior_courtyard()
	_build_bookstacks()
	_build_reception()
	_build_communal_tables()
	_build_window_desks()
	_build_fireplace_lounge()
	_build_remaining_decor()
	_build_cozy_density_pass()

	var study_spots := _build_study_spots()

	_build_npcs(
		study_spots
	)

	_build_review_cameras()
	_build_player_spawn()

	var repacked := PackedScene.new()

	var pack_error := repacked.pack(
		_scene_root
	)

	if pack_error != OK:
		_scene_root.free()

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
		LIBRARY_SCENE_PATH
	)

	_scene_root.free()
	_scene_root = null

	if save_error != OK:
		_fail(
			"ResourceSaver.save failed with error %d. Backup: %s"
			% [
				save_error,
				backup_path,
			]
		)
		return

	print("Footprint:              44 x 32")
	print("Study positions:        ", _seat_specs.size())
	print("Communal table seats:   8")
	print("Window desk seats:      4")
	print("Fireplace lounge seats: 4")
	print("Default NPC count:      4")
	print("Ambient:                dark medieval night / warm fire and candle light")
	print("Local light:            warm banker lamps + fireplace")
	print("Exterior:               moonlit stone cloister / old courtyard")
	print("Left stacks:            additional sconces + floor candelabra")
	print("Right side:             paired window bays + reading alcove + archive corner")
	print("Backup:                 ", backup_path)
	print("")
	print("DONE")
	print("")

	quit(
		0
	)


func _clear_existing_library_content() -> void:
	for child: Node in _scene_root.get_children():
		_scene_root.remove_child(
			child
		)
		child.free()


func _build_materials() -> void:
	_materials.clear()

	_materials["floor"] = _material(
		"LibraryFloor",
		Color(
			"#3f291b"
		),
		0.80
	)

	_materials["floor_alt"] = _material(
		"LibraryFloorAlt",
		Color(
			"#4a3020"
		),
		0.82
	)

	_materials["wood_dark"] = _material(
		"LibraryDarkWood",
		Color(
			"#1d130e"
		),
		0.82
	)

	_materials["wood_mid"] = _material(
		"LibraryMidWood",
		Color(
			"#4b3223"
		),
		0.80
	)

	_materials["wood_trim"] = _material(
		"LibraryTrim",
		Color(
			"#785333"
		),
		0.76
	)

	_materials["plaster"] = _material(
		"LibraryPlaster",
		Color(
			"#71685f"
		),
		0.92
	)

	_materials["plaster_dark"] = _material(
		"LibraryPlasterDark",
		Color(
			"#514a44"
		),
		0.94
	)

	_materials["rug"] = _material(
		"LibraryRug",
		Color(
			"#3a302b"
		),
		0.96
	)

	_materials["stone"] = _material(
		"LibraryStone",
		Color(
			"#47433f"
		),
		0.94
	)

	_materials["grass"] = _material(
		"CourtyardGrass",
		Color(
			"#1f3026"
		),
		0.98
	)

	_materials["path"] = _material(
		"CourtyardPath",
		Color(
			"#58534c"
		),
		0.96
	)

	_materials["building"] = _material(
		"CourtyardBuilding",
		Color(
			"#25272a"
		),
		0.93
	)

	_materials["tree_trunk"] = _material(
		"CourtyardTreeTrunk",
		Color(
			"#3b2d24"
		),
		0.95
	)

	_materials["tree_leaf"] = _material(
		"CourtyardTreeLeaf",
		Color(
			"#263f35"
		),
		0.98
	)

	_materials["rug_border"] = _material(
		"LibraryRugBorder",
		Color(
			"#78603a"
		),
		0.92
	)

	_materials["fabric_red"] = _material(
		"LibraryFabricRed",
		Color(
			"#5b2f2a"
		),
		0.94
	)

	_materials["fabric_teal"] = _material(
		"LibraryFabricTeal",
		Color(
			"#29443f"
		),
		0.94
	)

	_materials["plant_pot"] = _material(
		"LibraryPlantPot",
		Color(
			"#6a4030"
		),
		0.88
	)

	_materials["plant_leaf"] = _material(
		"LibraryPlantLeaf",
		Color(
			"#2d4b35"
		),
		0.96
	)

	_materials["painting_gold"] = _material(
		"LibraryPaintingGold",
		Color(
			"#8b6a38"
		),
		0.72
	)

	_materials["painting_red"] = _material(
		"LibraryPaintingRed",
		Color(
			"#4f2824"
		),
		0.90
	)

	_materials["painting_blue"] = _material(
		"LibraryPaintingBlue",
		Color(
			"#293747"
		),
		0.90
	)

	_materials["glass"] = _glass_material()

	_materials["window_glow"] = _emissive_material(
		"CourtyardWindowGlow",
		Color(
			"#d7b06c"
		),
		1.35
	)

	_materials["fire_glow"] = _emissive_material(
		"LibraryFireGlow",
		Color(
			"#ff9d4e"
		),
		2.2
	)


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "LibraryMedievalNightEnvironment"
	_redesign_root.add_child(
		world_environment
	)
	world_environment.owner = _scene_root

	var environment := Environment.new()

	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(
		"#070b13"
	)
	sky_material.sky_horizon_color = Color(
		"#171e2b"
	)
	sky_material.sky_curve = 0.18
	sky_material.sky_energy_multiplier = 0.30
	sky_material.ground_bottom_color = Color(
		"#080909"
	)
	sky_material.ground_horizon_color = Color(
		"#15191c"
	)

	var sky := Sky.new()
	sky.sky_material = sky_material

	environment.background_mode = (
		Environment.BG_SKY
	)
	environment.sky = sky

	# The room itself stays dark and cool. Warmth comes from real local sources:
	# fireplace, candles, wall sconces and exterior lanterns.
	environment.ambient_light_source = (
		Environment.AMBIENT_SOURCE_COLOR
	)
	environment.ambient_light_color = Color(
		"#586273"
	)
	environment.ambient_light_energy = 0.24

	environment.tonemap_mode = (
		Environment.TONE_MAPPER_FILMIC
	)

	environment.fog_enabled = true
	environment.fog_light_color = Color(
		"#3d4654"
	)
	environment.fog_light_energy = 0.24
	environment.fog_density = 0.0065
	environment.fog_sky_affect = 0.72

	world_environment.environment = environment

	var moon_fill := DirectionalLight3D.new()
	moon_fill.name = "LibraryMoonlight"
	moon_fill.light_color = Color(
		"#9aaac7"
	)
	moon_fill.light_energy = 0.20
	moon_fill.shadow_enabled = true
	moon_fill.rotation_degrees = Vector3(
		-52.0,
		-38.0,
		0.0
	)

	_redesign_root.add_child(
		moon_fill
	)
	moon_fill.owner = _scene_root

func _build_shell() -> void:
	# Floor.
	_box(
		_redesign_root,
		Vector3(
			44.0,
			0.35,
			32.0
		),
		Vector3(
			0.0,
			-0.22,
			0.0
		),
		_materials["floor"],
		"LibraryFloor"
	)

	_add_blocker(
		Vector3(
			0.0,
			-0.24,
			0.0
		),
		Vector3(
			44.0,
			0.45,
			32.0
		),
		0.0,
		"LibraryFloorCollision"
	)

	# A very subtle board rhythm keeps the large floor from reading as one flat
	# procedural slab.
	for x in range(
		-20,
		21,
		4
	):
		_box(
			_redesign_root,
			Vector3(
				0.035,
				0.012,
				31.2
			),
			Vector3(
				float(x),
				-0.026,
				0.0
			),
			_materials["floor_alt"],
			"FloorBoardLine_%d" % x
		)

	# Central quiet rug.
	_box(
		_redesign_root,
		Vector3(
			12.5,
			0.045,
			13.8
		),
		Vector3(
			0.0,
			0.025,
			-0.4
		),
		_materials["rug"],
		"CentralStudyRug"
	)

	# Warm border makes the study area read as a deliberate cozy zone rather
	# than a large plain floor rectangle.
	_box(
		_redesign_root,
		Vector3(
			13.1,
			0.022,
			14.4
		),
		Vector3(
			0.0,
			0.013,
			-0.4
		),
		_materials["rug_border"],
		"CentralStudyRugBorder"
	)

	_box(
		_redesign_root,
		Vector3(
			12.5,
			0.045,
			13.8
		),
		Vector3(
			0.0,
			0.027,
			-0.4
		),
		_materials["rug"],
		"CentralStudyRugTop"
	)

	# North wall.
	_box(
		_redesign_root,
		Vector3(
			44.4,
			6.5,
			0.55
		),
		Vector3(
			0.0,
			3.05,
			-16.0
		),
		_materials["plaster"],
		"NorthWall"
	)

	_add_blocker(
		Vector3(
			0.0,
			3.0,
			-15.75
		),
		Vector3(
			44.0,
			6.4,
			0.65
		),
		0.0,
		"NorthBoundary"
	)

	# West wall.
	_box(
		_redesign_root,
		Vector3(
			0.55,
			6.5,
			32.0
		),
		Vector3(
			-22.0,
			3.05,
			0.0
		),
		_materials["plaster"],
		"WestWall"
	)

	_add_blocker(
		Vector3(
			-21.75,
			3.0,
			0.0
		),
		Vector3(
			0.65,
			6.4,
			32.0
		),
		0.0,
		"WestBoundary"
	)

	# South wall with a wide visual doorway in the middle. The invisible room
	# boundary remains continuous so players cannot walk out of the gameplay
	# footprint.
	for side in [
		-1.0,
		1.0
	]:
		_box(
			_redesign_root,
			Vector3(
				18.9,
				6.5,
				0.55
			),
			Vector3(
				side * 12.55,
				3.05,
				16.0
			),
			_materials["plaster"],
			(
				"SouthWallLeft"
				if side < 0.0
				else "SouthWallRight"
			)
		)

	_add_blocker(
		Vector3(
			0.0,
			3.0,
			15.75
		),
		Vector3(
			44.0,
			6.4,
			0.65
		),
		0.0,
		"SouthBoundary"
	)

	# East wall is mostly glass.
	_box(
		_redesign_root,
		Vector3(
			0.55,
			0.95,
			32.0
		),
		Vector3(
			22.0,
			0.32,
			0.0
		),
		_materials["plaster_dark"],
		"EastWindowSillWall"
	)

	_box(
		_redesign_root,
		Vector3(
			0.55,
			1.15,
			32.0
		),
		Vector3(
			22.0,
			5.80,
			0.0
		),
		_materials["plaster"],
		"EastWindowHeaderWall"
	)

	_add_blocker(
		Vector3(
			21.75,
			3.0,
			0.0
		),
		Vector3(
			0.65,
			6.4,
			32.0
		),
		0.0,
		"EastBoundary"
	)

	# Wainscot gives the walls a richer silhouette while the main ambient light
	# stays neutral/cool.
	_box(
		_redesign_root,
		Vector3(
			43.8,
			1.15,
			0.22
		),
		Vector3(
			0.0,
			0.58,
			-15.68
		),
		_materials["wood_dark"],
		"NorthWainscot"
	)

	_box(
		_redesign_root,
		Vector3(
			0.22,
			1.15,
			31.4
		),
		Vector3(
			-21.68,
			0.58,
			0.0
		),
		_materials["wood_dark"],
		"WestWainscot"
	)

	# East windows: five large bays.
	for window_z in [
		-12.0,
		-6.0,
		0.0,
		6.0,
		12.0
	]:
		_build_east_window(
			window_z
		)

	# Interior beams only; no full ceiling, so the existing elevated exploration
	# camera remains unobstructed.
	for z in [
		-12.0,
		0.0,
		12.0
	]:
		_box(
			_redesign_root,
			Vector3(
				43.0,
				0.18,
				0.20
			),
			Vector3(
				-0.5,
				6.12,
				z
			),
			_materials["wood_dark"],
			"CeilingBeam_%d" % int(
				z
			)
		)


func _build_east_window(
	window_z: float
) -> void:
	var centre := Vector3(
		21.83,
		3.05,
		window_z
	)

	_box(
		_redesign_root,
		Vector3(
			0.10,
			4.0,
			4.75
		),
		centre,
		_materials["glass"],
		"EastGlass_%d" % int(
			window_z
		)
	)

	for z_offset in [
		-2.47,
		2.47
	]:
		_box(
			_redesign_root,
			Vector3(
				0.28,
				4.45,
				0.20
			),
			Vector3(
				21.70,
				3.05,
				window_z
				+ z_offset
			),
			_materials["wood_dark"],
			"EastWindowPost"
		)

	for y_value in [
		0.98,
		5.10
	]:
		_box(
			_redesign_root,
			Vector3(
				0.28,
				0.20,
				4.95
			),
			Vector3(
				21.70,
				y_value,
				window_z
			),
			_materials["wood_dark"],
			"EastWindowRail"
		)

	# One narrow centre mullion keeps the windows elegant instead of grid-heavy.
	_box(
		_redesign_root,
		Vector3(
			0.20,
			4.15,
			0.15
		),
		Vector3(
			21.69,
			3.05,
			window_z
		),
		_materials["wood_mid"],
		"EastWindowMullion"
	)

	# Pointed timber head gives the otherwise rectangular imported opening a
	# gothic silhouette from the gameplay camera.
	var gothic_left := _box(
		_redesign_root,
		Vector3(
			0.20,
			1.70,
			0.16
		),
		Vector3(
			21.64,
			5.25,
			window_z
			- 0.72
		),
		_materials["wood_dark"],
		"EastGothicArchLeft"
	)
	gothic_left.rotation.x = deg_to_rad(
		-36.0
	)

	var gothic_right := _box(
		_redesign_root,
		Vector3(
			0.20,
			1.70,
			0.16
		),
		Vector3(
			21.64,
			5.25,
			window_z
			+ 0.72
		),
		_materials["wood_dark"],
		"EastGothicArchRight"
	)
	gothic_right.rotation.x = deg_to_rad(
		36.0
	)


func _build_exterior_courtyard() -> void:
	# Moonlit stone courtyard immediately outside the east windows.
	_box(
		_redesign_root,
		Vector3(
			18.0,
			0.22,
			34.0
		),
		Vector3(
			31.0,
			-0.30,
			0.0
		),
		_materials["grass"],
		"MedievalCourtyardGround"
	)

	_box(
		_redesign_root,
		Vector3(
			3.0,
			0.10,
			33.0
		),
		Vector3(
			27.2,
			-0.13,
			0.0
		),
		_materials["stone"],
		"MedievalCourtyardStoneWalk"
	)

	# A dark stone cloister runs parallel to the library windows.
	_box(
		_redesign_root,
		Vector3(
			1.5,
			7.8,
			34.0
		),
		Vector3(
			38.5,
			3.2,
			0.0
		),
		_materials["building"],
		"OldCloisterBackWall"
	)

	for z_value in [
		-12.0,
		-6.0,
		0.0,
		6.0,
		12.0
	]:
		_build_cloister_arch(
			Vector3(
				35.5,
				0.0,
				z_value
			)
		)

	# Two heavier corner towers make the exterior read as an old monastic /
	# collegiate complex rather than a modern campus.
	for z_value in [
		-15.0,
		15.0
	]:
		_box(
			_redesign_root,
			Vector3(
				3.2,
				10.0,
				3.2
			),
			Vector3(
				40.0,
				4.6,
				z_value
			),
			_materials["stone"],
			"OldLibraryTower"
		)

		for y_value in [
			2.4,
			5.4,
			8.0
		]:
			_box(
				_redesign_root,
				Vector3(
					0.10,
					0.75,
					0.55
				),
				Vector3(
					38.35,
					y_value,
					z_value
				),
				_materials["window_glow"],
				"TowerLancetWindow"
			)

	# Dark mature trees frame the cloister.
	for data in [
		[
			Vector3(
				30.5,
				-0.15,
				-11.5
			),
			0.72,
			0.10
		],
		[
			Vector3(
				32.8,
				-0.15,
				-3.5
			),
			0.60,
			-0.25
		],
		[
			Vector3(
				30.8,
				-0.15,
				5.0
			),
			0.70,
			0.35
		],
		[
			Vector3(
				33.3,
				-0.15,
				12.0
			),
			0.58,
			-0.20
		],
	]:
		_place_courtyard_tree(
			data[0],
			float(
				data[1]
			),
			float(
				data[2]
			)
		)

	# Warm lanterns against the blue-black night.
	for z_value in [
		-9.0,
		0.0,
		9.0
	]:
		_build_courtyard_lamp(
			Vector3(
				27.0,
				0.0,
				z_value
			)
		)

func _build_cloister_arch(
	position_value: Vector3
) -> void:
	var root := Node3D.new()
	root.name = "CloisterArch"
	root.position = position_value
	_redesign_root.add_child(
		root
	)
	root.owner = _scene_root

	# Stone piers.
	for z_offset in [
		-2.25,
		2.25
	]:
		_box(
			root,
			Vector3(
				0.75,
				5.0,
				0.65
			),
			Vector3(
				0.0,
				2.45,
				z_offset
			),
			_materials["stone"],
			"CloisterPier"
		)

	# Pointed gothic head: two angled stone beams meeting at the centre.
	var left_arch := _box(
		root,
		Vector3(
			0.72,
			2.45,
			0.58
		),
		Vector3(
			0.0,
			5.25,
			-1.05
		),
		_materials["stone"],
		"CloisterArchLeft"
	)
	left_arch.rotation.x = deg_to_rad(
		-38.0
	)

	var right_arch := _box(
		root,
		Vector3(
			0.72,
			2.45,
			0.58
		),
		Vector3(
			0.0,
			5.25,
			1.05
		),
		_materials["stone"],
		"CloisterArchRight"
	)
	right_arch.rotation.x = deg_to_rad(
		38.0
	)

	# Warm recess deep inside each arch.
	_box(
		root,
		Vector3(
			0.08,
			2.3,
			2.7
		),
		Vector3(
			1.0,
			2.4,
			0.0
		),
		_materials["building"],
		"CloisterDarkRecess"
	)

	_build_candle_sconce(
		position_value
		+ Vector3(
			-0.75,
			2.15,
			0.0
		),
		0.0
	)


func _place_courtyard_tree(
	position_value: Vector3,
	scale_value: float,
	yaw: float
) -> void:
	for tree_path in OPTIONAL_TREE_PATHS:
		if ResourceLoader.exists(
			tree_path
		):
			var tree := _instance_scene(
				tree_path,
				position_value,
				Vector3.ONE
				* scale_value,
				yaw,
				"CourtyardTree"
			)

			if tree != null:
				return

	# Fallback silhouette.
	_cylinder(
		_redesign_root,
		0.34
		* scale_value,
		3.7
		* scale_value,
		position_value
		+ Vector3.UP
		* 1.85
		* scale_value,
		_materials["tree_trunk"],
		"CourtyardFallbackTrunk"
	)

	for offset in [
		Vector3(
			-0.8,
			3.5,
			0.0
		),
		Vector3(
			0.8,
			3.6,
			0.2
		),
		Vector3(
			0.0,
			4.25,
			0.0
		),
		Vector3(
			0.2,
			3.55,
			-0.8
		),
	]:
		_sphere(
			_redesign_root,
			Vector3(
				1.15,
				0.95,
				1.0
			)
			* scale_value,
			position_value
			+ offset
			* scale_value,
			_materials["tree_leaf"],
			"CourtyardFallbackLeaves"
		)


func _build_courtyard_lamp(
	position_value: Vector3
) -> void:
	_cylinder(
		_redesign_root,
		0.07,
		2.4,
		position_value
		+ Vector3.UP
		* 1.2,
		_materials["wood_dark"],
		"CourtyardLampPost"
	)

	_sphere(
		_redesign_root,
		Vector3(
			0.20,
			0.26,
			0.20
		),
		position_value
		+ Vector3.UP
		* 2.42,
		_materials["window_glow"],
		"CourtyardLampGlow"
	)

	_add_omni_light(
		position_value
		+ Vector3.UP
		* 2.35,
		Color(
			"#ffb66d"
		),
		0.90,
		4.8,
		"CourtyardLampLight"
	)


func _build_bookstacks() -> void:
	# West-wall run.
	for z_value in [
		-12.0,
		-8.0,
		-4.0,
		0.0,
		4.0,
		8.0,
		12.0
	]:
		_instance_asset(
			"bookshelf",
			Vector3(
				-20.90,
				0.0,
				z_value
			),
			Vector3.ONE,
			-PI
			/ 2.0,
			"WestWallBookshelf"
		)

		_add_blocker(
			Vector3(
				-20.70,
				2.05,
				z_value
			),
			Vector3(
				3.65,
				4.20,
				0.95
			),
			-PI
			/ 2.0,
			"WestWallShelfBlocker"
		)

	# North-west stack islands. These are deliberately shorter and more widely
	# spaced than the old procedural rows.
	for data in [
		[
			Vector3(
				-13.4,
				0.0,
				-8.5
			),
			0.0
		],
		[
			Vector3(
				-9.2,
				0.0,
				-8.5
			),
			0.0
		],
		[
			Vector3(
				-13.4,
				0.0,
				-2.5
			),
			PI
		],
		[
			Vector3(
				-9.2,
				0.0,
				-2.5
			),
			PI
		],
		[
			Vector3(
				-13.4,
				0.0,
				3.5
			),
			0.0
		],
		[
			Vector3(
				-9.2,
				0.0,
				3.5
			),
			0.0
		],
	]:
		_instance_asset(
			"bookshelf",
			data[0],
			Vector3.ONE,
			float(
				data[1]
			),
			"StackBookshelf"
		)

		_add_blocker(
			data[0]
			+ Vector3.UP
			* 2.05,
			Vector3(
				3.65,
				4.20,
				0.95
			),
			float(
				data[1]
			),
			"StackShelfBlocker"
		)


func _build_reception() -> void:
	# This reads as an old archivist's desk rather than a modern reception area.
	_instance_asset(
		"antique_bureau",
		Vector3(
			-7.3,
			0.0,
			11.4
		),
		Vector3(
			1.15,
			1.0,
			1.0
		),
		PI,
		"ArchivistBureau"
	)

	_add_blocker(
		Vector3(
			-7.3,
			0.95,
			11.4
		),
		Vector3(
			2.0,
			1.9,
			1.25
		),
		PI,
		"ArchivistBureauBlocker"
	)

	_instance_asset(
		"book_opened",
		Vector3(
			-7.3,
			1.43,
			11.0
		),
		Vector3(
			1.10,
			1.10,
			1.10
		),
		PI,
		"ArchivistLedger"
	)

	_instance_asset(
		"books",
		Vector3(
			-6.7,
			1.42,
			11.15
		),
		Vector3(
			0.72,
			0.72,
			0.72
		),
		-0.18,
		"ArchivistBookPile"
	)

	_instance_asset(
		"serving_cart",
		Vector3(
			-11.0,
			0.0,
			11.4
		),
		Vector3.ONE,
		PI
		/ 2.0,
		"RollingBookCart"
	)

	_add_blocker(
		Vector3(
			-11.0,
			0.65,
			11.4
		),
		Vector3(
			1.4,
			1.3,
			1.2
		),
		0.0,
		"BookCartBlocker"
	)

	_instance_asset(
		"bookstand",
		Vector3(
			-3.9,
			0.0,
			11.4
		),
		Vector3.ONE,
		PI,
		"IlluminatedBookstand"
	)

	_instance_asset(
		"book_opened",
		Vector3(
			-3.9,
			0.92,
			11.3
		),
		Vector3.ONE,
		PI,
		"BookstandManuscript"
	)

	_build_candle_cluster(
		Vector3(
			-8.0,
			1.48,
			11.1
		),
		2
	)

	_build_candle_cluster(
		Vector3(
			-3.2,
			0.95,
			11.3
		),
		1
	)

func _build_communal_tables() -> void:
	var table_centres := [
		Vector3(
			0.0,
			0.0,
			3.4
		),
		Vector3(
			0.0,
			0.0,
			-3.6
		),
	]

	var table_index := 0

	for centre in table_centres:
		_instance_asset(
			"antique_table",
			centre,
			Vector3(
				1.58,
				1.0,
				0.75
			),
			0.0,
			"CommunalTable_%d"
			% table_index
		)

		_add_blocker(
			centre
			+ Vector3.UP
			* 0.58,
			Vector3(
				4.35,
				1.20,
				1.85
			),
			0.0,
			"CommunalTableBlocker_%d"
			% table_index
		)

		for candle_x in [
			-1.15,
			1.15
		]:
			_build_candle_cluster(
				centre
				+ Vector3(
					candle_x,
					1.08,
					0.0
				),
				2
			)

		_instance_asset(
			"book_opened",
			centre
			+ Vector3(
				-0.45,
				1.08,
				0.28
			),
			Vector3.ONE,
			0.18,
			"CommunalOpenBook"
		)

		_instance_asset(
			"books",
			centre
			+ Vector3(
				0.55,
				1.07,
				-0.28
			),
			Vector3(
				0.82,
				0.82,
				0.82
			),
			-0.18,
			"CommunalBookStack"
		)

		_instance_asset(
			"study_set",
			centre
			+ Vector3(
				0.0,
				1.08,
				0.43
			),
			Vector3.ONE,
			0.0,
			"CommunalStudySet"
		)

		for x_value in [
			-1.25,
			1.25
		]:
			# North side of table: character faces +Z.
			var north_chair: Vector3 = (
				centre
				+ Vector3(
					x_value,
					0.0,
					-1.62
				)
			)

			_place_study_chair(
				north_chair,
				PI,
				(
					"Laptop"
					if x_value < 0.0
					else "Book"
				),
				"library-communal-%d-n-%d"
				% [
					table_index,
					(
						0
						if x_value < 0.0
						else 1
					),
				]
			)

			# South side of table: character faces -Z.
			var south_chair: Vector3 = (
				centre
				+ Vector3(
					x_value,
					0.0,
					1.62
				)
			)

			_place_study_chair(
				south_chair,
				0.0,
				(
					"Book"
					if x_value < 0.0
					else "Laptop"
				),
				"library-communal-%d-s-%d"
				% [
					table_index,
					(
						0
						if x_value < 0.0
						else 1
					),
				]
			)

		table_index += 1


func _place_study_chair(
	chair_position: Vector3,
	seat_yaw: float,
	study_type: String,
	seat_id: String
) -> void:
	var furniture_yaw := wrapf(
		seat_yaw
		+ PI,
		-PI,
		PI
	)

	_instance_asset(
		"study_chair",
		chair_position,
		Vector3.ONE,
		furniture_yaw,
		"StudyChair"
	)

	_add_blocker(
		chair_position
		+ Vector3.UP
		* 0.68,
		Vector3(
			0.90,
			1.35,
			0.90
		),
		furniture_yaw,
		"StudyChairBlocker"
	)

	_append_seat_from_furniture(
		seat_id,
		chair_position,
		seat_yaw,
		study_type,
		"desk_chair",
		0.10,
		0.35,
		1.24,
		DESK_VISUAL_OFFSET
	)


func _build_window_desks() -> void:
	# Two intimate window-reading bays instead of four isolated classroom-like
	# stations. Each bay shares one dark rug and one candle pool.
	var bay_centres := [
		-6.0,
		6.0
	]

	var index := 0

	for bay_z in bay_centres:
		# Shared rug under each pair.
		_box(
			_redesign_root,
			Vector3(
				6.0,
				0.035,
				5.0
			),
			Vector3(
				16.8,
				0.020,
				bay_z
			),
			_materials["rug"],
			"WindowReadingBayRug"
		)

		_box(
			_redesign_root,
			Vector3(
				6.35,
				0.018,
				5.35
			),
			Vector3(
				16.8,
				0.010,
				bay_z
			),
			_materials["rug_border"],
			"WindowReadingBayRugBorder"
		)

		for local_z in [
			-1.35,
			1.35
		]:
			var z_value: float = (
				float(bay_z)
				+ float(local_z)
			)

			var desk_position := Vector3(
				19.15,
				0.0,
				z_value
			)

			var chair_position := Vector3(
				17.25,
				0.0,
				z_value
			)

			_instance_asset(
				"study_desk",
				desk_position,
				Vector3.ONE,
				PI
				/ 2.0,
				"WindowStudyDesk_%d"
				% index
			)

			_add_blocker(
				desk_position
				+ Vector3.UP
				* 0.88,
				Vector3(
					1.10,
					1.75,
					2.05
				),
				0.0,
				"WindowDeskBlocker_%d"
				% index
			)

			# Old-manuscript / reading props rather than modern desk clutter.
			_instance_asset(
				"book_opened",
				Vector3(
					18.32,
					0.95,
					z_value
				),
				Vector3(
					0.94,
					0.94,
					0.94
				),
				-PI
				/ 2.0,
				"WindowDeskOpenBook_%d"
				% index
			)

			_instance_asset(
				"books",
				Vector3(
					18.42,
					0.94,
					z_value
					+ 0.43
				),
				Vector3(
					0.62,
					0.62,
					0.62
				),
				0.14,
				"WindowDeskBookStack_%d"
				% index
			)

			var seat_yaw := (
				-PI
				/ 2.0
			)

			var furniture_yaw := (
				PI
				/ 2.0
			)

			_instance_asset(
				"study_chair",
				chair_position,
				Vector3.ONE,
				furniture_yaw,
				"WindowStudyChair_%d"
				% index
			)

			_add_blocker(
				chair_position
				+ Vector3.UP
				* 0.68,
				Vector3(
					0.90,
					1.35,
					0.90
				),
				furniture_yaw,
				"WindowChairBlocker_%d"
				% index
			)

			_append_seat_from_furniture(
				"library-window-desk-%d"
				% index,
				chair_position,
				seat_yaw,
				(
					"Laptop"
					if index
					% 2
					== 0
					else "Book"
				),
				"desk_chair",
				0.10,
				0.35,
				1.24,
				DESK_VISUAL_OFFSET
			)

			index += 1

		# One low candle cluster between the paired desks.
		_build_candle_cluster(
			Vector3(
				18.15,
				0.96,
				bay_z
			),
			3
		)

		# Warm wall sconce beside each bay.
		_build_candle_sconce(
			Vector3(
				21.42,
				2.30,
				bay_z
			),
			-PI
			/ 2.0
		)

func _build_fireplace_lounge() -> void:
	# Separate rug visually defines the destination.
	_box(
		_redesign_root,
		Vector3(
			12.0,
			0.045,
			6.8
		),
		Vector3(
			0.0,
			0.030,
			-11.6
		),
		_materials["rug"],
		"FireplaceLoungeRug"
	)

	_instance_asset(
		"fireplace",
		Vector3(
			0.0,
			0.0,
			-15.45
		),
		Vector3.ONE,
		PI,
		"GrandFireplace"
	)

	_add_blocker(
		Vector3(
			0.0,
			1.35,
			-15.10
		),
		Vector3(
			5.6,
			2.8,
			1.25
		),
		0.0,
		"FireplaceBlocker"
	)

	# Small emissive glow sits just in front of the imported hearth opening.
	for x_value in [
		-0.65,
		0.0,
		0.65
	]:
		_sphere(
			_redesign_root,
			Vector3(
				0.30,
				0.48
				+ absf(
					x_value
				)
				* 0.12,
				0.18
			),
			Vector3(
				x_value,
				0.82,
				-14.55
			),
			_materials["fire_glow"],
			"FireplaceGlow"
		)

	_add_omni_light(
		Vector3(
			0.0,
			1.45,
			-13.85
		),
		Color(
			"#ff9f52"
		),
		4.0,
		7.2,
		"FireplaceWarmLight"
	)

	# Sofa.
	var sofa_position := Vector3(
		0.0,
		0.0,
		-9.80
	)

	_instance_asset(
		"elegant_sofa",
		sofa_position,
		Vector3(
			1.25,
			1.05,
			1.10
		),
		PI,
		"FireplaceSofa"
	)

	_add_blocker(
		sofa_position
		+ Vector3.UP
		* 0.82,
		Vector3(
			3.35,
			1.65,
			1.35
		),
		PI,
		"FireplaceSofaBlocker"
	)

	# Two authored seat positions across the same sofa.
	for x_value in [
		-0.72,
		0.72
	]:
		_append_seat_from_furniture(
			(
				"library-lounge-sofa-left"
				if x_value < 0.0
				else "library-lounge-sofa-right"
			),
			sofa_position
			+ Vector3(
				x_value,
				0.0,
				0.0
			),
			0.0,
			(
				"Book"
				if x_value < 0.0
				else "Laptop"
			),
			"armchair",
			0.10,
			0.62,
			1.35,
			ARMCHAIR_VISUAL_OFFSET
		)

	# Two antique side chairs, angled slightly toward the fireplace centre.
	var left_chair_position := Vector3(
		-3.45,
		0.0,
		-10.35
	)

	var right_chair_position := Vector3(
		3.45,
		0.0,
		-10.35
	)

	var left_yaw := -0.18
	var right_yaw := 0.18

	_place_lounge_chair(
		left_chair_position,
		left_yaw,
		"library-lounge-chair-left"
	)

	_place_lounge_chair(
		right_chair_position,
		right_yaw,
		"library-lounge-chair-right"
	)

	_instance_asset(
		"globe",
		Vector3(
			-5.55,
			0.0,
			-12.4
		),
		Vector3.ONE,
		0.18,
		"AntiqueGlobe"
	)

	_instance_asset(
		"bookstand",
		Vector3(
			5.35,
			0.0,
			-12.2
		),
		Vector3(
			1.05,
			1.05,
			1.05
		),
		-0.15,
		"LoungeBookstand"
	)

	_instance_asset(
		"book_opened",
		Vector3(
			5.35,
			0.90,
			-12.2
		),
		Vector3.ONE,
		-0.15,
		"LoungeOpenBook"
	)


func _place_lounge_chair(
	chair_position: Vector3,
	seat_yaw: float,
	seat_id: String
) -> void:
	var furniture_yaw := wrapf(
		seat_yaw
		+ PI,
		-PI,
		PI
	)

	_instance_asset(
		"antique_chair",
		chair_position,
		Vector3.ONE,
		furniture_yaw,
		"AntiqueLoungeChair"
	)

	_add_blocker(
		chair_position
		+ Vector3.UP
		* 0.80,
		Vector3(
			1.15,
			1.60,
			1.15
		),
		furniture_yaw,
		"AntiqueChairBlocker"
	)

	_append_seat_from_furniture(
		seat_id,
		chair_position,
		seat_yaw,
		"Book",
		"armchair",
		0.10,
		0.62,
		1.28,
		ARMCHAIR_VISUAL_OFFSET
	)


func _build_remaining_decor() -> void:
	_instance_asset(
		"antique_clock",
		Vector3(
			-20.30,
			0.0,
			-12.2
		),
		Vector3.ONE,
		-PI
		/ 2.0,
		"GrandfatherClock"
	)

	_add_blocker(
		Vector3(
			-20.25,
			1.80,
			-12.2
		),
		Vector3(
			1.10,
			3.60,
			1.10
		),
		0.0,
		"ClockBlocker"
	)

	# A few loose stacks make the room feel used without filling every surface.
	for data in [
		[
			Vector3(
				-16.8,
				0.05,
				-10.2
			),
			0.20
		],
		[
			Vector3(
				-15.2,
				0.05,
				6.8
			),
			-0.35
		],
		[
			Vector3(
				8.8,
				0.05,
				9.0
			),
			0.15
		],
	]:
		_instance_asset(
			"books",
			data[0],
			Vector3(
				0.86,
				0.86,
				0.86
			),
			float(
				data[1]
			),
			"LooseBookStack"
		)



func _build_cozy_density_pass() -> void:
	# Fill the north wall so very little bare plaster remains.
	for x_value in [
		-18.0,
		-13.8,
		-9.6,
		9.6,
		13.8,
		18.0
	]:
		_instance_asset(
			"bookshelf",
			Vector3(
				x_value,
				0.0,
				-15.15
			),
			Vector3.ONE,
			PI,
			"NorthWallBookshelf"
		)

		_add_blocker(
			Vector3(
				x_value,
				2.05,
				-14.95
			),
			Vector3(
				3.65,
				4.20,
				0.95
			),
			0.0,
			"NorthWallShelfBlocker"
		)

	# Two dense free-standing stacks create narrow, intimate book aisles.
	for data in [
		[
			Vector3(
				-15.0,
				0.0,
				8.6
			),
			0.0
		],
		[
			Vector3(
				-10.7,
				0.0,
				8.6
			),
			PI
		],
	]:
		_instance_asset(
			"bookshelf",
			data[0],
			Vector3(
				0.94,
				0.94,
				0.94
			),
			float(
				data[1]
			),
			"SouthReadingBookshelf"
		)

		_add_blocker(
			data[0]
			+ Vector3.UP
			* 1.92,
			Vector3(
				3.45,
				3.95,
				0.95
			),
			float(
				data[1]
			),
			"SouthReadingShelfBlocker"
		)

	# Stone pilasters and dark timber uprights break the large walls into old
	# architectural bays.
	for z_value in [
		-12.0,
		-6.0,
		0.0,
		6.0,
		12.0
	]:
		_box(
			_redesign_root,
			Vector3(
				0.38,
				5.6,
				0.50
			),
			Vector3(
				-21.45,
				2.8,
				z_value
			),
			_materials["stone"],
			"WestStonePier"
		)

	for x_value in [
		-18.0,
		-9.0,
		9.0,
		18.0
	]:
		_box(
			_redesign_root,
			Vector3(
				0.50,
				5.5,
				0.38
			),
			Vector3(
				x_value,
				2.75,
				-15.45
			),
			_materials["stone"],
			"NorthStonePier"
		)

	# Lounge side tables lit only by candles.
	for data in [
		[
			Vector3(
				-5.2,
				0.0,
				-10.1
			),
			0.0
		],
		[
			Vector3(
				5.2,
				0.0,
				-10.1
			),
			PI
		],
	]:
		_instance_asset(
			"antique_table",
			data[0],
			Vector3(
				0.52,
				0.82,
				0.52
			),
			float(
				data[1]
			),
			"LoungeSideTable"
		)

		_instance_asset(
			"books",
			data[0]
			+ Vector3(
				0.0,
				0.88,
				0.28
			),
			Vector3(
				0.60,
				0.60,
				0.60
			),
			0.12,
			"LoungeSideBooks"
		)

		_build_candle_cluster(
			data[0]
			+ Vector3.UP
			* 0.90,
			2
		)

	# A few dark plants/ivy-like silhouettes soften the stone and wood without
	# turning the room into a bright classroom.
	for plant_data in [
		[
			Vector3(
				-18.6,
				0.0,
				-13.0
			),
			0.85
		],
		[
			Vector3(
				18.7,
				0.0,
				12.5
			),
			0.76
		],
		[
			Vector3(
				10.7,
				0.0,
				-12.7
			),
			0.78
		],
	]:
		_build_library_plant(
			plant_data[0],
			float(
				plant_data[1]
			)
		)

	# Candle sconces: warm, low, and irregular rather than evenly lit.
	for data in [
		[
			Vector3(
				-21.42,
				2.35,
				-10.0
			),
			PI
			/ 2.0
		],
		[
			Vector3(
				-21.42,
				2.35,
				0.0
			),
			PI
			/ 2.0
		],
		[
			Vector3(
				-21.42,
				2.35,
				10.0
			),
			PI
			/ 2.0
		],
		[
			Vector3(
				8.0,
				2.35,
				-15.42
			),
			0.0
		],
		[
			Vector3(
				-8.0,
				2.35,
				-15.42
			),
			0.0
		],
	]:
		_build_candle_sconce(
			data[0],
			float(
				data[1]
			)
		)

	# Heavy, dark artwork/tapestry-like panels.
	_build_library_painting(
		Vector3(
			-21.40,
			3.65,
			5.0
		),
		Vector2(
			2.2,
			1.7
		),
		PI
		/ 2.0,
		_materials["painting_red"],
		"WestOldPainting"
	)

	_build_library_painting(
		Vector3(
			-21.40,
			3.65,
			-5.2
		),
		Vector2(
			2.0,
			1.6
		),
		PI
		/ 2.0,
		_materials["painting_blue"],
		"WestOldPaintingBlue"
	)

	_build_library_painting(
		Vector3(
			0.0,
			3.75,
			-15.40
		),
		Vector2(
			3.4,
			1.8
		),
		0.0,
		_materials["painting_red"],
		"FireplaceOldMaster"
	)

	# Scattered book piles add age and use without bright decorative clutter.
	for data in [
		[
			Vector3(
				-8.5,
				0.06,
				12.2
			),
			0.25
		],
		[
			Vector3(
				8.0,
				0.06,
				11.8
			),
			-0.18
		],
		[
			Vector3(
				12.2,
				0.06,
				6.5
			),
			0.33
		],
		[
			Vector3(
				-6.5,
				0.06,
				-7.4
			),
			-0.24
		],
	]:
		_instance_asset(
			"books",
			data[0],
			Vector3(
				0.72,
				0.72,
				0.72
			),
			float(
				data[1]
			),
			"ScatteredOldBooks"
		)

	# -----------------------------------------------------------------------
	# 9. Right-side window reading alcove.
	# -----------------------------------------------------------------------
	# This fills the previously empty floor without turning it into another row
	# of desks. It is intentionally lounge-like and slightly asymmetrical.
	_box(
		_redesign_root,
		Vector3(
			8.2,
			0.040,
			6.8
		),
		Vector3(
			11.3,
			0.025,
			0.0
		),
		_materials["rug"],
		"RightReadingAlcoveRug"
	)

	_box(
		_redesign_root,
		Vector3(
			8.55,
			0.018,
			7.15
		),
		Vector3(
			11.3,
			0.012,
			0.0
		),
		_materials["rug_border"],
		"RightReadingAlcoveRugBorder"
	)

	var alcove_left := Vector3(
		8.4,
		0.0,
		-1.35
	)

	var alcove_right := Vector3(
		13.8,
		0.0,
		1.35
	)

	_instance_asset(
		"antique_chair",
		alcove_left,
		Vector3.ONE,
		-1.12,
		"RightAlcoveArmchairLeft"
	)

	_add_blocker(
		alcove_left
		+ Vector3.UP
		* 0.80,
		Vector3(
			1.15,
			1.60,
			1.15
		),
		-1.12,
		"RightAlcoveChairLeftBlocker"
	)

	_instance_asset(
		"antique_chair",
		alcove_right,
		Vector3.ONE,
		2.05,
		"RightAlcoveArmchairRight"
	)

	_add_blocker(
		alcove_right
		+ Vector3.UP
		* 0.80,
		Vector3(
			1.15,
			1.60,
			1.15
		),
		2.05,
		"RightAlcoveChairRightBlocker"
	)

	# Small central table with old books and candlelight.
	var alcove_table := Vector3(
		11.1,
		0.0,
		0.0
	)

	_instance_asset(
		"antique_table",
		alcove_table,
		Vector3(
			0.62,
			0.78,
			0.62
		),
		0.0,
		"RightAlcoveSideTable"
	)

	_add_blocker(
		alcove_table
		+ Vector3.UP
		* 0.52,
		Vector3(
			1.25,
			1.05,
			1.25
		),
		0.0,
		"RightAlcoveTableBlocker"
	)

	_instance_asset(
		"book_opened",
		alcove_table
		+ Vector3(
			-0.25,
			0.84,
			0.0
		),
		Vector3(
			0.78,
			0.78,
			0.78
		),
		0.12,
		"RightAlcoveOpenBook"
	)

	_instance_asset(
		"books",
		alcove_table
		+ Vector3(
			0.30,
			0.84,
			0.14
		),
		Vector3(
			0.56,
			0.56,
			0.56
		),
		-0.18,
		"RightAlcoveBookStack"
	)

	_build_candle_cluster(
		alcove_table
		+ Vector3(
			0.0,
			0.88,
			-0.30
		),
		3
	)

	# Globe becomes the hero object for the alcove.
	_instance_asset(
		"globe",
		Vector3(
			15.6,
			0.0,
			-0.6
		),
		Vector3(
			0.92,
			0.92,
			0.92
		),
		0.20,
		"RightAlcoveGlobe"
	)

	# A freestanding candelabrum anchors the outer edge.
	_build_library_candelabrum(
		Vector3(
			7.4,
			0.0,
			1.8
		),
		1.0
	)

	# -----------------------------------------------------------------------
	# 10. Right-side archive / display corner near the entrance.
	# -----------------------------------------------------------------------
	# This gives the lower-right side visual weight while keeping the central
	# circulation route clear.
	_instance_asset(
		"bookshelf",
		Vector3(
			14.8,
			0.0,
			11.9
		),
		Vector3(
			0.88,
			0.88,
			0.88
		),
		PI,
		"RightArchiveBookshelf"
	)

	_add_blocker(
		Vector3(
			14.8,
			1.82,
			11.9
		),
		Vector3(
			3.25,
			3.75,
			0.92
		),
		0.0,
		"RightArchiveShelfBlocker"
	)

	_instance_asset(
		"bookstand",
		Vector3(
			10.9,
			0.0,
			11.5
		),
		Vector3(
			1.05,
			1.05,
			1.05
		),
		PI,
		"RightArchiveBookstand"
	)

	_instance_asset(
		"book_opened",
		Vector3(
			10.9,
			0.94,
			11.4
		),
		Vector3.ONE,
		PI,
		"RightArchiveManuscript"
	)

	_instance_asset(
		"serving_cart",
		Vector3(
			18.0,
			0.0,
			11.5
		),
		Vector3(
			0.90,
			0.90,
			0.90
		),
		-PI
		/ 2.0,
		"RightArchiveBookCart"
	)

	_add_blocker(
		Vector3(
			18.0,
			0.60,
			11.5
		),
		Vector3(
			1.30,
			1.20,
			1.15
		),
		0.0,
		"RightArchiveCartBlocker"
	)

	_build_candle_cluster(
		Vector3(
			11.65,
			0.98,
			11.45
		),
		2
	)

	# -----------------------------------------------------------------------
	# 11. Stronger left-stack lighting.
	# -----------------------------------------------------------------------
	# Extra sconces are concentrated inside the shelving zone, not evenly
	# distributed across the room.
	for sconce_data in [
		[
			Vector3(
				-21.38,
				2.15,
				-13.2
			),
			PI
			/ 2.0
		],
		[
			Vector3(
				-21.38,
				2.15,
				-7.0
			),
			PI
			/ 2.0
		],
		[
			Vector3(
				-21.38,
				2.15,
				6.8
			),
			PI
			/ 2.0
		],
		[
			Vector3(
				-21.38,
				2.15,
				13.0
			),
			PI
			/ 2.0
		],
	]:
		_build_candle_sconce(
			sconce_data[0],
			float(
				sconce_data[1]
			)
		)

	# Two floor candelabra at the ends of the left-side stack lanes.
	_build_library_candelabrum(
		Vector3(
			-16.8,
			0.0,
			-10.6
		),
		1.05
	)

	_build_library_candelabrum(
		Vector3(
			-16.8,
			0.0,
			5.9
		),
		1.05
	)


func _build_library_plant(
	position_value: Vector3,
	scale_value: float
) -> void:
	var root := Node3D.new()
	root.name = "LibraryPlant"
	root.position = position_value
	root.scale = Vector3.ONE * scale_value

	_redesign_root.add_child(
		root
	)
	root.owner = _scene_root

	_cylinder(
		root,
		0.38,
		0.58,
		Vector3(
			0.0,
			0.29,
			0.0
		),
		_materials["plant_pot"],
		"PlantPot"
	)

	for index in 9:
		var angle := (
			float(
				index
			)
			* TAU
			/ 9.0
		)

		var leaf := _sphere(
			root,
			Vector3(
				0.20,
				0.55,
				0.13
			),
			Vector3(
				cos(
					angle
				)
				* 0.34,
				0.92
				+ (
					index
					% 3
				)
				* 0.12,
				sin(
					angle
				)
				* 0.34
			),
			_materials["plant_leaf"],
			"PlantLeaf"
		)

		leaf.rotation.z = (
			cos(
				angle
			)
			* 0.42
		)
		leaf.rotation.x = (
			sin(
				angle
			)
			* 0.42
		)


func _build_library_candelabrum(
	position_value: Vector3,
	scale_value: float
) -> void:
	var root := Node3D.new()
	root.name = "MedievalCandelabrum"
	root.position = position_value
	root.scale = Vector3.ONE * scale_value

	_redesign_root.add_child(
		root
	)
	root.owner = _scene_root

	# Heavy iron-like base and central stem.
	_cylinder(
		root,
		0.32,
		0.12,
		Vector3(
			0.0,
			0.06,
			0.0
		),
		_materials["wood_dark"],
		"CandelabrumBase"
	)

	_cylinder(
		root,
		0.06,
		1.75,
		Vector3(
			0.0,
			0.92,
			0.0
		),
		_materials["wood_dark"],
		"CandelabrumStem"
	)

	for x_value in [
		-0.32,
		0.0,
		0.32
	]:
		_box(
			root,
			Vector3(
				0.05,
				0.05,
				0.40
			),
			Vector3(
				x_value,
				1.55,
				0.0
			),
			_materials["wood_dark"],
			"CandelabrumArm"
		)

		_cylinder(
			root,
			0.045,
			0.27,
			Vector3(
				x_value,
				1.78,
				0.0
			),
			_materials["plaster"],
			"CandelabrumCandle"
		)

		_sphere(
			root,
			Vector3(
				0.042,
				0.085,
				0.042
			),
			Vector3(
				x_value,
				1.98,
				0.0
			),
			_materials["fire_glow"],
			"CandelabrumFlame"
		)

	_add_omni_light(
		position_value
		+ Vector3.UP
		* 2.0
		* scale_value,
		Color(
			"#ffae63"
		),
		1.55,
		5.6,
		"CandelabrumWarmLight"
	)


func _build_candle_cluster(
	position_value: Vector3,
	count: int
) -> void:
	var spacing := 0.22
	var start_x := (
		-float(
			count
			- 1
		)
		* spacing
		* 0.5
	)

	for index in count:
		var candle_position := (
			position_value
			+ Vector3(
				start_x
				+ float(
					index
				)
				* spacing,
				0.0,
				0.0
			)
		)

		_cylinder(
			_redesign_root,
			0.055,
			0.34
			+ float(
				index
				% 2
			)
			* 0.08,
			candle_position
			+ Vector3.UP
			* 0.17,
			_materials["plaster"],
			"WaxCandle"
		)

		_sphere(
			_redesign_root,
			Vector3(
				0.045,
				0.095,
				0.045
			),
			candle_position
			+ Vector3.UP
			* (
				0.40
				+ float(
					index
					% 2
				)
				* 0.08
			),
			_materials["fire_glow"],
			"CandleFlame"
		)

	_add_omni_light(
		position_value
		+ Vector3.UP
		* 0.50,
		Color(
			"#ffb36b"
		),
		0.85
		+ float(
			count
		)
		* 0.18,
		3.8
		+ float(
			count
		)
		* 0.45,
		"CandleClusterLight"
	)


func _build_candle_sconce(
	position_value: Vector3,
	yaw: float
) -> void:
	var root := Node3D.new()
	root.name = "MedievalCandleSconce"
	root.position = position_value
	root.rotation.y = yaw

	_redesign_root.add_child(
		root
	)
	root.owner = _scene_root

	_box(
		root,
		Vector3(
			0.11,
			0.42,
			0.18
		),
		Vector3.ZERO,
		_materials["wood_trim"],
		"SconceBackplate"
	)

	_box(
		root,
		Vector3(
			0.08,
			0.08,
			0.34
		),
		Vector3(
			0.0,
			-0.05,
			-0.20
		),
		_materials["wood_trim"],
		"SconceArm"
	)

	_cylinder(
		root,
		0.050,
		0.30,
		Vector3(
			0.0,
			0.18,
			-0.34
		),
		_materials["plaster"],
		"SconceCandle"
	)

	_sphere(
		root,
		Vector3(
			0.045,
			0.095,
			0.045
		),
		Vector3(
			0.0,
			0.40,
			-0.34
		),
		_materials["fire_glow"],
		"SconceFlame"
	)

	_add_omni_light(
		position_value
		+ Vector3.UP
		* 0.36,
		Color(
			"#ffad63"
		),
		1.05,
		4.4,
		"WarmCandleSconceLight"
	)


func _build_library_sconce(
	position_value: Vector3,
	yaw: float
) -> void:
	_build_candle_sconce(
		position_value,
		yaw
	)

func _build_library_pendant(
	position_value: Vector3
) -> void:
	_cylinder(
		_redesign_root,
		0.035,
		0.95,
		position_value
		+ Vector3.DOWN
		* 0.46,
		_materials["wood_dark"],
		"PendantCord"
	)

	_sphere(
		_redesign_root,
		Vector3(
			0.27,
			0.20,
			0.27
		),
		position_value
		+ Vector3.DOWN
		* 0.95,
		_materials["window_glow"],
		"PendantShade"
	)

	_add_omni_light(
		position_value
		+ Vector3.DOWN
		* 1.15,
		Color(
			"#ffd39b"
		),
		1.60,
		6.4,
		"LibraryPendantLight"
	)


func _build_library_painting(
	position_value: Vector3,
	size: Vector2,
	yaw: float,
	art_material: Material,
	node_name: String
) -> void:
	var root := Node3D.new()
	root.name = node_name
	root.position = position_value
	root.rotation.y = yaw

	_redesign_root.add_child(
		root
	)
	root.owner = _scene_root

	_box(
		root,
		Vector3(
			size.x
			+ 0.22,
			size.y
			+ 0.22,
			0.10
		),
		Vector3.ZERO,
		_materials["painting_gold"],
		"PaintingFrame"
	)

	_box(
		root,
		Vector3(
			size.x,
			size.y,
			0.12
		),
		Vector3(
			0.0,
			0.0,
			-0.07
		),
		art_material,
		"PaintingArt"
	)

func _append_seat_from_furniture(
	seat_id: String,
	furniture_position: Vector3,
	seat_yaw: float,
	study_type: String,
	seat_type: String,
	seat_height: float,
	forward_offset: float,
	stand_distance: float,
	visual_offset: Vector3
) -> void:
	var forward := (
		Basis(
			Vector3.UP,
			seat_yaw
		)
		* Vector3.FORWARD
	)

	var right := (
		Basis(
			Vector3.UP,
			seat_yaw
		)
		* Vector3.RIGHT
	)

	var sitting := (
		furniture_position
		+ forward
		* forward_offset
		+ Vector3.UP
		* seat_height
	)

	var standing := (
		furniture_position
		- forward
		* stand_distance
	)

	var camera_target := (
		sitting
		+ Vector3.UP
		* 1.20
		+ forward
		* 0.28
	)

	var camera_position := (
		sitting
		+ forward
		* 4.3
		+ right
		* 3.0
		+ Vector3.UP
		* 2.65
	)

	_seat_specs.append(
		{
			"id": seat_id,
			"standing": standing,
			"sitting": sitting,
			"yaw": seat_yaw,
			"study_type": study_type,
			"seat_type": seat_type,
			"visual_offset": visual_offset,
			"seat_height": seat_height,
			"camera_position": camera_position,
			"camera_target": camera_target,
		}
	)


func _build_study_spots() -> Array:
	var result: Array = []
	var index := 0

	for spec in _seat_specs:
		var spot := STUDY_SPOT_SCRIPT.new()
		spot.name = (
			"StudySpot_%02d"
			% index
		)

		# This editor patch constructs the PackedScene while it is detached from
		# the live SceneTree. StudySpot.configure() / convert_to_editor_anchor()
		# use to_global() and to_local(), which require an in-tree Node3D.
		#
		# Author the exact same editable-anchor representation directly instead:
		# the StudySpot node itself sits at the authored sitting position and all
		# other anchors are stored as offsets in the seat's rotated local space.
		var sitting: Vector3 = spec["sitting"]
		var standing: Vector3 = spec["standing"]
		var camera_position: Vector3 = spec["camera_position"]
		var camera_target: Vector3 = spec["camera_target"]
		var seat_yaw: float = float(
			spec["yaw"]
		)
		var inverse_seat_basis := Basis(
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
		spot.seat_type = str(
			spec["seat_type"]
		)
		spot.seated_visual_offset = spec["visual_offset"]
		spot.seat_height = float(
			spec["seat_height"]
		)

		spot.sitting_offset = Vector3.ZERO
		spot.standing_offset = (
			inverse_seat_basis
			* (
				standing
				- sitting
			)
		)
		spot.camera_position_offset = (
			inverse_seat_basis
			* (
				camera_position
				- sitting
			)
		)
		spot.camera_target_offset = (
			inverse_seat_basis
			* (
				camera_target
				- sitting
			)
		)
		spot.local_facing_yaw = 0.0
		spot.reset_occupancy()

		_redesign_root.add_child(
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
	study_spots: Array
) -> void:
	# Four characters only. Keep the rest of the 16 seats available for players
	# and future multiplayer occupants.
	var npc_specs := [
		{
			"name": "Mina",
			"timer": "34m",
			"character": "rosie",
			"seat_index": 0,
		},
		{
			"name": "Theo",
			"timer": "51m",
			"character": "raymond",
			"seat_index": 5,
		},
		{
			"name": "Nora",
			"timer": "42m",
			"character": "bob",
			"seat_index": 10,
		},
		{
			"name": "Kai",
			"timer": "26m",
			"character": "rosie",
			"seat_index": 13,
		},
	]

	for npc_spec in npc_specs:
		var seat_index := int(
			npc_spec["seat_index"]
		)

		if (
			seat_index < 0
			or seat_index
			>= study_spots.size()
		):
			continue

		var spot = study_spots[
			seat_index
		]

		var npc := NPC_CONTROLLER_SCRIPT.new()
		npc.name = (
			"NPC_%s"
			% str(
				npc_spec["name"]
			)
		)

		npc.editor_display_name = str(
			npc_spec["name"]
		)

		npc.editor_occupant_id = str(
			npc_spec["name"]
		)

		npc.editor_timer_text = str(
			npc_spec["timer"]
		)

		npc.editor_seated = true

		npc.editor_study_kind = str(
			spot.study_type
		)

		npc.editor_spot_id = str(
			spot.seat_id
		)

		npc.editor_character_id = str(
			npc_spec["character"]
		)

		npc.position = spot.position
		npc.rotation.y = spot.rotation.y

		npc.process_mode = (
			Node.PROCESS_MODE_DISABLED
		)

		_redesign_root.add_child(
			npc
		)
		npc.owner = _scene_root

		npc.add_to_group(
			"editable_npc",
			true
		)

		var label := Label3D.new()
		label.name = "NameTimerLabel"
		label.text = (
			"%s  ·  %s"
			% [
				str(
					npc_spec["name"]
				),
				str(
					npc_spec["timer"]
				),
			]
		)

		label.position = Vector3(
			0.0,
			3.25,
			0.0
		)

		label.font_size = 24
		label.outline_size = 7
		label.modulate = Color(
			"#f5ead8"
		)
		label.outline_modulate = Color(
			0.07,
			0.06,
			0.06,
			0.86
		)

		label.billboard = (
			BaseMaterial3D.BILLBOARD_ENABLED
		)

		npc.add_child(
			label
		)
		label.owner = _scene_root


func _build_review_cameras() -> void:
	var camera_specs := [
		[
			"LibraryWide",
			Vector3(
				17.5,
				10.2,
				13.0
			),
			Vector3(
				0.0,
				1.25,
				-1.0
			),
			true,
		],
		[
			"EntranceComposition",
			Vector3(
				9.0,
				6.4,
				14.0
			),
			Vector3(
				-1.5,
				1.15,
				4.0
			),
			true,
		],
		[
			"BookStacks",
			Vector3(
				-4.5,
				5.6,
				6.5
			),
			Vector3(
				-12.0,
				1.8,
				-1.5
			),
			true,
		],
		[
			"CommunalStudy",
			Vector3(
				10.0,
				4.4,
				6.0
			),
			Vector3(
				0.0,
				1.15,
				0.0
			),
			false,
		],
		[
			"FireplaceLounge",
			Vector3(
				8.5,
				4.2,
				-7.0
			),
			Vector3(
				0.0,
				1.45,
				-13.5
			),
			true,
		],
		[
			"WindowCourtyard",
			Vector3(
				14.2,
				4.3,
				-1.0
			),
			Vector3(
				26.0,
				2.0,
				1.0
			),
			false,
		],
	]

	for data in camera_specs:
		var camera := Camera3D.new()
		camera.name = str(
			data[0]
		)

		camera.fov = 40.0
		camera.current = false

		# look_at() depends on an in-tree global transform. This PackedScene is
		# authored off-tree, so use the transform-explicit variant instead.
		camera.look_at_from_position(
			data[1],
			data[2],
			Vector3.UP
		)

		_redesign_root.add_child(
			camera
		)
		camera.owner = _scene_root

		camera.add_to_group(
			"editable_focus_camera",
			true
		)

		if bool(
			data[3]
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
		13.0
	)
	spawn.rotation.y = PI

	_redesign_root.add_child(
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
	var path := str(
		ASSETS.get(
			key,
			""
		)
	)

	if path.is_empty():
		return null

	return _instance_scene(
		path,
		position_value,
		scale_value,
		yaw,
		node_name
	)


func _instance_scene(
	path: String,
	position_value: Vector3,
	scale_value: Vector3,
	yaw: float,
	node_name: String
) -> Node3D:
	if not ResourceLoader.exists(
		path
	):
		push_warning(
			"Optional scene does not exist: %s"
			% path
		)
		return null

	var packed := load(
		path
	) as PackedScene

	if packed == null:
		push_warning(
			"Could not load PackedScene: %s"
			% path
		)
		return null

	var instance := packed.instantiate()

	if not (instance is Node3D):
		if instance != null:
			instance.free()

		push_warning(
			"Imported scene root is not Node3D: %s"
			% path
		)
		return null

	var node := instance as Node3D
	node.name = node_name
	node.position = position_value
	node.scale = scale_value
	node.rotation.y = yaw

	_redesign_root.add_child(
		node
	)
	node.owner = _scene_root

	return node


func _box(
	parent: Node,
	size: Vector3,
	position_value: Vector3,
	material: Material,
	node_name: String,
	yaw := 0.0
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.position = position_value
	node.rotation.y = yaw

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
	mesh.radial_segments = 20
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
	mesh.radial_segments = 20
	mesh.rings = 12
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

	_redesign_root.add_child(
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

	_redesign_root.add_child(
		light
	)
	light.owner = _scene_root

	return light


func _material(
	material_name: String,
	color: Color,
	roughness: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = material_name
	material.albedo_color = color
	material.roughness = roughness
	return material


func _glass_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "LibraryWindowGlass"
	material.albedo_color = Color(
		0.52,
		0.68,
		0.82,
		0.19
	)
	material.roughness = 0.16
	material.metallic = 0.0
	material.transparency = (
		BaseMaterial3D.TRANSPARENCY_ALPHA
	)
	material.cull_mode = (
		BaseMaterial3D.CULL_DISABLED
	)
	return material


func _emissive_material(
	material_name: String,
	color: Color,
	energy: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = material_name
	material.albedo_color = color
	material.roughness = 0.72
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _backup_original() -> String:
	var absolute_backup_dir := ProjectSettings.globalize_path(
		BACKUP_DIR
	)

	var make_error := DirAccess.make_dir_recursive_absolute(
		absolute_backup_dir
	)

	if (
		make_error != OK
		and make_error
		!= ERR_ALREADY_EXISTS
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
		+ "/library_before_redesign_"
		+ timestamp
		+ ".tscn"
	)

	var copy_error := DirAccess.copy_absolute(
		ProjectSettings.globalize_path(
			LIBRARY_SCENE_PATH
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
		"No new Library scene changes were saved by this run."
	)
	print("")

	quit(
		1
	)
