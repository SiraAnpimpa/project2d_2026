class_name CombatProjectile
extends Area2D

const PULSE_TEXTURE := preload("res://Assets/Gameplay/VFX/pulse_rifle_bolt.png")
const ACID_TEXTURE := preload("res://Assets/Gameplay/VFX/spitter_acid_projectile.png")

@export var speed := 720.0
@export var damage := 18
@export var lifetime := 1.5
@export var max_range := 900.0
@export var hostile := false

var direction := Vector2.RIGHT
var travelled := 0.0
@onready var sprite: Sprite2D = $Sprite


func configure(new_direction: Vector2, new_damage: int, new_speed: float, new_lifetime: float, is_hostile: bool = false) -> void:
	direction = new_direction.normalized()
	damage = new_damage
	speed = new_speed
	lifetime = new_lifetime
	hostile = is_hostile
	if is_inside_tree():
		remove_from_group("EnemyProjectile")
		remove_from_group("PlayerProjectile")
		add_to_group("EnemyProjectile" if hostile else "PlayerProjectile")
	rotation = direction.angle()
	if hostile:
		collision_layer = 32
		collision_mask = 3
		sprite.texture = ACID_TEXTURE
		$Trail.default_color = Color(0.28, 0.9, 0.08, 0.72)
	else:
		collision_layer = 16
		collision_mask = 5
		sprite.texture = PULSE_TEXTURE
	modulate = Color.WHITE


func _ready() -> void:
	add_to_group("EnemyProjectile" if hostile else "PlayerProjectile")
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime, false).timeout.connect(_expire)


func _physics_process(delta: float) -> void:
	var step := direction * speed * delta
	global_position += step
	travelled += step.length()
	if travelled >= max_range:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if hostile:
		if body.is_in_group("Player"):
			GameManager.damage(damage)
			if body.has_method("hit_feedback"):
				body.hit_feedback()
			impact(Color(0.35, 1.0, 0.12))
		elif body.collision_layer & 1:
			impact(Color(0.35, 1.0, 0.12))
	else:
		if body.is_in_group("Enemy") and body.has_method("take_damage"):
			body.take_damage(damage, direction)
			impact(Color(0.35, 0.9, 1.0))
		elif body.collision_layer & 1:
			impact(Color(0.35, 0.9, 1.0))


func impact(color: Color) -> void:
	set_physics_process(false)
	set_deferred("monitoring", false)
	var burst := CPUParticles2D.new()
	burst.one_shot = true
	burst.amount = 10
	burst.lifetime = 0.22
	burst.explosiveness = 1.0
	burst.direction = Vector2(-1, 0)
	burst.spread = 180.0
	burst.initial_velocity_min = 45.0
	burst.initial_velocity_max = 120.0
	burst.scale_amount_min = 1.5
	burst.scale_amount_max = 3.5
	burst.color = color
	get_parent().add_child(burst)
	burst.global_position = global_position
	burst.emitting = true
	queue_free()


func _expire() -> void:
	if is_inside_tree():
		queue_free()
