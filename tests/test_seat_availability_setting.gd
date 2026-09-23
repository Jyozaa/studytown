extends SceneTree

## Seat Availability View state machine (spec 21-25, 27-28, 77).
## Checks: ON+standing highlights, seated clears ALL, standing restores,
## OFF suppresses, OFF never disables E-take-seat interaction.

var app
var flow
var data
var checks := 0
var failures := 0


func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + description)


func _initialize() -> void:
	call_deferred("_run")


func highlights_on() -> int:
	var driver = app.world_root.get_node_or_null("SeatHighlightDriver")
	if driver == null:
		return -1
	var count := 0
	for key in driver.get("entries"):
		var mesh = driver.get("entries")[key]["mesh"]
		if (mesh as GeometryInstance3D).material_overlay != null:
			count += 1
	return count


func _run() -> void:
	data = root.get_node("GameState")
	data.persistence_enabled = false
	data.preferences["seat_availability_view"] = true
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	app.ensure_legacy_flow()
	await process_frame
	await process_frame
	flow = app.application_flow
	data.selected_room = 1
	app.current_room_name = data.ROOMS[1]
	app.build_room(1)
	await create_timer(1.4).timeout
	app._ft_install_seat_glows()
	await create_timer(0.4).timeout

	check(app.seat_highlights_allowed(), "A. setting ON + standing allows highlights")
	check(highlights_on() > 0, "A. available seats actually highlight while standing")

	# Take the nearest seat without teleport fudge: use the real standing anchor.
	var index := -1
	for i in app.study_spots.size():
		if app.study_spots[i].is_available() and app.study_spots[i].seat_type != "tanning_bed":
			index = i
			break
	check(index >= 0, "Room has an available seat")
	app.player.global_position = app.study_spots[index].standing_position
	await flow.take_seat(index)
	await create_timer(0.4).timeout
	check(not app.seat_highlights_allowed(), "B. seated turns the authoritative state off")
	check(highlights_on() == 0, "B. ALL seat highlights disappear when seated")
	check(flow.state == flow.State.SESSION_SETUP, "Session setup follows the seat")
	check(highlights_on() == 0, "C. highlights stay off during session setup")

	flow.start_session()
	await create_timer(0.4).timeout
	check(highlights_on() == 0, "D. highlights stay off during active focus")
	root.get_node("FocusManager").cancel_session()
	await flow.leave_seat()
	await create_timer(0.4).timeout
	check(app.seat_highlights_allowed(), "E. standing restores the allowed state")
	check(highlights_on() > 0, "E. highlights return after standing")

	# F/G: setting OFF suppresses while standing.
	data.preferences["seat_availability_view"] = false
	app.refresh_seat_highlights()
	await create_timer(0.4).timeout
	check(not app.seat_highlights_allowed(), "F. setting OFF suppresses highlights")
	check(highlights_on() == 0, "G. highlights stay off while walking with setting OFF")

	# H: interaction still works with the setting OFF.
	app.player.global_position = app.study_spots[index].standing_position
	app._update_nearest_spot()
	if is_instance_valid(app.prompt_label):
		check(
			app.prompt_label.visible and "TAKE" in app.prompt_label.text,
			"H. seat prompt still appears with highlights off"
		)
	else:
		check(false, "H. seat prompt exists with highlights off")
	check(app.nearest_spot >= 0, "H. nearest seat still resolves with highlights off")
	await flow.take_seat(app.nearest_spot)
	await create_timer(0.4).timeout
	check(flow.state == flow.State.SESSION_SETUP, "H. E-take-seat still works with highlights off")
	await flow.leave_seat()
	await create_timer(0.3).timeout

	# I: turning it back ON restores highlights while standing.
	data.preferences["seat_availability_view"] = true
	app.refresh_seat_highlights()
	await create_timer(0.4).timeout
	check(highlights_on() > 0, "I. turning the setting ON restores highlights while standing")

	print("SEAT AVAILABILITY: %d checks, %d failures" % [checks, failures])
	quit()
