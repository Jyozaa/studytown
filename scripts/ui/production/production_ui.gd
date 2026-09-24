class_name ProductionUI
extends Node
## Production presentation layer (world-first, cream identity).
## Owns NO gameplay: all actions go through GameplayFlow / FocusManager /
## GameState. Reacts to gameplay signals. Hidden entirely in --dev-strip.

enum Mode { SPLASH, WELCOME, ONBOARDING, MAP, ROOM }

const TransitionFX := preload("res://scripts/ui/production/pixel_transition.gd")
const AuthService := preload("res://scripts/services/auth_service.gd")

var main = null
var mode: int = Mode.SPLASH
var layer: CanvasLayer
var root: Control
var hud = null
var map = null
var focus_ui = null
var music_ui = null
var settings_ui = null
var people = null
var chat = null
var minimap = null
var player_card = null
var onboarding = null
var transition = null
var _splash_t := 0.0
var _map_return_room := -1


func configure(owner_node: Node) -> void:
	main = owner_node
	layer = CanvasLayer.new()
	layer.layer = 40
	main.add_child(layer)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var gp = main.gameplay
	gp.seat_taken.connect(_on_seat_taken)
	gp.stood_up.connect(_on_stood_up)
	gp.focus_started.connect(_on_focus_started)
	gp.focus_completed.connect(_on_focus_completed)
	gp.focus_cancelled.connect(_on_focus_cancelled)
	gp.room_changed.connect(_on_room_changed)


func boot() -> void:
	# Called for normal production startup (menu world behind).
	if str(GameState.auth_email).is_empty():
		_show_splash()
	else:
		_show_splash()


func _show_splash() -> void:
	_set_mode(Mode.SPLASH)
	_clear_overlays()
	var c := ProductionTheme.label(root, "StudyTown", 40, ProductionTheme.INK)
	var svp := ProductionTheme.vp_size(root)
	c.position = Vector2(svp.x * 0.5 - 150, svp.y * 0.5 - 60)
	c.size = Vector2(300, 60)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_splash_t = 0.0
	await get_tree().create_timer(0.9).timeout
	if mode != Mode.SPLASH:
		return
	if str(GameState.auth_email).is_empty():
		_show_welcome()
	elif not bool(GameState.onboarding_complete):
		_show_onboarding()
	else:
		open_map(false)


func _set_mode(m: int) -> void:
	mode = m
	_close_all_layers()


func _clear_overlays() -> void:
	for child in root.get_children():
		child.queue_free()
	hud = null
	map = null
	focus_ui = null
	music_ui = null
	settings_ui = null
	people = null
	chat = null
	minimap = null
	player_card = null
	onboarding = null


func _close_all_layers() -> void:
	_clear_overlays()


# ---- entry screens -------------------------------------------------------

func _show_welcome() -> void:
	_set_mode(Mode.WELCOME)
	_clear_overlays()
	onboarding = OnboardingUI.new()
	onboarding.setup(self, main, root, OnboardingUI.Page.WELCOME, {})


func _show_onboarding() -> void:
	onboarding_goto(1)


# ---- map -----------------------------------------------------------------

func open_map(from_exit := false) -> void:
	if mode == Mode.MAP or main.gameplay.busy:
		return
	if FocusManager.active:
		ProductionTheme.toast(root, "Finish or end your focus session before travelling.")
		return
	if main.gameplay.seated():
		_map_return_room = GameState.selected_room
		main._set_movement_enabled(false)
	_set_mode(Mode.MAP)
	_clear_overlays()
	map = WorldMap.open(root, _current_location_id())
	map.closed.connect(close_map)
	map.travel_requested.connect(travel_to)


func close_map() -> void:
	if mode != Mode.MAP:
		return
	if map != null and is_instance_valid(map):
		map.queue_free()
	map = null
	_map_return_room = -1
	if main.screen == main.Screen.ROOM:
		_enter_room_hud()


func _current_location_id() -> String:
	var entry: Dictionary = UIAssetRegistry.location_for_room(GameState.selected_room)
	return str(entry.get("id", ""))


func travel_to(room_index: int) -> void:
	if main.gameplay.busy:
		return
	if FocusManager.active:
		ProductionTheme.toast(root, "Finish or end your focus session before travelling.")
		return
	close_all_popovers()
	main._set_movement_enabled(false)
	var travel := func():
		if main.gameplay.seated():
			await main.gameplay.stand_up()
		main._enter_room(room_index)
		main._set_movement_enabled(true)
		_enter_room_hud()
	PixelTransition.play(get_tree(), _reduced_motion(), travel)


func _reduced_motion() -> bool:
	return bool(GameState.preferences.get("reduced_motion", false))


func _enter_room_hud() -> void:
	_set_mode(Mode.ROOM)
	_clear_overlays()
	hud = WorldHUD.new()
	hud.setup(self, main, root)
	focus_ui = FocusUI.new()
	focus_ui.setup(self, main, root)
	music_ui = MusicUI.new()
	music_ui.setup(self, main, root)
	_refresh_focus_panels()


# ---- popovers / drawers ---------------------------------------------------

func close_all_popovers() -> void:
	for key in ["people", "chat", "settings_ui", "player_card", "minimap"]:
		var node = get(key)
		if node != null and is_instance_valid(node):
			node.queue_free()
		set(key, null)


func toggle_people() -> void:
	if people != null and is_instance_valid(people):
		people.queue_free()
		people = null
		return
	close_all_popovers()
	people = PeopleDrawer.new()
	people.setup(self, main, root, {
		"player_name": str(GameState.profile.get("name", "You")),
		"focus_active": FocusManager.active,
		"focus_remaining": FocusManager.get_remaining_seconds(),
		"current_tag": str(GameState.current_tag),
	})


func toggle_chat() -> void:
	if chat != null and is_instance_valid(chat):
		chat.queue_free()
		chat = null
		return
	close_all_popovers()
	chat = LocalChat.new()
	chat.setup(self, main, root)


func toggle_settings() -> void:
	if settings_ui != null and is_instance_valid(settings_ui):
		settings_ui.queue_free()
		settings_ui = null
		return
	close_all_popovers()
	settings_ui = SettingsUI.new()
	settings_ui.setup(self, main, root)


func toggle_minimap() -> void:
	if minimap != null and is_instance_valid(minimap):
		minimap.queue_free()
		minimap = null
		return
	close_all_popovers()
	minimap = MiniMap.new()
	minimap.setup(self, main, root)


func show_player_card(occupant: Dictionary) -> void:
	if player_card != null and is_instance_valid(player_card):
		player_card.queue_free()
	player_card = PlayerCard.new()
	player_card.setup(self, main, root, occupant)


# ---- focus wiring ----------------------------------------------------------

func _refresh_focus_panels() -> void:
	if focus_ui != null and is_instance_valid(focus_ui):
		focus_ui.refresh()


func _on_seat_taken(_seat_id: String) -> void:
	_refresh_focus_panels()


func _on_stood_up() -> void:
	_refresh_focus_panels()


func _on_focus_started(_minutes: int) -> void:
	# focus_started emits before FocusManager.start_session flips active, so
	# refresh deferred: the active card needs FocusManager.active == true.
	_refresh_focus_panels.call_deferred()


func _on_focus_completed(minutes: int, reward_amount: int) -> void:
	# Stay seated with the room screen behind the completion modal so
	# Another Session rebuilds setup and Stand Up exits cleanly.
	if main != null:
		main.screen = main.Screen.ROOM
	if focus_ui != null and is_instance_valid(focus_ui):
		focus_ui.show_completion(minutes, reward_amount)
	else:
		_refresh_focus_panels()


func _on_focus_cancelled() -> void:
	_refresh_focus_panels()


func _on_room_changed(_index: int) -> void:
	if mode == Mode.ROOM:
		_enter_room_hud()


func _process(_delta: float) -> void:
	if hud != null and is_instance_valid(hud):
		hud.tick()
	if focus_ui != null and is_instance_valid(focus_ui):
		focus_ui.tick()
	if minimap != null and is_instance_valid(minimap):
		minimap.tick()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var focus_owner := get_viewport().gui_get_focus_owner()
		if focus_owner is LineEdit:
			return
		if (event as InputEventKey).keycode == KEY_M and mode == Mode.ROOM:
			open_map()
			get_viewport().set_input_as_handled()
		elif (event as InputEventKey).keycode == KEY_F9:
			_toggle_dev_panel()
			get_viewport().set_input_as_handled()
		elif (event as InputEventKey).keycode == KEY_ESCAPE:
			if close_topmost():
				get_viewport().set_input_as_handled()


func close_topmost() -> bool:
	if player_card != null and is_instance_valid(player_card):
		player_card.queue_free()
		player_card = null
		return true
	if settings_ui != null and is_instance_valid(settings_ui):
		settings_ui.queue_free()
		settings_ui = null
		return true
	if people != null and is_instance_valid(people):
		people.queue_free()
		people = null
		return true
	if chat != null and is_instance_valid(chat):
		chat.queue_free()
		chat = null
		return true
	if minimap != null and is_instance_valid(minimap):
		minimap.queue_free()
		minimap = null
		return true
	if mode == Mode.MAP:
		close_map()
		return true
	return false


func _toggle_dev_panel() -> void:
	# F9: summon the stripped dev panel inside production (hidden by default).
	if main.dev_panel != null and is_instance_valid(main.dev_panel):
		main.dev_panel.toggle_collapsed()
		return
	main.dev_panel = preload("res://scripts/dev/dev_panel.gd").new()
	main.add_child(main.dev_panel)
	main.dev_panel.setup(main)
	main.dev_panel.refresh()


# ---- auth / onboarding ------------------------------------------------------

func auth_submit(email: String, password: String, signup: bool) -> void:
	var svc = AuthService.new()
	var result: Dictionary = svc.create_account(email, password) if signup else svc.sign_in(email, password)
	if result.is_empty():
		_show_welcome()
		ProductionTheme.toast(root, "Could not sign in — check email and password.")
		return
	GameState.auth_email = str(result.get("email", email))
	GameState.save()
	if not bool(GameState.onboarding_complete):
		onboarding_goto(1)
	else:
		open_map(false)


func auth_swap() -> void:
	_show_welcome()


func onboarding_goto(step: int) -> void:
	if step < 1:
		_show_welcome()
		return
	if step > 4:
		GameState.onboarding_complete = true
		GameState.save()
		open_map(false)
		return
	_set_mode(Mode.ONBOARDING)
	_clear_overlays()
	onboarding = OnboardingUI.new()
	onboarding.setup(self, main, root, step, {"selected_character": int(GameState.selected_character)})


func onboarding_pick_character(index: int) -> void:
	GameState.selected_character = index
	GameState.save()
	if main.get("character_loader") != null:
		main.player_visual = main._create_character(main.player, index, false) if is_instance_valid(main.player) else main.player_visual
	_clear_overlays()
	onboarding = OnboardingUI.new()
	onboarding.setup(self, main, root, 2, {"selected_character": int(GameState.selected_character)})


func request_exit() -> void:
	# Doorway threshold reached: stand if idly seated, never strand a session.
	if FocusManager.active:
		ProductionTheme.toast(root, "Finish or end your focus session before travelling.")
		return
	if transitioning_guard():
		return
	open_map_from_exit()


func transitioning_guard() -> bool:
	return main.gameplay.busy


func open_map_from_exit() -> void:
	# Seated-but-idle players stand through gameplay, then the map opens.
	if main.gameplay.seated() and not FocusManager.active:
		await main.gameplay.stand_up()
	open_map()
