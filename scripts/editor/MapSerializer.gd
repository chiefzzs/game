extends Node
class_name MapSerializer
## V0.2 T02-07：地图保存 / 加载序列化器 — 统一 .map.json 格式（走 MapSchemaValidator 校验再写盘）
## 输出示例：
## {
##   "version": "0.2.0",
##   "map_id": "farm_01",
##   "display_name": "农场 - 新手教学",
##   "tilesets": [ {"id":1,"name":"farm","first_id":1} ],
##   "layers": [ {"index":2,"name":"Layer2 地面","cells":[[x,y,tile_id],...]} ],
##   "entities": [ {"id":"cp_1","kind":"checkpoint","x":800,"y":700,"props":{...}} ],
##   "objectives": [ {"logic":"AND"}, {"id":"reach_1","type":"REACH_AREA","data":{...},"reward":{...}} ],
##   "meta": {"author":"","create_ts":...,"spawn":{"x":560,"y":800}}
## }

signal save_completed(path: String, bytes: int, validation_errors: Array)
signal load_completed(path: String, map_data: Dictionary, validation_errors: Array)

var validator: MapSchemaValidator

func _ready() -> void:
	validator = MapSchemaValidator.new()

func build_map_dict(
	map_id: String,
	display_name: String,
	layers_data: Array,
	entities_data: Array,
	objectives_data: Array,
	meta: Dictionary = {},
	tilesets_list: Array = [{ "id": 1, "name": "farm", "first_id": 1 }, { "id": 2, "name": "village", "first_id": 100 }, { "id": 3, "name": "forest", "first_id": 200 }, { "id": 4, "name": "castle", "first_id": 300 }, { "id": 5, "name": "admin", "first_id": 400 }]
) -> Dictionary:
	var data := {
		"version": Config.config_version if Config else "0.2.0",
		"map_id": map_id,
		"display_name": display_name,
		"tilesets": tilesets_list.duplicate(true),
		"layers": layers_data.duplicate(true),
		"entities": entities_data.duplicate(true),
		"objectives": objectives_data.duplicate(true),
		"meta": meta.duplicate(true),
	}
	if not data["meta"].has("create_ts"):
		data["meta"]["create_ts"] = Time.get_datetime_string_from_system(true, true)
	return data

func save_to_file(map_data: Dictionary, abs_path: String, do_validate: bool = true) -> int:
	var errors: Array = validator.validate(map_data) if do_validate else []
	if do_validate and not errors.is_empty():
		save_completed.emit(abs_path, 0, errors)
		return -1
	var json_txt: String = JSON.stringify(map_data, "\t")
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		save_completed.emit(abs_path, 0, [{"path": "$file", "message": "无法打开文件写入: %s" % abs_path}])
		return -2
	f.store_string(json_txt)
	f.close()
	var backup_path := abs_path + ".bak"
	var fbak := FileAccess.open(backup_path, FileAccess.WRITE)
	if fbak:
		fbak.store_string(json_txt)
		fbak.close()
	save_completed.emit(abs_path, json_txt.length(), errors)
	return json_txt.length()

func load_from_file(abs_path: String, do_validate: bool = true) -> Dictionary:
	if not FileAccess.file_exists(abs_path):
		load_completed.emit(abs_path, {}, [{"path": "$file", "message": "文件不存在: %s" % abs_path}])
		return {}
	var f := FileAccess.open(abs_path, FileAccess.READ)
	if f == null:
		load_completed.emit(abs_path, {}, [{"path": "$file", "message": "无法打开文件读取: %s" % abs_path}])
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if parsed == null or not (parsed is Dictionary):
		load_completed.emit(abs_path, {}, [{"path": "$file", "message": "JSON 解析失败: map.json 结构不是对象"}])
		return {}
	var errors := validator.validate(parsed) if do_validate else []
	load_completed.emit(abs_path, parsed, errors)
	return parsed

func user_maps_dir() -> String:
	# 返回用户地图目录：%APPDATA%/Godot/app_userdata/MedievalRebellion/UserMaps/
	# 如目录不存在则创建
	var dir: String = OS.get_user_data_dir().path_join("UserMaps")
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	return dir

func resolve_map_path(filename: String) -> String:
	if filename.find("/") == -1 and filename.find("\\") == -1:
		return user_maps_dir().path_join(filename)
	return filename
