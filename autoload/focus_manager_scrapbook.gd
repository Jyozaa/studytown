extends Node

signal tick(remaining_seconds: int)
signal completed
signal cancelled
signal pause_changed(paused: bool)

var active := false
var paused := false
var task := ""
var duration_seconds := 0
var end_timestamp := 0.0
var paused_remaining_seconds := 0


func _process(_delta: float) -> void:
	if not active or paused:
		return

	var remaining := get_remaining_seconds()
	tick.emit(remaining)

	if remaining <= 0:
		active = false
		paused = false
		paused_remaining_seconds = 0
		completed.emit()


func start_session(
	new_task: String,
	seconds: int
) -> void:
	task = (
		new_task.strip_edges()
		if not new_task.strip_edges().is_empty()
		else "Quiet focus"
	)

	duration_seconds = clampi(
		seconds,
		1,
		10800
	)

	paused = false
	paused_remaining_seconds = duration_seconds
	end_timestamp = (
		Time.get_unix_time_from_system()
		+ duration_seconds
	)
	active = true

	pause_changed.emit(false)
	tick.emit(duration_seconds)


func get_remaining_seconds() -> int:
	if paused:
		return maxi(
			0,
			paused_remaining_seconds
		)

	return maxi(
		0,
		ceili(
			end_timestamp
			- Time.get_unix_time_from_system()
		)
	)


func pause_session() -> void:
	if not active or paused:
		return

	paused_remaining_seconds = get_remaining_seconds()
	paused = true
	pause_changed.emit(true)
	tick.emit(paused_remaining_seconds)


func resume_session() -> void:
	if not active or not paused:
		return

	end_timestamp = (
		Time.get_unix_time_from_system()
		+ paused_remaining_seconds
	)

	paused = false
	pause_changed.emit(false)
	tick.emit(get_remaining_seconds())


func toggle_pause() -> void:
	if paused:
		resume_session()
	else:
		pause_session()


func cancel_session() -> void:
	if not active:
		return

	active = false
	paused = false
	paused_remaining_seconds = 0

	pause_changed.emit(false)
	cancelled.emit()
