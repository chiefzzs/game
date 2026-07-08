extends Node
class_name DrawTools
## V0.2 T02-03：绘制工具 - 图块笔刷/橡皮/矩形填充/撤销栈50步/重做。
## 与 EditorMain.gd / TileMap 联动使用。

signal undo_performed(new_count: int)
signal redo_performed(new_count: int)
signal cell_painted(layer: int, coord: Vector2i, new_tile: int, old_tile: int)

const MAX_UNDO := 50
const TOOL_BRUSH := 0
const TOOL_ERASER := 1
const TOOL_RECT_FILL := 2

var current_tool: int = TOOL_BRUSH
var current_tile_id: int = 1
var current_layer: int = 0  # 当前绘制图层 (0-7，共8层)
var tilemap_target: TileMap = null

var _undo_stack: Array = []  # 每项: {"ops": Array of {"layer":int,"coord":Vector2i,"old":int,"new":int}}
var _redo_stack: Array = []
var _batch_ops: Array = []  # 当次拖拽的批量操作（最后合并成一个undo项）
var _is_dragging: bool = false

func bind_tilemap(tm: TileMap) -> void:
	tilemap_target = tm
	_undo_stack.clear()
	_redo_stack.clear()

func set_tool(t: int) -> void:
	current_tool = clamp(t, TOOL_BRUSH, TOOL_RECT_FILL)

func begin_batch() -> void:
	_is_dragging = true
	_batch_ops.clear()

func end_batch() -> void:
	if not _is_dragging:
		return
	_is_dragging = false
	if _batch_ops.is_empty():
		return
	if _undo_stack.size() >= MAX_UNDO:
		_undo_stack.pop_front()
	_undo_stack.append({"ops": _batch_ops.duplicate()})
	_redo_stack.clear()
	undo_performed.emit(_undo_stack.size())

func paint_cell(coord: Vector2i, tile_id_hint: int = -1) -> void:
	if tilemap_target == null or not is_instance_valid(tilemap_target):
		return
	var tid: int = tile_id_hint if tile_id_hint >= 0 else current_tile_id
	match current_tool:
		TOOL_BRUSH:
			_apply_cell(current_layer, coord, tid)
		TOOL_ERASER:
			_apply_cell(current_layer, coord, -1)
		TOOL_RECT_FILL:
			pass  # fill 调用 flood_fill 单独做

func _apply_cell(layer_idx: int, coord: Vector2i, new_tile: int) -> void:
	if tilemap_target == null:
		return
	var old: int = tilemap_target.get_cell_source_id(layer_idx, coord)
	if old == new_tile and new_tile != -1:
		return
	tilemap_target.set_cell(layer_idx, coord, max(0, new_tile), Vector2i.ZERO, 0)
	if new_tile == -1:
		tilemap_target.erase_cell(layer_idx, coord)
	var op := {"layer": layer_idx, "coord": coord, "old": old, "new": new_tile}
	if _is_dragging:
		_batch_ops.append(op)
	else:
		# single click = 1-op undo entry
		if _undo_stack.size() >= MAX_UNDO:
			_undo_stack.pop_front()
		_undo_stack.append({"ops": [op]})
		_redo_stack.clear()
	cell_painted.emit(layer_idx, coord, new_tile, old)

func flood_fill_area(start_coord: Vector2i, new_tile: int, rect_only: bool = false, end_coord: Vector2i = Vector2i.ZERO) -> int:
	if tilemap_target == null:
		return 0
	var ops := []
	if rect_only:
		var min_c := Vector2i(min(start_coord.x, end_coord.x), min(start_coord.y, end_coord.y))
		var max_c := Vector2i(max(start_coord.x, end_coord.x), max(start_coord.y, end_coord.y))
		for x in range(min_c.x, max_c.x + 1):
			for y in range(min_c.y, max_c.y + 1):
				var c := Vector2i(x, y)
				var old := tilemap_target.get_cell_source_id(current_layer, c)
				if old != new_tile:
					tilemap_target.set_cell(current_layer, c, new_tile, Vector2i.ZERO, 0)
					ops.append({"layer": current_layer, "coord": c, "old": old, "new": new_tile})
	else:
		# BFS flood fill (only same old tile)
		var target_old := tilemap_target.get_cell_source_id(current_layer, start_coord)
		if target_old == new_tile:
			return 0
		var visited := {}
		var queue: Array[Vector2i] = [start_coord]
		while queue.size() > 0:
			var c: Vector2i = queue.pop_front()
			var key := str(c.x) + "," + str(c.y)
			if visited.has(key):
				continue
			visited[key] = true
			var cur := tilemap_target.get_cell_source_id(current_layer, c)
			if cur != target_old:
				continue
			tilemap_target.set_cell(current_layer, c, new_tile, Vector2i.ZERO, 0)
			ops.append({"layer": current_layer, "coord": c, "old": target_old, "new": new_tile})
			queue.append(c + Vector2i.RIGHT)
			queue.append(c + Vector2i.LEFT)
			queue.append(c + Vector2i.UP)
			queue.append(c + Vector2i.DOWN)
	if ops.is_empty():
		return 0
	if _undo_stack.size() >= MAX_UNDO:
		_undo_stack.pop_front()
	_undo_stack.append({"ops": ops})
	_redo_stack.clear()
	return ops.size()

func undo() -> int:
	if _undo_stack.is_empty() or tilemap_target == null:
		return 0
	var entry: Dictionary = _undo_stack.pop_back()
	_redo_stack.append(entry)
	var count := 0
	for op in entry["ops"]:
		tilemap_target.set_cell(int(op["layer"]), op["coord"], int(op["old"]), Vector2i.ZERO, 0)
		if int(op["old"]) == -1:
			tilemap_target.erase_cell(int(op["layer"]), op["coord"])
		count += 1
	undo_performed.emit(_undo_stack.size())
	return count

func redo() -> int:
	if _redo_stack.is_empty() or tilemap_target == null:
		return 0
	var entry: Dictionary = _redo_stack.pop_back()
	_undo_stack.append(entry)
	var count := 0
	for op in entry["ops"]:
		tilemap_target.set_cell(int(op["layer"]), op["coord"], int(op["new"]), Vector2i.ZERO, 0)
		if int(op["new"]) == -1:
			tilemap_target.erase_cell(int(op["layer"]), op["coord"])
		count += 1
	redo_performed.emit(_redo_stack.size())
	return count

func can_undo() -> bool:
	return not _undo_stack.is_empty()

func can_redo() -> bool:
	return not _redo_stack.is_empty()

func undo_count() -> int:
	return _undo_stack.size()

func redo_count() -> int:
	return _redo_stack.size()

func clear_history() -> void:
	_undo_stack.clear()
	_redo_stack.clear()
	_batch_ops.clear()
