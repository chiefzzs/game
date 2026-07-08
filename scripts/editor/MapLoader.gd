extends Node
class_name MapLoader
## V0.2 T02-08：游戏端 MapLoader — 把 .map.json 加载到当前场景：
##   - 8层 TileMap 实例化 cells（把 id:x:y 写入 TileMap.set_cell）
##   - 实体（NPC/Enemy/Chest/CP/Portal/Trigger）实例化为 Area2D/CharacterBody2D 并挂载 metadata
##   - 目标 objectives 通过 LevelFlow.start_level(level_id, objectives) 绑定到 LevelFlowController
##
## 加载接口：
##   load_map_to_parent(parent: Node2D, map_data: Dictionary, use_autoload: bool = true)
##     -> {status, layers_instantiated, entities_instantiated, error_count}

signal loaded(map_id: String, summary: Dictionary)

const VALID_KINDS := ["npc", "enemy", "chest", "checkpoint", "portal", "trigger"]

func load_map_to_parent(parent: Node2D, map_data: Dictionary, use_autoload: bool = true) -> Dictionary:
	var summary := {"layers_instantiated": 0, "entities_instantiated": 0, "cells_count": 0, "error_count": 0, "issues": []}
	if map_data.is_empty():
		summary["error_count"] += 1
		summary["issues"].append("map_data is empty")
		return summary
	var map_id: String = str(map_data.get("map_id", ""))
	# --- 1. TileMap: 如果 parent 下没有 TileMap 节点，就新建 8 层 ---
	var tm: TileMap = parent.get_node_or_null("TileMap")
	if tm == null:
		tm = TileMap.new()
		tm.name = "TileMap"
		tm.add_layer(0)
		for i in range(1, 8):
			tm.add_layer(i)
		parent.add_child(tm)
	for i in range(tm.get_layers_count(), 8):
		tm.add_layer(i)
	# --- 2. Layers cells ---
	if map_data.has("layers") and map_data["layers"] is Array:
		for layer_dict in map_data["layers"]:
			if not (layer_dict is Dictionary):
				summary["error_count"] += 1
				summary["issues"].append("layer 不是 dictionary")
				continue
			var idx: int = int(layer_dict.get("index", 0))
			idx = clamp(idx, 0, 7)
			var cells: Array = layer_dict.get("cells", [])
			if cells is Array:
				for c in cells:
					if c is Array and c.size() >= 3:
						var cx: int = int(c[0]); var cy: int = int(c[1]); var tid: int = int(c[2])
						if tid >= 0:
							tm.set_cell(idx, Vector2i(cx, cy), 0, Vector2i(tid, 0), 0)
						else:
							tm.erase_cell(idx, Vector2i(cx, cy))
						summary["cells_count"] += 1
			summary["layers_instantiated"] += 1
	# --- 3. Entities ---
	if map_data.has("entities") and map_data["entities"] is Array:
		var eid_used := {}
		for ent in map_data["entities"]:
			if not (ent is Dictionary):
				summary["error_count"] += 1
				continue
			var kind: String = str(ent.get("kind", ""))
			var id: String = str(ent.get("id", ("ent_" + str(summary["entities_instantiated"]))))
			if eid_used.has(id):
				id = id + "_" + str(summary["entities_instantiated"])
			eid_used[id] = true
			var x: float = float(ent.get("x", 0))
			var y: float = float(ent.get("y", 0))
			var props: Dictionary = ent.get("props", {})
			var node: Node2D = _make_entity_node(kind, id, props)
			if node == null:
				summary["error_count"] += 1
				summary["issues"].append("未知 kind=" + kind)
				continue
			node.global_position = Vector2(x, y)
			parent.add_child(node)
			# 默认加个碰撞形状，保证 Area2D 类实体有 body_entered 可触发
			if node is Area2D and node.get_child_count() == 0:
				var cs := CollisionShape2D.new()
				var rect := RectangleShape2D.new()
				rect.size = Vector2(float(props.get("size_w", 32)), float(props.get("size_h", 32)))
				cs.shape = rect
				node.add_child(cs)
			summary["entities_instantiated"] += 1
	# --- 4. Objectives -> LevelFlow.start_level ---
	var arr: Array = map_data.get("objectives", [])
	var next_level_id: String = str(map_data.get("meta", {}).get("next_level", "")) if map_data.has("meta") else ""
	var intro: float = 3.0
	if use_autoload and LevelFlow:
		LevelFlow.start_level(map_id, arr, next_level_id, intro)
	loaded.emit(map_id, summary)
	return summary

func _make_entity_node(kind: String, id: String, props: Dictionary) -> Node2D:
	match kind:
		"checkpoint", "trigger", "chest", "portal":
			var area := Area2D.new()
			area.name = id
			area.set_meta("role", kind)
			area.set_meta("kind", kind)
			for k in props.keys():
				area.set_meta(k, props[k])
			return area
		"enemy", "npc":
			# 作为 CharacterBody2D 占位（真实项目用 CharacterBase 子类）
			var body := CharacterBody2D.new()
			body.name = id
			body.set_meta("role", kind)
			body.set_meta("kind", kind)
			for k in props.keys():
				body.set_meta(k, props[k])
			return body
		_:
			return null
