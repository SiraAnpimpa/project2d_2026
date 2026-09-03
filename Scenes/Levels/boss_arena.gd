extends ZoneMap

const FINAL_CORE_DROP: PackedScene = preload("res://Scenes/Prefabs/enemy_material_drop.tscn")

@onready var boss: HiveMatriarch = $HiveMatriarch


func _ready() -> void:
	super._ready()
	if GameManager.boss_defeated_state:
		boss.queue_free()
		if !GameManager.final_core_installed and GameManager.get_item_count(&"final_core") == 0:
			GameManager.set_objective("Recover the Final Launch Core", "BOSS ARENA // GUARANTEED DROP")
			call_deferred("_spawn_recovery_core")
		elif GameManager.get_item_count(&"final_core") > 0:
			GameManager.set_objective("Return to the ship", "FINAL LAUNCH CORE RECOVERED // LANDING ZONE")
	else:
		GameManager.mark_boss_arena_entered()
		boss.set_encounter_active(false)
		player.set_movement_enabled(false)
		call_deferred("_begin_boss_encounter")
	hud.set_objective(GameManager.current_objective, GameManager.current_objective_details)


func _begin_boss_encounter() -> void:
	hud.show_boss("HIVE MATRIARCH", boss.max_hp, boss.hp, boss.phase)
	await hud.show_boss_intro("HIVE MATRIARCH")
	if !is_instance_valid(boss) or GameManager.boss_defeated_state:
		return
	boss.set_encounter_active(true)
	player.set_movement_enabled(true)
	hud.show_echo("Energy source located. Major attacks are telegraphed—dodge, counterattack, and use cover.")


func _spawn_recovery_core() -> void:
	var drop := FINAL_CORE_DROP.instantiate() as EnemyMaterialDrop
	drop.configure(&"final_core", 1)
	add_child(drop)
	drop.global_position = Vector2.ZERO
