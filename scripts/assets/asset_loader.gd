class_name StudyTownAssetLoader
extends Node

const MANIFEST_PATH := "res://assets/acnh_manifest.example.json"

var prop_entries: Dictionary = {}

func _ready() -> void:
	load_manifest()

func load_manifest() -> void:
	prop_entries.clear()
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if parsed is Dictionary:
		for entry in parsed.get("props", []):
			if entry is Dictionary:
				prop_entries[str(entry.get("asset_id", ""))] = entry

func instantiate_prop(asset_id: String, fallback_path := "") -> Node3D:
	if prop_entries.is_empty():
		load_manifest()
	var entry: Dictionary = prop_entries.get(asset_id, {})
	var local_path := str(entry.get("expected_local_path", ""))
	var chosen_path := local_path if not local_path.is_empty() and ResourceLoader.exists(local_path) else fallback_path
	var holder := Node3D.new()
	holder.name = "Asset_%s" % asset_id
	holder.set_meta("using_development_asset", chosen_path == local_path and not local_path.is_empty())
	if not chosen_path.is_empty() and ResourceLoader.exists(chosen_path):
		var resource := load(chosen_path)
		if resource is PackedScene:
			holder.add_child(resource.instantiate())
	var configured_scale = entry.get("scale", [1.0, 1.0, 1.0])
	if configured_scale is Array and configured_scale.size() >= 3 and chosen_path == local_path:
		holder.scale = Vector3(float(configured_scale[0]), float(configured_scale[1]), float(configured_scale[2]))
	return holder
