extends Node

const HUD := preload("res://Scenes/Levels/game_ui.tscn")
const CONSOLE := preload("res://Scenes/Gameplay/ship_repair_console.tscn")
const LANDING := preload("res://Scenes/Levels/zone_67_prologue.tscn")
const OPTIONS := preload("res://Scenes/Levels/options.tscn")
const MENU := preload("res://Scenes/Levels/menu.tscn")
const CREDITS := preload("res://Scenes/Levels/credit.tscn")
const GAME_OVER := preload("res://Scenes/Levels/game_over.tscn")
const GAME_WIN := preload("res://Scenes/Levels/game_win.tscn")

const VIEWPORTS: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(1366, 768),
	Vector2i(640, 360),
	Vector2i(800, 360),
	Vector2i(360, 640),
	Vector2i(390, 844),
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run_test")


func _run_test() -> void:
	for viewport_size in VIEWPORTS:
		if !await _test_hud(viewport_size):
			return
		if !await _test_ship_console(viewport_size):
			return
	for viewport_size in [Vector2i(640, 360), Vector2i(360, 640)]:
		if !await _test_landing_intro(viewport_size):
			return
		if !await _test_unknown_ai(viewport_size):
			return
		if !await _test_static_screen(OPTIONS, "SettingsPanel", "SettingsPanel/Margin/ResponsiveShell/BackButton", viewport_size):
			return
		if !await _test_static_screen(MENU, "UI/MenuPanel", "UI/MenuPanel/Margin/MenuScroll/MenuItems/btnStart", viewport_size):
			return
		if !await _test_static_screen(CREDITS, "CreditsPanel", "CreditsPanel/Margin/ResponsiveShell/btnExit", viewport_size):
			return
		if !await _test_static_screen(GAME_OVER, "ResultPanel", "%PlayButton", viewport_size):
			return
		if !await _test_static_screen(GAME_WIN, "ResultPanel", "%PlayButton", viewport_size):
			return
	print("RESPONSIVE_UI_TEST: PASS")
	get_tree().quit()


func _test_hud(viewport_size: Vector2i) -> bool:
	GameManager.reset_new_game_state()
	var viewport := _make_viewport(viewport_size)
	var hud = HUD.instantiate()
	viewport.add_child(hud)
	await get_tree().process_frame
	await get_tree().process_frame
	hud.set_objective("Investigate the Abandoned Signal Base and recover the navigation components", "ZONE-67 // LONG OBJECTIVE WRAP CHECK")
	hud.set_interaction_prompt("E - INTERACT // SHIP CONSOLE")
	hud._apply_responsive_layout()
	await get_tree().process_frame
	var controls: Array[Control] = [
		hud.get_node("GameUI/StatusPanel"),
		hud.get_node("GameUI/ObjectivePanel"),
		hud.get_node("%SettingsButton"),
		hud.get_node("GameUI/MovementJoystick"),
		hud.get_node("GameUI/FireButton"),
		hud.get_node("GameUI/InteractButton"),
		hud.get_node("GameUI/MedKitButton"),
	]
	for control in controls:
		if control.visible and !_inside_viewport(control, viewport_size, "HUD/%s" % control.name):
			return false
	var joystick: Control = hud.get_node("GameUI/MovementJoystick")
	for action_path in ["GameUI/FireButton", "GameUI/InteractButton", "GameUI/MedKitButton"]:
		var action: Control = hud.get_node(action_path)
		if action.visible and joystick.get_global_rect().intersects(action.get_global_rect()):
			return _fail("HUD controls overlap at %s: joystick and %s" % [viewport_size, action.name])
	hud.alert_label.text = "OBJECTIVE UPDATED\nInvestigate the Abandoned Signal Base and recover every navigation component"
	hud.alert_panel.visible = true
	hud._layout_notification("OBJECTIVE")
	hud._sync_objective_visibility()
	if !_inside_viewport(hud.alert_panel, viewport_size, "ObjectiveNotification"):
		return false
	for action_path in ["GameUI/MovementJoystick", "GameUI/FireButton", "GameUI/InteractButton", "GameUI/MedKitButton"]:
		var action: Control = hud.get_node(action_path)
		if action.visible and hud.alert_panel.get_global_rect().intersects(action.get_global_rect()):
			return _fail("Notification overlaps %s at %s" % [action.name, viewport_size])
	hud.alert_panel.visible = false
	hud._sync_objective_visibility()
	hud.comm_text.text = "A long ECHO transmission must wrap without covering controls or leaving the visible screen."
	hud.comm_panel.visible = true
	hud._apply_responsive_layout()
	await get_tree().process_frame
	if !_inside_viewport(hud.comm_panel, viewport_size, "EchoPanel"):
		return false
	for action_path in ["GameUI/MovementJoystick", "GameUI/FireButton", "GameUI/InteractButton", "GameUI/MedKitButton"]:
		var action: Control = hud.get_node(action_path)
		if action.visible and hud.comm_panel.get_global_rect().intersects(action.get_global_rect()):
			return _fail("ECHO panel overlaps %s at %s" % [action.name, viewport_size])
	hud.comm_panel.visible = false
	hud._sync_objective_visibility()
	hud.show_boss("HIVE MATRIARCH", 2800, 2800, 1)
	await get_tree().process_frame
	if !_inside_viewport(hud.boss_panel, viewport_size, "BossHealth"):
		return false
	if hud.objective_panel.visible and hud.objective_panel.get_global_rect().intersects(hud.boss_panel.get_global_rect()):
		return _fail("Boss UI overlaps the objective at %s" % viewport_size)
	hud.set_settings_open(true)
	await get_tree().process_frame
	if !_inside_viewport(hud.settings_panel, viewport_size, "SettingsPanel"):
		return false
	if !_inside_viewport(hud.close_settings_button, viewport_size, "CloseSettingsButton"):
		return false
	if hud.settings_scroll == null:
		return _fail("In-game Settings has no scroll area")
	hud.set_settings_open(false)
	hud.queue_free()
	viewport.queue_free()
	await get_tree().process_frame
	return true


func _test_ship_console(viewport_size: Vector2i) -> bool:
	GameManager.reset_new_game_state()
	GameManager.add_item(&"energy_crystal", 3)
	GameManager.add_item(&"circuit_part", 2)
	GameManager.add_item(&"scrap_metal", 5)
	var viewport := _make_viewport(viewport_size)
	var console := CONSOLE.instantiate() as ShipRepairConsole
	viewport.add_child(console)
	await get_tree().process_frame
	await get_tree().process_frame
	if !_inside_viewport(console.console_panel, viewport_size, "ShipConsole"):
		return false
	if !_inside_viewport(console.close_button, viewport_size, "ShipConsole/CloseButton"):
		return false
	if console.page_root.get_parent() != console.page_scroll:
		return _fail("Ship Console page content is not inside its scroll area")
	console._show_section("weapon")
	await get_tree().process_frame
	if !_page_has_no_horizontal_overflow(console, "Weapon Upgrades"):
		return false
	console._show_section("repair")
	for system_id in ["power", "navigation", "engine"]:
		console._start_minigame(system_id)
		await get_tree().process_frame
		if !_page_has_no_horizontal_overflow(console, "%s mini-game" % system_id.capitalize()):
			return false
		console._cancel_minigame()
	console._close()
	viewport.queue_free()
	await get_tree().process_frame
	return true


func _page_has_no_horizontal_overflow(console: ShipRepairConsole, label: String) -> bool:
	var scroll_rect := console.page_scroll.get_global_rect()
	for node in console.page_root.find_children("*", "Button", true, false):
		var button := node as Button
		var rect := button.get_global_rect()
		if rect.position.x < scroll_rect.position.x - 1.0 or rect.end.x > scroll_rect.end.x + 1.0:
			return _fail("%s button overflows horizontally: %s" % [label, button.text])
	return true


func _test_landing_intro(viewport_size: Vector2i) -> bool:
	GameManager.reset_new_game_state()
	GameManager.landing_intro_seen = false
	var viewport := _make_viewport(viewport_size)
	var landing = LANDING.instantiate()
	viewport.add_child(landing)
	await get_tree().process_frame
	await get_tree().process_frame
	if !_inside_viewport(landing.story_panel, viewport_size, "LandingStoryPanel"):
		return false
	if !_inside_viewport(landing.continue_button, viewport_size, "LandingContinueButton"):
		return false
	if landing.story_scroll == null:
		return _fail("Landing story body is not scrollable")
	landing._finish_intro(false)
	landing.queue_free()
	viewport.queue_free()
	await get_tree().process_frame
	return true


func _test_unknown_ai(viewport_size: Vector2i) -> bool:
	var viewport := _make_viewport(viewport_size)
	var dialogue := UnknownAITerminal.UnknownAIDialogue.new()
	dialogue.add_to_group("DialogueUI")
	viewport.add_child(dialogue)
	await get_tree().process_frame
	await get_tree().process_frame
	if !_inside_viewport(dialogue.panel, viewport_size, "UnknownAI/Panel"):
		return false
	if !_inside_viewport(dialogue.close_button, viewport_size, "UnknownAI/CloseButton"):
		return false
	if dialogue.panel.find_child("DialogueScroll", true, false) == null:
		return _fail("UNKNOWN AI dialogue has no scrollable content area")
	dialogue._close()
	viewport.queue_free()
	await get_tree().process_frame
	return true


func _test_static_screen(scene: PackedScene, panel_path: String, action_path: String, viewport_size: Vector2i) -> bool:
	var viewport := _make_viewport(viewport_size)
	var instance := scene.instantiate()
	viewport.add_child(instance)
	await get_tree().process_frame
	await get_tree().process_frame
	var panel := instance.get_node(panel_path) as Control
	var action := instance.get_node(action_path) as Control
	if !_inside_viewport(panel, viewport_size, "%s/%s" % [instance.name, panel.name]):
		return false
	if !_inside_viewport(action, viewport_size, "%s/%s" % [instance.name, action.name]):
		return false
	instance.queue_free()
	viewport.queue_free()
	await get_tree().process_frame
	return true


func _make_viewport(viewport_size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	return viewport


func _inside_viewport(control: Control, viewport_size: Vector2i, label: String) -> bool:
	var rect := control.get_global_rect()
	var bounds := Rect2(Vector2.ZERO, Vector2(viewport_size))
	if rect.position.x < -1.0 or rect.position.y < -1.0 or rect.end.x > bounds.end.x + 1.0 or rect.end.y > bounds.end.y + 1.0:
		return _fail("%s escaped %s: %s" % [label, viewport_size, rect])
	return true


func _fail(message: String) -> bool:
	push_error("RESPONSIVE_UI_TEST: " + message)
	get_tree().paused = false
	get_tree().quit(1)
	return false
