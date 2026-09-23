extends SceneTree

# Seat interaction-radius debug captures for cafe/library/train.
# Run: -s tests/capture_seat_radii.gd -- --room=cafe|library|train
# Writes art_reviews/radii/seat_radius_<room>_*.png

var app
var frame := 0
var idx := 0
var cam: Camera3D
var room := "library"
var shots := []

const SETS := {
	"cafe": [
		["seat_radius_cafe_ground_overhead", Vector3(0, 30, 12), Vector3(0, 0, 0), 50.0],
		["seat_radius_cafe_windowbar", Vector3(-9.0, 3.0, 1.0), Vector3(-13.5, 0.5, 0.0), 50.0],
		["seat_radius_cafe_tables", Vector3(-5.0, 4.0, 9.0), Vector3(-4.0, 0.5, 2.0), 50.0],
		["seat_radius_cafe_lounge", Vector3(6.5, 3.0, 3.0), Vector3(10.0, 0.5, 6.5), 50.0],
		["seat_radius_cafe_second_overhead", Vector3(0, 32, -5), Vector3(0, 4.9, -5.0), 50.0],
		["seat_radius_cafe_second_tables", Vector3(-4.0, 8.0, -2.0), Vector3(-2.0, 5.2, -7.0), 50.0],
	],
	"library": [
		["seat_radius_library_overhead", Vector3(0, 26, 10), Vector3(0, 0, -1), 52.0],
		["seat_radius_library_tables", Vector3(-3.2, 3.2, 8.5), Vector3(-3.2, 0.8, 0.5), 50.0],
		["seat_radius_library_windowbar", Vector3(-6.0, 2.2, 5.5), Vector3(-6.0, 1.0, 10.0), 55.0],
		["seat_radius_library_lounge", Vector3(-7.5, 2.8, -3.0), Vector3(-12.0, 0.8, -6.8), 50.0],
		["seat_radius_library_reading", Vector3(-10.5, 2.4, 2.5), Vector3(-14.5, 0.8, 2.8), 50.0],
	],
	"train": [
		["seat_radius_train_overhead", Vector3(0, 26, 4), Vector3(0, 0, 0), 50.0],
		["seat_radius_train_row_01", Vector3(0, 3.2, -6.5), Vector3(0, 1.0, -10.5), 55.0],
		["seat_radius_train_row_02", Vector3(0, 3.2, 5.5), Vector3(0, 1.0, 1.5), 55.0],
		["seat_radius_train_aisle", Vector3(0, 2.2, 12.0), Vector3(0, 1.0, 2.0), 55.0],
	],
}

const ROOM_INDEX := {"library": 0, "garden": 1, "cafe": 1, "train": 2}

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--room="):
			room = arg.trim_prefix("--room=")
	root.get_node("GameState").persistence_enabled = false
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	shots = SETS.get(room, SETS["library"])

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		app.current_room_name = root.get_node("GameState").ROOMS[int(ROOM_INDEX.get(room, 0))]
		app.build_room(int(ROOM_INDEX.get(room, 0)))
	if frame == 120:
		var xray = app.world_root.get_node_or_null("PlayerOcclusionXRay")
		if xray != null:
			xray.enabled = false
		for c in app.world_root.find_children("*", "CanvasLayer", true, false):
			if int(c.layer) == 200:
				c.queue_free()
		app._set_debug_spots(true)
	if frame == 150 and idx < shots.size():
		var s: Array = shots[idx]
		cam = Camera3D.new()
		app.world_root.add_child(cam)
		cam.fov = float(s[3])
		cam.global_transform = Transform3D(Basis(), s[1]).looking_at(s[2])
		cam.make_current()
		idx += 1
		frame = 151
	if frame == 170 and idx > 0 and idx <= shots.size():
		if is_instance_valid(cam):
			cam.make_current()
		RenderingServer.force_draw(false)
		var img: Image = root.get_texture().get_image()
		var img2: Image = root.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute("art_reviews/radii")
		print("SHOT ", shots[idx - 1][0], " err=", img2.save_png("art_reviews/radii/" + str(shots[idx - 1][0]) + ".png"))
		for c in app.world_root.find_children("*", "Camera3D", false, false):
			if (c as Camera3D) != app.follow_camera_rig.camera:
				(c as Node).free()
		cam = null
		frame = 149
		if idx >= shots.size():
			print("RADII SHOTS DONE")
			quit()
	return false
