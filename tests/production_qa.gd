extends SceneTree

# Production UI QA: boots production (no args), drives welcome -> auth ->
# onboarding -> map -> room -> seat/setup/focus/drawers/transitions.
# Writes assets/dev_local/ui_qa/full_production/*.png

var app
var ui
var frame := 0
var running := false
const OUT := "/Users/joe/Desktop/studytown/assets/dev_local/ui_qa/full_production"

func _flog(s: String) -> void:
	var f := FileAccess.open("/tmp/prodqa.log", FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open("/tmp/prodqa.log", FileAccess.WRITE)
	f.seek_end()
	f.store_string(s + "\n")
	f.close()

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	var save_data = root.get_node("GameState")
	save_data.persistence_enabled = false
	save_data.auth_email = ""
	save_data.onboarding_complete = false
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)

func _shot(name: String) -> void:
	await process_frame
	RenderingServer.force_draw(false)
	var img: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(OUT)
	print("SHOT ", name, " err=", img.save_png(OUT + "/" + name + ".png"))
	_flog("shot " + name)

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 60 and not running:
		running = true
		_run.call_deferred()
	return false

func _run() -> void:
	await create_timer(1.2).timeout
	ui = app.prod_ui
	if ui == null:
		_flog("NO PROD UI - dev boot active?")
		print("QUIT-NOPRODUI")
		quit()
		return
	_flog("prod ui up")
	await _shot("startup_welcome")
	ui.auth_submit("qa@test.com", "password123", true)
	await create_timer(0.6).timeout
	ui.onboarding_goto(2)
	await create_timer(0.4).timeout
	await _shot("onboarding_character")
	ui.onboarding_goto(4)
	await create_timer(0.4).timeout
	ui.open_map(false)
	await create_timer(0.6).timeout
	await _shot("world_map")
	ui.travel_to(0)
	await create_timer(4.0).timeout
	# Walk into the room for a representative HUD frame: the raw spawn sits
	# in the doorway with the authored follow camera south of the wall.
	# Prefer a north-side communal desk so the authored south-offset camera
	# stays inside the room and the session camera frames a real table.
	var _free0: Array = []
	for i in app.study_spots.size():
		var s = app.study_spots[i]
		if s.is_available() and str(s.seat_type) == "desk_chair" and s.standing_position.z < 1.0:
			_free0.append(i)
	if _free0.is_empty():
		for i in app.study_spots.size():
			if app.study_spots[i].is_available():
				_free0.append(i)
	app.player.global_position = app.study_spots[_free0[0]].standing_position
	app.player.velocity = Vector3.ZERO
	await create_timer(1.2).timeout
	await _shot("room_library_hud")
	# Seat flow on the north communal desk (seat 6): interior standing view
	# and an authored session framing; south tables sit under the authored
	# follow camera's outside-the-wall line.
	var idx: int = _free0[0]
	if app.study_spots[6].is_available():
		idx = 6
	var spot = app.study_spots[idx]
	app.player.global_position = spot.standing_position
	app.player.velocity = Vector3.ZERO
	await create_timer(1.2).timeout
	await _shot("seat_interaction")
	var res: String = await app.gameplay.take_seat(idx)
	_flog("take_seat=" + res)
	await create_timer(1.6).timeout
	await _shot("focus_setup")
	var rs: String = app.gameplay.start_focus(120)
	_flog("start=" + rs)
	await create_timer(1.0).timeout
	await _shot("focus_active")
	ui.toggle_people()
	await create_timer(0.5).timeout
	await _shot("people_drawer")
	ui.toggle_people()
	ui.toggle_chat()
	ui.chat._send("Hello from the library! Cozy room, good light, great books.")
	ui.chat._send("This is a longer local message to verify that chat lines wrap neatly inside the drawer instead of spilling past its edge.")
	await create_timer(0.5).timeout
	await _shot("local_chat")
	ui.toggle_chat()
	ui.toggle_settings()
	await create_timer(0.5).timeout
	await _shot("settings")
	ui.toggle_settings()
	ui.toggle_minimap()
	await create_timer(0.4).timeout
	await _shot("minimap_library")
	ui.toggle_minimap()
	# Completion via forced expiry.
	var fm = root.get_node("FocusManager")
	fm.end_timestamp = Time.get_unix_time_from_system() - 1.0
	await create_timer(1.5).timeout
	await _shot("focus_complete")
	await app.gameplay.stand_up()
	# Transition frames: travel to cafe, catch cover/black/reveal.
	ui.travel_to(1)
	await create_timer(0.12).timeout
	await _shot("map_transition_cover")
	await create_timer(0.2).timeout
	await _shot("map_transition_black")
	await create_timer(4.0).timeout
	await _shot("map_transition_reveal")
	await _shot("room_garden_hud")
	# Train + Japanese walk-in HUD frames (first free seat, settled camera).
	for _ri in [2, 3]:
		ui.travel_to(_ri)
		await create_timer(4.0).timeout
		var _fr: Array = []
		for i in app.study_spots.size():
			if app.study_spots[i].is_available():
				_fr.append(i)
		if not _fr.is_empty():
			app.player.global_position = app.study_spots[_fr[0]].standing_position
			app.player.velocity = Vector3.ZERO
			await create_timer(1.2).timeout
		await _shot("room_train_hud" if _ri == 2 else "room_japanese_hud")
	# Player card on first NPC.
	var gs = root.get_node("GameState")
	var entries: Array = PeopleDrawer.presence_list(app, {
		"player_name": str(gs.profile.get("name", "You")),
		"focus_active": fm.active,
		"focus_remaining": fm.get_remaining_seconds(),
		"current_tag": str(gs.current_tag),
	})
	if entries.size() > 1:
		ui.show_player_card(entries[1])
		await create_timer(0.4).timeout
		await _shot("player_card")
	_flog("PRODQA DONE")
	print("PRODQA DONE")
	quit()
