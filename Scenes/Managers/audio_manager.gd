# This script is an autoload, that can be accessed from any other script!

extends Node

@onready var jump_sfx = $JumpSfx
@onready var coin_pickup_sfx = $CoinPickup
@onready var death_sfx = $DeathSfx
@onready var respawn_sfx = $RespawnSfx
@onready var level_complete_sfx = $LevelCompleteSfx
@onready var background_music: AudioStreamPlayer = $BackgroundMusic
@onready var enemy_encounter_sfx: AudioStreamPlayer = $EnemyEncounterSfx
@onready var enemy_death_sfx: AudioStreamPlayer = $EnemyDeathSfx
@onready var ship_flyby_sfx: AudioStreamPlayer = $ShipFlybySfx
@onready var radio_transmission_sfx: AudioStreamPlayer = $RadioTransmissionSfx

var encounter_cooldown_until_msec := 0


func _ready() -> void:
	background_music.finished.connect(_restart_background_music)
	background_music.play()


func play_enemy_encounter() -> void:
	var now := Time.get_ticks_msec()
	if enemy_encounter_sfx.playing or now < encounter_cooldown_until_msec:
		return
	enemy_encounter_sfx.play()
	encounter_cooldown_until_msec = now + 30000


func play_enemy_death() -> void:
	enemy_death_sfx.play()


func play_ship_flyby() -> void:
	ship_flyby_sfx.play()


func play_radio_transmission() -> void:
	if !radio_transmission_sfx.playing:
		radio_transmission_sfx.play()


func stop_radio_transmission() -> void:
	radio_transmission_sfx.stop()


func _restart_background_music() -> void:
	background_music.play()
