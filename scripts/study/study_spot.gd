class_name StudySpot
extends Node3D

enum OccupantType { NONE, PLAYER, NPC, REMOTE_PLAYER }

var seat_id := ""
var occupant_id := ""
var occupant_type := OccupantType.NONE
var standing_position := Vector3.ZERO
var sitting_position := Vector3.ZERO
var facing_yaw := 0.0
var seat_type := "desk_chair"
var seated_visual_offset := Vector3.ZERO
var seat_height := 0.0
var standing_transform := Transform3D.IDENTITY
var sitting_transform := Transform3D.IDENTITY
var study_type := "Laptop"
var camera_position := Vector3.ZERO
var camera_target := Vector3.ZERO
var interaction_radius := 2.05
var debug_visual: Node3D
var debug_stand_marker: MeshInstance3D
var debug_sit_marker: MeshInstance3D
var debug_radius_marker: MeshInstance3D
var debug_label: Label3D

func configure(id: String, standing: Vector3, sitting: Vector3, yaw: float, kind: String, camera_pos: Vector3, target: Vector3, type := "desk_chair", visual_offset := Vector3.ZERO, authored_seat_height := 0.0) -> void:
	seat_id = id
	standing_position = standing
	sitting_position = sitting
	facing_yaw = yaw
	seat_type = type
	seated_visual_offset = visual_offset
	seat_height = authored_seat_height
	standing_transform = Transform3D(Basis(Vector3.UP, yaw), standing)
	sitting_transform = Transform3D(Basis(Vector3.UP, yaw), sitting)
	study_type = kind
	camera_position = camera_pos
	camera_target = target

func is_available() -> bool:
	return occupant_type == OccupantType.NONE

func reserve(id: String, type: OccupantType) -> bool:
	if not is_available() and occupant_id != id:
		return false
	occupant_id = id
	occupant_type = type
	return true

func release(id := "") -> void:
	if not id.is_empty() and occupant_id != id:
		return
	occupant_id = ""
	occupant_type = OccupantType.NONE

func occupancy_text() -> String:
	match occupant_type:
		OccupantType.PLAYER: return "PLAYER"
		OccupantType.NPC: return "NPC · %s" % occupant_id
		OccupantType.REMOTE_PLAYER: return "REMOTE · %s" % occupant_id
		_: return "AVAILABLE"

func update_debug(nearest: bool) -> void:
	var color := Color("#f3bd45") if nearest else (Color("#b9483e") if not is_available() else Color("#49c86b"))
	for marker in [debug_stand_marker, debug_sit_marker, debug_radius_marker]:
		if is_instance_valid(marker):
			var material := StandardMaterial3D.new()
			material.albedo_color = color
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			marker.material_override = material
	if is_instance_valid(debug_label):
		debug_label.text = "%s\n%s · %s" % [seat_id, occupancy_text(), study_type]
		debug_label.modulate = color
