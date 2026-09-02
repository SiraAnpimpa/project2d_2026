@tool
class_name FullMapEnvironment
extends Node2D

@export_category("Full Map Environment")
@export_group("Identity & Visual")
@export var map_id := ""
@export var texture: Texture2D:
	set(value):
		texture = value
		_update_preview()
@export var map_size := Vector2(1672.0, 941.0):
	set(value):
		map_size = value
		_queue_collision_rebuild()
		_queue_editor_redraw()

@export_group("Collision In Texture Pixels")
@export var wall_segments: Array[Vector4] = []:
	set(value):
		wall_segments = value
		_queue_collision_rebuild()
		_queue_editor_redraw()
@export var collision_rects: Array[Rect2] = []:
	set(value):
		collision_rects = value
		_queue_collision_rebuild()
		_queue_editor_redraw()
@export var collision_circles: Array[Vector3] = []:
	set(value):
		collision_circles = value
		_queue_collision_rebuild()
		_queue_editor_redraw()
@export var collision_polygons: Array[PackedVector2Array] = []:
	set(value):
		collision_polygons = value
		_queue_collision_rebuild()
		_queue_editor_redraw()

@export_group("Validation")
@export var walkable_anchors: Array[Vector2] = []

var _collision_rebuild_queued := false


func _ready() -> void:
	_update_preview()
	_queue_collision_rebuild()
	_queue_editor_redraw()


func pixel_to_local(pixel_point: Vector2) -> Vector2:
	return pixel_point - map_size * 0.5


func local_to_pixel(local_point: Vector2) -> Vector2:
	return local_point + map_size * 0.5


func get_world_rect() -> Rect2:
	return Rect2(global_position - map_size * 0.5, map_size)


func get_collision_shape_count() -> int:
	var body := get_node_or_null("Collision") as StaticBody2D
	var shape_count := body.get_child_count() if body != null else 0
	for manual_body in _get_manual_collision_bodies():
		for node in manual_body.find_children("*", "CollisionPolygon2D", true, false):
			var polygon := node as CollisionPolygon2D
			if polygon != null and polygon.polygon.size() >= 3:
				shape_count += 1
	return shape_count


func is_local_point_blocked(local_point: Vector2, clearance: float = 0.0) -> bool:
	return is_pixel_point_blocked(local_to_pixel(local_point), clearance)


func is_pixel_point_blocked(pixel_point: Vector2, clearance: float = 0.0) -> bool:
	if pixel_point.x < clearance or pixel_point.y < clearance:
		return true
	if pixel_point.x > map_size.x - clearance or pixel_point.y > map_size.y - clearance:
		return true

	for segment in wall_segments:
		var start := Vector2(segment.x, segment.y)
		var end := Vector2(segment.z, segment.w)
		if _distance_to_segment(pixel_point, start, end) <= clearance:
			return true

	for rect in collision_rects:
		if rect.grow(clearance).has_point(pixel_point):
			return true

	for circle in collision_circles:
		if pixel_point.distance_to(Vector2(circle.x, circle.y)) <= circle.z + clearance:
			return true

	for polygon in collision_polygons:
		if Geometry2D.is_point_in_polygon(pixel_point, polygon):
			return true
		if clearance > 0.0 and _distance_to_polygon(pixel_point, polygon) <= clearance:
			return true

	if _is_manual_point_blocked(pixel_to_local(pixel_point), clearance):
		return true

	return false


func _is_manual_point_blocked(local_point: Vector2, clearance: float) -> bool:
	for manual_body in _get_manual_collision_bodies():
		for node in manual_body.find_children("*", "CollisionPolygon2D", true, false):
			var collision_polygon := node as CollisionPolygon2D
			if collision_polygon == null or collision_polygon.disabled:
				continue
			if collision_polygon.polygon.size() < 3:
				continue

			var transformed_polygon := PackedVector2Array()
			for vertex in collision_polygon.polygon:
				transformed_polygon.append(to_local(collision_polygon.to_global(vertex)))
			var distance := _distance_to_polygon(local_point, transformed_polygon)
			if collision_polygon.build_mode == CollisionPolygon2D.BUILD_SOLIDS:
				if Geometry2D.is_point_in_polygon(local_point, transformed_polygon):
					return true
			if distance <= clearance:
				return true

	return false


func _get_manual_collision_bodies() -> Array[StaticBody2D]:
	var bodies: Array[StaticBody2D] = []
	var local_body := get_node_or_null("ManualCollision") as StaticBody2D
	if local_body != null:
		bodies.append(local_body)
	var parent_node := get_parent()
	if parent_node != null:
		var sibling_body := parent_node.get_node_or_null("ManualCollision") as StaticBody2D
		if sibling_body != null and sibling_body != local_body:
			bodies.append(sibling_body)
	return bodies


func _draw() -> void:
	if !Engine.is_editor_hint():
		return

	var wall_color := Color(1.0, 0.25, 0.32, 0.92)
	var obstacle_fill := Color(1.0, 0.58, 0.12, 0.17)
	var obstacle_outline := Color(1.0, 0.68, 0.20, 0.94)
	var anchor_color := Color(0.18, 1.0, 0.68, 0.96)

	for segment in wall_segments:
		draw_line(
			pixel_to_local(Vector2(segment.x, segment.y)),
			pixel_to_local(Vector2(segment.z, segment.w)),
			wall_color,
			4.0
		)

	for rect in collision_rects:
		var local_rect := Rect2(pixel_to_local(rect.position), rect.size)
		draw_rect(local_rect, obstacle_fill, true)
		draw_rect(local_rect, obstacle_outline, false, 3.0)

	for circle in collision_circles:
		var centre := pixel_to_local(Vector2(circle.x, circle.y))
		draw_circle(centre, circle.z, obstacle_fill)
		draw_arc(centre, circle.z, 0.0, TAU, 64, obstacle_outline, 3.0)

	for polygon in collision_polygons:
		var local_polygon := _polygon_to_local(polygon)
		if local_polygon.size() >= 3:
			draw_colored_polygon(local_polygon, obstacle_fill)
			for index in local_polygon.size():
				draw_line(
					local_polygon[index],
					local_polygon[(index + 1) % local_polygon.size()],
					obstacle_outline,
					3.0
				)

	for anchor in walkable_anchors:
		var centre := pixel_to_local(anchor)
		draw_circle(centre, 8.0, anchor_color)
		draw_arc(centre, 22.0, 0.0, TAU, 32, anchor_color, 2.0)


func _queue_collision_rebuild() -> void:
	if !is_inside_tree() or _collision_rebuild_queued:
		return
	_collision_rebuild_queued = true
	call_deferred("_perform_collision_rebuild")


func _perform_collision_rebuild() -> void:
	_collision_rebuild_queued = false
	var body := get_node_or_null("Collision") as StaticBody2D
	if body == null:
		return

	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()

	for segment in wall_segments:
		_add_segment(
			body,
			pixel_to_local(Vector2(segment.x, segment.y)),
			pixel_to_local(Vector2(segment.z, segment.w))
		)
	for rect in collision_rects:
		_add_rectangle(body, pixel_to_local(rect.get_center()), rect.size)
	for circle in collision_circles:
		_add_circle(body, pixel_to_local(Vector2(circle.x, circle.y)), circle.z)
	for polygon in collision_polygons:
		_add_polygon(body, _polygon_to_local(polygon))


func _add_segment(body: StaticBody2D, start: Vector2, end: Vector2) -> void:
	if start.distance_squared_to(end) < 1.0:
		return
	var collision := CollisionShape2D.new()
	var shape := SegmentShape2D.new()
	shape.a = start
	shape.b = end
	collision.shape = shape
	body.add_child(collision)


func _add_rectangle(body: StaticBody2D, centre: Vector2, size: Vector2) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.position = centre
	collision.shape = shape
	body.add_child(collision)


func _add_circle(body: StaticBody2D, centre: Vector2, radius: float) -> void:
	if radius <= 0.0:
		return
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	collision.position = centre
	collision.shape = shape
	body.add_child(collision)


func _add_polygon(body: StaticBody2D, polygon: PackedVector2Array) -> void:
	if polygon.size() < 3:
		return
	var collision := CollisionPolygon2D.new()
	collision.build_mode = CollisionPolygon2D.BUILD_SOLIDS
	collision.polygon = polygon
	body.add_child(collision)


func _polygon_to_local(polygon: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in polygon:
		result.append(pixel_to_local(point))
	return result


func _distance_to_polygon(point: Vector2, polygon: PackedVector2Array) -> float:
	if polygon.size() < 2:
		return INF
	var nearest := INF
	for index in polygon.size():
		nearest = minf(
			nearest,
			_distance_to_segment(point, polygon[index], polygon[(index + 1) % polygon.size()])
		)
	return nearest


func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(start)
	var ratio := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * ratio)


func _queue_editor_redraw() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		queue_redraw()


func _update_preview() -> void:
	var sprite := get_node_or_null("Visual") as Sprite2D
	if sprite != null:
		sprite.texture = texture
