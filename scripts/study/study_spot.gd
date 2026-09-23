@tool
class_name StudySpot
extends Node3D

enum OccupantType {
	NONE,
	PLAYER,
	NPC,
	REMOTE_PLAYER,
}

@export_category("StudyTown Seat")
@export var seat_id := ""
@export var study_type := "Laptop"
@export var seat_type := "desk_chair"
@export var interaction_radius := 0.75
@export var seated_visual_offset := Vector3.ZERO
@export var seat_height := 0.0
@export var seat_label := ""
@export var physical_seat_id := ""
@export var slot_index := 0

# Tight per-family interaction radii (world units around the standing
# anchor). Legacy seats baked with the old 2.05 default are migrated on
# load; intentionally authored values are preserved.
const LEGACY_RADIUS := 2.05


static func default_interaction_radius(type: String, authored_seat_height: float) -> float:
	match type:
		"train_booth":
			return 0.65
		"armchair":
			return 0.80
		_:
			if authored_seat_height >= 0.33:
				return 0.70
			return 0.75

@export_category("Authored Session Cameras")
# Local-space position/target and FOV. Empty values use the room's solver.
@export var setup_camera_override: Dictionary = {}
@export var focus_camera_overrides: Array[Dictionary] = []

@export_category("Editable Anchors")
@export var standing_offset := Vector3.ZERO
@export var sitting_offset := Vector3.ZERO
@export var local_facing_yaw := 0.0
@export var camera_position_offset := Vector3.ZERO
@export var camera_target_offset := Vector3.ZERO

var occupant_id := ""
signal occupancy_changed
var occupant_type := OccupantType.NONE:
	set(value):
		if occupant_type == value: return
		occupant_type = value
		occupancy_changed.emit()

var debug_visual: Node3D
var debug_stand_marker: MeshInstance3D
var debug_sit_marker: MeshInstance3D
var debug_radius_marker: MeshInstance3D
var debug_label: Label3D


func apply_camera_data(data: Dictionary) -> void:
	if not data.has("setup") or data.get("focus", []).size() < 2:
		return
	setup_camera_override = decode_camera(data.setup)
	focus_camera_overrides.clear()
	for shot in data.focus:
		focus_camera_overrides.append(decode_camera(shot))


static func decode_camera(shot: Dictionary) -> Dictionary:
	var p: Array = shot.position
	var t: Array = shot.target
	return {"position": Vector3(p[0], p[1], p[2]), "target": Vector3(t[0], t[1], t[2]), "fov": float(shot.fov)}


# Existing gameplay code reads these names directly. They are computed from
# this node's editor transform, so moving/rotating a StudySpot in a baked room
# automatically moves all gameplay anchors with it.
var standing_position: Vector3:
	get:
		return to_global(standing_offset)
	set(value):
		standing_offset = to_local(value)


var sitting_position: Vector3:
	get:
		return to_global(sitting_offset)
	set(value):
		sitting_offset = to_local(value)


var facing_yaw: float:
	get:
		return global_rotation.y + local_facing_yaw
	set(value):
		local_facing_yaw = wrapf(
			value - global_rotation.y,
			-PI,
			PI
		)


var camera_position: Vector3:
	get:
		return to_global(camera_position_offset)
	set(value):
		camera_position_offset = to_local(value)


var camera_target: Vector3:
	get:
		return to_global(camera_target_offset)
	set(value):
		camera_target_offset = to_local(value)


var standing_transform: Transform3D:
	get:
		return Transform3D(
			Basis(Vector3.UP, facing_yaw),
			standing_position
		)


var sitting_transform: Transform3D:
	get:
		return Transform3D(
			Basis(Vector3.UP, facing_yaw),
			sitting_position
		)


func _ready() -> void:
	if Engine.is_editor_hint():
		call_deferred("_ensure_debug_visual", true)


func configure(
	id: String,
	standing: Vector3,
	sitting: Vector3,
	yaw: float,
	kind: String,
	camera_pos: Vector3,
	target: Vector3,
	type := "desk_chair",
	visual_offset := Vector3.ZERO,
	authored_seat_height := 0.0
) -> void:
	seat_id = id
	study_type = kind
	seat_type = type
	seated_visual_offset = visual_offset
	seat_height = authored_seat_height
	interaction_radius = default_interaction_radius(type, authored_seat_height)

	# Procedural rooms create StudySpot at the world origin, so these setters
	# preserve the old absolute behaviour. Baked scenes later call
	# convert_to_editor_anchor() to make the node itself the movable anchor.
	standing_position = standing
	sitting_position = sitting
	facing_yaw = yaw
	camera_position = camera_pos
	camera_target = target


func convert_to_editor_anchor() -> void:
	# Preserve every world-space value, then make the sitting position the
	# node's editor transform. Afterwards moving this node moves standing,
	# sitting and cinematic camera anchors as one unit.
	var world_standing := standing_position
	var world_sitting := sitting_position
	var world_camera := camera_position
	var world_target := camera_target
	var world_yaw := facing_yaw

	global_position = world_sitting
	global_rotation = Vector3(0.0, world_yaw, 0.0)

	standing_offset = to_local(world_standing)
	sitting_offset = to_local(world_sitting)
	camera_position_offset = to_local(world_camera)
	camera_target_offset = to_local(world_target)
	local_facing_yaw = 0.0

	reset_occupancy()
	_strip_debug_visual()


func sync_runtime_from_editor() -> void:
	reset_occupancy()
	# Baked scenes omit interaction_radius when it equalled the default at
	# bake time, so legacy seats load with the current default (0.75).
	# Resolve those to the per-family value; preserve authored overrides.
	if absf(interaction_radius - 0.75) < 0.001 or interaction_radius >= LEGACY_RADIUS - 0.1:
		interaction_radius = default_interaction_radius(seat_type, seat_height)
	_ensure_debug_visual(false)
	if is_instance_valid(debug_visual):
		debug_visual.visible = false
	update_debug(false)


func reset_occupancy() -> void:
	occupant_id = ""
	occupant_type = OccupantType.NONE


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
	reset_occupancy()


func occupancy_text() -> String:
	match occupant_type:
		OccupantType.PLAYER:
			return "PLAYER"
		OccupantType.NPC:
			return "NPC · %s" % occupant_id
		OccupantType.REMOTE_PLAYER:
			return "REMOTE · %s" % occupant_id
		_:
			return "AVAILABLE"


func update_debug(nearest: bool) -> void:
	if not is_instance_valid(debug_visual):
		return

	var color := (
		Color("#f3bd45")
		if nearest
		else (
			Color("#b9483e")
			if not is_available()
			else Color("#49c86b")
		)
	)

	for marker in [
		debug_stand_marker,
		debug_sit_marker,
		debug_radius_marker,
	]:
		if is_instance_valid(marker):
			var material := StandardMaterial3D.new()
			material.albedo_color = color
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			marker.material_override = material

	if is_instance_valid(debug_label):
		debug_label.text = "%s\n%s · %s" % [
			seat_id,
			occupancy_text(),
			study_type,
		]
		debug_label.modulate = color


func _strip_debug_visual() -> void:
	var existing := get_node_or_null("DebugVisual")
	if existing != null:
		remove_child(existing)
		existing.free()

	debug_visual = null
	debug_stand_marker = null
	debug_sit_marker = null
	debug_radius_marker = null
	debug_label = null


func _ensure_debug_visual(editor_preview: bool) -> void:
	var existing := get_node_or_null("DebugVisual") as Node3D

	if existing != null:
		debug_visual = existing
		debug_stand_marker = existing.get_node_or_null(
			"StandingMarker"
		) as MeshInstance3D
		debug_sit_marker = existing.get_node_or_null(
			"SittingMarker"
		) as MeshInstance3D
		debug_radius_marker = existing.get_node_or_null(
			"InteractionRadius"
		) as MeshInstance3D
		debug_label = existing.get_node_or_null(
			"SeatLabel"
		) as Label3D
		debug_visual.visible = editor_preview
		return

	var root := Node3D.new()
	root.name = "DebugVisual"
	add_child(root)
	debug_visual = root

	debug_stand_marker = _make_debug_disc(
		"StandingMarker",
		standing_offset + Vector3.UP * 0.05,
		Color("#49c86b")
	)
	root.add_child(debug_stand_marker)

	debug_sit_marker = _make_debug_disc(
		"SittingMarker",
		sitting_offset + Vector3.UP * 0.08,
		Color("#ed755f")
	)
	root.add_child(debug_sit_marker)

	var radius_marker := MeshInstance3D.new()
	radius_marker.name = "InteractionRadius"
	radius_marker.position = standing_offset + Vector3.UP * 0.035

	var torus := TorusMesh.new()
	torus.inner_radius = maxf(interaction_radius - 0.09, 0.05)
	torus.outer_radius = interaction_radius
	torus.rings = 48
	torus.ring_segments = 8
	radius_marker.mesh = torus
	radius_marker.material_override = _debug_material(
		Color(0.25, 1.0, 0.45, 0.48)
	)

	root.add_child(radius_marker)
	debug_radius_marker = radius_marker

	var arrow := MeshInstance3D.new()
	arrow.name = "FacingArrow"
	var arrow_mesh := BoxMesh.new()
	arrow_mesh.size = Vector3(0.08, 0.08, 0.90)
	arrow.mesh = arrow_mesh
	arrow.position = (
		sitting_offset
		+ Vector3(0.0, 0.15, -0.42)
	)
	arrow.rotation.y = local_facing_yaw
	arrow.material_override = _debug_material(
		Color("#f3bd45")
	)
	root.add_child(arrow)

	var label := Label3D.new()
	label.name = "SeatLabel"
	label.position = sitting_offset + Vector3.UP * 0.55
	label.font_size = 22
	label.outline_size = 6
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(label)
	debug_label = label

	root.visible = editor_preview
	update_debug(false)


func _make_debug_disc(
	node_name: String,
	position_value: Vector3,
	color: Color
) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	marker.name = node_name
	marker.position = position_value

	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.22
	mesh.bottom_radius = 0.22
	mesh.height = 0.04
	mesh.radial_segments = 18
	marker.mesh = mesh
	marker.material_override = _debug_material(color)

	return marker


func _debug_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
