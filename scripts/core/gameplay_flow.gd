extends Node
## GameplayFlow — non-UI gameplay controller for seating + focus sessions.
##
## Owns the mechanics (never presentation): distance validation, reservation,
## sit/stand transitions, seated cameras, focus start/complete/cancel, rewards.
## Production UI (application_flow) and the dev panel both consume this API;
## nothing here builds UI, navigates UI states, or reads UI state.
## Return codes let UI layers map outcomes to their own navigation/toasts.

var main = null
var busy := false
var focus_duration := 25 * 60
var owns_session := false
var elapsed_minutes := 0
var reward := 0
var on_break := false

signal seat_taken(seat_id: String)
signal stood_up
signal focus_started(minutes: int)
signal focus_completed(minutes: int, reward: int)
signal focus_cancelled
signal room_changed(room_index: int)


func configure(owner_node: Node) -> void:
	main = owner_node


func seated() -> bool:
	return main != null and is_instance_valid(main.active_study_spot)


func note(message: String) -> void:
	print("[StudyTown] ", message)


func try_interact() -> void:
	# E key in gameplay: sit on the nearest valid seat.
	if main == null or busy or seated():
		return
	if main.screen != main.Screen.ROOM:
		return
	main._update_nearest_spot()
	if main.nearest_spot >= 0:
		await take_seat(main.nearest_spot)


func take_seat(index: int, review := false) -> String:
	# Full validated sit mechanics. Returns a result code; no UI side effects.
	if main == null or busy:
		return "busy"
	if index < 0 or index >= main.study_spots.size():
		return "invalid"
	var spot = main.study_spots[index]
	if (
		not review
		and (
			main.player.global_position.distance_to(spot.standing_position)
			> spot.interaction_radius
		)
	):
		return "too_far"
	if not spot.reserve("local_player", StudySpot.OccupantType.PLAYER):
		return "taken"
	busy = true
	main.active_study_spot = spot
	main.pending_study_spot = spot
	main.session_setup_open = true
	main._set_movement_enabled(false)
	main.seat_highlights_suspended = true
	main._ft_set_seat_glows_enabled(false)
	var lounger: bool = str(spot.seat_type) == "tanning_bed"
	if lounger:
		await main._transition_player_to_resting_spot(spot)
	else:
		await main._transition_player_to_study_spot(spot)
	main.character_loader.set_seated(main.player_visual, true, spot.seated_visual_offset)
	main._play_seated_character_animation(
		main.player_visual, "Resting" if lounger else main._study_animation_for_spot(spot)
	)
	if lounger and not bool(main.player_visual.get_meta("is_imported_character", false)):
		main.player_visual.rotation.x = -PI / 2.0
	main.session_setup_camera = main._ft_make_session_setup_camera(spot)
	if not is_instance_valid(main.session_setup_camera):
		await stand_up()
		busy = false
		return "no_camera"
	var from_camera: Camera3D = main.get_viewport().get_camera_3d()
	main.focus_camera_director.transition(from_camera, main.session_setup_camera, 0.78)
	if not main.focus_camera_director.last_transition_clear:
		await stand_up()
		busy = false
		return "bad_transition"
	await main.get_tree().create_timer(0.80).timeout
	busy = false
	seat_taken.emit(str(main.active_study_spot.seat_id) if is_instance_valid(main.active_study_spot) else "")
	return "ok"


func stand_up() -> void:
	# Full validated stand mechanics: tween to standing anchor, restore the
	# character, return to the exploration camera, restore movement + glows.
	if main == null:
		return
	main.next_shot_at = INF
	main.screen = main.Screen.ROOM
	var spot = main.active_study_spot
	if is_instance_valid(spot):
		if str(spot.seat_type).begins_with("garden_") or spot.has_meta("garden_category"):
			main.character_loader.play_animation(main.player_visual, "Stand", 0.12)
		var motion := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		motion.tween_property(main.player, "global_position", spot.standing_position, 0.7)
		await motion.finished
	main._restore_player_standing()
	main.pending_study_spot = null
	main.session_setup_open = false
	main._transition_back_to_follow_camera()
	if main.focus_camera_director.last_transition_clear and is_instance_valid(main.focus_camera_director.active_tween):
		await main.focus_camera_director.active_tween.finished
	else:
		await main.get_tree().create_timer(0.72).timeout
	main.seat_highlights_suspended = false
	main._ft_set_seat_glows_enabled(true)
	main._set_movement_enabled(true)
	stood_up.emit()


func start_focus(duration_seconds: int) -> String:
	# Direct focus start for the currently occupied StudySpot.
	# No UI-state requirement: seated is the only precondition.
	if not seated():
		return "not_seated"
	if FocusManager.active:
		return "busy"
	on_break = false
	focus_duration = maxi(1, duration_seconds)
	main.session_setup_open = false
	main.pending_study_spot = null
	main.active_session_mode = "focus"
	main.screen = main.Screen.FOCUS
	main.session_focus_text = GameState.current_focus
	main.session_tag_name = GameState.current_tag
	main.selected_duration = focus_duration
	main._prepare_focus_camera_pool(main.active_study_spot)
	main.focus_shot_index = -1
	if is_instance_valid(main.get("garden_seat_director")) and not main.focus_cameras.is_empty():
		main.focus_shot_index = 0
		main.focus_camera_director.transition(main.get_viewport().get_camera_3d(), main.focus_cameras[0], 0.78)
	main.next_shot_at = Time.get_unix_time_from_system() + 25.0
	owns_session = true
	focus_started.emit(int(focus_duration / 60))
	FocusManager.start_session(
		GameState.current_focus if not str(GameState.current_focus).is_empty() else "Quiet focus",
		focus_duration
	)
	return "ok"


func start_break(duration_seconds: int = 300) -> String:
	# Short restorative break: retains the seat, earns no rewards, stays seated.
	if not seated():
		return "not_seated"
	if FocusManager.active:
		return "busy"
	on_break = true
	owns_session = true
	main.active_session_mode = "break"
	main.screen = main.Screen.FOCUS
	focus_started.emit(maxi(1, int(duration_seconds / 60)))
	FocusManager.start_session("Break", maxi(1, duration_seconds))
	return "ok"


func cancel_focus() -> String:
	# Early cancellation: partial reward, stop timer, stand up.
	if not FocusManager.active:
		return "inactive"
	elapsed_minutes = maxi(
		0, (FocusManager.duration_seconds - FocusManager.get_remaining_seconds()) / 60
	)
	if on_break:
		elapsed_minutes = 0
	else:
		GameState.award_session(FocusManager.task, elapsed_minutes, main.current_room_name, false)
	on_break = false
	owns_session = false
	FocusManager.cancel_session()
	await stand_up()
	focus_cancelled.emit()
	return "ok"


func consume_completion() -> bool:
	# Called from the FocusManager.completed handler when this controller
	# owns the running session: full reward, frame the seat, stay seated.
	if not owns_session:
		return false
	var was_break: bool = on_break
	owns_session = false
	on_break = false
	main.next_shot_at = INF
	if is_instance_valid(main.session_setup_camera):
		main.focus_camera_director.transition(
			main.get_viewport().get_camera_3d(), main.session_setup_camera, 0.78
		)
	if was_break:
		note("Break over")
		return true
	elapsed_minutes = maxi(0, FocusManager.duration_seconds / 60)
	reward = GameState.award_session(FocusManager.task, elapsed_minutes, main.current_room_name)
	note("Focus complete: +%d points" % reward)
	focus_completed.emit(elapsed_minutes, reward)
	if main.application_flow != null:
		main.application_flow.elapsed_minutes = elapsed_minutes
		main.application_flow.reward = reward
		main.application_flow.navigate(main.application_flow.State.SESSION_COMPLETE)
		main.get_tree().create_timer(2.4).timeout.connect(_on_complete_cooldown)
	return true


func _on_complete_cooldown() -> void:
	if is_instance_valid(main.active_study_spot) and main.application_flow != null:
		main.application_flow.navigate(main.application_flow.State.BREAK_SETUP)
