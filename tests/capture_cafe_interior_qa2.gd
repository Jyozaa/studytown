extends SceneTree

# Second-pass re-shots after tabletop/camera corrections.

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
	_add(Vector3(-3.0, 3.6, 1.0), Vector3(-3.0, 1.0, 1.0), 40.0, "tabletop_communal")
	_add(Vector3(-1.5, 2.4, 3.6), Vector3(-3.8, 1.0, 0.6), 44.0, "cafe_interior_communal_table")
	_add(Vector3(2.8, 2.4, -2.2), Vector3(-1.5, 1.0, -4.7), 40.0, "counter_props")
	_add(Vector3(10.5, 2.2, 2.8), Vector3(10.5, 0.6, 7.0), 44.0, "cafe_interior_lounge")
	_add(Vector3(0.0, 6.9, -5.2), Vector3(0.0, 5.8, -7.0), 40.0, "tabletop_second_floor")
	_add(Vector3(-1.5, 2.4, -5.6), Vector3(5.0, 1.0, -9.5), 44.0, "cafe_interior_kitchen_close")
	print("Setup cameras=", cameras.size())
