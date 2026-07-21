class_name Enemy
extends CharacterBody2D

@export var speed = 100.0
@export var direction = 1
@export var turn_cooldown = 0.3  # วินาทีขั้นต่ำก่อนจะยอมหันทิศใหม่อีกครั้ง

var alive = true
var _turn_timer = 0.0  # นับเวลาตั้งแต่หันทิศครั้งล่าสุด

@onready var wall_ray: RayCast2D = $Sprite/Ray/wallRay
@onready var player_ray: RayCast2D = $Sprite/Ray/playerRay
@onready var floor_ray: RayCast2D = $Sprite/Ray/floorRay

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$DeathParticles.one_shot = true
	direction = 1 if direction >= 0 else -1
	_update_facing()

func _physics_process(delta: float) -> void:
	_turn_timer += delta

	if not is_on_floor():
		velocity += get_gravity() * delta

	if alive && is_on_floor():
		if player_ray.is_colliding():
			found_player()
		elif _turn_timer >= turn_cooldown and (is_on_wall() || wall_ray.is_colliding() || !floor_ray.is_colliding()):
			direction = -direction
			_turn_timer = 0.0
		velocity.x = speed * direction
	else:
		velocity.x = 0

	_update_facing()

	move_and_slide()

func _update_facing() -> void:
	$Sprite.scale.x = -1 if direction < 0 else 1

func found_player():
	var point = player_ray.get_collision_point()
	if position.x > point.x : direction = -1
	if position.x < point.x : direction = 1

func _on_hit_area_body_entered(body: Node2D) -> void:
	if alive and body.is_in_group("Traps"):
		death_tween()
	if alive and body.is_in_group("Bullet"):
		GameManager.add_score()
		death_tween()
		body.queue_free()

func death_tween():
	alive = false
	collision_layer = 0
	$Sprite.hide()
	$DeathParticles.emitting = true
	$DeathSfx.play()
	await get_tree().create_timer(1).timeout
	queue_free()
