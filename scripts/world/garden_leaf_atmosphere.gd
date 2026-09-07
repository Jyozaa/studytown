extends Node3D

# Whole-map StudyTown Garden leaf atmosphere.
#
# Uses a REAL leaf card extracted from FenceIkegaki:
#   garden_falling_leaf.glb
#
# Two efficient MultiMeshes are used:
# - StaticLeafScatter: hundreds of permanent leaves across the whole Garden.
# - FallingLeaves: live leaves spawned around trees; once they reach ground they
#   vanish briefly, then a new leaf appears at another tree.
#
# No individual leaf Nodes are created at runtime.

@export var leaf_scene_path := (
	"res://assets/dev_local/blender_generated/runtime/"
	+ "garden_falling_leaf.glb"
)

@export var static_leaf_count := 950
@export var falling_leaf_count := 150

# Covers the expanded Garden world rather than only the playable 52 x 38 area.
@export var map_half_extent := Vector2(108.0, 92.0)

@export var fallback_ground_y := 0.035

@export var minimum_fall_speed := 0.55
@export var maximum_fall_speed := 1.05

@export var wind := Vector3(0.16, 0.0, 0.055)

var _rng := RandomNumberGenerator.new()

var _leaf_mesh: Mesh

var _tree_positions: Array[Vector3] = []

var _static_multimesh: MultiMesh
var _fall_multimesh: MultiMesh

var _fall_position: Array[Vector3] = []
var _fall_velocity: Array[Vector3] = []
var _fall_angles: Array[Vector3] = []
var _fall_spin: Array[Vector3] = []
var _fall_scale: Array[float] = []
var _fall_ground_y: Array[float] = []
var _fall_cooldown: Array[float] = []


func _ready() -> void:
	_rng.seed = 824731

	_leaf_mesh = _load_leaf_mesh()

	if _leaf_mesh == null:
		push_error(
			"GardenLeafAtmosphere could not load leaf mesh: "
			+ leaf_scene_path
		)
		set_process(false)
		return

	_collect_tree_positions(
		get_tree().current_scene
	)

	_build_static_scatter()
	_build_falling_leaves()

	set_process(true)


func _process(delta: float) -> void:
	if _fall_multimesh == null:
		return

	for index in range(
		falling_leaf_count
	):
		if _fall_cooldown[index] > 0.0:
			_fall_cooldown[index] -= delta

			_fall_multimesh.set_instance_transform(
				index,
				_hidden_transform()
			)

			if _fall_cooldown[index] <= 0.0:
				_respawn_falling_leaf(
					index,
					false
				)

			continue

		var position := _fall_position[index]
		var velocity := _fall_velocity[index]

		# Gentle layered wind so motion does not look mechanically linear.
		var phase := (
			Time.get_ticks_msec()
			* 0.001
			+ float(index) * 0.73
		)

		var flutter := Vector3(
			sin(phase * 1.31) * 0.055,
			0.0,
			cos(phase * 1.07) * 0.045
		)

		position += (
			velocity
			+ wind
			+ flutter
		) * delta

		var angles := _fall_angles[index]
		angles += _fall_spin[index] * delta

		_fall_position[index] = position
		_fall_angles[index] = angles

		if position.y <= _fall_ground_y[index]:
			# The leaf genuinely vanishes at the floor. A short invisible
			# cooldown prevents the respawn from reading as a teleport.
			_fall_cooldown[index] = _rng.randf_range(
				0.20,
				0.95
			)

			_fall_multimesh.set_instance_transform(
				index,
				_hidden_transform()
			)

			continue

		_fall_multimesh.set_instance_transform(
			index,
			_leaf_transform(
				position,
				angles,
				_fall_scale[index]
			)
		)


func _load_leaf_mesh() -> Mesh:
	if not ResourceLoader.exists(
		leaf_scene_path
	):
		return null

	var packed := load(
		leaf_scene_path
	) as PackedScene

	if packed == null:
		return null

	var temporary := packed.instantiate()

	if temporary == null:
		return null

	var found := _find_first_mesh(
		temporary
	)

	var result: Mesh = null

	if found != null:
		result = found.duplicate(
			true
		) as Mesh

	temporary.free()

	return result


func _find_first_mesh(
	node: Node
) -> Mesh:
	if (
		node is MeshInstance3D
		and (node as MeshInstance3D).mesh != null
	):
		return (
			node as MeshInstance3D
		).mesh

	for child: Node in node.get_children():
		var found := _find_first_mesh(
			child
		)

		if found != null:
			return found

	return null


func _collect_tree_positions(
	root: Node
) -> void:
	_tree_positions.clear()

	if root == null:
		return

	_collect_tree_positions_recursive(
		root
	)

	print(
		"STUDYTOWN_LEAF_ATMOSPHERE trees=",
		_tree_positions.size()
	)


func _collect_tree_positions_recursive(
	node: Node
) -> void:
	if node is Node3D:
		var node_3d := node as Node3D

		if _looks_like_tree(
			node_3d
		):
			_tree_positions.append(
				node_3d.global_position
			)

	for child: Node in node.get_children():
		_collect_tree_positions_recursive(
			child
		)


func _looks_like_tree(
	node: Node3D
) -> bool:
	var lowered := str(
		node.name
	).to_lower()

	if (
		"rug" in lowered
		or "stump" in lowered
		or "log" in lowered
		or "shadow" in lowered
	):
		return false

	if lowered.begins_with(
		"naturaloak_"
	):
		return true

	if lowered.begins_with(
		"foresttree"
	):
		return true

	if lowered.begins_with(
		"gardenoak"
	):
		return true

	if (
		"oak_tree" in lowered
		or "oaktree" in lowered
	):
		return true

	if lowered in [
		"bigtree",
		"gardenbigtree",
		"garden_big_tree",
	]:
		return true

	return false


func _build_static_scatter() -> void:
	var node := MultiMeshInstance3D.new()
	node.name = "StaticLeafScatter"

	_static_multimesh = MultiMesh.new()
	_static_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_static_multimesh.mesh = _leaf_mesh
	_static_multimesh.instance_count = static_leaf_count

	node.multimesh = _static_multimesh
	add_child(node)

	for index in range(
		static_leaf_count
	):
		var position := _static_leaf_position()

		var angles := Vector3(
			_rng.randf_range(
				-0.20,
				0.20
			),
			_rng.randf_range(
				0.0,
				TAU
			),
			_rng.randf_range(
				-0.20,
				0.20
			)
		)

		var scale_value := _rng.randf_range(
			0.72,
			1.24
		)

		_static_multimesh.set_instance_transform(
			index,
			_leaf_transform(
				position,
				angles,
				scale_value
			)
		)


func _static_leaf_position() -> Vector3:
	# Most permanent leaves cluster naturally under/near trees.
	if (
		not _tree_positions.is_empty()
		and _rng.randf() < 0.80
	):
		var tree_position := _random_tree_position()

		var angle := _rng.randf_range(
			0.0,
			TAU
		)

		var radius := _rng.randf_range(
			0.55,
			5.7
		)

		return Vector3(
			tree_position.x
			+ cos(angle) * radius,
			tree_position.y + 0.035,
			tree_position.z
			+ sin(angle) * radius
		)

	# The remaining twenty percent are distributed across the WHOLE expanded
	# map so the atmosphere does not abruptly stop between tree clusters.
	return Vector3(
		_rng.randf_range(
			-map_half_extent.x,
			map_half_extent.x
		),
		fallback_ground_y,
		_rng.randf_range(
			-map_half_extent.y,
			map_half_extent.y
		)
	)


func _build_falling_leaves() -> void:
	var node := MultiMeshInstance3D.new()
	node.name = "FallingLeaves"

	_fall_multimesh = MultiMesh.new()
	_fall_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_fall_multimesh.mesh = _leaf_mesh
	_fall_multimesh.instance_count = falling_leaf_count

	node.multimesh = _fall_multimesh
	add_child(node)

	_fall_position.resize(
		falling_leaf_count
	)
	_fall_velocity.resize(
		falling_leaf_count
	)
	_fall_angles.resize(
		falling_leaf_count
	)
	_fall_spin.resize(
		falling_leaf_count
	)
	_fall_scale.resize(
		falling_leaf_count
	)
	_fall_ground_y.resize(
		falling_leaf_count
	)
	_fall_cooldown.resize(
		falling_leaf_count
	)

	for index in range(
		falling_leaf_count
	):
		_respawn_falling_leaf(
			index,
			true
		)


func _respawn_falling_leaf(
	index: int,
	initial_distribution: bool
) -> void:
	var tree_position := _random_tree_position()

	var crown_angle := _rng.randf_range(
		0.0,
		TAU
	)

	var crown_radius := _rng.randf_range(
		0.35,
		2.65
	)

	var ground_y := (
		tree_position.y
		+ 0.035
	)

	var spawn_height: float

	if initial_distribution:
		# At scene start, distribute leaves through their whole fall so the
		# effect already looks established.
		spawn_height = _rng.randf_range(
			0.65,
			6.2
		)
	else:
		spawn_height = _rng.randf_range(
			4.2,
			6.7
		)

	var position := Vector3(
		tree_position.x
		+ cos(crown_angle) * crown_radius,
		ground_y + spawn_height,
		tree_position.z
		+ sin(crown_angle) * crown_radius
	)

	var velocity := Vector3(
		_rng.randf_range(
			-0.11,
			0.11
		),
		-_rng.randf_range(
			minimum_fall_speed,
			maximum_fall_speed
		),
		_rng.randf_range(
			-0.11,
			0.11
		)
	)

	var angles := Vector3(
		_rng.randf_range(
			0.0,
			TAU
		),
		_rng.randf_range(
			0.0,
			TAU
		),
		_rng.randf_range(
			0.0,
			TAU
		)
	)

	var spin := Vector3(
		_rng.randf_range(
			-1.7,
			1.7
		),
		_rng.randf_range(
			-2.4,
			2.4
		),
		_rng.randf_range(
			-1.7,
			1.7
		)
	)

	_fall_position[index] = position
	_fall_velocity[index] = velocity
	_fall_angles[index] = angles
	_fall_spin[index] = spin
	_fall_scale[index] = _rng.randf_range(
		0.78,
		1.20
	)
	_fall_ground_y[index] = ground_y
	_fall_cooldown[index] = 0.0

	_fall_multimesh.set_instance_transform(
		index,
		_leaf_transform(
			position,
			angles,
			_fall_scale[index]
		)
	)


func _random_tree_position() -> Vector3:
	if not _tree_positions.is_empty():
		return _tree_positions[
			_rng.randi_range(
				0,
				_tree_positions.size() - 1
			)
		]

	# Fallback if a future Garden changes all tree node names.
	return Vector3(
		_rng.randf_range(
			-map_half_extent.x,
			map_half_extent.x
		),
		fallback_ground_y,
		_rng.randf_range(
			-map_half_extent.y,
			map_half_extent.y
		)
	)


func _leaf_transform(
	position: Vector3,
	angles: Vector3,
	scale_value: float
) -> Transform3D:
	var basis := Basis.IDENTITY

	basis = basis.rotated(
		Vector3.RIGHT,
		angles.x
	)

	basis = basis.rotated(
		Vector3.UP,
		angles.y
	)

	basis = basis.rotated(
		Vector3.FORWARD,
		angles.z
	)

	basis = basis.scaled(
		Vector3.ONE
		* scale_value
	)

	return Transform3D(
		basis,
		position
	)


func _hidden_transform() -> Transform3D:
	return Transform3D(
		Basis.IDENTITY.scaled(
			Vector3.ZERO
		),
		Vector3.ZERO
	)
