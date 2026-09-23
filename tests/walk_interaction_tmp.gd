extends SceneTree

# Interaction-radius gameplay test: walk routes per room, log nearest-seat
# behaviour + max simultaneous eligible count + cross-floor isolation.

var app
var frame := 0
var stage := 0
var leg := 0
var leg_frame := 0
var last_pos := Vector3.ZERO
var legs: Array = []
var max_eligible := 0
var transitions := 0
var last_nearest := -2
var done4 := false
var done5 := false


func _flog(s: String) -> void:
	var f := FileAccess.open('/tmp/walkprog.log', FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open('/tmp/walkprog.log', FileAccess.WRITE)
	f.seek_end()
	f.store_string(s + '
')
	f.close()

func _initialize() -> void:
	root.get_node("GameState").persistence_enabled = false
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)

func _drive(desired: Vector3) -> void:
	var c: Camera3D = root.get_camera_3d()
	var fwd := Vector3(0, 0, -1)
	var rgt := Vector3(1, 0, 0)
	if c != null:
		var b := c.global_transform.basis
		fwd = Vector3(-b.z.x, 0, -b.z.z).normalized()
		rgt = Vector3(b.x.x, 0, b.x.z).normalized()
	var n := desired.normalized()
	var ix := clampf(n.dot(rgt), -1.0, 1.0)
	var iy := clampf(-n.dot(fwd), -1.0, 1.0)
	for a in ["move_forward", "move_back", "move_left", "move_right"]:
		Input.action_release(a)
	if iy < -0.05:
		Input.action_press("move_forward", -iy)
	elif iy > 0.05:
		Input.action_press("move_back", iy)
	if ix > 0.05:
		Input.action_press("move_right", ix)
	elif ix < -0.05:
		Input.action_press("move_left", -ix)

func _stop() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right"]:
		Input.action_release(a)

func _eligible_count() -> int:
	var n := 0
	var pfloor: bool = app.player.global_position.y > 2.4
	for s in app.study_spots:
		if not s.is_available():
			continue
		if (s.standing_position.y > 2.4) != pfloor:
			continue
		if app.player.global_position.distance_to(s.standing_position) <= float(s.interaction_radius):
			n += 1
	return n

func _process(_d: float) -> bool:
	frame += 1
	if frame % 300 == 1:
		_flog('hb f=' + str(frame) + ' stage=' + str(stage) + ' leg=' + str(leg))
	if frame == 5:
		_flog("cross-floor")
		print("ITEST cafe cross-floor checks")
		app.current_room_name = root.get_node("GameState").ROOMS[1]
		app.build_room(1)
		stage = 1
		frame = 6
	if stage == 1 and frame == 100:
		# Stand on ground floor below upstairs seats.
		app.player.global_position = Vector3(0, 0.1, -6.0)
		app.player.velocity = Vector3.ZERO
		stage = 2
		frame = 101
	if stage == 2 and frame == 160:
		var ns: String = app.study_spots[app.nearest_spot].seat_id if app.nearest_spot >= 0 else "none"
		print("ITEST ground-below-upstairs nearest=", ns, " (must not be cafe-U*)")
		# Teleport upstairs above ground seats.
		app.player.global_position = Vector3(0, 5.0, 2.0)
		app.player.velocity = Vector3.ZERO
		stage = 3
		frame = 161
	if stage == 3 and frame == 220:
		var ns2: String = app.study_spots[app.nearest_spot].seat_id if app.nearest_spot >= 0 else "none"
		print("ITEST upstairs-above-ground nearest=", ns2, " (must not be cafe-G*)")
		# Cafe walk: window bar -> communal -> round tables -> lounge.
		legs = [Vector3(-11.0, 0.1, 1.0), Vector3(-3.5, 0.1, -2.5), Vector3(-9.0, 0.1, 3.0), Vector3(-1.0, 0.1, 3.5), Vector3(6.0, 0.1, 0.5), Vector3(10.5, 0.1, 3.0)]
		app.player.global_position = Vector3(-13.0, 0.1, 1.0)
		leg = 0
		leg_frame = frame
		max_eligible = 0
		transitions = 0
		last_nearest = -2
		stage = 4
	if stage == 4 and frame > 230 and not done4 and leg < legs.size():
		var target: Vector3 = legs[leg]
		var p: Vector3 = app.player.global_position
		var flat := Vector3(target.x - p.x, 0, target.z - p.z)
		max_eligible = maxi(max_eligible, _eligible_count())
		if app.nearest_spot != last_nearest:
			transitions += 1
			last_nearest = app.nearest_spot
		if flat.length() < 1.0:
			leg += 1
			leg_frame = frame
			last_pos = p
		else:
			_drive(flat)
			if frame - leg_frame > 500:
				print("ITEST cafe leg ", leg, " STUCK at ", p)
				leg += 1
				leg_frame = frame
	if stage == 4 and leg >= legs.size() and not done4:
		done4 = true
		_stop()
		print("ITEST cafe walk max_eligible=", max_eligible, " transitions=", transitions)
		_flog("libwalk")
		print("ITEST library walk")
		app.current_room_name = root.get_node("GameState").ROOMS[0]
		app.build_room(0)
		legs = [Vector3(0, 0.1, 6.0), Vector3(-6.0, 0.1, 7.0), Vector3(-5.2, 0.1, 0.5), Vector3(-5.2, 0.1, 2.5), Vector3(-11.0, 0.1, 2.5), Vector3(-8.3, 0.1, 2.5), Vector3(-8.3, 0.1, -6.5), Vector3(-9.4, 0.1, -6.5), Vector3(-8.3, 0.1, -6.5), Vector3(-8.3, 0.1, 1.5), Vector3(-12.0, 0.1, 1.5), Vector3(-12.0, 0.1, 2.5), Vector3(-8.3, 0.1, 1.5), Vector3(-8.3, 0.1, 5.5), Vector3(8.5, 0.1, 5.5), Vector3(11.0, 0.1, 5.5), Vector3(11.5, 0.1, -8.0), Vector3(11.0, 0.1, 5.5), Vector3(8.5, 0.1, 5.5), Vector3(-4.0, 0.1, 5.5), Vector3(-8.0, 0.1, 5.5), Vector3(-6.0, 0.1, 6.5), Vector3(0, 0.1, 6.0), Vector3(0, 0.1, 10.0)]
		app.player.global_position = Vector3(0, 0.1, 10.0)
		leg = 0
		leg_frame = frame
		max_eligible = 0
		transitions = 0
		last_nearest = -2
		stage = 5
	if stage == 5 and not done5 and leg < legs.size():
		var target2: Vector3 = legs[leg]
		var p2: Vector3 = app.player.global_position
		var flat2 := Vector3(target2.x - p2.x, 0, target2.z - p2.z)
		max_eligible = maxi(max_eligible, _eligible_count())
		if app.nearest_spot != last_nearest:
			transitions += 1
			last_nearest = app.nearest_spot
		if flat2.length() < 1.0:
			leg += 1
			leg_frame = frame
		else:
			_drive(flat2)
			if frame - leg_frame > 500:
				print("ITEST library leg ", leg, " STUCK at ", p2, " vel=", app.player.velocity, " cam=", root.get_camera_3d().global_position if root.get_camera_3d() else "nocam", " move=", app.player.get("movement_enabled") if "movement_enabled" in app.player else "?", " nearest=", app.nearest_spot)
				leg += 1
				leg_frame = frame
	if stage == 5 and leg >= legs.size() and not done5:
		done5 = true
		_stop()
		print("ITEST library walk max_eligible=", max_eligible, " transitions=", transitions)
		_flog("trainwalk")
		print("ITEST train walk")
		app.current_room_name = root.get_node("GameState").ROOMS[2]
		app.build_room(2)
		legs = [Vector3(3.2, 0.1, -18.0), Vector3(3.2, 0.1, -8.0), Vector3(3.2, 0.1, 2.0), Vector3(3.2, 0.1, 12.0), Vector3(-3.2, 0.1, 12.0), Vector3(-3.2, 0.1, 2.0), Vector3(-3.2, 0.1, -8.0), Vector3(-3.2, 0.1, -18.0)]
		app.player.global_position = Vector3(3.2, 0.1, -19.0)
		leg = 0
		leg_frame = frame
		max_eligible = 0
		transitions = 0
		last_nearest = -2
		stage = 6
	if stage == 6 and leg < 1000:
		# static check: stand exactly on each spot's anchor, nearest must win
		var s = app.study_spots[leg % app.study_spots.size()]
		if frame % 20 == 0:
			app.player.global_position = s.standing_position + Vector3(0, 0.1, 0)
			app.player.velocity = Vector3.ZERO
		if frame % 20 == 10:
			var ns: String = app.study_spots[app.nearest_spot].seat_id if app.nearest_spot >= 0 else "none"
			if app.nearest_spot != leg % app.study_spots.size() and s.is_available():
				print("ITEST train static ", s.seat_id, " nearest=", ns)
			leg += 1
			if leg >= app.study_spots.size():
				print("ITEST train static done, mismatches above (expect none)")
			print("ITEST DONE")
			quit()
	return false
