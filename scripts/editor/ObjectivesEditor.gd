extends Control
class_name ObjectivesEditor
## V0.2 T02-06：目标配置编辑器面板
## 支持组合逻辑 AND/OR/NOT，共 10 种目标处理器类型：
##   REACH_AREA / DEFEAT_ENEMY / RECRUIT / OPEN_CHEST / TRIGGER /
##   DIALOG / BOSS / AND / OR / NOT
##
## 数据结构（最终写入 map.json 的 objectives 节点）：
## [
##   {"logic":"AND"},                                       ← 可选第一项，指定根组合逻辑
##   {"id":"reach_1","type":"REACH_AREA","data":{"x":1400,"y":700,"w":80,"h":80}, "reward":{"gold":10}},
##   {"id":"def_1","type":"DEFEAT_ENEMY","data":{"enemy_ids":["enemy_scarecrow_1"]}, "reward":{"unlock":["weapon_rusty_sword"]}},
## ]

signal objectives_changed(new_objectives: Array)

var objectives: Array = []
var _root_logic: String = "AND"

func set_root_logic(logic: String) -> void:
	var l := logic.to_upper()
	if l not in ["AND", "OR"]:
		l = "AND"
	_root_logic = l
	_sync_and_emit()

func get_root_logic() -> String:
	return _root_logic

func add_objective(obj_type: String, obj_id: String = "", data: Dictionary = {}, reward: Dictionary = {}) -> Dictionary:
	var type_upper := obj_type.to_upper()
	var id := obj_id if obj_id != "" else ("obj_" + str(objectives.size() + 1))
	var obj: Dictionary = {
		"id": id,
		"type": type_upper,
		"status": "pending",
		"data": data.duplicate(true),
		"reward": reward.duplicate(true),
	}
	objectives.append(obj)
	_sync_and_emit()
	return obj

func remove_objective(obj_id: String) -> bool:
	for i in range(objectives.size()):
		if objectives[i].get("id", "") == obj_id:
			objectives.remove_at(i)
			_sync_and_emit()
			return true
	return false

func update_objective(obj_id: String, field: String, value) -> bool:
	for i in range(objectives.size()):
		if objectives[i].get("id", "") == obj_id:
			objectives[i][field] = value
			_sync_and_emit()
			return true
	return false

func get_objective(obj_id: String) -> Dictionary:
	for o in objectives:
		if o.get("id", "") == obj_id:
			return o.duplicate(true)
	return {}

func list_types() -> Array:
	return [
		"REACH_AREA", "DEFEAT_ENEMY", "RECRUIT", "OPEN_CHEST",
		"TRIGGER", "DIALOG", "BOSS", "AND", "OR", "NOT",
	]

func load_objectives(arr: Array) -> void:
	objectives.clear()
	var logic_found := false
	for raw in arr:
		if raw is Dictionary:
			if raw.has("logic") and not logic_found:
				_root_logic = str(raw["logic"]).to_upper()
				logic_found = true
				continue
			if raw.has("id") and raw.has("type"):
				var copy: Dictionary = raw.duplicate(true)
				if not copy.has("status"):
					copy["status"] = "pending"
				if not copy.has("data"):
					copy["data"] = {}
				if not copy.has("reward"):
					copy["reward"] = {}
				objectives.append(copy)
	_sync_and_emit()

func to_json_array() -> Array:
	var out: Array = []
	out.append({"logic": _root_logic})
	for o in objectives:
		var c: Dictionary = o.duplicate(true)
		c.erase("status")  # 写盘时不存 status（由 LevelFlow 运行时写入）
		out.append(c)
	return out

func count() -> int:
	return objectives.size()

func _sync_and_emit() -> void:
	objectives_changed.emit(to_json_array())
