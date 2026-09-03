extends CanvasLayer

const MAIN_MENU_SCENE := "res://Scenes/Levels/menu.tscn"
const MOVEMENT_JOYSTICK_SCRIPT := preload("res://Scenes/Levels/movement_joystick.gd")
const NOTICE_COLORS := {
	"OBJECTIVE": Color(0.52, 0.92, 1.0),
	"PICKUP": Color(0.55, 1.0, 0.66),
	"WARNING": Color(1.0, 0.58, 0.25),
	"SYSTEM": Color(0.68, 0.78, 1.0),
}

@onready var salvage_label: Label = %SalvageLabel
@onready var hp_bar: ProgressBar = %ProgressBar
@onready var hp_value: Label = %HPValue
@onready var alert_panel: PanelContainer = %AlertPanel
@onready var alert_label: Label = %AlertLabel
@onready var objective_panel: PanelContainer = $GameUI/ObjectivePanel
@onready var objective_label: Label = %ObjectiveLabel
@onready var objective_meta_label: Label = %ObjectiveMetaLabel
@onready var status_panel: PanelContainer = $GameUI/StatusPanel
@onready var item_belt: PanelContainer = $GameUI/ItemBelt
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
var settings_tween: Tween
var interaction_prompt: Label
var movement_joystick: MovementJoystick
var fire_button: Button
var med_kit_button: Button
var comm_panel: PanelContainer
var comm_portrait: TextureRect
var comm_name: Label
var comm_text: Label
var defense_panel: PanelContainer
var defense_bar: ProgressBar
var defense_label: Label
var combat_material_panel: PanelContainer
var combat_material_label: Label
var boss_panel: PanelContainer
var boss_bar: ProgressBar
var boss_name_label: Label
var boss_phase_label: Label
var boss_intro: Control
var boss_intro_label: Label

var notification_queue: Array[Dictionary] = []
var notification_busy := false
var recent_notification_times: Dictionary = {}
var echo_queue: Array[Dictionary] = []
var echo_busy := false
var last_objective_text := ""
var compact_layout := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameManager.salvage_dropped.connect(_on_salvage_dropped)
	GameManager.player_respawned.connect(_on_player_respawned)
	GameManager.objective_changed.connect(set_objective)
	_build_gameplay_controls()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_sync_settings_controls()
	_refresh_status()
	set_objective(GameManager.current_objective, GameManager.current_objective_details)
	_apply_responsive_layout()


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
	hp_bar.max_value = GameManager.max_hp
	hp_bar.value = GameManager.hp
	hp_value.text = "%03d%%" % roundi(100.0 * float(GameManager.hp) / maxf(float(GameManager.max_hp), 1.0))
	for item_id in inventory_counts:
		var count_label: Label = inventory_counts[item_id]
		count_label.text = "%02d" % GameManager.get_item_count(item_id)
	if med_kit_button != null:
		var med_count := GameManager.get_item_count(&"med_kit")
		med_kit_button.text = "✚  MEDKIT\nFULL HEAL · %02d" % med_count
		med_kit_button.disabled = med_count <= 0 or GameManager.hp >= GameManager.max_hp or GameManager.death_in_progress
	if combat_material_label != null:
		combat_material_label.text = "BIO %02d   CAR %02d   ACID %02d   CORE %02d%s" % [
			GameManager.get_item_count(&"alien_biomass"),
			GameManager.get_item_count(&"hardened_carapace"),
			GameManager.get_item_count(&"acid_gland"),
			GameManager.get_item_count(&"alien_core"),
			"   ◆ FINAL CORE" if GameManager.get_item_count(&"final_core") > 0 else "",
		]


func alert(message: String, category: String = "WARNING", priority: int = 0, duration: float = 2.8) -> void:
	if message.begins_with("ECHO // "):
		show_echo(message.trim_prefix("ECHO // "))
		return
	var normalized_category := category.to_upper()
	var title := normalized_category
	if normalized_category == "WARNING" and !message.contains("WARNING"):
		title = "SYSTEM MESSAGE"
	queue_notification(normalized_category, title, message, duration, priority)


func queue_notification(category: String, title: String, message: String, duration := 2.8, priority := 0, duplicate_key := "") -> bool:
	var key := duplicate_key if !duplicate_key.is_empty() else "%s|%s|%s" % [category, title, message]
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(recent_notification_times.get(key, -1000.0)) < 3.0:
		return false
	recent_notification_times[key] = now
	var entry := {
		"category": category.to_upper(),
		"title": title,
		"message": message,
		"duration": clampf(duration, 2.0, 5.0),
		"priority": priority,
	}
	var insert_at := notification_queue.size()
	for index in range(notification_queue.size()):
		if priority > int(notification_queue[index].priority):
			insert_at = index
			break
	notification_queue.insert(insert_at, entry)
	if !notification_busy:
		call_deferred("_display_next_notification")
	return true


func _display_next_notification() -> void:
	if notification_busy or echo_busy or notification_queue.is_empty() or !is_inside_tree():
		return
	notification_busy = true
	var entry: Dictionary = notification_queue.pop_front()
	var category := String(entry.category)
	_layout_notification(category)
	alert_label.text = "%s\n%s" % [entry.title, entry.message]
	alert_label.add_theme_color_override("font_color", NOTICE_COLORS.get(category, NOTICE_COLORS.SYSTEM))
	alert_panel.visible = true
	alert_panel.modulate.a = 0.0
	var intro := create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	intro.tween_property(alert_panel, "modulate:a", 1.0, 0.18)
	await intro.finished
	await get_tree().create_timer(float(entry.duration), true).timeout
	if !is_inside_tree():
		return
	var outro := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	outro.tween_property(alert_panel, "modulate:a", 0.0, 0.16)
	await outro.finished
	alert_panel.visible = false
	notification_busy = false
	if !notification_queue.is_empty():
		call_deferred("_display_next_notification")
	elif !echo_queue.is_empty():
		call_deferred("_display_next_echo")


func set_objective(objective: String, details: String = "") -> void:
	var changed := !last_objective_text.is_empty() and objective != last_objective_text
	last_objective_text = objective
	objective_label.text = objective
	objective_meta_label.text = details
	objective_meta_label.visible = !details.is_empty()
	if changed:
		queue_notification("OBJECTIVE", "OBJECTIVE UPDATED", objective, 3.0, 4, "objective|" + objective)


func set_interaction_prompt(message: String) -> void:
	if interaction_prompt == null:
		return
	var usable := !message.is_empty()
	var context := _interaction_context(message)
	interaction_prompt.text = "E  /  INTERACT  ·  %s" % context if usable else ""
	interaction_prompt.visible = usable
	interact_button.visible = usable
	interact_button.text = "✋  INTERACT\n%s" % context


func _interaction_context(message: String) -> String:
	var upper := message.to_upper()
	for context in ["LAUNCH", "SHIP", "TERMINAL", "REPAIR", "EXIT", "CORE", "DOOR"]:
		if context in upper:
			return context
	return "ACTION"


func show_echo(message: String, mysterious: bool = false, duration := 3.2) -> void:
	echo_queue.append({"message": message, "mysterious": mysterious, "duration": clampf(duration, 2.0, 5.0)})
	if !echo_busy:
		call_deferred("_display_next_echo")


func _display_next_echo() -> void:
	if echo_busy or notification_busy or !notification_queue.is_empty() or echo_queue.is_empty() or comm_panel == null:
		return
	echo_busy = true
	var entry: Dictionary = echo_queue.pop_front()
	var mysterious := bool(entry.mysterious)
	comm_name.text = "UNKNOWN AI" if mysterious else "ECHO"
	comm_text.text = String(entry.message)
	comm_portrait.texture = load("res://Assets/Gameplay/UI/unknown_ai_portrait.png" if mysterious else "res://Assets/Gameplay/UI/echo_portrait.png")
	comm_name.modulate = Color(0.73, 0.52, 1.0) if mysterious else Color(0.35, 0.9, 1.0)
	comm_panel.visible = true
	comm_panel.modulate.a = 0.0
	var intro := create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	intro.tween_property(comm_panel, "modulate:a", 1.0, 0.16)
	await intro.finished
	await get_tree().create_timer(float(entry.duration), true).timeout
	if !is_inside_tree():
		return
	var outro := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	outro.tween_property(comm_panel, "modulate:a", 0.0, 0.18)
	await outro.finished
	comm_panel.visible = false
	echo_busy = false
	if !notification_queue.is_empty():
		call_deferred("_display_next_notification")
	elif !echo_queue.is_empty():
		call_deferred("_display_next_echo")


func set_defense_progress(progress: float, seconds_left: float) -> void:
	if defense_panel == null:
		return
	defense_panel.visible = progress < 1.0
	defense_bar.value = clampf(progress * 100.0, 0.0, 100.0)
	defense_label.text = "LAUNCH PREPARATION // %02d%%  ·  %02ds" % [roundi(progress * 100.0), ceili(seconds_left)]


func show_boss(name: String, maximum_hp: int, current_hp: int, phase: int = 1) -> void:
	if boss_panel == null:
		return
	boss_panel.visible = true
	boss_name_label.text = name
	boss_bar.max_value = maximum_hp
	boss_bar.value = current_hp
	boss_phase_label.text = "PHASE %d" % phase


func set_boss_health(current_hp: int, maximum_hp: int, phase: int) -> void:
	if boss_panel == null:
		return
	boss_bar.max_value = maximum_hp
	boss_bar.value = current_hp
	boss_phase_label.text = "PHASE %d" % phase


func hide_boss() -> void:
	if boss_panel != null:
		boss_panel.visible = false


func show_boss_intro(name: String) -> void:
	if boss_intro == null:
		return
	boss_intro_label.text = name + "\nFINAL COMBAT TEST"
	boss_intro.visible = true
	boss_intro.modulate.a = 0.0
	var intro := create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	intro.tween_property(boss_intro, "modulate:a", 1.0, 0.25)
	await intro.finished
	await get_tree().create_timer(1.35, true).timeout
	var outro := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	outro.tween_property(boss_intro, "modulate:a", 0.0, 0.25)
	await outro.finished
	boss_intro.visible = false


func _build_gameplay_controls() -> void:
	interact_button.visible = false
	interact_button.focus_mode = Control.FOCUS_NONE
	interact_button.mouse_filter = Control.MOUSE_FILTER_STOP

	combat_material_panel = PanelContainer.new()
	combat_material_panel.name = "CombatMaterialPanel"
	combat_material_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	$GameUI.add_child(combat_material_panel)
	combat_material_label = Label.new()
	combat_material_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_material_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combat_material_label.add_theme_font_size_override("font_size", 13)
	combat_material_label.add_theme_color_override("font_color", Color(0.62, 1.0, 0.72))
	combat_material_panel.add_child(combat_material_label)

	interaction_prompt = Label.new()
	interaction_prompt.name = "InteractionPrompt"
	interaction_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	interaction_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interaction_prompt.add_theme_color_override("font_color", Color(0.54, 1.0, 0.72))
	interaction_prompt.add_theme_color_override("font_outline_color", Color(0.0, 0.04, 0.08, 0.95))
	interaction_prompt.add_theme_constant_override("outline_size", 6)
	interaction_prompt.add_theme_font_size_override("font_size", 17)
	interaction_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interaction_prompt.visible = false
	$GameUI.add_child(interaction_prompt)

	movement_joystick = MOVEMENT_JOYSTICK_SCRIPT.new()
	movement_joystick.name = "MovementJoystick"
	movement_joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	$GameUI.add_child(movement_joystick)

	fire_button = Button.new()
	fire_button.name = "FireButton"
	fire_button.text = "⌖\nFIRE"
	fire_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	fire_button.focus_mode = Control.FOCUS_NONE
	fire_button.mouse_filter = Control.MOUSE_FILTER_STOP
	fire_button.add_theme_color_override("font_color", Color(1.0, 0.73, 0.34))
	fire_button.add_theme_font_size_override("font_size", 18)
	fire_button.button_down.connect(_on_fire_button_down)
	fire_button.button_up.connect(_on_fire_button_up)
	$GameUI.add_child(fire_button)

	med_kit_button = Button.new()
	med_kit_button.name = "MedKitButton"
	med_kit_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	med_kit_button.focus_mode = Control.FOCUS_NONE
	med_kit_button.mouse_filter = Control.MOUSE_FILTER_STOP
	med_kit_button.add_theme_color_override("font_color", Color(1.0, 0.52, 0.48))
	med_kit_button.add_theme_font_size_override("font_size", 14)
	med_kit_button.pressed.connect(_on_med_kit_pressed)
	$GameUI.add_child(med_kit_button)

	_build_echo_panel()
	_build_defense_panel()
	_build_boss_panel()
	_build_boss_intro()


func _build_echo_panel() -> void:
	comm_panel = PanelContainer.new()
	comm_panel.name = "EchoPanel"
	comm_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	comm_panel.visible = false
	var comm_row := HBoxContainer.new()
	comm_row.add_theme_constant_override("separation", 10)
	comm_panel.add_child(comm_row)
	comm_portrait = TextureRect.new()
	comm_portrait.custom_minimum_size = Vector2(88, 104)
	comm_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	comm_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	comm_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	comm_row.add_child(comm_portrait)
	var comm_copy := VBoxContainer.new()
	comm_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	comm_row.add_child(comm_copy)
	comm_name = Label.new()
	comm_name.add_theme_font_size_override("font_size", 17)
	comm_copy.add_child(comm_name)
	comm_text = Label.new()
	comm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	comm_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	comm_copy.add_child(comm_text)
	$GameUI.add_child(comm_panel)


func _build_defense_panel() -> void:
	defense_panel = PanelContainer.new()
	defense_panel.name = "DefenseProgress"
	defense_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
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


func _build_boss_panel() -> void:
	boss_panel = PanelContainer.new()
	boss_panel.name = "BossHealth"
	boss_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_panel.visible = false
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 9)
	boss_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	margin.add_child(content)
	var heading := HBoxContainer.new()
	content.add_child(heading)
	boss_name_label = Label.new()
	boss_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_name_label.add_theme_font_size_override("font_size", 17)
	boss_name_label.add_theme_color_override("font_color", Color(1.0, 0.43, 0.32))
	heading.add_child(boss_name_label)
	boss_phase_label = Label.new()
	boss_phase_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.34))
	heading.add_child(boss_phase_label)
	boss_bar = ProgressBar.new()
	boss_bar.show_percentage = false
	boss_bar.custom_minimum_size.y = 14
	content.add_child(boss_bar)
	$GameUI.add_child(boss_panel)


func _build_boss_intro() -> void:
	boss_intro = Control.new()
	boss_intro.name = "BossIntro"
	boss_intro.set_anchors_preset(Control.PRESET_FULL_RECT)
	boss_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_intro.visible = false
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.08, 0.0, 0.025, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_intro.add_child(shade)
	boss_intro_label = Label.new()
	boss_intro_label.set_anchors_preset(Control.PRESET_CENTER)
	boss_intro_label.position = Vector2(-300, -72)
	boss_intro_label.size = Vector2(600, 144)
	boss_intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_intro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_intro_label.add_theme_font_size_override("font_size", 32)
	boss_intro_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.38))
	boss_intro_label.add_theme_color_override("font_outline_color", Color(0.05, 0.0, 0.02, 1.0))
	boss_intro_label.add_theme_constant_override("outline_size", 8)
	boss_intro.add_child(boss_intro_label)
	$GameUI.add_child(boss_intro)


func _apply_responsive_layout() -> void:
	if !is_inside_tree() or movement_joystick == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	compact_layout = viewport_size.x < 900.0 or viewport_size.y < 540.0
	var safe := 16.0
	status_panel.position = Vector2(safe, 10)
	status_panel.size = Vector2(330, 60)
	objective_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	objective_panel.position = Vector2(safe, 80)
	objective_panel.size = Vector2(390 if compact_layout else 450, 96)
	settings_button.position = Vector2(viewport_size.x - 102, 10)
	settings_button.size = Vector2(86, 44)
	movement_joystick.position = Vector2(safe, viewport_size.y - 186)
	movement_joystick.size = Vector2(172, 172)
	fire_button.position = Vector2(viewport_size.x - 150, viewport_size.y - 150)
	fire_button.size = Vector2(134, 134)
	interact_button.position = Vector2(viewport_size.x - 316, viewport_size.y - 150)
	interact_button.size = Vector2(150, 66)
	med_kit_button.position = Vector2(viewport_size.x - 316, viewport_size.y - 78)
	med_kit_button.size = Vector2(150, 62)
	interaction_prompt.position = Vector2(-220, -220 if compact_layout else -150)
	interaction_prompt.size = Vector2(440, 42)
	item_belt.visible = !compact_layout
	combat_material_panel.visible = !compact_layout
	combat_material_panel.position = Vector2(-535, 78)
	combat_material_panel.size = Vector2(515, 42)
	_layout_notification("SYSTEM")
	defense_panel.position = Vector2(-260, 92)
	defense_panel.size = Vector2(520, 66)
	boss_panel.position = Vector2(-260, 92)
	boss_panel.size = Vector2(520, 66)
	comm_panel.position = Vector2(safe, viewport_size.y - (320 if compact_layout else 306))
	comm_panel.size = Vector2(minf(390, viewport_size.x - 32), 122)


func _layout_notification(category: String) -> void:
	if alert_panel == null:
		return
	if category == "PICKUP" and !compact_layout:
		alert_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		alert_panel.position = Vector2(-205, -124)
		alert_panel.size = Vector2(410, 58)
	else:
		alert_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
		alert_panel.position = Vector2(-260, 18)
		alert_panel.size = Vector2(520, 64)


func _on_fire_button_down() -> void:
	var player := GameManager.player
	if !settings_open and is_instance_valid(player) and player.has_method("set_mobile_fire"):
		player.set_mobile_fire(true)


func _on_fire_button_up() -> void:
	var player := GameManager.player
	if is_instance_valid(player) and player.has_method("set_mobile_fire"):
		player.set_mobile_fire(false)


func _on_med_kit_pressed() -> void:
	var player := GameManager.player
	if !settings_open and is_instance_valid(player) and player.has_method("use_med_kit"):
		player.use_med_kit()


func _on_interact_button_down() -> void:
	var player := GameManager.player
	if !settings_open and is_instance_valid(player) and player.has_method("perform_interaction"):
		player.perform_interaction()


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
		save_status.text = "SETTINGS ARE SAVED AUTOMATICALLY"
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
	for action in ["Left", "Right", "Up", "Down", "Interact", "UseMedKit", "Dodge"]:
		Input.action_release(action)
	if movement_joystick != null:
		movement_joystick._send_direction(Vector2.ZERO)
	_on_fire_button_up()


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
	save_status.text = "SAVE COMPLETE" if GameManager.save_game() else "SAVE FAILED"


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
		alert("SALVAGE x%02d REMAINS AT THE DEATH SITE" % last_dropped_amount, "WARNING", 5)
	else:
		alert("EMERGENCY RETURN TO LANDING POINT", "SYSTEM")
	last_dropped_amount = 0
