extends SceneTree

# Full-route walk with the REAL player body (capsule r0.52): entrance ->
# tables -> communal -> window bar -> lounge -> counter -> stairs -> climb
# -> upper loop. Ground truth for collision, whatever the audit margins say.

var app
var player: CharacterBody3D
var frame := 0
var phys := 0
var started := false
var wp_index := 0
var last_check := 0
var last_pos := Vector3.ZERO
var stall := 0
var done := false

var waypoints := [
	# Ground loop (y ignored; body walks floors).
	Vector3(0, 0, 9.0), Vector3(2.5, 0, 9.0), Vector3(2.5, 0, 4.5),
	Vector3(2.5, 0, -0.2), Vector3(9, 0, -0.2), Vector3(11.8, 0, -0.2),
	Vector3(11.8, 0, -0.5), Vector3(4, 0, 0), Vector3(0, 0, -2.4),
	Vector3(8, 0, -2.4), Vector3(11, 0, -2), Vector3(13.2, 0, -2),
	Vector3(11, 0, -2), Vector3(9, 0, -2), Vector3(9, 0, 0.3),
	Vector3(3, 0, 0.3), Vector3(3, 0, 4), Vector3(3, 0, 7),
	Vector3(6, 0, 8.6), Vector3(6, 0, 9.8), Vector3(14, 0, 9.8),
	Vector3(14, 0, 7.6), Vector3(13.6, 0, 7.6),
	Vector3(13.6, 0, 9.8),
	Vector3(6, 0, 9.8), Vector3(6, 0, 10.8), Vector3(-6, 0, 10.8),
	Vector3(-6, 0, 8.6), Vector3(-5.9, 0, 4.4), Vector3(-5.9, 0, 2.8),
	Vector3(-7.5, 0, 2.0), Vector3(-11.3, 0, 2.0), Vector3(-11.3, 0, 3.5),
	Vector3(-11.3, 0, -5.0), Vector3(-9.0, 0, -5.0), Vector3(-9.0, 0, -2.8),
	Vector3(-4.0, 0, -2.6), Vector3(-7.0, 0, 3.2), Vector3(-7.0, 0, 5.8),
	Vector3(-6.0, 0, 5.8), Vector3(-6.0, 0, 8.6), Vector3(-6.0, 0, 10.6),
	Vector3(-9.0, 0, 10.6), Vector3(-9.0, 0, 9.4),
	Vector3(-9.0, 0, 10.6), Vector3(-6.0, 0, 10.6), Vector3(-6.0, 0, 9.8),
	Vector3(6.0, 0, 9.8), Vector3(6.0, 0, 8.6), Vector3(3.0, 0, 7.0),
	Vector3(3.0, 0, 4.0), Vector3(3.0, 0, 0.3), Vector3(0.5, 0, -1.0),
	# Lounge + counter + east + stair entry.
	Vector3(0, 0, -2.4), Vector3(10.5, 0, 2.0), Vector3(10.5, 0, 4.4),
	Vector3(10.5, 0, 2.0), Vector3(11.8, 0, 0.5), Vector3(11.8, 0, -0.5),
	Vector3(4, 0, 0), Vector3(0, 0, -2.4), Vector3(8, 0, -2.4),
	Vector3(11, 0, -2), Vector3(13.2, 0, -2), Vector3(11, 0, -2),
	Vector3(9, 0, -2), Vector3(9, 0, 0.3), Vector3(3, 0, 0.3),
	Vector3(3, 0, 4), Vector3(3, 0, 7), Vector3(6, 0, 8.6),
	Vector3(6, 0, 9.8), Vector3(14, 0, 9.8), Vector3(14, 0, 7.6),
	Vector3(13.6, 0, 7.6),
	# Stair climb.
	Vector3(13.6, 0, 5.0), Vector3(13.6, 0, 2.0), Vector3(13.6, 0, -1.0),
	Vector3(13.6, 0, -3.4), Vector3(12.6, 0, -4.6), Vector3(9.0, 0, -4.6),
	# Upper loop.
	Vector3(2.5, 0, -4.4), Vector3(-2.5, 0, -4.4), Vector3(-8.0, 0, -4.4),
	Vector3(-11.8, 0, -4.6), Vector3(-13.2, 0, -4.6), Vector3(-13.2, 0, -9.6),
	Vector3(-8.0, 0, -9.9), Vector3(-2.0, 0, -9.9), Vector3(-2.0, 0, -10.8),
	Vector3(2.5, 0, -10.8), Vector3(2.5, 0, -6.2), Vector3(2.5, 0, -4.4),
	Vector3(7.0, 0, -4.4), Vector3(10.5, 0, -4.4), Vector3(12.5, 0, -4.6),
]

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	root.get_node("GameState").persistence_enabled = false
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		app.current_room_name = root.get_node("GameState").ROOMS[1]
		app.build_room(1)
	if frame == 120 and not started:
		started = true
		player = app.player
		player.set_movement_enabled(false)
		player.global_position = Vector3(0, 0.6, 10.5)
		player.velocity = Vector3.ZERO
		last_pos = player.global_position
		print("ROUTE start")
	return false

func _physics_process(_delta: float) -> bool:
	if not started or done:
		return false
	phys += 1
	if phys < 10:
		return false
	if wp_index >= waypoints.size():
		print("ROUTE SUCCESS final pos=", player.global_position)
		done = true
		quit()
		return false
	var target: Vector3 = waypoints[wp_index]
	var to := target - player.global_position
	to.y = 0.0
	if to.length() < 0.5:
		print("ROUTE wp ", wp_index, " ok y=", snappedf(player.global_position.y, 0.02))
		wp_index += 1
		stall = 0
		last_pos = player.global_position
		last_check = phys
		return false
	var dir := to.normalized()
	player.velocity.x = dir.x * 4.15
	player.velocity.z = dir.z * 4.15
	if player.is_on_floor():
		if player.velocity.y < 0.0:
			player.velocity.y = 0.0
	else:
		player.velocity.y -= 9.8 * _delta
	player.move_and_slide()
	if phys - last_check >= 45:
		var moved: float = Vector2(player.global_position.x - last_pos.x, player.global_position.z - last_pos.z).length()
		if moved < 0.15:
			stall += 1
			if stall >= 3:
				print("ROUTE STUCK at pos=", player.global_position, " wp=", wp_index, " target=", target, " floor=", player.is_on_floor(), " slides=", player.get_slide_collision_count())
				for i in player.get_slide_collision_count():
					var c := player.get_slide_collision(i)
					print("  collider=", c.get_collider(), " normal=", c.get_normal())
				done = true
				quit()
				return false
		else:
			stall = 0
		last_pos = player.global_position
		last_check = phys
	if phys > 6000:
		print("ROUTE TIMEOUT at wp ", wp_index, " pos=", player.global_position)
		done = true
		quit()
	return false
