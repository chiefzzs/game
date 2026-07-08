extends Node
## V0.3 scripts/editor/MapLoader.gd — Phase1存在性要求
## 占位实现：保证脚本可被Godot headless加载，返回空数据不崩溃

class_name MapLoader

signal map_loaded(map_id: String, data: Dictionary)
signal map_load_failed(map_id: String, reason: String)

var last_loaded: Dictionary = {}

func load_from_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		emit_signal("map_load_failed", path, "not_found")
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		emit_signal("map_load_failed", path, "open_fail")
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		emit_signal("map_load_failed", path, "parse_fail")
		return {}
	last_loaded = parsed
	emit_signal("map_loaded", path, parsed)
	return parsed

func is_valid(data: Dictionary) -> bool:
	return data != null and data.is_empty() == false and data.has("entities")
