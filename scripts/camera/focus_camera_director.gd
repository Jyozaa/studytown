class_name FocusCameraDirector
extends Node

var transition_camera: Camera3D
var active_tween: Tween
var clearance_provider: Node3D
var last_transition_clear := true

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
	var destination: WeakRef = weakref(to_camera)
	var route: Array[Vector3] = [to_camera.global_position]
	if is_instance_valid(clearance_provider):
		route = clearance_provider.transition_route(from_camera.global_position, to_camera.global_position)
	last_transition_clear = not route.is_empty()
	if route.is_empty():
		from_camera.make_current()
		push_warning("Rejected camera transition through Garden geometry: %s -> %s (destination lens clear: %s)" % [from_camera.global_position, to_camera.global_position, clearance_provider.lens_clear(to_camera.global_position)])
		return
	active_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	for i in route.size():
		var end := to_camera.global_transform
		end.origin = route[i]
		active_tween.tween_property(transition_camera, "global_transform", end, duration / route.size())
		active_tween.parallel().tween_property(transition_camera, "fov", to_camera.fov, duration / route.size())
	active_tween.chain().tween_callback(func():
		var resolved = destination.get_ref()
		if is_instance_valid(resolved):
			resolved.current = true
	)
