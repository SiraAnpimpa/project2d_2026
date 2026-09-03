class_name ShipRepairConsole
extends CanvasLayer

const SYSTEMS := {
	"power": {"title": "POWER SYSTEM", "item": &"energy_crystal", "item_name": "ENERGY CRYSTAL", "cost": 3, "icon": "res://Assets/UI/Items/energy_crystal.png"},
	"navigation": {"title": "NAVIGATION SYSTEM", "item": &"circuit_part", "item_name": "CIRCUIT PART", "cost": 2, "icon": "res://Assets/UI/Items/circuit_part.png"},
	"engine": {"title": "ENGINE SYSTEM", "item": &"scrap_metal", "item_name": "SCRAP METAL", "cost": 5, "icon": "res://Assets/UI/Items/scrap_metal.png"},
}
const UPGRADE_SPECS := {
	"damage": {"title": "DAMAGE", "description": "Higher bolt impact damage"},
	"fire_rate": {"title": "FIRE RATE", "description": "Shorter Pulse Rifle cooldown"},
	"energy": {"title": "ENERGY", "description": "Faster, larger overcharged projectiles"},
}
const MATERIAL_NAMES := {
	"alien_biomass": "ALIEN BIOMASS",
	"hardened_carapace": "HARDENED CARAPACE",
	"acid_gland": "ACID GLAND",
	"alien_core": "ALIEN CORE",
}
const STATUS_COLORS := {
	"DAMAGED": Color(1.0, 0.38, 0.22),
	"READY TO REPAIR": Color(0.42, 0.94, 1.0),
	"OPERATIONAL": Color(0.42, 1.0, 0.62),
	"LOCKED": Color(0.46, 0.52, 0.56),
	"MISSING": Color(1.0, 0.62, 0.24),
	"READY TO INSTALL": Color(1.0, 0.82, 0.28),
}

var screen: Control
var console_panel: PanelContainer
var outer_margin: MarginContainer
var header_title: Label
var header_subtitle: Label
var close_button: Button
var navigation: HBoxContainer
var section_tabs: Dictionary = {}
var page_scroll: ScrollContainer
var page_root: VBoxContainer
var gameplay_hud: CanvasLayer
var selected_section := "repair"
var compact_layout := false
var system_rows: Dictionary = {}
var upgrade_rows: Dictionary = {}
var final_core_row: Dictionary = {}
var feedback: Label
var overall_label: Label
var overall_bar: ProgressBar
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
	GameManager.inventory_changed.connect(_on_inventory_changed)
	GameManager.ship_system_changed.connect(_on_ship_system_changed)
	GameManager.final_core_changed.connect(_on_final_core_changed)
	GameManager.weapon_upgrade_changed.connect(_on_weapon_upgrade_changed)
	get_viewport().size_changed.connect(_apply_responsive_layout)
	get_tree().paused = true
	gameplay_hud = get_tree().get_first_node_in_group("GameHUD") as CanvasLayer
	if is_instance_valid(gameplay_hud):
		gameplay_hud.visible = false
	var player := GameManager.player
	if is_instance_valid(player) and player.has_method("set_movement_enabled"):
		player.set_movement_enabled(false)
	_apply_responsive_layout()
	_show_section("repair")
	_apply_responsive_layout()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and !event.is_echo():
		_close()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	screen = Control.new()
	screen.name = "ConsoleScreen"
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.theme = load("res://Scenes/Prefabs/theme.tres")
	add_child(screen)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.008, 0.025, 0.94)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.add_child(dim)

	console_panel = PanelContainer.new()
	console_panel.name = "ConsolePanel"
	console_panel.set_anchors_preset(Control.PRESET_CENTER)
	console_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.add_child(console_panel)
	outer_margin = MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_left", 20)
	outer_margin.add_theme_constant_override("margin_top", 16)
	outer_margin.add_theme_constant_override("margin_right", 20)
	outer_margin.add_theme_constant_override("margin_bottom", 16)
	console_panel.add_child(outer_margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	outer_margin.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	content.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	header_title = Label.new()
	header_title.text = "SHIP CONSOLE"
	header_title.add_theme_font_size_override("font_size", 26)
	header_title.add_theme_color_override("font_color", Color(0.4, 0.92, 1.0))
	heading.add_child(header_title)
	header_subtitle = Label.new()
	header_subtitle.text = "OLETHROS RESTORATION LINK"
	header_subtitle.add_theme_font_size_override("font_size", 13)
	header_subtitle.add_theme_color_override("font_color", Color(0.56, 0.72, 0.8))
	heading.add_child(header_subtitle)
	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "CLOSE  [ESC]"
	close_button.custom_minimum_size = Vector2(142, 48)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_close)
	header.add_child(close_button)

	navigation = HBoxContainer.new()
	navigation.name = "SectionTabs"
	navigation.alignment = BoxContainer.ALIGNMENT_CENTER
	navigation.add_theme_constant_override("separation", 8)
	content.add_child(navigation)
	for section in ["repair", "weapon", "echo"]:
		var tab := Button.new()
		tab.text = {"repair": "SHIP STATUS", "weapon": "WEAPON UPGRADES", "echo": "ECHO LOG"}[section]
		tab.custom_minimum_size = Vector2(0, 46)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.focus_mode = Control.FOCUS_NONE
		tab.pressed.connect(_show_section.bind(section))
		navigation.add_child(tab)
		section_tabs[section] = tab
	content.add_child(HSeparator.new())

	page_scroll = ScrollContainer.new()
	page_scroll.name = "PageScroll"
	page_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page_scroll.follow_focus = true
	content.add_child(page_scroll)
	page_root = VBoxContainer.new()
	page_root.name = "PageContent"
	page_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_root.add_theme_constant_override("separation", 10)
	page_scroll.add_child(page_root)


func _apply_responsive_layout() -> void:
	if console_panel == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var safe_rect := _safe_viewport_rect(viewport_size)
	compact_layout = safe_rect.size.x < 700.0 or safe_rect.size.y < 520.0
	var panel_size := Vector2(
		minf(1050.0, safe_rect.size.x),
		minf(720.0, safe_rect.size.y)
	)
	console_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	console_panel.position = safe_rect.get_center() - panel_size * 0.5
	console_panel.size = panel_size
	var inner_margin := 10 if compact_layout else 20
	outer_margin.add_theme_constant_override("margin_left", inner_margin)
	outer_margin.add_theme_constant_override("margin_top", 10 if compact_layout else 16)
	outer_margin.add_theme_constant_override("margin_right", inner_margin)
	outer_margin.add_theme_constant_override("margin_bottom", 10 if compact_layout else 16)
	header_title.add_theme_font_size_override("font_size", 18 if compact_layout else 26)
	header_subtitle.visible = !compact_layout or viewport_size.x >= 520.0
	close_button.text = "X" if viewport_size.x < 520.0 else "CLOSE  [ESC]"
	close_button.custom_minimum_size = Vector2(48 if viewport_size.x < 520.0 else 142, 44 if compact_layout else 48)
	navigation.add_theme_constant_override("separation", 4 if compact_layout else 8)
	var compact_tab_text := {"repair": "STATUS", "weapon": "UPGRADES", "echo": "ECHO"}
	var full_tab_text := {"repair": "SHIP STATUS", "weapon": "WEAPON UPGRADES", "echo": "ECHO LOG"}
	for section in section_tabs:
		var tab: Button = section_tabs[section]
		tab.text = compact_tab_text[section] if compact_layout else full_tab_text[section]
		tab.custom_minimum_size.y = 42 if compact_layout else 46
		tab.add_theme_font_size_override("font_size", 13 if compact_layout else 16)
	var current_page_title := page_root.get_node_or_null("PageTitle") as Label
	if current_page_title != null:
		current_page_title.add_theme_font_size_override("font_size", 18 if compact_layout else 22)


func _safe_viewport_rect(viewport_size: Vector2) -> Rect2:
	var safe_rect := Rect2(Vector2.ZERO, viewport_size)
	if get_viewport() == get_tree().root:
		var screen_size := Vector2(DisplayServer.screen_get_size())
		var display_safe := DisplayServer.get_display_safe_area()
		if screen_size.x > 0.0 and screen_size.y > 0.0 and display_safe.size.x > 0 and display_safe.size.y > 0:
			var scale := viewport_size / screen_size
			safe_rect = Rect2(Vector2(display_safe.position) * scale, Vector2(display_safe.size) * scale)
	return safe_rect.grow(-16.0)


func _show_section(section: String) -> void:
	selected_section = "repair" if section == "status" else section
	selected_system = ""
	_clear_page()
	match selected_section:
		"weapon": _build_weapon_page()
		"echo": _build_echo_page()
		_: _build_repair_page()


func _clear_page() -> void:
	for child in page_root.get_children():
		page_root.remove_child(child)
		child.queue_free()
	system_rows.clear()
	upgrade_rows.clear()
	final_core_row.clear()
	feedback = null
	overall_label = null
	overall_bar = null
	minigame_panel = null
	circuit_buttons.clear()
	engine_buttons.clear()
	nav_slider = null


func _page_title(text: String, color := Color(0.48, 0.92, 1.0)) -> Label:
	var label := Label.new()
	label.name = "PageTitle"
	label.text = text
	label.add_theme_font_size_override("font_size", 18 if compact_layout else 22)
	label.add_theme_color_override("font_color", color)
	page_root.add_child(label)
	return label


func _make_feedback() -> Label:
	var label := Label.new()
	label.custom_minimum_size.y = 38
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.66, 0.86, 0.94))
	page_root.add_child(label)
	return label


func _build_repair_page() -> void:
	_page_title("SHIP STATUS")
	var overall := VBoxContainer.new()
	overall.add_theme_constant_override("separation", 12)
	page_root.add_child(overall)
	overall_label = Label.new()
	overall_label.custom_minimum_size.x = 0
	overall_label.add_theme_font_size_override("font_size", 18)
	overall.add_child(overall_label)
	overall_bar = ProgressBar.new()
	overall_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overall_bar.custom_minimum_size.y = 22
	overall_bar.show_percentage = true
	overall.add_child(overall_bar)
	feedback = _make_feedback()
	feedback.text = "Select a ready system to begin repair. Resources are spent only after success."
	minigame_panel = PanelContainer.new()
	minigame_panel.custom_minimum_size.y = 190
	minigame_panel.visible = false
	page_root.add_child(minigame_panel)
	for system_id in SYSTEMS:
		var spec: Dictionary = SYSTEMS[system_id]
		system_rows[system_id] = _add_system_card(system_id, spec.title, load(spec.icon), _start_minigame.bind(system_id))
	final_core_row = _add_system_card("final_core", "FINAL LAUNCH CORE", _final_core_texture(), _install_final_core)
	_refresh()


func _add_system_card(system_id: String, title: String, icon_texture: Texture2D, action: Callable) -> Dictionary:
	var card := PanelContainer.new()
	card.name = system_id.capitalize().replace(" ", "") + "Card"
	page_root.add_child(card)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 9)
	card.add_child(margin)
	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 8)
	margin.add_child(card_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card_box.add_child(row)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(58, 58)
	icon.texture = icon_texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 2)
	row.add_child(details)
	var name_label := Label.new()
	name_label.text = title
	name_label.add_theme_font_size_override("font_size", 18)
	details.add_child(name_label)
	var status := Label.new()
	status.add_theme_font_size_override("font_size", 14)
	details.add_child(status)
	var resource := Label.new()
	resource.add_theme_font_size_override("font_size", 14)
	resource.add_theme_color_override("font_color", Color(0.72, 0.84, 0.9))
	details.add_child(resource)
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	card_box.add_child(button)
	return {"resource": resource, "status": status, "button": button, "icon": icon}


func _final_core_texture() -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://Assets/Gameplay/Items/alien_upgrade_materials.png")
	atlas.region = Rect2(910, 269, 344, 651)
	return atlas


func _build_weapon_page() -> void:
	_page_title("PULSE RIFLE // WEAPON UPGRADES", Color(0.55, 1.0, 0.72))
	var stock := Label.new()
	stock.text = _material_stock_text()
	stock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stock.add_theme_color_override("font_color", Color(0.68, 0.82, 0.9))
	page_root.add_child(stock)
	for category in UPGRADE_SPECS:
		var spec: Dictionary = UPGRADE_SPECS[category]
		var card := PanelContainer.new()
		page_root.add_child(card)
		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_top", 9)
		margin.add_theme_constant_override("margin_right", 14)
		margin.add_theme_constant_override("margin_bottom", 9)
		card.add_child(margin)
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		margin.add_child(row)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)
		var name_label := Label.new()
		name_label.text = spec.title
		name_label.add_theme_font_size_override("font_size", 19)
		details.add_child(name_label)
		var description := Label.new()
		description.text = spec.description
		description.add_theme_font_size_override("font_size", 13)
		description.add_theme_color_override("font_color", Color(0.65, 0.75, 0.82))
		details.add_child(description)
		var level_label := Label.new()
		details.add_child(level_label)
		var requirements := Label.new()
		requirements.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		requirements.add_theme_color_override("font_color", Color(0.72, 0.86, 0.92))
		details.add_child(requirements)
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 50)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_purchase_upgrade.bind(category))
		row.add_child(button)
		upgrade_rows[category] = {"level": level_label, "requirements": requirements, "button": button}
	feedback = _make_feedback()
	feedback.text = "Upgrades immediately change live weapon damage, fire rate, and projectile energy."
	_refresh_weapon_rows()


func _build_echo_page() -> void:
	_page_title("ECHO // MISSION LOG", Color(0.62, 0.85, 1.0))
	var log := Label.new()
	log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log.custom_minimum_size.y = 260
	log.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	log.add_theme_font_size_override("font_size", 17)
	if GameManager.final_core_installed:
		log.text = "Launch system operational. Escape trajectory confirmed.\n\nAll mission-critical systems report ready."
	elif GameManager.get_item_count(&"final_core") > 0:
		log.text = "The recovered core is compatible with the launch system.\n\nReturn here and install it."
	elif GameManager.boss_arena_entered:
		log.text = "Energy source located. Extremely large biological signature confirmed."
	elif GameManager.hive_entered:
		log.text = "Hive pressure is severe. Powerful organisms may yield emergency medical supplies."
	elif GameManager.are_all_systems_repaired():
		log.text = "Primary systems restored. The original launch core is beyond repair.\n\nA compatible energy signature lies beneath the abandoned sector."
	else:
		log.text = "Restore the three primary ship systems. Hostile organisms provide renewable weapon materials."
	page_root.add_child(log)
	feedback = _make_feedback()
	feedback.text = "CURRENT OBJECTIVE // %s" % GameManager.current_objective


func _refresh() -> void:
	if selected_section != "repair" or overall_label == null:
		return
	var restored := GameManager.repaired_system_count() + (1 if GameManager.final_core_installed else 0)
	overall_label.text = "SHIP RESTORATION\n%d / 4 SYSTEMS RESTORED" % restored
	overall_bar.value = float(restored) * 25.0
	for system_id in SYSTEMS:
		var spec: Dictionary = SYSTEMS[system_id]
		var row: Dictionary = system_rows[system_id]
		var current := GameManager.get_item_count(spec.item)
		var repaired := GameManager.is_ship_system_repaired(StringName(system_id))
		var ready := current >= int(spec.cost)
		var state := "OPERATIONAL" if repaired else ("READY TO REPAIR" if ready else "DAMAGED")
		row.resource.text = "%s  %d / %d" % [spec.item_name, current, spec.cost]
		row.status.text = "STATUS  ·  " + state
		row.status.add_theme_color_override("font_color", STATUS_COLORS[state])
		row.button.disabled = repaired or !ready
		row.button.text = "✓  REPAIRED" if repaired else ("START REPAIR" if ready else "NEED %d MORE" % (int(spec.cost) - current))
	_refresh_final_core_row()


func _refresh_final_core_row() -> void:
	if final_core_row.is_empty():
		return
	var has_core := GameManager.get_item_count(&"final_core") > 0
	var state := "OPERATIONAL" if GameManager.final_core_installed else ("READY TO INSTALL" if has_core else "MISSING")
	final_core_row.resource.text = "FINAL CORE  %d / 1" % GameManager.get_item_count(&"final_core")
	final_core_row.status.text = "STATUS  ·  " + state
	final_core_row.status.add_theme_color_override("font_color", STATUS_COLORS[state])
	final_core_row.button.disabled = GameManager.final_core_installed or !has_core
	final_core_row.button.text = "✓  INSTALLED" if GameManager.final_core_installed else ("INSTALL CORE" if has_core else "LOCKED")


func _refresh_weapon_rows() -> void:
	if selected_section != "weapon":
		return
	for category in UPGRADE_SPECS:
		var row: Dictionary = upgrade_rows[category]
		var level := GameManager.get_weapon_upgrade_level(StringName(category))
		row.level.text = "LEVEL %d / %d" % [level, GameManager.WEAPON_UPGRADE_MAX_LEVEL]
		if level >= GameManager.WEAPON_UPGRADE_MAX_LEVEL:
			row.requirements.text = "Peak calibration reached"
			row.button.text = "MAX LEVEL"
			row.button.disabled = true
			continue
		var cost := GameManager.get_next_weapon_upgrade_cost(StringName(category))
		row.requirements.text = _format_cost(cost)
		var affordable := GameManager.can_afford(cost)
		row.button.text = "UPGRADE" if affordable else "NEED MATERIALS"
		row.button.disabled = !affordable


func _format_cost(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for item_id in cost:
		parts.append("%s  %d / %d" % [MATERIAL_NAMES.get(item_id, String(item_id).to_upper()), GameManager.get_item_count(StringName(item_id)), int(cost[item_id])])
	return "  ·  ".join(parts)


func _material_stock_text() -> String:
	return "BIOMASS %d  ·  CARAPACE %d  ·  ACID GLAND %d  ·  ALIEN CORE %d" % [
		GameManager.get_item_count(&"alien_biomass"),
		GameManager.get_item_count(&"hardened_carapace"),
		GameManager.get_item_count(&"acid_gland"),
		GameManager.get_item_count(&"alien_core"),
	]


func _purchase_upgrade(category: String) -> void:
	if GameManager.purchase_weapon_upgrade(StringName(category)):
		feedback.text = "%s UPGRADED // LEVEL %d" % [UPGRADE_SPECS[category].title, GameManager.get_weapon_upgrade_level(StringName(category))]
		_refresh_weapon_rows()
	else:
		feedback.text = "UPGRADE FAILED // CHECK MATERIALS OR MAX LEVEL"


func _install_final_core() -> void:
	if GameManager.install_final_core():
		_refresh()
		feedback.text = "FINAL LAUNCH CORE INSTALLED // LAUNCH SYSTEM OPERATIONAL"
	else:
		feedback.text = "INSTALLATION LOCKED // RECOVER CORE AND RESTORE PRIMARY SYSTEMS"


func _start_minigame(system_id: String) -> void:
	if selected_section != "repair":
		_show_section("repair")
	var spec: Dictionary = SYSTEMS[system_id]
	if GameManager.is_ship_system_repaired(StringName(system_id)):
		feedback.text = "SYSTEM ALREADY OPERATIONAL"
		return
	if GameManager.get_item_count(spec.item) < int(spec.cost):
		feedback.text = "INSUFFICIENT MATERIALS // %s %d REQUIRED" % [spec.item_name, spec.cost]
		return
	selected_system = system_id
	_clear_minigame()
	minigame_panel.visible = true
	match system_id:
		"power": _build_power_game()
		"navigation": _build_navigation_game()
		"engine": _build_engine_game()


func _base_minigame(title_text: String, instruction: String) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	minigame_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.42, 0.9, 1.0))
	box.add_child(title)
	var hint := Label.new()
	hint.text = instruction
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	return box


func _build_power_game() -> void:
	feedback.text = "Resources commit only after circuit validation."
	var box := _base_minigame("POWER // CONNECT ENERGY CIRCUIT", "Rotate every conductor to the horizontal position.")
	var row := GridContainer.new()
	row.columns = 4
	row.add_theme_constant_override("h_separation", 8)
	box.add_child(row)
	circuit_buttons.clear()
	for index in range(4):
		var button := Button.new()
		button.custom_minimum_size = Vector2(58, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 26)
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
	var box := _base_minigame("NAVIGATION // SIGNAL CALIBRATION", "TARGET WAVEFORM: 67 THz")
	nav_slider = HSlider.new()
	nav_slider.min_value = 0
	nav_slider.max_value = 100
	nav_slider.step = 1
	nav_slider.value = 22
	nav_slider.custom_minimum_size = Vector2(0, 46)
	box.add_child(nav_slider)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)
	var sync := Button.new()
	sync.text = "SYNCHRONIZE SIGNAL"
	sync.custom_minimum_size = Vector2(0, 48)
	sync.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	feedback.text = "VALVE ORDER // A → C → B → IGNITION"
	var box := _base_minigame("ENGINE // STARTUP SEQUENCE", "Wrong input safely resets the sequence.")
	var row := GridContainer.new()
	row.columns = 2
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	box.add_child(row)
	engine_progress = 0
	engine_buttons.clear()
	for label in ["VALVE A", "VALVE C", "VALVE B", "IGNITION"]:
		var button := Button.new()
		button.text = label
		button.custom_minimum_size = Vector2(120, 50)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		feedback.text = "SEQUENCE RESET // A → C → B → IGNITION"


func _add_cancel_button(parent: Control) -> void:
	var cancel := Button.new()
	cancel.text = "CANCEL DIAGNOSTIC"
	cancel.custom_minimum_size = Vector2(0, 44)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	_clear_minigame()
	_refresh()
	feedback.text = "%s RESTORED // SYSTEM OPERATIONAL" % spec.title
	if GameManager.are_all_systems_repaired():
		feedback.text = "PRIMARY SYSTEMS RESTORED // FINAL LAUNCH CORE STILL MISSING"


func _cancel_minigame() -> void:
	selected_system = ""
	_clear_minigame()
	feedback.text = "DIAGNOSTIC CANCELLED // NO RESOURCES CONSUMED"


func _clear_minigame() -> void:
	if minigame_panel != null:
		for node in minigame_panel.get_children():
			node.queue_free()
		minigame_panel.visible = false
	circuit_states = [0, 2, 3, 0]
	circuit_buttons.clear()
	engine_buttons.clear()


func _on_inventory_changed(_item_id: StringName, _amount: int) -> void:
	if selected_section == "repair":
		_refresh()
	elif selected_section == "weapon":
		_refresh_weapon_rows()


func _on_ship_system_changed(_system_id: StringName, _repaired: bool) -> void:
	_refresh()


func _on_final_core_changed(_collected: bool, _installed: bool) -> void:
	_refresh()


func _on_weapon_upgrade_changed(_category: StringName, _level: int) -> void:
	_refresh_weapon_rows()


func _close() -> void:
	get_tree().paused = false
	if is_instance_valid(gameplay_hud):
		gameplay_hud.visible = true
	var player := GameManager.player
	if is_instance_valid(player) and player.has_method("set_movement_enabled") and !GameManager.death_in_progress:
		player.set_movement_enabled(true)
	queue_free()
