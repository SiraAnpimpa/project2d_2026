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
		hud.main_menu_button.pressed.emit()
		return

	var movement_joystick: Control = hud.get_node("GameUI/MovementJoystick")
	var fire_button: Button = hud.get_node("GameUI/FireButton")
	var medkit_button: Button = hud.get_node("GameUI/MedKitButton")
	if movement_joystick == null or fire_button == null or medkit_button == null:
		_fail("Final mobile controls were not created")
		return
	if hud.has_node("GameUI/DPad"):
		_fail("Legacy movement D-pad is still present")
		return
	if hud.has_node("GameUI/AimShootJoystick"):
		_fail("Removed right aim analog is still present")
		return
	if "FIRE" not in fire_button.text or "MEDKIT" not in medkit_button.text:
		_fail("Mobile action buttons do not have readable labels")
		return
	if hud.has_node("GameUI/TopBar/SystemPanel") or hud.has_node("GameUI/BottomBar/MoveControls"):
		_fail("Legacy gameplay UI is still present")
		return
	if movement_joystick.get_global_rect().intersects(fire_button.get_global_rect()) or fire_button.get_global_rect().intersects(medkit_button.get_global_rect()):
		_fail("Mobile controls overlap")
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
	var main_menu_button: Button = hud.main_menu_button
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
