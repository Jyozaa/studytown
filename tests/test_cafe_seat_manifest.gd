extends SceneTree

# Seat manifest: one line per café spot (mesh binding, positions, state).
# Also asserts exactly one AvailabilityGlow per spot and no cushion meshes.

var app
var frame := 0
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
	if frame == 200 and not done:
		done = true
		_run()
		quit()
	return false

func _run() -> void:
	app._ft_install_seat_glows()
	var glow_counts := {}
	var cushion_left := 0
	for n in app.world_root.find_children("*", "Node", true, false):
		if str(n.name) == "AvailabilityGlow":
			var p := (n as Node).get_parent()
			glow_counts[p] = int(glow_counts.get(p, 0)) + 1
		if str(n.name) == "AvailableSeatCushion":
			cushion_left += 1
			print("STALE-CUSHION at ", (n as Node3D).global_position)
	var multi := 0
	for spot in app.study_spots:
		var c: int = int(glow_counts.get(spot, 0))
		if c != 1:
			multi += 1
			print("GLOW-COUNT spot=", spot.seat_id, " count=", c)
	print("MANIFEST spots=", app.study_spots.size(), " bad-glow-count=", multi, " stale-cushions=", cushion_left)
	var driver = app.world_root.get_node_or_null("SeatHighlightDriver")
	if driver == null:
		print("MANIFEST ERROR: no driver")
		return
	for line in driver.call("report"):
		print("SEAT ", line)
	var shared := 0
	for key in driver.get("entries"):
		var spots: Array = driver.get("entries")[key]["spots"]
		if spots.size() > 1:
			shared += 1
			var mesh = driver.get("entries")[key]["mesh"]
			var ids := []
			for s in spots:
				ids.append(s.seat_id)
			print("SHARED mesh=", (mesh as Node3D).name, " pos=", (mesh as Node3D).global_position, " spots=", ids)
	print("SHARED-MESH-COUNT=", shared)
	print("MANIFEST DONE")
