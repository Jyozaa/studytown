extends Node

enum Screen { MENU, ROOM, FOCUS }

const PlayerControllerScript := preload("res://scripts/player/player_controller.gd")
const CharacterLoaderScript := preload("res://scripts/assets/character_loader.gd")
const AssetLoaderScript := preload("res://scripts/assets/asset_loader.gd")
const FollowCameraScript := preload("res://scripts/camera/follow_camera.gd")
const FocusCameraDirectorScript := preload("res://scripts/camera/focus_camera_director.gd")
const StudySpotScript := preload("res://scripts/study/study_spot.gd")
const NPCControllerScript := preload("res://scripts/npc/npc_controller.gd")
const RoomFloorScript := preload("res://scripts/world/room_floor.gd")
const RoomDefinitionsScript := preload("res://scripts/rooms/room_definitions.gd")
const GENERATED_ASSET_DIR := "res://assets/dev_local/blender_generated/runtime/"

# Physics layer 5.
# This layer is queried by cinematic/focus cameras but ignored by the player.
const CAMERA_OCCLUDER_LAYER := 1 << 4

# World geometry + camera-only visual occluders.
const FOCUS_OCCLUSION_MASK := 1 | CAMERA_OCCLUDER_LAYER

# These offsets are added on top of CharacterProfile.sitting_visual_offset.
#
# Armchairs and especially train booths need a stronger upward correction
# because their actual upholstered seat surfaces are higher than ordinary
# chairs. The Blender train bench seat surface is ~0.84m and the generated
# armchair is ~0.79m.
const SEAT_VISUAL_OFFSETS := {
	"desk_chair": Vector3(0.0, 0.15, 0.12),
	"armchair": Vector3(0.0, 0.40, 0.12),
	"cafe_chair": Vector3(0.0, 0.20, 0.12),
	"train_booth": Vector3(0.0, 0.50, 0.02),
	"floor_cushion": Vector3(0.0, -0.18, 0.02),
	# Position tuning for the imported cat while lying on a tanning bed.
	# The user can adjust this later without touching the Resting animation.
	"tanning_bed": Vector3.ZERO,
}

# Tanning-bed anchors are intentionally isolated here so placement can be
# tuned later without changing the Resting pose or timer interaction.
const TANNING_BED_LYING_HEIGHT := 0.58
const TANNING_BED_STAND_DISTANCE := 1.42
const TANNING_BED_LYING_YAW_OFFSET := PI / 2.0

# Market-stall placement. This sits in the open grass area directly in front
# (south) of the fountain while remaining clear of the current paved routes.
# Position and yaw are isolated here for easy visual tuning later.
const GARDEN_MARKET_STALL_POSITION := Vector3(2.0, 0.0, 7)
const GARDEN_MARKET_STALL_YAW := 0.0

const CREAM := Color("#fff4d6")
const INK := Color("#2d211c")
const COCOA := Color("#533528")
const WOOD := Color("#9f582d")
const HONEY := Color("#dc8e3d")
const GREEN := Color("#3f8f58")
const TEAL := Color("#2f8f92")
const BLUE := Color("#4b73cb")
const GOLD := Color("#f3bd45")
const CORAL := Color("#ed755f")

var screen := Screen.MENU
var world_root: Node3D
var ui_root: CanvasLayer
var player
var player_visual: Node3D
var explore_camera: Camera3D
var follow_camera_rig

# Seat-relative shots that must actually see the studying player.
var focus_cameras: Array[Camera3D] = []

# Room/environment B-roll. These do not need to have the player visible.
var room_broll_cameras: Array[Camera3D] = []

var study_spots: Array = []
var npcs: Array[Node3D] = []
var prompt_label: Label
var debug_label: Label
var coins_label: Label
var focus_time_label: Label
var focus_task_label: Label
var focus_shot_label: Label
var debug_spots_visible := false
var focus_shot_index := 0
var focus_candidates_evaluated := 0
var focus_candidates_rejected := 0
var next_shot_at := 0.0
var nearest_spot := -1
var movement_enabled := true
var selected_duration := 25 * 60
var resting_duration := 30 * 60
var active_session_mode := "focus"
var task_input: LineEdit
var current_room_name := "Grand Library"
var player_parts: Dictionary = {}
var walk_phase := 0.0
var wave_time := 0.0
var menu_character: Node3D
var character_loader
var asset_loader
var focus_camera_director
var current_room_config: Dictionary = {}
var collision_debug_visible := false
var train_scenery_nodes: Array[Node3D] = []
var garden_water_jet_nodes: Array[Node3D] = []
var garden_fire_nodes: Array[Node3D] = []
var active_study_spot
var pending_study_spot
var performance_review := false
var performance_started_at := 0
var performance_samples: Array[int] = []

var mats := {}

func _ready() -> void:
	seed(1207)
	character_loader = CharacterLoaderScript.new()
	character_loader.name = "CharacterLoader"
	add_child(character_loader)
	asset_loader = AssetLoaderScript.new()
	asset_loader.name = "AssetLoader"
	add_child(asset_loader)
	focus_camera_director = FocusCameraDirectorScript.new()
	focus_camera_director.name = "FocusCameraDirector"
	add_child(focus_camera_director)
	_build_materials()
	FocusManager.tick.connect(_on_focus_tick)
	FocusManager.completed.connect(_on_focus_completed)
	FocusManager.cancelled.connect(_on_focus_cancelled)
	var review := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("review="): review = arg.trim_prefix("review=")
		elif arg.begins_with("--review="): review = arg.trim_prefix("--review=")
		elif arg in ["perf", "--perf"]: performance_review = true
	match review:
		"library": current_room_name = GameState.ROOMS[0]; build_room(0)
		"focus": current_room_name = GameState.ROOMS[0]; build_room(0); call_deferred("_begin_review_focus")
		"focus_laptop": current_room_name = GameState.ROOMS[0]; build_room(0); call_deferred("_begin_review_focus_at", 7)
		"focus_book": current_room_name = GameState.ROOMS[0]; build_room(0); call_deferred("_begin_review_focus_at", 13)
		"garden_focus": current_room_name = GameState.ROOMS[1]; build_room(1); call_deferred("_begin_review_focus")
		"train_focus": current_room_name = GameState.ROOMS[2]; build_room(2); call_deferred("_begin_review_focus")
		"japanese_focus": current_room_name = GameState.ROOMS[3]; build_room(3); call_deferred("_begin_review_focus")
		"library_focus_fixed": current_room_name = GameState.ROOMS[0]; build_room(0); call_deferred("_begin_review_focus")
		"garden_focus_fixed": current_room_name = GameState.ROOMS[1]; build_room(1); call_deferred("_begin_review_focus")
		"train_focus_fixed": current_room_name = GameState.ROOMS[2]; build_room(2); call_deferred("_begin_review_focus")
		"japanese_focus_fixed": current_room_name = GameState.ROOMS[3]; build_room(3); call_deferred("_begin_review_focus")
		"garden": current_room_name = GameState.ROOMS[1]; build_room(1)
		"train": current_room_name = GameState.ROOMS[2]; build_room(2)
		"japanese": current_room_name = GameState.ROOMS[3]; build_room(3)
		"grounded": current_room_name = GameState.ROOMS[0]; build_room(0); call_deferred("_begin_review_walk")
		"player_walk_readable": GameState.selected_character = 2; current_room_name = GameState.ROOMS[0]; build_room(0); call_deferred("_begin_review_walk_side")
		"npc_walk_readable": current_room_name = GameState.ROOMS[0]; build_room(0); call_deferred("_begin_npc_walk_review")
		"library_hall": current_room_name = GameState.ROOMS[0]; build_room(0); call_deferred("_activate_review_camera", 0)
		"library_fireplace": current_room_name = GameState.ROOMS[0]; build_room(0); call_deferred("_activate_review_camera", 3)
		"library_shelves": current_room_name = GameState.ROOMS[0]; build_room(0); call_deferred("_activate_shelf_review")
		"all_seats": current_room_name = GameState.ROOMS[0]; build_room(0); call_deferred("_set_debug_spots", true); call_deferred("_activate_review_camera", 6)
		"npc_seating": current_room_name = GameState.ROOMS[0]; build_room(0); call_deferred("_activate_npc_review")
		"garden_npc_seating": current_room_name = GameState.ROOMS[1]; build_room(1); call_deferred("_activate_npc_review")
		"train_npc_seating": current_room_name = GameState.ROOMS[2]; build_room(2); call_deferred("_activate_npc_review")
		"japanese_npc_seating": current_room_name = GameState.ROOMS[3]; build_room(3); call_deferred("_activate_npc_review")
		"library_sitting": current_room_name = GameState.ROOMS[0]; build_room(0); call_deferred("_begin_seating_review", "desk_chair")
		"armchair_sitting": current_room_name = GameState.ROOMS[0]; build_room(0); call_deferred("_begin_seating_review", "armchair")
		"cafe_chair_sitting": current_room_name = GameState.ROOMS[1]; build_room(1); call_deferred("_begin_seating_review", "cafe_chair")
		"train_sitting": current_room_name = GameState.ROOMS[2]; build_room(2); call_deferred("_begin_seating_review", "train_booth")
		"japanese_sitting": current_room_name = GameState.ROOMS[3]; build_room(3); call_deferred("_begin_seating_review", "floor_cushion")
		"wall_bookshelves": current_room_name = GameState.ROOMS[3]; build_room(3); call_deferred("_activate_wall_shelf_review")
		"garden_tufts": current_room_name = GameState.ROOMS[1]; build_room(1); call_deferred("_activate_garden_tuft_review")
		"plant_placement": current_room_name = GameState.ROOMS[0]; build_room(0); call_deferred("_activate_plant_review")
		"prop_grounding": current_room_name = GameState.ROOMS[0]; build_room(0); call_deferred("_activate_prop_grounding_review")
		"garden_grass": current_room_name = GameState.ROOMS[1]; build_room(1); call_deferred("_activate_review_camera", 0)
		"garden_cafe": current_room_name = GameState.ROOMS[1]; build_room(1); call_deferred("_activate_review_camera", 1)
		"garden_water": current_room_name = GameState.ROOMS[1]; build_room(1); call_deferred("_activate_review_camera", 2)
		"garden_tree": current_room_name = GameState.ROOMS[1]; build_room(1); call_deferred("_activate_review_camera", 3)
		"garden_pool": current_room_name = GameState.ROOMS[1]; build_room(1); call_deferred("_activate_review_camera", 4)
		"garden_campfire": current_room_name = GameState.ROOMS[1]; build_room(1); call_deferred("_activate_review_camera", 5)
		"garden_stall": current_room_name = GameState.ROOMS[1]; build_room(1); call_deferred("_activate_review_camera", 6)
		"train_scenery": current_room_name = GameState.ROOMS[2]; build_room(2); call_deferred("_activate_review_camera", 5)
		"character_front": _build_character_review(0.0, false)
		"character_three_quarter": _build_character_review(0.62, false)
		"character_side": _build_character_review(PI / 2.0, false)
		"character_back": _build_character_review(PI, false)
		"character_sitting": _build_character_review(0.32, true)
		"cat_idle": _build_character_review(0.0, false, "Idle")
		"cat_walk": _build_character_review(0.0, false, "Walk")
		"cat_idle_three_quarter": _build_character_review(0.58, false, "Idle")
		"cat_walk_three_quarter": _build_character_review(0.58, false, "Walk")
		"cat_walk_side": _build_character_review(PI / 2.0, false, "Walk")
		"cat_sit": _build_character_review(0.32, true, "Sit")
		"cat_seated_idle": _build_character_review(0.32, true, "SeatedIdle")
		"cat_study_laptop": _build_character_review(0.32, true, "StudyLaptop")
		"cat_study_book": _build_character_review(0.32, true, "StudyBook")
		"cat_wave": _build_character_review(0.0, false, "Wave")
		"cat_stretch": _build_character_review(0.0, false, "Stretch")
		"cat_cheer": _build_character_review(0.0, false, "Cheer")
		_: show_main_menu()
	if performance_review:
		performance_started_at = Time.get_ticks_msec()

func _build_materials() -> void:
	for entry in [
		["cream", CREAM, 0.72, 0.0], ["ink", INK, 0.84, 0.0],
		["cocoa", COCOA, 0.78, 0.0], ["wood", WOOD, 0.7, 0.0],
		["honey", HONEY, 0.62, 0.0], ["green", GREEN, 0.78, 0.0],
		["teal", TEAL, 0.55, 0.0], ["blue", BLUE, 0.62, 0.0],
		["gold", GOLD, 0.45, 0.1], ["coral", CORAL, 0.68, 0.0],
		["skin1", Color("#c98359"), 0.72, 0.0], ["skin2", Color("#f0b890"), 0.72, 0.0],
		["skin3", Color("#6d3d2c"), 0.74, 0.0], ["hair1", Color("#251b1c"), 0.82, 0.0],
		["hair2", Color("#a8462e"), 0.78, 0.0], ["hair3", Color("#201c23"), 0.88, 0.0],
		["paper", Color("#fff8e8"), 0.92, 0.0], ["glass", Color("#bdeaff"), 0.12, 0.25],
		["grass", Color("#3f8650"), 0.9, 0.0], ["leaf", Color("#287847"), 0.88, 0.0],
		["stone", Color("#b9aa94"), 0.96, 0.0], ["red", Color("#b9483e"), 0.72, 0.0],
		["purple", Color("#7f559f"), 0.72, 0.0], ["pink", Color("#e987a8"), 0.72, 0.0],
	]:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = entry[1]
		mat.roughness = entry[2]
		mat.metallic = entry[3]
		if entry[0] == "glass":
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 0.32
		mats[entry[0]] = mat
	var grass_texture_path := "res://assets/dev_local/environment/grass.jpg"
	if ResourceLoader.exists(grass_texture_path):
		mats.grass.albedo_texture = load(grass_texture_path)
		mats.grass.albedo_color = Color("#b8d9a4")
		mats.grass.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		mats.grass.texture_repeat = true
		mats.grass.uv1_scale = Vector3(16.0, 16.0, 16.0)

	# Garden lawn uses the exact user-supplied source image copied into the
	# project. No generated atlas, colour processing or procedural replacement.
	var garden_grass := StandardMaterial3D.new()
	garden_grass.albedo_color = Color.WHITE
	garden_grass.roughness = 0.92
	garden_grass.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	garden_grass.texture_repeat = false

	var garden_grass_texture_path := "res://assets/dev_local/environment/garden_grass.jpeg"
	if ResourceLoader.exists(garden_grass_texture_path):
		garden_grass.albedo_texture = load(garden_grass_texture_path)
	else:
		garden_grass.albedo_color = Color("#298f68")
	mats.garden_grass = garden_grass

	# A solid underlay sits beneath the image tiles. It is only visible through
	# sub-pixel seams at extreme camera angles and prevents bright cracks.
	var garden_grass_underlay := StandardMaterial3D.new()
	garden_grass_underlay.albedo_color = Color("#278e68")
	garden_grass_underlay.roughness = 0.94
	mats.garden_grass_underlay = garden_grass_underlay

	# Seamless continuous stone path material. The supplied tile.png is mapped
	# in world space so adjacent CSG path segments share one texture scale rather
	# than each restarting at a tile boundary.
	var garden_path := StandardMaterial3D.new()
	garden_path.albedo_color = Color.WHITE
	garden_path.roughness = 0.94
	garden_path.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	garden_path.texture_repeat = true
	garden_path.uv1_triplanar = true
	garden_path.uv1_world_triplanar = true
	garden_path.uv1_scale = Vector3(0.72, 0.72, 0.72)
	var garden_path_texture_path := "res://assets/dev_local/environment/tile.png"
	if ResourceLoader.exists(garden_path_texture_path):
		garden_path.albedo_texture = load(garden_path_texture_path)
	else:
		garden_path.albedo_color = Color("#9c958b")
	mats.garden_path = garden_path

	# Animated water surface used by the fountain basin and pool.
	var water_shader_material := ShaderMaterial.new()
	var water_shader_path := "res://shaders/garden_water.gdshader"
	if ResourceLoader.exists(water_shader_path):
		var water_shader_resource: Resource = load(water_shader_path)
		if water_shader_resource is Shader:
			water_shader_material.shader = water_shader_resource as Shader
			mats.water = water_shader_material
	else:
		var water_fallback := StandardMaterial3D.new()
		water_fallback.albedo_color = Color(0.27, 0.72, 0.80, 0.86)
		water_fallback.roughness = 0.12
		water_fallback.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mats.water = water_fallback

	# Continuous fountain streams use a separate animated translucent shader.
	var stream_material := ShaderMaterial.new()
	var stream_shader_path := "res://shaders/garden_stream.gdshader"
	if ResourceLoader.exists(stream_shader_path):
		var stream_shader_resource: Resource = load(stream_shader_path)
		if stream_shader_resource is Shader:
			stream_material.shader = stream_shader_resource as Shader
			mats.fountain_stream = stream_material
	else:
		var stream_fallback := StandardMaterial3D.new()
		stream_fallback.albedo_color = Color(0.68, 0.93, 1.0, 0.66)
		stream_fallback.roughness = 0.05
		stream_fallback.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		stream_fallback.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mats.fountain_stream = stream_fallback

	# The upper fountain uses a continuous umbrella-shaped sheet rather than
	# separate crown jets. A dedicated shader keeps the sheet broken-up/foamy
	# enough to read as moving water instead of transparent glass.
	var sheet_material := ShaderMaterial.new()
	var sheet_shader_path := "res://shaders/garden_fountain_sheet.gdshader"
	if ResourceLoader.exists(sheet_shader_path):
		var sheet_shader_resource: Resource = load(sheet_shader_path)
		if sheet_shader_resource is Shader:
			sheet_material.shader = sheet_shader_resource as Shader
			mats.fountain_sheet = sheet_material
	else:
		mats.fountain_sheet = mats.fountain_stream

	var flame_outer := StandardMaterial3D.new()
	flame_outer.albedo_color = Color("#ff6a2b")
	flame_outer.emission_enabled = true
	flame_outer.emission = Color("#ff5424")
	flame_outer.emission_energy_multiplier = 2.4
	flame_outer.roughness = 0.35
	mats.flame_outer = flame_outer

	var flame_inner := StandardMaterial3D.new()
	flame_inner.albedo_color = Color("#ffd15c")
	flame_inner.emission_enabled = true
	flame_inner.emission = Color("#ffb52d")
	flame_inner.emission_energy_multiplier = 2.8
	flame_inner.roughness = 0.30
	mats.flame_inner = flame_inner

func _clear_scene() -> void:
	# Queue the old scene for deletion.
	if is_instance_valid(world_root):
		world_root.queue_free()

	if is_instance_valid(ui_root):
		ui_root.queue_free()

	# IMPORTANT:
	# References to children of the old World can otherwise remain pointing at
	# already-freed Godot Objects. Explicitly clear them whenever the room/menu
	# scene is rebuilt.
	player = null
	player_visual = null
	explore_camera = null
	follow_camera_rig = null
	menu_character = null

	active_study_spot = null
	pending_study_spot = null
	active_session_mode = "focus"

	player_parts.clear()

	study_spots.clear()
	npcs.clear()
	focus_cameras.clear()
	room_broll_cameras.clear()
	train_scenery_nodes.clear()
	garden_water_jet_nodes.clear()
	garden_fire_nodes.clear()

	nearest_spot = -1

	# Create the new scene roots.
	world_root = Node3D.new()
	world_root.name = "World"
	add_child(world_root)

	ui_root = CanvasLayer.new()
	ui_root.name = "Interface"
	add_child(ui_root)


func show_main_menu() -> void:
	screen = Screen.MENU
	_set_movement_enabled(false)
	_clear_scene()
	_build_menu_world()
	_build_menu_ui()

func _build_menu_world() -> void:
	_add_environment(Color("#403029"), Color("#fff0cb"), 0.9)
	var floor := _box(world_root, Vector3(8, 0.35, 8), Vector3(0, -0.3, 0), mats.wood)
	floor.rotation.y = PI / 4.0
	for i in 8:
		var star := _sphere(world_root, Vector3(0.10, 0.10, 0.10), Vector3(cos(i) * 3.1, 0.25 + (i % 3) * 0.35, sin(i) * 3.1), mats.gold)
		star.name = "WarmSparkle"
	menu_character = _create_character(world_root, GameState.selected_character, false)
	menu_character.position = Vector3(0.8, 0, 0)
	menu_character.scale *= 1.10
	var pedestal := _cylinder(world_root, 1.75, 0.35, Vector3(0.8, -0.08, 0), mats.cream, 48)
	pedestal.position.y = -0.16
	var cam := Camera3D.new()
	world_root.add_child(cam)
	cam.position = Vector3(5.8, 3.4, 7.8)
	cam.fov = 34
	cam.look_at_from_position(cam.position, Vector3(0.8, 1.65, 0))
	cam.current = true
	var light := OmniLight3D.new()
	world_root.add_child(light)
	light.position = Vector3(1, 5, 4)
	light.light_color = Color("#ffd89b")
	light.light_energy = 7.0
	light.omni_range = 12.0
	light.shadow_enabled = true

func _build_character_review(yaw: float, seated: bool, animation_state := "") -> void:
	screen = Screen.MENU
	_clear_scene()
	_add_environment(Color("#b98f78"), Color("#fff0ce"), 0.82)
	_cylinder(world_root, 2.0, 0.34, Vector3(0, -0.17, 0), mats.cream, 48)
	var character := _create_character(world_root, 0, seated)
	character.rotation.y = yaw
	if not animation_state.is_empty():
		character_loader.play_animation(character, animation_state, 0.0)
	if seated:
		_build_armchair(Vector3(0, 0, 0.22), 0.0, mats.teal)
	var cam := _make_camera(Vector3(0, 2.45, 6.6), Vector3(0, 1.42, 0), 28.0)
	cam.current = true
	var title := _label("MASTER CHARACTER 01  ·  %s" % ("SEATED" if seated else "MODEL REVIEW"), 18, CREAM)
	ui_root.add_child(title)
	title.position = Vector2(36, 32)
	title.add_theme_stylebox_override("normal", _panel_style(Color(0.08,0.05,0.04,0.82), 18, 1, Color(1,0.85,0.6,0.2)))

func _build_menu_ui() -> void:
	var wash := ColorRect.new()
	ui_root.add_child(wash)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(0.06, 0.045, 0.035, 0.18)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var left := PanelContainer.new()
	ui_root.add_child(left)
	left.position = Vector2(42, 38)
	left.size = Vector2(410, 644)
	left.add_theme_stylebox_override("panel", _panel_style(Color("#fff5dc"), 30, 8, Color("#e6b66b")))
	var margin := MarginContainer.new()
	left.add_child(margin)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 26)
	var stack := VBoxContainer.new()
	margin.add_child(stack)
	stack.add_theme_constant_override("separation", 13)
	var eyebrow := _label("WELCOME TO", 13, GREEN)
	stack.add_child(eyebrow)
	var title := _label(GameState.PRODUCT_NAME, 43, INK)
	title.add_theme_font_size_override("font_size", 43)
	stack.add_child(title)
	var subtitle := _label("A cozy place to do meaningful work, together.", 18, COCOA)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(subtitle)
	stack.add_child(_separator())
	stack.add_child(_label("Choose your study buddy", 20, INK))
	var chars := HBoxContainer.new()
	chars.add_theme_constant_override("separation", 10)
	stack.add_child(chars)
	var char_names := ["Bob", "Rosie", "Raymond"]
	for i in 3:
		var b := _button(char_names[i], i == GameState.selected_character)
		b.custom_minimum_size = Vector2(104, 52)
		b.pressed.connect(_select_character.bind(i))
		chars.add_child(b)
	stack.add_child(_label("Where do you want to focus?", 20, INK))
	var room_names := ["Grand Library", "Garden Café", "Scenic Train", "Japanese Study Room"]
	var descriptors := ["Warm & bookish  ·  6 studying", "Sunny & leafy  ·  5 studying", "Mountain views  ·  4 studying", "Quiet & serene  ·  5 studying"]
	for i in 4:
		var card := Button.new()
		card.text = room_names[i] + "\n" + descriptors[i]
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.custom_minimum_size = Vector2(0, 62)
		card.add_theme_font_size_override("font_size", 16)
		card.add_theme_color_override("font_color", INK)
		card.add_theme_color_override("font_hover_color", INK)
		card.add_theme_stylebox_override("normal", _panel_style(Color("#f7e8c8"), 16, 2, Color("#ead09b")))
		card.add_theme_stylebox_override("hover", _panel_style(Color("#ffe3a9"), 16, 3, HONEY))
		card.add_theme_stylebox_override("pressed", _panel_style(Color("#f4cd82"), 16, 3, WOOD))
		card.pressed.connect(_enter_room.bind(i))
		stack.add_child(card)

	var tip := _pill("Pick a room card to begin", Vector2(860, 638))
	ui_root.add_child(tip)

func _select_character(index: int) -> void:
	GameState.selected_character = index
	GameState.save()
	show_main_menu()

func _enter_room(index: int) -> void:
	GameState.selected_room = index
	GameState.save()
	current_room_name = GameState.ROOMS[index]
	build_room(index)

func build_room(index: int) -> void:
	screen = Screen.ROOM

	# Destroy/reset references from the previous menu or room first.
	_clear_scene()

	current_room_config = RoomDefinitionsScript.get_room(index)

	_add_structural_floor(current_room_config.size)

	match index:
		0:
			_build_library()
		1:
			_build_garden()
		2:
			_build_train()
		3:
			_build_japanese_room()

	_create_player()
	_create_follow_camera()
	_build_room_ui()
	_update_camera_current()

	# Enable movement only after the new Player actually exists.
	_set_movement_enabled(true)

func _process(delta: float) -> void:
	if mats.has("water") and mats.water is StandardMaterial3D:
		var water_material := mats.water as StandardMaterial3D
		water_material.uv1_offset += Vector3(delta * 0.010, delta * 0.006, 0.0)
	if performance_review:
		_collect_performance_sample()
	if is_instance_valid(menu_character):
		menu_character.rotation.y = sin(Time.get_ticks_msec() * 0.0005) * 0.18
	if screen == Screen.ROOM:
		_update_nearest_spot()
		if is_instance_valid(player_visual) and not bool(player_visual.get_meta("is_imported_character", false)):
			if player is PlayerController and player.current_locomotion == "Walk":
				walk_phase += delta * 9.5
				_animate_walk(sin(walk_phase) * 0.55)
			else:
				_animate_idle(delta)
	if screen == Screen.FOCUS and Time.get_unix_time_from_system() >= next_shot_at:
		_cycle_focus_camera()
	if current_room_config.get("id", "") == "train":
		for scenery in train_scenery_nodes:
			if is_instance_valid(scenery):
				scenery.position.z += delta * float(scenery.get_meta("parallax_speed", 2.0))
				if scenery.position.z > 25.0:
					scenery.position.z -= 50.0
	if current_room_config.get("id", "") == "garden":
		_animate_garden_effects(delta)
	if wave_time > 0.0:
		wave_time -= delta
		if player_parts.has("arm_r"):
			player_parts.arm_r.rotation.z = -1.9 + sin(wave_time * 11.0) * 0.28
	elif player_parts.has("arm_r") and screen != Screen.FOCUS:
		player_parts.arm_r.rotation.z = lerpf(player_parts.arm_r.rotation.z, -0.08, delta * 8.0)

func _collect_performance_sample() -> void:
	var elapsed := Time.get_ticks_msec() - performance_started_at
	if elapsed >= 3000 and elapsed < 7000:
		var expected_count := int((elapsed - 3000) / 1000) + 1
		if performance_samples.size() < expected_count:
			performance_samples.append(Engine.get_frames_per_second())
	elif elapsed >= 7000:
		var total := 0
		var minimum := 100000
		for sample in performance_samples:
			total += sample
			minimum = mini(minimum, sample)
		var average := roundi(float(total) / maxf(performance_samples.size(), 1.0))
		print("PERF_RESULT room=%s average_fps=%d minimum_fps=%d samples=%d" % [current_room_config.get("id", "menu"), average, minimum if not performance_samples.is_empty() else 0, performance_samples.size()])
		performance_review = false
		get_tree().quit()

func _physics_process(delta: float) -> void:
	if is_instance_valid(debug_label) and debug_label.visible:
		debug_label.text = "DEV  F3 anchors  ·  F4 collision  ·  F5 short focus  ·  F6 performance\nFPS: %d   Grounded: %s   Y: %.2f" % [Engine.get_frames_per_second(), str(is_instance_valid(player) and player.is_on_floor()), player.global_position.y if is_instance_valid(player) else 0.0]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		if screen == Screen.MENU:
			return
		if screen == Screen.FOCUS:
			FocusManager.cancel_session()
		show_main_menu()
	elif event.is_action_pressed("interact") and screen == Screen.ROOM and nearest_spot >= 0:
		var nearest = study_spots[nearest_spot]
		if str(nearest.seat_type) == "tanning_bed":
			_open_resting_setup(nearest_spot)
		else:
			_open_focus_setup(nearest_spot)
	elif event.is_action_pressed("wave") and screen == Screen.ROOM:
		wave_time = 1.45
		if bool(player_visual.get_meta("is_imported_character", false)):
			character_loader.play_animation(player_visual, "Wave", 0.12)
			get_tree().create_timer(1.1).timeout.connect(func():
				if is_instance_valid(player_visual) and screen == Screen.ROOM:
					character_loader.play_animation(player_visual, "Idle", 0.2)
			)
		_show_toast("You wave.  Jamie waves back!  👋")
	elif event.is_action_pressed("debug_spots") and screen == Screen.ROOM:
		debug_spots_visible = not debug_spots_visible
		_set_debug_spots(debug_spots_visible)
	elif event.is_action_pressed("debug_collision") and screen == Screen.ROOM:
		collision_debug_visible = not collision_debug_visible
		_set_collision_debug(collision_debug_visible)
	elif event.is_action_pressed("debug_focus") and screen == Screen.ROOM:
		selected_duration = 10
		_open_focus_setup(maxi(nearest_spot, 0))
	elif event.is_action_pressed("debug_overlay"):
		if is_instance_valid(debug_label):
			debug_label.visible = not debug_label.visible

func _create_player() -> void:
	player = PlayerControllerScript.new()
	player.name = "Player"
	world_root.add_child(player)
	var profile = character_loader.get_profile(GameState.selected_character)
	var using_imported := ResourceLoader.exists(profile.expected_local_path)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = profile.collider_radius if using_imported else 0.43
	capsule.height = profile.collider_height if using_imported else 1.85
	shape.shape = capsule
	shape.position.y = profile.collider_y_offset if using_imported else capsule.height * 0.5
	player.add_child(shape)
	player_visual = _create_character(player, GameState.selected_character, false)
	player_parts = player_visual.get_meta("parts", {})
	# Start in a readable three-quarter pose; movement immediately takes over
	# facing without affecting the fixed world-space camera yaw.
	player.configure_spawn(Transform3D(Basis(Vector3.UP, -PI * 0.75), current_room_config.spawn))
	player.locomotion_changed.connect(_on_player_locomotion_changed)
	var label := Label3D.new()
	player.add_child(label)
	label.text = "YOU"
	label.position = Vector3(0, profile.label_height if using_imported else 2.9, 0)
	label.font_size = 30
	label.outline_size = 8
	label.modulate = CREAM
	label.outline_modulate = Color(0.08, 0.05, 0.04, 0.85)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED

func _create_character(parent: Node, variant: int, seated: bool) -> Node3D:
	return character_loader.create_character(parent, variant, Callable(self, "_create_fallback_character"), seated)

func _create_fallback_character(parent: Node, variant: int, seated: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Character_%02d" % (variant + 1)
	parent.add_child(root)
	var skin: Material = mats[["skin1", "skin2", "skin3"][variant]]
	var hair: Material = mats[["hair1", "hair2", "hair3"][variant]]
	var top: Material = [mats.honey, mats.green, mats.gold][variant]
	var accent: Material = [mats.blue, mats.cream, mats.blue][variant]
	var parts := {}

	var torso := _sphere(root, Vector3(0.68, 0.67, 0.48), Vector3(0, 1.18, 0), top, 32, 20)
	torso.name = "SculptedSweater"
	var hem := _cylinder(root, 0.62, 0.22, Vector3(0, 0.82, 0), accent, 32)
	hem.scale.z = 0.78
	var head := _sphere(root, Vector3(0.93, 0.86, 0.72), Vector3(0, 2.08, -0.02), skin, 40, 24)
	head.name = "WideCheekHead"
	parts.head = head
	# Eyes use layered whites, irises, pupils and highlights for gameplay readability.
	for side in [-1.0, 1.0]:
		var eye := _sphere(root, Vector3(0.235, 0.285, 0.105), Vector3(side * 0.33, 2.02, -0.67), mats.paper, 24, 16)
		eye.rotation.x = -0.05
		_sphere(root, Vector3(0.122, 0.16, 0.07), Vector3(side * 0.33, 2.00, -0.765), [mats.blue, mats.green, mats.cocoa][variant], 20, 12)
		_sphere(root, Vector3(0.064, 0.095, 0.052), Vector3(side * 0.33, 1.995, -0.82), mats.ink, 16, 10)
		_sphere(root, Vector3(0.025, 0.034, 0.022), Vector3(side * 0.292, 2.055, -0.863), mats.paper, 12, 8)
	var mouth := _sphere(root, Vector3(0.09, 0.035, 0.025), Vector3(0, 1.67, -0.735), mats.coral, 16, 8)
	mouth.name = "SmallSmile"
	# Hair is assembled as directional sculpted clumps, not a single helmet.
	_sphere(root, Vector3(0.96, 0.50, 0.73), Vector3(0, 2.63, 0.02), hair, 32, 18)
	for i in 7:
		var ang := lerpf(-2.5, -0.55, float(i) / 6.0)
		var clump := _capsule_mesh(root, 0.16 + (i % 2) * 0.025, 0.72, Vector3(cos(ang) * 0.69, 2.50 + sin(i * 1.3) * 0.07, -0.37 + sin(ang) * 0.20), hair)
		clump.rotation.z = ang * 0.32
		clump.rotation.x = -0.35
	if variant == 1:
		for side in [-1.0, 1.0]:
			var braid := _capsule_mesh(root, 0.16, 0.85, Vector3(side * 0.72, 2.13, 0.07), hair)
			braid.rotation.z = side * 0.2
	if variant == 2:
		for x in [-0.62, -0.32, 0.0, 0.32, 0.62]:
			_sphere(root, Vector3(0.22, 0.22, 0.22), Vector3(x, 2.68 + cos(x * 6.0) * 0.08, -0.02), hair, 16, 10)

	var arm_l := Node3D.new(); root.add_child(arm_l); arm_l.position = Vector3(-0.59, 1.38, 0)
	var arm_r := Node3D.new(); root.add_child(arm_r); arm_r.position = Vector3(0.59, 1.38, 0)
	parts.arm_l = arm_l; parts.arm_r = arm_r
	for arm in [arm_l, arm_r]:
		_capsule_mesh(arm, 0.18, 0.77, Vector3(0, -0.32, 0), top)
		_sphere(arm, Vector3(0.22, 0.22, 0.22), Vector3(0, -0.74, -0.01), skin, 20, 12)
	var leg_l := Node3D.new(); root.add_child(leg_l); leg_l.position = Vector3(-0.29, 0.78, 0)
	var leg_r := Node3D.new(); root.add_child(leg_r); leg_r.position = Vector3(0.29, 0.78, 0)
	parts.leg_l = leg_l; parts.leg_r = leg_r
	for leg in [leg_l, leg_r]:
		_capsule_mesh(leg, 0.22, 0.67, Vector3(0, -0.30, 0), mats.cream if variant != 2 else mats.blue)
		var shoe := _sphere(leg, Vector3(0.31, 0.20, 0.43), Vector3(0, -0.68, -0.15), mats.blue if variant != 1 else mats.cocoa, 24, 14)
		shoe.name = "ChunkyShoe"
		_box(leg, Vector3(0.58, 0.07, 0.72), Vector3(0, -0.83, -0.16), mats.paper)
	if seated:
		leg_l.rotation.x = -1.25; leg_r.rotation.x = -1.25
	root.set_meta("parts", parts)
	return root

func _on_player_locomotion_changed(state: String) -> void:
	character_loader.play_animation(player_visual, state)

func _set_movement_enabled(value: bool) -> void:
	movement_enabled = value

	if is_instance_valid(player) and player is PlayerController:
		player.set_movement_enabled(value)

func _animate_walk(amount: float) -> void:
	if player_parts.is_empty(): return
	player_parts.leg_l.rotation.x = amount
	player_parts.leg_r.rotation.x = -amount
	player_parts.arm_l.rotation.x = -amount * 0.65
	if wave_time <= 0.0: player_parts.arm_r.rotation.x = amount * 0.65
	player_visual.position.y = abs(sin(walk_phase * 0.5)) * 0.045

func _animate_idle(delta: float) -> void:
	if player_parts.is_empty(): return
	for key in ["leg_l", "leg_r", "arm_l"]:
		player_parts[key].rotation.x = lerpf(player_parts[key].rotation.x, 0.0, delta * 8.0)
	if wave_time <= 0.0: player_parts.arm_r.rotation.x = lerpf(player_parts.arm_r.rotation.x, 0.0, delta * 8.0)
	player_visual.position.y = sin(Time.get_ticks_msec() * 0.002) * 0.012

func _build_library() -> void:
	_add_environment(Color("#312018"), Color("#ffddb2"), 1.05)
	# 44 x 32 structural footprint: entrance, hall, stacks, lounge, quiet desks and window nook.
	_box(world_root, Vector3(44.0, 0.35, 32.0), Vector3(0, -0.22, 0), mats.wood)
	for x in range(-20, 21, 4):
		for z in range(-14, 15, 4):
			_box(world_root, Vector3(3.72, 0.025, 3.72), Vector3(x, -0.02, z), mats.honey if (x + z) % 8 == 0 else mats.cocoa)
	_box(world_root, Vector3(44.4, 6.2, 0.5), Vector3(0, 2.9, -16.0), mats.cream)
	_box(world_root, Vector3(0.5, 6.2, 32.0), Vector3(-22.0, 2.9, 0), mats.cream)
	_box(world_root, Vector3(0.5, 0.8, 32.0), Vector3(22.0, 0.3, 0), mats.cream)
	for x in [-16.5, -9.5, -2.5, 4.5, 11.5, 18.5]:
		_build_window(Vector3(x, 3.1, -15.72), Vector2(4.6, 3.8), false)
	# The entrance is composed as a real reception zone instead of open floor.
	_box(world_root, Vector3(11.0, 0.05, 5.8), Vector3(0, 0.025, 10.5), mats.red)
	for data in [[Vector3(-7.4,0,10.2),PI / 2.0],[Vector3(-7.4,0,8.6),PI / 2.0]]:
		_place_local_prop("mini_diy_workbench", "", data[0], Vector3(1.65,1.25,1.35), data[1])
	_build_chair(Vector3(-5.8,0,9.4), -PI / 2.0)
	_build_armchair(Vector3(6.0,0,10.6), PI, mats.green)
	_build_armchair(Vector3(9.0,0,10.6), PI, mats.gold)
	_place_local_prop("potted_spring_flowers", "", Vector3(4.2,0,12.3), Vector3.ONE)
	_place_local_prop("potted_autumn_flowers", "", Vector3(10.8,0,12.2), Vector3.ONE)
	_place_local_prop("natural_basket", "", Vector3(7.5,0,8.9), Vector3.ONE)
	_place_local_prop("tote_bag", "", Vector3(9.7,0,9.3), Vector3.ONE)
	_place_local_prop("corkboard", "", Vector3(-19.7,1.25,13.0), Vector3.ONE, PI / 2.0)
	_place_local_prop("pendulum_clock", "", Vector3(-19.6,1.35,8.4), Vector3.ONE, PI / 2.0)
	_place_local_prop("wall_clock", "", Vector3(17.5,2.2,-15.30), Vector3.ONE)
	_place_local_prop("potted_summer_flowers", "", Vector3(14.0,0,12.4), Vector3.ONE)
	_place_local_prop("potted_winter_flowers", "", Vector3(-14.0,0,12.4), Vector3.ONE)
	for z in [-12.0, -7.5, -3.0, 1.5, 6.0, 10.5]:
		# Generated shelves expose their book side on local +Z after GLTF axis
		# conversion, so +90 degrees faces the left-wall units into the room.
		_build_bookshelf(Vector3(-21.55, 2.35, z), PI / 2.0, 3.8, 4.45, 0.52, int(z * 10.0 + 160.0))
	# Every free-standing aisle is an intentional back-to-back pair: books face
	# the walkable aisles and the thin unfinished backs meet in the middle.
	for x in [-9.0, 0.0, 9.0]:
		for aisle_center_z in [-5.5, 1.2]:
			_build_double_bookshelf(Vector3(x, 0.0, aisle_center_z), 0.0)
	_build_fireplace(Vector3(0, 0, -15.55))
	_box(world_root, Vector3(13.0, 0.05, 7.0), Vector3(0, 0.03, -11.0), mats.red)
	for pos in [Vector3(-4.0,0,-11.2), Vector3(-1.4,0,-9.4), Vector3(1.4,0,-9.4), Vector3(4.0,0,-11.2)]:
		_build_armchair(pos, 0.0, mats.teal if pos.x < 0 else mats.gold)
	for data in [[Vector3(-2.6,0,-11.0),0.0],[Vector3(2.6,0,-11.0),PI]]:
		_place_local_prop("mini_diy_workbench", "", data[0], Vector3(1.2,0.72,1.0), data[1])
	_place_local_prop("coffee_grinder", "", Vector3(-2.6,0.86,-11.0), Vector3.ONE)
	_place_local_prop("cup_of_coffee", "", Vector3(2.7,0.83,-11.0), Vector3.ONE)
	_place_local_prop("horoscope_set", "", Vector3(-0.2,0.84,-11.0), Vector3.ONE)
	_place_local_prop("fossil", "", Vector3(0.8,0.83,-10.9), Vector3.ONE)
	_place_local_prop("rug", "res://assets/external/kenney_furniture_kit/rugRounded.glb", Vector3(0,0.055,-11.0), Vector3(25.0,1.0,22.0))
	# Quiet desk area on the east side.
	for data in [[Vector3(15.5,0,-7.0),true],[Vector3(15.5,0,-1.0),false],[Vector3(15.5,0,5.0),true]]:
		_build_study_table(data[0], data[1])
		_place_local_prop("hardcover_books", "res://assets/external/kenney_furniture_kit/books.glb", data[0] + Vector3(-1.0,1.28,-0.18), Vector3.ONE)
		_place_local_prop("coffee_mug", "", data[0] + Vector3(1.1,1.24,0.22), Vector3.ONE)
		_place_local_prop("paperback_books", "", data[0] + Vector3(0.15,1.28,0.38), Vector3.ONE * 0.9, 0.16)
	_place_local_prop("cup_of_hot_chocolate", "", Vector3(16.5,1.25,-6.7), Vector3.ONE)
	_place_local_prop("thank_you_mom_dad_mugs", "", Vector3(14.4,1.25,-0.8), Vector3.ONE)
	# Communal reading tables fill the formerly empty approach to the stacks.
	for data in [[Vector3(-7.0,0,5.4),false],[Vector3(0.0,0,6.0),true],[Vector3(7.0,0,5.4),false]]:
		_build_study_table(data[0], data[1], "Book")
		_place_local_prop("lost_book", "", data[0] + Vector3(-0.9,1.27,0.18), Vector3.ONE, -0.12)
		_place_local_prop("nookphone", "", data[0] + Vector3(0.9,1.27,0.2), Vector3.ONE, 0.18)
	_place_local_prop("desk_fan", "", Vector3(0.0,1.27,6.0), Vector3.ONE)
	# Window reading area and side study nook.
	for pos in [Vector3(-16.0,0,-10.5), Vector3(-12.5,0,-10.5), Vector3(-17.0,0,8.5), Vector3(-13.5,0,10.5)]:
		_build_armchair(pos, PI, mats.green if pos.z > 0 else mats.gold)
	_build_study_table(Vector3(-14.8,0,4.2), false, "Book")
	_build_globe(Vector3(19.0, 0, 11.0))
	for pos in [Vector3(-19.5,0,13.2), Vector3(19.5,0,13.2), Vector3(19.5,0,-13.3)]:
		_place_local_prop("potted_autumn_flowers", "", pos, Vector3.ONE * 1.15)
	var npc_positions := [
		[Vector3(4.0, 0.05, -11.2), 0, 1, "Jamie", "18m"],
		[Vector3(-16.0, 0.05, -10.5), PI, 2, "Nora", "42m"],
		[Vector3(-13.5, 0.05, 10.5), PI, 0, "Kai", "26m"],
		[Vector3(-7.0, 0.05, 4.26), PI, 1, "Mina", "34m"],
		[Vector3(15.5, 0.05, 3.86), PI, 2, "Theo", "51m"],
		[Vector3(7.0, 0.05, 4.26), PI, 0, "Eli", "22m"],
	]
	for data in npc_positions:
		_create_npc(data[0], data[1], data[2], data[3], data[4], true)
	_focus_camera(Vector3(18.0, 10.5, 14.0), Vector3(0, 1.0, -2.0), "Reading hall wide")
	_focus_camera(Vector3(11.5, 3.2, -3.0), Vector3(15.5, 1.1, -6.8), "Player side study")
	_focus_camera(Vector3(16.0, 2.5, -4.3), Vector3(15.4, 1.1, -6.6), "Over shoulder")
	_focus_camera(Vector3(9.0, 6.8, -5.0), Vector3(0, 1.7, -14.5), "Fireplace lounge")
	_focus_camera(Vector3(-4.0, 2.8, 2.0), Vector3(0, 1.8, 0), "Bookshelf foreground")
	_focus_camera(Vector3(-9.0, 4.2, -8.0), Vector3(-15.0, 1.2, -10.0), "Window reading")
	_focus_camera(Vector3(-18.0, 7.5, 13.0), Vector3(0, 1.0, 0), "Architectural establishing")
	_add_world_boundaries(current_room_config.bounds)

func _build_bookshelf(pos: Vector3, yaw: float, width: float, height: float, depth: float, book_seed: int) -> void:
	var generated_path := GENERATED_ASSET_DIR + "bookshelf_single.glb"
	if ResourceLoader.exists(generated_path):
		_import_prop(generated_path, Vector3(pos.x, 0.0, pos.z), Vector3(width / 3.8, height / 4.45, depth / 0.68), yaw)
		_add_blocker(pos, Vector3(width + 0.45, height + 0.2, depth + 0.45), yaw)
		return
	var shelf := Node3D.new()
	world_root.add_child(shelf)
	shelf.position = pos
	shelf.rotation.y = yaw
	# Open-front construction: a thin recessed back plus sculpted frame rails.
	_box(shelf, Vector3(width + 0.18, height + 0.18, 0.14), Vector3(0, 0, depth * 0.42), mats.cocoa)
	_box(shelf, Vector3(0.22, height + 0.18, depth + 0.20), Vector3(-width * 0.5 - 0.03, 0, 0), mats.wood)
	_box(shelf, Vector3(0.22, height + 0.18, depth + 0.20), Vector3(width * 0.5 + 0.03, 0, 0), mats.wood)
	_box(shelf, Vector3(width + 0.48, 0.22, depth + 0.34), Vector3(0, height * 0.5 + 0.13, 0), mats.honey)
	_box(shelf, Vector3(width + 0.48, 0.25, depth + 0.34), Vector3(0, -height * 0.5 - 0.12, 0), mats.cocoa)
	var palette := [mats.red, mats.blue, mats.green, mats.gold, mats.purple, mats.cream, mats.coral]
	var rows := 5
	for r in rows:
		var y := -height * 0.5 + 0.47 + r * (height - 0.55) / rows
		_box(shelf, Vector3(width + 0.1, 0.15, depth + 0.20), Vector3(0, y - 0.31, -0.03), mats.honey)
		var x := -width * 0.5 + 0.18
		var index := 0
		while x < width * 0.5 - 0.12:
			var bw := 0.10 + fmod(float(book_seed + r * 13 + index * 7), 7.0) * 0.018
			var bh := 0.34 + fmod(float(book_seed + r * 19 + index * 11), 9.0) * 0.027
			var book := _box(shelf, Vector3(bw, bh, 0.31), Vector3(x, y - 0.07 + (bh - 0.34) * 0.5, -depth * 0.58), palette[(book_seed + r + index) % palette.size()])
			if index % 8 == 6: book.rotation.z = -0.13
			x += bw + 0.045
			index += 1
	_add_blocker(pos, Vector3(width + 0.45, height + 0.2, depth + 0.45), yaw)

func _build_double_bookshelf(pos: Vector3, yaw: float) -> void:
	var generated_path := GENERATED_ASSET_DIR + "bookshelf_double.glb"
	if ResourceLoader.exists(generated_path):
		_import_prop(generated_path, pos, Vector3.ONE, yaw)
		_add_blocker(pos + Vector3.UP * 1.9, Vector3(6.2, 4.0, 1.68), yaw)
		return
	_build_bookshelf(pos + Vector3(0, 2.05, -0.43), yaw, 5.8, 3.8, 0.72, 220)
	_build_bookshelf(pos + Vector3(0, 2.05, 0.43), yaw + PI, 5.8, 3.8, 0.72, 271)

func _build_window(pos: Vector3, size: Vector2, rotated: bool) -> void:
	var root := Node3D.new(); world_root.add_child(root); root.position = pos
	if rotated: root.rotation.y = PI / 2.0
	_box(root, Vector3(size.x + 0.36, 0.20, 0.24), Vector3(0, size.y * 0.5 + 0.10, 0), mats.cocoa)
	_box(root, Vector3(size.x + 0.36, 0.20, 0.24), Vector3(0, -size.y * 0.5 - 0.10, 0), mats.cocoa)
	_box(root, Vector3(0.20, size.y + 0.36, 0.24), Vector3(size.x * 0.5 + 0.10, 0, 0), mats.cocoa)
	_box(root, Vector3(0.20, size.y + 0.36, 0.24), Vector3(-size.x * 0.5 - 0.10, 0, 0), mats.cocoa)
	_box(root, Vector3(size.x, size.y, 0.25), Vector3(0, 0, -0.02), mats.glass)
	for x in [-size.x * 0.27, 0.0, size.x * 0.27]:
		_box(root, Vector3(0.08, size.y, 0.28), Vector3(x, 0, -0.08), mats.wood)
	for y in [-size.y * 0.25, size.y * 0.24]:
		_box(root, Vector3(size.x, 0.08, 0.28), Vector3(0, y, -0.08), mats.wood)
	var curtain_l := _capsule_mesh(root, 0.16, size.y + 0.25, Vector3(-size.x * 0.54, 0, -0.35), mats.red)
	var curtain_r := _capsule_mesh(root, 0.16, size.y + 0.25, Vector3(size.x * 0.54, 0, -0.35), mats.red)
	curtain_l.scale.z = 0.55; curtain_r.scale.z = 0.55

func _build_fireplace(pos: Vector3) -> void:
	var generated_path := GENERATED_ASSET_DIR + "fireplace.glb"
	if ResourceLoader.exists(generated_path):
		var generated := _import_prop(generated_path, pos, Vector3.ONE)
		var light := OmniLight3D.new(); generated.add_child(light)
		light.position = Vector3(0, 1.25, -1.0); light.light_color = Color("#ff9e4a"); light.light_energy = 4.2; light.omni_range = 6.0
		_add_blocker(pos + Vector3(0, 1.9, 0.15), Vector3(3.2, 3.8, 0.9), 0.0)
		return
	var root := Node3D.new(); world_root.add_child(root); root.position = pos
	_box(root, Vector3(3.05, 0.32, 0.70), Vector3(0, 3.70, 0.20), mats.honey)
	_box(root, Vector3(0.54, 3.8, 0.65), Vector3(-1.22, 1.78, 0.15), mats.stone)
	_box(root, Vector3(0.54, 3.8, 0.65), Vector3(1.22, 1.78, 0.15), mats.stone)
	_box(root, Vector3(3.1, 0.52, 0.86), Vector3(0, 0.18, 0.26), mats.stone)
	_box(root, Vector3(2.05, 2.45, 0.45), Vector3(0, 1.45, 0.15), mats.ink)
	_box(root, Vector3(1.58, 1.8, 0.12), Vector3(0, 1.05, -0.12), mats.cocoa)
	for x in [-0.52, -0.16, 0.18, 0.54]:
		var log := _capsule_mesh(root, 0.14, 1.25, Vector3(x, 0.66, -0.44), mats.wood)
		log.rotation.z = PI / 2.0
	for x in [-0.42, 0.0, 0.42]:
		var flame := _sphere(root, Vector3(0.24, 0.55 + abs(x) * 0.12, 0.18), Vector3(x, 1.08 + abs(x) * 0.25, -0.50), mats.gold, 20, 12)
		flame.rotation.z = x * 0.7
	var light := OmniLight3D.new(); root.add_child(light)
	light.position = Vector3(0, 1.25, -1.0); light.light_color = Color("#ff9e4a"); light.light_energy = 6.0; light.omni_range = 7.0
	_add_blocker(pos + Vector3(0, 1.9, 0.15), Vector3(3.2, 3.8, 0.9), 0.0)

func _build_study_table(pos: Vector3, flip: bool, study_type := "Laptop") -> void:
	var generated_path := GENERATED_ASSET_DIR + "study_table.glb"
	if ResourceLoader.exists(generated_path):
		_import_prop(generated_path, pos, Vector3.ONE)
	else:
		var root := Node3D.new(); world_root.add_child(root); root.position = pos
		_box(root, Vector3(3.65, 0.24, 1.55), Vector3(0, 1.05, 0), mats.wood)
		_box(root, Vector3(3.9, 0.09, 1.72), Vector3(0, 1.20, 0), mats.honey)
		for x in [-1.5, 1.5]:
			for z in [-0.55, 0.55]:
				_capsule_mesh(root, 0.12, 1.0, Vector3(x, 0.51, z), mats.cocoa)
	_import_prop("res://assets/external/kenney_furniture_kit/lampRoundTable.glb", pos + Vector3(0.55 if flip else -0.55, 1.23, 0), Vector3.ONE * 0.65)
	if study_type == "Laptop":
		_import_prop("res://assets/external/kenney_furniture_kit/laptop.glb", pos + Vector3(-0.55 if flip else 0.55, 1.26, -0.08), Vector3.ONE * 0.82, PI)
	else:
		_place_local_prop("lost_book", "res://assets/external/kenney_furniture_kit/books.glb", pos + Vector3(0.15, 1.26, -0.08), Vector3.ONE * 1.22, PI)
	_build_chair(pos + Vector3(0, 0, 1.42), PI, study_type)
	_build_chair(pos + Vector3(0, 0, -1.42), 0, study_type)
	# Deliberately composed paper, mug and book stack.
	_box(world_root, Vector3(0.50, 0.035, 0.68), pos + Vector3(-1.15, 1.29, 0.08), mats.paper).rotation.y = 0.12
	_cylinder(world_root, 0.17, 0.28, pos + Vector3(1.35, 1.38, 0.12), mats.teal, 24)
	for i in 3:
		_box(world_root, Vector3(0.55 + i * 0.04, 0.10, 0.38), pos + Vector3(1.18, 1.29 + i * 0.10, -0.42), [mats.red, mats.blue, mats.green][i])
	_add_blocker(pos + Vector3(0, 0.62, 0), Vector3(3.75, 1.24, 1.62), 0.0)

func _build_chair(pos: Vector3, yaw: float, study_type := "Book", seat_type := "desk_chair"):
	# Froggy Chair is intentionally no longer used at runtime. Standard desk
	# seating and Garden Cafe seating now use original StudyTown Blender assets
	# with different silhouettes appropriate to each environment.
	var generated_name := "cafe_chair" if seat_type == "cafe_chair" else "library_chair"
	var generated_path := GENERATED_ASSET_DIR + generated_name + ".glb"

	if ResourceLoader.exists(generated_path):
		_import_prop(generated_path, pos, Vector3.ONE, yaw)
	else:
		# Public/development fallback. Keep this visually close to the Blender
		# version so seating still reads correctly before local assets are built.
		var root := Node3D.new()
		world_root.add_child(root)
		root.position = pos
		root.rotation.y = yaw

		if seat_type == "cafe_chair":
			# Lightweight open-air bistro chair: slim warm-wood frame, small
			# cream seat, and an open slatted back.
			_box(root, Vector3(0.96, 0.16, 0.92), Vector3(0, 0.72, 0), mats.cream)
			for x in [-0.39, 0.39]:
				_capsule_mesh(root, 0.065, 0.76, Vector3(x, 0.36, -0.31), mats.wood)
				_capsule_mesh(root, 0.065, 1.40, Vector3(x, 0.95, 0.36), mats.wood)
			for y in [1.02, 1.24, 1.45]:
				_box(root, Vector3(0.82, 0.075, 0.10), Vector3(0, y, 0.38), mats.wood)
		else:
			# Traditional reading-room desk chair: darker wooden frame with a
			# modest upholstered seat and substantial back rails.
			_box(root, Vector3(1.02, 0.18, 0.96), Vector3(0, 0.72, 0), mats.cocoa)
			_box(root, Vector3(0.86, 0.08, 0.78), Vector3(0, 0.82, -0.02), mats.cream)
			for x in [-0.40, 0.40]:
				_capsule_mesh(root, 0.075, 0.82, Vector3(x, 0.37, -0.33), mats.cocoa)
				_capsule_mesh(root, 0.085, 1.52, Vector3(x, 1.02, 0.38), mats.cocoa)
			_box(root, Vector3(0.96, 0.12, 0.12), Vector3(0, 1.57, 0.38), mats.honey)
			for y in [1.14, 1.34]:
				_box(root, Vector3(0.72, 0.08, 0.10), Vector3(0, y, 0.38), mats.wood)

	var blocker_size := Vector3(1.08, 1.36, 1.06) if seat_type == "cafe_chair" else Vector3(1.16, 1.48, 1.12)
	_add_blocker(pos + Vector3(0, blocker_size.y * 0.5, 0), blocker_size, yaw)
	return _register_furniture_seat(pos, yaw, study_type, 0.05, 0.34, 0.96, seat_type)

func _build_armchair(pos: Vector3, yaw: float, fabric: Material, study_type := "Book"):
	var color_name := "gold" if fabric == mats.gold else ("teal" if fabric == mats.teal else "green")
	var generated_path := GENERATED_ASSET_DIR + "armchair_%s.glb" % color_name
	if ResourceLoader.exists(generated_path):
		_import_prop(generated_path, pos, Vector3.ONE, yaw)
	else:
		var root := Node3D.new(); world_root.add_child(root); root.position = pos; root.rotation.y = yaw
		_sphere(root, Vector3(0.85, 0.34, 0.78), Vector3(0, 0.53, 0), fabric, 28, 16)
		_sphere(root, Vector3(0.88, 0.83, 0.30), Vector3(0, 1.14, 0.44), fabric, 28, 16)
		for x in [-0.78, 0.78]: _sphere(root, Vector3(0.23, 0.32, 0.72), Vector3(x, 0.72, 0), fabric, 20, 12)
		for x in [-0.55, 0.55]: _capsule_mesh(root, 0.10, 0.44, Vector3(x, 0.20, 0.36), mats.cocoa)
	_add_blocker(pos + Vector3(0, 0.7, 0), Vector3(1.8, 1.4, 1.6), yaw)
	return _register_furniture_seat(pos, yaw, study_type, 0.10, 0.34, 1.25, "armchair")

func _register_furniture_seat(pos: Vector3, furniture_yaw: float, study_type: String, seat_height: float, forward_offset: float, stand_distance: float, seat_type := "desk_chair"):
	var seat_yaw := wrapf(furniture_yaw - PI, -PI, PI)
	var forward := Basis(Vector3.UP, seat_yaw) * Vector3.FORWARD
	var right := Basis(Vector3.UP, seat_yaw) * Vector3.RIGHT

	# The generic furniture values put the character too close to the front
	# edge of several seats. Keep seat placement authored by seat family.
	var tuned_forward_offset := forward_offset

	match seat_type:
		"desk_chair":
			tuned_forward_offset = 0.35
		"armchair":
			tuned_forward_offset = 0.65
		"cafe_chair":
			tuned_forward_offset = 0.35
		"train_booth":
			tuned_forward_offset = 0.40
		"floor_cushion":
			tuned_forward_offset = 0.0

	var sitting := pos + forward * tuned_forward_offset + Vector3.UP * seat_height
	var standing := pos - forward * stand_distance
	var camera_target := sitting + Vector3.UP * 1.20 + forward * 0.28
	# Personal focus views sit across the desk at a three-quarter angle so the
	# cat's face and animated paws remain visible instead of showing only its back.
	var camera_position := sitting + forward * 4.6 + right * 3.25 + Vector3.UP * 2.75
	var visual_offset: Vector3 = SEAT_VISUAL_OFFSETS.get(seat_type, Vector3.ZERO)
	return _add_study_spot(standing, sitting, seat_yaw, study_type, camera_position, camera_target, seat_type, visual_offset, seat_height)

func _build_globe(pos: Vector3) -> void:
	var generated_path := GENERATED_ASSET_DIR + "globe.glb"
	if ResourceLoader.exists(generated_path):
		_import_prop(generated_path, pos, Vector3.ONE)
		return
	_cylinder(world_root, 0.48, 0.18, pos + Vector3(0, 0.09, 0), mats.cocoa, 28)
	_capsule_mesh(world_root, 0.08, 1.45, pos + Vector3(0, 0.74, 0), mats.gold)
	_sphere(world_root, Vector3(0.70, 0.70, 0.70), pos + Vector3(0, 1.48, 0), mats.blue, 32, 20)
	for x in [-0.28, 0.25]: _sphere(world_root, Vector3(0.23, 0.09, 0.10), pos + Vector3(x, 1.5, -0.64), mats.green, 18, 10)

func _build_garden() -> void:
	_add_environment(Color("#72b9cd"), Color("#fff1c8"), 0.88)

	# Structural grass underlay + many exact-image surface tiles. The individual
	# tiles use rotated UVs, not a generated/modified texture.
	_box(
		world_root,
		Vector3(52, 0.35, 38),
		Vector3(0, -0.22, 0),
		mats.garden_grass_underlay
	)
	_build_garden_grass_mosaic()

	_build_garden_cafe_zone()
	_build_garden_tree_study_zone()
	_build_garden_small_oak_trees()
	_build_garden_fountain(Vector3(0.0, 0.0, -0.6))
	_build_garden_market_stall()
	_build_garden_pool_zone()
	_build_garden_campfire_zone()
	_build_garden_path_network()
	_build_garden_hedges_and_weeds()
	_build_garden_rocks_and_grass()

	for data in [
		[Vector3(-23.0, 0.0, -5.0), "potted_spring_flowers", 0.10],
		[Vector3(-7.5, 0.0, -15.2), "potted_autumn_flowers", -0.12],
		[Vector3(22.0, 0.0, -5.5), "potted_summer_flowers", 0.18],
		[Vector3(-22.0, 0.0, 15.2), "potted_winter_flowers", -0.10],
		[Vector3(22.0, 0.0, 15.0), "potted_spring_flowers", 0.12],
	]:
		_place_local_prop(str(data[1]), "", data[0], Vector3.ONE * 0.92, float(data[2]))

	for data in [
		[Vector3(-15.7, 0.05, -9.1), 1, "Lumi", "20m"],
		[Vector3(12.4, 0.05, -8.4), 2, "Ben", "37m"],
		[Vector3(17.3, 0.05, 10.1), 0, "Sora", "48m"],
		[Vector3(-13.7, 0.05, -9.0), 1, "Poppy", "31m"],
	]:
		_create_npc(data[0], 0.0, int(data[1]), str(data[2]), str(data[3]), true)

	_create_garden_barista()

	_focus_camera(Vector3(24.0, 13.8, 20.0), Vector3(0, 1.1, 0), "Garden wide")
	_focus_camera(Vector3(-7.8, 5.0, -4.0), Vector3(-17.1, 1.5, -13.2), "Open-air café")
	_focus_camera(Vector3(8.5, 5.2, -3.6), Vector3(0.0, 1.2, -0.6), "Central fountain")
	_focus_camera(Vector3(23.5, 7.2, -2.8), Vector3(15.4, 2.4, -10.5), "Tree rug study")
	_focus_camera(Vector3(-4.5, 5.8, 17.2), Vector3(-15.2, 0.8, 10.7), "Poolside")
	_focus_camera(Vector3(22.5, 4.8, 16.5), Vector3(16.2, 0.9, 10.7), "Campfire circle")
	_focus_camera(Vector3(10.8, 5.1, 14.8), GARDEN_MARKET_STALL_POSITION + Vector3(0, 1.5, 0), "Market stall")
	_add_world_boundaries(current_room_config.bounds)


func _build_garden_grass_mosaic() -> void:
	# 8 x 6 = 48 independent uses of the exact same garden_grass.jpeg.
	# Each tile chooses one of four UV orientations. Geometry itself never
	# overlaps, so there is no z-fighting between grass tiles.
	var columns := 8
	var rows := 6
	var room_width := 52.0
	var room_depth := 38.0
	var tile_width: float = room_width / float(columns)
	var tile_depth: float = room_depth / float(rows)

	for row in range(rows):
		for column in range(columns):
			# Deterministic non-repeating-looking quarter-turn sequence.
			var quarter_turn: int = (
				column * 3
				+ row * 5
				+ column * row
				+ (row % 2) * 2
			) % 4

			var tile_position := Vector3(
				-room_width * 0.5 + tile_width * (float(column) + 0.5),
				0.004,
				-room_depth * 0.5 + tile_depth * (float(row) + 0.5)
			)

			_build_garden_grass_tile(
				tile_position,
				Vector2(tile_width, tile_depth),
				quarter_turn
			)


func _build_garden_grass_tile(
	position_value: Vector3,
	size_value: Vector2,
	quarter_turn: int
) -> void:
	# Build UVs explicitly so the source image can rotate without rotating the
	# rectangular ground geometry. That keeps all 48 tiles perfectly aligned.
	var half_x := size_value.x * 0.5
	var half_z := size_value.y * 0.5

	var vertices := [
		Vector3(-half_x, 0.0, -half_z),
		Vector3(half_x, 0.0, -half_z),
		Vector3(half_x, 0.0, half_z),
		Vector3(-half_x, 0.0, half_z),
	]

	var uv_sets := [
		[
			Vector2(0.0, 0.0),
			Vector2(1.0, 0.0),
			Vector2(1.0, 1.0),
			Vector2(0.0, 1.0),
		],
		[
			Vector2(1.0, 0.0),
			Vector2(1.0, 1.0),
			Vector2(0.0, 1.0),
			Vector2(0.0, 0.0),
		],
		[
			Vector2(1.0, 1.0),
			Vector2(0.0, 1.0),
			Vector2(0.0, 0.0),
			Vector2(1.0, 0.0),
		],
		[
			Vector2(0.0, 1.0),
			Vector2(0.0, 0.0),
			Vector2(1.0, 0.0),
			Vector2(1.0, 1.0),
		],
	]
	var uvs: Array = uv_sets[quarter_turn % 4]

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(mats.garden_grass)

	for index in [0, 1, 2, 0, 2, 3]:
		surface.set_normal(Vector3.UP)
		surface.set_uv(uvs[index])
		surface.add_vertex(vertices[index])

	var tile := MeshInstance3D.new()
	tile.name = "GardenGrassTile"
	tile.mesh = surface.commit()
	tile.position = position_value
	tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world_root.add_child(tile)


func _build_garden_cafe_zone() -> void:
	var rug_path := GENERATED_ASSET_DIR + "garden_cafe_rug.glb"
	if ResourceLoader.exists(rug_path):
		_import_prop(rug_path, Vector3(-16.7, 0.0, -11.5), Vector3.ONE)
	else:
		_box(world_root, Vector3(14.4, 0.055, 8.5), Vector3(-16.7, 0.03, -11.5), mats.cream)
		_box(world_root, Vector3(13.7, 0.022, 7.82), Vector3(-16.7, 0.070, -11.5), mats.cocoa)

	var back_wall_path := GENERATED_ASSET_DIR + "garden_cafe_back_wall.glb"
	var cafe_back_z := -15.72
	if ResourceLoader.exists(back_wall_path):
		_import_prop(back_wall_path, Vector3(-17.4, 0.0, cafe_back_z), Vector3.ONE)
	else:
		_box(world_root, Vector3(12.4, 4.5, 0.30), Vector3(-17.4, 2.25, cafe_back_z), mats.cream)
	_add_blocker(Vector3(-17.4, 2.25, cafe_back_z), Vector3(12.6, 4.5, 0.48), 0.0)

	var counter_path := GENERATED_ASSET_DIR + "garden_cafe_counter.glb"
	var counter_position := Vector3(-17.4, 0.0, -14.3)
	var counter_scale := Vector3(0.88, 0.78, 0.74)
	if ResourceLoader.exists(counter_path):
		_import_prop(counter_path, counter_position, counter_scale)
	else:
		_box(world_root, Vector3(6.50, 0.92, 1.18), Vector3(-17.4, 0.46, -14.55), mats.cocoa)
		_box(world_root, Vector3(6.82, 0.16, 1.38), Vector3(-17.4, 0.98, -14.55), mats.honey)
	_add_blocker(Vector3(-17.4, 0.55, -14.55), Vector3(6.90, 1.10, 1.38), 0.0)

	# The bookcases form the LEFT café wall. The rear edge of the first case
	# meets the counter's back wall, and the two cases meet edge-to-edge. Their
	# authored fronts face inward at PI/2, while _import_prop grounds them at y=0.
	_build_bookshelf(Vector3(-23.25, 1.78, -14.04), PI / 2.0, 3.35, 3.55, 0.54, 612)
	_build_bookshelf(Vector3(-23.25, 1.78, -10.67), PI / 2.0, 3.35, 3.55, 0.54, 663)

	for table_data in [
		[Vector3(-18.7, 0.0, -10.7), 0.10],
		[Vector3(-13.9, 0.0, -9.9), -0.12],
	]:
		_build_garden_open_cafe_table(table_data[0], float(table_data[1]))

	# Prefer the locally converted archive café props when they exist. They are
	# owner-local and gitignored, so public builds still fall back to StudyTown's
	# generated/placeholder props.
	var archive_cafe_props := [
		["garden_cafe_coffee_mill.glb", Vector3(-19.25, 1.04, -14.50), Vector3.ONE, 0.0],
		["garden_cafe_coffee_cup.glb", Vector3(-17.55, 1.04, -14.45), Vector3.ONE, 0.10],
		["garden_cafe_milk_pitcher.glb", Vector3(-16.20, 1.04, -14.47), Vector3.ONE, -0.12],
		["garden_cafe_siphon.glb", Vector3(-15.05, 1.04, -14.50), Vector3.ONE, 0.06],
		["garden_cafe_saucer.glb", Vector3(-20.15, 2.20, -15.33), Vector3.ONE, 0.0],
		["garden_cafe_coffee_cup.glb", Vector3(-19.62, 2.20, -15.33), Vector3.ONE, 0.18],
		["garden_cafe_water_cup.glb", Vector3(-18.95, 2.20, -15.33), Vector3.ONE, -0.08],
		["garden_cafe_saucer.glb", Vector3(-16.10, 3.10, -15.33), Vector3.ONE, 0.0],
		["garden_cafe_coffee_cup.glb", Vector3(-15.55, 3.10, -15.33), Vector3.ONE, -0.12],
	]
	var archive_prop_found := false
	for data in archive_cafe_props:
		var archive_path: String = GENERATED_ASSET_DIR + str(data[0])
		if ResourceLoader.exists(archive_path):
			_import_prop(archive_path, data[1], data[2], float(data[3]))
			archive_prop_found = true

	if not archive_prop_found:
		_place_local_prop("coffee_grinder", "", Vector3(-19.25, 1.04, -14.50), Vector3.ONE * 0.88)
		_place_local_prop("cup_of_coffee", "", Vector3(-17.35, 1.04, -14.45), Vector3.ONE)
		_place_local_prop("can_of_juice", "", Vector3(-15.55, 1.04, -14.47), Vector3.ONE)

func _build_garden_open_cafe_table(pos: Vector3, yaw: float) -> void:
	var table_path := GENERATED_ASSET_DIR + "garden_cafe_table.glb"
	if ResourceLoader.exists(table_path):
		_import_prop(table_path, pos, Vector3.ONE, yaw)
	else:
		_cylinder(world_root, 1.05, 0.18, pos + Vector3(0, 1.00, 0), mats.wood, 36)
		_capsule_mesh(world_root, 0.15, 0.94, pos + Vector3(0, 0.49, 0), mats.cocoa)
		_cylinder(world_root, 0.52, 0.12, pos + Vector3(0, 0.06, 0), mats.cocoa, 28)
	_add_blocker(pos + Vector3(0, 0.56, 0), Vector3(1.55, 1.12, 1.55), yaw)

	var forward: Vector3 = Basis(Vector3.UP, yaw) * Vector3.FORWARD
	var chair_a: Vector3 = pos + forward * 1.58
	var chair_b: Vector3 = pos - forward * 1.58
	# The generated café chair's visual forward axis is opposite the generic
	# furniture convention. Flip both chairs so their seats/backs face inward
	# toward the table instead of away from it.
	_build_chair(chair_a, yaw, "Laptop", "cafe_chair")
	_build_chair(chair_b, yaw + PI, "Book", "cafe_chair")
	var archive_cup_path := GENERATED_ASSET_DIR + "garden_cafe_coffee_cup.glb"
	var archive_saucer_path := GENERATED_ASSET_DIR + "garden_cafe_saucer.glb"
	if ResourceLoader.exists(archive_saucer_path):
		_import_prop(archive_saucer_path, pos + Vector3(0.38, 0.86, 0.18), Vector3.ONE, yaw)
	if ResourceLoader.exists(archive_cup_path):
		_import_prop(archive_cup_path, pos + Vector3(0.38, 0.90, 0.18), Vector3.ONE, yaw + 0.18)
	else:
		_place_local_prop("coffee_mug", "", pos + Vector3(0.38, 0.90, 0.18), Vector3.ONE)
	_place_local_prop("iced_tea", "", pos + Vector3(-0.38, 0.90, -0.12), Vector3.ONE)


func _build_garden_market_stall() -> void:
	# Purpose-built compact stall. The previous v20 version combined several
	# IdrMarket01 donor meshes whose original scale/proportions made the result
	# look like a giant indoor checkout desk with a distorted roof texture.
	#
	# v21 uses ONE Blender-built stall GLB with controlled dimensions. Existing
	# archive coffee props are still used on the counter as decoration.
	var stall_pos := GARDEN_MARKET_STALL_POSITION
	var stall_yaw := GARDEN_MARKET_STALL_YAW
	var stall_basis := Basis(Vector3.UP, stall_yaw)

	var stall_path := GENERATED_ASSET_DIR + "garden_market_stall.glb"
	if ResourceLoader.exists(stall_path):
		_import_prop(
			stall_path,
			stall_pos,
			Vector3.ONE * 0.70,
			stall_yaw
		)
	else:
		# Very close fallback to the generated asset's silhouette.
		_box(
			world_root,
			Vector3(4.90, 0.10, 2.65),
			stall_pos + Vector3.UP * 0.05,
			mats.honey
		)
		for local_x in [-2.20, 2.20]:
			for local_z in [-1.04, 1.04]:
				var local_post := Vector3(
					float(local_x),
					1.48,
					float(local_z)
				)
				_box(
					world_root,
					Vector3(0.16, 2.96, 0.16),
					stall_pos + stall_basis * local_post,
					mats.wood
				)

		var fallback_counter_pos := (
			stall_pos
			+ stall_basis * Vector3(0.0, 0.50, 0.77)
		)
		_box(
			world_root,
			Vector3(4.42, 1.00, 0.72),
			fallback_counter_pos,
			mats.wood
		)
		_box(
			world_root,
			Vector3(4.68, 0.13, 0.92),
			fallback_counter_pos + Vector3.UP * 0.56,
			mats.honey
		)
		_box(
			world_root,
			Vector3(5.15, 0.17, 2.90),
			stall_pos + Vector3.UP * 3.01,
			mats.cream
		)

	# Put small, correctly scaled café props on the counter. These are the
	# archive assets that already looked good elsewhere in the Garden.
	var counter_surface := (
		stall_pos
		+ stall_basis * Vector3(0.0, 1.09, 0.76)
	)

	var cup_path := (
		GENERATED_ASSET_DIR
		+ "garden_cafe_coffee_cup.glb"
	)
	if ResourceLoader.exists(cup_path):
		_import_prop(
			cup_path,
			counter_surface
				+ stall_basis * Vector3(0.75, 0.0, 0.0),
			Vector3.ONE,
			stall_yaw + 0.12
		)

	var mill_path := (
		GENERATED_ASSET_DIR
		+ "garden_cafe_coffee_mill.glb"
	)
	if ResourceLoader.exists(mill_path):
		_import_prop(
			mill_path,
			counter_surface
				+ stall_basis * Vector3(-0.70, 0.0, 0.0),
			Vector3.ONE * 0.82,
			stall_yaw
		)

	var pitcher_path := (
		GENERATED_ASSET_DIR
		+ "garden_cafe_milk_pitcher.glb"
	)
	if ResourceLoader.exists(pitcher_path):
		_import_prop(
			pitcher_path,
			counter_surface
				+ stall_basis * Vector3(0.10, 0.0, 0.0),
			Vector3.ONE * 0.90,
			stall_yaw - 0.08
		)

	# Only the serving counter needs a broad collision blocker. The four thin
	# posts remain visually present without creating an awkward invisible box.
	var counter_blocker_pos := (
		stall_pos
		+ stall_basis * Vector3(0.0, 0.54, 0.77)
	)
	_add_blocker(
		counter_blocker_pos,
		Vector3(4.55, 1.08, 0.90),
		stall_yaw
	)


func _build_garden_tree_study_zone() -> void:
	var tree_pos := Vector3(15.4, 0.0, -10.8)
	var tree_path := GENERATED_ASSET_DIR + "garden_big_tree.glb"
	if ResourceLoader.exists(tree_path):
		_import_prop(tree_path, tree_pos, Vector3.ONE * 1.12)
	elif ResourceLoader.exists("res://assets/dev_local/props/big_tree_museum.glb"):
		_import_prop("res://assets/dev_local/props/big_tree_museum.glb", tree_pos, Vector3.ONE * 1.38)
	else:
		_build_tree(tree_pos, 2.30)

	_add_blocker(tree_pos + Vector3(0, 3.1, 0), Vector3(3.0, 6.2, 3.0), 0.0)

	var rug_path := GENERATED_ASSET_DIR + "garden_tree_rug.glb"
	var rug_positions := [
		Vector3(11.6, 0.0, -8.35),
		Vector3(19.2, 0.0, -8.35),
	]
	for rug_pos in rug_positions:
		if ResourceLoader.exists(rug_path):
			_import_prop(rug_path, rug_pos, Vector3.ONE)
		else:
			_box(world_root, Vector3(4.45, 0.07, 2.85), rug_pos + Vector3.UP * 0.035, mats.cocoa)
			_box(world_root, Vector3(4.05, 0.025, 2.45), rug_pos + Vector3.UP * 0.082, mats.teal)

		var direction: Vector3 = tree_pos - rug_pos
		direction.y = 0.0
		var yaw: float = atan2(-direction.x, -direction.z)
		var sitting: Vector3 = rug_pos + Vector3.UP * 0.09
		var forward: Vector3 = Basis(Vector3.UP, yaw) * Vector3.FORWARD
		_add_study_spot(
			rug_pos - forward * 1.60,
			sitting,
			yaw,
			"Book",
			rug_pos + forward * 4.1 + Vector3(2.5, 2.5, 0.0),
			sitting + Vector3.UP * 1.10,
			"floor_cushion",
			SEAT_VISUAL_OFFSETS.floor_cushion,
			0.09
		)


func _garden_small_oak_tree_data() -> Array:
	# Two trees occupy the grass corridor between café and pool.
	# One frames the campfire area from the outer-right side.
	# These anchor positions are intentionally kept exactly as tuned.
	return [
		[Vector3(-20.35, 0.0, -0.15), 0.82, 0.34],
		[Vector3(-12.0, 0.0, 4.85), 0.76, -0.58],
		[Vector3(23.00, 0.0, 15.00), 0.80, 1.06],
	]


func _build_garden_small_oak_trees() -> void:
	var oak_path := GENERATED_ASSET_DIR + "garden_oak_tree.glb"

	for data in _garden_small_oak_tree_data():
		var tree_position: Vector3 = data[0]
		var tree_scale: float = float(data[1])
		var tree_yaw: float = float(data[2])

		if ResourceLoader.exists(oak_path):
			# garden_oak_tree.glb is converted with one trunk/root system and a
			# second foliage-only shell rotated 180 degrees inside the GLB. Do
			# not duplicate the complete tree here or the roots/trunk double up.
			_import_prop(
				oak_path,
				tree_position,
				Vector3.ONE * tree_scale,
				tree_yaw
			)
		else:
			# Public fallback remains clearly smaller than the large study tree.
			_build_tree(tree_position, 1.20 * tree_scale)

		# One trunk blocker per tree. The foliage-only rear shell has no
		# separate collision.
		_add_blocker(
			tree_position + Vector3.UP * (1.55 * tree_scale),
			Vector3(
				0.92 * tree_scale,
				3.10 * tree_scale,
				0.92 * tree_scale
			),
			tree_yaw
		)


func _build_garden_fountain(pos: Vector3) -> void:
	var fountain_path := GENERATED_ASSET_DIR + "garden_fountain.glb"
	if ResourceLoader.exists(fountain_path):
		_import_prop(fountain_path, pos, Vector3.ONE)
	else:
		_cylinder(world_root, 3.65, 0.20, pos + Vector3(0, 0.10, 0), mats.stone, 48)
		_cylinder(world_root, 3.45, 0.42, pos + Vector3(0, 0.30, 0), mats.stone, 48)
		_cylinder(world_root, 0.48, 1.20, pos + Vector3(0, 1.05, 0), mats.stone, 30)
		_cylinder(world_root, 1.42, 0.20, pos + Vector3(0, 1.52, 0), mats.stone, 42)

	# Animated water in both the large lower basin and the smaller upper bowl.
	_cylinder(world_root, 2.96, 0.055, pos + Vector3(0, 0.56, 0), mats.water, 52)
	_build_garden_upper_basin_water(pos)
	_add_blocker(pos + Vector3(0, 0.70, 0), Vector3(6.45, 1.40, 6.45), 0.0)
	_build_garden_water_jet(pos)
	_build_garden_fountain_planting(pos)


func _build_garden_fountain_planting(pos: Vector3) -> void:
	var shrub_path := GENERATED_ASSET_DIR + "garden_shrub.glb"
	var flower_path := GENERATED_ASSET_DIR + "garden_flower_patch.glb"
	for index in 8:
		var angle: float = float(index) * TAU / 8.0 + PI / 8.0
		var radius: float = 4.35
		var plant_pos := pos + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var path: String = shrub_path if index % 2 == 0 else flower_path
		if ResourceLoader.exists(path):
			_import_prop(path, plant_pos, Vector3.ONE * (0.92 + (index % 3) * 0.08), angle)
		else:
			_sphere(world_root, Vector3(0.65, 0.55, 0.60), plant_pos + Vector3.UP * 0.55, mats.leaf, 18, 10)


func _build_garden_upper_basin_water(fountain_pos: Vector3) -> void:
	# The imported upper bowl is annular: water surrounds the central stem/nozzle
	# rather than covering it. Build a thin animated water ring just below the
	# stone lip so the inward side jets have a believable place to land.
	var inner_radius := 0.30
	var outer_radius := 0.94
	var water_y := 1.53
	var segments := 48

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(mats.water)

	for index in range(segments):
		var next_index: int = (index + 1) % segments
		var a0: float = float(index) * TAU / float(segments)
		var a1: float = float(next_index) * TAU / float(segments)

		var inner0 := fountain_pos + Vector3(
			cos(a0) * inner_radius,
			water_y,
			sin(a0) * inner_radius
		)
		var inner1 := fountain_pos + Vector3(
			cos(a1) * inner_radius,
			water_y,
			sin(a1) * inner_radius
		)
		var outer0 := fountain_pos + Vector3(
			cos(a0) * outer_radius,
			water_y,
			sin(a0) * outer_radius
		)
		var outer1 := fountain_pos + Vector3(
			cos(a1) * outer_radius,
			water_y,
			sin(a1) * outer_radius
		)

		var u0: float = float(index) / float(segments)
		var u1: float = float(index + 1) / float(segments)

		surface.set_normal(Vector3.UP)
		surface.set_uv(Vector2(u0, 0.0))
		surface.add_vertex(inner0)
		surface.set_normal(Vector3.UP)
		surface.set_uv(Vector2(u0, 1.0))
		surface.add_vertex(outer0)
		surface.set_normal(Vector3.UP)
		surface.set_uv(Vector2(u1, 1.0))
		surface.add_vertex(outer1)

		surface.set_normal(Vector3.UP)
		surface.set_uv(Vector2(u0, 0.0))
		surface.add_vertex(inner0)
		surface.set_normal(Vector3.UP)
		surface.set_uv(Vector2(u1, 1.0))
		surface.add_vertex(outer1)
		surface.set_normal(Vector3.UP)
		surface.set_uv(Vector2(u1, 0.0))
		surface.add_vertex(inner1)

	var upper_water := MeshInstance3D.new()
	upper_water.name = "FountainUpperBasinWater"
	upper_water.mesh = surface.commit()
	upper_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world_root.add_child(upper_water)


func _build_garden_water_jet(fountain_pos: Vector3) -> void:
	# The source fountain's visible lower nozzles sit on a ring at roughly
	# radius 2.08m, with a 22.5-degree phase offset. Starting the water at those
	# coordinates makes every stream visibly emerge from an actual nozzle.
	# A tiny outward correction puts the stream origin on the visible tip of
	# each orange nozzle instead of slightly behind it.
	var nozzle_radius := 2.00
	var nozzle_tip_y := 0.89
	var nozzle_phase := deg_to_rad(23.0)

	# Eight nozzle jets. They start narrow at the nozzle and become visibly
	# thicker as gravity pulls them toward the landing point, per the requested
	# fountain reference.
	var side_jet_count := 8
	for jet_index in range(side_jet_count):
		var angle: float = (
			nozzle_phase
			+ float(jet_index) * TAU / float(side_jet_count)
		)

		var start := fountain_pos + Vector3(
			cos(angle) * nozzle_radius,
			nozzle_tip_y,
			sin(angle) * nozzle_radius
		)
		# Land in the animated upper basin rather than terminating against the
		# pedestal. The endpoint sits a few centimetres above the water surface.
		var finish := fountain_pos + Vector3(
			cos(angle) * 0.78,
			1.57,
			sin(angle) * 0.78
		)

		var height_variation: float = sin(float(jet_index) * 1.73) * 0.035
		_build_water_arc_tube(
			start,
			finish,
			0.58 + height_variation,
			0.038,
			14,
			9,
			float(jet_index) * 0.61,
			1.95
		)

	# The fountain mesh tops out at about y=1.77. The old plume began at 2.72,
	# leaving almost a metre of empty air below it. Start directly on the top
	# nozzle so the jet is physically connected to the fountain.
	var top_nozzle_y := 1.77
	var plume_height := 1.34
	var plume_start := fountain_pos + Vector3(0.0, top_nozzle_y, 0.0)

	var central_stream := _build_vertical_water_plume(
		plume_start,
		plume_height,
		0.055,
		16,
		9,
		0.0
	)
	central_stream.name = "FountainConnectedCentralPlume"

	# The central jet shoots upward, then spreads into ONE continuous 360-degree
	# falling umbrella. This is deliberately a sheet rather than a set of
	# individual crown streams, giving the inverted-cone/enveloping shape from
	# the reference.
	var umbrella_apex_y: float = top_nozzle_y + plume_height - 0.03
	_build_fountain_umbrella_sheet(
		fountain_pos,
		umbrella_apex_y,
		0.82,
		0.88,
		56,
		12
	)


func _build_fountain_umbrella_sheet(
	origin: Vector3,
	apex_y: float,
	outer_radius: float,
	drop_height: float,
	angular_segments: int,
	flow_segments: int
) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(mats.fountain_sheet)

	for flow_index in range(flow_segments):
		var t0: float = float(flow_index) / float(flow_segments)
		var t1: float = float(flow_index + 1) / float(flow_segments)

		# Starts almost at the plume radius, expands quickly, then falls under
		# gravity. Keeping a non-zero inner radius prevents a pinched apex.
		var spread0: float = pow(sin(t0 * PI * 0.5), 0.82)
		var spread1: float = pow(sin(t1 * PI * 0.5), 0.82)
		var radius0: float = lerpf(0.050, outer_radius, spread0)
		var radius1: float = lerpf(0.050, outer_radius, spread1)

		var y0: float = apex_y - drop_height * pow(t0, 1.42)
		var y1: float = apex_y - drop_height * pow(t1, 1.42)

		for angular_index in range(angular_segments):
			var next_index: int = (angular_index + 1) % angular_segments
			var a0: float = float(angular_index) * TAU / float(angular_segments)
			var a1: float = float(next_index) * TAU / float(angular_segments)

			# Slightly scallop the falling edge. This keeps the silhouette organic
			# without breaking the sheet into individual streams.
			var edge_amount0: float = pow(t0, 3.0)
			var edge_amount1: float = pow(t1, 3.0)
			var ripple0: float = sin(a0 * 7.0 + t0 * 5.0) * 0.025 * edge_amount0
			var ripple1: float = sin(a1 * 7.0 + t0 * 5.0) * 0.025 * edge_amount0
			var ripple2: float = sin(a0 * 7.0 + t1 * 5.0) * 0.025 * edge_amount1
			var ripple3: float = sin(a1 * 7.0 + t1 * 5.0) * 0.025 * edge_amount1

			var p00 := origin + Vector3(
				cos(a0) * radius0,
				y0 + ripple0,
				sin(a0) * radius0
			)
			var p01 := origin + Vector3(
				cos(a1) * radius0,
				y0 + ripple1,
				sin(a1) * radius0
			)
			var p10 := origin + Vector3(
				cos(a0) * radius1,
				y1 + ripple2,
				sin(a0) * radius1
			)
			var p11 := origin + Vector3(
				cos(a1) * radius1,
				y1 + ripple3,
				sin(a1) * radius1
			)

			var u0: float = float(angular_index) / float(angular_segments)
			var u1: float = float(angular_index + 1) / float(angular_segments)

			surface.set_uv(Vector2(u0, t0))
			surface.add_vertex(p00)
			surface.set_uv(Vector2(u0, t1))
			surface.add_vertex(p10)
			surface.set_uv(Vector2(u1, t1))
			surface.add_vertex(p11)

			surface.set_uv(Vector2(u0, t0))
			surface.add_vertex(p00)
			surface.set_uv(Vector2(u1, t1))
			surface.add_vertex(p11)
			surface.set_uv(Vector2(u1, t0))
			surface.add_vertex(p01)

	var sheet := MeshInstance3D.new()
	sheet.name = "FountainUmbrellaWaterSheet"
	sheet.mesh = surface.commit()
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world_root.add_child(sheet)
	return sheet


func _build_vertical_water_plume(
	start: Vector3,
	height: float,
	radius: float,
	path_segments: int,
	radial_segments: int,
	phase_offset: float
) -> MeshInstance3D:
	var points: Array[Vector3] = []
	for index in range(path_segments + 1):
		var t: float = float(index) / float(path_segments)

		# Slightly lively but still forceful/vertical.
		var sway_strength: float = sin(t * PI) * 0.012
		var point := start + Vector3(
			sin(t * 10.5 + phase_offset) * sway_strength,
			height * t,
			cos(t * 8.7 + phase_offset) * sway_strength
		)
		points.append(point)

	return _build_water_tube_from_points(
		points,
		radius,
		radial_segments,
		phase_offset,
		0.72,
		1.04
	)


func _build_water_arc_tube(
	start: Vector3,
	finish: Vector3,
	arc_height: float,
	radius: float,
	path_segments: int,
	radial_segments: int,
	phase_offset: float = 0.0,
	end_taper: float = 1.95
) -> MeshInstance3D:
	var points: Array[Vector3] = []

	for index in range(path_segments + 1):
		var t: float = float(index) / float(path_segments)
		var point: Vector3 = start.lerp(finish, t)
		point.y += sin(t * PI) * arc_height

		var wobble: float = sin(t * PI) * 0.007
		point.x += sin(t * 11.0 + phase_offset) * wobble
		point.z += cos(t * 9.0 + phase_offset) * wobble
		points.append(point)

	return _build_water_tube_from_points(
		points,
		radius,
		radial_segments,
		phase_offset,
		0.68,
		end_taper
	)


func _build_water_tube_from_points(
	points: Array[Vector3],
	radius: float,
	radial_segments: int,
	phase_offset: float,
	start_taper: float,
	end_taper: float
) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(mats.fountain_stream)

	var path_segments: int = points.size() - 1

	for path_index in range(path_segments):
		var point_a: Vector3 = points[path_index]
		var point_b: Vector3 = points[path_index + 1]

		var tangent_a: Vector3
		var tangent_b: Vector3

		if path_index == 0:
			tangent_a = (points[1] - points[0]).normalized()
		else:
			tangent_a = (
				points[path_index + 1] - points[path_index - 1]
			).normalized()

		if path_index + 1 == path_segments:
			tangent_b = (
				points[path_segments] - points[path_segments - 1]
			).normalized()
		else:
			tangent_b = (
				points[path_index + 2] - points[path_index]
			).normalized()

		var side_a: Vector3 = tangent_a.cross(Vector3.UP)
		if side_a.length_squared() < 0.0001:
			side_a = Vector3.RIGHT
		else:
			side_a = side_a.normalized()
		var up_a: Vector3 = side_a.cross(tangent_a).normalized()

		var side_b: Vector3 = tangent_b.cross(Vector3.UP)
		if side_b.length_squared() < 0.0001:
			side_b = Vector3.RIGHT
		else:
			side_b = side_b.normalized()
		var up_b: Vector3 = side_b.cross(tangent_b).normalized()

		var v0: float = float(path_index) / float(path_segments)
		var v1: float = float(path_index + 1) / float(path_segments)

		var taper_a: float = lerpf(start_taper, end_taper, v0)
		var taper_b: float = lerpf(start_taper, end_taper, v1)

		var pulse_a: float = 0.96 + sin(v0 * TAU * 2.4 + phase_offset) * 0.035
		var pulse_b: float = 0.96 + sin(v1 * TAU * 2.4 + phase_offset) * 0.035

		var radius_a: float = radius * taper_a * pulse_a
		var radius_b: float = radius * taper_b * pulse_b

		for radial_index in range(radial_segments):
			var radial_next: int = (radial_index + 1) % radial_segments
			var a0: float = float(radial_index) * TAU / float(radial_segments)
			var a1: float = float(radial_next) * TAU / float(radial_segments)

			var normal_a0: Vector3 = (
				side_a * cos(a0) + up_a * sin(a0)
			).normalized()
			var normal_a1: Vector3 = (
				side_a * cos(a1) + up_a * sin(a1)
			).normalized()
			var normal_b0: Vector3 = (
				side_b * cos(a0) + up_b * sin(a0)
			).normalized()
			var normal_b1: Vector3 = (
				side_b * cos(a1) + up_b * sin(a1)
			).normalized()

			var vertex_a0: Vector3 = point_a + normal_a0 * radius_a
			var vertex_a1: Vector3 = point_a + normal_a1 * radius_a
			var vertex_b0: Vector3 = point_b + normal_b0 * radius_b
			var vertex_b1: Vector3 = point_b + normal_b1 * radius_b

			var u0: float = float(radial_index) / float(radial_segments)
			var u1: float = float(radial_index + 1) / float(radial_segments)

			surface.set_normal(normal_a0)
			surface.set_uv(Vector2(u0, v0))
			surface.add_vertex(vertex_a0)

			surface.set_normal(normal_b0)
			surface.set_uv(Vector2(u0, v1))
			surface.add_vertex(vertex_b0)

			surface.set_normal(normal_b1)
			surface.set_uv(Vector2(u1, v1))
			surface.add_vertex(vertex_b1)

			surface.set_normal(normal_a0)
			surface.set_uv(Vector2(u0, v0))
			surface.add_vertex(vertex_a0)

			surface.set_normal(normal_b1)
			surface.set_uv(Vector2(u1, v1))
			surface.add_vertex(vertex_b1)

			surface.set_normal(normal_a1)
			surface.set_uv(Vector2(u1, v0))
			surface.add_vertex(vertex_a1)

	var stream := MeshInstance3D.new()
	stream.name = "FountainWaterStream"
	stream.mesh = surface.commit()
	stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world_root.add_child(stream)
	return stream


func _build_garden_pool_zone() -> void:
	var pool_pos := Vector3(-15.2, 0.0, 10.7)
	var pool_path := GENERATED_ASSET_DIR + "garden_pool.glb"
	if ResourceLoader.exists(pool_path):
		_import_prop(pool_path, pool_pos, Vector3.ONE)
	else:
		# Pale tile courtyard border around a rectangular water opening.
		_box(world_root, Vector3(10.4, 0.18, 0.85), pool_pos + Vector3(0, 0.09, -2.88), mats.cream)
		_box(world_root, Vector3(10.4, 0.18, 0.85), pool_pos + Vector3(0, 0.09, 2.88), mats.cream)
		_box(world_root, Vector3(0.85, 0.18, 4.9), pool_pos + Vector3(-4.78, 0.09, 0), mats.cream)
		_box(world_root, Vector3(0.85, 0.18, 4.9), pool_pos + Vector3(4.78, 0.09, 0), mats.cream)

	_box(world_root, Vector3(8.65, 0.055, 4.82), pool_pos + Vector3(0, 0.26, 0), mats.water)
	_add_blocker(pool_pos + Vector3(0, 0.58, 0), Vector3(8.75, 1.16, 4.92), 0.0)

	# Two loungers sit just beyond the upper coping, matching the reference's
	# small resort-pool feeling without crowding the circulation path.
	var tanning_path := GENERATED_ASSET_DIR + "garden_tanning_bed.glb"
	for data in [
		[Vector3(-17.0, 0.0, 14.55), 0.06],
		[Vector3(-13.7, 0.0, 14.55), -0.04],
	]:
		var bed_position: Vector3 = data[0]
		var bed_yaw: float = float(data[1])
		if ResourceLoader.exists(tanning_path):
			_import_prop(tanning_path, bed_position, Vector3.ONE, bed_yaw)
		else:
			_box(
				world_root,
				Vector3(2.45, 0.16, 0.92),
				bed_position + Vector3(0, 0.34, 0),
				mats.wood
			).rotation.y = bed_yaw

		_register_garden_resting_spot(bed_position, bed_yaw)


func _register_garden_resting_spot(
	bed_position: Vector3,
	bed_yaw: float
) -> void:
	# The actual bed/player placement is deliberately easy to tune later.
	# The Resting skeletal animation itself handles lying flat and facing up.
	var bed_basis := Basis(Vector3.UP, bed_yaw)
	var standing := (
		bed_position
		+ bed_basis * Vector3(0.0, 0.0, TANNING_BED_STAND_DISTANCE)
	)
	var lying := (
		bed_position
		+ Vector3.UP * TANNING_BED_LYING_HEIGHT
	)
	var lying_yaw := bed_yaw + TANNING_BED_LYING_YAW_OFFSET

	_add_study_spot(
		standing,
		lying,
		lying_yaw,
		"Resting",
		lying + Vector3(3.8, 3.0, 3.4),
		lying + Vector3.UP * 0.55,
		"tanning_bed",
		SEAT_VISUAL_OFFSETS.tanning_bed,
		TANNING_BED_LYING_HEIGHT
	)


func _build_garden_campfire_zone() -> void:
	var fire_pos := Vector3(16.2, 0.0, 10.7)
	var campfire_path := GENERATED_ASSET_DIR + "garden_campfire.glb"
	if ResourceLoader.exists(campfire_path):
		_import_prop(campfire_path, fire_pos, Vector3.ONE)
	else:
		for index in 10:
			var angle: float = float(index) * TAU / 10.0
			_sphere(world_root, Vector3(0.38, 0.22, 0.32), fire_pos + Vector3(cos(angle) * 1.10, 0.20, sin(angle) * 1.10), mats.stone, 14, 8)
		for log_angle in [-0.55, 0.55]:
			var log := _capsule_mesh(world_root, 0.16, 1.65, fire_pos + Vector3(0, 0.34, 0), mats.wood)
			log.rotation = Vector3(0, float(log_angle), PI / 2.0)
	_add_blocker(fire_pos + Vector3(0, 0.48, 0), Vector3(2.15, 0.96, 2.15), 0.0)
	_build_garden_fire_effect(fire_pos + Vector3(0, 0.48, 0))

	var firewood_path := GENERATED_ASSET_DIR + "garden_firewood.glb"
	if ResourceLoader.exists(firewood_path):
		_import_prop(firewood_path, fire_pos + Vector3(-2.05, 0.0, 1.55), Vector3.ONE * 0.82, -0.35)

	var log_path := GENERATED_ASSET_DIR + "garden_log_seat.glb"
	var log_positions := [
		Vector3(12.9, 0.0, 10.7),
		Vector3(19.5, 0.0, 10.7),
		Vector3(16.2, 0.0, 14.0),
	]
	for log_pos in log_positions:
		var direction: Vector3 = fire_pos - log_pos
		direction.y = 0.0
		var face_yaw: float = atan2(-direction.x, -direction.z)
		var log_yaw: float = face_yaw + PI / 2.0
		if ResourceLoader.exists(log_path):
			_import_prop(log_path, log_pos, Vector3.ONE, log_yaw)
		else:
			var log := _capsule_mesh(world_root, 0.34, 2.15, log_pos + Vector3.UP * 0.38, mats.wood)
			log.rotation = Vector3(0, log_yaw, PI / 2.0)
		_register_garden_log_seat(log_pos, face_yaw)


func _register_garden_log_seat(log_pos: Vector3, face_yaw: float) -> void:
	var forward: Vector3 = Basis(Vector3.UP, face_yaw) * Vector3.FORWARD
	var sitting: Vector3 = log_pos + Vector3.UP * 0.52
	var standing: Vector3 = log_pos - forward * 1.55
	_add_study_spot(
		standing,
		sitting,
		face_yaw,
		"Book",
		sitting + forward * 4.0 + Vector3(2.5, 2.2, 0),
		sitting + Vector3.UP * 1.10,
		"garden_log",
		Vector3(0.0, 0.02, 0.03),
		0.52
	)


func _build_garden_fire_effect(origin: Vector3) -> void:
	# Pointed flame tongues replace the old stack of orange/yellow spheres.
	var flame_data := [
		[Vector3(-0.26, 0.34, 0.04), 0.20, 0.88, mats.flame_outer, -0.16],
		[Vector3(0.25, 0.30, -0.08), 0.18, 0.78, mats.flame_outer, 0.18],
		[Vector3(-0.05, 0.43, -0.18), 0.22, 1.08, mats.flame_outer, 0.05],
		[Vector3(0.08, 0.38, 0.18), 0.17, 0.82, mats.flame_inner, -0.08],
		[Vector3(-0.12, 0.34, 0.12), 0.15, 0.72, mats.flame_inner, 0.12],
	]
	for index in range(flame_data.size()):
		var data: Array = flame_data[index]
		var flame := _cone(
			world_root,
			float(data[1]),
			float(data[2]),
			origin + data[0],
			data[3],
			14
		)
		flame.rotation.z = float(data[4])
		flame.set_meta("fire_origin", flame.position)
		flame.set_meta("fire_phase", float(index) * 1.11)
		flame.set_meta("fire_base_scale", flame.scale)
		garden_fire_nodes.append(flame)

	var light := OmniLight3D.new()
	world_root.add_child(light)
	light.position = origin + Vector3.UP * 0.85
	light.light_color = Color("#ff9b4f")
	light.light_energy = 3.6
	light.omni_range = 5.4


func _garden_path_routes() -> Array:
	# Single source of truth for the paved Garden network. Weed placement uses
	# these exact same centre lines, so changing a road later automatically
	# changes the no-weed zones too.
	return [
		[
			Vector3(0.0, 0.0, 17.2),
			Vector3(-0.5, 0.0, 12.2),
			Vector3(-2.9, 0.0, 7.0),
			Vector3(-4.5, 0.0, 3.1),
		],
		[
			Vector3(-4.5, 0.0, 3.1),
			Vector3(-8.6, 0.0, -0.8),
			Vector3(-12.0, 0.0, -5.3),
			Vector3(-15.6, 0.0, -8.3),
		],
		[
			Vector3(4.6, 0.0, 3.0),
			Vector3(7.5, 0.0, -2.4),
			Vector3(10.9, 0.0, -6.0),
			Vector3(14.0, 0.0, -8.1),
		],
		[
			Vector3(-4.2, 0.0, 4.0),
			Vector3(-8.4, 0.0, 6.7),
			Vector3(-11.7, 0.0, 8.4),
			Vector3(-13.4, 0.0, 9.5),
		],
		[
			Vector3(-4.5, 0.0, 3.1),
			Vector3(0.0, 0.0, 4.5),
			Vector3(4.6, 0.0, 3.0),
		],
		[
			Vector3(4.6, 0.0, 3.0),
			Vector3(8.2, 0.0, 5.8),
			Vector3(11.8, 0.0, 8.4),
			Vector3(13.65, 0.0, 10.35),
		],
	]


func _build_garden_path_network() -> void:
	# One CSG union for the entire paved network.
	var path_root := CSGCombiner3D.new()
	path_root.name = "GardenContinuousStonePaths"
	path_root.use_collision = false
	world_root.add_child(path_root)

	for route in _garden_path_routes():
		_add_garden_csg_path(path_root, route)


func _add_garden_csg_path(path_root: CSGCombiner3D, points: Array) -> void:
	var path_width := 2.48
	var path_height := 0.055

	for segment_index in range(points.size() - 1):
		var start: Vector3 = points[segment_index]
		var finish: Vector3 = points[segment_index + 1]
		var direction: Vector3 = finish - start
		direction.y = 0.0
		var distance: float = direction.length()
		if distance <= 0.001:
			continue

		var segment := CSGBox3D.new()
		segment.size = Vector3(path_width, path_height, distance + 0.18)
		segment.position = (start + finish) * 0.5 + Vector3.UP * (path_height * 0.5 + 0.008)
		segment.rotation.y = atan2(direction.x, direction.z)
		segment.material = mats.garden_path
		segment.operation = CSGShape3D.OPERATION_UNION
		segment.use_collision = false
		path_root.add_child(segment)

	# Round union pads make bends and junctions read as one laid stone path.
	for point in points:
		var joint := CSGCylinder3D.new()
		joint.radius = path_width * 0.50
		joint.height = path_height
		joint.sides = 20
		joint.position = point + Vector3.UP * (path_height * 0.5 + 0.008)
		joint.material = mats.garden_path
		joint.operation = CSGShape3D.OPERATION_UNION
		joint.use_collision = false
		path_root.add_child(joint)



func _build_garden_hedges_and_weeds() -> void:
	var hedge_path := GENERATED_ASSET_DIR + "garden_hedge.glb"
	if ResourceLoader.exists(hedge_path):
		var hedge_data := [
			[Vector3(6.5, 0.0, -16.6), 0.0, 1.0],
			[Vector3(9.5, 0.0, -16.6), 0.0, 1.0],
			[Vector3(12.5, 0.0, -16.6), 0.0, 1.0],
			[Vector3(18.5, 0.0, -16.6), 0.0, 1.0],
			[Vector3(21.5, 0.0, -16.6), 0.0, 1.0],
			[Vector3(24.0, 0.0, -8.0), PI / 2.0, 1.0],
			[Vector3(24.0, 0.0, -5.0), PI / 2.0, 1.0],
			[Vector3(24.0, 0.0, 2.5), PI / 2.0, 1.0],
			[Vector3(24.0, 0.0, 5.5), PI / 2.0, 1.0],
			[Vector3(-24.0, 0.0, 5.0), PI / 2.0, 1.0],
			[Vector3(-24.0, 0.0, 8.0), PI / 2.0, 1.0],
		]
		for data in hedge_data:
			_import_prop(hedge_path, data[0], Vector3.ONE * float(data[2]), float(data[1]))

	var weed_path := GENERATED_ASSET_DIR + "garden_weed_clump.glb"
	if not ResourceLoader.exists(weed_path):
		return

	# Spawn weeds procedurally on grass only. The RNG seed keeps the layout
	# stable between launches, while the rejection test guarantees weeds do not
	# appear on roads or inside the Garden's functional/building zones.
	var weeds: Array[Vector3] = _generate_safe_garden_weed_positions(35)
	for index in range(weeds.size()):
		var scale_value: float = 0.76 + fmod(float(index * 7), 6.0) * 0.055
		_import_prop(
			weed_path,
			weeds[index],
			Vector3.ONE * scale_value,
			float(index) * 0.71
		)


func _generate_safe_garden_weed_positions(count: int) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 48127

	# Keep plants comfortably inside the room boundary and away from the outer
	# hedge line.
	var min_x := -22.4
	var max_x := 22.4
	var min_z := -15.4
	var max_z := 16.0
	var minimum_weed_spacing := 0.95
	var max_attempts := count * 90
	var attempts := 0

	while result.size() < count and attempts < max_attempts:
		attempts += 1
		var candidate := Vector3(
			rng.randf_range(min_x, max_x),
			0.0,
			rng.randf_range(min_z, max_z)
		)

		if not _garden_is_safe_weed_position(candidate):
			continue

		var too_close_to_weed := false
		for existing in result:
			if Vector2(candidate.x, candidate.z).distance_to(
				Vector2(existing.x, existing.z)
			) < minimum_weed_spacing:
				too_close_to_weed = true
				break

		if too_close_to_weed:
			continue

		result.append(candidate)

	return result


func _garden_is_safe_weed_position(point: Vector3) -> bool:
	# ROAD NETWORK
	# Path width is 2.48m. Add another 0.72m so leaves do not hang over the
	# stone even when the weed model is scaled up.
	var road_clearance := 1.96
	for route in _garden_path_routes():
		for segment_index in range(route.size() - 1):
			var start: Vector3 = route[segment_index]
			var finish: Vector3 = route[segment_index + 1]
			if _garden_distance_to_segment_xz(point, start, finish) < road_clearance:
				return false

	# OPEN-AIR CAFE
	# Covers the whole café floor plus the rear wall, left bookcase wall,
	# counter, tables and chairs.
	if _garden_point_in_rect_xz(point, -24.4, -8.9, -16.5, -6.2):
		return false

	# CENTRAL FOUNTAIN + surrounding planting / circulation ring.
	if _garden_distance_xz(point, Vector3.ZERO) < 5.15:
		return false

	# POOL + loungers.
	if _garden_point_in_rect_xz(point, -21.2, -8.8, 6.8, 16.2):
		return false

	# CAMPFIRE, firewood, log seats and paved approach.
	if _garden_distance_xz(point, Vector3(16.2, 0.0, 10.7)) < 5.05:
		return false

	# BIG TREE + the two study rugs.
	if _garden_point_in_rect_xz(point, 9.2, 21.6, -14.4, -5.6):
		return false

	# Three additional oak trees.
	for tree_data in _garden_small_oak_tree_data():
		var tree_position: Vector3 = tree_data[0]
		var tree_scale: float = float(tree_data[1])
		if _garden_distance_xz(point, tree_position) < 1.75 * tree_scale:
			return false

	# Market stall in the open lawn in front of the fountain.
	if _garden_point_in_rect_xz(point, 1.45, 7.75, 7.00, 11.45):
		return false

	# Keep the immediate spawn/entrance area clear.
	if _garden_point_in_rect_xz(point, -2.4, 2.4, 14.8, 18.5):
		return false

	return true


func _garden_distance_to_segment_xz(
	point: Vector3,
	start: Vector3,
	finish: Vector3
) -> float:
	var segment := Vector2(finish.x - start.x, finish.z - start.z)
	var to_point := Vector2(point.x - start.x, point.z - start.z)
	var length_squared := segment.length_squared()

	if length_squared <= 0.000001:
		return to_point.length()

	var t: float = clampf(to_point.dot(segment) / length_squared, 0.0, 1.0)
	var closest := Vector2(start.x, start.z) + segment * t
	return Vector2(point.x, point.z).distance_to(closest)


func _garden_distance_xz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func _garden_point_in_rect_xz(
	point: Vector3,
	min_x: float,
	max_x: float,
	min_z: float,
	max_z: float
) -> bool:
	return (
		point.x >= min_x
		and point.x <= max_x
		and point.z >= min_z
		and point.z <= max_z
	)


func _build_garden_rocks_and_grass() -> void:
	var rock_data := [
		[Vector3(7.8,0,2.9),"garden_rock_a.glb",0.82,0.10],
		[Vector3(11.0,0,4.8),"garden_rock_b.glb",1.05,-0.25],
		[Vector3(14.2,0,3.8),"garden_rock_c.glb",0.88,0.35],
		[Vector3(8.8,0,11.8),"garden_rock_b.glb",0.72,-0.10],
		[Vector3(-7.8,0,13.8),"garden_rock_a.glb",0.68,0.20],
	]
	for data in rock_data:
		var path: String = GENERATED_ASSET_DIR + str(data[1])
		if ResourceLoader.exists(path):
			_import_prop(path, data[0], Vector3.ONE * float(data[2]), float(data[3]))
		else:
			_sphere(world_root, Vector3(0.95, 0.65, 0.82) * float(data[2]), data[0] + Vector3.UP * 0.52 * float(data[2]), mats.stone, 14, 9).rotation.y = float(data[3])

	var shrub_path := GENERATED_ASSET_DIR + "garden_shrub.glb"
	var flower_path := GENERATED_ASSET_DIR + "garden_flower_patch.glb"
	var planting_data := [
		[Vector3(-21.8,0,-13.9),shrub_path,1.15,0.2], [Vector3(-10.1,0,-14.6),flower_path,1.0,-0.2],
		[Vector3(9.8,0,-13.7),shrub_path,1.10,0.1], [Vector3(21.4,0,-12.7),flower_path,1.05,-0.3],
		[Vector3(-20.8,0,8.1),shrub_path,1.05,0.4], [Vector3(-20.6,0,13.2),flower_path,1.05,-0.2],
		[Vector3(-9.5,0,14.9),shrub_path,0.95,0.1], [Vector3(7.4,0,14.3),flower_path,1.0,0.4],
		[Vector3(20.9,0,5.0),shrub_path,1.15,-0.4], [Vector3(21.2,0,13.7),flower_path,1.0,0.2],
		[Vector3(10.0,0,-7.6),flower_path,0.85,0.1], [Vector3(20.6,0,-7.7),shrub_path,0.95,-0.2],
		[Vector3(7.0,0,-14.2),shrub_path,0.92,0.2], [Vector3(17.6,0,-14.1),shrub_path,0.96,-0.1],
	]
	for data in planting_data:
		var path: String = str(data[1])
		if ResourceLoader.exists(path):
			# Shrub/flower GLBs are now closed during Blender conversion:
			# front shell + a rear shell rotated around the actual mesh centre.
			_import_prop(
				path,
				data[0],
				Vector3.ONE * float(data[2]),
				float(data[3])
			)

	var tuft_path := GENERATED_ASSET_DIR + "grass_tuft.glb"
	if not ResourceLoader.exists(tuft_path):
		return
	var tufts := [
		Vector3(-20.8,0.02,-4.5),Vector3(-7.5,0.02,-8.0),Vector3(-8.8,0.02,4.8),
		Vector3(-20.8,0.02,12.8),Vector3(-4.0,0.02,13.6),Vector3(8.0,0.02,12.6),
		Vector3(7.0,0.02,5.0),Vector3(7.0,0.02,-2.0),Vector3(19.2,0.02,-14.0),
		Vector3(22.0,0.02,-2.0),Vector3(18.8,0.02,15.2),Vector3(-3.0,0.02,-5.5),
	]
	for index in range(tufts.size()):
		var tuft := _import_prop(tuft_path, tufts[index], Vector3.ONE * (0.72 + fmod(float(index * 5), 5.0) * 0.045), float(index) * 0.73)
		_override_mesh_material(tuft, mats.leaf)

func _create_garden_barista() -> void:
	var root := NPCControllerScript.new()
	world_root.add_child(root)
	root.name = "NPC_GardenBarista"
	root.position = Vector3(-20.5, 0.05, -15.15)
	var visual := _create_character(root, 0, false)
	root.setup(visual, character_loader, false, "Book", null, "GardenBarista")
	root.next_action_at = INF
	var label := Label3D.new()
	root.add_child(label)
	label.text = "Mira  ·  Barista"
	var profile = character_loader.get_profile(0)
	label.position = Vector3(0, profile.label_height, 0)
	label.font_size = 22
	label.outline_size = 7
	label.modulate = CREAM
	label.outline_modulate = Color(0.08,0.05,0.04,0.85)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	call_deferred("_start_garden_barista_leg", root, 1)


func _start_garden_barista_leg(root, target_index: int) -> void:
	if not is_instance_valid(root) or current_room_config.get("id", "") != "garden":
		return
	# The barista patrol stays in the service corridor between counter and
	# shelving wall and therefore never intersects café customers.
	var points := [Vector3(-20.5, 0.05, -15.15), Vector3(-14.5, 0.05, -15.15)]
	var duration := 3.8
	root.walk_to(points[target_index], duration)
	await get_tree().create_timer(duration + 0.45).timeout
	if not is_instance_valid(root) or current_room_config.get("id", "") != "garden":
		return
	await get_tree().create_timer(0.55).timeout
	if is_instance_valid(root):
		_start_garden_barista_leg(root, 1 - target_index)


func _animate_garden_effects(_delta: float) -> void:
	var time := Time.get_ticks_msec() * 0.001

	for flame in garden_fire_nodes:
		if not is_instance_valid(flame):
			continue
		var base: Vector3 = flame.get_meta("fire_origin", flame.position)
		var flame_phase := float(flame.get_meta("fire_phase", 0.0))
		flame.position = base + Vector3(sin(time * 5.2 + flame_phase) * 0.055, sin(time * 7.4 + flame_phase) * 0.08, cos(time * 4.6 + flame_phase) * 0.035)
		var pulse := 1.0 + sin(time * 8.0 + flame_phase) * 0.11
		var base_scale: Vector3 = flame.get_meta("fire_base_scale", Vector3.ONE)
		flame.scale = Vector3(
			base_scale.x * (2.0 - pulse),
			base_scale.y * pulse,
			base_scale.z * (2.0 - pulse)
		)
		flame.rotation.z += sin(time * 4.2 + flame_phase) * 0.0015


func _build_train() -> void:
	_add_environment(Color("#416b91"), Color("#f8e6ba"), 0.78)
	_box(world_root, Vector3(11.0, 0.35, 42.0), Vector3(0, -0.22, 0), mats.cream)
	_box(world_root, Vector3(2.25, 0.035, 39.0), Vector3(0, 0.02, 0), mats.red)
	for x in [-5.5, 5.5]:
		_box(world_root, Vector3(0.36, 1.0, 42.0), Vector3(x, 0.48, 0), mats.red)
		_box(world_root, Vector3(0.36, 0.68, 42.0), Vector3(x, 3.85, 0), mats.red)
		for z in [-20.5,-15.5,-10.5,-5.5,-0.5,4.5,9.5,14.5,20.5]: _box(world_root,Vector3(0.42,3.5,0.28),Vector3(x,2.18,z),mats.cocoa)
	for x in [-5.3, 5.3]:
		for z in [-18.0,-13.0,-8.0,-3.0,2.0,7.0,12.0,17.0]:
			var root := Node3D.new(); world_root.add_child(root); root.position = Vector3(x, 2.45, z); root.rotation.y = PI / 2.0
			_build_window(root.position, Vector2(3.8, 2.1), true)
	# Layered exterior scenery: meadow foreground, trees, water, villages, distant mountains and a tunnel section.
	var scenery_start := world_root.get_child_count()
	for side in [-1.0, 1.0]:
		_box(world_root, Vector3(12.0,0.16,48.0),Vector3(side*11.0,-0.75,0),mats.grass)
		for z in range(-24, 25, 5):
			_place_local_prop("oak_trees_museum", "", Vector3(side*10.5, -0.5, z), Vector3.ONE * 0.52, z * 0.09)
		for z in [-18.0, -8.0, 2.0, 12.0, 20.0]:
			var mountain_path := GENERATED_ASSET_DIR + "scenic_mountain.glb"
			if ResourceLoader.exists(mountain_path):
				_import_prop(mountain_path, Vector3(side * 18.0, -0.75, z), Vector3(1.25, 1.0, 0.70), side * 0.18)
			else:
				var mountain := _sphere(world_root, Vector3(4.5, 2.8, 1.9), Vector3(side*18.0, 1.0, z), mats.blue, 20, 12)
				mountain.rotation.z = 0.15 * side
	# Water and a tiny village read as separate travel beats through the east windows.
	_box(world_root,Vector3(8.0,0.12,13.0),Vector3(13.8,-0.55,4.0),mats.water)
	for z in [-14.0,-10.5,14.0,17.5]:
		var village_path := GENERATED_ASSET_DIR + "village_house.glb"
		if ResourceLoader.exists(village_path):
			_import_prop(village_path, Vector3(14.0, -0.65, z), Vector3.ONE, z * 0.07)
		else:
			_box(world_root,Vector3(1.8,1.4,1.8),Vector3(14.0,0.0,z),mats.cream)
	for index in range(scenery_start, world_root.get_child_count()):
		var scenery := world_root.get_child(index) as Node3D
		if scenery != null:
			var distance := absf(scenery.position.x)
			scenery.set_meta("parallax_speed", 5.2 if distance < 12.5 else (2.8 if distance < 16.0 else 1.15))
			train_scenery_nodes.append(scenery)
	# Dark frames imply a tunnel without enclosing the gameplay carriage.
	for z in [-21.0,-19.5]:
		_box(world_root,Vector3(18.0,0.5,0.5),Vector3(0,5.0,z),mats.ink)
		for x in [-8.8,8.8]: _box(world_root,Vector3(0.5,10.0,0.5),Vector3(x,0,z),mats.ink)
	# Entry, seating, study, quiet, window and end bays now span the carriage length.
	for z in [-16.5, -10.5, -4.5, 1.5, 7.5, 13.5]:
		var bench_path := GENERATED_ASSET_DIR + "train_bench.glb"
		var train_table_path := GENERATED_ASSET_DIR + "train_table.glb"
		if ResourceLoader.exists(bench_path):
			# The Blender bench's upholstered back is local -Z. Keep it against
			# the carriage wall so the cushion and seated character face the aisle.
			_import_prop(bench_path, Vector3(-3.8, 0.0, z), Vector3.ONE, PI / 2.0)
			_import_prop(bench_path, Vector3(3.8, 0.0, z), Vector3.ONE, -PI / 2.0)
		else:
			_box(world_root, Vector3(2.7, 0.18, 1.1), Vector3(-3.8, 0.72, z), mats.teal)
			_box(world_root, Vector3(2.7, 0.18, 1.1), Vector3(3.8, 0.72, z), mats.gold)
		if ResourceLoader.exists(train_table_path):
			_import_prop(train_table_path, Vector3(0, 0, z), Vector3.ONE)
		else:
			_box(world_root, Vector3(2.7, 0.16, 1.0), Vector3(0, 1.02, z), mats.wood)
			_capsule_mesh(world_root, 0.12, 1.0, Vector3(0, 0.5, z), mats.cocoa)
		_import_prop("res://assets/external/kenney_furniture_kit/laptop.glb", Vector3(-0.7,1.12,z), Vector3.ONE * 0.78, PI / 2.0)
		_place_local_prop("coffee_mug", "", Vector3(0.75,1.14,z+0.15), Vector3.ONE)
		_place_local_prop("hardcover_books", "", Vector3(0.72,1.13,z-0.22), Vector3.ONE * 0.72, z * 0.08)
		if int(z + 20.0) % 2 == 0:
			_place_local_prop("nookphone", "", Vector3(0.05,1.13,z+0.22), Vector3.ONE, PI / 2.0)
		else:
			_place_local_prop("lost_book", "", Vector3(-0.05,1.13,z+0.22), Vector3.ONE, -PI / 2.0)
		var travel_prop := "can_of_juice" if z < -8.0 else ("dal_mug" if z < 3.0 else ("grilled_cheese_sandwich" if z < 10.0 else "thank_you_mom_dad_mugs"))
		_place_local_prop(travel_prop, "", Vector3(-0.1,1.13,z-0.30), Vector3.ONE, z * 0.05)
		_place_local_prop("tote_bag" if z < 0 else "leather_handbag", "", Vector3(4.5,0,z+0.45), Vector3.ONE * 0.85, PI / 2.0)
		for side in [-1.0, 1.0]:
			var seat_yaw := -PI / 2.0 if side < 0.0 else PI / 2.0
			for seat_z in [-0.46, 0.46]:
				_register_furniture_seat(Vector3(side * 3.8, 0.0, z + seat_z), seat_yaw + PI, "Laptop" if seat_z < 0.0 else "Book", 0.05, 0.34, 0.88, "train_booth")
		_add_blocker(Vector3(-4.0,0.75,z),Vector3(2.8,1.5,1.2),0.0)
		_add_blocker(Vector3(4.0,0.75,z),Vector3(2.8,1.5,1.2),0.0)
	_place_local_prop("pendulum_clock", "", Vector3(-5.1,1.45,-1.0), Vector3.ONE, PI / 2.0)
	_place_local_prop("corkboard", "", Vector3(5.05,1.4,10.0), Vector3.ONE, -PI / 2.0)
	_place_local_prop("desk_fan", "", Vector3(0.0,1.12,13.5), Vector3.ONE * 0.8)
	for data in [[Vector3(3.8,0.05,-16.22),1,"Pip","29m"],[Vector3(3.8,0.05,7.78),2,"Zoe","43m"],[Vector3(-3.8,0.05,-4.22),0,"Milo","19m"],[Vector3(3.8,0.05,13.78),1,"June","54m"]]:
		_create_npc(data[0],PI / 2.0 if data[0].x < 0 else -PI / 2.0,data[1],data[2],data[3],true)
	_focus_camera(Vector3(7.5, 5.8, 18.0), Vector3(0, 1, 5), "Carriage wide")
	_focus_camera(Vector3(1.0, 2.2, -12.0), Vector3(-3.8, 1.15, -16.0), "Player by window")
	_focus_camera(Vector3(-1.0, 2.3, -14.0), Vector3(-3.5, 1.1, -16.0), "Over shoulder")
	_focus_camera(Vector3(-2.0, 2.8, 5.0), Vector3(8.0, 2.0, 2.0), "Mountains passing")
	_focus_camera(Vector3(0, 2.8, -20.0), Vector3(0, 1.2, 12), "Down the carriage")
	_focus_camera(Vector3(6.5, 3.2, 6.0), Vector3(17.0, 1.0, 2.0), "Lake and mountains")
	_focus_camera(Vector3(-3.8, 3.2, -4.0), Vector3(-11.0, 1.3, -2.0), "Landscape only")
	_add_world_boundaries(current_room_config.bounds)

func _build_japanese_room() -> void:
	_add_environment(Color("#526f5a"), Color("#ffe6b2"), 0.76)
	_box(world_root, Vector3(38,0.35,30),Vector3(0,-0.22,0),mats.cream)
	# Tatami hall, garden-window side, quiet desks, reading corner and low-table area.
	for x in range(-16,17,4):
		for z in range(-12,13,4):
			var tatami := _box(world_root,Vector3(3.55,0.04,3.55),Vector3(x,0.02,z),mats.stone)
			tatami.rotation.y = PI / 2.0 if (x + z) % 4 == 0 else 0
	# An entry runner and two compact tea-reading clusters fill the foreground view.
	_box(world_root, Vector3(11.4,0.05,4.9),Vector3(0,0.025,10.0),mats.wood)
	_box(world_root, Vector3(10.9,0.055,4.45),Vector3(0,0.055,10.0),mats.cocoa)
	for data in [[Vector3(-6.0,0,9.0),0.0],[Vector3(6.0,0,9.0),PI]]:
		_place_local_prop("mini_diy_workbench", "", data[0], Vector3(1.55,0.82,1.25), data[1])
		_build_chair(data[0] + Vector3(0,0,1.45), PI)
		_place_local_prop("hardcover_books", "", data[0] + Vector3(-0.45,0.92,0), Vector3.ONE * 0.72, 0.18)
		_place_local_prop("iced_tea", "", data[0] + Vector3(0.42,0.9,0), Vector3.ONE)
	_place_local_prop("potted_spring_flowers", "", Vector3(-9.0,0,11.4), Vector3.ONE)
	_place_local_prop("potted_autumn_flowers", "", Vector3(9.0,0,11.4), Vector3.ONE)
	_place_local_prop("kadomatsu", "", Vector3(-11.5,0,11.7), Vector3.ONE)
	_place_local_prop("potted_winter_flowers", "", Vector3(11.5,0,11.7), Vector3.ONE)
	_box(world_root,Vector3(38.4,5.2,0.35),Vector3(0,2.45,-15.0),mats.cream)
	for x in range(-18,19,3): _box(world_root,Vector3(0.15,5.0,0.4),Vector3(x,2.4,-14.8),mats.cocoa)
	for y in [0.4,2.45,4.75]: _box(world_root,Vector3(38.2,0.14,0.4),Vector3(0,y,-14.8),mats.cocoa)
	_box(world_root,Vector3(0.35,5.2,30),Vector3(-19.0,2.45,0),mats.cocoa)
	_box(world_root,Vector3(0.35,0.8,30),Vector3(19.0,0.3,0),mats.cocoa)
	for x in [-12.0, 0.0, 12.0]: _build_window(Vector3(x,2.6,-14.72),Vector2(8.0,3.7),false)
	_place_local_prop("pendulum_clock", "", Vector3(-16.8,1.5,-13.9), Vector3.ONE)
	_place_local_prop("corkboard", "", Vector3(15.5,1.4,-13.9), Vector3.ONE)
	_place_local_prop("wall_clock", "", Vector3(0.0,2.35,-14.55), Vector3.ONE)
	_place_local_prop("broom", "", Vector3(-18.25,0.0,-12.2), Vector3.ONE, -0.22)
	for data in [[Vector3(-16.0,0,-7.0),PI / 2.0],[Vector3(16.0,0,-7.0),-PI / 2.0]]:
		_place_local_prop("mini_diy_workbench", "", data[0], Vector3(1.35,1.0,1.15), data[1])
	# Finished Blender shelves turn the long side walls into intimate study bays.
	for z in [-9.5, -1.0, 7.5]:
		_build_bookshelf(Vector3(-18.35, 2.22, z), PI / 2.0, 3.8, 4.45, 0.68, int(180 + z * 7.0))
		_build_bookshelf(Vector3(18.35, 2.22, z), -PI / 2.0, 3.8, 4.45, 0.68, int(240 + z * 9.0))
	# Main study hall desks are widely separated; side rooms use distinct compositions.
	for x in [-8.0,0.0,8.0]:
		for z in [-5.0,3.0]:
			var low_table_path := GENERATED_ASSET_DIR + "japanese_low_table.glb"
			var cushion_path := GENERATED_ASSET_DIR + "floor_cushion.glb"
			if ResourceLoader.exists(low_table_path):
				_import_prop(low_table_path, Vector3(x, 0, z), Vector3.ONE)
			else:
				_box(world_root,Vector3(2.8,0.18,1.2),Vector3(x,0.72,z),mats.wood)
				for sx in [-1.05,1.05]: _capsule_mesh(world_root,0.09,0.7,Vector3(x+sx,0.35,z),mats.cocoa)
			if ResourceLoader.exists(cushion_path):
				_import_prop(cushion_path, Vector3(x, 0, z + 1.0), Vector3.ONE)
			else:
				_sphere(world_root,Vector3(0.65,0.14,0.65),Vector3(x,0.16,z+1.0),mats.red,24,12)
			_import_prop("res://assets/external/kenney_furniture_kit/laptop.glb",Vector3(x,0.84,z),Vector3.ONE*0.72,PI)
			_place_local_prop("hardcover_books", "res://assets/external/kenney_furniture_kit/books.glb", Vector3(x+0.8,0.84,z), Vector3.ONE*0.8)
			_place_local_prop("paperback_books", "", Vector3(x-0.75,0.85,z+0.18), Vector3.ONE * 0.72, x * 0.04)
			_place_local_prop("nookphone" if z < 0 else "lost_book", "", Vector3(x,0.85,z-0.28), Vector3.ONE, 0.12)
			if x == 0.0 and z > 0.0:
				_place_local_prop("zodiac_snake_figurine", "", Vector3(x+0.35,0.84,z+0.12), Vector3.ONE)
			elif x < 0.0 and z > 0.0:
				_place_local_prop("cup_of_tea", "", Vector3(x+0.25,0.84,z+0.10), Vector3.ONE)
			_add_study_spot(Vector3(x,0,z+1.85),Vector3(x,0.28,z+1.05),0,"Book",Vector3(x+4.5,2.7,z+4.4),Vector3(x,1.12,z+0.15),"floor_cushion",SEAT_VISUAL_OFFSETS.floor_cushion,0.28)
			_add_blocker(Vector3(x,0.55,z),Vector3(2.9,1.1,1.3),0.0)
	# Reading corner and low tea table create quieter destinations away from the hall.
	for pos in [Vector3(-14,0,9),Vector3(-11,0,11),Vector3(13,0,10)]:
		_build_armchair(pos, PI, mats.teal if pos.x < 0 else mats.gold)
	_build_chair(Vector3(9.8,0,10.5), PI)
	var low_table_path := GENERATED_ASSET_DIR + "japanese_low_table.glb"
	var cushion_path := GENERATED_ASSET_DIR + "floor_cushion.glb"
	_import_prop(low_table_path, Vector3(13, 0, 6.5), Vector3(1.05, 1.0, 1.05))
	for cushion_z in [-1.0, 1.0]:
		_import_prop(cushion_path, Vector3(13, 0, 6.5 + cushion_z), Vector3.ONE)
		_register_furniture_seat(Vector3(13, 0, 6.5 + cushion_z), PI if cushion_z > 0 else 0.0, "Book", 0.28, 0.20, 0.82, "floor_cushion")
	_place_local_prop("coffee_mug", "", Vector3(13.5,0.86,6.5), Vector3.ONE)
	_place_local_prop("iced_tea", "", Vector3(12.5,0.86,6.5), Vector3.ONE)
	_place_local_prop("natural_basket", "", Vector3(-12.5,0,8.0), Vector3.ONE)
	for x in [-16.6,16.6]:
		_place_local_prop("potted_autumn_flowers" if x < 0 else "potted_spring_flowers", "res://assets/external/kenney_furniture_kit/pottedPlant.glb", Vector3(x,0,12.0), Vector3.ONE)
		for y in [1.7,3.0]:
			_import_prop(GENERATED_ASSET_DIR + "wall_lamp.glb", Vector3(x, y, -14.55), Vector3.ONE * 0.82)
	# Supplied plants, books and rugs break up repeated tatami without blocking circulation.
	for data in [[Vector3(-16.2,0,-9.8),0.0],[Vector3(16.2,0,-9.8),0.4],[Vector3(-16.2,0,4.8),-0.2],[Vector3(16.2,0,4.8),0.2]]:
		_place_local_prop("potted_spring_flowers", "res://assets/external/kenney_furniture_kit/pottedPlant.glb", data[0], Vector3.ONE * 0.86, data[1])
	_import_prop("res://assets/external/kenney_furniture_kit/rugRounded.glb", Vector3(-12.5,0.03,9.7), Vector3(2.4,1.0,1.8), 0.12)
	_import_prop("res://assets/external/kenney_furniture_kit/rugRounded.glb", Vector3(12.0,0.03,8.4), Vector3(2.0,1.0,1.55), -0.08)
	for data in [[Vector3(-6,0.05,10.45),1,"Hana","24m"],[Vector3(8,-0.34,3.82),2,"Iko","46m"],[Vector3(0,-0.34,3.82),0,"Ren","39m"],[Vector3(-11,0.05,11),1,"Ami","17m"],[Vector3(9.8,0.05,10.5),2,"Yuki","52m"]]:
		_create_npc(data[0],0,data[1],data[2],data[3],true)
	_focus_camera(Vector3(15,8.0,13),Vector3(0,0.7,0),"Tatami hall wide")
	_focus_camera(Vector3(-3.2,2.7,-1.0),Vector3(-8.0,0.8,-5.0),"Quiet desk study")
	_focus_camera(Vector3(9.5,3.0,-5),Vector3(0,1.8,-14.5),"Garden windows")
	_focus_camera(Vector3(-8,3.4,13),Vector3(-13,1.0,10),"Reading corner")
	_focus_camera(Vector3(17,3.0,10),Vector3(13,0.8,6.5),"Low table")
	_add_world_boundaries(current_room_config.bounds)

func _build_cafe_table(pos: Vector3, accent: Material) -> void:
	var generated_path := GENERATED_ASSET_DIR + "cafe_table.glb"
	if ResourceLoader.exists(generated_path):
		_import_prop(generated_path, pos, Vector3.ONE)
	else:
		_cylinder(world_root,1.2,0.18,pos+Vector3(0,1.02,0),mats.wood,40)
		_capsule_mesh(world_root,0.18,1.0,pos+Vector3(0,0.5,0),mats.cocoa)
		_cylinder(world_root,0.58,0.12,pos+Vector3(0,0.06,0),mats.cocoa,32)
		_capsule_mesh(world_root,0.08,3.2,pos+Vector3(0,2.25,0),mats.cocoa)
		for i in 8:
			var petal:=_sphere(world_root,Vector3(1.25,0.10,0.52),pos+Vector3(cos(i*TAU/8.0)*0.8,3.72,sin(i*TAU/8.0)*0.8),accent,20,10)
			petal.rotation.y=i*TAU/8.0
	_build_chair(pos+Vector3(0,0,1.52),PI,"Laptop","cafe_chair")
	_import_prop("res://assets/external/kenney_furniture_kit/laptop.glb",pos+Vector3(0,1.16,-0.2),Vector3.ONE*0.76,PI)
	_place_local_prop("iced_tea", "", pos + Vector3(0.65, 1.17, 0.1), Vector3.ONE)
	_add_blocker(pos + Vector3(0,0.65,0),Vector3(2.25,1.3,2.25),0.0)
	_add_blocker(pos + Vector3(0,2.55,0),Vector3(0.22,3.5,0.22),0.0)

func _build_tree(pos: Vector3, scale_value: float) -> void:
	var root:=Node3D.new();world_root.add_child(root);root.position=pos;root.scale=Vector3.ONE*scale_value
	_capsule_mesh(root,0.28,3.4,Vector3(0,1.7,0),mats.wood)
	for p in [Vector3(-0.8,3.1,0),Vector3(0.7,3.3,0.2),Vector3(0,4.0,0),Vector3(-0.2,3.5,-0.7),Vector3(0.5,3.4,-0.6)]:
		_sphere(root,Vector3(1.05,0.9,0.92),p,mats.leaf,24,14)

func _build_bush(pos: Vector3, scale_value: float) -> void:
	for p in [Vector3(-0.55,0.6,0),Vector3(0.55,0.6,0),Vector3(0,0.9,0.15)]:
		_sphere(world_root,Vector3(0.8,0.72,0.75)*scale_value,pos+p*scale_value,mats.green,20,12)
	for i in 7:
		_sphere(world_root,Vector3(0.09,0.09,0.09),pos+Vector3(sin(i*2.1)*0.75,0.65+fmod(i,3)*0.25,cos(i*1.7)*0.55),[mats.pink,mats.gold,mats.cream][i%3],14,8)

func _build_plant(pos: Vector3, scale_value: float) -> void:
	_cylinder(world_root,0.55*scale_value,0.72*scale_value,pos+Vector3(0,0.36*scale_value,0),mats.coral,28)
	for i in 9:
		var ang:=i*TAU/9.0
		var leaf:=_sphere(world_root,Vector3(0.28,0.62,0.16)*scale_value,pos+Vector3(cos(ang)*0.35,1.05*scale_value+sin(i*2.0)*0.12,sin(ang)*0.35),mats.leaf,20,12)
		leaf.rotation.z=cos(ang)*0.48
		leaf.rotation.x=sin(ang)*0.48

func _create_npc(pos: Vector3, yaw: float, variant: int, display_name: String, timer: String, seated: bool) -> void:
	var assigned_spot = _find_available_spot_near(pos) if seated else null
	if seated and assigned_spot == null:
		push_warning("NPC %s has no available authored seat near %s" % [display_name, pos])
		return
	if assigned_spot != null and not assigned_spot.reserve(display_name, StudySpot.OccupantType.NPC):
		push_warning("NPC %s could not reserve %s" % [display_name, assigned_spot.seat_id])
		return
	var root=NPCControllerScript.new();world_root.add_child(root)
	root.name = "NPC_%s" % display_name
	root.position = assigned_spot.sitting_position if assigned_spot != null else pos
	root.rotation.y = assigned_spot.facing_yaw if assigned_spot != null else yaw
	var visual:=_create_character(root,variant,seated)
	if seated:
		character_loader.set_seated(visual, true, assigned_spot.seated_visual_offset)
		if not bool(visual.get_meta("is_imported_character", false)):
			var parts:Dictionary=visual.get_meta("parts")
			parts.leg_l.rotation.x=-1.22;parts.leg_r.rotation.x=-1.22
			parts.leg_l.position.y=0.63;parts.leg_r.position.y=0.63
			parts.arm_l.rotation.x=-0.78;parts.arm_r.rotation.x=-0.78
	var label:=Label3D.new();root.add_child(label)
	label.text=display_name+"  ·  "+timer
	var profile = character_loader.get_profile(variant)
	label.position=Vector3(0, profile.label_height, 0)
	label.font_size=24;label.outline_size=7;label.modulate=CREAM;label.outline_modulate=Color(0.08,0.05,0.04,0.85)
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	root.setup(visual, character_loader, seated, assigned_spot.study_type if assigned_spot != null else ("Laptop" if variant % 2 == 0 else "Book"), assigned_spot, display_name)

	# Armchairs use a dedicated strict 90-degree seated leg pose. NPCController
	# does not know about the armchair-specific clips, so select the correct
	# imported action here and keep this NPC in that study pose.
	if assigned_spot != null and str(assigned_spot.seat_type) == "armchair":
		var armchair_animation := (
			"ArmchairStudyLaptop"
			if str(assigned_spot.study_type) == "Laptop"
			else "ArmchairStudyBook"
		)
		_play_seated_character_animation(visual, armchair_animation, 0.0)
		root.next_action_at = INF

	npcs.append(root)

func _find_available_spot_near(position_hint: Vector3, maximum_distance := 4.0):
	var best = null
	var best_distance := maximum_distance
	for spot in study_spots:
		if not spot.is_available():
			continue
		var distance: float = position_hint.distance_to(spot.sitting_position)
		if distance < best_distance:
			best = spot
			best_distance = distance
	return best

func _add_study_spot(standing: Vector3, sitting: Vector3, yaw: float, study_type: String, camera_pos: Vector3, camera_target: Vector3, seat_type := "desk_chair", seated_visual_offset := Vector3.ZERO, seat_height := 0.0):
	var spot = StudySpotScript.new()
	world_root.add_child(spot)
	spot.name = "StudySpot_%02d" % study_spots.size()
	spot.configure("%s-seat-%02d" % [current_room_config.get("id", "review"), study_spots.size()], standing, sitting, yaw, study_type, camera_pos, camera_target, seat_type, seated_visual_offset, seat_height)
	var debug_root:=Node3D.new();spot.add_child(debug_root);debug_root.name="DebugVisual";debug_root.visible=false
	var stand_marker:=_cylinder(debug_root,0.22,0.04,standing+Vector3(0,0.05,0),mats.green,18)
	var sit_marker:=_cylinder(debug_root,0.22,0.04,sitting+Vector3(0,0.08,0),mats.coral,18)
	var radius_ring := MeshInstance3D.new(); debug_root.add_child(radius_ring); radius_ring.position = standing + Vector3.UP * 0.035
	var torus := TorusMesh.new(); torus.inner_radius = 1.96; torus.outer_radius = 2.05; torus.rings = 48; torus.ring_segments = 8
	var ring_material := StandardMaterial3D.new(); ring_material.albedo_color = Color(0.25, 1.0, 0.45, 0.58); ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	torus.material = ring_material; radius_ring.mesh = torus
	var arrow:=_box(debug_root,Vector3(0.08,0.08,0.9),sitting+Vector3(0,0.15,-0.42),mats.gold);arrow.rotation.y=yaw
	var seat_label := Label3D.new(); debug_root.add_child(seat_label); seat_label.position = sitting + Vector3.UP * 0.55
	seat_label.font_size = 22; seat_label.outline_size = 6; seat_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	spot.debug_visual = debug_root
	spot.debug_stand_marker = stand_marker
	spot.debug_sit_marker = sit_marker
	spot.debug_radius_marker = radius_ring
	spot.debug_label = seat_label
	study_spots.append(spot)
	spot.update_debug(false)
	return spot

func _update_nearest_spot() -> void:
	if not is_instance_valid(player):return
	var best:=-1;var best_distance:=INF
	for i in study_spots.size():
		if not study_spots[i].is_available(): continue
		var d:float=player.global_position.distance_to(study_spots[i].standing_position)
		if d <= study_spots[i].interaction_radius and d < best_distance:best=i;best_distance=d
	nearest_spot=best
	if debug_spots_visible:
		for i in study_spots.size(): study_spots[i].update_debug(i == best)
	if is_instance_valid(prompt_label):
		prompt_label.visible = best >= 0
		if best >= 0:
			var nearest = study_spots[best]
			if str(nearest.seat_type) == "tanning_bed":
				prompt_label.text = "E   Rest here"
			else:
				prompt_label.text = "E   Study here  ·  " + nearest.study_type

func _set_debug_spots(value: bool) -> void:
	for i in study_spots.size():
		study_spots[i].debug_visual.visible=value
		study_spots[i].update_debug(i == nearest_spot)
	_show_toast("StudySpot anchors "+("visible" if value else "hidden"))

func _set_collision_debug(value: bool) -> void:
	get_tree().call_group("collision_debug", "set_visible", value)
	_show_toast("Structural collision "+("visible" if value else "hidden"))

func _build_room_ui() -> void:
	var top:=PanelContainer.new();ui_root.add_child(top);top.position=Vector2(28,24);top.size=Vector2(430,76)
	top.add_theme_stylebox_override("panel",_panel_style(Color(0.09,0.065,0.05,0.92),24,2,Color(1,0.85,0.56,0.25)))
	var h:=HBoxContainer.new();top.add_child(h);h.add_theme_constant_override("separation",16)
	var back:=_button("‹  Places",false);back.custom_minimum_size=Vector2(112,54);back.pressed.connect(show_main_menu);h.add_child(back)
	var title_box:=VBoxContainer.new();h.add_child(title_box)
	var title:=_label(current_room_name,22,CREAM);title_box.add_child(title)
	title_box.add_child(_label("A quiet room · %d studying"%npcs.size(),13,Color("#d6c6aa")))

	var stats:=PanelContainer.new();ui_root.add_child(stats);stats.position=Vector2(1000,24);stats.size=Vector2(250,76)
	stats.add_theme_stylebox_override("panel",_panel_style(Color(0.09,0.065,0.05,0.92),24,2,Color(1,0.85,0.56,0.25)))
	coins_label=_label("●  %d Focus Coins"%GameState.focus_coins,18,CREAM);coins_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;coins_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;stats.add_child(coins_label)

	prompt_label=_label("E   Study here",17,INK);ui_root.add_child(prompt_label);prompt_label.position=Vector2(490,630);prompt_label.size=Vector2(300,58);prompt_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;prompt_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;prompt_label.add_theme_stylebox_override("normal",_panel_style(Color("#fff2cc"),22,3,HONEY));prompt_label.visible=false
	var hint:=_pill("WASD move   ·   E interact   ·   F wave",Vector2(28,650));ui_root.add_child(hint)
	debug_label=_label("DEV  F3 anchors  ·  F4 collision  ·  F5 short focus  ·  F6 performance\nFPS: --   Grounded: --",13,CREAM);ui_root.add_child(debug_label);debug_label.position=Vector2(820,610);debug_label.size=Vector2(430,84);debug_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;debug_label.visible=false

func _open_resting_setup(spot_index: int) -> void:
	if study_spots.is_empty():
		return
	spot_index = clampi(spot_index, 0, study_spots.size() - 1)
	var spot = study_spots[spot_index]

	if not spot.reserve("local_player", StudySpot.OccupantType.PLAYER):
		_show_toast("That lounger is occupied")
		return

	pending_study_spot = spot
	_set_movement_enabled(false)

	var overlay := ColorRect.new()
	ui_root.add_child(overlay)
	overlay.name = "RestingSetupOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.06, 0.04, 0.03, 0.68)

	var panel := PanelContainer.new()
	overlay.add_child(panel)
	panel.position = Vector2(355, 135)
	panel.size = Vector2(570, 430)
	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(CREAM, 30, 5, HONEY)
	)

	var margin := MarginContainer.new()
	panel.add_child(margin)
	for key in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + key, 28)

	var stack := VBoxContainer.new()
	margin.add_child(stack)
	stack.add_theme_constant_override("separation", 16)

	stack.add_child(_label("Take a rest", 30, INK))
	stack.add_child(
		_label(
			"Choose how long you want to rest here.",
			17,
			COCOA
		)
	)

	var presets := GridContainer.new()
	presets.columns = 3
	presets.add_theme_constant_override("h_separation", 10)
	presets.add_theme_constant_override("v_separation", 10)
	stack.add_child(presets)

	for data in [
		["10 min", 600],
		["20 min", 1200],
		["30 min", 1800],
		["60 min", 3600],
		["120 min", 7200],
		["10 sec · DEV", 10],
	]:
		var button := _button(
			data[0],
			int(data[1]) == resting_duration
		)
		button.custom_minimum_size = Vector2(155, 48)
		button.pressed.connect(
			_choose_resting_duration.bind(
				int(data[1]),
				presets
			)
		)
		button.set_meta("seconds", data[1])
		presets.add_child(button)

	var custom_row := HBoxContainer.new()
	custom_row.add_theme_constant_override("separation", 12)
	stack.add_child(custom_row)
	custom_row.add_child(_label("Custom minutes", 16, COCOA))

	var custom_minutes := SpinBox.new()
	custom_minutes.min_value = 1
	custom_minutes.max_value = 480
	custom_minutes.value = clampi(resting_duration / 60, 1, 480)
	custom_minutes.custom_minimum_size = Vector2(150, 44)
	custom_minutes.add_theme_font_size_override("font_size", 17)
	custom_minutes.value_changed.connect(
		func(value: float):
			resting_duration = int(value) * 60
	)
	custom_row.add_child(custom_minutes)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	stack.add_child(actions)

	var cancel := _button("Not yet", false)
	cancel.custom_minimum_size = Vector2(180, 58)
	cancel.pressed.connect(_close_resting_setup)
	actions.add_child(cancel)

	var start := _button("Begin resting  →", true)
	start.custom_minimum_size = Vector2(300, 58)
	start.pressed.connect(_begin_resting.bind(spot_index))
	actions.add_child(start)


func _choose_resting_duration(
	seconds: int,
	grid: GridContainer
) -> void:
	resting_duration = seconds
	for child in grid.get_children():
		if child is Button:
			var selected := (
				int(child.get_meta("seconds")) == seconds
			)
			child.add_theme_stylebox_override(
				"normal",
				_panel_style(
					HONEY if selected else Color("#f4e3bf"),
					14,
					2,
					WOOD if selected else Color("#d8bd88")
				)
			)


func _close_resting_setup() -> void:
	var overlay := ui_root.get_node_or_null("RestingSetupOverlay")
	if overlay:
		overlay.queue_free()

	if (
		pending_study_spot != null
		and is_instance_valid(pending_study_spot)
	):
		pending_study_spot.release("local_player")
		pending_study_spot.update_debug(false)

	pending_study_spot = null
	_set_movement_enabled(true)


func _open_focus_setup(spot_index: int) -> void:
	if study_spots.is_empty():return
	spot_index=clampi(spot_index,0,study_spots.size()-1)
	var spot = study_spots[spot_index]
	if not spot.reserve("local_player", StudySpot.OccupantType.PLAYER):
		_show_toast("That seat is occupied")
		return
	pending_study_spot = spot
	_set_movement_enabled(false)
	var overlay:=ColorRect.new();ui_root.add_child(overlay);overlay.name="FocusSetupOverlay";overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.color=Color(0.06,0.04,0.03,0.68)
	var panel:=PanelContainer.new();overlay.add_child(panel);panel.position=Vector2(355,115);panel.size=Vector2(570,490);panel.add_theme_stylebox_override("panel",_panel_style(CREAM,30,5,HONEY))
	var margin:=MarginContainer.new();panel.add_child(margin)
	for key in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+key,28)
	var stack:=VBoxContainer.new();margin.add_child(stack);stack.add_theme_constant_override("separation",14)
	stack.add_child(_label("Settle in and focus",30,INK))
	stack.add_child(_label("What are you working on?",17,COCOA))
	task_input=LineEdit.new();task_input.placeholder_text="e.g. Data structures coursework";task_input.max_length=64;task_input.custom_minimum_size=Vector2(0,56);task_input.add_theme_font_size_override("font_size",18);task_input.add_theme_color_override("font_color",INK);task_input.add_theme_color_override("font_placeholder_color",Color("#927d68"));task_input.add_theme_stylebox_override("normal",_panel_style(Color("#fffaf0"),15,2,Color("#d7b87d")));stack.add_child(task_input)
	stack.add_child(_label("Choose a focus time",17,COCOA))
	var presets:=GridContainer.new();presets.columns=3;presets.add_theme_constant_override("h_separation",10);presets.add_theme_constant_override("v_separation",10);stack.add_child(presets)
	for data in [["25 min",1500],["50 min",3000],["90 min",5400],["120 min",7200],["10 sec · DEV",10]]:
		var b:=_button(data[0],int(data[1])==selected_duration);b.custom_minimum_size=Vector2(155,48);b.pressed.connect(_choose_duration.bind(int(data[1]),presets));presets.add_child(b);b.set_meta("seconds",data[1])
	var custom_row := HBoxContainer.new(); custom_row.add_theme_constant_override("separation", 12); stack.add_child(custom_row)
	custom_row.add_child(_label("Custom minutes", 16, COCOA))
	var custom_minutes := SpinBox.new(); custom_minutes.min_value = 1; custom_minutes.max_value = 180; custom_minutes.value = clampi(selected_duration / 60, 1, 180); custom_minutes.custom_minimum_size = Vector2(150, 44); custom_minutes.add_theme_font_size_override("font_size", 17); custom_minutes.value_changed.connect(func(value: float): selected_duration = int(value) * 60); custom_row.add_child(custom_minutes)
	var actions:=HBoxContainer.new();actions.add_theme_constant_override("separation",12);stack.add_child(actions)
	var cancel:=_button("Not yet",false);cancel.custom_minimum_size=Vector2(180,58);cancel.pressed.connect(_close_focus_setup);actions.add_child(cancel)
	var start:=_button("Begin focus  →",true);start.custom_minimum_size=Vector2(300,58);start.pressed.connect(_begin_focus.bind(spot_index));actions.add_child(start)
	task_input.grab_focus()

func _choose_duration(seconds: int, grid: GridContainer) -> void:
	selected_duration=seconds
	for child in grid.get_children():
		if child is Button:
			var selected:=int(child.get_meta("seconds"))==seconds
			child.add_theme_stylebox_override("normal",_panel_style(HONEY if selected else Color("#f4e3bf"),14,2,WOOD if selected else Color("#d8bd88")))

func _close_focus_setup() -> void:
	var overlay:=ui_root.get_node_or_null("FocusSetupOverlay")
	if overlay:overlay.queue_free()
	if pending_study_spot != null and is_instance_valid(pending_study_spot):
		pending_study_spot.release("local_player")
		pending_study_spot.update_debug(false)
	pending_study_spot = null
	_set_movement_enabled(true)

func _study_animation_for_spot(spot) -> String:
	if spot == null or not is_instance_valid(spot):
		return "StudyBook"

	var seat_type := str(spot.seat_type)
	var study_type := str(spot.study_type)

	if seat_type == "floor_cushion":
		return "FloorStudy"

	if seat_type == "train_booth":
		return "TrainStudy"

	if seat_type == "armchair":
		return "ArmchairStudyLaptop" if study_type == "Laptop" else "ArmchairStudyBook"

	if study_type == "Laptop":
		return "StudyLaptop"

	return "StudyBook"

func _prepare_custom_loop_animation(character: Node, state: String) -> void:
	if not is_instance_valid(character):
		return
	if not state.begins_with("Armchair"):
		return
	if not character.has_meta("animation_controller"):
		return

	var controller = character.get_meta("animation_controller")
	if not is_instance_valid(controller):
		return
	if not is_instance_valid(controller.animation_player):
		return

	var clip := StringName(str(controller.animation_map.get(state, state)))
	if controller.animation_player.has_animation(clip):
		controller.animation_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR

func _play_seated_character_animation(character: Node, state: String, blend := 0.18) -> void:
	_prepare_custom_loop_animation(character, state)
	character_loader.play_animation(character, state, blend)

func _begin_resting(spot_index: int) -> void:
	var spot = study_spots[spot_index]

	if not spot.reserve("local_player", StudySpot.OccupantType.PLAYER):
		_show_toast("That lounger is occupied")
		_close_resting_setup()
		return

	active_session_mode = "resting"
	active_study_spot = spot
	pending_study_spot = null

	var overlay := ui_root.get_node_or_null("RestingSetupOverlay")
	if overlay:
		overlay.queue_free()

	await _transition_player_to_resting_spot(spot)
	player.velocity = Vector3.ZERO

	if bool(
		player_visual.get_meta(
			"is_imported_character",
			false
		)
	):
		character_loader.set_seated(
			player_visual,
			true,
			spot.seated_visual_offset
		)
		character_loader.play_animation(
			player_visual,
			"Resting",
			0.18
		)
	elif player_parts.has("leg_l"):
		# Public fallback only. Imported cats use the authored Resting action.
		player_visual.rotation.x = -PI / 2.0

	_set_movement_enabled(false)
	screen = Screen.FOCUS

	_build_resting_hud()
	_prepare_focus_camera_pool(spot)
	focus_shot_index = -1
	next_shot_at = 0

	# Reuse the existing reliable countdown/signal infrastructure, but Resting
	# is handled separately on completion and never awards Focus Coins.
	FocusManager.start_session(
		"Resting",
		resting_duration
	)


func _transition_player_to_resting_spot(spot) -> void:
	_set_movement_enabled(false)
	player.velocity = Vector3.ZERO

	var approach := create_tween()
	approach.set_trans(Tween.TRANS_CUBIC)
	approach.set_ease(Tween.EASE_IN_OUT)

	approach.tween_property(
		player,
		"global_position",
		spot.standing_position,
		0.32
	)
	approach.parallel().tween_property(
		player,
		"rotation:y",
		spot.facing_yaw,
		0.32
	)
	await approach.finished

	player.global_position = spot.standing_position
	player.rotation.y = spot.facing_yaw

	var target_visual_offset := Vector3.ZERO
	var profile = player_visual.get_meta(
		"character_profile",
		null
	)

	if profile != null:
		target_visual_offset = (
			profile.sitting_visual_offset
			+ spot.seated_visual_offset
		)

	var settle := create_tween()
	settle.set_trans(Tween.TRANS_CUBIC)
	settle.set_ease(Tween.EASE_IN_OUT)

	settle.tween_property(
		player,
		"global_position",
		spot.sitting_position,
		0.72
	)

	if bool(
		player_visual.get_meta(
			"is_imported_character",
			false
		)
	):
		settle.parallel().tween_property(
			player_visual,
			"position",
			target_visual_offset,
			0.72
		)

	await settle.finished
	player.global_position = spot.sitting_position


func _begin_focus(spot_index: int) -> void:
	active_session_mode = "focus"
	var task:=task_input.text if is_instance_valid(task_input) else "Quiet focus"
	var spot = study_spots[spot_index]
	if not spot.reserve("local_player", StudySpot.OccupantType.PLAYER):
		_show_toast("That seat is occupied")
		_close_focus_setup()
		return
	active_study_spot = spot
	pending_study_spot = null
	var overlay:=ui_root.get_node_or_null("FocusSetupOverlay");if overlay:overlay.queue_free()
	# Author-authored anchors are used directly for deterministic seat alignment.
	await _transition_player_to_study_spot(spot)
	player.velocity=Vector3.ZERO
	if bool(player_visual.get_meta("is_imported_character", false)):
		character_loader.set_seated(player_visual, true, spot.seated_visual_offset)
		_play_seated_character_animation(
			player_visual,
			_study_animation_for_spot(spot)
		)
	elif player_parts.has("leg_l"):
		player_parts.leg_l.rotation.x=-1.22;player_parts.leg_r.rotation.x=-1.22
		player_parts.arm_l.rotation.x=-0.80;player_parts.arm_r.rotation.x=-0.80
	_set_movement_enabled(false)
	screen=Screen.FOCUS
	_build_focus_hud(task)
	_prepare_focus_camera_pool(spot)
	focus_shot_index=-1
	next_shot_at=0
	FocusManager.start_session(task,selected_duration)

func _transition_player_to_study_spot(spot) -> void:
	_set_movement_enabled(false)
	player.velocity = Vector3.ZERO

	# ------------------------------------------------------------
	# 1. Walk/slide to the authored standing anchor.
	# ------------------------------------------------------------

	var approach := create_tween()
	approach.set_trans(Tween.TRANS_CUBIC)
	approach.set_ease(Tween.EASE_IN_OUT)

	approach.tween_property(
		player,
		"global_position",
		spot.standing_position,
		0.32
	)

	approach.parallel().tween_property(
		player,
		"rotation:y",
		spot.facing_yaw,
		0.32
	)

	await approach.finished

	player.global_position = spot.standing_position
	player.rotation.y = spot.facing_yaw

	# ------------------------------------------------------------
	# 2. Begin actual skeletal Sit.
	# ------------------------------------------------------------

	character_loader.play_animation(
		player_visual,
		"Sit",
		0.12
	)

	# ------------------------------------------------------------
	# 3. Move the CHARACTER ROOT into the authored chair anchor
	#    while also blending the MODEL toward the seat-specific
	#    visual correction.
	#
	# Previously the visual offset was applied only after the root
	# had already reached the chair, which made the character sink
	# or snap into furniture.
	# ------------------------------------------------------------

	var target_visual_offset := Vector3.ZERO

	var profile = player_visual.get_meta(
		"character_profile",
		null
	)

	if profile != null:
		target_visual_offset = (
			profile.sitting_visual_offset
			+ spot.seated_visual_offset
		)

	var settle := create_tween()
	settle.set_trans(Tween.TRANS_CUBIC)
	settle.set_ease(Tween.EASE_IN_OUT)

	settle.tween_property(
		player,
		"global_position",
		spot.sitting_position,
		0.90
	)

	if bool(
		player_visual.get_meta(
			"is_imported_character",
			false
		)
	):
		settle.parallel().tween_property(
			player_visual,
			"position",
			target_visual_offset,
			0.90
		)

	await settle.finished

	player.global_position = spot.sitting_position

	if bool(
		player_visual.get_meta(
			"is_imported_character",
			false
		)
	):
		player_visual.position = target_visual_offset

func _begin_review_focus() -> void:
	if study_spots.is_empty(): return
	var spot = study_spots[0]
	if not spot.is_available():
		spot = study_spots.filter(func(candidate): return candidate.is_available()).front()
	spot.reserve("local_player", StudySpot.OccupantType.PLAYER)
	active_study_spot = spot
	player.position = spot.sitting_position
	player.rotation.y = spot.facing_yaw
	player.velocity = Vector3.ZERO
	character_loader.set_seated(player_visual, true, spot.seated_visual_offset)
	_play_seated_character_animation(
		player_visual,
		_study_animation_for_spot(spot),
		0.0
	)
	if player_parts.has("leg_l"):
		player_parts.leg_l.rotation.x = -1.22
		player_parts.leg_r.rotation.x = -1.22
		player_parts.arm_l.rotation.x = -0.80
		player_parts.arm_r.rotation.x = -0.80
	_set_movement_enabled(false)
	screen = Screen.FOCUS
	_build_focus_hud("Reference analysis notes")
	_prepare_focus_camera_pool(spot)
	focus_shot_index = -1
	next_shot_at = 0
	FocusManager.start_session("Reference analysis notes", 1500)

func _begin_review_focus_at(spot_index: int) -> void:
	if study_spots.is_empty():
		return
	var clamped_index := clampi(spot_index, 0, study_spots.size() - 1)
	if not study_spots[clamped_index].is_available():
		var available = study_spots.filter(func(candidate): return candidate.is_available())
		if available.is_empty():
			return
		clamped_index = study_spots.find(available.front())
	var chosen = study_spots[clamped_index]
	chosen.reserve("local_player", StudySpot.OccupantType.PLAYER)
	active_study_spot = chosen
	player.position = chosen.sitting_position
	player.rotation.y = chosen.facing_yaw
	player.velocity = Vector3.ZERO
	character_loader.set_seated(player_visual, true, chosen.seated_visual_offset)
	_play_seated_character_animation(
		player_visual,
		_study_animation_for_spot(chosen),
		0.0
	)
	_set_movement_enabled(false)
	screen = Screen.FOCUS
	_build_focus_hud("Reference analysis notes")
	_prepare_focus_camera_pool(chosen)
	focus_shot_index = -1
	next_shot_at = 0
	FocusManager.start_session("Reference analysis notes", 1500)

func _begin_review_walk() -> void:
	Input.action_press("move_forward")
	await get_tree().create_timer(2.2).timeout
	Input.action_release("move_forward")

func _begin_review_walk_side() -> void:
	Input.action_press("move_right")
	await get_tree().create_timer(2.8).timeout
	Input.action_release("move_right")

func _begin_npc_walk_review() -> void:
	if npcs.is_empty():
		return
	player.visible = false
	var npc = npcs.front()
	npc.global_position = Vector3(-4.0, 0.05, 9.2)
	npc.walk_to(Vector3(4.0, 0.05, 9.2), 3.4)
	_make_camera(Vector3(2.2, 3.3, 15.0), Vector3(0.0, 1.25, 9.2), 40.0)

func _begin_seating_review(seat_type: String) -> void:
	var matching := study_spots.filter(func(spot): return spot.is_available() and spot.seat_type == seat_type)
	if matching.is_empty():
		return
	var spot = matching.front()
	spot.reserve("local_player", StudySpot.OccupantType.PLAYER)
	active_study_spot = spot
	player.global_position = spot.sitting_position
	player.rotation.y = spot.facing_yaw
	player.velocity = Vector3.ZERO
	character_loader.set_seated(
		player_visual,
		true,
		spot.seated_visual_offset
	)

	var review_animation := "SeatedIdle"

	if seat_type == "floor_cushion":
		review_animation = "FloorStudy"
	elif seat_type == "train_booth":
		review_animation = "TrainStudy"
	elif seat_type == "armchair":
		review_animation = "ArmchairSeatedIdle"

	_play_seated_character_animation(
		player_visual,
		review_animation,
		0.0
	)
	_set_movement_enabled(false)
	var forward := Basis(Vector3.UP, spot.facing_yaw) * Vector3.FORWARD
	var right := Basis(Vector3.UP, spot.facing_yaw) * Vector3.RIGHT
	var target: Vector3 = spot.sitting_position + Vector3.UP * 1.18
	var camera_offset := forward * 3.25 + right * 2.65 + Vector3.UP * 1.45
	if seat_type == "train_booth":
		camera_offset = forward * 2.20 + right * 3.80 + Vector3.UP * 1.45
	elif seat_type == "floor_cushion":
		camera_offset = forward * 0.85 + right * 4.10 + Vector3.UP * 1.35
	_make_camera(target + camera_offset, target, 40.0)

func _activate_review_camera(index: int) -> void:
	var pool: Array[Camera3D] = (
		room_broll_cameras
		if not room_broll_cameras.is_empty()
		else focus_cameras
	)

	if pool.is_empty():
		return

	pool[
		clampi(index, 0, pool.size() - 1)
	].current = true

func _activate_shelf_review() -> void:
	_make_camera(Vector3(-8.0, 4.3, 7.4), Vector3(0.0, 1.85, 1.15), 40.0)

func _activate_wall_shelf_review() -> void:
	_make_camera(Vector3(-10.2, 3.4, 5.8), Vector3(-18.0, 2.0, 0.5), 38.0)

func _activate_garden_tuft_review() -> void:
	_make_camera(Vector3(8.8, 1.35, 7.4), Vector3(7.25, 0.26, 4.25), 34.0)

func _activate_plant_review() -> void:
	_make_camera(Vector3(13.5, 4.4, 15.0), Vector3(7.8, 0.85, 10.9), 40.0)

func _activate_prop_grounding_review() -> void:
	_make_camera(Vector3(11.0, 3.5, 10.5), Vector3(6.5, 0.8, 9.8), 40.0)

func _activate_npc_review() -> void:
	if npcs.is_empty():
		return
	var review_index := 3
	if str(current_room_config.get("id", "")) == "garden":
		# The east-edge table sits under dense tree canopies. Review the open
		# central café seat so foliage cannot conceal the seated silhouette.
		review_index = 1
	var reviewed_npc = npcs[mini(review_index, npcs.size() - 1)]
	if reviewed_npc.assigned_spot == null:
		return
	var spot = reviewed_npc.assigned_spot
	var forward := Basis(Vector3.UP, spot.facing_yaw) * Vector3.FORWARD
	var right := Basis(Vector3.UP, spot.facing_yaw) * Vector3.RIGHT
	var target: Vector3 = spot.sitting_position + Vector3.UP * 1.25
	var camera_offset := forward * 0.75 + right * 4.0 + Vector3.UP * 1.55
	if spot.seat_type == "cafe_chair":
		camera_offset = -forward * 0.40 + right * 4.20 + Vector3.UP * 1.55
	if spot.seat_type == "train_booth":
		camera_offset = forward * 2.20 + right * 3.80 + Vector3.UP * 1.45
	_make_camera(target + camera_offset, target, 40.0)

func _build_resting_hud() -> void:
	for child in ui_root.get_children():
		child.queue_free()

	var vignette := ColorRect.new()
	ui_root.add_child(vignette)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.03, 0.02, 0.015, 0.09)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hud := PanelContainer.new()
	ui_root.add_child(hud)
	hud.position = Vector2(36, 36)
	hud.size = Vector2(370, 155)
	hud.add_theme_stylebox_override(
		"panel",
		_panel_style(
			Color(0.08, 0.055, 0.04, 0.90),
			25,
			2,
			Color(1, 0.83, 0.52, 0.28)
		)
	)

	var margin := MarginContainer.new()
	hud.add_child(margin)
	for key in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + key, 20)

	var stack := VBoxContainer.new()
	margin.add_child(stack)
	stack.add_child(
		_label(
			current_room_name.to_upper(),
			12,
			Color("#e2b95e")
		)
	)
	focus_task_label = _label("RESTING", 18, CREAM)
	stack.add_child(focus_task_label)
	focus_time_label = _label(
		"%02d:%02d" % [
			resting_duration / 60,
			resting_duration % 60
		],
		35,
		CREAM
	)
	stack.add_child(focus_time_label)
	focus_shot_label = _label(
		"RESTING  ·  settling in",
		13,
		Color("#c7b496")
	)
	stack.add_child(focus_shot_label)

	var end := _button("End resting", false)
	ui_root.add_child(end)
	end.position = Vector2(1070, 642)
	end.size = Vector2(170, 48)
	end.pressed.connect(FocusManager.cancel_session)


func _build_focus_hud(task: String) -> void:
	for child in ui_root.get_children():child.queue_free()
	var vignette:=ColorRect.new();ui_root.add_child(vignette);vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);vignette.color=Color(0.03,0.02,0.015,0.13);vignette.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var hud:=PanelContainer.new();ui_root.add_child(hud);hud.position=Vector2(36,36);hud.size=Vector2(370,155);hud.add_theme_stylebox_override("panel",_panel_style(Color(0.08,0.055,0.04,0.90),25,2,Color(1,0.83,0.52,0.28)))
	var margin:=MarginContainer.new();hud.add_child(margin)
	for key in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+key,20)
	var stack:=VBoxContainer.new();margin.add_child(stack)
	stack.add_child(_label(current_room_name.to_upper(),12,Color("#e2b95e")))
	focus_task_label=_label(task if not task.strip_edges().is_empty() else "Quiet focus",18,CREAM);stack.add_child(focus_task_label)
	focus_time_label=_label("25:00",35,CREAM);stack.add_child(focus_time_label)
	focus_shot_label=_label("FOCUS  ·  settling in",13,Color("#c7b496"));stack.add_child(focus_shot_label)
	var end:=_button("End session",false);ui_root.add_child(end);end.position=Vector2(1090,642);end.size=Vector2(150,48);end.pressed.connect(FocusManager.cancel_session)

func _on_focus_tick(remaining: int) -> void:
	if is_instance_valid(focus_time_label):focus_time_label.text="%02d:%02d"%[remaining/60,remaining%60]

func _cycle_focus_camera() -> void:
	var sequence := _build_focus_sequence()

	if sequence.is_empty():
		return

	var to_camera: Camera3D

	for _attempt in sequence.size():
		focus_shot_index = (
			focus_shot_index + 1
		) % sequence.size()

		var candidate := sequence[focus_shot_index]

		var requires_player_visibility := bool(
			candidate.get_meta(
				"requires_player_visibility",
				true
			)
		)

		if (
			not requires_player_visibility
			or active_study_spot == null
			or _is_focus_shot_clear(
				candidate.global_position,
				active_study_spot
			)
		):
			to_camera = candidate
			break

	if not is_instance_valid(to_camera):
		push_warning(
			"All player-facing focus cameras became obstructed; "
			+ "retaining current shot."
		)

		next_shot_at = (
			Time.get_unix_time_from_system()
			+ 5.0
		)

		return

	var from_camera := get_viewport().get_camera_3d()

	focus_camera_director.transition(
		from_camera,
		to_camera,
		0.72
	)

	next_shot_at = (
		Time.get_unix_time_from_system()
		+ 25.0
	)

	if is_instance_valid(focus_shot_label):
		var session_label := (
			"RESTING"
			if active_session_mode == "resting"
			else "FOCUS"
		)
		focus_shot_label.text = (
			"%s  ·  shot %d of %d"
			% [
				session_label,
				focus_shot_index + 1,
				sequence.size()
			]
		)


func _build_focus_sequence() -> Array[Camera3D]:
	var result: Array[Camera3D] = []

	# First: personal, player-visible shots.
	for camera in focus_cameras:
		if is_instance_valid(camera):
			result.append(camera)

	# Then: environment B-roll.
	for camera in _eligible_room_broll():
		if is_instance_valid(camera):
			result.append(camera)

	return result


func _eligible_room_broll() -> Array[Camera3D]:
	var result: Array[Camera3D] = []

	for camera in room_broll_cameras:
		if not is_instance_valid(camera):
			continue

		var shot_name := str(
			camera.get_meta("shot_name", "")
		).to_lower()

		# These old authored cameras were aimed at one particular desk and should
		# not be used when the player chooses a different seat.
		if (
			shot_name.contains("player side")
			or shot_name.contains("over shoulder")
		):
			continue

		result.append(camera)

		# Four room shots is enough variety without overwhelming the personal
		# study framing.
		if result.size() >= 4:
			break

	return result

func _prepare_focus_camera_pool(
	spot,
	report := true
) -> void:
	# Delete only the dynamically generated PERSONAL cameras.
	#
	# Do NOT delete room_broll_cameras. They are authored room/environment
	# compositions and live for the lifetime of the room.
	for camera in focus_cameras:
		if is_instance_valid(camera):
			camera.queue_free()

	focus_cameras.clear()

	focus_candidates_evaluated = 0
	focus_candidates_rejected = 0

	var room_id := str(
		current_room_config.get(
			"id",
			"library"
		)
	)

	var offsets := [
		Vector3(4.15, 2.55, 1.65),
		Vector3(-4.15, 2.50, 1.65),

		Vector3(2.15, 2.55, 4.30),
		Vector3(-2.15, 2.45, 4.10),

		Vector3(1.10, 3.15, 5.25),
		Vector3(-1.10, 3.00, 5.00),

		Vector3(2.75, 3.25, 3.55),
		Vector3(-2.75, 3.15, 3.55),

		Vector3(0.60, 3.75, 4.10),
		Vector3(-0.60, 3.65, 4.10),
	]

	if room_id == "train":
		offsets = [
			Vector3(2.35, 2.65, 2.45),
			Vector3(-2.35, 2.60, 2.45),

			Vector3(1.10, 2.55, 3.85),
			Vector3(-1.10, 2.45, 3.70),

			Vector3(1.75, 2.90, 3.25),
			Vector3(-1.75, 2.80, 3.20),

			Vector3(0.45, 3.35, 3.60),
			Vector3(-0.45, 3.25, 3.55),
		]

	var basis := Basis(
		Vector3.UP,
		spot.facing_yaw
	)

	var forward := (
		basis
		* Vector3.FORWARD
	)

	var right := (
		basis
		* Vector3.RIGHT
	)

	var target: Vector3 = (
		spot.sitting_position
		+ Vector3.UP * 1.48
		+ forward * 0.06
	)

	for index in offsets.size():
		var offset: Vector3 = offsets[index]

		var position: Vector3 = (
			spot.sitting_position
			+ right * offset.x
			+ Vector3.UP * offset.y
			+ forward * offset.z
		)

		focus_candidates_evaluated += 1

		if not _is_focus_shot_clear(
			position,
			spot
		):
			focus_candidates_rejected += 1
			continue

		var camera := _make_camera(
			position,
			target,
			38.0,
			false
		)

		camera.set_meta(
			"shot_name",
			"%s personal angle %d"
			% [
				spot.seat_type.capitalize(),
				index + 1
			]
		)

		camera.set_meta(
			"focus_target",
			target
		)

		camera.set_meta(
			"requires_player_visibility",
			true
		)

		camera.set_meta(
			"room_broll",
			false
		)

		focus_cameras.append(camera)

	if focus_cameras.is_empty():
		push_error(
			"No clear player-facing focus camera found for %s"
			% spot.seat_id
		)

		return


	if report:
		print(
			"FOCUS_POOL room=%s seat=%s personal=%d rejected=%d broll=%d"
			% [
				room_id,
				spot.seat_id,
				focus_cameras.size(),
				focus_candidates_rejected,
				_eligible_room_broll().size()
			]
		)

func _is_focus_shot_clear(camera_position: Vector3, spot) -> bool:
	if spot == null or not is_instance_valid(spot) or not is_inside_tree():
		return false
	var bounds: Vector2 = current_room_config.get("bounds", Vector2(20.0, 15.0))
	if absf(camera_position.x) > bounds.x - 0.35 or absf(camera_position.z) > bounds.y - 0.35:
		return false
	var distance := camera_position.distance_to(spot.sitting_position)
	if distance < 2.6 or distance > 7.5 or camera_position.y < 1.65:
		return false
	var forward := Basis(Vector3.UP, spot.facing_yaw) * Vector3.FORWARD
	var target_points := [
		spot.sitting_position + Vector3.UP * 1.62 + forward * 0.04,
		spot.sitting_position + Vector3.UP * 2.18 + forward * 0.02,
	]
	for target_point in target_points:
		var query := PhysicsRayQueryParameters3D.create(
			camera_position,
			target_point,
			FOCUS_OCCLUSION_MASK
		)
		if player is CollisionObject3D:
			query.exclude = [player.get_rid()]
		var hit: Dictionary = world_root.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			return false
	return true

func _on_focus_completed() -> void:
	if screen != Screen.FOCUS:
		return

	var minutes := roundi(
		float(FocusManager.duration_seconds) / 60.0
	)

	if active_session_mode == "resting":
		_restore_player_standing()
		_transition_back_to_follow_camera()
		active_session_mode = "focus"
		_show_resting_completion(minutes)
		return

	var reward := GameState.award_session(
		FocusManager.task,
		minutes,
		current_room_name
	)
	_restore_player_standing()
	_transition_back_to_follow_camera()
	_show_completion(minutes, reward)

func _on_focus_cancelled() -> void:
	if screen == Screen.FOCUS:
		_restore_player_standing()
		_transition_back_to_follow_camera()
		active_session_mode = "focus"
		await get_tree().create_timer(0.7).timeout
		build_room(GameState.selected_room)

func _transition_back_to_follow_camera() -> void:
	if not is_instance_valid(explore_camera):
		return
	var from_camera := get_viewport().get_camera_3d()
	if is_instance_valid(from_camera):
		focus_camera_director.transition(from_camera, explore_camera, 0.72)

func _restore_player_standing() -> void:
	if not is_instance_valid(player) or not is_instance_valid(player_visual):
		return
	if active_study_spot != null and is_instance_valid(active_study_spot):
		player.global_position = active_study_spot.standing_position
		player.rotation.y = active_study_spot.facing_yaw
		active_study_spot.release("local_player")
		active_study_spot.update_debug(false)
	character_loader.set_seated(player_visual, false)
	player_visual.rotation.x = 0.0
	character_loader.play_animation(player_visual, "Idle")
	player.velocity = Vector3.ZERO
	active_study_spot = null

func _show_resting_completion(minutes: int) -> void:
	var overlay := ColorRect.new()
	ui_root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.05, 0.035, 0.025, 0.72)

	var panel := PanelContainer.new()
	overlay.add_child(panel)
	panel.position = Vector2(370, 165)
	panel.size = Vector2(540, 360)
	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(CREAM, 30, 6, HONEY)
	)

	var margin := MarginContainer.new()
	panel.add_child(margin)
	for key in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + key, 34)

	var stack := VBoxContainer.new()
	margin.add_child(stack)
	stack.add_theme_constant_override("separation", 18)

	var done := _label("Rest complete", 39, INK)
	done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(done)

	var detail := _label(
		"%d minutes resting" % minutes,
		24,
		COCOA
	)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(detail)

	var return_button := _button("Return to the garden", true)
	return_button.custom_minimum_size = Vector2(0, 56)
	return_button.pressed.connect(
		build_room.bind(GameState.selected_room)
	)
	stack.add_child(return_button)

	var places := _button("Choose another place", false)
	places.custom_minimum_size = Vector2(0, 54)
	places.pressed.connect(show_main_menu)
	stack.add_child(places)


func _show_completion(minutes: int, reward: int) -> void:
	var overlay:=ColorRect.new();ui_root.add_child(overlay);overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.color=Color(0.05,0.035,0.025,0.72)
	var panel:=PanelContainer.new();overlay.add_child(panel);panel.position=Vector2(370,145);panel.size=Vector2(540,430);panel.add_theme_stylebox_override("panel",_panel_style(CREAM,30,6,GOLD))
	var margin:=MarginContainer.new();panel.add_child(margin)
	for key in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+key,34)
	var stack:=VBoxContainer.new();margin.add_child(stack);stack.add_theme_constant_override("separation",18)
	var done:=_label("Nice work!",39,INK);done.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;stack.add_child(done)
	var detail:=_label("%d minutes focused\n\n+%d Focus Coins"%[minutes,reward],24,COCOA);detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;stack.add_child(detail)
	var again:=_button("Study again",true);again.custom_minimum_size=Vector2(0,56);again.pressed.connect(build_room.bind(GameState.selected_room));stack.add_child(again)
	var places:=_button("Choose another place",false);places.custom_minimum_size=Vector2(0,54);places.pressed.connect(show_main_menu);stack.add_child(places)

func _add_environment(background: Color, ambient: Color, energy: float) -> void:
	var environment:=WorldEnvironment.new();world_root.add_child(environment)
	var env:=Environment.new();environment.environment=env
	env.background_mode=Environment.BG_COLOR;env.background_color=background;env.background_energy_multiplier=0.75
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=ambient;env.ambient_light_energy=0.28
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.tonemap_exposure=0.72
	env.glow_enabled=true;env.glow_intensity=0.16;env.glow_bloom=0.05
	var sun:=DirectionalLight3D.new();world_root.add_child(sun);sun.rotation_degrees=Vector3(-55,-30,0);sun.light_color=ambient;sun.light_energy=energy;sun.shadow_enabled=true;sun.directional_shadow_max_distance=40
	var fill:=OmniLight3D.new();world_root.add_child(fill);fill.position=Vector3(-5,7,6);fill.light_color=Color("#ffcf94");fill.light_energy=0.68;fill.omni_range=22;fill.shadow_enabled=true

func _make_camera(pos: Vector3, target: Vector3, fov: float, make_current: bool=true) -> Camera3D:
	var cam:=Camera3D.new();world_root.add_child(cam);cam.position=pos;cam.fov=fov;cam.look_at_from_position(pos,target);cam.current=make_current;return cam

func _readable_focus_position(authored_position: Vector3, target: Vector3) -> Vector3:
	var direction := authored_position - target
	if direction.length_squared() < 0.001:
		direction = Vector3(1.0, 0.45, 1.0)
	return target + direction.normalized() * maxf(direction.length(), 6.8)

func _focus_camera(
	pos: Vector3,
	target: Vector3,
	shot_name: String
) -> void:
	var cam := _make_camera(
		pos,
		target,
		36.0,
		false
	)

	cam.set_meta("shot_name", shot_name)

	# Environment B-roll is allowed to show the room without the player.
	cam.set_meta("requires_player_visibility", false)
	cam.set_meta("room_broll", true)

	room_broll_cameras.append(cam)

func _update_camera_current() -> void:
	if is_instance_valid(explore_camera):explore_camera.current=true

func _add_structural_floor(size: Vector2) -> void:
	var floor = RoomFloorScript.new()
	world_root.add_child(floor)
	floor.configure(size, 0.0)

func _create_follow_camera() -> void:
	follow_camera_rig = FollowCameraScript.new()
	follow_camera_rig.name = "FollowCameraRig"
	world_root.add_child(follow_camera_rig)
	explore_camera = follow_camera_rig.setup(player, current_room_config)
	if player is PlayerController:
		player.set_movement_camera(explore_camera)

func _add_world_boundaries(extents: Vector2) -> void:
	for data in [[Vector3(extents.x+0.3,1.5,0),Vector3(0.4,3.0,extents.y*2.0)],[Vector3(-extents.x-0.3,1.5,0),Vector3(0.4,3.0,extents.y*2.0)],[Vector3(0,1.5,extents.y+0.3),Vector3(extents.x*2.0,3.0,0.4)],[Vector3(0,1.5,-extents.y-0.3),Vector3(extents.x*2.0,3.0,0.4)]]:
		var body:=StaticBody3D.new();world_root.add_child(body);body.position=data[0];body.collision_layer=1;body.collision_mask=0
		var cs:=CollisionShape3D.new();body.add_child(cs);var shape:=BoxShape3D.new();shape.size=data[1];cs.shape=shape
		_add_collision_debug_mesh(body, data[1])

func _add_blocker(pos: Vector3, size: Vector3, yaw := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "MajorFurnitureCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	body.rotation.y = yaw
	world_root.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	_add_collision_debug_mesh(body, size)
	return body

func _add_collision_debug_mesh(parent: Node3D, size: Vector3) -> void:
	var debug_mesh := MeshInstance3D.new()
	debug_mesh.name = "CollisionDebug"
	debug_mesh.add_to_group("collision_debug")
	var mesh := BoxMesh.new()
	mesh.size = size + Vector3.ONE * 0.025
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.1, 0.9, 0.45, 0.23)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	debug_mesh.mesh = mesh
	debug_mesh.visible = false
	parent.add_child(debug_mesh)

func _place_local_prop(
	asset_id: String,
	fallback_path: String,
	pos: Vector3,
	scale_value: Vector3,
	yaw := 0.0
) -> Node3D:
	var holder: Node3D = asset_loader.instantiate_prop(
		asset_id,
		fallback_path
	)

	if holder.get_child_count() == 0:
		holder.queue_free()

		# Public fallback only.
		# The local-development build should normally resolve the supplied asset.
		match asset_id:
			"oak_trees_museum":
				_build_tree(pos, scale_value.x)

			"potted_spring_flowers":
				_build_plant(pos, scale_value.x)

			"coffee_mug":
				_cylinder(
					world_root,
					0.13 * scale_value.x,
					0.26 * scale_value.y,
					pos + Vector3(
						0,
						0.13 * scale_value.y,
						0
					),
					mats.teal,
					20
				)

		return holder

	world_root.add_child(holder)

	# The holder is ROOM placement only.
	# The AssetLoader's inner AssetTransform retains manifest corrections.
	holder.position = pos
	holder.rotation.y = yaw
	holder.scale = scale_value

	# Treat the authored Y as the supporting surface for ordinary floor and
	# tabletop props. This fixes inconsistent source pivots without flattening
	# intentional wall placement. Near the structural floor, snap the support
	# target to exactly Y=0 so tiny 2-5 cm authoring offsets cannot read as
	# floating from the gameplay camera.
	if not _skip_visual_grounding(asset_id):
		_ground_prop_to_surface(holder, _grounding_target_y(pos.y))

	# Large visible props need to participate in camera obstruction even when
	# they intentionally have no gameplay collider.
	_add_camera_occluder_from_visual(holder)
	_add_gameplay_blocker_from_visual(holder, asset_id)

	return holder


func _grounding_target_y(authored_y: float) -> float:
	return 0.0 if absf(authored_y) <= 0.08 else authored_y


func _skip_visual_grounding(tag: String) -> bool:
	var token := tag.to_lower()
	# These are intentionally positioned by their centre/attachment point or
	# need an explicitly authored vertical level rather than a support surface.
	return (
		token.contains("corkboard")
		or token.contains("pendulum_clock")
		or token.contains("wall_lamp")
		or token.contains("water_surface")
	)


func _ground_prop_to_surface(holder: Node3D, target_y: float) -> void:
	var bounds_result := _combined_world_aabb(holder)

	if not bool(bounds_result.get("valid", false)):
		return

	var bounds: AABB = bounds_result["aabb"]

	var bottom_y := bounds.position.y
	var correction := target_y - bottom_y

	# Refuse insane corrections caused by corrupt source bounds.
	if absf(correction) > 4.0:
		push_warning(
			"Skipping suspicious grounding correction %.2f for %s"
			% [correction, holder.name]
		)
		return

	holder.global_position.y += correction


func _add_camera_occluder_from_visual(holder: Node3D) -> void:
	if not is_instance_valid(holder):
		return

	var bounds_result := _combined_world_aabb(holder)

	if not bool(bounds_result.get("valid", false)):
		return

	var bounds: AABB = bounds_result["aabb"]

	if not _should_create_camera_occluder(holder, bounds):
		return

	var body := StaticBody3D.new()
	body.name = "CameraOccluder_%s" % str(
		holder.get_meta("asset_id", holder.name)
	)

	body.collision_layer = CAMERA_OCCLUDER_LAYER
	body.collision_mask = 0

	world_root.add_child(body)

	var shape_node := CollisionShape3D.new()
	body.add_child(shape_node)

	var box_shape := BoxShape3D.new()

	# Slightly contract the visual bounds so an object only blocks the camera
	# when it genuinely occupies the sight line.
	box_shape.size = Vector3(
		maxf(bounds.size.x * 0.90, 0.05),
		maxf(bounds.size.y * 0.94, 0.05),
		maxf(bounds.size.z * 0.90, 0.05)
	)

	shape_node.shape = box_shape
	body.global_position = bounds.get_center()


func _should_create_camera_occluder(
	holder: Node3D,
	bounds: AABB
) -> bool:
	var asset_id := str(
		holder.get_meta("asset_id", "")
	).to_lower()

	# These are small storytelling props. They should never make a cinematic
	# camera invalid.
	var small_prop_tokens := [
		"mug",
		"cup",
		"book",
		"phone",
		"clock",
		"flower",
		"plant",
		"bag",
		"basket",
		"fossil",
		"figurine",
		"fan",
		"grinder",
		"juice",
		"tea",
		"donut",
		"sandwich"
	]

	for token in small_prop_tokens:
		if asset_id.contains(token):
			return false

	# Only substantial visual objects need camera-only collision.
	var large_horizontal := maxf(
		bounds.size.x,
		bounds.size.z
	) >= 1.45

	var tall := bounds.size.y >= 1.65

	return large_horizontal or tall


func _combined_world_aabb(root: Node) -> Dictionary:
	var meshes: Array[MeshInstance3D] = []
	_collect_mesh_instances(root, meshes)

	if meshes.is_empty():
		return {
			"valid": false,
			"aabb": AABB()
		}

	var found := false
	var result := AABB()

	for mesh_instance in meshes:
		if not is_instance_valid(mesh_instance):
			continue

		if mesh_instance.mesh == null:
			continue

		var local_bounds := mesh_instance.get_aabb()
		var world_bounds: AABB = (
			mesh_instance.global_transform
			* local_bounds
		)

		if not found:
			result = world_bounds
			found = true
		else:
			result = result.merge(world_bounds)

	return {
		"valid": found,
		"aabb": result
	}

func _collect_gameplay_bounds(node: Node, state: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D

		if mesh_instance.mesh != null:
			var local_bounds: AABB = mesh_instance.mesh.get_aabb()
			var minimum := local_bounds.position
			var maximum := local_bounds.end

			var corners := [
				Vector3(minimum.x, minimum.y, minimum.z),
				Vector3(maximum.x, minimum.y, minimum.z),
				Vector3(minimum.x, maximum.y, minimum.z),
				Vector3(maximum.x, maximum.y, minimum.z),
				Vector3(minimum.x, minimum.y, maximum.z),
				Vector3(maximum.x, minimum.y, maximum.z),
				Vector3(minimum.x, maximum.y, maximum.z),
				Vector3(maximum.x, maximum.y, maximum.z),
			]

			for corner in corners:
				var world_point: Vector3 = mesh_instance.global_transform * corner

				if not bool(state.get("has_bounds", false)):
					state["bounds"] = AABB(world_point, Vector3.ZERO)
					state["has_bounds"] = true
				else:
					var current_bounds: AABB = state["bounds"]
					current_bounds = current_bounds.expand(world_point)
					state["bounds"] = current_bounds

	for child in node.get_children():
		_collect_gameplay_bounds(child, state)


func _gameplay_world_aabb(root: Node) -> AABB:
	var state := {
		"has_bounds": false,
		"bounds": AABB(),
	}

	_collect_gameplay_bounds(root, state)

	var result: AABB = state["bounds"]
	return result


func _add_gameplay_blocker_from_visual(holder: Node3D, tag := "") -> void:
	if not is_instance_valid(holder):
		return

	var bounds: AABB = _gameplay_world_aabb(holder)

	if bounds.size.length_squared() <= 0.0001:
		return

	var token := str(tag).to_lower()

	# Decorative/tabletop objects do not need player collision.
	for small_token in [
		"mug",
		"cup",
		"book",
		"phone",
		"flower",
		"weed",
		"grass",
		"tuft",
		"juice",
		"tea",
		"donut",
		"sandwich",
		"laptop",
		"figurine",
		"clock",
		"basket",
	]:
		if token.contains(small_token):
			return

	# These are either deliberately walkable/flat or already have authored
	# furniture collision elsewhere.
	for handled_token in [
		"rug",
		"water_surface",
		"floor_cushion",
		"train_bench",
		"japanese_low_table",
		"armchair",
		"chair",
	]:
		if token.contains(handled_token):
			return

	var horizontal_max := maxf(bounds.size.x, bounds.size.z)

	# Skip objects too small/low to reasonably block the player.
	if bounds.size.y < 0.45:
		return

	if horizontal_max < 0.75:
		return

	var blocker_size := Vector3(
		maxf(bounds.size.x * 0.72, 0.55),
		clampf(bounds.size.y, 0.60, 2.40),
		maxf(bounds.size.z * 0.72, 0.55)
	)

	# Tree collision should represent the trunk rather than the whole canopy.
	if token.contains("tree") or token.contains("palm"):
		blocker_size.x = clampf(bounds.size.x * 0.28, 0.75, 1.35)
		blocker_size.z = clampf(bounds.size.z * 0.28, 0.75, 1.35)
		blocker_size.y = clampf(bounds.size.y, 1.20, 2.40)

	# Large solid props should block most of their visible footprint.
	elif token.contains("fountain"):
		blocker_size.x = maxf(bounds.size.x * 0.90, 0.80)
		blocker_size.z = maxf(bounds.size.z * 0.90, 0.80)

	elif token.contains("tent"):
		blocker_size.x = maxf(bounds.size.x * 0.82, 0.80)
		blocker_size.z = maxf(bounds.size.z * 0.82, 0.80)

	var blocker_center := bounds.position + bounds.size * 0.5

	# Anchor collision upward from the bottom of the visual.
	blocker_center.y = bounds.position.y + blocker_size.y * 0.5

	var body := StaticBody3D.new()
	body.name = "GameplayBlocker_%s" % str(tag).replace(" ", "_")
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("gameplay_prop_blocker", true)

	world_root.add_child(body)
	body.global_position = blocker_center

	var collision := CollisionShape3D.new()
	body.add_child(collision)

	var shape := BoxShape3D.new()
	shape.size = blocker_size
	collision.shape = shape


func _collect_mesh_instances(
	node: Node,
	result: Array[MeshInstance3D]
) -> void:
	if node is MeshInstance3D:
		result.append(node)

	for child in node.get_children():
		_collect_mesh_instances(child, result)

func _box(parent: Node, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var node:=MeshInstance3D.new();parent.add_child(node);var mesh:=BoxMesh.new();mesh.size=size;mesh.material=material;node.mesh=mesh;node.position=pos;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON;return node

func _sphere(parent: Node, scale_value: Vector3, pos: Vector3, material: Material, radial: int=24, rings: int=14) -> MeshInstance3D:
	var node:=MeshInstance3D.new();parent.add_child(node);var mesh:=SphereMesh.new();mesh.radius=1.0;mesh.height=2.0;mesh.radial_segments=radial;mesh.rings=rings;mesh.material=material;node.mesh=mesh;node.scale=scale_value;node.position=pos;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON;return node

func _cylinder(parent: Node, radius: float, height: float, pos: Vector3, material: Material, radial: int=24) -> MeshInstance3D:
	var node:=MeshInstance3D.new();parent.add_child(node);var mesh:=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=height;mesh.radial_segments=radial;mesh.material=material;node.mesh=mesh;node.position=pos;return node

func _capsule_mesh(parent: Node, radius: float, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var node:=MeshInstance3D.new();parent.add_child(node);var mesh:=CapsuleMesh.new();mesh.radius=radius;mesh.height=maxf(height,radius*2.05);mesh.radial_segments=20;mesh.rings=8;mesh.material=material;node.mesh=mesh;node.position=pos;return node

func _cone(parent: Node, radius: float, height: float, pos: Vector3, material: Material, radial: int=16) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	parent.add_child(node)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.02
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = radial
	mesh.rings = 2
	mesh.material = material
	node.mesh = mesh
	node.position = pos
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func _import_prop(
	path: String,
	pos: Vector3,
	scale_value: Vector3,
	yaw: float = 0.0
) -> Node3D:
	var holder := Node3D.new()
	holder.name = "ImportedProp_%s" % path.get_file().get_basename()

	world_root.add_child(holder)

	holder.position = pos
	holder.scale = scale_value
	holder.rotation.y = yaw

	if ResourceLoader.exists(path):
		var resource: Resource = load(path)

		if resource is PackedScene:
			var packed_scene: PackedScene = resource as PackedScene
			var instance: Node = packed_scene.instantiate()
			holder.add_child(instance)

	if holder.get_child_count() > 0:
		var prop_tag := path.get_file().get_basename()

		# Generated furniture, rugs and ordinary external props should use their
		# actual rendered bounds rather than trusting arbitrary model pivots.
		# Authored Y is interpreted as the support surface. Wall-mounted assets
		# and animated water surfaces intentionally keep their explicit height.
		if not _skip_visual_grounding(prop_tag):
			_ground_prop_to_surface(holder, _grounding_target_y(pos.y))

		# Most generated furniture already has explicit authored blockers. The
		# generated fountain does not, so create one from its visible bounds.
		if prop_tag.to_lower().contains("fountain"):
			_add_gameplay_blocker_from_visual(holder, prop_tag)

	return holder

func _override_mesh_material(root: Node, material: Material) -> void:
	if root is MeshInstance3D:
		root.material_override = material
	for child in root.get_children():
		_override_mesh_material(child, material)

func _panel_style(color: Color, radius: int, border_width: int=0, border_color: Color=Color.TRANSPARENT) -> StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=color
	style.corner_radius_top_left=radius;style.corner_radius_top_right=radius;style.corner_radius_bottom_left=radius;style.corner_radius_bottom_right=radius
	style.border_width_left=border_width;style.border_width_right=border_width;style.border_width_top=border_width;style.border_width_bottom=border_width;style.border_color=border_color
	style.content_margin_left=16;style.content_margin_right=16;style.content_margin_top=10;style.content_margin_bottom=10
	style.shadow_color=Color(0.08,0.04,0.02,0.25);style.shadow_size=7;style.shadow_offset=Vector2(0,4)
	return style

func _label(text_value: String,size_value: int,color: Color) -> Label:
	var label:=Label.new();label.text=text_value;label.add_theme_font_size_override("font_size",size_value);label.add_theme_color_override("font_color",color);return label

func _button(text_value: String,selected: bool) -> Button:
	var b:=Button.new();b.text=text_value;b.add_theme_font_size_override("font_size",16);b.add_theme_color_override("font_color",INK);b.add_theme_color_override("font_hover_color",INK);b.add_theme_color_override("font_pressed_color",INK)
	b.add_theme_stylebox_override("normal",_panel_style(HONEY if selected else Color("#f4e3bf"),16,2,WOOD if selected else Color("#d8bd88")))
	b.add_theme_stylebox_override("hover",_panel_style(Color("#ffd681"),16,3,HONEY));b.add_theme_stylebox_override("pressed",_panel_style(Color("#e9ae4c"),16,3,WOOD));return b

func _separator() -> HSeparator:
	var sep:=HSeparator.new();sep.add_theme_constant_override("separation",10);sep.modulate=Color("#d8bd88");return sep

func _pill(text_value: String,pos: Vector2) -> Label:
	var label:=_label(text_value,14,CREAM);label.position=pos;label.size=Vector2(310,46);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.add_theme_stylebox_override("normal",_panel_style(Color(0.09,0.065,0.05,0.88),20,1,Color(1,0.85,0.56,0.20)));return label

func _show_toast(message: String) -> void:
	if not is_instance_valid(ui_root):return
	var toast:=_pill(message,Vector2(465,555));ui_root.add_child(toast);toast.name="Toast"
	var tween:=create_tween();tween.tween_interval(1.5);tween.tween_property(toast,"modulate:a",0.0,0.35);tween.tween_callback(toast.queue_free)
