extends SceneTree

# Flow error audit: dashboard -> join cafe -> return home.
# Counts SCRIPT ERROR lines; the run passes only with zero.

var app
var frame := 0
var stage := 0

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	root.get_node("GameState").persistence_enabled = false
	print("FLOWTEST launch -> dashboard")
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	app.ensure_legacy_flow()

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 60 and stage == 0:
		stage = 1
		print("FLOWTEST dashboard settled; joining cafe")
		app.current_room_name = root.get_node("GameState").ROOMS[1]
		app.build_room(1)
	if frame == 200 and stage == 1:
		stage = 2
		app._ft_install_seat_glows()
		app.application_flow.room_loaded()
		print("FLOWTEST cafe room_loaded done")
	if frame == 320 and stage == 2:
		stage = 3
		app.application_flow.home()
		print("FLOWTEST returned home")
	if frame == 420 and stage == 3:
		stage = 4
		var names := []
		for n in app.world_root.find_children("*", "Node", true, false):
			if str(n.get_script()) != "<null>" and "nameplate" in str(n.get_script()).to_lower():
				names.append(n.name)
		print("FLOWTEST nameplate nodes live: ", names)
		print("FLOWTEST DONE")
		quit()
	return false
