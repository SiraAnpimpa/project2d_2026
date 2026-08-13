extends Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run_test")


func _run_test() -> void:
	var hud_scene: PackedScene = load("res://Scenes/Levels/game_ui.tscn")
	var hud = hud_scene.instantiate()
	add_child(hud)
	await get_tree().process_frame
	if "--preview-settings" in OS.get_cmdline_user_args():
		hud.set_settings_open(true)
		return
	if "--preview-main-menu" in OS.get_cmdline_user_args():
		hud.set_settings_open(true)
		await get_tree().process_frame
		hud.get_node("SettingsOverlay/SettingsPanel/Margin/Content/MainMenuButton").pressed.emit()
		return

	var up: Button = hud.get_node("GameUI/DPad/Up")
	var left: Button = hud.get_node("GameUI/DPad/Left")
	var right: Button = hud.get_node("GameUI/DPad/Right")
	var down: Button = hud.get_node("GameUI/DPad/Down")
	print("DPAD_RECTS: ", up.get_global_rect(), " | ", left.get_global_rect(), " | ", right.get_global_rect(), " | ", down.get_global_rect())
	if up.global_position.y >= left.global_position.y:
		_fail("Up control is not above the horizontal pair")
		return
	if down.global_position.y <= left.global_position.y:
		_fail("Down control is not below the horizontal pair")
		return
	if left.global_position.x >= up.global_position.x or right.global_position.x <= up.global_position.x:
		_fail("Left and right controls do not form a cross")
		return
	if left.global_position.x < 0.0 or right.global_position.x + right.size.x > get_viewport().get_visible_rect().size.x:
		_fail("D-pad is outside the visible viewport")
		return
	if hud.has_node("GameUI/TopBar/SystemPanel") or hud.has_node("GameUI/BottomBar/MoveControls"):
		_fail("Legacy gameplay UI is still present")
		return

	var objective_panel: PanelContainer = hud.get_node("GameUI/ObjectivePanel")
	var objective_label: Label = hud.get_node("GameUI/ObjectivePanel/Margin/Content/ObjectiveLabel")
	var objective_meta: Label = hud.get_node("GameUI/ObjectivePanel/Margin/Content/ObjectiveMetaLabel")
	var settings_button: Button = hud.get_node("GameUI/SettingsButton")
	hud.set_objective("FIND THE SIGNAL ORIGIN", "ZONE-67 // ACTIVE MISSION")
	if objective_panel.size.x < 440.0 or objective_panel.size.y < 90.0:
		_fail("Mission panel is not prominent enough")
		return
	if objective_label.text != "FIND THE SIGNAL ORIGIN" or objective_meta.text != "ZONE-67 // ACTIVE MISSION":
		_fail("Mission title and details are not both visible")
		return
	if settings_button.text != "SETTINGS" or "SYS" in settings_button.text:
		_fail("System button was not replaced by Settings")
		return
	var telemetry_font: Font = hud.get_node("GameUI/StatusPanel/Margin/Content/Header/Protocol").get_theme_font("font")
	var mission_font: Font = objective_label.get_theme_font("font")
	if telemetry_font == mission_font:
		_fail("Mission and telemetry typography roles are not distinct")
		return

	hud.set_settings_open(true)
	await get_tree().process_frame
	if !hud.get_node("SettingsOverlay").visible or !get_tree().paused:
		_fail("In-game settings did not open and pause gameplay")
		return
	var main_menu_button: Button = hud.get_node("SettingsOverlay/SettingsPanel/Margin/Content/MainMenuButton")
	if main_menu_button.text.find("MAIN MENU") < 0 or main_menu_button.pressed.get_connections().is_empty():
		_fail("Main Menu action is missing from Settings")
		return
	hud.set_settings_open(false)
	if get_tree().paused:
		_fail("Closing settings did not resume gameplay")
		return

	hud.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	hud = null
	hud_scene = null
	print("GAMEPLAY_SYSTEM_TEST: PASS")
	get_tree().quit()


func _fail(message: String) -> void:
	push_error("GAMEPLAY_SYSTEM_TEST: " + message)
	get_tree().paused = false
	get_tree().quit(1)
