extends Node2D

const MAP_BOUNDS := Rect2(-836.0, -470.5, 1672.0, 941.0)

const STORY_BEATS: Array[Dictionary] = [
	{
		'tag': 'SHIP LOG // SYSTEM FAILURE',
		'title': 'ความขัดข้องกลางอวกาศ',
		'body': 'ระหว่างเดินทาง ยานของนักบินอวกาศเกิดความขัดข้องอย่างไร้สาเหตุ\nระบบขับเคลื่อนและระบบนำทางเสียหาย จนต้องหาจุดลงจอดฉุกเฉิน'
	},
	{
		'tag': 'EMERGENCY PROTOCOL // TRANSMITTING',
		'title': 'สัญญาณขอลงจอด',
		'body': 'นักบินส่งคำขอลงจอดฉุกเฉินไปยังดาวเคราะห์ที่ใกล้ที่สุด\nท่ามกลางความเงียบ ระบบสื่อสารยังคงรอคำตอบที่อาจไม่มีวันมาถึง'
	},
	{
		'tag': 'UNKNOWN SOURCE // SIGNAL RECEIVED',
		'title': 'คำตอบจาก Zone-67',
		'body': 'หลังจากรออยู่ครู่หนึ่ง สัญญาณปริศนาก็ตอบกลับมาเพียงข้อความเดียว\n\nอนุญาตให้ลงจอดที่ Zone-67\n\nไม่มีชื่อผู้ส่ง และไม่พบข้อมูลของฐานแห่งนี้ในระบบนำทาง'
	},
	{
		'tag': 'ZONE-67 // TOUCHDOWN CONFIRMED',
		'title': 'การลงจอดครั้งสุดท้าย',
		'body': 'เมื่อยานแตะพื้น นักบินกลับไม่พบผู้คนหรือผู้ที่ส่งสัญญาณตอบรับ\nมีเพียงความเงียบของฐานร้าง และต้นทางสัญญาณที่ยังไม่ทราบตำแหน่ง\n\nขั้นแรกคือต้องออกสำรวจและหาคำตอบว่าใครเป็นผู้อนุญาตให้ลงจอด'
	}
]

@onready var player: TopDownPlayer = %Player
@onready var hud = $UserInterface
@onready var intro_sequence: CanvasLayer = $IntroSequence
@onready var transmission_label: Label = %TransmissionLabel
@onready var story_tag: Label = %StoryTag
@onready var story_title: Label = %StoryTitle
@onready var story_body: Label = %StoryBody
@onready var continue_button: Button = %ContinueButton
@onready var story_panel: PanelContainer = $IntroSequence/Screen/Center/StoryPanel
@onready var story_margin: MarginContainer = $IntroSequence/Screen/Center/StoryPanel/Margin
@onready var story_content: VBoxContainer = $IntroSequence/Screen/Center/StoryPanel/Margin/Content
@onready var story_header: HBoxContainer = $IntroSequence/Screen/Center/StoryPanel/Margin/Content/Header
@onready var story_protocol: Label = $IntroSequence/Screen/Center/StoryPanel/Margin/Content/Header/Protocol
@onready var story_footer: HBoxContainer = $IntroSequence/Screen/Center/StoryPanel/Margin/Content/Footer
@onready var story_hint: Label = $IntroSequence/Screen/Center/StoryPanel/Margin/Content/Footer/Hint

var story_scroll: ScrollContainer

var story_index := 0


func _ready() -> void:
	_build_responsive_story_body()
	get_viewport().size_changed.connect(_apply_intro_responsive_layout)
	_apply_intro_responsive_layout()
	GameManager.current_level = scene_file_path
	GameManager.player = player
	player.set_camera_limits(MAP_BOUNDS)
	var default_spawn: Vector2 = $SpawnPoints/Default.global_position
	var loaded_from_save: bool = GameManager.loading_save
	if loaded_from_save:
		player.global_position = GameManager.save_player_position
		GameManager.save_player_position = Vector2.ZERO
	if !GameManager.pending_spawn.is_empty():
		var marker := get_node_or_null("SpawnPoints/" + String(GameManager.pending_spawn)) as Marker2D
		if marker != null:
			player.global_position = marker.global_position
			default_spawn = marker.global_position
		GameManager.pending_spawn = &""
	player.set_respawn_position(default_spawn)
	GameManager.loading_save = false
	GameManager.spawn_saved_drops_for_current_level()

	player.set_movement_enabled(false)
	hud.set_objective('รอระบบลงจอดดำเนินการเสร็จสิ้น', 'PWR 00%  •  NAV 00%  •  ENG 00%')
	_show_story_beat()

	if GameManager.landing_intro_seen or '--skip-intro' in OS.get_cmdline_user_args():
		_finish_intro(false)
	else:
		continue_button.grab_focus()


func _build_responsive_story_body() -> void:
	story_content.remove_child(story_body)
	story_scroll = ScrollContainer.new()
	story_scroll.name = "StoryScroll"
	story_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	story_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	story_scroll.follow_focus = true
	story_content.add_child(story_scroll)
	story_content.move_child(story_scroll, story_footer.get_index())
	story_body.custom_minimum_size = Vector2.ZERO
	story_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	story_scroll.add_child(story_body)


func _apply_intro_responsive_layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var compact := viewport_size.x < 700.0 or viewport_size.y < 520.0
	var narrow := viewport_size.x < 520.0
	var safe := 12.0 if compact else 24.0
	var center := $IntroSequence/Screen/Center as CenterContainer
	center.offset_left = safe
	center.offset_top = safe
	center.offset_right = -safe
	center.offset_bottom = -safe
	story_panel.custom_minimum_size = Vector2(
		maxf(280.0, minf(820.0, viewport_size.x - safe * 2.0)),
		maxf(260.0, minf(476.0, viewport_size.y - safe * 2.0))
	)
	var inner_x := 14 if compact else 42
	var inner_y := 12 if compact else 30
	story_margin.add_theme_constant_override("margin_left", inner_x)
	story_margin.add_theme_constant_override("margin_top", inner_y)
	story_margin.add_theme_constant_override("margin_right", inner_x)
	story_margin.add_theme_constant_override("margin_bottom", inner_y)
	story_content.add_theme_constant_override("separation", 8 if compact else 14)
	story_protocol.visible = !narrow
	story_header.add_theme_constant_override("separation", 8)
	story_title.add_theme_font_size_override("font_size", 23 if compact else 30)
	story_body.add_theme_font_size_override("font_size", 15 if compact else 18)
	story_tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_hint.visible = !compact or (viewport_size.x >= 620.0 and viewport_size.y >= 420.0)
	continue_button.custom_minimum_size = Vector2(0 if narrow else 184, 48 if compact else 52)
	continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if narrow else Control.SIZE_SHRINK_END


func _unhandled_input(event: InputEvent) -> void:
	if intro_sequence.visible and event.is_action_pressed('ui_accept') and !event.is_echo():
		_advance_story()
		get_viewport().set_input_as_handled()


func _show_story_beat() -> void:
	var beat: Dictionary = STORY_BEATS[story_index]
	transmission_label.text = 'TRANSMISSION %02d / %02d' % [story_index + 1, STORY_BEATS.size()]
	story_tag.text = beat['tag']
	story_title.text = beat['title']
	story_body.text = beat['body']
	continue_button.text = 'เริ่มสำรวจ' if story_index == STORY_BEATS.size() - 1 else 'ถัดไป'
	if story_index == 2:
		AudioManager.play_radio_transmission()
	elif story_index == STORY_BEATS.size() - 1:
		AudioManager.stop_radio_transmission()
		AudioManager.play_ship_flyby()


func _on_continue_button_pressed() -> void:
	_advance_story()


func _advance_story() -> void:
	if story_index < STORY_BEATS.size() - 1:
		story_index += 1
		_show_story_beat()
	else:
		_finish_intro()


func _finish_intro(show_alert: bool = true) -> void:
	GameManager.landing_intro_seen = true
	AudioManager.stop_radio_transmission()
	intro_sequence.visible = false
	player.set_movement_enabled(true)
	hud.set_objective(GameManager.current_objective, GameManager.current_objective_details)
	if show_alert:
		hud.alert('ECHO // Inspect the damaged ship')
