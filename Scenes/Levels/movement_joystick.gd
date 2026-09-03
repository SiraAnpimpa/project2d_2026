class_name MovementJoystick
extends Control

@export_range(0.0, 0.9, 0.01) var dead_zone := 0.16
@export var maximum_radius := 54.0

var touch_index := -1
var dragging_mouse := false
var direction := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	gui_input.connect(_on_gui_input)
	queue_redraw()


func _exit_tree() -> void:
	_send_direction(Vector2.ZERO)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and touch_index < 0:
			touch_index = event.index
			_update_from_local(event.position)
			accept_event()
		elif !event.pressed and event.index == touch_index:
			touch_index = -1
			_send_direction(Vector2.ZERO)
			accept_event()
	elif event is InputEventScreenDrag and event.index == touch_index:
		_update_from_local(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging_mouse = event.pressed
		if dragging_mouse:
			_update_from_local(event.position)
		else:
			_send_direction(Vector2.ZERO)
		accept_event()
	elif event is InputEventMouseMotion and dragging_mouse:
		_update_from_local(event.position)
		accept_event()


func _update_from_local(local_position: Vector2) -> void:
	var center := size * 0.5
	var radius := maxf(minf(maximum_radius, minf(size.x, size.y) * 0.38), 1.0)
	var raw_direction := ((local_position - center) / radius).limit_length(1.0)
	_send_direction(raw_direction if raw_direction.length() >= dead_zone else Vector2.ZERO)


func _send_direction(new_direction: Vector2) -> void:
	direction = new_direction.limit_length(1.0)
	var player := GameManager.player
	if is_instance_valid(player) and player.has_method("set_mobile_move"):
		player.set_mobile_move(direction)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := maxf(minf(maximum_radius, minf(size.x, size.y) * 0.38), 1.0)
	draw_circle(center, radius + 13.0, Color(0.008, 0.025, 0.045, 0.72))
	draw_arc(center, radius + 13.0, 0.0, TAU, 64, Color(0.24, 0.78, 0.95, 0.76), 2.0, true)
	draw_circle(center, radius - 5.0, Color(0.03, 0.12, 0.17, 0.52))
	var knob_position := center + direction * radius
	draw_circle(knob_position, 27.0, Color(0.08, 0.38, 0.48, 0.96))
	draw_arc(knob_position, 27.0, 0.0, TAU, 40, Color(0.55, 0.96, 1.0, 0.94), 2.0, true)
	draw_line(knob_position + Vector2(-9, 0), knob_position + Vector2(9, 0), Color(0.72, 0.98, 1.0), 2.0)
	draw_line(knob_position + Vector2(0, -9), knob_position + Vector2(0, 9), Color(0.72, 0.98, 1.0), 2.0)
