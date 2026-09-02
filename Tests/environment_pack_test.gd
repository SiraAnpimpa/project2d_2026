extends Node

const PACKS: Array[Dictionary] = [
	{
		"path": "res://Scenes/EnvironmentPacks/landing_zone_pack.tscn",
		"map_id": "landing_zone",
		"minimum_shapes": 2,
	},
	{
		"path": "res://Scenes/EnvironmentPacks/crystal_field_pack.tscn",
		"map_id": "crystal_field",
		"minimum_shapes": 4,
	},
	{
		"path": "res://Scenes/EnvironmentPacks/signal_base_pack.tscn",
		"map_id": "signal_base",
		"minimum_shapes": 14,
	},
]

const PLAYER_CLEARANCE := 18.0
const GRID_STEP := 16.0
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(-1, 0),
	Vector2i(1, 0),
	Vector2i(0, -1),
	Vector2i(0, 1),
	Vector2i(-1, -1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(1, 1),
]


func _ready() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	for spec in PACKS:
		var packed := load(spec.path) as PackedScene
		if packed == null:
			_fail("Could not load pack: " + spec.path)
			return
		var pack := packed.instantiate()
		add_child(pack)
		await get_tree().process_frame
		await get_tree().process_frame

		if !(pack is FullMapEnvironment):
			_fail("Pack root must expose FullMapEnvironment collision controls: " + spec.path)
			return
		var environment := pack as FullMapEnvironment
		if !(environment.get_node_or_null("ManualCollision") is StaticBody2D):
			_fail("Pack is missing the editor-drawn ManualCollision layer: " + spec.path)
			return
		if environment.map_id != spec.map_id:
			_fail("Map ID mismatch in: " + spec.path)
			return
		if environment.texture == null:
			_fail("Map texture is missing in: " + spec.path)
			return
		if environment.texture.get_size() != environment.map_size:
			_fail("Map texture and collision coordinates use different sizes in: " + spec.path)
			return
		if environment.map_size != Vector2(1672.0, 941.0):
			_fail("Unexpected map dimensions in: " + spec.path)
			return
		var sprite := environment.get_node("Visual") as Sprite2D
		if sprite.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
			_fail("Map texture is not using nearest filtering in: " + spec.path)
			return
		if environment.get_collision_shape_count() < int(spec.minimum_shapes):
			_fail("Collision detail is too low in: " + spec.path)
			return
		if !_validate_manual_polygon(environment, spec.path):
			return
		if !_validate_walkable_anchors(environment, spec.path):
			return
		if !_validate_anchor_connectivity(environment, spec.path):
			return

		pack.queue_free()
		await get_tree().process_frame

	print("ENVIRONMENT_PACK_TEST: PASS")
	get_tree().quit()


func _validate_manual_polygon(environment: FullMapEnvironment, pack_path: String) -> bool:
	var manual_body := environment.get_node("ManualCollision") as StaticBody2D
	var anchor := environment.walkable_anchors[0]
	var centre := environment.pixel_to_local(anchor)
	var polygon := CollisionPolygon2D.new()
	polygon.polygon = PackedVector2Array([
		centre + Vector2(-8.0, -8.0),
		centre + Vector2(8.0, -8.0),
		centre + Vector2(8.0, 8.0),
		centre + Vector2(-8.0, 8.0),
	])
	manual_body.add_child(polygon)
	var detected := environment.is_pixel_point_blocked(anchor)
	manual_body.remove_child(polygon)
	polygon.queue_free()
	if !detected:
		_fail("Editor-drawn collision polygons are not detected in: " + pack_path)
		return false
	return true


func _validate_walkable_anchors(environment: FullMapEnvironment, pack_path: String) -> bool:
	if environment.walkable_anchors.size() < 6:
		_fail("Not enough navigation anchors in: " + pack_path)
		return false
	for anchor in environment.walkable_anchors:
		if environment.is_pixel_point_blocked(anchor, PLAYER_CLEARANCE):
			_fail("Walkable anchor is blocked at %s in %s" % [anchor, pack_path])
			return false
	return true


func _validate_anchor_connectivity(environment: FullMapEnvironment, pack_path: String) -> bool:
	var start := _nearest_free_cell(environment, environment.walkable_anchors[0])
	if start == Vector2i(-1, -1):
		_fail("Could not place navigation flood-fill start in: " + pack_path)
		return false

	var frontier: Array[Vector2i] = [start]
	var visited: Dictionary = {start: true}
	var cursor := 0
	while cursor < frontier.size():
		var cell := frontier[cursor]
		cursor += 1
		for direction in DIRECTIONS:
			var next := cell + direction
			if visited.has(next) or !_cell_is_walkable(environment, next):
				continue
			if direction.x != 0 and direction.y != 0:
				if !_cell_is_walkable(environment, cell + Vector2i(direction.x, 0)):
					continue
				if !_cell_is_walkable(environment, cell + Vector2i(0, direction.y)):
					continue
			visited[next] = true
			frontier.append(next)

	for anchor in environment.walkable_anchors:
		var anchor_cell := _nearest_free_cell(environment, anchor)
		if anchor_cell == Vector2i(-1, -1) or !visited.has(anchor_cell):
			_fail("Walkable regions are disconnected near %s in %s" % [anchor, pack_path])
			return false
	return true


func _nearest_free_cell(environment: FullMapEnvironment, point: Vector2) -> Vector2i:
	var origin := Vector2i(roundi(point.x / GRID_STEP), roundi(point.y / GRID_STEP))
	for radius in range(4):
		for offset_y in range(-radius, radius + 1):
			for offset_x in range(-radius, radius + 1):
				var candidate := origin + Vector2i(offset_x, offset_y)
				if _cell_is_walkable(environment, candidate):
					return candidate
	return Vector2i(-1, -1)


func _cell_is_walkable(environment: FullMapEnvironment, cell: Vector2i) -> bool:
	var point := Vector2(cell) * GRID_STEP
	return !environment.is_pixel_point_blocked(point, PLAYER_CLEARANCE)


func _fail(message: String) -> void:
	push_error("ENVIRONMENT_PACK_TEST: " + message)
	get_tree().quit(1)
