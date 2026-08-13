class_name SalvageDrop
extends Area2D

@onready var visual: Node2D = $Visual
@onready var amount_label: Label = $Amount
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var drop_id := -1
var amount := 0
var collecting := false
var animation_time := 0.0


func configure(new_drop_id: int, new_amount: int) -> void:
	drop_id = new_drop_id
	amount = maxi(new_amount, 0)


func _ready() -> void:
	amount_label.text = "x%02d" % amount


func _process(delta: float) -> void:
	animation_time += delta
	visual.position.y = sin(animation_time * 3.2) * 3.0
	amount_label.position.y = 22.0 + visual.position.y


func _on_body_entered(body: Node2D) -> void:
	if collecting or !body.is_in_group("Player"):
		return
	collecting = true
	collision_shape.set_deferred("disabled", true)
	GameManager.collect_dropped_salvage(drop_id, amount)
	if AudioManager.coin_pickup_sfx:
		AudioManager.coin_pickup_sfx.play()
	var pickup := create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	pickup.tween_property(self, "scale", Vector2(1.45, 1.45), 0.12)
	pickup.parallel().tween_property(self, "modulate:a", 0.0, 0.12)
	await pickup.finished
	queue_free()
