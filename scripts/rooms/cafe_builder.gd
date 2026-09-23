class_name CafeBuilder
extends RefCounted

## Study Café builder (replaces the Garden, room index 1).
##
## World convention: +x EAST/right, +z SOUTH/front/entrance, +y UP.
## Ground floor y=0, mezzanine walking surface y=4.8, bounds x±16 / z±12.
## No roof: full-height walls with a cutaway-friendly open top so the
## exploration camera always sees the interior (x-ray covers occlusion).
##
## Built incrementally by phase; each phase is screenshot-verified in
## art_reviews/current/ before the next begins.

const MEZZ_TOP := 4.8
const MEZZ_SLAB_T := 0.5
const MEZZ_Z_EDGE := -3.5
const WALL_H := 7.2
const WALL_T := 0.4


static func build(main) -> void:
	_build_materials(main)
	_add_environment(main)
	main._add_structural_floor(Vector2(32.0, 24.0))
	_build_ground_floor(main)
	_build_walls(main)
	_build_mezzanine(main)
	_build_stairs(main)
	_build_exterior_base(main)
	main._add_world_boundaries(Vector2(15.5, 11.5))
	_build_ground_furniture(main)
	_build_counter_and_kitchen(main)
	_build_upstairs(main)
	_build_interior_lamps(main)
	_build_lighting(main)
	_populate_npcs(main)
	# Baked-scene discriminator: editable_main.gd loads room_layouts/garden.tscn
	# for room 1 and must tell the Café apart from the legacy Garden (both use
	# room id "garden"). This inert marker bakes into the scene; it changes
	# nothing at runtime.
	var marker := Node3D.new()
	marker.name = "CafeRoomMarker"
	marker.set_meta("cafe_room", true)
	main.world_root.add_child(marker)


static func _populate_npcs(main) -> void:
	var specs: Array = [
		[Vector3(-13.0, 0.65, -2.5), 0.0, 0, "Mina", "42m"],
		[Vector3(-3.5, 0.65, 2.8), PI, 1, "Theo", "18m"],
		[Vector3(6.0, 0.65, 4.2), -PI * 0.5, 2, "Hana", "27m"],
		[Vector3(10.5, 0.65, 7.6), PI, 0, "Nora", "35m"],
		[Vector3(-10.0, 5.45, -5.5), PI, 1, "Ren", "22m"],
		[Vector3(9.5, 5.45, -6.0), 0.0, 2, "Yuki", "51m"],
	]
	for i in specs.size():
		var spec: Array = specs[i]
		var pos: Vector3 = spec[0] as Vector3
		var yaw: float = spec[1] as float
		var variant: int = spec[2] as int
		var display_name: String = spec[3] as String
		var timer: String = spec[4] as String
		main._create_npc(pos, yaw, variant, display_name, timer, true)


static func _build_materials(main) -> void:
	# Restrained custom palette supporting the KayKit furniture, never
	# fighting it. Stored on main.mats beside the shared set.
	# Exterior walls use warm taupe-mocha (sunset-friendly); cream stays
	# only for the kitchen tile. Lamp glow is unshaded warm emissive.
	var extra := {
		"cafe_floor": Color("#8A4531"),
		"cafe_darkwood": Color("#6E3524"),
		"cafe_cream": Color("#E8DCC6"),
		"cafe_taupe": Color("#A68A64"),
		"cafe_trim": Color("#533528"),
		"cafe_tile": Color("#E8DCC6"),
		"cafe_tile_dark": Color("#2D211C"),
		"cafe_ground": Color("#26382A"),
	}
	for key in extra:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = extra[key]
		mat.roughness = 0.82
		main.mats[key] = mat
	var lamp_glow := StandardMaterial3D.new()
	lamp_glow.albedo_color = Color("#ffd9a0")
	lamp_glow.emission_enabled = true
	lamp_glow.emission = Color("#ffbe6e")
	lamp_glow.emission_energy_multiplier = 2.4
	lamp_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	main.mats["cafe_lamp_glow"] = lamp_glow
	# Glass-floor panels: subtle blue-grey, genuinely see-through.
	var glass_floor := StandardMaterial3D.new()
	glass_floor.albedo_color = Color(0.72, 0.83, 0.90, 0.32)
	glass_floor.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass_floor.roughness = 0.15
	glass_floor.metallic = 0.10
	main.mats["cafe_glass_floor"] = glass_floor
	# Dark gunmetal beams for the glass grid + pendant cords/shades.
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("#363c42")
	metal.metallic = 0.85
	metal.roughness = 0.45
	main.mats["cafe_metal"] = metal
	# Warm lit-window accents for the sunset city (unshaded amber).
	var window_glow := StandardMaterial3D.new()
	window_glow.albedo_color = Color("#ff9d5c")
	window_glow.emission_enabled = true
	window_glow.emission = Color("#ff9550")
	window_glow.emission_energy_multiplier = 1.2
	window_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	main.mats["cafe_window_glow"] = window_glow


static func _add_environment(main) -> void:
	# Base; replaced by sunset in Phase 17. Kept minimal so validation passes
	# before that phase lands.
	main._add_environment(Color("#1a1410"), Color("#ffe2b8"), 0.55)


static func _sunset_sky_material(sun_dir: Vector3) -> ShaderMaterial:
	# Directional golden-hour gradient: blue zenith, peach horizon
	# concentrated around the sun azimuth, dusky ground haze below.
	var shader := Shader.new()
	shader.code = """
shader_type sky;
render_mode use_half_res_pass;
uniform vec3 top_color : source_color = vec3(0.42, 0.63, 0.82);
uniform vec3 mid_color : source_color = vec3(0.61, 0.66, 0.77);
uniform vec3 horizon_cool : source_color = vec3(0.72, 0.78, 0.86);
uniform vec3 horizon_warm : source_color = vec3(0.95, 0.69, 0.50);
uniform vec3 sun_glow_color : source_color = vec3(1.0, 0.75, 0.55);
uniform vec3 ground_color : source_color = vec3(0.23, 0.20, 0.22);
uniform float sky_energy = 1.30;
uniform vec3 sun_direction = vec3(-0.95, 0.31, 0.0);
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


static func _build_lighting(main) -> void:
	var world = main.world_root
	# Late golden hour: low western sun, peach horizon near the sun fading
	# to blue elsewhere, dim cool ambient so amber interior pools dominate.
	# Remove (not queue) stale environments and suns immediately: queue_free()
	# is deferred, so the room baker would otherwise snapshot the zombies
	# into the editable scene and ship duplicate skies/suns.
	for env in world.find_children("*", "WorldEnvironment", true, false):
		world.remove_child(env)
		(env as WorldEnvironment).free()
	for old_sun in world.find_children("*", "DirectionalLight3D", true, false):
		world.remove_child(old_sun)
		(old_sun as DirectionalLight3D).free()
	var sunset := WorldEnvironment.new()
	sunset.name = "CafeSunset"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sun_dir := Vector3(-0.95, 0.31, 0.0).normalized()
	var sky := Sky.new()
	sky.sky_material = _sunset_sky_material(sun_dir)
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#8fa3c7")
	environment.ambient_light_energy = 0.17
	environment.ambient_light_sky_contribution = 0.22
	environment.fog_enabled = true
	environment.fog_light_color = Color("#c9a189")
	environment.fog_light_energy = 0.30
	environment.fog_density = 0.0026
	environment.fog_sky_affect = 0.30
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.68
	environment.glow_enabled = true
	environment.glow_intensity = 0.04
	environment.glow_bloom = 0.02
	environment.glow_strength = 0.80
	world.add_child(sunset)
	sunset.environment = environment
	var sun := DirectionalLight3D.new()
	sun.name = "CafeSun"
	# ~18 degrees above the western horizon: long eastward shadows.
	sun.rotation_degrees = Vector3(-18, -90, 0)
	sun.light_color = Color("#ffc28f")
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.45
	sun.directional_shadow_max_distance = 80.0
	world.add_child(sun)
	# Warm-edged stylized clouds (~20-35% coverage), same sparse layout.
	preload("res://scripts/world/sky_clouds.gd").build(world, 10, Vector3(60.0, 22.0, 55.0), 0.42, Color(1.0, 0.93, 0.86, 1.0))
	# Warm interior base pools (restrained so pendant/counter/lounge pools
	# below read as distinct warm zones instead of one flat wash).
	for spec in [
		[Vector3(0, 3.0, 8.5), 0.55, 4.5],
		[Vector3(-8.0, 7.2, -7.0), 0.55, 4.5],
		[Vector3(0, 7.2, -7.0), 0.70, 5.0],
		[Vector3(-9.0, 2.5, 6.2), 0.70, 5.0],
	]:
		_warm_pool(main, spec[0], spec[1], spec[2])


static func _warm_pool(main, pos: Vector3, energy: float, light_range: float) -> void:
	var lamp := OmniLight3D.new()
	lamp.position = pos
	lamp.light_color = Color("#ffc27a")
	lamp.light_energy = energy
	lamp.omni_range = light_range
	lamp.shadow_enabled = false
	main.world_root.add_child(lamp)


# Pendant fixture: cord + dark shade + emissive bulb. Purely visual; any
# real light comes from a shared _warm_pool so three pendants cost one light.
static func _pendant(main, pos: Vector3, hang_top: float) -> void:
	var world = main.world_root
	var metal_mat: Material = main.mats["cafe_metal"]
	var shade_y := pos.y
	main._box(world, Vector3(0.06, hang_top - shade_y, 0.06), Vector3(pos.x, (hang_top + shade_y) * 0.5, pos.z), metal_mat)
	main._cylinder(world, 0.30, 0.24, Vector3(pos.x, shade_y + 0.12, pos.z), metal_mat, 16)
	main._sphere(world, Vector3(0.20, 0.16, 0.20), Vector3(pos.x, shade_y - 0.02, pos.z), main.mats["cafe_lamp_glow"], 16, 12)


static func _build_ground_floor(main) -> void:
	var world = main.world_root
	# Warm dark wood dining floor, top at y=0.
	main._box(world, Vector3(32.0, 0.12, 24.0), Vector3(0, -0.06, 0), main.mats.cafe_floor)
	# Kitchen tile zone (x -8..11, z -11..-6), slightly proud for a clear
	# material transition. Checkerboard comes with Phase 9 dressing.
	main._box(world, Vector3(19.0, 0.14, 5.0), Vector3(1.5, -0.06, -8.5), main.mats.cafe_tile)


static func _wall_with_collision(main, center: Vector3, size: Vector3) -> void:
	main._box(main.world_root, size, center, main.mats.cafe_taupe)
	main._add_blocker(center, size, 0.0)


# Unified exterior top height: every main wall segment caps at WALL_H (7.2).
# Darkwood cap strips give one clean beam line around N/E/W; the south
# cutaway (deliberate 3 m camera element) gets its own continuous beam.
static func _wall_cap(main, center: Vector3, size: Vector3) -> void:
	main._box(main.world_root, size, center, main.mats.cafe_darkwood)


static func _build_walls(main) -> void:
	var h := WALL_H
	var t := WALL_T
	var cy := h * 0.5
	# SOUTH (entrance) wall is a 3.0 m cutaway so the exploration camera
	# outside it can frame the spawn without the wall filling the view.
	# Now it is glazed flanking the doorway, matching the west visual language.
	_wall_with_collision(main, Vector3(-8.6, 0.5, 12.0), Vector3(14.8, 1.0, t))
	_wall_with_collision(main, Vector3(8.6, 0.5, 12.0), Vector3(14.8, 1.0, t))
	main._box(main.world_root, Vector3(0.24, 3.0, 0.5), Vector3(-1.32, 1.5, 12.0), main.mats.cafe_darkwood)
	main._box(main.world_root, Vector3(0.24, 3.0, 0.5), Vector3(1.32, 1.5, 12.0), main.mats.cafe_darkwood)
	main._box(main.world_root, Vector3(2.9, 0.24, 0.5), Vector3(0, 3.0, 12.0), main.mats.cafe_darkwood)
	# Continuous south top beam: every glass head (y=3.0) terminates into it.
	_wall_cap(main, Vector3(-8.6, 3.06, 12.0), Vector3(14.8, 0.24, 0.5))
	_wall_cap(main, Vector3(8.6, 3.06, 12.0), Vector3(14.8, 0.24, 0.5))
	# South glazing – 3 m tall cutaway: sill 0-1 m, glass 1-3 m (2 m tall).
	# Posts every ~3 m, 4 panes per side (8 total), style matches west.
	# Panes/posts span exactly 1.0..3.0 so glass meets sill below and the
	# top beam above with no floating edges.
	for x in [-14.5, -11.5, -8.5, -5.5, -2.5]:
		_wall_with_collision(main, Vector3(x, 2.0, 12.0), Vector3(0.28, 2.0, t))
	for x in [2.5, 5.5, 8.5, 11.5, 14.5]:
		_wall_with_collision(main, Vector3(x, 2.0, 12.0), Vector3(0.28, 2.0, t))
	for x in [-13.0, -10.0, -7.0, -4.0]:
		main._box(main.world_root, Vector3(2.72, 2.0, 0.08), Vector3(x, 2.0, 12.0), main.mats.glass)
	for x in [4.0, 7.0, 10.0, 13.0]:
		main._box(main.world_root, Vector3(2.72, 2.0, 0.08), Vector3(x, 2.0, 12.0), main.mats.glass)
	# Thin fill strips between outer posts / door frame so no brown voids remain.
	_wall_with_collision(main, Vector3(-1.9, 2.0, 12.0), Vector3(0.7, 2.0, t))
	_wall_with_collision(main, Vector3(1.9, 2.0, 12.0), Vector3(0.7, 2.0, t))
	# Invisible doorway blocker (no outside to walk to).
	main._add_blocker(Vector3(0, 1.5, 12.0), Vector3(2.4, 3.0, 0.4), 0.0)
	# WEST window wall: sill band (top 1.0), header band (5.2..7.2),
	# posts every 3 m spanning exactly 1.0..5.2, panes filling post gaps.
	_wall_with_collision(main, Vector3(-16.0, 0.5, 0.0), Vector3(t, 1.0, 24.0))
	_wall_with_collision(main, Vector3(-16.0, 6.2, 0.0), Vector3(t, 2.0, 24.0))
	_wall_cap(main, Vector3(-16.0, 7.29, 0.0), Vector3(0.5, 0.18, 24.4))
	for i in range(9):
		var z := -12.0 + float(i) * 3.0
		_wall_with_collision(main, Vector3(-16.0, 3.1, z), Vector3(t, 4.2, 0.3))
	# Glass panes between posts (8 panels, 2.7 wide x 4.2 tall, exact fit).
	for i in 8:
		var z := -10.5 + float(i) * 3.0
		main._box(main.world_root, Vector3(0.08, 4.2, 2.7), Vector3(-16.0, 3.1, z), main.mats.glass)
	# EAST window wall – glazed like west, EXCEPT the stair zone (z -3.5..6.5)
	# which is structural wall so glass/rail/steps never share one volume.
	# SOUTH→NORTH: glass (7.5, 10.5) | stair wall (-1.5, 1.5, 4.5) | glass (-10.5, -7.5, -4.5).
	_wall_with_collision(main, Vector3(16.0, 0.5, 0.0), Vector3(t, 1.0, 24.0))
	_wall_with_collision(main, Vector3(16.0, 6.2, 0.0), Vector3(t, 2.0, 24.0))
	_wall_cap(main, Vector3(16.0, 7.29, 0.0), Vector3(0.5, 0.18, 24.4))
	for i in range(9):
		var z := -12.0 + float(i) * 3.0
		_wall_with_collision(main, Vector3(16.0, 3.1, z), Vector3(t, 4.2, 0.3))
	for i in 8:
		var z := -10.5 + float(i) * 3.0
		if z > -3.0 and z < 6.0:
			# Stair-zone structural infill between sill band and header band.
			_wall_with_collision(main, Vector3(16.0, 3.1, z), Vector3(t, 4.2, 2.7))
		else:
			main._box(main.world_root, Vector3(0.08, 4.2, 2.7), Vector3(16.0, 3.1, z), main.mats.glass)
	# NORTH (back) wall: solid below (top 4.0) + window band 4.0..6.2 +
	# header 6.2..7.2. Posts and panes span exactly 4.0..6.2 so no span
	# floats above the solid section; cap unifies the 7.2 top line.
	_wall_with_collision(main, Vector3(0, 2.0, -12.0), Vector3(32.0, 4.0, t))
	_wall_with_collision(main, Vector3(0, 6.7, -12.0), Vector3(32.0, 1.0, t))
	_wall_cap(main, Vector3(0, 7.29, -12.0), Vector3(32.4, 0.18, 0.5))
	for i in 7:
		var x := -12.0 + float(i) * 4.0
		_wall_with_collision(main, Vector3(x, 5.1, -12.0), Vector3(0.3, 2.2, t))
	for i in 6:
		var x := -10.0 + float(i) * 4.0
		main._box(main.world_root, Vector3(3.7, 2.2, 0.08), Vector3(x, 5.1, -11.8), main.mats.glass)


static func _slab_with_collision(main, center: Vector3, size: Vector3) -> StaticBody3D:
	main._box(main.world_root, size, center, main.mats.cafe_floor)
	var body := StaticBody3D.new()
	main.world_root.add_child(body)
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	return body


static func _build_mezzanine(main) -> void:
	# Glass-panel + dark-metal-beam floor (x -15..15, z -11..-3.5).
	# Walking top stays y=4.8 so every upstairs anchor is unchanged.
	_build_glass_floor(main)
	# Support posts at the open edge corners (visual + blockers).
	for x in [-14.5, 14.5]:
		for z in [-10.5, -4.0]:
			main._box(main.world_root, Vector3(0.4, MEZZ_TOP, 0.4), Vector3(x, MEZZ_TOP * 0.5, z), main.mats.cafe_darkwood)
			main._add_blocker(Vector3(x, MEZZ_TOP * 0.5, z), Vector3(0.5, MEZZ_TOP, 0.5), 0.0)
	# Balcony railing along z=-3.5 from x=-13 to +11 (stair landing breaks it
	# at the east end). Blackened gunmetal rails + balusters with one
	# collision strip; support posts below stay darkwood.
	var z := MEZZ_Z_EDGE
	var metal_mat: Material = main.mats["cafe_metal"]
	main._box(main.world_root, Vector3(24.0, 0.12, 0.12), Vector3(-1.0, MEZZ_TOP + 1.1, z), metal_mat)
	main._box(main.world_root, Vector3(24.0, 0.09, 0.09), Vector3(-1.0, MEZZ_TOP + 0.55, z), metal_mat)
	var x := -13.0
	while x <= 11.0:
		main._box(main.world_root, Vector3(0.09, 1.1, 0.09), Vector3(x, MEZZ_TOP + 0.55, z), metal_mat)
		x += 0.75
	main._add_blocker(Vector3(-1.0, MEZZ_TOP + 0.55, z), Vector3(24.0, 1.1, 0.2), 0.0)


static func _build_glass_floor(main) -> void:
	# Reference-style grid: 10 x 2 large transparent panels (3.0 x 3.75)
	# carried by perimeter + longitudinal + cross gunmetal beams.
	# Tops flush at MEZZ_TOP (4.8); one invisible box gives smooth walking.
	var x0 := -15.0
	var x1 := 15.0
	var z0 := -11.0
	var z1 := -3.5
	var cols := 10
	var rows := 2
	var world = main.world_root
	var glass_mat: Material = main.mats["cafe_glass_floor"]
	var metal_mat: Material = main.mats["cafe_metal"]
	var pw := (x1 - x0) / float(cols)
	var pd := (z1 - z0) / float(rows)
	var beam_w := 0.14
	var glass_t := 0.06
	for c in cols:
		for r in rows:
			var cx := x0 + (float(c) + 0.5) * pw
			var cz := z0 + (float(r) + 0.5) * pd
			var panel: MeshInstance3D = main._box(world, Vector3(pw - beam_w, glass_t, pd - beam_w), Vector3(cx, MEZZ_TOP - glass_t * 0.5, cz), glass_mat)
			panel.set_meta("xray_exclude", true)
			panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var beam_h := 0.18
	var beam_y := MEZZ_TOP - beam_h * 0.5
	for zi in [z0, (z0 + z1) * 0.5, z1]:
		main._box(world, Vector3(x1 - x0, beam_h, beam_w), Vector3((x0 + x1) * 0.5, beam_y, zi), metal_mat)
	for ci in cols + 1:
		var bx := x0 + float(ci) * pw
		main._box(world, Vector3(beam_w, beam_h, z1 - z0), Vector3(bx, beam_y, (z0 + z1) * 0.5), metal_mat)
	var body := StaticBody3D.new()
	world.add_child(body)
	body.position = Vector3((x0 + x1) * 0.5, MEZZ_TOP - 0.1, (z0 + z1) * 0.5)
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(x1 - x0, 0.2, z1 - z0)
	shape.shape = box
	body.add_child(shape)


static func _build_stairs(main) -> void:
	# East wall run: corrected to be clearly readable, well-connected, and
	# not embedded. Centered at x=13.6 (was 13.0) to give the ground lounge
	# couch a half-metre gap, width 2.2 for comfort, 16 steps, landings both
	# ends, invisible ramp for CharacterBody climbing.
	var steps := 16
	var rise := MEZZ_TOP / float(steps)
	var x := 13.6
	var stair_width := 2.2
	var half_w := stair_width * 0.5
	var z0 := 6.0
	var run := 9.5
	var tread := run / float(steps)
	var body := StaticBody3D.new()
	main.world_root.add_child(body)
	body.position = Vector3.ZERO
	body.collision_layer = 1
	body.collision_mask = 0
	for i in steps:
		var top_y := rise * float(i + 1)
		var z := z0 - tread * (float(i) + 0.5)
		main._box(main.world_root, Vector3(stair_width, 0.28, tread + 0.04), Vector3(x, top_y - 0.14, z), main.mats.cafe_floor)
	# Landing pads – remove the floating/embedded feel at both ends.
	main._box(main.world_root, Vector3(stair_width + 0.2, 0.12, 1.0), Vector3(x, 0.06, z0 + 0.6), main.mats.cafe_floor)
	main._box(main.world_root, Vector3(stair_width + 0.2, 0.12, 1.0), Vector3(x, MEZZ_TOP - 0.06, MEZZ_Z_EDGE + 0.5), main.mats.cafe_floor)
	# CharacterBody3D cannot mount vertical step faces, so one invisible
	# climbable ramp carries the player; the visible steps stay decorative.
	# Slope ~27 degrees, under the controller's 46-degree floor limit.
	# Span z -3.7..7.5: the tip lands flush with the glass top (4.8) just
	# inside the glass edge (no lip at the stair exit) while the south end
	# dives deep below the ground floor (no catchable corner at entry).
	var ramp_shape := CollisionShape3D.new()
	var ramp_box := BoxShape3D.new()
	ramp_box.size = Vector3(stair_width - 0.15, 0.18, 12.55)
	ramp_shape.shape = ramp_box
	# Centered on the slope line (surface y 1.98 at z 1.9).
	ramp_shape.position = Vector3(x, 1.98, 1.9)
	ramp_shape.rotation.x = atan2(MEZZ_TOP, run)
	body.add_child(ramp_shape)
	# Stringer boards + open-side (west) railing with sloped handrail.
	# Both must use the SAME +atan2 sign as the invisible climb ramp above:
	# stairs ascend toward -Z (z 6.0 -> -3.5), so rotation.x = +atan tips the
	# +Z (south) end down and the -Z (north) end up, parallel to the incline.
	var slope := atan2(MEZZ_TOP, run)
	for sx in [x - half_w - 0.09, x + half_w + 0.09]:
		var stringer: MeshInstance3D = main._box(main.world_root, Vector3(0.18, 0.9, 10.0), Vector3(sx, 1.75, 1.25), main.mats.cafe_darkwood)
		stringer.rotation.x = slope
	var rail_x := x - half_w - 0.09
	var rail: MeshInstance3D = main._box(main.world_root, Vector3(0.12, 0.12, 10.8), Vector3(rail_x, 3.35, 1.45), main.mats["cafe_metal"])
	rail.rotation.x = slope
	for i in 7:
		var t := float(i) / 6.0
		main._box(main.world_root, Vector3(0.09, 1.0, 0.09), Vector3(rail_x, t * MEZZ_TOP + 0.5, lerpf(6.0, -3.5, t)), main.mats["cafe_metal"])
	# Invisible sloped guards flanking the HIGH half of the climb (visual
	# stringers/rail carry no collision): they stop lateral falls where a
	# drop would be ugly, but end at z=1.0 so the south walkway stays open
	# and both stair ends remain freely enterable.
	var guard_z := -1.425
	var guard_y := (MEZZ_TOP * 0.5 - 0.08) + (1.25 - guard_z) * (MEZZ_TOP / run) + 0.45
	for gx in [x - half_w - 0.18, x + half_w + 0.18]:
		var guard := StaticBody3D.new()
		main.world_root.add_child(guard)
		guard.position = Vector3(gx, guard_y, guard_z)
		guard.rotation.x = slope
		guard.collision_layer = 1
		guard.collision_mask = 0
		var guard_cs := CollisionShape3D.new()
		var guard_box := BoxShape3D.new()
		guard_box.size = Vector3(0.12, 1.0, 4.85)
		guard_cs.shape = guard_box
		guard.add_child(guard_cs)
	# Top landing short rail to close the balcony gap (east end)
	main._box(main.world_root, Vector3(0.09, 1.1, 0.09), Vector3(rail_x, MEZZ_TOP + 0.55, MEZZ_Z_EDGE), main.mats["cafe_metal"])


# ---------------------------------------------------------------------------
# Ground floor furniture (Phase 7) + counter/kitchen (Phase 9).
# Every seat below is a real StudySpot; orientations verified in screenshots.
# ---------------------------------------------------------------------------

static func _seat(main, pos: Vector3, face_dir: Vector3, study_type: String, seat_height: float, stand_dist: float, seat_type: String, prefix: String, n: int):
	var spot = main._register_furniture_seat(pos, _furniture_yaw_for(face_dir), study_type, seat_height, 0.35, stand_dist, seat_type)
	_name_spot(main, spot, prefix, n)
	return spot


static func _prop(main, relative_path: String, pos: Vector3, yaw := 0.0, scale_value := Vector3.ONE) -> Node3D:
	return _place(main, relative_path, pos, yaw, scale_value)


static func _chair(main, model: String, pos: Vector3, face_dir: Vector3, study_type: String, seat_height: float, stand_dist: float, seat_type: String, prefix: String, n: int) -> void:
	var yaw := _furniture_yaw_for(face_dir)
	_place(main, model, pos, yaw)
	# Tight chair-body collision (0.7 footprint): the player can walk
	# between chairs but not through them. Stand anchors (1.1+ away) stay
	# reachable outside this box.
	main._add_blocker(pos + Vector3(0, 0.6, 0), Vector3(0.7, 1.2, 0.7), yaw)
	_seat(main, pos, face_dir, study_type, seat_height, stand_dist, seat_type, prefix, n)


static func _build_ground_furniture(main) -> void:
	var n := 0
	# Entrance: decorated shelf west (clear of round-B stand anchors),
	# cactus east.
	_place(main, "furniture_bits/Assets/gltf/shelf_B_large_decorated.gltf", Vector3(-4.6, 0, 9.0), PI * 0.5)
	main._add_blocker(Vector3(-4.6, 0.5, 9.0), Vector3(0.6, 1.0, 2.0), 0.0)
	_place(main, "furniture_bits/Assets/gltf/cactus_medium_A.gltf", Vector3(4.0, 0, 9.0), 0.0)
	# West window bar: 4 long tables end-to-end (z -6..6) + 5 stools facing -X.
	for i in 4:
		var z := -4.5 + float(i) * 3.0
		_place(main, "furniture_bits/Assets/gltf/table_medium_long.gltf", Vector3(-14.0, 0, z), PI * 0.5)
		main._add_blocker(Vector3(-14.0, 0.5, z), Vector3(2.0, 1.0, 3.0), 0.0)
	for i in 5:
		var z := -5.0 + float(i) * 2.5
		n += 1
		_chair(main, "furniture_bits/Assets/gltf/chair_stool_wood.gltf", Vector3(-12.4, 0, z), Vector3(-1, 0, 0), "Laptop" if i % 2 == 0 else "Book", 0.35, 1.1, "cafe_chair", "G", n)
	# Window counter props: 2 laptop stations + 2 mug stations + 1 empty.
	# Tabletop y=1.0; laptop base +0.07, mug base +0.04 (measured FBX bounds).
	_prop(main, "Low Poly Furniture/Electronics/Laptop.fbx", Vector3(-14.0, 1.07, -3.0), PI * 0.5, Vector3.ONE * LAPTOP_SCALE)
	_prop(main, "Low Poly Furniture/Electronics/Laptop.fbx", Vector3(-14.0, 1.07, 2.0), PI * 0.5, Vector3.ONE * LAPTOP_SCALE)
	_prop(main, "Low Poly Furniture/Miscellaneous/Mug.fbx", Vector3(-14.0, 1.04, -0.5), 0.0, Vector3.ONE * MUG_SCALE)
	_prop(main, "Low Poly Furniture/Miscellaneous/Mug.fbx", Vector3(-14.0, 1.04, 3.5), 0.0, Vector3.ONE * MUG_SCALE)
	# Communal table (-3.5, 1.0) with 6 wood chairs, 3 per long side.
	_place(main, "furniture_bits/Assets/gltf/table_medium_long.gltf", Vector3(-3.5, 0, 1.0), 0.0)
	main._add_blocker(Vector3(-3.5, 0.5, 1.0), Vector3(3.0, 1.0, 2.0), 0.0)
	for i in 3:
		var x := -4.5 + float(i) * 1.2
		n += 1
		_chair(main, "furniture_bits/Assets/gltf/chair_A_wood.gltf", Vector3(x, 0, -0.5), Vector3(0, 0, 1), "Laptop", 0.3, 1.25, "cafe_chair", "G", n)
		n += 1
		_chair(main, "furniture_bits/Assets/gltf/chair_A_wood.gltf", Vector3(x, 0, 2.5), Vector3(0, 0, -1), "Book", 0.3, 1.25, "cafe_chair", "G", n)
	_prop(main, "Low Poly Furniture/Electronics/Laptop.fbx", Vector3(-3.5, 1.07, 0.7), 0.0, Vector3.ONE * LAPTOP_SCALE)
	_prop(main, "Low Poly Furniture/Miscellaneous/Mug.fbx", Vector3(-2.6, 1.04, 1.3), 0.0, Vector3.ONE * MUG_SCALE)
	_prop(main, "Low Poly Furniture/Miscellaneous/Mug.fbx", Vector3(-4.7, 1.04, 0.6), 0.0, Vector3.ONE * MUG_SCALE)
	_prop(main, "furniture_bits/Assets/gltf/book_set.gltf", Vector3(-4.2, 1.25, 1.2), 0.4)
	# Round tables: restrained dressing (tops y=1.0).
	n = _round_table(main, n, Vector3(-9.0, 0, 6.2), 3, "chair_A")
	_prop(main, "Low Poly Furniture/Miscellaneous/Mug.fbx", Vector3(-9.0, 1.04, 6.2), 0.0, Vector3.ONE * MUG_SCALE)
	_prop(main, "furniture_bits/Assets/gltf/book_set.gltf", Vector3(-8.4, 1.25, 6.6), -0.3)
	n = _round_table(main, n, Vector3(-1.0, 0, 6.5), 3, "chair_A")
	_prop(main, "Low Poly Furniture/Electronics/Laptop.fbx", Vector3(-1.0, 1.07, 6.5), 0.2, Vector3.ONE * LAPTOP_SCALE)
	_prop(main, "Low Poly Furniture/Miscellaneous/Mug.fbx", Vector3(-0.3, 1.04, 6.1), 0.0, Vector3.ONE * MUG_SCALE)
	n = _round_table(main, n, Vector3(6.0, 0, 2.5), 2, "chair_A")
	_prop(main, "furniture_bits/Assets/gltf/book_set.gltf", Vector3(6.0, 1.25, 2.5), 0.5)
	_prop(main, "Low Poly Furniture/Miscellaneous/Mug.fbx", Vector3(6.6, 1.04, 2.9), 0.0, Vector3.ONE * MUG_SCALE)
	# East lounge: couch (3 spots) + armchair + low table + rug + lamp + plant.
	_place(main, "furniture_bits/Assets/gltf/rug_oval_A.gltf", Vector3(10.5, 0.02, 6.4), 0.0)
	_place(main, "furniture_bits/Assets/gltf/table_low.gltf", Vector3(10.5, 0, 5.6), 0.0)
	main._add_blocker(Vector3(10.5, 0.25, 5.6), Vector3(2.4, 0.5, 1.5), 0.0)
	_place(main, "furniture_bits/Assets/gltf/couch_pillows.gltf", Vector3(10.5, 0, 7.2), PI)
	main._add_blocker(Vector3(10.5, 0.55, 7.2), Vector3(3.0, 1.1, 1.6), 0.0)
	for i in 3:
		n += 1
		_seat(main, Vector3(9.4 + float(i) * 1.1, 0, 7.2), Vector3(0, 0, -1), "Book", 0.1, 1.4, "armchair", "G", n)
	_place(main, "furniture_bits/Assets/gltf/armchair_pillows.gltf", Vector3(8.0, 0, 6.0), _furniture_yaw_for(Vector3(0.83, 0, -0.21)))
	main._add_blocker(Vector3(8.0, 0.7, 6.0), Vector3(1.3, 1.4, 1.3), PI * 0.75)
	n += 1
	_seat(main, Vector3(8.0, 0, 6.0), Vector3(0.83, 0, -0.21), "Laptop", 0.1, 1.25, "armchair", "G", n)
	_place(main, "furniture_bits/Assets/gltf/lamp_standing.gltf", Vector3(12.5, 0, 8.7), 0.0)
	main._add_blocker(Vector3(12.5, 0.75, 8.7), Vector3(0.6, 1.5, 0.6), 0.0)
	_place(main, "furniture_bits/Assets/gltf/cactus_medium_B.gltf", Vector3(12.3, 0, 4.6), 0.0)
	main._add_blocker(Vector3(12.3, 0.4, 4.6), Vector3(0.5, 0.8, 0.5), 0.0)
	_place(main, "furniture_bits/Assets/gltf/cactus_medium_A.gltf", Vector3(4.0, 0, 9.0), 0.0)
	main._add_blocker(Vector3(4.0, 0.4, 9.0), Vector3(0.5, 0.8, 0.5), 0.0)
	# Lounge low table dressing (top y=0.5): books + mug.
	_prop(main, "furniture_bits/Assets/gltf/book_set.gltf", Vector3(10.2, 0.75, 5.6), 0.3)
	_prop(main, "Low Poly Furniture/Miscellaneous/Mug.fbx", Vector3(10.9, 0.54, 5.8), 0.0, Vector3.ONE * MUG_SCALE)


static func _round_table(main, n: int, center: Vector3, chairs: int, chair_model: String) -> int:
	_place(main, "restaurant_bits/Assets/gltf/table_round_A.gltf", center, 0.0)
	main._add_blocker(center + Vector3(0, 0.5, 0), Vector3(2.6, 1.0, 2.6), 0.0)
	for i in chairs:
		var angle := TAU * float(i) / float(chairs) + 0.5
		var pos := center + Vector3(cos(angle), 0, sin(angle)) * 2.0
		n += 1
		_chair(main, "restaurant_bits/Assets/gltf/" + chair_model + ".gltf", pos, (center - pos).normalized(), "Book" if i % 2 == 1 else "Laptop", 0.3, 1.1, "cafe_chair", "G", n)
	return n


static func _build_counter_and_kitchen(main) -> void:
	# Service counter across z=-4.75, customer side +Z.
	var modules := [
		"restaurant_bits/Assets/gltf/kitchencounter_straight_A.gltf",
		"restaurant_bits/Assets/gltf/kitchencounter_straight_A.gltf",
		"restaurant_bits/Assets/gltf/kitchencounter_straight_A_decorated.gltf",
		"restaurant_bits/Assets/gltf/kitchencounter_straight_A.gltf",
		"restaurant_bits/Assets/gltf/kitchencounter_straight_B.gltf",
	]
	for i in modules.size():
		var x := -5.0 + float(i) * 2.0
		_place(main, modules[i], Vector3(x, 0, -4.75), 0.0)
		main._add_blocker(Vector3(x, 0.5, -4.75), Vector3(2.0, 1.0, 2.0), 0.0)
	_prop(main, "restaurant_bits/Assets/gltf/menu.gltf", Vector3(1.0, 1.0, -4.4), 0.0)
	# North backsplash row facing south into the kitchen.
	_place(main, "restaurant_bits/Assets/gltf/kitchencounter_straight_A_backsplash.gltf", Vector3(-4.5, 0, -9.5), 0.0)
	_place(main, "restaurant_bits/Assets/gltf/kitchencounter_sink_backsplash.gltf", Vector3(-2.5, 0, -9.5), 0.0)
	_place(main, "restaurant_bits/Assets/gltf/kitchencounter_straight_B_backsplash.gltf", Vector3(1.5, 0, -9.5), 0.0)
	for x in [-4.5, -2.5, 1.5]:
		main._add_blocker(Vector3(x, 0.5, -9.5), Vector3(2.0, 1.0, 2.0), 0.0)
	_prop(main, "restaurant_bits/Assets/gltf/dishrack_plates.gltf", Vector3(-2.5, 1.0, -9.5), 0.0)
	# Fridge + stove face south.
	_place(main, "restaurant_bits/Assets/gltf/fridge_A_decorated.gltf", Vector3(8.5, 0, -9.5), 0.0)
	main._add_blocker(Vector3(8.5, 1.0, -9.5), Vector3(2.0, 2.0, 2.2), 0.0)
	_place(main, "restaurant_bits/Assets/gltf/fridge_B.gltf", Vector3(11.0, 0, -9.5), 0.0)
	main._add_blocker(Vector3(11.0, 1.0, -9.5), Vector3(2.0, 2.0, 2.2), 0.0)
	_place(main, "restaurant_bits/Assets/gltf/stove_multi_decorated.gltf", Vector3(4.5, 0, -9.5), 0.0)
	main._add_blocker(Vector3(4.5, 0.5, -9.5), Vector3(2.0, 1.0, 2.0), 0.0)
	# Extractor local span is y 2.0..4.0, so placement y=0 puts the hood
	# mouth just above the stove top (1.72). The old y=2.3 left it floating.
	_place(main, "restaurant_bits/Assets/gltf/extractorhood.gltf", Vector3(4.5, 0, -9.5), 0.0)
	# Prep island + wall cabinets + counter dressing (jars/plates sit on
	# the service counter top y=1.0 with measured base-at-origin bounds).
	_place(main, "restaurant_bits/Assets/gltf/kitchentable_A_large_decorated.gltf", Vector3(1.0, 0, -7.2), 0.0)
	main._add_blocker(Vector3(1.0, 0.5, -7.2), Vector3(3.0, 1.0, 2.0), 0.0)
	_place(main, "furniture_bits/Assets/gltf/cabinet_small_decorated.gltf", Vector3(-6.5, 2.2, -11.4), 0.0)
	_place(main, "furniture_bits/Assets/gltf/cabinet_medium_decorated.gltf", Vector3(6.5, 2.2, -11.4), 0.0)
	_prop(main, "restaurant_bits/Assets/gltf/jar_A_small.gltf", Vector3(-5.5, 1.0, -4.75), 0.2)
	_prop(main, "restaurant_bits/Assets/gltf/jar_A_small.gltf", Vector3(2.6, 1.0, -4.75), -0.3)
	_prop(main, "restaurant_bits/Assets/gltf/plate_small.gltf", Vector3(-0.5, 1.0, -4.4), 0.0)
	_prop(main, "restaurant_bits/Assets/gltf/food_burger.gltf", Vector3(-0.5, 1.1, -4.4), 0.4, Vector3.ONE * 0.5)


# ---------------------------------------------------------------------------
# Second floor, deck y=4.8 (Phase 13). All anchors carry the deck height.
# ---------------------------------------------------------------------------

static func _build_upstairs(main) -> void:
	var deck := 4.8
	var n := 0
	# West quiet study: 2 medium tables (2.0 footprint), opposite chairs.
	for t in [Vector3(-10.0, deck, -7.0), Vector3(-6.0, deck, -7.0)]:
		_place(main, "furniture_bits/Assets/gltf/table_medium.gltf", t, 0.0)
		main._add_blocker(t + Vector3(0, 0.5, 0), Vector3(2.0, 1.0, 2.0), 0.0)
		n += 1
		_chair(main, "furniture_bits/Assets/gltf/chair_A_wood.gltf", t + Vector3(0, 0, -1.5), Vector3(0, 0, 1), "Laptop", 0.3, 1.1, "cafe_chair", "U", n)
		n += 1
		_chair(main, "furniture_bits/Assets/gltf/chair_A_wood.gltf", t + Vector3(0, 0, 1.5), Vector3(0, 0, -1), "Book", 0.3, 1.1, "cafe_chair", "U", n)
	# Bookshelves against the north wall (backs 0.25 off the wall face) +
	# lamp displayed on the west shelf top + plants.
	_place(main, "furniture_bits/Assets/gltf/shelf_B_large_decorated.gltf", Vector3(-10.0, deck, -11.55), 0.0)
	_place(main, "furniture_bits/Assets/gltf/shelf_B_large_decorated.gltf", Vector3(-6.0, deck, -11.55), 0.0)
	main._add_blocker(Vector3(-10.0, deck + 0.5, -11.55), Vector3(2.0, 1.0, 0.6), 0.0)
	main._add_blocker(Vector3(-6.0, deck + 0.5, -11.55), Vector3(2.0, 1.0, 0.6), 0.0)
	_place(main, "furniture_bits/Assets/gltf/lamp_table.gltf", Vector3(-10.0, deck + 0.72, -11.4), 0.0, Vector3.ONE * 0.55)
	_place(main, "furniture_bits/Assets/gltf/cactus_medium_A.gltf", Vector3(-14.3, deck, -7.5), 0.0)
	main._add_blocker(Vector3(-14.3, deck + 0.4, -7.5), Vector3(0.5, 0.8, 0.5), 0.0)
	_place(main, "furniture_bits/Assets/gltf/cactus_medium_B.gltf", Vector3(-3.5, deck, -10.8), 0.0)
	main._add_blocker(Vector3(-3.5, deck + 0.4, -10.8), Vector3(0.5, 0.8, 0.5), 0.0)
	# Central long table + 4 chairs + study props.
	_place(main, "furniture_bits/Assets/gltf/table_medium_long.gltf", Vector3(0.0, deck, -7.0), 0.0)
	main._add_blocker(Vector3(0.0, deck + 0.5, -7.0), Vector3(3.0, 1.0, 2.0), 0.0)
	for i in 2:
		var x := -0.75 + float(i) * 1.5
		n += 1
		_chair(main, "furniture_bits/Assets/gltf/chair_A_wood.gltf", Vector3(x, deck, -8.5), Vector3(0, 0, 1), "Laptop", 0.3, 1.1, "cafe_chair", "U", n)
		n += 1
		_chair(main, "furniture_bits/Assets/gltf/chair_A_wood.gltf", Vector3(x, deck, -5.5), Vector3(0, 0, -1), "Book", 0.3, 1.1, "cafe_chair", "U", n)
	_prop(main, "Low Poly Furniture/Electronics/Laptop.fbx", Vector3(-0.5, deck + 1.07, -7.0), 0.0, Vector3.ONE * LAPTOP_SCALE)
	_prop(main, "Low Poly Furniture/Electronics/Laptop.fbx", Vector3(0.5, deck + 1.07, -7.0), 0.0, Vector3.ONE * LAPTOP_SCALE)
	_prop(main, "Low Poly Furniture/Miscellaneous/Mug.fbx", Vector3(-1.2, deck + 1.04, -7.0), 0.0, Vector3.ONE * MUG_SCALE)
	_prop(main, "furniture_bits/Assets/gltf/book_set.gltf", Vector3(1.2, deck + 1.25, -7.0), 0.3)
	# East lounge: couch (2 spots) + armchair + low table + rug + lamp + plant.
	_place(main, "furniture_bits/Assets/gltf/rug_rectangle_A.gltf", Vector3(9.5, deck + 0.02, -7.4), 0.0)
	_place(main, "furniture_bits/Assets/gltf/table_low.gltf", Vector3(9.5, deck, -6.8), 0.0)
	main._add_blocker(Vector3(9.5, deck + 0.25, -6.8), Vector3(2.4, 0.5, 1.5), 0.0)
	_place(main, "furniture_bits/Assets/gltf/couch_pillows.gltf", Vector3(9.5, deck, -8.4), PI)
	main._add_blocker(Vector3(9.5, deck + 0.55, -8.4), Vector3(3.0, 1.1, 1.6), 0.0)
	for i in 3:
		n += 1
		_seat(main, Vector3(8.55 + float(i) * 0.95, deck, -8.4), Vector3(0, 0, 1), "Book", 0.1, 1.4, "armchair", "U", n)
	_place(main, "furniture_bits/Assets/gltf/armchair_pillows.gltf", Vector3(11.8, deck, -6.6), _furniture_yaw_for(Vector3(-0.7, 0, -0.3)))
	main._add_blocker(Vector3(11.8, deck + 0.7, -6.6), Vector3(1.3, 1.4, 1.3), 0.0)
	n += 1
	_seat(main, Vector3(11.8, deck, -6.6), Vector3(-0.7, 0, -0.3), "Laptop", 0.1, 1.25, "armchair", "U", n)
	_place(main, "furniture_bits/Assets/gltf/lamp_standing.gltf", Vector3(7.2, deck, -8.6), 0.0)
	main._add_blocker(Vector3(7.2, deck + 0.75, -8.6), Vector3(0.6, 1.5, 0.6), 0.0)
	_place(main, "furniture_bits/Assets/gltf/cabinet_medium_decorated.gltf", Vector3(15.0, deck, -8.0), -PI * 0.5)
	main._add_blocker(Vector3(15.0, deck + 0.5, -8.0), Vector3(0.6, 1.0, 2.0), 0.0)
	_place(main, "furniture_bits/Assets/gltf/cactus_medium_A.gltf", Vector3(7.4, deck, -5.4), 0.0)
	main._add_blocker(Vector3(7.4, deck + 0.4, -5.4), Vector3(0.5, 0.8, 0.5), 0.0)
	# Upstairs lounge low table dressing (top deck+0.5).
	_prop(main, "furniture_bits/Assets/gltf/book_set.gltf", Vector3(9.2, deck + 0.75, -6.8), -0.2)
	_prop(main, "Low Poly Furniture/Miscellaneous/Mug.fbx", Vector3(9.9, deck + 0.54, -6.6), 0.0, Vector3.ONE * MUG_SCALE)
	# Desk lamp at the west end of the west study table (top deck+1.0).
	_place(main, "furniture_bits/Assets/gltf/lamp_table.gltf", Vector3(-10.7, deck + 1.0, -7.0), 0.2, Vector3.ONE * 0.55)
	# North window bar (fits clear of the central table): 4 stools face -Z.
	_place(main, "furniture_bits/Assets/gltf/table_medium_long.gltf", Vector3(5.0, deck, -9.6), 0.0)
	main._add_blocker(Vector3(5.0, deck + 0.5, -9.6), Vector3(3.0, 1.0, 2.0), 0.0)
	for i in 4:
		n += 1
		_chair(main, "furniture_bits/Assets/gltf/chair_stool_wood.gltf", Vector3(3.5 + float(i) * 0.95, deck, -8.0), Vector3(0, 0, -1), "Laptop", 0.35, 1.1, "cafe_chair", "U", n)


static func _build_interior_lamps(main) -> void:
	var deck := MEZZ_TOP
	var world = main.world_root
	# Wall-to-wall pendant beams (thin darkwood, y=5.0) south of the glass
	# floor edge: cords have a real structural anchor. (No beam over the
	# counter row – it would slice through upstairs head space; counter
	# pendants hang from the glass grid's own cross beams instead.)
	for bz in [1.0, 6.35]:
		main._box(world, Vector3(32.0, 0.25, 0.25), Vector3(0, 5.0, bz), main.mats.cafe_darkwood)
	# 3 pendants over the communal table sharing one warm pool.
	for x in [-4.5, -3.5, -2.5]:
		_pendant(main, Vector3(x, 3.1, 1.0), 5.0)
	_warm_pool(main, Vector3(-3.5, 2.9, 1.0), 1.00, 6.0)
	# 1 pendant per round-table cluster sharing one pool.
	_pendant(main, Vector3(-9.0, 3.1, 6.2), 5.0)
	_pendant(main, Vector3(-1.0, 3.1, 6.5), 5.0)
	_warm_pool(main, Vector3(-5.0, 2.9, 6.35), 0.80, 5.5)
	# 3 pendants over the service counter hung from the glass-grid cross
	# beams (x=-3/0/3 underside y≈4.62) + warm working pool + task pool.
	for x in [-3.0, 0.0, 3.0]:
		_pendant(main, Vector3(x, 3.0, -4.75), 4.62)
	_warm_pool(main, Vector3(-1.0, 2.7, -4.75), 0.90, 5.0)
	_warm_pool(main, Vector3(0.0, 2.1, -8.2), 0.65, 4.0)
	# Lounge + stair glow: standing lamp exists; pools make them read.
	_warm_pool(main, Vector3(10.5, 2.2, 6.4), 0.70, 4.5)
	_warm_pool(main, Vector3(9.5, 6.9, -7.2), 0.60, 4.0)
	# Table lamps on the window bar + central upstairs table (tops at
	# y=1.0 / deck+1.0; model is 1 m wide at scale 1). The communal table
	# relies on its pendant trio instead (a lamp would crowd the books).
	_place(main, "furniture_bits/Assets/gltf/lamp_table.gltf", Vector3(-14.0, 1.0, 0.5), -0.2, Vector3.ONE * 0.55)
	_place(main, "furniture_bits/Assets/gltf/lamp_table.gltf", Vector3(0.1, deck + 1.0, -7.35), 0.5, Vector3.ONE * 0.55)
	# Standing lamps: entrance corner + upstairs NW corner pocket (out of
	# the balcony walkway) + balcony walk. Lounge lamp is placed below.
	_place(main, "furniture_bits/Assets/gltf/lamp_standing.gltf", Vector3(-7.0, 0, 9.5), 0.0)
	main._add_blocker(Vector3(-7.0, 0.75, 9.5), Vector3(0.6, 1.5, 0.6), 0.0)
	_place(main, "furniture_bits/Assets/gltf/lamp_standing.gltf", Vector3(-13.5, deck, -10.9), 0.0)
	main._add_blocker(Vector3(-13.5, deck + 0.75, -10.9), Vector3(0.6, 1.5, 0.6), 0.0)
	_place(main, "furniture_bits/Assets/gltf/lamp_standing.gltf", Vector3(-1.0, deck, -5.2), PI)
	# Wall sconces: warm emissive shades on the solid north wall (interior
	# face) and one above the east stairwell. Bracket + glowing shade.
	for x in [-8.0, 0.0, 8.0]:
		main._box(world, Vector3(0.12, 0.12, 0.25), Vector3(x, 3.0, -11.7), main.mats.cafe_darkwood)
		main._box(world, Vector3(0.3, 0.22, 0.18), Vector3(x, 3.18, -11.58), main.mats.cafe_lamp_glow)
	main._box(world, Vector3(0.25, 0.12, 0.12), Vector3(15.7, 3.4, 1.25), main.mats.cafe_darkwood)
	main._box(world, Vector3(0.18, 0.22, 0.3), Vector3(15.58, 3.58, 1.25), main.mats.cafe_lamp_glow)
	# Bookshelf accent strips (emissive only) over the upstairs shelves.
	for x in [-10.0, -6.0]:
		main._box(world, Vector3(2.0, 0.06, 0.08), Vector3(x, deck + 0.80, -11.5), main.mats.cafe_lamp_glow)
	# Counter accents: warm emissive candles on the service top (y≈1.0).
	for x in [-4.0, -1.0, 2.0]:
		main._cylinder(world, 0.06, 0.22, Vector3(x, 1.11, -4.75), main.mats.cafe_lamp_glow, 12)
	# Candles on the west window bar between study props (emissive, no light).
	for z in [-1.5, 1.0, 4.2]:
		main._cylinder(world, 0.05, 0.18, Vector3(-14.0, 1.09, z), main.mats.cafe_lamp_glow, 12)
	# Cool north fill so the shaded back façade stays readable in daylight
	# (exterior reads cooler/dimmer than the warm interior by design).
	var north_fill := OmniLight3D.new()
	north_fill.position = Vector3(0, 4.5, -18.0)
	north_fill.light_color = Color("#a8b4e8")
	north_fill.light_energy = 0.25
	north_fill.omni_range = 14.0
	north_fill.shadow_enabled = false
	world.add_child(north_fill)


static func _build_exterior_base(main) -> void:
	# Dark muted ground disc; forest ring lands in Phase 15.
	main._box(main.world_root, Vector3(90.0, 0.5, 70.0), Vector3(0, -0.4, 4.0), main.mats.cafe_ground)
	_build_exterior_nature(main)


static func _nature(main, asset: String, pos: Vector3, yaw := 0.0, scale_value := 1.0) -> Node3D:
	return _place(main, "nature/Assets/gltf/" + asset + ".gltf", pos, yaw, Vector3.ONE * scale_value)


static func _build_exterior_nature(main) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	# Entrance path: x=0 z 12->17 (sidewalk only). The road crossing tile
	# continues the route south; the old path to z=30 would pave over the road.
	var path_mat := StandardMaterial3D.new()
	path_mat.albedo_color = Color("#c9b8a3")
	path_mat.roughness = 0.88
	main._box(main.world_root, Vector3(3.5, 0.08, 5.5), Vector3(0, 0.02, 14.5), path_mat)
	# South entrance landscaping on the plaza (z 12..17) and south verge
	# (z 28+). Nothing planted on the road band (z 17..27).
	_nature(main, "Tree_2_A_Color1", Vector3(-13, 0, 14.5), 0.2, 1.0)
	_nature(main, "Tree_4_B_Color1", Vector3(13, 0, 14.5), -0.3, 1.0)
	_nature(main, "Tree_1_B_Color1", Vector3(-22, 0, 29.5), 0.6, 1.1)
	_nature(main, "Tree_3_C_Color1", Vector3(23, 0, 29.5), -0.5, 1.0)
	for p in [Vector3(-6, 0, 15.5), Vector3(5, 0, 15.8), Vector3(-10, 0, 14.8)]:
		_nature(main, "Bush_1_A_Color1", p, rng.randf_range(0, TAU), rng.randf_range(0.9, 1.2))
		_nature(main, "Bush_1_C_Color1", p + Vector3(0.6, 0, 0.4), rng.randf_range(0, TAU), rng.randf_range(0.9, 1.1))
	_nature(main, "Grass_1_A_Color1", Vector3(-4.5, 0, 15.0), 0.0, 1.0)
	_nature(main, "Grass_2_C_Color1", Vector3(4.5, 0, 15.5), 0.2, 1.0)
	# --- South additional layering: foreground grasses, mid bushes, framing
	_nature(main, "Bush_2_A_Color1", Vector3(-9, 0, 15.5), 0.4, 1.0)
	_nature(main, "Bush_4_B_Color1", Vector3(8, 0, 15.2), -0.6, 1.0)
	_nature(main, "Bush_3_C_Color1", Vector3(-15, 0, 14.8), 0.9, 1.15)
	_nature(main, "Bush_1_D_Color1", Vector3(15, 0, 14.8), -0.4, 1.05)
	_nature(main, "Rock_2_A_Color1", Vector3(-7, 0, 15.0), 0.3, 1.0)
	_nature(main, "Rock_1_D_Color1", Vector3(7, 0, 15.0), -0.2, 1.0)
	_nature(main, "Rock_3_A_Color1", Vector3(-11, 0, 15.2), 0.7, 1.1)
	_nature(main, "Grass_1_B_Color1", Vector3(-3.5, 0, 15.2), 0.3, 1.1)
	_nature(main, "Grass_2_B_Color1", Vector3(3.5, 0, 15.5), -0.2, 1.0)
	_nature(main, "Grass_1_C_Color1", Vector3(-13.5, 0, 15.0), 0.5, 1.0)
	_nature(main, "Grass_2_D_Color1", Vector3(14, 0, 15.5), -0.7, 1.0)
	# West side – foundation planting (x -17..-19.5, clear of road x -30..-20)
	# plus midground BEHIND the west building row (x -44..-48, clear of the
	# x -35..-25 road and the x -28.5/-31.5 traffic lanes by 12 m+).
	# Visible through the window bar as layered depth.
	_nature(main, "Tree_1_A_Color1", Vector3(-18.5, 0, -4), 0.1, 1.0)
	_nature(main, "Tree_2_D_Color1", Vector3(-45, 0, -12), -0.4, 1.0)
	_nature(main, "Tree_3_A_Color1", Vector3(-45, 0, 8), 0.7, 1.0)
	_nature(main, "Tree_4_C_Color1", Vector3(-46, 0, -18), 0.3, 1.0)
	_nature(main, "Tree_2_B_Color1", Vector3(-44, 0, 18), -0.6, 1.0)
	_nature(main, "Bush_1_B_Color1", Vector3(-18, 0, 2), 0.5, 1.0)
	_nature(main, "Bush_2_C_Color1", Vector3(-45, 0, -6), -0.8, 1.0)
	_nature(main, "Bush_4_E_Color1", Vector3(-45, 0, 10), 0.9, 1.0)
	_nature(main, "Rock_1_C_Color1", Vector3(-44, 0, 0), 0.2, 1.0)
	_nature(main, "Rock_2_F_Color1", Vector3(-44, 0, -10), -0.3, 1.0)
	# West additional – layered depth: foreground shrubs + mid trees + rock/grass bits
	_nature(main, "Tree_1_B_Color1", Vector3(-18.5, 0, 3), 0.3, 0.92)
	_nature(main, "Tree_3_B_Color1", Vector3(-45, 0, -8), -0.2, 1.05)
	_nature(main, "Tree_4_B_Color1", Vector3(-46, 0, 14), 0.6, 1.0)
	_nature(main, "Tree_2_C_Color1", Vector3(-48, 0, 4), -0.5, 1.12)
	_nature(main, "Tree_1_C_Color1", Vector3(-45, 0, -14), 0.4, 0.98)
	_nature(main, "Bush_1_A_Color1", Vector3(-18, 0, -2), 0.2, 1.1)
	_nature(main, "Bush_2_D_Color1", Vector3(-18.5, 0, 5.5), -0.3, 1.0)
	_nature(main, "Bush_3_A_Color1", Vector3(-45, 0, -3), 0.7, 1.12)
	_nature(main, "Bush_4_C_Color1", Vector3(-45, 0, -2), -0.5, 1.0)
	_nature(main, "Bush_1_F_Color1", Vector3(-46, 0, 12), 0.9, 0.95)
	_nature(main, "Rock_1_E_Color1", Vector3(-18.5, 0, -6), 0.4, 1.1)
	_nature(main, "Rock_3_C_Color1", Vector3(-44, 0, -9), -0.6, 1.0)
	_nature(main, "Rock_2_B_Color1", Vector3(-44, 0, 6), 0.2, 0.9)
	_nature(main, "Grass_1_A_Color1", Vector3(-18, 0, -7), 0.1, 1.0)
	_nature(main, "Grass_1_B_Color1", Vector3(-18.5, 0, 7.5), -0.4, 1.05)
	_nature(main, "Grass_2_A_Color1", Vector3(-44, 0, 1), 0.6, 1.0)
	# North side – landscape strip (z -17..-19.5, clear of lane z -30..-20)
	# plus verge beyond the lane. Rear lane + rooftops behind.
	_nature(main, "Tree_1_C_Color1", Vector3(-12, 0, -18.5), 0.3, 1.0)
	_nature(main, "Tree_2_C_Color1", Vector3(-4, 0, -18.5), -0.2, 1.0)
	_nature(main, "Tree_3_B_Color1", Vector3(7, 0, -18.5), 0.4, 1.0)
	_nature(main, "Tree_4_A_Color1", Vector3(18, 0, -18.5), -0.5, 1.0)
	# Rear verge sits BEHIND the north building row (backs at z≈-42):
	# trunks 2 m+ clear of facades, canopies just kiss the rear walls.
	_nature(main, "Tree_2_E_Color1", Vector3(27, 0, -44), 0.6, 1.0)
	_nature(main, "Rock_3_B_Color1", Vector3(-24, 0, -44), 0.1, 1.0)
	_nature(main, "Rock_3_D_Color1", Vector3(-22, 0, -44), -0.4, 1.0)
	_nature(main, "Rock_1_H_Color1", Vector3(-26, 0, -44), 0.8, 1.0)
	# North additional – extend belt + layered foreground/mid
	_nature(main, "Tree_3_C_Color1", Vector3(-18, 0, -18.5), 0.5, 1.02)
	_nature(main, "Tree_1_A_Color1", Vector3(2, 0, -44), -0.3, 1.08)
	_nature(main, "Tree_4_C_Color1", Vector3(11, 0, -18.5), 0.7, 1.0)
	_nature(main, "Tree_2_A_Color1", Vector3(22, 0, -44), -0.6, 1.05)
	_nature(main, "Tree_Bare_1_A_Color1", Vector3(-6, 0, -44), 0.2, 0.98)
	_nature(main, "Bush_1_E_Color1", Vector3(-10, 0, -18.5), 0.3, 1.1)
	_nature(main, "Bush_3_B_Color1", Vector3(4, 0, -18.5), -0.5, 1.0)
	_nature(main, "Bush_4_A_Color1", Vector3(14, 0, -18.5), 0.6, 1.05)
	_nature(main, "Bush_2_C_Color1", Vector3(20, 0, -44), -0.2, 0.95)
	_nature(main, "Rock_2_D_Color1", Vector3(-16, 0, -18.5), 0.5, 1.0)
	_nature(main, "Rock_1_G_Color1", Vector3(4, 0, -44), -0.3, 1.1)
	_nature(main, "Rock_3_E_Color1", Vector3(12, 0, -44), 0.7, 0.9)
	_nature(main, "Grass_1_D_Color1", Vector3(-8, 0, -19), 0.2, 1.0)
	_nature(main, "Grass_2_C_Color1", Vector3(8, 0, -18.5), -0.4, 1.05)
	_nature(main, "Grass_1_C_Color1", Vector3(16, 0, -18.5), 0.6, 1.0)
	# East side – foundation planting (x 17.5..19.5, clear of road x 20..30)
	# plus depth BEHIND the east building row (x 42..46, clear of the
	# x 25..35 road and x 28.5/31.5 traffic lanes by 10 m+).
	# Breathing room kept around stair glass.
	_nature(main, "Tree_2_B_Color1", Vector3(18.5, 0, -5), -0.3, 1.0)
	_nature(main, "Tree_1_A_Color1", Vector3(18.5, 0, 7), 0.5, 1.0)
	_nature(main, "Tree_4_B_Color1", Vector3(43, 0, -16), -0.2, 1.0)
	_nature(main, "Tree_3_C_Color1", Vector3(44, 0, 20), 0.4, 1.0)
	_nature(main, "Bush_2_A_Color1", Vector3(18.5, 0, 2), 0.0, 1.0)
	_nature(main, "Bush_3_A_Color1", Vector3(44, 0, -10), 0.6, 1.0)
	_nature(main, "Bush_4_C_Color1", Vector3(44, 0, 12), -0.7, 1.0)
	_nature(main, "Rock_2_C_Color1", Vector3(43, 0, 0), 0.2, 1.0)
	_nature(main, "Rock_1_F_Color1", Vector3(44, 0, -8), -0.3, 1.0)
	# East additional – richer depth with foreground shrubs/grasses and mid trees
	_nature(main, "Tree_1_C_Color1", Vector3(18.5, 0, -10), 0.4, 0.95)
	_nature(main, "Tree_2_D_Color1", Vector3(44, 0, -2), -0.4, 1.08)
	_nature(main, "Tree_3_A_Color1", Vector3(42, 0, -4), 0.7, 1.0)
	_nature(main, "Tree_4_A_Color1", Vector3(46, 0, 6), -0.5, 1.1)
	_nature(main, "Tree_2_A_Color1", Vector3(44, 0, 16), 0.3, 1.02)
	_nature(main, "Bush_1_B_Color1", Vector3(18.5, 0, 0), 0.2, 1.05)
	_nature(main, "Bush_2_B_Color1", Vector3(45, 0, 6), -0.3, 1.1)
	_nature(main, "Bush_1_E_Color1", Vector3(44, 0, -6), 0.5, 0.95)
	_nature(main, "Bush_4_D_Color1", Vector3(44, 0, -1), -0.6, 1.0)
	_nature(main, "Bush_3_C_Color1", Vector3(45, 0, 10), 0.8, 1.0)
	_nature(main, "Rock_1_B_Color1", Vector3(18.5, 0, 4), 0.3, 1.1)
	_nature(main, "Rock_3_G_Color1", Vector3(44, 0, -12), -0.5, 1.0)
	_nature(main, "Rock_2_E_Color1", Vector3(43, 0, 3), 0.4, 0.95)
	_nature(main, "Grass_1_A_Color1", Vector3(18.5, 0, -7), 0.1, 1.0)
	_nature(main, "Grass_2_B_Color1", Vector3(45, 0, 9), -0.4, 1.05)
	_nature(main, "Grass_1_D_Color1", Vector3(45, 0, -4), 0.5, 1.0)
	# Perimeter foreground dressing near building foundations – visible in window views
	_nature(main, "Bush_1_C_Color1", Vector3(-17.5, 0, 6), 0.2, 0.9)
	_nature(main, "Bush_3_A_Color1", Vector3(-17.5, 0, -4), -0.3, 0.95)
	_nature(main, "Grass_1_B_Color1", Vector3(-17.2, 0, 2), 0.5, 1.0)
	_nature(main, "Grass_2_A_Color1", Vector3(17.4, 0, 4), -0.2, 1.0)
	_nature(main, "Grass_1_C_Color1", Vector3(17.3, 0, -6), 0.7, 0.95)
	_nature(main, "Bush_2_A_Color1", Vector3(17.6, 0, -10), -0.4, 0.9)
	_nature(main, "Bush_1_A_Color1", Vector3(-6, 0, -13.5), 0.1, 0.85)
	_nature(main, "Bush_4_B_Color1", Vector3(6, 0, -13.5), -0.2, 0.85)
	_nature(main, "Rock_1_A_Color1", Vector3(-18, 0, 11), 0.3, 0.8)
	_nature(main, "Rock_2_A_Color1", Vector3(18.5, 0, 11), -0.3, 0.8)
	# The old distant forest belt is replaced by the city district below:
	# streets, buildings, street trees and pocket greens give upstairs
	# windows real depth instead of an empty ring.
	_build_city_district(main)
	# Far horizon hills behind the skyline to kill the void.
	var hill_mat := StandardMaterial3D.new()
	hill_mat.albedo_color = Color("#2f3e2f")
	hill_mat.roughness = 0.92
	for h in [
		[Vector3(0, -0.6, -52), Vector3(60, 3.5, 18)],
		[Vector3(0, -0.6, 62), Vector3(55, 3.2, 16)],
	]:
		var hill: MeshInstance3D = main._box(main.world_root, h[1], h[0], hill_mat)
		hill.set_meta("xray_exclude", true)


# ---------------------------------------------------------------------------
# City district (KayKit City Builder Bits + Nature). The Café becomes one
# building in a small university-town district: streets, opposite buildings,
# parked cars, streetlights, street trees, pocket greens, distant skyline.
#
# Scale note: KayKit city bits are toy-scale (2 m road tiles, 1.65-3.05 m
# buildings, 0.94 m cars, 0.96 m streetlights) next to true-scale Nature
# trees (4-5 m). Every city asset places at CITY_S (5x) so buildings read
# 10 m wide / 8-15 m tall, cars 4.7 m long, streetlights 4.8 m tall.
#
# The district is VISUAL ONLY: no collision, no scripts, x-ray excluded,
# distant shadows off, static parked cars. Player stays inside the Café via
# the existing world boundaries.
# ---------------------------------------------------------------------------

const CITY_S := 5.0


# Lightweight ambient traffic: one Node3D drives every moving car along
# flat waypoint loops (no physics, no AI). Yaw eases toward each segment.
class CafeTraffic extends Node3D:
	var movers: Array = []

	func add_car(node: Node3D, pts: PackedVector3Array, speed: float, start_i := 1) -> void:
		var a: Vector3 = pts[(start_i - 1 + pts.size()) % pts.size()]
		var b: Vector3 = pts[start_i % pts.size()]
		node.position = a
		node.rotation.y = atan2(b.x - a.x, b.z - a.z)
		# Baked-scene support: the traffic driver itself is rebuilt at load
		# (see editable_main.gd), so each car carries its route. Groups and
		# metadata persist in the .tscn; edited car transforms do not matter
		# because cars snap back onto their routes at runtime.
		node.add_to_group("editable_cafe_traffic", true)
		node.set_meta("traffic_pts", pts)
		node.set_meta("traffic_speed", speed)
		node.set_meta("traffic_start", start_i)
		movers.append({"node": node, "pts": pts, "i": start_i % pts.size(), "speed": speed})

	func _process(delta: float) -> void:
		for m in movers:
			var node: Node3D = m["node"]
			if not is_instance_valid(node):
				continue
			var pts: PackedVector3Array = m["pts"]
			var target: Vector3 = pts[int(m["i"])]
			var to := target - node.position
			to.y = 0.0
			var step: float = float(m["speed"]) * delta
			if to.length() < maxf(1.4, step):
				m["i"] = (int(m["i"]) + 1) % pts.size()
				continue
			var dir := to.normalized()
			node.position += dir * step
			node.rotation.y = lerp_angle(node.rotation.y, atan2(dir.x, dir.z), minf(1.0, delta * 2.5))


static func _block(main, asset: String, pos: Vector3, yaw := 0.0, s := Vector3.ONE, shadows := false) -> Node3D:
	var node := _place(main, "blocks/" + asset + ".gltf", pos, yaw, s)
	node.set_meta("xray_exclude", true)
	if not shadows:
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func _city(main, asset: String, pos: Vector3, yaw := 0.0, s = 5.0, shadows := true) -> Node3D:
	var sv: Vector3 = s if s is Vector3 else Vector3.ONE * float(s)
	var node := _place(main, "city/" + asset + ".gltf", pos, yaw, sv)
	node.set_meta("xray_exclude", true)
	if not shadows:
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func _city_lamp_head(main, lamp_pos: Vector3, yaw: float) -> void:
	# Warm emissive bulb at the streetlight head (arm reaches local -X).
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
	bulb.position = lamp_pos + offset
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bulb.set_meta("xray_exclude", true)
	main.world_root.add_child(bulb)


static func _build_city_district(main) -> void:
	var S := CITY_S
	# --- district ground: 240x240 slab (x±120, z -110..130), top y=-0.18.
	# 3 cm under the café ground top so the overlap never z-fights.
	var city_ground := StandardMaterial3D.new()
	city_ground.albedo_color = Color("#46503f")
	city_ground.roughness = 0.95
	var ground_slab: MeshInstance3D = main._box(main.world_root, Vector3(240.0, 0.5, 240.0), Vector3(0, -0.43, 10.0), city_ground)
	ground_slab.set_meta("xray_exclude", true)
	# --- LAYER 1 roads: 10x10 m tiles, top y=0.05. South road runs
	# east-west (yaw PI/2); west/east roads and north lane complete the block.
	# South road x -45..45, crossing aligned with the café entrance (x=0).
	# Terminated vistas: closing buildings at (±50, 22) end the view
	# down the street instead of a raw tile edge.
	for xi in [-40, -30, -20, -10, 0, 10, 20, 30, 40]:
		if xi == 0:
			_city(main, "road_straight_crossing", Vector3(xi, -0.45, 22), PI * 0.5)
		else:
			_city(main, "road_straight", Vector3(xi, -0.45, 22), PI * 0.5)
	_city(main, "building_D", Vector3(-50, -0.2, 22), PI * 0.5)
	_city(main, "building_F", Vector3(50, -0.2, 22), -PI * 0.5)
	# West road x=-30 (z -25..15) and east road x=30, running north-south.
	for zi in [-20, -10, 0, 10]:
		_city(main, "road_straight", Vector3(-30, -0.45, zi), 0.0)
		_city(main, "road_straight", Vector3(30, -0.45, zi), 0.0)
	# North lane z=-25 (x -25..25), running east-west.
	for xi in [-20, -10, 0, 10, 20]:
		_city(main, "road_straight", Vector3(xi, -0.45, -25), PI * 0.5)
	# T-junctions where side streets meet the south road and north lane.
	_city(main, "road_tsplit", Vector3(-30, -0.45, 22), 0.0)
	_city(main, "road_tsplit", Vector3(30, -0.45, 22), PI)
	_city(main, "road_tsplit", Vector3(-30, -0.45, -25), PI)
	_city(main, "road_tsplit", Vector3(30, -0.45, -25), 0.0)
	# --- LAYER 2 ring roads: outer EW streets (z=52 / -55) and NS streets
	# (x=±60), junctions where stubs meet them, corners closing the ring.
	# 2 m grass seams at corner joints read as corner lots (planted below).
	for xi in [-50, -40, -20, -10, 0, 10, 20, 40, 50]:
		_city(main, "road_straight", Vector3(xi, -0.45, 52), PI * 0.5)
		_city(main, "road_straight", Vector3(xi, -0.45, -55), PI * 0.5)
	for xi in [-30, 30]:
		_city(main, "road_junction", Vector3(xi, -0.45, 52), 0.0)
		_city(main, "road_junction", Vector3(xi, -0.45, -55), 0.0)
	for zi in [-40, -30, -20, -10, 0, 10, 20, 30, 40]:
		_city(main, "road_straight", Vector3(-60, -0.45, zi), 0.0)
		_city(main, "road_straight", Vector3(60, -0.45, zi), 0.0)
	_city(main, "road_corner", Vector3(-60, -0.45, 52), 0.0)
	_city(main, "road_corner", Vector3(60, -0.45, 52), -PI * 0.5)
	_city(main, "road_corner", Vector3(-60, -0.45, -55), PI * 0.5)
	_city(main, "road_corner", Vector3(60, -0.45, -55), PI)
	# Stub streets linking the inner block to the ring (x=±30).
	for zi in [30, 40]:
		_city(main, "road_straight", Vector3(-30, -0.45, zi), 0.0)
		_city(main, "road_straight", Vector3(30, -0.45, zi), 0.0)
	for zi in [-35, -45]:
		_city(main, "road_straight", Vector3(-30, -0.45, zi), 0.0)
		_city(main, "road_straight", Vector3(30, -0.45, zi), 0.0)
	# --- sidewalks (base slabs, 0.2 thick, top y=0.05). Strips touch road
	# edges exactly; gap fillers bridge the side streets as raised pavement.
	for xi in [-15, -5, 5, 15]:
		_city(main, "base", Vector3(xi, -0.15, 14.5), 0.0, Vector3(5, 2, 2.5))
		_city(main, "base", Vector3(xi, -0.15, -19.0), 0.0, Vector3(5, 2, 2.5))
	for zi in [-15, -5, 5, 15]:
		_city(main, "base", Vector3(-19, -0.15, zi), 0.0, Vector3(2.5, 2, 5))
		_city(main, "base", Vector3(19, -0.15, zi), 0.0, Vector3(2.5, 2, 5))
	_city(main, "base", Vector3(-30, -0.15, 16), 0.0, Vector3(5, 2, 1.0))
	_city(main, "base", Vector3(30, -0.15, 16), 0.0, Vector3(5, 2, 1.0))
	# --- south building row (z 31..42), facing the street (yaw PI).
	_city(main, "building_B", Vector3(-30, -0.2, 36), PI)
	_city(main, "building_F", Vector3(-18, -0.2, 36), PI)
	_city(main, "building_A", Vector3(-6, -0.2, 36), PI)
	_city(main, "building_D", Vector3(8, -0.2, 37), PI)
	_city(main, "building_H", Vector3(22, -0.2, 36), PI)
	# --- west row (x -33..-43), facing east (yaw PI/2), slight setbacks.
	_city(main, "building_C", Vector3(-38, -0.2, -14), PI * 0.5)
	_city(main, "building_G", Vector3(-36.5, -0.2, -2), PI * 0.5)
	_city(main, "building_B", Vector3(-38, -0.2, 10), PI * 0.5)
	_city(main, "building_E", Vector3(-37, -0.2, -24), PI * 0.5)
	# --- east row (x 32..42), facing west (yaw -PI/2).
	_city(main, "building_A", Vector3(37, -0.2, -10), -PI * 0.5)
	_city(main, "building_D", Vector3(35.5, -0.2, 4), -PI * 0.5)
	_city(main, "building_F", Vector3(37, -0.2, 18), -PI * 0.5)
	# --- north row (z -32..-42), facing south (yaw 0).
	_city(main, "building_E", Vector3(-24, -0.2, -37), 0.0)
	_city(main, "building_C", Vector3(-12, -0.2, -36), 0.0)
	_city(main, "building_H", Vector3(2, -0.2, -37), 0.0)
	_city(main, "building_G", Vector3(14, -0.2, -36), 0.0)
	# Sunset lit windows: restrained amber quads on street-facing upper
	# floors (~20-30% of near-row windows). Thin boxes hug the facades.
	for wpos in [
		Vector3(-32.2, 4.5, 30.9), Vector3(-27.8, 4.5, 30.9),
		Vector3(-20.2, 4.5, 30.9), Vector3(-15.8, 4.5, 30.9),
		Vector3(-8.2, 4.5, 30.9), Vector3(-3.8, 4.5, 30.9),
		Vector3(5.8, 4.5, 31.9), Vector3(10.2, 4.5, 31.9),
		Vector3(19.8, 4.5, 30.9), Vector3(24.2, 4.5, 30.9),
	]:
		main._box(main.world_root, Vector3(0.9, 1.2, 0.08), wpos, main.mats["cafe_window_glow"])
	for wpos in [
		Vector3(-32.9, 4.5, -16.0), Vector3(-32.9, 4.5, -12.0),
		Vector3(-31.4, 4.5, -4.0), Vector3(-31.4, 4.5, 0.0),
		Vector3(-32.9, 4.5, 8.0), Vector3(-32.9, 4.5, 12.0),
	]:
		main._box(main.world_root, Vector3(0.08, 1.2, 0.9), wpos, main.mats["cafe_window_glow"])
	# --- LAYER 3 far skyline (75-105 out, no shadows, silhouettes only).
	# The previous 45-60 ring moved outward to clear the L2 ring roads.
	_city(main, "building_G", Vector3(-30, -0.2, 82), PI, 6.0, false)
	_city(main, "building_E_withoutBase", Vector3(15, -0.7, 86), PI, S, false)
	_city(main, "building_C", Vector3(85, -0.2, -15), PI * 0.5, S, false)
	_city(main, "building_F", Vector3(90, -0.2, 28), 0.0, S, false)
	_city(main, "building_A", Vector3(60, -0.2, 82), PI, S, false)
	_city(main, "building_B", Vector3(-65, -0.2, 78), PI, S, false)
	_city(main, "building_H", Vector3(-80, -0.2, -48), 0.0, S, false)
	_city(main, "building_D", Vector3(75, -0.2, -66), 0.0, S, false)
	# Single watertower on the distant south skyline (roof of E ≈ 11.5).
	_city(main, "watertower", Vector3(15, 11.0, 86), 0.3, 4.0, false)
	# --- far tree belt (12, no shadows): layered horizon silhouettes.
	for t in [
		["Tree_2_A_Color1", Vector3(48, 0, -85)], ["Tree_4_A_Color1", Vector3(-48, 0, -85)],
		["Tree_1_B_Color1", Vector3(95, 0, -35)], ["Tree_3_B_Color1", Vector3(-95, 0, -30)],
		["Tree_2_C_Color1", Vector3(95, 0, 55)], ["Tree_1_C_Color1", Vector3(-95, 0, 55)],
		["Tree_4_C_Color1", Vector3(60, 0, 95)], ["Tree_3_A_Color1", Vector3(-60, 0, 95)],
		["Tree_1_A_Color1", Vector3(100, 0, 0)], ["Tree_2_B_Color1", Vector3(-100, 0, 5)],
		["Tree_3_C_Color1", Vector3(40, 0, -95)], ["Tree_4_A_Color1", Vector3(-40, 0, -95)],
	]:
		var node := _nature(main, t[0], t[1], 0.0, 1.1)
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# --- BlockBits elevation shelves (outer districts only; the café
	# stays on its flat main level). Tops +1.5 / +3 with brick retaining
	# faces; buildings and trees placed on the platforms at their top Y.
	# A. North raised strip with background buildings.
	_block(main, "dirt_with_grass", Vector3(25, 0, -75), 0.0, Vector3(20, 1.5, 7))
	_block(main, "grass", Vector3(25, 1.5, -78), 0.0, Vector3(15, 1.5, 5))
	_block(main, "bricks_A", Vector3(25, 0, -67.8), 0.0, Vector3(20, 1.5, 0.3))
	_city(main, "building_G", Vector3(15, 2.8, -78), 0.0, S, false)
	_city(main, "building_E", Vector3(33, 2.8, -78), 0.0, S, false)
	for tr in [
		["Tree_1_B_Color1", Vector3(7, 1.5, -76)], ["Tree_3_C_Color1", Vector3(43, 1.5, -76)],
		["Tree_2_A_Color1", Vector3(15, 1.5, -70)], ["Tree_4_B_Color1", Vector3(35, 1.5, -70)],
	]:
		_nature(main, tr[0], tr[1], 0.0, 1.0)
	# B. West raised district edge.
	_block(main, "dirt_with_grass", Vector3(-75, 0, -25), 0.0, Vector3(7, 1.5, 20))
	_block(main, "grass", Vector3(-80, 1.5, -25), 0.0, Vector3(5, 1.5, 14))
	_block(main, "bricks_A", Vector3(-67.8, 0, -25), 0.0, Vector3(0.3, 1.5, 20))
	_city(main, "building_C", Vector3(-80, 2.8, -30), PI * 0.5, S, false)
	_city(main, "building_E", Vector3(-80, 2.8, -16), PI * 0.5, S, false)
	for tr in [
		["Tree_2_D_Color1", Vector3(-70, 1.5, -40)], ["Tree_1_A_Color1", Vector3(-70, 1.5, -10)],
		["Tree_3_A_Color1", Vector3(-70, 1.5, -25)],
	]:
		_nature(main, tr[0], tr[1], 0.0, 1.0)
	# C. South-east multi-level expansion.
	_block(main, "dirt_with_grass", Vector3(75, 0, 45), 0.0, Vector3(8, 1.5, 8))
	_block(main, "grass", Vector3(85, 1.5, 50), 0.0, Vector3(6, 1.5, 6))
	_block(main, "bricks_B", Vector3(75, 0, 53.2), 0.0, Vector3(8, 1.5, 0.3))
	_city(main, "building_A", Vector3(84, 2.8, 50), -PI * 0.5, S, false)
	_city(main, "building_F", Vector3(72, 1.3, 42), 0.0, S, false)
	for tr in [
		["Tree_4_A_Color1", Vector3(70, 1.5, 50)], ["Tree_2_B_Color1", Vector3(80, 1.5, 40)],
		["Tree_1_C_Color1", Vector3(88, 3.0, 56)],
	]:
		_nature(main, tr[0], tr[1], 0.0, 1.0)
	# D. South terrace behind the near row: tree line + two buildings,
	# entrance corridor (x±7) kept low so the axis view stays open.
	_block(main, "dirt_with_grass", Vector3(0, 0, 68), 0.0, Vector3(25, 1.5, 5))
	_block(main, "grass", Vector3(0, 1.5, 72), 0.0, Vector3(18, 1.5, 5))
	_block(main, "bricks_A", Vector3(0, 0, 62.8), 0.0, Vector3(25, 1.5, 0.3))
	_city(main, "building_C", Vector3(-12, 2.8, 72), PI, S, false)
	_city(main, "building_H", Vector3(12, 2.8, 72), PI, S, false)
	for tr in [
		["Tree_1_A_Color1", Vector3(-22, 1.5, 65)], ["Tree_2_B_Color1", Vector3(22, 1.5, 65)],
		["Tree_3_C_Color1", Vector3(0, 1.5, 65)],
	]:
		_nature(main, tr[0], tr[1], 0.0, 1.0)
	# E. South-west park terrace (raised greenery, no buildings).
	_block(main, "grass", Vector3(-72, 0, 40), 0.0, Vector3(5, 1, 5))
	for tr in [
		["Tree_2_C_Color1", Vector3(-74, 1.0, 38)], ["Tree_3_B_Color1", Vector3(-70, 1.0, 42)],
		["Tree_1_A_Color1", Vector3(-75, 1.0, 43)],
	]:
		_nature(main, tr[0], tr[1], 0.0, 0.95)
	# F. NORTH-WEST high district (base top +1.5 / mid top +3 / upper top
	# +4.5): single background building on the upper stone platform, trees
	# ringed on the open aprons outside each upper footprint.
	_block(main, "dirt", Vector3(-45, 0, -70), 0.0, Vector3(12, 1.5, 6))
	_block(main, "stone_dark", Vector3(-45, 0, -66.6), 0.0, Vector3(12, 1.5, 0.3))
	_block(main, "dirt_with_grass", Vector3(-45, 1.5, -72), 0.0, Vector3(9, 1.5, 5))
	_block(main, "stone", Vector3(-45, 3.0, -73.5), 0.0, Vector3(6, 1.5, 5))
	_city(main, "building_F", Vector3(-45, 4.3, -73.5), 0.0, S, false)
	for tr in [
		["Tree_1_A_Color1", Vector3(-56.5, 1.5, -70)], ["Tree_3_B_Color1", Vector3(-33.5, 1.5, -70)],
		["Tree_2_C_Color1", Vector3(-45, 1.5, -65)], ["Tree_4_A_Color1", Vector3(-54, 3.0, -72)],
		["Tree_1_C_Color1", Vector3(-36, 3.0, -72)],
	]:
		_nature(main, tr[0], tr[1], 0.0, 1.0)
	# G. NORTH-EAST high district: mirror of F with gravel/stone retaining
	# so the two northern districts read differently.
	_block(main, "gravel", Vector3(45, 0, -70), 0.0, Vector3(12, 1.5, 6))
	_block(main, "stone", Vector3(45, 0, -66.6), 0.0, Vector3(12, 1.5, 0.3))
	_block(main, "gravel_with_grass", Vector3(45, 1.5, -72), 0.0, Vector3(9, 1.5, 5))
	_block(main, "stone_dark", Vector3(45, 3.0, -73.5), 0.0, Vector3(6, 1.5, 5))
	_city(main, "building_A", Vector3(45, 4.3, -73.5), 0.0, S, false)
	for tr in [
		["Tree_2_B_Color1", Vector3(33.5, 1.5, -70)], ["Tree_4_C_Color1", Vector3(56.5, 1.5, -70)],
		["Tree_3_A_Color1", Vector3(45, 1.5, -65)], ["Tree_1_B_Color1", Vector3(36, 3.0, -72)],
		["Tree_2_A_Color1", Vector3(54, 3.0, -72)],
	]:
		_nature(main, tr[0], tr[1], 0.0, 1.0)
	# H. WEST FAR high band (base +1.5 / upper +3 / cap +6): narrow
	# tree/building skyline west of the B district for triple west depth.
	_block(main, "dirt_with_grass", Vector3(-88, 0, 15), 0.0, Vector3(7, 1.5, 12))
	_block(main, "bricks_B", Vector3(-80.2, 0, 15), 0.0, Vector3(0.3, 1.5, 12))
	_block(main, "grass", Vector3(-90, 1.5, 15), 0.0, Vector3(6, 1.5, 10))
	_block(main, "stone_dark", Vector3(-90, 3.0, 14), 0.0, Vector3(5, 1.5, 5))
	_city(main, "building_D", Vector3(-90, 4.3, 14), PI * 0.5, S, false)
	for tr in [
		["Tree_3_C_Color1", Vector3(-81.5, 1.5, 9)], ["Tree_1_A_Color1", Vector3(-81.5, 1.5, 21)],
		["Tree_2_A_Color1", Vector3(-90, 1.5, 2.6)], ["Tree_4_B_Color1", Vector3(-90, 1.5, 27.4)],
		["Tree_1_B_Color1", Vector3(-90, 3.0, 6.5)], ["Tree_2_C_Color1", Vector3(-92, 3.0, 22.5)],
		["Tree_3_A_Color1", Vector3(-88, 3.0, 22.5)],
	]:
		_nature(main, tr[0], tr[1], 0.0, 1.0)
	# I. SOUTH-EAST FAR skyline terrace (mid +3 / upper +4.5): second
	# elevated district behind the closer C district + ring road.
	_block(main, "dirt", Vector3(80, 0, -35), 0.0, Vector3(10, 1.5, 7))
	_block(main, "bricks_A", Vector3(80, 0, -27.7), 0.0, Vector3(10, 1.5, 0.3))
	_block(main, "dirt_with_grass", Vector3(80, 1.5, -36), 0.0, Vector3(9, 1.5, 5))
	_block(main, "stone", Vector3(80, 3.0, -36.5), 0.0, Vector3(6, 1.5, 5))
	_city(main, "building_C", Vector3(80, 4.3, -36.5), -PI * 0.5, S, false)
	for tr in [
		["Tree_4_A_Color1", Vector3(76, 1.5, -28.5)], ["Tree_2_B_Color1", Vector3(84, 1.5, -28.5)],
		["Tree_1_C_Color1", Vector3(71.5, 3.0, -36)], ["Tree_3_B_Color1", Vector3(88.5, 3.0, -36)],
	]:
		_nature(main, tr[0], tr[1], 0.0, 1.0)
	# --- parked cars (static curbside, y=0.35 so wheels meet road top 0.05).
	# Curb lanes leave the center lanes free for the moving traffic below.
	_city(main, "car_sedan", Vector3(-12, 0.35, 18.3), PI * 0.5)
	_city(main, "car_hatchback", Vector3(7, 0.35, 18.3), PI * 0.5)
	_city(main, "car_taxi", Vector3(16, 0.35, 25.7), -PI * 0.5)
	_city(main, "car_stationwagon", Vector3(-3, 0.35, 25.7), -PI * 0.5)
	_city(main, "car_sedan", Vector3(-33.8, 0.35, -8), 0.0)
	_city(main, "car_hatchback", Vector3(-26.2, 0.35, 10), PI)
	_city(main, "car_taxi", Vector3(33.8, 0.35, -4), PI)
	_city(main, "car_stationwagon", Vector3(26.2, 0.35, 14), 0.0)
	_city(main, "car_sedan", Vector3(8, 0.35, -21.5), PI * 0.5)
	_city(main, "car_hatchback", Vector3(-10, 0.35, -28.5), -PI * 0.5)
	# --- moving traffic: 6 slow ambient cars on waypoint loops (one shared
	# driver, no physics). Center lanes only, clear of parked cars/props.
	var traffic := CafeTraffic.new()
	traffic.name = "CafeTraffic"
	main.world_root.add_child(traffic)
	var y := 0.35
	# R1: inner block clockwise (south EB → east NB → north WB → west SB).
	var r1 := PackedVector3Array([
		Vector3(-45, y, 20.5), Vector3(25, y, 20.5), Vector3(28.5, y, 17),
		Vector3(28.5, y, -20), Vector3(25, y, -26.5), Vector3(-25, y, -26.5),
		Vector3(-28.5, y, -20), Vector3(-28.5, y, 17), Vector3(-25, y, 20.5),
	])
	traffic.add_car(_city(main, "car_sedan", r1[0], 0.0), r1, 2.2, 1)
	traffic.add_car(_city(main, "car_taxi", r1[4], 0.0), r1, 2.2, 5)
	# R2: inner block counter-clockwise.
	var r2 := PackedVector3Array([
		Vector3(45, y, 23.5), Vector3(-25, y, 23.5), Vector3(-31.5, y, 17),
		Vector3(-31.5, y, -20), Vector3(-25, y, -23.5), Vector3(25, y, -23.5),
		Vector3(31.5, y, -20), Vector3(31.5, y, 17), Vector3(25, y, 23.5),
	])
	traffic.add_car(_city(main, "car_hatchback", r2[0], 0.0), r2, 2.2, 1)
	traffic.add_car(_city(main, "car_stationwagon", r2[4], 0.0), r2, 2.2, 5)
	# R3: outer ring rectangle (EW52 → NS60 → EW-55 → NS60).
	var r3 := PackedVector3Array([
		Vector3(-50, y, 52), Vector3(50, y, 52), Vector3(60, y, 52),
		Vector3(60, y, -55), Vector3(50, y, -55), Vector3(-50, y, -55),
		Vector3(-60, y, -55), Vector3(-60, y, 52),
	])
	traffic.add_car(_city(main, "car_sedan", r3[0], 0.0), r3, 2.6, 1)
	traffic.add_car(_city(main, "car_taxi", r3[4], 0.0), r3, 2.6, 5)
	# --- streetlights (14): emissive heads everywhere, real lights only
	# on the 3 closest to the café (WebGL budget).
	var lamp_positions: Array = [
		[Vector3(-20, 0.03, 15.8), PI], [Vector3(-12, 0.03, 15.8), PI],
		[Vector3(12, 0.03, 15.8), PI], [Vector3(20, 0.03, 15.8), PI],
		[Vector3(-21, 0.03, -15), PI * 0.5], [Vector3(-21, 0.03, -5), PI * 0.5],
		[Vector3(-21, 0.03, 5), PI * 0.5], [Vector3(-21, 0.03, 15), PI * 0.5],
		[Vector3(21, 0.03, -10), -PI * 0.5], [Vector3(21, 0.03, 2), -PI * 0.5],
		[Vector3(21, 0.03, 14), -PI * 0.5],
		[Vector3(-12, 0.03, -21), 0.0], [Vector3(0, 0.03, -21), 0.0],
		[Vector3(12, 0.03, -21), 0.0],
		[Vector3(-15, 0.03, 48.5), PI], [Vector3(15, 0.03, 48.5), PI],
		[Vector3(-15, 0.03, -51.5), 0.0], [Vector3(15, 0.03, -51.5), 0.0],
	]
	for entry in lamp_positions:
		_city(main, "streetlight", entry[0], entry[1])
		_city_lamp_head(main, entry[0], entry[1])
	for pos in [Vector3(-12, 5.2, 15.8), Vector3(12, 5.2, 15.8), Vector3(-21, 5.2, 5)]:
		var lamp := OmniLight3D.new()
		lamp.position = pos
		lamp.light_color = Color("#ffb46b")
		lamp.light_energy = 0.65
		lamp.omni_range = 8.0
		lamp.shadow_enabled = false
		main.world_root.add_child(lamp)
	# --- one signalised intersection (SW): traffic lights only here.
	_city(main, "trafficlight_A", Vector3(-35, 0.0, 16.5), PI * 0.5)
	_city(main, "trafficlight_B", Vector3(-25, 0.0, 28.0), -PI * 0.5)
	# --- benches, hydrants, trash, dumpster corner, city bushes.
	_city(main, "bench", Vector3(-8, 0.05, 15.9), PI, 4.0)
	_city(main, "bench", Vector3(8, 0.05, 15.9), PI, 4.0)
	_city(main, "bench", Vector3(-30, 0.05, 28.5), 0.0, 4.0)
	_city(main, "bench", Vector3(-21, 0.05, 2), PI * 0.5, 4.0)
	_city(main, "bench", Vector3(0, 0.05, -21.5), 0.0, 4.0)
	_city(main, "firehydrant", Vector3(-4, 0.05, 14.8), 0.0, 4.0)
	_city(main, "firehydrant", Vector3(21.5, 0.05, 16.0), 0.0, 4.0)
	_city(main, "trash_A", Vector3(-7, 0.05, 16.2), 0.3, 4.0)
	_city(main, "trash_B", Vector3(9, 0.05, 16.2), -0.4, 4.0)
	_city(main, "trash_A", Vector3(-21, 0.05, 6.5), 0.0, 4.0)
	_city(main, "dumpster", Vector3(-14, 0.0, -31.0), 0.1, 4.0)
	_city(main, "box_A", Vector3(-13, 0.0, -31.0), 0.3, 4.0)
	_city(main, "box_B", Vector3(-12.4, 0.0, -30.8), -0.2, 4.0)
	for b in [
		[Vector3(-30, 0.0, 30.5), 0.2], [Vector3(-18, 0.0, 30.5), -0.3],
		[Vector3(8, 0.0, 31.5), 0.5], [Vector3(-36, 0.0, -8), 0.1],
		[Vector3(36, 0.0, -2), -0.2], [Vector3(2, 0.0, -44), 0.4],
	]:
		_city(main, "bush", b[0], b[1], 4.0)
	# --- street trees (8) in sidewalk planting lines.
	_nature(main, "Tree_1_B_Color1", Vector3(-14, 0, 15.3), 0.2, 1.0)
	_nature(main, "Tree_3_C_Color1", Vector3(14, 0, 15.3), -0.4, 1.0)
	_nature(main, "Tree_2_A_Color1", Vector3(-19, 0, -12), 0.5, 1.0)
	_nature(main, "Tree_4_B_Color1", Vector3(-19, 0, -2), -0.3, 1.0)
	_nature(main, "Tree_3_A_Color1", Vector3(19.5, 0, -8), 0.4, 1.0)
	_nature(main, "Tree_2_D_Color1", Vector3(19.5, 0, 4), -0.5, 1.0)
	_nature(main, "Tree_1_C_Color1", Vector3(-14, 0, -19), 0.3, 1.0)
	_nature(main, "Tree_4_A_Color1", Vector3(-2, 0, -19), -0.2, 1.0)
	# --- SW pocket green (2 trees + bench + bushes + grass).
	_nature(main, "Tree_2_C_Color1", Vector3(-32, 0, 28), 0.4, 1.0)
	_nature(main, "Tree_3_B_Color1", Vector3(-28, 0, 29), -0.5, 1.0)
	_nature(main, "Bush_1_A_Color1", Vector3(-31, 0, 27), 0.1, 1.0)
	_nature(main, "Bush_2_B_Color1", Vector3(-29, 0, 30), -0.3, 1.0)
	_nature(main, "Grass_1_A_Color1", Vector3(-30, 0, 29.5), 0.5, 1.0)
	# --- NE pocket green (3 trees + rocks + bushes). Clear of the x=30
	# stub road (x 25..35) and the east building row: sits at x 38..45.
	_nature(main, "Tree_1_A_Color1", Vector3(40, 0, -33), 0.3, 1.05)
	_nature(main, "Tree_4_C_Color1", Vector3(44, 0, -32), -0.4, 1.0)
	_nature(main, "Tree_3_A_Color1", Vector3(42, 0, -35), 0.6, 0.95)
	_nature(main, "Rock_1_A_Color1", Vector3(41, 0, -34), 0.2, 1.0)
	_nature(main, "Rock_2_B_Color1", Vector3(43, 0, -34), -0.5, 1.0)
	_nature(main, "Bush_3_A_Color1", Vector3(40.5, 0, -34.5), 0.4, 1.0)
	_nature(main, "Bush_4_C_Color1", Vector3(43.5, 0, -33.5), -0.4, 1.0)
	# --- gap trees between buildings (5): centered in gaps, clear of walls
	# and glass. South pair sit 3 m+ from adjacent fronts; west/east sit
	# behind their rows; north sits centered in the C/H gap.
	_nature(main, "Tree_2_B_Color1", Vector3(-26, 0, 32.5), 0.3, 1.0)
	_nature(main, "Tree_1_A_Color1", Vector3(16.5, 0, 32.5), -0.4, 1.0)
	_nature(main, "Tree_3_C_Color1", Vector3(-44, 0, -6), 0.5, 1.05)
	_nature(main, "Tree_4_B_Color1", Vector3(43.5, 0, 4), -0.3, 1.0)
	_nature(main, "Tree_1_C_Color1", Vector3(-5, 0, -33.5), 0.2, 1.0)
	# --- far skyline trees (4, no shadows): layered silhouettes only.
	for t in [
		["Tree_2_A_Color1", Vector3(48, 0, -40)], ["Tree_4_A_Color1", Vector3(-48, 0, -38)],
		["Tree_1_B_Color1", Vector3(50, 0, 30)], ["Tree_3_B_Color1", Vector3(-50, 0, 32)],
	]:
		var node := _nature(main, t[0], t[1], 0.0, 1.1)
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ---------------------------------------------------------------------------
# Furnishing helpers. All asset paths live under assets/source/cafe_packs/.
# KayKit models are true 1 unit = 1 m; Low Poly Furniture props take a scale.
# ---------------------------------------------------------------------------

const PACK := "res://assets/source/cafe_packs/"
const LAPTOP_SCALE := 0.15
const MUG_SCALE := 0.15
const SMALL_PROP_SCALE := 0.2


static func _name_spot(main, spot, prefix: String, n: int) -> void:
	spot.seat_id = "cafe-%s%02d" % [prefix, n]
	spot.seat_label = ("Ground table " if prefix == "G" else "Upstairs seat ") + str(n)


static func _place(main, relative_path: String, pos: Vector3, yaw := 0.0, scale_value := Vector3.ONE) -> Node3D:
	var packed: PackedScene = load(PACK + relative_path)
	var node := packed.instantiate() as Node3D
	main.world_root.add_child(node)
	node.position = pos
	node.rotation.y = yaw
	node.scale = scale_value
	return node


# Furniture yaw whose sitter faces `direction` (uses the StudyTown -Z
# forward convention: seat_yaw = atan2(-dx, -dz), furniture faces backward).
static func _furniture_yaw_for(direction: Vector3) -> float:
	var seat_yaw := atan2(-direction.x, -direction.z)
	return wrapf(seat_yaw + PI, -PI, PI)
