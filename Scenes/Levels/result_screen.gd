extends Control

@onready var play_button: Button = %PlayButton
@onready var score_summary: Label = %ScoreSummary


func _ready() -> void:
	score_summary.text = "SALVAGE RECOVERED  //  %04d" % GameManager.salvage
	play_button.grab_focus()
	modulate.a = 0.0
	create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).tween_property(self, "modulate:a", 1.0, 0.24)


func _on_play_pressed() -> void:
	GameManager.restart()


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Levels/menu.tscn")
