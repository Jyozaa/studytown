extends SceneTree

var app
var player: CharacterBody3D
var frame := 0
var phys := 0
var started := false
var done := false

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
		player.global_position = Vector3(13.6, 0.6, 7.0)
		player.velocity = Vector3.ZERO
		print("DBG start")
	return false

func _physics_process(delta: float) -> bool:
	if not started or done:
		return false
	phys += 1
	if phys < 10 or phys > 400:
		if phys > 400:
			done = true
			_report()
			quit()
		return false
	player.velocity.x = 0.0
	player.velocity.z = -4.15
	if player.is_on_floor():
		if player.velocity.y < 0.0:
			player.velocity.y = 0.0
	else:
		player.velocity.y -= 9.8 * delta
	player.move_and_slide()
	if phys % 40 == 0:
		print("DBG f=", phys, " pos=", player.global_position, " floor=", player.is_on_floor(), " slides=", player.get_slide_collision_count())
		for i in player.get_slide_collision_count():
			var c := player.get_slide_collision(i)
			print("  slide ", i, " collider=", c.get_collider(), " normal=", c.get_normal(), " pos=", c.get_position())
	return false

func _report() -> void:
	print("=== boxes containing XZ near player ===")
	var pp := player.global_position
	for body in app.world_root.find_children("*", "StaticBody3D", true, false):
		var b := body as StaticBody3D
		if b.collision_layer & 2 == 0 and b.collision_layer != 1:
			continue
		for cs in b.find_children("*", "CollisionShape3D", false, false):
			var sh := (cs as CollisionShape3D).shape
			if sh is BoxShape3D:
				var center: Vector3 = b.global_transform * (cs as Node3D).position
				var size: Vector3 = (sh as BoxShape3D).size
				if absf(pp.x - center.x) < size.x * 0.5 + 0.6 and absf(pp.z - center.z) < size.z * 0.5 + 0.6 and center.y - size.y * 0.5 < 2.0 and center.y + size.y * 0.5 > -0.5:
					print("BOX layer=", b.collision_layer, " name=", b.name, " c=", center, " s=", size, " yaw=", b.global_rotation.y)
	print("=== player capsule ===")
	for cs in player.find_children("*", "CollisionShape3D", false, false):
		print("player shape at ", (cs as Node3D).position, " ", ((cs as CollisionShape3D).shape as CapsuleShape3D).radius, ((cs as CollisionShape3D).shape as CapsuleShape3D).height)
