class_name TopDownPlayer
extends CharacterBody2D

signal interaction_requested

@export var move_speed: float = 230.0
@export var acceleration: float = 1500.0
@export var deceleration: float = 1900.0
@export var walk_frames_per_second: float = 8.0

@onready var astronaut: Sprite2D = $Astronaut
@onready var camera: Camera2D = $Camera2D

var movement_enabled := true
var spawn_point := Vector2.ZERO
var facing_row := 0
var animation_clock := 0.0
var is_dying := false


func _ready() -> void:
	spawn_point = global_position
	GameManager.player = self
	_update_sprite(0)


func _exit_tree() -> void:
	if GameManager.player == self:
		GameManager.player = null


func _physics_process(delta: float) -> void:
	var input_direction := Vector2.ZERO
	if movement_enabled and !is_dying:
		input_direction = Input.get_vector("Left", "Right", "Up", "Down")

	var target_velocity := input_direction * move_speed
	var rate := acceleration if input_direction != Vector2.ZERO else deceleration
	velocity = velocity.move_toward(target_velocity, rate * delta)
	move_and_slide()

	if input_direction != Vector2.ZERO:
		_update_facing(input_direction)
		animation_clock += delta * walk_frames_per_second
		_update_sprite(int(animation_clock) % astronaut.hframes)
	else:
		animation_clock = 0.0
		_update_sprite(0)

	if movement_enabled and Input.is_action_just_pressed("Interact"):
		interaction_requested.emit()


func _update_facing(direction: Vector2) -> void:
	if absf(direction.x) > absf(direction.y):
		facing_row = 1 if direction.x < 0.0 else 2
	else:
		facing_row = 3 if direction.y < 0.0 else 0


func _update_sprite(column: int) -> void:
	astronaut.frame = facing_row * astronaut.hframes + column


func set_movement_enabled(enabled: bool) -> void:
	movement_enabled = enabled
	if !enabled:
		velocity = Vector2.ZERO
		animation_clock = 0.0
		_update_sprite(0)


func set_respawn_point(world_position: Vector2) -> void:
	global_position = world_position
	spawn_point = world_position


func set_respawn_position(world_position: Vector2) -> void:
	spawn_point = world_position


func set_camera_limits(bounds: Rect2) -> void:
	camera.limit_left = floori(bounds.position.x)
	camera.limit_top = floori(bounds.position.y)
	camera.limit_right = ceili(bounds.end.x)
	camera.limit_bottom = ceili(bounds.end.y)


func death_tween() -> void:
	if is_dying:
		return
	is_dying = true
	set_movement_enabled(false)
	if AudioManager.death_sfx:
		AudioManager.death_sfx.play()
	var fade_out := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade_out.tween_property(self, "modulate", Color(1.0, 0.22, 0.3, 0.0), 0.3)
	fade_out.parallel().tween_property(self, "scale", Vector2(0.72, 0.72), 0.3)
	await fade_out.finished
	global_position = spawn_point
	velocity = Vector2.ZERO
	modulate = Color.WHITE
	scale = Vector2(0.72, 0.72)
	var return_tween := create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	return_tween.tween_property(self, "scale", Vector2.ONE, 0.24)
	await return_tween.finished
	if AudioManager.respawn_sfx:
		AudioManager.respawn_sfx.play()
	is_dying = false
	set_movement_enabled(true)
