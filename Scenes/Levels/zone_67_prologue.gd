extends Node2D

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

var story_index := 0


func _ready() -> void:
	GameManager.current_level = scene_file_path
	GameManager.player = player
	player.set_camera_limits(Rect2(-1254, -1254, 2508, 2508))
	var loaded_from_save: bool = GameManager.loading_save
	if loaded_from_save:
		player.global_position = GameManager.save_player_position
		GameManager.save_player_position = Vector2.ZERO
	if !GameManager.pending_spawn.is_empty():
		if GameManager.pending_spawn == &"FromCrystal":
			player.global_position = Vector2(1050, -627)
		GameManager.pending_spawn = &""
	player.set_respawn_position(Vector2(-700, 690))
	GameManager.loading_save = false
	GameManager.spawn_saved_drops_for_current_level()

	player.set_movement_enabled(false)
	hud.set_objective('รอระบบลงจอดดำเนินการเสร็จสิ้น', 'PWR 00%  •  NAV 00%  •  ENG 00%')
	_show_story_beat()

	if GameManager.landing_intro_seen or '--skip-intro' in OS.get_cmdline_user_args():
		_finish_intro(false)
	else:
		continue_button.grab_focus()


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
	intro_sequence.visible = false
	player.set_movement_enabled(true)
	hud.set_objective(
		'สำรวจจุดลงจอดและตรวจสอบต้นทางสัญญาณ',
		'PWR 00%  •  NAV 00%  •  ENG 00%'
	)
	if show_alert:
		hud.alert('SHIP AI // เริ่มสำรวจ Zone-67')
