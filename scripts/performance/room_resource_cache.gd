extends RefCounted

## Bounded authored-scene cache shared by thumbnails and playable room loads.
static var scenes: Dictionary = {}

static func get_scene(path: String) -> PackedScene:
	if not scenes.has(path):
		if scenes.size() >= 4: scenes.erase(scenes.keys()[0])
		scenes[path] = load(path) as PackedScene
	return scenes[path]


## Drops cached scenes so GPU resources can tear down cleanly at exit.
static func release() -> void:
	scenes.clear()
