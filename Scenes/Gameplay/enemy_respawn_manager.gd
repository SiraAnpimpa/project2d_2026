class_name EnemyRespawnManager
extends Node2D

signal enemy_spawned(enemy: AlienEnemy, slot: EnemySpawnSlot)
signal enemy_slot_emptied(slot: EnemySpawnSlot, respawn_delay: float)

@export_category("Area Respawn Configuration")
@export var respawn_enabled := true
@export_range(0.1, 600.0, 0.1) var respawn_interval := 60.0
@export_range(1, 24, 1) var maximum_alive := 6
@export_range(0.0, 1000.0, 10.0) var safe_spawn_distance := 300.0
@export_range(0.25, 30.0, 0.25) var blocked_retry_interval := 4.0
@export var avoid_visible_camera := true

@export_category("Optional Spawn Sources")
@export_range(0.0, 10.0, 0.1) var external_spawn_lockout := 1.25

var slots: Array[EnemySpawnSlot] = []
var _initialized := false
var _external_lockout_remaining := 0.0
var _external_enemies: Array[AlienEnemy] = []


func _ready() -> void:
	add_to_group("EnemyRespawnManager")
	call_deferred("_initialize_slots")


func _process(delta: float) -> void:
	if !_initialized or get_tree().paused:
		return
	_external_lockout_remaining = maxf(_external_lockout_remaining - delta, 0.0)
	if !respawn_enabled:
		return
	for slot in slots:
		if !slot.waiting_for_respawn:
			continue
		slot.respawn_remaining = maxf(slot.respawn_remaining - delta, 0.0)
		if slot.respawn_remaining <= 0.0 and !_try_spawn_slot(slot, false):
			slot.respawn_remaining = blocked_retry_interval


func _initialize_slots() -> void:
	if _initialized:
		return
	slots.clear()
	for node in find_children("*", "EnemySpawnSlot", true, false):
		var slot := node as EnemySpawnSlot
		if slot != null:
			slots.append(slot)
	_initialized = true
	for slot in slots:
		if slot.spawn_on_entry and slot.slot_enabled:
			if !_try_spawn_slot(slot, true):
				slot.arm_respawn(blocked_retry_interval)


func _try_spawn_slot(slot: EnemySpawnSlot, entering_area: bool) -> bool:
	if slot == null or !slot.is_available() or slot.enemy_scene == null:
		return false
	if get_alive_count() >= maximum_alive:
		return false
	if !_is_player_distance_safe(slot.global_position):
		return false
	if !entering_area and !_is_spawn_location_safe(slot.global_position):
		return false
	var enemy := slot.enemy_scene.instantiate() as AlienEnemy
	if enemy == null:
		return false
	var container := get_node_or_null("ActiveEnemies")
	if container == null:
		container = self
	container.add_child(enemy)
	enemy.global_position = slot.global_position
	slot.mark_spawned(enemy)
	enemy.died.connect(_on_slot_enemy_died.bind(slot), CONNECT_ONE_SHOT)
	enemy_spawned.emit(enemy, slot)
	return true


func _on_slot_enemy_died(_enemy: Node, slot: EnemySpawnSlot) -> void:
	if slot == null:
		return
	if respawn_enabled:
		slot.arm_respawn(respawn_interval)
	else:
		slot.active_enemy = null
		slot.waiting_for_respawn = false
	enemy_slot_emptied.emit(slot, respawn_interval)


func get_alive_count() -> int:
	_cleanup_external_enemies()
	var count := _external_enemies.size()
	for slot in slots:
		if is_instance_valid(slot.active_enemy) and slot.active_enemy.state != AlienEnemy.State.DEAD:
			count += 1
	return count


func can_spawn_external() -> bool:
	return _initialized and _external_lockout_remaining <= 0.0 and get_alive_count() < maximum_alive


func spawn_external(enemy_scene: PackedScene, world_position: Vector2) -> AlienEnemy:
	if enemy_scene == null or !can_spawn_external():
		return null
	var enemy := enemy_scene.instantiate() as AlienEnemy
	if enemy == null:
		return null
	var container := get_node_or_null("ActiveEnemies")
	if container == null:
		container = self
	container.add_child(enemy)
	enemy.global_position = world_position
	_external_enemies.append(enemy)
	_external_lockout_remaining = external_spawn_lockout
	enemy.died.connect(_on_external_enemy_died.bind(enemy), CONNECT_ONE_SHOT)
	return enemy


func force_reset() -> void:
	for slot in slots:
		if is_instance_valid(slot.active_enemy):
			slot.active_enemy.queue_free()
		slot.active_enemy = null
		slot.waiting_for_respawn = false
	for enemy in _external_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_external_enemies.clear()
	for slot in slots:
		if slot.spawn_on_entry and slot.slot_enabled:
			if !_try_spawn_slot(slot, true):
				slot.arm_respawn(blocked_retry_interval)


func _on_external_enemy_died(_dead_enemy: Node, tracked_enemy: AlienEnemy) -> void:
	_external_enemies.erase(tracked_enemy)


func _cleanup_external_enemies() -> void:
	for index in range(_external_enemies.size() - 1, -1, -1):
		var enemy := _external_enemies[index]
		if !is_instance_valid(enemy) or enemy.state == AlienEnemy.State.DEAD:
			_external_enemies.remove_at(index)


func _is_spawn_location_safe(world_position: Vector2) -> bool:
	if !_is_player_distance_safe(world_position):
		return false
	if !avoid_visible_camera:
		return true
	var camera := get_viewport().get_camera_2d()
	if camera == null or !camera.enabled:
		return true
	var viewport_rect := Rect2(Vector2.ZERO, get_viewport_rect().size).grow(48.0)
	var screen_position := get_viewport().get_canvas_transform() * world_position
	return !viewport_rect.has_point(screen_position)


func _is_player_distance_safe(world_position: Vector2) -> bool:
	var active_player := GameManager.player as Node2D
	if !is_instance_valid(active_player):
		return true
	return active_player.global_position.distance_to(world_position) >= safe_spawn_distance
