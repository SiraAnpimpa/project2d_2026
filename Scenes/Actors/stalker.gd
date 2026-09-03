class_name Stalker
extends AlienEnemy

@export var dash_range := 285.0
@export var dash_speed := 520.0
@export var dash_duration := 0.24

var dashing := false
var dash_remaining := 0.0
var dash_direction := Vector2.ZERO
var dash_connected := false


func _physics_process(delta: float) -> void:
	if dashing:
		dash_remaining -= delta
		velocity = dash_direction * dash_speed
		move_and_slide()
		var player := GameManager.player as Node2D
		if !dash_connected and is_instance_valid(player) and global_position.distance_to(player.global_position) <= attack_range + 34.0:
			dash_connected = true
			GameManager.damage(attack_damage)
			if player.has_method("hit_feedback"):
				player.hit_feedback()
		if dash_remaining <= 0.0:
			_finish_dash()
		return
	super._physics_process(delta)


func _handle_crawler(distance: float, direction: Vector2) -> void:
	if distance <= attack_range and cooldown <= 0.0 and !attack_locked:
		_start_attack()
		return
	if distance <= dash_range and distance > attack_range + 45.0 and cooldown <= 0.0 and !attack_locked:
		_start_dash(direction)
		return
	state = State.CHASE
	velocity = direction * move_speed


func _start_dash(direction: Vector2) -> void:
	attack_locked = true
	state = State.TELEGRAPH
	velocity = Vector2.ZERO
	var warning := create_tween().set_loops(2)
	warning.tween_property(visual, "modulate", Color(0.45, 1.0, 0.22), 0.1)
	warning.tween_property(visual, "modulate", Color.WHITE, 0.1)
	await get_tree().create_timer(0.42).timeout
	if state == State.DEAD:
		return
	dash_direction = direction
	var player := GameManager.player as Node2D
	if is_instance_valid(player):
		dash_direction = (player.global_position - global_position).normalized()
	dash_remaining = dash_duration
	dash_connected = false
	dashing = true
	state = State.ATTACK


func _finish_dash() -> void:
	dashing = false
	velocity = Vector2.ZERO
	state = State.RECOVER
	cooldown = attack_cooldown
	await get_tree().create_timer(0.34).timeout
	if state != State.DEAD:
		state = State.CHASE
		attack_locked = false


func _die() -> void:
	dashing = false
	super._die()
