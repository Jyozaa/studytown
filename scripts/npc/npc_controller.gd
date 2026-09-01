class_name NPCController
extends Node3D

enum CalmState { STUDY_LAPTOP, STUDY_BOOK, IDLE_SEATED, IDLE_STANDING, STRETCH, WAVE }

var visual: Node3D
var phase := 0.0
var base_visual_y := 0.0
var base_visual_rotation_y := 0.0
var seated := true
var study_kind := "Laptop"
var state := CalmState.STUDY_LAPTOP
var next_action_at := 0.0
var character_loader: Node

func setup(character: Node3D, loader: Node = null, is_seated := true, kind := "Laptop") -> void:
	visual = character
	character_loader = loader
	seated = is_seated
	study_kind = kind
	phase = randf() * TAU
	base_visual_y = character.position.y
	base_visual_rotation_y = character.rotation.y
	state = CalmState.STUDY_LAPTOP if kind == "Laptop" else CalmState.STUDY_BOOK
	next_action_at = Time.get_unix_time_from_system() + randf_range(35.0, 70.0)
	_play_study()

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
