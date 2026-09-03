class_name AlienEnemy
extends CharacterBody2D

signal died(enemy: Node)

enum State { IDLE, CHASE, TELEGRAPH, ATTACK, RECOVER, HURT, DEAD }

@export var ranged_enemy := false
@export var max_hp := 55
@export var move_speed := 115.0
@export var detection_range := 430.0
@export var attack_range := 62.0
@export var preferred_range := 250.0
@export var retreat_range := 150.0
@export var attack_damage := 12
@export var attack_cooldown := 1.25
@export var telegraph_duration := 0.46
@export var recovery_duration := 0.32
@export var projectile_speed := 430.0
@export var acceleration := 950.0
@export var obstacle_lookahead := 74.0
@export var projectile_scene: PackedScene = preload("res://Scenes/Prefabs/combat_projectile.tscn")
@export_category("Repeatable Material Drops")
@export var drop_table: EnemyDropTable
@export_range(0.0, 2.0, 0.01) var material_drop_chance := 1.0

const MATERIAL_DROP_SCENE: PackedScene = preload("res://Scenes/Prefabs/enemy_material_drop.tscn")

@onready var visual: Node2D = $Visual
@onready var sprite: Sprite2D = $Visual/Sprite
@onready var hp_bar: ProgressBar = $HPBar
@onready var hitbox: CollisionShape2D = $CollisionShape2D
@onready var attack_sfx: AudioStreamPlayer2D = get_node_or_null("AttackSfx") as AudioStreamPlayer2D

var hp := 1
var state := State.IDLE
var cooldown := 0.0
var state_clock := 0.0
var anim_clock := 0.0
var attack_locked := false
var strafe_clock := 0.0
var strafe_sign := 1.0
var stuck_clock := 0.0
var escape_clock := 0.0
var escape_direction := Vector2.ZERO
var previous_position := Vector2.ZERO
var encounter_announced := false


func _ready() -> void:
	add_to_group("Enemy")
	hp = max_hp
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	if ranged_enemy:
		attack_range = preferred_range + 35.0
	strafe_sign = -1.0 if get_instance_id() % 2 == 0 else 1.0
	previous_position = global_position


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	cooldown = maxf(cooldown - delta, 0.0)
	escape_clock = maxf(escape_clock - delta, 0.0)
	strafe_clock += delta
	state_clock += delta
	anim_clock += delta * (7.0 if state == State.CHASE else 4.0)
	_update_animation()

	var player := GameManager.player as Node2D
	if !is_instance_valid(player) or GameManager.death_in_progress:
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		move_and_slide()
		return
	var offset := player.global_position - global_position
	var distance := offset.length()
	var direction := offset.normalized()
	if distance <= detection_range and !encounter_announced:
		encounter_announced = true
		AudioManager.play_enemy_encounter()

	if state in [State.TELEGRAPH, State.ATTACK, State.RECOVER, State.HURT]:
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
		return

	if distance > detection_range:
		state = State.IDLE
		velocity = velocity.move_toward(Vector2.ZERO, 500.0 * delta)
	elif ranged_enemy:
		_handle_spitter(distance, direction)
	else:
		_handle_crawler(distance, direction)

	move_and_slide()
	_update_stuck_recovery(delta)
	if absf(velocity.x) > 2.0:
		sprite.flip_h = velocity.x < 0.0


func _handle_crawler(distance: float, direction: Vector2) -> void:
	if distance <= attack_range and cooldown <= 0.0 and !attack_locked:
		_start_attack()
		return
	state = State.CHASE
	_set_chase_velocity(direction)


func _handle_spitter(distance: float, direction: Vector2) -> void:
	if distance < retreat_range:
		state = State.CHASE
		_set_chase_velocity(-direction)
	elif distance > preferred_range + 70.0:
		state = State.CHASE
		_set_chase_velocity(direction)
	else:
		state = State.CHASE
		if strafe_clock >= 1.15:
			strafe_clock = 0.0
			strafe_sign *= -1.0
		var strafe_direction := direction.rotated(PI * 0.5 * strafe_sign)
		_set_chase_velocity(strafe_direction, 0.58)
		if cooldown <= 0.0 and !attack_locked:
			_start_attack()


func _start_attack() -> void:
	if attack_locked or state == State.DEAD:
		return
	attack_locked = true
	state = State.TELEGRAPH
	state_clock = 0.0
	var telegraph_color := Color(0.52, 1.0, 0.25) if ranged_enemy else Color(1.0, 0.56, 0.22)
	var warning := create_tween().set_loops(2)
	warning.tween_property(visual, "modulate", telegraph_color, 0.12)
	warning.tween_property(visual, "modulate", Color.WHITE, 0.12)
	await get_tree().create_timer(telegraph_duration).timeout
	if state == State.DEAD:
		return
	state = State.ATTACK
	var player := GameManager.player as Node2D
	if is_instance_valid(player):
		var direction := (player.global_position - global_position).normalized()
		if ranged_enemy:
			_fire_acid(direction)
		elif global_position.distance_to(player.global_position) <= attack_range + 24.0:
			GameManager.damage(attack_damage)
			if player.has_method("hit_feedback"):
				player.hit_feedback()
	await get_tree().create_timer(0.16).timeout
	if state == State.DEAD:
		return
	state = State.RECOVER
	await get_tree().create_timer(recovery_duration).timeout
	if state != State.DEAD:
		state = State.CHASE
		cooldown = attack_cooldown
		attack_locked = false


func _fire_acid(direction: Vector2) -> void:
	if projectile_scene == null:
		return
	if GameManager.sfx_on and attack_sfx != null and attack_sfx.stream != null:
		attack_sfx.play()
	var projectile := projectile_scene.instantiate() as CombatProjectile
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + direction * 42.0 + Vector2(0, -12)
	projectile.configure(direction, attack_damage, projectile_speed, 2.2, true)


func _set_chase_velocity(desired_direction: Vector2, speed_scale: float = 1.0) -> void:
	var steered_direction := _get_steered_direction(desired_direction.normalized())
	var target_velocity := steered_direction * move_speed * speed_scale
	velocity = velocity.move_toward(target_velocity, acceleration * get_physics_process_delta_time())


func _get_steered_direction(desired_direction: Vector2) -> Vector2:
	if escape_clock > 0.0 and escape_direction != Vector2.ZERO:
		return escape_direction
	if !_direction_is_blocked(desired_direction):
		return desired_direction
	var left := desired_direction.rotated(0.92)
	var right := desired_direction.rotated(-0.92)
	var left_blocked := _direction_is_blocked(left)
	var right_blocked := _direction_is_blocked(right)
	if !left_blocked and !right_blocked:
		return left if strafe_sign > 0.0 else right
	if !left_blocked:
		return left
	if !right_blocked:
		return right
	return desired_direction.rotated(PI * 0.5 * strafe_sign)


func _direction_is_blocked(direction: Vector2) -> bool:
	if direction == Vector2.ZERO:
		return false
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + direction * obstacle_lookahead,
		1
	)
	query.exclude = [get_rid()]
	return !get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _update_stuck_recovery(delta: float) -> void:
	var travelled := global_position.distance_to(previous_position)
	if state == State.CHASE and velocity.length() > move_speed * 0.25 and travelled < 0.7:
		stuck_clock += delta
	else:
		stuck_clock = maxf(stuck_clock - delta * 2.0, 0.0)
	if stuck_clock >= 0.38:
		stuck_clock = 0.0
		strafe_sign *= -1.0
		escape_clock = 0.75
		escape_direction = velocity.normalized().rotated(PI * 0.62 * strafe_sign)
		if escape_direction == Vector2.ZERO:
			escape_direction = Vector2.from_angle(randf() * TAU)
	previous_position = global_position


func take_damage(amount: int, knock_direction: Vector2 = Vector2.ZERO) -> void:
	if state == State.DEAD:
		return
	hp = clampi(hp - amount, 0, max_hp)
	hp_bar.value = hp
	if hp <= 0:
		_die()
		return
	state = State.HURT
	velocity = knock_direction * 90.0
	var hurt := create_tween()
	hurt.tween_property(visual, "modulate", Color(1.0, 0.22, 0.35), 0.07)
	hurt.tween_property(visual, "modulate", Color.WHITE, 0.12)
	await hurt.finished
	if state != State.DEAD:
		state = State.CHASE


func _die() -> void:
	state = State.DEAD
	died.emit(self)
	if GameManager.sfx_on:
		AudioManager.play_enemy_death()
	_roll_material_drop()
	attack_locked = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	hitbox.set_deferred("disabled", true)
	collision_layer = 0
	collision_mask = 0
	sprite.frame = 15
	hp_bar.visible = false
	var death := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	death.tween_property(visual, "modulate", Color(0.35, 1.0, 0.25, 0.75), 0.16)
	death.tween_property(visual, "scale", Vector2(1.18, 0.35), 0.42)
	death.parallel().tween_property(visual, "modulate:a", 0.0, 0.42)
	await death.finished
	queue_free()


func _roll_material_drop() -> void:
	if drop_table == null or get_tree().current_scene == null:
		return
	var drops := drop_table.roll_drops(null, material_drop_chance)
	for index in range(drops.size()):
		var result: Dictionary = drops[index]
		var drop := MATERIAL_DROP_SCENE.instantiate() as EnemyMaterialDrop
		if drop == null:
			continue
		drop.configure(result.get("item_id", &"alien_biomass"), int(result.get("amount", 1)))
		get_tree().current_scene.add_child(drop)
		var angle := TAU * float(index) / maxf(float(drops.size()), 1.0)
		drop.global_position = global_position + Vector2.RIGHT.rotated(angle) * float(index * 14)


func _update_animation() -> void:
	var row := 0
	match state:
		State.CHASE: row = 1
		State.TELEGRAPH, State.ATTACK, State.RECOVER: row = 2
		State.HURT, State.DEAD: row = 3
	sprite.frame = row * 4 + int(anim_clock) % 4
