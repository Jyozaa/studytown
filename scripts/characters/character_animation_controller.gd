class_name CharacterAnimationController
extends Node

const LOOPING_STATES := [&"Idle", &"Walk", &"SeatedIdle", &"StudyLaptop", &"StudyBook"]
const ONE_SHOT_STATES := [&"Sit", &"Wave", &"Stretch", &"Cheer"]

var animation_player: AnimationPlayer
var animation_map: Dictionary = {}
var current_state := &"Idle"
var return_state := &"Idle"
var crossfade_duration := 0.18

func configure(player: AnimationPlayer, mapping: Dictionary) -> void:
	animation_player = player
	animation_map = mapping.duplicate(true)
	_configure_loop_modes()
	if not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)

func play_state(state: StringName, blend := -1.0) -> void:
	if not is_instance_valid(animation_player):
		return
	var clip := _clip_for(state)
	if not animation_player.has_animation(clip):
		return
	current_state = state
	if state not in ONE_SHOT_STATES:
		return_state = state
	if animation_player.current_animation != clip or not animation_player.is_playing():
		animation_player.play(clip, crossfade_duration if blend < 0.0 else blend)

func play_one_shot(state: StringName, fallback_state := &"Idle", blend := -1.0) -> void:
	return_state = fallback_state
	play_state(state, blend)

func is_playing_state(state: StringName) -> bool:
	return is_instance_valid(animation_player) and animation_player.current_animation == _clip_for(state) and animation_player.is_playing()

func _configure_loop_modes() -> void:
	for state in LOOPING_STATES:
		var clip := _clip_for(state)
		if animation_player.has_animation(clip):
			animation_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	for state in ONE_SHOT_STATES:
		var clip := _clip_for(state)
		if animation_player.has_animation(clip):
			animation_player.get_animation(clip).loop_mode = Animation.LOOP_NONE

func _clip_for(state: StringName) -> StringName:
	return StringName(str(animation_map.get(str(state), str(state))))

func _on_animation_finished(clip: StringName) -> void:
	if clip == _clip_for(current_state) and current_state in ONE_SHOT_STATES:
		play_state(return_state)
