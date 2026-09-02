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
		var manual_collision := level.get_node_or_null("ManualCollision") as StaticBody2D
		if manual_collision == null:
			_fail("Level is missing its editor-visible ManualCollision layer: " + level_path)
			return
		if manual_collision.find_children("*", "CollisionPolygon2D", true, false).is_empty():
			_fail("Level has no editor-drawn collision polygons: " + level_path)
			return
		var environments := level.find_children("*", "FullMapEnvironment", true, false)
		if environments.size() != 1:
			_fail("Level does not contain one full map environment: " + level_path)
			return
		for environment in environments:
			if environment.texture == null or environment.texture.get_size() != Vector2(1672, 941):
				_fail("Full map art is missing or has the wrong resolution: " + environment.name)
				return
			var sprite := environment.get_node("Visual") as Sprite2D
			if sprite.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
				_fail("Full map is not using nearest filtering: " + environment.name)
				return
			if environment.get_collision_shape_count() < 1:
				_fail("Full map collision was not generated: " + environment.name)
				return
		if !_validate_gameplay_points(level):
			return
		if !_validate_spawn_clearance(level):
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
	var environments := level.find_children("*", "FullMapEnvironment", true, false)
	for point in points:
		if !level.is_ancestor_of(point):
			continue
		for environment in environments:
			var full_map := environment as FullMapEnvironment
			var local_point: Vector2 = full_map.to_local(point.global_position)
			if full_map.is_local_point_blocked(local_point, 20.0):
				_fail("Gameplay point is inside or too close to collision: %s/%s" % [level.name, point.name])
				return false
	return true


func _validate_spawn_clearance(level: Node) -> bool:
	var spawn_points := level.get_node_or_null("SpawnPoints")
	if spawn_points == null:
		return true
	var gates := get_tree().get_nodes_in_group("ZoneGate")
	for marker_node in spawn_points.get_children():
		var marker := marker_node as Marker2D
		if marker == null:
			continue
		for gate_node in gates:
			if !level.is_ancestor_of(gate_node):
				continue
			var shape_node := gate_node.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if shape_node == null or !(shape_node.shape is RectangleShape2D):
				continue
			var local_point: Vector2 = shape_node.to_local(marker.global_position)
			var half_size := (shape_node.shape as RectangleShape2D).size * 0.5 + Vector2.ONE * 18.0
			if absf(local_point.x) <= half_size.x and absf(local_point.y) <= half_size.y:
				_fail("Spawn point overlaps a zone gate: %s/%s" % [level.name, marker.name])
				return false
	return true


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
