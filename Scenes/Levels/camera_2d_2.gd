extends Camera2D

# สร้างช่องสำหรับลาก Node ตัวละครมาใส่ใน Inspector
@export var target: Node2D

func _process(_delta: float) -> void:
	if target:
		# สั่งให้ตำแหน่งของกล้องเท่ากับตำแหน่งของตัวละครทุกๆ เฟรม
		global_position = target.global_position
