extends SceneTree

# Drives the REAL player body up the stairs with scripted velocity and
# reports where it gets stuck ( faithful move_and_slide collision test).

var app
var player: CharacterBody3D
var frame := 0
var phys := 0
var started := false
var wp_index := 0
var last_progress := Vector3.ZERO
var stall := 0
var done := false

var waypoints := [
	Vector3(13.6, 0.0, 7.6),
	Vector3(13.6, 0.0, 5.0),
	Vector3(13.6, 0.0, 2.0),
	Vector3(13.6, 0.0, -1.0),
	Vector3(13.6, 0.0, -3.4),
	Vector3(12.6, 0.0, -4.6),
	Vector3(9.0, 0.0, -4.6),
	Vector3(9.0, 0.0, -7.0),
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
		player.global_position = Vector3(13.6, 0.6, 9.0)
		player.velocity = Vector3.ZERO
		last_progress = player.global_position
		print("CLIMB start pos=", player.global_position)
	return false

func _physics_process(_delta: float) -> bool:
	if not started or done:
		return false
	phys += 1
	if phys < 10:
		return false
	if wp_index >= waypoints.size():
		print("CLIMB SUCCESS final pos=", player.global_position)
		done = true
		quit()
		return false
	var target: Vector3 = waypoints[wp_index]
	var to := target - player.global_position
	to.y = 0.0
	if to.length() < 0.45:
		print("CLIMB wp ", wp_index, " reached at y=", snappedf(player.global_position.y, 0.01))
		wp_index += 1
		stall = 0
		last_progress = player.global_position
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
	if phys % 30 == 0:
		var moved: float = Vector2(player.global_position.x - last_progress.x, player.global_position.z - last_progress.z).length()
		print("CLIMB f=", phys, " pos=", Vector3(snappedf(player.global_position.x, 0.01), snappedf(player.global_position.y, 0.01), snappedf(player.global_position.z, 0.01)), " floor=", player.is_on_floor(), " wp=", wp_index)
		if moved < 0.08 and phys > 60:
			stall += 1
			if stall >= 3:
				print("CLIMB STUCK at pos=", player.global_position, " heading wp ", wp_index, " ", target)
				_dump_nearby_blockers()
				done = true
				quit()
				return false
		else:
			stall = 0
		last_progress = player.global_position
	if phys > 2400:
		print("CLIMB TIMEOUT pos=", player.global_position)
		done = true
		quit()
	return false

func _dump_nearby_blockers() -> void:
	for body in app.world_root.find_children("*", "StaticBody3D", true, false):
		var b := body as StaticBody3D
		var d: float = Vector2(b.global_position.x - player.global_position.x, b.global_position.z - player.global_position.z).length()
		if d < 3.0:
			var info := b.name + " at " + str(b.global_position)
			for cs in b.find_children("*", "CollisionShape3D", false, false):
				var sh := (cs as CollisionShape3D).shape
				info += " shape=" + (str((sh as BoxShape3D).size) if sh is BoxShape3D else sh.get_class())
			print("NEAR ", info)
