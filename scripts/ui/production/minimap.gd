class_name MiniMap
extends Control
## Compact room minimap from live room data: bounds outline, seat dots,
## real player/NPC markers. Toggleable panel with zoom + close.

var ui = null
var main = null
var _zoom := 1.0
var _map: Control


func setup(controller, owner_node: Node, parent: Control) -> void:
	ui = controller
	main = owner_node
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(self)
	var vp := ProductionTheme.vp_size(self)
	var panel := ProductionTheme.panel(self, Rect2(vp.x - 14 - 248, 84, 248, 300))
	var title := ProductionTheme.label(panel, "Room map", 14, ProductionTheme.INK_SOFT)
	title.position = Vector2(12, 8)
	title.size = Vector2(150, 20)
	_map = _MapCanvas.new()
	_map.setup(self)
	_map.position = Vector2(12, 32)
	_map.size = Vector2(224, 224)
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_map)
	var zin := ProductionTheme.button(panel, "+", ProductionTheme.PAPER_HI, ProductionTheme.INK)
	zin.position = Vector2(12, 262)
	zin.size = Vector2(70, 30)
	zin.pressed.connect(func():
		_zoom = clampf(_zoom * 1.25, 0.75, 2.5)
		_map.queue_redraw())
	var zout := ProductionTheme.button(panel, "-", ProductionTheme.PAPER_HI, ProductionTheme.INK)
	zout.position = Vector2(89, 262)
	zout.size = Vector2(70, 30)
	zout.pressed.connect(func():
		_zoom = clampf(_zoom / 1.25, 0.75, 2.5)
		_map.queue_redraw())
	var close := ProductionTheme.button(panel, "Close", ProductionTheme.PAPER_HI, ProductionTheme.INK)
	close.position = Vector2(166, 262)
	close.size = Vector2(70, 30)
	close.pressed.connect(func(): queue_free())


func tick() -> void:
	if _map != null and is_instance_valid(_map):
		_map.queue_redraw()


class _MapCanvas extends Control:
	var minimap = null

	func setup(owner: MiniMap) -> void:
		minimap = owner

	func _draw() -> void:
		if minimap == null or minimap.main == null:
			return
		var m = minimap.main
		draw_rect(Rect2(Vector2.ZERO, size), Color("#2E2A22"))
		var bounds := Vector2(20, 15)
		if m.get("current_room_config") != null:
			var cfg: Dictionary = m.current_room_config
			if cfg.has("bounds"):
				bounds = cfg["bounds"]
		var sc: float = minf(size.x / (bounds.x * 2.0), size.y / (bounds.y * 2.0)) * minimap._zoom
		var center := size * 0.5
		var to_map := func(p: Vector3) -> Vector2:
			return center + Vector2(p.x, p.z) * sc
		draw_rect(Rect2(center - bounds * sc, bounds * 2.0 * sc), Color("#4A4234"), false, 2.0)
		if m.get("study_spots") != null:
			for spot in m.study_spots:
				if is_instance_valid(spot):
					draw_circle(to_map.call(spot.sitting_position), 2.5, Color(0.85, 0.72, 0.42, 0.9))
		if m.get("npcs") != null:
			for npc in m.npcs:
				if is_instance_valid(npc):
					draw_circle(to_map.call((npc as Node3D).global_position), 3.5, Color("#7E93A3"))
		if is_instance_valid(m.player):
			var pp: Vector2 = to_map.call(m.player.global_position)
			draw_circle(pp, 5.0, Color("#D9A441"))
			draw_arc(pp, 8.0, 0.0, TAU, 16, Color("#F9F1DC"), 2.0)
