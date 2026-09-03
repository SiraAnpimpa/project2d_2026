extends Control

@onready var music_toggle: CheckButton = %MusicToggle
@onready var sfx_toggle: CheckButton = %SfxToggle
@onready var fullscreen_toggle: CheckButton = %FullscreenToggle
@onready var back_button: Button = %BackButton
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var settings_margin: MarginContainer = $SettingsPanel/Margin
@onready var settings_content: VBoxContainer = $SettingsPanel/Margin/Content
@onready var title: Label = $SettingsPanel/Margin/Content/Title
@onready var subtitle: Label = $SettingsPanel/Margin/Content/Subtitle
@onready var page_header: Label = $Header

var settings_scroll: ScrollContainer

var syncing_controls := false


func _ready() -> void:
	_build_responsive_shell()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	call_deferred("_apply_responsive_layout")
	GameManager.load_option()
	syncing_controls = true
	music_toggle.button_pressed = GameManager.music_on
	sfx_toggle.button_pressed = GameManager.sfx_on
	fullscreen_toggle.button_pressed = GameManager.fullscreen_on
	syncing_controls = false
	music_toggle.grab_focus()
	modulate.a = 0.0
	create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).tween_property(self, "modulate:a", 1.0, 0.22)


func _build_responsive_shell() -> void:
	settings_content.remove_child(title)
	settings_content.remove_child(back_button)
	settings_margin.remove_child(settings_content)
	var shell := VBoxContainer.new()
	shell.name = "ResponsiveShell"
	shell.add_theme_constant_override("separation", 10)
	settings_margin.add_child(shell)
	shell.add_child(title)
	settings_scroll = ScrollContainer.new()
	settings_scroll.name = "SettingsScroll"
	settings_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	settings_scroll.follow_focus = true
	shell.add_child(settings_scroll)
	settings_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_scroll.add_child(settings_content)
	shell.add_child(back_button)


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var compact := viewport_size.x < 700.0 or viewport_size.y < 520.0
	var safe := 12.0 if compact else 24.0
	var panel_size := Vector2(
		maxf(280.0, minf(680.0, viewport_size.x - safe * 2.0)),
		maxf(280.0, minf(620.0, viewport_size.y - safe * 2.0))
	)
	var panel_position := (viewport_size - panel_size) * 0.5
	settings_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	settings_panel.offset_left = panel_position.x
	settings_panel.offset_top = panel_position.y
	settings_panel.offset_right = panel_position.x + panel_size.x
	settings_panel.offset_bottom = panel_position.y + panel_size.y
	var inner_margin := 14 if compact else 30
	settings_margin.add_theme_constant_override("margin_left", inner_margin)
	settings_margin.add_theme_constant_override("margin_top", 12 if compact else 24)
	settings_margin.add_theme_constant_override("margin_right", inner_margin)
	settings_margin.add_theme_constant_override("margin_bottom", 12 if compact else 24)
	title.add_theme_font_size_override("font_size", 23 if compact else 29)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	music_toggle.text = "เพลงประกอบ  //  MUSIC" if compact else "เพลงประกอบ  //  MUSIC CHANNEL"
	sfx_toggle.text = "เสียงเอฟเฟกต์  //  SFX" if compact else "เสียงเอฟเฟกต์  //  SFX CHANNEL"
	fullscreen_toggle.text = "เต็มหน้าจอ  //  FULLSCREEN"
	for button in [music_toggle, sfx_toggle, fullscreen_toggle, back_button]:
		button.clip_text = true
	page_header.visible = !compact


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
