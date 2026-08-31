extends Node

signal tick(remaining_seconds: int)
signal completed
signal cancelled

var active := false
var task := ""
var duration_seconds := 0
var end_timestamp := 0.0

func _process(_delta: float) -> void:
	if not active:
		return
	var remaining := get_remaining_seconds()
	tick.emit(remaining)
	if remaining <= 0:
		active = false
		completed.emit()

func start_session(new_task: String, seconds: int) -> void:
	task = new_task.strip_edges() if not new_task.strip_edges().is_empty() else "Quiet focus"
	duration_seconds = clampi(seconds, 1, 10800)
	end_timestamp = Time.get_unix_time_from_system() + duration_seconds
	active = true
	tick.emit(duration_seconds)

func get_remaining_seconds() -> int:
	return maxi(0, ceili(end_timestamp - Time.get_unix_time_from_system()))

func cancel_session() -> void:
	if not active:
		return
	active = false
	cancelled.emit()

