class_name WorldItemPickup
extends Area2D

@export var pickup_id := ""
@export var item_id: StringName = &"scrap_metal"
@export var display_name := "SCRAP METAL"
@export var amount := 1
@export var icon: Texture2D
@export var glow_color := Color(0.286, 0.843, 1.0, 0.32)
@export var visual_scale := 0.052

@onready var visual: Node2D = $Visual
@onready var glow: Polygon2D = $Visual/Glow
@onready var sprite: Sprite2D = $Visual/Icon
@onready var amount_label: Label = $Amount
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var animation_time := 0.0
var collecting := false


func _ready() -> void:
	if GameManager.is_pickup_collected(pickup_id):
		queue_free()
		return
	sprite.texture = icon
	sprite.scale = Vector2.ONE * visual_scale
	glow.color = glow_color
	amount_label.text = "x%d" % amount
	amount_label.visible = amount > 1


func _process(delta: float) -> void:
	animation_time += delta
	visual.position.y = -10.0 + sin(animation_time * 2.8) * 5.0
	var pulse := 0.88 + sin(animation_time * 3.6) * 0.08
	glow.scale = Vector2.ONE * pulse
	amount_label.position.y = 26.0 + visual.position.y


func _on_body_entered(body: Node2D) -> void:
	if collecting or !body.is_in_group("Player"):
		return
	if !GameManager.collect_pickup(pickup_id, item_id, amount):
		return
	collecting = true
	collision_shape.set_deferred("disabled", true)
	if AudioManager.coin_pickup_sfx:
		AudioManager.coin_pickup_sfx.play()
	var hud := get_tree().get_first_node_in_group("GameHUD")
	if hud != null and hud.has_method("alert"):
		hud.alert("ITEM ACQUIRED // %s  x%d" % [display_name, amount])
	var pickup := create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	pickup.tween_property(self, "scale", Vector2(1.35, 1.35), 0.16)
	pickup.parallel().tween_property(self, "modulate:a", 0.0, 0.16)
	await pickup.finished
	queue_free()
