extends Node

# Owns navigation, not world construction. Exactly one base state and one
# optional overlay are mounted; overlays never own or pause the session clock.
enum State {
	ONBOARDING,
	HOME,
	AUTH,
	MAP,
	ROOM_EXPLORING,
	SEAT_TRANSITION,
	SESSION_SETUP,
	CURRENT_FOCUS_EDITOR,
	SESSION_SETTINGS,
	ACTIVE_SESSION,
	PLAYER_PROFILE_OVERLAY,
	ROOM_MEMBERS,
	ROOM_CHAT,
	MUSIC_RADIO,
	ENDING_SESSION,
	SESSION_COMPLETE,
	BREAK_SETUP,
	ACTIVE_BREAK
}
const UI := preload("res://scripts/ui/study_theme.gd")
const Dashboard := preload("res://scripts/ui/dashboard.gd")
const StudyTheme := preload("res://scripts/ui/study_theme.gd")
const Onboarding := preload("res://scripts/ui/onboarding.gd")
const SessionPanels := preload("res://scripts/ui/session_panels.gd")
const Social := preload("res://scripts/ui/social_panels.gd")
const Radio := preload("res://scripts/ui/music_controller.gd")
const MapScreen := preload("res://scripts/ui/map_screen.gd")
const TransitionFX := preload("res://scripts/ui/transition_fx.gd")
const AuthScreens := preload("res://scripts/ui/auth_screens.gd")
const AppLauncher := preload("res://scripts/ui/app_launcher.gd")
const AuthService := preload("res://scripts/services/auth_service.gd")

var main
var state := State.HOME
var base_state := State.HOME
var page: Control
var overlay: Control
var timer_label: Label
var radio
var onboarding_step := 0
var dashboard_tab := "Home"
var duration := 25 * 60
var break_duration := 5 * 60
var focus_text := ""
var tag := "Study"
var deep_focus := false
var selected_member := 0
var messages: Array[String] = []
var reward := 0
var elapsed_minutes := 0
var generation := 0
var joining := false
var radio_tab := "RADIO"
var radio_expanded := false
var debug_short := false
var ending_was_break := false
var chat_acknowledged := false
var editing_buddy := false
var overlay_snapshot: Dictionary = {}
var auth_mode := "welcome"
var auth_email := ""
var auth_password := ""
var auth_error := ""
var auth_busy := false
var auth_service: RefCounted
var map_via_exit := false
var map_travel_in_progress := false
var launcher_open := false
var launcher_page := "menu"
var transitioning := false
var exit_cooldown := false
# Dev-strip mode: when false, no UI is drawn/presented at all (draw, toast,
# overlays, menus, nameplates are all suppressed) while gameplay logic
# (seating, sessions, room flow) keeps working. Reviews set it true.
var ui_enabled := true
var transition_layer: CanvasLayer
var transition_veil: ColorRect


func configure(owner_node: Node) -> void:
	main = owner_node
	focus_text = GameState.current_focus
	tag = GameState.current_tag
	deep_focus = bool(GameState.preferences.get("deep_focus", false))
	auth_email = str(GameState.auth_email)
	auth_service = AuthService.new()
	radio = Radio.new()
	add_child(radio)
	# Persistent warm dip used by room <-> map transitions. Lives on its own
	# CanvasLayer so clear_ui() rebuilding the page never destroys it.
	transition_layer = CanvasLayer.new()
	transition_layer.name = "TransitionLayer"
	transition_layer.layer = 50
	main.add_child(transition_layer)
	transition_veil = ColorRect.new()
	transition_veil.name = "TransitionVeil"
	transition_veil.color = Color(0.23, 0.15, 0.09, 0.0)
	transition_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_layer.add_child(transition_veil)


func _dip(to_alpha: float, duration: float) -> Tween:
	transition_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := transition_veil.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(transition_veil, "color:a", to_alpha, duration)
	return tween


func _dip_done() -> void:
	transition_veil.color.a = 0.0
	transition_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE


func boot() -> void:
	# Fresh installs (no auth, no onboarding) start at a short splash, then
	# Welcome. Existing saves route as before; completed users land on the Map.
	if str(GameState.auth_email).is_empty() and not GameState.onboarding_complete:
		auth_mode = "splash"
		navigate(State.AUTH)
		await get_tree().create_timer(1.0).timeout
		if auth_mode == "splash":
			auth_mode = "welcome"
			draw()
	elif not GameState.onboarding_complete:
		navigate(State.ONBOARDING)
	else:
		navigate(State.MAP)


func home() -> void:
	state = State.HOME if GameState.onboarding_complete else State.ONBOARDING
	base_state = state
	joining = false
	draw()


func room_loaded() -> void:
	state = State.ROOM_EXPLORING
	base_state = state
	map_travel_in_progress = false
	main.session_setup_open = false
	main.seat_highlights_suspended = false
	main._ft_install_seat_glows()
	if ui_enabled:
		Social.install_nameplates(self)
	messages = [
		"Welcome to %s." % main.current_room_name, "Local room • members and chat are simulated."
	]
	for member in members().slice(1):
		messages.append("%s joined the room." % member.name)
	draw()


func clear_ui() -> void:
	for child in main.ui_root.get_children():
		main.ui_root.remove_child(child)
		child.queue_free()
	main.prompt_label = null
	main.debug_label = null
	main.focus_time_label = null
	timer_label = null
	page = Control.new()
	page.name = "ApplicationPage"
	page.size = Vector2(1280, 720)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.ui_root.add_child(page)
	overlay = null


func draw() -> void:
	if not ui_enabled:
		return
	if not is_instance_valid(main.ui_root):
		return
	clear_ui()
	var visible_state: int = base_state if is_overlay() else state
	match visible_state:
		State.ONBOARDING:
			Onboarding.build(self, page)
		State.AUTH:
			if auth_mode == "splash":
				AuthScreens.splash(self, page)
			elif auth_mode == "welcome":
				AuthScreens.welcome(self, page)
			else:
				AuthScreens.form(self, page, auth_mode)
		State.HOME:
			Dashboard.build(self, page)
		State.MAP:
			MapScreen.build(self, page)
		_:
			SessionPanels.hud(self, page, visible_state)
			match visible_state:
				State.SESSION_SETUP:
					SessionPanels.setup(self, page)
				State.ENDING_SESSION:
					SessionPanels.ending(self, page)
				State.SESSION_COMPLETE:
					SessionPanels.complete(self, page)
				State.BREAK_SETUP:
					SessionPanels.break_setup(self, page)
	if is_overlay():
		overlay = Control.new()
		overlay.name = "ExclusiveOverlay"
		overlay.size = Vector2(1280, 720)
		page.add_child(overlay)
		if state in [State.ROOM_MEMBERS, State.ROOM_CHAT, State.PLAYER_PROFILE_OVERLAY]:
			overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			Social.build(self, overlay)
		else:
			var dim := ColorRect.new()
			dim.color = StudyTheme.SCRIM
			dim.size = Vector2(1280, 720)
			dim.mouse_filter = Control.MOUSE_FILTER_STOP
			overlay.add_child(dim)
			match state:
				State.CURRENT_FOCUS_EDITOR:
					SessionPanels.focus_editor(self, overlay)
				State.SESSION_SETTINGS:
					SessionPanels.settings(self, overlay)
				State.MUSIC_RADIO:
					radio.build(self, overlay)
		UI.fade(overlay)
	if launcher_open and state in [State.ROOM_EXPLORING, State.MAP, State.HOME]:
		if launcher_page == "settings":
			AppLauncher.settings(self, page)
		else:
			AppLauncher.launcher(self, page)
	tick(FocusManager.get_remaining_seconds())


func is_overlay() -> bool:
	return (
		state
		in [
			State.CURRENT_FOCUS_EDITOR,
			State.SESSION_SETTINGS,
			State.PLAYER_PROFILE_OVERLAY,
			State.ROOM_MEMBERS,
			State.ROOM_CHAT,
			State.MUSIC_RADIO
		]
	)


func navigate(next: int) -> void:
	generation += 1
	state = next
	base_state = next
	if not ui_enabled:
		return
	draw()
	UI.fade(page)


func open_overlay(next: int) -> void:
	if not ui_enabled:
		return
	if state == State.SEAT_TRANSITION or joining:
		return
	if not is_overlay():
		base_state = state
		overlay_snapshot = {
			"focus": focus_text, "tag": tag, "duration": duration, "deep_focus": deep_focus
		}
	state = next
	main._set_movement_enabled(false)
	draw()


func close_overlay(commit := false) -> void:
	if (
		not commit
		and state in [State.CURRENT_FOCUS_EDITOR, State.SESSION_SETTINGS]
		and not overlay_snapshot.is_empty()
	):
		focus_text = overlay_snapshot.focus
		tag = (
			overlay_snapshot.tag
			if GameState.tags.has(overlay_snapshot.tag)
			else str(GameState.tags[0])
		)
		duration = overlay_snapshot.duration
		deep_focus = overlay_snapshot.deep_focus
	state = base_state
	draw()
	main._set_movement_enabled(state == State.ROOM_EXPLORING)


func submit_auth(mode: String, email: String, password: String) -> void:
	if auth_busy:
		return
	auth_busy = true
	auth_error = ""
	draw()
	# Never log, print, or persist the password.
	var result: Dictionary = (
		auth_service.create_account(email, password)
		if mode != "login" else auth_service.sign_in(email, password)
	)
	auth_busy = false
	if result.is_empty():
		auth_error = str(auth_service.last_error)
		draw()
		return
	auth_email = str(result.email)
	auth_password = ""
	GameState.auth_email = auth_email
	GameState.save()
	if mode != "login" and not GameState.onboarding_complete:
		onboarding_step = 0
		navigate(State.ONBOARDING)
	else:
		navigate(State.MAP)


func open_launcher() -> void:
	if state in [State.SEAT_TRANSITION] or transitioning or joining:
		return
	launcher_open = true
	launcher_page = "menu"
	draw()


func close_launcher() -> void:
	launcher_open = false
	draw()


func open_map() -> void:
	if transitioning or joining:
		return
	if FocusManager.active:
		toast("End your focus session first.")
		return
	if is_instance_valid(main.active_study_spot):
		toast("Stand up first to travel.")
		return
	if state != State.ROOM_EXPLORING and state != State.MAP and state != State.HOME:
		return
	map_via_exit = false
	main.set_map_suppression(true)
	navigate(State.MAP)


func close_map() -> void:
	if state != State.MAP:
		return
	map_via_exit = false
	main.set_map_suppression(false)
	if main.screen == main.Screen.ROOM:
		navigate(State.ROOM_EXPLORING)
	else:
		navigate(State.HOME)


func request_exit_to_map() -> void:
	if not ui_enabled:
		return
	# Reaching a doorway threshold locks movement, bar-sweeps to cover,
	# reveals the Map. One authoritative guard prevents double triggers.
	if state != State.ROOM_EXPLORING or transitioning or joining or exit_cooldown:
		return
	if FocusManager.active or is_instance_valid(main.active_study_spot):
		return
	exit_cooldown = true
	transitioning = true
	map_via_exit = true
	main._set_movement_enabled(false)
	main.set_map_suppression(true)
	await TransitionFX.bar_wipe(
		transition_layer, get_tree(),
		func():
			navigate(State.MAP)
	)
	transitioning = false
	get_tree().create_timer(8.0).timeout.connect(func(): exit_cooldown = false)


func map_travel(destination_id: String) -> void:
	# Spec 41: destination selection disables map input, dips, swaps the room
	# behind an opaque veil, then reveals the loaded room (no stale frames).
	if transitioning or joining:
		return
	var entry: Dictionary = preload("res://scripts/ui/destination_registry.gd").for_id(destination_id)
	if entry.is_empty():
		return
	if FocusManager.active:
		toast("End your focus session first.")
		return
	transitioning = true
	launcher_open = false
	map_via_exit = false
	map_travel_in_progress = true
	await TransitionFX.bar_wipe(
		transition_layer, get_tree(),
		func():
			main.set_map_suppression(false)
			await join_room(int(entry.room_index))
	)
	map_travel_in_progress = false
	transitioning = false


func join_room(index: int) -> void:
	if joining:
		return
	joining = true
	# The transition veil already covers the swap; just let the current frame
	# settle so no half-torn room is ever visible.
	await get_tree().process_frame
	GameState.selected_room = index
	GameState.save()
	main.current_room_name = GameState.ROOMS[index]
	main.build_room(index)
	await get_tree().process_frame
	joining = false


func take_seat(index: int, review := false) -> void:
	if state != State.ROOM_EXPLORING or index < 0 or index >= main.study_spots.size():
		return
	var spot = main.study_spots[index]
	if (
		not review
		and (
			main.player.global_position.distance_to(spot.standing_position)
			> spot.interaction_radius
		)
	):
		return
	if not spot.reserve("local_player", StudySpot.OccupantType.PLAYER):
		toast("That seat is already taken.")
		return
	main.active_study_spot = spot
	main.pending_study_spot = spot
	main.session_setup_open = true
	main._set_movement_enabled(false)
	main.seat_highlights_suspended = true
	main._ft_set_seat_glows_enabled(false)
	navigate(State.SEAT_TRANSITION)
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
		navigate(State.SESSION_SETUP)
		await leave_seat()
		toast("This seat's camera needs attention. Please try another seat.")
		return
	var from_camera: Camera3D = main.get_viewport().get_camera_3d()
	main.focus_camera_director.transition(from_camera, main.session_setup_camera, 0.78)
	if not main.focus_camera_director.last_transition_clear:
		navigate(State.SESSION_SETUP)
		await leave_seat()
		toast("No clear camera approach to that seat.")
		return
	await get_tree().create_timer(0.80).timeout
	navigate(State.BREAK_SETUP if lounger else State.SESSION_SETUP)


func save_focus() -> void:
	GameState.current_focus = focus_text.strip_edges().left(120)
	GameState.current_tag = tag
	GameState.preferences.deep_focus = deep_focus
	GameState.save()
	main.session_focus_text = GameState.current_focus
	main.session_tag_name = tag
	main.selected_duration = duration


func start_session() -> void:
	if state != State.SESSION_SETUP or main.active_study_spot == null:
		return
	save_focus()
	main.session_setup_open = false
	main.pending_study_spot = null
	main.active_session_mode = "focus"
	main.screen = main.Screen.FOCUS
	main._prepare_focus_camera_pool(main.active_study_spot)
	main.focus_shot_index = -1
	if is_instance_valid(main.get("garden_seat_director")) and not main.focus_cameras.is_empty():
		main.focus_shot_index = 0
		main.focus_camera_director.transition(main.get_viewport().get_camera_3d(), main.focus_cameras[0], 0.78)
	# Preserve setup framing for the start; later shots remain slow and quiet.
	main.next_shot_at = Time.get_unix_time_from_system() + 25.0
	navigate(State.ACTIVE_SESSION)
	FocusManager.start_session(
		focus_text if not focus_text.is_empty() else "Quiet focus", 10 if debug_short else duration
	)
	debug_short = false


func tick(remaining: int) -> void:
	if is_instance_valid(timer_label):
		timer_label.text = UI.countdown(remaining)


func request_end() -> void:
	if not FocusManager.active:
		return
	ending_was_break = main.active_session_mode == "break"
	main.next_shot_at = INF
	frame_seat()
	navigate(State.ENDING_SESSION)


func frame_seat() -> void:
	if is_instance_valid(main.session_setup_camera):
		main.focus_camera_director.transition(
			main.get_viewport().get_camera_3d(), main.session_setup_camera, 0.78
		)


func continue_session() -> void:
	main.next_shot_at = Time.get_unix_time_from_system() + 25.0
	navigate(State.ACTIVE_BREAK if ending_was_break else State.ACTIVE_SESSION)


func end_early() -> void:
	if not FocusManager.active:
		return
	elapsed_minutes = maxi(
		0, (FocusManager.duration_seconds - FocusManager.get_remaining_seconds()) / 60
	)
	if not ending_was_break:
		GameState.award_session(FocusManager.task, elapsed_minutes, main.current_room_name, false)
	FocusManager.cancel_session()
	await leave_seat(true)


func completed() -> void:
	main.next_shot_at = INF
	frame_seat()
	if main.active_session_mode == "break":
		navigate(State.BREAK_SETUP)
		return
	elapsed_minutes = maxi(0, FocusManager.duration_seconds / 60)
	reward = GameState.award_session(FocusManager.task, elapsed_minutes, main.current_room_name)
	navigate(State.SESSION_COMPLETE)
	var token := generation
	await get_tree().create_timer(2.4).timeout
	if token == generation and state == State.SESSION_COMPLETE:
		navigate(State.BREAK_SETUP)
	elif is_overlay() and base_state == State.SESSION_COMPLETE:
		base_state = State.BREAK_SETUP


func another_session() -> void:
	main.screen = main.Screen.ROOM
	main.session_setup_open = true
	main.active_session_mode = "focus"
	main.next_shot_at = INF
	if is_instance_valid(main.session_setup_camera):
		main.focus_camera_director.transition(
			main.get_viewport().get_camera_3d(), main.session_setup_camera, 0.78
		)
	navigate(State.SESSION_SETUP)


func start_break() -> void:
	main.active_session_mode = "break"
	main.screen = main.Screen.FOCUS
	main.next_shot_at = Time.get_unix_time_from_system() + 25.0
	navigate(State.ACTIVE_BREAK)
	FocusManager.start_session("A little breathing room", break_duration)


func leave_seat(go_home := false) -> void:
	if state == State.SEAT_TRANSITION:
		return
	navigate(State.SEAT_TRANSITION)
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
		await get_tree().create_timer(0.72).timeout
	main.seat_highlights_suspended = false
	main._ft_set_seat_glows_enabled(true)
	if go_home and ui_enabled:
		main.show_main_menu()
	else:
		navigate(State.ROOM_EXPLORING)
		main._set_movement_enabled(true)


func back() -> void:
	if not ui_enabled:
		return
	if launcher_open:
		if launcher_page == "settings":
			launcher_page = "menu"
			draw()
		else:
			close_launcher()
		return
	if is_overlay():
		close_overlay()
	elif state == State.MAP:
		close_map()
	elif state == State.AUTH:
		return
	elif state == State.SESSION_SETUP:
		leave_seat()
	elif state in [State.ACTIVE_SESSION, State.ACTIVE_BREAK]:
		request_end()
	elif state == State.ENDING_SESSION:
		continue_session()
	elif state in [State.BREAK_SETUP, State.SESSION_COMPLETE]:
		leave_seat(true)
	elif state == State.ROOM_EXPLORING:
		main.show_main_menu()


func input_event(event: InputEvent) -> bool:
	if event.is_action_pressed("menu"):
		back()
		return true
	if event.is_action_pressed("interact"):
		if state == State.ROOM_EXPLORING:
			main._update_nearest_spot()
			take_seat(main.nearest_spot)
		return true
	if event.is_action_pressed("debug_focus") and state == State.ROOM_EXPLORING:
		debug_short = true
		for index in main.study_spots.size():
			if main.study_spots[index].is_available():
				take_seat(index, true)
				break
		return true
	return state != State.ROOM_EXPLORING


func members() -> Array:
	var result: Array = [
		{
			"name": str(GameState.profile.name),
			"country": str(GameState.profile.country),
			"task": focus_text,
			"tag": tag,
			"minutes": 0,
			"character": GameState.selected_character
		}
	]
	var countries := ["GB", "FR", "JP", "CA", "DE", "US"]
	for i in main.npcs.size():
		var npc = main.npcs[i]
		var character_index: int = i % maxi(1, main.character_loader.profiles.size())
		if is_instance_valid(npc.visual):
			var profile = npc.visual.get_meta("character_profile", null)
			if profile != null:
				for index in main.character_loader.profiles.size():
					if main.character_loader.profiles[index].character_id == profile.character_id:
						character_index = index
						break
		result.append(
			{
				"name": str(npc.editor_display_name),
				"country": countries[i % countries.size()],
				"task":
				["One chapter at a time", "Working through my notes", "A little progress today"][
					i % 3
				],
				"tag": ["Reading", "Study", "Work"][i % 3],
				"minutes": 18 + i * 7,
				"character": character_index
			}
		)
	return result


func copy_code() -> void:
	DisplayServer.clipboard_set(
		"STUDYTOWN-%s-1177" % str(main.current_room_config.get("id", "library")).to_upper()
	)
	toast("Room code copied. Local demo; online joining is not connected.")


func toast(message: String) -> void:
	if not ui_enabled:
		print("[StudyTown] ", message)
		return
	StudyTheme.toast(main.ui_root, message)


func run_review(kind: String) -> void:
	GameState.persistence_enabled = false
	if kind == "ui_onboarding":
		GameState.onboarding_complete = false
		main.show_main_menu()
		return
	GameState.onboarding_complete = true
	if kind == "ui_home":
		main.show_main_menu()
		return
	var index := 1 if "garden" in kind else (2 if "train" in kind else 0)
	main.current_room_name = GameState.ROOMS[index]
	main.build_room(index)
	await get_tree().physics_frame
	if "setup" in kind or "active" in kind or "break" in kind or "editor" in kind:
		for i in main.study_spots.size():
			if main.study_spots[i].is_available():
				await take_seat(i, true)
				break
	if "active" in kind:
		start_session()
	if "break" in kind:
		navigate(State.BREAK_SETUP)
	if "editor" in kind:
		open_overlay(State.CURRENT_FOCUS_EDITOR)
	if is_instance_valid(main.active_study_spot):
		print(
			"UI_REVIEW camera=",
			main.session_setup_camera.global_position,
			" seat=",
			main.active_study_spot.sitting_position,
			" clear=",
			main.session_setup_camera.get_meta("visibility_validated")
		)
