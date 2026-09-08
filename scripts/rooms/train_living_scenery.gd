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


func _ready() -> void:
	_rng.randomize()
	_collect_runtime_nodes()
	_initialize_fish_jump_schedule()


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
	for boat: Node3D in _boats:
		if not is_instance_valid(
			boat
		):
			continue

		var base_position: Vector3 = boat.get_meta(
			"living_base_position",
			boat.position
		)
		var base_rotation: Vector3 = boat.get_meta(
			"living_base_rotation",
			boat.rotation
		)
		var phase: float = float(
			boat.get_meta(
				"living_phase",
				0.0
			)
		)

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
	for scenery: Node3D in _scenery_roots:
		if not is_instance_valid(
			scenery
		):
			continue

		var speed: float = float(
			scenery.get_meta(
				"parallax_speed",
				1.65
			)
		)

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
	for fish: Node3D in _fish:
		if not is_instance_valid(
			fish
		):
			continue

		var base_scale: Vector3 = fish.get_meta(
			"living_base_scale",
			fish.scale
		)
		var phase: float = float(
			fish.get_meta(
				"living_phase",
				0.0
			)
		)
		var swim_speed: float = float(
			fish.get_meta(
				"living_speed",
				0.42
			)
		)
		var swim_rate: float = float(
			fish.get_meta(
				"living_swim_rate",
				3.8
			)
		)
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
	for bird: Node3D in _birds:
		if not is_instance_valid(
			bird
		):
			continue

		var phase: float = float(
			bird.get_meta(
				"living_phase",
				0.0
			)
		)
		var cycle: float = float(
			bird.get_meta(
				"living_cycle",
				24.0
			)
		)
		var duration: float = float(
			bird.get_meta(
				"living_duration",
				7.0
			)
		)

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

		var start_position: Vector3 = bird.get_meta(
			"living_start_position",
			bird.position
		)
		var end_position: Vector3 = bird.get_meta(
			"living_end_position",
			bird.position
		)

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

		var base_rotation: Vector3 = bird.get_meta(
			"living_base_rotation",
			bird.rotation
		)

		bird.rotation = base_rotation
		bird.rotation.z += (
			sin(
				progress * TAU * 2.0
				+ phase
			)
			* 0.085
		)


func _animate_tractors() -> void:
	for tractor: Node3D in _tractors:
		if not is_instance_valid(
			tractor
		):
			continue

		var base_position: Vector3 = tractor.get_meta(
			"living_base_position",
			tractor.position
		)
		var phase: float = float(
			tractor.get_meta(
				"living_phase",
				0.0
			)
		)
		var speed: float = float(
			tractor.get_meta(
				"living_speed",
				0.20
			)
		)

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
	for firefly: Node3D in _fireflies:
		if not is_instance_valid(
			firefly
		):
			continue

		var base_position: Vector3 = firefly.get_meta(
			"living_base_position",
			firefly.position
		)
		var phase: float = float(
			firefly.get_meta(
				"living_phase",
				0.0
			)
		)

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
	for flame: Node3D in _flames:
		if not is_instance_valid(
			flame
		):
			continue

		var base_scale: Vector3 = flame.get_meta(
			"living_base_scale",
			flame.scale
		)
		var phase: float = float(
			flame.get_meta(
				"living_phase",
				0.0
			)
		)

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
	for smoke: MeshInstance3D in _smoke:
		if not is_instance_valid(
			smoke
		):
			continue

		var base_position: Vector3 = smoke.get_meta(
			"living_base_position",
			smoke.position
		)
		var phase: float = float(
			smoke.get_meta(
				"living_phase",
				0.0
			)
		)

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
	for ripple: MeshInstance3D in _ripples:
		if not is_instance_valid(
			ripple
		):
			continue

		var phase: float = float(
			ripple.get_meta(
				"living_phase",
				0.0
			)
		)

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
	for pivot: Node3D in _lighthouse_beams:
		if not is_instance_valid(
			pivot
		):
			continue

		var speed: float = float(
			pivot.get_meta(
				"living_speed",
				0.24
			)
		)
		var phase: float = float(
			pivot.get_meta(
				"living_phase",
				0.0
			)
		)

		pivot.rotation.y = (
			_elapsed * speed
			+ phase
		)
