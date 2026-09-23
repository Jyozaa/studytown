extends SceneTree

var app
var frame := 0
var shots := []
var idx := 0

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	root.get_node("GameState").persistence_enabled = false
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	shots = [
		["before_overhead", Vector3(0, 30, 6), Vector3(0, 0, -2), 50.0],
		["before_interior", Vector3(0, 3, 14), Vector3(0, 1.5, -6), 55.0],
		["before_shelves", Vector3(-14, 4, -4), Vector3(-19, 2, -12), 50.0],
	]

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		app.current_room_name = root.get_node("GameState").ROOMS[0]
		app.build_room(0)
	if frame == 150 and idx < shots.size():
		var s: Array = shots[idx]
		var cam := Camera3D.new()
		app.world_root.add_child(cam)
		cam.fov = float(s[3])
		cam.global_transform = Transform3D(Basis(), s[1]).looking_at(s[2])
		cam.make_current()
		idx += 1
		frame = 151
	if frame == 170 and idx <= shots.size() and idx > 0:
		var img: Image = root.get_texture().get_image()
		var img2: Image = root.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute("art_reviews/library")
		print("SHOT ", shots[idx - 1][0], " err=", img2.save_png("art_reviews/library/" + str(shots[idx - 1][0]) + ".png"))
		for c in app.world_root.find_children("*", "Camera3D", false, false):
			(c as Node).free()
		frame = 149
		if idx >= shots.size():
			print("BEFORE DONE")
			quit()
	return false
