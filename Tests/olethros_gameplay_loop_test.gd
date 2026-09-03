extends Node

const PLAYER := preload("res://Scenes/Actors/top_down_player.tscn")
const CRAWLER := preload("res://Scenes/Actors/alien_crawler.tscn")
const SPITTER := preload("res://Scenes/Actors/alien_spitter.tscn")
const CONSOLE := preload("res://Scenes/Gameplay/ship_repair_console.tscn")


func _ready() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	GameManager.reset_new_game_state()
	if GameManager.use_med_kit():
		_fail("Med Kit was usable with empty inventory")
		return
	GameManager.add_item(&"med_kit", 2)
	if GameManager.use_med_kit() or GameManager.get_item_count(&"med_kit") != 2:
		_fail("Med Kit was consumed at full HP")
		return
	GameManager.hp = 40
	if !GameManager.use_med_kit() or GameManager.hp != GameManager.max_hp or GameManager.get_item_count(&"med_kit") != 1:
		_fail("Med Kit did not fully restore HP and consume one item")
		return
	GameManager.hp = 90
	if !GameManager.use_med_kit() or GameManager.hp != 100 or GameManager.get_item_count(&"med_kit") != 0:
		_fail("Med Kit did not clamp healing at MaxHP")
		return

	var player := PLAYER.instantiate() as TopDownPlayer
	add_child(player)
	player.global_position = Vector2.ZERO
	var crawler := CRAWLER.instantiate() as AlienEnemy
	add_child(crawler)
	crawler.global_position = Vector2(180, 0)
	var spitter := SPITTER.instantiate() as AlienEnemy
	add_child(spitter)
	spitter.global_position = Vector2(280, 0)
	await get_tree().process_frame
	if crawler.hp != crawler.max_hp or spitter.hp != spitter.max_hp:
		_fail("Enemy HP was not initialized")
		return
	player.aim_direction = Vector2.UP
	player.fire_weapon()
	player.fire_weapon()
	await get_tree().process_frame
	if get_tree().get_nodes_in_group("PlayerProjectile").size() != 1:
		_fail("Pulse Rifle cooldown did not prevent duplicate same-frame shots")
		return
	await get_tree().create_timer(0.22).timeout
	player.fire_weapon()
	await get_tree().process_frame
	if get_tree().get_nodes_in_group("PlayerProjectile").size() < 2:
		_fail("Pulse Rifle did not fire again after its configured fire rate")
		return
	var near_interactable := Interactable.new()
	near_interactable.global_position = Vector2(35, 0)
	add_child(near_interactable)
	var far_interactable := Interactable.new()
	far_interactable.global_position = Vector2(70, 0)
	add_child(far_interactable)
	await get_tree().process_frame
	player._scan_interactables()
	if player.current_interactable != near_interactable:
		_fail("Interaction priority did not select the closest valid target")
		return
	near_interactable.queue_free()
	far_interactable.queue_free()
	crawler.take_damage(18, Vector2.RIGHT)
	await get_tree().create_timer(0.25).timeout
	if crawler.hp != crawler.max_hp - 18:
		_fail("Crawler did not receive projectile-equivalent damage")
		return
	spitter.take_damage(spitter.max_hp, Vector2.RIGHT)
	await get_tree().process_frame
	if spitter.state != AlienEnemy.State.DEAD:
		_fail("Spitter death did not disable its state machine")
		return

	GameManager.add_item(&"energy_crystal", 3)
	var console := CONSOLE.instantiate() as ShipRepairConsole
	add_child(console)
	await get_tree().process_frame
	console._start_minigame("power")
	if GameManager.get_item_count(&"energy_crystal") != 3:
		_fail("Starting a repair mini-game consumed resources")
		return
	console._cancel_minigame()
	if GameManager.get_item_count(&"energy_crystal") != 3:
		_fail("Cancelling a repair mini-game consumed resources")
		return
	console._start_minigame("power")
	console.circuit_states = [1, 1, 1, 1]
	console._commit_success()
	if !GameManager.is_ship_system_repaired(&"power") or GameManager.get_item_count(&"energy_crystal") != 0:
		_fail("Successful Power repair did not commit the resource transaction")
		return
	if GameManager.repair_ship_system(&"power", &"energy_crystal", 3):
		_fail("A repaired system was repaired twice")
		return
	console._close()
	await get_tree().process_frame
	var terminal := UnknownAITerminal.new()
	add_child(terminal)
	await get_tree().process_frame
	terminal.interact(player)
	await get_tree().process_frame
	var dialogue := get_tree().get_first_node_in_group("DialogueUI")
	if !GameManager.unknown_ai_contacted or dialogue == null:
		_fail("UNKNOWN AI terminal did not open shared dialogue state")
		return
	dialogue._close()
	await get_tree().process_frame
	GameManager.add_item(&"access_card", 1)

	GameManager.add_item(&"circuit_part", 2)
	GameManager.add_item(&"scrap_metal", 5)
	console = CONSOLE.instantiate() as ShipRepairConsole
	add_child(console)
	await get_tree().process_frame
	console._start_minigame("navigation")
	if GameManager.get_item_count(&"circuit_part") != 2 or console.nav_slider == null:
		_fail("Navigation mini-game did not open without consuming resources")
		return
	console.nav_slider.value = 67
	console._check_navigation()
	if !GameManager.is_ship_system_repaired(&"navigation") or GameManager.get_item_count(&"circuit_part") != 0:
		_fail("Navigation calibration did not commit the correct transaction")
		return
	console._start_minigame("engine")
	if GameManager.get_item_count(&"scrap_metal") != 5:
		_fail("Engine mini-game consumed resources before success")
		return
	for step in ["VALVE A", "VALVE C", "VALVE B", "IGNITION"]:
		console._engine_input(step)
	if !GameManager.is_ship_system_repaired(&"engine") or GameManager.get_item_count(&"scrap_metal") != 0:
		_fail("Engine startup sequence did not commit the correct transaction")
		return
	console._close()
	await get_tree().process_frame
	if !GameManager.are_all_systems_repaired() or !GameManager.can_enter_hive():
		_fail("Repairing all systems after UNKNOWN AI contact did not unlock the Hive route")
		return
	if GameManager.can_launch():
		_fail("Primary repairs incorrectly bypassed the Hive, boss, and final-core progression")
		return

	print("OLETHROS_GAMEPLAY_LOOP_TEST: PASS")
	get_tree().paused = false
	get_tree().quit()


func _fail(message: String) -> void:
	push_error("OLETHROS_GAMEPLAY_LOOP_TEST: " + message)
	get_tree().paused = false
	get_tree().quit(1)
