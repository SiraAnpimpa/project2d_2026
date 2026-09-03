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
@export_range(12.0, 80.0, 1.0) var spawn_clearance := 32.0
@export_range(0.0, 320.0, 8.0) var relocation_radius := 192.0
@export_range(8.0, 64.0, 4.0) var relocation_step := 32.0

@export_category("Area Difficulty")
@export_range(0.5, 3.0, 0.05) var enemy_health_multiplier := 1.0
@export_range(0.5, 3.0, 0.05) var enemy_damage_multiplier := 1.0
@export_range(0.5, 2.0, 0.05) var enemy_speed_multiplier := 1.0

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
	var resolved: Dictionary = find_clear_spawn_position(slot.global_position)
	if !bool(resolved.get("found", false)):
		return false
	var spawn_position: Vector2 = resolved.get("position", slot.global_position)
	if !entering_area and !_is_spawn_location_safe(spawn_position):
		return false
	var enemy := slot.enemy_scene.instantiate() as AlienEnemy
	if enemy == null:
		return false
	_apply_area_difficulty(enemy)
	var container := get_node_or_null("ActiveEnemies")
	if container == null:
		container = self
	container.add_child(enemy)
	enemy.global_position = spawn_position
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
	var resolved: Dictionary = find_clear_spawn_position(world_position, false)
	if !bool(resolved.get("found", false)):
		return null
	var spawn_position: Vector2 = resolved.get("position", world_position)
	var enemy := enemy_scene.instantiate() as AlienEnemy
	if enemy == null:
		return null
	_apply_area_difficulty(enemy)
	var container := get_node_or_null("ActiveEnemies")
	if container == null:
		container = self
	container.add_child(enemy)
	enemy.global_position = spawn_position
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


func find_clear_spawn_position(origin: Vector2, respect_player_distance: bool = true) -> Dictionary:
	if _is_world_position_clear(origin) and (!respect_player_distance or _is_player_distance_safe(origin)):
		return {"found": true, "position": origin}
	if relocation_radius <= 0.0:
		return {"found": false}
	var ring_count := ceili(relocation_radius / relocation_step)
	for ring in range(1, ring_count + 1):
		var radius := float(ring) * relocation_step
		var sample_count := 12 + ring * 4
		for sample in range(sample_count):
			var angle := TAU * float(sample) / float(sample_count) + float(ring % 2) * 0.17
			var candidate := origin + Vector2.from_angle(angle) * radius
			if _is_world_position_clear(candidate) and (!respect_player_distance or _is_player_distance_safe(candidate)):
				return {"found": true, "position": candidate}
	return {"found": false}


func _is_world_position_clear(world_position: Vector2) -> bool:
	for node in get_tree().get_nodes_in_group("FullMapEnvironment"):
		var environment := node as FullMapEnvironment
		if environment == null or get_tree().current_scene == null:
			continue
		if !get_tree().current_scene.is_ancestor_of(environment):
			continue
		if environment.is_local_point_blocked(environment.to_local(world_position), spawn_clearance):
			return false
	var shape := CircleShape2D.new()
	shape.radius = spawn_clearance
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, world_position)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _apply_area_difficulty(enemy: AlienEnemy) -> void:
	enemy.max_hp = maxi(roundi(float(enemy.max_hp) * enemy_health_multiplier), 1)
	enemy.attack_damage = maxi(roundi(float(enemy.attack_damage) * enemy_damage_multiplier), 1)
	enemy.move_speed = maxf(enemy.move_speed * enemy_speed_multiplier, 1.0)
