extends Node

const PLAYER := preload("res://Scenes/Actors/top_down_player.tscn")
const HUD := preload("res://Scenes/Levels/game_ui.tscn")
const CRAWLER := preload("res://Scenes/Actors/alien_crawler.tscn")
const CONSOLE := preload("res://Scenes/Gameplay/ship_repair_console.tscn")


class TestInteractable:
	extends Interactable
	var interaction_count := 0

	func _ready() -> void:
		super._ready()
		prompt = "E - INTERACT // TERMINAL"

	func interact(_player: Node2D) -> void:
		interaction_count += 1


func _ready() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	GameManager.reset_new_game_state()
	var player := PLAYER.instantiate() as TopDownPlayer
	add_child(player)
	var hud = HUD.instantiate()
	add_child(hud)
	await get_tree().process_frame
	await get_tree().physics_frame

	if player.move_speed > 170.0 or !is_equal_approx(player.astronaut.scale.x, 0.32):
		return _fail("Player pacing or visual scale revision is missing")
	if FileAccess.file_exists("res://Scenes/Levels/aim_joystick.gd") or hud.has_node("GameUI/AimShootJoystick"):
		return _fail("Right aim analog code or UI still exists")
	var joystick := hud.get_node("GameUI/MovementJoystick") as MovementJoystick
	var fire_button := hud.get_node("GameUI/FireButton") as Button
	var interact_button := hud.get_node("GameUI/InteractButton") as Button
	var medkit_button := hud.get_node("GameUI/MedKitButton") as Button
	if joystick == null or fire_button == null or interact_button == null or medkit_button == null:
		return _fail("FIRE / INTERACT / MEDKIT / movement controls are incomplete")
	if "FIRE" not in fire_button.text or "INTERACT" not in interact_button.text or "MEDKIT" not in medkit_button.text:
		return _fail("Mobile buttons are missing readable text labels")

	joystick._send_direction(Vector2(0.8, -0.2))
	await get_tree().physics_frame
	if player.mobile_move_direction.length() < 0.5 or player.mobile_firing:
		return _fail("Movement joystick did not stay isolated to movement")
	if !get_tree().get_nodes_in_group("PlayerProjectile").is_empty():
		return _fail("Movement joystick caused a projectile")
	joystick._send_direction(Vector2.ZERO)

	var empty_touch := InputEventScreenTouch.new()
	empty_touch.index = 7
	empty_touch.position = Vector2(500, 300)
	empty_touch.pressed = true
	Input.parse_input_event(empty_touch)
	await get_tree().physics_frame
	empty_touch.pressed = false
	Input.parse_input_event(empty_touch)
	if !get_tree().get_nodes_in_group("PlayerProjectile").is_empty():
		return _fail("Generic gameplay touch caused firing")

	var enemy := CRAWLER.instantiate() as AlienEnemy
	add_child(enemy)
	enemy.global_position = player.global_position + Vector2(500, 0)
	await get_tree().physics_frame
	hud._on_fire_button_down()
	await get_tree().physics_frame
	if !player.mobile_firing or get_tree().get_nodes_in_group("PlayerProjectile").is_empty():
		return _fail("Dedicated FIRE button did not fire")
	if player.aim_direction.dot(Vector2.RIGHT) < 0.8:
		return _fail("Mobile FIRE did not auto-aim at the nearest hostile")
	await get_tree().create_timer(0.28).timeout
	var held_count := get_tree().get_nodes_in_group("PlayerProjectile").size()
	if held_count < 2:
		return _fail("Holding FIRE did not respect continuous weapon fire")
	hud._on_fire_button_up()
	await get_tree().create_timer(0.24).timeout
	if player.mobile_firing or get_tree().get_nodes_in_group("PlayerProjectile").size() > held_count:
		return _fail("Releasing FIRE did not stop continuous fire")

	var terminal := TestInteractable.new()
	terminal.global_position = player.global_position
	add_child(terminal)
	await get_tree().process_frame
	player._scan_interactables()
	if !interact_button.visible or "TERMINAL" not in interact_button.text:
		return _fail("Contextual mobile INTERACT did not identify the terminal")
	hud._on_interact_button_down()
	if terminal.interaction_count != 1:
		return _fail("Mobile INTERACT did not call the shared interaction path")

	GameManager.hp = 9
	GameManager.add_item(&"med_kit", 1)
	var projectiles_before_medkit := get_tree().get_nodes_in_group("PlayerProjectile").size()
	hud._on_med_kit_pressed()
	if GameManager.hp != GameManager.max_hp or GameManager.get_item_count(&"med_kit") != 0:
		return _fail("Med Kit did not fully heal and consume exactly one item")
	if get_tree().get_nodes_in_group("PlayerProjectile").size() != projectiles_before_medkit:
		return _fail("Med Kit button caused a projectile")
	GameManager.add_item(&"med_kit", 1)
	hud._on_med_kit_pressed()
	if GameManager.get_item_count(&"med_kit") != 1:
		return _fail("Med Kit was consumed while HP was already full")

	var accepted: bool = hud.queue_notification("PICKUP", "PICKUP", "+1 TEST", 2.0, 0, "duplicate-test")
	var duplicate: bool = hud.queue_notification("PICKUP", "PICKUP", "+1 TEST", 2.0, 0, "duplicate-test")
	if !accepted or duplicate:
		return _fail("Notification duplicate suppression failed")
	if fire_button.get_global_rect().intersects(medkit_button.get_global_rect()) or joystick.get_global_rect().intersects(interact_button.get_global_rect()):
		return _fail("Mobile safe-area controls overlap")

	var compact_view := SubViewport.new()
	compact_view.size = Vector2i(640, 360)
	add_child(compact_view)
	var compact_hud = HUD.instantiate()
	compact_view.add_child(compact_hud)
	await get_tree().process_frame
	compact_hud.set_interaction_prompt("E - INTERACT // SHIP")
	var compact_fire: Button = compact_hud.get_node("GameUI/FireButton")
	var compact_interact: Button = compact_hud.get_node("GameUI/InteractButton")
	var compact_medkit: Button = compact_hud.get_node("GameUI/MedKitButton")
	var compact_joystick: Control = compact_hud.get_node("GameUI/MovementJoystick")
	var compact_size := Vector2(compact_view.size)
	for control in [compact_fire, compact_interact, compact_medkit, compact_joystick]:
		var rect: Rect2 = control.get_global_rect()
		if rect.position.x < 0.0 or rect.position.y < 0.0 or rect.end.x > compact_size.x or rect.end.y > compact_size.y:
			return _fail("A mobile control escaped the 640x360 safe area")
	if compact_fire.get_global_rect().intersects(compact_medkit.get_global_rect()) or compact_joystick.get_global_rect().intersects(compact_interact.get_global_rect()):
		return _fail("Compact phone layout has overlapping actions")
	if compact_hud.get_node("GameUI/ItemBelt").visible:
		return _fail("Compact phone layout did not reduce non-critical HUD density")
	compact_view.queue_free()
	await get_tree().process_frame

	var console_view := SubViewport.new()
	console_view.size = Vector2i(640, 360)
	add_child(console_view)
	var console := CONSOLE.instantiate() as ShipRepairConsole
	console_view.add_child(console)
	await get_tree().process_frame
	if console.console_panel.size.x > 608.0 or console.console_panel.size.y > 336.0:
		return _fail("Ship console does not fit a 640x360 phone viewport")
	if !(console.page_root.get_parent() is ScrollContainer):
		return _fail("Ship console does not provide vertical scrolling on mobile")
	console._close()
	await get_tree().process_frame
	console_view.queue_free()

	print("MOBILE_POLISH_TEST: PASS")
	get_tree().quit()


func _fail(message: String) -> void:
	push_error("MOBILE_POLISH_TEST: " + message)
	get_tree().paused = false
	get_tree().quit(1)
