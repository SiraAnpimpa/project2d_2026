class_name ZoneMap
extends Node2D

@export var objective_title := "สำรวจพื้นที่"
@export var objective_details := "ZONE-67 // EXPLORATION"
@export var arrival_message := ""
@export var map_bounds := Rect2(-1672, -941, 3344, 1882)

@onready var player: TopDownPlayer = %Player
@onready var hud = $UserInterface


func _ready() -> void:
	GameManager.current_level = scene_file_path
	GameManager.player = player
	var default_spawn := player.global_position
	var loaded_from_save := GameManager.loading_save
	if loaded_from_save:
		player.global_position = GameManager.save_player_position
		GameManager.save_player_position = Vector2.ZERO

	if !GameManager.pending_spawn.is_empty():
		var marker := get_node_or_null("SpawnPoints/" + String(GameManager.pending_spawn)) as Marker2D
		if marker != null:
			player.global_position = marker.global_position
			default_spawn = marker.global_position

	player.set_respawn_position(default_spawn)
	player.set_camera_limits(map_bounds)
	GameManager.pending_spawn = &""
	GameManager.loading_save = false
	GameManager.spawn_saved_drops_for_current_level()
	hud.set_objective(GameManager.current_objective, GameManager.current_objective_details)
	if !arrival_message.is_empty():
		hud.call_deferred("alert", arrival_message)
