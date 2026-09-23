extends SceneTree

# Room-switch regression on the gameplay API (no UI controller):
# standing / seated / completed / cancelled switches across all rooms.

var app
var focus_mgr
var frame := 0
var started := false

func _flog(s: String) -> void:
	var f := FileAccess.open("/tmp/roomswitch.log", FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open("/tmp/roomswitch.log", FileAccess.WRITE)
	f.seek_end()
	f.store_string(s + "\n")
	f.close()

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	root.get_node("GameState").persistence_enabled = false
	focus_mgr = root.get_node("FocusManager")
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)

func _state(tag: String) -> void:
	_flog(tag + " room=" + app.current_room_name + " spots=" + str(app.study_spots.size()) + " seated=" + str(is_instance_valid(app.active_study_spot)) + " move=" + str(app.player.get("movement_enabled")) + " cam=" + str(is_instance_valid(app.explore_camera)) + " glow=" + str(_glow_count()))

func _glow_count() -> int:
	var hi := 0
	var driver = app.world_root.get_node_or_null("SeatHighlightDriver")
	if driver != null:
		for key in driver.get("applied"):
			if int(driver.get("applied")[key]) > 0:
				hi += 1
	return hi

func _first_free() -> int:
	for i in app.study_spots.size():
		if app.study_spots[i].is_available():
			return i
	return -1

func _goto_standing(i: int) -> void:
	var spot = app.study_spots[i]
	app.player.global_position = spot.standing_position
	app.player.velocity = Vector3.ZERO

func _process(_d: float) -> bool:
	frame += 1
	if frame == 60 and not started:
		started = true
		_run.call_deferred()
	return false

func _run() -> void:
	await create_timer(0.5).timeout
	_flog("boot flow-null=" + str(app.application_flow == null))
	_state("T1 standing lib")
	app._enter_room(1)
	await create_timer(0.5).timeout
	_state("T1 cafe")
	var i := _first_free()
	_goto_standing(i)
	await create_timer(0.3).timeout
	var r2: String = await app.gameplay.take_seat(_first_free())
	_flog("T2 sit res=" + r2)
	await app.gameplay.stand_up()
	app._enter_room(2)
	await create_timer(0.5).timeout
	_state("T2 train-after-seated-switch")
	var j := _first_free()
	_goto_standing(j)
	await create_timer(0.3).timeout
	var r3: String = await app.gameplay.take_seat(_first_free())
	_flog("T3 sit res=" + r3)
	var rs: String = app.gameplay.start_focus(300)
	_flog("T3 start res=" + rs + " focus=" + str(focus_mgr.active))
	focus_mgr.end_timestamp = Time.get_unix_time_from_system() - 1.0
	await create_timer(1.5).timeout
	_flog("T3 completed focus=" + str(focus_mgr.active) + " coins=" + str(root.get_node("GameState").focus_coins))
	await app.gameplay.stand_up()
	app._enter_room(0)
	await create_timer(0.5).timeout
	_state("T3 library-after-complete-switch")
	var k := _first_free()
	_goto_standing(k)
	await create_timer(0.3).timeout
	var r4: String = await app.gameplay.take_seat(_first_free())
	_flog("T4 sit res=" + r4)
	var rc: String = app.gameplay.start_focus(300)
	_flog("T4 start res=" + rc)
	var rx: String = await app.gameplay.cancel_focus()
	_flog("T4 cancel res=" + rx + " focus=" + str(focus_mgr.active))
	app._enter_room(1)
	await create_timer(0.5).timeout
	_state("T4 cafe-after-cancel-switch")
	_flog("SWITCH DONE")
	print("SWITCH DONE")
	quit()
