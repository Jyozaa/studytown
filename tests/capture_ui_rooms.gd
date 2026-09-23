extends SceneTree

# Room HUD captures (state-polled): cafe + train. Writes art_reviews/ui/.

var app
var flow
var save_data
var frame := 0
var running := false

func _flog(s: String) -> void:
	var f := FileAccess.open("/tmp/uirooms_prog.log", FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open("/tmp/uirooms_prog.log", FileAccess.WRITE)
	f.seek_end()
	f.store_string(s + "\n")
	f.close()

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	save_data = root.get_node("GameState")
	save_data.persistence_enabled = false
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)

func _shot(name: String) -> void:
	await process_frame
	RenderingServer.force_draw(false)
	var img: Image = root.get_texture().get_image()
	var img2: Image = root.get_texture().get_image()
	print("SHOT ", name, " err=", img2.save_png("/Users/joe/Desktop/studytown/art_reviews/ui/" + name + ".png"))
	_flog("shot " + name)

func _await_state(want: int, timeout_s: float) -> void:
	var waited := 0.0
	while flow.state != want and waited < timeout_s:
		await create_timer(0.25).timeout
		waited += 0.25

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		save_data.auth_email = "qa@example.com"
		save_data.onboarding_complete = true
		flow = app.application_flow
		app.show_main_menu()
		flow.navigate(flow.State.MAP)
	if frame == 60 and not running:
		running = true
		_run.call_deferred()
	return false

func _run() -> void:
	await create_timer(0.5).timeout
	flow.map_travel("cafe")
	await _await_state(4, 30.0)
	await create_timer(1.0).timeout
	await _shot("ui_room_cafe")
	flow.open_map()
	await create_timer(0.6).timeout
	flow.map_travel("train")
	await _await_state(4, 30.0)
	await create_timer(1.0).timeout
	await _shot("ui_room_train")
	_flog("rooms done")
	print("UIROOMS DONE")
	quit()
