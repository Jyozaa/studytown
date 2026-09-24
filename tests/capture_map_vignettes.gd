extends SceneTree

# Map vignette capture: boots each room, frames an isometric-style view with
# a dedicated camera, saves assets/ui/map/vignette_<id>.png (720x560).
# Usage: -s tests/capture_map_vignettes.gd -- --room=N   (0..3)

var app
var frame := 0
var room := 0
var done := false
const IDS := ["library", "garden", "train", "japanese"]
const BOUNDS := [Vector2(21.2, 15.2), Vector2(15.5, 11.5), Vector2(4.8, 20.2), Vector2(18.2, 14.2)]

func _initialize() -> void:
	root.size = Vector2i(720, 560)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--room="):
			room = int(arg.trim_prefix("--room="))
	var save_data = root.get_node("GameState")
	save_data.persistence_enabled = false
	save_data.selected_room = room
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		root.get_node("GameState").selected_room = room
		app.build_room(room)
	if frame == 220 and not done:
		done = true
		for n in app.ui_root.find_children("*", "Control", true, false):
			(n as Control).visible = false
		var b: Vector2 = BOUNDS[room]
		var dist: float = maxf(b.x, b.y) * 1.15 + 6.0
		var cam := Camera3D.new()
		app.world_root.add_child(cam)
		var azim := 0.6
		cam.position = Vector3(sin(azim) * dist * 0.75, dist * 0.85, cos(azim) * dist * 0.75)
		cam.look_at(Vector3(0, 0.5, 0), Vector3.UP)
		cam.fov = 32.0
		cam.current = true
	if frame == 280 and done:
		await process_frame
		RenderingServer.force_draw(false)
		var img: Image = root.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute("/Users/joe/Desktop/studytown/assets/ui/map")
		var err = img.save_png("/Users/joe/Desktop/studytown/assets/ui/map/vignette_%s.png" % IDS[room])
		print("VIGNETTE %s err=%d" % [IDS[room], err])
		quit()
	return false
