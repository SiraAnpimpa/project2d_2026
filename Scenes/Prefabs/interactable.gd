class_name Interactable
extends Node2D

@export var prompt := "E - INTERACT"
@export var interaction_radius := 115.0
@export var requires_line_of_sight := false
var enabled := true


func _ready() -> void:
	add_to_group("Interactable")


func can_interact(_player: Node2D) -> bool:
	return enabled and is_visible_in_tree()


func get_prompt() -> String:
	return prompt


func get_interaction_position() -> Vector2:
	return global_position


func interact(_player: Node2D) -> void:
	return
