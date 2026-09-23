extends RefCounted

## Never edit a source resource. Cached templates retain original texture objects.
var templates: Dictionary = {}
static var shaders: Dictionary = {}
var unsupported: Dictionary = {}
var material_copies := 0
var shader_creations := 0
var creation_usec := 0


func variant(source: Material) -> ShaderMaterial:
	var started := Time.get_ticks_usec()
	if templates.has(source): return templates[source]
	if unsupported.has(source): return null
	if source.next_pass != null:
		unsupported[source] = "Source multipass material is left unchanged"
		return null
	var result := ShaderMaterial.new()
	if source is StandardMaterial3D:
		var code := FileAccess.get_file_as_string("res://shaders/player_occlusion_xray.gdshader")
		if source.cull_mode == BaseMaterial3D.CULL_DISABLED: code = code.replace("cull_back", "cull_disabled")
		elif source.cull_mode == BaseMaterial3D.CULL_FRONT: code = code.replace("cull_back", "cull_front")
		if source.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED: code = code.replace("blend_mix,", "unshaded, blend_mix,")
		if source.texture_filter in [BaseMaterial3D.TEXTURE_FILTER_NEAREST, BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS]:
			code = code.replace("filter_linear_mipmap", "filter_nearest_mipmap")
		if not source.texture_repeat: code = code.replace("repeat_enable", "repeat_disable")
		# Opaque exteriors stay in the opaque depth pipeline. Only the actual
		# window enters alpha blending, avoiding whole-mesh sorting artefacts.
		if source.transparency in [BaseMaterial3D.TRANSPARENCY_DISABLED, BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR]:
			var alpha_line := "ALPHA = (source_alpha ? color.a : 1.0) * xray_opacity(SCREEN_UV);"
			var opaque_code := code.replace("depth_prepass_alpha", "depth_draw_opaque").replace(alpha_line, "if (xray_opacity(SCREEN_UV) < 0.99999) { discard; }")
			var soft := ShaderMaterial.new()
			soft.shader = cached_shader(code.replace(alpha_line, "if (xray_opacity(SCREEN_UV) >= 0.99999) { discard; }\n\t" + alpha_line))
			result.shader = cached_shader(opaque_code)
			result.next_pass = soft
		else:
			result.shader = cached_shader(code)
		var parameters := {
			"base_color": source.albedo_color, "base_texture": source.albedo_texture,
			"roughness_value": source.roughness, "rough_texture": source.roughness_texture,
			"metallic_value": source.metallic, "metal_texture": source.metallic_texture,
			"specular_value": source.metallic_specular, "uv_scale": source.uv1_scale, "uv_offset": source.uv1_offset,
			"rough_channel": channel(source.roughness_texture_channel), "metal_channel": channel(source.metallic_texture_channel),
			"normal_enabled": source.normal_enabled, "normal_texture": source.normal_texture, "normal_strength": source.normal_scale,
			"ao_enabled": source.ao_enabled, "ao_texture": source.ao_texture, "ao_channel": channel(source.ao_texture_channel),
			"vertex_color_enabled": source.vertex_color_use_as_albedo,
			"source_alpha": source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA,
			"alpha_cutoff": source.alpha_scissor_threshold if source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR else 0.0,
			"emission_color": source.emission if source.emission_enabled else Color.BLACK,
			"emission_energy": source.emission_energy_multiplier if source.emission_enabled else 0.0,
			"emission_texture": source.emission_texture,
			"emission_has_texture": source.emission_texture != null,
			"emission_multiply": source.emission_operator == BaseMaterial3D.EMISSION_OP_MULTIPLY,
		}
		for key in parameters:
			if parameters[key] != null:
				result.set_shader_parameter(key, parameters[key])
				if result.next_pass != null: result.next_pass.set_shader_parameter(key, parameters[key])
	elif source is ShaderMaterial and source.shader != null:
		var code: String = source.shader.code
		# Keep original UV/vertex deformation and fragment calculations intact.
		# Unknown include-driven/multipass shaders are explicitly left untouched.
		var fragment := code.find("void fragment()")
		if fragment < 0 or "#include" in code or "instance uniform" in code or source.next_pass != null:
			unsupported[source] = "No safely editable fragment body"
			return null
		var opening := code.find("{", fragment)
		var closing := opening + 1
		var depth := 1
		while closing < code.length() and depth > 0:
			if code[closing] == "{": depth += 1
			if code[closing] == "}": depth -= 1
			closing += 1
		var alpha := "ALPHA *= xray_opacity(SCREEN_UV);" if "ALPHA" in code.substr(opening, closing - opening) else "ALPHA = xray_opacity(SCREEN_UV);"
		code = code.insert(closing - 1, "\n" + alpha + "\n")
		code = code.insert(code.find(";") + 1, "\n#include \"res://shaders/player_occlusion_window.gdshaderinc\"\n")
		result.shader = cached_shader(code)
		for parameter in source.shader.get_shader_uniform_list():
			var value = source.get_shader_parameter(parameter.name)
			if value != null: result.set_shader_parameter(parameter.name, value)
	else:
		unsupported[source] = "Unsupported material class"
		return null
	result.render_priority = source.render_priority
	templates[source] = result
	creation_usec += Time.get_ticks_usec() - started
	return result


func cached_shader(code: String) -> Shader:
	if not shaders.has(code):
		if shaders.size() >= 32: shaders.erase(shaders.keys()[0])
		shader_creations += 1
		var shader := Shader.new()
		shader.code = code
		shaders[code] = shader
	return shaders[code]


## Drops cached shader variants so GPU resources can tear down cleanly.
static func release() -> void:
	shaders.clear()


func channel(index: int) -> Vector4:
	if index == 4: return Vector4(0.333333, 0.333333, 0.333333, 0)
	var value := Vector4.ZERO
	value[clampi(index, 0, 3)] = 1.0
	return value
