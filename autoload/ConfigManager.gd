extends Node
## V0.3 ConfigManager.gd - 4层配置体系：L1常量 < L2平衡 < L3关卡 < L4用户设置
## dotPath 语法： get("player.farmer.max_hp", 100) 即可穿透合并后的字典树

enum ConfigLayer { L1_CONSTANTS = 0, L2_BALANCE = 1, L3_LEVELS = 2, L4_USER = 3 }

var _merged: Dictionary = {}
var _layers: Array[Dictionary] = [{}, {}, {}, {}]
var _dirty: bool = true

const LAYER_FILES := {
	ConfigLayer.L1_CONSTANTS: ["res://config/L1_constants/constants.json"],
	ConfigLayer.L2_BALANCE: [
		"res://config/L2_balance/player.json",
		"res://config/L2_balance/companions.json",
		"res://config/L2_balance/enemies.json",
		"res://config/L2_balance/combat_formula.json",
		"res://config/L2_balance/pickups.json"],
	ConfigLayer.L3_LEVELS: ["res://config/L3_levels/chapters.json"],
}

func _ready() -> void:
	reload_all()

func reload_all() -> void:
	for layer in ConfigLayer.values():
		_layers[layer] = {}
		if layer in LAYER_FILES:
			for path in LAYER_FILES[layer]:
				var parsed: Dictionary = _read_json(path)
				_deep_merge_into(_layers[layer], parsed)
	if FileAccess.file_exists("user://settings.json"):
		var uset = _read_json("user://settings.json")
		_layers[ConfigLayer.L4_USER] = uset
	_build_merged()
	_dirty = false

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

func _deep_merge_into(base: Dictionary, extra: Dictionary) -> void:
	for k in extra.keys():
		var v = extra[k]
		if base.has(k) and typeof(base[k]) == TYPE_DICTIONARY and typeof(v) == TYPE_DICTIONARY:
			_deep_merge_into(base[k], v)
		else:
			base[k] = v

func _build_merged() -> void:
	_merged.clear()
	for layer in ConfigLayer.values():
		_deep_merge_into(_merged, _layers[layer])

var _overrides: Dictionary = {}

func cfg_get(path: String, default: Variant = null) -> Variant:
	if _overrides.has(path):
		return _overrides[path]
	if _dirty:
		_build_merged()
		_dirty = false
	var parts: PackedStringArray = path.split(".")
	var cur: Variant = _merged
	for p in parts:
		if typeof(cur) != TYPE_DICTIONARY:
			return default
		var d: Dictionary = cur
		if not d.has(p):
			return default
		cur = d[p]
	return cur

func override(path: String, value: Variant) -> void:
	if value == null and _overrides.has(path):
		_overrides.erase(path)
	else:
		_overrides[path] = value
	_dirty = true

func get_layer(layer: int) -> Dictionary:
	return _layers[layer].duplicate(true)

func set_user(key: String, value: Variant) -> void:
	_deep_put(_layers[ConfigLayer.L4_USER], key, value)
	_dirty = true

func _deep_put(d: Dictionary, path: String, value: Variant) -> void:
	var parts: PackedStringArray = path.split(".")
	var cur: Dictionary = d
	for i in range(parts.size() - 1):
		var p: String = parts[i]
		if not cur.has(p) or typeof(cur[p]) != TYPE_DICTIONARY:
			cur[p] = {}
		cur = cur[p]
	cur[parts[parts.size() - 1]] = value

func save_settings() -> Error:
	var txt := JSON.stringify(_layers[ConfigLayer.L4_USER], "\t")
	var f := FileAccess.open("user://settings.json", FileAccess.WRITE)
	if f == null:
		return ERR_FILE_CANT_OPEN
	f.store_string(txt)
	f.close()
	return OK

func dump() -> String:
	return JSON.stringify(_merged, "\t")
