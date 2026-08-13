class_name ZoneGate
extends Area2D

@export_file("*.tscn") var target_scene := ""
@export var target_spawn: StringName = &"Default"
@export var gate_label := "ZONE LINK"
@export var accent_color := Color(0.286, 0.843, 1.0, 0.48)

@onready var field: Polygon2D = $Field
@onready var label: Label = $Label

var animation_time := 0.0
var transitioning := false


func _ready() -> void:
	field.color = accent_color
	label.text = gate_label


func _process(delta: float) -> void:
	animation_time += delta
	field.modulate.a = 0.72 + sin(animation_time * 3.0) * 0.2


func _on_body_entered(body: Node2D) -> void:
	if transitioning or !body.is_in_group("Player"):
		return
	transitioning = true
	set_deferred("monitoring", false)
	GameManager.call_deferred("travel_to", target_scene, target_spawn)
