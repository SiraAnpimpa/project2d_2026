class_name AimJoystick
extends TextureRect

@export var dead_zone := 0.24
var touch_index := -1
var dragging_mouse := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)


func _exit_tree() -> void:
	_send_aim(Vector2.ZERO, false)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and touch_index < 0:
			touch_index = event.index
			_update_from_local(event.position)
		elif !event.pressed and event.index == touch_index:
			touch_index = -1
			_send_aim(Vector2.ZERO, false)
	elif event is InputEventScreenDrag and event.index == touch_index:
		_update_from_local(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging_mouse = event.pressed
		if dragging_mouse:
			_update_from_local(event.position)
		else:
			_send_aim(Vector2.ZERO, false)
	elif event is InputEventMouseMotion and dragging_mouse:
		_update_from_local(event.position)


func _update_from_local(local_position: Vector2) -> void:
	var half := size * 0.5
	var radius := maxf(minf(half.x, half.y), 1.0)
	var direction := (local_position - half) / radius
	direction = direction.limit_length(1.0)
	_send_aim(direction, direction.length() >= dead_zone)


func _send_aim(direction: Vector2, firing: bool) -> void:
	var player := GameManager.player
	if is_instance_valid(player) and player.has_method("set_mobile_aim"):
		player.set_mobile_aim(direction, firing)
