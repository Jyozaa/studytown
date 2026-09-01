class_name NPCController
extends Node3D

enum CalmState { STUDY_LAPTOP, STUDY_BOOK, IDLE_SEATED, IDLE_STANDING, WALK, STRETCH, WAVE }

var visual: Node3D
var phase := 0.0
var base_visual_y := 0.0
var base_visual_rotation_y := 0.0
var seated := true
var study_kind := "Laptop"
var state := CalmState.STUDY_LAPTOP
var next_action_at := 0.0
var character_loader: Node
var assigned_spot
var occupant_id := ""
var walking_tween: Tween

func setup(character: Node3D, loader: Node = null, is_seated := true, kind := "Laptop", spot = null, id := "") -> void:
	visual = character
	character_loader = loader
	seated = is_seated
	study_kind = kind
	assigned_spot = spot
	occupant_id = id
	phase = randf() * TAU
	base_visual_y = character.position.y
	base_visual_rotation_y = character.rotation.y
	state = CalmState.STUDY_LAPTOP if kind == "Laptop" else CalmState.STUDY_BOOK
	next_action_at = Time.get_unix_time_from_system() + randf_range(35.0, 70.0)
	_play_study()
	_validate_anchor()

func _process(_delta: float) -> void:
	if not is_instance_valid(visual):
		return
	var t := Time.get_ticks_msec() * 0.001
	visual.position.y = base_visual_y
	visual.rotation.y = base_visual_rotation_y + sin(t * 0.37 + phase) * 0.018
	if Time.get_unix_time_from_system() >= next_action_at:
		_play_ambient_action()

func _play_study() -> void:
	if not is_instance_valid(character_loader):
		return
	state = CalmState.STUDY_LAPTOP if study_kind == "Laptop" else CalmState.STUDY_BOOK
	character_loader.play_animation(visual, "StudyLaptop" if study_kind == "Laptop" else "StudyBook", 0.25)

func _play_ambient_action() -> void:
	if not is_instance_valid(character_loader):
		return
	state = CalmState.STRETCH if randf() < 0.72 else CalmState.WAVE
	character_loader.play_animation(visual, "Stretch" if state == CalmState.STRETCH else "Wave", 0.25)
	get_tree().create_timer(1.8).timeout.connect(_resume_study)
	next_action_at = Time.get_unix_time_from_system() + randf_range(45.0, 85.0)

func _resume_study() -> void:
	if is_instance_valid(visual):
		_play_study()

func walk_to(destination: Vector3, duration := 2.4) -> void:
	if not is_instance_valid(visual) or not is_instance_valid(character_loader):
		return
	if assigned_spot != null and is_instance_valid(assigned_spot):
		assigned_spot.release(occupant_id)
	assigned_spot = null
	seated = false
	state = CalmState.WALK
	character_loader.set_seated(visual, false)
	base_visual_y = visual.position.y
	base_visual_rotation_y = visual.rotation.y
	character_loader.play_animation(visual, "Walk", 0.12)
	var flat_direction := destination - global_position
	flat_direction.y = 0.0
	if flat_direction.length_squared() > 0.001:
		rotation.y = atan2(-flat_direction.x, -flat_direction.z)
	if is_instance_valid(walking_tween):
		walking_tween.kill()
	walking_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	walking_tween.tween_property(self, "global_position", destination, duration)
	walking_tween.finished.connect(_finish_walk)

func _finish_walk() -> void:
	state = CalmState.IDLE_STANDING
	if is_instance_valid(visual):
		character_loader.play_animation(visual, "Idle", 0.18)
	base_visual_y = visual.position.y
	base_visual_rotation_y = visual.rotation.y

func _validate_anchor() -> void:
	if not seated or assigned_spot == null or not is_instance_valid(assigned_spot):
		return
	if global_position.distance_to(assigned_spot.sitting_position) > 0.08:
		push_warning("NPC %s is %.3f metres from assigned seat %s" % [occupant_id, global_position.distance_to(assigned_spot.sitting_position), assigned_spot.seat_id])
	if absf(global_position.y - assigned_spot.sitting_position.y) > 0.08:
		push_warning("NPC %s has invalid seated Y at %s" % [occupant_id, assigned_spot.seat_id])

func _exit_tree() -> void:
	if assigned_spot != null and is_instance_valid(assigned_spot):
		assigned_spot.release(occupant_id)
