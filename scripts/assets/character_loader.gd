class_name CharacterLoader
extends Node

const MANIFEST_PATH := "res://assets/local_asset_manifest.json"
const AnimationControllerScript := preload("res://scripts/characters/character_animation_controller.gd")

var profiles: Array[CharacterProfile] = []
var warned_missing := false

func _ready() -> void:
	load_manifest()

func load_manifest() -> void:
	profiles.clear()
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if parsed is Dictionary:
		for entry in parsed.get("assets", []):
			if entry is Dictionary and str(entry.get("category", "")) == "character" and not str(entry.get("runtime_relative_path", "")).is_empty():
				profiles.append(CharacterProfile.from_dictionary(entry))

func get_profile(index: int) -> CharacterProfile:
	if profiles.is_empty():
		load_manifest()
	if profiles.is_empty():
		return CharacterProfile.new()
	return profiles[clampi(index, 0, profiles.size() - 1)]

func create_character(parent: Node, index: int, fallback_factory: Callable, seated := false) -> Node3D:
	var profile := get_profile(index)
	if not profile.expected_local_path.is_empty() and ResourceLoader.exists(profile.expected_local_path):
		var resource := load(profile.expected_local_path)
		if resource is PackedScene:
			var visual_root := Node3D.new()
			visual_root.name = "VisualRoot_%s" % profile.character_id
			parent.add_child(visual_root)
			visual_root.position = profile.sitting_visual_offset if seated else profile.standing_visual_offset
			visual_root.rotation_degrees.y = profile.forward_axis_correction_degrees
			visual_root.scale = profile.scale
			var model: Node = resource.instantiate()
			model.name = "ImportedACNHModel"
			visual_root.add_child(model)
			visual_root.set_meta("character_profile", profile)
			visual_root.set_meta("is_imported_character", true)
			var animation_player := _find_animation_player(visual_root)
			if animation_player != null:
				var controller = AnimationControllerScript.new()
				controller.name = "CharacterAnimationController"
				visual_root.add_child(controller)
				controller.configure(animation_player, profile.animation_map)
				visual_root.set_meta("animation_controller", controller)
			play_animation(visual_root, "Sit" if seated else "Idle", 0.0)
			return visual_root
	if not warned_missing:
		warned_missing = true
		push_warning("Local cat development models are absent; using the public fallback characters.")
	var fallback: Node3D = fallback_factory.call(parent, index, seated)
	fallback.set_meta("character_profile", profile)
	fallback.set_meta("is_imported_character", false)
	return fallback

func play_animation(character: Node, state: String, blend := 0.18) -> void:
	if not is_instance_valid(character):
		return
	var controller = character.get_meta("animation_controller") if character.has_meta("animation_controller") else null
	if is_instance_valid(controller):
		if state in ["Wave", "Stretch"]:
			controller.play_one_shot(StringName(state), controller.return_state, blend)
		else:
			controller.play_state(StringName(state), blend)
		return
	var profile: CharacterProfile = character.get_meta("character_profile", null)
	var clip := state
	if profile != null:
		clip = str(profile.animation_map.get(state, state))
	var animation_player := _find_animation_player(character)
	if animation_player == null:
		return
	if animation_player.has_animation(clip) and animation_player.current_animation != clip:
		animation_player.play(clip, blend)

func set_seated(character: Node3D, seated: bool) -> void:
	if not is_instance_valid(character):
		return
	var profile: CharacterProfile = character.get_meta("character_profile", null)
	if profile == null:
		return
	character.position = profile.sitting_visual_offset if seated else profile.standing_visual_offset

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
