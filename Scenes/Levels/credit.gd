extends Control

@onready var credits_panel: PanelContainer = $CreditsPanel
@onready var credits_margin: MarginContainer = $CreditsPanel/Margin
@onready var credits_content: VBoxContainer = $CreditsPanel/Margin/Content
@onready var exit_button: Button = $CreditsPanel/Margin/Content/btnExit
@onready var title: Label = $CreditsPanel/Margin/Content/Title
@onready var subtitle: Label = $CreditsPanel/Margin/Content/Subtitle
@onready var course: Label = $CreditsPanel/Margin/Content/Course
@onready var team_grid: GridContainer = $CreditsPanel/Margin/Content/TeamGrid
@onready var logo: TextureRect = $CreditsPanel/Margin/Content/LogoCenter/Logo


func _ready() -> void:
	_build_responsive_shell()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	call_deferred("_apply_responsive_layout")


func _build_responsive_shell() -> void:
	credits_content.remove_child(exit_button)
	credits_margin.remove_child(credits_content)
	var shell := VBoxContainer.new()
	shell.name = "ResponsiveShell"
	shell.add_theme_constant_override("separation", 10)
	credits_margin.add_child(shell)
	var scroll := ScrollContainer.new()
	scroll.name = "CreditsScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	shell.add_child(scroll)
	credits_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(credits_content)
	shell.add_child(exit_button)


func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var compact := viewport_size.x < 700.0 or viewport_size.y < 520.0
	var safe := 12.0 if compact else 24.0
	var panel_size := Vector2(minf(820.0, viewport_size.x - safe * 2.0), minf(680.0, viewport_size.y - safe * 2.0))
	team_grid.columns = 1 if viewport_size.x < 520.0 else 2
	for child in team_grid.get_children():
		if child is Label:
			(child as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	logo.custom_minimum_size.x = minf(250.0, panel_size.x - 40.0)
	var panel_position := (viewport_size - panel_size) * 0.5
	credits_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	credits_panel.offset_left = panel_position.x
	credits_panel.offset_top = panel_position.y
	credits_panel.offset_right = panel_position.x + panel_size.x
	credits_panel.offset_bottom = panel_position.y + panel_size.y
	var inner_margin := 14 if compact else 34
	credits_margin.add_theme_constant_override("margin_left", inner_margin)
	credits_margin.add_theme_constant_override("margin_top", 12 if compact else 24)
	credits_margin.add_theme_constant_override("margin_right", inner_margin)
	credits_margin.add_theme_constant_override("margin_bottom", 12 if compact else 24)
	title.add_theme_font_size_override("font_size", 24 if compact else 30)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	course.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	exit_button.custom_minimum_size.y = 48 if compact else 50
