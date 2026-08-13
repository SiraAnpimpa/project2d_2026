class_name Enemy
extends CharacterBody2D
@export var speed = 100.0
@export var direction = 1
@export var flip = false
@export var hp = 50
@export var atk = 10 
@export var maxhp = 50


var can_walk = true
var alive = true
@onready var wall_ray: RayCast2D = $Sprite/Ray/wallRay
@onready var player_ray: RayCast2D = $Sprite/Ray/playerRay
@onready var floor_ray: RayCast2D = $Sprite/Ray/floorRay

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$DeathParticles.one_shot = true
	$ProgressBar.max_value = maxhp
	$ProgressBar.value = hp

func _process(delta: float) -> void:
	if flip : $Sprite.scale.x = -1
	else: $Sprite.scale.x = 1
	$ProgressBar.value = hp

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	
	if alive && is_on_floor():
		if player_ray.is_colliding() :
			found_player()
		elif is_on_wall() || wall_ray.is_colliding() || !floor_ray.is_colliding():
			direction = -direction
			velocity.x = speed * direction
			velocity.y = -200
			
		var vx = round(speed * direction - velocity.x )	
		if can_walk:
			if vx>0:
				velocity.x += 5
			elif vx<0:	 			
				velocity.x -= 5
			else:
				velocity.x = speed * direction	
	
	if direction < 0 : flip = false
	if direction > 0 : flip = true
	
	move_and_slide()
		
func found_player():
	var point = player_ray.get_collision_point()
	if position.x > point.x : direction = -1
	if position.x < point.x : direction = 1

func _on_hit_area_body_entered(body: Node2D) -> void:
	if alive and (body.is_in_group("Bullet") or body.is_in_group("Trap") ):
		hp -= 10
		var dx = global_position.x - body.global_position.x
		if dx>0: velocity.x = 100
		else: velocity.x = -100
		velocity.y = -200
		  
		damage_tween()
		if hp <=0 :
			GameManager.add_score()
			death_tween()
			body.queue_free()

func damage_tween():
	$DamageParticles.emitting = true
	$DeathSfx.play()
	var tween = create_tween() 
	tween.stop(); tween.play()
	can_walk = false
	for i in range(1,10):
		tween.tween_property(self , "modulate", Color.RED, 0.1)
		tween.tween_property(self , "modulate", Color.WHITE, 0.1)
	await tween.finished
	can_walk = true
	
func death_tween():
	alive = false
	collision_layer = 0
	$Sprite.hide()
	$DeathParticles.emitting = true
	$DeathSfx.play()
	await get_tree().create_timer(1).timeout
	queue_free()	
