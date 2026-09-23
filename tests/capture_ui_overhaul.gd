extends SceneTree

## StudyTown UI overhaul QA tour (spec 75/76/77/83/97).
##
## Writes the required screenshots to a gitignored directory and prints a
## structural layout audit for every captured state:
##   - visible Controls that fall outside the 1280x720 design canvas
##   - sibling panels that overlap heavily
##   - labels whose text cannot fit
##
## Run:
##   Godot --path . --script tests/capture_ui_overhaul.gd -- \
##     --capture-dir=assets/dev_local/ui_qa
##
## Screenshots are development-only and are never committed.

const DESIGN := Vector2(1280, 720)
var app
var flow
var output := "res://assets/dev_local/ui_qa"
var issues := 0


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			output = argument.trim_prefix("--capture-dir=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	call_deferred("_run")


func shot(id: String) -> void:
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(output.path_join(id + ".png"))
	root.get_texture().get_image().save_png(path)
	_audit(id)


func _audit(id: String) -> void:
	var page: Control = flow.page
	if not is_instance_valid(page):
		return
	var problems: Array[String] = []
	_collect(page, page, problems)
	for line in problems:
		issues += 1
		print("UI_AUDIT ", id, " :: ", line)
	print("UI_AUDIT ", id, " :: issues=", problems.size())


func _collect(node: Node, page: Control, problems: Array[String]) -> void:
	var siblings: Array[Panel] = []
	for child in node.get_children():
		if child is Control and (child as Control).visible and (child as Control).size.x > 1.0:
			var control := child as Control
			var rect := control.get_global_rect()
			if (
				rect.position.x < -2.0 or rect.position.y < -2.0
				or rect.end.x > DESIGN.x + 2.0 or rect.end.y > DESIGN.y + 2.0
			):
				problems.append("%s off-canvas rect=%s" % [control.name, str(rect)])
			if control is Label and not (control as Label).autowrap_mode:
				var label := control as Label
				if label.text.length() > 0:
					var needed := label.get_minimum_size().x
					if needed > label.size.x + 6.0:
						problems.append(
							"%s clipped text '%s' needs %.0f has %.0f"
							% [label.name, label.text.left(28), needed, label.size.x]
						)
			if control is Panel:
				siblings.append(control as Panel)
			_collect(control, page, problems)
	for i in siblings.size():
		for j in range(i + 1, siblings.size()):
			var a := siblings[i].get_global_rect()
			var b := siblings[j].get_global_rect()
			var overlap := a.intersection(b)
			if overlap.size.x <= 0.0 or overlap.size.y <= 0.0:
				continue
			var smaller := minf(a.size.x * a.size.y, b.size.x * b.size.y)
			if smaller > 0.0 and (overlap.size.x * overlap.size.y) / smaller > 0.25:
				problems.append(
					"panels overlap %s/%s area=%.2f"
					% [siblings[i].name, siblings[j].name, (overlap.size.x * overlap.size.y) / smaller]
				)


func _fresh() -> void:
	var data = root.get_node("GameState")
	data.persistence_enabled = false
	data.auth_email = ""
	data.onboarding_complete = false
	data.preferences["seat_availability_view"] = true


func _take_available_seat() -> bool:
	for i in app.study_spots.size():
		if app.study_spots[i].is_available() and app.study_spots[i].seat_type != "tanning_bed":
			await flow.take_seat(i, true)
			return true
	return false


func _run() -> void:
	_fresh()
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	flow = app.application_flow
	if flow == null:
		push_error("No application flow")
		quit(1)
		return

	# ---- AUTH / FIRST LAUNCH ------------------------------------------------
	await shot("ui_first_launch")
	flow.auth_mode = "welcome"
	flow.draw()
	await shot("ui_welcome")
	flow.auth_mode = "signup"
	flow.auth_error = ""
	flow.draw()
	await shot("ui_signup")
	flow.auth_mode = "login"
	flow.draw()
	await shot("ui_login")

	# ---- ONBOARDING ---------------------------------------------------------
	flow.onboarding_step = 0
	flow.navigate(flow.State.ONBOARDING)
	await shot("ui_onboarding")
	flow.onboarding_step = 1
	flow.draw()
	await shot("ui_onboarding_buddy")

	# ---- MAP ----------------------------------------------------------------
	root.get_node("GameState").onboarding_complete = true
	flow.navigate(flow.State.MAP)
	await shot("ui_map")
	# Hover the second destination card (Garden Café).
	var buttons: Array = flow.page.find_children("*", "Button", true, false)
	if buttons.size() > 1:
		var target: Button = buttons[buttons.size() - 2] as Button
		var motion := InputEventMouseMotion.new()
		motion.position = target.get_global_rect().get_center()
		app.get_viewport().push_input(motion)
	await shot("ui_map_destination_hover")

	# ---- ROOMS --------------------------------------------------------------
	for room in [0, 1, 2]:
		app.current_room_name = root.get_node("GameState").ROOMS[room]
		app.build_room(room)
		await create_timer(1.4).timeout
		await shot("ui_room_%s" % ["library", "cafe", "train"][room])
		if room == 0:
			# Seat prompt: stand next to an available seat without sitting.
			for spot in app.study_spots:
				if spot.is_available() and spot.seat_type != "tanning_bed":
					app.player.global_position = spot.standing_position
					break
			await create_timer(0.35).timeout
			await shot("ui_seat_prompt")
			await _take_available_seat()
			await shot("ui_session_setup")
			flow.start_session()
			await create_timer(0.8).timeout
			await shot("ui_focus_active")
			# Music cards while seated (HUD level 1).
			flow.radio_expanded = false
			flow.draw()
			await shot("ui_music_collapsed")
			flow.radio_expanded = true
			flow.draw()
			await shot("ui_music_expanded")
			root.get_node("FocusManager").cancel_session()
			await flow.leave_seat()

	# ---- LAUNCHER / SETTINGS -----------------------------------------------
	flow.launcher_open = true
	flow.launcher_page = "menu"
	flow.draw()
	await shot("ui_launcher")
	flow.launcher_page = "settings"
	flow.draw()
	await shot("ui_settings")
	await shot("ui_seat_availability_toggle")
	flow.launcher_open = false
	flow.draw()

	# ---- TRANSITION FRAMES: Library -> Map ----------------------------------
	app.current_room_name = root.get_node("GameState").ROOMS[0]
	app.build_room(0)
	await create_timer(1.2).timeout
	flow.request_exit_to_map()
	for i in 6:
		await create_timer(0.07).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(
			ProjectSettings.globalize_path(output.path_join("seq_library_to_map_%02d.png" % i))
		)
	await create_timer(0.6).timeout

	# ---- TRANSITION FRAMES: Map -> Train ------------------------------------
	flow.navigate(flow.State.MAP)
	flow.map_travel("train")
	for i in 6:
		await create_timer(0.07).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(
			ProjectSettings.globalize_path(output.path_join("seq_map_to_train_%02d.png" % i))
		)
	await create_timer(1.2).timeout
	await shot("ui_after_map_to_train")

	print("UI_QA DONE issues=", issues)
	quit()
