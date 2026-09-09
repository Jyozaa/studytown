class_name GardenBuilder
extends RefCounted

## Central Pond, Garden only. Builds an editable, self-contained room.
## No dependency on main.gd, and never modifies another room or source model.
const RUNTIME := "res://assets/dev_local/blender_generated/runtime/"
const Spot := preload("res://scripts/study/study_spot.gd")
const Student := preload("res://scripts/npc/npc_controller.gd")
const SHORE := [
	Vector2(10.4, -1),
	Vector2(9.7, 1.7),
	Vector2(8.1, 4.1),
	Vector2(3.1, 5.2),
	Vector2(0.3, 6.3),
	Vector2(-4.4, 6.2),
	Vector2(-7.2, 4.3),
	Vector2(-9.6, 2.0),
	Vector2(-10.5, -1),
	Vector2(-9.3, -4.3),
	Vector2(-6.8, -5.8),
	Vector2(-3.5, -7.4),
	Vector2(0.1, -7.8),
	Vector2(3.8, -7.3),
	Vector2(7.4, -5.8),
	Vector2(9.5, -3.7),
]
var room: Node3D
var zones: Dictionary = {}
var scenes: Dictionary = {}
var runtime_paths: Dictionary = {}
var use_local_assets := true
var materials: Dictionary = {}
var spots: Array[StudySpot] = []
var shore := PackedVector2Array()
var island := PackedVector2Array()


func build() -> Node3D:
	var registry = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/local_asset_manifest.json")
	)
	if registry is Dictionary:
		for entry in registry.get("assets", []):
			var id: String = entry.get("asset_id", "")
			if id.begins_with("central_pond_"):
				runtime_paths[id.trim_prefix("central_pond_")] = (
					"res://assets/dev_local/" + str(entry.runtime_relative_path)
				)
	room = Node3D.new()
	room.name = "GardenCentralPond"
	room.set_meta("layout_version", "central_pond_A_1")
	for zone in [
		"Terrain",
		"Pond",
		"Island",
		"Bridges",
		"Paths",
		"Gazebo",
		"Cafe",
		"Campfire",
		"StudyLawn",
		"QuietGrove",
		"Planting",
		"Surroundings",
		"Lighting",
		"StudySpots",
		"Students",
		"Cameras"
	]:
		var node := Node3D.new()
		node.name = zone
		room.add_child(node)
		zones[zone] = node
	materials.grass = material("#3d6248")
	materials.island = material("#51734f")
	materials.path = material("#68615a")
	materials.edge = material("#55504a")
	materials.soil = material("#49382c")
	materials.wood = material("#987047")
	materials.leaf = material("#417651")
	materials.stone = material("#78877f")
	materials.cream = material("#e7d4aa")
	materials.grass = meadow(false)
	materials.island = meadow(true)
	apply_ground_texture(materials.path, "tile.png", 0.14, Color("#82786c"))
	shore = smooth_loop(PackedVector2Array(SHORE), 5)
	for i in shore.size():
		var angle := TAU * float(i) / shore.size()
		var radius := 1.0 + 0.05 * sin(angle * 3.0 + 0.7)
		island.append(Vector2(cos(angle) * 3.5 * radius, -1.0 + sin(angle) * 3.25 * radius))
	terrain_and_water()
	bridges()
	paths()
	destinations()
	planting()
	students()
	lighting()
	preload("res://scripts/rooms/garden_sunset.gd").new().build(self)
	cameras()
	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector3(0, 0.65, 15.6)
	spawn.add_to_group("editable_player_spawn", true)
	room.add_child(spawn)
	set_owners(room)
	return room


func material(hex: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.roughness = 0.88
	return mat


func apply_ground_texture(
	mat: StandardMaterial3D, file: String, scale_value: float, tint: Color
) -> void:
	var path := "res://assets/dev_local/environment/" + file
	if not use_local_assets or not ResourceLoader.exists(path):
		return
	mat.albedo_texture = load(path)
	mat.albedo_color = tint
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * scale_value
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC


func meadow(lighter: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/garden_meadow.gdshader")
	var path := "res://assets/dev_local/environment/garden_grass.jpeg"
	if use_local_assets and ResourceLoader.exists(path):
		mat.set_shader_parameter("has_pattern", true)
		mat.set_shader_parameter("lawn_pattern", load(path))
	if lighter:
		mat.set_shader_parameter("sun_grass", Color("#3b5035"))
	return mat


func smooth_loop(points: PackedVector2Array, steps: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in points.size():
		for j in steps:
			result.append(
				points[i].cubic_interpolate(
					points[(i + 1) % points.size()],
					points[posmod(i - 1, points.size())],
					points[(i + 2) % points.size()],
					float(j) / steps
				)
			)
	return result


func flat_polygon(
	parent: Node, label: String, polygon: PackedVector2Array, y: float, mat: Material
) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(polygon)
	for i in range(0, indices.size(), 3):
		# Godot front faces are clockwise when seen from above.
		for k in [0, 1, 2]:
			var p := polygon[indices[i + k]]
			surface.set_normal(Vector3.UP)
			surface.set_uv(p * 0.085)
			surface.add_vertex(Vector3(p.x, y, p.y))
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = surface.commit()
	mesh.material_override = mat
	parent.add_child(mesh)
	return mesh


func strip(
	parent: Node,
	label: String,
	outer: PackedVector2Array,
	inner: PackedVector2Array,
	y: float,
	mat: Material
) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outer.size():
		var next := (i + 1) % outer.size()
		for p: Vector2 in [outer[i], outer[next], inner[next], outer[i], inner[next], inner[i]]:
			surface.set_normal(Vector3.UP)
			surface.set_uv(p * 0.3)
			surface.add_vertex(Vector3(p.x, y, p.y))
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = surface.commit()
	mesh.material_override = mat
	parent.add_child(mesh)


func expanded(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in points:
		result.append(p + (p - Vector2(0, -1)).normalized() * amount)
	return result


func terrain_and_water() -> void:
	box(
		zones.Terrain,
		"StructuralFloor",
		Vector3(52, 0.4, 38),
		Vector3(0, -0.2, 0),
		materials.grass,
		true
	)
	block(zones.Terrain, "SurroundingGroundFloor", Vector3(200, 0.2, 200), Vector3(0, -0.13, 0))
	flat_polygon(
		zones.Terrain,
		"SurroundingMeadow",
		PackedVector2Array(
			[Vector2(-100, -100), Vector2(100, -100), Vector2(100, 100), Vector2(-100, 100)]
		),
		-0.025,
		materials.grass
	)
	# The shared shader is instanced, not edited; other rooms keep their water.
	var water := ShaderMaterial.new()
	water.shader = load("res://shaders/garden_sunset_water.gdshader")
	flat_polygon(zones.Pond, "OrganicWater", shore, 0.055, water)
	strip(zones.Pond, "SoftShoreline", expanded(shore, 0.42), shore, 0.065, materials.soil)
	flat_polygon(zones.Island, "IslandBank", expanded(island, 0.12), 0.09, materials.soil)
	flat_polygon(zones.Island, "IslandMeadow", island, 0.115, materials.island)
	prism(zones.Island, "IslandStructuralFloor", island, -0.1, 0.115)
	# One collision wedge per shoreline segment, with the bridge channel cut
	# out. This preserves a true island hole; a single convex hull would seal it.
	var channel := PackedVector2Array(
		[Vector2(-13, -2.18), Vector2(13, -2.18), Vector2(13, 0.18), Vector2(-13, 0.18)]
	)
	for i in shore.size():
		var n := (i + 1) % shore.size()
		var wedge := PackedVector2Array([shore[i], shore[n], island[n], island[i]])
		for piece in Geometry2D.clip_polygons(wedge, channel):
			prism(zones.Pond, "WaterBoundary%02d" % i, piece, -0.2, 0.9)
	for data in [
		["NorthBoundary", Vector3(52, 3, 0.3), Vector3(0, 1.4, -18.6)],
		["SouthBoundary", Vector3(52, 3, 0.3), Vector3(0, 1.4, 18.6)],
		["WestBoundary", Vector3(0.3, 3, 38), Vector3(-25.6, 1.4, 0)],
		["EastBoundary", Vector3(0.3, 3, 38), Vector3(25.6, 1.4, 0)]
	]:
		block(zones.Terrain, data[0], data[1], data[2])


func bridges() -> void:
	for x in [-6.95, 6.95]:
		var bridge := prop(
			"Bridges", "garden_pond_log_bridge", Vector3(x, -0.20, -1), 0, Vector3(1, 0.45, 0.55)
		)
		bridge.name = "WestLogBridge" if x < 0 else "EastLogBridge"
		# Smooth structural deck at the log crowns. Godot floor snap is not
		# step-up logic: explicit approach ramps are required at BOTH banks.
		block(zones.Bridges, "BridgeDeck", Vector3(7.8, 0.38, 2.34), Vector3(x, 0.17, -1))
		for direction in [-1, 1]:
			bridge_ramp(x, direction)
		for z in [-2.30, 0.30]:
			block(zones.Bridges, "BridgeRail", Vector3(7.8, 1.0, 0.16), Vector3(x, 0.45, z))


func bridge_ramp(center_x: float, direction: int) -> void:
	var high_x := center_x + direction * 3.9
	var low_x := center_x + direction * 4.9
	var corners := PackedVector3Array(
		[
			Vector3(low_x, 0.005, -2.17),
			Vector3(low_x, 0.005, 0.17),
			Vector3(high_x, 0.36, 0.17),
			Vector3(high_x, 0.36, -2.17)
		]
	)
	var body := StaticBody3D.new()
	body.name = "BridgeApproachRamp"
	var shape := CollisionShape3D.new()
	var convex := ConvexPolygonShape3D.new()
	var points := corners.duplicate()
	for p in corners:
		points.append(Vector3(p.x, -0.2, p.z))
	convex.points = points
	shape.shape = convex
	body.add_child(shape)
	zones.Bridges.add_child(body)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var order := [0, 1, 2, 0, 2, 3] if direction == 1 else [0, 2, 1, 0, 3, 2]
	for i in order:
		surface.set_uv(Vector2(corners[i].x, corners[i].z) * 0.3)
		surface.add_vertex(corners[i] + Vector3.UP * 0.001)
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = "StoneBridgeApproach"
	mesh.mesh = surface.commit()
	mesh.material_override = materials.path
	zones.Bridges.add_child(mesh)


func paths() -> void:
	strip(
		zones.Paths,
		"WindingRingBorder",
		expanded(shore, 4.0),
		expanded(shore, 1.15),
		0.020,
		materials.edge
	)
	strip(
		zones.Paths,
		"WindingRingPath",
		expanded(shore, 3.83),
		expanded(shore, 1.32),
		0.025,
		materials.path
	)
	for data in [
		[Vector2(0, 15.8), Vector2(0, 8.7), 3.5],
		[Vector2(0, -10), Vector2(0, -14), 3.2],
		[Vector2(-14, -1), Vector2(-19, -1), 2.6],
		[Vector2(13, -1), Vector2(17, -6.8), 2.4],
		[Vector2(10, 8), Vector2(17, 10), 2.4],
		[Vector2(-9, 8), Vector2(-17, 10), 2.4],
		[Vector2(-12.7, -1), Vector2(12.7, -1), 2.3]
	]:
		# The cross route is drawn only on land; bridges carry it over water.
		if data[0].x == -12.7:
			path_segment(Vector2(-3.5, -1), Vector2(3.5, -1), 2.15, 0.12)
			path_segment(Vector2(-14, -1), Vector2(-10.7, -1), 2.3)
			path_segment(Vector2(10.7, -1), Vector2(14, -1), 2.3)
		else:
			path_segment(data[0], data[1], data[2])
	for data in [
		[Vector2(0, -14), Vector2(4.4, 3.8)],
		[Vector2(-18.8, -3.5), Vector2(4.3, 6.5)],
		[Vector2(17, -7), Vector2(3.9, 3.3)],
		[Vector2(17, 9), Vector2(4.8, 3.8)],
		[Vector2(-17, 10), Vector2(4.3, 3.5)]
	]:
		var poly := ellipse(data[0], data[1], 40)
		flat_polygon(zones.Paths, "DestinationTerrace", poly, 0.03, materials.path)


func path_segment(a: Vector2, b: Vector2, width: float, y := 0.028) -> void:
	var side := (b - a).normalized().orthogonal() * width * 0.5
	flat_polygon(
		zones.Paths,
		"ConnectingPath",
		PackedVector2Array([a - side, b - side, b + side, a + side]),
		y,
		materials.path
	)


func ellipse(center: Vector2, radius: Vector2, count: int) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for i in count:
		var a := TAU * float(i) / count
		polygon.append(center + Vector2(cos(a), sin(a)) * radius)
	return polygon


func destinations() -> void:
	var island_tree := prop(
		"Island", "garden_big_tree", Vector3(0, 0.11, -3.0), 0.0, Vector3(0.70, 0.83, 0.48)
	)
	mesh_collision(island_tree, "Trunk")
	seat("island", Vector3(-1.65, 0.12, 0.48), PI, "garden_forest_bench", 0.0)
	seat("island", Vector3(1.65, 0.12, 0.48), PI, "garden_forest_bench", 0.0)
	var gazebo := prop(
		"Gazebo", "garden_pond_gazebo", Vector3(0, 0.035, -14.7), PI / 8, Vector3(1.9, 1.5, 1.9)
	)
	mesh_collision(gazebo)
	# Model-accurate column collision keeps each entrance gap open.
	block(zones.Gazebo, "GazeboRoof", Vector3(6.8, 1.1, 6.8), Vector3(0, 5.9, -14.7), 16)
	table("Gazebo", Vector3(0, 0.04, -14.7), 0, false)
	for d in [
		[Vector3(-1.9, 0.05, -14.7), -PI / 2],
		[Vector3(1.9, 0.05, -14.7), PI / 2],
		[Vector3(0, 0.05, -16.65), PI],
		[Vector3(0, 0.05, -12.75), 0.0]
	]:
		seat("gazebo", d[0], d[1])
	prop("Cafe", "garden_cafe_counter", Vector3(-22, 0.04, -4), PI / 2, Vector3.ONE * 0.72)
	block(zones.Cafe, "Counter", Vector3(1.0, 1.4, 5.3), Vector3(-22, 0.7, -4))
	for d in [
		[Vector3(-18.5, 0.04, -7), 0.15],
		[Vector3(-18.1, 0.04, -2.2), -0.23],
		[Vector3(-19.8, 0.04, 2.9), 0.25]
	]:
		table("Cafe", d[0], d[1], true)
	# Two paired study tables, with a third parasol table for the café story.
	for d in [[Vector3(-18.5, 0.04, -7), 0.15], [Vector3(-18.1, 0.04, -2.2), -0.23]]:
		var side := Basis(Vector3.UP, d[1]) * Vector3.RIGHT * 1.9
		seat("cafe", d[0] - side, -PI / 2 + d[1])
		seat("cafe", d[0] + side, PI / 2 + d[1])
	for z in [1.2, 4.6]:
		prop("Cafe", "cafe_chair", Vector3(-19.8, 0.04, z), 0 if z < 3 else PI)
	for d in [
		["garden_cafe_coffee_mill", Vector3(-22, 0.78, -5.5)],
		["garden_cafe_siphon", Vector3(-22, 0.78, -3.8)],
		["garden_cafe_milk_pitcher", Vector3(-22, 0.78, -2.6)]
	]:
		prop("Cafe", d[0], d[1], PI / 2, Vector3.ONE * 0.85)
	prop("Campfire", "garden_forest_firepit", Vector3(17, 0.04, -7), 0, Vector3.ONE * 1.5)
	block(zones.Campfire, "Firepit", Vector3(1.8, 0.8, 1.8), Vector3(17, 0.4, -7))
	seat("campfire", Vector3(14.6, 0.04, -7.3), -PI / 2, "garden_log_seat", -0.14)
	seat("campfire", Vector3(19.3, 0.04, -7.5), PI / 2, "garden_log_seat", -0.14)
	prop("Campfire", "garden_log_seat", Vector3(17, 0.04, -9.2))
	for d in [[Vector3(15, 0.04, 8.2), 0.18], [Vector3(19, 0.04, 10.6), -0.25]]:
		table("StudyLawn", d[0], d[1], false)
		var side := Basis(Vector3.UP, d[1]) * Vector3.RIGHT * 1.7
		seat("lawn", d[0] - side, -PI / 2 + d[1])
		seat("lawn", d[0] + side, PI / 2 + d[1])
	seat("grove", Vector3(-17.4, 0.04, 8.2), PI, "garden_forest_bench", 0.0)
	seat("grove", Vector3(-19.1, 0.04, 11.3), -PI / 2, "garden_forest_bench", 0.0)
	prop("Planting", "garden_forest_bench", Vector3(-7.8, 0.035, -9.8), -0.4)
	prop("Planting", "garden_forest_bench", Vector3(8.2, 0.035, -9.3), 0.4)
	prop("Planting", "garden_party_light_arch", Vector3(0, 0.025, 13.5), 0, Vector3.ONE * 1.22)
	for x in [-2.15, 2.15]:
		block(zones.Planting, "ArchPost", Vector3(0.26, 3.5, 0.26), Vector3(x, 1.7, 13.5))


func table(zone: String, pos: Vector3, yaw: float, parasol: bool) -> void:
	prop(zone, "garden_pond_parasol" if parasol else "garden_cafe_table", pos, yaw)
	block(zones[zone], "Table", Vector3(1.45, 1.15, 1.45), pos + Vector3.UP * 0.55)
	if parasol:
		block(zones[zone], "ParasolCanopy", Vector3(2.9, 0.5, 2.9), pos + Vector3.UP * 3.5, 16)
	else:
		prop(zone, "garden_cafe_coffee_cup", pos + Vector3(0.45, 0.91, 0.1), yaw)
		prop(zone, "garden_cafe_saucer", pos + Vector3(0.45, 0.87, 0.1), yaw)


func seat(
	category: String, pos: Vector3, facing: float, model := "cafe_chair", vertical_offset := 0.0
) -> void:
	var zone: String = {
		"island": "Island",
		"gazebo": "Gazebo",
		"cafe": "Cafe",
		"campfire": "Campfire",
		"lawn": "StudyLawn",
		"grove": "QuietGrove"
	}[category]
	prop(zone, model, pos, facing + PI)
	var forward := Basis(Vector3.UP, facing) * Vector3.FORWARD
	var right := Basis(Vector3.UP, facing) * Vector3.RIGHT
	var spot := Spot.new()
	spot.name = "Seat_%s_%02d" % [category, spots.size()]
	spot.seat_id = "garden_%s_%02d" % [category, spots.size()]
	spot.position = pos + forward * 0.22
	spot.local_facing_yaw = facing
	# Side approach avoids walking through the table in front or chair back.
	spot.standing_offset = right * 1.23 - forward * 0.2
	if category == "island":
		spot.standing_offset = right * (0.9 if pos.x > 0 else -0.9) + forward * 0.6
	if category == "gazebo" and pos.z > -13:
		spot.standing_offset = -right * 1.05 - forward * 0.1
	spot.sitting_offset = Vector3.UP * 0.05
	spot.seat_type = "cafe_chair"
	spot.study_type = "Book"
	spot.seated_visual_offset = Vector3(0, 0.20 + vertical_offset, 0.12)
	spot.interaction_radius = 1.65
	spot.seat_height = 0.72 + vertical_offset
	spot.camera_position_offset = forward * 3.7 + right * 2.0 + Vector3.UP * 2.7
	spot.camera_target_offset = Vector3.UP * 1.62
	spot.set_meta("garden_category", category)
	spot.set_meta(
		"garden_cushion_height", 0.47 if "bench" in model else (0.65 if "log" in model else 0.73)
	)
	spot.add_to_group("editable_study_spot", true)
	zones.StudySpots.add_child(spot)
	spots.append(spot)
	block(zones[zone], "SeatBack", Vector3(1.0, 1.1, 0.2), pos - forward * 0.3).rotation.y = facing


func planting() -> void:
	# Deliberate beds; no seeded random scatter and no planting on the ring.
	for p in [
		Vector3(-20, 0, -13),
		Vector3(20, 0, -13),
		Vector3(-21, 0, 13.8),
		Vector3(20.5, 0, 14.8),
		Vector3(-6.1, 0, -16.8),
		Vector3(6.1, 0, -16.8)
	]:
		prop("Planting", "garden_pond_blossom", p, p.x * 0.12, Vector3.ONE * 0.96)
		block(zones.Planting, "BlossomTrunk", Vector3(0.7, 3, 0.7), p + Vector3.UP * 1.5)
	for d in [
		[-22, -15, 1.15],
		[-15, -16, 1.25],
		[-8.3, -15.4, 1.0],
		[7.9, -15.5, 1.0],
		[15, -15.8, 1.25],
		[23, -14, 1.1],
		[-24, -8.5, 0.95],
		[24, -6, 1.1],
		[-24, 2, 1.05],
		[24, 3, 0.95],
		[-23, 15.5, 1.15],
		[-15.4, 15.5, 1.15],
		[-9, 16.2, 0.85],
		[9.2, 16.5, 0.88],
		[23, 15.7, 1.15],
		[22, 8.5, 0.9],
		[-14.5, 6, 0.85],
		[11, -13.7, 0.85]
	]:
		tree(Vector3(d[0], 0, d[1]), d[2], "Planting")
	# The sunset layer supplies irregular forest clusters and rolling terrain.
	for d in [
		[-8.6, -4.9],
		[-5.4, -7],
		[5.7, -6.7],
		[9.8, -3.4],
		[8.4, 3.7],
		[4.6, 5.8],
		[-2.8, 5.8],
		[-8.6, 3.6],
		[-3, -2.9],
		[2.7, -2.9],
		[-21, -11.7],
		[21, -10.5],
		[-5.2, -14.8],
		[5.2, -14.8],
		[-20.4, 6.7],
		[-15.4, 12.3],
		[13.2, 12.8],
		[20, 5.1],
		[-3.8, 14.6],
		[3.8, 14.6]
	]:
		bed(Vector3(d[0], 0.04, d[1]), spots.size() + int(d[0] * 3))
	for i in 13:
		var p := shore[(i * 6 + 3) % shore.size()]
		if absf(p.y + 1) < 1.8:
			continue
		var outward := (p - Vector2(0, -1)).normalized()
		for j in 2 if i % 3 else 3:
			var at := p + outward * (0.2 + j * 0.22) + outward.orthogonal() * (j * 0.72)
			var model: String = ["garden_rock_a", "garden_rock_b", "garden_pond_low_rock"][posmod(
				i + j, 3
			)]
			prop(
				"Planting",
				model,
				Vector3(at.x, 0.04, at.y),
				i * 0.7 + j,
				Vector3.ONE * (0.4 + j * 0.13)
			)
	for d in [[-24, -12], [-24, 7], [24, -1], [24, 12], [-5.5, 16.8], [5.5, 16.8]]:
		prop("Planting", "garden_hedge", Vector3(d[0], 0, d[1]), PI / 2 if absf(d[0]) > 20 else 0)
		block(
			zones.Planting,
			"Hedge",
			Vector3(0.9, 1.1, 2.7) if absf(d[0]) > 20 else Vector3(2.7, 1.1, 0.9),
			Vector3(d[0], 0.5, d[1])
		)
	# Layer low planting beneath the perimeter canopy, leaving route mouths open.
	for side in [-1, 1]:
		for z in [-15, -10, -4, 2, 8, 14]:
			bed(Vector3(side * 24, 0.04, z), z)
	for x in [-21, -16, -11, -7, 7, 11, 16, 21]:
		bed(Vector3(x, 0.04, -17.2), x)
		if absf(x) > 9:
			bed(Vector3(x, 0.04, 17.1), x + 3)


func tree(pos: Vector3, size: float, zone: String) -> void:
	prop(zone, "garden_oak_tree", pos, pos.x * 0.17, Vector3.ONE * size)
	if zone != "Surroundings":
		block(
			zones[zone], "TreeTrunk", Vector3(0.85 * size, 3.2, 0.85 * size), pos + Vector3.UP * 1.6
		)


func bed(pos: Vector3, variant: int) -> void:
	var bed_outline := ellipse(Vector2(pos.x, pos.z), Vector2(1.45 + 0.15 * sin(variant), 0.85), 16)
	for i in bed_outline.size():
		bed_outline[i] += Vector2(sin(i * 2.1 + variant), cos(i * 1.7)) * 0.12
	flat_polygon(zones.Planting, "PlantedSoil", bed_outline, 0.035, materials.soil)
	prop(
		"Planting", "garden_shrub", pos + Vector3(-0.5, 0, -0.15), variant * 0.9, Vector3.ONE * 0.67
	)
	prop(
		"Planting",
		"garden_flower_patch",
		pos + Vector3(0.4, 0, 0.1),
		variant * 0.4,
		Vector3.ONE * (0.58 + 0.12 * absf(sin(variant)))
	)
	prop("Planting", "garden_weed_clump", pos + Vector3(0.95, 0, -0.3), variant, Vector3.ONE * 0.7)


func students() -> void:
	for data in [
		[0, "Lumi", "rosie"],
		[3, "Ben", "raymond"],
		[7, "Poppy", "bob"],
		[10, "Sora", "rosie"],
		[13, "Mina", "raymond"],
		[16, "Pip", "bob"]
	]:
		var spot := spots[int(data[0])]
		var npc := Student.new()
		npc.name = "NPC_" + data[1]
		npc.editor_display_name = data[1]
		npc.editor_occupant_id = data[1]
		npc.editor_character_id = data[2]
		npc.editor_timer_text = "%dm" % (18 + int(data[0]))
		npc.editor_spot_id = spot.seat_id
		npc.editor_study_kind = "Book"
		npc.editor_seated = true
		npc.position = spot.position + spot.sitting_offset
		npc.rotation.y = spot.local_facing_yaw
		zones.Students.add_child(npc)


func lighting() -> void:
	var env := WorldEnvironment.new()
	env.name = "GardenSunset"
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_SKY
	var sky_material := ShaderMaterial.new()
	sky_material.shader = load("res://shaders/garden_sunset_sky.gdshader")
	env.environment.sky = Sky.new()
	env.environment.sky.sky_material = sky_material
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#9298bd")
	env.environment.ambient_light_energy = 0.55
	env.environment.ambient_light_sky_contribution = 0.15
	env.environment.fog_enabled = true
	env.environment.fog_mode = Environment.FOG_MODE_DEPTH
	env.environment.fog_depth_begin = 40.0
	env.environment.fog_depth_end = 210.0
	env.environment.fog_depth_curve = 1.6
	env.environment.fog_density = 1.0
	env.environment.fog_light_color = Color("#79768c")
	env.environment.fog_sky_affect = 0.0
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	zones.Lighting.add_child(env)
	# One static, local cubemap supplies tree/gazebo silhouettes to the pond.
	# It is captured once, not six new views every frame.
	var reflection := ReflectionProbe.new()
	reflection.name = "PondSunsetReflection"
	reflection.position = Vector3(0, 6.0, -1)
	reflection.origin_offset = Vector3(0, -4.5, 0)
	reflection.size = Vector3(34, 16, 30)
	reflection.max_distance = 95.0
	reflection.box_projection = true
	reflection.intensity = 0.65
	reflection.update_mode = ReflectionProbe.UPDATE_ONCE
	zones.Lighting.add_child(reflection)
	var sun := DirectionalLight3D.new()
	sun.name = "GardenWarmSun"
	sun.rotation_degrees = Vector3(-29, -48, 0)
	sun.light_color = Color("#ffd0a0")
	sun.light_energy = 0.95
	sun.shadow_opacity = 0.72
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 75
	zones.Lighting.add_child(sun)
	for p in [
		Vector3(-2.9, 0, 14.5),
		Vector3(2.9, 0, 14.5),
		Vector3(-4, 0, -11.6),
		Vector3(4, 0, -11.6),
		Vector3(-15.4, 0, -4.6),
		Vector3(20.5, 0, -5),
		Vector3(-13, 0, 10.6),
		Vector3(12.5, 0, 6.8)
	]:
		prop("Lighting", "garden_forest_lamp", p)
	for p in [
		Vector3(0, 3.8, -14), Vector3(-21, 2.0, -4), Vector3(17, 1.0, -7), Vector3(0, 2.2, 13.5),
		Vector3(-13, 2.0, 10.6), Vector3(12.5, 2.0, 6.8), Vector3(-7, 2.0, -1), Vector3(7, 2.0, -1)
	]:
		var light := OmniLight3D.new()
		light.position = p
		light.light_color = Color("#ffba70")
		light.light_energy = 1.25
		light.omni_range = 5.0
		light.shadow_enabled = false
		zones.Lighting.add_child(light)


func cameras() -> void:
	for d in [
		["PondAndIsland", Vector3(12, 9, 11), Vector3(0, 2, -1)],
		["GazeboVista", Vector3(-5, 4, -10), Vector3(0, 2.1, -14)],
		["CafeTerrace", Vector3(-12, 4, 2), Vector3(-18.5, 1.2, -4)],
		["Fireside", Vector3(12, 4, -2), Vector3(17, 1.1, -7)]
	]:
		var camera := Camera3D.new()
		camera.name = d[0]
		camera.position = d[1]
		camera.transform = camera.transform.looking_at(d[2])
		camera.fov = 46
		camera.set_meta("shot_name", d[0])
		camera.add_to_group("editable_broll_camera", true)
		zones.Cameras.add_child(camera)


func prop(zone: String, id: String, pos: Vector3, yaw := 0.0, size := Vector3.ONE) -> Node3D:
	var path: String = runtime_paths.get(id, RUNTIME + id + ".glb")
	var instance: Node3D
	if use_local_assets and ResourceLoader.exists(path):
		if not scenes.has(path):
			scenes[path] = load(path)
		instance = scenes[path].instantiate()
	else:
		instance = fallback(id)
	instance.name = id
	instance.set_meta("garden_asset_id", id)
	instance.position = pos
	instance.rotation.y = yaw
	instance.scale = size
	zones[zone].add_child(instance)
	return instance


func mesh_collision(node: Node3D, name_filter := "") -> void:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		if not name_filter.is_empty() and name_filter not in str(child.name):
			continue
		var local: Transform3D = child.transform
		var ancestor: Node = child.get_parent()
		while ancestor != node:
			if ancestor is Node3D:
				local = ancestor.transform * local
			ancestor = ancestor.get_parent()
		var body := StaticBody3D.new()
		body.name = "ModelCollision"
		body.transform = node.transform * local
		body.collision_layer = 1
		body.collision_mask = 2
		var shape := CollisionShape3D.new()
		shape.shape = child.mesh.create_trimesh_shape()
		body.add_child(shape)
		node.get_parent().add_child(body)


func fallback(id: String) -> Node3D:
	# Public clean-room geometry only when the owner-local model is absent.
	var node := Node3D.new()
	if "tree" in id:
		box(node, "Trunk", Vector3(0.6, 3.3, 0.6), Vector3(0, 1.65, 0), materials.wood)
		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 2.1
		sphere.height = 3.5
		mesh.mesh = sphere
		mesh.position.y = 3.6
		mesh.material_override = materials.leaf
		node.add_child(mesh)
	elif "bridge" in id:
		for i in 25:
			box(
				node,
				"Plank",
				Vector3(0.3, 0.2, 4.3),
				Vector3(-3.8 + i * 0.31, 0.4, 0),
				materials.wood
			)
	elif "gazebo" in id:
		for x in [-1.9, 1.9]:
			for z in [-1.9, 1.9]:
				box(node, "Post", Vector3(0.18, 3.0, 0.18), Vector3(x, 1.5, z), materials.wood)
		box(node, "Roof", Vector3(4.5, 0.3, 4.5), Vector3(0, 3.2, 0), materials.leaf)
	elif "chair" in id or "bench" in id or "seat" in id:
		var width := 1.8 if "bench" in id else 0.9
		box(node, "Seat", Vector3(width, 0.14, 0.9), Vector3(0, 0.72, 0), materials.wood)
		box(node, "Back", Vector3(width, 0.55, 0.12), Vector3(0, 1.05, -0.35), materials.wood)
		for x in [-width * 0.4, width * 0.4]:
			for z in [-0.3, 0.3]:
				box(node, "Leg", Vector3(0.1, 0.7, 0.1), Vector3(x, 0.35, z), materials.wood)
	elif "table" in id or "parasol" in id or "counter" in id:
		box(node, "Tabletop", Vector3(1.7, 0.15, 1.7), Vector3(0, 0.88, 0), materials.wood)
		box(node, "Base", Vector3(0.4, 0.8, 0.4), Vector3(0, 0.4, 0), materials.wood)
	else:
		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.4
		sphere.height = 0.6
		mesh.mesh = sphere
		mesh.position.y = 0.3
		mesh.material_override = materials.stone if "rock" in id else materials.leaf
		node.add_child(mesh)
	return node


func box(
	parent: Node, label: String, size: Vector3, pos: Vector3, mat: Material, collision := false
) -> Node3D:
	var node := MeshInstance3D.new()
	node.name = label + "Visual"
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	parent.add_child(node)
	if collision:
		block(parent, label, size, pos)
	return node


func block(parent: Node, label: String, size: Vector3, pos: Vector3, layer := 1) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = pos
	body.collision_layer = layer
	body.collision_mask = 2
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	parent.add_child(body)
	return body


func prism(
	parent: Node, label: String, polygon: PackedVector2Array, low: float, high: float
) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = 1
	body.collision_mask = 2
	var shape := CollisionShape3D.new()
	var convex := ConvexPolygonShape3D.new()
	var vertices := PackedVector3Array()
	for p in polygon:
		vertices.append(Vector3(p.x, low, p.y))
		vertices.append(Vector3(p.x, high, p.y))
	convex.points = vertices
	shape.shape = convex
	body.add_child(shape)
	parent.add_child(body)


func set_owners(parent: Node) -> void:
	for child in parent.get_children():
		child.owner = room
		# Preserve GLB PackedScene ownership and shared meshes. Flattening the
		# imported descendants duplicates overrides and confuses editor reloads.
		if child.scene_file_path.is_empty():
			set_owners(child)
