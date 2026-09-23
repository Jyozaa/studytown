extends SceneTree

# UI flow captures: auth -> onboarding -> map -> rooms -> launcher/settings ->
# music -> seat prompt -> session setup -> active session -> transitions.
# Writes art_reviews/ui/*.png + /tmp/uiflow_prog.log markers.

var app
var flow
var frame := 0
var running := false

func _flog(s: String) -> void:
	var f := FileAccess.open("/tmp/uiflow_prog.log", FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open("/tmp/uiflow_prog.log", FileAccess.WRITE)
	f.seek_end()
	f.store_string(s + "\n")
	f.close()

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)

func _shot(name: String) -> void:
	await process_frame
	RenderingServer.force_draw(false)
	var img: Image = root.get_texture().get_image()
	var img2: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("/Users/joe/Desktop/studytown/art_reviews/ui")
	print("SHOT ", name, " err=", img2.save_png("/Users/joe/Desktop/studytown/art_reviews/ui/" + name + ".png"))
	_flog("shot " + name)

func _auth_shot(mode: String, name: String) -> void:
	flow.auth_mode = mode
	flow.auth_error = ""
	if mode == "login":
		flow.auth_error = ""
	flow.draw()
	await _shot(name)

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		var save_data = root.get_node("GameState")
		save_data.persistence_enabled = false
		save_data.auth_email = ""
		save_data.onboarding_complete = false
		flow = app.application_flow
		app.show_main_menu()
		flow.boot()
	if frame == 60 and not running:
		running = true
		_run_auth.call_deferred()
	return false

func _run_auth() -> void:
	await create_timer(0.5).timeout
	var save_data = root.get_node("GameState")
	_flog('state=' + str(flow.state) + ' mode=' + flow.auth_mode)
	await _auth_shot("welcome", "ui_welcome")
	await _auth_shot("signup", "ui_signup")
	await _auth_shot("login", "ui_login")
	_flog("auth done")
	# Full journey: sign up -> onboarding -> map -> library.
	flow.submit_auth("signup", "qa@example.com", "password123")
	await create_timer(0.6).timeout
	_flog("authed state=" + str(flow.state))
	for step in 4:
		flow.onboarding_step = step
		flow.draw()
		if step == 0 or step == 3:
			await _shot("ui_onboarding_%d" % (step + 1))
	_flog("onboarding done")
	save_data.onboarding_complete = true
	flow.navigate(flow.State.MAP)
	await create_timer(0.4).timeout
	_flog("post-onboarding state=" + str(flow.state))
	await _shot("ui_map")
	flow.map_travel("library")
	await create_timer(2.5).timeout
	_flog("in-room state=" + str(flow.state))
	await _shot("ui_room_library")
	flow.open_launcher()
	await create_timer(0.5).timeout
	await _shot("ui_launcher")
	flow.launcher_page = "settings"
	flow.draw()
	await create_timer(0.5).timeout
	await _shot("ui_settings")
	flow.close_launcher()
	flow.radio_expanded = true
	flow.draw()
	await create_timer(0.4).timeout
	await _shot("ui_music_expanded")
	flow.radio_expanded = false
	flow.draw()
	await create_timer(0.4).timeout
	await _shot("ui_music_collapsed")
	_flog("rooms-a done")
	# Seat prompt + session setup + active session in the library.
	var seat_idx := -1
	for i in app.study_spots.size():
		if app.study_spots[i].is_available():
			seat_idx = i
			break
	var seat = app.study_spots[seat_idx]
	app.player.global_position = seat.standing_position
	app.player.velocity = Vector3.ZERO
	await create_timer(0.6).timeout
	await _shot("ui_seat_prompt")
	await flow.take_seat(seat_idx, true)
	await create_timer(1.6).timeout
	await _shot("ui_session_setup")
	flow.debug_short = true
	flow.start_session()
	await create_timer(1.0).timeout
	await _shot("ui_focus_active")
	_flog("session done")
	print("UIFLOW AUTH DONE")
	quit()
