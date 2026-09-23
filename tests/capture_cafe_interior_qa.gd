extends SceneTree

# Interior asset + glass floor + lighting QA for the Café pass.

var frame := 0
var app
var stage := 0
var cameras: Array[Camera3D] = []
var shot_names: Array[String] = []
var shot_index := 0
var switch_frame := 0
var pending_shot := ""

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
		print("CAFE built spots=", app.study_spots.size(), " npcs=", app.npcs.size())
		var xray = app.world_root.get_node_or_null("PlayerOcclusionXRay")
		if xray != null:
			xray.enabled = false
			print("XRAY disabled for capture")
		_setup_cameras()
		stage = 2
		shot_index = 0
		for cam in cameras:
			cam.current = false
		if cameras.size() > 0:
			cameras[0].current = true
			print("SWITCH to ", shot_names[0], " pos=", cameras[0].position)
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
	var path := "art_reviews/current/" + label + ".png"
	var err := img.save_png(path)
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
	# 38. Interior overviews.
	_add(Vector3(0, 9, 6), Vector3(0, 0, -2), 50.0, "cafe_interior_asset_ground_overhead")
	_add(Vector3(0, 2.2, 10.5), Vector3(0, 1.2, -6), 50.0, "cafe_interior_asset_ground_north")
	_add(Vector3(0, 2.2, -9.0), Vector3(0, 1.2, 8), 50.0, "cafe_interior_asset_ground_south")
	_add(Vector3(-13.5, 2.2, 1.0), Vector3(5, 1.2, 1.0), 50.0, "cafe_interior_asset_ground_east")
	_add(Vector3(13.5, 2.2, 1.0), Vector3(-5, 1.2, 1.0), 50.0, "cafe_interior_asset_ground_west")
	_add(Vector3(-1.5, 2.4, -5.6), Vector3(5.0, 1.0, -9.5), 44.0, "cafe_interior_kitchen_close")
	_add(Vector3(-1.5, 2.4, 3.6), Vector3(-3.8, 1.0, 0.6), 44.0, "cafe_interior_communal_table")
	_add(Vector3(-11.0, 1.8, 0.5), Vector3(-14.2, 1.0, 0.5), 44.0, "cafe_interior_window_bar")
	_add(Vector3(10.5, 2.2, 2.8), Vector3(10.5, 0.6, 7.0), 44.0, "cafe_interior_lounge")
	_add(Vector3(0, 11.5, -4.0), Vector3(0, 4.8, -7.5), 50.0, "cafe_interior_second_overhead")
	_add(Vector3(13.0, 6.4, -7.0), Vector3(-5, 5.2, -7.5), 50.0, "cafe_interior_second_west")
	_add(Vector3(-13.0, 6.4, -7.0), Vector3(5, 5.2, -7.5), 50.0, "cafe_interior_second_east")
	# 39. Tabletop close-ups.
	_add(Vector3(-9.0, 2.0, 7.8), Vector3(-9.0, 1.0, 6.2), 40.0, "tabletop_round_01")
	_add(Vector3(-1.0, 2.0, 8.1), Vector3(-1.0, 1.0, 6.5), 40.0, "tabletop_round_02")
	_add(Vector3(-1.6, 2.3, 3.4), Vector3(-3.7, 1.0, 0.7), 40.0, "tabletop_communal")
	_add(Vector3(-12.2, 1.9, 2.0), Vector3(-14.0, 1.0, 1.0), 40.0, "tabletop_window_bar")
	_add(Vector3(0.0, 6.9, -5.2), Vector3(0.0, 5.8, -7.0), 40.0, "tabletop_second_floor")
	_add(Vector3(2.8, 2.4, -2.2), Vector3(-1.5, 1.0, -4.7), 40.0, "counter_props")
	_add(Vector3(1.5, 2.2, -7.0), Vector3(3.5, 1.0, -9.5), 40.0, "kitchen_props")
	# 40. Glass floor.
	_add(Vector3(-6.0, 7.5, -7.0), Vector3(4.0, 4.8, -7.5), 46.0, "glass_floor_top")
	_add(Vector3(-10.0, 6.6, -1.5), Vector3(5.0, 4.4, -8.5), 46.0, "glass_floor_angle")
	_add(Vector3(0.0, 1.6, -1.0), Vector3(0.0, 4.6, -7.5), 50.0, "glass_floor_from_below")
	_add(Vector3(11.0, 6.2, 0.5), Vector3(13.4, 4.4, -3.2), 44.0, "glass_floor_stairs_connection")
	_add(Vector3(2.5, 6.3, -5.0), Vector3(-2.0, 4.8, -7.2), 44.0, "glass_floor_furniture_contact")
	# 41. Lighting finals.
	_add(Vector3(0, 3.4, 7.5), Vector3(-2, 1.0, -3), 46.0, "cafe_lighting_ground_final")
	_add(Vector3(2.5, 2.2, -1.5), Vector3(-2.0, 1.2, -5.5), 44.0, "cafe_lighting_counter_final")
	_add(Vector3(7.0, 2.0, 4.0), Vector3(11.0, 0.8, 7.0), 44.0, "cafe_lighting_lounge_final")
	_add(Vector3(-6.0, 7.0, -4.2), Vector3(2.0, 5.2, -8.0), 46.0, "cafe_lighting_second_final")
	_add(Vector3(-8.0, 2.0, 6.0), Vector3(-16.0, 2.0, 2.0), 46.0, "cafe_lighting_window_contrast_final")
	print("Setup cameras=", cameras.size())
