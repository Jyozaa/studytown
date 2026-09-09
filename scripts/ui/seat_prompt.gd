extends Panel
var label: Label


func _process(_delta: float) -> void:
	visible = is_instance_valid(label) and label.visible and not label.text.is_empty()
