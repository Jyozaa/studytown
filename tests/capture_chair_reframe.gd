extends SceneTree

var app
var frame := 0
var review: Camera3D

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
	if frame == 150:
		app._ft_install_seat_glows()
		app.player.global_position = Vector3(-6.6, 0.1, 7.8)
		app.player.velocity = Vector3.ZERO
		review = Camera3D.new()
		app.world_root.add_child(review)
		review.fov = 40.0
		review.global_transform = Transform3D(Basis(), Vector3(-5.8, 1.4, 5.6)).looking_at(Vector3(-7.3, 0.5, 7.1))
		review.make_current()
		app.hud.hide()
	if frame == 200:
		if app.nearest_spot >= 0:
			print("NEAREST chair_reframe = ", app.study_spots[app.nearest_spot].seat_id)
		else:
			print("NEAREST chair_reframe = none")
		var img: Image = root.get_texture().get_image()
		var img2: Image = root.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute("art_reviews/current")
		print("SHOT chair_reframe err=", img2.save_png("art_reviews/current/seatglow_chair_close.png"))
		print("CAP DONE")
		quit()
	return false
