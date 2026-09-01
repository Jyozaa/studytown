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

func setup(follow_target: Node3D, settings: Dictionary) -> Camera3D:
	target = follow_target
	offset = settings.get("camera_offset", offset)
	look_height = float(settings.get("camera_look_height", look_height))
	position_damping = float(settings.get("camera_damping", position_damping))
	camera = Camera3D.new()
	camera.name = "ExplorationCamera"
	camera.fov = float(settings.get("camera_fov", 38.0))
	camera.cull_mask = 0xFFFFF
	add_child(camera)
	var look := target.global_position + Vector3.UP * look_height
	global_position = look + offset
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
	global_position = global_position.lerp(_resolve_obstruction(desired_look, desired_position), weight)
	smoothed_look = smoothed_look.lerp(desired_look, 1.0 - exp(-look_damping * delta))
	look_at(smoothed_look, Vector3.UP)

func _resolve_obstruction(from: Vector3, desired: Vector3) -> Vector3:
	if not is_inside_tree():
		return desired
	var query := PhysicsRayQueryParameters3D.create(from, desired, 1)
	if target is CollisionObject3D:
		query.exclude = [target.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return desired
	var normal: Vector3 = hit.get("normal", Vector3.UP)
	return hit.get("position", desired) + normal * collision_margin
