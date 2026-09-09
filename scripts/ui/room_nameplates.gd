extends Node

# Screen-space pills preserve legibility without inflating character meshes.
const UI := preload("res://scripts/ui/dark_ui.gd")
var flow
var layer: CanvasLayer
var labels: Array[Control] = []
var actors: Array[Node3D] = []


func _ready() -> void:
	layer = CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	for i in flow.main.npcs.size():
		var npc = flow.main.npcs[i]
		for child in npc.get_children():
			if child is Label3D:
				child.visible = false
		var pill := UI.button(
			layer,
			"BREAK   " if i % 5 == 3 else "%dm      " % (18 + i * 7),
			Rect2(0, 0, 110, 27),
			func():
				flow.selected_member = i + 1
				flow.open_overlay(flow.State.PLAYER_PROFILE_OVERLAY),
			Color(0.16, 0.18, 0.21, 0.82)
		)
		UI.flag(pill, ["GB", "FR", "JP", "CA", "DE", "US"][i % 6], Rect2(80, 7, 22, 13))
		labels.append(pill)
		actors.append(npc)
	for child in flow.main.player.get_children():
		if child is Label3D:
			child.visible = false
	var you := UI.button(
		layer,
		"YOU",
		Rect2(0, 0, 67, 27),
		func():
			flow.selected_member = 0
			flow.open_overlay(flow.State.PLAYER_PROFILE_OVERLAY),
		Color(0.16, 0.18, 0.21, 0.86)
	)
	labels.append(you)
	actors.append(flow.main.player)


func _process(_delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	for i in labels.size():
		var actor := actors[i]
		var target: Vector3 = actor.global_position + Vector3.UP * 3.05
		var pill := labels[i]
		pill.visible = (
			not camera.is_position_behind(target)
			and not flow.is_overlay()
			and flow.state != flow.State.SEAT_TRANSITION
		)
		if pill.visible:
			pill.position = camera.unproject_position(target) - Vector2(pill.size.x / 2, 20)
			if i == actors.size() - 1 and pill.position.x > 850 and pill.position.y < 84:
				pill.position.y = 84
			pill.visible = (
				flow
				. main
				. follow_camera_rig
				. raycast_obstructions(camera.global_position, target, 1 | 16)
				. is_empty()
			)
