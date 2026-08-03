extends RigidBody2D

func _ready() -> void:
	pass
	
func shoot(direction: Vector2, speed: float, lifetime:float):
	apply_impulse(direction * speed)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
