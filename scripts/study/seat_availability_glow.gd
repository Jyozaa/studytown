extends Node3D

# Availability indicator anchor, child of its StudySpot ("AvailabilityGlow").
#
# Seats handled by SeatHighlightDriver (furniture overlay, no geometry here):
# cafe-*, library-*, train-*, japanese-*. All other rooms keep the original
# disc cushion behavior below, untouched.
var phase := 0.0
var enabled := true
var cushion: MeshInstance3D
static var shared_mesh: SphereMesh
static var shared_material: ShaderMaterial
var spot: StudySpot
var nearest := false


func _is_cafe() -> bool:
	if not is_instance_valid(spot):
		return false
	var sid := str(spot.seat_id)
	return sid.begins_with("cafe-") or sid.begins_with("library-") or sid.begins_with("train-") or sid.begins_with("japanese-")


func configure(index: int) -> void:
	phase = float(index) * 0.73
	if is_instance_valid(cushion): cushion.set_instance_shader_parameter("glow_phase", phase)


func _ready() -> void:
	spot = get_parent()
	if _is_cafe():
		# Remove stale baked disc meshes: driver-covered seats glow on the
		# furniture itself, never via floor discs.
		for child in get_children():
			if str(child.name) == "AvailableSeatCushion":
				remove_child(child)
				child.free()
		spot.occupancy_changed.connect(_update_visibility)
		_update_visibility()
		return
	cushion = MeshInstance3D.new()
	cushion.name = "AvailableSeatCushion"
	if shared_mesh == null:
		shared_mesh = SphereMesh.new()
		shared_mesh.radius = 0.42
		shared_mesh.height = 0.84
		shared_mesh.radial_segments = 20
		shared_mesh.rings = 10
		shared_material = ShaderMaterial.new()
		shared_material.shader = preload("res://shaders/seat_availability_glow.gdshader")
	cushion.mesh = shared_mesh
	cushion.scale = Vector3(1.0, 0.13, 0.82)
	cushion.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cushion)
	var cushion_height := 0.18 if spot.seat_type == "floor_cushion" else 0.73
	# New Garden benches/logs have explicit measured cushion heights. Existing
	# rooms keep their original effect placement unchanged.
	if spot.has_meta("garden_cushion_height"):
		cushion_height = float(spot.get_meta("garden_cushion_height"))
	cushion.global_position = spot.sitting_position + Vector3.UP * cushion_height
	cushion.material_override = shared_material
	cushion.set_instance_shader_parameter("glow_phase", phase)
	spot.occupancy_changed.connect(_update_visibility)
	_update_visibility()


func _update_visibility() -> void:
	visible = enabled and is_instance_valid(spot) and spot.is_available()


func set_nearest(value: bool) -> void:
	nearest = value
	if is_instance_valid(cushion):
		cushion.set_instance_shader_parameter("glow_nearest", value)
		cushion.scale.x = 1.12 if nearest else 1.0


func set_enabled(value: bool) -> void:
	enabled = value
	_update_visibility()
