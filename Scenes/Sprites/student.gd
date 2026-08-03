class_name student
extends CharacterBody2D

signal hit_enemy
signal hit_trap 


# --------- VARIABLES ---------- #

@export_category("Player Properties") # You can tweak these changes according to your likings
@export var move_speed : float = 300
@export var jump_force : float = 650
@export var gravity : float = 30
@export var max_jump_count : int = 2
@export var bullet_scene : PackedScene
@export var shoot_cooldown_time : float = 0.2
@export var bullet_lifetime = 0.178
@export var bullet_speed : float = 600.0


var jump_count : int = 2

@export_category("Toggle Functions") # Double jump feature is disable by default (Can be toggled from inspector)
@export var double_jump : = false

var is_grounded : bool = false
var movement_enabled : bool = true
var spawn_point = Vector2(0,0)
var is_attacking = false
var shoot_cooldown_timer = 0.0
var can_damage = true
var bullet_cooldown_timer = 0.0

@onready var player_sprite : AnimationPlayer = $student/AnimationPlayer
@onready var player_node = $student
@onready var bullet_marker = $BulletMarker
@onready var particle_trails = $ParticleTrails
@onready var death_particles = $DeathParticles



# --------- BUILT-IN FUNCTIONS ---------- #
func _ready() -> void:
	spawn_point = global_position
	if GameManager.save_player_position.x != 0:
		global_position =  GameManager.save_player_position
		GameManager.save_player_position = Vector2.ZERO
	player_sprite.animation_finished.connect(_on_animation_finished)
	
func _physics_process(_delta):
	is_grounded = is_on_floor()
	movement()

func _process(_delta):
	player_animations()
	flip_player()
	handle_shooting()
	if shoot_cooldown_timer > 0:
		shoot_cooldown_timer -= _delta
	if bullet_cooldown_timer > 0:
		bullet_cooldown_timer -= _delta
# --------- CUSTOM FUNCTIONS ---------- #

# <-- Player Movement Code -->
func movement():
	# Gravity
	if !is_on_floor():
		velocity.y += gravity
	elif is_on_floor():
		jump_count = max_jump_count
		velocity.x = 0
	
	handle_jumping()
	
	# Move Player
	if movement_enabled:
		if Input.is_action_pressed("Left"):
			velocity.x = -move_speed
		if Input.is_action_pressed("Right"):
			velocity.x = move_speed
	if velocity.y > 5000:
		hit_trap.emit()
	move_and_slide()

# Handles jumping functionality (double jump or single jump, can be toggled from inspector)
func handle_jumping():
	if Input.is_action_just_pressed("Jump") and movement_enabled:
		if is_on_floor() and !double_jump:
			jump()
		elif double_jump and jump_count > 0:
			jump()
			jump_count -= 1

# Player jump
func jump():
	jump_tween()
	AudioManager.jump_sfx.play()
	velocity.y = -jump_force

# Handle Player Animations
func player_animations():
	particle_trails.emitting = false
	if is_attacking:
		return
	
	if is_on_floor():
		if abs(velocity.x) > 0:
			particle_trails.emitting = true
			player_sprite.current_animation = "Walk"
		else:
			player_sprite.current_animation = "Idle"
	else:
		player_sprite.current_animation = "Jump"


# Flip player sprite based on X velocity
func flip_player():
	if velocity.x < 0: 
		player_node.scale.x = -abs(player_node.scale.x)
	elif velocity.x > 0:
		player_node.scale.x = abs(player_node.scale.x)

# Tween Animations
var squash_tween : Tween

func jump_tween():
	if squash_tween and squash_tween.is_running():
		squash_tween.kill()
	player_node.scale.y = 1.0
	squash_tween = create_tween()
	squash_tween.tween_property(player_node, "scale:y", 1.4, 0.1)
	squash_tween.tween_property(player_node, "scale:y", 1.0, 0.1)

func death_tween():
	AudioManager.death_sfx.play()
	death_particles.emitting = true
	movement_enabled = false
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	tween.parallel().tween_property(self, "position", Vector2(position.x,position.y-100), 0.15)
	await tween.finished
	global_position = spawn_point
	await get_tree().create_timer(0.3).timeout
	movement_enabled = true
	AudioManager.respawn_sfx.play()
	respawn_tween()

func respawn_tween():
	var tween = create_tween()
	tween.stop(); tween.play()
	tween.tween_property(self, "scale", Vector2.ONE, 0.15) 
	tween.parallel().tween_property(self, "position", spawn_point, 0.15)

func damage_tween():
	var tween = create_tween() 
	tween.stop(); tween.play()
	can_damage = false
	for i in range(1,10):
		tween.tween_property(player_node , "modulate", Color.RED, 0.1)
		tween.tween_property(player_node , "modulate", Color.WHITE, 0.1)
	await tween.finished
	can_damage = true
# --------- SIGNALS ---------- #

# Damage
func _on_collision_body_entered(body):
	if body.is_in_group("Enemy") or body.is_in_group("Traps"):
		var dx = body.position.x - position.x
		velocity.y = -400
		if dx > 0:
			velocity.x = -300
		else:
			velocity.x = 300					
		damage_tween()
		if body.is_in_group("Traps"):
			hit_trap.emit()
		else:
			hit_enemy.emit()

func _on_collision_area_entered(area: Area2D) -> void:
	if !can_damage : return
	if area.is_in_group("EnemyBullet") or area.is_in_group("BossMelee"):
		var dx = area.global_position.x - position.x
		velocity.y = -400
		if dx > 0:
			velocity.x = -300
		else:
			velocity.x = 300
		damage_tween()
		hit_enemy.emit()
		if area.is_in_group("EnemyBullet"):
			area.queue_free()

func handle_shooting():
	if Input.is_action_just_pressed("attack") and movement_enabled and shoot_cooldown_timer <= 0:
		attack()
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F and movement_enabled and bullet_cooldown_timer <= 0:
			shoot_bullet()

func shoot_bullet():
	if bullet_scene == null:
		return
	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	var facing = 1 if player_node.scale.x > 0 else -1
	bullet.global_position = bullet_marker.global_position
	bullet.scale.x = facing
	bullet.shoot(Vector2(facing, 0), bullet_speed, bullet_lifetime)
	bullet_cooldown_timer = shoot_cooldown_time
	
func attack():
	is_attacking = true
	player_sprite.play("Attack")
	shoot_cooldown_timer = shoot_cooldown_time

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "Attack":
		is_attacking = false
