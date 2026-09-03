extends Control

@onready var btn_start: Button = $UI/MenuPanel/Margin/MenuItems/btnStart
@onready var btn_continue: Button = $UI/MenuPanel/Margin/MenuItems/btnContinue
@onready var title_block: Control = $UI/TitleBlock
@onready var title_label: Label = $UI/TitleBlock/Title
@onready var tagline: Label = $UI/TitleBlock/Tagline
@onready var menu_panel: PanelContainer = $UI/MenuPanel
@onready var menu_margin: MarginContainer = $UI/MenuPanel/Margin
@onready var menu_items: VBoxContainer = $UI/MenuPanel/Margin/MenuItems
@onready var footer: Label = $UI/Footer
@onready var menu_buttons: Array[Button] = [
	$UI/MenuPanel/Margin/MenuItems/btnStart,
	$UI/MenuPanel/Margin/MenuItems/btnContinue,
	$UI/MenuPanel/Margin/MenuItems/btnOption,
	$UI/MenuPanel/Margin/MenuItems/btnCredit,
	$UI/MenuPanel/Margin/MenuItems/btnQuit,
]


func _ready() -> void:
	_build_responsive_menu_scroll()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	GameManager.load_option()
	btn_continue.disabled = !GameManager.has_gamesaved()
	for button in menu_buttons:
		button.mouse_entered.connect(_focus_menu_button.bind(button))
	btn_start.grab_focus()
	$UI.modulate.a = 0.0
	create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).tween_property($UI, "modulate:a", 1.0, 0.25)


func _build_responsive_menu_scroll() -> void:
	menu_margin.remove_child(menu_items)
	var scroll := ScrollContainer.new()
	scroll.name = "MenuScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	menu_margin.add_child(scroll)
	menu_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(menu_items)


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var compact := viewport_size.x < 900.0 or viewport_size.y < 560.0
	var safe := 12.0 if compact else 28.0
	title_block.set_anchors_preset(Control.PRESET_TOP_LEFT)
	menu_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	if compact:
		title_block.position = Vector2(safe, safe)
		title_block.size = Vector2(viewport_size.x - safe * 2.0, 112.0)
		title_label.add_theme_font_size_override("font_size", 38)
		tagline.add_theme_font_size_override("font_size", 12)
		tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var panel_top := 126.0
		menu_panel.position = Vector2(safe, panel_top)
		menu_panel.size = Vector2(viewport_size.x - safe * 2.0, viewport_size.y - panel_top - safe)
		footer.visible = false
	else:
		title_block.position = Vector2(viewport_size.x * 0.05, viewport_size.y * 0.06)
		title_block.size = Vector2(viewport_size.x * 0.55, viewport_size.y * 0.28)
		title_label.add_theme_font_size_override("font_size", 60)
		tagline.add_theme_font_size_override("font_size", 14)
		var panel_size := Vector2(minf(430.0, viewport_size.x * 0.28), minf(620.0, viewport_size.y * 0.68))
		menu_panel.position = Vector2(viewport_size.x - panel_size.x - viewport_size.x * 0.04, viewport_size.y * 0.16)
		menu_panel.size = panel_size
		footer.visible = true
	var inner_margin := 12 if compact else 20
	menu_margin.add_theme_constant_override("margin_left", inner_margin)
	menu_margin.add_theme_constant_override("margin_top", 12 if compact else 18)
	menu_margin.add_theme_constant_override("margin_right", inner_margin)
	menu_margin.add_theme_constant_override("margin_bottom", 12 if compact else 16)


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
