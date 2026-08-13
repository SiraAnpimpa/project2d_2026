extends Node

const LANDING_SCENE := preload("res://Scenes/Levels/zone_67_prologue.tscn")


func _ready() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	GameManager.landing_intro_seen = false
	GameManager.loading_save = false
	GameManager.pending_spawn = &""
	var first_visit = LANDING_SCENE.instantiate()
	add_child(first_visit)
	await get_tree().process_frame
	if !first_visit.intro_sequence.visible:
		_fail("Transmission did not appear on a new game")
		return
	first_visit._finish_intro(false)
	if !GameManager.landing_intro_seen:
		_fail("Completing the Transmission did not persist its state")
		return
	first_visit.queue_free()
	await get_tree().process_frame

	GameManager.pending_spawn = &"FromCrystal"
	var return_visit = LANDING_SCENE.instantiate()
	add_child(return_visit)
	await get_tree().process_frame
	if return_visit.intro_sequence.visible:
		_fail("Transmission appeared again after returning to Landing Zone")
		return
	if !return_visit.player.movement_enabled:
		_fail("Player stayed locked when returning to Landing Zone")
		return
	return_visit.queue_free()
	await get_tree().process_frame

	GameManager.landing_intro_seen = true
	GameManager.loading_save = true
	GameManager.pending_spawn = &""
	var loaded_visit = LANDING_SCENE.instantiate()
	add_child(loaded_visit)
	await get_tree().process_frame
	if loaded_visit.intro_sequence.visible:
		_fail("Transmission appeared again after loading a completed intro save")
		return
	loaded_visit.queue_free()
	await get_tree().process_frame

	GameManager.landing_intro_seen = true
	GameManager.reset_new_game_state()
	if GameManager.landing_intro_seen:
		_fail("Starting a new game did not reset the Transmission")
		return

	print("LANDING_INTRO_TEST: PASS")
	get_tree().quit()


func _fail(message: String) -> void:
	push_error("LANDING_INTRO_TEST: " + message)
	get_tree().paused = false
	get_tree().quit(1)
