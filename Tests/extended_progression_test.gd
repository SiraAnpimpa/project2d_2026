extends Node

const PLAYER := preload("res://Scenes/Actors/top_down_player.tscn")
const CRAWLER := preload("res://Scenes/Actors/alien_crawler.tscn")
const SPITTER := preload("res://Scenes/Actors/alien_spitter.tscn")
const STALKER := preload("res://Scenes/Actors/stalker.tscn")
const BOSS := preload("res://Scenes/Actors/hive_matriarch.tscn")
const CONSOLE := preload("res://Scenes/Gameplay/ship_repair_console.tscn")


func _ready() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	GameManager.reset_new_game_state()
	if !_check_drop_configuration():
		return
	if !await _check_weapon_upgrades():
		return
	if !await _check_world_and_boss_progression():
		return
	print("EXTENDED_PROGRESSION_TEST: PASS")
	get_tree().paused = false
	get_tree().quit()


func _check_drop_configuration() -> bool:
	var crawler := CRAWLER.instantiate() as AlienEnemy
	var spitter := SPITTER.instantiate() as AlienEnemy
	var stalker := STALKER.instantiate() as Stalker
	if crawler.drop_table == null or spitter.drop_table == null or stalker.drop_table == null:
		return _fail("An enemy is missing a configurable drop table")
	for enemy in [crawler, spitter, stalker]:
		for item_id in enemy.drop_table.item_ids:
			if item_id in [&"scrap_metal", &"energy_crystal", &"circuit_part"]:
				return _fail("Enemy drop table contains a primary repair resource")
	if !crawler.drop_table.item_ids.has(&"alien_biomass") or !spitter.drop_table.item_ids.has(&"acid_gland"):
		return _fail("Crawler or Spitter tendencies are not configured")
	if !stalker.drop_table.item_ids.has(&"alien_core"):
		return _fail("Stalker cannot provide rare Alien Cores")
	var med_kit_index := stalker.drop_table.item_ids.find(&"med_kit")
	if med_kit_index < 0 or stalker.drop_table.drop_chances[med_kit_index] < 0.15 or stalker.drop_table.drop_chances[med_kit_index] > 0.30:
		return _fail("Stalker Med Kit chance is not configured in the intended valuable range")
	var crawler_core := crawler.drop_table.item_ids.find(&"alien_core")
	var stalker_core := stalker.drop_table.item_ids.find(&"alien_core")
	if crawler_core < 0 or stalker_core < 0 or stalker.drop_table.drop_chances[stalker_core] <= crawler.drop_table.drop_chances[crawler_core]:
		return _fail("Stalker rare-drop chance is not better than the Crawler chance")
	crawler.free()
	spitter.free()
	stalker.free()
	return true


func _check_weapon_upgrades() -> bool:
	var player := PLAYER.instantiate() as TopDownPlayer
	add_child(player)
	await get_tree().process_frame
	for item_id in [&"alien_biomass", &"hardened_carapace", &"acid_gland", &"alien_core"]:
		GameManager.add_item(item_id, 20)
	var biomass_before := GameManager.get_item_count(&"alien_biomass")
	if !GameManager.purchase_weapon_upgrade(&"damage"):
		return _fail("Damage Level 2 purchase failed with sufficient materials")
	if GameManager.get_weapon_upgrade_level(&"damage") != 2 or GameManager.get_item_count(&"alien_biomass") != biomass_before - 3:
		return _fail("Damage upgrade did not consume its real inventory cost")
	if player.weapon_damage != 25:
		return _fail("Damage upgrade did not update the active Pulse Rifle")
	if !GameManager.purchase_weapon_upgrade(&"damage") or GameManager.get_weapon_upgrade_level(&"damage") != 3:
		return _fail("Damage Level 3 could not be purchased")
	if GameManager.purchase_weapon_upgrade(&"damage"):
		return _fail("Max-level damage upgrade was purchased twice")
	var base_rate := player.fire_rate
	if !GameManager.purchase_weapon_upgrade(&"fire_rate") or player.fire_rate <= base_rate:
		return _fail("Fire-rate upgrade did not shorten the real weapon cooldown")
	var base_speed := player.projectile_speed
	if !GameManager.purchase_weapon_upgrade(&"energy") or player.projectile_speed <= base_speed or player.projectile_power_scale <= 1.0:
		return _fail("Energy upgrade did not affect projectile speed and power scale")
	var console := CONSOLE.instantiate() as ShipRepairConsole
	add_child(console)
	await get_tree().process_frame
	console._show_section("weapon")
	if console.upgrade_rows.size() != 3:
		return _fail("Ship console did not build all three upgrade categories")
	console._show_section("repair")
	if console.system_rows.size() != 3 or console.final_core_row.is_empty() or console.overall_bar == null:
		return _fail("Ship status UI is missing its four-system restoration hierarchy")
	console._close()
	await get_tree().process_frame
	var live_crawler := CRAWLER.instantiate() as AlienEnemy
	live_crawler.material_drop_chance = 2.0
	add_child(live_crawler)
	live_crawler.global_position = Vector2(320, 0)
	var biomass_before_drop := GameManager.get_item_count(&"alien_biomass")
	live_crawler.take_damage(live_crawler.max_hp)
	await get_tree().process_frame
	var biomass_drop: EnemyMaterialDrop = null
	for node in get_tree().get_nodes_in_group("EnemyMaterialDrop"):
		if node is EnemyMaterialDrop and node.item_id == &"alien_biomass":
			biomass_drop = node
			break
	if biomass_drop == null:
		return _fail("Configured Crawler drop table did not create its guaranteed test drop")
	biomass_drop._on_body_entered(player)
	await get_tree().create_timer(0.2).timeout
	if GameManager.get_item_count(&"alien_biomass") != biomass_before_drop + 1:
		return _fail("Collected enemy material did not enter inventory immediately")
	player.fire_cooldown = 0.0
	player.fire_weapon()
	await get_tree().process_frame
	var fired := get_tree().get_nodes_in_group("PlayerProjectile")
	if fired.is_empty() or fired.back().damage != player.weapon_damage or fired.back().speed != player.projectile_speed:
		return _fail("Pulse Rifle projectile did not use upgraded live stats")
	return true


func _check_world_and_boss_progression() -> bool:
	if GameManager.can_enter_hive() or GameManager.can_launch():
		return _fail("Late-game route was open at the start")
	GameManager.contact_unknown_ai()
	if GameManager.can_enter_hive():
		return _fail("Hive access bypassed the required Access Card")
	GameManager.add_item(&"access_card", 1)
	GameManager.add_item(&"energy_crystal", 3)
	GameManager.add_item(&"circuit_part", 2)
	GameManager.add_item(&"scrap_metal", 5)
	GameManager.repair_ship_system(&"power", &"energy_crystal", 3)
	GameManager.repair_ship_system(&"navigation", &"circuit_part", 2)
	GameManager.repair_ship_system(&"engine", &"scrap_metal", 5)
	if !GameManager.can_enter_hive() or GameManager.can_launch():
		return _fail("Primary repairs did not unlock only the Hive stage")
	GameManager.mark_hive_entered()
	if !GameManager.can_enter_boss_arena():
		return _fail("Entering the Hive did not unlock the Boss Arena")
	var hive_scene := load("res://Scenes/Levels/alien_hive.tscn") as PackedScene
	var hive := hive_scene.instantiate()
	var manager := hive.get_node("EnemyRespawnManager") as EnemyRespawnManager
	if manager == null or !is_equal_approx(manager.respawn_interval, 30.0) or manager.maximum_alive != 10:
		hive.free()
		return _fail("Hive respawn pressure is not configured to 30 seconds with a cap")
	if hive.find_children("*", "AlienEgg", true, false).size() < 3:
		hive.free()
		return _fail("Hive egg encounter sources are missing")
	var hive_exit := hive.get_node("ToSignalBase") as Node2D
	if hive_exit.position.y > -300.0 or hive_exit.position.x < -200.0:
		hive.free()
		return _fail("Hive return exit was not moved to the top route")
	if !hive.has_node("FinishedFloorInset") or !hive.has_node("EnvironmentProps/ReturnCorridor"):
		hive.free()
		return _fail("Hive environment completion pass is missing")
	hive.free()
	var arena_scene := load("res://Scenes/Levels/boss_arena.tscn") as PackedScene
	var arena := arena_scene.instantiate()
	if !arena.find_children("*", "EnemyRespawnManager", true, false).is_empty():
		arena.free()
		return _fail("Boss Arena incorrectly contains an exploration respawn manager")
	if !arena.has_node("ArenaFloor") or !arena.has_node("ArenaNorthRim") or arena.map_bounds.size.x >= 1672.0:
		arena.free()
		return _fail("Boss Arena floor coverage or camera-safe bounds are incomplete")
	arena.free()
	GameManager.mark_boss_arena_entered()
	var boss := BOSS.instantiate() as HiveMatriarch
	add_child(boss)
	boss.set_physics_process(false)
	if boss.max_hp <= 1800 or boss.get_attack_catalog().size() != 7:
		return _fail("Boss is not configured as a strong seven-pattern final encounter")
	boss.phase = 3
	var selected_attack := boss._select_attack(200.0)
	boss.last_attack = selected_attack
	if boss._select_attack(200.0) == selected_attack:
		return _fail("Boss attack selector repeated the same major pattern")
	boss.phase = 1
	GameManager.hp = GameManager.max_hp
	var boss_player := GameManager.player as Node2D
	boss_player.global_position = boss.global_position
	if !boss_player.start_dodge():
		return _fail("Player dodge could not start")
	boss._perform_melee()
	if GameManager.hp != GameManager.max_hp:
		return _fail("Dodge invulnerability did not protect the player")
	boss_player.dodging = false
	boss._perform_melee()
	if GameManager.hp >= GameManager.max_hp:
		return _fail("Boss melee attack could not damage the player")
	boss.take_damage(900)
	if boss.phase != 2:
		return _fail("Boss did not enter Phase 2")
	boss.take_damage(950)
	if boss.phase != 3:
		return _fail("Boss did not enter Phase 3")
	boss.take_damage(1000)
	if !GameManager.boss_defeated_state:
		return _fail("Boss death did not persist immediately")
	await get_tree().create_timer(1.0).timeout
	var drops := get_tree().get_nodes_in_group("EnemyMaterialDrop")
	var final_drop: EnemyMaterialDrop = null
	for node in drops:
		if node is EnemyMaterialDrop and node.item_id == &"final_core":
			final_drop = node
			break
	if final_drop == null:
		return _fail("Boss did not guarantee the Final Launch Core drop")
	var player := GameManager.player as Node2D
	final_drop._on_body_entered(player)
	await get_tree().create_timer(0.2).timeout
	if GameManager.get_item_count(&"final_core") != 1 or GameManager.can_launch():
		return _fail("Final Core collection state is incorrect or launch bypassed installation")
	if !GameManager.install_final_core() or !GameManager.can_launch():
		return _fail("Final Core installation did not unlock launch")
	if !GameManager.save_game():
		return _fail("Extended permanent progression could not be saved")
	var file := FileAccess.open(GameManager.save_path, FileAccess.READ)
	var saved = JSON.parse_string(file.get_pascal_string()) if file != null else null
	if file != null:
		file.close()
	if typeof(saved) != TYPE_DICTIONARY or !bool(saved.get("boss_defeated_state", false)) or !bool(saved.get("final_core_installed", false)):
		return _fail("Boss/final-core persistence is missing from the save payload")
	var saved_upgrades = saved.get("weapon_upgrade_levels", {})
	if typeof(saved_upgrades) != TYPE_DICTIONARY or int(saved_upgrades.get("damage", 1)) != 3:
		return _fail("Weapon upgrades are missing from the save payload")
	return true


func _fail(message: String) -> bool:
	push_error("EXTENDED_PROGRESSION_TEST: " + message)
	get_tree().paused = false
	get_tree().quit(1)
	return false
