extends SceneTree

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
		app._ft_install_seat_glows()
		app.player.global_position = Vector3(-5.0, 0.1, 4.6)
		print("OVERLAY setup done, waiting for driver frames")
	if frame == 260 and done:
		var driver = app.world_root.get_node_or_null("SeatHighlightDriver")
		print("OVERLAY driver=", driver != null, " nearest=", app.nearest_spot)
		if driver != null:
			var counts := {}
			for key in driver.get("entries"):
				var mesh = driver.get("entries")[key]["mesh"]
				var ov = (mesh as GeometryInstance3D).material_overlay
				var state := "none"
				if ov == driver.get("dim_mat"):
					state = "dim"
				elif ov == driver.get("bright_mat"):
					state = "bright"
				else:
					state = "OTHER:" + str(ov)
				counts[state] = int(counts.get(state, 0)) + 1
			print("OVERLAY states: ", counts)
			for line in driver.call("report"):
				print("SEAT ", line)
		print("OVERLAY DONE")
		quit()
	return false
