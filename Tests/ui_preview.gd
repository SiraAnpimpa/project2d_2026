extends Node

const HUD := preload("res://Scenes/Levels/game_ui.tscn")
const CONSOLE := preload("res://Scenes/Gameplay/ship_repair_console.tscn")
const LANDING := preload("res://Scenes/Levels/zone_67_prologue.tscn")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.reset_new_game_state()
	var mode := "ship"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-preview="):
			mode = argument.trim_prefix("--ui-preview=")
	match mode:
		"hud": _preview_hud()
		"intro": _preview_intro()
		"unknown": _preview_unknown_ai()
		_: _preview_ship_console()


func _add_background() -> void:
	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.005, 0.012, 0.028)
	add_child(background)


func _preview_ship_console() -> void:
	_add_background()
	GameManager.add_item(&"energy_crystal", 3)
	GameManager.add_item(&"circuit_part", 2)
	GameManager.add_item(&"scrap_metal", 5)
	add_child(CONSOLE.instantiate())


func _preview_hud() -> void:
	_add_background()
	var hud = HUD.instantiate()
	add_child(hud)
	hud.set_objective("Investigate the Abandoned Signal Base", "ZONE-67 // OBJECTIVE AND BOSS REGION CHECK")
	hud.set_interaction_prompt("E - INTERACT // TERMINAL")
	hud.show_boss("HIVE MATRIARCH", 2800, 1940, 2)


func _preview_intro() -> void:
	GameManager.landing_intro_seen = false
	add_child(LANDING.instantiate())


func _preview_unknown_ai() -> void:
	_add_background()
	var dialogue := UnknownAITerminal.UnknownAIDialogue.new()
	dialogue.add_to_group("DialogueUI")
	add_child(dialogue)
