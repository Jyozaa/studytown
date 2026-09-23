extends SceneTree

var app
var frame := 0

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	root.get_node("GameState").persistence_enabled = false
	print("LOADTEST instantiate main")
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		print("LOADTEST build room 1")
		app.current_room_name = root.get_node("GameState").ROOMS[1]
		app.build_room(1)
		print("LOADTEST build returned")
	if frame == 200:
		var layout = app.get("editable_room_layout")
		print("LOADTEST layout=", layout, " spots=", app.study_spots.size(), " npcs=", app.npcs.size())
		var marker = layout.get_node_or_null("CafeRoomMarker")
		print("LOADTEST marker=", marker)
		var traffic = layout.get_node_or_null("CafeTraffic")
		print("LOADTEST traffic=", traffic, " movers=", traffic.get("movers").size() if traffic != null else -1)
		var tagged := 0
		for n in layout.find_children("*", "Node3D", true, false):
			if n.is_in_group("editable_cafe_traffic"):
				tagged += 1
		print("LOADTEST traffic-tagged cars=", tagged)
		print("LOADTEST DONE")
		quit()
	return false
