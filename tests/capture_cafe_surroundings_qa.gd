extends SceneTree

# Surrounding environment QA capture: overlap audit + elevation + sky + traffic.
# Saves into art_reviews/current/ with the exact filenames required by the pass.

var frame := 0
var app
var stage := 0
var cameras: Array[Camera3D] = []
var shot_names: Array[String] = []
var shot_waits: Array[int] = []
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
		var wait: int = shot_waits[shot_index - 1] if shot_index - 1 < shot_waits.size() else 28
		var age := frame - switch_frame
		if age == 15 and pending_shot != "":
			var warm: Image = root.get_texture().get_image()
			if warm != null:
				print("WARM ", pending_shot, " cs=", _checksum(warm))
		if age >= wait:
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

func _checksum(img: Image) -> int:
	var h := 0
	var w := img.get_width()
	var hgt := img.get_height()
	for y in range(0, hgt, 60):
		for x in range(0, w, 80):
			var c := img.get_pixel(x, y)
			h = (h * 31 + int(c.r * 255.0) + int(c.g * 255.0) * 7 + int(c.b * 255.0) * 13) & 0x7fffffff
	return h

func _take_shot_sync(label: String) -> void:
	DirAccess.make_dir_recursive_absolute("art_reviews/current")
	var img: Image = root.get_texture().get_image()
	if img == null:
		print("SHOT FAIL null image ", label)
		return
	var path := "art_reviews/current/" + label + ".png"
	var err := img.save_png(path)
	print("SHOT ", label, " cs=", _checksum(img), " err=", err)

func _add(pos: Vector3, target: Vector3, fov: float, label: String, wait := 28) -> void:
	var cam := Camera3D.new()
	app.world_root.add_child(cam)
	cam.position = pos
	cam.fov = fov
	cam.look_at_from_position(pos, target)
	cam.current = false
	cameras.append(cam)
	shot_names.append(label)
	shot_waits.append(wait)

func _setup_cameras() -> void:
	cameras.clear()
	shot_names.clear()
	shot_waits.clear()
	# 1. Overlap audit set (fast captures).
	_add(Vector3(0, 95, 20), Vector3(0, 0, 5), 42.0, "surrounding_overlap_overhead")
	_add(Vector3(0, 20, -84), Vector3(0, 3, -12), 40.0, "surrounding_overlap_north")
	_add(Vector3(0, 22, 80), Vector3(0, 3, 12), 40.0, "surrounding_overlap_south")
	_add(Vector3(95, 25, 10), Vector3(0, 5, 0), 40.0, "surrounding_overlap_east")
	_add(Vector3(-95, 25, -10), Vector3(0, 5, 0), 40.0, "surrounding_overlap_west")
	_add(Vector3(-30, 18, 8), Vector3(-38, 0, -4), 42.0, "surrounding_overlap_zone_01")
	_add(Vector3(30, 18, 8), Vector3(38, 0, -4), 42.0, "surrounding_overlap_zone_02")
	_add(Vector3(-30, 10, -55), Vector3(-45, 3, -71), 42.0, "surrounding_overlap_zone_03")
	_add(Vector3(30, 10, -55), Vector3(45, 3, -71), 42.0, "surrounding_overlap_zone_04")
	# 2. Traffic series with long gaps so cars advance ~20 m between shots.
	_add(Vector3(0, 14, 34), Vector3(0, 0, 22), 40.0, "traffic_a_01", 200)
	_add(Vector3(-30, 7, 14), Vector3(-30, 0, -6), 40.0, "traffic_a_02", 200)
	_add(Vector3(44, 12, 4), Vector3(30, 0, 4), 40.0, "traffic_a_03", 200)
	_add(Vector3(40, 6, -25), Vector3(-20, 1, -25), 40.0, "traffic_b_01", 200)
	_add(Vector3(0, 14, 34), Vector3(0, 0, 22), 40.0, "traffic_b_02", 200)
	_add(Vector3(-30, 7, 14), Vector3(-30, 0, -6), 40.0, "traffic_b_03", 200)
	# 3. Elevation finals.
	_add(Vector3(0, 100, 30), Vector3(0, 0, 0), 42.0, "elevation_overhead_final")
	_add(Vector3(0, 24, -90), Vector3(0, 4, -20), 40.0, "elevation_north_final")
	_add(Vector3(0, 24, 90), Vector3(0, 4, 20), 40.0, "elevation_south_final")
	_add(Vector3(100, 28, 0), Vector3(0, 5, 0), 40.0, "elevation_east_final")
	_add(Vector3(-100, 28, 0), Vector3(0, 5, 0), 40.0, "elevation_west_final")
	# 4. Second-floor depth views.
	_add(Vector3(-4, 6.0, -5), Vector3(-4, 5.2, -30), 44.0, "second_floor_city_north_final")
	_add(Vector3(0, 6.5, -6), Vector3(0, 4.5, 25), 44.0, "second_floor_city_south_final")
	_add(Vector3(4, 6.2, -11), Vector3(30, 5.0, -6), 44.0, "second_floor_city_east_final")
	_add(Vector3(-2, 6.8, -9.5), Vector3(-30, 5.5, -9.5), 44.0, "second_floor_city_west_final")
	# 5. Sky + interior warmth + glass check.
	_add(Vector3(0, 4, 20), Vector3(10, 22, -30), 50.0, "baby_blue_sky_01")
	_add(Vector3(-14, 3, 8), Vector3(-30, 20, 20), 50.0, "baby_blue_sky_02")
	_add(Vector3(0, 5, 7), Vector3(0, 1, -1), 40.0, "traffic_final_01")
	_add(Vector3(10, 4, 28), Vector3(0, 2, 12), 40.0, "traffic_final_02")
	_add(Vector3(0, 7.5, -4.5), Vector3(0, 5, -8), 40.0, "traffic_final_03")
	print("Setup cameras=", cameras.size())
