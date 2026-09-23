extends RefCounted

## Swaps baked garden hero vegetation with converted CraftPix models at room
## load. The .tscn on disk is never modified; originals stay as automatic
## fallback when a pack GLB is absent (e.g. clean checkouts). Trunk
## collision, seat anchors, and leaf emitters live elsewhere and are
## untouched, so falling leaves keep falling from the same spots.

const RUNTIME := "res://assets/dev_local/blender_generated/runtime/"

# Round upright canopies only for hero spots (weepers/pines excluded here).
const OAK_SWAPS := [
	"craftpix_tree_temp_climate_002.glb",
	"craftpix_tree_temp_climate_003.glb",
	"craftpix_tree_temp_climate_004.glb",
	"craftpix_tree_temp_climate_007.glb",
	"craftpix_tree_temp_climate_008.glb",
	"craftpix_tree_temp_climate_009.glb",
	"craftpix_tree_temp_climate_011.glb",
	"craftpix_tree_temp_climate_016.glb",
]
const BLOSSOM_SWAPS := [
	"craftpix_tree_temp_climate_005.glb",
	"craftpix_tree_temp_climate_010.glb",
	"craftpix_tree_temp_climate_012.glb",
	"craftpix_tree_temp_climate_018.glb",
]
const CENTER_TREE := "craftpix_tree_temp_climate_001.glb"
const SHRUB_SWAPS := [
	"craftpix_bush_temp_climate_001.glb",
	"craftpix_bush_temp_climate_003.glb",
	"craftpix_bush_temp_climate_005.glb",
	"craftpix_bush_temp_climate_006.glb",
	"craftpix_bush_temp_climate_010.glb",
]

# Lightens/desaturates the pack's vivid atlas greens toward a paler sage.
# Applied once per material (shared resources persist across room visits).
static var _tinted_materials: Array = []
const TREE_TINT := Color(1.25, 1.28, 1.20, 1.0)
const SHRUB_TINT := Color(1.12, 1.15, 1.08, 1.0)

# Set by the editor preview script: physics raycasts don't hit anything
# outside a running game, so grounding falls back to y=0 for previews.
static var editor_preview := false


const LAMP_SWAPS := [
	"craftpix_lamp_1.glb",
	"craftpix_lamp_3.glb",
	"craftpix_lamp_4.glb",
	"craftpix_lamp_1.glb",
]


static func apply(layout: Node3D) -> void:
	# Dressing may be baked straight into garden.tscn (see
	# tools/editor/bake_garden_dressing_preview.gd); running it twice would
	# double-swap every tree, so a baked marker skips the whole pass.
	if int(layout.get_meta("garden_dressed_version", 0)) >= 1:
		return
	var oak_index := 0
	var blossom_index := 0
	var shrub_index := 0
	for node in layout.find_children("*", "Node3D", true, false):
		var source: String = node.scene_file_path
		if source.is_empty():
			continue
		var glb := ""
		var tint := TREE_TINT
		if source.ends_with("garden_big_tree.glb"):
			glb = CENTER_TREE
		elif source.ends_with("garden_oak_tree.glb"):
			glb = OAK_SWAPS[oak_index % OAK_SWAPS.size()]
			oak_index += 1
		elif source.ends_with("garden_pond_blossom.glb"):
			glb = BLOSSOM_SWAPS[blossom_index % BLOSSOM_SWAPS.size()]
			blossom_index += 1
		elif source.ends_with("garden_shrub.glb"):
			glb = SHRUB_SWAPS[shrub_index % SHRUB_SWAPS.size()]
			shrub_index += 1
			tint = SHRUB_TINT
		else:
			continue
		swap_instance(node, RUNTIME + glb, tint)
	print("CRAFTPIX_DRESSING oaks=", oak_index, " blossoms=", blossom_index, " shrubs=", shrub_index)
	_swap_lamps(layout)
	_place_house(layout, layout, RUNTIME + "craftpix_house_04_full.glb", "CraftPixBackdropHouse", Vector3(-14.0, 0.0, -25.0), PI)
	_plant_surroundings(layout)
	_place_dressing_props(layout)
	_place_extra_lamps(layout)
	_brighten_bulbs(layout)
	_align_leaf_emitters(layout)
	_dress_falling_leaves(layout)
	_scatter_path_litter(layout)


static var _shared_litter_material: StandardMaterial3D


## Drops shared resources so GPU objects can tear down cleanly at exit.
static func release() -> void:
	_shared_litter_material = null
	_shared_leaf_mesh = null
	_shared_leaf_texture = null
	_shared_leaf_draw = null
	_tinted_materials.clear()
	_house_tinted.clear()


## Hundreds of permanent fallen leaves resting on the paths: one MultiMesh
## (single draw call), deterministic layout, never fading.
static func _scatter_path_litter(layout: Node3D) -> void:
	if layout.get_node_or_null("Paths/CraftPixLeafLitter") != null:
		return
	if _shared_leaf_mesh == null or _shared_leaf_texture == null:
		return
	var zone: Node3D = layout.get_node_or_null("Paths") as Node3D
	if zone == null:
		return
	if _shared_litter_material == null:
		_shared_litter_material = StandardMaterial3D.new()
		_shared_litter_material.albedo_texture = _shared_leaf_texture
		_shared_litter_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		_shared_litter_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_shared_litter_material.roughness = 0.9
		_shared_litter_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240
	var spots: Array[Vector3] = []
	for i in 150:
		var t: float = TAU * float(i) / 150.0
		var wobble: float = rng.randf_range(-1.6, 1.6)
		spots.append(Vector3(
			-0.1 + (14.3 + wobble) * cos(t),
			0.03,
			-0.7 + (10.9 + wobble) * sin(t)
		))
	for i in 40:
		spots.append(Vector3(rng.randf_range(-1.6, 1.6), 0.03, rng.randf_range(8.0, 18.0)))
	for i in 30:
		spots.append(Vector3(rng.randf_range(-1.6, 1.6), 0.03, rng.randf_range(-16.0, -10.0)))
	var litter := MultiMeshInstance3D.new()
	litter.name = "CraftPixLeafLitter"
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _shared_leaf_mesh
	multimesh.instance_count = spots.size()
	multimesh.visible_instance_count = spots.size()
	for i in spots.size():
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * rng.randf_range(0.6, 1.0))
		multimesh.set_instance_transform(i, Transform3D(basis, spots[i]))
	litter.multimesh = multimesh
	litter.material_override = _shared_litter_material
	litter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	zone.add_child(litter)


## Extra lamp posts along the ring, bridges, and grove, with glowing bulbs.
## Emissive only (no new OmniLight3Ds): the pond test budgets real lights at
## eight, and the seating zones already pool light.
static func _place_extra_lamps(layout: Node3D) -> void:
	if layout.get_node_or_null("Planting/CraftPixProps") == null:
		return
	var props: Node3D = layout.get_node_or_null("Planting/CraftPixProps") as Node3D
	if props == null:
		return
	var models := ["craftpix_lamp_1.glb", "craftpix_lamp_3.glb", "craftpix_lamp_4.glb"]
	var spots := [
		Vector3(-8.0, 0.0, 12.0), Vector3(8.0, 0.0, 12.0),
		Vector3(-11.5, 0.0, -8.0), Vector3(11.5, 0.0, -6.0),
		Vector3(0.0, 0.0, -18.5), Vector3(-16.0, 0.0, 6.0),
	]
	var index := 0
	for spot in spots:
		var node := _place_prop(props, layout, models[index % models.size()], "CraftPixLampExtra_%d" % index, spot, 0.0)
		index += 1
		if node == null:
			continue


## Turns every baked lantern bulb up: larger globes plus hotter shared
## emissive materials so the glow carries across the garden at night.
static func _brighten_bulbs(layout: Node3D) -> void:
	var handled_materials := {}
	for mesh_instance in layout.find_children("LampBulb*", "MeshInstance3D", true, false):
		var bulb := mesh_instance as MeshInstance3D
		# Fill the lantern cage so the glow reads from every angle instead
		# of hiding behind the cage bars from some viewpoints.
		bulb.scale = bulb.scale * 2.0
		if bulb.mesh == null:
			continue
		for surface in bulb.mesh.get_surface_count():
			var material: Material = bulb.get_active_material(surface)
			if material == null or not (material is StandardMaterial3D):
				continue
			var id: int = material.get_instance_id()
			if handled_materials.has(id):
				continue
			handled_materials[id] = true
			(material as StandardMaterial3D).emission_energy_multiplier = 6.5


static func _place_dressing_props(layout: Node3D) -> void:
	if layout.get_node_or_null("Planting/CraftPixProps") != null:
		return
	var zone: Node3D = layout.get_node_or_null("Planting") as Node3D
	if zone == null:
		return
	var props := Node3D.new()
	props.name = "CraftPixProps"
	zone.add_child(props)
	_place_prop(props, layout, "craftpix_gate_1.glb", "GateNorthL", Vector3(-1.6, 0.0, -10.5), 0.0)
	_place_prop(props, layout, "craftpix_gate_1.glb", "GateNorthR", Vector3(1.6, 0.0, -10.5), 0.0)
	_place_prop(props, layout, "craftpix_gate_3.glb", "GateScreenEast", Vector3(6.0, 0.0, -11.0), 0.6)
	_place_prop(props, layout, "craftpix_gate_1.glb", "GateSpawn", Vector3(0.0, 0.0, 18.5), PI)
	_place_prop(props, layout, "craftpix_fense_2.glb", "FenceWestA", Vector3(-19.5, 0.0, 4.0), PI * 0.5)
	_place_prop(props, layout, "craftpix_fense_3.glb", "FenceWestB", Vector3(-19.5, 0.0, 8.5), PI * 0.5)
	_place_prop(props, layout, "craftpix_fense_1.glb", "FenceEastA", Vector3(19.0, 0.0, -6.0), PI * 0.5)
	_place_prop(props, layout, "craftpix_fense_5.glb", "RubbleNorthA", Vector3(-3.5, 0.0, -17.5), 0.3)
	_place_prop(props, layout, "craftpix_fense_4.glb", "RubbleNorthB", Vector3(3.5, 0.0, -17.5), -0.4)
	_place_prop(props, layout, "craftpix_bag_1.glb", "PotCafeA", Vector3(-9.5, 0.0, 8.0), 0.0)
	_place_prop(props, layout, "craftpix_bag_2.glb", "PotCafeB", Vector3(11.0, 0.0, 9.5), 0.0)
	_place_prop(props, layout, "craftpix_bag_2.glb", "PotTerrace", Vector3(4.5, 0.0, -13.0), 0.0)
	_place_prop(props, layout, "craftpix_bench.glb", "BenchNorth", Vector3(-5.5, 0.0, -13.5), PI * 0.1)


static func _place_prop(parent: Node3D, layout: Node3D, glb: String, prop_name: String, spot: Vector3, yaw: float) -> Node3D:
	var path: String = RUNTIME + glb
	if not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = load(path)
	var node := packed.instantiate() as Node3D
	if node == null:
		return null
	parent.add_child(node)
	var ground_y := _ground_y(layout, spot)
	if ground_y < -50.0:
		node.queue_free()
		return null
	node.name = prop_name
	node.position = Vector3(spot.x, ground_y - 0.02, spot.z)
	node.rotation.y = yaw
	return node


## Re-seats leaf emitter heights onto the swapped canopies: emitters were
## authored for the original tree heights, so without this leaves spawn in
## mid-air or inside trunks.
static func _align_leaf_emitters(layout: Node3D) -> void:
	var tops: Array = []
	for node in layout.find_children("*", "Node3D", true, false):
		var source: String = (node as Node3D).scene_file_path
		if source.is_empty():
			continue
		if not (source.ends_with("garden_oak_tree.glb") or source.ends_with("garden_pond_blossom.glb") or source.ends_with("garden_big_tree.glb")):
			continue
		for mesh_instance in (node as Node3D).find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (mesh_instance as MeshInstance3D).mesh
			if mesh == null:
				continue
			var box: AABB = (mesh_instance as MeshInstance3D).global_transform * (mesh_instance as MeshInstance3D).get_aabb()
			tops.append(Vector3(box.position.x + box.size.x * 0.5, box.position.y + box.size.y, box.position.z + box.size.z * 0.5))
	# Replacement canopies sit at the same spots (swaps preserve position).
	for emitter in layout.find_children("*", "GPUParticles3D", true, false):
		var particles := emitter as GPUParticles3D
		var best_y := 1.0e9
		var best_dist := 6.0
		for top in tops:
			var flat: float = Vector2(top.x - particles.global_position.x, top.z - particles.global_position.z).length()
			if flat < best_dist:
				best_dist = flat
				best_y = top.y
		if best_y < 1.0e8:
			particles.position.y = best_y - particles.global_position.y + particles.position.y + 0.2


static var _shared_leaf_mesh: ArrayMesh
static var _shared_leaf_texture: Texture2D
static var _shared_leaf_draw: ShaderMaterial


## Real leaf look for the falling foliage: the authored textured leaf mesh as
## the shared draw pass plus a texture-aware draw material, and pink petal
## process materials retinted to green (the blossom trees they fell from are
## gone). Motion, counts, and emitter spots are untouched.
static func _dress_falling_leaves(layout: Node3D) -> void:
	if _shared_leaf_mesh == null:
		const LEAF := "res://assets/dev_local/blender_generated/runtime/garden_falling_leaf.glb"
		if ResourceLoader.exists(LEAF):
			var packed: PackedScene = load(LEAF)
			var instance := packed.instantiate() as Node3D
			if instance != null:
				for mesh_instance in instance.find_children("*", "MeshInstance3D", true, false):
					var mesh: Mesh = (mesh_instance as MeshInstance3D).mesh
					if mesh == null or mesh.get_surface_count() < 1:
						continue
					var arrays: Array = mesh.surface_get_arrays(0)
					if arrays.size() <= Mesh.ARRAY_TEX_UV or arrays[Mesh.ARRAY_TEX_UV] == null:
						continue
					_shared_leaf_mesh = mesh
					var material: Material = (mesh_instance as MeshInstance3D).get_active_material(0)
					if material is StandardMaterial3D and (material as StandardMaterial3D).albedo_texture != null:
						_shared_leaf_texture = (material as StandardMaterial3D).albedo_texture
					break
				instance.free()
	if _shared_leaf_draw == null:
		_shared_leaf_draw = ShaderMaterial.new()
		_shared_leaf_draw.shader = load("res://shaders/garden_drifting_leaf.gdshader")
		if _shared_leaf_texture != null:
			_shared_leaf_draw.set_shader_parameter("leaf_tex", _shared_leaf_texture)
	var green_process: ShaderMaterial = null
	for emitter in layout.find_children("*", "GPUParticles3D", true, false):
		var process: Material = (emitter as GPUParticles3D).process_material
		if process is ShaderMaterial and (process as ShaderMaterial).resource_name == "GreenLeafMaterial":
			green_process = process
			break
	for emitter in layout.find_children("*", "GPUParticles3D", true, false):
		var particles := emitter as GPUParticles3D
		var process: Material = particles.process_material
		if process is ShaderMaterial and (process as ShaderMaterial).resource_name == "CherryPetalMaterial" and green_process != null:
			particles.process_material = green_process
		particles.lifetime = 12.0
		if _shared_leaf_mesh != null:
			particles.draw_pass_1 = _shared_leaf_mesh
			particles.draw_pass_1.surface_set_material(0, _shared_leaf_draw)


## Places one static cottage. Outside walkable bounds: no collision needed.
## Ground-snapped by raycast; skipped silently when no ground is found.
static func _place_house(layout: Node3D, parent: Node3D, glb_path: String, house_name: String, spot: Vector3, yaw: float) -> void:
	if layout.get_node_or_null(String(layout.get_path_to(parent)) + "/" + house_name) != null:
		return
	if not ResourceLoader.exists(glb_path):
		return
	var packed: PackedScene = load(glb_path)
	var house := packed.instantiate() as Node3D
	if house == null:
		return
	parent.add_child(house)
	var ground_y := _ground_y(layout, spot)
	if ground_y < -50.0:
		house.queue_free()
		return
	house.name = house_name
	house.position = Vector3(spot.x, ground_y - 0.05, spot.z)
	house.rotation.y = yaw
	# Warm the washed-out plaster toward cream timber.
	_tone_house(house)


static var _house_tinted: Array = []


static func _tone_house(house: Node3D) -> void:
	for mesh_instance in house.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mesh_instance as MeshInstance3D).mesh
		if mesh == null:
			continue
		for surface in mesh.get_surface_count():
			var material: Material = (mesh_instance as MeshInstance3D).get_active_material(surface)
			if material == null or not (material is StandardMaterial3D):
				continue
			var id: int = material.get_instance_id()
			if _house_tinted.has(id):
				continue
			_house_tinted.append(id)
			(material as StandardMaterial3D).albedo_color *= Color(1.06, 0.97, 0.86, 1.0)


## Extra backdrop: a ring of taller pack trees plus a second cottage, all
## outside the walkable bounds. Static, collisionless, grounded by raycast
## (skipped wherever no ground is found). Deterministic seed.
static func _plant_surroundings(layout: Node3D) -> void:
	if layout.get_node_or_null("Surroundings/CraftPixRing") != null:
		return
	var zone: Node3D = layout.get_node_or_null("Surroundings") as Node3D
	if zone == null:
		return
	var ring := Node3D.new()
	ring.name = "CraftPixRing"
	zone.add_child(ring)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var tree_models := [
		"craftpix_tree_temp_climate_002.glb",
		"craftpix_tree_temp_climate_004.glb",
		"craftpix_tree_temp_climate_006.glb",
		"craftpix_tree_temp_climate_011.glb",
		"craftpix_tree_temp_climate_014.glb",
		"craftpix_tree_temp_climate_019.glb",
		"craftpix_tree_temp_climate_020.glb",
		"craftpix_tree_temp_climate_021.glb",
		"craftpix_tree_temp_climate_001.glb",
		"craftpix_tree_temp_climate_008.glb",
		"craftpix_tree_temp_climate_016.glb",
		"craftpix_tree_temp_climate_015.glb",
	]
	for i in 40:
		var angle: float = TAU * float(i) / 40.0 + rng.randf_range(-0.06, 0.06)
		var radius := rng.randf_range(30.0, 48.0)
		var spot := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius * 0.75)
		var ground_y := _ground_y(layout, spot)
		if ground_y < -50.0:
			continue
		var path: String = RUNTIME + tree_models[i % tree_models.size()]
		if not ResourceLoader.exists(path):
			continue
		var packed: PackedScene = load(path)
		var tree := packed.instantiate() as Node3D
		if tree == null:
			continue
		ring.add_child(tree)
		tree.position = Vector3(spot.x, ground_y - 0.1, spot.z)
		tree.rotation.y = rng.randf_range(0.0, TAU)
		var s := rng.randf_range(1.2, 1.8)
		tree.scale = Vector3.ONE * s
		_tone_materials(tree, TREE_TINT)
	# Second cottage east-north, facing the garden.
	_place_house(layout, ring, RUNTIME + "craftpix_house_02_full.glb", "CraftPixBackdropHouseEast", Vector3(21.0, 0.0, -24.0), -PI * 0.35)


## Swaps every baked lamp post for a pack lamp (round-robin over the four
## models) and hangs a warm shadowless light at each lantern head.
static func _swap_lamps(layout: Node3D) -> void:
	var lamp_index := 0
	for node in layout.find_children("*", "Node3D", true, false):
		var source: String = (node as Node3D).scene_file_path
		if source.is_empty() or not source.ends_with("garden_forest_lamp.glb"):
			continue
		var replacement := swap_instance(node, RUNTIME + LAMP_SWAPS[lamp_index % LAMP_SWAPS.size()])
		lamp_index += 1
		if replacement == null:
			continue




static func _ground_y(layout: Node3D, spot: Vector3) -> float:
	if editor_preview:
		return 0.0
	var space: PhysicsDirectSpaceState3D = layout.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(spot.x, 30.0, spot.z), Vector3(spot.x, -5.0, spot.z), 1
	)
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return -100.0
	return (hit.position as Vector3).y


## Hides the original instance and plants the replacement at the same spot,
## uniformly scaled so heights match (proportions stay authorial).
static func swap_instance(node: Node3D, glb_path: String, tint := Color.WHITE) -> Node3D:
	if not is_instance_valid(node) or not ResourceLoader.exists(glb_path):
		return null
	var target_height := _world_height(node)
	if target_height <= 0.01:
		return null
	var packed: PackedScene = load(glb_path)
	var replacement := packed.instantiate() as Node3D
	if replacement == null:
		return null
	node.get_parent().add_child(replacement)
	# Fresh yaw-only basis: copying the original's full transform would
	# inherit non-uniform squash (e.g. the island tree's flattened z).
	var yaw: float = node.global_rotation.y
	var factor := 1.0
	var source_height := _world_height(replacement)
	if source_height > 0.01:
		factor = target_height / source_height
	replacement.global_transform = Transform3D(
		Basis(Vector3.UP, yaw).scaled(Vector3.ONE * factor), node.global_position
	)
	node.visible = false
	_tone_materials(replacement, tint)
	return replacement


## Multiplies albedo toward the garden mood. Textured StandardMaterials
## multiply texture by albedo_color, so one shared tint per model is enough.
static func _tone_materials(root: Node3D, tint: Color) -> void:
	if tint == Color.WHITE:
		return
	var seen := {}
	for mesh_instance in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mesh_instance as MeshInstance3D).mesh
		if mesh == null:
			continue
		for surface in mesh.get_surface_count():
			var material: Material = (mesh_instance as MeshInstance3D).get_active_material(surface)
			if material == null or not (material is StandardMaterial3D):
				continue
			var id: int = material.get_instance_id()
			if seen.has(id) or _tinted_materials.has(id):
				continue
			seen[id] = true
			_tinted_materials.append(id)
			(material as StandardMaterial3D).albedo_color *= tint


static func _world_height(node: Node3D) -> float:
	var bounds := AABB()
	var found := false
	for mesh_instance in node.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mesh_instance as MeshInstance3D).mesh
		if mesh == null:
			continue
		var box: AABB = (mesh_instance as MeshInstance3D).global_transform * (mesh_instance as MeshInstance3D).get_aabb()
		bounds = box if not found else bounds.merge(box)
		found = true
	return bounds.size.y if found else 0.0
