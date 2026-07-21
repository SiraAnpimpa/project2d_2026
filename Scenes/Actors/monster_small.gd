extends Enemy

func _ready() -> void:
	super._ready()
	if $Sprite/AnimateSprite.sprite_frames == null:
		push_error("monster_small: AnimateSprite ยังไม่ได้ผูก SpriteFrames resource")
		return

	var types: Array = Array($Sprite/AnimateSprite.sprite_frames.get_animation_names())
	if types.is_empty():
		push_error("monster_small: SpriteFrames ไม่มี animation ให้เลือกเลย")
		return

	$Sprite/AnimateSprite.animation = types.pick_random()
	$Sprite/AnimateSprite.play()
