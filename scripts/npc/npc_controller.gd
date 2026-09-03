class_name NPCController
extends Node3D

enum CalmState {
	STUDY_LAPTOP,
	STUDY_BOOK,
	IDLE_SEATED,
	IDLE_STANDING,
	WALK,
	STRETCH,
	WAVE,
}

# These exported fields are only persistence metadata for locally baked room
# scenes. Procedural/public rooms continue to use setup() exactly as before.
@export_category("Editable Room Binding")
@export var editor_display_name := ""
@export var editor_occupant_id := ""
@export var editor_timer_text := ""
@export var editor_seated := true
@export var editor_study_kind := "Laptop"
@export var editor_spot_id := ""
@export var editor_patrol_kind := ""

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


func setup(
	character: Node3D,
	loader: Node = null,
	is_seated := true,
	kind := "Laptop",
	spot = null,
	id := ""
) -> void:
	visual = character
	character_loader = loader
	seated = is_seated
	study_kind = kind
	assigned_spot = spot
	occupant_id = id

	editor_occupant_id = id
	editor_display_name = id
	editor_seated = is_seated
	editor_study_kind = kind
	editor_spot_id = (
		str(spot.seat_id)
		if spot != null and is_instance_valid(spot)
		else ""
	)

	phase = randf() * TAU
	base_visual_y = character.position.y
	base_visual_rotation_y = character.rotation.y
	state = (
		CalmState.STUDY_LAPTOP
		if kind == "Laptop"
		else CalmState.STUDY_BOOK
	)
	next_action_at = (
		Time.get_unix_time_from_system()
		+ randf_range(35.0, 70.0)
	)
	_play_study()
	_validate_anchor()


func capture_for_editable_scene() -> void:
	editor_seated = seated
	editor_study_kind = study_kind
	editor_occupant_id = occupant_id

	if editor_display_name.is_empty():
		editor_display_name = occupant_id

	editor_spot_id = (
		str(assigned_spot.seat_id)
		if assigned_spot != null
			and is_instance_valid(assigned_spot)
		else ""
	)

	for child in get_children():
		if child is Label3D:
			var text := str((child as Label3D).text)
			if "·" in text:
				var parts := text.split("·", false, 1)
				editor_display_name = parts[0].strip_edges()
				if parts.size() > 1:
					editor_timer_text = parts[1].strip_edges()
			elif not text.is_empty():
				editor_display_name = text
			break

	if name == "NPC_GardenBarista":
		editor_patrol_kind = "garden_barista"


func rebind_runtime(
	loader: Node,
	spots_by_id: Dictionary
) -> void:
	character_loader = loader
	visual = _find_character_visual(self)

	seated = editor_seated
	study_kind = editor_study_kind
	occupant_id = (
		editor_occupant_id
		if not editor_occupant_id.is_empty()
		else editor_display_name
	)

	assigned_spot = spots_by_id.get(editor_spot_id, null)

	if (
		assigned_spot != null
		and is_instance_valid(assigned_spot)
	):
		assigned_spot.reserve(
			occupant_id,
			StudySpot.OccupantType.NPC
		)
		global_position = assigned_spot.sitting_position
		rotation.y = assigned_spot.facing_yaw

	if not is_instance_valid(visual):
		push_warning(
			"Editable NPC %s has no character visual"
			% name
		)
		return

	if seated:
		character_loader.set_seated(
			visual,
			true,
			(
				assigned_spot.seated_visual_offset
				if assigned_spot != null
				and is_instance_valid(assigned_spot)
				else Vector3.ZERO
			)
		)
	else:
		character_loader.set_seated(
			visual,
			false
		)

	phase = randf() * TAU
	base_visual_y = visual.position.y
	base_visual_rotation_y = visual.rotation.y
	state = (
		CalmState.STUDY_LAPTOP
		if study_kind == "Laptop"
		else CalmState.STUDY_BOOK
	)
	next_action_at = (
		Time.get_unix_time_from_system()
		+ randf_range(35.0, 70.0)
	)

	if editor_patrol_kind == "garden_barista":
		next_action_at = INF
		character_loader.play_animation(
			visual,
			"Idle",
			0.0
		)
	elif seated:
		_play_study()
	else:
		state = CalmState.IDLE_STANDING
		character_loader.play_animation(
			visual,
			"Idle",
			0.0
		)

	_validate_anchor()


func _find_character_visual(node: Node) -> Node3D:
	for child in node.get_children():
		if child is Node3D:
			var node_3d := child as Node3D
			if (
				node_3d.has_meta("is_imported_character")
				or node_3d.has_meta("character_profile")
				or node_3d.has_meta("parts")
			):
				return node_3d

			var nested := _find_character_visual(node_3d)
			if nested != null:
				return nested

	return null


func _process(_delta: float) -> void:
	if not is_instance_valid(visual):
		return

	var t := Time.get_ticks_msec() * 0.001
	visual.position.y = base_visual_y
	visual.rotation.y = (
		base_visual_rotation_y
		+ sin(t * 0.37 + phase) * 0.018
	)

	if Time.get_unix_time_from_system() >= next_action_at:
		_play_ambient_action()


func _play_study() -> void:
	if not is_instance_valid(character_loader):
		return

	state = (
		CalmState.STUDY_LAPTOP
		if study_kind == "Laptop"
		else CalmState.STUDY_BOOK
	)

	var animation_name := (
		"StudyLaptop"
		if study_kind == "Laptop"
		else "StudyBook"
	)

	if assigned_spot != null and is_instance_valid(assigned_spot):
		if str(assigned_spot.seat_type) == "floor_cushion":
			animation_name = "FloorStudy"
		elif str(assigned_spot.seat_type) == "train_booth":
			animation_name = "TrainStudy"

	character_loader.play_animation(
		visual,
		animation_name,
		0.25
	)


func _play_ambient_action() -> void:
	if not is_instance_valid(character_loader):
		return

	# Floor-seated characters should remain in their dedicated compact pose.
	if assigned_spot != null and is_instance_valid(assigned_spot):
		if str(assigned_spot.seat_type) == "floor_cushion":
			next_action_at = (
				Time.get_unix_time_from_system()
				+ randf_range(45.0, 85.0)
			)
			return

	state = (
		CalmState.STRETCH
		if randf() < 0.72
		else CalmState.WAVE
	)

	character_loader.play_animation(
		visual,
		"Stretch" if state == CalmState.STRETCH else "Wave",
		0.25
	)

	get_tree().create_timer(
		1.8
	).timeout.connect(_resume_study)

	next_action_at = (
		Time.get_unix_time_from_system()
		+ randf_range(45.0, 85.0)
	)


func _resume_study() -> void:
	if is_instance_valid(visual):
		_play_study()


func walk_to(
	destination: Vector3,
	duration := 2.4
) -> void:
	if (
		not is_instance_valid(visual)
		or not is_instance_valid(character_loader)
	):
		return

	if (
		assigned_spot != null
		and is_instance_valid(assigned_spot)
	):
		assigned_spot.release(occupant_id)

	assigned_spot = null
	seated = false
	state = CalmState.WALK

	character_loader.set_seated(
		visual,
		false
	)

	base_visual_y = visual.position.y
	base_visual_rotation_y = visual.rotation.y

	character_loader.play_animation(
		visual,
		"Walk",
		0.12
	)

	var flat_direction := destination - global_position
	flat_direction.y = 0.0

	if flat_direction.length_squared() > 0.001:
		rotation.y = atan2(
			-flat_direction.x,
			-flat_direction.z
		)

	if is_instance_valid(walking_tween):
		walking_tween.kill()

	walking_tween = (
		create_tween()
		.set_trans(Tween.TRANS_SINE)
		.set_ease(Tween.EASE_IN_OUT)
	)
	walking_tween.tween_property(
		self,
		"global_position",
		destination,
		duration
	)
	walking_tween.finished.connect(
		_finish_walk
	)


func _finish_walk() -> void:
	state = CalmState.IDLE_STANDING

	if is_instance_valid(visual):
		character_loader.play_animation(
			visual,
			"Idle",
			0.18
		)
		base_visual_y = visual.position.y
		base_visual_rotation_y = visual.rotation.y


func _validate_anchor() -> void:
	if (
		not seated
		or assigned_spot == null
		or not is_instance_valid(assigned_spot)
	):
		return

	if (
		global_position.distance_to(
			assigned_spot.sitting_position
		) > 0.08
	):
		push_warning(
			"NPC %s is %.3f metres from assigned seat %s"
			% [
				occupant_id,
				global_position.distance_to(
					assigned_spot.sitting_position
				),
				assigned_spot.seat_id,
			]
		)

	if (
		absf(
			global_position.y
			- assigned_spot.sitting_position.y
		) > 0.08
	):
		push_warning(
			"NPC %s has invalid seated Y at %s"
			% [
				occupant_id,
				assigned_spot.seat_id,
			]
		)


func _exit_tree() -> void:
	if (
		assigned_spot != null
		and is_instance_valid(assigned_spot)
	):
		assigned_spot.release(occupant_id)
