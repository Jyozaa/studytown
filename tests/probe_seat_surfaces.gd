extends SceneTree

var paths := [
	"res://assets/source/cafe_packs/furniture_bits/Assets/gltf/chair_A_wood.gltf",
	"res://assets/source/cafe_packs/furniture_bits/Assets/gltf/chair_stool_wood.gltf",
	"res://assets/source/cafe_packs/restaurant_bits/Assets/gltf/chair_A.gltf",
	"res://assets/source/cafe_packs/furniture_bits/Assets/gltf/couch_pillows.gltf",
	"res://assets/source/cafe_packs/furniture_bits/Assets/gltf/armchair_pillows.gltf",
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
	current = packed.instantiate() as Node3D
	root.add_child(current)
	frame = 0

func _process(_delta: float) -> bool:
	frame += 1
	if frame < 3:
		return false
	print("ASSET ", paths[idx].get_file())
	for mi in current.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var aabb := m.mesh.get_aabb()
		var t: Transform3D = m.global_transform
		var mn := Vector3(1e9, 1e9, 1e9)
		var mx := Vector3(-1e9, -1e9, -1e9)
		for c in 8:
			var corner := aabb.position + Vector3(aabb.size.x if c & 1 else 0.0, aabb.size.y if c & 2 else 0.0, aabb.size.z if c & 4 else 0.0)
			var w: Vector3 = t * corner
			mn = mn.min(w)
			mx = mx.max(w)
		print("  part=", m.name, " y[%.2f,%.2f] x[%.2f,%.2f] z[%.2f,%.2f]" % [mn.y, mx.y, mn.x, mx.x, mn.z, mx.z])
	idx += 1
	_next()
	return false
