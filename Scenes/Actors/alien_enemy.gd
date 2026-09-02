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
@export var projectile_scene: PackedScene = preload("res://Scenes/Prefabs/combat_projectile.tscn")
@export_category("Repeatable Material Drops")
@export_enum("crawler", "spitter", "elite", "none") var drop_profile := "crawler"
@export_range(0.0, 1.0, 0.01) var material_drop_chance := 0.72

const MATERIAL_DROP_SCENE: PackedScene = preload("res://Scenes/Prefabs/enemy_material_drop.tscn")

@onready var visual: Node2D = $Visual
@onready var sprite: Sprite2D = $Visual/Sprite
@onready var hp_bar: ProgressBar = $HPBar
@onready var hitbox: CollisionShape2D = $CollisionShape2D

var hp := 1
var state := State.IDLE
var cooldown := 0.0
var state_clock := 0.0
var anim_clock := 0.0
var attack_locked := false


func _ready() -> void:
	add_to_group("Enemy")
	hp = max_hp
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	if ranged_enemy:
		move_speed *= 0.82
		attack_range = preferred_range + 35.0


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	cooldown = maxf(cooldown - delta, 0.0)
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
	if absf(velocity.x) > 2.0:
		sprite.flip_h = velocity.x < 0.0


func _handle_crawler(distance: float, direction: Vector2) -> void:
	if distance <= attack_range and cooldown <= 0.0 and !attack_locked:
		_start_attack()
		return
	state = State.CHASE
	velocity = direction * move_speed


func _handle_spitter(distance: float, direction: Vector2) -> void:
	if distance < retreat_range:
		state = State.CHASE
		velocity = -direction * move_speed
	elif distance > preferred_range + 70.0:
		state = State.CHASE
		velocity = direction * move_speed
	else:
		velocity = Vector2.ZERO
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
	await get_tree().create_timer(0.46).timeout
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
	await get_tree().create_timer(0.32).timeout
	if state != State.DEAD:
		state = State.CHASE
		cooldown = attack_cooldown
		attack_locked = false


func _fire_acid(direction: Vector2) -> void:
	if projectile_scene == null:
		return
	var projectile := projectile_scene.instantiate() as CombatProjectile
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + direction * 42.0 + Vector2(0, -12)
	projectile.configure(direction, attack_damage, 390.0, 2.2, true)


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
	if drop_profile == "none" or randf() > material_drop_chance:
		return
	var roll := randf()
	var item_id: StringName = &"scrap_metal"
	var amount := 1
	match drop_profile:
		"spitter":
			item_id = &"circuit_part" if roll < 0.18 else (&"energy_crystal" if roll < 0.52 else &"scrap_metal")
		"elite":
			item_id = &"circuit_part" if roll < 0.42 else (&"energy_crystal" if roll < 0.70 else &"scrap_metal")
			amount = 2 if roll < 0.16 else 1
		_:
			item_id = &"circuit_part" if roll < 0.06 else (&"energy_crystal" if roll < 0.28 else &"scrap_metal")
	var drop := MATERIAL_DROP_SCENE.instantiate() as EnemyMaterialDrop
	if drop == null or get_tree().current_scene == null:
		return
	drop.configure(item_id, amount)
	get_tree().current_scene.add_child(drop)
	drop.global_position = global_position


func _update_animation() -> void:
	var row := 0
	match state:
		State.CHASE: row = 1
		State.TELEGRAPH, State.ATTACK, State.RECOVER: row = 2
		State.HURT, State.DEAD: row = 3
	sprite.frame = row * 4 + int(anim_clock) % 4
