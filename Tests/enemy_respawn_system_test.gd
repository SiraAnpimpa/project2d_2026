extends Node

const CRAWLER := preload("res://Scenes/Actors/alien_crawler.tscn")
const EGG := preload("res://Scenes/Gameplay/alien_egg.tscn")
const HIVE_GROUP := preload("res://Scenes/Gameplay/hive_respawn_group.tscn")


func _ready() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	GameManager.reset_new_game_state()
	var test_player := Node2D.new()
	test_player.position = Vector2(900, 0)
	add_child(test_player)
	GameManager.player = test_player

	var manager := EnemyRespawnManager.new()
	manager.respawn_interval = 0.18
	manager.blocked_retry_interval = 0.06
	manager.safe_spawn_distance = 160.0
	manager.avoid_visible_camera = false
	manager.maximum_alive = 1
	var active_enemies := Node2D.new()
	active_enemies.name = "ActiveEnemies"
	manager.add_child(active_enemies)
	var first_slot := _make_slot("FirstSlot", Vector2.ZERO)
	manager.add_child(first_slot)
	var second_slot := _make_slot("SecondSlot", Vector2(420, 0))
	manager.add_child(second_slot)
	add_child(manager)
	await get_tree().process_frame
	await get_tree().process_frame

	if manager.slots.size() != 2 or manager.get_alive_count() != 1:
		_fail("Manager did not initialize spawn slots or respect maximum_alive")
		return
	var first_enemy := first_slot.active_enemy
	if !is_instance_valid(first_enemy) or first_enemy.hp != first_enemy.max_hp:
		_fail("Initial slot enemy did not spawn at full HP")
		return
	test_player.position = Vector2.ZERO
	# A 2x test multiplier makes the crawler's configured common 62% roll deterministic.
	first_enemy.material_drop_chance = 2.0
	first_enemy.take_damage(first_enemy.max_hp)
	await get_tree().process_frame
	if !first_slot.waiting_for_respawn:
		_fail("Enemy death did not empty and arm its spawn slot")
		return
	if get_tree().get_nodes_in_group("EnemyMaterialDrop").is_empty():
		_fail("Enemy defeat did not reroll and create a repeatable material drop")
		return
	await get_tree().create_timer(0.24).timeout
	if is_instance_valid(first_slot.active_enemy):
		_fail("Enemy respawned beside the player")
		return
	if manager.get_alive_count() > manager.maximum_alive:
		_fail("Area exceeded its maximum alive enemy count")
		return

	test_player.position = Vector2(900, 0)
	await get_tree().create_timer(0.16).timeout
	if manager.get_alive_count() != 1:
		_fail("A safe missing slot did not respawn after the retry interval")
		return
	var restored_enemy := first_slot.active_enemy if is_instance_valid(first_slot.active_enemy) else second_slot.active_enemy
	if !is_instance_valid(restored_enemy) or restored_enemy.hp != restored_enemy.max_hp:
		_fail("Respawned enemy did not return with full HP and reset state")
		return

	if !_check_area_configuration("res://Scenes/Levels/crystal_field.tscn", 60.0):
		return
	if !_check_area_configuration("res://Scenes/Levels/abandoned_signal_base.tscn", 60.0):
		return
	var hive := HIVE_GROUP.instantiate() as EnemyRespawnManager
	if hive == null or !is_equal_approx(hive.respawn_interval, 30.0) or hive.maximum_alive != 10:
		_fail("Hive reusable profile is not configured for 30 seconds and a bounded cap")
		return
	var egg := EGG.instantiate() as AlienEgg
	if egg == null or !is_equal_approx(egg.reactivation_time, 30.0):
		_fail("Alien egg does not use the requested 30-second reactivation default")
		return
	hive.free()
	egg.free()

	print("ENEMY_RESPAWN_SYSTEM_TEST: PASS")
	get_tree().quit()


func _make_slot(slot_name: String, slot_position: Vector2) -> EnemySpawnSlot:
	var slot := EnemySpawnSlot.new()
	slot.name = slot_name
	slot.position = slot_position
	slot.enemy_scene = CRAWLER
	return slot


func _check_area_configuration(scene_path: String, expected_interval: float) -> bool:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_fail("Could not load configured exploration area: " + scene_path)
		return false
	var level := packed.instantiate()
	var manager := level.get_node_or_null("EnemyRespawnManager") as EnemyRespawnManager
	if manager == null or !manager.respawn_enabled:
		level.free()
		_fail("Exploration area has no enabled respawn manager: " + scene_path)
		return false
	if !is_equal_approx(manager.respawn_interval, expected_interval):
		level.free()
		_fail("Exploration area respawn interval is incorrect: " + scene_path)
		return false
	if manager.maximum_alive < 1:
		level.free()
		_fail("Exploration area has no bounded maximum alive count: " + scene_path)
		return false
	level.free()
	return true


func _fail(message: String) -> void:
	push_error("ENEMY_RESPAWN_SYSTEM_TEST: " + message)
	get_tree().paused = false
	get_tree().quit(1)
