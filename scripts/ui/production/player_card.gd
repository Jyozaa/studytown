class_name PlayerCard
extends Control
## Small contextual card for a world occupant: name, state, activity, Wave.

var ui = null
var main = null
var _entry: Dictionary = {}


func setup(controller, owner_node: Node, parent: Control, occupant: Dictionary) -> void:
	ui = controller
	main = owner_node
	_entry = occupant
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(self)
	var vp := ProductionTheme.vp_size(self)
	var card := ProductionTheme.panel(self, Rect2(vp.x * 0.5 - 150, vp.y - 250, 300, 170))
	var is_you: bool = bool(_entry.get("you", false))
	ProductionTheme.label(card, str(_entry.get("name", "Buddy")), 19, ProductionTheme.INK).position = Vector2(16, 12)
	ProductionTheme.label(card, str(_entry.get("state", "")), 13, ProductionTheme.INK_SOFT).position = Vector2(16, 40)
	var activity := "Exploring the room"
	if is_you and str(GameState.current_focus) != "":
		activity = str(GameState.current_focus).left(40)
	ProductionTheme.label(card, activity, 12, ProductionTheme.INK_FAINT).position = Vector2(16, 62)
	var wave := ProductionTheme.button(card, "Wave", ProductionTheme.PAPER_HI, ProductionTheme.INK)
	wave.position = Vector2(16, 92)
	wave.size = Vector2(130, 42)
	wave.pressed.connect(_on_wave)
	var close := ProductionTheme.button(card, "Close", ProductionTheme.PAPER_HI, ProductionTheme.INK)
	close.position = Vector2(154, 92)
	close.size = Vector2(130, 42)
	close.pressed.connect(queue_free)


func _on_wave() -> void:
	# Local wave only: NPC wave responses are not implemented.
	if main.get("wave_time") != null:
		main.set("wave_time", 1.45)
		var visual = main.get("player_visual")
		if visual != null and is_instance_valid(visual) and bool(visual.get_meta("is_imported_character", false)):
			main.character_loader.play_animation(visual, "Wave", 0.12)
