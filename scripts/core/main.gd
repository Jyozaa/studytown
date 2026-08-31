extends Node

enum Screen { MENU, ROOM, FOCUS }

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
var player: CharacterBody3D
var player_visual: Node3D
var explore_camera: Camera3D
var focus_cameras: Array[Camera3D] = []
var study_spots: Array[Dictionary] = []
var npcs: Array[Node3D] = []
var prompt_label: Label
var debug_label: Label
var coins_label: Label
var focus_time_label: Label
var focus_task_label: Label
var focus_shot_label: Label
var debug_spots_visible := false
var focus_shot_index := 0
var next_shot_at := 0.0
var nearest_spot := -1
var movement_enabled := true
var selected_duration := 25 * 60
var task_input: LineEdit
var current_room_name := "Grand Library"
var player_parts: Dictionary = {}
var walk_phase := 0.0
var wave_time := 0.0
var menu_character: Node3D

var mats := {}

func _ready() -> void:
	seed(1207)
	_build_materials()
	FocusManager.tick.connect(_on_focus_tick)
	FocusManager.completed.connect(_on_focus_completed)
	FocusManager.cancelled.connect(_on_focus_cancelled)
	var review := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("review="): review = arg.trim_prefix("review=")
		elif arg.begins_with("--review="): review = arg.trim_prefix("--review=")
	match review:
		"library": current_room_name = GameState.ROOMS[0]; build_room(0)
		"focus": current_room_name = GameState.ROOMS[0]; build_room(0); call_deferred("_begin_review_focus")
		"garden": current_room_name = GameState.ROOMS[1]; build_room(1)
		"train": current_room_name = GameState.ROOMS[2]; build_room(2)
		"japanese": current_room_name = GameState.ROOMS[3]; build_room(3)
		"character_front": _build_character_review(PI, false)
		"character_three_quarter": _build_character_review(PI + 0.62, false)
		"character_side": _build_character_review(PI + PI / 2.0, false)
		"character_back": _build_character_review(0.0, false)
		"character_sitting": _build_character_review(PI + 0.32, true)
		_: show_main_menu()

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
		["grass", Color("#4ea85e"), 0.9, 0.0], ["leaf", Color("#287847"), 0.88, 0.0],
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

func _clear_scene() -> void:
	if is_instance_valid(world_root):
		world_root.queue_free()
	if is_instance_valid(ui_root):
		ui_root.queue_free()
	world_root = Node3D.new()
	world_root.name = "World"
	add_child(world_root)
	ui_root = CanvasLayer.new()
	ui_root.name = "Interface"
	add_child(ui_root)
	study_spots.clear()
	npcs.clear()
	focus_cameras.clear()
	player_parts.clear()
	nearest_spot = -1

func show_main_menu() -> void:
	screen = Screen.MENU
	movement_enabled = false
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
	menu_character.scale = Vector3.ONE * 1.22
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

func _build_character_review(yaw: float, seated: bool) -> void:
	screen = Screen.MENU
	_clear_scene()
	_add_environment(Color("#b98f78"), Color("#fff0ce"), 0.82)
	_cylinder(world_root, 2.0, 0.34, Vector3(0, -0.17, 0), mats.cream, 48)
	var character := _create_character(world_root, 0, seated)
	character.rotation.y = yaw
	if seated:
		_build_armchair(Vector3(0, 0, 0.22), PI, mats.teal)
		character.position = Vector3(0, 0.08, -0.03)
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
	var char_names := ["Milo", "Rowan", "Nia"]
	for i in 3:
		var b := _button(char_names[i], i == GameState.selected_character)
		b.custom_minimum_size = Vector2(104, 52)
		b.pressed.connect(_select_character.bind(i))
		chars.add_child(b)
	stack.add_child(_label("Where do you want to focus?", 20, INK))
	var room_names := ["Grand Library", "Garden Café", "Scenic Train", "Japanese Study Room"]
	var descriptors := ["Warm & bookish  ·  8 studying", "Sunny & leafy  ·  6 studying", "Mountain views  ·  7 studying", "Quiet & serene  ·  5 studying"]
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
	movement_enabled = true
	_clear_scene()
	match index:
		0: _build_library()
		1: _build_garden()
		2: _build_train()
		3: _build_japanese_room()
	_create_player()
	_build_room_ui()
	_update_camera_current()

func _process(delta: float) -> void:
	if is_instance_valid(menu_character):
		menu_character.rotation.y = PI + sin(Time.get_ticks_msec() * 0.0005) * 0.18
	if screen == Screen.ROOM:
		_update_nearest_spot()
		_animate_npcs(delta)
	if screen == Screen.FOCUS and Time.get_unix_time_from_system() >= next_shot_at:
		_cycle_focus_camera()
	if wave_time > 0.0:
		wave_time -= delta
		if player_parts.has("arm_r"):
			player_parts.arm_r.rotation.z = -1.9 + sin(wave_time * 11.0) * 0.28
	elif player_parts.has("arm_r") and screen != Screen.FOCUS:
		player_parts.arm_r.rotation.z = lerpf(player_parts.arm_r.rotation.z, -0.08, delta * 8.0)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or not movement_enabled or screen != Screen.ROOM:
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input.x, 0, input.y)
	var target := direction.normalized() * 4.25
	player.velocity.x = move_toward(player.velocity.x, target.x, 18.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, target.z, 18.0 * delta)
	player.velocity.y = -0.5
	if direction.length_squared() > 0.01:
		var target_yaw := atan2(-direction.x, -direction.z)
		player.rotation.y = lerp_angle(player.rotation.y, target_yaw, 10.0 * delta)
		walk_phase += delta * 9.5
		_animate_walk(sin(walk_phase) * 0.55)
	else:
		walk_phase += delta * 2.0
		_animate_idle(delta)
	player.move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		if screen == Screen.MENU:
			return
		if screen == Screen.FOCUS:
			FocusManager.cancel_session()
		show_main_menu()
	elif event.is_action_pressed("interact") and screen == Screen.ROOM and nearest_spot >= 0:
		_open_focus_setup(nearest_spot)
	elif event.is_action_pressed("wave") and screen == Screen.ROOM:
		wave_time = 1.45
		_show_toast("You wave.  Jamie waves back!  👋")
	elif event.is_action_pressed("debug_spots") and screen == Screen.ROOM:
		debug_spots_visible = not debug_spots_visible
		_set_debug_spots(debug_spots_visible)
	elif event.is_action_pressed("debug_focus") and screen == Screen.ROOM:
		selected_duration = 10
		_open_focus_setup(maxi(nearest_spot, 0))
	elif event.is_action_pressed("debug_overlay"):
		if is_instance_valid(debug_label):
			debug_label.visible = not debug_label.visible

func _create_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	world_root.add_child(player)
	player.position = Vector3(0, 0.1, 3.2) if GameState.selected_room != 2 else Vector3(0, 0.1, 4.0)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.43
	capsule.height = 1.85
	shape.shape = capsule
	shape.position.y = 0.93
	player.add_child(shape)
	player_visual = _create_character(player, GameState.selected_character, false)
	player_parts = player_visual.get_meta("parts")
	var label := Label3D.new()
	player.add_child(label)
	label.text = "YOU"
	label.position = Vector3(0, 2.9, 0)
	label.font_size = 30
	label.outline_size = 8
	label.modulate = CREAM
	label.outline_modulate = Color(0.08, 0.05, 0.04, 0.85)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED

func _create_character(parent: Node, variant: int, seated: bool) -> Node3D:
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
	# Thick architectural shell and patterned floor.
	_box(world_root, Vector3(18.6, 0.35, 13.6), Vector3(0, -0.22, 0), mats.wood)
	for x in range(-8, 9, 2):
		for z in range(-6, 7, 2):
			var tile := _box(world_root, Vector3(1.82, 0.018, 1.82), Vector3(x, -0.025, z), mats.honey if (x + z) % 4 == 0 else mats.cocoa)
			tile.rotation.y = PI / 4.0
	_box(world_root, Vector3(19, 5.4, 0.45), Vector3(0, 2.55, -6.65), mats.cream)
	_box(world_root, Vector3(0.45, 5.4, 13.5), Vector3(-9.25, 2.55, 0), mats.cream)
	# Camera-facing wall is a low cutaway with thick trim so the player stays readable.
	_box(world_root, Vector3(0.45, 0.75, 13.5), Vector3(9.25, 0.24, 0), mats.cream)
	# Lower moulding and roof beams anchor the walls.
	for z in [-6.39, 6.39]:
		_box(world_root, Vector3(18.7, 0.26, 0.32), Vector3(0, 0.28, z), mats.cocoa)
	for x in [-9.02, 9.02]:
		_box(world_root, Vector3(0.30, 0.26, 13.0), Vector3(x, 0.28, 0), mats.cocoa)

	# Four tall arched windows; panes and mullions create depth without texture dependence.
	for x in [-7.0, -2.35, 2.35, 7.0]:
		_build_window(Vector3(x, 2.85, -6.40), Vector2(3.35, 3.45), false)
	# Built-in shelves wrap both side walls and frame the fireplace.
	for z in [-4.45, -1.45, 1.55, 4.55]:
		_build_bookshelf(Vector3(-8.72, 2.35, z), -PI / 2.0, 2.65, 4.45, 0.48, int(z * 10.0 + 80.0))
		_build_bookshelf(Vector3(8.72, 2.35, z), PI / 2.0, 2.65, 4.45, 0.48, int(z * 10.0 + 170.0))
	_build_bookshelf(Vector3(-6.55, 2.25, -6.2), PI, 2.8, 4.25, 0.52, 4)
	_build_bookshelf(Vector3(6.55, 2.25, -6.2), PI, 2.8, 4.25, 0.52, 18)
	_build_fireplace(Vector3(0, 0, -6.28))

	# Central reading carpet and authored furniture groups.
	_box(world_root, Vector3(9.8, 0.045, 6.5), Vector3(0, 0.04, 0.55), mats.red)
	for x in [-3.25, 3.25]:
		for z in [-2.25, 1.25]:
			_build_study_table(Vector3(x, 0, z), x < 0)
			_add_study_spot(Vector3(x, 0, z + 1.15), Vector3(x, 0.05, z + 0.72), 0.0, "Laptop", Vector3(x + (5.4 if x < 0 else -5.4), 3.15, z + 4.0), Vector3(x, 1.30, z + 0.10))
	# Reading nook provides foreground layering.
	_build_armchair(Vector3(-6.25, 0, 4.65), -0.55, mats.teal)
	_build_armchair(Vector3(-4.65, 0, 5.15), 0.25, mats.gold)
	_cylinder(world_root, 0.72, 0.62, Vector3(-5.45, 0.31, 4.15), mats.wood, 32)
	_import_prop("res://assets/external/kenney_furniture_kit/plantSmall1.glb", Vector3(-5.45, 0.65, 4.15), Vector3.ONE * 0.72)
	_build_globe(Vector3(6.9, 0, 4.55))
	_build_plant(Vector3(7.8, 0, 5.35), 1.25)
	_build_plant(Vector3(-7.95, 0, 5.35), 1.08)
	for pos in [Vector3(-1.0,0,4.7), Vector3(1.0,0,4.7)]:
		_build_armchair(pos, 0.0, mats.green)

	# Seated population uses the same master proportions and explicit anchors.
	var npc_positions := [
		[Vector3(-3.25, 0.05, -1.53), 0, 1, "Jamie", "18m"],
		[Vector3(3.25, 0.05, -1.53), 0, 2, "Nora", "42m"],
		[Vector3(-3.25, 0.05, 1.97), 0, 2, "Kai", "26m"],
		[Vector3(3.25, 0.05, 1.97), 0, 1, "Sora", "51m"],
		[Vector3(-6.25, 0.05, 4.65), -0.55, 0, "Eli", "12m"],
		[Vector3(1.0, 0.05, 4.7), 0, 2, "Mina", "33m"],
	]
	for data in npc_positions:
		_create_npc(data[0], data[1], data[2], data[3], data[4], true)

	explore_camera = _make_camera(Vector3(13.4, 12.5, 14.3), Vector3(-0.2, 1.0, -0.4), 39.0)
	_focus_camera(Vector3(10.8, 7.0, 9.8), Vector3(0, 1.0, 0), "Wide room")
	_focus_camera(Vector3(-6.6, 3.3, 4.2), Vector3(-3.2, 1.2, 0.5), "Bookshelf foreground")
	_focus_camera(Vector3(5.6, 2.8, 4.8), Vector3(3.1, 1.15, 0.4), "Quiet side profile")
	_focus_camera(Vector3(0.2, 3.0, -2.8), Vector3(0, 1.65, -6.1), "Fireplace glow")
	_focus_camera(Vector3(-1.4, 2.5, 0.6), Vector3(3.2, 1.15, 1.1), "Across the desks")
	_focus_camera(Vector3(7.8, 4.2, -2.6), Vector3(2.3, 2.1, -6.2), "Window composition")
	_add_world_boundaries(Vector2(8.0, 5.6))

func _build_bookshelf(pos: Vector3, yaw: float, width: float, height: float, depth: float, book_seed: int) -> void:
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

func _build_study_table(pos: Vector3, flip: bool) -> void:
	var root := Node3D.new(); world_root.add_child(root); root.position = pos
	_box(root, Vector3(3.65, 0.24, 1.55), Vector3(0, 1.05, 0), mats.wood)
	_box(root, Vector3(3.9, 0.09, 1.72), Vector3(0, 1.20, 0), mats.honey)
	for x in [-1.5, 1.5]:
		for z in [-0.55, 0.55]:
			_capsule_mesh(root, 0.12, 1.0, Vector3(x, 0.51, z), mats.cocoa)
	_import_prop("res://assets/external/kenney_furniture_kit/lampRoundTable.glb", pos + Vector3(0.55 if flip else -0.55, 1.23, 0), Vector3.ONE * 0.65)
	_import_prop("res://assets/external/kenney_furniture_kit/laptop.glb", pos + Vector3(-0.55 if flip else 0.55, 1.26, -0.08), Vector3.ONE * 0.82, PI)
	_build_chair(pos + Vector3(0, 0, 1.14), PI)
	_build_chair(pos + Vector3(0, 0, -1.14), 0)
	# Deliberately composed paper, mug and book stack.
	_box(world_root, Vector3(0.50, 0.035, 0.68), pos + Vector3(-1.15, 1.29, 0.08), mats.paper).rotation.y = 0.12
	_cylinder(world_root, 0.17, 0.28, pos + Vector3(1.35, 1.38, 0.12), mats.teal, 24)
	for i in 3:
		_box(world_root, Vector3(0.55 + i * 0.04, 0.10, 0.38), pos + Vector3(1.18, 1.29 + i * 0.10, -0.42), [mats.red, mats.blue, mats.green][i])

func _build_chair(pos: Vector3, yaw: float) -> void:
	var root := Node3D.new(); world_root.add_child(root); root.position = pos; root.rotation.y = yaw
	_box(root, Vector3(0.95, 0.18, 0.92), Vector3(0, 0.72, 0), mats.teal)
	var back := _sphere(root, Vector3(0.54, 0.72, 0.15), Vector3(0, 1.25, 0.39), mats.teal, 24, 16)
	back.rotation.x = -0.12
	for x in [-0.36, 0.36]:
		for z in [-0.34, 0.34]:
			_capsule_mesh(root, 0.09, 0.72, Vector3(x, 0.35, z), mats.cocoa)

func _build_armchair(pos: Vector3, yaw: float, fabric: Material) -> void:
	var root := Node3D.new(); world_root.add_child(root); root.position = pos; root.rotation.y = yaw
	_sphere(root, Vector3(0.85, 0.34, 0.78), Vector3(0, 0.53, 0), fabric, 28, 16)
	_sphere(root, Vector3(0.88, 0.83, 0.30), Vector3(0, 1.14, 0.44), fabric, 28, 16)
	for x in [-0.78, 0.78]: _sphere(root, Vector3(0.23, 0.32, 0.72), Vector3(x, 0.72, 0), fabric, 20, 12)
	for x in [-0.55, 0.55]: _capsule_mesh(root, 0.10, 0.44, Vector3(x, 0.20, 0.36), mats.cocoa)

func _build_globe(pos: Vector3) -> void:
	_cylinder(world_root, 0.48, 0.18, pos + Vector3(0, 0.09, 0), mats.cocoa, 28)
	_capsule_mesh(world_root, 0.08, 1.45, pos + Vector3(0, 0.74, 0), mats.gold)
	_sphere(world_root, Vector3(0.70, 0.70, 0.70), pos + Vector3(0, 1.48, 0), mats.blue, 32, 20)
	for x in [-0.28, 0.25]: _sphere(world_root, Vector3(0.23, 0.09, 0.10), pos + Vector3(x, 1.5, -0.64), mats.green, 18, 10)

func _build_garden() -> void:
	_add_environment(Color("#81cde0"), Color("#fff3bf"), 1.2)
	_box(world_root, Vector3(20, 0.35, 14), Vector3(0, -0.22, 0), mats.grass)
	# Curved-feeling stone path from overlapping rounded pavers.
	for i in 13:
		var x := sin(i * 0.38) * 1.1
		_sphere(world_root, Vector3(1.25, 0.08, 0.75), Vector3(x, 0.01, 6.0 - i), mats.stone, 20, 10)
	# Café pavilion and awning.
	_box(world_root, Vector3(8.2, 0.28, 3.7), Vector3(0, 0.06, -4.8), mats.cream)
	for x in [-4.0, 4.0]:
		for z in [-6.2, -3.35]: _capsule_mesh(world_root, 0.15, 3.6, Vector3(x, 1.8, z), mats.wood)
	_box(world_root, Vector3(8.8, 0.28, 4.2), Vector3(0, 3.55, -4.8), mats.honey)
	for x in range(-4, 5):
		_box(world_root, Vector3(0.48, 0.04, 4.1), Vector3(x, 3.72, -4.8), mats.red if x % 2 == 0 else mats.cream)
	for x in [-5.8, 5.8]:
		for z in [-4.8, 0.0, 4.4]: _build_tree(Vector3(x, 0, z), 1.0 + fmod(abs(x + z), 3.0) * 0.08)
	for x in [-7.7, -3.6, 3.6, 7.7]:
		_build_bush(Vector3(x, 0, 5.8), 1.0)
	# Café study islands.
	for data in [[Vector3(-3.0,0,-1.1),mats.teal],[Vector3(3.0,0,-1.1),mats.gold],[Vector3(-3.2,0,3.2),mats.coral],[Vector3(3.2,0,3.2),mats.green]]:
		_build_cafe_table(data[0], data[1])
		_add_study_spot(data[0] + Vector3(0,0,1.15), data[0] + Vector3(0,0.05,0.68), 0.0, "Laptop", data[0] + Vector3(0,2.3,4.3), data[0] + Vector3(0,1.0,0))
	for data in [[Vector3(-3,0.05,-0.42),1,"Lumi","20m"],[Vector3(3,0.05,-0.42),2,"Ben","37m"],[Vector3(-3.2,0.05,3.88),0,"Aya","16m"],[Vector3(3.2,0.05,3.88),1,"Theo","48m"]]:
		_create_npc(data[0],0,data[1],data[2],data[3],true)
	explore_camera = _make_camera(Vector3(15.5, 14.0, 17.0), Vector3(0, 0.8, -0.3), 41.0)
	_focus_camera(Vector3(11, 7, 10), Vector3(0, 1, 0), "Garden wide")
	_focus_camera(Vector3(-5, 3.2, 4.0), Vector3(-3, 1, -1), "Among the flowers")
	_focus_camera(Vector3(5.0, 2.8, 4.5), Vector3(3, 1, 2.9), "Café table")
	_focus_camera(Vector3(0, 3.5, -0.4), Vector3(0, 1.5, -4.8), "Striped pavilion")
	_add_world_boundaries(Vector2(8.4, 5.8))

func _build_train() -> void:
	_add_environment(Color("#7bc1dc"), Color("#f8e6ba"), 0.95)
	_box(world_root, Vector3(8.2, 0.35, 16), Vector3(0, -0.22, 0), mats.cream)
	for x in [-4.25, 4.25]:
		_box(world_root, Vector3(0.36, 1.0, 16), Vector3(x, 0.48, 0), mats.red)
		_box(world_root, Vector3(0.36, 0.68, 16), Vector3(x, 3.85, 0), mats.red)
		for z in [-7.7,-3.75,0.0,3.75,7.7]: _box(world_root,Vector3(0.42,3.5,0.28),Vector3(x,2.18,z),mats.cocoa)
	for x in [-4.05, 4.05]:
		for z in [-5.6, -1.9, 1.8, 5.5]:
			var root := Node3D.new(); world_root.add_child(root); root.position = Vector3(x, 2.45, z); root.rotation.y = PI / 2.0
			_build_window(root.position, Vector2(2.9, 2.1), true)
	# Outside scenery layers remain visible through the carriage openings.
	for x in [-7.0, 7.0]:
		for z in range(-10, 11, 3):
			_build_tree(Vector3(x, -0.5, z), 0.75)
		for z in [-7.5, -1.0, 6.0]:
			var mountain := _sphere(world_root, Vector3(3.4, 2.1, 1.4), Vector3(x * 1.3, 1.0, z), mats.blue, 20, 12)
			mountain.rotation.z = 0.15
	# Seats and tables in four bays.
	for z in [-4.9, -1.6, 1.7, 5.0]:
		_box(world_root, Vector3(2.2, 0.18, 0.9), Vector3(-2.9, 0.72, z), mats.teal)
		_box(world_root, Vector3(2.2, 0.18, 0.9), Vector3(2.9, 0.72, z), mats.gold)
		_sphere(world_root, Vector3(1.1, 0.7, 0.2), Vector3(-3.1, 1.22, z + 0.36), mats.teal, 24, 14)
		_sphere(world_root, Vector3(1.1, 0.7, 0.2), Vector3(3.1, 1.22, z + 0.36), mats.gold, 24, 14)
		_box(world_root, Vector3(2.7, 0.16, 1.0), Vector3(0, 1.02, z), mats.wood)
		_capsule_mesh(world_root, 0.12, 1.0, Vector3(0, 0.5, z), mats.cocoa)
		_import_prop("res://assets/external/kenney_furniture_kit/laptop.glb", Vector3(-0.7,1.12,z), Vector3.ONE * 0.78, PI / 2.0)
		_add_study_spot(Vector3(-2.9,0,z+0.8), Vector3(-2.9,0.05,z+0.2), PI / 2.0, "Laptop", Vector3(0,2.4,z+3.7), Vector3(-1.6,1.0,z))
	for data in [[Vector3(-2.9,0.05,-4.7),1,"Pip","29m"],[Vector3(2.9,0.05,-1.4),2,"Zoe","43m"],[Vector3(-2.9,0.05,1.9),0,"Noa","11m"],[Vector3(2.9,0.05,5.2),1,"Remy","35m"]]:
		_create_npc(data[0],PI / 2.0 if data[0].x < 0 else -PI / 2.0,data[1],data[2],data[3],true)
	explore_camera = _make_camera(Vector3(10.5, 13.5, 15.8), Vector3(0, 1.0, 0), 39.0)
	_focus_camera(Vector3(7.5, 5.8, 10.5), Vector3(0, 1, 0), "Wide carriage")
	_focus_camera(Vector3(1.0, 2.2, 2.8), Vector3(-2.8, 1.15, 1.8), "Window study")
	_focus_camera(Vector3(-2.0, 2.4, -0.4), Vector3(5.5, 1.9, -1.8), "Mountains passing")
	_focus_camera(Vector3(0, 2.5, -7.2), Vector3(0, 1.2, 4), "Down the carriage")
	_add_world_boundaries(Vector2(3.7, 7.4))

func _build_japanese_room() -> void:
	_add_environment(Color("#758f7a"), Color("#ffe6b2"), 0.9)
	_box(world_root, Vector3(18,0.35,13),Vector3(0,-0.22,0),mats.cream)
	# Tatami grid and dark timber frame.
	for x in range(-4,5,2):
		for z in range(-5,6,2):
			var tatami := _box(world_root,Vector3(1.75,0.04,3.55),Vector3(x,0.02,z),mats.stone)
			tatami.rotation.y = PI / 2.0 if (x + z) % 4 == 0 else 0
	_box(world_root,Vector3(18.4,4.8,0.35),Vector3(0,2.25,-6.3),mats.cream)
	for x in range(-8,9,2): _box(world_root,Vector3(0.15,4.7,0.4),Vector3(x,2.25,-6.1),mats.cocoa)
	for y in [0.4,2.25,4.35]: _box(world_root,Vector3(18.2,0.14,0.4),Vector3(0,y,-6.1),mats.cocoa)
	for x in [-8.8,8.8]: _box(world_root,Vector3(0.35,4.8,13),Vector3(x,2.25,0),mats.cocoa)
	_build_window(Vector3(0,2.4,-6.08),Vector2(7.8,3.5),false)
	# Low desks, cushions, alcove shelves and paper lanterns.
	for x in [-4.0,0.0,4.0]:
		for z in [-2.1,2.4]:
			_box(world_root,Vector3(2.8,0.18,1.2),Vector3(x,0.72,z),mats.wood)
			for sx in [-1.05,1.05]: _capsule_mesh(world_root,0.09,0.7,Vector3(x+sx,0.35,z),mats.cocoa)
			_sphere(world_root,Vector3(0.65,0.14,0.65),Vector3(x,0.16,z+1.0),mats.red,24,12)
			_import_prop("res://assets/external/kenney_furniture_kit/laptop.glb",Vector3(x,0.84,z),Vector3.ONE*0.72,PI)
			_add_study_spot(Vector3(x,0,z+1.5),Vector3(x,0.04,z+0.75),0,"Book",Vector3(x,2.0,z+4.2),Vector3(x,0.8,z))
	for x in [-6.6,6.6]:
		_build_plant(Vector3(x,0,4.8),1.15)
		for y in [1.7,3.0]:
			var lamp := _sphere(world_root,Vector3(0.48,0.65,0.48),Vector3(x,y,-4.9),mats.paper,24,14)
			lamp.scale.z=0.75
	for data in [[Vector3(-4,0.05,-1.35),1,"Hana","24m"],[Vector3(0,0.05,-1.35),2,"Iko","46m"],[Vector3(4,0.05,-1.35),0,"Emi","31m"],[Vector3(-4,0.05,3.15),2,"Jun","19m"],[Vector3(4,0.05,3.15),1,"Rin","38m"]]:
		_create_npc(data[0],0,data[1],data[2],data[3],true)
	explore_camera=_make_camera(Vector3(14.5,13.4,16.0),Vector3(0,0.7,-0.3),40)
	_focus_camera(Vector3(10,6.2,10),Vector3(0,0.7,0),"Tatami wide")
	_focus_camera(Vector3(-5.2,2.7,4.5),Vector3(-3.9,0.8,-1.5),"Lantern study")
	_focus_camera(Vector3(5.4,3.0,1),Vector3(0,1.8,-5.8),"Garden window")
	_add_world_boundaries(Vector2(8.0,5.5))

func _build_cafe_table(pos: Vector3, accent: Material) -> void:
	_cylinder(world_root,1.2,0.18,pos+Vector3(0,1.02,0),mats.wood,40)
	_capsule_mesh(world_root,0.18,1.0,pos+Vector3(0,0.5,0),mats.cocoa)
	_cylinder(world_root,0.58,0.12,pos+Vector3(0,0.06,0),mats.cocoa,32)
	_build_chair(pos+Vector3(0,0,1.16),PI)
	_import_prop("res://assets/external/kenney_furniture_kit/laptop.glb",pos+Vector3(0,1.16,-0.2),Vector3.ONE*0.76,PI)
	_cylinder(world_root,0.13,0.30,pos+Vector3(0.65,1.23,0.1),accent,24)
	# Umbrella canopy uses overlapping petals for a designed silhouette.
	_capsule_mesh(world_root,0.08,3.2,pos+Vector3(0,2.25,0),mats.cocoa)
	for i in 8:
		var petal:=_sphere(world_root,Vector3(1.25,0.10,0.52),pos+Vector3(cos(i*TAU/8.0)*0.8,3.72,sin(i*TAU/8.0)*0.8),accent,20,10)
		petal.rotation.y=i*TAU/8.0

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
	var root:=Node3D.new();world_root.add_child(root);root.position=pos;root.rotation.y=yaw;root.set_meta("phase",randf()*TAU)
	var visual:=_create_character(root,variant,seated)
	visual.scale=Vector3.ONE*0.92
	if seated:
		visual.position.y=0.02
		visual.position.z=-0.05
		var parts:Dictionary=visual.get_meta("parts")
		parts.leg_l.rotation.x=-1.22;parts.leg_r.rotation.x=-1.22
		parts.leg_l.position.y=0.63;parts.leg_r.position.y=0.63
		parts.arm_l.rotation.x=-0.78;parts.arm_r.rotation.x=-0.78
	var label:=Label3D.new();root.add_child(label)
	label.text=display_name+"  ·  "+timer
	label.position=Vector3(0,2.75,0)
	label.font_size=24;label.outline_size=7;label.modulate=CREAM;label.outline_modulate=Color(0.08,0.05,0.04,0.85)
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	npcs.append(root)

func _animate_npcs(_delta: float) -> void:
	var t:=Time.get_ticks_msec()*0.001
	for npc in npcs:
		if is_instance_valid(npc) and npc.get_child_count()>0:
			var visual:=npc.get_child(0) as Node3D
			visual.position.y=0.02+sin(t*1.2+float(npc.get_meta("phase")))*0.012
			visual.rotation.y=sin(t*0.37+float(npc.get_meta("phase")))*0.035

func _add_study_spot(standing: Vector3, sitting: Vector3, yaw: float, study_type: String, camera_pos: Vector3, camera_target: Vector3) -> void:
	var debug_root:=Node3D.new();world_root.add_child(debug_root);debug_root.name="StudySpot_%02d"%study_spots.size();debug_root.visible=false
	var stand_marker:=_cylinder(debug_root,0.22,0.04,standing+Vector3(0,0.05,0),mats.green,18)
	var sit_marker:=_cylinder(debug_root,0.22,0.04,sitting+Vector3(0,0.08,0),mats.coral,18)
	var arrow:=_box(debug_root,Vector3(0.08,0.08,0.9),sitting+Vector3(0,0.15,-0.42),mats.gold);arrow.rotation.y=yaw
	study_spots.append({"standing":standing,"sitting":sitting,"yaw":yaw,"type":study_type,"camera_pos":camera_pos,"camera_target":camera_target,"debug":debug_root})

func _update_nearest_spot() -> void:
	if not is_instance_valid(player):return
	var best:=-1;var best_distance:=2.05
	for i in study_spots.size():
		var d:float=player.global_position.distance_to(study_spots[i].standing)
		if d<best_distance:best=i;best_distance=d
	nearest_spot=best
	if is_instance_valid(prompt_label):
		prompt_label.visible=best>=0
		if best>=0:prompt_label.text="E   Study here  ·  "+study_spots[best].type

func _set_debug_spots(value: bool) -> void:
	for spot in study_spots:spot.debug.visible=value
	_show_toast("StudySpot anchors "+("visible" if value else "hidden"))

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
	var hint:=_pill("WASD move   ·   E study   ·   F wave",Vector2(28,650));ui_root.add_child(hint)
	debug_label=_label("DEV  F3 anchors  ·  F5 10-second focus  ·  F6 overlay\nFPS: --   Renderer: Compatibility",13,CREAM);ui_root.add_child(debug_label);debug_label.position=Vector2(860,620);debug_label.size=Vector2(390,74);debug_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;debug_label.visible=false

func _open_focus_setup(spot_index: int) -> void:
	if study_spots.is_empty():return
	spot_index=clampi(spot_index,0,study_spots.size()-1)
	movement_enabled=false
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
	movement_enabled=true

func _begin_focus(spot_index: int) -> void:
	var task:=task_input.text if is_instance_valid(task_input) else "Quiet focus"
	var spot:Dictionary=study_spots[spot_index]
	var overlay:=ui_root.get_node_or_null("FocusSetupOverlay");if overlay:overlay.queue_free()
	# Author-authored anchors are used directly for deterministic seat alignment.
	player.position=spot.sitting
	player.rotation.y=spot.yaw
	player.velocity=Vector3.ZERO
	if player_parts.has("leg_l"):
		player_parts.leg_l.rotation.x=-1.22;player_parts.leg_r.rotation.x=-1.22
		player_parts.arm_l.rotation.x=-0.80;player_parts.arm_r.rotation.x=-0.80
	movement_enabled=false
	screen=Screen.FOCUS
	_build_focus_hud(task)
	# The first camera is spot-specific, followed by authored room B-roll.
	var personal:=_make_camera(spot.camera_pos,spot.camera_target,36.0,false);focus_cameras.push_front(personal)
	focus_shot_index=-1
	next_shot_at=0
	FocusManager.start_session(task,selected_duration)

func _begin_review_focus() -> void:
	if study_spots.is_empty(): return
	var spot: Dictionary = study_spots[0]
	player.position = spot.sitting
	player.rotation.y = spot.yaw
	player.velocity = Vector3.ZERO
	if player_parts.has("leg_l"):
		player_parts.leg_l.rotation.x = -1.22
		player_parts.leg_r.rotation.x = -1.22
		player_parts.arm_l.rotation.x = -0.80
		player_parts.arm_r.rotation.x = -0.80
	movement_enabled = false
	screen = Screen.FOCUS
	_build_focus_hud("Reference analysis notes")
	var personal := _make_camera(spot.camera_pos, spot.camera_target, 36.0, false)
	personal.set_meta("shot_name", "Personal desk")
	focus_cameras.push_front(personal)
	focus_shot_index = -1
	next_shot_at = 0
	FocusManager.start_session("Reference analysis notes", 1500)

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
	if focus_cameras.is_empty():return
	focus_shot_index=(focus_shot_index+1)%focus_cameras.size()
	for cam in focus_cameras:cam.current=false
	focus_cameras[focus_shot_index].current=true
	next_shot_at=Time.get_unix_time_from_system()+25.0
	if is_instance_valid(focus_shot_label):focus_shot_label.text="FOCUS  ·  shot %d of %d"%[focus_shot_index+1,focus_cameras.size()]

func _on_focus_completed() -> void:
	if screen!=Screen.FOCUS:return
	var minutes:=roundi(float(FocusManager.duration_seconds)/60.0)
	var reward:=GameState.award_session(FocusManager.task,minutes,current_room_name)
	_show_completion(minutes,reward)

func _on_focus_cancelled() -> void:
	if screen==Screen.FOCUS:build_room(GameState.selected_room)

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
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=ambient;env.ambient_light_energy=0.36
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.tonemap_exposure=1.10
	env.glow_enabled=true;env.glow_intensity=0.24;env.glow_bloom=0.08
	var sun:=DirectionalLight3D.new();world_root.add_child(sun);sun.rotation_degrees=Vector3(-55,-30,0);sun.light_color=ambient;sun.light_energy=energy;sun.shadow_enabled=true;sun.directional_shadow_max_distance=40
	var fill:=OmniLight3D.new();world_root.add_child(fill);fill.position=Vector3(-5,7,6);fill.light_color=Color("#ffcf94");fill.light_energy=1.6;fill.omni_range=18;fill.shadow_enabled=true

func _make_camera(pos: Vector3, target: Vector3, fov: float, make_current: bool=true) -> Camera3D:
	var cam:=Camera3D.new();world_root.add_child(cam);cam.position=pos;cam.fov=fov;cam.look_at_from_position(pos,target);cam.current=make_current;return cam

func _focus_camera(pos: Vector3,target: Vector3,shot_name: String) -> void:
	var cam:=_make_camera(pos,target,36.0,false);cam.set_meta("shot_name",shot_name);focus_cameras.append(cam)

func _update_camera_current() -> void:
	if is_instance_valid(explore_camera):explore_camera.current=true

func _add_world_boundaries(extents: Vector2) -> void:
	for data in [[Vector3(extents.x+0.3,1.5,0),Vector3(0.4,3.0,extents.y*2.0)],[Vector3(-extents.x-0.3,1.5,0),Vector3(0.4,3.0,extents.y*2.0)],[Vector3(0,1.5,extents.y+0.3),Vector3(extents.x*2.0,3.0,0.4)],[Vector3(0,1.5,-extents.y-0.3),Vector3(extents.x*2.0,3.0,0.4)]]:
		var body:=StaticBody3D.new();world_root.add_child(body);body.position=data[0]
		var cs:=CollisionShape3D.new();body.add_child(cs);var shape:=BoxShape3D.new();shape.size=data[1];cs.shape=shape
	# Large furniture collisions are authored separately enough for this slice; boundaries protect composition.

func _box(parent: Node, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var node:=MeshInstance3D.new();parent.add_child(node);var mesh:=BoxMesh.new();mesh.size=size;mesh.material=material;node.mesh=mesh;node.position=pos;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON;return node

func _sphere(parent: Node, scale_value: Vector3, pos: Vector3, material: Material, radial: int=24, rings: int=14) -> MeshInstance3D:
	var node:=MeshInstance3D.new();parent.add_child(node);var mesh:=SphereMesh.new();mesh.radius=1.0;mesh.height=2.0;mesh.radial_segments=radial;mesh.rings=rings;mesh.material=material;node.mesh=mesh;node.scale=scale_value;node.position=pos;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON;return node

func _cylinder(parent: Node, radius: float, height: float, pos: Vector3, material: Material, radial: int=24) -> MeshInstance3D:
	var node:=MeshInstance3D.new();parent.add_child(node);var mesh:=CylinderMesh.new();mesh.top_radius=radius;mesh.bottom_radius=radius;mesh.height=height;mesh.radial_segments=radial;mesh.material=material;node.mesh=mesh;node.position=pos;return node

func _capsule_mesh(parent: Node, radius: float, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var node:=MeshInstance3D.new();parent.add_child(node);var mesh:=CapsuleMesh.new();mesh.radius=radius;mesh.height=maxf(height,radius*2.05);mesh.radial_segments=20;mesh.rings=8;mesh.material=material;node.mesh=mesh;node.position=pos;return node

func _import_prop(path: String,pos: Vector3,scale_value: Vector3,yaw: float=0.0) -> Node3D:
	var holder:=Node3D.new();world_root.add_child(holder);holder.position=pos;holder.scale=scale_value;holder.rotation.y=yaw
	if ResourceLoader.exists(path):
		var scene=load(path)
		if scene is PackedScene:holder.add_child(scene.instantiate())
	return holder

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
