extends Node2D

@export var boss_music : AudioStream
@onready var music_player : AudioStreamPlayer = $UserInterface/MusicPlayer
@export var next_scene : PackedScene
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GameManager.player = %Player
	$MusicPlayer.play(0)
	var tween = create_tween()
	$UserInterface/Label.scale = Vector2.ZERO
	tween.stop(); tween.play()
	tween.tween_property($UserInterface/Label, "scale", Vector2.ONE, 1)
	await get_tree().create_timer(3).timeout
	$UserInterface/Label.queue_free()


func _on_player_hit_enemy() -> void:
	GameManager.damage(5)	

func _on_player_hit_trap() -> void:
	GameManager.death()


func _on_music_player_finished() -> void:
	$MusicPlayer.play(0)


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player") && next_scene != null:
		AudioManager.level_complete_sfx.play()
		SceneTransition.load_scene(next_scene)


func _on_bossroom_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		if boss_music and $MusicPlayer.stream != boss_music:
			$MusicPlayer.stream = boss_music
			$MusicPlayer.play()
