extends Enemy

@export var max_hp : int = 100
@export var attacks_before_rest : int = 5
@export var rest_duration : float = 4.0
@export var attack_cooldown : float = 0.8
@export var attack_range : float = 80.0
@export var detect_range : float = 300.0
@export var chase_speed : float = 60.0
@export var bolt_scene : PackedScene
@onready var pivot_node : Node2D = $pivot
@export var patrol_point_a : NodePath
@export var patrol_point_b : NodePath
@export var patrol_speed : float = 50.0
@onready var ui_node : CanvasLayer = $UI

var patrol_target : Vector2
var is_patrolling : bool = false
var going_to_b : bool = true
var hp : int
var attack_count : int = 0
var is_resting : bool = false
var is_attacking_now : bool = false
var attack_timer : float = 0.0

@onready var hp_bar : ProgressBar = $UI/ProgressBar
@onready var anim_player : AnimationPlayer = $AnimationPlayer
@onready var pivot_sprite : AnimatedSprite2D = $pivot/AnimatedSprite2D

func _ready() -> void:
	super._ready()
	hp = max_hp
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	play_anim("idle")
	patrol_target = global_position
	ui_node.visible = false

func _physics_process(delta: float) -> void:
	if not alive:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not is_on_floor():
		velocity += get_gravity() * delta
		
	if attack_timer > 0:
		attack_timer -= delta

	var player = GameManager.player
	var distance = INF
	if player:
		distance = global_position.distance_to(player.global_position)

	if is_patrolling:
		var to_target = patrol_target.x - global_position.x
		if abs(to_target) < 5:
			is_patrolling = false
			velocity.x = 0
			play_anim("idle")
		else:
			direction = 1 if to_target > 0 else -1
			velocity.x = direction * patrol_speed
			play_anim("idle")
		# Let the player interrupt patrol if they're close enough to fight
		if player and distance <= detect_range:
			is_patrolling = false
	elif player:
		var to_player = player.global_position - global_position
		direction = 1 if to_player.x > 0 else -1

		if is_resting:
			velocity.x = 0
		elif distance <= attack_range and attack_timer <= 0 and not is_attacking_now:
			start_attack()
		elif distance <= detect_range and not is_attacking_now:
			velocity.x = direction * chase_speed
			play_anim("idle")
		elif not is_attacking_now:
			velocity.x = 0
			play_anim("idle")

	if direction < 0 : flip = false
	if direction > 0 : flip = true
	if direction < 0:
		pivot_node.scale.x = abs(pivot_node.scale.x)
	elif direction > 0:
		pivot_node.scale.x = -abs(pivot_node.scale.x)

	move_and_slide()
	
func start_attack() -> void:
	is_attacking_now = true
	velocity.x = 0
	attack_timer = attack_cooldown
	attack_count += 1
	play_anim("Attack")

	# Small delay so the bolt fires mid-animation instead of on frame 0
	await get_tree().create_timer(attack_cooldown * 0.25).timeout
	fire_bolt()

	await get_tree().create_timer(attack_cooldown * 0.25).timeout
	is_attacking_now = false

	if attack_count >= attacks_before_rest:
		start_rest()

func fire_bolt() -> void:
	if bolt_scene == null or not alive:
		return
	var player = GameManager.player
	if player == null:
		return

	var bolt = bolt_scene.instantiate()
	get_tree().current_scene.add_child(bolt)
	bolt.global_position = pivot_node.global_position
	var target_point = player.global_position + Vector2(0, -40)  # aim toward chest
	var dir = (target_point - pivot_node.global_position)
	bolt.launch(dir)

func start_rest() -> void:
	is_resting = true
	attack_count = 0
	play_anim("tried")
	await get_tree().create_timer(rest_duration).timeout
	is_resting = false
	begin_patrol()

func begin_patrol() -> void:
	if patrol_point_a == NodePath("") or patrol_point_b == NodePath(""):
		play_anim("idle")
		return
	is_patrolling = true
	var point_a = get_node(patrol_point_a).global_position
	var point_b = get_node(patrol_point_b).global_position
	patrol_target = point_b if going_to_b else point_a
	going_to_b = !going_to_b

func play_anim(anim_name: String) -> void:
	if pivot_sprite.animation != anim_name:
		pivot_sprite.animation = anim_name
		pivot_sprite.play()

# --- Damage overrides: boss takes hits instead of dying in one ---
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
	var music_player = get_node_or_null("/root/level_02/MusicPlayer") # Adjust path to match your level
	if music_player:
		music_player.stop()

	$DeathParticles.emitting = true
	$DeathSfx.play()
	show_slain_text()
	await get_tree().create_timer(1.5).timeout
	queue_free()

func show_slain_text() -> void:
	var label := Label.new()
	label.text = "DIANA SLAIN"
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
