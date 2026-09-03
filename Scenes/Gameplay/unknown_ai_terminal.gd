class_name UnknownAITerminal
extends Interactable


func _ready() -> void:
	super._ready()
	prompt = "E - ACCESS TERMINAL"
	interaction_radius = 120.0


func interact(player: Node2D) -> void:
	if get_tree().get_first_node_in_group("DialogueUI") != null:
		return
	GameManager.contact_unknown_ai()
	var dialogue := UnknownAIDialogue.new()
	dialogue.add_to_group("DialogueUI")
	get_tree().current_scene.add_child(dialogue)
	if player.has_method("set_movement_enabled"):
		player.set_movement_enabled(false)


class UnknownAIDialogue:
	extends CanvasLayer
	var answer: Label
	var panel: PanelContainer
	var portrait: TextureRect
	var panel_margin: MarginContainer
	var title: Label
	var close_button: Button
	var gameplay_hud: CanvasLayer

	func _ready() -> void:
		layer = 30
		process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().paused = true
		AudioManager.play_radio_transmission()
		gameplay_hud = get_tree().get_first_node_in_group("GameHUD") as CanvasLayer
		if is_instance_valid(gameplay_hud):
			gameplay_hud.visible = false
		var screen := Control.new()
		screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		screen.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(screen)
		var dim := ColorRect.new()
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.color = Color(0.005, 0.008, 0.03, 0.9)
		screen.add_child(dim)
		panel = PanelContainer.new()
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.offset_left = 20
		panel.offset_top = 18
		panel.offset_right = -20
		panel.offset_bottom = -18
		screen.add_child(panel)
		panel_margin = MarginContainer.new()
		panel_margin.add_theme_constant_override("margin_left", 16)
		panel_margin.add_theme_constant_override("margin_top", 12)
		panel_margin.add_theme_constant_override("margin_right", 16)
		panel_margin.add_theme_constant_override("margin_bottom", 12)
		panel.add_child(panel_margin)
		var shell := VBoxContainer.new()
		shell.add_theme_constant_override("separation", 10)
		panel_margin.add_child(shell)
		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 10)
		shell.add_child(header)
		title = Label.new()
		title.text = "UNKNOWN AI // SIGNAL SOURCE"
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.add_theme_font_size_override("font_size", 25)
		title.add_theme_color_override("font_color", Color(0.68, 0.5, 1.0))
		header.add_child(title)
		close_button = Button.new()
		close_button.name = "CloseButton"
		close_button.text = "DISCONNECT  [X]"
		close_button.custom_minimum_size = Vector2(156, 46)
		close_button.pressed.connect(_close)
		header.add_child(close_button)
		var scroll := ScrollContainer.new()
		scroll.name = "DialogueScroll"
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		shell.add_child(scroll)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(row)
		portrait = TextureRect.new()
		portrait.custom_minimum_size = Vector2(260, 420)
		portrait.texture = load("res://Assets/Gameplay/UI/unknown_ai_portrait.png")
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(portrait)
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy.add_theme_constant_override("separation", 12)
		row.add_child(copy)
		answer = Label.new()
		answer.text = "New biological entity detected.\nYour arrival was... unexpected."
		answer.custom_minimum_size.y = 150
		answer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		answer.add_theme_color_override("font_color", Color(0.65, 0.91, 1.0))
		copy.add_child(answer)
		_add_choice(copy, "1 // Who sent the landing signal?", "The signal preceded your distress call. I merely ensured you heard it.")
		_add_choice(copy, "2 // What happened to this facility?", "Its operators sought an intelligence beneath Zone-67. The facility survived them.")
		_add_choice(copy, "3 // Why is no one here?", "Absence is not proof of departure. Your sensors are... limited.")
		get_viewport().size_changed.connect(_apply_responsive_layout)
		_apply_responsive_layout()

	func _apply_responsive_layout() -> void:
		var viewport_size := get_viewport().get_visible_rect().size
		var compact := viewport_size.x < 700.0 or viewport_size.y < 500.0
		var safe := 12.0
		panel.offset_left = safe
		panel.offset_top = safe
		panel.offset_right = -safe
		panel.offset_bottom = -safe
		var inner_margin := 10 if compact else 16
		panel_margin.add_theme_constant_override("margin_left", inner_margin)
		panel_margin.add_theme_constant_override("margin_top", inner_margin)
		panel_margin.add_theme_constant_override("margin_right", inner_margin)
		panel_margin.add_theme_constant_override("margin_bottom", inner_margin)
		portrait.visible = viewport_size.x >= 820.0 and viewport_size.y >= 500.0
		answer.custom_minimum_size.y = 92 if compact else 150
		title.add_theme_font_size_override("font_size", 18 if compact else 25)
		close_button.text = "X" if viewport_size.x < 520.0 else "DISCONNECT  [X]"
		close_button.custom_minimum_size = Vector2(48 if viewport_size.x < 520.0 else 156, 44 if compact else 46)

	func _add_choice(parent: Control, label_text: String, response: String) -> void:
		var button := Button.new()
		button.text = label_text
		button.custom_minimum_size.y = 48
		button.pressed.connect(_answer.bind(response))
		parent.add_child(button)

	func _answer(response: String) -> void:
		answer.text = response

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_cancel") and !event.is_echo():
			_close()

	func _close() -> void:
		get_tree().paused = false
		var player := GameManager.player
		if is_instance_valid(player) and player.has_method("set_movement_enabled"):
			player.set_movement_enabled(true)
		queue_free()

	func _exit_tree() -> void:
		AudioManager.stop_radio_transmission()
		if is_instance_valid(gameplay_hud):
			gameplay_hud.visible = true
