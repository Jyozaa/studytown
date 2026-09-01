class_name PlayerController
extends CharacterBody3D

signal locomotion_changed(state: String)

@export var move_speed := 4.15
@export var acceleration := 16.0
@export var deceleration := 20.0
@export var rotation_speed := 10.0
@export var floor_snap := 0.35

var movement_enabled := true
var spawn_transform := Transform3D.IDENTITY
var respawn_depth := -12.0
var current_locomotion := "Idle"
var movement_camera: Camera3D

func _ready() -> void:
	floor_snap_length = floor_snap
	floor_max_angle = deg_to_rad(46.0)
	collision_layer = 2
	collision_mask = 1

func configure_spawn(value: Transform3D) -> void:
	spawn_transform = value
	global_transform = value
	respawn_depth = value.origin.y - 12.0

func set_movement_enabled(value: bool) -> void:
	movement_enabled = value
	if not value:
		velocity = Vector3.ZERO
		_set_locomotion("Idle")

func set_movement_camera(value: Camera3D) -> void:
	movement_camera = value

func get_camera_relative_direction(input: Vector2) -> Vector3:
	if not is_instance_valid(movement_camera):
		return Vector3(input.x, 0.0, input.y).normalized()
	var forward := -movement_camera.global_basis.z
	var right := movement_camera.global_basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	return (right * input.x + forward * -input.y).normalized()

func _physics_process(delta: float) -> void:
	if not movement_enabled:
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := get_camera_relative_direction(input)
	var target_velocity := direction * move_speed
	var rate := acceleration if direction.length_squared() > 0.0 else deceleration
	velocity.x = move_toward(velocity.x, target_velocity.x, rate * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, rate * delta)
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
	else:
		var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
		velocity.y -= gravity * delta
	if direction.length_squared() > 0.001:
		var target_yaw := atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, rotation_speed * delta)
		_set_locomotion("Walk")
	elif Vector2(velocity.x, velocity.z).length() < 0.12:
		_set_locomotion("Idle")
	move_and_slide()
	if global_position.y < respawn_depth:
		global_transform = spawn_transform
		velocity = Vector3.ZERO

func _set_locomotion(value: String) -> void:
	if current_locomotion == value:
		return
	current_locomotion = value
	locomotion_changed.emit(value)
