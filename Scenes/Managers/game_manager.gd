extends Node

signal health_changed(current: int, maximum: int)
signal salvage_changed(amount: int)
signal salvage_dropped(amount: int, world_position: Vector2)
signal player_respawned
signal inventory_changed(item_id: StringName, amount: int)
signal ship_system_changed(system_id: StringName, repaired: bool)
signal objective_changed(title: String, details: String)
signal final_defense_started
signal final_defense_completed

const SALVAGE_DROP_SCENE: PackedScene = preload("res://Scenes/Prefabs/salvage_drop.tscn")
const INVENTORY_ITEM_IDS: PackedStringArray = [
	"scrap_metal",
	"energy_crystal",
	"circuit_part",
	"med_kit",
	"access_card",
	"data_log",
]

var salvage: int = 0
var hp: int = 100
var max_hp: int = 100

var sfx_on := true
var music_on := true
var fullscreen_on := false

var player: Node2D = null
var current_level := "res://Scenes/Levels/zone_67_prologue.tscn"
var save_path := "user://game.save"
var save_player_position := Vector2.ZERO
var loading_save := false
var death_in_progress := false
var pending_spawn: StringName = &""
var landing_intro_seen := false
var unknown_ai_contacted := false
var final_defense_active := false
var final_defense_done := false
var ship_systems: Dictionary = {
	"power": false,
	"navigation": false,
	"engine": false,
}
var current_objective := "Inspect the damaged ship"
var current_objective_details := "LANDING ZONE // E - INTERACT"

var dropped_salvage: Array[Dictionary] = []
var next_drop_id := 1
var inventory: Dictionary = {
	"scrap_metal": 0,
	"energy_crystal": 0,
	"circuit_part": 0,
	"med_kit": 0,
	"access_card": 0,
	"data_log": 0,
}
var collected_pickups: Dictionary = {}


func add_salvage(value: int = 1) -> void:
	salvage = maxi(salvage + value, 0)
	salvage_changed.emit(salvage)


func add_item(item_id: StringName, value: int = 1) -> bool:
	var key := String(item_id)
	if !inventory.has(key):
		return false
	inventory[key] = maxi(int(inventory[key]) + value, 0)
	inventory_changed.emit(item_id, int(inventory[key]))
	return true


func get_item_count(item_id: StringName) -> int:
	return int(inventory.get(String(item_id), 0))


func spend_item(item_id: StringName, amount: int) -> bool:
	var key := String(item_id)
	if amount <= 0 or !inventory.has(key) or int(inventory[key]) < amount:
		return false
	inventory[key] = int(inventory[key]) - amount
	inventory_changed.emit(item_id, int(inventory[key]))
	return true


func use_med_kit() -> bool:
	if death_in_progress or hp <= 0 or hp >= max_hp or get_item_count(&"med_kit") <= 0:
		return false
	if !spend_item(&"med_kit", 1):
		return false
	add_hp(ceili(max_hp * 0.25))
	return true


func repair_ship_system(system_id: StringName, item_id: StringName, cost: int) -> bool:
	var key := String(system_id)
	if !ship_systems.has(key) or bool(ship_systems[key]):
		return false
	# Mini-games call this only after success; verify stock again at commit time.
	if !spend_item(item_id, cost):
		return false
	ship_systems[key] = true
	ship_system_changed.emit(system_id, true)
	if are_all_systems_repaired() and !final_defense_active and !final_defense_done:
		final_defense_active = true
		set_objective("Defend the ship", "LAUNCH PREPARATION // INCOMING HOSTILES")
		final_defense_started.emit()
	else:
		set_objective("Repair the three primary ship systems", get_ship_status_text())
	return true


func is_ship_system_repaired(system_id: StringName) -> bool:
	return bool(ship_systems.get(String(system_id), false))


func repaired_system_count() -> int:
	var count := 0
	for value in ship_systems.values():
		if bool(value):
			count += 1
	return count


func are_all_systems_repaired() -> bool:
	return repaired_system_count() == ship_systems.size()


func get_ship_status_text() -> String:
	return "PWR %s  •  NAV %s  •  ENG %s" % [
		"OK" if ship_systems.power else "00%",
		"OK" if ship_systems.navigation else "00%",
		"OK" if ship_systems.engine else "00%",
	]


func set_objective(title: String, details: String = "") -> void:
	current_objective = title
	current_objective_details = details
	objective_changed.emit(title, details)


func complete_final_defense() -> void:
	if final_defense_done:
		return
	final_defense_active = false
	final_defense_done = true
	set_objective("Board the ship", "E - LAUNCH // LANDING ZONE")
	final_defense_completed.emit()


func collect_pickup(pickup_id: String, item_id: StringName, amount: int = 1) -> bool:
	if pickup_id.is_empty() or collected_pickups.has(pickup_id):
		return false
	if !add_item(item_id, amount):
		return false
	collected_pickups[pickup_id] = true
	return true


func is_pickup_collected(pickup_id: String) -> bool:
	return !pickup_id.is_empty() and collected_pickups.has(pickup_id)


func travel_to(target_scene: String, target_spawn: StringName = &"") -> void:
	if target_scene.is_empty():
		return
	get_tree().paused = false
	current_level = target_scene
	pending_spawn = target_spawn
	loading_save = false
	get_tree().change_scene_to_file(target_scene)


func _clear_inventory() -> void:
	for item_id in INVENTORY_ITEM_IDS:
		inventory[item_id] = 0
		inventory_changed.emit(StringName(item_id), 0)


func load_next_level(next_scene: PackedScene) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_packed(next_scene)


func restart() -> void:
	reset_new_game_state()
	get_tree().change_scene_to_file(current_level)


func reset_new_game_state() -> void:
	get_tree().paused = false
	salvage = 0
	hp = max_hp
	_clear_inventory()
	collected_pickups.clear()
	save_player_position = Vector2.ZERO
	loading_save = false
	death_in_progress = false
	pending_spawn = &""
	landing_intro_seen = false
	unknown_ai_contacted = false
	final_defense_active = false
	final_defense_done = false
	ship_systems = {"power": false, "navigation": false, "engine": false}
	current_objective = "Inspect the damaged ship"
	current_objective_details = "LANDING ZONE // E - INTERACT"
	dropped_salvage.clear()
	next_drop_id = 1
	current_level = "res://Scenes/Levels/zone_67_prologue.tscn"
	health_changed.emit(hp, max_hp)
	salvage_changed.emit(salvage)


func damage(value: int = 1) -> void:
	if death_in_progress:
		return
	hp = clampi(hp - value, 0, max_hp)
	health_changed.emit(hp, max_hp)
	if hp <= 0:
		call_deferred("death")


func add_hp(value: int = 1) -> void:
	if death_in_progress:
		return
	hp = clampi(hp + value, 0, max_hp)
	health_changed.emit(hp, max_hp)


func death() -> void:
	if death_in_progress:
		return
	death_in_progress = true

	var active_player := player
	var death_position := Vector2.ZERO
	if is_instance_valid(active_player):
		death_position = active_player.global_position

	var dropped_amount := salvage
	var drop_entry: Dictionary = {}
	if dropped_amount > 0:
		drop_entry = _register_salvage_drop(death_position, dropped_amount)
		salvage = 0
		salvage_changed.emit(salvage)
		salvage_dropped.emit(dropped_amount, death_position)

	if is_instance_valid(active_player) and active_player.has_method("death_tween"):
		await active_player.death_tween()

	var test_scene := get_tree().current_scene != null and get_tree().current_scene.scene_file_path.begins_with("res://Tests/")
	if test_scene:
		hp = max_hp
		health_changed.emit(hp, max_hp)
		if !drop_entry.is_empty():
			_spawn_salvage_entry(drop_entry)
		player_respawned.emit()
		death_in_progress = false
	else:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://Scenes/Levels/game_over.tscn")


func _register_salvage_drop(world_position: Vector2, amount: int) -> Dictionary:
	var scene_path := current_level
	if get_tree().current_scene != null and !get_tree().current_scene.scene_file_path.is_empty():
		scene_path = get_tree().current_scene.scene_file_path
	var entry: Dictionary = {
		"id": next_drop_id,
		"level": scene_path,
		"position": [world_position.x, world_position.y],
		"amount": amount,
	}
	next_drop_id += 1
	dropped_salvage.append(entry)
	return entry


func spawn_saved_drops_for_current_level() -> void:
	if get_tree().current_scene == null:
		return
	var scene_path := get_tree().current_scene.scene_file_path
	for entry in dropped_salvage:
		if String(entry.get("level", "")) == scene_path:
			_spawn_salvage_entry(entry)


func _spawn_salvage_entry(entry: Dictionary) -> void:
	if get_tree().current_scene == null:
		return
	var drop_id := int(entry.get("id", -1))
	for node in get_tree().get_nodes_in_group("SalvageDrop"):
		if int(node.get("drop_id")) == drop_id:
			return

	var position_data: Array = entry.get("position", [0.0, 0.0])
	if position_data.size() < 2:
		return
	var drop = SALVAGE_DROP_SCENE.instantiate()
	drop.configure(drop_id, int(entry.get("amount", 0)))
	get_tree().current_scene.add_child(drop)
	drop.global_position = Vector2(float(position_data[0]), float(position_data[1]))


func collect_dropped_salvage(drop_id: int, amount: int) -> void:
	for index in range(dropped_salvage.size() - 1, -1, -1):
		if int(dropped_salvage[index].get("id", -1)) == drop_id:
			dropped_salvage.remove_at(index)
			break
	add_salvage(amount)


func update_option() -> void:
	var music_bus := AudioServer.get_bus_index("music")
	var sfx_bus := AudioServer.get_bus_index("sfx")
	if sfx_bus >= 0:
		AudioServer.set_bus_mute(sfx_bus, !sfx_on)
	if music_bus >= 0:
		AudioServer.set_bus_mute(music_bus, !music_on)


func set_fullscreen(enabled: bool) -> void:
	fullscreen_on = enabled
	if fullscreen_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func save_option() -> void:
	var file := FileAccess.open("user://option.json", FileAccess.WRITE)
	if file:
		var payload: Dictionary = {
			"music": music_on,
			"sound": sfx_on,
			"fullscreen": fullscreen_on,
		}
		file.store_pascal_string(JSON.stringify(payload, "  "))
		file.close()


func load_option() -> void:
	if !FileAccess.file_exists("user://option.json"):
		fullscreen_on = DisplayServer.window_get_mode() in [
			DisplayServer.WINDOW_MODE_FULLSCREEN,
			DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
		]
		return

	var file := FileAccess.open("user://option.json", FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_pascal_string())
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		return
	music_on = bool(data.get("music", true))
	sfx_on = bool(data.get("sound", true))
	fullscreen_on = bool(data.get("fullscreen", false))
	update_option()
	set_fullscreen(fullscreen_on)


func save_game() -> bool:
	if !is_instance_valid(player):
		return false
	current_level = get_tree().current_scene.scene_file_path
	var pos := player.global_position
	var payload: Dictionary = {
		"current_level": current_level,
		"player": [pos.x, pos.y],
		"salvage": salvage,
		"hp": hp,
		"inventory": inventory.duplicate(true),
		"collected_pickups": collected_pickups.keys(),
		"landing_intro_seen": landing_intro_seen,
		"unknown_ai_contacted": unknown_ai_contacted,
		"ship_systems": ship_systems.duplicate(true),
		"final_defense_active": final_defense_active,
		"final_defense_done": final_defense_done,
		"objective": current_objective,
		"objective_details": current_objective_details,
		"dropped_salvage": dropped_salvage,
		"next_drop_id": next_drop_id,
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_pascal_string(JSON.stringify(payload, "  "))
	file.close()
	return true


func has_gamesaved() -> bool:
	return FileAccess.file_exists(save_path)


func load_game() -> void:
	if !FileAccess.file_exists(save_path):
		restart()
		return

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		restart()
		return
	var data = JSON.parse_string(file.get_pascal_string())
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		restart()
		return

	current_level = String(data.get("current_level", current_level))
	salvage = maxi(int(data.get("salvage", data.get("score", 0))), 0)
	hp = clampi(int(data.get("hp", max_hp)), 1, max_hp)
	_clear_inventory()
	var saved_inventory = data.get("inventory", {})
	if typeof(saved_inventory) == TYPE_DICTIONARY:
		for item_id in INVENTORY_ITEM_IDS:
			inventory[item_id] = maxi(int(saved_inventory.get(item_id, 0)), 0)
			inventory_changed.emit(StringName(item_id), int(inventory[item_id]))
	collected_pickups.clear()
	var saved_pickups = data.get("collected_pickups", [])
	if typeof(saved_pickups) == TYPE_ARRAY:
		for pickup_id in saved_pickups:
			collected_pickups[String(pickup_id)] = true
	landing_intro_seen = bool(data.get("landing_intro_seen", true))
	unknown_ai_contacted = bool(data.get("unknown_ai_contacted", false))
	var saved_systems = data.get("ship_systems", {})
	for system_id in ship_systems:
		ship_systems[system_id] = bool(saved_systems.get(system_id, false)) if typeof(saved_systems) == TYPE_DICTIONARY else false
	final_defense_active = bool(data.get("final_defense_active", false))
	final_defense_done = bool(data.get("final_defense_done", false))
	current_objective = String(data.get("objective", "Inspect the damaged ship"))
	current_objective_details = String(data.get("objective_details", get_ship_status_text()))
	next_drop_id = maxi(int(data.get("next_drop_id", 1)), 1)
	dropped_salvage.clear()
	for raw_entry in data.get("dropped_salvage", []):
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var raw_position: Array = raw_entry.get("position", [0.0, 0.0])
		if raw_position.size() < 2:
			continue
		var normalized_entry: Dictionary = {
			"id": int(raw_entry.get("id", next_drop_id)),
			"level": String(raw_entry.get("level", current_level)),
			"position": [float(raw_position[0]), float(raw_position[1])],
			"amount": maxi(int(raw_entry.get("amount", 0)), 0),
		}
		if normalized_entry["amount"] > 0:
			dropped_salvage.append(normalized_entry)
			next_drop_id = maxi(next_drop_id, int(normalized_entry["id"]) + 1)

	var pos: Array = data.get("player", [0.0, 0.0])
	save_player_position = Vector2(float(pos[0]), float(pos[1])) if pos.size() >= 2 else Vector2.ZERO
	if current_level.begins_with("res://Scenes/Levels/level_"):
		current_level = "res://Scenes/Levels/zone_67_prologue.tscn"
		save_player_position = Vector2.ZERO
		dropped_salvage.clear()
	loading_save = true
	death_in_progress = false
	pending_spawn = &""
	get_tree().paused = false
	get_tree().change_scene_to_file(current_level)
