class_name StudyTownAssetLoader
extends Node

const MANIFEST_PATH := "res://assets/local_asset_manifest.json"

var prop_entries: Dictionary = {}


func _ready() -> void:
	load_manifest()


func load_manifest() -> void:
	prop_entries.clear()

	if not FileAccess.file_exists(MANIFEST_PATH):
		return

	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(MANIFEST_PATH)
	)

	if parsed is not Dictionary:
		return

	for entry in parsed.get("assets", []):
		if entry is Dictionary and str(entry.get("category", "")) != "character":
			prop_entries[str(entry.get("asset_id", ""))] = entry


func get_entry(asset_id: String) -> Dictionary:
	if prop_entries.is_empty():
		load_manifest()

	return prop_entries.get(asset_id, {}).duplicate(true)


func instantiate_prop(asset_id: String, fallback_path := "") -> Node3D:
	if prop_entries.is_empty():
		load_manifest()

	var entry: Dictionary = prop_entries.get(asset_id, {})

	var local_path := str(entry.get("runtime_relative_path", ""))
	var using_local := (
		not local_path.is_empty()
		and ResourceLoader.exists(local_path)
	)

	var chosen_path := local_path if using_local else fallback_path

	var holder := Node3D.new()
	holder.name = "Asset_%s" % asset_id

	holder.set_meta("asset_id", asset_id)
	holder.set_meta("using_local_asset", using_local)
	holder.set_meta("manifest_entry", entry.duplicate(true))

	if chosen_path.is_empty() or not ResourceLoader.exists(chosen_path):
		return holder

	var resource: Resource = load(chosen_path)

	if resource is not PackedScene:
		return holder

	var packed_scene: PackedScene = resource as PackedScene

	var asset_root := Node3D.new()
	asset_root.name = "AssetTransform"
	holder.add_child(asset_root)

	var instance: Node = packed_scene.instantiate()
	instance.name = "AssetModel"
	asset_root.add_child(instance)

	if using_local:
		var visual_offset := _vector3(
			entry.get("visual_offset", [0.0, 0.0, 0.0]),
			Vector3.ZERO
		)

		var pivot_correction := _vector3(
			entry.get("pivot_correction", [0.0, 0.0, 0.0]),
			Vector3.ZERO
		)

		var configured_rotation := _vector3(
			entry.get("rotation_degrees", [0.0, 0.0, 0.0]),
			Vector3.ZERO
		)

		var configured_scale := _vector3(
			entry.get("scale", [1.0, 1.0, 1.0]),
			Vector3.ONE
		)

		var ground_offset := float(entry.get("ground_offset", 0.0))

		asset_root.position = (
			visual_offset
			+ pivot_correction
			+ Vector3.UP * ground_offset
		)

		asset_root.rotation_degrees = configured_rotation
		asset_root.scale = configured_scale

	return holder


func _vector3(value: Variant, fallback: Vector3) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(
			float(value[0]),
			float(value[1]),
			float(value[2])
		)

	return fallback
