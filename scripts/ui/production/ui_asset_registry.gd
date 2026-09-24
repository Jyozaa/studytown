class_name UIAssetRegistry
extends RefCounted
## Central registry for optional production UI artwork.
## Tries the final path first, falls back to the wired placeholder,
## never crashes when art is missing.

const MAP_DIR := "res://assets/ui/map/"
const PLACEHOLDER_DIR := "res://assets/ui/placeholders/"

const LOCATIONS := [
	{"id": "library", "name": "Grand Library", "blurb": "Quiet desks · reading spaces", "vignette": "vignette_library.png", "room_index": 0},
	{"id": "garden", "name": "Garden Café", "blurb": "Outdoor study · café tables", "vignette": "vignette_garden.png", "room_index": 1},
	{"id": "train", "name": "Scenic Train", "blurb": "Window booths · passing hills", "vignette": "vignette_train.png", "room_index": 2},
	{"id": "japanese", "name": "Japanese Study Room", "blurb": "Tatami · tea · low tables", "vignette": "vignette_japanese.png", "room_index": 3},
]


static func vignette_path(location_id: String) -> String:
	for loc in LOCATIONS:
		if str(loc["id"]) == location_id:
			var final := MAP_DIR + str(loc["vignette"])
			var ph := PLACEHOLDER_DIR + "vignette_placeholder.png"
			if FileAccess.file_exists(final) or FileAccess.file_exists(ProjectSettings.globalize_path(final)):
				return final
			return ph
	return ""


static func load_vignette(location_id: String) -> Texture2D:
	# Runtime-captured PNGs have no .import sidecars, so go through Image.
	var path := vignette_path(location_id)
	if path == "":
		return null
	var global := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(global):
		return null
	var img: Image = Image.load_from_file(global if FileAccess.file_exists(global) else path)
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)


static func location_for_room(room_index: int) -> Dictionary:
	for loc in LOCATIONS:
		if int(loc["room_index"]) == room_index:
			return loc
	return {}
