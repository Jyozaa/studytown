extends Node

# Owns navigation, not world construction. Exactly one base state and one
# optional overlay are mounted; overlays never own or pause the session clock.
enum State {
	ONBOARDING,
	HOME,
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
const UI := preload("res://scripts/ui/dark_ui.gd")
const Dashboard := preload("res://scripts/ui/dashboard.gd")
const Onboarding := preload("res://scripts/ui/onboarding.gd")
const SessionPanels := preload("res://scripts/ui/session_panels.gd")
const Social := preload("res://scripts/ui/social_panels.gd")
const Radio := preload("res://scripts/ui/music_controller.gd")

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


func configure(owner_node: Node) -> void:
	main = owner_node
	focus_text = GameState.current_focus
	tag = GameState.current_tag
	deep_focus = bool(GameState.preferences.get("deep_focus", false))
	radio = Radio.new()
	add_child(radio)


func home() -> void:
	state = State.HOME if GameState.onboarding_complete else State.ONBOARDING
	base_state = state
	joining = false
	draw()


func room_loaded() -> void:
	state = State.ROOM_EXPLORING
	base_state = state
	main.session_setup_open = false
	main._ft_install_seat_glows()
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
	if not is_instance_valid(main.ui_root):
		return
	clear_ui()
	var visible_state: int = base_state if is_overlay() else state
	match visible_state:
		State.ONBOARDING:
			Onboarding.build(self, page)
		State.HOME:
			Dashboard.build(self, page)
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
			dim.color = Color(0.02, 0.025, 0.035, 0.65)
			dim.size = Vector2(1280, 720)
			overlay.add_child(dim)
			match state:
				State.CURRENT_FOCUS_EDITOR:
					SessionPanels.focus_editor(self, overlay)
				State.SESSION_SETTINGS:
					SessionPanels.settings(self, overlay)
				State.MUSIC_RADIO:
					radio.build(self, overlay)
		UI.fade(overlay)
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
	draw()
	UI.fade(page)


func open_overlay(next: int) -> void:
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


func join_room(index: int) -> void:
	if joining:
		return
	joining = true
	var cover := UI.panel(page, Rect2(0, 0, 1280, 720), UI.BG, 0)
	UI.label(cover, "Joining %s…" % GameState.ROOMS[index], Rect2(390, 322, 600, 60), 28)
	UI.fade(cover, 0.20)
	await get_tree().create_timer(0.22).timeout
	GameState.selected_room = index
	GameState.save()
	main.current_room_name = GameState.ROOMS[index]
	main.build_room(index)
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
	var from_camera: Camera3D = main.get_viewport().get_camera_3d()
	main.focus_camera_director.transition(from_camera, main.session_setup_camera, 0.78)
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
		var motion := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		motion.tween_property(main.player, "global_position", spot.standing_position, 0.7)
		await motion.finished
	main._restore_player_standing()
	main.pending_study_spot = null
	main.session_setup_open = false
	main._transition_back_to_follow_camera()
	await get_tree().create_timer(0.72).timeout
	main._ft_set_seat_glows_enabled(true)
	if go_home:
		main.show_main_menu()
	else:
		navigate(State.ROOM_EXPLORING)
		main._set_movement_enabled(true)


func back() -> void:
	if is_overlay():
		close_overlay()
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
	var card := UI.panel(main.ui_root, Rect2(300, 28, 680, 50))
	UI.label(card, message, Rect2(18, 5, 644, 40), 14)
	UI.fade(card)
	get_tree().create_timer(3.2).timeout.connect(
		func():
			if is_instance_valid(card):
				card.queue_free()
	)


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
