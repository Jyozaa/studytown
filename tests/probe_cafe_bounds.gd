extends SceneTree

var paths := [
	"res://assets/source/cafe_packs/Low Poly Furniture/Electronics/Laptop.fbx",
	"res://assets/source/cafe_packs/Low Poly Furniture/Miscellaneous/Mug.fbx",
	"res://assets/source/cafe_packs/restaurant_bits/Assets/gltf/dishrack_plates.gltf",
	"res://assets/source/cafe_packs/restaurant_bits/Assets/gltf/fridge_A_decorated.gltf",
	"res://assets/source/cafe_packs/restaurant_bits/Assets/gltf/extractorhood.gltf",
	"res://assets/source/cafe_packs/furniture_bits/Assets/gltf/cactus_medium_A.gltf",
	"res://assets/source/cafe_packs/furniture_bits/Assets/gltf/table_low.gltf",
	"res://assets/source/cafe_packs/restaurant_bits/Assets/gltf/plate_small.gltf",
	"res://assets/source/cafe_packs/restaurant_bits/Assets/gltf/food_burger.gltf",
	"res://assets/source/cafe_packs/restaurant_bits/Assets/gltf/jar_A_small.gltf",
]
var idx := 0
var frame := 0
var current: Node3D = null

func _initialize() -> void:
	_next()

func _next() -> void:
	if current != null:
		current.queue_free()
		current = null
	if idx >= paths.size():
		print("PROBE DONE")
		quit()
		return
	var packed: PackedScene = load(paths[idx])
	var node := packed.instantiate() as Node3D
	root.add_child(node)
	current = node
	frame = 0

func _process(_delta: float) -> bool:
	frame += 1
	if frame < 3:
		return false
	var mn := Vector3(1e9, 1e9, 1e9)
	var mx := Vector3(-1e9, -1e9, -1e9)
	for mi in current.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D)
		if m.mesh == null:
			continue
		var aabb := m.mesh.get_aabb()
		var t: Transform3D = m.global_transform
		for c in 8:
			var corner := aabb.position + Vector3(
				aabb.size.x if c & 1 else 0.0,
				aabb.size.y if c & 2 else 0.0,
				aabb.size.z if c & 4 else 0.0)
			var w: Vector3 = t * corner
			mn = mn.min(w)
			mx = mx.max(w)
	print("BOUNDS ", paths[idx].get_file(), " ymin=%.3f ymax=%.3f x:[%.3f,%.3f] z:[%.3f,%.3f] scale=%s" % [mn.y, mx.y, mn.x, mx.x, mn.z, mx.z, str(current.scale)])
	idx += 1
	_next()
	return false
