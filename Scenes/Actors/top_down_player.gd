class_name TopDownPlayer
extends CharacterBody2D

signal interaction_requested

@export var move_speed: float = 165.0
@export var acceleration: float = 1500.0
@export var deceleration: float = 1900.0
@export var walk_frames_per_second: float = 8.0
@export_category("Pulse Rifle")
@export var projectile_scene: PackedScene = preload("res://Scenes/Prefabs/combat_projectile.tscn")
@export var weapon_damage := 18
@export var fire_rate := 5.0
@export var projectile_speed := 760.0
@export var projectile_lifetime := 1.4
@export var mobile_auto_aim_range := 620.0
@export_category("Dodge")
@export var dodge_speed := 620.0
@export var dodge_duration := 0.18
@export var dodge_cooldown_time := 0.82

@onready var astronaut: Sprite2D = $Astronaut
@onready var camera: Camera2D = $Camera2D
@onready var muzzle: Marker2D = $Muzzle

var movement_enabled := true
var spawn_point := Vector2.ZERO
var facing_row := 0
var animation_clock := 0.0
var is_dying := false
var fire_cooldown := 0.0
var aim_direction := Vector2.RIGHT
var mobile_move_direction := Vector2.ZERO
var mobile_firing := false
var mobile_input_active := false
var desktop_firing := false
var last_facing_direction := Vector2.RIGHT
var current_interactable: Node2D = null
var interaction_scan_clock := 0.0
var projectile_power_scale := 1.0
var dodging := false
var dodge_remaining := 0.0
var dodge_cooldown := 0.0
var dodge_direction := Vector2.RIGHT


func _ready() -> void:
	spawn_point = global_position
	GameManager.player = self
	GameManager.weapon_upgrade_changed.connect(_on_weapon_upgrade_changed)
	_apply_weapon_upgrades()
	_update_sprite(0)


func _exit_tree() -> void:
	if GameManager.player == self:
		GameManager.player = null


func _input(event: InputEvent) -> void:
	# A release must always stop desktop fire, even if the pointer ends over UI.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and !event.pressed:
		desktop_firing = false


func _unhandled_input(event: InputEvent) -> void:
	# Only an unhandled physical mouse press begins PC firing. UI and touch events
	# are consumed before this point and can never leak into the weapon channel.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		desktop_firing = true


func _physics_process(delta: float) -> void:
	if fire_cooldown > 0.0:
		fire_cooldown -= delta
	dodge_cooldown = maxf(dodge_cooldown - delta, 0.0)
	if dodging:
		dodge_remaining -= delta
		velocity = dodge_direction * dodge_speed
		move_and_slide()
		if dodge_remaining <= 0.0:
			dodging = false
			astronaut.modulate = Color.WHITE
		return
	var input_direction := Vector2.ZERO
	if movement_enabled and !is_dying:
		var keyboard_direction := Input.get_vector("Left", "Right", "Up", "Down")
		input_direction = mobile_move_direction if mobile_move_direction.length_squared() > 0.01 else keyboard_direction
	if movement_enabled and !is_dying and Input.is_action_just_pressed("Dodge"):
		start_dodge(input_direction)
		return

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
		perform_interaction()
	if movement_enabled and Input.is_action_just_pressed("UseMedKit"):
		use_med_kit()

	_update_aim()
	if movement_enabled and !is_dying and (desktop_firing or mobile_firing):
		fire_weapon()

	interaction_scan_clock -= delta
	if interaction_scan_clock <= 0.0:
		interaction_scan_clock = 0.1
		_scan_interactables()


func _update_facing(direction: Vector2) -> void:
	last_facing_direction = direction.normalized()
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


func start_dodge(preferred_direction := Vector2.ZERO) -> bool:
	if !movement_enabled or is_dying or dodging or dodge_cooldown > 0.0:
		return false
	dodge_direction = preferred_direction.normalized() if preferred_direction.length_squared() > 0.01 else aim_direction.normalized()
	if dodge_direction.length_squared() < 0.01:
		dodge_direction = Vector2.RIGHT
	dodging = true
	dodge_remaining = dodge_duration
	dodge_cooldown = dodge_cooldown_time
	astronaut.modulate = Color(0.55, 0.95, 1.0, 0.62)
	return true


func is_invulnerable() -> bool:
	return dodging


func _update_aim() -> void:
	if mobile_firing:
		var target := _find_mobile_auto_aim_target()
		if is_instance_valid(target):
			aim_direction = (target.global_position - global_position).normalized()
		else:
			aim_direction = last_facing_direction
	elif mobile_input_active:
		aim_direction = last_facing_direction
	else:
		var mouse_vector := get_global_mouse_position() - global_position
		if mouse_vector.length_squared() > 1.0:
			aim_direction = mouse_vector.normalized()
	muzzle.position = aim_direction * 25.0 + Vector2(0, -19)


func set_mobile_move(direction: Vector2) -> void:
	mobile_input_active = true
	mobile_move_direction = direction.limit_length(1.0)


func set_mobile_fire(firing: bool) -> void:
	mobile_input_active = true
	mobile_firing = firing
	if firing:
		_update_aim()


func _find_mobile_auto_aim_target() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance := mobile_auto_aim_range
	for candidate_node in get_tree().get_nodes_in_group("Enemy"):
		var candidate := candidate_node as Node2D
		if !is_instance_valid(candidate) or candidate.collision_layer == 0 or !candidate.is_visible_in_tree():
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance >= nearest_distance or !_has_line_of_sight_to(candidate):
			continue
		nearest = candidate
		nearest_distance = distance
	return nearest


func _has_line_of_sight_to(target: Node2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 5)
	query.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == target


func fire_weapon() -> void:
	if fire_cooldown > 0.0 or projectile_scene == null or !movement_enabled:
		return
	var projectile := projectile_scene.instantiate() as CombatProjectile
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = muzzle.global_position
	projectile.configure(aim_direction, weapon_damage, projectile_speed, projectile_lifetime)
	projectile.scale = Vector2.ONE * projectile_power_scale
	fire_cooldown = 1.0 / maxf(fire_rate, 0.1)
	var flash := Polygon2D.new()
	flash.polygon = PackedVector2Array([
		Vector2(0, -4), Vector2(22, -6), Vector2(38, 0),
		Vector2(22, 6), Vector2(0, 4), Vector2(9, 0),
	])
	flash.color = Color(0.5, 0.94, 1.0, 0.92)
	add_child(flash)
	flash.position = muzzle.position
	flash.rotation = aim_direction.angle()
	var tween := create_tween()
	tween.tween_property(flash, "scale", Vector2(0.2, 0.2), 0.08)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.08)
	tween.tween_callback(flash.queue_free)


func _on_weapon_upgrade_changed(_category: StringName, _level: int) -> void:
	_apply_weapon_upgrades()


func _apply_weapon_upgrades() -> void:
	weapon_damage = GameManager.get_weapon_damage()
	fire_rate = GameManager.get_weapon_fire_rate()
	projectile_speed = GameManager.get_weapon_projectile_speed()
	projectile_power_scale = GameManager.get_weapon_projectile_scale()


func _scan_interactables() -> void:
	var best: Node2D = null
	var best_distance := INF
	for candidate in get_tree().get_nodes_in_group("Interactable"):
		if !(candidate is Node2D) or !candidate.has_method("can_interact") or !candidate.can_interact(self):
			continue
		var target_position: Vector2 = candidate.get_interaction_position() if candidate.has_method("get_interaction_position") else candidate.global_position
		var distance := global_position.distance_to(target_position)
		var radius := float(candidate.get("interaction_radius")) if candidate.get("interaction_radius") != null else 115.0
		if distance <= radius and distance < best_distance:
			best = candidate
			best_distance = distance
	current_interactable = best
	var hud := get_tree().get_first_node_in_group("GameHUD")
	if hud != null and hud.has_method("set_interaction_prompt"):
		hud.set_interaction_prompt(best.get_prompt() if best != null else "")


func perform_interaction() -> void:
	if current_interactable != null and is_instance_valid(current_interactable) and current_interactable.can_interact(self):
		current_interactable.interact(self)
		interaction_requested.emit()


func use_med_kit() -> void:
	var hud := get_tree().get_first_node_in_group("GameHUD")
	if GameManager.use_med_kit():
		if hud != null and hud.has_method("alert"):
			hud.alert("MED KIT USED // HP FULL", "PICKUP")
		hit_feedback(Color(0.45, 1.0, 0.62))
	elif hud != null and hud.has_method("alert"):
		hud.alert("HP ALREADY FULL" if GameManager.hp >= GameManager.max_hp else "NO MED KIT")


func hit_feedback(color: Color = Color(1.0, 0.25, 0.32)) -> void:
	var tween := create_tween()
	tween.tween_property(astronaut, "modulate", color, 0.07)
	tween.tween_property(astronaut, "modulate", Color.WHITE, 0.14)


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
	desktop_firing = false
	mobile_firing = false
	if AudioManager.death_sfx:
		AudioManager.death_sfx.play()
	var fade_out := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade_out.tween_property(self, "modulate", Color(1.0, 0.22, 0.3, 0.0), 0.3)
	fade_out.parallel().tween_property(self, "scale", Vector2(0.72, 0.72), 0.3)
	await fade_out.finished
	var test_scene := get_tree().current_scene != null and get_tree().current_scene.scene_file_path.begins_with("res://Tests/")
	if !test_scene:
		return
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
