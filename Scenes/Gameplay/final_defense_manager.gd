class_name FinalDefenseManager
extends Node2D

const CRAWLER := preload("res://Scenes/Actors/alien_crawler.tscn")
const SPITTER := preload("res://Scenes/Actors/alien_spitter.tscn")
const DEFENSE_DURATION := 50.0
const SPAWN_POINTS: Array[Vector2] = [
	Vector2(-620, -260), Vector2(570, -285), Vector2(610, 255), Vector2(-570, 270),
]

var elapsed := 0.0
var wave_clock := 0.0
var running := false
var wave_index := 0


func _ready() -> void:
	GameManager.final_defense_started.connect(start_defense)
	if GameManager.final_defense_active and !GameManager.final_defense_done:
		call_deferred("start_defense")


func start_defense() -> void:
	if running or GameManager.final_defense_done:
		return
	running = true
	elapsed = 0.0
	wave_clock = 0.0
	wave_index = 0
	var hud := get_tree().get_first_node_in_group("GameHUD")
	if hud != null:
		hud.show_echo("All primary systems operational. Warning: multiple hostile lifeforms approaching.")
		hud.alert("FINAL DEFENSE // PROTECT THE SHIP")
	_spawn_wave()


func _process(delta: float) -> void:
	if !running or get_tree().paused:
		return
	elapsed += delta
	wave_clock += delta
	var progress := clampf(elapsed / DEFENSE_DURATION, 0.0, 1.0)
	var hud := get_tree().get_first_node_in_group("GameHUD")
	if hud != null and hud.has_method("set_defense_progress"):
		hud.set_defense_progress(progress, DEFENSE_DURATION - elapsed)
	if wave_clock >= 7.5:
		wave_clock = 0.0
		_spawn_wave()
	if elapsed >= DEFENSE_DURATION:
		running = false
		GameManager.complete_final_defense()
		if hud != null:
			hud.set_defense_progress(1.0, 0.0)
			hud.show_echo("Launch preparation complete. Board the ship immediately.")
			hud.alert("LAUNCH READY // E - BOARD SHIP")


func _spawn_wave() -> void:
	if get_tree().get_nodes_in_group("Enemy").size() >= 9:
		return
	wave_index += 1
	var amount := mini(2 + wave_index / 2, 4)
	for index in range(amount):
		var packed: PackedScene = SPITTER if (wave_index + index) % 3 == 0 else CRAWLER
		var enemy := packed.instantiate() as AlienEnemy
		get_parent().add_child(enemy)
		enemy.global_position = SPAWN_POINTS[(wave_index + index) % SPAWN_POINTS.size()] + Vector2(index * 24, index * 17)
