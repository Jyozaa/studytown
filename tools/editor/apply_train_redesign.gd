extends SceneTree

# StudyTown Train redesign v9 — inward compartment seats + larger tables + deeper sunset.
#
# Rebuilds only:
#   res://assets/dev_local/room_layouts/train.tscn
#
# This version follows the user-supplied Train layout diagram literally:
#
# LEFT / UPPER SIDE OF PLAN
#   - six individual FtrSeatTransport blue cabin seats
#   - two small café tables
#
# RIGHT / LOWER SIDE OF PLAN
#   - one individual seat at each end
#   - two adjacent FtrSeatLong modules forming the central long bench
#   - one small café table at each end
#
# Total usable positions: 10.
#
# Deliberately NOT used:
#   FtrPartitionpole  (rope partition)
#   FtrHandrail       (safety railing)
#
# Those were the oversized white objects in the earlier Train pass and are not
# train-interior poles. Train poles/straps below are lightweight procedural
# geometry at actual carriage scale.
#
# Runtime seat type remains "train_booth" so TrainStudy animation behavior is
# preserved.

const TRAIN_SCENE_PATH := (
	"res://assets/dev_local/room_layouts/train.tscn"
)

const BACKUP_DIR := (
	"res://assets/dev_local/room_layouts/backups"
)

const STUDY_SPOT_SCRIPT := preload(
	"res://scripts/study/study_spot.gd"
)

const NPC_CONTROLLER_SCRIPT := preload(
	"res://scripts/npc/npc_controller.gd"
)

const ASSETS := {
	"seat":
		"res://assets/dev_local/blender_generated/runtime/train_seat_transport.glb",
	"long_seat":
		"res://assets/dev_local/blender_generated/runtime/train_seat_long.glb",
	# Final inspected main table: FtrWoodenTableMini ReBody3.
	"table":
		"res://assets/dev_local/blender_generated/runtime/train_table_wooden_mini.glb",

	# Inspected decorative table candidates.
	"table_antique":
		"res://assets/dev_local/blender_generated/runtime/train_table_antique_small.glb",
	"table_vintage":
		"res://assets/dev_local/blender_generated/runtime/train_table_vintage_medium.glb",
	"table_elegant":
		"res://assets/dev_local/blender_generated/runtime/train_table_elegant_medium.glb",
	"window":
		"res://assets/dev_local/blender_generated/runtime/train_window_steel.glb",
	"fan":
		"res://assets/dev_local/blender_generated/runtime/train_wall_fan.glb",
	"clock":
		"res://assets/dev_local/blender_generated/runtime/train_wall_clock.glb",
	"corkboard":
		"res://assets/dev_local/blender_generated/runtime/train_corkboard.glb",
	"books":
		"res://assets/dev_local/blender_generated/runtime/train_books.glb",
	"open_book":
		"res://assets/dev_local/blender_generated/runtime/train_open_book.glb",
	"coffee":
		"res://assets/dev_local/blender_generated/runtime/train_coffee_cup.glb",
	"mug":
		"res://assets/dev_local/blender_generated/runtime/train_mug.glb",
	"case":
		"res://assets/dev_local/blender_generated/runtime/train_duralumin_case.glb",
	"backpack":
		"res://assets/dev_local/blender_generated/runtime/train_backpack.glb",
	"travel_bag":
		"res://assets/dev_local/blender_generated/runtime/train_travel_bag.glb",
	"shopping_bag":
		"res://assets/dev_local/blender_generated/runtime/train_shopping_bag.glb",

	# Optional already-converted Garden structures/foliage reused outside.
	"garden_trailer":
		"res://assets/dev_local/blender_generated/runtime/garden_forest_trailer.glb",
	"garden_gazebo":
		"res://assets/dev_local/blender_generated/runtime/garden_western_gazebo.glb",
	"garden_tent":
		"res://assets/dev_local/blender_generated/runtime/garden_campsite_tent.glb",
	"garden_oak":
		"res://assets/dev_local/blender_generated/runtime/garden_oak_tree.glb",
	"garden_big_tree":
		"res://assets/dev_local/blender_generated/runtime/garden_big_tree.glb",

	# Exact current Garden mountain / forest-village runtime assets.
	"mountain_a":
		"res://assets/dev_local/blender_generated/runtime/natural_rock_mountain_a.glb",
	"mountain_b":
		"res://assets/dev_local/blender_generated/runtime/natural_rock_mountain_b.glb",
	"mountain_c":
		"res://assets/dev_local/blender_generated/runtime/natural_rock_mountain_c.glb",
	"garden_forest_lamp":
		"res://assets/dev_local/blender_generated/runtime/garden_forest_lamp.glb",
	"garden_streetlamp":
		"res://assets/dev_local/blender_generated/runtime/garden_forest_streetlamp.glb",
	"garden_lantern":
		"res://assets/dev_local/blender_generated/runtime/garden_forest_lantern.glb",
	"garden_firepit":
		"res://assets/dev_local/blender_generated/runtime/garden_forest_firepit.glb",
	"garden_bench":
		"res://assets/dev_local/blender_generated/runtime/garden_forest_bench.glb",
	"garden_party_arch":
		"res://assets/dev_local/blender_generated/runtime/garden_party_light_arch.glb",

	# Already-converted Library assets reused to make the carriage feel lived-in.
	"library_books":
		"res://assets/dev_local/blender_generated/runtime/library_books.glb",
	"library_open_book":
		"res://assets/dev_local/blender_generated/runtime/library_book_opened.glb",
	"library_bankers_lamp":
		"res://assets/dev_local/blender_generated/runtime/library_bankers_lamp.glb",
	"library_antique_clock":
		"res://assets/dev_local/blender_generated/runtime/library_antique_clock.glb",
	"library_magazine_rack":
		"res://assets/dev_local/blender_generated/runtime/library_magazine_rack.glb",
	"library_bookstand":
		"res://assets/dev_local/blender_generated/runtime/library_bookstand.glb",
	"library_serving_cart":
		"res://assets/dev_local/blender_generated/runtime/library_serving_cart.glb",
}

const REQUIRED_ASSETS: Array[String] = [
	"seat",
	"long_seat",
	"table",
	"window",
	"books",
	"open_book",
	"coffee",
]

const TRAIN_VISUAL_OFFSET := Vector3(
	0.0,
	0.47,
	0.02
)

const SCENERY_TILE_LENGTH := 10.0
const SCENERY_WRAP_LENGTH := 50.0
const SCENERY_SPEED := 1.65

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
	print("# STUDYTOWN TRAIN REDESIGN V9")
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
				"Missing Train runtime asset: "
				+ asset_path
				+ "\nRun the corrected Train Blender conversion first, "
				+ "then run the headless Godot import."
			)
			return

	var packed := load(
		TRAIN_SCENE_PATH
	) as PackedScene

	if packed == null:
		_fail(
			"Could not load train.tscn."
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

	_clear_scene()

	_scene_root.set_meta(
		"studytown_room_index",
		2
	)
	_scene_root.set_meta(
		"studytown_room_id",
		"train"
	)
	_scene_root.set_meta(
		"redesigned_by",
		"apply_train_redesign.gd"
	)
	_scene_root.set_meta(
		"train_redesign_version",
		9
	)

	_build_materials()

	_room_root = Node3D.new()
	_room_root.name = "TrainOldWorldRedesignV9"
	_scene_root.add_child(
		_room_root
	)
	_room_root.owner = _scene_root

	_build_environment()
	_build_carriage_shell()
	_build_windows()
	_build_reference_seating()
	_build_overhead_hardware()
	_build_wall_details()
	_build_luggage()
	_build_cozy_carriage_decor()
	_build_exterior()

	var spots: Array = (
		_build_study_spots()
	)

	_build_npcs(
		spots
	)
	_build_review_cameras()
	_build_player_spawn()

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

	_scene_root.free()
	_scene_root = null

	if save_error != OK:
		_fail(
			"ResourceSaver.save failed with error %d"
			% save_error
		)
		return

	print("Footprint:           11 x 42")
	print("Study positions:     ", _seat_specs.size(), " (2 per long seat)")
	print("Left zone:           4 back-to-back long-seat pairs")
	print("Centre:              continuous longitudinal walkway carpet")
	print("Right zone:          2 face-to-face long-seat compartments")
	print("Main tables:         4 extra-large WoodenTableMini ReBody3")
	print("Decor density:       9 decorative tables + dense lamps/books/props")
	print("Cross walkway:       clear between the 2 right-side compartments")
	print("Interior style:      dark walnut / brass / burgundy / amber")
	print("Compartment facing:  both long-seat pairs face inward toward tables")
	print("Exterior loop:       5 x 10 m seamless tiles, 50 m runtime wrap")
	print("Mountains:           Garden natural_rock_mountain A/B/C assets")
	print("Exterior density:    cottages + trailers + tents + gazebo + campsite props")
	print("Backup:              ", backup_path)
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
	_materials.clear()

	_materials["floor"] = _material(
		"TrainWalnutFloor",
		Color(
			"#2b1b13"
		),
		0.84
	)

	_materials["aisle"] = _material(
		"TrainWineCarpet",
		Color(
			"#4a2528"
		),
		0.96
	)

	_materials["wall"] = _material(
		"TrainWalnutWall",
		Color(
			"#4b3020"
		),
		0.88
	)

	_materials["wall_lower"] = _material(
		"TrainDarkWalnutPanel",
		Color(
			"#281912"
		),
		0.86
	)

	_materials["metal"] = _material(
		"TrainAgedBrass",
		Color(
			"#927044"
		),
		0.54
	)

	_materials["metal_dark"] = _material(
		"TrainDarkBronze",
		Color(
			"#493723"
		),
		0.68
	)

	_materials["rubber"] = _material(
		"TrainDarkLeather",
		Color(
			"#211817"
		),
		0.91
	)

	_materials["table_wood"] = _material(
		"TrainTableWalnut",
		Color(
			"#4e3020"
		),
		0.82
	)

	_materials["table_edge"] = _material(
		"TrainTableBrass",
		Color(
			"#8b673b"
		),
		0.60
	)

	_materials["seat_fabric"] = _material(
		"TrainBurgundyUpholstery",
		Color(
			"#5a2228"
		),
		0.96
	)

	_materials["seat_frame"] = _material(
		"TrainSeatDarkWood",
		Color(
			"#563824"
		),
		0.82
	)

	_materials["curtain"] = _material(
		"TrainVelvetCurtain",
		Color(
			"#4b2027"
		),
		0.98
	)

	_materials["rug_border"] = _material(
		"TrainRugGoldBorder",
		Color(
			"#81613a"
		),
		0.90
	)

	_materials["paper"] = _material(
		"TrainWarmPaper",
		Color(
			"#d9c8a9"
		),
		0.96
	)

	_materials["light"] = _emissive_material(
		"TrainLanternGlow",
		Color(
			"#ffad5e"
		),
		1.45
	)

	_materials["fire_glow"] = _emissive_material(
		"TrainOilFlame",
		Color(
			"#ff9a48"
		),
		2.0
	)

	_materials["water"] = _material(
		"TrainTwilightWater",
		Color(
			"#263d53"
		),
		0.46
	)

	_materials["water_glow"] = _material(
		"TrainWaterReflection",
		Color(
			"#596b79"
		),
		0.48
	)

	_materials["shore"] = _material(
		"TrainOldWorldShore",
		Color(
			"#263229"
		),
		0.98
	)

	_materials["mountain_far"] = _unshaded_material(
		"TrainMountainFar",
		Color(
			"#38394b"
		)
	)

	_materials["mountain_near"] = _unshaded_material(
		"TrainMountainNear",
		Color(
			"#242d35"
		)
	)

	_materials["mountain_mid"] = _unshaded_material(
		"TrainMountainMid",
		Color(
			"#303544"
		)
	)

	_materials["town"] = _material(
		"TrainOldTownPlaster",
		Color(
			"#6b5947"
		),
		0.95
	)

	_materials["town_dark"] = _material(
		"TrainOldTownTimber",
		Color(
			"#332219"
		),
		0.92
	)

	_materials["roof"] = _material(
		"TrainOldTownRoof",
		Color(
			"#3b2926"
		),
		0.94
	)

	_materials["town_glow"] = _emissive_material(
		"TrainTownWindowGlow",
		Color(
			"#ffbd72"
		),
		1.35
	)

	_materials["tree_trunk"] = _material(
		"TrainSceneryTreeTrunk",
		Color(
			"#34271f"
		),
		0.98
	)

	_materials["tree_leaf"] = _material(
		"TrainSceneryTreeLeaf",
		Color(
			"#20362c"
		),
		0.99
	)

	_materials["sun"] = _emissive_material(
		"TrainTwilightSun",
		Color(
			"#e88f59"
		),
		1.20
	)

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "TrainWarmSunsetEnvironment"

	_room_root.add_child(
		world_environment
	)
	world_environment.owner = _scene_root

	var environment := Environment.new()

	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(
		"#334b70"
	)
	sky_material.sky_horizon_color = Color(
		"#dc8166"
	)
	sky_material.sky_curve = 0.22
	sky_material.sky_energy_multiplier = 0.66
	sky_material.ground_bottom_color = Color(
		"#2c3438"
	)
	sky_material.ground_horizon_color = Color(
		"#a16f62"
	)

	var sky := Sky.new()
	sky.sky_material = sky_material

	environment.background_mode = (
		Environment.BG_SKY
	)
	environment.sky = sky

	# Warm sunset, but deliberately one step darker than v8 for richer contrast.
	environment.ambient_light_source = (
		Environment.AMBIENT_SOURCE_COLOR
	)
	environment.ambient_light_color = Color(
		"#c39a87"
	)
	environment.ambient_light_energy = 0.34
	environment.tonemap_mode = (
		Environment.TONE_MAPPER_FILMIC
	)

	environment.fog_enabled = true
	environment.fog_light_color = Color(
		"#b17c72"
	)
	environment.fog_light_energy = 0.28
	environment.fog_density = 0.0018
	environment.fog_sky_affect = 0.44

	world_environment.environment = environment

	var sunset_fill := DirectionalLight3D.new()
	sunset_fill.name = "TrainWarmSunsetFill"
	sunset_fill.light_color = Color(
		"#ffc28e"
	)
	sunset_fill.light_energy = 0.42
	sunset_fill.shadow_enabled = true
	sunset_fill.rotation_degrees = Vector3(
		-30.0,
		58.0,
		0.0
	)

	_room_root.add_child(
		sunset_fill
	)
	sunset_fill.owner = _scene_root

func _build_carriage_shell() -> void:
	_box(
		_room_root,
		Vector3(
			11.0,
			0.30,
			42.0
		),
		Vector3(
			0.0,
			-0.19,
			0.0
		),
		_materials["floor"],
		"TrainFloor"
	)

	_box(
		_room_root,
		Vector3(
			2.05,
			0.035,
			38.5
		),
		Vector3(
			0.0,
			0.01,
			0.0
		),
		_materials["aisle"],
		"TrainAisleRunner"
	)

	_add_blocker(
		Vector3(
			0.0,
			-0.22,
			0.0
		),
		Vector3(
			11.0,
			0.42,
			42.0
		),
		0.0,
		"TrainFloorCollision"
	)

	for side: float in [
		-1.0,
		1.0
	]:
		var side_x: float = (
			side
			* 5.48
		)

		_box(
			_room_root,
			Vector3(
				0.34,
				1.00,
				42.0
			),
			Vector3(
				side_x,
				0.43,
				0.0
			),
			_materials["wall_lower"],
			"TrainLowerSideWall"
		)

		_box(
			_room_root,
			Vector3(
				0.34,
				0.68,
				42.0
			),
			Vector3(
				side_x,
				3.86,
				0.0
			),
			_materials["wall"],
			"TrainUpperSideWall"
		)

		_add_blocker(
			Vector3(
				side * 5.28,
				2.0,
				0.0
			),
			Vector3(
				0.55,
				4.20,
				42.0
			),
			0.0,
			"TrainSideBoundary"
		)

	for end_side: float in [
		-1.0,
		1.0
	]:
		var end_z: float = (
			end_side
			* 21.0
		)

		_box(
			_room_root,
			Vector3(
				11.0,
				4.40,
				0.36
			),
			Vector3(
				0.0,
				1.98,
				end_z
			),
			_materials["wall"],
			"TrainEndWall"
		)

		for door_side: float in [
			-1.0,
			1.0
		]:
			_box(
				_room_root,
				Vector3(
					2.15,
					3.15,
					0.10
				),
				Vector3(
					door_side * 1.12,
					1.70,
					end_z
					- end_side
					* 0.21
				),
				_materials["metal_dark"],
				"TrainEndDoor"
			)

			_box(
				_room_root,
				Vector3(
					1.02,
					1.40,
					0.07
				),
				Vector3(
					door_side * 1.12,
					2.02,
					end_z
					- end_side
					* 0.28
				),
				_materials["rubber"],
				"TrainEndDoorWindow"
			)

	_add_blocker(
		Vector3(
			0.0,
			2.0,
			20.72
		),
		Vector3(
			11.0,
			4.25,
			0.62
		),
		0.0,
		"TrainNorthBoundary"
	)

	_add_blocker(
		Vector3(
			0.0,
			2.0,
			-20.72
		),
		Vector3(
			11.0,
			4.25,
			0.62
		),
		0.0,
		"TrainSouthBoundary"
	)

	# Old hanging carriage lanterns replace the modern fluorescent strips.
	# They leave the corners dim and give the carriage pools of amber light.
	for lantern_z: float in [
		-14.5,
		-5.0,
		5.0,
		14.5
	]:
		_build_hanging_lantern(
			Vector3(
				-0.65,
				3.70,
				lantern_z
			)
		)

func _build_windows() -> void:
	var window_zs: Array[float] = [
		-16.0,
		-11.4,
		-6.8,
		-2.2,
		2.4,
		7.0,
		11.6,
		16.2,
	]

	for side: float in [
		-1.0,
		1.0
	]:
		for window_z: float in window_zs:
			_instance_asset(
				"window",
				Vector3(
					side * 5.34,
					1.00,
					window_z
				),
				Vector3(
					1.03,
					1.0,
					1.03
				),
				(
					PI
					/ 2.0
					if side < 0.0
					else -PI
					/ 2.0
				),
				"TrainSteelWindow"
			)

		for post_z: float in [
			-18.3,
			-13.7,
			-9.1,
			-4.5,
			0.1,
			4.7,
			9.3,
			13.9,
			18.5,
		]:
			_box(
				_room_root,
				Vector3(
					0.25,
					2.78,
					0.22
				),
				Vector3(
					side * 5.23,
					2.18,
					post_z
				),
				_materials["metal_dark"],
				"TrainWindowPost"
			)


func _build_reference_seating() -> void:
	# Godot's Vector3.FORWARD is -Z. Seat StudySpot yaws below therefore match
	# the visual bench direction exactly; this matters for focus-camera placement.
	# -----------------------------------------------------------------------
	# USER DIAGRAM: LEFT HALF
	#
	# Four rows of long seats. In every row:
	#   outer bench -> faces the outside/window
	#   inner bench -> faces the longitudinal walkway
	#
	# The two benches are back-to-back, not face-to-face.
	# -----------------------------------------------------------------------
	var outer_x: float = -4.45
	var inner_x: float = -2.75

	# Longitudinal walkway occupies roughly x=-1.55 .. +0.20.
	_box(
		_room_root,
		Vector3(
			1.75,
			0.025,
			38.0
		),
		Vector3(
			-0.68,
			0.025,
			0.0
		),
		_materials["aisle"],
		"LongitudinalWalkwayCarpet"
	)

	var left_row_zs: Array[float] = [
		-15.0,
		-5.0,
		5.0,
		15.0,
	]

	for row_index: int in range(
		left_row_zs.size()
	):
		var row_z: float = left_row_zs[
			row_index
		]

		# Outer bench faces -X toward the window/outside.
		var outer_position := Vector3(
			outer_x,
			0.0,
			row_z
		)

		_instance_asset(
			"long_seat",
			outer_position,
			Vector3(
				0.95,
				0.95,
				0.95
			),
			PI / 2.0,
			"LeftOuterLongSeat_%02d"
			% row_index
		)

		_add_blocker(
			outer_position
			+ Vector3.UP
			* 0.62,
			Vector3(
				1.05,
				1.30,
				2.05
			),
			0.0,
			"LeftOuterSeatBlocker"
		)

		_append_long_train_seats(
			"train-left-outer-%02d"
			% row_index,
			outer_position,
			PI / 2.0,
			"Book",
			"Laptop"
		)

		# Inner bench faces +X toward the carpeted walkway.
		var inner_position := Vector3(
			inner_x,
			0.0,
			row_z
		)

		_instance_asset(
			"long_seat",
			inner_position,
			Vector3(
				0.95,
				0.95,
				0.95
			),
			-PI / 2.0,
			"LeftInnerLongSeat_%02d"
			% row_index
		)

		_add_blocker(
			inner_position
			+ Vector3.UP
			* 0.62,
			Vector3(
				1.05,
				1.30,
				2.05
			),
			0.0,
			"LeftInnerSeatBlocker"
		)

		_append_train_seat(
			"train-left-inner-%02d"
			% row_index,
			inner_position,
			-PI / 2.0,
			(
				"Laptop"
				if row_index % 2 == 0
				else "Book"
			)
		)

	# -----------------------------------------------------------------------
	# USER DIAGRAM: RIGHT HALF
	#
	# Two face-to-face long-seat compartments.
	# Each compartment uses two small tables side by side.
	# A full-width cross walkway separates the two compartments.
	# -----------------------------------------------------------------------
	var right_zone_centre_x: float = 2.85

	# Cross-carriage walkway in the middle of the right half.
	_box(
		_room_root,
		Vector3(
			5.10,
			0.025,
			3.25
		),
		Vector3(
			2.75,
			0.026,
			0.0
		),
		_materials["aisle"],
		"RightZoneCrossWalkway"
	)

	var compartment_centres: Array[float] = [
		-10.4,
		10.4,
	]

	for compartment_index: int in range(
		compartment_centres.size()
	):
		var centre_z: float = compartment_centres[
			compartment_index
		]

		var north_bench_position := Vector3(
			right_zone_centre_x,
			0.0,
			centre_z - 4.05
		)

		var south_bench_position := Vector3(
			right_zone_centre_x,
			0.0,
			centre_z + 4.05
		)

		# These benches run across X and face each other along Z.
		_instance_asset(
			"long_seat",
			north_bench_position,
			Vector3(
				1.55,
				0.95,
				0.95
			),
			0.0,
			"RightCompartmentNorthSeat_%02d"
			% compartment_index
		)

		_instance_asset(
			"long_seat",
			south_bench_position,
			Vector3(
				1.55,
				0.95,
				0.95
			),
			PI,
			"RightCompartmentSouthSeat_%02d"
			% compartment_index
		)

		_add_blocker(
			north_bench_position
			+ Vector3.UP
			* 0.62,
			Vector3(
				3.55,
				1.30,
				1.00
			),
			0.0,
			"RightNorthBenchBlocker"
		)

		_add_blocker(
			south_bench_position
			+ Vector3.UP
			* 0.62,
			Vector3(
				3.55,
				1.30,
				1.00
			),
			0.0,
			"RightSouthBenchBlocker"
		)

		# The imported seated character faces 180 degrees from the authored
		# anchor yaw. Using 0 for the north bench and PI for the south bench
		# therefore makes both players face INWARD toward the table zone.
		_append_long_train_seats(
			"train-right-%02d-north"
			% compartment_index,
			north_bench_position,
			0.0,
			"Laptop",
			"Book"
		)

		_append_long_train_seats(
			"train-right-%02d-south"
			% compartment_index,
			south_bench_position,
			PI,
			"Book",
			"Laptop"
		)

		# Two actual small café tables form the rectangular table zone drawn in
		# the user's layout.
		for table_index: int in range(
			2
		):
			# Two WoodenTableMini pieces sit nearly flush and read as one
			# rectangular compartment table with only a narrow seam.
			var table_x: float = (
				2.20
				+ float(
					table_index
				)
				* 1.30
			)

			_place_reference_table(
				Vector3(
					table_x,
					0.0,
					centre_z
				),
				0.0,
				compartment_index * 2
				+ table_index
			)

func _place_reference_table(
	position_value: Vector3,
	yaw: float,
	index: int
) -> void:
	# FtrWoodenTableMini ReBody3 remains the main table, but v8 scales it up so
	# each pair fills the compartment properly rather than reading as side tables.
	var table := _instance_asset(
		"table",
		position_value,
		Vector3(
			1.55,
			1.14,
			1.34
		),
		yaw,
		"TrainWoodenMiniTable_%02d"
		% index
	)

	if table == null:
		return

	_add_blocker(
		position_value
		+ Vector3.UP
		* 0.39,
		Vector3(
			1.34,
			0.88,
			1.12
		),
		0.0,
		"TrainWoodenMiniTableBlocker"
	)

	if index % 2 == 0:
		_instance_asset(
			"open_book",
			position_value
			+ Vector3(
				-0.14,
				0.87,
				0.04
			),
			Vector3(
				0.64,
				0.64,
				0.64
			),
			0.10,
			"TrainTableOpenBook"
		)
	else:
		_instance_asset(
			"books",
			position_value
			+ Vector3(
				-0.12,
				0.87,
				0.04
			),
			Vector3(
				0.48,
				0.48,
				0.48
			),
			-0.08,
			"TrainTableBooks"
		)

	_instance_asset(
		(
			"coffee"
				if index < 2
				else "mug"
		),
		position_value
		+ Vector3(
			0.30,
			0.87,
			-0.20
		),
		Vector3(
			0.72,
			0.72,
			0.72
		),
		0.0,
		"TrainTableDrink"
	)

func _append_long_train_seats(
	base_id: String,
	bench_position: Vector3,
	seat_yaw: float,
	study_type_a: String,
	study_type_b: String
) -> void:
	# Every FtrSeatLong mesh visually accommodates two characters. Position the
	# gameplay anchors along the seat's local RIGHT axis so both characters sit
	# side-by-side rather than sharing the same point.
	var seat_basis := Basis(
		Vector3.UP,
		seat_yaw
	)

	var along_bench: Vector3 = (
		seat_basis
		* Vector3.RIGHT
	)

	var seat_offset: float = 0.54

	_append_train_seat(
		base_id + "-a",
		bench_position
		- along_bench
		* seat_offset,
		seat_yaw,
		study_type_a
	)

	_append_train_seat(
		base_id + "-b",
		bench_position
		+ along_bench
		* seat_offset,
		seat_yaw,
		study_type_b
	)


func _append_train_seat(
	seat_id: String,
	seat_position: Vector3,
	seat_yaw: float,
	study_type: String
) -> void:
	# The imported Animal Crossing seated character faces 180 degrees opposite
	# the authored Train seat's forward convention. Keep all physical anchors
	# where they are, but flip only the character-facing yaw.
	var anchor_basis: Basis = Basis(
		Vector3.UP,
		seat_yaw
	)

	var anchor_forward: Vector3 = (
		anchor_basis
		* Vector3.FORWARD
	)

	var sitting: Vector3 = (
		seat_position
		+ anchor_forward
		* 0.13
		+ Vector3.UP
		* 0.05
	)

	var standing: Vector3 = (
		seat_position
		- anchor_forward
		* 0.95
	)

	var character_yaw: float = wrapf(
		seat_yaw
		+ PI,
		-PI,
		PI
	)

	var camera_basis: Basis = Basis(
		Vector3.UP,
		character_yaw
	)

	var camera_forward: Vector3 = (
		camera_basis
		* Vector3.FORWARD
	)

	var camera_right: Vector3 = (
		camera_basis
		* Vector3.RIGHT
	)

	var camera_target: Vector3 = (
		sitting
		+ Vector3.UP
		* 1.18
		+ camera_forward
		* 0.20
	)

	var camera_position: Vector3 = (
		sitting
		+ camera_forward
		* 3.35
		+ camera_right
		* 1.85
		+ Vector3.UP
		* 2.15
	)

	_seat_specs.append(
		{
			"id": seat_id,
			"standing": standing,
			"sitting": sitting,
			"yaw": character_yaw,
			"study_type": study_type,
			"camera_position": camera_position,
			"camera_target": camera_target,
		}
	)

func _build_overhead_hardware() -> void:
	# Keep every floor-level walkway completely clear.
	#
	# No FtrPartitionpole.
	# No FtrHandrail.
	# No floor-mounted pole cluster.
	#
	# Only shallow luggage shelves and lightweight ceiling straps are used.
	for side: float in [
		-1.0,
		1.0
	]:
		_box(
			_room_root,
			Vector3(
				0.92,
				0.055,
				35.5
			),
			Vector3(
				side * 4.55,
				3.22,
				0.0
			),
			_materials["metal"],
			"TrainLuggageRack"
		)

	# One slim overhead rail above the longitudinal carpet.
	_box(
		_room_root,
		Vector3(
			0.055,
			0.055,
			34.0
		),
		Vector3(
			-0.68,
			3.48,
			0.0
		),
		_materials["metal"],
		"WalkwayOverheadRail"
	)

	for strap_z: float in [
		-15.0,
		-11.0,
		-7.0,
		-3.0,
		3.0,
		7.0,
		11.0,
		15.0,
	]:
		_build_hand_strap(
			Vector3(
				-0.68,
				3.33,
				strap_z
			)
		)

func _build_hand_strap(
	position_value: Vector3
) -> void:
	_cylinder(
		_room_root,
		0.016,
		0.38,
		position_value
		+ Vector3.DOWN
		* 0.18,
		_materials["rubber"],
		"TrainStrapStem"
	)

	var loop := MeshInstance3D.new()
	loop.name = "TrainSmallHandLoop"
	loop.position = (
		position_value
		+ Vector3.DOWN
		* 0.44
	)

	var torus := TorusMesh.new()
	torus.inner_radius = 0.082
	torus.outer_radius = 0.118
	torus.rings = 14
	torus.ring_segments = 8

	loop.mesh = torus
	loop.material_override = _materials[
		"rubber"
	]
	loop.rotation.x = PI / 2.0

	_room_root.add_child(
		loop
	)
	loop.owner = _scene_root


func _build_wall_details() -> void:
	if ResourceLoader.exists(
		str(
			ASSETS["clock"]
		)
	):
		_instance_asset(
			"clock",
			Vector3(
				0.0,
				2.72,
				-20.55
			),
			Vector3(
				0.72,
				0.72,
				0.72
			),
			0.0,
			"TrainWallClock"
		)

	if ResourceLoader.exists(
		str(
			ASSETS["fan"]
		)
	):
		_instance_asset(
			"fan",
			Vector3(
				-5.02,
				2.55,
				17.0
			),
			Vector3(
				0.62,
				0.62,
				0.62
			),
			PI
			/ 2.0,
			"TrainSmallWallFan"
		)

	if ResourceLoader.exists(
		str(
			ASSETS["corkboard"]
		)
	):
		_instance_asset(
			"corkboard",
			Vector3(
				5.02,
				2.34,
				17.0
			),
			Vector3(
				0.55,
				0.55,
				0.55
			),
			-PI
			/ 2.0,
			"TrainSmallNoticeBoard"
		)


func _build_luggage() -> void:
	var rack_items: Array[Dictionary] = [
		{
			"key": "case",
			"position": Vector3(
				-4.50,
				3.31,
				-12.0
			),
			"scale": Vector3(
				0.72,
				0.72,
				0.72
			),
			"yaw": 0.08,
		},
		{
			"key": "travel_bag",
			"position": Vector3(
				-4.50,
				3.31,
				10.0
			),
			"scale": Vector3(
				0.70,
				0.70,
				0.70
			),
			"yaw": -0.10,
		},
		{
			"key": "backpack",
			"position": Vector3(
				4.50,
				3.31,
				-7.0
			),
			"scale": Vector3(
				0.70,
				0.70,
				0.70
			),
			"yaw": 0.10,
		},
		{
			"key": "case",
			"position": Vector3(
				4.50,
				3.31,
				12.0
			),
			"scale": Vector3(
				0.68,
				0.68,
				0.68
			),
			"yaw": -0.06,
		},
	]

	for spec: Dictionary in rack_items:
		var key: String = str(
			spec["key"]
		)

		var asset_path: String = str(
			ASSETS.get(
				key,
				""
			)
		)

		if not ResourceLoader.exists(
			asset_path
		):
			continue

		_instance_asset(
			key,
			spec["position"],
			spec["scale"],
			float(
				spec["yaw"]
			),
			"TrainRackLuggage"
		)

	if ResourceLoader.exists(
		str(
			ASSETS["shopping_bag"]
		)
	):
		_instance_asset(
			"shopping_bag",
			Vector3(
				4.72,
				0.0,
				-15.1
			),
			Vector3(
				0.62,
				0.62,
				0.62
			),
			-PI
			/ 2.0,
			"TrainFloorBag"
		)


func _build_exterior() -> void:
	# -----------------------------------------------------------------------
	# FLAWLESS 50 m LOOP
	# -----------------------------------------------------------------------
	#
	# editable_main.gd wraps each editable_train_scenery node by exactly 50 m:
	#
	#     if scenery.position.z > 25:
	#         scenery.position.z -= 50
	#
	# Therefore this scene uses five equally spaced 10 m scenery tiles, all at
	# the SAME speed. Their ground/water slabs overlap by 0.24 m, so there is
	# never a visible crack when a tile wraps from +25 back to -25.
	#
	# Buildings and trees stay well inside each tile's ±5 m boundary. Nothing
	# structural is allowed to cross a tile edge, preventing cut-off buildings.
	# -----------------------------------------------------------------------
	var tile_zs: Array[float] = [
		-20.0,
		-10.0,
		0.0,
		10.0,
		20.0,
	]

	for side: float in [
		-1.0,
		1.0
	]:
		for tile_index: int in range(
			tile_zs.size()
		):
			_build_seamless_scenery_tile(
				side,
				tile_zs[
					tile_index
				],
				tile_index
			)

	# Sunset disc is static and far enough away that it behaves like sky, while
	# the land/building belt loops in front of it.
	var sun := MeshInstance3D.new()
	sun.name = "TrainSunsetDisc"
	sun.position = Vector3(
		18.0,
		2.2,
		-2.0
	)
	sun.scale = Vector3(
		0.15,
		0.56,
		0.56
	)

	var sun_mesh := SphereMesh.new()
	sun_mesh.radius = 1.0
	sun_mesh.height = 2.0
	sun_mesh.radial_segments = 18
	sun_mesh.rings = 10
	sun.mesh = sun_mesh
	sun.material_override = _materials[
		"sun"
	]

	_room_root.add_child(
		sun
	)
	sun.owner = _scene_root

func _build_seamless_scenery_tile(
	side: float,
	z_value: float,
	tile_index: int
) -> void:
	var tile := Node3D.new()
	tile.name = "TrainLoopTile_%s_%02d" % [
		(
			"Left"
				if side < 0.0
				else "Right"
		),
		tile_index,
	]
	tile.position = Vector3(
		0.0,
		0.0,
		z_value
	)
	tile.set_meta(
		"parallax_speed",
		SCENERY_SPEED
	)
	tile.add_to_group(
		"editable_train_scenery",
		true
	)

	_room_root.add_child(
		tile
	)
	tile.owner = _scene_root

	# Identical overlapping edge geometry keeps the 50 m loop seamless.
	_box(
		tile,
		Vector3(
			7.8,
			0.07,
			SCENERY_TILE_LENGTH
			+ 0.34
		),
		Vector3(
			side * 9.25,
			-0.82,
			0.0
		),
		_materials["water"],
		"LoopWater"
	)

	_box(
		tile,
		Vector3(
			18.0,
			0.24,
			SCENERY_TILE_LENGTH
			+ 0.34
		),
		Vector3(
			side * 20.4,
			-0.66,
			0.0
		),
		_materials["shore"],
		"LoopLand"
	)

	_box(
		tile,
		Vector3(
			2.6,
			0.11,
			SCENERY_TILE_LENGTH
			+ 0.34
		),
		Vector3(
			side * 13.0,
			-0.72,
			0.0
		),
		_materials["shore"],
		"LoopShoreline"
	)

	# -----------------------------------------------------------------------
	# REAL GARDEN MOUNTAINS
	# -----------------------------------------------------------------------
	# These are the exact natural_rock_mountain_a/b/c assets already used by
	# the Garden. Keep each formation comfortably inside its 10 m tile so it
	# wraps as a complete object rather than being cut at a tile boundary.
	var mountain_keys: Array[String] = [
		"mountain_a",
		"mountain_b",
		"mountain_c",
	]

	for mountain_index: int in range(
		2
	):
		var mountain_key: String = mountain_keys[
			(
				tile_index
				+ mountain_index
			)
			% mountain_keys.size()
		]

		_instance_asset_under(
			tile,
			mountain_key,
			Vector3(
				side
				* (
					26.0
					+ float(
						mountain_index
					)
					* 4.0
				),
				-0.55,
				(
					-2.35
						if mountain_index == 0
						else 2.35
				)
			),
			Vector3(
				0.44,
				0.40
					+ float(
						tile_index % 2
					)
					* 0.05,
				0.44
			),
			(
				0.18
					* float(
						tile_index
							+ mountain_index
					)
			),
			"PassingNaturalRockMountain"
		)

	# -----------------------------------------------------------------------
	# DENSE FOREST BELT
	# -----------------------------------------------------------------------
	var tree_zs: Array[float] = [
		-4.0,
		-2.7,
		-1.3,
		0.0,
		1.3,
		2.7,
		4.0,
	]

	for tree_index: int in range(
		tree_zs.size()
	):
		var tree_key: String = (
			"garden_big_tree"
				if (
					tree_index == 3
					and tile_index % 2 == 0
				)
				else "garden_oak"
		)

		var tree_scale_value: float = (
			0.38
			+ float(
				(
					tile_index
						+ tree_index
				)
				% 4
			)
			* 0.07
		)

		_instance_asset_under(
			tile,
			tree_key,
			Vector3(
				side
				* (
					15.0
					+ float(
						tree_index % 3
					)
					* 1.10
				),
				-0.55,
				tree_zs[
					tree_index
				]
			),
			Vector3.ONE
			* tree_scale_value,
			0.11
			* float(
				tile_index
					+ tree_index
			),
			"PassingTree"
		)

	# -----------------------------------------------------------------------
	# OLD TOWN / CAMPSITE STRUCTURES
	# -----------------------------------------------------------------------
	# Two timber cottages remain on every tile.
	for house_index: int in range(
		2
	):
		var house_z: float = (
			-2.35
			+ float(
				house_index
			)
			* 4.55
		)

		var house_x: float = (
			side
			* (
				16.1
				+ float(
					(
						tile_index
							+ house_index
					)
					% 2
				)
				* 1.45
			)
		)

		_build_timber_cottage(
			tile,
			Vector3(
				house_x,
				-0.55,
				house_z
			),
			side,
			0.76
			+ float(
				(
					tile_index
						+ house_index
				)
				% 3
			)
			* 0.08
		)

	# Then add a real Garden structure cluster to EVERY tile, not just three of
	# the five tiles.
	match tile_index:
		0:
			_add_train_scenery_cluster(
				tile,
				side,
				"trailer"
			)

		1:
			_add_train_scenery_cluster(
				tile,
				side,
				"campsite"
			)

		2:
			_add_train_scenery_cluster(
				tile,
				side,
				"gazebo"
			)

		3:
			_add_train_scenery_cluster(
				tile,
				side,
				"trailer_camp"
			)

		4:
			_add_train_scenery_cluster(
				tile,
				side,
				"lantern_camp"
			)

	# Additional warm window points make the entire shoreline feel inhabited.
	for glow_index: int in range(
		7
	):
		var glow_z: float = (
			-4.2
			+ float(
				glow_index
			)
			* 1.40
		)

		_box(
			tile,
			Vector3(
				0.05,
				0.18,
				0.22
			),
			Vector3(
				side
				* (
					14.2
					+ float(
						glow_index % 3
					)
					* 0.58
				),
				0.28
					+ float(
						glow_index % 3
					)
					* 0.13,
				glow_z
			),
			_materials["town_glow"],
			"PassingVillageLight"
		)

func _add_train_scenery_cluster(
	parent: Node3D,
	side: float,
	cluster_type: String
) -> void:
	var structure_x: float = side * 18.2

	match cluster_type:
		"trailer":
			_instance_asset_under(
				parent,
				"garden_trailer",
				Vector3(
					structure_x,
					-0.55,
					0.0
				),
				Vector3.ONE
				* 0.50,
				(
					-0.20
						if side > 0.0
						else 0.20
				),
				"PassingForestTrailer"
			)

			_instance_asset_under(
				parent,
				"garden_bench",
				Vector3(
					side * 15.4,
					-0.55,
					2.6
				),
				Vector3.ONE
				* 0.54,
				0.35,
				"PassingTrailerBench"
			)

			_instance_asset_under(
				parent,
				"garden_streetlamp",
				Vector3(
					side * 15.0,
					-0.55,
					-2.8
				),
				Vector3.ONE
				* 0.54,
				0.0,
				"PassingTrailerStreetlamp"
			)

		"campsite":
			_instance_asset_under(
				parent,
				"garden_tent",
				Vector3(
					structure_x,
					-0.55,
					-0.5
				),
				Vector3.ONE
				* 0.48,
				-0.22,
				"PassingCampsiteTent"
			)

			_instance_asset_under(
				parent,
				"garden_firepit",
				Vector3(
					side * 15.2,
					-0.55,
					2.2
				),
				Vector3.ONE
				* 0.48,
				0.0,
				"PassingFirepit"
			)

			_instance_asset_under(
				parent,
				"garden_party_arch",
				Vector3(
					side * 16.0,
					-0.55,
					-2.6
				),
				Vector3.ONE
				* 0.42,
				0.0,
				"PassingPartyArch"
			)

		"gazebo":
			_instance_asset_under(
				parent,
				"garden_gazebo",
				Vector3(
					structure_x,
					-0.55,
					0.0
				),
				Vector3.ONE
				* 0.52,
				0.15,
				"PassingGazebo"
			)

			for lamp_z: float in [
				-2.4,
				2.4
			]:
				_instance_asset_under(
					parent,
					"garden_forest_lamp",
					Vector3(
						side * 15.4,
						-0.55,
						lamp_z
					),
					Vector3.ONE
					* 0.58,
					0.0,
					"PassingGardenLamp"
				)

		"trailer_camp":
			_instance_asset_under(
				parent,
				"garden_trailer",
				Vector3(
					side * 18.8,
					-0.55,
					-1.8
				),
				Vector3.ONE
				* 0.42,
				0.15,
				"PassingSmallTrailer"
			)

			_instance_asset_under(
				parent,
				"garden_tent",
				Vector3(
					side * 17.0,
					-0.55,
					2.3
				),
				Vector3.ONE
				* 0.38,
				-0.18,
				"PassingSmallTent"
			)

			_instance_asset_under(
				parent,
				"garden_lantern",
				Vector3(
					side * 14.8,
					-0.55,
					0.2
				),
				Vector3.ONE
				* 0.62,
				0.0,
				"PassingLantern"
			)

		"lantern_camp":
			_instance_asset_under(
				parent,
				"garden_tent",
				Vector3(
					side * 18.5,
					-0.55,
					0.8
				),
				Vector3.ONE
				* 0.44,
				0.18,
				"PassingTent"
			)

			_instance_asset_under(
				parent,
				"garden_bench",
				Vector3(
					side * 15.5,
					-0.55,
					-2.4
				),
				Vector3.ONE
				* 0.52,
				0.1,
				"PassingBench"
			)

			for lantern_z: float in [
				-3.1,
				0.0,
				3.1
			]:
				_instance_asset_under(
					parent,
					"garden_lantern",
					Vector3(
						side * 15.0,
						-0.55,
						lantern_z
					),
					Vector3.ONE
					* 0.62,
					0.0,
					"PassingLantern"
				)


func _build_mountain_peak_under(
	parent: Node,
	position_value: Vector3,
	scale_value: Vector3,
	material: Material,
	node_name: String
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.position = position_value
	node.scale = scale_value

	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 2.0
	cone.radial_segments = 5
	cone.rings = 1

	node.mesh = cone
	node.material_override = material

	parent.add_child(
		node
	)
	node.owner = _scene_root

	return node

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

		var inverse_basis: Basis = Basis(
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
		spot.seat_type = "train_booth"
		spot.seated_visual_offset = (
			TRAIN_VISUAL_OFFSET
		)
		spot.seat_height = 0.05
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
			"name": "Pip",
			"timer": "29m",
			"character": "rosie",
			"seat_index": 0,
		},
		{
			"name": "Zoe",
			"timer": "43m",
			"character": "raymond",
			"seat_index": 3,
		},
		{
			"name": "Milo",
			"timer": "19m",
			"character": "bob",
			"seat_index": 6,
		},
		{
			"name": "June",
			"timer": "54m",
			"character": "rosie",
			"seat_index": 9,
		},
		{
			"name": "Theo",
			"timer": "36m",
			"character": "raymond",
			"seat_index": 12,
		},
		{
			"name": "Iris",
			"timer": "22m",
			"character": "rosie",
			"seat_index": 15,
		},
		{
			"name": "Noah",
			"timer": "47m",
			"character": "bob",
			"seat_index": 19,
		},
		{
			"name": "Mae",
			"timer": "31m",
			"character": "rosie",
			"seat_index": 22,
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
			2.72,
			0.0
		)
		label.font_size = 22
		label.outline_size = 6
		label.modulate = Color(
			"#f4eee4"
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
			"name": "TrainReferenceWide",
			"position": Vector3(
				7.0,
				5.15,
				17.5
			),
			"target": Vector3(
				0.0,
				1.10,
				1.0
			),
			"broll": true,
		},
		{
			"name": "TrainDownAisle",
			"position": Vector3(
				0.42,
				2.40,
				17.0
			),
			"target": Vector3(
				0.0,
				1.22,
				-13.0
			),
			"broll": true,
		},
		{
			"name": "TrainTableBay",
			"position": Vector3(
				1.5,
				2.25,
				-9.0
			),
			"target": Vector3(
				-4.0,
				1.05,
				-8.1
			),
			"broll": false,
		},
		{
			"name": "TrainSunset",
			"position": Vector3(
				-1.3,
				2.55,
				-1.0
			),
			"target": Vector3(
				15.0,
				1.2,
				-2.5
			),
			"broll": true,
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
		17.0
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

	_room_root.add_child(
		node
	)
	node.owner = _scene_root

	if key == "long_seat" or key == "seat":
		_restyle_imported_asset(
			node,
			"seat"
		)

	# Table assets intentionally keep their selected ReBody/ReFabric textures.
	return node


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


func _add_local_scenery_light(
	parent: Node3D,
	position_value: Vector3,
	color: Color,
	energy: float,
	range_value: float
) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = "PassingStructureLight"
	light.position = position_value
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	light.shadow_enabled = false

	parent.add_child(
		light
	)
	light.owner = _scene_root

	return light


func _restyle_imported_asset(
	root: Node,
	style_key: String
) -> void:
	# Preserve imported geometry but replace its modern palette at the material
	# surface level. Material names from the source models carry Body/Fabric
	# labels, so this remains robust even when the mesh hierarchy changes.
	if root is MeshInstance3D:
		var mesh_instance := root as MeshInstance3D

		if mesh_instance.mesh != null:
			for surface_index: int in range(
				mesh_instance.mesh.get_surface_count()
			):
				var source_material: Material = (
					mesh_instance.mesh.surface_get_material(
						surface_index
					)
				)

				var material_name: String = ""

				if source_material != null:
					material_name = (
						source_material.resource_name.to_lower()
					)

				if style_key == "seat":
					if material_name.contains(
						"fabric"
					):
						mesh_instance.set_surface_override_material(
							surface_index,
							_materials["seat_fabric"]
						)
					else:
						mesh_instance.set_surface_override_material(
							surface_index,
							_materials["seat_frame"]
						)

				elif style_key == "table":
					mesh_instance.set_surface_override_material(
						surface_index,
						_materials["table_wood"]
					)

	for child: Node in root.get_children():
		_restyle_imported_asset(
			child,
			style_key
		)


func _build_cozy_carriage_decor() -> void:
	# -----------------------------------------------------------------------
	# WALNUT / BRASS TRIM
	# -----------------------------------------------------------------------
	for side: float in [
		-1.0,
		1.0
	]:
		_box(
			_room_root,
			Vector3(
				0.12,
				0.13,
				39.0
			),
			Vector3(
				side * 5.12,
				1.02,
				0.0
			),
			_materials["metal"],
			"CarriageBrassDadoRail"
		)

		_box(
			_room_root,
			Vector3(
				0.11,
				0.15,
				39.0
			),
			Vector3(
				side * 5.10,
				3.38,
				0.0
			),
			_materials["wall_lower"],
			"CarriageWalnutTopRail"
		)

	# More velvet drapes than v7.
	for side: float in [
		-1.0,
		1.0
	]:
		for window_z: float in [
			-17.2,
			-12.6,
			-8.0,
			-3.4,
			1.2,
			5.8,
			10.4,
			15.0
		]:
			_build_window_drape(
				side,
				window_z
			)

	# Dense candle-sconce rhythm between window bays.
	for side: float in [
		-1.0,
		1.0
	]:
		for sconce_z: float in [
			-15.0,
			-10.0,
			-5.0,
			0.0,
			5.0,
			10.0,
			15.0
		]:
			_build_candle_sconce(
				Vector3(
					side * 5.02,
					2.52,
					sconce_z
				),
				(
					PI / 2.0
						if side < 0.0
						else -PI / 2.0
				)
			)

	# -----------------------------------------------------------------------
	# RUGS
	# -----------------------------------------------------------------------
	for row_z: float in [
		-15.0,
		-5.0,
		5.0,
		15.0
	]:
		_box(
			_room_root,
			Vector3(
				3.30,
				0.022,
				3.35
			),
			Vector3(
				-3.65,
				0.030,
				row_z
			),
			_materials["aisle"],
			"LeftReadingRug"
		)

		_box(
			_room_root,
			Vector3(
				3.42,
				0.012,
				3.47
			),
			Vector3(
				-3.65,
				0.018,
				row_z
			),
			_materials["rug_border"],
			"LeftReadingRugBorder"
		)

	for compartment_z: float in [
		-10.4,
		10.4
	]:
		_box(
			_room_root,
			Vector3(
				4.55,
				0.022,
				7.55
			),
			Vector3(
				2.85,
				0.030,
				compartment_z
			),
			_materials["aisle"],
			"CompartmentRug"
		)

		_box(
			_room_root,
			Vector3(
				4.68,
				0.012,
				7.68
			),
			Vector3(
				2.85,
				0.018,
				compartment_z
			),
			_materials["rug_border"],
			"CompartmentRugBorder"
		)

	# -----------------------------------------------------------------------
	# MAIN TABLE LIGHTS
	# -----------------------------------------------------------------------
	for table_position: Vector3 in [
		Vector3(
			2.20,
			0.90,
			-10.4
		),
		Vector3(
			3.50,
			0.90,
			-10.4
		),
		Vector3(
			2.20,
			0.90,
			10.4
		),
		Vector3(
			3.50,
			0.90,
			10.4
		),
	]:
		_build_oil_lamp(
			table_position
		)

	# -----------------------------------------------------------------------
	# DECORATIVE TABLES — far denser than v7.
	# -----------------------------------------------------------------------
	var decorative_specs: Array[Dictionary] = [
		{
			"key": "table_antique",
			"position": Vector3(-4.20, 0.0, -18.25),
			"scale": Vector3(0.84, 0.84, 0.84),
			"yaw": 0.0,
			"style": "antique_lamp",
		},
		{
			"key": "table_vintage",
			"position": Vector3(4.05, 0.0, -18.10),
			"scale": Vector3(0.58, 0.72, 0.58),
			"yaw": PI,
			"style": "books",
		},
		{
			"key": "table_elegant",
			"position": Vector3(-4.05, 0.0, 18.15),
			"scale": Vector3(0.52, 0.72, 0.52),
			"yaw": 0.0,
			"style": "open_book",
		},
		{
			"key": "table_antique",
			"position": Vector3(4.20, 0.0, 18.20),
			"scale": Vector3(0.76, 0.76, 0.76),
			"yaw": PI,
			"style": "tea",
		},

		# Side tables between the four left-side reading rows.
		{
			"key": "table_antique",
			"position": Vector3(-4.72, 0.0, -10.0),
			"scale": Vector3(0.62, 0.68, 0.62),
			"yaw": PI / 2.0,
			"style": "antique_lamp",
		},
		{
			"key": "table_antique",
			"position": Vector3(-4.72, 0.0, 0.0),
			"scale": Vector3(0.60, 0.66, 0.60),
			"yaw": PI / 2.0,
			"style": "books",
		},
		{
			"key": "table_antique",
			"position": Vector3(-4.72, 0.0, 10.0),
			"scale": Vector3(0.62, 0.68, 0.62),
			"yaw": PI / 2.0,
			"style": "tea",
		},

		# Two additional compact accent tables on the far-right wall, kept clear
		# of the central cross-walkway.
		{
			"key": "table_elegant",
			"position": Vector3(4.62, 0.0, -4.8),
			"scale": Vector3(0.40, 0.58, 0.40),
			"yaw": -PI / 2.0,
			"style": "open_book",
		},
		{
			"key": "table_elegant",
			"position": Vector3(4.62, 0.0, 4.8),
			"scale": Vector3(0.40, 0.58, 0.40),
			"yaw": -PI / 2.0,
			"style": "antique_lamp",
		},
	]

	for spec: Dictionary in decorative_specs:
		_build_decorative_table(
			str(
				spec["key"]
			),
			spec["position"],
			spec["scale"],
			float(
				spec["yaw"]
			),
			str(
				spec["style"]
			)
		)

	# Extra Library props and book clusters around the carriage ends.
	_instance_optional_asset(
		"library_antique_clock",
		Vector3(
			0.0,
			0.0,
			-19.65
		),
		Vector3.ONE
		* 0.48,
		0.0,
		"TrainAntiqueClock"
	)

	_instance_optional_asset(
		"library_magazine_rack",
		Vector3(
			-1.85,
			0.0,
			18.65
		),
		Vector3.ONE
		* 0.58,
		PI,
		"TrainMagazineRack"
	)

	_instance_optional_asset(
		"library_bookstand",
		Vector3(
			1.75,
			0.0,
			18.65
		),
		Vector3.ONE
		* 0.54,
		PI,
		"TrainBookstand"
	)

	for book_z: float in [
		-15.7,
		-12.0,
		-5.7,
		-2.0,
		4.3,
		8.0,
		14.3,
		17.0
	]:
		_instance_optional_asset(
			"library_books",
			Vector3(
				-4.94,
				1.04,
				book_z
			),
			Vector3.ONE
			* 0.36,
			0.12,
			"TrainWindowBooks"
		)

func _build_decorative_table(
	key: String,
	position_value: Vector3,
	scale_value: Vector3,
	yaw: float,
	prop_style: String
) -> void:
	var table := _instance_optional_asset(
		key,
		position_value,
		scale_value,
		yaw,
		"TrainDecorativeTable"
	)

	if table == null:
		return

	var blocker_size := Vector3(
		1.10,
		0.78,
		1.00
	)

	if key == "table_vintage":
		blocker_size = Vector3(
			1.55,
			0.78,
			0.88
		)
	elif key == "table_elegant":
		blocker_size = Vector3(
			1.45,
			0.80,
			1.00
		)

	_add_blocker(
		position_value
		+ Vector3.UP
		* 0.38,
		blocker_size,
		yaw,
		"TrainDecorativeTableBlocker"
	)

	var top_y: float = 0.70

	match prop_style:
		"antique_lamp":
			var lamp := _instance_optional_asset(
				"library_bankers_lamp",
				position_value
				+ Vector3(
					0.0,
					top_y,
					0.0
				),
				Vector3.ONE
				* 0.48,
				yaw,
				"TrainDecorativeBankersLamp"
			)

			if lamp == null:
				_build_oil_lamp(
					position_value
					+ Vector3(
						0.0,
						top_y,
						0.0
					)
				)

		"books":
			_instance_optional_asset(
				"library_books",
				position_value
				+ Vector3(
					0.0,
					top_y,
					0.0
				),
				Vector3.ONE
				* 0.40,
				yaw
				+ 0.08,
				"TrainDecorativeBooks"
			)

		"open_book":
			var book := _instance_optional_asset(
				"library_open_book",
				position_value
				+ Vector3(
					0.0,
					top_y,
					0.0
				),
				Vector3.ONE
				* 0.44,
				yaw,
				"TrainDecorativeOpenBook"
			)

			if book == null:
				_instance_asset(
					"open_book",
					position_value
					+ Vector3(
						0.0,
						top_y,
						0.0
					),
					Vector3.ONE
					* 0.62,
					yaw,
					"TrainDecorativeOpenBook"
				)

		"tea":
			_instance_asset(
				"coffee",
				position_value
				+ Vector3(
					-0.12,
					top_y,
					0.05
				),
				Vector3.ONE
				* 0.62,
				yaw,
				"TrainDecorativeTea"
			)

			_build_oil_lamp(
				position_value
				+ Vector3(
					0.20,
					top_y,
					-0.08
				)
			)


func _build_window_drape(
	side: float,
	z_value: float
) -> void:
	for local_z: float in [
		-1.58,
		1.58
	]:
		_box(
			_room_root,
			Vector3(
				0.10,
				1.82,
				0.30
			),
			Vector3(
				side * 5.05,
				2.10,
				z_value
				+ local_z
			),
			_materials["curtain"],
			"VelvetWindowDrape"
		)

		_box(
			_room_root,
			Vector3(
				0.13,
				0.07,
				0.42
			),
			Vector3(
				side * 5.02,
				3.02,
				z_value
				+ local_z
			),
			_materials["metal"],
			"BrassCurtainCap"
		)


func _build_candle_sconce(
	position_value: Vector3,
	yaw: float
) -> void:
	var root := Node3D.new()
	root.name = "TrainCandleSconce"
	root.position = position_value
	root.rotation.y = yaw

	_room_root.add_child(
		root
	)
	root.owner = _scene_root

	_box(
		root,
		Vector3(
			0.10,
			0.35,
			0.14
		),
		Vector3.ZERO,
		_materials["metal_dark"],
		"SconceBackplate"
	)

	_box(
		root,
		Vector3(
			0.05,
			0.05,
			0.25
		),
		Vector3(
			0.0,
			-0.02,
			-0.16
		),
		_materials["metal"],
		"SconceArm"
	)

	_cylinder(
		root,
		0.035,
		0.23,
		Vector3(
			0.0,
			0.16,
			-0.27
		),
		_materials["paper"],
		"SconceCandle"
	)

	_sphere(
		root,
		Vector3(
			0.032,
			0.070,
			0.032
		),
		Vector3(
			0.0,
			0.34,
			-0.27
		),
		_materials["fire_glow"],
		"SconceFlame"
	)

	_add_omni_light(
		position_value
		+ Vector3.UP
		* 0.28,
		Color(
			"#ffae68"
		),
		0.72,
		3.4,
		"TrainSconceWarmLight"
	)


func _build_oil_lamp(
	position_value: Vector3
) -> void:
	_cylinder(
		_room_root,
		0.11,
		0.08,
		position_value
		+ Vector3.UP
		* 0.04,
		_materials["metal"],
		"OilLampBase"
	)

	_cylinder(
		_room_root,
		0.045,
		0.24,
		position_value
		+ Vector3.UP
		* 0.17,
		_materials["paper"],
		"OilLampGlass"
	)

	_sphere(
		_room_root,
		Vector3(
			0.034,
			0.072,
			0.034
		),
		position_value
		+ Vector3.UP
		* 0.31,
		_materials["fire_glow"],
		"OilLampFlame"
	)

	_add_omni_light(
		position_value
		+ Vector3.UP
		* 0.30,
		Color(
			"#ffad64"
		),
		0.62,
		3.0,
		"OilLampWarmLight"
	)


func _build_hanging_lantern(
	position_value: Vector3
) -> void:
	var root := Node3D.new()
	root.name = "OldCarriageLantern"
	root.position = position_value

	_room_root.add_child(
		root
	)
	root.owner = _scene_root

	_cylinder(
		root,
		0.025,
		0.30,
		Vector3(
			0.0,
			0.15,
			0.0
		),
		_materials["metal_dark"],
		"LanternChain"
	)

	_box(
		root,
		Vector3(
			0.34,
			0.42,
			0.34
		),
		Vector3(
			0.0,
			-0.22,
			0.0
		),
		_materials["light"],
		"LanternGlow"
	)

	# Four brass frame posts.
	for x_value: float in [
		-0.19,
		0.19
	]:
		for z_value: float in [
			-0.19,
			0.19
		]:
			_cylinder(
				root,
				0.015,
				0.48,
				Vector3(
					x_value,
					-0.22,
					z_value
				),
				_materials["metal"],
				"LanternFrame"
			)

	_add_omni_light(
		position_value
		+ Vector3.DOWN
		* 0.22,
		Color(
			"#ffc071"
		),
		1.05,
		5.2,
		"OldCarriageLanternLight"
	)


func _instance_optional_asset(
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

	return _instance_asset(
		key,
		position_value,
		scale_value,
		yaw,
		node_name
	)


func _build_timber_cottage(
	parent: Node3D,
	position_value: Vector3,
	side: float,
	scale_value: float
) -> void:
	var root := Node3D.new()
	root.name = "PassingTimberCottage"
	root.position = position_value
	root.scale = (
		Vector3.ONE
		* scale_value
	)

	parent.add_child(
		root
	)
	root.owner = _scene_root

	# Main old plaster body.
	_box(
		root,
		Vector3(
			2.30,
			1.80,
			2.25
		),
		Vector3(
			0.0,
			0.90,
			0.0
		),
		_materials["town"],
		"CottageBody"
	)

	# Dark roof.
	var roof := MeshInstance3D.new()
	roof.name = "CottageRoof"
	roof.position = Vector3(
		0.0,
		2.02,
		0.0
	)
	roof.rotation.z = PI / 4.0

	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(
		1.90,
		1.90,
		2.65
	)
	roof.mesh = roof_mesh
	roof.material_override = _materials["roof"]

	root.add_child(
		roof
	)
	roof.owner = _scene_root

	# Timber-frame crossbars.
	for y_value: float in [
		0.38,
		1.20
	]:
		_box(
			root,
			Vector3(
				2.38,
				0.09,
				0.08
			),
			Vector3(
				-side * 1.16,
				y_value,
				0.0
			),
			_materials["town_dark"],
			"CottageTimberHorizontal"
		)

	for z_value: float in [
		-0.72,
		0.0,
		0.72
	]:
		_box(
			root,
			Vector3(
				0.08,
				1.70,
				0.08
			),
			Vector3(
				-side * 1.16,
				0.88,
				z_value
			),
			_materials["town_dark"],
			"CottageTimberVertical"
		)

	# Two warm windows face the train.
	for z_value: float in [
		-0.55,
		0.55
	]:
		_box(
			root,
			Vector3(
				0.055,
				0.45,
				0.42
			),
			Vector3(
				-side * 1.19,
				1.05,
				z_value
			),
			_materials["town_glow"],
			"CottageWarmWindow"
		)


func _build_mountain_ridge(
	parent: Node3D,
	x_value: float,
	base_y: float,
	tile_index: int,
	layer_index: int,
	material: Material,
	height_scale: float
) -> void:
	# A jagged vertical silhouette strip. Boundary heights are identical on every
	# tile, while the interior peaks vary deterministically by tile/layer.
	var z_values: Array[float] = [
		-5.15,
		-4.25,
		-3.20,
		-2.15,
		-1.05,
		0.0,
		1.05,
		2.15,
		3.20,
		4.25,
		5.15,
	]

	var peak_patterns: Array[Array] = [
		[
			0.55,
			1.20,
			2.15,
			1.45,
			2.80,
			1.75,
			3.10,
			1.60,
			2.40,
			1.10,
			0.55,
		],
		[
			0.55,
			1.55,
			2.65,
			1.35,
			2.10,
			3.00,
			1.70,
			2.75,
			1.50,
			1.25,
			0.55,
		],
		[
			0.55,
			1.05,
			2.35,
			2.95,
			1.45,
			2.20,
			3.25,
			1.55,
			2.55,
			1.20,
			0.55,
		],
	]

	var pattern_index: int = (
		tile_index
		+ layer_index
	) % peak_patterns.size()

	var heights: Array = peak_patterns[
		pattern_index
	]

	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()

	for point_index: int in range(
		z_values.size()
	):
		var ridge_height: float = (
			float(
				heights[
					point_index
				]
			)
			* height_scale
		)

		vertices.append(
			Vector3(
				x_value,
				base_y,
				z_values[
					point_index
				]
			)
		)

		vertices.append(
			Vector3(
				x_value,
				base_y
				+ ridge_height,
				z_values[
					point_index
				]
			)
		)

	for segment_index: int in range(
		z_values.size()
		- 1
	):
		var a: int = segment_index * 2
		var b: int = a + 1
		var c: int = a + 2
		var d: int = a + 3

		indices.append_array(
			PackedInt32Array(
				[
					a,
					b,
					d,
					a,
					d,
					c,
				]
			)
		)

	var arrays: Array = []
	arrays.resize(
		Mesh.ARRAY_MAX
	)
	arrays[
		Mesh.ARRAY_VERTEX
	] = vertices
	arrays[
		Mesh.ARRAY_INDEX
	] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES,
		arrays
	)

	var ridge := MeshInstance3D.new()
	ridge.name = "LayeredMountainRidge"
	ridge.mesh = mesh
	ridge.material_override = material

	parent.add_child(
		ridge
	)
	ridge.owner = _scene_root


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
	mesh.radial_segments = 16
	mesh.rings = 10

	node.mesh = mesh
	node.material_override = material

	parent.add_child(
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


func _unshaded_material(
	name_value: String,
	color: Color
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = name_value
	material.albedo_color = color
	material.roughness = 1.0
	material.shading_mode = (
		BaseMaterial3D.SHADING_MODE_UNSHADED
	)
	material.cull_mode = (
		BaseMaterial3D.CULL_DISABLED
	)
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

	var make_error: Error = (
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
		+ "/train_before_old_world_v9_"
		+ timestamp
		+ ".tscn"
	)

	var copy_error: Error = (
		DirAccess.copy_absolute(
			ProjectSettings.globalize_path(
				TRAIN_SCENE_PATH
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
		"No new Train scene changes were saved by this run."
	)
	print("")
	quit(
		1
	)
