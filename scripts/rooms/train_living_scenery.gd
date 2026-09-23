extends Node3D

# Runtime-only motion for the Train's living exterior — v7 seamless water + true submerged jumps.
# Everything is animated locally under the existing 10 m scenery tiles, so the
# established 50 m Train scenery wrap remains untouched.

var _elapsed: float = 0.0

const EXTENDED_SCENERY_WRAP_LENGTH := 100.0
const EXTENDED_SCENERY_HALF_LENGTH := 50.0
const TRAIN_SCENERY_SPEED := 1.65
const FISH_WRAP_MIN_Z := -80.0
const FISH_WRAP_MAX_Z := 80.0

# One continuous water surface is authored at this exact height by the patcher.
# Fish idle well below it and must physically cross this Y value to be airborne.
const WATER_SURFACE_Y := -0.78
const FISH_UNDERWATER_Y := -1.34

var _rng := RandomNumberGenerator.new()

var _scenery_roots: Array[Node3D] = []
var _fish_jump_next: Dictionary = {}
var _fish_jump_start: Dictionary = {}
var _fish_jump_duration: Dictionary = {}
var _fish_jump_height: Dictionary = {}
var _fish_world_x: Dictionary = {}
var _fish_world_y: Dictionary = {}
var _fish_world_start_z: Dictionary = {}

var _boats: Array[Node3D] = []
var _fish: Array[Node3D] = []
var _birds: Array[Node3D] = []
var _tractors: Array[Node3D] = []
var _fireflies: Array[Node3D] = []
var _flames: Array[Node3D] = []
var _smoke: Array[MeshInstance3D] = []
var _ripples: Array[MeshInstance3D] = []
var _lighthouse_beams: Array[Node3D] = []

# Snapshotted once in _ready: per-frame get_meta() on ~150 animated nodes
# showed up in profiles, so every authored constant below is cached by group
# index. The node arrays never mutate after collection, so indices stay
# aligned for the room's lifetime. All values are patcher-authored and
# read-only at runtime, making the snapshot behavior-identical.
var _boat_base_pos: Array[Vector3] = []
var _boat_base_rot: Array[Vector3] = []
var _boat_phase := PackedFloat32Array()
var _scenery_speed := PackedFloat32Array()
var _fish_base_scale: Array[Vector3] = []
var _fish_phase := PackedFloat32Array()
var _fish_speed := PackedFloat32Array()
var _fish_rate := PackedFloat32Array()
var _bird_phase := PackedFloat32Array()
var _bird_cycle := PackedFloat32Array()
var _bird_duration := PackedFloat32Array()
var _bird_start: Array[Vector3] = []
var _bird_end: Array[Vector3] = []
var _bird_rot: Array[Vector3] = []
var _tractor_base: Array[Vector3] = []
var _tractor_phase := PackedFloat32Array()
var _tractor_speed := PackedFloat32Array()
var _firefly_base: Array[Vector3] = []
var _firefly_phase := PackedFloat32Array()
var _flame_scale: Array[Vector3] = []
var _flame_phase := PackedFloat32Array()
var _smoke_base: Array[Vector3] = []
var _smoke_phase := PackedFloat32Array()
var _ripple_phase := PackedFloat32Array()
var _beam_speed := PackedFloat32Array()
var _beam_phase := PackedFloat32Array()


func _ready() -> void:
	_rng.randomize()
	_collect_runtime_nodes()
	_snapshot_bases()
	_initialize_fish_jump_schedule()
	# Deferred: during scene instantiation the parent is still busy setting up
	# children, so adding the cap nodes must wait a frame.
	_build_end_caps.call_deferred()
	_dress_sky.call_deferred()


func _exit_tree() -> void:
	# Drop strong references before renderer/resource teardown. This is especially
	# useful for the large editable Train scene in Compatibility rendering.
	_scenery_roots.clear()
	_boats.clear()
	_fish.clear()
	_birds.clear()
	_tractors.clear()
	_fireflies.clear()
	_flames.clear()
	_smoke.clear()
	_ripples.clear()
	_lighthouse_beams.clear()

	_fish_jump_next.clear()
	_fish_jump_start.clear()
	_fish_jump_duration.clear()
	_fish_jump_height.clear()
	_fish_world_x.clear()
	_fish_world_y.clear()
	_fish_world_start_z.clear()

	_snapshot_clear()


func _dress_sky() -> void:
	# Bluer sky plus drifting clouds. The baked sky material is duplicated
	# first so menu thumbnails and later room visits (which share the cached
	# PackedScene resources) keep the authored sunset look.
	if not is_inside_tree():
		return
	var redesign: Node3D = get_parent() as Node3D
	if redesign == null:
		return
	var world_env: WorldEnvironment = redesign.get_node_or_null("TrainWarmSunsetEnvironment") as WorldEnvironment
	if is_instance_valid(world_env) and world_env.environment != null and world_env.environment.sky != null:
		var sky_material: ProceduralSkyMaterial = world_env.environment.sky.sky_material as ProceduralSkyMaterial
		if sky_material != null:
			var bluer: ProceduralSkyMaterial = sky_material.duplicate()
			bluer.sky_top_color = Color(0.26, 0.44, 0.72, 1.0)
			bluer.sky_horizon_color = Color(0.80, 0.55, 0.52, 1.0)
			bluer.ground_horizon_color = Color(0.58, 0.47, 0.45, 1.0)
			var sky := Sky.new()
			sky.sky_material = bluer
			var environment: Environment = world_env.environment.duplicate()
			environment.sky = sky
			world_env.environment = environment
	preload("res://scripts/world/sky_clouds.gd").build(self, 7, Vector3(60.0, 24.0, 55.0), 0.7)


func _build_end_caps() -> void:
	# The side scenery tiles stop at z=±45 and the carriage floor ends at
	# z=±21, so looking down the corridor past either end of the train shows
	# grey void. These static caps extend the ground to z=±70 with a few
	# distant hills. They are pure visuals: no collision (outside the
	# walkable bounds), no shadows, no x-ray (a 60 m plane must never become
	# an occluder window). Materials are sampled from the existing tiles so
	# the palette matches with zero new assets; flat fallbacks keep clean
	# checkouts working if tile names ever change.
	var redesign: Node3D = get_parent() as Node3D
	if redesign == null or not is_inside_tree():
		return
	var showcase: MeshInstance3D = redesign.get_node_or_null("TrainLoopTile_Left_00/LoopLand") as MeshInstance3D
	var ground_material: Material = showcase.get_active_material(0) if is_instance_valid(showcase) else null
	if ground_material == null:
		var flat := StandardMaterial3D.new()
		flat.albedo_color = Color(0.149, 0.196, 0.161, 1.0)
		flat.roughness = 0.98
		ground_material = flat
	var rock_material: Material = ground_material
	for candidate in redesign.get_node_or_null("TrainLoopTile_Left_00").find_children("*", "MeshInstance3D", true, false) if is_instance_valid(redesign.get_node_or_null("TrainLoopTile_Left_00")) else []:
		if "rockmountain" in str(candidate.name).to_lower():
			var sampled: Material = candidate.get_active_material(0)
			if sampled != null:
				rock_material = sampled
				break
	var caps := Node3D.new()
	caps.name = "TrainEndCaps"
	# Honored by the x-ray eligibility walk: no trimesh proxy, no window.
	caps.set_meta("xray_exclude", true)
	redesign.add_child(caps)
	for side in [-1.0, 1.0]:
		var ground := MeshInstance3D.new()
		ground.name = "EndCapGroundNorth" if side < 0.0 else "EndCapGroundSouth"
		var slab := BoxMesh.new()
		slab.size = Vector3(60.0, 0.5, 50.0)
		ground.mesh = slab
		ground.material_override = ground_material
		# Top at y=-0.95: tucks under the carriage floor end and stays below
		# the side tiles' land/water tops so nothing z-fights.
		ground.position = Vector3(0.0, -1.2, side * 45.0)
		ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		caps.add_child(ground)
		var hill_data: Array = [[-18.0, 58.0, 9.0], [2.0, 63.0, 12.0], [19.0, 57.0, 7.0]]
		for entry in hill_data:
			var hill := MeshInstance3D.new()
			hill.name = "EndCapHill"
			var dome := SphereMesh.new()
			dome.radius = entry[2]
			dome.height = entry[2] * 2.0
			dome.radial_segments = 16
			dome.rings = 8
			hill.mesh = dome
			hill.material_override = rock_material
			hill.scale.y = 0.42
			hill.position = Vector3(entry[0], -0.95, side * entry[1])
			hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			caps.add_child(hill)


func _snapshot_clear() -> void:
	_boat_base_pos.clear()
	_boat_base_rot.clear()
	_boat_phase = PackedFloat32Array()
	_scenery_speed = PackedFloat32Array()
	_fish_base_scale.clear()
	_fish_phase = PackedFloat32Array()
	_fish_speed = PackedFloat32Array()
	_fish_rate = PackedFloat32Array()
	_bird_phase = PackedFloat32Array()
	_bird_cycle = PackedFloat32Array()
	_bird_duration = PackedFloat32Array()
	_bird_start.clear()
	_bird_end.clear()
	_bird_rot.clear()
	_tractor_base.clear()
	_tractor_phase = PackedFloat32Array()
	_tractor_speed = PackedFloat32Array()
	_firefly_base.clear()
	_firefly_phase = PackedFloat32Array()
	_flame_scale.clear()
	_flame_phase = PackedFloat32Array()
	_smoke_base.clear()
	_smoke_phase = PackedFloat32Array()
	_ripple_phase = PackedFloat32Array()
	_beam_speed = PackedFloat32Array()
	_beam_phase = PackedFloat32Array()


func _snapshot_bases() -> void:
	_snapshot_clear()
	for boat: Node3D in _boats:
		_boat_base_pos.append(boat.get_meta("living_base_position", boat.position))
		_boat_base_rot.append(boat.get_meta("living_base_rotation", boat.rotation))
		_boat_phase.append(float(boat.get_meta("living_phase", 0.0)))
	for scenery: Node3D in _scenery_roots:
		_scenery_speed.append(float(scenery.get_meta("parallax_speed", 1.65)))
	for fish: Node3D in _fish:
		_fish_base_scale.append(fish.get_meta("living_base_scale", fish.scale))
		_fish_phase.append(float(fish.get_meta("living_phase", 0.0)))
		_fish_speed.append(float(fish.get_meta("living_speed", 0.42)))
		_fish_rate.append(float(fish.get_meta("living_swim_rate", 3.8)))
	for bird: Node3D in _birds:
		_bird_phase.append(float(bird.get_meta("living_phase", 0.0)))
		_bird_cycle.append(float(bird.get_meta("living_cycle", 24.0)))
		_bird_duration.append(float(bird.get_meta("living_duration", 7.0)))
		_bird_start.append(bird.get_meta("living_start_position", bird.position))
		_bird_end.append(bird.get_meta("living_end_position", bird.position))
		_bird_rot.append(bird.get_meta("living_base_rotation", bird.rotation))
	for tractor: Node3D in _tractors:
		_tractor_base.append(tractor.get_meta("living_base_position", tractor.position))
		_tractor_phase.append(float(tractor.get_meta("living_phase", 0.0)))
		_tractor_speed.append(float(tractor.get_meta("living_speed", 0.20)))
	for firefly: Node3D in _fireflies:
		_firefly_base.append(firefly.get_meta("living_base_position", firefly.position))
		_firefly_phase.append(float(firefly.get_meta("living_phase", 0.0)))
	for flame: Node3D in _flames:
		_flame_scale.append(flame.get_meta("living_base_scale", flame.scale))
		_flame_phase.append(float(flame.get_meta("living_phase", 0.0)))
	for smoke: MeshInstance3D in _smoke:
		_smoke_base.append(smoke.get_meta("living_base_position", smoke.position))
		_smoke_phase.append(float(smoke.get_meta("living_phase", 0.0)))
	for ripple: MeshInstance3D in _ripples:
		_ripple_phase.append(float(ripple.get_meta("living_phase", 0.0)))
	for pivot: Node3D in _lighthouse_beams:
		_beam_speed.append(float(pivot.get_meta("living_speed", 0.24)))
		_beam_phase.append(float(pivot.get_meta("living_phase", 0.0)))


func _collect_runtime_nodes() -> void:
	_scenery_roots = _collect_node3d_group(
		"train_extended_scenery"
	)

	_boats = _collect_node3d_group(
		"train_living_boat"
	)
	_fish = _collect_node3d_group(
		"train_living_fish"
	)
	_birds = _collect_node3d_group(
		"train_living_bird"
	)
	_tractors = _collect_node3d_group(
		"train_living_tractor"
	)
	_fireflies = _collect_node3d_group(
		"train_living_firefly"
	)
	_flames = _collect_node3d_group(
		"train_living_flame"
	)
	_lighthouse_beams = _collect_node3d_group(
		"train_living_lighthouse_beam"
	)

	_smoke.clear()
	for node: Node in get_tree().get_nodes_in_group(
		"train_living_smoke"
	):
		if node is MeshInstance3D:
			_smoke.append(
				node as MeshInstance3D
			)

	_ripples.clear()
	for node: Node in get_tree().get_nodes_in_group(
		"train_living_ripple"
	):
		if node is MeshInstance3D:
			_ripples.append(
				node as MeshInstance3D
			)


func _collect_node3d_group(
	group_name: String
) -> Array[Node3D]:
	var result: Array[Node3D] = []

	for node: Node in get_tree().get_nodes_in_group(
		group_name
	):
		if node is Node3D:
			result.append(
				node as Node3D
			)

	return result


func _process(
	delta: float
) -> void:
	_animate_extended_scenery(
		delta
	)

	_elapsed += delta

	_animate_boats()
	_animate_fish()
	_animate_birds()
	_animate_tractors()
	_animate_fireflies()
	_animate_flames()
	_animate_smoke()
	_animate_ripples()
	_animate_lighthouse_beams()


func _animate_boats() -> void:
	for index: int in range(_boats.size()):
		var boat: Node3D = _boats[index]
		if not is_instance_valid(
			boat
		):
			continue

		var base_position: Vector3 = _boat_base_pos[index]
		var base_rotation: Vector3 = _boat_base_rot[index]
		var phase: float = _boat_phase[index]

		boat.position = (
			base_position
			+ Vector3(
				0.0,
				sin(
					_elapsed * 0.92
					+ phase
				)
				* 0.055,
				sin(
					_elapsed * 0.18
					+ phase
				)
				* 0.72
			)
		)

		boat.rotation = base_rotation
		boat.rotation.x += (
			sin(
				_elapsed * 0.72
				+ phase
			)
			* 0.018
		)
		boat.rotation.z += (
			sin(
				_elapsed * 0.86
				+ phase * 1.3
			)
			* 0.030
		)


func _animate_extended_scenery(
	delta: float
) -> void:
	# The redesigned Train now owns its exterior movement instead of relying on
	# main.gd's legacy 50 m wrap. Ten tiles per side give a 100 m continuous
	# landscape, which prevents the far-camera cutoff visible with five tiles.
	for index: int in range(_scenery_roots.size()):
		var scenery: Node3D = _scenery_roots[index]
		if not is_instance_valid(
			scenery
		):
			continue

		var speed: float = _scenery_speed[index]

		scenery.position.z += (
			delta
			* speed
		)

		if (
			scenery.position.z
			> EXTENDED_SCENERY_HALF_LENGTH
		):
			scenery.position.z -= (
				EXTENDED_SCENERY_WRAP_LENGTH
			)

		elif (
			scenery.position.z
			< -EXTENDED_SCENERY_HALF_LENGTH
		):
			scenery.position.z += (
				EXTENDED_SCENERY_WRAP_LENGTH
			)


func _initialize_fish_jump_schedule() -> void:
	_fish_jump_next.clear()
	_fish_jump_start.clear()
	_fish_jump_duration.clear()
	_fish_jump_height.clear()

	for fish_index: int in range(
		_fish.size()
	):
		var fish: Node3D = _fish[
			fish_index
		]

		if not is_instance_valid(
			fish
		):
			continue

		var key: int = fish.get_instance_id()

		# Store a world-space swimming lane. The fish remain visually continuous
		# even when their parent 10 m scenery tile wraps around the Train.
		_fish_world_x[
			key
		] = fish.global_position.x
		_fish_world_y[
			key
		] = FISH_UNDERWATER_Y
		_fish_world_start_z[
			key
		] = fish.global_position.z

		var forced_position: Vector3 = fish.global_position
		forced_position.y = FISH_UNDERWATER_Y
		fish.global_position = forced_position

		# Stagger the initial launches and add random jitter so the school never
		# jumps as one synchronized group.
		_fish_jump_next[
			key
		] = (
			2.0
			+ float(
				fish_index % 9
			)
			* 0.82
			+ _rng.randf_range(
				0.0,
				5.5
			)
		)


func _start_fish_jump(
	fish: Node3D
) -> void:
	var key: int = fish.get_instance_id()

	_fish_jump_start[
		key
	] = _elapsed

	_fish_jump_duration[
		key
	] = _rng.randf_range(
		0.82,
		1.24
	)

	# This value is the amount of clear air above the water surface at apex.
	_fish_jump_height[
		key
	] = _rng.randf_range(
		0.55,
		0.95
	)

	# Do not schedule the next launch until this jump has landed.
	_fish_jump_next.erase(
		key
	)


func _finish_fish_jump(
	fish: Node3D
) -> void:
	var key: int = fish.get_instance_id()

	_fish_jump_start.erase(
		key
	)
	_fish_jump_duration.erase(
		key
	)
	_fish_jump_height.erase(
		key
	)

	# Independent random wait. With many fish this produces occasional single
	# jumps and small overlaps, but never a synchronized whole-school jump.
	_fish_jump_next[
		key
	] = (
		_elapsed
		+ _rng.randf_range(
			7.0,
			20.0
		)
	)


func _animate_fish() -> void:
	for index: int in range(_fish.size()):
		var fish: Node3D = _fish[index]
		if not is_instance_valid(
			fish
		):
			continue

		var base_scale: Vector3 = _fish_base_scale[index]
		var phase: float = _fish_phase[index]
		var swim_speed: float = _fish_speed[index]
		var swim_rate: float = _fish_rate[index]
		var key: int = fish.get_instance_id()

		var lane_x: float = float(
			_fish_world_x.get(
				key,
				fish.global_position.x
			)
		)
		var underwater_y: float = float(
			_fish_world_y.get(
				key,
				fish.global_position.y
			)
		)
		var start_z: float = float(
			_fish_world_start_z.get(
				key,
				fish.global_position.z
			)
		)

		# Scenery itself travels +Z at 1.65 m/s. Add the fish's own swimming
		# speed on top so it genuinely swims +Z THROUGH the water, i.e. opposite
		# the Train rather than merely being carried by the scenery.
		var world_swim_speed: float = (
			TRAIN_SCENERY_SPEED
			+ swim_speed
		)

		# Use the full 100 m exterior loop instead of the old ~8 m local wrap.
		# Any wrap now occurs at the distant ends of the scenery, eliminating the
		# nearby sudden-disappearance effect.
		var world_z: float = wrapf(
			start_z
			+ _elapsed
			* world_swim_speed,
			FISH_WRAP_MIN_Z,
			FISH_WRAP_MAX_Z
		)

		var swim_phase: float = (
			_elapsed * swim_rate
			+ phase * 1.7
		)

		var lateral_sway: float = (
			sin(
				swim_phase
			)
			* 0.085
		)

		var depth_bob: float = (
			sin(
				swim_phase * 0.52
				+ phase
			)
			* 0.016
		)

		var jump_y: float = 0.0
		var jump_pitch: float = 0.0

		if (
			not _fish_jump_start.has(
				key
			)
			and _fish_jump_next.has(
				key
			)
			and _elapsed
				>= float(
					_fish_jump_next[
						key
					]
				)
		):
			_start_fish_jump(
				fish
			)

		if _fish_jump_start.has(
			key
		):
			var jump_start: float = float(
				_fish_jump_start[
					key
				]
			)
			var jump_duration: float = float(
				_fish_jump_duration[
					key
				]
			)
			var jump_height: float = float(
				_fish_jump_height[
					key
				]
			)

			var jump_progress: float = (
				(
					_elapsed
					- jump_start
				)
				/ maxf(
					jump_duration,
					0.001
				)
			)

			if jump_progress >= 1.0:
				_finish_fish_jump(
					fish
				)
			else:
				# `jump_height` is extra clearance ABOVE the water. Add the
				# submerged-to-surface distance so every jump necessarily breaks
				# the surface, even for the deepest fish.
				var total_jump_height: float = (
					(
						WATER_SURFACE_Y
						- underwater_y
					)
					+ jump_height
				)

				jump_y = (
					sin(
						jump_progress
						* PI
					)
					* total_jump_height
				)

				# Nose up during ascent, flatten around the apex, nose down on
				# re-entry.
				jump_pitch = (
					sin(
						jump_progress
						* TAU
					)
					* 0.36
				)

		fish.global_position = Vector3(
			lane_x
			+ lateral_sway,
			underwater_y
			+ depth_bob
			+ jump_y,
			world_z
		)

		# v4-established visual orientation: this archive fish mesh points +Z
		# when yaw is 0.
		fish.global_rotation = Vector3(
			jump_pitch,
			0.0,
			0.0
		)

		fish.rotation.y += (
			sin(
				swim_phase
			)
			* 0.105
		)

		fish.rotation.z = (
			cos(
				swim_phase
			)
			* 0.030
		)

		var flex: float = (
			sin(
				swim_phase
			)
			* 0.018
		)

		fish.scale = Vector3(
			base_scale.x
			* (
				1.0
				+ flex
			),
			base_scale.y,
			base_scale.z
			* (
				1.0
				- flex
			)
		)

func _animate_birds() -> void:
	for index: int in range(_birds.size()):
		var bird: Node3D = _birds[index]
		if not is_instance_valid(
			bird
		):
			continue

		var phase: float = _bird_phase[index]
		var cycle: float = _bird_cycle[index]
		var duration: float = _bird_duration[index]

		var active_time: float = fposmod(
			_elapsed + phase,
			cycle
		)

		bird.visible = (
			active_time <= duration
		)

		if not bird.visible:
			continue

		var progress: float = clampf(
			active_time
			/ maxf(
				duration,
				0.001
			),
			0.0,
			1.0
		)

		var start_position: Vector3 = _bird_start[index]
		var end_position: Vector3 = _bird_end[index]

		bird.position = start_position.lerp(
			end_position,
			progress
		)

		bird.position.y += (
			sin(
				progress * TAU * 3.0
				+ phase
			)
			* 0.12
		)

		bird.position.z += (
			sin(
				progress * PI
			)
			* 0.70
		)

		var base_rotation: Vector3 = _bird_rot[index]

		bird.rotation = base_rotation
		bird.rotation.z += (
			sin(
				progress * TAU * 2.0
				+ phase
			)
			* 0.085
		)


func _animate_tractors() -> void:
	for index: int in range(_tractors.size()):
		var tractor: Node3D = _tractors[index]
		if not is_instance_valid(
			tractor
		):
			continue

		var base_position: Vector3 = _tractor_base[index]
		var phase: float = _tractor_phase[index]
		var speed: float = _tractor_speed[index]

		var travel: float = fposmod(
			_elapsed * speed
			+ phase,
			8.0
		)

		tractor.position = Vector3(
			base_position.x,
			base_position.y
			+ sin(
				_elapsed * 1.2
				+ phase
			)
			* 0.008,
			lerpf(
				-4.0,
				4.0,
				travel / 8.0
			)
		)


func _animate_fireflies() -> void:
	for index: int in range(_fireflies.size()):
		var firefly: Node3D = _fireflies[index]
		if not is_instance_valid(
			firefly
		):
			continue

		var base_position: Vector3 = _firefly_base[index]
		var phase: float = _firefly_phase[index]

		firefly.position = (
			base_position
			+ Vector3(
				sin(
					_elapsed * 0.61
					+ phase
				)
				* 0.52,
				sin(
					_elapsed * 0.83
					+ phase * 1.7
				)
				* 0.28,
				cos(
					_elapsed * 0.57
					+ phase
				)
				* 0.62
			)
		)

		var pulse: float = (
			0.72
			+ (
				sin(
					_elapsed * 2.4
					+ phase
				)
				+ 1.0
			)
			* 0.22
		)

		firefly.scale = Vector3.ONE * pulse


func _animate_flames() -> void:
	for index: int in range(_flames.size()):
		var flame: Node3D = _flames[index]
		if not is_instance_valid(
			flame
		):
			continue

		var base_scale: Vector3 = _flame_scale[index]
		var phase: float = _flame_phase[index]

		flame.scale = Vector3(
			base_scale.x
			* (
				0.88
				+ sin(
					_elapsed * 5.2
					+ phase
				)
				* 0.10
			),
			base_scale.y
			* (
				0.92
				+ sin(
					_elapsed * 6.8
					+ phase
				)
				* 0.18
			),
			base_scale.z
			* (
				0.88
				+ cos(
					_elapsed * 5.7
					+ phase
				)
				* 0.10
			)
		)

		flame.rotation.y += 0.015


func _animate_smoke() -> void:
	for index: int in range(_smoke.size()):
		var smoke: MeshInstance3D = _smoke[index]
		if not is_instance_valid(
			smoke
		):
			continue

		var base_position: Vector3 = _smoke_base[index]
		var phase: float = _smoke_phase[index]

		var progress: float = fposmod(
			_elapsed * 0.26
			+ phase,
			1.0
		)

		smoke.position = (
			base_position
			+ Vector3(
				sin(
					progress * TAU
					+ phase
				)
				* 0.13,
				progress * 1.10,
				cos(
					progress * TAU
					+ phase
				)
				* 0.08
			)
		)

		smoke.scale = Vector3.ONE * (
			0.45
			+ progress * 0.85
		)

		# All smoke puffs now share one material. Fade per instance instead of
		# mutating the shared material resource.
		smoke.transparency = clampf(
			0.10
			+ progress * 0.90,
			0.0,
			1.0
		)


func _animate_ripples() -> void:
	for index: int in range(_ripples.size()):
		var ripple: MeshInstance3D = _ripples[index]
		if not is_instance_valid(
			ripple
		):
			continue

		var phase: float = _ripple_phase[index]

		var progress: float = fposmod(
			_elapsed * 0.21
			+ phase,
			1.0
		)

		var size_value: float = (
			0.38
			+ progress * 0.92
		)

		ripple.scale = Vector3(
			size_value,
			1.0,
			size_value
		)

		# Shared ripple material; only per-instance transparency changes.
		ripple.transparency = clampf(
			progress,
			0.0,
			1.0
		)


func _animate_lighthouse_beams() -> void:
	for index: int in range(_lighthouse_beams.size()):
		var pivot: Node3D = _lighthouse_beams[index]
		if not is_instance_valid(
			pivot
		):
			continue

		var speed: float = _beam_speed[index]
		var phase: float = _beam_phase[index]

		pivot.rotation.y = (
			_elapsed * speed
			+ phase
		)
