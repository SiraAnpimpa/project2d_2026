class_name UnknownAITerminal
extends Interactable


func _ready() -> void:
	super._ready()
	prompt = "E - ACCESS TERMINAL"
	interaction_radius = 120.0


func interact(player: Node2D) -> void:
	if get_tree().get_first_node_in_group("DialogueUI") != null:
		return
	GameManager.unknown_ai_contacted = true
	if !GameManager.are_all_systems_repaired():
		GameManager.set_objective("Repair all three ship systems", GameManager.get_ship_status_text())
	var dialogue := UnknownAIDialogue.new()
	dialogue.add_to_group("DialogueUI")
	get_tree().current_scene.add_child(dialogue)
	if player.has_method("set_movement_enabled"):
		player.set_movement_enabled(false)


class UnknownAIDialogue:
	extends CanvasLayer
	var answer: Label

	func _ready() -> void:
		layer = 30
		process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().paused = true
		var screen := Control.new()
		screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(screen)
		var dim := ColorRect.new()
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.color = Color(0.005, 0.008, 0.03, 0.9)
		screen.add_child(dim)
		var panel := PanelContainer.new()
		panel.set_anchors_preset(Control.PRESET_CENTER)
		panel.position = Vector2(-470, -300)
		panel.size = Vector2(940, 600)
		screen.add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		panel.add_child(row)
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(300, 500)
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
