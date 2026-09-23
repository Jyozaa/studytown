extends SceneTree
var app
var frame := 0
var idx := 0
var bad := []
var done := false
func _initialize() -> void:
	root.get_node("GameState").persistence_enabled = false
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
func _process(_d: float) -> bool:
	frame += 1
	if frame == 5:
		app.current_room_name = root.get_node("GameState").ROOMS[2]
		app.build_room(2)
	if frame == 120 and not done:
		done = true
	if done and idx < app.study_spots.size():
		var s = app.study_spots[idx]
		app.player.global_position = s.standing_position + Vector3(0, 0.1, 0)
		app.player.velocity = Vector3.ZERO
		idx += 1
		frame = 121
	if frame == 140 and idx > 0 and idx <= app.study_spots.size():
		var s2 = app.study_spots[idx - 1]
		var ns: String = app.study_spots[app.nearest_spot].seat_id if app.nearest_spot >= 0 else "none"
		if app.nearest_spot != idx - 1:
			bad.append(str(s2.seat_id) + "->" + ns)
		frame = 139
		if idx >= app.study_spots.size():
			print("TRAINSTATIC checked=", idx, " mismatched=", bad)
			print("TRAINSTATIC DONE")
			quit()
	return false
