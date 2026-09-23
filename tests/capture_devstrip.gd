extends SceneTree

# Dev-strip visual QA: boots straight into gameplay (dev boot is automatic),
# captures library/cafe/train + collapsed view. No production UI expected.

var app
var frame := 0
var stage := 0

func _flog(s: String) -> void:
	var f := FileAccess.open("/tmp/devstrip_prog.log", FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open("/tmp/devstrip_prog.log", FileAccess.WRITE)
	f.seek_end()
	f.store_string(s + "\n")
	f.close()

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	root.get_node("GameState").persistence_enabled = false
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)

func _shot(name: String) -> void:
	RenderingServer.force_draw(false)
	var img: Image = root.get_texture().get_image()
	var img2: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("/Users/joe/Desktop/studytown/art_reviews/devstrip")
	print("SHOT ", name, " err=", img2.save_png("/Users/joe/Desktop/studytown/art_reviews/devstrip/" + name + ".png"))
	_flog("shot " + name)


func _process(_delta: float) -> bool:
	frame += 1
	if frame % 100 == 1:
		_flog("hb %d stage=%d" % [frame, stage])
	if frame == 200 and stage == 0:
		stage = 1
		_flog("lib")
		_shot("ui_strip_library")
		_flog("switching to cafe")
		app._enter_room(1)
		app.dev_panel.refresh()
		_flog("cafe ready")
		stage = 2
		frame = 201
	if frame == 400 and stage == 2:
		stage = 3
		_flog("cafe")
		await _shot("ui_strip_cafe")
		_flog("switching to train")
		app._enter_room(2)
		app.dev_panel.refresh()
		_flog("train ready")
		stage = 4
		frame = 401
	if frame == 600 and stage == 4:
		stage = 5
		_flog("train")
		await _shot("ui_strip_train")
		app.dev_panel._set_collapsed(true)
		stage = 6
		frame = 601
	if frame == 700 and stage == 6:
		_flog("clean")
		await _shot("ui_strip_clean_gameplay")
		print("DEVSTRIP DONE")
		quit()
	return false
