class_name ShipRepairConsole
extends CanvasLayer

const SYSTEMS := {
	"power": {"title": "POWER SYSTEM", "item": &"energy_crystal", "item_name": "ENERGY CRYSTAL", "cost": 3},
	"navigation": {"title": "NAVIGATION SYSTEM", "item": &"circuit_part", "item_name": "CIRCUIT PART", "cost": 2},
	"engine": {"title": "ENGINE SYSTEM", "item": &"scrap_metal", "item_name": "SCRAP METAL", "cost": 5},
}

var content: VBoxContainer
var system_rows: Dictionary = {}
var feedback: Label
var overall_label: Label
var minigame_panel: PanelContainer
var selected_system := ""
var circuit_states := [0, 2, 3, 0]
var circuit_buttons: Array[Button] = []
var nav_slider: HSlider
var engine_progress := 0
var engine_buttons: Array[Button] = []


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	get_tree().paused = true
	var player := GameManager.player
	if is_instance_valid(player) and player.has_method("set_movement_enabled"):
		player.set_movement_enabled(false)
	_refresh()
	feedback.text = "ECHO // Primary ship systems are critically damaged.\nComplete diagnostics before resources are committed."


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and !event.is_echo():
		_close()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var screen := Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.01, 0.035, 0.9)
	screen.add_child(dim)
	var frame := TextureRect.new()
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.position = Vector2(-590, -380)
	frame.size = Vector2(1180, 760)
	frame.texture = load("res://Assets/Gameplay/UI/repair_console_frame.png")
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(frame)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_CENTER)
	margin.position = Vector2(-475, -305)
	margin.size = Vector2(950, 610)
	screen.add_child(margin)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(92, 92)
	portrait.texture = load("res://Assets/Gameplay/UI/echo_portrait.png")
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(portrait)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var title := Label.new()
	title.text = "SHIP REPAIR // ECHO INTERFACE"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.4, 0.92, 1.0))
	heading.add_child(title)
	overall_label = Label.new()
	overall_label.name = "Overall"
	overall_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.7))
	heading.add_child(overall_label)
	var close := Button.new()
	close.text = "CLOSE  [ESC]"
	close.custom_minimum_size = Vector2(150, 48)
	close.pressed.connect(_close)
	header.add_child(close)

	for system_id in SYSTEMS:
		var spec: Dictionary = SYSTEMS[system_id]
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 54
		row.add_theme_constant_override("separation", 12)
		content.add_child(row)
		var name_label := Label.new()
		name_label.text = spec.title
		name_label.custom_minimum_size.x = 245
		name_label.add_theme_font_size_override("font_size", 18)
		row.add_child(name_label)
		var resource_label := Label.new()
		resource_label.custom_minimum_size.x = 300
		resource_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(resource_label)
		var status := Label.new()
		status.custom_minimum_size.x = 140
		status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(status)
		var button := Button.new()
		button.text = "START REPAIR"
		button.custom_minimum_size = Vector2(180, 48)
		button.pressed.connect(_start_minigame.bind(system_id))
		row.add_child(button)
		system_rows[system_id] = {"resource": resource_label, "status": status, "button": button}

	feedback = Label.new()
	feedback.custom_minimum_size.y = 62
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	feedback.add_theme_color_override("font_color", Color(0.66, 0.86, 0.94))
	content.add_child(feedback)
	minigame_panel = PanelContainer.new()
	minigame_panel.custom_minimum_size.y = 248
	content.add_child(minigame_panel)


func _refresh() -> void:
	if overall_label != null:
		overall_label.text = "SHIP REPAIR // %d / 3 SYSTEMS OPERATIONAL" % GameManager.repaired_system_count()
	for system_id in SYSTEMS:
		var spec: Dictionary = SYSTEMS[system_id]
		var row: Dictionary = system_rows[system_id]
		var current := GameManager.get_item_count(spec.item)
		row.resource.text = "%s   %d / %d" % [spec.item_name, current, spec.cost]
		var repaired := GameManager.is_ship_system_repaired(StringName(system_id))
		row.status.text = "OPERATIONAL" if repaired else "DAMAGED"
		row.status.modulate = Color(0.45, 1.0, 0.65) if repaired else Color(1.0, 0.45, 0.24)
		row.button.disabled = repaired
		row.button.text = "REPAIRED" if repaired else "START REPAIR"


func _start_minigame(system_id: String) -> void:
	var spec: Dictionary = SYSTEMS[system_id]
	if GameManager.is_ship_system_repaired(StringName(system_id)):
		feedback.text = "SYSTEM ALREADY OPERATIONAL"
		return
	if GameManager.get_item_count(spec.item) < int(spec.cost):
		feedback.text = "INSUFFICIENT MATERIALS // %s %d REQUIRED" % [spec.item_name, spec.cost]
		return
	selected_system = system_id
	_clear_minigame()
	match system_id:
		"power": _build_power_game()
		"navigation": _build_navigation_game()
		"engine": _build_engine_game()


func _base_minigame(title_text: String, instruction: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	minigame_panel.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", Color(0.42, 0.9, 1.0))
	box.add_child(title)
	var hint := Label.new()
	hint.text = instruction
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	return box


func _build_power_game() -> void:
	feedback.text = "Resources reserved only after successful circuit validation."
	var box := _base_minigame("POWER // CONNECT ENERGY CIRCUIT", "Rotate every circuit node until all cyan conductors face the system core.")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	box.add_child(row)
	circuit_buttons.clear()
	for index in range(4):
		var button := Button.new()
		button.custom_minimum_size = Vector2(100, 76)
		button.add_theme_font_size_override("font_size", 30)
		button.pressed.connect(_rotate_circuit.bind(index))
		row.add_child(button)
		circuit_buttons.append(button)
	_update_circuit_buttons()
	_add_cancel_button(box)


func _rotate_circuit(index: int) -> void:
	circuit_states[index] = (circuit_states[index] + 1) % 4
	_update_circuit_buttons()
	if circuit_states == [1, 1, 1, 1]:
		feedback.text = "POWER CONNECTION STABLE"
		_commit_success()


func _update_circuit_buttons() -> void:
	var glyphs := ["╴", "─", "╶", "│"]
	for index in range(circuit_buttons.size()):
		circuit_buttons[index].text = glyphs[circuit_states[index]]
		circuit_buttons[index].modulate = Color(0.35, 1.0, 0.7) if circuit_states[index] == 1 else Color(0.45, 0.75, 1.0)


func _build_navigation_game() -> void:
	feedback.text = "Align current frequency to target 67 ± 3."
	var box := _base_minigame("NAVIGATION // SIGNAL CALIBRATION", "TARGET WAVEFORM: 67 THz // drag the frequency control, then synchronize.")
	nav_slider = HSlider.new()
	nav_slider.min_value = 0
	nav_slider.max_value = 100
	nav_slider.step = 1
	nav_slider.value = 22
	nav_slider.custom_minimum_size = Vector2(0, 50)
	box.add_child(nav_slider)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(actions)
	var sync := Button.new()
	sync.text = "SYNCHRONIZE SIGNAL"
	sync.custom_minimum_size = Vector2(240, 52)
	sync.pressed.connect(_check_navigation)
	actions.add_child(sync)
	_add_cancel_button(actions)


func _check_navigation() -> void:
	var error := absf(float(nav_slider.value) - 67.0)
	if error <= 3.0:
		feedback.text = "SIGNAL SYNCHRONIZED"
		_commit_success()
	else:
		feedback.text = "SIGNAL DRIFT // CURRENT %02d // ADJUST TOWARD 67" % roundi(nav_slider.value)


func _build_engine_game() -> void:
	feedback.text = "ECHO HINT // Valve A → Valve C → Valve B → Ignition"
	var box := _base_minigame("ENGINE // STARTUP SEQUENCE", "Stabilize the valves in the indicated order. Wrong input safely resets the sequence.")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	engine_progress = 0
	engine_buttons.clear()
	for label in ["VALVE A", "VALVE C", "VALVE B", "IGNITION"]:
		var button := Button.new()
		button.text = label
		button.custom_minimum_size = Vector2(170, 64)
		button.pressed.connect(_engine_input.bind(label))
		row.add_child(button)
		engine_buttons.append(button)
	_add_cancel_button(box)


func _engine_input(value: String) -> void:
	var sequence := ["VALVE A", "VALVE C", "VALVE B", "IGNITION"]
	if value == sequence[engine_progress]:
		engine_buttons[engine_progress].disabled = true
		engine_progress += 1
		feedback.text = "ENGINE SEQUENCE // %d / 4" % engine_progress
		if engine_progress == sequence.size():
			feedback.text = "ENGINE PRESSURE STABLE"
			_commit_success()
	else:
		engine_progress = 0
		for button in engine_buttons:
			button.disabled = false
		feedback.text = "SEQUENCE ERROR // RESET // A → C → B → IGNITION"


func _add_cancel_button(parent: Control) -> void:
	var cancel := Button.new()
	cancel.text = "CANCEL DIAGNOSTIC"
	cancel.custom_minimum_size = Vector2(190, 44)
	cancel.pressed.connect(_cancel_minigame)
	parent.add_child(cancel)


func _commit_success() -> void:
	if selected_system.is_empty():
		return
	var completed := selected_system
	var spec: Dictionary = SYSTEMS[completed]
	if !GameManager.repair_ship_system(StringName(completed), spec.item, int(spec.cost)):
		feedback.text = "RESOURCE CHECK FAILED // INVENTORY CHANGED"
		return
	selected_system = ""
	for node in minigame_panel.get_children():
		node.queue_free()
	_refresh()
	var echo_lines := {
		"power": "Power system restored. Ship power output stabilizing.",
		"navigation": "Navigation restored. Orbital escape trajectory available.",
		"engine": "Engine system restored. Pressure nominal.",
	}
	feedback.text = "ECHO // " + echo_lines[completed]
	if GameManager.are_all_systems_repaired():
		feedback.text += "\nWARNING // Multiple hostile lifeforms approaching the Landing Zone."


func _cancel_minigame() -> void:
	selected_system = ""
	_clear_minigame()
	feedback.text = "DIAGNOSTIC CANCELLED // No resources consumed."


func _clear_minigame() -> void:
	for node in minigame_panel.get_children():
		node.queue_free()
	circuit_states = [0, 2, 3, 0]
	circuit_buttons.clear()
	engine_buttons.clear()


func _close() -> void:
	get_tree().paused = false
	var player := GameManager.player
	if is_instance_valid(player) and player.has_method("set_movement_enabled") and !GameManager.death_in_progress:
		player.set_movement_enabled(true)
	queue_free()
