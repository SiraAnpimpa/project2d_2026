class_name EnemyMaterialDrop
extends Area2D

const ITEM_ATLAS: Texture2D = preload("res://Assets/Gameplay/Items/alien_upgrade_materials.png")
const ITEM_REGIONS: Dictionary = {
	"alien_biomass": Rect2(0, 294, 264, 607),
	"hardened_carapace": Rect2(255, 294, 230, 558),
	"acid_gland": Rect2(460, 284, 245, 617),
	"alien_core": Rect2(670, 289, 264, 563),
	"final_core": Rect2(910, 269, 344, 651),
}
const ITEM_NAMES: Dictionary = {
	"alien_biomass": "ALIEN BIOMASS",
	"hardened_carapace": "HARDENED CARAPACE",
	"acid_gland": "ACID GLAND",
	"alien_core": "ALIEN CORE",
	"final_core": "FINAL LAUNCH CORE",
	"med_kit": "MED KIT",
}

@onready var visual: Node2D = $Visual
@onready var glow: Polygon2D = $Visual/Glow
@onready var icon: Sprite2D = $Visual/Icon
@onready var amount_label: Label = $Amount
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var item_id: StringName = &"alien_biomass"
var amount := 1
var collecting := false
var animation_time := 0.0


func configure(new_item_id: StringName, new_amount: int = 1) -> void:
	item_id = new_item_id
	amount = maxi(new_amount, 1)


func _ready() -> void:
	add_to_group("EnemyMaterialDrop")
	icon.texture = _get_item_texture(item_id)
	amount_label.text = "x%d" % amount
	amount_label.visible = amount > 1
	match item_id:
		&"alien_biomass": glow.color = Color(0.82, 0.16, 0.55, 0.34)
		&"hardened_carapace": glow.color = Color(0.5, 0.35, 0.8, 0.34)
		&"acid_gland": glow.color = Color(0.48, 1.0, 0.15, 0.36)
		&"alien_core": glow.color = Color(0.22, 0.88, 1.0, 0.38)
		&"final_core": glow.color = Color(0.35, 1.0, 0.68, 0.52)
		&"med_kit": glow.color = Color(1.0, 0.32, 0.34, 0.42)


func _get_item_texture(for_item_id: StringName) -> Texture2D:
	if for_item_id == &"med_kit":
		return load("res://Assets/UI/Items/med_kit.png")
	var region: Rect2 = ITEM_REGIONS.get(String(for_item_id), ITEM_REGIONS["alien_biomass"])
	var atlas := AtlasTexture.new()
	atlas.atlas = ITEM_ATLAS
	atlas.region = region
	return atlas


func _process(delta: float) -> void:
	animation_time += delta
	visual.position.y = -8.0 + sin(animation_time * 3.1) * 4.0
	glow.scale = Vector2.ONE * (0.9 + sin(animation_time * 3.8) * 0.08)


func _on_body_entered(body: Node2D) -> void:
	if collecting or !body.is_in_group("Player"):
		return
	collecting = true
	collision_shape.set_deferred("disabled", true)
	if item_id == &"final_core":
		GameManager.collect_final_core()
	else:
		GameManager.add_item(item_id, amount)
	if GameManager.sfx_on and AudioManager.coin_pickup_sfx:
		AudioManager.coin_pickup_sfx.play()
	var hud := get_tree().get_first_node_in_group("GameHUD")
	if hud != null and hud.has_method("alert"):
		hud.alert("+%d %s" % [amount, ITEM_NAMES.get(String(item_id), String(item_id).to_upper())], "PICKUP")
	var pickup := create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	pickup.tween_property(self, "scale", Vector2(1.35, 1.35), 0.14)
	pickup.parallel().tween_property(self, "modulate:a", 0.0, 0.14)
	await pickup.finished
	queue_free()
