extends SceneTree

var frame := 0
var app
var stage := 0
var cameras: Array[Camera3D] = []
var shot_index := 0
var shot_names: Array[String] = []

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	root.get_node("GameState").persistence_enabled = false
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)

var switch_frame := 0
var pending_shot := ""
var last_checksum := -1

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		app.current_room_name = root.get_node("GameState").ROOMS[1]
		app.build_room(1)
		stage = 1
	if stage == 1 and frame == 120:
		print("CAFE built spots=", app.study_spots.size(), " npcs=", app.npcs.size())
		# WYSIWYG geometry QA: the occlusion x-ray would melt exterior walls
		# between review cameras and the player. Disable it for capture.
		var xray = app.world_root.get_node_or_null("PlayerOcclusionXRay")
		if xray != null:
			xray.enabled = false
			print("XRAY disabled for capture")
		_setup_cameras()
		stage = 2
		shot_index = 0
		switch_frame = frame
		# activate first camera immediately
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
		# Dual capture: a warm get_image() at +15 flushes the presenter,
		# the saved shot at +28 reads a settled frame. All synchronous.
		var age := frame - switch_frame
		if age == 15 and pending_shot != "":
			var warm: Image = root.get_texture().get_image()
			if warm != null:
				print("WARM ", pending_shot, " cs=", _checksum(warm))
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

func _setup_cameras() -> void:
	cameras.clear()
	shot_names.clear()
	# Helper to add camera via main's _make_camera but we build manually for control.
	var defs: Array = [
		# A. general scene review (extended world)
		[Vector3(0, 95, 20), Vector3(0, 0, 5), 42.0, "cafe_ext_overhead_large"],
		[Vector3(0, 22, 80), Vector3(0, 3, 12), 40.0, "cafe_ext_south_far"],
		[Vector3(-95, 25, -10), Vector3(0, 5, 0), 40.0, "cafe_ext_west_far"],
		[Vector3(95, 25, 10), Vector3(0, 5, 0), 40.0, "cafe_ext_east_far"],
		[Vector3(0, 20, -84), Vector3(0, 3, -12), 40.0, "cafe_ext_north_far"],
		# B. second floor outward views
		[Vector3(-4, 6.0, -5), Vector3(-4, 5.2, -30), 44.0, "cafe_view_second_north"],
		[Vector3(4, 6.2, -11), Vector3(30, 5.0, -6), 44.0, "cafe_view_second_east"],
		[Vector3(0, 6.5, -6), Vector3(0, 4.5, 25), 44.0, "cafe_view_second_south"],
		[Vector3(-2, 6.8, -9.5), Vector3(-30, 5.5, -9.5), 44.0, "cafe_view_second_west"],
		# C. traffic routes
		[Vector3(0, 14, 34), Vector3(0, 0, 22), 40.0, "traffic_route_south"],
		[Vector3(-30, 7, 14), Vector3(-30, 0, -6), 40.0, "traffic_route_west"],
		[Vector3(44, 12, 4), Vector3(30, 0, 4), 40.0, "traffic_route_east"],
		[Vector3(40, 6, -25), Vector3(-20, 1, -25), 40.0, "traffic_route_north"],
		# D. clipping review (dense/intersection spots)
		[Vector3(-38, 4, 30), Vector3(-30, 0, 22), 42.0, "clipping_check_01"],
		[Vector3(10, 4, -19), Vector3(-14, 0, -32), 42.0, "clipping_check_02"],
		[Vector3(50, 6, -26), Vector3(40, 1, -34), 42.0, "clipping_check_03"],
		[Vector3(0, 14, 52), Vector3(0, 2, 70), 42.0, "clipping_check_04"],
		[Vector3(30, 5, 2), Vector3(30, 0, -14), 42.0, "clipping_check_05"],
		# E. café shell review (heights, glass connections, back wall)
		[Vector3(24, 9, 20), Vector3(0, 5, 0), 40.0, "cafe_wall_height_review"],
		[Vector3(4, 2.0, 8), Vector3(4, 2.0, 13), 44.0, "cafe_glass_connection_south"],
		[Vector3(20, 2.5, 8), Vector3(16, 2.8, 8), 44.0, "cafe_glass_connection_east"],
		[Vector3(-20, 2.5, 0), Vector3(-16, 2.8, 0), 44.0, "cafe_glass_connection_west"],
		[Vector3(0, 6, -22), Vector3(0, 4, -12), 40.0, "cafe_backwall_review"],
		# F. lighting review
		[Vector3(0, 5, 7), Vector3(0, 1, -1), 40.0, "cafe_interior_lighting_01"],
		[Vector3(0, 7.5, -4.5), Vector3(0, 5, -8), 40.0, "cafe_interior_lighting_02"],
		[Vector3(10, 4, 28), Vector3(0, 2, 12), 40.0, "cafe_window_glow_evening"],
	]
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("set="):
			only = arg.trim_prefix("set=")
	var groups := {
		"A": ["cafe_ext_"], "B": ["cafe_view_"], "C": ["traffic_"],
		"D": ["clipping_"],
		"E": ["cafe_wall_height_review", "cafe_glass_connection", "cafe_backwall"],
		"F": ["cafe_interior", "cafe_window"], "G": ["cafe_city_seated"],
	}
	if only != "" and groups.has(only):
		var prefixes: Array = groups[only]
		print("SHOTSET filter=", only)
		defs = defs.filter(func(d): return prefixes.any(func(p): return str(d[3]).begins_with(p)))
	for d in defs:
		var cam := Camera3D.new()
		app.world_root.add_child(cam)
		cam.position = d[0]
		cam.fov = d[2]
		cam.look_at_from_position(d[0], d[1])
		cam.current = false
		cameras.append(cam)
		shot_names.append(d[3])

	# Add seated study-camera views near new glazing via director
	if only != "" and only != "G":
		print("Setup cameras=", cameras.size())
		return
	var director = app.get("garden_seat_director")
	if director != null:
		# Seated QA near glazing: west bar (0) + upstairs east (33)
		var spot_indices: Array = [0, 33]
		var picked := 0
		for idx in spot_indices:
			if idx < app.study_spots.size():
				var spot = app.study_spots[idx]
				if director.solve(spot):
					var cam: Camera3D = director.camera(spot, spot.setup_camera_override, "setup")
					cameras.append(cam)
					shot_names.append("cafe_city_seated_%s" % spot.seat_id)
					picked += 1
		if picked < 2:
			for i in range(app.study_spots.size()):
				if picked >= 2:
					break
				var spot = app.study_spots[i]
				var already := false
				for n in shot_names:
					if spot.seat_id in n:
						already = true
						break
				if already:
					continue
				if director.solve(spot):
					var cam: Camera3D = director.camera(spot, spot.setup_camera_override, "setup")
					cameras.append(cam)
					shot_names.append("cafe_city_seated_%s_%d" % [spot.seat_id, picked])
					picked += 1
	print("Setup cameras=", cameras.size())


