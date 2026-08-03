extends Area2D

@export var speed : float = 350.0
@export var lifetime : float = 3.0
@export var damage : int = 10

var direction : Vector2 = Vector2.RIGHT

func _ready() -> void:
	$AnimatedSprite2D.play()
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func launch(dir: Vector2) -> void:
	direction = dir.normalized()
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
