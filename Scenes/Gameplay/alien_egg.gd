class_name AlienEgg
extends Node2D

@export var enemy_scenes: Array[PackedScene] = []
@export_range(32.0, 800.0, 8.0) var activation_distance := 180.0
@export_range(0.1, 300.0, 0.1) var reactivation_time := 30.0
@export var active := true

@onready var visual: Node2D = $Visual
@onready var shell: Polygon2D = $Visual/Shell

var cooldown_remaining := 0.0
var hatching := false
var _manager: EnemyRespawnManager = null


func _ready() -> void:
	add_to_group("AlienEgg")
	_manager = _find_respawn_manager()


func _process(delta: float) -> void:
	if !active or get_tree().paused:
		return
	cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)
	if hatching or cooldown_remaining > 0.0 or _manager == null:
		return
	var active_player := GameManager.player as Node2D
	if !is_instance_valid(active_player):
		return
	if active_player.global_position.distance_to(global_position) <= activation_distance:
		_start_hatch()


func _start_hatch() -> void:
	if hatching or !_manager.can_spawn_external() or enemy_scenes.is_empty():
		return
	for egg_node in get_tree().get_nodes_in_group("AlienEgg"):
		var other_egg := egg_node as AlienEgg
		if other_egg != null and other_egg != self and other_egg.hatching:
			return
	hatching = true
	var warning := create_tween().set_loops(3)
	warning.tween_property(visual, "position:x", -6.0, 0.07)
	warning.tween_property(visual, "position:x", 6.0, 0.07)
	await warning.finished
	visual.position = Vector2.ZERO
	if !_manager.can_spawn_external():
		hatching = false
		cooldown_remaining = 2.0
		return
	var selected_scene: PackedScene = enemy_scenes.pick_random()
	var enemy: AlienEnemy = _manager.spawn_external(selected_scene, global_position + Vector2(0, 18))
	if enemy == null:
		hatching = false
		cooldown_remaining = 2.0
		return
	cooldown_remaining = reactivation_time
	var hatch_flash := create_tween()
	hatch_flash.tween_property(shell, "modulate", Color(0.55, 1.0, 0.32, 0.28), 0.12)
	hatch_flash.tween_property(shell, "modulate", Color.WHITE, 0.32)
	await hatch_flash.finished
	hatching = false


func _find_respawn_manager() -> EnemyRespawnManager:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is EnemyRespawnManager:
			return ancestor as EnemyRespawnManager
		ancestor = ancestor.get_parent()
	return get_tree().get_first_node_in_group("EnemyRespawnManager") as EnemyRespawnManager
