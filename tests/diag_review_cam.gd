extends SceneTree

var frame := 0
var app
var cam: Camera3D = null

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
	if frame == 120:
		var xray = app.world_root.get_node_or_null("PlayerOcclusionXRay")
		if xray != null:
			xray.enabled = false
		cam = Camera3D.new()
		app.world_root.add_child(cam)
		cam.position = Vector3(0, 11, 9)
		cam.fov = 44.0
		cam.look_at_from_position(Vector3(0, 11, 9), Vector3(0, 0, -2))
		cam.current = true
		print("DIAG set review cam pos=", cam.position, " current=", cam.current)
	if frame == 150:
		print("DIAG at take: viewport_cam=", root.get_camera_3d(), " review pos=", cam.position if cam != null else null)
		var img: Image = root.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute("art_reviews/current")
		print("DIAG shot err=", img.save_png("art_reviews/current/diag_review_cam.png"))
		print("DIAG DONE")
		quit()
	return false
