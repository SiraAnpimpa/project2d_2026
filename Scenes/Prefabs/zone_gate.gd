class_name ZoneGate
extends Area2D

@export_file("*.tscn") var target_scene := ""
@export var target_spawn: StringName = &"Default"
@export var gate_label := "ZONE LINK"
@export var accent_color := Color(0.286, 0.843, 1.0, 0.48)
@export_enum("none", "base", "hive", "boss") var progression_requirement := "none"
@export var interaction_radius := 125.0

@onready var field: Polygon2D = $Field
@onready var label: Label = $Label

var animation_time := 0.0
var transitioning := false


func _ready() -> void:
	add_to_group("Interactable")
	field.color = accent_color
	label.text = gate_label


func _process(delta: float) -> void:
	animation_time += delta
	field.modulate.a = 0.72 + sin(animation_time * 3.0) * 0.2


func can_interact(_player: Node2D) -> bool:
	return !transitioning and visible


func get_interaction_position() -> Vector2:
	return global_position


func get_prompt() -> String:
	return "E - INTERACT // EXIT // %s" % gate_label


func interact(_player: Node2D) -> void:
	if transitioning:
		return
	if !_can_travel():
		var hud := get_tree().get_first_node_in_group("GameHUD")
		if hud != null and hud.has_method("alert"):
			var reason := "ACCESS CARD REQUIRED" if progression_requirement == "base" else "COMPLETE PRIMARY REPAIRS AND STORY OBJECTIVES"
			hud.alert("ACCESS LOCKED // " + reason, "WARNING", 6)
		return
	transitioning = true
	set_deferred("monitoring", false)
	GameManager.call_deferred("travel_to", target_scene, target_spawn)


func _can_travel() -> bool:
	match progression_requirement:
		"base": return GameManager.can_enter_signal_base()
		"hive": return GameManager.can_enter_hive()
		"boss": return GameManager.can_enter_boss_arena()
		_: return true
