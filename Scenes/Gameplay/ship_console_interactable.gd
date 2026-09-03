class_name ShipConsoleInteractable
extends Interactable

const CONSOLE := preload("res://Scenes/Gameplay/ship_repair_console.tscn")


func _ready() -> void:
	super._ready()
	interaction_radius = 135.0
	_update_prompt()


func interact(_player: Node2D) -> void:
	if GameManager.can_launch():
		get_tree().change_scene_to_file("res://Scenes/Levels/game_win.tscn")
		return
	if get_tree().get_first_node_in_group("ShipRepairUI") != null:
		return
	var console := CONSOLE.instantiate()
	console.add_to_group("ShipRepairUI")
	get_tree().current_scene.add_child(console)
	if !GameManager.are_all_systems_repaired():
		GameManager.set_objective("Repair the three primary ship systems", GameManager.get_ship_status_text())


func get_prompt() -> String:
	if GameManager.can_launch():
		return "E - BOARD SHIP / LAUNCH"
	if GameManager.get_item_count(&"final_core") > 0:
		return "E - INSTALL FINAL CORE"
	return "E - ACCESS SHIP CONSOLE"


func _update_prompt() -> void:
	prompt = get_prompt()
