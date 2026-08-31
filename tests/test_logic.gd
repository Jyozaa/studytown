extends SceneTree

var failures := 0

func _initialize() -> void:
	_test_facing()
	_test_focus_timestamp()
	_test_duration_validation()
	if failures == 0:
		print("StudyTown logic tests: 13 passed")
		quit(0)
	else:
		printerr("StudyTown logic tests: %d failed" % failures)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _test_facing() -> void:
	var directions := [
		Vector3(0,0,-1), Vector3(0,0,1), Vector3(-1,0,0), Vector3(1,0,0),
		Vector3(-1,0,-1).normalized(), Vector3(1,0,-1).normalized(),
		Vector3(-1,0,1).normalized(), Vector3(1,0,1).normalized(),
	]
	for direction in directions:
		var yaw := atan2(-direction.x, -direction.z)
		var forward := Basis(Vector3.UP, yaw) * Vector3.FORWARD
		_check(forward.dot(direction) > 0.999, "-Z forward must face %s" % direction)

func _test_focus_timestamp() -> void:
	var manager := preload("res://autoload/focus_manager.gd").new()
	root.add_child(manager)
	manager.start_session("Test", 2)
	_check(manager.get_remaining_seconds() > 0 and manager.get_remaining_seconds() <= 2, "timestamp timer starts in range")
	_check(manager.end_timestamp > Time.get_unix_time_from_system(), "end timestamp is in the future")
	manager.cancel_session()
	_check(not manager.active, "cancel stops timer")

func _test_duration_validation() -> void:
	var manager := preload("res://autoload/focus_manager.gd").new()
	root.add_child(manager)
	manager.start_session("Bounds", 999999)
	_check(manager.duration_seconds == 10800, "duration clamps to 180 minutes")
	manager.cancel_session()
	_check(manager.task == "Bounds", "task is retained")

