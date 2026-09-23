extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = QuadMesh.new()
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded; instance uniform float test_strength = 0.5; void fragment() { ALBEDO = vec3(test_strength, 0.0, 0.0); }"
	material.shader = shader
	mesh.material_override = material
	root.add_child(mesh)
	mesh.set_instance_shader_parameter("test_strength", 0.8)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position.z = 2.0
	camera.make_current()
	await create_timer(0.3).timeout
	RenderingServer.force_draw(false)
	print("INSTANCE_PROBE ", mesh.get_instance_shader_parameter("test_strength"))
	quit()
