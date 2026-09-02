class_name ShipConsoleInteractable
extends Interactable

const CONSOLE := preload("res://Scenes/Gameplay/ship_repair_console.tscn")


func _ready() -> void:
	super._ready()
	interaction_radius = 135.0
	GameManager.final_defense_completed.connect(_on_defense_completed)
	_update_prompt()


func interact(_player: Node2D) -> void:
	if GameManager.final_defense_done and GameManager.are_all_systems_repaired():
		get_tree().change_scene_to_file("res://Scenes/Levels/game_win.tscn")
		return
	if GameManager.final_defense_active:
		var hud := get_tree().get_first_node_in_group("GameHUD")
		if hud != null:
			hud.alert("LAUNCH LOCKED // DEFEND THE SHIP")
		return
	if get_tree().get_first_node_in_group("ShipRepairUI") != null:
		return
	var console := CONSOLE.instantiate()
	console.add_to_group("ShipRepairUI")
	get_tree().current_scene.add_child(console)
	GameManager.set_objective("Repair the three primary ship systems", GameManager.get_ship_status_text())


func get_prompt() -> String:
	if GameManager.final_defense_done:
		return "E - BOARD SHIP / LAUNCH"
	return "E - ACCESS REPAIR CONSOLE"


func _on_defense_completed() -> void:
	_update_prompt()


func _update_prompt() -> void:
	prompt = get_prompt()
