extends Control
class_name WorkshopMain
## V0.2 迭代2 T02-10/T02-11：游戏内地图工坊 UI
## 4 个子项：
##   1. 📄 新建空地图 → 打开 EditorMain 场景（新建状态）
##   2. 📂 编辑已有地图 → 扫描用户地图目录（%APPDATA%/Godot/app_userdata/MedievalRebellion/UserMaps）
##                       列出所有 .map.json 供选择后打开编辑器
##   3. 📚 官方模板 → 打开 3 张官方模板（empty/farm/arena）
##   4. 🎮 测试用户地图 → 选择 .map.json 后作为游戏关卡启动，加载进 GameMain
##
## 入口挂在：
##   - 主菜单 Level2（“⚒ 地图工坊”）
##   - 暂停菜单 扩展按钮（Workshop 入口开关，MainMenu PauseMenu 两处可挂）

signal map_test_requested(map_path: String)
signal map_edit_requested(map_path: String)
signal workshop_back_to_menu()

const USER_MAPS_DIR_KEY := "UserMaps"
const TEMPLATES_DIR := "res://scenes/workshop/templates/"

var _serializer: MapSerializer
var _current_user_maps: Array = []  # Array of {path, name, id}
var _current_templates: Array = []

func _ready() -> void:
	_serializer = MapSerializer.new()
	_refresh_user_maps()
	_refresh_templates()
	_connect_signals_if_present()

func _connect_signals_if_present() -> void:
	# 自动连接 WorkshopMain 场景中约定命名的按钮：
	#   $TopBar/BackBtn, $Buttons/BtnNew, $Buttons/BtnEdit, $Buttons/BtnOfficial, $Buttons/BtnTest
	if has_node("Buttons/BtnNew"):
		$Buttons/BtnNew.pressed.connect(_on_new_clicked)
	if has_node("Buttons/BtnEdit"):
		$Buttons/BtnEdit.pressed.connect(_on_edit_clicked)
	if has_node("Buttons/BtnOfficial"):
		$Buttons/BtnOfficial.pressed.connect(_on_official_clicked)
	if has_node("Buttons/BtnTest"):
		$Buttons/BtnTest.pressed.connect(_on_test_clicked)
	if has_node("TopBar/BackBtn"):
		$TopBar/BackBtn.pressed.connect(func(): workshop_back_to_menu.emit())
	# 刷新按钮
	if has_node("TopBar/RefreshBtn"):
		$TopBar/RefreshBtn.pressed.connect(_on_refresh)

func user_maps_dir() -> String:
	return _serializer.user_maps_dir() if _serializer else OS.get_user_data_dir().path_join(USER_MAPS_DIR_KEY)

func _refresh_user_maps() -> void:
	_current_user_maps.clear()
	var dir_path := user_maps_dir()
	var da := DirAccess.open(dir_path)
	if da == null:
		return
	da.list_dir_begin()
	var f := da.get_next()
	while f != "":
		if f.ends_with(".map.json") and not f.ends_with(".bak"):
			var full := dir_path.path_join(f)
			var just_name := f.get_basename().get_basename()
			_current_user_maps.append({"path": full, "name": just_name, "file": f, "size_bytes": FileAccess.get_modified_time(full)})
		f = da.get_next()
	da.list_dir_end()
	_current_user_maps.sort_custom(func(a, b): return int(b["size_bytes"]) - int(a["size_bytes"]))

func _refresh_templates() -> void:
	_current_templates.clear()
	var names := ["empty", "farm", "arena"]
	for n in names:
		var res_path := TEMPLATES_DIR + n + ".map.json"
		var abs_path := ProjectSettings.globalize_path(res_path)
		if FileAccess.file_exists(abs_path):
			_current_templates.append({
				"res_path": res_path,
				"abs_path": abs_path,
				"name": n,
				"display_name": {
					"empty": "🧱 Empty 空白模板",
					"farm": "🌾 Farm 农场模板",
					"arena": "⚔ Arena 竞技场模板",
				}.get(n, n)
			})
	# 如果官方模板不存在，先创建一张 farm 示例（保证功能可演示）
	if _current_templates.is_empty():
		_ensure_builtin_templates()
		_refresh_templates()

func _ensure_builtin_templates() -> void:
	# 写入3张 .map.json 到 templates 目录
	var abs_dir := ProjectSettings.globalize_path(TEMPLATES_DIR)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	_save_empty_template(abs_dir.path_join("empty.map.json"), "empty_01", "🧱 空白地图", 60, 30)
	_save_farm_template(abs_dir.path_join("farm.map.json"))
	_save_arena_template(abs_dir.path_join("arena.map.json"))

func _save_empty_template(path: String, id: String, dn: String, cols: int, rows: int) -> void:
	var layers: Array = []
	for li in range(8):
		layers.append({"index": li, "name": "Layer" + str(li), "cells": []})
	var data := _serializer.build_map_dict(id, dn, layers, [], [
		{"logic": "AND"},
		{"id": "reach_end", "type": "REACH_AREA", "data": {"x": 1600, "y": 700, "w": 120, "h": 120}, "reward": {"gold": 20}}
	], {
		"spawn": {"x": 200, "y": 800},
		"next_level": "",
		"template_name": "empty",
		"create_ts": Time.get_datetime_string_from_system(true, true),
	})
	_serializer.save_to_file(data, path, true)

func _save_farm_template(path: String) -> void:
	var cells := []
	# 地面：y=14 (60 tiles grass, tile_id=1)
	for x in range(0, 60):
		cells.append([x, 14, 1])
	# 左平台 stone(3) ：x=10..21 y=10
	for x in range(10, 22):
		cells.append([x, 10, 3])
	# 右平台 wood(4)：x=30..41 y=8
	for x in range(30, 42):
		cells.append([x, 8, 4])
	var layers := []
	for li in range(8):
		if li == 2:
			layers.append({"index": li, "name": "Layer2 地面", "cells": cells})
		else:
			layers.append({"index": li, "name": "Layer" + str(li), "cells": []})
	var entities := [
		{"id": "cp_1", "kind": "checkpoint", "x": 200, "y": 760, "props": {"cp_id": "cp_start", "restore_hp": true}},
		{"id": "chest_1", "kind": "chest", "x": 15 * 48 + 24, "y": 9 * 48, "props": {"loot": {"gold": 30}, "is_locked": false}},
		{"id": "sc_1", "kind": "enemy", "x": 1100, "y": 660, "props": {"hp": 30, "atk": 10, "patrol_r": 40, "chase_r": 180, "attack_r": 34, "cd": 1.2}},
		{"id": "np_f", "kind": "npc", "x": 80, "y": 800 - 40, "props": {"name": "Farmer John", "dialog": "join_me_farm", "recruit_cost": 50, "hp": 60, "atk": 8}},
		{"id": "pt_n", "kind": "portal", "x": 2800, "y": 640, "props": {"target_level": "village_edge_01", "need_objectives_done": true}},
		{"id": "tr_reach", "kind": "trigger", "x": 1600, "y": 680, "props": {"obj_id": "reach_end", "size_w": 120, "size_h": 120, "action": "objective_done"}},
	]
	var objectives := [
		{"logic": "AND"},
		{"id": "reach_end", "type": "REACH_AREA", "data": {"x": 1600, "y": 680, "w": 120, "h": 120}, "reward": {"gold": 20}},
		{"id": "sc_die_1", "type": "DEFEAT_ENEMY", "data": {"enemy_ids": ["sc_1"]}, "reward": {"unlock": ["skin_default"], "gold": 15}},
	]
	var data := _serializer.build_map_dict("farm_01", "🌾 农场 - 新手村", layers, entities, objectives, {
		"spawn": {"x": 200, "y": 800},
		"next_level": "village_edge_01",
		"template_name": "farm",
		"mode": "PVE",
		"min_rank": 1,
		"bounds": {"x": 0, "y": 0, "w": 60 * 48, "h": 1080},
		"create_ts": Time.get_datetime_string_from_system(true, true),
	})
	_serializer.save_to_file(data, path, true)

func _save_arena_template(path: String) -> void:
	var cells := []
	# 竞技场地板 (1~50 x, y=13..14  共2行)
	for x in range(1, 50):
		cells.append([x, 14, 3])
		cells.append([x, 13, 3])
	# 两堵 side wall：y=9..14  at x=0 and x=50
	for y in range(9, 15):
		cells.append([0, y, 3])
		cells.append([50, y, 3])
	var layers := []
	for li in range(8):
		if li == 2:
			layers.append({"index": li, "name": "Layer2 ArenaFloor", "cells": cells})
		else:
			layers.append({"index": li, "name": "Layer" + str(li), "cells": []})
	var entities := [
		{"id": "cp_start", "kind": "checkpoint", "x": 200, "y": 600, "props": {"cp_id": "cp_start", "restore_hp": true}},
		{"id": "enemy_s_1", "kind": "enemy", "x": 1600, "y": 600, "props": {"hp": 80, "atk": 14, "patrol_r": 80, "chase_r": 500, "attack_r": 40, "cd": 1.0}},
		{"id": "enemy_s_2", "kind": "enemy", "x": 1800, "y": 600, "props": {"hp": 80, "atk": 14, "patrol_r": 80, "chase_r": 500, "attack_r": 40, "cd": 1.0}},
		{"id": "enemy_k_1", "kind": "enemy", "x": 1100, "y": 600, "props": {"hp": 180, "atk": 24, "patrol_r": 40, "chase_r": 400, "attack_r": 44, "cd": 1.4}},
		{"id": "ch_1", "kind": "chest", "x": 2300, "y": 600, "props": {"loot": {"gold": 80, "potion": 2}, "is_locked": false}},
		{"id": "exit_p", "kind": "portal", "x": 2350, "y": 600, "props": {"target_level": "admin_hall", "need_objectives_done": true}},
	]
	var objectives := [
		{"logic": "AND"},
		{"id": "kill_boss", "type": "BOSS", "data": {"enemy_id": "enemy_k_1"}, "reward": {"gold": 100, "unlock": ["title_arena_champion"]}},
		{"id": "kill_ads", "type": "DEFEAT_ENEMY", "data": {"enemy_ids": ["enemy_s_1", "enemy_s_2"]}, "reward": {"gold": 40}},
	]
	var data := _serializer.build_map_dict("arena_01", "⚔ 竞技场 - 骑士挑战", layers, entities, objectives, {
		"spawn": {"x": 200, "y": 620},
		"next_level": "admin_hall",
		"template_name": "arena",
		"mode": "ARENA",
		"min_rank": 3,
		"bounds": {"x": 0, "y": 0, "w": 51 * 48, "h": 1080},
		"create_ts": Time.get_datetime_string_from_system(true, true),
	})
	_serializer.save_to_file(data, path, true)

func _on_refresh() -> void:
	_refresh_user_maps()
	_refresh_templates()
	set_status("已刷新：用户地图 %d 张 | 官方模板 %d 张 → %s" % [_current_user_maps.size(), _current_templates.size(), user_maps_dir()], 0)

func _on_new_clicked() -> void:
	# 打开编辑器场景（新建空白图）
	set_status("新建地图 → 打开地图编辑器...", 0)
	await get_tree().process_frame
	if get_tree().change_scene_to_file("res://scenes/editor/EditorMain.tscn") != OK:
		set_status("打开编辑器失败：EditorMain.tscn 未找到或脚本错误", 2)

func _on_edit_clicked() -> void:
	_on_refresh()
	if _current_user_maps.is_empty():
		set_status("用户目录还没有地图：请先用『新建』或把 .map.json 放进 " + user_maps_dir(), 1)
		return
	var first_map := _current_user_maps[0]
	set_status("打开编辑器，加载用户地图: " + first_map["file"], 0)
	Flags.Set("editor_load_on_start", first_map["path"])
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/editor/EditorMain.tscn")

func _on_official_clicked() -> void:
	_on_refresh()
	if _current_templates.is_empty():
		set_status("官方模板还未构建（请重启游戏，或手动在 workshop/templates 放 .map.json）", 1)
		return
	var first := _current_templates[0]
	set_status("打开官方模板 → " + first["display_name"], 0)
	# 把模板 map.json 拷贝到用户目录再以编辑模式打开
	var user_dest := user_maps_dir().path_join("official__" + first["name"] + "_" + str(Time.get_unix_time_from_system()) + ".map.json")
	DirAccess.copy_absolute(first["abs_path"], user_dest)
	Flags.Set("editor_load_on_start", user_dest)
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/editor/EditorMain.tscn")

func _on_test_clicked() -> void:
	var candidates := []
	candidates.append_array(_current_user_maps)
	# 也允许测试官方模板
	for t in _current_templates:
		candidates.append({"path": t["abs_path"], "name": t["name"], "file": t["name"] + ".map.json"})
	if candidates.is_empty():
		set_status("没有可测试的地图。请先『新建』『官方模板』创建一张地图", 1)
		return
	var pick := candidates[0]
	set_status("🎮 启动测试地图: " + pick["file"], 0)
	Flags.Set("next_run_load_map", pick["path"])
	await get_tree().process_frame
	if get_tree().change_scene_to_file("res://scenes/gameplay/GameMain.tscn") != OK:
		# 无 GameMain 场景 → fallback 到 InputCollisionTest 旧测试场景
		Flags.Set("next_run_load_map", pick["path"])
		get_tree().change_scene_to_file("res://scenes/test/V01_InputCollisionTest.tscn")

func set_status(msg: String, level: int = 0) -> void:
	if has_node("StatusBar/Label"):
		var pref := ["ℹ ", "⚠ ", "❌ "][clamp(level, 0, 2)]
		$StatusBar/Label.text = pref + msg

func list_user_maps() -> Array:
	return _current_user_maps.duplicate(true)

func list_templates() -> Array:
	return _current_templates.duplicate(true)
