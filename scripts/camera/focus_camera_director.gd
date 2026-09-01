class_name FocusCameraDirector
extends Node

var transition_camera: Camera3D
var active_tween: Tween

func transition(from_camera: Camera3D, to_camera: Camera3D, duration := 0.65) -> void:
	if not is_instance_valid(from_camera) or not is_instance_valid(to_camera):
		return
	if is_instance_valid(active_tween):
		active_tween.kill()
	if not is_instance_valid(transition_camera):
		transition_camera = Camera3D.new()
		transition_camera.name = "CameraTransition"
		add_child(transition_camera)
	transition_camera.global_transform = from_camera.global_transform
	transition_camera.fov = from_camera.fov
	transition_camera.current = true
	active_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	active_tween.tween_property(transition_camera, "global_transform", to_camera.global_transform, duration)
	active_tween.tween_property(transition_camera, "fov", to_camera.fov, duration)
	active_tween.chain().tween_callback(func(): to_camera.current = true)
