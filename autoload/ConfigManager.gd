extends Node
## 全局配置管理器（Autoload单例，Node名：Config，注意不是ConfigManager！短名）
## 四层配置：L1常量 / L2平衡 / L3关卡 / L4玩家设置
## 调用：Config.GetL2("player.baseHp", 100)  Config.SetPref("audio.bgmVolume", 0.5)

var _l1_cache: Dictionary = {}
var _l2_cache: Dictionary = {}
var _l3_cache: Dictionary = {}
var _l4_cache: Dictionary = {}

const L1_PATH := "res://config/L1_constants/constants.json"
const L2_DIR := "res://config/L2_balance/"
const L3_CHAPTERS_PATH := "res://config/L3_levels/chapters.json"
const L4_DEFAULT_PATH := "res://config/L4_settings/settings.default.json"
const L4_USER_PATH := "user://settings.json"

signal PlayerPrefChanged(key: String, new_value)
signal BalanceReloaded()

func _ready() -> void:
	_LoadL1()
	_LoadL2()
	_LoadL3()
	_LoadOrInitL4()

# ------------------------------------------------------------
# 对外查询
# ------------------------------------------------------------
func GetL2(path: String, def_val = null):
	return _QueryDict(_l2_cache, path, def_val)

func GetL1(path: String, def_val = null):
	return _QueryDict(_l1_cache, path, def_val)

func GetL3(path: String, def_val = null):
	return _QueryDict(_l3_cache, path, def_val)

func GetPref(key: String, def_val = null):
	return _QueryDict(_l4_cache, key, def_val)

func SetPref(key: String, value) -> void:
	_WriteDict(_l4_cache, key, value)
	_SaveL4()
	PlayerPrefChanged.emit(key, value)

func ResetPrefsToDefault() -> void:
	_l4_cache = _LoadJson(L4_DEFAULT_PATH)
	_SaveL4()
	PlayerPrefChanged.emit("__ALL__", null)

func ReloadBalance() -> void:
	if OS.has_feature("editor") or OS.is_debug_build():
		_LoadL2()
		BalanceReloaded.emit()
		print("[Config] L2 balance reloaded.")

func DumpAllPrefs() -> void:
	print("=== L4 Player Settings ===")
	print(JSON.stringify(_l4_cache, "\t"))

# ------------------------------------------------------------
# 内部加载/保存
# ------------------------------------------------------------
func _LoadL1() -> void:
	_l1_cache = _LoadJson(L1_PATH)
func _LoadL2() -> void:
	_l2_cache.clear()
	var dir := DirAccess.open(L2_DIR)
	if dir:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if fname.ends_with(".json"):
				var key_name := fname.get_basename()
				var data := _LoadJson(L2_DIR + fname)
				_l2_cache[key_name] = data
			fname = dir.get_next()
func _LoadL3() -> void:
	var raw := _LoadJson(L3_CHAPTERS_PATH)
	_l3_cache = raw if raw.has("chapters") else {"chapters": raw}
func _LoadOrInitL4() -> void:
	if FileAccess.file_exists(L4_USER_PATH):
		_l4_cache = _LoadJson(L4_USER_PATH)
	else:
		_l4_cache = _LoadJson(L4_DEFAULT_PATH)
		_SaveL4()
func _SaveL4() -> void:
	_SaveJson(L4_USER_PATH, _l4_cache)

static func _LoadJson(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[Config] 无法加载: " + path + " (" + str(FileAccess.get_open_error()) + ")")
		return {}
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[Config] JSON不是字典: " + path)
		return {}
	return parsed

static func _SaveJson(path: String, data: Dictionary) -> void:
	var d := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(d):
		DirAccess.make_dir_absolute(d)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[Config] 无法写入: " + path)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

# ------------------------------------------------------------
# dotPath 核心算法
# ------------------------------------------------------------
static func _QueryDict(dict: Dictionary, dot_path: String, def_val):
	if dict.is_empty():
		return def_val
	var parts := dot_path.split(".", false)
	var cur: Variant = dict
	for p in parts:
		# 支持 "key[index]" 这种数组查询（简单处理）
		var bracket_open := p.find("[")
		var index := -1
		if bracket_open > 0:
			var p2 := p.substr(bracket_open + 1, p.length() - bracket_open - 2)
			if p2.is_valid_int():
				index = int(p2)
			p = p.substr(0, bracket_open)
		if typeof(cur) == TYPE_DICTIONARY and (cur as Dictionary).has(p):
			cur = (cur as Dictionary)[p]
			if index >= 0 and typeof(cur) == TYPE_ARRAY:
				var arr := cur as Array
				if index < arr.size():
					cur = arr[index]
				else:
					return def_val
		else:
			return def_val
	return cur

static func _WriteDict(dict: Dictionary, dot_path: String, value) -> void:
	var parts := dot_path.split(".", false)
	var cur: Dictionary = dict
	for i in range(parts.size() - 1):
		var p := parts[i]
		if not cur.has(p) or typeof(cur[p]) != TYPE_DICTIONARY:
			cur[p] = {}
		cur = cur[p]
	cur[parts[parts.size() - 1]] = value
