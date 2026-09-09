extends MultiMeshInstance3D

## Keep CPU-side placements serialized: the headless dummy renderer does not
## retain MultiMesh GPU buffers when the Garden is baked without a display.
@export var placements: Array[Transform3D] = []
@export var tints := PackedColorArray()


func _ready() -> void:
	for i in placements.size():
		multimesh.set_instance_transform(i, placements[i])
		multimesh.set_instance_color(i, tints[i])
