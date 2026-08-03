class_name Enemy
extends CharacterBody2D
@export var speed = 100.0
@export var direction = 1
@export var flip = false

var alive = true
@onready var wall_ray: RayCast2D = $Sprite/Ray/wallRay
@onready var player_ray: RayCast2D = $Sprite/Ray/playerRay
@onready var floor_ray: RayCast2D = $Sprite/Ray/floorRay

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$DeathParticles.one_shot = true
	if direction>0 : direction = 1
	if direction<0 : direction = -1

func _process(delta: float) -> void:
	if flip : $Sprite.scale.x = -1
	else: $Sprite.scale.x = 1

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	if alive && is_on_floor():
		if player_ray.is_colliding() :
			found_player()
		elif is_on_wall() || wall_ray.is_colliding() || !floor_ray.is_colliding():
			direction = -direction
		velocity.x = speed * direction 
	else:
		velocity.x = 0
	
	if direction < 0 : flip = false
	if direction > 0 : flip = true
	
	move_and_slide()
		
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
		
func _on_hit_area_area_entered(area: Area2D) -> void:
	pass
		
func death_tween():
	alive = false
	collision_layer = 0
	$Sprite.hide()
	$DeathParticles.emitting = true
	$DeathSfx.play()
	await get_tree().create_timer(1).timeout
	queue_free()	
