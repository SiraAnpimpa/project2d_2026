class_name AlienEgg
extends Node2D

@export var enemy_scenes: Array[PackedScene] = []
@export_range(32.0, 800.0, 8.0) var activation_distance := 180.0
@export_range(0.1, 300.0, 0.1) var reactivation_time := 30.0
@export var active := true

@onready var visual: Node2D = $Visual
@onready var shell: Polygon2D = $Visual/Shell
@onready var egg_sprite: Sprite2D = $Visual/EggSprite

var cooldown_remaining := 0.0
var hatching := false
var egg_open := false
var _manager: EnemyRespawnManager = null


func _ready() -> void:
	add_to_group("AlienEgg")
	_manager = _find_respawn_manager()
	_set_frame(0)


func _process(delta: float) -> void:
	if !active or get_tree().paused:
		return
	cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)
	if egg_open and cooldown_remaining <= 0.0:
		egg_open = false
		_set_frame(0)
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
	_set_frame(1)
	var warning := create_tween().set_loops(3)
	warning.tween_property(visual, "position:x", -6.0, 0.07)
	warning.tween_property(visual, "position:x", 6.0, 0.07)
	await get_tree().create_timer(0.12).timeout
	_set_frame(2)
	await warning.finished
	visual.position = Vector2.ZERO
	_set_frame(3)
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
	egg_open = true
	_set_frame(4)
	var hatch_flash := create_tween()
	hatch_flash.tween_property(egg_sprite, "modulate", Color(0.55, 1.0, 0.32, 0.5), 0.12)
	hatch_flash.tween_property(egg_sprite, "modulate", Color.WHITE, 0.32)
	await hatch_flash.finished
	hatching = false


func trigger_hatch() -> void:
	if active and !hatching and cooldown_remaining <= 0.0:
		_start_hatch()


func _set_frame(frame_index: int) -> void:
	if egg_sprite != null:
		const EGG_CELL_WIDTH := 250.8
		egg_sprite.region_rect = Rect2(frame_index * EGG_CELL_WIDTH, 0, EGG_CELL_WIDTH, 280)


func _find_respawn_manager() -> EnemyRespawnManager:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is EnemyRespawnManager:
			return ancestor as EnemyRespawnManager
		ancestor = ancestor.get_parent()
	return get_tree().get_first_node_in_group("EnemyRespawnManager") as EnemyRespawnManager
