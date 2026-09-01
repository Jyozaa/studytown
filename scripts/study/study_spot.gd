class_name StudySpot
extends Node3D

var standing_position := Vector3.ZERO
var sitting_position := Vector3.ZERO
var facing_yaw := 0.0
var study_type := "Laptop"
var camera_position := Vector3.ZERO
var camera_target := Vector3.ZERO
var debug_visual: Node3D

func configure(standing: Vector3, sitting: Vector3, yaw: float, kind: String, camera_pos: Vector3, target: Vector3) -> void:
	standing_position = standing
	sitting_position = sitting
	facing_yaw = yaw
	study_type = kind
	camera_position = camera_pos
	camera_target = target
