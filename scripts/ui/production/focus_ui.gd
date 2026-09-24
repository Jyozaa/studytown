class_name FocusUI
extends Control
## Compact focus flow: setup panel (left), active timer card, completion.
## Reads GameplayFlow/FocusManager/GameState; all actions call GameplayFlow.

var ui = null
var main = null
var _setup_panel: Control = null
var _active_card: Control = null
var _active_label: Label = null
var _complete_panel: Control = null
var _durations := [5, 15, 25, 50]
var _duration_idx := 2


func setup(controller, owner_node: Node, parent: Control) -> void:
	ui = controller
	main = owner_node
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(self)
	refresh()


func _clear() -> void:
	for child in get_children():
		child.queue_free()
	_setup_panel = null
	_active_card = null
	_active_label = null
	_complete_panel = null


func refresh() -> void:
	_clear()
	if main.screen != main.Screen.ROOM and main.screen != main.Screen.FOCUS:
		return
	if FocusManager.active:
		_build_active()
	elif main.gameplay.seated() and main.screen == main.Screen.ROOM:
		_build_setup()
	elif main.screen == main.Screen.ROOM:
		_build_idle()


func _build_setup() -> void:
	_setup_panel = ProductionTheme.panel(self, Rect2(16, 120, 330, 470))
	var setup_head := ProductionTheme.section(_setup_panel, "Focus setup")
	setup_head.position = Vector2(16, 10)
	setup_head.size = Vector2(200, 20)
	ProductionTheme.label(_setup_panel, "Start focus session", 19, ProductionTheme.INK).position = Vector2(16, 34)
	_setup_panel.get_child(1).size = Vector2(298, 28)
	var mins: int = _durations[_duration_idx]
	var big := ProductionTheme.label(_setup_panel, "%d min" % mins, 46, ProductionTheme.INK)
	big.position = Vector2(16, 66)
	big.size = Vector2(298, 56)
	var slider := ProductionTheme.slider(_setup_panel, 0.0, 3.0, 1.0, float(_duration_idx))
	slider.position = Vector2(16, 130)
	slider.size = Vector2(298, 26)
	slider.value_changed.connect(func(v: float):
		_duration_idx = int(v)
		refresh())
	var tick_row := HBoxContainer.new()
	tick_row.position = Vector2(16, 158)
	tick_row.size = Vector2(298, 18)
	tick_row.add_theme_constant_override("separation", 58)
	tick_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_panel.add_child(tick_row)
	for d in _durations:
		var t := Label.new()
		t.text = "%dm" % d
		t.add_theme_font_size_override("font_size", 12)
		t.add_theme_color_override("font_color", ProductionTheme.INK_FAINT)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tick_row.add_child(t)
	var tag_head := ProductionTheme.section(_setup_panel, "Tag")
	tag_head.position = Vector2(16, 184)
	tag_head.size = Vector2(200, 20)
	var tag_row := HBoxContainer.new()
	tag_row.position = Vector2(16, 206)
	tag_row.add_theme_constant_override("separation", 8)
	_setup_panel.add_child(tag_row)
	for tag in GameState.tags:
		var chip := ProductionTheme.chip(tag_row, str(tag), str(tag) == str(GameState.current_tag))
		chip.custom_minimum_size = Vector2(0, 34)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.pressed.connect(_on_tag.bind(str(tag)))
	var proj: int = GameState.projected_reward(_durations[_duration_idx])
	var rw := ProductionTheme.label(_setup_panel, "Reward  ◈ +%d" % proj, 16, ProductionTheme.GREEN_DARK)
	rw.position = Vector2(16, 252)
	rw.size = Vector2(298, 26)
	var hint := ProductionTheme.label(_setup_panel, "1 point / minute · +5 bonus at 25+", 12, ProductionTheme.INK_FAINT)
	hint.position = Vector2(16, 280)
	hint.size = Vector2(298, 20)
	var start := ProductionTheme.primary_button(_setup_panel, "Start Session")
	start.position = Vector2(16, 308)
	start.size = Vector2(298, 52)
	start.pressed.connect(_on_start)
	var cancel := ProductionTheme.button(_setup_panel, "Stand up", ProductionTheme.PAPER_HI, ProductionTheme.INK)
	cancel.position = Vector2(16, 368)
	cancel.size = Vector2(298, 44)
	cancel.pressed.connect(func(): await main.gameplay.stand_up())


func _on_tag(tag: String) -> void:
	GameState.current_tag = tag
	GameState.save()
	refresh()


func _on_start() -> void:
	var res: String = main.gameplay.start_focus(_durations[_duration_idx] * 60)
	if res != "ok":
		ProductionTheme.toast(get_parent(), "Could not start session.")


func _build_idle() -> void:
	var vp := ProductionTheme.vp_size(self)
	var pill := ProductionTheme.panel(self, Rect2(vp.x - 16 - 250, vp.y - 16 - 64, 250, 64))
	ProductionTheme.label(pill, "Find a seat to focus", 14, ProductionTheme.INK_SOFT).position = Vector2(16, 0)


func _build_active() -> void:
	var vpa := ProductionTheme.vp_size(self)
	_active_card = ProductionTheme.panel(self, Rect2(vpa.x - 16 - 250, vpa.y - 16 - 120, 250, 120))
	var act_head := ProductionTheme.section(_active_card, "Focus")
	act_head.position = Vector2(14, 8)
	act_head.size = Vector2(200, 20)
	_active_label = ProductionTheme.label(_active_card, "--:--", 42, ProductionTheme.INK)
	_active_label.position = Vector2(14, 26)
	_active_label.size = Vector2(150, 52)
	var tag: String = str(GameState.current_tag)
	if str(GameState.current_focus) != "":
		tag = "%s · %s" % [tag, str(GameState.current_focus).left(18)]
	var tag_label := ProductionTheme.label(_active_card, tag, 12, ProductionTheme.INK_SOFT)
	tag_label.position = Vector2(14, 78)
	tag_label.size = Vector2(150, 20)
	tag_label.clip_text = true
	var end_btn := ProductionTheme.button(_active_card, "End", ProductionTheme.CORAL, Color("#FDF8EA"))
	end_btn.position = Vector2(168, 30)
	end_btn.size = Vector2(68, 60)
	end_btn.pressed.connect(func(): await main.gameplay.cancel_focus())


func show_completion(minutes: int, reward_amount: int) -> void:
	_clear()
	var vpc := ProductionTheme.vp_size(self)
	_complete_panel = ProductionTheme.modal(self, Rect2(vpc.x * 0.5 - 200, vpc.y * 0.5 - 170, 400, 340))
	ProductionTheme.label(_complete_panel, "Session complete", 23, ProductionTheme.INK).position = Vector2(24, 20)
	var big := ProductionTheme.label(_complete_panel, "◈ +%d" % reward_amount, 46, ProductionTheme.GREEN_DARK)
	big.position = Vector2(24, 60)
	big.size = Vector2(352, 56)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := ProductionTheme.label(_complete_panel, "%d minutes · %s" % [minutes, str(GameState.current_tag)], 14, ProductionTheme.INK_SOFT)
	sub.position = Vector2(24, 120)
	sub.size = Vector2(352, 24)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var again := ProductionTheme.primary_button(_complete_panel, "Another Session")
	again.position = Vector2(24, 160)
	again.size = Vector2(352, 50)
	again.pressed.connect(func():
		_complete_panel.queue_free()
		_complete_panel = null
		refresh())
	var row := HBoxContainer.new()
	row.position = Vector2(24, 220)
	row.size = Vector2(352, 44)
	row.add_theme_constant_override("separation", 12)
	_complete_panel.add_child(row)
	var take_break := ProductionTheme.button(row, "Take Break")
	take_break.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	take_break.pressed.connect(func():
		_complete_panel.queue_free()
		_complete_panel = null
		await main.gameplay.start_break()
		refresh())
	var stand := ProductionTheme.button(row, "Stand Up")
	stand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stand.pressed.connect(func():
		_complete_panel.queue_free()
		_complete_panel = null
		await main.gameplay.stand_up()
		refresh())


func tick() -> void:
	if _active_label != null and is_instance_valid(_active_label) and FocusManager.active:
		_active_label.text = ProductionTheme.countdown(FocusManager.get_remaining_seconds())
