extends RefCounted

## Builds puffy low-poly drifting clouds from shared primitive resources.
## No scene files are touched and no new assets are needed: one shared
## SphereMesh, one shared unshaded material, per-puff node scales.

static var shared_mesh: SphereMesh
static var shared_material: StandardMaterial3D


## Drops shared resources so GPU objects can tear down cleanly at exit.
static func release() -> void:
	shared_mesh = null
	shared_material = null

const CloudDrift := preload("res://scripts/world/cloud_drift.gd")

# Puff offsets (x, y, z, radius) forming one stylized cloud.
const PUFFS := [
	[0.0, 0.0, 0.0, 3.2],
	[2.6, 0.4, 0.6, 2.3],
	[-2.7, 0.3, -0.5, 2.5],
	[0.8, 1.1, -0.8, 1.9],
]


static func _resources() -> void:
	if shared_mesh == null:
		shared_mesh = SphereMesh.new()
		shared_mesh.radius = 1.0
		shared_mesh.height = 2.0
		shared_mesh.radial_segments = 12
		shared_mesh.rings = 6
	if shared_material == null:
		shared_material = StandardMaterial3D.new()
		shared_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shared_material.albedo_color = Color(1.0, 0.968, 0.925, 1.0)


static func build(parent: Node3D, cloud_count := 7, area := Vector3(60.0, 24.0, 55.0), drift_speed := 0.6, tint := Color(1.0, 1.0, 1.0, 1.0)) -> Node3D:
	_resources()
	var root: Node3D = CloudDrift.new()
	root.name = "DriftingClouds"
	root.set("speed", drift_speed)
	root.set("wrap", area.x + 15.0)
	parent.add_child(root)
	# Per-room copy so train (sunset) and garden (night) tint independently.
	var material: StandardMaterial3D = shared_material.duplicate()
	material.albedo_color = Color(1.0, 0.968, 0.925, 1.0) * tint
	# Fixed seed: identical layout every visit, reproducible screenshots.
	# Ring placement guarantees coverage in every horizontal view direction;
	# uniform scatter alone kept missing the camera frustum in testing.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in cloud_count:
		var cloud := Node3D.new()
		cloud.name = "Cloud_%02d" % i
		var angle: float = TAU * float(i) / float(cloud_count) + rng.randf_range(-0.2, 0.2)
		var radius: float = area.x * rng.randf_range(0.85, 1.05)
		var scale_factor := rng.randf_range(1.3, 2.0)
		cloud.position = Vector3(
			cos(angle) * radius,
			area.y + rng.randf_range(-3.0, 3.0),
			sin(angle) * radius * area.z / area.x
		)
		cloud.scale = Vector3.ONE * scale_factor
		root.add_child(cloud)
		for puff in PUFFS:
			var mesh_instance := MeshInstance3D.new()
			mesh_instance.mesh = shared_mesh
			mesh_instance.material_override = material
			mesh_instance.position = Vector3(puff[0], puff[1], puff[2])
			mesh_instance.scale = Vector3(puff[3], puff[3] * 0.55, puff[3])
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh_instance.set_meta("xray_exclude", true)
			cloud.add_child(mesh_instance)
	return root
