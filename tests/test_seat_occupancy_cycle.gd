extends SceneTree

# Occupancy cycle: free -> reserved (sit) -> released. Overlay must follow.
# Then Library build: legacy disc cushions must still install (shared code intact).

var app
var frame := 0
var stage := 0
var target_spot = null
var target_mesh: MeshInstance3D

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	root.get_node("GameState").persistence_enabled = false
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)

func _overlay_of(mesh: MeshInstance3D) -> String:
	var driver = app.world_root.get_node_or_null("SeatHighlightDriver")
	if driver == null or mesh == null:
		return "nodriver"
	var ov = mesh.material_overlay
	if ov == driver.get("dim_mat"):
		return "dim"
	if ov == driver.get("bright_mat"):
		return "bright"
	if ov == null:
		return "none"
	return "other"

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		app.current_room_name = root.get_node("GameState").ROOMS[1]
		app.build_room(1)
	if frame == 200 and stage == 0:
		stage = 1
		app._ft_install_seat_glows()
		app.player.global_position = Vector3(-8.6, 0.1, 5.6)
		for s in app.study_spots:
			if str(s.seat_id) == "cafe-G12":
				target_spot = s
		var driver = app.world_root.get_node_or_null("SeatHighlightDriver")
		target_mesh = driver.call("bound_mesh", target_spot)
		print("OCC free-avail=", target_spot.is_available())
	if frame == 260 and stage == 1:
		stage = 2
		print("OCC free-overlay=", _overlay_of(target_mesh), " (expect dim or bright)")
		target_spot.reserve("test_player", 2)
		print("OCC reserved-avail=", target_spot.is_available())
	if frame == 300 and stage == 2:
		stage = 3
		print("OCC sat-overlay=", _overlay_of(target_mesh), " (expect none)")
		target_spot.release()
		print("OCC released-avail=", target_spot.is_available())
	if frame == 340 and stage == 3:
		stage = 4
		print("OCC back-overlay=", _overlay_of(target_mesh), " (expect dim or bright)")
		print("OCC CAFE DONE; building library")
		app.build_room(0)
	if frame == 500 and stage == 4:
		stage = 5
		app._ft_install_seat_glows()
		var discs := 0
		var glows := 0
		for n in app.world_root.find_children("*", "Node", true, false):
			if str(n.name) == "AvailableSeatCushion":
				discs += 1
			if str(n.name) == "AvailabilityGlow":
				glows += 1
		print("OCC library glows=", glows, " discs=", discs, " (expect discs>0, legacy intact)")
		print("OCC DONE")
		quit()
	return false
