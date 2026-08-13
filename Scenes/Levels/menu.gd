extends Control

@onready var btn_start: Button = $UI/MenuPanel/Margin/MenuItems/btnStart
@onready var btn_continue: Button = $UI/MenuPanel/Margin/MenuItems/btnContinue
@onready var menu_buttons: Array[Button] = [
	$UI/MenuPanel/Margin/MenuItems/btnStart,
	$UI/MenuPanel/Margin/MenuItems/btnContinue,
	$UI/MenuPanel/Margin/MenuItems/btnOption,
	$UI/MenuPanel/Margin/MenuItems/btnCredit,
	$UI/MenuPanel/Margin/MenuItems/btnQuit,
]


func _ready() -> void:
	GameManager.load_option()
	btn_continue.disabled = !GameManager.has_gamesaved()
	for button in menu_buttons:
		button.mouse_entered.connect(_focus_menu_button.bind(button))
	btn_start.grab_focus()
	$UI.modulate.a = 0.0
	create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).tween_property($UI, "modulate:a", 1.0, 0.25)


func _focus_menu_button(button: Button) -> void:
	if !button.disabled:
		button.grab_focus()


func _on_btn_start_pressed() -> void:
	GameManager.restart()


func _on_btn_option_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Levels/options.tscn")


func _on_btn_credit_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Levels/credit.tscn")


func _on_btn_continue_pressed() -> void:
	GameManager.load_game()


func _on_btn_quit_pressed() -> void:
	get_tree().quit()
