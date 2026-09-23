extends SceneTree

## Bakes the full garden dressing straight into garden.tscn so the Godot
## editor shows exactly what the game shows.
##
## A timestamped backup of the pre-bake scene is required to exist in
## assets/dev_local/room_layouts/backups/ before running (the script aborts
## without one). Runtime dressing (craftpix swaps, night lighting, clouds)
## detects the baked marker and skips itself, so nothing ever double-applies;
## the procedural fallback garden still dresses at runtime as before.
##
## Usage (repo root):
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
##     --script tools/editor/bake_garden_dressing_preview.gd
##
## Then open res://assets/dev_local/room_layouts/garden.tscn in the editor.
## To undo: copy the newest garden_before_dressing_bake_* backup back over
## garden.tscn.

const SOURCE_SCENE := "res://assets/dev_local/room_layouts/garden.tscn"
const BACKUP_PREFIX := "garden_before_dressing_bake_"

const SkyClouds := preload("res://scripts/world/sky_clouds.gd")
const GardenSunset := preload("res://scripts/rooms/garden_sunset.gd")
const GardenDressing := preload("res://scripts/world/craftpix_garden_dressing.gd")


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var backup_dir := "assets/dev_local/room_layouts/backups".path_join("")
	if DirAccess.dir_exists_absolute("assets/dev_local/room_layouts/backups"):
		var found := false
		for backup_file in DirAccess.get_files_at("assets/dev_local/room_layouts/backups"):
			if (backup_file as String).begins_with(BACKUP_PREFIX):
				found = true
				break
		if not found:
			push_error("No pre-bake backup found; refusing to overwrite garden.tscn")
			quit(1)
			return
	var packed: PackedScene = load(SOURCE_SCENE)
	if packed == null:
		push_error("Cannot load garden scene: " + SOURCE_SCENE)
		quit(1)
		return
	var layout := packed.instantiate() as Node3D
	if layout == null:
		push_error("Garden root is not Node3D")
		quit(1)
		return
	root.add_child(layout)
	if int(layout.get_meta("garden_dressed_version", 0)) >= 1:
		push_error("garden.tscn is already dressed; restore the newest garden_before_dressing_bake_* backup first, then re-run")
		quit(1)
		return
	# Let physics register statics so raycast grounding works headless.
	await physics_frame
	await physics_frame
	SkyClouds.build(layout, 7, Vector3(70.0, 24.0, 60.0), 0.6, Color(0.35, 0.42, 0.60, 1.0))
	GardenSunset.soften_baked_light(layout)
	GardenDressing.apply(layout)
	await process_frame
	layout.set_meta("garden_dressed_version", 1)
	_take_ownership(layout, layout)
	var baked := PackedScene.new()
	if baked.pack(layout) != OK:
		push_error("Could not pack dressed garden")
		quit(1)
		return
	if ResourceSaver.save(baked, SOURCE_SCENE) != OK:
		push_error("Could not save " + SOURCE_SCENE)
		quit(1)
		return
	print("GARDEN_DRESSED_SAVED ", SOURCE_SCENE)
	quit()


func _take_ownership(node: Node, root: Node) -> void:
	for child in node.get_children():
		if child.owner == null:
			child.owner = root
		_take_ownership(child, root)
