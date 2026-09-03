class_name AcidPool
extends Area2D

@export var tick_damage := 6
@export var tick_interval := 0.75

var player_inside := false
var tick_remaining := 0.0


func _ready() -> void:
	add_to_group("EnvironmentalHazard")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if !player_inside or get_tree().paused:
		return
	tick_remaining -= delta
	if tick_remaining <= 0.0:
		tick_remaining = tick_interval
		GameManager.damage(tick_damage)
		var player := GameManager.player
		if is_instance_valid(player) and player.has_method("hit_feedback"):
			player.hit_feedback(Color(0.45, 1.0, 0.12))


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_inside = true
		tick_remaining = 0.05


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_inside = false

