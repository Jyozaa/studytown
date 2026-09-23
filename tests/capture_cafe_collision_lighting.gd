extends SceneTree

# Collision-debug views (green boxes) + warm-lighting v2 views.

var frame := 0
var app
var stage := 0
var cameras: Array[Camera3D] = []
var shot_names: Array[String] = []
var shot_index := 0
var switch_frame := 0
var pending_shot := ""
var debug_phase := true

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	root.get_node("GameState").persistence_enabled = false
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		app.current_room_name = root.get_node("GameState").ROOMS[1]
		app.build_room(1)
		stage = 1
	if stage == 1 and frame == 120:
		var xray = app.world_root.get_node_or_null("PlayerOcclusionXRay")
		if xray != null:
			xray.enabled = false
		call_group("collision_debug", "set_visible", true)
		print("COLLISION DEBUG visible")
		_setup_cameras()
		stage = 2
		shot_index = 0
		for cam in cameras:
			cam.current = false
		cameras[0].current = true
		pending_shot = shot_names[0]
		shot_index = 1
		switch_frame = frame
		print("CAPTURE count=", shot_names.size())
	if stage == 2 and shot_index <= cameras.size():
		var age := frame - switch_frame
		if age >= 28:
			if pending_shot != "":
				_take_shot_sync(pending_shot)
				pending_shot = ""
				# After the last collision_* shot, hide debug meshes.
				if debug_phase and pending_shot == "" and shot_names[shot_index - 1].begins_with("collision_") and (shot_index >= cameras.size() or not shot_names[shot_index].begins_with("collision_")):
					call_group("collision_debug", "set_visible", false)
					debug_phase = false
					print("COLLISION DEBUG hidden")
			if shot_index < cameras.size():
				for cam in cameras:
					cam.current = false
				cameras[shot_index].current = true
				print("SWITCH to ", shot_names[shot_index], " pos=", cameras[shot_index].position)
				pending_shot = shot_names[shot_index]
				shot_index += 1
				switch_frame = frame
			elif shot_index == cameras.size() and pending_shot == "":
				print("ALL SHOTS DONE")
				quit()
	return false

func _take_shot_sync(label: String) -> void:
	DirAccess.make_dir_recursive_absolute("art_reviews/current")
	var img: Image = root.get_texture().get_image()
	if img == null:
		print("SHOT FAIL null image ", label)
		return
	var err := img.save_png("art_reviews/current/" + label + ".png")
	print("SHOT ", label, " err=", err)

func _add(pos: Vector3, target: Vector3, fov: float, label: String) -> void:
	var cam := Camera3D.new()
	app.world_root.add_child(cam)
	cam.position = pos
	cam.fov = fov
	cam.look_at_from_position(pos, target)
	cam.current = false
	cameras.append(cam)
	shot_names.append(label)

func _setup_cameras() -> void:
	cameras.clear()
	shot_names.clear()
	_add(Vector3(0, 12, 4), Vector3(0, 0, -1), 46.0, "collision_ground_overhead")
	_add(Vector3(-5, 3.0, 6.5), Vector3(-5, 0.5, 0.5), 46.0, "collision_ground_tables")
	_add(Vector3(-10.5, 2.4, 0.5), Vector3(-13.5, 0.5, 0.5), 46.0, "collision_ground_windowbar")
	_add(Vector3(7.0, 2.6, 3.0), Vector3(10.5, 0.5, 6.5), 46.0, "collision_ground_lounge")
	_add(Vector3(0, 2.6, -1.0), Vector3(0, 0.8, -7.5), 46.0, "collision_ground_counter")
	_add(Vector3(10.0, 1.6, 9.0), Vector3(13.6, 1.0, 5.0), 46.0, "collision_stairs_bottom")
	_add(Vector3(9.0, 2.4, 1.5), Vector3(13.8, 2.4, 1.5), 44.0, "collision_stairs_side")
	_add(Vector3(10.5, 6.4, 0.5), Vector3(13.4, 4.6, -3.4), 44.0, "collision_stairs_top")
	_add(Vector3(0, 12.5, -4.5), Vector3(0, 4.8, -7.5), 46.0, "collision_second_overhead")
	_add(Vector3(-4, 7.0, -4.6), Vector3(2, 5.2, -7.6), 46.0, "collision_second_tables")
	_add(Vector3(-8, 6.6, -1.0), Vector3(4, 5.4, -3.6), 46.0, "collision_second_railing")
	_add(Vector3(0, 3.2, 8.0), Vector3(-2, 1.0, -3), 46.0, "lighting_ground_wide_v2")
	_add(Vector3(-1.5, 2.4, 3.6), Vector3(-3.8, 1.0, 0.6), 44.0, "lighting_communal_v2")
	_add(Vector3(-8.0, 2.0, 6.0), Vector3(-14.5, 1.2, 0.5), 46.0, "lighting_windowbar_v2")
	_add(Vector3(10.5, 2.2, 2.8), Vector3(10.5, 0.6, 7.0), 44.0, "lighting_lounge_v2")
	_add(Vector3(2.5, 2.2, -1.5), Vector3(-2.0, 1.2, -5.5), 44.0, "lighting_counter_v2")
	_add(Vector3(11.5, 2.0, 8.5), Vector3(13.4, 1.2, 3.0), 44.0, "lighting_stairs_v2")
	_add(Vector3(-6.0, 7.0, -4.2), Vector3(2.0, 5.2, -8.0), 46.0, "lighting_second_floor_v2")
	_add(Vector3(-4.0, 6.3, -6.0), Vector3(-2.0, 4.6, -7.5), 44.0, "lighting_glass_floor_v2")
	_add(Vector3(-11.0, 1.8, 3.0), Vector3(-16.5, 2.2, 3.0), 48.0, "lighting_inside_vs_outside_v2")
	print("Setup cameras=", cameras.size())
