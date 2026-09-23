extends SceneTree

var frame := 0
var app
var stage := 0


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
		stage = 1
	if stage == 1 and frame == 150:
		print("CAFE spots=", app.study_spots.size(), " npcs=", app.npcs.size())
		for npc in app.npcs:
			print("NPC ", npc.name, " seated=", npc.setup if "setup" in str(npc) else "?", " pos=", npc.global_position)
		_take_shot("cafe_with_npcs")
	if stage == 2 and frame == 220:
		print("CAFE done")
		quit()
	return false


func _take_shot(label: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	if label == "cafe_with_npcs":
		stage = 2
	DirAccess.make_dir_recursive_absolute("art_reviews/current")
	root.get_texture().get_image().save_png("art_reviews/current/" + label + ".png")
	print("SHOT ", label)
