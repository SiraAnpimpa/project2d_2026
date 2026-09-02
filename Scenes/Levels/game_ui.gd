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
@onready var interact_button: Button = $GameUI/InteractButton
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
var interaction_prompt: Label
var med_kit_button: Button
var aim_joystick: AimJoystick
var comm_panel: PanelContainer
var comm_portrait: TextureRect
var comm_name: Label
var comm_text: Label
var defense_panel: PanelContainer
var defense_bar: ProgressBar
var defense_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.salvage_dropped.connect(_on_salvage_dropped)
	GameManager.player_respawned.connect(_on_player_respawned)
	GameManager.objective_changed.connect(set_objective)
	_build_gameplay_controls()
	_sync_settings_controls()
	_refresh_status()
	set_objective(GameManager.current_objective, GameManager.current_objective_details)


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
	if med_kit_button != null:
		var med_count := GameManager.get_item_count(&"med_kit")
		med_kit_button.text = "+  %02d\nMED KIT" % med_count
		med_kit_button.disabled = med_count <= 0 or GameManager.hp >= GameManager.max_hp or GameManager.death_in_progress


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


func set_interaction_prompt(message: String) -> void:
	if interaction_prompt == null:
		return
	interaction_prompt.text = message
	interaction_prompt.visible = !message.is_empty()
	interact_button.visible = !message.is_empty()
	interact_button.text = "INTERACT"


func show_echo(message: String, mysterious: bool = false, duration := 3.2) -> void:
	if comm_panel == null:
		return
	comm_name.text = "UNKNOWN AI" if mysterious else "ECHO"
	comm_text.text = message
	comm_portrait.texture = load("res://Assets/Gameplay/UI/unknown_ai_portrait.png" if mysterious else "res://Assets/Gameplay/UI/echo_portrait.png")
	comm_name.modulate = Color(0.73, 0.52, 1.0) if mysterious else Color(0.35, 0.9, 1.0)
	comm_panel.visible = true
	comm_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(comm_panel, "modulate:a", 1.0, 0.15)
	await get_tree().create_timer(duration, true).timeout
	if comm_panel != null:
		var out := create_tween()
		out.tween_property(comm_panel, "modulate:a", 0.0, 0.18)
		await out.finished
		comm_panel.visible = false


func set_defense_progress(progress: float, seconds_left: float) -> void:
	if defense_panel == null:
		return
	defense_panel.visible = progress < 1.0
	defense_bar.value = clampf(progress * 100.0, 0.0, 100.0)
	defense_label.text = "LAUNCH PREPARATION // %02d%%  •  %02ds" % [roundi(progress * 100.0), ceili(seconds_left)]


func _build_gameplay_controls() -> void:
	interact_button.visible = false
	interaction_prompt = Label.new()
	interaction_prompt.name = "InteractionPrompt"
	interaction_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	interaction_prompt.position = Vector2(-220, -142)
	interaction_prompt.size = Vector2(440, 42)
	interaction_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interaction_prompt.add_theme_color_override("font_color", Color(0.54, 1.0, 0.72))
	interaction_prompt.add_theme_color_override("font_outline_color", Color(0.0, 0.04, 0.08, 0.95))
	interaction_prompt.add_theme_constant_override("outline_size", 6)
	interaction_prompt.add_theme_font_size_override("font_size", 17)
	interaction_prompt.visible = false
	$GameUI.add_child(interaction_prompt)

	aim_joystick = AimJoystick.new()
	aim_joystick.name = "AimShootJoystick"
	aim_joystick.texture = load("res://Assets/Gameplay/UI/aim_joystick.png")
	aim_joystick.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	aim_joystick.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	aim_joystick.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	aim_joystick.position = Vector2(-174, -182)
	aim_joystick.size = Vector2(158, 158)
	aim_joystick.modulate.a = 0.62
	$GameUI.add_child(aim_joystick)
	$GameUI.move_child(aim_joystick, $GameUI.get_child_count() - 1)

	interact_button.position = Vector2(-274, -156)
	interact_button.size = Vector2(92, 62)
	interact_button.anchor_left = 1.0
	interact_button.anchor_top = 1.0
	interact_button.anchor_right = 1.0
	interact_button.anchor_bottom = 1.0

	med_kit_button = Button.new()
	med_kit_button.name = "MedKitButton"
	med_kit_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	med_kit_button.position = Vector2(-278, -84)
	med_kit_button.size = Vector2(96, 64)
	med_kit_button.focus_mode = Control.FOCUS_NONE
	med_kit_button.add_theme_color_override("font_color", Color(1.0, 0.52, 0.48))
	med_kit_button.pressed.connect(_on_med_kit_pressed)
	$GameUI.add_child(med_kit_button)

	comm_panel = PanelContainer.new()
	comm_panel.name = "EchoPanel"
	comm_panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	comm_panel.position = Vector2(18, -92)
	comm_panel.size = Vector2(410, 184)
	comm_panel.visible = false
	var comm_row := HBoxContainer.new()
	comm_row.add_theme_constant_override("separation", 12)
	comm_panel.add_child(comm_row)
	comm_portrait = TextureRect.new()
	comm_portrait.custom_minimum_size = Vector2(130, 164)
	comm_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	comm_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	comm_row.add_child(comm_portrait)
	var comm_copy := VBoxContainer.new()
	comm_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	comm_row.add_child(comm_copy)
	comm_name = Label.new()
	comm_name.add_theme_font_size_override("font_size", 18)
	comm_copy.add_child(comm_name)
	comm_text = Label.new()
	comm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	comm_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	comm_copy.add_child(comm_text)
	$GameUI.add_child(comm_panel)

	defense_panel = PanelContainer.new()
	defense_panel.name = "DefenseProgress"
	defense_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	defense_panel.position = Vector2(-260, 126)
	defense_panel.size = Vector2(520, 66)
	defense_panel.visible = false
	var defense_copy := VBoxContainer.new()
	defense_panel.add_child(defense_copy)
	defense_label = Label.new()
	defense_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	defense_label.add_theme_color_override("font_color", Color(1.0, 0.67, 0.25))
	defense_copy.add_child(defense_label)
	defense_bar = ProgressBar.new()
	defense_bar.show_percentage = false
	defense_copy.add_child(defense_bar)
	$GameUI.add_child(defense_panel)


func _on_med_kit_pressed() -> void:
	var player := GameManager.player
	if is_instance_valid(player) and player.has_method("use_med_kit"):
		player.use_med_kit()


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
	for action in ["Left", "Right", "Up", "Down", "Interact", "Shoot", "UseMedKit"]:
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
