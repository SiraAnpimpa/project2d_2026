class_name EnemySpawnSlot
extends Marker2D

@export var enemy_scene: PackedScene
@export var spawn_on_entry := true
@export var slot_enabled := true
@export var slot_id: StringName

var active_enemy: AlienEnemy = null
var respawn_remaining := 0.0
var waiting_for_respawn := false


func is_available() -> bool:
	return slot_enabled and !is_instance_valid(active_enemy)


func arm_respawn(delay: float) -> void:
	active_enemy = null
	respawn_remaining = maxf(delay, 0.0)
	waiting_for_respawn = true


func mark_spawned(enemy: AlienEnemy) -> void:
	active_enemy = enemy
	respawn_remaining = 0.0
	waiting_for_respawn = false
