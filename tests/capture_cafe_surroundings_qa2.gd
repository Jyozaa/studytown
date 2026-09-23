extends SceneTree

# Supplementary close-range QA: steep road-canyon views + H/I terrace closeups.

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
		var xray = app.world_root.get_node_or_null("PlayerOcclusionXRay")
		if xray != null:
			xray.enabled = false
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
		if age == 15 and pending_shot != "":
			var warm: Image = root.get_texture().get_image()
			if warm != null:
				print("WARM ", pending_shot)
		if age >= 60:
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
	_add(Vector3(-30, 32, 6), Vector3(-34, 0, -4), 42.0, "surrounding_overlap_zone_01b")
	_add(Vector3(30, 32, 6), Vector3(34, 0, -4), 42.0, "surrounding_overlap_zone_02b")
	_add(Vector3(30, 14, 14), Vector3(30, 0, -2), 40.0, "traffic_a_03b")
	_add(Vector3(-70, 8, 15), Vector3(-90, 4, 15), 42.0, "surrounding_overlap_zone_05")
	_add(Vector3(60, 10, -20), Vector3(80, 4, -36), 42.0, "surrounding_overlap_zone_06")
	print("Setup cameras=", cameras.size())
