class_name CharacterProfile
extends RefCounted

var character_id := "fallback"
var display_name := "Study buddy"
var source_page := ""
var expected_local_path := ""
var model_format := "glb"
var scale := Vector3.ONE
var visual_offset := Vector3.ZERO
var forward_axis_correction_degrees := 0.0
var collider_radius := 0.43
var collider_height := 1.85
var label_height := 2.9
var sit_offset := Vector3.ZERO
var animation_map: Dictionary = {}
var diagnostic: Dictionary = {}

static func from_dictionary(data: Dictionary) -> CharacterProfile:
	var profile := CharacterProfile.new()
	profile.character_id = str(data.get("character_id", "fallback"))
	profile.display_name = str(data.get("display_name", "Study buddy"))
	profile.source_page = str(data.get("source_page", ""))
	profile.expected_local_path = str(data.get("expected_local_path", ""))
	profile.model_format = str(data.get("model_format", "glb"))
	profile.scale = _vector3(data.get("scale", [1.0, 1.0, 1.0]), Vector3.ONE)
	profile.visual_offset = _vector3(data.get("visual_offset", [0.0, 0.0, 0.0]), Vector3.ZERO)
	profile.forward_axis_correction_degrees = float(data.get("forward_axis_correction_degrees", 0.0))
	profile.collider_radius = float(data.get("collider_radius", 0.43))
	profile.collider_height = float(data.get("collider_height", 1.85))
	profile.label_height = float(data.get("label_height", 2.9))
	profile.sit_offset = _vector3(data.get("sit_offset", [0.0, 0.0, 0.0]), Vector3.ZERO)
	profile.animation_map = data.get("animation_map", {}).duplicate(true)
	profile.diagnostic = data.get("diagnostic", {}).duplicate(true)
	return profile

static func _vector3(value: Variant, fallback: Vector3) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return fallback
