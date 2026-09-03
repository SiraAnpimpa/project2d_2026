extends Control

@onready var play_button: Button = %PlayButton
@onready var score_summary: Label = %ScoreSummary
@onready var result_panel: PanelContainer = $ResultPanel
@onready var result_margin: MarginContainer = $ResultPanel/Margin
@onready var result_content: VBoxContainer = $ResultPanel/Margin/Content
@onready var title: Label = $ResultPanel/Margin/Content/Title
@onready var message: Label = $ResultPanel/Margin/Content/Message
@onready var actions: HBoxContainer = $ResultPanel/Margin/Content/Actions
@onready var menu_button: Button = $ResultPanel/Margin/Content/Actions/MenuButton

var full_menu_text := ""
var full_play_text := ""


func _ready() -> void:
	full_menu_text = menu_button.text
	full_play_text = play_button.text
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	call_deferred("_apply_responsive_layout")
	score_summary.text = "SALVAGE RECOVERED  //  %04d" % GameManager.salvage
	play_button.grab_focus()
	modulate.a = 0.0
	create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).tween_property(self, "modulate:a", 1.0, 0.24)


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var compact := viewport_size.x < 700.0 or viewport_size.y < 520.0
	var safe := 12.0 if compact else 24.0
	var panel_size := Vector2(minf(760.0, viewport_size.x - safe * 2.0), minf(560.0, viewport_size.y - safe * 2.0))
	var panel_position := (viewport_size - panel_size) * 0.5
	result_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	result_panel.offset_left = panel_position.x
	result_panel.offset_top = panel_position.y
	result_panel.offset_right = panel_position.x + panel_size.x
	result_panel.offset_bottom = panel_position.y + panel_size.y
	var inner_margin := 14 if compact else 34
	result_margin.add_theme_constant_override("margin_left", inner_margin)
	result_margin.add_theme_constant_override("margin_top", 12 if compact else 28)
	result_margin.add_theme_constant_override("margin_right", inner_margin)
	result_margin.add_theme_constant_override("margin_bottom", 12 if compact else 28)
	result_content.add_theme_constant_override("separation", 8 if compact else 15)
	title.add_theme_font_size_override("font_size", 25 if compact else 38)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	score_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_button.custom_minimum_size = Vector2(0, 48 if compact else 52)
	play_button.custom_minimum_size = Vector2(0, 48 if compact else 52)
	menu_button.clip_text = true
	play_button.clip_text = true
	menu_button.text = "เมนู" if viewport_size.x < 520.0 else full_menu_text
	play_button.text = ("ลองใหม่" if name == "MissionFailed" else "เริ่มใหม่") if viewport_size.x < 520.0 else full_play_text
	menu_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 8 if compact else 14)


func _on_play_pressed() -> void:
	GameManager.restart()


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Levels/menu.tscn")
