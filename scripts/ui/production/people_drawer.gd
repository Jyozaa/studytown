class_name PeopleDrawer
extends Control
## Right-side people drawer: ROOM / FRIENDS / SEARCH tabs over live state.
## Presence adapter: local player + NPCs only (honest, no fake online users).

var ui = null
var main = null
var _tab := "ROOM"
var _drawer: Control
var _body: Control
var _search := ""


var _env := {}


func set_env(env: Dictionary) -> void:
	_env = env
	if _body != null:
		refresh()


func setup(controller, owner_node: Node, parent: Control, env: Dictionary = {}) -> void:
	ui = controller
	main = owner_node
	_env = env
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(self)
	_build()


func _build() -> void:
	if _drawer != null and is_instance_valid(_drawer):
		_drawer.queue_free()
	_body = null
	var d := ProductionTheme.drawer(self, 1, 360.0)
	_drawer = d
	ProductionTheme.label(d, "People", 23, ProductionTheme.INK).position = Vector2(20, 16)
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(20, 56)
	tabs.size = Vector2(320, 36)
	tabs.add_theme_constant_override("separation", 8)
	d.add_child(tabs)
	for t in ["ROOM", "FRIENDS", "SEARCH"]:
		var chip := ProductionTheme.chip(tabs, t, _tab == t, ProductionTheme.BLUEGREY)
		chip.custom_minimum_size = Vector2(0, 36)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.pressed.connect(_on_tab.bind(t))
	if _tab == "SEARCH":
		var field := ProductionTheme.text_field(d, "", "Search people")
		field.position = Vector2(20, 100)
		field.size = Vector2(320, 42)
		field.text_changed.connect(func(txt: String):
			_search = txt
			refresh())
	_body = Panel.new()
	_body.position = Vector2(20, 152 if _tab == "SEARCH" else 104)
	_body.size = Vector2(320, 400 if _tab == "SEARCH" else 420)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxEmpty.new()
	_body.add_theme_stylebox_override("panel", sb)
	d.add_child(_body)
	refresh()


static func presence_list(m: Node, autoloads: Dictionary) -> Array:
	# Generic presence format: future multiplayer replaces this provider.
	# Autoloads are passed in because static scope cannot see singletons.
	var out: Array = []
	out.append({
		"node": m.player, "name": str(autoloads.get("player_name", "You")),
		"you": true, "state": PeopleDrawer._player_state(m, autoloads),
	})
	for npc in m.npcs:
		if not is_instance_valid(npc):
			continue
		out.append({
			"node": npc, "name": PeopleDrawer._npc_name(npc),
			"you": false, "state": PeopleDrawer._npc_state(m, npc),
		})
	return out


static func _player_state(m: Node, autoloads: Dictionary) -> String:
	if bool(autoloads.get("focus_active", false)):
		return "Focusing %s" % ProductionTheme.countdown(int(autoloads.get("focus_remaining", 0)))
	if m.gameplay.seated():
		return "Seated · %s" % str(autoloads.get("current_tag", "Study"))
	return "Walking"


static func _npc_name(npc: Node) -> String:
	var label := str(npc.get("editor_display_name"))
	return label if label != "" else "Buddy"


static func _npc_state(m: Node, npc: Node) -> String:
	if bool(npc.get("seated")):
		var spot = npc.get("assigned_spot")
		if spot != null and is_instance_valid(spot):
			if str(spot.get("seat_type")) == "tanning_bed":
				return "Resting"
			return "Seated"
		return "Seated"
	return "Walking"


func _on_tab(t: String) -> void:
	_tab = t
	_build()


func refresh() -> void:
	for c in _body.get_children():
		c.queue_free()
	if _tab == "FRIENDS":
		var l := ProductionTheme.label(_body, "No friends yet.\nInvite friends to study together.", 14, ProductionTheme.INK_SOFT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.position = Vector2(60, 140)
		l.size = Vector2(200, 80)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return
	var rows := presence_list(main, _env)
	if _tab == "SEARCH":
		rows = rows.filter(func(e: Dictionary) -> bool:
			return _search == "" or str(e["name"]).to_lower().contains(_search.to_lower()))
	var y := 0.0
	for entry in rows:
		_row(entry, y)
		y += 64.0


func set_search(text: String) -> void:
	_search = text
	if _tab != "SEARCH":
		_tab = "SEARCH"
	refresh()


func _row(entry: Dictionary, y: float) -> void:
	var card := ProductionTheme.panel(_body, Rect2(0, y, 320, 56), ProductionTheme.PAPER_HI, 14)
	var dot := ColorRect.new()
	dot.color = ProductionTheme.GREEN if not bool(entry.get("you", false)) else ProductionTheme.AMBER
	dot.position = Vector2(12, 18)
	dot.size = Vector2(20, 20)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(dot)
	ProductionTheme.label(card, str(entry["name"]), 16, ProductionTheme.INK).position = Vector2(42, 6)
	ProductionTheme.label(card, str(entry["state"]), 12, ProductionTheme.INK_SOFT).position = Vector2(42, 28)
	var view := ProductionTheme.button(card, "View", ProductionTheme.PAPER, ProductionTheme.INK)
	view.position = Vector2(320 - 12 - 76, 10)
	view.size = Vector2(76, 36)
	view.pressed.connect(func(): ui.show_player_card(entry))
