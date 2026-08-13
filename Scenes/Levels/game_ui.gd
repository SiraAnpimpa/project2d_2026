extends CanvasLayer

const MAIN_MENU_SCENE := "res://Scenes/Levels/menu.tscn"

@onready var salvage_label: Label = %SalvageLabel
@onready var hp_bar: ProgressBar = %ProgressBar
@onready var hp_value: Label = %HPValue
@onready var alert_panel: PanelContainer = %AlertPanel
@onready var alert_label: Label = %AlertLabel
@onready var objective_label: Label = %ObjectiveLabel
@onready var objective_meta_label: Label = %ObjectiveMetaLabel
@onready var settings_overlay: Control = %SettingsOverlay
@onready var settings_button: Button = %SettingsButton
@onready var close_settings_button: Button = %CloseSettingsButton
@onready var music_toggle: CheckButton = %MusicToggle
@onready var sfx_toggle: CheckButton = %SfxToggle
@onready var fullscreen_toggle: CheckButton = %FullscreenToggle
@onready var save_status: Label = %SaveStatus
@onready var inventory_counts: Dictionary = {
	&"scrap_metal": %ScrapCount,
	&"energy_crystal": %EnergyCount,
	&"circuit_part": %CircuitCount,
	&"med_kit": %MedKitCount,
	&"access_card": %AccessCount,
	&"data_log": %DataLogCount,
}

var settings_open := false
var syncing_settings := false
var last_dropped_amount := 0
var alert_sequence := 0
var settings_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.salvage_dropped.connect(_on_salvage_dropped)
	GameManager.player_respawned.connect(_on_player_respawned)
	_sync_settings_controls()
	_refresh_status()


func _exit_tree() -> void:
	_release_gameplay_actions()
	if settings_open:
		get_tree().paused = false


func _process(_delta: float) -> void:
	_refresh_status()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and !event.is_echo():
		set_settings_open(!settings_open)
		get_viewport().set_input_as_handled()


func _refresh_status() -> void:
	salvage_label.text = "SALVAGE // %04d" % GameManager.salvage
	hp_bar.value = GameManager.hp
	hp_value.text = "%03d%%" % GameManager.hp
	for item_id in inventory_counts:
		var count_label: Label = inventory_counts[item_id]
		count_label.text = "%02d" % GameManager.get_item_count(item_id)


func alert(message: String) -> void:
	alert_sequence += 1
	var sequence_id := alert_sequence
	alert_label.text = message
	alert_panel.visible = true
	alert_panel.modulate.a = 0.0
	var intro := create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	intro.tween_property(alert_panel, "modulate:a", 1.0, 0.16)
	await intro.finished
	await get_tree().create_timer(1.65, true).timeout
	if sequence_id != alert_sequence:
		return
	var outro := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	outro.tween_property(alert_panel, "modulate:a", 0.0, 0.15)
	await outro.finished
	if sequence_id == alert_sequence:
		alert_panel.visible = false


func set_objective(objective: String, details: String = "") -> void:
	objective_label.text = objective
	objective_meta_label.text = details
	objective_meta_label.visible = !details.is_empty()


func set_settings_open(enabled: bool) -> void:
	if settings_open == enabled:
		return
	settings_open = enabled
	_release_gameplay_actions()
	if settings_tween != null and settings_tween.is_valid():
		settings_tween.kill()
	settings_tween = null
	if enabled:
		_sync_settings_controls()
		save_status.text = "การตั้งค่าจะบันทึกอัตโนมัติ"
		settings_overlay.visible = true
		settings_overlay.modulate.a = 0.0
		get_tree().paused = true
		settings_tween = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		settings_tween.tween_property(settings_overlay, "modulate:a", 1.0, 0.18)
		close_settings_button.grab_focus()
	else:
		get_tree().paused = false
		settings_overlay.visible = false
		settings_button.grab_focus()


func _sync_settings_controls() -> void:
	syncing_settings = true
	music_toggle.button_pressed = GameManager.music_on
	sfx_toggle.button_pressed = GameManager.sfx_on
	fullscreen_toggle.button_pressed = GameManager.fullscreen_on
	syncing_settings = false


func _release_gameplay_actions() -> void:
	for action in ["Left", "Right", "Up", "Down", "Interact"]:
		Input.action_release(action)


func _press_action(action: StringName) -> void:
	if !settings_open:
		Input.action_press(action)


func _release_action(action: StringName) -> void:
	Input.action_release(action)


func _on_settings_button_pressed() -> void:
	set_settings_open(true)


func _on_close_settings_pressed() -> void:
	set_settings_open(false)


func _on_music_toggled(enabled: bool) -> void:
	if syncing_settings:
		return
	GameManager.music_on = enabled
	GameManager.update_option()
	GameManager.save_option()


func _on_sfx_toggled(enabled: bool) -> void:
	if syncing_settings:
		return
	GameManager.sfx_on = enabled
	GameManager.update_option()
	GameManager.save_option()


func _on_fullscreen_toggled(enabled: bool) -> void:
	if syncing_settings:
		return
	GameManager.set_fullscreen(enabled)
	GameManager.save_option()


func _on_save_pressed() -> void:
	if GameManager.save_game():
		save_status.text = "บันทึกภารกิจแล้ว // SAVE COMPLETE"
	else:
		save_status.text = "ไม่สามารถบันทึกได้ // SAVE FAILED"


func _on_main_menu_pressed() -> void:
	_release_gameplay_actions()
	GameManager.save_game()
	settings_open = false
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_salvage_dropped(amount: int, _world_position: Vector2) -> void:
	last_dropped_amount = amount


func _on_player_respawned() -> void:
	if last_dropped_amount > 0:
		alert("EMERGENCY RETURN // SALVAGE x%02d ตกอยู่ที่จุดเสียชีวิต" % last_dropped_amount)
	else:
		alert("EMERGENCY RETURN // กลับสู่จุดลงจอด")
	last_dropped_amount = 0


func _on_btn_left_pressed() -> void:
	_press_action("Left")


func _on_btn_left_released() -> void:
	_release_action("Left")


func _on_btn_up_pressed() -> void:
	_press_action("Up")


func _on_btn_up_released() -> void:
	_release_action("Up")


func _on_btn_down_pressed() -> void:
	_press_action("Down")


func _on_btn_down_released() -> void:
	_release_action("Down")


func _on_btn_right_pressed() -> void:
	_press_action("Right")


func _on_btn_right_released() -> void:
	_release_action("Right")


func _on_btn_interact_button_down() -> void:
	_press_action("Interact")


func _on_btn_interact_button_up() -> void:
	_release_action("Interact")
