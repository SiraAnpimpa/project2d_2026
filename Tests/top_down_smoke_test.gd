extends Node


func _ready() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	GameManager.salvage = 0
	GameManager.hp = GameManager.max_hp
	GameManager.dropped_salvage.clear()
	GameManager.next_drop_id = 1
	GameManager.death_in_progress = false
	var level_scene: PackedScene = load("res://Scenes/Levels/zone_67_prologue.tscn")
	var level = level_scene.instantiate()
	add_child(level)
	await get_tree().process_frame

	var player: TopDownPlayer = level.get_node("Player")
	var sprite: Sprite2D = player.get_node("Astronaut")
	level._finish_intro(false)

	var right_start := player.global_position
	Input.action_press("Right")
	for frame in range(8):
		await get_tree().physics_frame
	Input.action_release("Right")
	player.set_movement_enabled(false)
	if player.global_position.x <= right_start.x + 5.0 or sprite.frame / 4 != 2:
		_fail("Right movement or east-facing animation failed")
		return

	player.set_movement_enabled(true)
	var up_start := player.global_position
	Input.action_press("Up")
	for frame in range(8):
		await get_tree().physics_frame
	Input.action_release("Up")
	player.set_movement_enabled(false)
	if player.global_position.y >= up_start.y - 5.0 or sprite.frame / 4 != 3:
		_fail("Up movement or north-facing animation failed")
		return

	var locked_position := player.global_position
	Input.action_press("Down")
	for frame in range(4):
		await get_tree().physics_frame
	Input.action_release("Down")
	if player.global_position.distance_to(locked_position) > 0.01:
		_fail("Movement lock failed")
		return

	player.set_movement_enabled(true)
	GameManager.add_salvage(7)
	var death_position := player.global_position
	var expected_spawn := player.spawn_point
	await GameManager.death()
	await get_tree().process_frame
	if GameManager.salvage != 0:
		_fail("Held salvage was not removed on death")
		return
	if GameManager.hp != GameManager.max_hp:
		_fail("Health was not restored after emergency return")
		return
	if player.global_position.distance_to(expected_spawn) > 0.01:
		_fail("Player did not return to the level start point")
		return

	var drops := get_tree().get_nodes_in_group("SalvageDrop")
	if drops.size() != 1:
		_fail("Death did not create exactly one salvage drop")
		return
	var drop = drops[0]
	if int(drop.amount) != 7 or drop.global_position.distance_to(death_position) > 0.01:
		_fail("Salvage drop amount or position is incorrect")
		return
	GameManager.sfx_on = false
	await drop._on_body_entered(player)
	GameManager.sfx_on = true
	if GameManager.salvage != 7 or !GameManager.dropped_salvage.is_empty():
		_fail("Dropped salvage could not be recovered")
		return

	level.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	print("TOP_DOWN_SMOKE_TEST: PASS")
	get_tree().quit()


func _fail(message: String) -> void:
	push_error("TOP_DOWN_SMOKE_TEST: " + message)
	get_tree().quit(1)
