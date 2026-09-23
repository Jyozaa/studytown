extends SceneTree
var app
var frame := 0
var legs := [Vector3(0,0.1,10.0), Vector3(0,0.1,6.0), Vector3(8.5,0.1,6.0), Vector3(8.5,0.1,8.0), Vector3(-6.0,0.1,6.5), Vector3(-5.0,0.1,2.0), Vector3(-11.0,0.1,2.0), Vector3(-9.3,0.1,7.5), Vector3(-8.5,0.1,2.0), Vector3(-8.5,0.1,-9.9), Vector3(-9.5,0.1,-6.5), Vector3(-8.3,0.1,-2.0), Vector3(-8.3,0.1,1.5), Vector3(-12.0,0.1,1.5), Vector3(-12.0,0.1,2.5), Vector3(-8.0,0.1,4.0), Vector3(-4.0,0.1,5.0), Vector3(0,0.1,5.0), Vector3(0,0.1,-5.0), Vector3(0,0.1,-9.5), Vector3(0,0.1,-5.0), Vector3(0,0.1,5.0), Vector3(4.0,0.1,5.0), Vector3(8.0,0.1,4.0), Vector3(11.0,0.1,4.5), Vector3(11.0,0.1,-2.0), Vector3(11.5,0.1,-8.0), Vector3(11.0,0.1,-2.0), Vector3(8.0,0.1,4.0), Vector3(4.0,0.1,5.0), Vector3(0,0.1,5.0), Vector3(0,0.1,6.0), Vector3(0,0.1,10.0)]
var leg := 0
var leg_frame := 0
var last_pos := Vector3.ZERO
var stuck := []
var done := false
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
func _process(_d: float) -> bool:
	frame += 1
	if frame == 5:
		app.current_room_name = root.get_node("GameState").ROOMS[0]
		app.build_room(0)
		app.player.global_position = legs[0]
		last_pos = legs[0]
		leg = 1
		leg_frame = frame
	if frame > 10 and not done and leg < legs.size():
		var target: Vector3 = legs[leg]
		var p: Vector3 = app.player.global_position
		var flat := Vector3(target.x - p.x, 0, target.z - p.z)
		if flat.length() < 1.0:
			print("WALK leg ", leg, " reached")
			leg += 1
			leg_frame = frame
			last_pos = p
		else:
			_drive(flat)
			if frame - leg_frame > 900:
				print("WALK leg ", leg, " STUCK at ", p)
				stuck.append(leg)
				leg += 1
				leg_frame = frame
			elif frame % 150 == 0:
				if p.distance_to(last_pos) < 0.25 and frame - leg_frame > 150:
					print("WALK leg ", leg, " NO PROGRESS at ", p)
					stuck.append(leg)
					leg += 1
					leg_frame = frame
				last_pos = p
	if leg >= legs.size() and not done:
		done = true
		for a in ["move_forward", "move_back", "move_left", "move_right"]:
			Input.action_release(a)
		print("WALK stuck_legs=", stuck, " (expect [])")
		print("WALK DONE")
		quit()
	return false
