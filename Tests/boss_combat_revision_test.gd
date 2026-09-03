extends Node2D

const PLAYER := preload("res://Scenes/Actors/top_down_player.tscn")
const HUD := preload("res://Scenes/Levels/game_ui.tscn")
const BOSS := preload("res://Scenes/Actors/hive_matriarch.tscn")
const STALKER := preload("res://Scenes/Actors/stalker.tscn")


func _ready() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	GameManager.reset_new_game_state()
	var player := PLAYER.instantiate() as TopDownPlayer
	add_child(player)
	player.set_physics_process(false)
	player.dodging = true
	var hud = HUD.instantiate()
	add_child(hud)
	var boss := BOSS.instantiate() as HiveMatriarch
	add_child(boss)
	boss.set_physics_process(false)
	await get_tree().process_frame

	var stalker := STALKER.instantiate() as Stalker
	if boss.max_hp < stalker.max_hp * 10 or boss.melee_damage <= stalker.attack_damage:
		stalker.free()
		return _fail("Boss stats are not substantially stronger than the Hive elite")
	stalker.free()
	if boss.get_attack_catalog().size() != 7:
		return _fail("Boss does not expose seven meaningful attack patterns")

	boss.phase = 3
	for index in range(30):
		var next_attack := boss._select_attack(190.0 + float(index % 3) * 80.0)
		if next_attack == boss.last_attack:
			return _fail("Boss repeated a major attack despite available alternatives")
		boss.last_attack = next_attack

	boss.phase = 1
	player.global_position = Vector2(700, 0)
	boss.global_position = Vector2.ZERO
	boss._perform_projectile_spread()
	await get_tree().process_frame
	if get_tree().get_nodes_in_group("EnemyProjectile").size() != 3:
		return _fail("Phase 1 projectile pattern is not the readable three-shot spread")
	_clear_group("EnemyProjectile")
	boss.phase = 3
	boss._perform_projectile_spread()
	await get_tree().process_frame
	if get_tree().get_nodes_in_group("EnemyProjectile").size() != 7:
		return _fail("Phase 3 projectile pressure did not escalate")
	_clear_group("EnemyProjectile")

	boss._perform_summon()
	await get_tree().process_frame
	if get_tree().get_nodes_in_group("BossSummon").size() < 2:
		return _fail("Boss summon pattern did not create combat pressure")
	_clear_group("BossSummon")

	player.global_position = Vector2(120, 0)
	boss.global_position = Vector2.ZERO
	await boss._perform_leap()
	if boss.global_position.distance_to(player.global_position) > 180.0:
		return _fail("Boss leap did not land near the predicted player position")
	await boss._perform_acid_field()
	await get_tree().process_frame
	if get_tree().get_nodes_in_group("EnvironmentalHazard").size() < 3:
		return _fail("Boss acid-area pattern did not create persistent hazards")
	_clear_group("EnvironmentalHazard")
	await boss._perform_rage_sweep()
	await get_tree().process_frame
	if get_tree().get_nodes_in_group("EnemyProjectile").size() != 12:
		return _fail("Phase 3 rage sweep did not create its radial follow-up")
	_clear_group("EnemyProjectile")

	boss.global_position = Vector2(-300, 0)
	player.global_position = Vector2(300, 0)
	boss._begin_charge()
	for index in range(50):
		boss._process_charge(0.02)
		if !boss.charging:
			break
	if boss.charging or boss.cooldown <= 0.0 or boss.state != HiveMatriarch.State.RECOVER:
		return _fail("Charge did not end in a fair recovery window")

	boss.state = HiveMatriarch.State.HUNT
	boss.hp = boss.max_hp
	boss.phase = 1
	boss.take_damage(900)
	if boss.phase != 2:
		return _fail("Boss Phase 2 did not begin at 70 percent HP")
	boss.take_damage(950)
	if boss.phase != 3:
		return _fail("Boss Phase 3 did not begin at 35 percent HP")
	hud.show_boss("HIVE MATRIARCH", boss.max_hp, boss.hp, boss.phase)
	hud.set_boss_health(boss.hp, boss.max_hp, boss.phase)
	if !hud.boss_panel.visible or hud.boss_bar.value != boss.hp or "PHASE 3" not in hud.boss_phase_label.text:
		return _fail("Dedicated top-screen boss health display did not update")

	print("BOSS_COMBAT_REVISION_TEST: PASS")
	get_tree().quit()


func _clear_group(group_name: StringName) -> void:
	for node in get_tree().get_nodes_in_group(group_name):
		if is_instance_valid(node):
			node.queue_free()


func _fail(message: String) -> void:
	push_error("BOSS_COMBAT_REVISION_TEST: " + message)
	get_tree().paused = false
	get_tree().quit(1)
