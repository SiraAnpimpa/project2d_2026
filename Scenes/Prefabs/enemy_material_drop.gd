class_name EnemyMaterialDrop
extends Area2D

const ITEM_ICONS: Dictionary = {
	"scrap_metal": preload("res://Assets/UI/Items/scrap_metal.png"),
	"energy_crystal": preload("res://Assets/UI/Items/energy_crystal.png"),
	"circuit_part": preload("res://Assets/UI/Items/circuit_part.png"),
}
const ITEM_NAMES: Dictionary = {
	"scrap_metal": "SCRAP METAL",
	"energy_crystal": "ENERGY CRYSTAL",
	"circuit_part": "CIRCUIT PART",
}

@onready var visual: Node2D = $Visual
@onready var glow: Polygon2D = $Visual/Glow
@onready var icon: Sprite2D = $Visual/Icon
@onready var amount_label: Label = $Amount
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var item_id: StringName = &"scrap_metal"
var amount := 1
var collecting := false
var animation_time := 0.0


func configure(new_item_id: StringName, new_amount: int = 1) -> void:
	item_id = new_item_id
	amount = maxi(new_amount, 1)


func _ready() -> void:
	add_to_group("EnemyMaterialDrop")
	icon.texture = ITEM_ICONS.get(String(item_id)) as Texture2D
	amount_label.text = "x%d" % amount
	amount_label.visible = amount > 1
	match item_id:
		&"energy_crystal": glow.color = Color(0.282, 0.855, 1.0, 0.34)
		&"circuit_part": glow.color = Color(0.439, 0.31, 1.0, 0.34)
		_: glow.color = Color(0.976, 0.808, 0.384, 0.30)


func _process(delta: float) -> void:
	animation_time += delta
	visual.position.y = -8.0 + sin(animation_time * 3.1) * 4.0
	glow.scale = Vector2.ONE * (0.9 + sin(animation_time * 3.8) * 0.08)


func _on_body_entered(body: Node2D) -> void:
	if collecting or !body.is_in_group("Player"):
		return
	collecting = true
	collision_shape.set_deferred("disabled", true)
	GameManager.add_item(item_id, amount)
	if GameManager.sfx_on and AudioManager.coin_pickup_sfx:
		AudioManager.coin_pickup_sfx.play()
	var hud := get_tree().get_first_node_in_group("GameHUD")
	if hud != null and hud.has_method("alert"):
		hud.alert("MATERIAL ACQUIRED // %s  x%d" % [ITEM_NAMES.get(String(item_id), String(item_id).to_upper()), amount])
	var pickup := create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	pickup.tween_property(self, "scale", Vector2(1.35, 1.35), 0.14)
	pickup.parallel().tween_property(self, "modulate:a", 0.0, 0.14)
	await pickup.finished
	queue_free()
