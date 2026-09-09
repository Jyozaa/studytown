extends SceneTree

## Deliberately Garden-only. Every replacement keeps an exact timestamped copy.
const Builder := preload("res://scripts/rooms/garden_builder.gd")
const TARGET := "res://assets/dev_local/room_layouts/garden.tscn"


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	if "--replace-garden" not in OS.get_cmdline_user_args():
		printerr("Pass -- --replace-garden to replace ONLY Garden, with backup.")
		quit(1)
		return
	if FileAccess.file_exists(TARGET):
		var stamp := Time.get_datetime_string_from_system().replace(":", "-")
		var backup := "res://assets/dev_local/backups/garden_central_pond_redesign/%s" % stamp
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(backup))
		var error := DirAccess.copy_absolute(
			ProjectSettings.globalize_path(TARGET),
			ProjectSettings.globalize_path(backup + "/garden.tscn")
		)
		if error != OK:
			printerr("Backup failed; Garden not changed: ", error)
			quit(1)
			return
		print("GARDEN_BACKUP ", backup)
	var builder := Builder.new()
	var garden := builder.build()
	var packed := PackedScene.new()
	var error := packed.pack(garden)
	if error == OK:
		error = ResourceSaver.save(packed, TARGET)
	print("GARDEN_REBUILD result=", error, " seats=", builder.spots.size())
	garden.free()
	quit(0 if error == OK else 1)
