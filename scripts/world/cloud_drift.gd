extends Node3D

## Drifts direct children slowly along +X with symmetric wrapping.
## Children are expected to be cloud clusters positioned in x ∈ [-wrap, wrap].

var speed := 0.6
var wrap := 75.0


func _process(delta: float) -> void:
	var step: float = speed * delta
	for child in get_children():
		if child is Node3D:
			child.position.x += step
			if child.position.x > wrap:
				child.position.x -= wrap * 2.0
