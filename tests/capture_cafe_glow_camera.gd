extends SceneTree

# Seat-glow audit (player teleported per group) + exploration camera
# before/after framing (follow rig with old vs new offset).

var frame := 0
var app
var stage := 0
var shots: Array = []
var shot_index := 0
var switch_frame := 0
var pending := -1
var review_cam: Camera3D = null

const OLD_OFFSET := Vector3(2.2, 11.8, 16.8)
const OLD_FOV := 42.0

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	root.get_node("GameState").persistence_enabled = false
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)

func _add(label: String, kind: String, player_pos: Vector3, cam_pos := Vector3.ZERO, cam_target := Vector3.ZERO, fov := 42.0, old_cam := false, settle := 30) -> void:
	shots.append({"label": label, "kind": kind, "player": player_pos, "cam": cam_pos, "target": cam_target, "fov": fov, "old": old_cam, "settle": settle})

func _setup() -> void:
	shots.clear()
	_add("ground_floor_all_seats", "review", Vector3(0, 0.1, 7.0), Vector3(0, 11, 9), Vector3(0, 0, -2), 44.0)
	_add("window_bar_glows", "review", Vector3(-11.0, 0.1, 4.5), Vector3(-10.8, 1.7, -1.2), Vector3(-13.8, 0.7, 0.2), 42.0)
	_add("round_table_glows", "review", Vector3(-0.5, 0.1, 3.8), Vector3(-7.5, 2.0, 9.0), Vector3(-3.0, 0.7, 5.5), 42.0)
	_add("communal_table_glows", "review", Vector3(-6.5, 0.1, 4.5), Vector3(-1.0, 2.2, 3.2), Vector3(-3.8, 0.8, 0.8), 42.0)
	_add("lounge_glows", "review", Vector3(7.0, 0.1, 3.2), Vector3(11.5, 2.0, 3.0), Vector3(9.5, 0.6, 6.8), 42.0)
	_add("stairs_nearby_glows", "review", Vector3(9.0, 0.1, 8.5), Vector3(12.0, 2.2, 4.0), Vector3(11.0, 0.8, 6.5), 42.0)
	_add("second_floor_all_seats", "review", Vector3(0, 4.9, -4.5), Vector3(0, 12.0, -3.0), Vector3(0, 4.8, -7.5), 46.0)
	_add("second_floor_table_glows", "review", Vector3(-3.5, 4.9, -4.6), Vector3(1.5, 6.6, -4.8), Vector3(-0.5, 5.5, -7.2), 42.0)
	_add("second_floor_lounge_glows", "review", Vector3(7.0, 4.9, -4.8), Vector3(11.5, 6.6, -4.4), Vector3(9.5, 5.2, -7.2), 42.0)
	_add("seatglow_chair_close", "review", Vector3(-7.8, 0.1, 6.2), Vector3(-5.8, 1.4, 5.6), Vector3(-7.3, 0.5, 7.1), 40.0)
	_add("seatglow_stool_close", "review", Vector3(-10.2, 0.1, 2.6), Vector3(-11.0, 1.2, 1.8), Vector3(-12.5, 0.45, 0.2), 40.0)
	_add("seatglow_couch_close", "review", Vector3(7.0, 0.1, 8.8), Vector3(7.6, 1.4, 5.2), Vector3(9.2, 0.4, 6.9), 40.0)
	_add("camera_ground_before", "follow", Vector3(0, 0.1, 9.0), Vector3.ZERO, Vector3.ZERO, OLD_FOV, true, 100)
	_add("camera_ground_after", "follow", Vector3(0, 0.1, 9.0), Vector3.ZERO, Vector3.ZERO, 40.0, false, 100)
	_add("camera_ground_tables", "follow", Vector3(-5.0, 0.1, 4.0))
	_add("camera_windowbar", "follow", Vector3(-11.0, 0.1, 1.0))
	_add("camera_lounge", "follow", Vector3(10.5, 0.1, 4.5))
	_add("camera_stairs", "follow", Vector3(12.5, 0.1, 6.5))
	_add("camera_second_floor", "follow", Vector3(0, 4.9, -5.0))
	_add("camera_second_lounge", "follow", Vector3(10.0, 4.9, -6.0))
	_add("camera_second_windowbar", "follow", Vector3(5.0, 4.9, -8.5))
	print("Setup shots=", shots.size())

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		app.current_room_name = root.get_node("GameState").ROOMS[1]
		app.build_room(1)
		stage = 1
	if stage == 1 and frame == 120:
		var xray = app.world_root.get_node_or_null("PlayerOcclusionXRay")
		if xray != null:
			xray.enabled = false
		# Bypass the fullscreen xray warmup cover entirely: follow_camera_rig
		# would otherwise steal the current camera for several frames.
		var xray2 = app.world_root.get_node_or_null("PlayerOcclusionXRay")
		if xray2 != null and xray2.has_method("free"):
			for c in app.world_root.find_children("*", "CanvasLayer", true, false):
				if int(c.layer) == 200:
					c.queue_free()
		_setup()
		stage = 2
		shot_index = 0
		_begin_shot()
		shot_index = 1
		switch_frame = frame
	if stage == 2 and shot_index <= shots.size():
		var age := frame - switch_frame
		var need: int = shots[shot_index - 1]["settle"] if shot_index - 1 < shots.size() else 30
		# Dual read (proven pattern from earlier captures): a warm get_image
		# flushes the macOS presenter; the saved shot reads a settled frame.
		if age == need - 12 and pending >= 0:
			var warm: Image = root.get_texture().get_image()
		if age >= need:
			if pending >= 0:
				_take(pending)
				pending = -1
			if shot_index < shots.size():
				_begin_shot()
				shot_index += 1
				switch_frame = frame
			elif shot_index == shots.size() and pending < 0:
				print("ALL SHOTS DONE")
				quit()
	return false

func _begin_shot() -> void:
	var s = shots[shot_index]
	app.player.global_position = s["player"]
	app.player.velocity = Vector3.ZERO
	var rig = app.follow_camera_rig
	if s["kind"] == "follow":
		if review_cam != null:
			review_cam.current = false
		if bool(s["old"]):
			rig.offset = OLD_OFFSET
		else:
			rig.offset = app.current_room_config.camera_offset
		rig.camera.fov = float(s["fov"])
		rig.camera.current = true
	else:
		if review_cam == null:
			review_cam = Camera3D.new()
			app.world_root.add_child(review_cam)
		review_cam.position = s["cam"]
		review_cam.fov = float(s["fov"])
		review_cam.look_at_from_position(s["cam"], s["target"])
		review_cam.current = true
	pending = shot_index

func _take(i: int) -> void:
	DirAccess.make_dir_recursive_absolute("art_reviews/current")
	var shot = shots[i]
	# Follow shots must read the real follow camera; review shots must win
	# over it. Reassert current *inside* the take to avoid a race with the
	# follow rig's per-frame update.
	if shot["kind"] == "follow":
		app.follow_camera_rig.camera.current = true
		if review_cam != null:
			review_cam.current = false
	else:
		if review_cam != null:
			review_cam.current = true
		app.follow_camera_rig.camera.current = false
	# Ensure ordering: review cameras were added to world_root, so they are
	# topmost; force_draw flushes the frame.
	RenderingServer.force_draw(false)
	var img: Image = root.get_texture().get_image()
	if img == null:
		print("SHOT FAIL ", shots[i]["label"])
		return
	print("SHOT ", shots[i]["label"], " err=", img.save_png("art_reviews/current/" + str(shots[i]["label"]) + ".png"))
	if app.nearest_spot >= 0 and app.nearest_spot < app.study_spots.size():
		var spot = app.study_spots[app.nearest_spot]
		print("NEAREST for ", shots[i]["label"], " = ", spot.seat_id)
