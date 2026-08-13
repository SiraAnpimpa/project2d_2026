extends Node

const LEVELS: Array[String] = [
	"res://Scenes/Levels/zone_67_prologue.tscn",
	"res://Scenes/Levels/crystal_field.tscn",
	"res://Scenes/Levels/abandoned_signal_base.tscn",
]
const ITEM_IDS: PackedStringArray = [
	"scrap_metal",
	"energy_crystal",
	"circuit_part",
	"med_kit",
	"access_card",
	"data_log",
]

const TEST_SAVE_PATH := "user://world_content_test.save"

var original_save_path := ""


func _ready() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	original_save_path = GameManager.save_path
	GameManager.save_path = TEST_SAVE_PATH
	_remove_test_save()

	for item_id in ITEM_IDS:
		var texture_path := "res://Assets/UI/Items/%s.png" % item_id
		var texture := load(texture_path) as Texture2D
		if texture == null or texture.get_width() < 512 or texture.get_height() < 512:
			_fail("Missing or low-resolution item icon: " + texture_path)
			return

	for level_path in LEVELS:
		var packed := load(level_path) as PackedScene
		if packed == null:
			_fail("Could not load map scene: " + level_path)
			return
		var level := packed.instantiate()
		add_child(level)
		await get_tree().process_frame
		var chunks := level.find_children("*", "EnvironmentChunk", true, false)
		var expected_chunks := 4 if level_path != LEVELS[2] else 3
		if chunks.size() != expected_chunks:
			_fail("Environment pack has the wrong number of chunks: " + level_path)
			return
		for chunk in chunks:
			if chunk.texture == null or chunk.texture.get_width() < 1200 or chunk.texture.get_height() < 1200:
				_fail("Environment chunk art is missing or low resolution: " + chunk.name)
				return
			var sprite := chunk.get_node("Visual") as Sprite2D
			if sprite.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
				_fail("Environment chunk is not using nearest filtering: " + chunk.name)
				return
			if chunk.get_node("Collision").get_child_count() < 4:
				_fail("Environment chunk collision was not generated: " + chunk.name)
				return
		if !_validate_gameplay_points(level):
			return
		if !level.has_node("UserInterface/GameUI/ItemBelt"):
			_fail("Item HUD is missing from: " + level_path)
			return
		if level_path == LEVELS[1]:
			GameManager.player = level.get_node("Player")
			GameManager.current_level = level_path
			GameManager.add_item(&"energy_crystal", 2)
			GameManager.collected_pickups["test_energy"] = true
			GameManager.landing_intro_seen = true
			if !GameManager.save_game():
				_fail("World inventory could not be saved")
				return
			var save_file := FileAccess.open(GameManager.save_path, FileAccess.READ)
			var saved_data = JSON.parse_string(save_file.get_pascal_string()) if save_file != null else null
			if save_file != null:
				save_file.close()
			if typeof(saved_data) != TYPE_DICTIONARY:
				_fail("World save data could not be read")
				return
			if int(saved_data.get("inventory", {}).get("energy_crystal", 0)) != 2:
				_fail("World inventory was not written to save data")
				return
			if !saved_data.get("collected_pickups", []).has("test_energy"):
				_fail("Collected pickup state was not written to save data")
				return
			if !bool(saved_data.get("landing_intro_seen", false)):
				_fail("Landing intro state was not written to save data")
				return
		level.queue_free()
		await get_tree().process_frame

	GameManager._clear_inventory()
	GameManager.collected_pickups.clear()
	if !GameManager.collect_pickup("test_energy", &"energy_crystal", 2):
		_fail("Item pickup was not accepted")
		return
	if GameManager.get_item_count(&"energy_crystal") != 2:
		_fail("Item inventory count is incorrect")
		return
	if GameManager.collect_pickup("test_energy", &"energy_crystal", 2):
		_fail("Collected pickup could be collected twice")
		return

	print("WORLD_CONTENT_TEST: PASS")
	_cleanup()
	get_tree().quit()


func _validate_gameplay_points(level: Node) -> bool:
	var points: Array[Node] = []
	points.append_array(get_tree().get_nodes_in_group("WorldPickup"))
	points.append_array(get_tree().get_nodes_in_group("ZoneGate"))
	var player := level.get_node_or_null("Player") as Node2D
	if player != null:
		points.append(player)
	var chunks := level.find_children("*", "EnvironmentChunk", true, false)
	for point in points:
		if !level.is_ancestor_of(point):
			continue
		for chunk in chunks:
			var body := chunk.get_node("Collision") as StaticBody2D
			for collision in body.get_children():
				var shape_node := collision as CollisionShape2D
				if shape_node == null or shape_node.shape == null:
					continue
				var local_point := shape_node.to_local(point.global_position)
				if _shape_contains_point(shape_node.shape, local_point):
					_fail("Gameplay point is inside a wall: %s/%s" % [level.name, point.name])
					return false
	return true


func _shape_contains_point(shape: Shape2D, point: Vector2) -> bool:
	if shape is RectangleShape2D:
		var half_size := (shape as RectangleShape2D).size * 0.5
		return absf(point.x) <= half_size.x and absf(point.y) <= half_size.y
	if shape is CircleShape2D:
		return point.length_squared() <= pow((shape as CircleShape2D).radius, 2.0)
	return false


func _fail(message: String) -> void:
	push_error("WORLD_CONTENT_TEST: " + message)
	_cleanup()
	get_tree().paused = false
	get_tree().quit(1)


func _cleanup() -> void:
	_remove_test_save()
	if !original_save_path.is_empty():
		GameManager.save_path = original_save_path


func _remove_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
