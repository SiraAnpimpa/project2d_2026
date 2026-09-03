class_name HiveMatriarch
extends CharacterBody2D

signal phase_changed(phase: int)
signal died

enum State { HUNT, TELEGRAPH, ATTACK, RECOVER, DEAD }

const CRAWLER: PackedScene = preload("res://Scenes/Actors/alien_crawler.tscn")
const SPITTER: PackedScene = preload("res://Scenes/Actors/alien_spitter.tscn")
const STALKER: PackedScene = preload("res://Scenes/Actors/stalker.tscn")
const PROJECTILE: PackedScene = preload("res://Scenes/Prefabs/combat_projectile.tscn")
const FINAL_CORE_DROP: PackedScene = preload("res://Scenes/Prefabs/enemy_material_drop.tscn")
const ACID_POOL_SCRIPT := preload("res://Scenes/Gameplay/acid_pool.gd")
const ATTACK_CATALOG := [
	"claw_combo", "charge", "leap", "projectile_spread", "acid_field", "summon", "rage_sweep",
]

@export var max_hp := 2800
@export var move_speed := 96.0
@export var melee_damage := 34
@export var detection_range := 980.0
@export var melee_range := 124.0
@export var arena_bounds := Rect2(-710, -360, 1420, 720)

@onready var visual: Node2D = $Visual
@onready var sprite: Sprite2D = $Visual/Sprite
@onready var hp_bar: ProgressBar = $HPBar
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var hp := 2800
var phase := 1
var state := State.HUNT
var cooldown := 1.4
var animation_clock := 0.0
var charging := false
var charge_direction := Vector2.ZERO
var charge_remaining := 0.0
var charge_connected := false
var last_attack := ""
var attacks_used: Array[String] = []
var attack_usage: Dictionary = {}
var reposition_sign := 1.0
var encounter_active := true


func _ready() -> void:
	add_to_group("Enemy")
	add_to_group("Boss")
	hp = max_hp
	hp_bar.visible = false
	for attack_name in ATTACK_CATALOG:
		attack_usage[attack_name] = 0


func set_encounter_active(active: bool) -> void:
	encounter_active = active
	if !active:
		velocity = Vector2.ZERO


func get_attack_catalog() -> PackedStringArray:
	return PackedStringArray(ATTACK_CATALOG)


func _physics_process(delta: float) -> void:
	if state == State.DEAD or !encounter_active:
		return
	animation_clock += delta * (6.0 + phase)
	_update_animation()
	if charging:
		_process_charge(delta)
		return
	if state in [State.TELEGRAPH, State.ATTACK, State.RECOVER]:
		velocity = velocity.move_toward(Vector2.ZERO, 700.0 * delta)
		move_and_slide()
		return
	cooldown = maxf(cooldown - delta, 0.0)
	var player := GameManager.player as Node2D
	if !is_instance_valid(player) or GameManager.death_in_progress:
		velocity = Vector2.ZERO
		return
	var offset := player.global_position - global_position
	var distance := offset.length()
	if distance > detection_range:
		velocity = Vector2.ZERO
		return
	if cooldown <= 0.0:
		_choose_attack(distance)
		return
	var direction := offset.normalized()
	var phase_speed := move_speed + float(phase - 1) * 15.0
	if distance > 285.0:
		velocity = direction * phase_speed
	elif distance < 175.0:
		velocity = -direction * phase_speed * 0.72
	else:
		velocity = direction.orthogonal() * reposition_sign * phase_speed * 0.58
	move_and_slide()
	global_position.x = clampf(global_position.x, arena_bounds.position.x, arena_bounds.end.x)
	global_position.y = clampf(global_position.y, arena_bounds.position.y, arena_bounds.end.y)
	if absf(velocity.x) > 2.0:
		sprite.flip_h = velocity.x < 0.0


func _choose_attack(distance: float) -> void:
	var attack := _select_attack(distance)
	last_attack = attack
	attacks_used.append(attack)
	attack_usage[attack] = int(attack_usage.get(attack, 0)) + 1
	if attacks_used.size() > 12:
		attacks_used.pop_front()
	reposition_sign *= -1.0
	_start_attack(attack)


func _select_attack(distance: float) -> String:
	var candidates: Array[String] = ["charge", "projectile_spread"]
	if distance <= melee_range + 70.0:
		candidates.append("claw_combo")
	if phase >= 2:
		candidates.append("leap")
		candidates.append("acid_field")
		if get_tree().get_nodes_in_group("BossSummon").size() < 4:
			candidates.append("summon")
	if phase >= 3 and distance <= 260.0:
		candidates.append("rage_sweep")
	if candidates.size() > 1 and last_attack in candidates:
		candidates.erase(last_attack)
	return candidates.pick_random()


func _start_attack(kind: String) -> void:
	if state != State.HUNT:
		return
	state = State.TELEGRAPH
	velocity = Vector2.ZERO
	var warning_color := Color(0.36, 1.0, 0.24) if kind in ["projectile_spread", "acid_field", "summon"] else Color(1.0, 0.34, 0.2)
	var warning := create_tween().set_loops(3)
	warning.tween_property(visual, "modulate", warning_color, 0.11)
	warning.tween_property(visual, "modulate", Color.WHITE, 0.11)
	await get_tree().create_timer(maxf(0.66 - float(phase - 1) * 0.07, 0.5)).timeout
	if state == State.DEAD:
		return
	state = State.ATTACK
	match kind:
		"claw_combo": await _perform_claw_combo()
		"leap": await _perform_leap()
		"projectile_spread": _perform_projectile_spread()
		"acid_field": await _perform_acid_field()
		"summon": _perform_summon()
		"rage_sweep": await _perform_rage_sweep()
		_: 
			_begin_charge()
			return
	if state != State.DEAD:
		await get_tree().create_timer(0.16).timeout
		_begin_recovery()


func _perform_melee() -> void:
	var player := GameManager.player as Node2D
	if is_instance_valid(player) and global_position.distance_to(player.global_position) <= melee_range + 28.0:
		GameManager.damage(melee_damage)
		if player.has_method("hit_feedback"):
			player.hit_feedback()


func _perform_claw_combo() -> void:
	for hit_index in range(3):
		if state == State.DEAD:
			return
		var player := GameManager.player as Node2D
		if is_instance_valid(player) and global_position.distance_to(player.global_position) <= melee_range + 34.0:
			GameManager.damage(12 + phase * 3)
			if player.has_method("hit_feedback"):
				player.hit_feedback()
		visual.rotation = (-0.1 if hit_index % 2 == 0 else 0.1)
		await get_tree().create_timer(0.16).timeout
	visual.rotation = 0.0


func _perform_projectile_spread() -> void:
	var player := GameManager.player as Node2D
	var base_direction := Vector2.RIGHT
	if is_instance_valid(player):
		base_direction = (player.global_position - global_position).normalized()
	var count := 3 if phase == 1 else (5 if phase == 2 else 7)
	var spread := 0.52 if phase == 1 else 0.76
	for index in range(count):
		var ratio := 0.5 if count == 1 else float(index) / float(count - 1)
		var direction := base_direction.rotated(lerpf(-spread, spread, ratio))
		_spawn_projectile(direction, 14 + phase * 3, 345.0 + phase * 28.0)


func _perform_summon() -> void:
	var existing := get_tree().get_nodes_in_group("BossSummon").size()
	if existing >= 4:
		_perform_projectile_spread()
		return
	var summon_count := mini(phase, 3)
	for index in range(summon_count):
		var packed: PackedScene = STALKER if phase == 3 and index == 0 else (SPITTER if index % 2 == 0 else CRAWLER)
		var enemy := packed.instantiate() as AlienEnemy
		enemy.drop_table = null
		get_tree().current_scene.add_child(enemy)
		enemy.add_to_group("BossSummon")
		enemy.global_position = global_position + Vector2.RIGHT.rotated(TAU * float(index) / float(summon_count)) * 190.0


func _perform_leap() -> void:
	var player := GameManager.player as Node2D
	if !is_instance_valid(player):
		return
	var player_velocity := (player as CharacterBody2D).velocity if player is CharacterBody2D else Vector2.ZERO
	var predicted := player.global_position + player_velocity * 0.42
	predicted.x = clampf(predicted.x, arena_bounds.position.x + 70.0, arena_bounds.end.x - 70.0)
	predicted.y = clampf(predicted.y, arena_bounds.position.y + 70.0, arena_bounds.end.y - 70.0)
	_create_warning_zone(predicted, 112.0, Color(1.0, 0.28, 0.18, 0.25), 0.72)
	await get_tree().create_timer(0.46).timeout
	if state == State.DEAD:
		return
	var leap := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	leap.tween_property(self, "global_position", predicted, 0.24)
	leap.parallel().tween_property(visual, "scale", Vector2(1.12, 1.12), 0.12)
	leap.tween_property(visual, "scale", Vector2.ONE, 0.1)
	await leap.finished
	if is_instance_valid(player) and global_position.distance_to(player.global_position) <= 112.0:
		GameManager.damage(30 + phase * 4)
		if player.has_method("hit_feedback"):
			player.hit_feedback()


func _perform_acid_field() -> void:
	var player := GameManager.player as Node2D
	if !is_instance_valid(player):
		return
	var positions: Array[Vector2] = []
	var player_velocity := (player as CharacterBody2D).velocity if player is CharacterBody2D else Vector2.ZERO
	var origin := player.global_position + player_velocity * 0.28
	for index in range(3):
		var offset := Vector2.RIGHT.rotated(TAU * float(index) / 3.0) * (105.0 if index > 0 else 0.0)
		var point := origin + offset
		point.x = clampf(point.x, arena_bounds.position.x + 80.0, arena_bounds.end.x - 80.0)
		point.y = clampf(point.y, arena_bounds.position.y + 80.0, arena_bounds.end.y - 80.0)
		positions.append(point)
		_create_warning_zone(point, 72.0, Color(0.48, 1.0, 0.12, 0.22), 0.78)
	await get_tree().create_timer(0.58).timeout
	if state == State.DEAD:
		return
	for point in positions:
		_spawn_acid_hazard(point)


func _perform_rage_sweep() -> void:
	_create_warning_zone(global_position, 220.0, Color(1.0, 0.2, 0.16, 0.2), 0.78)
	await get_tree().create_timer(0.5).timeout
	if state == State.DEAD:
		return
	var player := GameManager.player as Node2D
	if is_instance_valid(player) and global_position.distance_to(player.global_position) <= 220.0:
		GameManager.damage(42)
		if player.has_method("hit_feedback"):
			player.hit_feedback()
	for index in range(12):
		_spawn_projectile(Vector2.RIGHT.rotated(TAU * float(index) / 12.0), 17, 390.0)


func _spawn_projectile(direction: Vector2, damage: int, speed: float) -> void:
	var projectile := PROJECTILE.instantiate() as CombatProjectile
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + direction * 82.0 + Vector2(0, -18)
	projectile.configure(direction, damage, speed, 2.7, true)


func _begin_charge() -> void:
	var player := GameManager.player as Node2D
	charge_direction = Vector2.RIGHT
	if is_instance_valid(player):
		charge_direction = (player.global_position - global_position).normalized()
	charge_remaining = 0.62
	charge_connected = false
	charging = true


func _process_charge(delta: float) -> void:
	charge_remaining -= delta
	velocity = charge_direction * (390.0 + phase * 58.0)
	move_and_slide()
	var player := GameManager.player as Node2D
	if !charge_connected and is_instance_valid(player) and global_position.distance_to(player.global_position) <= melee_range:
		charge_connected = true
		GameManager.damage(melee_damage + phase * 7)
		if player.has_method("hit_feedback"):
			player.hit_feedback()
	if charge_remaining <= 0.0 or get_slide_collision_count() > 0:
		charging = false
		_begin_recovery()


func _begin_recovery() -> void:
	if state == State.DEAD:
		return
	state = State.RECOVER
	velocity = Vector2.ZERO
	cooldown = maxf(1.45 - float(phase - 1) * 0.2, 0.92)
	await get_tree().create_timer(0.5).timeout
	if state != State.DEAD:
		state = State.HUNT


func _create_warning_zone(world_position: Vector2, radius: float, color: Color, lifetime: float) -> Polygon2D:
	var warning := Polygon2D.new()
	warning.z_index = 4
	warning.polygon = _circle_polygon(radius)
	warning.color = color
	get_tree().current_scene.add_child(warning)
	warning.global_position = world_position
	var pulse := warning.create_tween().set_loops(3)
	pulse.tween_property(warning, "modulate:a", 0.25, lifetime / 6.0)
	pulse.tween_property(warning, "modulate:a", 1.0, lifetime / 6.0)
	get_tree().create_timer(lifetime, false).timeout.connect(warning.queue_free)
	return warning


func _spawn_acid_hazard(world_position: Vector2) -> void:
	var hazard := Area2D.new()
	hazard.name = "MatriarchAcid"
	hazard.collision_layer = 0
	hazard.collision_mask = 2
	hazard.set_script(ACID_POOL_SCRIPT)
	hazard.set("tick_damage", 10 + phase * 2)
	hazard.set("tick_interval", 0.82)
	var pool := Polygon2D.new()
	pool.z_index = -2
	pool.polygon = _circle_polygon(70.0)
	pool.color = Color(0.34, 0.86, 0.08, 0.58)
	hazard.add_child(pool)
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 65.0
	collision.shape = shape
	hazard.add_child(collision)
	get_tree().current_scene.add_child(hazard)
	hazard.global_position = world_position
	var fade := hazard.create_tween()
	fade.tween_interval(3.6)
	fade.tween_property(hazard, "modulate:a", 0.0, 0.55)
	fade.tween_callback(hazard.queue_free)


func _circle_polygon(radius: float, points := 40) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for index in range(points):
		polygon.append(Vector2.RIGHT.rotated(TAU * float(index) / float(points)) * radius)
	return polygon


func take_damage(amount: int, knock_direction: Vector2 = Vector2.ZERO) -> void:
	if state == State.DEAD or !encounter_active:
		return
	hp = clampi(hp - amount, 0, max_hp)
	var next_phase := 3 if hp <= max_hp * 0.35 else (2 if hp <= max_hp * 0.70 else 1)
	if next_phase != phase:
		phase = next_phase
		phase_changed.emit(phase)
		var hud := get_tree().get_first_node_in_group("GameHUD")
		if hud != null and hud.has_method("queue_notification"):
			hud.queue_notification("WARNING", "HIVE MATRIARCH", "PHASE %d // ATTACK PATTERNS ESCALATING" % phase, 3.5, 8, "boss_phase_%d" % phase)
	_sync_boss_hud()
	var hurt := create_tween()
	hurt.tween_property(visual, "modulate", Color(0.35, 1.0, 0.82), 0.06)
	hurt.tween_property(visual, "modulate", Color.WHITE, 0.12)
	if hp <= 0:
		_die()
	elif knock_direction.length_squared() > 0.0:
		velocity += knock_direction * 4.0


func _sync_boss_hud() -> void:
	var hud := get_tree().get_first_node_in_group("GameHUD")
	if hud != null and hud.has_method("set_boss_health"):
		hud.set_boss_health(hp, max_hp, phase)


func _die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	charging = false
	velocity = Vector2.ZERO
	set_physics_process(false)
	collision_shape.set_deferred("disabled", true)
	collision_layer = 0
	collision_mask = 0
	for summon in get_tree().get_nodes_in_group("BossSummon"):
		if is_instance_valid(summon):
			summon.queue_free()
	for projectile in get_tree().get_nodes_in_group("EnemyProjectile"):
		if is_instance_valid(projectile):
			projectile.queue_free()
	for hazard in get_tree().get_nodes_in_group("EnvironmentalHazard"):
		if is_instance_valid(hazard) and hazard.name == "MatriarchAcid":
			hazard.queue_free()
	var hud := get_tree().get_first_node_in_group("GameHUD")
	if hud != null and hud.has_method("hide_boss"):
		hud.hide_boss()
	GameManager.mark_boss_defeated()
	died.emit()
	var death := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	death.tween_property(visual, "modulate", Color(0.35, 1.0, 0.62), 0.22)
	death.tween_property(visual, "scale", Vector2(1.2, 0.5), 0.65)
	death.parallel().tween_property(visual, "modulate:a", 0.0, 0.65)
	await death.finished
	_spawn_final_core()
	queue_free()


func _spawn_final_core() -> void:
	if GameManager.final_core_installed or GameManager.get_item_count(&"final_core") > 0:
		return
	var drop := FINAL_CORE_DROP.instantiate() as EnemyMaterialDrop
	drop.configure(&"final_core", 1)
	get_tree().current_scene.add_child(drop)
	drop.global_position = global_position


func _update_animation() -> void:
	var row := 0
	match state:
		State.HUNT: row = 1 if velocity.length_squared() > 25.0 else 0
		State.TELEGRAPH, State.ATTACK: row = 2
		State.RECOVER: row = 0
		State.DEAD: row = 3
	sprite.frame = row * 4 + int(animation_clock) % 4
