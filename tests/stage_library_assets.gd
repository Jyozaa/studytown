extends SceneTree

# Library asset scale staging: one row of candidate assets + player.
# Prints AABB (size, floor offset) per asset, screenshots side view.

const PACK := "res://assets/source/cafe_packs/"

var app
var frame := 0

const ITEMS := [
	["furniture_bits/Assets/gltf/table_medium_long.gltf", 1.0],
	["furniture_bits/Assets/gltf/table_medium.gltf", 1.0],
	["furniture_bits/Assets/gltf/table_small.gltf", 1.0],
	["furniture_bits/Assets/gltf/table_low.gltf", 1.0],
	["furniture_bits/Assets/gltf/chair_A_wood.gltf", 1.0],
	["furniture_bits/Assets/gltf/chair_B_wood.gltf", 1.0],
	["furniture_bits/Assets/gltf/chair_stool_wood.gltf", 1.0],
	["furniture_bits/Assets/gltf/couch_pillows.gltf", 1.0],
	["furniture_bits/Assets/gltf/armchair_pillows.gltf", 1.0],
	["furniture_bits/Assets/gltf/lamp_standing.gltf", 1.0],
	["furniture_bits/Assets/gltf/lamp_table.gltf", 1.0],
	["furniture_bits/Assets/gltf/rug_rectangle_A.gltf", 1.0],
	["furniture_bits/Assets/gltf/cabinet_medium_decorated.gltf", 1.0],
	["furniture_bits/Assets/gltf/book_set.gltf", 1.0],
	["restaurant_bits/Assets/gltf/table_round_A.gltf", 1.0],
	["restaurant_bits/Assets/gltf/kitchencounter_straight_A_decorated.gltf", 1.0],
	["restaurant_bits/Assets/gltf/fridge_A_decorated.gltf", 1.0],
	["restaurant_bits/Assets/gltf/menu.gltf", 1.0],
	["Low Poly Furniture/Electronics/Laptop.fbx", 0.15],
	["Low Poly Furniture/Miscellaneous/Mug.fbx", 0.15],
	["nature/Assets/gltf/Tree_1_A_Color1.gltf", 1.0],
	["nature/Assets/gltf/Tree_2_C_Color1.gltf", 1.0],
	["nature/Assets/gltf/Bush_1_A_Color1.gltf", 1.0],
	["nature/Assets/gltf/Rock_1_M_Color1.gltf", 1.0],
	["city/road_straight.gltf", 1.0],
	["city/streetlight.gltf", 1.0],
	["city/bench.gltf", 1.0],
	["city/car_sedan.gltf", 1.0],
	["blocks/grass.gltf", 1.0],
	["blocks/dirt_with_grass.gltf", 1.0],
	["blocks/stone_dark.gltf", 1.0],
]

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	root.get_node("GameState").persistence_enabled = false
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)

func _aabb_of(node: Node) -> AABB:
	var box := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		if m == null:
			continue
		var t: Transform3D = (mi as Node3D).global_transform
		var corners := [
			t * m.get_aabb().position, t * (m.get_aabb().position + m.get_aabb().size),
			t * (m.get_aabb().position + Vector3(m.get_aabb().size.x, 0, 0)),
			t * (m.get_aabb().position + Vector3(0, m.get_aabb().size.y, 0)),
			t * (m.get_aabb().position + Vector3(0, 0, m.get_aabb().size.z)),
		]
		for c in corners:
			if first:
				box = AABB(c, Vector3.ZERO)
				first = false
			else:
				box = box.expand(c)
	return box

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		app.current_room_name = root.get_node("GameState").ROOMS[0]
		app.build_room(0)
	if frame == 120:
		# Temp ground far south of the library shell.
		var ground := StaticBody3D.new()
		ground.position = Vector3(0, -0.5, 60)
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(140, 1, 30)
		col.shape = shape
		ground.add_child(col)
		var vis := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(140, 1, 30)
		vis.mesh = bm
		ground.add_child(vis)
		app.world_root.add_child(ground)
		var x := -60.0
		for item in ITEMS:
			var packed: PackedScene = load(PACK + item[0])
			if packed == null:
				print("STAGE MISSING: ", item[0])
				continue
			var node := packed.instantiate() as Node3D
			app.world_root.add_child(node)
			node.position = Vector3(x, 0, 60)
			node.scale = Vector3.ONE * float(item[1])
			var box := _aabb_of(node)
			print("STAGE %s size=%s miny=%.2f" % [item[0].get_file(), str(box.size), box.position.y])
			x += 4.0
		app.player.global_position = Vector3(-64, 0.1, 57)
		print("STAGE DONE placing")
	if frame == 200:
		var cam := Camera3D.new()
		app.world_root.add_child(cam)
		cam.fov = 40.0
		cam.global_transform = Transform3D(Basis(), Vector3(-30, 4, 48)).looking_at(Vector3(-30, 1, 60))
		cam.make_current()
		app.hud.hide()
	if frame == 230:
		var img: Image = root.get_texture().get_image()
		var img2: Image = root.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute("art_reviews/library")
		print("STAGE shot err=", img2.save_png("art_reviews/library/stage_west.png"))
	if frame == 240:
		for cam in app.world_root.find_children("*", "Camera3D", false, false):
			if (cam as Camera3D).name != "":
				pass
		var cam2 := Camera3D.new()
		app.world_root.add_child(cam2)
		cam2.fov = 40.0
		cam2.global_transform = Transform3D(Basis(), Vector3(20, 4, 48)).looking_at(Vector3(20, 1, 60))
		cam2.make_current()
	if frame == 260:
		var img3: Image = root.get_texture().get_image()
		var img4: Image = root.get_texture().get_image()
		print("STAGE shot2 err=", img4.save_png("art_reviews/library/stage_east.png"))
		print("STAGE DONE")
		quit()
	return false
