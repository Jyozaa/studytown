extends SceneTree

var app
var frame := 0
var idx := 0
var cam: Camera3D

const SHOTS := [
	["library_collision3_overhead", Vector3(0, 30, 10), Vector3(0, 0, -1), 50.0],
	["library_collision3_bookshelves", Vector3(-7.0, 6.0, 2.0), Vector3(-7.0, 0.5, -8.0), 50.0],
	["library_collision3_tables", Vector3(0, 7.0, 9.0), Vector3(0, 0.5, 1.0), 50.0],
	["library_collision3_windowbar", Vector3(0, 4.0, 5.0), Vector3(0, 0.5, 10.5), 55.0],
	["library_collision3_lounge", Vector3(-11.5, 5.0, -1.5), Vector3(-11.5, 0.5, -6.5), 50.0],
	["library_collision3_counter", Vector3(11.5, 4.0, -5.0), Vector3(12.0, 0.5, -10.5), 50.0],
	["library_collision3_entrance", Vector3(0, 3.5, 5.5), Vector3(0, 1.0, 12.0), 50.0],
]

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	root.get_node("GameState").persistence_enabled = false
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		app.current_room_name = root.get_node("GameState").ROOMS[0]
		app.build_room(0)
	if frame == 120:
		var xray = app.world_root.get_node_or_null("PlayerOcclusionXRay")
		if xray != null:
			xray.enabled = false
		for c in app.world_root.find_children("*", "CanvasLayer", true, false):
			if int(c.layer) == 200:
				c.queue_free()
		call_group("collision_debug", "set_visible", true)
		# Furniture QA: hide room-scale boxes (structural floor + world
		# boundaries) so tight furniture blockers read clearly.
		for dbg in get_nodes_in_group("collision_debug"):
			var mi := dbg as MeshInstance3D
			if mi != null and mi.mesh is BoxMesh and (mi.mesh as BoxMesh).size.x > 8.0:
				mi.visible = false
	if frame == 150 and idx < SHOTS.size():
		var s: Array = SHOTS[idx]
		cam = Camera3D.new()
		app.world_root.add_child(cam)
		cam.fov = float(s[3])
		cam.global_transform = Transform3D(Basis(), s[1]).looking_at(s[2])
		cam.make_current()
		idx += 1
		frame = 151
	if frame == 170 and idx > 0 and idx <= SHOTS.size():
		if is_instance_valid(cam):
			cam.make_current()
		RenderingServer.force_draw(false)
		var img: Image = root.get_texture().get_image()
		var img2: Image = root.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute("art_reviews/library")
		print("SHOT ", SHOTS[idx - 1][0], " err=", img2.save_png("art_reviews/library/" + str(SHOTS[idx - 1][0]) + ".png"))
		for c in app.world_root.find_children("*", "Camera3D", false, false):
			if (c as Camera3D) != app.follow_camera_rig.camera:
				(c as Node).free()
		cam = null
		frame = 149
		if idx >= SHOTS.size():
			print("LIBCOLLISION DONE")
			quit()
	return false
