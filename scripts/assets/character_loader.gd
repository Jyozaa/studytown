class_name CharacterLoader
extends Node

const MANIFEST_PATH := "res://assets/local_asset_manifest.json"
const AnimationControllerScript := preload(
	"res://scripts/characters/character_animation_controller.gd"
)

var profiles: Array[CharacterProfile] = []
var warned_missing := false


func _ready() -> void:
	load_manifest()


func load_manifest() -> void:
	profiles.clear()

	if not FileAccess.file_exists(MANIFEST_PATH):
		return

	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(MANIFEST_PATH)
	)

	if parsed is Dictionary:
		for entry in parsed.get("assets", []):
			if (
				entry is Dictionary
				and str(entry.get("category", "")) == "character"
				and not str(
					entry.get("runtime_relative_path", "")
				).is_empty()
			):
				profiles.append(
					CharacterProfile.from_dictionary(entry)
				)


func get_profile(index: int) -> CharacterProfile:
	if profiles.is_empty():
		load_manifest()

	if profiles.is_empty():
		return CharacterProfile.new()

	return profiles[
		clampi(index, 0, profiles.size() - 1)
	]


func get_profile_by_character_id(
	character_id: String
) -> CharacterProfile:
	if profiles.is_empty():
		load_manifest()

	for profile: CharacterProfile in profiles:
		if profile.character_id == character_id:
			return profile

	return CharacterProfile.new()


func create_character(
	parent: Node,
	index: int,
	fallback_factory: Callable,
	seated := false
) -> Node3D:
	var profile: CharacterProfile = get_profile(index)

	var imported: Node3D = _create_imported_character(
		parent,
		profile,
		seated
	)

	if imported != null:
		return imported

	if not warned_missing:
		warned_missing = true
		push_warning(
			"Local cat development models are absent; "
			+ "using the public fallback characters."
		)

	var fallback: Node3D = fallback_factory.call(
		parent,
		index,
		seated
	)

	fallback.set_meta(
		"character_profile",
		profile
	)
	fallback.set_meta(
		"is_imported_character",
		false
	)

	return fallback


func recreate_character_by_id(
	parent: Node,
	character_id: String,
	seated := false
) -> Node3D:
	var profile: CharacterProfile = (
		get_profile_by_character_id(
			character_id
		)
	)

	return _create_imported_character(
		parent,
		profile,
		seated
	)


func _create_imported_character(
	parent: Node,
	profile: CharacterProfile,
	seated: bool
) -> Node3D:
	if profile == null:
		return null

	if profile.expected_local_path.is_empty():
		return null

	if not ResourceLoader.exists(
		profile.expected_local_path
	):
		return null

	var resource: Resource = load(
		profile.expected_local_path
	)

	if not resource is PackedScene:
		return null

	var visual_root := Node3D.new()
	visual_root.name = (
		"VisualRoot_%s"
		% profile.character_id
	)
	parent.add_child(visual_root)

	visual_root.position = (
		profile.sitting_visual_offset
		if seated
		else profile.standing_visual_offset
	)
	visual_root.rotation_degrees.y = (
		profile.forward_axis_correction_degrees
	)
	visual_root.scale = profile.scale

	var model: Node = (
		(resource as PackedScene).instantiate()
	)
	model.name = "ImportedACNHModel"
	visual_root.add_child(model)

	visual_root.set_meta(
		"character_profile",
		profile
	)
	visual_root.set_meta(
		"is_imported_character",
		true
	)

	_bind_animation_controller(
		visual_root,
		profile
	)

	play_animation(
		visual_root,
		"Sit" if seated else "Idle",
		0.0
	)

	return visual_root


func rebind_character_runtime(
	character: Node3D,
	character_id := ""
) -> bool:
	if not is_instance_valid(character):
		return false

	var resolved_id: String = character_id

	if (
		resolved_id.is_empty()
		and str(character.name).begins_with(
			"VisualRoot_"
		)
	):
		resolved_id = str(character.name).trim_prefix(
			"VisualRoot_"
		)

	var profile: CharacterProfile = null
	var stored_profile: Variant = (
		character.get_meta(
			"character_profile",
			null
		)
	)

	if stored_profile is CharacterProfile:
		profile = (
			stored_profile
			as CharacterProfile
		)

	if profile == null:
		if not resolved_id.is_empty():
			profile = (
				get_profile_by_character_id(
					resolved_id
				)
			)
		else:
			profile = get_profile(0)

	character.set_meta(
		"character_profile",
		profile
	)

	var animation_player: AnimationPlayer = (
		_find_animation_player(character)
	)

	if animation_player == null:
		character.set_meta(
			"is_imported_character",
			false
		)
		return false

	character.set_meta(
		"is_imported_character",
		true
	)
	animation_player.active = true

	_bind_animation_controller(
		character,
		profile
	)

	return true


func _bind_animation_controller(
	character: Node3D,
	profile: CharacterProfile
) -> void:
	var animation_player: AnimationPlayer = (
		_find_animation_player(character)
	)

	if animation_player == null:
		return

	var controller: Node = (
		character.get_node_or_null(
			"CharacterAnimationController"
		)
	)

	if controller == null:
		controller = (
			AnimationControllerScript.new()
		)
		controller.name = (
			"CharacterAnimationController"
		)
		character.add_child(controller)

	controller.configure(
		animation_player,
		profile.animation_map
	)

	character.set_meta(
		"animation_controller",
		controller
	)


func play_animation(
	character: Node,
	state: String,
	blend := 0.18
) -> void:
	if not is_instance_valid(character):
		return

	var controller: Variant = (
		character.get_meta(
			"animation_controller"
		)
		if character.has_meta(
			"animation_controller"
		)
		else null
	)

	if is_instance_valid(controller):
		if state in [
			"Sit",
			"Wave",
			"Stretch",
			"Cheer",
		]:
			controller.play_one_shot(
				StringName(state),
				controller.return_state,
				blend
			)
		else:
			controller.play_state(
				StringName(state),
				blend
			)
		return

	var profile: CharacterProfile = null
	var profile_meta: Variant = (
		character.get_meta(
			"character_profile",
			null
		)
	)

	if profile_meta is CharacterProfile:
		profile = (
			profile_meta
			as CharacterProfile
		)

	var clip: String = state

	if profile != null:
		clip = str(
			profile.animation_map.get(
				state,
				state
			)
		)

	var animation_player: AnimationPlayer = (
		_find_animation_player(character)
	)

	if animation_player == null:
		return

	animation_player.active = true

	if (
		animation_player.has_animation(clip)
		and (
			animation_player.current_animation
			!= clip
			or not animation_player.is_playing()
		)
	):
		animation_player.play(
			clip,
			blend
		)


func set_seated(
	character: Node3D,
	seated: bool,
	seat_visual_offset := Vector3.ZERO
) -> void:
	if not is_instance_valid(character):
		return

	var profile: CharacterProfile = null
	var profile_meta: Variant = (
		character.get_meta(
			"character_profile",
			null
		)
	)

	if profile_meta is CharacterProfile:
		profile = (
			profile_meta
			as CharacterProfile
		)

	if profile == null:
		return

	character.position = (
		profile.sitting_visual_offset
		+ seat_visual_offset
		if seated
		else profile.standing_visual_offset
	)


func _find_animation_player(
	node: Node
) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer

	for child: Node in node.get_children():
		var found: AnimationPlayer = (
			_find_animation_player(child)
		)

		if found != null:
			return found

	return null
