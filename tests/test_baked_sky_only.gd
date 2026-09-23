extends SceneTree

var frame := 0

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	var packed: PackedScene = load("res://assets/dev_local/room_layouts/garden.tscn")
	var layout := packed.instantiate() as Node3D
	root.add_child(layout)
	var env_count := 0
	var sun_count := 0
	for n in layout.find_children("*", "WorldEnvironment", true, false):
		env_count += 1
		var e := (n as WorldEnvironment).environment
		print("SKYTEST env=", n.name, " bg=", e.background_mode, " sky=", e.sky, " mat=", e.sky.sky_material if e.sky != null else null)
	for n in layout.find_children("*", "DirectionalLight3D", true, false):
		sun_count += 1
		print("SKYTEST sun=", n.name, " rot=", (n as DirectionalLight3D).rotation_degrees, " e=", (n as DirectionalLight3D).light_energy)
	print("SKYTEST envs=", env_count, " suns=", sun_count)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0, 14, 24)
	cam.look_at_from_position(Vector3(0, 14, 24), Vector3(0, 9, -60))
	cam.current = true
	cam.fov = 55.0

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 60:
		var img: Image = root.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute("art_reviews/current")
		print("SKYTEST shot err=", img.save_png("art_reviews/current/baked_sky_isolation.png"))
		# Sample sky pixels directly.
		print("SKYTEST px top=", img.get_pixel(640, 100), " mid=", img.get_pixel(640, 300), " hor=", img.get_pixel(640, 450))
		print("SKYTEST DONE")
		quit()
	return false
