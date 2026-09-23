class_name FollowCamera
extends Node3D

@export var position_damping := 7.5
@export var look_damping := 9.0
@export var collision_margin := 0.45

var target: Node3D
var camera: Camera3D
var offset := Vector3(8.5, 8.5, 8.5)
var look_height := 1.2
var look_ahead := 0.32
var smoothed_look := Vector3.ZERO
var horizontal_camera_bounds := Vector2(INF, INF)
var vertical_camera_bounds := Vector2(-INF, INF)
var last_safe_position := Vector3.ZERO
var has_safe_position := false
var physical_correction := false
var lens_radius := 0.28
var lens_shape := SphereShape3D.new()
var shape_query := PhysicsShapeQueryParameters3D.new()


func setup(follow_target: Node3D, settings: Dictionary) -> Camera3D:
	target = follow_target
	offset = settings.get("camera_offset", offset)
	look_height = float(settings.get("camera_look_height", look_height))
	position_damping = float(settings.get("camera_damping", position_damping))
	if str(settings.get("id", "")) == "train":
		# Narrow carriage: keep the envelope at the side walls and ends so
		# seat-entry transitions always start inside flyable space, but raise
		# the ceiling to match the other rooms' elevated framing (open car).
		horizontal_camera_bounds = settings.bounds - Vector2.ONE * 0.3
		vertical_camera_bounds = Vector2(1.1, 12.5)
	camera = Camera3D.new()
	camera.name = "ExplorationCamera"
	camera.fov = float(settings.get("camera_fov", 38.0))
	camera.cull_mask = 0xFFFFF
	add_child(camera)
	var look := target.global_position + Vector3.UP * look_height
	global_position = clamp_position(look + offset)
	smoothed_look = look
	look_at(look, Vector3.UP)
	camera.current = true
	return camera


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target) or not is_instance_valid(camera):
		return
	var velocity_hint := Vector3.ZERO
	if target is CharacterBody3D:
		velocity_hint = target.velocity * look_ahead
	var desired_look := target.global_position + Vector3.UP * look_height + velocity_hint
	var desired_position := desired_look + offset
	var weight := 1.0 - exp(-position_damping * delta)
	var destination := global_position.lerp(_resolve_obstruction(desired_look, desired_position), weight)
	# Sweep the lens's frame-to-frame motion, not the character sightline.
	if within_bounds(global_position) and lens_is_clear(global_position):
		var query := lens_query(global_position)
		query.motion = destination - global_position
		var travel := get_world_3d().direct_space_state.cast_motion(query)
		if travel[0] < 1.0:
			destination = global_position.lerp(destination, maxf(0.0, travel[0] - 0.02))
			physical_correction = true
	else:
		# Recover an initially embedded lens immediately, not through several
		# interpolated frames inside the mesh.
		destination = _resolve_obstruction(desired_look, desired_position)
	global_position = destination
	if within_bounds(destination) and lens_is_clear(destination):
		last_safe_position = destination
		has_safe_position = true
	smoothed_look = smoothed_look.lerp(desired_look, 1.0 - exp(-look_damping * delta))
	if global_position.distance_squared_to(smoothed_look) > 0.0001:
		look_at(smoothed_look, Vector3.UP)


func _resolve_obstruction(_from: Vector3, desired: Vector3) -> Vector3:
	desired = clamp_position(desired)
	physical_correction = not lens_is_clear(desired)
	if not physical_correction: return desired
	for distance in [0.35, 0.7, 1.1, 1.6, 2.2, 3.0, 4.0]:
		for direction in [Vector3.UP, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK, Vector3.DOWN,
			Vector3(-1, 0, -1).normalized(), Vector3(-1, 0, 1).normalized(), Vector3(1, 0, -1).normalized(), Vector3(1, 0, 1).normalized()]:
			var candidate: Vector3 = desired + direction * distance
			if not within_bounds(candidate): continue
			if lens_is_clear(candidate): return candidate
	if has_safe_position and within_bounds(last_safe_position) and lens_is_clear(last_safe_position): return last_safe_position
	return global_position if within_bounds(global_position) and lens_is_clear(global_position) else desired


func clamp_position(position: Vector3) -> Vector3:
	return Vector3(clampf(position.x, -horizontal_camera_bounds.x, horizontal_camera_bounds.x),
		clampf(position.y, vertical_camera_bounds.x, vertical_camera_bounds.y),
		clampf(position.z, -horizontal_camera_bounds.y, horizontal_camera_bounds.y))


func within_bounds(position: Vector3) -> bool:
	return position.is_equal_approx(clamp_position(position))


func lens_query(position: Vector3) -> PhysicsShapeQueryParameters3D:
	var query := shape_query
	query.motion = Vector3.ZERO
	lens_shape.radius = lens_radius
	query.shape = lens_shape
	query.transform.origin = position
	query.collision_mask = 17
	if target is CollisionObject3D: query.exclude = [target.get_rid()]
	return query


func lens_is_clear(position: Vector3) -> bool:
	if not is_inside_tree(): return true
	return get_world_3d().direct_space_state.intersect_shape(lens_query(position), 1).is_empty()


func raycast_obstructions(from: Vector3, to: Vector3, mask := 1) -> Dictionary:
	if not is_inside_tree():
		return {}
	var query := PhysicsRayQueryParameters3D.create(from, to, mask)
	if target is CollisionObject3D:
		query.exclude = [target.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	# Invisible limits constrain walking, not the camera or presence badges.
	# Actual walls and furniture still participate in obstruction tests.
	for _attempt in 8:
		if hit.is_empty():
			break
		var collider = hit.get("collider")
		if (
			not is_instance_valid(collider)
			or not (
				(
					str(collider.name)
					in ["NorthBoundary", "SouthBoundary", "EastBoundary", "WestBoundary"]
				)
				or bool(collider.get_meta("camera_passthrough", false))
			)
		):
			break
		var excluded := query.exclude
		excluded.append(collider.get_rid())
		query.exclude = excluded
		hit = get_world_3d().direct_space_state.intersect_ray(query)
	return hit
