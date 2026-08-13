extends Control

@onready var music_toggle: CheckButton = %MusicToggle
@onready var sfx_toggle: CheckButton = %SfxToggle
@onready var fullscreen_toggle: CheckButton = %FullscreenToggle
@onready var back_button: Button = %BackButton

var syncing_controls := false


func _ready() -> void:
	GameManager.load_option()
	syncing_controls = true
	music_toggle.button_pressed = GameManager.music_on
	sfx_toggle.button_pressed = GameManager.sfx_on
	fullscreen_toggle.button_pressed = GameManager.fullscreen_on
	syncing_controls = false
	music_toggle.grab_focus()
	modulate.a = 0.0
	create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).tween_property(self, "modulate:a", 1.0, 0.22)


func _on_music_toggled(enabled: bool) -> void:
	if syncing_controls:
		return
	GameManager.music_on = enabled
	GameManager.update_option()
	GameManager.save_option()


func _on_sfx_toggled(enabled: bool) -> void:
	if syncing_controls:
		return
	GameManager.sfx_on = enabled
	GameManager.update_option()
	GameManager.save_option()


func _on_fullscreen_toggled(enabled: bool) -> void:
	if syncing_controls:
		return
	GameManager.set_fullscreen(enabled)
	GameManager.save_option()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Levels/menu.tscn")
