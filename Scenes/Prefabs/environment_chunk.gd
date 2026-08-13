@tool
class_name EnvironmentChunk
extends Node2D

enum Edge { NORTH, EAST, SOUTH, WEST }

@export_category("Environment Chunk")
@export_group("Identity & Visual")
@export var chunk_id := ""
@export var texture: Texture2D:
	set(value):
		texture = value
		_update_preview()
@export var chunk_size := Vector2(1254, 1254):
	set(value):
		chunk_size = value
		_rebuild_collision()
		_queue_editor_redraw()

@export_group("Walkway Connections")
@export_flags("North", "East", "South", "West") var open_edges := 0:
	set(value):
		open_edges = value
		_rebuild_collision()
		_queue_editor_redraw()
@export_range(96.0, 480.0, 8.0) var doorway_width := 300.0:
	set(value):
		doorway_width = value
		_rebuild_collision()
		_queue_editor_redraw()
@export_range(24.0, 180.0, 4.0) var wall_depth := 92.0:
	set(value):
		wall_depth = value
		_rebuild_collision()
		_queue_editor_redraw()

@export_group("Local Obstacles")
@export var obstacle_rects: Array[Rect2] = []:
	set(value):
		obstacle_rects = value
		_rebuild_collision()
		_queue_editor_redraw()
@export var obstacle_circles: Array[Vector3] = []:
	set(value):
		obstacle_circles = value
		_rebuild_collision()
		_queue_editor_redraw()

var _collision_rebuild_queued := false


func _ready() -> void:
	_update_preview()
	_rebuild_collision()
	_queue_editor_redraw()


func is_edge_open(edge: Edge) -> bool:
	return (open_edges & (1 << int(edge))) != 0


func get_walkable_rect() -> Rect2:
	return Rect2(-chunk_size * 0.5 + Vector2.ONE * wall_depth, chunk_size - Vector2.ONE * wall_depth * 2.0)


func _draw() -> void:
	if !Engine.is_editor_hint():
		return

	var wall_fill := Color(1.0, 0.19, 0.30, 0.16)
	var wall_outline := Color(1.0, 0.32, 0.40, 0.88)
	var doorway_color := Color(0.20, 1.0, 0.72, 0.95)
	var obstacle_fill := Color(1.0, 0.59, 0.16, 0.20)
	var obstacle_outline := Color(1.0, 0.67, 0.24, 0.92)

	_draw_horizontal_preview(-chunk_size.y * 0.5 + wall_depth * 0.5, Edge.NORTH, wall_fill, wall_outline, doorway_color)
	_draw_horizontal_preview(chunk_size.y * 0.5 - wall_depth * 0.5, Edge.SOUTH, wall_fill, wall_outline, doorway_color)
	_draw_vertical_preview(chunk_size.x * 0.5 - wall_depth * 0.5, Edge.EAST, wall_fill, wall_outline, doorway_color)
	_draw_vertical_preview(-chunk_size.x * 0.5 + wall_depth * 0.5, Edge.WEST, wall_fill, wall_outline, doorway_color)

	for rect in obstacle_rects:
		draw_rect(rect, obstacle_fill, true)
		draw_rect(rect, obstacle_outline, false, 3.0)
	for circle in obstacle_circles:
		var centre := Vector2(circle.x, circle.y)
		draw_circle(centre, circle.z, obstacle_fill)
		draw_arc(centre, circle.z, 0.0, TAU, 64, obstacle_outline, 3.0)


func _draw_horizontal_preview(y: float, edge: Edge, fill: Color, outline: Color, doorway: Color) -> void:
	if !is_edge_open(edge):
		_draw_preview_rect(Vector2(0.0, y), Vector2(chunk_size.x, wall_depth), fill, outline)
		return
	var segment_width := (chunk_size.x - doorway_width) * 0.5
	var offset := doorway_width * 0.5 + segment_width * 0.5
	_draw_preview_rect(Vector2(-offset, y), Vector2(segment_width, wall_depth), fill, outline)
	_draw_preview_rect(Vector2(offset, y), Vector2(segment_width, wall_depth), fill, outline)
	draw_line(Vector2(-doorway_width * 0.5, y), Vector2(doorway_width * 0.5, y), doorway, 7.0)


func _draw_vertical_preview(x: float, edge: Edge, fill: Color, outline: Color, doorway: Color) -> void:
	if !is_edge_open(edge):
		_draw_preview_rect(Vector2(x, 0.0), Vector2(wall_depth, chunk_size.y), fill, outline)
		return
	var segment_height := (chunk_size.y - doorway_width) * 0.5
	var offset := doorway_width * 0.5 + segment_height * 0.5
	_draw_preview_rect(Vector2(x, -offset), Vector2(wall_depth, segment_height), fill, outline)
	_draw_preview_rect(Vector2(x, offset), Vector2(wall_depth, segment_height), fill, outline)
	draw_line(Vector2(x, -doorway_width * 0.5), Vector2(x, doorway_width * 0.5), doorway, 7.0)


func _draw_preview_rect(centre: Vector2, size: Vector2, fill: Color, outline: Color) -> void:
	var rect := Rect2(centre - size * 0.5, size)
	draw_rect(rect, fill, true)
	draw_rect(rect, outline, false, 2.0)


func _queue_editor_redraw() -> void:
	if Engine.is_editor_hint() and is_inside_tree():
		queue_redraw()


func _update_preview() -> void:
	var sprite := get_node_or_null("Visual") as Sprite2D
	if sprite != null:
		sprite.texture = texture


func _rebuild_collision() -> void:
	if !is_inside_tree():
		return
	if _collision_rebuild_queued:
		return
	_collision_rebuild_queued = true
	call_deferred("_perform_collision_rebuild")


func _perform_collision_rebuild() -> void:
	_collision_rebuild_queued = false
	var body := get_node_or_null("Collision") as StaticBody2D
	if body == null:
		return
	for child in body.get_children():
		child.queue_free()

	_build_horizontal_edge(body, -chunk_size.y * 0.5 + wall_depth * 0.5, Edge.NORTH)
	_build_horizontal_edge(body, chunk_size.y * 0.5 - wall_depth * 0.5, Edge.SOUTH)
	_build_vertical_edge(body, chunk_size.x * 0.5 - wall_depth * 0.5, Edge.EAST)
	_build_vertical_edge(body, -chunk_size.x * 0.5 + wall_depth * 0.5, Edge.WEST)

	for rect in obstacle_rects:
		_add_rectangle(body, rect.position + rect.size * 0.5, rect.size)
	for circle in obstacle_circles:
		_add_circle(body, Vector2(circle.x, circle.y), circle.z)


func _build_horizontal_edge(body: StaticBody2D, y: float, edge: Edge) -> void:
	if !is_edge_open(edge):
		_add_rectangle(body, Vector2(0.0, y), Vector2(chunk_size.x, wall_depth))
		return
	var segment_width := (chunk_size.x - doorway_width) * 0.5
	var offset := doorway_width * 0.5 + segment_width * 0.5
	_add_rectangle(body, Vector2(-offset, y), Vector2(segment_width, wall_depth))
	_add_rectangle(body, Vector2(offset, y), Vector2(segment_width, wall_depth))


func _build_vertical_edge(body: StaticBody2D, x: float, edge: Edge) -> void:
	if !is_edge_open(edge):
		_add_rectangle(body, Vector2(x, 0.0), Vector2(wall_depth, chunk_size.y))
		return
	var segment_height := (chunk_size.y - doorway_width) * 0.5
	var offset := doorway_width * 0.5 + segment_height * 0.5
	_add_rectangle(body, Vector2(x, -offset), Vector2(wall_depth, segment_height))
	_add_rectangle(body, Vector2(x, offset), Vector2(wall_depth, segment_height))


func _add_rectangle(body: StaticBody2D, position: Vector2, size: Vector2) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.position = position
	collision.shape = shape
	body.add_child(collision)


func _add_circle(body: StaticBody2D, position: Vector2, radius: float) -> void:
	if radius <= 0.0:
		return
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	collision.position = position
	collision.shape = shape
	body.add_child(collision)
