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

	func _ready() -> void:
		layer = 30
		process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().paused = true
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
		var scroll := ScrollContainer.new()
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.add_child(scroll)
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
		var title := Label.new()
		title.text = "UNKNOWN AI // SIGNAL SOURCE"
		title.add_theme_font_size_override("font_size", 25)
		title.add_theme_color_override("font_color", Color(0.68, 0.5, 1.0))
		copy.add_child(title)
		answer = Label.new()
		answer.text = "New biological entity detected.\nYour arrival was... unexpected."
		answer.custom_minimum_size.y = 150
		answer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		answer.add_theme_color_override("font_color", Color(0.65, 0.91, 1.0))
		copy.add_child(answer)
		_add_choice(copy, "1 // Who sent the landing signal?", "The signal preceded your distress call. I merely ensured you heard it.")
		_add_choice(copy, "2 // What happened to this facility?", "Its operators sought an intelligence beneath Zone-67. The facility survived them.")
		_add_choice(copy, "3 // Why is no one here?", "Absence is not proof of departure. Your sensors are... limited.")
		var close := Button.new()
		close.text = "4 // DISCONNECT"
		close.custom_minimum_size.y = 48
		close.pressed.connect(_close)
		copy.add_child(close)
		get_viewport().size_changed.connect(_apply_responsive_layout)
		_apply_responsive_layout()

	func _apply_responsive_layout() -> void:
		var viewport_size := get_viewport().get_visible_rect().size
		portrait.visible = viewport_size.x >= 820.0 and viewport_size.y >= 500.0
		answer.custom_minimum_size.y = 110 if viewport_size.y < 500.0 else 150

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
