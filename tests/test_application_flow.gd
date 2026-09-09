extends SceneTree

# Run with --headless --path . --script tests/test_application_flow.gd -- --review=ui_test
# Uses an in-memory save and never edits an authored room or local profile.
const UI := preload("res://scripts/ui/dark_ui.gd")
var failures := 0
var checks := 0
var app
var flow
var save_data
var focus


func _initialize() -> void:
	call_deferred("_run")


func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + description)


func _run() -> void:
	save_data = root.get_node("GameState")
	focus = root.get_node("FocusManager")
	save_data.persistence_enabled = false
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	flow = app.application_flow
	for pair in [
		["0025", 1500],
		["02:00", 7200],
		["0120", 4800],
		["25", 1500],
		["99:99", 7200],
		["0000", 300]
	]:
		check(UI.parse_duration(pair[0]) == pair[1], "Duration parses " + pair[0])
	for pair in [[5, 5], [20, 20], [25, 30], [40, 45], [60, 65], [120, 125]]:
		check(save_data.projected_reward(pair[0]) == pair[1], "Reward at %d minutes" % pair[0])
	check(save_data.projected_reward(0) == 0, "Zero minutes cannot earn a point")
	save_data.onboarding_complete = false
	app.show_main_menu()
	check(flow.state == flow.State.ONBOARDING, "First run opens onboarding")
	for step in 12:
		flow.onboarding_step = step
		flow.draw()
		await process_frame
		check(flow.page.get_child_count() > 0, "Onboarding step %d renders" % step)
	save_data.onboarding_complete = true
	flow.home()
	check(flow.state == flow.State.HOME, "Completed onboarding opens Home")
	for tab in ["Home", "Friends", "Servers", "Stats", "Profile", "Store", "Settings"]:
		flow.dashboard_tab = tab
		flow.draw()
		await process_frame
		check(flow.page.get_child_count() > 0, tab + " destination renders")
	for room in 3:
		app.current_room_name = save_data.ROOMS[room]
		app.build_room(room)
		await physics_frame
		await physics_frame
		await create_timer(0.65).timeout
		var world_id: int = app.world_root.get_instance_id()
		check(flow.state == flow.State.ROOM_EXPLORING, "Room %d starts exploring" % room)
		check(app.player.movement_enabled, "Room %d movement enabled" % room)
		check(app.player.is_on_floor(), "Room %d remains grounded at entry" % room)
		if room == 0:
			check(
				app.explore_camera.global_position.distance_to(app.player.global_position) > 8.0,
				"Invisible Library boundary cannot collapse follow camera"
			)
		var before_walk: Vector3 = app.player.global_position
		Input.action_press("move_forward")
		await create_timer(0.2).timeout
		Input.action_release("move_forward")
		check(
			app.player.global_position.distance_to(before_walk) > 0.05,
			"Room %d WASD moves the grounded player" % room
		)
		for candidate_spot in app.study_spots:
			if not candidate_spot.is_available() or candidate_spot.seat_type == "tanning_bed":
				continue
			app.session_setup_camera = app._ft_make_session_setup_camera(candidate_spot)
			check(
				bool(app.session_setup_camera.get_meta("visibility_validated", false)),
				"Clear setup view for " + candidate_spot.seat_id
			)
		var index := -1
		for i in app.study_spots.size():
			if app.study_spots[i].is_available():
				index = i
				break
		check(index >= 0, "Room %d has an available seat" % room)
		if index < 0:
			continue
		var seat = app.study_spots[index]
		var original: Transform3D = seat.global_transform
		app.player.global_position = seat.standing_position + Vector3(10, 0, 0)
		flow.take_seat(index)
		check(flow.state == flow.State.ROOM_EXPLORING, "E cannot take a distant seat")
		app.player.global_position = seat.standing_position
		await flow.take_seat(index)
		check(flow.state == flow.State.SESSION_SETUP, "Room %d reaches session setup" % room)
		check(seat.occupant_id == "local_player", "Seat is reserved")
		check(not app.player.movement_enabled, "Seated player cannot move")
		check(
			app.player.global_position.distance_to(seat.sitting_position) < 0.001,
			"Player uses authored sitting anchor"
		)
		check(seat.global_transform == original, "Authored seat transform unchanged")
		check(
			bool(app.session_setup_camera.get_meta("visibility_validated", false)),
			"Room %d has a clear front setup camera" % room
		)
		var forward: Vector3 = Basis(Vector3.UP, seat.facing_yaw) * Vector3.FORWARD
		check(
			(app.session_setup_camera.global_position - seat.sitting_position).dot(forward) > 0,
			"Setup is never behind the player"
		)
		for spot in app.study_spots:
			check(
				not spot.get_node("AvailabilityGlow").enabled, "No availability glow while seated"
			)
		flow.duration = 7200
		flow.draw()
		var duration_input := flow.page.find_child("DurationInput", true, false) as LineEdit
		var duration_slider := flow.page.find_child("DurationSlider", true, false) as HSlider
		check(
			duration_input.text == "02:00" and duration_slider.value == 120,
			"Two-hour input and slider sync"
		)
		duration_slider.value = 25
		check(flow.duration == 1500 and duration_input.text == "00:25", "Slider updates time")
		duration_input.text = "0040"
		duration_input.text_changed.emit("0040")
		check(flow.duration == 2400 and duration_slider.value == 40, "Direct digits update slider")
		flow.open_overlay(flow.State.CURRENT_FOCUS_EDITOR)
		flow.focus_text = "An intentional study session"
		flow.tag = "Reading"
		flow.save_focus()
		flow.close_overlay(true)
		check(
			save_data.current_focus == flow.focus_text and save_data.current_tag == "Reading",
			"Focus and tag save"
		)
		flow.open_overlay(flow.State.SESSION_SETTINGS)
		flow.duration = 600
		flow.close_overlay()
		check(flow.duration == 2400, "Closing settings without Save discards draft")
		var camera: Camera3D = app.get_viewport().get_camera_3d()
		flow.debug_short = true
		flow.start_session()
		check(flow.state == flow.State.ACTIVE_SESSION and focus.active, "Start begins timer")
		check(focus.duration_seconds == 10, "Developer short session uses ten seconds")
		check(app.get_viewport().get_camera_3d() == camera, "Start preserves the seated camera")
		check(
			app.next_shot_at > Time.get_unix_time_from_system() + 20,
			"B-roll waits before switching"
		)
		focus.pause_session()
		var remaining: int = focus.get_remaining_seconds()
		await create_timer(0.05).timeout
		check(focus.get_remaining_seconds() == remaining, "Pause holds timer")
		focus.resume_session()
		for overlay_state in [
			flow.State.ROOM_MEMBERS,
			flow.State.PLAYER_PROFILE_OVERLAY,
			flow.State.ROOM_CHAT,
			flow.State.MUSIC_RADIO
		]:
			flow.open_overlay(overlay_state)
			check(focus.active and flow.is_overlay(), "Overlay leaves session running")
			flow.close_overlay()
			check(flow.state == flow.State.ACTIVE_SESSION, "Overlay restores active state")
		flow.request_end()
		check(
			flow.state == flow.State.ENDING_SESSION and focus.active,
			"Early end prompts without cancelling"
		)
		flow.continue_session()
		check(flow.state == flow.State.ACTIVE_SESSION, "Continue returns to session")
		focus.duration_seconds = 1500
		focus.end_timestamp = Time.get_unix_time_from_system() - 1
		await process_frame
		await process_frame
		check(flow.state == flow.State.SESSION_COMPLETE, "Natural completion displays reward")
		check(flow.reward == 30, "25-minute completion awards 30")
		check(seat.occupant_id == "local_player", "Completion retains the seat")
		flow.navigate(flow.State.BREAK_SETUP)
		flow.break_duration = 60
		flow.start_break()
		check(
			flow.state == flow.State.ACTIVE_BREAK and focus.active, "Break starts on the same seat"
		)
		focus.end_timestamp = Time.get_unix_time_from_system() - 1
		await process_frame
		await process_frame
		check(flow.state == flow.State.BREAK_SETUP, "Break completion returns to break options")
		flow.another_session()
		check(
			flow.state == flow.State.SESSION_SETUP and seat.occupant_id == "local_player",
			"Another session keeps the seat"
		)
		await flow.leave_seat(false)
		check(
			flow.state == flow.State.ROOM_EXPLORING and seat.is_available(), "Finish releases seat"
		)
		check(
			app.world_root.get_instance_id() == world_id,
			"Session lifecycle never rebuilds the room"
		)
		check(
			app.player.global_position.distance_to(seat.standing_position) < 0.1,
			"Stand uses authored standing anchor"
		)
		check(seat.global_transform == original, "Full lifecycle preserves authored transforms")
		await flow.take_seat(index, true)
		flow.start_session()
		focus.duration_seconds = 1500
		focus.end_timestamp = Time.get_unix_time_from_system() + 1440
		var coins_before: int = save_data.focus_coins
		flow.request_end()
		await flow.end_early()
		check(
			save_data.focus_coins == coins_before + 1, "Early leave earns only the completed minute"
		)
		check(
			flow.state == flow.State.HOME and not focus.active,
			"Early leave returns home without an active timer"
		)
	print("APPLICATION FLOW: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
