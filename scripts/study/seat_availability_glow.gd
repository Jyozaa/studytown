extends Node3D

# Runtime-only seat cushion, never a debug torus or a collider.
var phase := 0.0
var enabled := true
var cushion: MeshInstance3D
var glow_material: StandardMaterial3D


func configure(index: int) -> void:
	phase = float(index) * 0.73


func _ready() -> void:
	var spot = get_parent()
	cushion = MeshInstance3D.new()
	cushion.name = "AvailableSeatCushion"
	var mesh := SphereMesh.new()
	mesh.radius = 0.42
	mesh.height = 0.84
	mesh.radial_segments = 20
	mesh.rings = 10
	cushion.mesh = mesh
	cushion.scale = Vector3(1.0, 0.13, 0.82)
	cushion.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cushion)
	var cushion_height := 0.18 if spot.seat_type == "floor_cushion" else 0.73
	# New Garden benches/logs have explicit measured cushion heights. Existing
	# rooms keep their original effect placement unchanged.
	if spot.has_meta("garden_cushion_height"):
		cushion_height = float(spot.get_meta("garden_cushion_height"))
	cushion.global_position = spot.sitting_position + Vector3.UP * cushion_height
	glow_material = StandardMaterial3D.new()
	glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_material.emission_enabled = true
	glow_material.emission = Color.WHITE
	glow_material.emission_energy_multiplier = 0.6
	cushion.material_override = glow_material


func _process(_delta: float) -> void:
	var spot = get_parent()
	visible = enabled and spot != null and spot.is_available()
	if not visible:
		return
	var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.001 * TAU / 2.1 + phase)
	glow_material.albedo_color = Color(1, 1, 1, lerpf(0.09, 0.33, pulse))


func set_enabled(value: bool) -> void:
	enabled = value
	if not value:
		visible = false
