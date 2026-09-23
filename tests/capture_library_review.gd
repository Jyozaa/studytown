extends SceneTree

# Library review capture. Shots defined below; run writes PNGs to
# art_reviews/library/. Edit SHOTS for each QA phase.

var app
var frame := 0
var idx := 0
var cam: Camera3D

const SHOTS := [
	["library_tabletop_bar_end", Vector3(-7.3, 1.9, 8.9), Vector3(-7.3, 1.0, 10.7), 45.0],
	["library_snack_props2", Vector3(12.2, 1.9, -8.4), Vector3(12.6, 1.0, -10.3), 45.0],
	["library_glow_tables", Vector3(-3.2, 3.2, 8.5), Vector3(-3.2, 0.8, 0.5), 50.0],
	["library_glow_lounge", Vector3(-7.5, 2.8, -3.0), Vector3(-12.0, 0.8, -6.8), 50.0],
	["library_glow_west", Vector3(-8.5, 2.2, 7.5), Vector3(-12.3, 0.7, 7.6), 50.0],
	["library_glow_reading", Vector3(9.5, 2.0, 5.5), Vector3(12.6, 0.7, 5.3), 50.0],
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
	if frame == 150 and idx < SHOTS.size():
		var s: Array = SHOTS[idx]
		cam = Camera3D.new()
		app.world_root.add_child(cam)
		cam.fov = float(s[3])
		cam.global_transform = Transform3D(Basis(), s[1]).looking_at(s[2])
		cam.make_current()
		if s.size() > 4:
			app.player.global_position = s[4]
			app.player.velocity = Vector3.ZERO
		idx += 1
		frame = 151
	if frame == 170 and idx > 0 and idx <= SHOTS.size():
		if is_instance_valid(cam):
			cam.make_current()
		RenderingServer.force_draw(false)
		var img: Image = root.get_texture().get_image()
		var img2: Image = root.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute("art_reviews/library")
		print("SHOT ", SHOTS[idx - 1][0], " err=", img2.save_png("art_reviews/library/" + str(SHOTS[idx - 1][0]) + ".png"), " nearest=", (app.study_spots[app.nearest_spot].seat_id if app.nearest_spot >= 0 else "none"))
		for c in app.world_root.find_children("*", "Camera3D", false, false):
			if (c as Camera3D) != app.follow_camera_rig.camera:
				(c as Node).free()
		cam = null
		frame = 149
		if idx >= SHOTS.size():
			print("LIBREVIEW DONE")
			quit()
	return false
