@tool
extends SceneTree
## Phase4 Headless：MapSerializer 构造 farm 模板 → 保存临时文件 → Validator校验 → MapLoader 实例化。
func _init() -> void:
	var serializer := load("res://scripts/editor/MapSerializer.gd").new()
	var validator := load("res://scripts/editor/MapSchemaValidator.gd").new()
	var loader := load("res://scripts/editor/MapLoader.gd").new()
	var tmp_dir := OS.get_user_data_dir().path_join("tmp_smoke")
	DirAccess.make_dir_recursive_absolute(tmp_dir)
	var save_to := tmp_dir.path_join("smoke_farm_io.map.json")
	# 1. build
	var cells := []
	for x in range(0, 60):
		cells.append([x, 14, 1])
	var layers := []
	for li in range(8):
		if li == 2:
			layers.append({"index": li, "name": "L2", "cells": cells})
		else:
			layers.append({"index": li, "name": "L"+str(li), "cells": []})
	var entities := [
		{"id": "cp1", "kind": "checkpoint", "x": 200, "y": 760, "props": {"cp_id": "cp_start"}},
		{"id": "sc1", "kind": "enemy", "x": 1100, "y": 660, "props": {"hp": 30, "atk": 10}},
	]
	var objectives := [
		{"logic": "AND"},
		{"id": "reach_end", "type": "REACH_AREA", "data": {"x": 1600, "y": 700, "w": 120, "h": 120}, "reward": {"gold": 20}},
	]
	var dict := serializer.build_map_dict("smoke_io_farm", "Farm-Smoke", layers, entities, objectives, {"spawn": {"x": 200, "y": 800}})
	# 2. save
	var bytes := serializer.save_to_file(dict, save_to, true)
	if bytes <= 0:
		print("[Phase4][FAIL] save failed, bytes=", bytes)
		quit(1)
	print("[Phase4][OK] 写入 ", save_to, "  ", bytes, " bytes")
	# 3. validate
	var errs := validator.validate(dict)
	if not errs.is_empty():
		print("[Phase4][FAIL] validate: ", errs.size(), " errors")
		quit(2)
	print("[Phase4][OK] Schema 通过")
	# 4. load
	var loaded: Dictionary = serializer.load_from_file(save_to, false)
	if loaded.is_empty():
		print("[Phase4][FAIL] load returned empty")
		quit(3)
	var parent := Node2D.new()
	add_child(parent)
	var summary: Dictionary = loader.load_map_to_parent(parent, loaded, false)
	print("[Phase4][OK] MapLoader 实例化 layers=", summary.layers_instantiated,
		" entities=", summary.entities_instantiated, " cells=", summary.cells_count,
		" errors=", summary.error_count)
	var success := summary.error_count == 0 and summary.layers_instantiated == 8
	print("[Phase4]", "✅ 全部通过" if success else "❌ 失败")
	quit(0 if success else 4)
