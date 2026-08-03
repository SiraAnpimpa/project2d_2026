extends Enemy

@export var max_hp : int = 150
@export var attack_range : float = 100.0
@export var idle_duration : float = 3.0
@export var jump_force : float = 500.0
@export var retreat_offset : float = 500.0
@export var shot_count : int = 10
@export var shot_interval : float = 0.4
@export var bolt_scene : PackedScene

@onready var pivot_node : Node2D = $pivot
@onready var pivot_sprite : AnimatedSprite2D = $pivot/AnimatedSprite2D
@onready var hp_bar : ProgressBar = $UI/ProgressBar
@onready var ui_node : CanvasLayer = $UI
@onready var melee_hitbox : Area2D = $pivot/MeleeHitbox

var hp : int
var state : String = "idle"
var facing : int = -1  # -1 = facing left, 1 = facing right

func _ready() -> void:
	super._ready()
	hp = max_hp
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	melee_hitbox.monitoring = false
	melee_hitbox.monitorable = false
	play_anim("idle")
	ui_node.visible = false
	run_pattern()

func _physics_process(delta: float) -> void:
	if not alive:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	# Continuously track player position while idle or moving around
	if state == "idle":
		face_player()
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif state != "melee" and state != "retreat":
		velocity.x = 0

	move_and_slide()

func face_player() -> void:
	var player = GameManager.player
	if player == null:
		return
	
	if player.global_position.x < global_position.x:
		facing = 1
	else:
		facing = -1

	pivot_node.scale.x = abs(pivot_node.scale.x) * facing

# --- Main attack pattern loop ---
func run_pattern() -> void:
	while alive:
		state = "idle"
		play_anim("idle")
		await get_tree().create_timer(idle_duration).timeout
		if not is_instance_valid(self) or not is_inside_tree() or not alive: return

		await melee_combo()
		if not is_instance_valid(self) or not is_inside_tree() or not alive: return

		state = "idle"
		play_anim("idle")
		await get_tree().create_timer(idle_duration * 0.5).timeout
		if not is_instance_valid(self) or not is_inside_tree() or not alive: return

		await retreat_and_shoot()
		if not is_instance_valid(self) or not is_inside_tree() or not alive: return

func melee_combo() -> void:
	state = "melee"
	face_player()

	play_anim("jump")
	velocity.y = -jump_force
	velocity.x = -facing * 300
	await get_tree().create_timer(0.1).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return

	# Wait until she's actually back on the ground before attacking
	var safety_timeout = 0.0
	while not is_on_floor():
		if not is_instance_valid(self) or not is_inside_tree():
			return
		await get_tree().physics_frame
		safety_timeout += 0.016
		if safety_timeout > 2.0:  # failsafe in case she never registers as grounded
			break
	velocity.x = 0

	if not alive:
		return

	for anim in ["melee", "melee", "melee2"]:
		if not alive or not is_inside_tree(): return
		play_anim(anim)
		melee_hitbox.monitoring = true
		melee_hitbox.monitorable = true
		await get_tree().create_timer(0.3).timeout
		if not is_instance_valid(self) or not is_inside_tree(): return
		melee_hitbox.monitoring = false
		melee_hitbox.monitorable = false
		await get_tree().create_timer(0.3).timeout
		if not is_instance_valid(self) or not is_inside_tree(): return

func hop_toward_player() -> void:
	play_anim("jump")
	velocity.y = -jump_force
	velocity.x = -facing * 150
	await get_tree().create_timer(0.15).timeout
	velocity.x = 0

func retreat_and_shoot() -> void:
	state = "retreat"
	pivot_node.scale.x = facing * abs(pivot_node.scale.x)
	play_anim("jump")
	velocity.y = -jump_force
	velocity.x = facing * retreat_offset * 0.5
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(self) or not is_inside_tree(): return
	velocity.x = 0

	face_player()
	state = "shoot"
	for i in range(shot_count):
		if not alive or not is_inside_tree(): return
		play_anim("shoot")
		fire_bolt()
		await get_tree().create_timer(shot_interval).timeout
		if not is_instance_valid(self) or not is_inside_tree(): return

func fire_bolt() -> void:
	if bolt_scene == null:
		return
	var player = GameManager.player
	if player == null:
		return
	var bolt = bolt_scene.instantiate()
	get_tree().current_scene.add_child(bolt)
	bolt.global_position = pivot_node.global_position
	var target_point = player.global_position + Vector2(0, -40)
	bolt.launch(target_point - pivot_node.global_position)

func play_anim(anim_name: String) -> void:
	if pivot_sprite.animation != anim_name:
		pivot_sprite.animation = anim_name
		pivot_sprite.play()

# --- Damage handling: idle = free-hit window ---
func _on_hit_area_body_entered(body: Node2D) -> void:
	if alive and body.is_in_group("Bullet"):
		take_damage(5)
		body.queue_free()

func _on_hit_area_area_entered(area: Area2D) -> void:
	if alive and area.is_in_group("Bullet"):
		take_damage(5)

func take_damage(amount: int) -> void:
	hp -= amount
	hp_bar.value = hp
	if hp <= 0:
		boss_death()

func boss_death() -> void:
	alive = false
	collision_layer = 0
	GameManager.add_score()
	pivot_sprite.hide()
	# Stop the boss music
	var music_player = get_node_or_null("/root/level_03/MusicPlayer") # Adjust path to match your level
	if music_player:
		music_player.stop()

	$DeathParticles.emitting = true
	$DeathSfx.play()
	show_slain_text()
	await get_tree().create_timer(1.5).timeout
	queue_free()

func show_slain_text() -> void:
	var label := Label.new()
	label.text = "ARRIETTE SLAIN"
	label.add_theme_font_size_override("font_size", 48)
	get_tree().current_scene.add_child(label)
	label.global_position = global_position + Vector2(-100, -150)
	label.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.3)
	tween.tween_property(label, "position:y", label.position.y - 40, 1.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.5).set_delay(0.8)
	tween.finished.connect(label.queue_free)

func _on_bossroom_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		ui_node.visible = true
