class_name NPCController
extends Node3D

var visual: Node3D
var phase := 0.0
var base_visual_y := 0.0

func setup(character: Node3D) -> void:
	visual = character
	phase = randf() * TAU
	base_visual_y = character.position.y

func _process(_delta: float) -> void:
	if not is_instance_valid(visual):
		return
	var t := Time.get_ticks_msec() * 0.001
	visual.position.y = base_visual_y + sin(t * 1.2 + phase) * 0.008
	visual.rotation.y = sin(t * 0.37 + phase) * 0.025
