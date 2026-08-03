extends Area2D

# You can change these to your likings
@export var amplitude := 4
@export var frequency := 5

var time_passed = 0
var initial_position := Vector2.ZERO

func _ready():
	$AnimatedSprite2D.play()
	initial_position = position

func _process(delta):
	coin_hover(delta) # Call the coin_hover function

# Coin Hover Animation
func coin_hover(delta):
	time_passed += delta

# Coin collected
func _on_body_entered(body):
	if body.is_in_group("Player"):
		AudioManager.coin_pickup_sfx.play()
		GameManager.add_score()
		var tween = create_tween()
		tween.tween_property(self, "position", Vector2(position.x,position.y-100), 0.5)
		tween.set_parallel()
		tween.tween_property(self, "scale", Vector2(2,2), 0.5)
		await tween.finished
		queue_free()
