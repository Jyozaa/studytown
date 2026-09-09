extends SceneTree

# Visual regression tour. Screenshots go ONLY to the supplied absolute temp
# directory because local character/room screenshots must never be committed.
var app
var flow
var output := ""


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			output = argument.trim_prefix("--capture-dir=")
	if not output.begins_with("/tmp/"):
		printerr("Pass --capture-dir=/tmp/<existing-directory>")
		quit(1)
		return
	call_deferred("_run")


func shot(id: String) -> void:
	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(output.path_join(id + ".png"))
	print("UI_CAPTURE ", id, " result=", result)


func _run() -> void:
	var data = root.get_node("GameState")
	data.persistence_enabled = false
	data.onboarding_complete = false
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	flow = app.application_flow
	if flow == null:
		quit(1)
		return
	app.show_main_menu()
	await shot("01-onboarding")
	flow.onboarding_step = 2
	flow.draw()
	await shot("02-character")
	data.onboarding_complete = true
	flow.home()
	await shot("03-home")
	for room in 3:
		app.current_room_name = data.ROOMS[room]
		app.build_room(room)
		await physics_frame
		await shot("04-exploring-%d" % room)
		for i in app.study_spots.size():
			if app.study_spots[i].is_available():
				await flow.take_seat(i, true)
				break
		await shot("05-setup-%d" % room)
		if room < 2:
			await flow.leave_seat()
	flow.open_overlay(flow.State.CURRENT_FOCUS_EDITOR)
	await shot("06-focus-editor")
	flow.close_overlay()
	flow.open_overlay(flow.State.SESSION_SETTINGS)
	await shot("07-session-settings")
	flow.close_overlay()
	flow.start_session()
	await shot("08-active-session")
	for mode in [
		flow.State.ROOM_MEMBERS,
		flow.State.PLAYER_PROFILE_OVERLAY,
		flow.State.ROOM_CHAT,
		flow.State.MUSIC_RADIO
	]:
		flow.open_overlay(mode)
		await shot("09-overlay-%d" % mode)
		flow.close_overlay()
	flow.radio_tab = "SOUNDSCAPE"
	flow.open_overlay(flow.State.MUSIC_RADIO)
	await shot("10-soundscape")
	flow.close_overlay()
	flow.request_end()
	await shot("11-ending")
	flow.continue_session()
	var timer = root.get_node("FocusManager")
	timer.end_timestamp = Time.get_unix_time_from_system() - 1
	await process_frame
	await shot("12-complete")
	flow.navigate(flow.State.BREAK_SETUP)
	await shot("13-break-setup")
	flow.start_break()
	await shot("14-active-break")
	timer.cancel_session()
	quit()
