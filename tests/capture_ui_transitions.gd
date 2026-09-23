extends SceneTree

# Transition + multi-room captures: library door exit (bar sweep frames),
# map, cafe/train HUD, dashboard. Writes art_reviews/ui/transition_*.png etc.

var app
var flow
var save_data
var frame := 0
var running := false

func _flog(s: String) -> void:
	var f := FileAccess.open("/tmp/uitrans_prog.log", FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open("/tmp/uitrans_prog.log", FileAccess.WRITE)
	f.seek_end()
	f.store_string(s + "\n")
	f.close()

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	save_data = root.get_node("GameState")
	save_data.persistence_enabled = false
	save_data.auth_email = "qa@example.com"
	save_data.onboarding_complete = true
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	app.ensure_legacy_flow()

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
	_flog("state=" + str(flow.state) + " want=" + str(want))

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		flow = app.application_flow
		app.show_main_menu()
		flow.navigate(flow.State.MAP)
	if frame == 60 and not running:
		running = true
		_run.call_deferred()
	return false

func _run() -> void:
	await create_timer(0.5).timeout
	await _shot("ui_map_final")
	# Into the library, walk to the door, exit through it.
	flow.map_travel("library")
	await _await_state(4, 20.0)
	_flog("lib state=" + str(flow.state))
	app.player.global_position = Vector3(0, 0.1, 10.2)
	app.player.velocity = Vector3.ZERO
	await create_timer(0.4).timeout
	flow.request_exit_to_map()
	await create_timer(0.3).timeout
	await _shot("ui_exit_sweep_mid")
	await _await_state(3, 12.0)
	_flog("after-exit state=" + str(flow.state))
	await _shot("ui_exit_covered")
	await create_timer(0.6).timeout
	await _shot("ui_map_from_exit")
	# Map -> cafe with sweep frames.
	flow.map_travel("cafe")
	await create_timer(0.35).timeout
	await _shot("ui_travel_sweep_mid")
	await _await_state(4, 20.0)
	_flog("cafe state=" + str(flow.state))
	await _shot("ui_room_cafe")
	# Cafe -> map -> train.
	flow.open_map()
	await create_timer(0.5).timeout
	flow.map_travel("train")
	await _await_state(4, 20.0)
	_flog("train state=" + str(flow.state))
	await _shot("ui_room_train")
	# Dashboard home.
	app.show_main_menu()
	await create_timer(0.5).timeout
	_flog("home state=" + str(flow.state))
	await _shot("ui_dashboard")
	_flog("trans done")
	print("UITRANS DONE")
	quit()
