extends SceneTree

# Single-room dev capture: boots straight into ROOM via selected_room,
# screenshots after settle. Usage: -s tests/capture_devroom.gd -- --room=N
# Writes art_reviews/devstrip/ui_strip_<name>.png

var app
var frame := 0
var room := 0
var done := false
const NAMES := ["library", "cafe", "train"]

func _flog(s: String) -> void:
	var f := FileAccess.open("/tmp/devroom_prog.log", FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open("/tmp/devroom_prog.log", FileAccess.WRITE)
	f.seek_end()
	f.store_string(s + "\n")
	f.close()

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
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
	if frame == 250 and not done:
		done = true
		_flog("room=%d settled" % room)
		await process_frame
		RenderingServer.force_draw(false)
		var img: Image = root.get_texture().get_image()
		var img2: Image = root.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute("/Users/joe/Desktop/studytown/art_reviews/devstrip")
		var err = img2.save_png("/Users/joe/Desktop/studytown/art_reviews/devstrip/ui_strip_%s.png" % NAMES[room])
		_flog("shot err=%d" % err)
		print("DEVROOM DONE")
		quit()
	return false
