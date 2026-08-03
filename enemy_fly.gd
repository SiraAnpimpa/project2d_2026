extends Enemy

@export var hover_amplitude : float = 20.0
@export var hover_speed : float = 2.0
@export var detect_range : float = 250.0
@export var attack_range : float = 60.0
@export var chase_speed : float = 80.0

var hover_time : float = 0.0
var current_anim := ""

func _ready() -> void:
	super._ready()
	hover_time = randf() * TAU  # random phase so flies don't all bob in sync
	play_anim("idle")

func _physics_process(delta: float) -> void:
	if not alive:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var player = GameManager.player
	var distance = INF
	if player:
		distance = global_position.distance_to(player.global_position)

	if player and distance <= detect_range:
		var to_player = (player.global_position - global_position)
		direction = 1 if to_player.x > 0 else -1

		if distance <= attack_range:
			# Close enough — stop and attack
			velocity = Vector2.ZERO
			play_anim("attack")
		else:
			# Chase — fly toward the player, still bobbing a little
			var dir_normalized = to_player.normalized()
			hover_time += delta * hover_speed
			velocity.x = dir_normalized.x * chase_speed
			velocity.y = dir_normalized.y * chase_speed + sin(hover_time) * (hover_amplitude * 0.3)
			play_anim("idle")
	else:
		# No player nearby — normal patrol/hover
		if wall_ray.is_colliding():
			direction = -direction
		velocity.x = speed * direction
		hover_time += delta * hover_speed
		velocity.y = sin(hover_time) * hover_amplitude
		play_anim("idle")

	if direction < 0 : flip = false
	if direction > 0 : flip = true

	move_and_slide()

func play_anim(anim_name: String) -> void:
	if current_anim != anim_name:
		current_anim = anim_name
		$Sprite/AnimateSprite.animation = anim_name
		$Sprite/AnimateSprite.play()
