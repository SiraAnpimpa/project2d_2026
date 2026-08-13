extends Node

const PACKS: Array[Dictionary] = [
	{
		"path": "res://Scenes/EnvironmentPacks/landing_zone_pack.tscn",
		"count": 4,
		"external": {"WreckNE": 1},
	},
	{
		"path": "res://Scenes/EnvironmentPacks/crystal_field_pack.tscn",
		"count": 4,
		"external": {"Gateway": 2, "SignalApproach": 2},
	},
	{
		"path": "res://Scenes/EnvironmentPacks/signal_base_pack.tscn",
		"count": 3,
		"external": {"DishCore": 2},
	},
]

const EDGE_NORTH := 0
const EDGE_EAST := 1
const EDGE_SOUTH := 2
const EDGE_WEST := 3


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
		var chunks := pack.find_children("*", "EnvironmentChunk", true, false)
		if chunks.size() != int(spec.count):
			_fail("Wrong chunk count in: " + spec.path)
			return
		var ids: Dictionary = {}
		for chunk in chunks:
			if chunk.chunk_id.is_empty() or ids.has(chunk.chunk_id):
				_fail("Chunk ID is empty or duplicated in: " + spec.path)
				return
			ids[chunk.chunk_id] = true
			if chunk.open_edges == 0:
				_fail("Chunk has no configured walkable connector: " + chunk.chunk_id)
				return
			if chunk.get_node("Collision").get_child_count() < 4:
				_fail("Chunk has no generated wall collision: " + chunk.chunk_id)
				return
		if not _validate_neighbor_connections(chunks, spec.path):
			return
		for node_name in spec.external:
			var chunk := pack.get_node_or_null(NodePath(node_name))
			if chunk == null or not _has_edge(chunk, int(spec.external[node_name])):
				_fail("Missing external connector on %s/%s" % [spec.path, node_name])
				return
		pack.queue_free()
		await get_tree().process_frame

	print("ENVIRONMENT_PACK_TEST: PASS")
	get_tree().quit()


func _validate_neighbor_connections(chunks: Array[Node], pack_path: String) -> bool:
	for index in range(chunks.size()):
		for other_index in range(index + 1, chunks.size()):
			var first = chunks[index]
			var second = chunks[other_index]
			var delta: Vector2 = second.position - first.position
			var step: Vector2 = first.chunk_size
			if is_equal_approx(absf(delta.x), step.x) and is_zero_approx(delta.y):
				var left = first if delta.x > 0.0 else second
				var right = second if delta.x > 0.0 else first
				if not _has_edge(left, EDGE_EAST) or not _has_edge(right, EDGE_WEST):
					_fail("Blocked horizontal seam between %s and %s in %s" % [left.chunk_id, right.chunk_id, pack_path])
					return false
			elif is_equal_approx(absf(delta.y), step.y) and is_zero_approx(delta.x):
				var top = first if delta.y > 0.0 else second
				var bottom = second if delta.y > 0.0 else first
				if not _has_edge(top, EDGE_SOUTH) or not _has_edge(bottom, EDGE_NORTH):
					_fail("Blocked vertical seam between %s and %s in %s" % [top.chunk_id, bottom.chunk_id, pack_path])
					return false
	return true


func _has_edge(chunk: Node, edge: int) -> bool:
	return (int(chunk.open_edges) & (1 << edge)) != 0


func _fail(message: String) -> void:
	push_error("ENVIRONMENT_PACK_TEST: " + message)
	get_tree().quit(1)
