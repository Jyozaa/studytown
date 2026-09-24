class_name LocalChat
extends Control
## Left-side chat drawer: LOCAL (spatial, radius-based count) + DM (honest
## empty state). Local messages live in memory for the run only.

const MAX_LEN := 160
const LOCAL_RADIUS := 10.0

var ui = null
var main = null
var _tab := "LOCAL"
var _drawer: Control
var _body: Control
var _messages: Array = []
var _field: LineEdit = null


func setup(controller, owner_node: Node, parent: Control) -> void:
	ui = controller
	main = owner_node
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(self)
	_build()


func nearby_count() -> int:
	var n := 0
	for npc in main.npcs:
		if is_instance_valid(npc) and (npc as Node3D).global_position.distance_to(main.player.global_position) <= LOCAL_RADIUS:
			n += 1
	return n


func _build() -> void:
	if _drawer != null and is_instance_valid(_drawer):
		_drawer.queue_free()
	_body = null
	_field = null
	var d := ProductionTheme.drawer(self, -1, 360.0)
	_drawer = d
	ProductionTheme.label(d, "Chat", 23, ProductionTheme.INK).position = Vector2(20, 16)
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(20, 56)
	tabs.size = Vector2(320, 36)
	tabs.add_theme_constant_override("separation", 8)
	d.add_child(tabs)
	var local_title := "LOCAL (%d)" % nearby_count()
	for t in ["LOCAL", "DM"]:
		var chip := ProductionTheme.chip(tabs, local_title if t == "LOCAL" else t, _tab == t, ProductionTheme.BLUEGREY)
		chip.custom_minimum_size = Vector2(0, 36)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.pressed.connect(_on_tab.bind(t))
	_body = Panel.new()
	_body.position = Vector2(20, 104)
	_body.size = Vector2(320, 360)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxEmpty.new()
	_body.add_theme_stylebox_override("panel", sb)
	d.add_child(_body)
	if _tab == "LOCAL":
		_field = ProductionTheme.text_field(d, "", "Message nearby…")
		_field.max_length = MAX_LEN
		_field.position = Vector2(20, 474)
		_field.size = Vector2(232, 44)
		_field.text_submitted.connect(_send)
		_field.focus_entered.connect(func(): main._set_movement_enabled(false))
		_field.focus_exited.connect(func(): main._set_movement_enabled(not is_instance_valid(main.active_study_spot)))
		var send := ProductionTheme.button(d, ">", ProductionTheme.AMBER, Color("#3D2C12"))
		send.position = Vector2(260, 474)
		send.size = Vector2(60, 44)
		send.pressed.connect(func(): _send(_field.text))
	refresh()


func _on_tab(t: String) -> void:
	_tab = t
	_build()


func _send(text: String) -> void:
	var cleaned := text.strip_edges().left(MAX_LEN)
	if cleaned.is_empty():
		return
	_messages.append({"from": "You", "text": cleaned})
	if _messages.size() > 40:
		_messages.pop_front()
	if _field != null and is_instance_valid(_field):
		_field.text = ""
		_field.release_focus()
	refresh()


func refresh() -> void:
	if _body == null or not is_instance_valid(_body):
		return
	for c in _body.get_children():
		c.queue_free()
	if _tab == "DM":
		var l := ProductionTheme.label(_body, "No conversations yet.\nDMs arrive when friends join.", 14, ProductionTheme.INK_SOFT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.position = Vector2(40, 140)
		l.size = Vector2(240, 80)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return
	var y := 0.0
	for m in _messages.slice(maxi(0, _messages.size() - 8)):
		var who := ProductionTheme.label(_body, str(m["from"]), 13, ProductionTheme.GREEN_DARK)
		who.position = Vector2(4, y)
		who.size = Vector2(312, 18)
		# Hand-wrapped: Label.size clamps to the unwrapped text width, so
		# dynamic messages are broken into short lines before display.
		var split := LocalChat.wrap_lines(str(m["text"]), 40).split("\n")
		var shown: Array = split.slice(0, 4)
		if split.size() > 4:
			shown[3] = str(shown[3]) + " …"
		var lines := shown.size()
		var body := ProductionTheme.label(_body, "\n".join(shown), 14, ProductionTheme.INK)
		body.position = Vector2(4, y + 18)
		body.size = Vector2(312, 18 + 18.0 * lines)
		y += 24.0 + 18.0 * lines


static func wrap_lines(text: String, width: int) -> String:
	# Greedy word wrap for chat display. Long words are hard-cut.
	var out: Array = []
	var line := ""
	for word in text.split(" ", false):
		var w := str(word)
		while w.length() > width:
			if not line.is_empty():
				out.append(line)
				line = ""
			out.append(w.left(width))
			w = w.substr(width)
		if line.is_empty():
			line = w
		elif (line + " " + w).length() <= width:
			line += " " + w
		else:
			out.append(line)
			line = w
	if not line.is_empty():
		out.append(line)
	if out.is_empty():
		return ""
	return "\n".join(out)
