class_name RoomFloor
extends StaticBody3D

func configure(size: Vector2, top_y := 0.0) -> void:
	name = "StructuralFloor"
	collision_layer = 1
	collision_mask = 0
	position = Vector3(0.0, top_y - 0.2, 0.0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, 0.4, size.y)
	collision.shape = shape
	add_child(collision)
	var debug_mesh := MeshInstance3D.new()
	debug_mesh.name = "CollisionDebug"
	debug_mesh.add_to_group("collision_debug")
	var mesh := BoxMesh.new()
	mesh.size = shape.size + Vector3(0.03, 0.03, 0.03)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.15, 0.95, 0.45, 0.26)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	debug_mesh.mesh = mesh
	debug_mesh.visible = false
	add_child(debug_mesh)
