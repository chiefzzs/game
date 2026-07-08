@tool
extends SceneTree
## Phase4 Headless：MapSerializer 构造 farm 模板 → 保存临时文件 → Validator校验 → MapLoader 实例化。
func _init() -> void:
	var serializer_script: Script = load("res://scripts/editor/MapSerializer.gd")
	var validator_script: Script = load("res://scripts/editor/MapSchemaValidator.gd")
	var loader_script: Script = load("res://scripts/editor/MapLoader.gd")
	var serializer: RefCounted = serializer_script.new()
	var validator: RefCounted = validator_script.new()
	var loader: RefCounted = loader_script.new()
	var tmp_dir: String = OS.get_user_data_dir().path_join("tmp_smoke")
	DirAccess.make_dir_recursive_absolute(tmp_dir)
	var save_to: String = tmp_dir.path_join("smoke_farm_io.map.json")
	# 1. build
	var cells: Array = []
	for x in range(0, 60):
		cells.append([x, 14, 1])
	var layers: Array = []
	for li in range(8):
		if li == 2:
			layers.append({"index": li, "name": "L2", "cells": cells})
		else:
			layers.append({"index": li, "name": "L"+str(li), "cells": []})
	var entities: Array = [
		{"id": "cp1", "kind": "checkpoint", "x": 200, "y": 760, "props": {"cp_id": "cp_start"}},
		{"id": "sc1", "kind": "enemy", "x": 1100, "y": 660, "props": {"hp": 30, "atk": 10}},
	]
	var objectives: Array = [
		{"logic": "AND"},
		{"id": "reach_end", "type": "REACH_AREA", "data": {"x": 1600, "y": 700, "w": 120, "h": 120}, "reward": {"gold": 20}},
	]
	var dict: Dictionary = serializer.build_map_dict("smoke_io_farm", "Farm-Smoke", layers, entities, objectives, {"spawn": {"x": 200, "y": 800}})
	# 2. save
	var bytes: int = serializer.save_to_file(dict, save_to, true)
	if bytes <= 0:
		print("[Phase4][FAIL] save failed, bytes=", bytes)
		quit(1)
	print("[Phase4][OK] 写入 ", save_to, "  ", bytes, " bytes")
	# 3. validate
	var errs: Array = validator.validate(dict)
	if not errs.is_empty():
		print("[Phase4][FAIL] validate: ", errs.size(), " errors")
		quit(2)
	print("[Phase4][OK] Schema 通过")
	# 4. load
	var loaded: Dictionary = serializer.load_from_file(save_to, false)
	if loaded.is_empty():
		print("[Phase4][FAIL] load returned empty")
		quit(3)
	var parent: Node2D = Node2D.new()
	root.add_child(parent)
	var summary: Dictionary = loader.load_map_to_parent(parent, loaded, false)
	var li_cnt: int = summary.get("layers_instantiated") if summary.has("layers_instantiated") else 0
	var ei_cnt: int = summary.get("entities_instantiated") if summary.has("entities_instantiated") else 0
	var cc_cnt: int = summary.get("cells_count") if summary.has("cells_count") else 0
	var ec_cnt: int = summary.get("error_count") if summary.has("error_count") else 0
	print("[Phase4][OK] MapLoader 实例化 layers=", li_cnt,
		" entities=", ei_cnt, " cells=", cc_cnt,
		" errors=", ec_cnt)
	var success: bool = (ec_cnt == 0) and (li_cnt == 8)
	print("[Phase4]", "✅ 全部通过" if success else "❌ 失败")
	quit(0 if success else 4)
