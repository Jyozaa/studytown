extends RefCounted

# Quiet forest library rebuild (KayKit assets) around the PRESERVED
# library_bookshelf.glb wall units. Single storey, south glazing +
# central entrance, forest road south, layered exterior forest.
# Conventions mirror cafe_builder.gd: KayKit 1 unit = 1 m, Low Poly
# props at 0.15, city assets at CITY_S, StudyTown -Z forward.

const PACK := "res://assets/source/cafe_packs/"
const SHELF_MODEL := "res://assets/dev_local/blender_generated/runtime/library_bookshelf.glb"
const LAPTOP_SCALE := 0.15
const MUG_SCALE := 0.15
const CITY_S := 5.0

# Interior shell bounds.
const IX := 17.0
const IZ := 12.0
const WALL_H := 6.0
const WALL_T := 0.4
const GLASS_Y0 := 1.0
const GLASS_Y1 := 5.2


static func build(main) -> void:
	_build_materials(main)
	main._add_environment(Color("#14161d"), Color("#b9c8e2"), 0.5)
	main._add_structural_floor(Vector2(44.0, 32.0))
	_build_wood_floor(main)
	_build_shell(main)
	_build_bookshelves(main)
	_build_communal_tables(main)
	_build_window_bar(main)
	_build_lounge(main)
	_build_cozy_west(main)
	_build_nook_east(main)
	_build_reading_nook(main)
	_build_reception(main)
	_build_refreshment(main)
	_build_interior_decor(main)
	_build_forecourt(main)
	_build_road(main)
	_build_near_forest(main)
	_build_elevation(main)
	_build_far_forest(main)
	_build_lighting(main)
	_populate_npcs(main)
	main._add_world_boundaries(Vector2(21.2, 15.2))
	var marker := Node3D.new()
	marker.name = "LibraryRoomMarker"
	marker.set_meta("library_room", true)
	main.world_root.add_child(marker)


static func _name_spot(main, spot, n: int) -> void:
	spot.seat_id = "library-L%02d" % n
	spot.seat_label = "Library seat " + str(n)


static func _place(main, relative_path: String, pos: Vector3, yaw := 0.0, scale_value := Vector3.ONE) -> Node3D:
	var packed: PackedScene = load(PACK + relative_path)
	var node := packed.instantiate() as Node3D
	main.world_root.add_child(node)
	node.position = pos
	node.rotation.y = yaw
	node.scale = scale_value
	return node


static func _place_abs(main, abs_path: String, pos: Vector3, yaw := 0.0, scale_value := Vector3.ONE) -> Node3D:
	var packed: PackedScene = load(abs_path)
	var node := packed.instantiate() as Node3D
	main.world_root.add_child(node)
	node.position = pos
	node.rotation.y = yaw
	node.scale = scale_value
	return node


static func _furniture_yaw_for(direction: Vector3) -> float:
	var seat_yaw := atan2(-direction.x, -direction.z)
	return wrapf(seat_yaw + PI, -PI, PI)


static func _seat(main, pos: Vector3, face_dir: Vector3, study_type: String, seat_height: float, stand_dist: float, seat_type: String):
	var n: int = main.study_spots.size() + 1
	var spot = main._register_furniture_seat(pos, _furniture_yaw_for(face_dir), study_type, seat_height, 0.35, stand_dist, seat_type)
	_name_spot(main, spot, n)
	return spot


static func _prop(main, relative_path: String, pos: Vector3, yaw := 0.0, scale_value := Vector3.ONE) -> Node3D:
	return _place(main, relative_path, pos, yaw, scale_value)


static func _chair(main, model: String, pos: Vector3, face_dir: Vector3, study_type: String, seat_height: float, stand_dist: float, seat_type: String) -> void:
	var yaw := _furniture_yaw_for(face_dir)
	_place(main, model, pos, yaw)
	main._add_blocker(pos + Vector3(0, 0.6, 0), Vector3(0.7, 1.2, 0.7), yaw)
	_seat(main, pos, face_dir, study_type, seat_height, stand_dist, seat_type)


static func _city(main, asset: String, pos: Vector3, yaw := 0.0, s = CITY_S, shadows := true) -> Node3D:
	var sv: Vector3 = s if s is Vector3 else Vector3.ONE * float(s)
	var node := _place(main, "city/" + asset + ".gltf", pos, yaw, sv)
	node.set_meta("xray_exclude", true)
	if not shadows:
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func _block(main, asset: String, pos: Vector3, yaw := 0.0, s := Vector3.ONE, shadows := false) -> Node3D:
	var node := _place(main, "blocks/" + asset + ".gltf", pos, yaw, s)
	node.set_meta("xray_exclude", true)
	if not shadows:
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func _nature(main, asset: String, pos: Vector3, yaw := 0.0, scale_value := 1.0, shadows := true) -> Node3D:
	var node := _place(main, "nature/Assets/gltf/" + asset + ".gltf", pos, yaw, Vector3.ONE * scale_value)
	node.set_meta("xray_exclude", true)
	if not shadows:
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func _warm_pool(main, pos: Vector3, energy: float, light_range: float) -> void:
	var lamp := OmniLight3D.new()
	lamp.position = pos
	lamp.light_color = Color("#ffc27a")
	lamp.light_energy = energy
	lamp.omni_range = light_range
	lamp.shadow_enabled = false
	main.world_root.add_child(lamp)


static func _build_materials(main) -> void:
	var extra := {
		"lib_floor": Color("#7A5238"),
		"lib_wall": Color("#A9947D"),
		"lib_darkwood": Color("#4E3423"),
		"lib_trim": Color("#3E2A1D"),
		"lib_ground": Color("#2E4429"),
		"lib_path": Color("#9C8E7C"),
		"lib_counter": Color("#6E4A2F"),
	}
	for key in extra:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = extra[key]
		mat.roughness = 0.85
		main.mats[key] = mat
	var lamp_glow := StandardMaterial3D.new()
	lamp_glow.albedo_color = Color("#ffd9a0")
	lamp_glow.emission_enabled = true
	lamp_glow.emission = Color("#ffbe6e")
	lamp_glow.emission_energy_multiplier = 2.4
	lamp_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	main.mats["lib_lamp_glow"] = lamp_glow


static func _wall(main, center: Vector3, size: Vector3) -> void:
	main._box(main.world_root, size, center, main.mats.lib_wall)
	main._add_blocker(center, size, 0.0)


static func _trim(main, center: Vector3, size: Vector3) -> void:
	main._box(main.world_root, size, center, main.mats.lib_darkwood)


static func _build_wood_floor(main) -> void:
	main._box(main.world_root, Vector3(IX * 2.0 + 0.8, 0.12, IZ * 2.0 + 0.8), Vector3(0, -0.06, 0), main.mats.lib_floor)
	# Entry mat just inside the door.
	main._box(main.world_root, Vector3(3.0, 0.05, 1.6), Vector3(0, 0.02, 10.6), main.mats.lib_trim)
	# Exterior forest-floor plane (visual only; no gameplay collision).
	var ground := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(210, 1.0, 175)
	ground.mesh = gm
	ground.material_override = main.mats.lib_ground
	main.world_root.add_child(ground)
	ground.position = Vector3(0, -1.02, -6)


static func _glass_pane_ns(main, x: float, z: float) -> void:
	# Glass pane in a north/south wall (faces +/-z). Spans exactly
	# sill-top to header-bottom so framing always connects.
	var mid := (GLASS_Y0 + GLASS_Y1) * 0.5
	var h := GLASS_Y1 - GLASS_Y0
	main._box(main.world_root, Vector3(2.8, h, 0.08), Vector3(x, mid, z), main.mats.glass)
	main._add_blocker(Vector3(x, mid, z), Vector3(2.8, h, 0.5), 0.0)


static func _glass_pane_ew(main, z: float, x: float) -> void:
	# Glass pane in an east/west wall (faces +/-x).
	var mid := (GLASS_Y0 + GLASS_Y1) * 0.5
	var h := GLASS_Y1 - GLASS_Y0
	main._box(main.world_root, Vector3(0.08, h, 2.8), Vector3(x, mid, z), main.mats.glass)
	main._add_blocker(Vector3(x, mid, z), Vector3(0.5, h, 2.8), 0.0)


static func _build_shell(main) -> void:
	var h := WALL_H
	var t := WALL_T
	var mid := (GLASS_Y0 + GLASS_Y1) * 0.5
	var gh := GLASS_Y1 - GLASS_Y0
	# Corner piers (block gameplay, anchor the glass grid visually).
	for cx in [-IX, IX]:
		for cz in [-IZ, IZ]:
			main._box(main.world_root, Vector3(1.0, h, 1.0), Vector3(cx, h * 0.5, cz), main.mats.lib_wall)
			main._add_blocker(Vector3(cx, h * 0.5, cz), Vector3(1.0, h, 1.0), 0.0)
	# NORTH wall: sill + posts + full glazing + header.
	_wall(main, Vector3(0, 0.5, -IZ), Vector3(IX * 2.0, 1.0, t))
	for i in 11:
		var x := -15.5 + float(i) * 3.1
		_wall(main, Vector3(x, mid, -IZ), Vector3(0.3, gh, t))
	for i in 10:
		_glass_pane_ns(main, -13.95 + float(i) * 3.1, -IZ)
	_trim(main, Vector3(0, 5.6, -IZ), Vector3(IX * 2.0, 0.8, t + 0.2))
	# WEST / EAST walls: sill + posts + full glazing + header.
	for sx in [-1.0, 1.0]:
		var x: float = sx * IX
		_wall(main, Vector3(x, 0.5, 0), Vector3(t, 1.0, IZ * 2.0))
		for i in 8:
			var z := -10.85 + float(i) * 3.1
			_wall(main, Vector3(x, mid, z), Vector3(t, gh, 0.3))
		for i in 7:
			_glass_pane_ew(main, -9.3 + float(i) * 3.1, x)
		_trim(main, Vector3(x, 5.6, 0), Vector3(t + 0.2, 0.8, IZ * 2.0))
	# SOUTH facade: same glass module as north, minus the entrance bay.
	_wall(main, Vector3(-9.4, 0.5, IZ), Vector3(15.2, 1.0, t))
	_wall(main, Vector3(9.4, 0.5, IZ), Vector3(15.2, 1.0, t))
	for i in 11:
		var x := -15.5 + float(i) * 3.1
		if absf(x) < 1.0:
			continue
		_wall(main, Vector3(x, mid, IZ), Vector3(0.3, gh, t))
	for i in 10:
		var x := -13.95 + float(i) * 3.1
		if absf(x) < 3.0:
			continue
		_glass_pane_ns(main, x, IZ)
	# Door frame, transom glass, header beam.
	_trim(main, Vector3(-1.55, 1.7, IZ), Vector3(0.3, 3.4, 0.5))
	_trim(main, Vector3(1.55, 1.7, IZ), Vector3(0.3, 3.4, 0.5))
	_trim(main, Vector3(0, 3.5, IZ), Vector3(3.4, 0.3, 0.5))
	main._box(main.world_root, Vector3(2.8, 1.7, 0.08), Vector3(0, 4.35, IZ), main.mats.glass)
	_trim(main, Vector3(0, 5.6, IZ), Vector3(IX * 2.0, 0.8, t + 0.2))
	# Top cap line around the whole building (unified height).
	_trim(main, Vector3(0, h + 0.09, -IZ), Vector3(IX * 2.0 + t * 2.0, 0.18, 0.8))
	_trim(main, Vector3(0, h + 0.09, IZ), Vector3(IX * 2.0 + t * 2.0, 0.18, 0.8))
	_trim(main, Vector3(-IX, h + 0.09, 0), Vector3(0.8, 0.18, IZ * 2.0))
	_trim(main, Vector3(IX, h + 0.09, 0), Vector3(0.8, 0.18, IZ * 2.0))
	# Exterior mid band breaks up the tall outer faces.
	_trim(main, Vector3(0, 2.3, -IZ - 0.21), Vector3(IX * 2.0 + 0.1, 0.22, 0.06))
	_trim(main, Vector3(-IX - 0.21, 2.3, 0), Vector3(0.06, 0.22, IZ * 2.0 + 0.1))
	_trim(main, Vector3(IX + 0.21, 2.3, 0), Vector3(0.06, 0.22, IZ * 2.0 + 0.1))
	# Invisible doorway blocker: players admire the entrance, never exit.
	main._add_blocker(Vector3(0, 1.6, IZ), Vector3(2.4, 3.2, 0.4), 0.0)
	# Doorway stays OPEN visually (no wall across the entrance).


# Preserved bookshelf wall unit (library_bookshelf.glb, same model/materials
# as the existing Library). One unit ≈ 3.5 m wide x 4.2 m tall x 0.9 m deep
# at scale 1; rows place units side by side with a small gap.
static func _shelf_row(main, start: Vector3, dir: Vector3, count: int, yaw: float, unit_scale := 1.0) -> void:
	var step := 3.62 * unit_scale
	for i in count:
		var pos := start + dir * (step * float(i))
		_place_abs(main, SHELF_MODEL, pos, yaw, Vector3.ONE * unit_scale)
		# Tight footprint blocker per unit (aisles stay open).
		var depth := Vector3(3.5 * unit_scale, 4.2, 1.0 * unit_scale)
		if absf(dir.x) > 0.5:
			main._add_blocker(pos + Vector3(0, 2.1, 0), depth, 0.0)
		else:
			main._add_blocker(pos + Vector3(0, 2.1, 0), Vector3(1.0 * unit_scale, 4.2, 3.5 * unit_scale), 0.0)


static func _build_bookshelves(main) -> void:
	# North wall run (faces south into the room), standing just off the glass.
	_shelf_row(main, Vector3(-12.4, 0, -10.6), Vector3(1, 0, 0), 5, 0.0)
	# West wall run (faces east).
	_shelf_row(main, Vector3(-15.6, 0, -8.0), Vector3(0, 0, 1), 4, PI * 0.5)
	# Mid-west aisle run: BACK-TO-BACK pair. A faces west (books to the
	# west aisle), B faces east (books to the central aisle); backs meet.
	_shelf_row(main, Vector3(-7.0, 0, -9.0), Vector3(0, 0, 1), 2, -PI * 0.5, 0.9)
	_shelf_row(main, Vector3(-6.05, 0, -9.0), Vector3(0, 0, 1), 2, PI * 0.5, 0.9)
	# Mid-east aisle run: mirrored back-to-back pair.
	_shelf_row(main, Vector3(7.0, 0, -9.0), Vector3(0, 0, 1), 2, PI * 0.5, 0.9)
	_shelf_row(main, Vector3(6.05, 0, -9.0), Vector3(0, 0, 1), 2, -PI * 0.5, 0.9)
	# East wall run (faces west).
	_shelf_row(main, Vector3(15.6, 0, -8.0), Vector3(0, 0, 1), 4, -PI * 0.5)


static func _communal_table(main, center: Vector3) -> void:
	# table_medium_long top y=1.0; 6 wood chairs, 3 per long side.
	_place(main, "furniture_bits/Assets/gltf/table_medium_long.gltf", center, 0.0)
	main._add_blocker(center + Vector3(0, 0.5, 0), Vector3(3.0, 1.0, 2.0), 0.0)
	for i in 3:
		var x := center.x - 1.1 + float(i) * 1.1
		_chair(main, "furniture_bits/Assets/gltf/chair_A_wood.gltf", Vector3(x, 0, center.z - 1.55), Vector3(0, 0, 1), "Book", 0.3, 1.25, "desk_chair")
		_chair(main, "furniture_bits/Assets/gltf/chair_B_wood.gltf", Vector3(x, 0, center.z + 1.55), Vector3(0, 0, -1), "Laptop" if i == 1 else "Book", 0.3, 1.25, "desk_chair")
	# Restrained dressing: lamp, books, laptop, mug (tops y=1.0).
	_prop(main, "furniture_bits/Assets/gltf/lamp_table.gltf", center + Vector3(-0.9, 1.0, -0.3), 0.3)
	_prop(main, "furniture_bits/Assets/gltf/book_set.gltf", center + Vector3(0.6, 1.0, 0.2), -0.4)
	_prop(main, "furniture_bits/Assets/gltf/book_single.gltf", center + Vector3(1.0, 1.0, -0.3), 0.9)
	_prop(main, "Low Poly Furniture/Electronics/Laptop.fbx", center + Vector3(-0.1, 1.07, 0.3), 0.2, Vector3.ONE * LAPTOP_SCALE)
	_prop(main, "Low Poly Furniture/Miscellaneous/Mug.fbx", center + Vector3(0.2, 1.04, -0.4), 0.0, Vector3.ONE * MUG_SCALE)


static func _build_communal_tables(main) -> void:
	_communal_table(main, Vector3(-3.2, 0, 2.0))
	_communal_table(main, Vector3(3.2, 0, 2.0))
	# Real rug meshes under each cluster (replace flat trim boxes).
	_prop(main, "furniture_bits/Assets/gltf/rug_rectangle_A.gltf", Vector3(-3.2, 0.01, 2.0), 0.0)
	_prop(main, "furniture_bits/Assets/gltf/rug_rectangle_A.gltf", Vector3(3.2, 0.01, 2.0), 0.0)


static func _build_window_bar(main) -> void:
	# Bars hug the south windows; stools sit NORTH of the bars and face
	# SOUTH toward the glass/road (spec: stools face the windows). Stand
	# anchors land on open floor north of each stool.
	for cx in [-6.0, 6.0]:
		_place(main, "furniture_bits/Assets/gltf/table_medium_long.gltf", Vector3(cx, 0, 10.7), 0.0)
		main._add_blocker(Vector3(cx, 0.5, 10.7), Vector3(3.0, 1.0, 2.0), 0.0)
	for i in 3:
		_chair(main, "furniture_bits/Assets/gltf/chair_stool_wood.gltf", Vector3(-7.1 + float(i) * 1.1, 0, 9.0), Vector3(0, 0, 1), "Laptop" if i == 1 else "Book", 0.35, 1.25, "desk_chair")
	for i in 3:
		_chair(main, "furniture_bits/Assets/gltf/chair_stool_wood.gltf", Vector3(4.9 + float(i) * 1.1, 0, 9.0), Vector3(0, 0, 1), "Book" if i == 1 else "Laptop", 0.35, 1.25, "desk_chair")
	# Bar props with clear desk space between stations (bar top y=1.0).
	_prop(main, "Low Poly Furniture/Electronics/Laptop.fbx", Vector3(-6.0, 1.07, 10.7), 0.0, Vector3.ONE * LAPTOP_SCALE)
	_prop(main, "Low Poly Furniture/Miscellaneous/Mug.fbx", Vector3(-5.2, 1.04, 10.9), 0.0, Vector3.ONE * MUG_SCALE)
	_prop(main, "furniture_bits/Assets/gltf/book_single.gltf", Vector3(6.3, 1.0, 10.6), 0.5)
	_prop(main, "Low Poly Furniture/Miscellaneous/Mug.fbx", Vector3(5.5, 1.04, 10.8), 0.0, Vector3.ONE * MUG_SCALE)
	# Table lamps at the outer bar ends (warm evening accents).
	_prop(main, "furniture_bits/Assets/gltf/lamp_table.gltf", Vector3(-7.3, 1.0, 10.7), 0.0)
	_prop(main, "furniture_bits/Assets/gltf/lamp_table.gltf", Vector3(7.3, 1.0, 10.7), 0.0)


static func _build_lounge(main) -> void:
	# North-west lounge: couch faces east into the room, armchairs angle
	# toward the low table, lamp behind the couch.
	var c := Vector3(-12.0, 0, -6.5)
	_prop(main, "furniture_bits/Assets/gltf/rug_oval_A.gltf", Vector3(-11.0, 0.02, -6.5), PI * 0.5)
	_place(main, "furniture_bits/Assets/gltf/table_low.gltf", Vector3(-10.8, 0, -6.5), PI * 0.5)
	main._add_blocker(Vector3(-10.8, 0.25, -6.5), Vector3(1.5, 0.5, 2.4), 0.0)
	_place(main, "furniture_bits/Assets/gltf/couch_pillows.gltf", c, _furniture_yaw_for(Vector3(1, 0, 0)))
	main._add_blocker(c + Vector3(0, 0.55, 0), Vector3(1.6, 1.1, 3.0), 0.0)
	for i in 3:
		_seat(main, c + Vector3(0, 0, -1.0 + float(i) * 1.0), Vector3(1, 0, 0), "Book", 0.1, 1.4, "armchair")
	_place(main, "furniture_bits/Assets/gltf/armchair_pillows.gltf", Vector3(-10.0, 0, -8.6), _furniture_yaw_for(Vector3(-0.5, 0, 0.87)))
	main._add_blocker(Vector3(-10.0, 0.7, -8.6), Vector3(1.3, 1.4, 1.3), 0.0)
	_seat(main, Vector3(-10.0, 0, -8.6), Vector3(-0.5, 0, 0.87), "Laptop", 0.1, 1.25, "armchair")
	_place(main, "furniture_bits/Assets/gltf/armchair_pillows.gltf", Vector3(-10.0, 0, -4.4), _furniture_yaw_for(Vector3(-0.5, 0, -0.87)))
	main._add_blocker(Vector3(-10.0, 0.7, -4.4), Vector3(1.3, 1.4, 1.3), 0.0)
	_seat(main, Vector3(-10.0, 0, -4.4), Vector3(-0.5, 0, -0.87), "Book", 0.1, 1.25, "armchair")
	_place(main, "furniture_bits/Assets/gltf/lamp_standing.gltf", Vector3(-14.2, 0, -8.8), 0.0)
	main._add_blocker(Vector3(-14.2, 0.75, -8.8), Vector3(0.6, 1.5, 0.6), 0.0)
	_place(main, "furniture_bits/Assets/gltf/cabinet_small_decorated.gltf", Vector3(-13.8, 0, -3.6), PI * 0.5)
	main._add_blocker(Vector3(-13.8, 0.9, -3.6), Vector3(1.0, 1.8, 2.0), 0.0)
	_place(main, "furniture_bits/Assets/gltf/cactus_small_A.gltf", Vector3(-13.8, 0, -9.2), 0.0)
	# Coffee-table dressing (top y=0.5).
	_prop(main, "furniture_bits/Assets/gltf/book_set.gltf", Vector3(-10.8, 0.5, -6.9), 0.4)
	_prop(main, "Low Poly Furniture/Miscellaneous/Mug.fbx", Vector3(-10.7, 0.54, -6.1), 0.0, Vector3.ONE * MUG_SCALE)


static func _build_cozy_west(main) -> void:
	# South-west cozy corner: second couch cluster, distinct from the NW lounge.
	var c := Vector3(-12.5, 0, 7.5)
	_prop(main, "furniture_bits/Assets/gltf/rug_oval_A.gltf", Vector3(-11.5, 0.02, 7.8), 0.0)
	_place(main, "furniture_bits/Assets/gltf/table_low.gltf", Vector3(-11.3, 0, 7.5), 0.0)
	main._add_blocker(Vector3(-11.3, 0.25, 7.5), Vector3(2.4, 0.5, 1.5), 0.0)
	_place(main, "furniture_bits/Assets/gltf/couch_pillows.gltf", c, _furniture_yaw_for(Vector3(1, 0, 0)))
	main._add_blocker(c + Vector3(0, 0.55, 0), Vector3(1.6, 1.1, 3.0), 0.0)
	for i in 3:
		_seat(main, c + Vector3(0, 0, -1.0 + float(i) * 1.0), Vector3(1, 0, 0), "Book", 0.1, 1.4, "armchair")
	_place(main, "furniture_bits/Assets/gltf/armchair_pillows.gltf", Vector3(-10.3, 0, 9.5), _furniture_yaw_for(Vector3(-0.6, 0, -0.75)))
	main._add_blocker(Vector3(-10.3, 0.7, 9.5), Vector3(1.3, 1.4, 1.3), 0.0)
	_seat(main, Vector3(-10.3, 0, 9.5), Vector3(-0.6, 0, -0.75), "Laptop", 0.1, 1.6, "armchair")
	_place(main, "furniture_bits/Assets/gltf/lamp_standing.gltf", Vector3(-14.3, 0, 9.5), 0.0)
	main._add_blocker(Vector3(-14.3, 0.75, 9.5), Vector3(0.6, 1.5, 0.6), 0.0)
	_place(main, "furniture_bits/Assets/gltf/cactus_medium_B.gltf", Vector3(-14.5, 0, 5.8), 0.0)
	main._add_blocker(Vector3(-14.5, 0.4, 5.8), Vector3(0.5, 0.8, 0.5), 0.0)
	_prop(main, "furniture_bits/Assets/gltf/book_set.gltf", Vector3(-11.3, 0.5, 7.2), -0.3)
	_prop(main, "Low Poly Furniture/Miscellaneous/Mug.fbx", Vector3(-11.1, 0.54, 7.9), 0.0, Vector3.ONE * MUG_SCALE)
	_prop(main, "furniture_bits/Assets/gltf/pictureframe_small_C.gltf", Vector3(-16.7, 2.1, 7.5), PI * 0.5)


static func _build_nook_east(main) -> void:
	# East reading nook near the glass: armchair + side table + rug + lamp.
	var c := Vector3(12.5, 0, 5.5)
	_prop(main, "furniture_bits/Assets/gltf/rug_oval_A.gltf", Vector3(12.3, 0.02, 5.0), PI * 0.5)
	_place(main, "furniture_bits/Assets/gltf/table_small.gltf", Vector3(12.5, 0, 4.2), 0.0)
	main._add_blocker(Vector3(12.5, 0.5, 4.2), Vector3(1.0, 1.0, 1.0), 0.0)
	_place(main, "furniture_bits/Assets/gltf/armchair_pillows.gltf", c, _furniture_yaw_for(Vector3(-1, 0, 0.2)))
	main._add_blocker(c + Vector3(0, 0.7, 0), Vector3(1.3, 1.4, 1.3), 0.0)
	_seat(main, c, Vector3(-1, 0, 0.2), "Book", 0.1, 1.25, "armchair")
	_place(main, "furniture_bits/Assets/gltf/lamp_standing.gltf", Vector3(13.8, 0, 6.8), 0.0)
	main._add_blocker(Vector3(13.8, 0.75, 6.8), Vector3(0.6, 1.5, 0.6), 0.0)
	_place(main, "furniture_bits/Assets/gltf/cactus_small_B.gltf", Vector3(11.4, 0, 6.9), 0.0)
	_prop(main, "furniture_bits/Assets/gltf/book_single.gltf", Vector3(12.5, 1.0, 4.2), 0.4)
	_prop(main, "Low Poly Furniture/Miscellaneous/Mug.fbx", Vector3(12.3, 1.04, 4.0), 0.0, Vector3.ONE * MUG_SCALE)


static func _build_reading_nook(main) -> void:
	# Quiet west-wall nook south of the lounge.
	var c := Vector3(-14.6, 0, 2.5)
	_prop(main, "furniture_bits/Assets/gltf/rug_oval_A.gltf", Vector3(-13.6, 0.02, 2.5), PI * 0.5)
	_place(main, "furniture_bits/Assets/gltf/table_small.gltf", Vector3(-13.4, 0, 2.5), 0.0)
	main._add_blocker(Vector3(-13.4, 0.5, 2.5), Vector3(1.0, 1.0, 1.0), 0.0)
	_place(main, "furniture_bits/Assets/gltf/armchair_pillows.gltf", c, _furniture_yaw_for(Vector3(1, 0, 0.25)))
	main._add_blocker(c + Vector3(0, 0.7, 0), Vector3(1.3, 1.4, 1.3), 0.0)
	_seat(main, c, Vector3(1, 0, 0.25), "Book", 0.1, 1.25, "armchair")
	_place(main, "furniture_bits/Assets/gltf/armchair_pillows.gltf", Vector3(-14.6, 0, 4.6), _furniture_yaw_for(Vector3(0.9, 0, -0.45)))
	main._add_blocker(Vector3(-14.6, 0.7, 4.6), Vector3(1.3, 1.4, 1.3), 0.0)
	_seat(main, Vector3(-14.6, 0, 4.6), Vector3(0.9, 0, -0.45), "Laptop", 0.1, 1.25, "armchair")
	_place(main, "furniture_bits/Assets/gltf/lamp_standing.gltf", Vector3(-15.2, 0, 0.6), 0.0)
	main._add_blocker(Vector3(-15.2, 0.75, 0.6), Vector3(0.6, 1.5, 0.6), 0.0)
	_prop(main, "furniture_bits/Assets/gltf/book_single.gltf", Vector3(-13.4, 1.0, 2.5), 0.7)
	_prop(main, "Low Poly Furniture/Miscellaneous/Mug.fbx", Vector3(-13.2, 1.04, 2.3), 0.0, Vector3.ONE * MUG_SCALE)
	_place(main, "furniture_bits/Assets/gltf/cactus_small_B.gltf", Vector3(-15.5, 0, 6.2), 0.0)


static func _build_reception(main) -> void:
	# Compact desk south-east of the entrance (clear of the east window
	# bar); chair faces west into the room.
	var c := Vector3(10.0, 0, 9.5)
	_place(main, "furniture_bits/Assets/gltf/table_medium.gltf", c, 0.0)
	main._add_blocker(c + Vector3(0, 0.5, 0), Vector3(2.0, 1.0, 2.0), 0.0)
	_chair(main, "furniture_bits/Assets/gltf/chair_B_wood.gltf", Vector3(11.5, 0, 9.5), Vector3(-1, 0, 0), "Laptop", 0.3, 1.25, "desk_chair")
	_prop(main, "Low Poly Furniture/Electronics/Laptop.fbx", Vector3(10.0, 1.07, 9.5), -PI * 0.5, Vector3.ONE * LAPTOP_SCALE)
	_prop(main, "furniture_bits/Assets/gltf/lamp_table.gltf", Vector3(9.5, 1.0, 10.0), 0.0)
	_prop(main, "furniture_bits/Assets/gltf/book_single.gltf", Vector3(10.5, 1.0, 9.1), 0.3)
	_place(main, "furniture_bits/Assets/gltf/cactus_small_A.gltf", Vector3(8.6, 0, 10.8), 0.0)


static func _build_refreshment(main) -> void:
	# North-east tea/snack nook: two counters + fridge against the north
	# wall, stools facing the counter, menu board on the wall.
	for cx in [10.5, 12.5]:
		_place(main, "restaurant_bits/Assets/gltf/kitchencounter_straight_A_decorated.gltf", Vector3(cx, 0, -10.6), 0.0)
		main._add_blocker(Vector3(cx, 1.0, -10.6), Vector3(2.0, 2.0, 1.6), 0.0)
	_place(main, "restaurant_bits/Assets/gltf/fridge_A_decorated.gltf", Vector3(14.6, 0, -10.6), -PI * 0.5)
	main._add_blocker(Vector3(14.6, 1.2, -10.6), Vector3(2.0, 2.4, 1.6), 0.0)
	_prop(main, "restaurant_bits/Assets/gltf/menu.gltf", Vector3(11.5, 1.9, -11.6), 0.0)
	_prop(main, "restaurant_bits/Assets/gltf/jar_A_small.gltf", Vector3(10.2, 1.02, -10.0), 0.0)
	_prop(main, "Low Poly Furniture/Miscellaneous/Mug.fbx", Vector3(12.9, 1.04, -10.0), 0.0, Vector3.ONE * MUG_SCALE)
	_prop(main, "furniture_bits/Assets/gltf/lamp_table.gltf", Vector3(13.3, 1.02, -10.0), 0.0)
	for cx in [10.5, 12.5]:
		_chair(main, "furniture_bits/Assets/gltf/chair_stool_wood.gltf", Vector3(cx, 0, -9.0), Vector3(0, 0, -1), "Book", 0.35, 1.1, "cafe_chair")


static func _build_interior_decor(main) -> void:
	# Wall art groups (lounge, reception, reading nook).
	_prop(main, "furniture_bits/Assets/gltf/pictureframe_large_A.gltf", Vector3(-16.7, 2.2, -6.5), PI * 0.5)
	_prop(main, "furniture_bits/Assets/gltf/pictureframe_medium.gltf", Vector3(-16.7, 2.0, -4.9), PI * 0.5)
	_prop(main, "furniture_bits/Assets/gltf/pictureframe_small_A.gltf", Vector3(8.0, 2.2, -11.7), 0.0)
	_prop(main, "furniture_bits/Assets/gltf/pictureframe_small_B.gltf", Vector3(8.8, 2.1, -11.7), 0.0)
	_prop(main, "furniture_bits/Assets/gltf/pictureframe_large_B.gltf", Vector3(-14.0, 2.2, 11.7), PI)
	# Corner plants (clear of routes).
	for spec in [
		["furniture_bits/Assets/gltf/cactus_medium_A.gltf", Vector3(-15.8, 0, -11.0)],
		["furniture_bits/Assets/gltf/cactus_medium_B.gltf", Vector3(15.8, 0, -11.0)],
		["furniture_bits/Assets/gltf/cactus_medium_A.gltf", Vector3(-15.8, 0, 10.8)],
		["furniture_bits/Assets/gltf/cactus_small_A.gltf", Vector3(15.8, 0, 10.8)],
		["furniture_bits/Assets/gltf/cactus_medium_B.gltf", Vector3(-3.0, 0, -11.0)],
		["furniture_bits/Assets/gltf/cactus_small_B.gltf", Vector3(3.0, 0, 10.8)],
	]:
		_place(main, spec[0], spec[1], 0.0)
		main._add_blocker((spec[1] as Vector3) + Vector3(0, 0.4, 0), Vector3(0.5, 0.8, 0.5), 0.0)
	# Standing lamps flanking the central shelf aisles (warm beacons).
	for lx in [-5.0, 5.0]:
		_place(main, "furniture_bits/Assets/gltf/lamp_standing.gltf", Vector3(lx, 0, -3.2), 0.0)
		main._add_blocker(Vector3(lx, 0.75, -3.2), Vector3(0.6, 1.5, 0.6), 0.0)
	# Decor cabinets in transitions (never in aisles).
	_place(main, "furniture_bits/Assets/gltf/cabinet_medium_decorated.gltf", Vector3(-16.2, 0, 8.0), PI * 0.5)
	main._add_blocker(Vector3(-16.2, 0.9, 8.0), Vector3(1.0, 1.8, 2.0), 0.0)
	_place(main, "furniture_bits/Assets/gltf/cabinet_small_decorated.gltf", Vector3(16.2, 0, 8.0), -PI * 0.5)
	main._add_blocker(Vector3(16.2, 0.9, 8.0), Vector3(1.0, 1.8, 1.0), 0.0)


static func _build_forecourt(main) -> void:
	# Paved footpath from the entrance south to the road verge.
	main._box(main.world_root, Vector3(4.0, 0.1, 8.0), Vector3(0, -0.02, 16.0), main.mats.lib_path)
	# Planting zones flanking the path.
	for spec in [
		["nature/Assets/gltf/Bush_2_A_Color1.gltf", Vector3(-3.4, 0, 14.5)],
		["nature/Assets/gltf/Bush_2_B_Color1.gltf", Vector3(3.4, 0, 14.5)],
		["nature/Assets/gltf/Grass_1_C_Singlesided_Color1.gltf", Vector3(-3.2, 0, 17.0)],
		["nature/Assets/gltf/Grass_1_C_Singlesided_Color1.gltf", Vector3(3.2, 0, 17.0)],
		["nature/Assets/gltf/Rock_2_B_Color1.gltf", Vector3(-4.4, 0, 16.5)],
		["nature/Assets/gltf/Rock_2_B_Color1.gltf", Vector3(4.4, 0, 16.5)],
	]:
		_nature(main, spec[0].trim_prefix("nature/Assets/gltf/").trim_suffix(".gltf"), spec[1], randf() * TAU, 1.0, false)
	# West bench (clear of the path) + balanced east bench.
	_city(main, "bench", Vector3(-6.5, 0, 16.0), PI * 0.5)
	main._add_blocker(Vector3(-6.5, 0.5, 16.0), Vector3(2.0, 1.0, 0.8), 0.0)
	_city(main, "bench", Vector3(9.5, 0, 16.5), -PI * 0.5)
	main._add_blocker(Vector3(9.5, 0.5, 16.5), Vector3(2.0, 1.0, 0.8), 0.0)
	# LIBRARY sign east of the path (primitive geometry + TextMesh).
	_trim(main, Vector3(5.2, 1.0, 15.0), Vector3(0.18, 2.0, 0.18))
	_trim(main, Vector3(5.2, 1.0, 16.4), Vector3(0.18, 2.0, 0.18))
	main._box(main.world_root, Vector3(2.6, 0.7, 0.12), Vector3(5.2, 2.1, 15.7), main.mats.lib_darkwood)
	var sign := Label3D.new()
	sign.text = "LIBRARY"
	sign.font_size = 64
	sign.modulate = Color("#f3e6c8")
	sign.outline_size = 8
	sign.position = Vector3(5.2, 2.1, 15.78)
	sign.rotation.y = 0.0
	main.world_root.add_child(sign)
	main._add_blocker(Vector3(5.2, 1.0, 15.7), Vector3(2.6, 2.0, 0.6), 0.0)
	# Potted plants flanking the entrance (outside).
	_place(main, "furniture_bits/Assets/gltf/cactus_medium_A.gltf", Vector3(-2.6, 0, 13.0), 0.0)
	_place(main, "furniture_bits/Assets/gltf/cactus_medium_B.gltf", Vector3(2.6, 0, 13.0), 0.0)
	main._add_blocker(Vector3(-2.6, 0.4, 13.0), Vector3(0.5, 0.8, 0.5), 0.0)
	main._add_blocker(Vector3(2.6, 0.4, 13.0), Vector3(0.5, 0.8, 0.5), 0.0)


static func _streetlight(main, pos: Vector3, yaw: float) -> void:
	_city(main, "streetlight", pos, yaw)
	if not main.mats.has("city_lamp_glow"):
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color("#ffd9a0")
		glow.emission_enabled = true
		glow.emission = Color("#ffbe6e")
		glow.emission_energy_multiplier = 3.0
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		main.mats["city_lamp_glow"] = glow
	var offset := Basis(Vector3.UP, yaw) * Vector3(-0.22, 0.93, 0.0) * CITY_S
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	bulb.mesh = sphere
	bulb.material_override = main.mats["city_lamp_glow"]
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.world_root.add_child(bulb)
	bulb.position = pos + offset
	main._add_blocker(pos + Vector3(0, 2.0, 0), Vector3(0.6, 4.0, 0.6), 0.0)


static func _build_road(main) -> void:
	# Quiet two-lane east-west road south of the forecourt (tiles 10 m at CITY_S).
	var z := 24.0
	for xi in [-25.0, -15.0, -5.0, 5.0, 15.0, 25.0]:
		_city(main, "road_straight", Vector3(xi, -0.45, z), PI * 0.5, CITY_S, false)
	_city(main, "road_straight_crossing", Vector3(0, -0.44, z), PI * 0.5, CITY_S, false)
	# Sidewalk/verge strip between forecourt and road.
	main._box(main.world_root, Vector3(70, 0.08, 3.0), Vector3(0, -0.04, 19.0), main.mats.lib_path)
	# Sparse streetlights along the road + entrance path + west terrace.
	_streetlight(main, Vector3(-8, 0, 20.5), 0.0)
	_streetlight(main, Vector3(8, 0, 20.5), PI)
	_streetlight(main, Vector3(-20, 0, 27.5), PI)
	_streetlight(main, Vector3(20, 0, 27.5), 0.0)
	_streetlight(main, Vector3(-3.5, 0, 18.5), PI * 0.5)
	_streetlight(main, Vector3(3.5, 0, 18.5), -PI * 0.5)
	_streetlight(main, Vector3(-21, 0, 5), PI * 0.5)
	# Two parked cars (quiet road, no continuous traffic).
	_city(main, "car_sedan", Vector3(-14, 0.1, 23.0), PI * 0.5)
	_city(main, "car_hatchback", Vector3(17, 0.1, 25.5), -PI * 0.5)
	# Roadside props: hydrant, trash, crates.
	_city(main, "firehydrant", Vector3(-11, 0, 20.8), 0.3)
	_city(main, "trash_B", Vector3(11.5, 0, 20.8), -0.4)
	_city(main, "box_A", Vector3(12.3, 0, 20.8), 0.2)


static func _tree_cluster(main, pos: Vector3, tree: String, scale_value: float, with_rock := true) -> void:
	_nature(main, tree, pos, randf() * TAU, scale_value, true)
	_nature(main, "Bush_2_A_Color1", pos + Vector3(1.8, 0, 0.8), randf() * TAU, 1.4, false)
	_nature(main, "Bush_3_B_Color1", pos + Vector3(-1.6, 0, 1.2), randf() * TAU, 1.2, false)
	if with_rock:
		_nature(main, "Rock_2_C_Color1", pos + Vector3(0.6, 0, -1.8), randf() * TAU, 1.0, false)
	_nature(main, "Grass_1_B_Singlesided_Color1", pos + Vector3(-0.8, 0, -0.6), 0.0, 1.5, false)
	_nature(main, "Grass_2_A_Singlesided_Color1", pos + Vector3(1.2, 0, 1.4), 0.0, 1.5, false)


static func _build_near_forest(main) -> void:
	# ~30 important nearby trees; never blocking entrance, road or path.
	var spots := [
		[Vector3(-24, 0, 8), "Tree_1_A_Color1", 1.1],
		[Vector3(-27, 0, -4), "Tree_2_B_Color1", 1.0],
		[Vector3(-22, 0, -14), "Tree_3_A_Color1", 1.2],
		[Vector3(-12, 0, -19), "Tree_4_A_Color1", 1.0],
		[Vector3(0, 0, -21), "Tree_1_B_Color1", 1.15],
		[Vector3(12, 0, -19), "Tree_2_A_Color1", 1.0],
		[Vector3(22, 0, -14), "Tree_3_C_Color1", 1.1],
		[Vector3(27, 0, -4), "Tree_4_B_Color1", 0.95],
		[Vector3(24, 0, 8), "Tree_1_C_Color1", 1.05],
		[Vector3(-30, 0, 16), "Tree_2_C_Color1", 1.2],
		[Vector3(30, 0, 16), "Tree_3_B_Color1", 1.1],
		[Vector3(-14, 0, 30), "Tree_4_C_Color1", 1.0],
		[Vector3(14, 0, 30), "Tree_1_A_Color1", 1.05],
		[Vector3(-33, 0, -10), "Tree_2_A_Color1", 1.25],
		[Vector3(33, 0, -10), "Tree_3_A_Color1", 1.2],
		[Vector3(-8, 0, -26), "Tree_1_C_Color1", 1.1],
		[Vector3(8, 0, -26), "Tree_4_A_Color1", 1.05],
		[Vector3(-26, 0, 28), "Tree_2_B_Color1", 1.0],
		[Vector3(26, 0, 28), "Tree_3_C_Color1", 1.0],
		[Vector3(-12, 0, 17), "Tree_3_B_Color1", 1.0],
		[Vector3(12, 0, 17), "Tree_4_B_Color1", 1.05],
		[Vector3(-21, 0, 13), "Tree_1_B_Color1", 0.95],
		[Vector3(21, 0, 13), "Tree_2_C_Color1", 1.0],
		[Vector3(-37, 0, 4), "Tree_3_A_Color1", 1.2],
		[Vector3(37, 0, 4), "Tree_1_C_Color1", 1.15],
		[Vector3(-35, 0, -18), "Tree_4_C_Color1", 1.1],
		[Vector3(35, 0, -18), "Tree_2_A_Color1", 1.2],
		[Vector3(-17, 0, -17), "Tree_1_A_Color1", 1.0],
		[Vector3(17, 0, -17), "Tree_3_C_Color1", 1.05],
		[Vector3(-8, 0, 33), "Tree_2_B_Color1", 1.0],
	]
	for s in spots:
		_tree_cluster(main, s[0], s[1], s[2])
	# Near-bank collision: keep the player out of planting (a few blockers).
	for bx in [-24.0, -12.0, 12.0, 24.0]:
		main._add_blocker(Vector3(bx, 1.0, -19.0), Vector3(4.0, 2.0, 4.0), 0.0)


static func _bank(main, x: float, z: float, levels: int, top_asset := "grass") -> void:
	# Grounded BlockBits terrace column: stone base, dirt middle, grass top.
	# Each unit is 2 m; level i spans y (2i-0.5)..(2i+1.5), top at 2*levels-0.5.
	for i in levels:
		var asset := "stone_dark" if i == 0 else ("dirt_with_grass" if i < levels - 1 else top_asset)
		_block(main, asset, Vector3(x, 0.5 + 2.0 * float(i), z), 0.0)


static func _build_elevation(main) -> void:
	# (Older validated banks kept as-is.) New terraces use grounded _bank
	# columns: west +3.5 / +5.5, east +3.5 / +5.5, north +2 / +3.5 / +7.5,
	# south-across-road +1.5 / +3.5 / +5.5.
	for spec in [
		["dirt_with_grass", Vector3(-30, 1.0, -6), 0.0],
		["dirt_with_grass", Vector3(-34, 1.0, -6), 0.0],
		["grass", Vector3(-32, 3.0, -12), 0.0],
		["dirt_with_grass", Vector3(30, 0.6, -6), 0.0],
		["grass", Vector3(33, 2.2, -12), 0.0],
		["dirt_with_grass", Vector3(-14, 1.6, -26), 0.0],
		["grass", Vector3(-10, 3.4, -30), 0.0],
		["dirt_with_grass", Vector3(14, 1.6, -26), 0.0],
		["grass", Vector3(10, 3.4, -30), 0.0],
		["stone_dark", Vector3(0, 4.6, -34), 0.0],
		["grass", Vector3(-6, 6.2, -38), 0.0],
		["grass", Vector3(6, 6.2, -38), 0.0],
		["dirt_with_grass", Vector3(-40, 0.6, 10), 0.0],
		["dirt_with_grass", Vector3(40, 0.6, 10), 0.0],
		["gravel_with_grass", Vector3(-26, -0.4, 30), 0.0],
		["gravel_with_grass", Vector3(26, -0.4, 30), 0.0],
		["dirt_with_grass", Vector3(-30, 1.0, 2), 0.0],
	]:
		_block(main, spec[0], spec[1], spec[2])
	_bank(main, -38, -8, 2)
	_bank(main, -38, 0, 2)
	_bank(main, -38, 8, 2)
	_bank(main, -46, -10, 3)
	_bank(main, -46, 0, 3)
	_bank(main, -46, 10, 3)
	_bank(main, 37, -6, 2)
	_bank(main, 37, 4, 2)
	_bank(main, 45, -8, 3)
	_bank(main, 45, 2, 3)
	_bank(main, 45, 10, 3)
	_bank(main, -24, -24, 1)
	_bank(main, 24, -24, 1)
	_bank(main, -20, -32, 2)
	_bank(main, 20, -32, 2)
	_bank(main, 0, -32, 2, "stone_dark")
	_bank(main, -12, -36, 4)
	_bank(main, 12, -36, 4)
	_bank(main, -20, 34, 1)
	_bank(main, 0, 34, 1)
	_bank(main, 20, 34, 1)
	_bank(main, -15, 40, 2)
	_bank(main, 15, 40, 2)
	_bank(main, 0, 46, 3)
	# Trees rooted on the banks (positions match bank tops).
	_nature(main, "Tree_2_A_Color1", Vector3(-32, 4.0, -12), 0.4, 1.2, false)
	_nature(main, "Tree_3_B_Color1", Vector3(33, 3.2, -12), 2.1, 1.1, false)
	_nature(main, "Tree_4_A_Color1", Vector3(-10, 4.4, -30), 1.2, 1.3, false)
	_nature(main, "Tree_1_B_Color1", Vector3(10, 4.4, -30), 2.6, 1.25, false)
	_nature(main, "Tree_3_A_Color1", Vector3(-6, 7.2, -38), 0.8, 1.4, false)
	_nature(main, "Tree_2_C_Color1", Vector3(6, 7.2, -38), 2.2, 1.35, false)
	_nature(main, "Tree_1_C_Color1", Vector3(-38, 3.5, -8), 0.3, 1.2, false)
	_nature(main, "Tree_4_B_Color1", Vector3(-38, 3.5, 8), 1.9, 1.1, false)
	_nature(main, "Tree_2_B_Color1", Vector3(-46, 5.5, 0), 1.1, 1.3, false)
	_nature(main, "Tree_3_C_Color1", Vector3(37, 3.5, -6), 2.4, 1.15, false)
	_nature(main, "Tree_1_A_Color1", Vector3(45, 5.5, 2), 0.7, 1.25, false)
	_nature(main, "Tree_4_C_Color1", Vector3(-20, 3.5, -32), 1.5, 1.2, false)
	_nature(main, "Tree_2_C_Color1", Vector3(20, 3.5, -32), 2.8, 1.15, false)
	_nature(main, "Tree_3_B_Color1", Vector3(-7, 1.5, 34), 0.9, 1.2, false)
	_nature(main, "Tree_1_B_Color1", Vector3(15, 3.5, 40), 2.0, 1.1, false)
	_nature(main, "Tree_4_A_Color1", Vector3(0, 5.5, 46), 1.4, 1.15, false)
	_nature(main, "Rock_2_C_Color1", Vector3(-6.5, 5.4, -34), 0.5, 1.0, false)
	_nature(main, "Rock_2_B_Color1", Vector3(3.0, 5.2, -35), 2.0, 1.0, false)
	_nature(main, "Bush_3_B_Color1", Vector3(-5.2, 5.6, -33), 0.0, 1.3, false)
	_nature(main, "Bush_2_A_Color1", Vector3(-7.8, 5.6, -34.5), 1.0, 1.2, false)


static func _build_far_forest(main) -> void:
	# Mid ring (20-45 u): 55 denser trees with undergrowth, no shadows.
	# Far ring (45-90 u): 70 lightweight silhouettes, no shadows.
	# No collision, no scripts, shared scenes/materials throughout.
	var families := ["Tree_1_A_Color1", "Tree_2_B_Color1", "Tree_3_A_Color1", "Tree_4_B_Color1", "Tree_1_C_Color1", "Tree_3_C_Color1"]
	for i in 55:
		var angle := TAU * float(i) / 55.0 + 0.11 * float(i % 3)
		var dist := 22.0 + 20.0 * fmod(float(i * 37), 10.0) / 10.0
		var pos := Vector3(cos(angle) * dist, 0, sin(angle) * dist * 0.85 - 6.0)
		if absf(pos.z - 24.0) < 9.0 and absf(pos.x) < 40.0:
			continue
		if absf(pos.x) < 8.0 and pos.z > 0.0 and pos.z < 30.0:
			continue
		_nature(main, families[i % families.size()], pos, float(i) * 1.7, 1.1 + 0.4 * fmod(float(i * 53), 10.0) / 10.0, false)
		if i % 2 == 0:
			_nature(main, "Bush_3_A_Color1", pos + Vector3(2.2, 0, 1.0), 0.0, 1.5, false)
		if i % 4 == 1:
			_nature(main, "Grass_2_B_Singlesided_Color1", pos + Vector3(-1.8, 0, -1.0), 0.0, 1.8, false)
	for i in 70:
		var angle2 := TAU * float(i) / 70.0 + 0.07 * float(i % 5)
		var dist2 := 48.0 + 38.0 * fmod(float(i * 41), 10.0) / 10.0
		var pos2 := Vector3(cos(angle2) * dist2, 0, sin(angle2) * dist2 * 0.85 - 6.0)
		if absf(pos2.z - 24.0) < 10.0 and absf(pos2.x) < 42.0:
			continue
		if absf(pos2.x) < 9.0 and pos2.z > 0.0 and pos2.z < 32.0:
			continue
		_nature(main, families[(i + 2) % families.size()], pos2, float(i) * 2.3, 1.3 + 0.6 * fmod(float(i * 29), 10.0) / 10.0, false)
		if i % 4 == 0:
			_nature(main, "Bush_4_A_Color1", pos2 + Vector3(2.5, 0, 1.0), 0.0, 1.6, false)


static func _build_lighting(main) -> void:
	var world = main.world_root
	for env in world.find_children("*", "WorldEnvironment", true, false):
		world.remove_child(env)
		(env as WorldEnvironment).free()
	for old_sun in world.find_children("*", "DirectionalLight3D", true, false):
		world.remove_child(old_sun)
		(old_sun as DirectionalLight3D).free()
	# Late-afternoon sky: soft blue zenith, warm peach horizon, restrained sun.
	var sky_env := WorldEnvironment.new()
	sky_env.name = "LibrarySky"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sun_dir := Vector3(-0.8, 0.18, 0.3).normalized()
	var sky := Sky.new()
	sky.sky_material = _sky_material(sun_dir)
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#5a6d8f")
	environment.ambient_light_energy = 0.14
	environment.ambient_light_sky_contribution = 0.25
	environment.fog_enabled = true
	environment.fog_light_color = Color("#6d7c93")
	environment.fog_light_energy = 0.30
	environment.fog_density = 0.0022
	environment.fog_sky_affect = 0.30
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.68
	environment.glow_enabled = true
	environment.glow_intensity = 0.04
	environment.glow_bloom = 0.02
	environment.glow_strength = 0.80
	world.add_child(sky_env)
	sky_env.environment = environment
	var sun := DirectionalLight3D.new()
	sun.name = "LibrarySun"
	sun.rotation_degrees = Vector3(-10, -65, 0)
	sun.light_color = Color("#ffb37a")
	sun.light_energy = 0.45
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.45
	sun.directional_shadow_max_distance = 90.0
	world.add_child(sun)
	preload("res://scripts/world/sky_clouds.gd").build(world, 10, Vector3(60.0, 24.0, 55.0), 0.35, Color(0.62, 0.68, 0.80, 1.0))
	# Warm interior pools: tables, lounge, nook, reception, snack counter.
	_warm_pool(main, Vector3(-3.2, 2.6, 2.0), 0.75, 5.0)
	_warm_pool(main, Vector3(3.2, 2.6, 2.0), 0.75, 5.0)
	_warm_pool(main, Vector3(-11.5, 2.6, -6.5), 0.7, 4.5)
	_warm_pool(main, Vector3(-14.0, 2.6, 2.5), 0.65, 4.0)
	_warm_pool(main, Vector3(10.0, 2.6, 9.5), 0.65, 4.0)
	_warm_pool(main, Vector3(11.5, 2.6, -9.5), 0.65, 4.0)
	_warm_pool(main, Vector3(0, 2.6, 9.5), 0.6, 5.0)
	_warm_pool(main, Vector3(-12.0, 2.6, 7.5), 0.7, 4.5)
	_warm_pool(main, Vector3(12.5, 2.6, 5.5), 0.65, 4.0)
	_warm_pool(main, Vector3(0, 2.6, -6.0), 0.6, 5.0)


static func _sky_material(sun_dir: Vector3) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type sky;
render_mode use_half_res_pass;
uniform vec3 top_color : source_color = vec3(0.20, 0.29, 0.42);
uniform vec3 mid_color : source_color = vec3(0.32, 0.42, 0.52);
uniform vec3 horizon_cool : source_color = vec3(0.51, 0.56, 0.63);
uniform vec3 horizon_warm : source_color = vec3(0.76, 0.56, 0.45);
uniform vec3 sun_glow_color : source_color = vec3(1.0, 0.62, 0.42);
uniform vec3 ground_color : source_color = vec3(0.13, 0.14, 0.18);
uniform float sky_energy = 0.90;
uniform vec3 sun_direction = vec3(-0.8, 0.18, 0.3);
void sky() {
	vec3 eye = normalize(EYEDIR);
	vec3 sun_h = normalize(vec3(sun_direction.x, 0.0, sun_direction.z));
	vec3 eye_h = vec3(eye.x, 0.0, eye.z);
	float az = 0.0;
	if (length(eye_h) > 0.001) {
		az = dot(normalize(eye_h), sun_h) * 0.5 + 0.5;
	}
	float warmth = pow(az, 3.0);
	if (eye.y >= 0.0) {
		float h = clamp(eye.y, 0.0, 1.0);
		vec3 grad = mix(mid_color, top_color, smoothstep(0.08, 0.65, h));
		vec3 horizon = mix(horizon_cool, horizon_warm, warmth);
		COLOR = mix(horizon, grad, smoothstep(0.0, 0.28, h)) * sky_energy;
		float disk = smoothstep(0.9993, 0.9998, dot(eye, normalize(sun_direction)));
		float glow = pow(max(dot(eye, normalize(sun_direction)), 0.0), 24.0) * (1.0 - smoothstep(0.0, 0.5, h));
		COLOR += sun_glow_color * (disk * 1.2 + glow * 0.35 * (0.4 + 0.6 * warmth));
	} else {
		float h = clamp(-eye.y, 0.0, 1.0);
		COLOR = mix(horizon_cool * 0.55 + horizon_warm * 0.25 * warmth, ground_color, smoothstep(0.0, 0.4, h));
	}
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("sun_direction", sun_dir.normalized())
	return mat


static func _populate_npcs(main) -> void:
	# Six background students seated across zones; many seats stay free.
	var specs: Array = [
		[Vector3(-3.6, 0.1, 0.4), 0.0, 1, "Theo", "18m"],
		[Vector3(4.6, 0.1, 3.6), 0.0, 0, "Mina", "42m"],
		[Vector3(-6.0, 0.1, 9.0), 0.0, 2, "Hana", "27m"],
		[Vector3(-10.0, 0.1, -7.6), 0.0, 0, "Nora", "35m"],
		[Vector3(-14.6, 0.1, 2.5), 0.0, 1, "Ren", "22m"],
		[Vector3(10.5, 0.1, -9.0), 0.0, 2, "Yuki", "51m"],
	]
	for i in specs.size():
		var spec: Array = specs[i]
		main._create_npc(spec[0], spec[1], spec[2], spec[3], spec[4], true)
